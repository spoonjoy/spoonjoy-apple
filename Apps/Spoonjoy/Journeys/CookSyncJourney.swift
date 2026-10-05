import SpoonjoyCore
import XCTest

/// Journey 4: checking an ingredient in cook mode reaches QA's cook-session store. The test process reads
/// the session straight from QA with the account's own bearer token, so a pass proves the server holds the
/// check and not only this device. The check also survives a relaunch.
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
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "whole", name: lemon)],
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
        journey.tap(JourneyID.recipeDetailCook)

        let ingredient = journey.element(JourneyID.cookIngredient, labelContainingIgnoringCase: lemon)
        XCTAssertTrue(
            ingredient.waitForExistence(timeout: JourneyApp.networkTimeout),
            "Cook mode does not list the lemon. Screen: \(journey.screen)"
        )
        ingredient.tap()
        XCTAssertEqual(ingredient.value as? String, "checked", "Tapping the lemon did not check it in cook mode.")
        journey.attachScreenshot(named: "01-checked-in-cook-mode", to: self)

        // The app sends after a short pause; the test process reads QA until the check arrives.
        let reading = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThan(reading.revision, 0, "QA's cook session has not moved past revision 0.")
        XCTAssertTrue(reading.checkedIngredientIDs.contains(ingredientID), "QA's cook session does not hold the checked ingredient.")
        let attachment = XCTAttachment(string: reading.redactedBody)
        attachment.name = "qa-cook-session-response (bearer token redacted)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // The relaunch keeps this device's own state, so the proof that the server holds the check is the
        // reading above; here the relaunch must still be signed in and must not undo what QA holds.
        verifyAfterRelaunch(journey) {
            XCTAssertFalse(journey.element(JourneyID.passwordSignIn).exists, "The app signed out on relaunch.")
        }
        let afterRelaunch = try await qa.cookSession(recipeID: recipeID, waitingForChecked: ingredientID)
        XCTAssertGreaterThanOrEqual(afterRelaunch.revision, reading.revision, "A relaunch moved QA's cook session backwards.")
    }
}
