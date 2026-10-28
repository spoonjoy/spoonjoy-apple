import SpoonjoyCore
import XCTest

/// Journey 4: checking an ingredient in cook mode reaches QA's cook-session store. The test process reads
/// the session straight from QA with the account's own bearer token, so a pass proves the server holds the
/// check and not only this device. The step has a duration, so checking all its ingredients starts its timer, and
/// the journey cancels it. The CI simulator refuses AlarmKit, so the app records a stand-in alarm
/// (`NativeJourneyAlarmFixture`); cook mode's per-step registry, ring and Cancel control are the real ones. A swipe
/// turns to step 2, and after a relaunch at the largest text size cook mode reopens there with step 1's checks kept.
///
/// Before cook mode, the recipe page checks the step's first ingredient: as on the web it sinks to the bottom of
/// the step's list, nothing above the step moves (Clear progress has room kept for it in the Steps heading), and
/// Clear progress puts it back.
@MainActor
final class CookSyncJourney: JourneyTestCase {
    func testCookModeCheckReachesTheServerJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Cook Sync J4"
        let lemon = "Journey\(token)lemon"
        let salt = "Journey\(token)salt"
        let oil = "Journey\(token)oil"
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
                        RecipeIngredientDraft(quantity: 1, unit: "tsp", name: salt),
                        RecipeIngredientDraft(quantity: 2, unit: "tbsp", name: oil)
                    ],
                    outputStepNums: []
                ),
                // A second step to turn to: by a swipe on compact width, by the dock's Next on regular width.
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

        // The recipe page lists lemon, salt and oil with nothing to clear yet. The API orders a step's ingredients
        // by ID (orderBy id in app/lib/api-v1.server.ts), so the journey reads the step's order from the page.
        let pageLemon = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: lemon)
        let pageSalt = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: salt)
        let pageOil = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: oil)
        let recipeTitle = journey.element(JourneyID.recipeDetailTitle)
        let stepOne = journey.element(JourneyID.recipeDetailStep(1))
        XCTAssertTrue(
            pageLemon.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not list the lemon. Screen: \(journey.screen)"
        )
        XCTAssertTrue(pageSalt.exists, "The recipe page does not list the salt. Screen: \(journey.screen)")
        XCTAssertTrue(pageOil.exists, "The recipe page does not list the oil. Screen: \(journey.screen)")
        let stepOrder = [pageLemon, pageSalt, pageOil].sorted { $0.frame.minY < $1.frame.minY }
        let firstIngredient = stepOrder[0]
        let secondIngredient = stepOrder[1]
        let lastIngredient = stepOrder[2]
        XCTAssertFalse(journey.element(JourneyID.recipeDetailClearProgress).exists, "Clear progress shows with nothing to clear.")
        let stepOffsetBeforeCheck = stepOne.frame.minY - recipeTitle.frame.minY
        journey.attachScreenshot(named: "00-recipe-before-check", to: self)

        // Checking the first ingredient sinks it below the others, and the page above the step does not move.
        firstIngredient.tap()
        XCTAssertEqual(firstIngredient.value as? String, "used", "Tapping the first ingredient on the recipe page did not check it.")
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailClearProgress).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Clear progress did not appear after the first check. Screen: \(journey.screen)"
        )
        XCTAssertEqual(
            stepOne.frame.minY - recipeTitle.frame.minY,
            stepOffsetBeforeCheck,
            accuracy: 0.5,
            "Checking an ingredient moved the step down the page."
        )
        XCTAssertLessThan(secondIngredient.frame.minY, lastIngredient.frame.minY, "The unchecked ingredients lost their order.")
        XCTAssertGreaterThan(firstIngredient.frame.minY, lastIngredient.frame.minY, "The checked ingredient did not move to the bottom.")
        journey.attachScreenshot(named: "00a-recipe-first-ingredient-checked", to: self)

        // Clear progress unchecks it, and it returns to the top of the step.
        journey.tap(JourneyID.recipeDetailClearProgress)
        XCTAssertEqual(firstIngredient.value as? String, "not used", "Clear progress did not uncheck the ingredient.")
        XCTAssertLessThan(firstIngredient.frame.minY, secondIngredient.frame.minY, "The unchecked ingredient did not return to the top.")
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

        journey.tap(JourneyID.recipeDetailCook)

        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: lemon)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the lemon. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.cookStepMeta, labelContaining: "Step 1 of 2").exists,
            "Cook mode does not say Step 1 of 2. Screen: \(journey.screen)"
        )
        XCTAssertTrue(journey.element(JourneyID.cookMore).exists, "Cook mode has no More menu for Scale. Screen: \(journey.screen)")
        XCTAssertTrue(journey.element(JourneyID.cookTimerRing).exists, "The timed step has no timer ring. Screen: \(journey.screen)")
        ingredient.tap()
        XCTAssertTrue(isChecked(ingredient), "Tapping the lemon did not check it in cook mode. Value: \(String(describing: ingredient.value))")
        journey.attachScreenshot(named: "01-checked-in-cook-mode", to: self)

        // The app sends after a short pause; the test process reads QA until the check arrives.
        let reading = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThan(reading.revision, 0, "QA's cook session has not moved past revision 0.")
        XCTAssertTrue(reading.checkedIngredientIDs.contains(ingredientID), "QA's cook session does not hold the checked ingredient.")
        let attachment = XCTAttachment(string: reading.redactedBody)
        attachment.name = "qa-cook-session-response (bearer token redacted)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Checking the rest of the step's ingredients starts its timer by itself: the ring counts down and offers Cancel.
        XCTAssertFalse(journey.element(JourneyID.cookTimerRunning).exists, "The timer started before every ingredient was checked.")
        let saltRow = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: salt)
        saltRow.tap()
        XCTAssertTrue(isChecked(saltRow), "Tapping the salt did not check it in cook mode.")
        let oilRow = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: oil)
        oilRow.tap()
        XCTAssertTrue(isChecked(oilRow), "Tapping the oil did not check it in cook mode.")
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerRunning).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Checking every ingredient did not start the step's timer. Screen: \(journey.screen)"
        )
        XCTAssertTrue(journey.element(JourneyID.cookTimerCancel).exists, "The running timer does not offer Cancel. Screen: \(journey.screen)")
        // While the timer runs the ring is its status, with no second message under it.
        XCTAssertFalse(journey.element(JourneyID.cookTimerStatus).exists, "The running timer repeats its status in a second line.")
        journey.attachScreenshot(named: "02-timer-running", to: self)

        journey.tap(JourneyID.cookTimerCancel)
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerRunning).waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Cancelling the step timer did not stop the ring. Screen: \(journey.screen)"
        )
        XCTAssertTrue(journey.element(JourneyID.cookTimerRing).exists, "Cancelling the timer did not bring the ring back to start.")
        XCTAssertFalse(journey.element(JourneyID.cookTimerCancel).exists, "Cancel stayed after the timer was cancelled.")
        XCTAssertTrue(journey.element(JourneyID.cookTimerStatus).exists, "Cancelling the timer did not say so.")
        journey.attachScreenshot(named: "03-timer-cancelled", to: self)

        verifyCookSessionLiveActivity(journey, returnTo: ingredient)

        turnToTheNextStep(journey)
        XCTAssertTrue(
            journey.element(JourneyID.cookStepMeta, labelContaining: "Step 2 of 2").waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Turning the page did not reach Step 2 of 2. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "05-second-step", to: self)

        // The relaunch keeps this device's own state, so the proof that the server holds the check is the reading above.
        // It takes the largest accessibility text size too: cook mode reopens on step 2, and step 1 still has its checks.
        let cookLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)/cook"))
        journey.useLargestAccessibilityTextOnNextLaunch()
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        journey.openLink(cookLink)
        XCTAssertTrue(
            journey.element(JourneyID.cookStepMeta, labelContaining: "Step 2 of 2").waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode did not reopen on step 2 after a relaunch. Screen: \(journey.screen)"
        )
        turnToThePreviousStep(journey)
        let lemonAfterRelaunch = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: lemon)
        XCTAssertTrue(
            lemonAfterRelaunch.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Turning back did not show step 1's lemon after a relaunch. Screen: \(journey.screen)"
        )
        XCTAssertTrue(isChecked(lemonAfterRelaunch), "The lemon lost its check after a relaunch.")
        verifyLargestTextLayout(journey)
        journey.attachScreenshot(named: "06-after-relaunch-largest-text", to: self)

        let afterRelaunch = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThanOrEqual(afterRelaunch.revision, reading.revision, "A relaunch moved QA's cook session backwards.")
    }
}

extension CookSyncJourney {
    /// The checkbox reads "1" as a switch and "checked" as a button, depending on how the platform exposes it.
    private func isChecked(_ element: XCUIElement) -> Bool {
        ["1", "checked"].contains(element.value as? String ?? "")
    }

    /// Compact width has no dock: a swipe turns the page. Regular width keeps the dock, so Next turns it there, and
    /// Back joins the dock once there is a step to go back to.
    private func usesDock(_ journey: JourneyApp) -> Bool {
        journey.app.windows.firstMatch.frame.width >= 700
    }

    private func turnToTheNextStep(_ journey: JourneyApp) {
        guard usesDock(journey) else {
            journey.element(JourneyID.cookPage).swipeLeft()
            return
        }
        let dockNext = journey.element(JourneyID.cookDockNext)
        XCTAssertTrue(dockNext.waitForExistence(timeout: JourneyApp.interactionTimeout), "The dock has no Next. Screen: \(journey.screen)")
        XCTAssertTrue(journey.element(JourneyID.cookDockDone).exists, "The dock has no Mark step. Screen: \(journey.screen)")
        XCTAssertFalse(journey.element(JourneyID.cookDockPrevious).exists, "Step 1 shows a Back with nowhere to go. Screen: \(journey.screen)")
        dockNext.tap()
        let dockPrevious = journey.element(JourneyID.cookDockPrevious)
        XCTAssertTrue(dockPrevious.waitForExistence(timeout: JourneyApp.interactionTimeout), "Back did not join the dock after Next. Screen: \(journey.screen)")
        XCTAssertTrue(dockPrevious.isHittable, "Back is in the dock but can't be tapped. Screen: \(journey.screen)")
    }

    private func turnToThePreviousStep(_ journey: JourneyApp) {
        guard usesDock(journey) else {
            journey.element(JourneyID.cookPage).swipeRight()
            return
        }
        journey.tap(JourneyID.cookDockPrevious)
    }

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
