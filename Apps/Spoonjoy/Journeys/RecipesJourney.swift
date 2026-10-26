import SpoonjoyCore
import XCTest

/// Journey 2: a new account edits a two-step recipe made elsewhere, pasting and typing ingredients in the
/// native editor, and the recipe then shows up in My Recipes, the Kitchen, its detail page, a title search
/// and an ingredient search, and again after a relaunch.
@MainActor
final class RecipesJourney: JourneyTestCase {
    func testRecipesJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Lemon Pasta J2"
        let basil = "Journey\(token)basil"
        let spaghetti = "spaghetti"
        // Matches neither the title nor any ingredient, so its search has no results.
        let unmatchedQuery = "Journey\(token)nothing"
        // There is no in-app recipe form, so the recipe is made on QA, the way the connector or a share would.
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
        journey.tap(JourneyID.recipeDetailActions)
        journey.tap(JourneyID.recipeDetailEdit)
        journey.assertFieldValue(JourneyID.editorTitle, equals: title)

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

        // The step title, a single-line field, is the last one edited, so Return closes the keyboard before Save.
        // Saving returns to the recipe page.
        journey.replaceText(in: JourneyID.editorStepTitle(2), with: "Cook the spaghetti and rice")
        journey.saveRecipeEditor()
        XCTAssertTrue(
            journey.element(JourneyID.recipeDetailStep(2), descendantLabelContaining: "rice").waitForExistence(timeout: JourneyApp.networkTimeout),
            "The recipe page does not list the typed rice after saving. Screen: \(journey.screen)"
        )

        journey.openTab(JourneyCopy.kitchenTab)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRecipe, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The Kitchen does not show the new recipe."
        )
        journey.attachScreenshot(named: "03a-kitchen-with-recipe", to: self)
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
        journey.attachScreenshot(named: "05-search-results", to: self)
        // A query with no results clears the list, so the next result can only come from the ingredient search.
        journey.search(for: unmatchedQuery)
        XCTAssertTrue(
            journey.element(JourneyID.searchResult, labelContaining: title).waitForNonExistence(timeout: JourneyApp.networkTimeout),
            "A search that matches nothing still lists the recipe."
        )
        journey.attachScreenshot(named: "06-search-no-results", to: self)
        journey.search(for: basil)
        XCTAssertTrue(
            journey.element(JourneyID.searchResult, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Searching for an ingredient did not find the recipe."
        )

        // The relaunch also takes the largest accessibility text size, to capture the recipe page's ingredients at it.
        journey.useLargestAccessibilityTextOnNextLaunch()
        verifyAfterRelaunch(journey) {
            // At the largest text size the Kitchen's lead still names the recipe and keeps both actions reachable.
            journey.openTab(JourneyCopy.kitchenTab)
            XCTAssertTrue(
                journey.element(JourneyID.kitchenRecipe, labelContaining: title).waitForExistence(timeout: JourneyApp.networkTimeout),
                "The Kitchen lost its lead recipe at the largest text size. Screen: \(journey.screen)"
            )
            let cook = journey.element(JourneyID.kitchenRecipeCook)
            XCTAssertTrue(cook.waitForExistence(timeout: JourneyApp.interactionTimeout), "Start cooking is missing at the largest text size.")
            // The lead grows with the text, so its buttons can sit below the first screen.
            if !cook.isHittable {
                journey.app.swipeUp()
            }
            XCTAssertTrue(cook.isHittable, "Start cooking cannot be tapped at the largest text size. Screen: \(journey.screen)")
            XCTAssertTrue(journey.element(JourneyID.kitchenRecipeOpen).exists, "The Recipe button is missing at the largest text size.")
            journey.attachScreenshot(named: "06a-kitchen-accessibility-text-size", to: self)

            journey.openTab(JourneyCopy.recipesTab)
            // The shared recipe row stacks and wraps at this size instead of running off the screen.
            let row = journey.element(JourneyID.recipesRow, labelContaining: title)
            XCTAssertTrue(row.waitForExistence(timeout: JourneyApp.networkTimeout), "My Recipes lost the recipe at the largest text size.")
            let screenFrame = journey.app.windows.firstMatch.frame
            XCTAssertTrue(row.isHittable, "The recipe row cannot be tapped at the largest text size. Screen: \(journey.screen)")
            XCTAssertGreaterThanOrEqual(row.frame.minX, screenFrame.minX, "The recipe row starts off the screen at the largest text size.")
            XCTAssertLessThanOrEqual(row.frame.maxX, screenFrame.maxX, "The recipe row runs off the screen at the largest text size.")
            journey.attachScreenshot(named: "06b-recipe-row-accessibility-text-size", to: self)
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
            // Rice is step 2's last ingredient, so checking it keeps the list's order; the tap scrolls the list
            // into view for the capture.
            let rice = journey.element(JourneyID.recipeDetailIngredient, labelContainingIgnoringCase: "rice")
            rice.tap()
            XCTAssertEqual(rice.value as? String, "used", "Tapping the rice at the largest text size did not check it.")
            journey.attachScreenshot(named: "07-ingredients-accessibility-text-size", to: self)
        }
    }
}
