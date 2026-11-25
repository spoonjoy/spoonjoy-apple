import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Headless units journey, after web's `e2e/journeys/unit-conversion.journey.ts`: the cook picks metric under Serves on
/// the recipe page, imperial then metric in cook mode's More menu, and the recipe as written from the shopping list's
/// menu. One choice holds for all three and survives a relaunch, as web's `sj_units` cookie survives a reload.
@MainActor
@Suite("UnitsJourney", .serialized)
struct UnitsJourneyTests {
    static let recipe = "recipe_units"
    static let milk = "ing_units_milk"
    static let flour = "ing_units_flour"
    static let garlic = "ing_units_garlic"

    static let kitchen = SpoonjoyJourneyKitchen(recipes: [
        .init(recipe, "Journey Units Pancakes", steps: [
            .init("step_units_batter", title: "Make the batter", "Whisk the milk into the flour with the garlic.", ingredients: [
                .init(milk, "milk", 1, "cup"),
                .init(flour, "flour", 1, "lb"),
                .init(garlic, "garlic", 2, "clove"),
            ]),
        ]),
    ])

    private func cookAmount(_ screen: ReinsScreen, _ id: String) -> String? {
        screen.state["ingredients"]?.arrayValue?.first { $0["id"] == .string(id) }?["quantity"]?.stringValue
    }

    private func pageAmount(_ screen: ReinsScreen, _ id: String) -> String? {
        screen.state["ingredientRows"]?.arrayValue?.first { $0["id"] == .string(id) }?["amount"]?.stringValue
    }

    @Test func testPickedUnitsHoldAcrossTheRecipeCookModeTheListAndARelaunch() async throws {
        try await headless {
            var fixtures = SpoonjoyReinsFixtures()
            fixtures.recipePageProgress = RecipePageProgressStore(defaults: try #require(UserDefaults(suiteName: "reins-units-\(UUID().uuidString)")))
            let app = try await HeadlessApp.launch(Self.kitchen, fixtures: fixtures)

            // The recipe as written until the cook picks: Original first, then Metric, US and Imperial.
            try await app.journey.do("openRecipe", ["id": .string(Self.recipe)], until: { $0.focus == "recipe" })
            #expect(app.screen.state["units"]?["picked"] == "Original")
            #expect(app.screen.state["units"]?["choices"] == ["Original", "Metric", "US", "Imperial"])
            #expect(pageAmount(app.screen, Self.milk) == "1 cup")

            // Metric under Serves: volume and weight convert, counted cloves stay as written.
            try await app.journey.do("pickUnits", ["system": "metric"], until: { pageAmount($0, Self.milk) == "235 ml" })
            #expect(pageAmount(app.screen, Self.flour) == "455 g")
            #expect(pageAmount(app.screen, Self.garlic) == "2 cloves")
            #expect(app.screen.state["units"]?["picked"] == "Metric")

            // Cook mode opens in metric, with Units beside Scale in More.
            try await app.journey.do("startCooking", until: { $0.focus == "cook" })
            #expect(app.screen.state["more"] == ["Scale", "Units", "Add to list"])
            #expect(cookAmount(app.screen, Self.milk) == "235 ml", "cook mode keeps the recipe page's units")

            // Imperial, then metric again, from cook mode's More menu.
            try await app.journey.do("pickUnits", ["system": "imperial"], until: { cookAmount($0, Self.milk) == "8 ½ fl oz" })
            #expect(cookAmount(app.screen, Self.flour) == "1 lb", "a pound is already imperial, so it stays as written")
            try await app.journey.do("pickUnits", ["system": "metric"], until: { cookAmount($0, Self.milk) == "235 ml" })

            // Scale and units compose: twice the recipe in metric.
            try await app.journey.do("setScale", ["factor": 2], until: { cookAmount($0, Self.milk) == "475 ml" })
            try await app.journey.do("setScale", ["factor": 1], until: { cookAmount($0, Self.milk) == "235 ml" })

            // A relaunch keeps metric.
            try await app.relaunch()
            try await app.journey.do("selectTab", ["tab": "kitchen"], until: { $0.focus == "kitchen" })
            try await app.journey.do("openRecipe", ["id": .string(Self.recipe)], until: { $0.focus == "recipe" })
            #expect(pageAmount(app.screen, Self.milk) == "235 ml", "the recipe page kept metric after a relaunch")

            // The shopping list's menu shares the choice; picking Original there puts the recipe back as written.
            try await app.journey.do("selectTab", ["tab": "shopping"], until: { $0.focus == "shopping" })
            #expect(app.screen.state["units"]?["picked"] == "Metric", "the list opens in the units picked on the recipe")
            try await app.journey.do("pickUnits", ["system": "original"], until: { $0.state["units"]?["picked"] == "Original" })

            try await app.relaunch()
            try await app.journey.do("selectTab", ["tab": "kitchen"], until: { $0.focus == "kitchen" })
            try await app.journey.do("openRecipe", ["id": .string(Self.recipe)], until: { $0.focus == "recipe" })
            #expect(pageAmount(app.screen, Self.milk) == "1 cup", "the recipe is as written again after a relaunch")
            #expect(pageAmount(app.screen, Self.flour) == "1 lb")
        }
    }
}
