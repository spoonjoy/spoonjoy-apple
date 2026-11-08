import SpoonjoyCore
import XCTest

/// Live journey: checking an ingredient in cook mode reaches QA's cook-session store. The test process reads the
/// session straight from QA with the account's own bearer token, so a pass proves the server holds the check and not
/// only this device, and a relaunch never moves QA's revision backwards. The cook-mode logic itself (ordering, timers,
/// page turns, saved progress) is proved headless in SpoonjoyReinsTests; this journey keeps only what needs QA or the
/// real UI and OS: the recipe page's step stays put when a check shows Clear progress, the cook session's Live Activity
/// on SpringBoard, and cook mode's layout at the largest accessibility text size.
@MainActor
final class CookSyncJourney: JourneyTestCase {
    func testCookModeCheckReachesTheServerJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Cook Sync J4"
        let lemon = "Journey\(token)lemon"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Zest the lemon",
                    description: "Zest the lemon into a bowl.",
                    duration: 10,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 1, unit: "whole", name: lemon),
                        RecipeIngredientDraft(quantity: 1, unit: "tsp", name: "Journey\(token)salt")
                    ],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Serve",
                    description: "Spoon the zest over the dish.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: []
                )
            ]
        )
        let ingredientID = try await qa.ingredientID(named: lemon, inRecipe: recipeID)
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        journey.openTab(JourneyCopy.recipesTab)
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)

        // UI: Clear progress has room kept for it in the Steps heading, so a check that shows it moves nothing above the
        // step, and clearing moves nothing back.
        let pageLemon = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: lemon)
        let recipeTitle = journey.element(JourneyID.recipeDetailTitle)
        let stepOne = journey.element(JourneyID.recipeDetailStep(1))
        XCTAssertTrue(
            pageLemon.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not list the lemon. Screen: \(journey.screen)"
        )
        let stepOffsetBeforeCheck = stepOne.frame.minY - recipeTitle.frame.minY
        journey.attachScreenshot(named: "00-recipe-before-check", to: self)
        JourneyTruncation.assertNone(journey, on: "The recipe page at the default text size")
        pageLemon.tap()
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailClearProgress).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Clear progress did not appear after a check. Screen: \(journey.screen)"
        )
        XCTAssertEqual(
            stepOne.frame.minY - recipeTitle.frame.minY,
            stepOffsetBeforeCheck,
            accuracy: 0.5,
            "Checking an ingredient moved the step down the page."
        )
        journey.attachScreenshot(named: "00a-recipe-ingredient-checked", to: self)
        journey.tap(JourneyID.recipeDetailClearProgress)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailClearProgress).waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Clear progress stayed after there was nothing left to clear."
        )
        XCTAssertEqual(
            stepOne.frame.minY - recipeTitle.frame.minY,
            stepOffsetBeforeCheck,
            accuracy: 0.5,
            "Clearing progress moved the step."
        )
        try await testAddToListStaysReachable(journey, row: pageLemon, ingredient: lemon, qa: qa)

        journey.tap(JourneyID.recipeDetailCook)
        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: lemon)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the lemon. Screen: \(journey.screen)"
        )
        ingredient.tap()
        journey.attachScreenshot(named: "01-checked-in-cook-mode", to: self)
        JourneyTruncation.assertNone(journey, on: "The cook step at the default text size")

        // Live: the app sends after a short pause; the test process reads QA until the check arrives.
        let reading = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThan(reading.revision, 0, "QA's cook session has not moved past revision 0.")
        XCTAssertTrue(reading.checkedIngredientIDs.contains(ingredientID), "QA's cook session does not hold the checked ingredient.")
        let attachment = XCTAttachment(string: reading.redactedBody)
        attachment.name = "qa-cook-session-response (bearer token redacted)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // OS: the cook session's Live Activity on SpringBoard.
        verifyCookSessionLiveActivity(journey, returnTo: ingredient)

        // UI: after a relaunch at the largest accessibility text size, cook mode's step text, ring and card fit.
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        journey.useLargestAccessibilityTextOnNextLaunch()
        verifyAfterRelaunch(journey) {
            journey.openLink(cookLink)
            verifyLargestTextLayout(journey)
            journey.attachScreenshot(named: "06-after-relaunch-largest-text", to: self)
            JourneyTruncation.assertNone(journey, on: "The cook step at the largest text size")
        }

        // Live: the relaunch's own sync never moves QA's cook session backwards.
        let afterRelaunch = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThanOrEqual(afterRelaunch.revision, reading.revision, "A relaunch moved QA's cook session backwards.")
    }

    /// UI and live: the recipe page's ingredient rows draw no cart, so Add to list lives in each row's context menu.
    /// A long press opens it, and choosing it puts that one ingredient on QA's shopping list.
    private func testAddToListStaysReachable(
        _ journey: JourneyApp,
        row: XCUIElement,
        ingredient: String,
        qa: JourneyQAClient
    ) async throws {
        row.press(forDuration: 1.2)
        let addToList = journey.element(JourneyID.ingredientAddToList)
        XCTAssertTrue(
            addToList.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "The ingredient row's context menu has no Add to list. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "00b-recipe-ingredient-add-to-list", to: self)
        addToList.tap()
        for _ in 0..<30 {
            if try await qa.shoppingList().receiptItems.contains(where: { $0.name.localizedCaseInsensitiveContains(ingredient) }) {
                return
            }
            try await Task.sleep(for: .seconds(1))
        }
        XCTFail("Add to list on the lemon's row did not put it on QA's shopping list.")
    }
}

extension CookSyncJourney {
    /// At the largest accessibility text size the step text wraps inside the window, the ring stays at least 120 pt,
    /// and the step text, ring and step card do not overlap.
    private func verifyLargestTextLayout(_ journey: JourneyApp) {
        let window = journey.app.windows.firstMatch.frame
        let text = journey.element(JourneyID.cookStepText)
        let ring = journey.element(JourneyID.cookTimerRing)
        let card = journey.element(JourneyID.cookStepCard)
        XCTAssertTrue(text.waitForExistence(timeout: JourneyApp.interactionTimeout), "Step 1 has no step text. Screen: \(journey.screen)")
        XCTAssertTrue(ring.exists, "Step 1 has no timer ring at the largest text size. Screen: \(journey.screen)")
        XCTAssertTrue(card.exists, "Step 1 has no step card at the largest text size. Screen: \(journey.screen)")
        XCTAssertGreaterThanOrEqual(text.frame.minX, window.minX, "The step text starts outside the window.")
        XCTAssertLessThanOrEqual(text.frame.maxX, window.maxX, "The step text runs past the window instead of wrapping.")
        XCTAssertGreaterThanOrEqual(min(ring.frame.width, ring.frame.height), 120, "The timer ring is smaller than 120 pt.")
        XCTAssertLessThanOrEqual(text.frame.maxY, ring.frame.minY + 0.5, "The step text overlaps the timer ring.")
        XCTAssertLessThanOrEqual(ring.frame.maxY, card.frame.minY + 0.5, "The timer ring overlaps the step card.")
    }

    /// Leaving cook mode open and going home shows the cook session in the Dynamic Island (or the Lock Screen
    /// banner on a phone without one), read through SpringBoard. Cook mode is still registered, so it says Step 1.
    private func verifyCookSessionLiveActivity(_ journey: JourneyApp, returnTo cookModeElement: XCUIElement) {
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Only Spoonjoy's own island or Lock Screen elements count, and "Step 1 of" never matches Step 10.
        let step = springboard.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier IN %@ AND label BEGINSWITH %@",
                ["cookSession.liveActivity.step", "cookSession.liveActivity.ring"],
                "Step 1 of "
            ))
            .firstMatch
        XCTAssertTrue(
            step.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The cook session Live Activity does not show Step 1 outside the app. SpringBoard: \(springboard.debugDescription)"
        )
        let island = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        island.name = "04-cook-session-live-activity"
        island.lifetime = .keepAlways
        add(island)

        journey.app.activate()
        XCTAssertTrue(
            cookModeElement.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Returning to the app did not bring cook mode back. Screen: \(journey.screen)"
        )
    }
}
