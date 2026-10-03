import XCTest

/// Journey 2: a new account creates a two-step recipe with ingredients in the native editor, and the
/// recipe then shows up in My Recipes, the Kitchen, its detail page, a title search and an ingredient
/// search, and again after a relaunch.
@MainActor
final class RecipesJourney: JourneyTestCase {
    func testRecipesJourney() throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Lemon Pasta J2"
        let basil = "Journey\(token)basil"
        let spaghetti = "spaghetti"
        // Matches neither the title nor any ingredient, so its search has no results.
        let unmatchedQuery = "Journey\(token)nothing"
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // Account 1 has no recipes, so the Shopping List offers "Create a recipe", which opens the editor.
        journey.openTab(JourneyCopy.shoppingTab)
        journey.tap(JourneyID.shoppingCreateRecipe)
        journey.enterText(title, into: JourneyID.editorTitle)
        journey.enterText("2", into: JourneyID.editorServings)

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
        // Paste two ingredient lines into step 2: the preview parses them, the rows are added to the step.
        journey.tap(JourneyID.editorStepPasteIngredients(2))
        journey.enterText("2 large eggs\n1 tbsp soy sauce", into: JourneyID.editorPasteText)
        journey.assertFieldValue(JourneyID.editorPasteRowName(1), equals: "eggs")
        journey.assertFieldValue(JourneyID.editorPasteRowQuantity(1), equals: "2")
        journey.assertFieldValue(JourneyID.editorPasteRowUnit(1), equals: "large")
        journey.assertFieldValue(JourneyID.editorPasteRowName(2), equals: "soy sauce")
        journey.assertFieldValue(JourneyID.editorPasteRowQuantity(2), equals: "1")
        journey.assertFieldValue(JourneyID.editorPasteRowUnit(2), equals: "tbsp")
        journey.attachScreenshot(named: "01-paste-preview", to: self)
        journey.tap(JourneyID.editorPasteAdd)
        journey.assertFieldValue(JourneyID.editorIngredientName(step: 2, ingredient: 2), equals: "eggs")
        journey.assertFieldValue(JourneyID.editorIngredientQuantity(step: 2, ingredient: 2), equals: "2")
        journey.assertFieldValue(JourneyID.editorIngredientUnit(step: 2, ingredient: 2), equals: "large")
        journey.assertFieldValue(JourneyID.editorIngredientName(step: 2, ingredient: 3), equals: "soy sauce")
        journey.attachScreenshot(named: "02-pasted-rows", to: self)

        // A single typed line fills the quantity and unit when Return is pressed.
        journey.tap(JourneyID.editorStepAddIngredient(2))
        journey.enterText("2 cups rice", into: JourneyID.editorIngredientName(step: 2, ingredient: 4))
        journey.pressReturn()
        journey.assertFieldValue(JourneyID.editorIngredientName(step: 2, ingredient: 4), equals: "rice")
        journey.assertFieldValue(JourneyID.editorIngredientQuantity(step: 2, ingredient: 4), equals: "2")
        journey.assertFieldValue(JourneyID.editorIngredientUnit(step: 2, ingredient: 4), equals: "cup")
        journey.attachScreenshot(named: "03-typed-line-parsed", to: self)
        journey.enterText("Boil the spaghetti until tender.", into: JourneyID.editorStepDescription(2))
        journey.enterText("Cook the spaghetti", into: JourneyID.editorStepTitle(2))

        // The step title, a single-line field, is the last one edited, so Return closes the keyboard before
        // Save. Saving a new recipe returns to My Recipes.
        journey.saveRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.recipesRow, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "My Recipes does not list the new recipe after saving it. Screen: \(journey.screen)"
        )

        journey.openTab(JourneyCopy.kitchenTab)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRecipe, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen does not show the new recipe."
        )
        // The account's only recipe is the Kitchen's lead recipe.
        journey.tap(JourneyID.kitchenRecipeOpen)
        let detailTitle = journey.element(JourneyID.recipeDetailTitle)
        XCTAssertTrue(detailTitle.waitForExistence(timeout: JourneyApp.networkTimeout), "The recipe detail page did not open from the Kitchen.")
        XCTAssertEqual(detailTitle.label, title, "The detail page shows another recipe's title.")
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: basil).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Step 1 on the detail page does not list the basil. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: spaghetti).exists,
            "Step 2 on the detail page does not list the spaghetti. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: "eggs").exists,
            "Step 2 on the detail page does not list the eggs. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: "soy sauce").exists,
            "Step 2 on the detail page does not list the soy sauce. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: "rice").exists,
            "Step 2 on the detail page does not list the rice. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-saved-recipe", to: self)

        journey.openSearch()
        journey.search(for: title)
        XCTAssertTrue(
            journey.element(JourneyID.searchResult, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Searching for the title did not find the recipe."
        )
        // A query with no results clears the list, so the next result can only come from the ingredient search.
        journey.search(for: unmatchedQuery)
        XCTAssertTrue(
            journey.element(JourneyID.searchResult, labelContaining: title).waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "A search that matches nothing still lists the recipe."
        )
        journey.search(for: basil)
        XCTAssertTrue(
            journey.element(JourneyID.searchResult, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Searching for an ingredient did not find the recipe."
        )

        verifyAfterRelaunch(journey) {
            journey.openTab(JourneyCopy.recipesTab)
            journey.openRecipe(titled: title, from: JourneyID.recipesRow)
            XCTAssertEqual(journey.element(JourneyID.recipeDetailTitle).label, title, "My Recipes opened another recipe after a relaunch.")
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStep(1), descendantLabelContaining: basil).waitForExistence(timeout: JourneyApp.interactionTimeout),
                "Step 1 lost its basil after a relaunch. Screen: \(journey.screen)"
            )
            XCTAssertTrue(
                journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: spaghetti).exists,
                "Step 2 lost its spaghetti after a relaunch. Screen: \(journey.screen)"
            )
        }
    }
}
