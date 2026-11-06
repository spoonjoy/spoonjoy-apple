import SpoonjoyCore
import XCTest

/// The recipe lists at the largest accessibility text size: the Kitchen's lead keeps both actions reachable and
/// My Recipes' index row wraps inside the screen. Editing, search and scaling are proved headless in
/// SpoonjoyReinsTests.
@MainActor
final class RecipesJourney: JourneyTestCase {
    func testRecipesJourney() async throws {
        let account = try JourneyAccounts.account(1)
        let token = try JourneyAccounts.runToken()
        let title = "Journey \(token) Lemon Pasta J2"
        let qa = try await JourneyQAClient.signIn(account)
        // An older second recipe, so My Recipes has an index row under the lead. Its long title must wrap at the
        // largest text size.
        let indexTitle = "Journey \(token) Slow-Braised Short Ribs with Gremolata J2"
        _ = try await qa.createRecipe(
            title: indexTitle,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Braise the ribs",
                    description: "Braise the ribs until tender.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: []
                )
            ]
        )
        _ = try await qa.createRecipe(
            title: title,
            servings: "4",
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
        let journey = JourneyApp.launchFresh()

        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        journey.useLargestAccessibilityTextOnNextLaunch()
        verifyAfterRelaunch(journey) {
            // UI: at the largest text size the Kitchen's lead still names the recipe and keeps both actions reachable.
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

            // UI: on My Recipes the shared index row stacks and wraps at this size instead of running off the screen.
            // The lead fills the first screen, so the index row sits further down.
            journey.openTab(JourneyCopy.recipesTab)
            let row = journey.element(JourneyID.recipesRow, labelContaining: indexTitle)
            XCTAssertTrue(row.waitForExistence(timeout: JourneyApp.networkTimeout), "My Recipes has no index row for the older recipe at the largest text size.")
            journey.swipeUpUntilHittable(row)
            let screenFrame = journey.app.windows.firstMatch.frame
            XCTAssertTrue(row.isHittable, "The index row cannot be tapped at the largest text size. Screen: \(journey.screen)")
            XCTAssertGreaterThanOrEqual(row.frame.minX, screenFrame.minX, "The recipe row starts off the screen at the largest text size.")
            XCTAssertLessThanOrEqual(row.frame.maxX, screenFrame.maxX, "The recipe row runs off the screen at the largest text size.")
            journey.attachScreenshot(named: "06b-recipe-row-accessibility-text-size", to: self)
        }
    }
}
