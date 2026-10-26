import SpoonjoyCore
import XCTest

/// Journey 4: there is no in-app recipe form. Every create entry opens Add a recipe, whose pasted link becomes
/// a capture draft in Imports that survives a relaunch. A recipe made elsewhere is then edited in the native
/// editor: its two steps are swapped, and the new order holds on the recipe page and after a relaunch.
@MainActor
final class EditorJourney: JourneyTestCase {
    func testAddRecipeFromPastedLinkJourney() throws {
        let account = try JourneyAccounts.account(3)
        let token = try JourneyAccounts.runToken()
        // A recipe page on QA. Importing it would need AI consent, so the journey stops at the capture draft.
        let link = JourneyQA.baseURL.appendingPathComponent("recipes/journey-\(token)-pasted").absoluteString
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // Account 3 has no recipes yet, so the kitchen leads with its hero, whose button opens Add a recipe.
        XCTAssertTrue(
            journey.element(JourneyID.kitchenEmptyHero).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A kitchen with no recipes does not show the empty-kitchen hero. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "00-empty-kitchen-hero", to: self)
        journey.tap(JourneyID.kitchenEmptyHeroCreate)
        journey.assertAddRecipeSheet()
        journey.attachScreenshot(named: "01-add-recipe-sheet", to: self)
        journey.tap(JourneyID.addRecipeClose)

        // The Shopping List's "Add a recipe" opens the same sheet.
        journey.openTab(JourneyCopy.shoppingTab)
        journey.tap(JourneyID.shoppingCreateRecipe)
        journey.assertAddRecipeSheet()
        journey.tap(JourneyID.addRecipeClose)

        // The Kitchen toolbar's Add a recipe: a pasted link becomes a capture draft in Imports.
        journey.openTab(JourneyCopy.kitchenTab)
        journey.tap(JourneyID.addRecipe)
        journey.assertAddRecipeSheet()
        journey.enterText(link, into: JourneyID.addRecipeLink)
        journey.tap(JourneyID.addRecipeImport)
        XCTAssertTrue(
            journey.element(JourneyID.captureDraft, descendantLabelContaining: link).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Importing a pasted link did not open Imports with the link as a capture draft. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "02-pasted-link-in-imports", to: self)

        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.kitchenTab)
            journey.tap(JourneyID.kitchenImports)
            XCTAssertTrue(
                journey.element(JourneyID.captureDraft, descendantLabelContaining: link).waitForExistence(timeout: JourneyApp.interactionTimeout),
                "The pasted link's capture draft is gone after a relaunch. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "03-pasted-link-after-relaunch", to: self)
        }
    }

    func testEditorReorderJourney() async throws {
        let account = try JourneyAccounts.account(3)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Basil Pasta J4"
        let basil = "Journey\(token)basil"
        let spaghetti = "spaghetti"
        let qa = try await JourneyQAClient.signIn(account)
        _ = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Tear the basil",
                    description: "Tear the basil leaves into a bowl.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: basil)],
                    outputStepNums: []
                ),
                RecipeStepDraft(
                    stepNum: 2,
                    stepTitle: "Cook the spaghetti",
                    description: "Boil the spaghetti until tender.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 200, unit: "g", name: spaghetti)],
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
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: basil).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Step 1 on the detail page does not list the basil. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-recipe", to: self)

        // Swap the two steps.
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailEdit)
        journey.tap(JourneyID.editorStepMoveUp(2))
        journey.assertFieldValue(JourneyID.editorStepTitle(1), equals: "Cook the spaghetti")
        journey.assertFieldValue(JourneyID.editorStepTitle(2), equals: "Tear the basil")
        journey.attachScreenshot(named: "05-steps-swapped-in-editor", to: self)
        journey.saveOpenRecipeEditor()
        let swapLog = XCTAttachment(string: journey.syncLog)
        swapLog.name = "sync-log-after-swap-save"
        swapLog.lifetime = .keepAlways
        add(swapLog)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: spaghetti).waitForExistence(timeout: JourneyApp.networkTimeout),
            "After the swap, step 1 on the recipe page does not list the spaghetti. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: basil).exists,
            "After the swap, step 2 on the recipe page does not list the basil. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "06-steps-swapped-on-recipe-page", to: self)

        // Add a recipe, opened while this recipe's editor holds an unsaved edit, leaves the editor alone.
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailEdit)
        let unsavedServings = "7"
        journey.replaceText(in: JourneyID.editorServings, with: unsavedServings)
        // The keyboard covers the tab bar, so it is closed before switching tabs.
        journey.pressReturn()
        XCTAssertTrue(
            journey.app.keyboards.firstMatch.waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Return did not close the keyboard. Screen: \(journey.screen)"
        )
        journey.openTab(JourneyCopy.kitchenTab)
        journey.tap(JourneyID.addRecipe)
        journey.assertAddRecipeSheet()
        journey.tap(JourneyID.addRecipeClose)
        // Each tab keeps its own stack, so the Recipes tab still shows that recipe's editor with the unsaved edit.
        journey.openTab(JourneyCopy.recipesTab)
        journey.assertFieldValue(JourneyID.editorServings, equals: unsavedServings)
        // Cancelling asks before dropping the edit, then returns to the recipe under its saved title.
        journey.tap(JourneyID.editorCancel)
        let discard = journey.copy(JourneyCopy.discardChanges)
        XCTAssertTrue(
            discard.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Cancelling an edited recipe did not ask to discard the changes. Screen: \(journey.screen)"
        )
        discard.tap()
        let detailTitle = journey.element(JourneyID.recipeDetailTitle)
        XCTAssertTrue(
            detailTitle.waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Discarding the edit did not return to the recipe. Screen: \(journey.screen)"
        )
        XCTAssertEqual(detailTitle.label, title, "The recipe whose editor was open lost its saved title.")
        journey.attachScreenshot(named: "10-existing-recipe-unaffected", to: self)

        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            // Everyone lists the public recipes the website's Recipes page lists, from the server.
            journey.chooseRecipesScope(JourneyCopy.everyoneScope)
            XCTAssertTrue(
                journey.element(JourneyID.recipesRow).waitForExistence(timeout: JourneyApp.networkTimeout),
                "Everyone's Recipes lists no recipes. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "11-everyone-recipes", to: self)
            journey.chooseRecipesScope(JourneyCopy.mineScope)
            journey.openRecipe(titled: title, from: JourneyID.recipesRow)
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: spaghetti).waitForExistence(timeout: JourneyApp.interactionTimeout),
                "The swapped steps did not survive a relaunch: step 1 lost its spaghetti. Screen: \(journey.screen)"
            )
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: basil).exists,
                "The swapped steps did not survive a relaunch: step 2 lost its basil. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "07-order-after-relaunch", to: self)
        }
    }

    /// Journey 4b: the recipe is renamed somewhere else while the cook has it open in the editor, and the cook
    /// saves a different title. The app never overwrites the other version unseen: the recipe page shows both
    /// titles, and the cook keeps their own. QA then holds the cook's title, which survives a relaunch.
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
        journey.assertFieldValue(JourneyID.editorTitle, equals: original)

        // Another device renames the recipe while this editor is open.
        try await qa.renameRecipe(recipeID, to: elsewhere)

        journey.replaceText(in: JourneyID.editorTitle, with: mine)
        journey.saveOpenRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeKeepMine).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not offer to keep the edit after the recipe was renamed elsewhere. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeField("title", version: "mine"), labelContaining: mine).exists,
            "The conflict banner does not show the cook's title. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeField("title", version: "theirs"), labelContaining: elsewhere).exists,
            "The conflict banner does not show the title saved elsewhere. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeUseTheirs).exists,
            "The conflict banner does not offer the version saved elsewhere. Screen: \(journey.screen)"
        )
        let heldTitle = try await qa.recipeTitle(recipeID)
        XCTAssertEqual(heldTitle, elsewhere, "The held edit overwrote the title saved elsewhere.")
        journey.attachScreenshot(named: "12-recipe-edit-conflict-banner", to: self)

        journey.tap(JourneyID.heldChangeKeepMine)
        XCTAssertTrue(
            journey.element(JourneyID.heldChangeTitle).waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "The conflict banner stayed after keeping the edit. Screen: \(journey.screen)"
        )
        let saved = try await qa.recipeTitle(recipeID, waitingFor: mine)
        XCTAssertEqual(saved, mine, "QA does not hold the cook's title after Keep My Edit.")
        journey.attachScreenshot(named: "13-recipe-edit-conflict-kept-mine", to: self)

        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: mine, from: JourneyID.recipesRow)
            XCTAssertFalse(
                journey.element(JourneyID.heldChangeTitle).exists,
                "The conflict banner came back after a relaunch. Screen: \(journey.screen)"
            )
        }
    }
}
