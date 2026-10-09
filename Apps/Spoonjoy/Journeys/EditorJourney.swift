import XCTest

/// Journey 4: a new account creates a two-step recipe with a photo in the native editor, the photo becomes the
/// recipe's cover, and the account then swaps the two steps in the editor. The new order holds on the recipe
/// page and after a relaunch. Paste and parse coverage stays in the Recipes journey.
@MainActor
final class EditorJourney: JourneyTestCase {
    func testEditorPhotoAndReorderJourney() throws {
        let account = try JourneyAccounts.account(3)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Basil Pasta J4"
        let basil = "Journey\(token)basil"
        let spaghetti = "spaghetti"
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // Account 3 has no recipes yet, so the kitchen leads with its hero, and the hero's button opens a blank editor.
        XCTAssertTrue(
            journey.element(JourneyID.kitchenEmptyHero).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A kitchen with no recipes does not show the empty-kitchen hero. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "00-empty-kitchen-hero", to: self)
        journey.tap(JourneyID.kitchenEmptyHeroCreate)
        journey.assertFieldEmpty(JourneyID.editorTitle)
        journey.goBack()

        // Account 3 has no recipes, so the Shopping List offers "Create a recipe", which opens the editor.
        journey.openTab(JourneyCopy.shoppingTab)
        journey.tap(JourneyID.shoppingCreateRecipe)
        journey.enterText(title, into: JourneyID.editorTitle)
        journey.enterText("2", into: JourneyID.editorServings)

        // Add a photo. The journey build stages a generated picture here instead of opening the system picker,
        // which automation cannot drive reliably; the thumbnail is the proof the editor holds the photo.
        journey.tap(JourneyID.editorPhotoPick)
        XCTAssertTrue(
            journey.element(JourneyID.editorPhotoThumbnail).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The editor does not show a thumbnail of the chosen photo. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.editorPhotoReady).exists,
            "The editor does not show the chosen photo as ready. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "00-photo-chosen", to: self)

        journey.tap(JourneyID.editorAddStep)
        journey.tap(JourneyID.editorStepAddIngredient(1))
        journey.enterText(basil, into: JourneyID.editorIngredientName(step: 1, ingredient: 1))
        journey.replaceText(in: JourneyID.editorIngredientQuantity(step: 1, ingredient: 1), with: "1")
        journey.enterText("cup", into: JourneyID.editorIngredientUnit(step: 1, ingredient: 1))
        journey.enterText("Tear the basil leaves into a bowl.", into: JourneyID.editorStepDescription(1))
        journey.enterText("Tear the basil", into: JourneyID.editorStepTitle(1))

        journey.tap(JourneyID.editorAddStep)
        journey.tap(JourneyID.editorStepAddIngredient(2))
        journey.enterText(spaghetti, into: JourneyID.editorIngredientName(step: 2, ingredient: 1))
        journey.replaceText(in: JourneyID.editorIngredientQuantity(step: 2, ingredient: 1), with: "200")
        journey.enterText("g", into: JourneyID.editorIngredientUnit(step: 2, ingredient: 1))
        journey.enterText("Boil the spaghetti until tender.", into: JourneyID.editorStepDescription(2))
        journey.enterText("Cook the spaghetti", into: JourneyID.editorStepTitle(2))

        // Saving a new recipe returns to My Recipes.
        journey.saveRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.recipesRow, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "My Recipes does not list the new recipe after saving it. Screen: \(journey.screen)"
        )
        journey.openRecipe(titled: title, from: JourneyID.recipesRow)
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: basil).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Step 1 on the detail page does not list the basil. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: spaghetti).exists,
            "Step 2 on the detail page does not list the spaghetti. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailCover).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The detail page shows no cover image, so the photo chosen on create did not become the cover. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-saved-recipe", to: self)

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

        // New Recipe, opened while this recipe's editor is open, starts from a blank draft and leaves the recipe
        // alone: the editor that is still open keeps its unsaved edit, and the recipe keeps its saved title.
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
        journey.tap(JourneyID.newRecipe)
        journey.assertFieldEmpty(JourneyID.editorTitle)
        journey.assertFieldEmpty(JourneyID.editorServings)
        journey.attachScreenshot(named: "09-new-recipe-while-editing-is-blank", to: self)
        journey.openTab(JourneyCopy.recipesTab)
        journey.assertFieldValue(JourneyID.editorServings, equals: unsavedServings)
        journey.attachScreenshot(named: "10-open-editor-kept-its-edit", to: self)
        journey.goBack()
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailTitle).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Leaving the editor did not return to the recipe. Screen: \(journey.screen)"
        )

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
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailCover).exists,
                "The cover photo is gone after the steps were swapped and the app relaunched. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "07-order-after-relaunch", to: self)
            // The cover comes from the on-disk image cache after a relaunch, so it needs no network wait.
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailCover).waitForExistence(timeout: JourneyApp.interactionTimeout),
                "The cover is missing after a relaunch. Screen: \(journey.screen)"
            )
            journey.attachScreenshot(named: "08-cover-after-relaunch", to: self)
        }
    }
}
