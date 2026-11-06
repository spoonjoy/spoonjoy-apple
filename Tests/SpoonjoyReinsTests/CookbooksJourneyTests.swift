import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// CookbooksJourney, headless: the shelf lists a cookbook of six recipes, its page shows the title, the first recipe
/// and the search field, the search narrows and says when nothing matches, a link to a missing recipe lands on the
/// not-found page whose Back to recipes opens My Recipes, and the recipes are still there after a relaunch.
@MainActor
@Suite("CookbooksJourney", .serialized)
struct CookbooksJourney {
    static let names = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]
    static let titles = names.map { "Journey \($0) J5" }

    static var kitchen: SpoonjoyJourneyKitchen {
        let recipes = names.enumerated().map { index, name in
            SpoonjoyJourneyKitchen.RecipeSpec("recipe_j5_\(name.lowercased())", titles[index], steps: [
                .init("step_j5_\(name.lowercased())", title: "Step \(index + 1)", "Cook it.", ingredients: [.init("ing_j5_\(index + 1)", "journeyflour\(index + 1)", 1, "cup")]),
            ])
        }
        return SpoonjoyJourneyKitchen(recipes: recipes, cookbooks: [.init("cookbook_j5_shelf", "Journey Shelf J5", recipeIDs: recipes.map(\.id))])
    }

    @Test("testCookbooksJourney")
    func testCookbooksJourney() async throws {
        try await headless {
            let app = try await HeadlessApp.launch(Self.kitchen)

            // The cookbook shelf lists the new cookbook; its row opens the cookbook page.
            try await app.journey.do("selectTab", ["tab": "cookbooks"], until: { screen in
                screen.focus == "cookbooks" && screen.state["rows"]?.arrayValue?.contains { $0["title"] == "Journey Shelf J5" } == true
            })
            try await app.journey.do("openCookbook", ["id": "cookbook_j5_shelf"], until: { $0.focus == "cookbook" })

            // The page shows the title, the first recipe and the search field, which appears for more than one recipe.
            let page = app.screen
            #expect(page.state["title"] == "Journey Shelf J5")
            #expect(page.state["recipes"]?[0]?["title"] == .string(Self.titles[0]))
            #expect(page.state["recipes"]?.arrayValue?.count == 6)
            #expect(page.state["searchField"] == true)
            #expect(page.actionNames.contains("search"))

            // Searching narrows the contents to the matching recipe, which keeps its place in the cookbook.
            try await app.journey.do("search", ["query": "Charlie"], until: { screen in
                screen.state["recipes"]?.arrayValue?.map { $0["title"] } == [.string(Self.titles[2])]
            })
            #expect(app.screen.state["recipes"]?[0]?["ordinal"] == 3)
            #expect(app.screen.state["noMatch"] == nil)

            // A search with no match says so.
            try await app.journey.do("search", ["query": "Journeynothing"], until: { screen in
                screen.state["noMatch"]?["title"] == "No recipes match \u{201C}Journeynothing\u{201D}"
            })
            #expect(app.screen.state["recipes"]?.arrayValue?.isEmpty == true)
            #expect(app.screen.state["noMatch"]?["help"] == .string(SearchSurfaceEmptyState.noMatchHelp))

            // A link to a recipe that does not exist shows the not-found page with a way back.
            app.shell.openLink(try #require(URL(string: "spoonjoy://recipes/journey-missing-j5")))
            try await app.journey.expect("notFound", describing: "the not-found page says the recipe could not be found") { screen in
                screen.state["message"] == "We couldn't find this recipe." && screen.actionNames.contains("backToRecipes")
            }

            // Back to recipes opens My Recipes, which lists the seeded recipes.
            try await app.journey.do("backToRecipes", until: { $0.context["tabs"]?["selected"] == "recipes" })
            #expect(app.shell.navigation.route == .recipes)
            #expect(app.shell.content.recipeCatalog.rows.contains { $0.title == Self.titles[0] })

            // After a relaunch the Recipes tab still lists the seeded recipes.
            try await app.relaunch()
            try await app.journey.do("selectTab", ["tab": "recipes"], until: { $0.context["tabs"]?["selected"] == "recipes" })
            #expect(app.shell.content.recipeCatalog.rows.contains { $0.title == Self.titles[0] })
        }
    }
}
