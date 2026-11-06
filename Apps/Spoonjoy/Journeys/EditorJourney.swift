import SpoonjoyCore
import XCTest

/// The recipe editor's checks that need QA or the real keyboard. The editor's own logic (capture drafts, moving
/// steps, save planning, the discard prompt, the conflict banner's choices) is proved headless in SpoonjoyReinsTests.
@MainActor
final class EditorJourney: JourneyTestCase {
    /// UI: Return closes the keyboard in the editor's single-line Servings field. The check runs on a cold start: the
    /// relaunch comes first, so no saved draft or open editor is carried into it.
    func testEditorReturnClosesTheKeyboardJourney() async throws {
        let account = try JourneyAccounts.account(3)
        let token = try JourneyAccounts.runToken()
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: "Journey \(token) Basil Pasta J4",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Tear the basil",
                    description: "Tear the basil leaves into a bowl.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "Journey\(token)basil")],
                    outputStepNums: []
                )
            ]
        )
        let recipeLink = try XCTUnwrap(URL(string: "spoonjoy://recipes/\(recipeID)"))
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        verifyAfterRelaunch(journey) {
            journey.openLink(recipeLink)
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.networkTimeout),
                "\(recipeLink) did not open the recipe. Screen: \(journey.screen)"
            )
            journey.tap(JourneyID.recipeDetailActions)
            journey.tap(JourneyID.recipeDetailEdit)
            journey.replaceText(in: JourneyID.editorServings, with: "7")
            journey.pressReturn()
            XCTAssertTrue(
                journey.app.keyboards.firstMatch.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
                "Return did not close the keyboard. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "05-editor-keyboard-closed", to: self)
        }
    }

    /// Live journey: the recipe is renamed somewhere else while the cook has it open in the editor, and the cook saves
    /// a different title. QA keeps the other version while the held-change banner is up, and holds the cook's title
    /// after Keep mine.
    func testRecipeEditConflictJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let original = "Journey \(token) Soup J4b Original"
        let elsewhere = "Journey \(token) Soup J4b Elsewhere"
        let mine = "Journey \(token) Soup J4b Mine"
        let qa = try await JourneyQAClient.signIn(account)
        let recipeID = try await qa.createRecipe(
            title: original,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Simmer",
                    description: "Simmer the stock.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "l", name: "stock")],
                    outputStepNums: []
                )
            ]
        )
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )
        journey.openTab(JourneyCopy.recipesTab)
        journey.openRecipe(titled: original, from: JourneyID.recipesRow)
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailEdit)
        // The editor has loaded QA's version before the rename, so the save below is based on the original.
        journey.assertFieldValue(JourneyID.editorTitle, equals: original)

        // Another device renames the recipe while this editor is open.
        try await qa.renameRecipe(recipeID, to: elsewhere)

        journey.replaceText(in: JourneyID.editorTitle, with: mine)
        journey.saveOpenRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeKeepMine).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not offer to keep the edit after the recipe was renamed elsewhere. Screen: \(journey.screen)"
        )
        // Live: while the banner is up, QA still holds the title saved elsewhere.
        let heldTitle = try await qa.recipeTitle(recipeID)
        XCTAssertEqual(heldTitle, elsewhere, "The held edit overwrote the title saved elsewhere.")
        journey.attachScreenshot(named: "12-recipe-edit-conflict-banner", to: self)

        // Live: Keep mine reaches QA.
        journey.tap(JourneyID.heldChangeKeepMine)
        let saved = try await qa.recipeTitle(recipeID, waitingFor: mine)
        XCTAssertEqual(saved, mine, "QA does not hold the cook's title after Keep mine.")
        journey.attachScreenshot(named: "13-recipe-edit-conflict-kept-mine", to: self)

        // After a relaunch the app lists the recipe under the title QA holds.
        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: mine, from: JourneyID.recipesRow)
        }
    }
}
