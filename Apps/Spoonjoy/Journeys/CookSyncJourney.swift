import SpoonjoyCore
import XCTest

/// Journey 4: checking an ingredient in cook mode reaches QA's cook-session store. The test process reads
/// the session straight from QA with the account's own bearer token, so a pass proves the server holds the
/// check and not only this device. The check also survives a relaunch. The step has a duration, so the journey
/// also sets its timer and cancels it. The CI simulator refuses AlarmKit, so the app records a stand-in alarm
/// (`NativeJourneyAlarmFixture`); cook mode's per-step registry and Cancel control are the real ones.
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

        // The recipe page: the step lists lemon, salt and oil in the recipe's order, with nothing to clear yet.
        let pageLemon = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: lemon)
        let pageSalt = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: salt)
        let pageOil = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: oil)
        let recipeTitle = journey.element(JourneyID.recipeDetailTitle)
        let stepOne = journey.element(JourneyID.recipeDetailStep(1))
        XCTAssertTrue(
            pageLemon.waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not list the lemon. Screen: \(journey.screen)"
        )
        XCTAssertLessThan(pageLemon.frame.minY, pageSalt.frame.minY, "The lemon is not first before any check.")
        XCTAssertLessThan(pageSalt.frame.minY, pageOil.frame.minY, "The salt is not above the oil before any check.")
        XCTAssertFalse(journey.element(JourneyID.recipeDetailClearProgress).exists, "Clear progress shows with nothing to clear.")
        let stepOffsetBeforeCheck = stepOne.frame.minY - recipeTitle.frame.minY
        journey.attachScreenshot(named: "00-recipe-before-check", to: self)

        // Checking the first ingredient sinks it below the others, and the page above the step does not move.
        pageLemon.tap()
        XCTAssertEqual(pageLemon.value as? String, "used", "Tapping the lemon on the recipe page did not check it.")
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
        XCTAssertLessThan(pageSalt.frame.minY, pageOil.frame.minY, "The unchecked salt and oil lost their order.")
        XCTAssertGreaterThan(pageLemon.frame.minY, pageOil.frame.minY, "The checked lemon did not move below the oil.")
        journey.attachScreenshot(named: "00a-recipe-first-ingredient-checked", to: self)

        // Clear progress unchecks it, and the lemon returns to the top of the step.
        journey.tap(JourneyID.recipeDetailClearProgress)
        XCTAssertEqual(pageLemon.value as? String, "not used", "Clear progress did not uncheck the lemon.")
        XCTAssertLessThan(pageLemon.frame.minY, pageSalt.frame.minY, "The unchecked lemon did not return to the top.")
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
            journey.element(JourneyID.cookScale).exists,
            "Cook mode does not show scaling inline. Screen: \(journey.screen)"
        )
        ingredient.tap()
        // The checkbox reads "1" as a switch and "checked" as a button, depending on how the platform exposes it.
        XCTAssertTrue(
            ["1", "checked"].contains(ingredient.value as? String ?? ""),
            "Tapping the lemon did not check it in cook mode. Value: \(String(describing: ingredient.value))"
        )
        journey.attachScreenshot(named: "01-checked-in-cook-mode", to: self)

        // The app sends after a short pause; the test process reads QA until the check arrives.
        let reading = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThan(reading.revision, 0, "QA's cook session has not moved past revision 0.")
        XCTAssertTrue(reading.checkedIngredientIDs.contains(ingredientID), "QA's cook session does not hold the checked ingredient.")
        let attachment = XCTAttachment(string: reading.redactedBody)
        attachment.name = "qa-cook-session-response (bearer token redacted)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The step's timer: once it is set, Cancel replaces the start button.
        journey.tap(JourneyID.cookTimerStart)
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerCancel).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Starting the step timer did not offer Cancel. Screen: \(journey.screen)"
        )
        XCTAssertFalse(journey.element(JourneyID.cookTimerStart).exists, "The start button stayed while the step's timer runs.")
        // One status line while the timer runs: the "timer set" row, with no second message under it.
        XCTAssertTrue(journey.element(JourneyID.cookTimerSetLabel).exists, "The running timer does not say it is set.")
        XCTAssertFalse(journey.element(JourneyID.cookTimerStatus).exists, "The running timer repeats its status in a second line.")
        journey.attachScreenshot(named: "02-timer-set-with-cancel", to: self)

        journey.tap(JourneyID.cookTimerCancel)
        XCTAssertTrue(
            journey.element(JourneyID.cookTimerStart).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Cancelling the step timer did not bring the start button back. Screen: \(journey.screen)"
        )
        XCTAssertFalse(journey.element(JourneyID.cookTimerCancel).exists, "Cancel stayed after the timer was cancelled.")
        XCTAssertTrue(journey.element(JourneyID.cookTimerStatus).exists, "Cancelling the timer did not say so.")
        journey.attachScreenshot(named: "03-timer-cancelled", to: self)

        // The relaunch keeps this device's own state, so the proof that the server holds the check is the
        // reading above; here the relaunch must still be signed in and must not undo what QA holds.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        let afterRelaunch = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThanOrEqual(afterRelaunch.revision, reading.revision, "A relaunch moved QA's cook session backwards.")
    }
}
