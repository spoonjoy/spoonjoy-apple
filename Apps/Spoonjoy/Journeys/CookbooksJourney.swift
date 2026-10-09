import SpoonjoyCore
import XCTest

/// Journey 5: a cookbook with several recipes opens from the Cookbooks tab; its page scrolls under the solid
/// top edge, its "Search this cookbook" field narrows the contents, and a link to a recipe that does not exist
/// lands on the not-found page, whose "Back to recipes" button opens My Recipes.
@MainActor
final class CookbooksJourney: JourneyTestCase {
    func testCookbooksJourney() async throws {
        let account = try JourneyAccounts.account(4)
        let token = try JourneyAccounts.runToken()
        let cookbookTitle = "Journey \(token) Shelf J5"
        let titles = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"].map { "Journey \(token) \($0) J5" }

        let qa = try await JourneyQAClient.signIn(account)
        let cookbookID = try await qa.createCookbook(title: cookbookTitle)
        try await addRecipe(titles[0], number: 1, to: cookbookID, using: qa)
        try await addRecipe(titles[1], number: 2, to: cookbookID, using: qa)
        try await addRecipe(titles[2], number: 3, to: cookbookID, using: qa)
        try await addRecipe(titles[3], number: 4, to: cookbookID, using: qa)
        try await addRecipe(titles[4], number: 5, to: cookbookID, using: qa)
        try await addRecipe(titles[5], number: 6, to: cookbookID, using: qa)

        let journey = JourneyApp.launchFresh()
        journey.signIn(as: account.username, password: account.password)
        XCTAssertTrue(
            journey.element(JourneyID.kitchenRoot).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Signing in did not open the kitchen."
        )

        // The cookbook shelf lists the new cookbook; its row opens the cookbook page.
        journey.openTab(JourneyCopy.cookbooksTab)
        let shelfRow = journey.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", cookbookTitle)).firstMatch
        XCTAssertTrue(shelfRow.waitForExistence(timeout: JourneyApp.networkTimeout), "The Cookbooks shelf does not list the new cookbook. Screen: \(journey.screen)")
        journey.attachScreenshot(named: "01-cookbook-shelf", to: self)
        shelfRow.tap()

        // The page shows the title, the first recipe and the search field, which appears for more than one recipe.
        let title = journey.app.staticTexts.matching(NSPredicate(format: "label == %@", cookbookTitle)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: JourneyApp.networkTimeout), "The cookbook page does not show its title. Screen: \(journey.screen)")
        XCTAssertTrue(
            cookbookRow(journey, titles[0]).waitForExistence(timeout: JourneyApp.networkTimeout),
            "The cookbook page does not list its first recipe. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "02-cookbook-top", to: self)

        // Scrolling moves the title under the solid top edge while the contents and search field stay reachable.
        journey.app.swipeUp()
        journey.attachScreenshot(named: "03-cookbook-scrolled", to: self)
        XCTAssertTrue(journey.element(JourneyID.cookbookSearchField).exists, "The scrolled cookbook page lost its search field. Screen: \(journey.screen)")

        // Searching narrows the contents to the matching recipe.
        journey.enterText("Charlie", into: JourneyID.cookbookSearchField)
        XCTAssertTrue(
            cookbookRow(journey, titles[2]).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "Searching the cookbook for Charlie hides Charlie. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            cookbookRow(journey, titles[0]).waitForNonExistence(timeout: JourneyApp.interactionTimeout),
            "Searching the cookbook for Charlie still lists Alpha. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "04-cookbook-search-match", to: self)

        // A search with no match says so.
        journey.replaceText(in: JourneyID.cookbookSearchField, with: "Journey\(token)nothing")
        XCTAssertTrue(
            journey.element(JourneyID.cookbookSearchEmpty).waitForExistence(timeout: JourneyApp.interactionTimeout),
            "A cookbook search that matches nothing does not say so. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "05-cookbook-search-empty", to: self)

        // A link to a recipe that does not exist shows the not-found page with a way back.
        journey.openLink(URL(string: "spoonjoy://recipes/journey-missing-\(token.lowercased())")!)
        XCTAssertTrue(
            journey.element(JourneyID.routeError).waitForExistence(timeout: JourneyApp.networkTimeout),
            "A link to a missing recipe did not show the not-found page. Screen: \(journey.screen)"
        )
        XCTAssertTrue(
            journey.copy(JourneyCopy.recipeNotFound).exists,
            "The not-found page does not say the recipe could not be found. Screen: \(journey.screen)"
        )
        XCTAssertTrue(journey.element(JourneyID.routeErrorBack).exists, "The not-found page has no Back to recipes button.")
        journey.attachScreenshot(named: "06-not-found", to: self)

        journey.tap(JourneyID.routeErrorBack)
        XCTAssertTrue(
            journey.element(JourneyID.recipesRow, labelContaining: titles[0]).waitForExistence(timeout: JourneyApp.networkTimeout),
            "Back to recipes did not open My Recipes. Screen: \(journey.screen)"
        )
        journey.attachScreenshot(named: "07-back-to-recipes", to: self)

        // The link left the app signed in, and My Recipes still lists the seeded recipes after a relaunch.
        verifyAfterRelaunch(journey) {
            XCTAssertTrue(
                journey.element(JourneyID.recipesRow, labelContaining: titles[0]).waitForExistence(timeout: JourneyApp.networkTimeout),
                "My Recipes does not list the seeded recipe after a relaunch. Screen: \(journey.screen)"
            )
        }
    }

    private func addRecipe(_ title: String, number: Int, to cookbookID: String, using qa: JourneyQAClient) async throws {
        let recipeID = try await qa.createRecipe(
            title: title,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Step \(number)",
                    description: "Cook it.",
                    duration: nil,
                    ingredients: [RecipeIngredientDraft(quantity: 1, unit: "cup", name: "journeyflour\(number)")],
                    outputStepNums: []
                )
            ]
        )
        try await qa.addRecipe(recipeID, toCookbook: cookbookID)
    }

    private func cookbookRow(_ journey: JourneyApp, _ recipeTitle: String) -> XCUIElement {
        journey.app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ". \(recipeTitle)")).firstMatch
    }
}
