import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Journey 2 headless (Apps/Spoonjoy/Journeys/RecipesJourney.swift): an account edits a two-step recipe made
/// elsewhere, pasting and typing ingredients in the editor, and the recipe then shows in My Recipes, the Kitchen, its
/// page (scaled to six servings), a title search and an ingredient search, and again after a relaunch.
///
/// The live journey makes the recipe on QA; here the kitchen folder holds it, as a sync would have left it. The store is
/// cache-only, so the save queues and shows on the page at once; search runs against `SpoonjoyFakeAPI` over the
/// production search client. The largest-text-size checks stay live (P).
@MainActor
@Suite("RecipesJourney", .serialized)
struct RecipesJourney {
    static let pasta = "recipe_j2_lemon_pasta"
    static let ribs = "recipe_j2_short_ribs"
    static let title = "Journey Lemon Pasta J2"
    static let indexTitle = "Journey Slow-Braised Short Ribs with Gremolata J2"
    static let basil = "Journeybasil"
    static let spaghetti = "spaghetti"
    static let unmatchedQuery = "Journeynothing"

    static var kitchen: SpoonjoyJourneyKitchen {
        SpoonjoyJourneyKitchen(recipes: [
            .init(ribs, indexTitle, servings: nil, steps: [.init("step_j2_ribs_1", title: "Braise the ribs", "Braise the ribs until tender.")]),
            .init(pasta, title, servings: "4", steps: [
                .init("step_j2_basil", title: "Tear the basil", "Tear the basil leaves into a bowl.", ingredients: [.init("ing_j2_basil", basil, 1, "cup")]),
                .init("step_j2_spaghetti", title: "Cook the spaghetti", "Boil the spaghetti until tender.", ingredients: [.init("ing_j2_spaghetti", spaghetti, 200, "g")]),
            ]),
        ])
    }

    @Test("Journey 2: paste, type and save in the editor; the recipe is found everywhere, scaled, and after a relaunch")
    func testRecipesJourney() async throws {
        try await headless {
            let api = SpoonjoyFakeAPI(recipes: try Self.kitchen.recipeValues())
            var fixtures = SpoonjoyReinsFixtures.cacheOnly(searchingWith: api)
            fixtures.recipePageProgress = RecipePageProgressStore(defaults: try #require(UserDefaults(suiteName: "reins-j2-\(UUID().uuidString)")))
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)
            let journey = app.journey

            try await journey.expect("kitchen")
            try await journey.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" && $0.state.rowTitles.contains(Self.title) })
            try await journey.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state["canEdit"] == true })
            try await journey.do("edit", until: { $0.focus == "editor" && $0.state["title"] == .string(Self.title) })

            // Paste two ingredient lines into step 2: the preview parses them, and Add puts the rows on the step.
            try await journey.do("pasteIngredients", ["step": 2], until: { $0.focus == "paste" })
            try await journey.do("setPasteText", ["text": "2 large eggs\n1 tbsp soy sauce"], until: { screen in
                screen.state["rows"]?[0] == ["name": "eggs", "quantity": "2", "unit": "large"]
                    && screen.state["rows"]?[1] == ["name": "soy sauce", "quantity": "1", "unit": "tbsp"]
            })
            try await journey.do("addPasted", until: { screen in
                screen.focus == "editor"
                    && screen.state.ingredient(step: 2, 2) == ["name": "eggs", "quantity": "2", "unit": "large"]
                    && screen.state.ingredient(step: 2, 3)?["name"] == "soy sauce"
            })

            // A single typed line fills the quantity and unit when Return is pressed.
            try await journey.do("addIngredient", ["step": 2], until: { $0.state.ingredient(step: 2, 4)?["name"] == "" })
            try await journey.do("typeIngredient", ["step": 2, "ingredient": 4, "text": "2 cups rice\n"], until: {
                $0.state.ingredient(step: 2, 4) == ["name": "rice", "quantity": "2", "unit": "cup"]
            })

            // The step title is the last field edited; Save returns to the recipe page, which lists the rice.
            try await journey.do("setStepTitle", ["step": 2, "text": "Cook the spaghetti and rice"])
            try await journey.do("save", until: { $0.focus == "recipe" && $0.state.stepIngredients(2).contains("rice") })

            // The Kitchen shows the recipe and opens it, with every ingredient on its step.
            try await journey.do("selectTab", ["tab": "kitchen"], until: { $0.focus == "kitchen" && $0.state.recipeTitles.contains(Self.title) })
            let recipe = try await journey.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state["title"] == .string(Self.title) })
            #expect(recipe.state.stepIngredients(1).contains(Self.basil), "step 1 lists the basil")
            for name in [Self.spaghetti, "eggs", "soy sauce", "rice"] {
                #expect(recipe.state.stepIngredients(2).contains(name), "step 2 lists the \(name)")
            }

            // "Serves 4" is the page's one scale control: two more servings scale every amount.
            #expect(recipe.state["serves"] == "Serves 4")
            #expect(recipe.state.amount(of: Self.basil) == "1 cup", "the basil starts at 1 cup")
            try await journey.do("incrementServes", until: { $0.state["serves"] == "Serves 5" })
            let scaled = try await journey.do("incrementServes", until: { $0.state["serves"] == "Serves 6" })
            #expect(scaled.state.amount(of: Self.basil) == "1 ½ cup", "six servings instead of four scale the basil to 1 ½ cups")

            // Search finds the recipe by title; a query that matches nothing clears the list; an ingredient finds it.
            try await journey.do("selectTab", ["tab": "search"], until: { $0.focus == "search" })
            try await journey.do("search", ["query": .string(Self.title)], until: { $0.state.results.contains(Self.title) })
            try await journey.do("search", ["query": .string(Self.unmatchedQuery)], until: { $0.state["query"] == .string(Self.unmatchedQuery) && $0.state.results.isEmpty })
            try await journey.do("search", ["query": .string(Self.basil)], until: { $0.state.results.contains(Self.title) })
            #expect(await api.requests("GET", "/api/v1/search").map { $0.query["q"] } == [Self.title, Self.unmatchedQuery, Self.basil])

            try await app.relaunch()
            let after = app.journey

            // The Kitchen still leads with a recipe and keeps both of its actions.
            let kitchen = try await after.expect("kitchen", describing: "the kitchen lists the recipe") { $0.state.recipeTitles.contains(Self.title) }
            #expect(kitchen.state["lead"]?["title"]?.stringValue != nil, "the Kitchen has a lead recipe")
            #expect(kitchen.actionNames.contains("startCooking") && kitchen.actionNames.contains("openRecipe"))

            try await after.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" && $0.state.rowTitles.contains(Self.title) })
            let reopened = try await after.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state["title"] == .string(Self.title) })
            #expect(reopened.state.stepIngredients(1).contains(Self.basil), "step 1 kept its basil after a relaunch")
            #expect(reopened.state.stepIngredients(2).contains(Self.spaghetti), "step 2 kept its spaghetti after a relaunch")
            // The page's scale is saved per recipe, so it comes back at six servings.
            #expect(reopened.state["serves"] == "Serves 6", "the recipe remembers it serves 6")
            #expect(reopened.state.amount(of: Self.basil) == "1 ½ cup", "the basil keeps its scaled amount")
            // Rice is step 2's last ingredient, so checking it keeps the list's order.
            let rice = try #require(reopened.state.ingredientRow(named: "rice")?["id"])
            try await after.do("toggleIngredient", ["id": rice], until: { $0.state.ingredientRow(named: "rice")?["value"] == "used" })

            // Back on My Recipes, the older recipe has its index row.
            try await after.do("goBack", until: { $0.focus == "recipes" && $0.state.rowTitles.contains(Self.indexTitle) })
            #expect(await api.unexpected.isEmpty)
        }
    }
}

fileprivate extension ReinsValue {
    var rowTitles: [String] { (self["rows"]?.arrayValue ?? []).compactMap { $0["title"]?.stringValue } }
    var recipeTitles: [String] { (self["recipes"]?.arrayValue ?? []).compactMap { $0["title"]?.stringValue } }
    var results: [String] { (self["results"]?.arrayValue ?? []).compactMap(\.stringValue) }

    /// The editor's ingredient, both numbered from 1 as the screen numbers them.
    func ingredient(step: Int, _ number: Int) -> ReinsValue? {
        guard let ingredients = self["steps"]?[step - 1]?["ingredients"]?.arrayValue, ingredients.indices.contains(number - 1) else { return nil }
        return ingredients[number - 1]
    }

    /// The recipe page's ingredient names on a step, numbered from 1.
    func stepIngredients(_ step: Int) -> [String] {
        (self["steps"]?[step - 1]?["ingredients"]?.arrayValue ?? []).compactMap(\.stringValue)
    }

    func ingredientRow(named name: String) -> ReinsValue? {
        self["ingredientRows"]?.arrayValue?.first { $0["name"]?.stringValue == name }
    }

    func amount(of name: String) -> String? {
        ingredientRow(named: name)?["amount"]?.stringValue
    }
}
