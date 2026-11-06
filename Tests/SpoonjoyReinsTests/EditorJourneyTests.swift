import Foundation
import OuroReins
import SpoonjoyCore
@testable import SpoonjoyReins
import Testing

/// Journey 4 headless (Apps/Spoonjoy/Journeys/EditorJourney.swift): every create entry opens Add a recipe, whose pasted
/// link becomes a capture draft that survives a relaunch; a recipe's steps are swapped in the editor and the order holds;
/// and a recipe renamed elsewhere while it is open in the editor is held on its page, where the cook keeps their title.
///
/// The live journeys make their recipes on QA; here the kitchen folder holds them. The add-recipe and reorder journeys
/// run cache-only, as the device does offline; Everyone's list and the conflict journey are served by `SpoonjoyFakeAPI`
/// through the production clients, so the 409, the held change and Keep My Edit run the real queue end to end.
@MainActor
@Suite("EditorJourney", .serialized)
struct EditorJourney {
    // MARK: Add a recipe from a pasted link

    @Test("Journey 4: every create entry opens Add a recipe, and a pasted link becomes a capture draft that survives a relaunch")
    func testAddRecipeFromPastedLinkJourney() async throws {
        try await headless {
            let link = "https://qa.spoonjoy.app/recipes/journey-pasted"
            let app = try await HeadlessApp.launch(SpoonjoyJourneyKitchen())
            let journey = app.journey

            // A kitchen with no recipes leads with its hero, whose button opens Add a recipe.
            try await journey.expect("kitchen", describing: "the empty kitchen shows its hero") { $0.state["emptyHero"] != .null && $0.state["emptyHero"] != nil }
            try await journey.do("addRecipe", until: { $0.focus == "addRecipe" && $0.path.contains("sheet") })
            try await journey.do("close", until: { $0.focus == "kitchen" })

            // The Shopping List's Add a recipe opens the same sheet.
            try await journey.do("selectTab", ["tab": "shopping"], until: { $0.focus == "shopping" && $0.actionNames.contains("addRecipe") })
            try await journey.do("addRecipe", until: { $0.focus == "addRecipe" })
            try await journey.do("close", until: { $0.focus == "shopping" })

            // The Kitchen toolbar's Add a recipe: a pasted link becomes a capture draft in Imports.
            try await journey.do("selectTab", ["tab": "kitchen"], until: { $0.focus == "kitchen" })
            try await journey.do("addRecipe", until: { $0.focus == "addRecipe" && $0.state["title"] == "Add a recipe" })
            try await journey.do("typeLink", ["link": .string(link)], until: { $0.actionNames.contains("importLink") })
            try await journey.do("importLink", until: { $0.focus == "capture" && $0.state.draftShows(link) })

            try await app.relaunch()
            try await app.journey.expect("kitchen")
            try await app.journey.do("openImports", until: { $0.focus == "capture" && $0.state.draftShows(link) })
        }
    }

    // MARK: Reorder

    static let pasta = "recipe_j4_basil_pasta"
    static let title = "Journey Basil Pasta J4"
    static let basil = "Journeybasil"
    static let spaghetti = "spaghetti"

    static var reorderKitchen: SpoonjoyJourneyKitchen {
        SpoonjoyJourneyKitchen(recipes: [
            .init(pasta, title, servings: nil, steps: [
                .init("step_j4_basil", title: "Tear the basil", "Tear the basil leaves into a bowl.", ingredients: [.init("ing_j4_basil", basil, 1, "cup")]),
                .init("step_j4_spaghetti", title: "Cook the spaghetti", "Boil the spaghetti until tender.", ingredients: [.init("ing_j4_spaghetti", spaghetti, 200, "g")]),
            ]),
        ])
    }

    @Test("Journey 4: the steps swap in the editor and on the page, an unsaved edit survives Add a recipe, and the order holds after a relaunch")
    func testEditorReorderJourney() async throws {
        try await headless {
            let api = SpoonjoyFakeAPI(recipes: try Self.reorderKitchen.recipeValues())
            let app = try await HeadlessApp.launch(Self.reorderKitchen, fixtures: .cacheOnly(searchingWith: api))
            let journey = app.journey

            try await journey.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" })
            try await journey.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state.stepIngredients(1).contains(Self.basil) })

            // Swap the two steps.
            try await journey.do("edit", until: { $0.focus == "editor" })
            try await journey.do("moveStepUp", ["step": 2], until: { screen in
                screen.state["steps"]?[0]?["title"] == "Cook the spaghetti" && screen.state["steps"]?[1]?["title"] == "Tear the basil"
            })
            let swapped = try await journey.do("save", until: { $0.focus == "recipe" && $0.state.stepIngredients(1).contains(Self.spaghetti) })
            #expect(swapped.state.stepIngredients(2).contains(Self.basil), "after the swap, step 2 lists the basil")

            // Add a recipe, opened while the editor holds an unsaved edit, leaves the editor alone.
            try await journey.do("edit", until: { $0.focus == "editor" })
            try await journey.do("setServings", ["text": "7"], until: { $0.state["servings"] == "7" })
            try await journey.do("selectTab", ["tab": "kitchen"], until: { $0.focus == "kitchen" })
            try await journey.do("addRecipe", until: { $0.focus == "addRecipe" })
            try await journey.do("close", until: { $0.focus == "kitchen" })
            // Each tab keeps its own stack, so the Recipes tab still shows the editor with the unsaved edit.
            try await journey.do("selectTab", ["tab": "recipes"], until: { $0.focus == "editor" && $0.state["servings"] == "7" })
            // Cancelling asks before dropping the edit, then returns to the recipe under its saved title.
            try await journey.do("cancel", until: { $0.state["confirm"]?["title"] == "Discard your changes?" && $0.actionNames.contains("discard") })
            let back = try await journey.do("discard", until: { $0.focus == "recipe" })
            #expect(back.state["title"] == .string(Self.title), "the recipe whose editor was open kept its saved title")
            #expect(back.state["servings"] == .null, "the discarded servings were not saved")

            try await app.relaunch()
            let after = app.journey
            try await after.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" })
            // Everyone lists the public recipes, from the server.
            try await after.do("chooseScope", ["scope": "everyone"], until: { $0.state["scope"] == "everyone" && !($0.state["rows"]?.arrayValue ?? []).isEmpty })
            #expect(await api.requests("GET", "/api/v1/recipes").count >= 1)
            try await after.do("chooseScope", ["scope": "mine"], until: { $0.state["scope"] == "mine" })
            let reopened = try await after.do("openRecipe", ["id": .string(Self.pasta)], until: { $0.focus == "recipe" && $0.state.stepIngredients(1).contains(Self.spaghetti) })
            #expect(reopened.state.stepIngredients(2).contains(Self.basil), "the swapped order survived a relaunch")
        }
    }

    // MARK: Edit conflict

    static let soup = "recipe_j4b_soup"
    static let original = "Journey Soup J4b Original"
    static let elsewhere = "Journey Soup J4b Elsewhere"
    static let mine = "Journey Soup J4b Mine"

    static var conflictKitchen: SpoonjoyJourneyKitchen {
        SpoonjoyJourneyKitchen(recipes: [
            .init(soup, original, servings: nil, steps: [
                .init("step_j4b_simmer", title: "Simmer", "Simmer the stock.", ingredients: [.init("ing_j4b_stock", "stock", 1, "l")]),
            ]),
        ])
    }

    @Test("Journey 4b: a recipe renamed elsewhere while it is open is held on its page with both titles, and Keep My Edit saves mine")
    func testRecipeEditConflictJourney() async throws {
        try await headless {
            let api = SpoonjoyFakeAPI(recipes: try Self.conflictKitchen.recipeValues())
            let app = try await HeadlessApp.launch(Self.conflictKitchen, fixtures: .online(api))
            let journey = app.journey

            try await journey.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" })
            try await journey.do("openRecipe", ["id": .string(Self.soup)], until: { $0.focus == "recipe" })
            try await journey.do("edit", until: { $0.focus == "editor" && $0.state["title"] == .string(Self.original) && $0.state["connectivity"] == "online" })

            // Another device renames the recipe while this editor is open.
            await api.rename(Self.soup, to: Self.elsewhere)

            try await journey.do("setTitle", ["text": .string(Self.mine)])
            let held = try await journey.do("save", until: { $0.focus == "recipe" && $0.state["heldChange"]?["fields"] != nil && $0.state["heldChange"] != .null })
            let title = held.state["heldChange"]?["fields"]?.arrayValue?.first { $0["field"] == "title" }
            #expect(title?["mine"] == .string(Self.mine), "the banner shows the cook's title")
            #expect(title?["theirs"] == .string(Self.elsewhere), "the banner shows the title saved elsewhere")
            #expect(held.state["heldChange"]?["choices"] == ["Keep My Edit", "Use Saved Version"], "the banner offers both versions")
            #expect(held.actionNames.contains("resolveHeldChange"))
            // The held edit did not overwrite the server's title (the live journey's QA check, against the fake server).
            #expect(await api.version(of: Self.soup)?.title == Self.elsewhere)

            try await journey.do("resolveHeldChange", ["choice": "mine"], until: { $0.focus == "recipe" && $0.state["heldChange"] == .null })
            #expect(await api.version(of: Self.soup)?.title == Self.mine, "the server holds the cook's title after Keep My Edit")
            #expect(await api.unexpected.isEmpty)

            try await app.relaunch()
            let after = app.journey
            try await after.do("selectTab", ["tab": "recipes"], until: { $0.focus == "recipes" })
            let reopened = try await after.do("openRecipe", ["id": .string(Self.soup)], until: { $0.focus == "recipe" })
            #expect(reopened.state["heldChange"] == .null, "the banner did not come back after a relaunch")
        }
    }
}

fileprivate extension ReinsValue {
    func draftShows(_ link: String) -> Bool {
        (self["draft"]?["previewLines"]?.arrayValue ?? []).contains { $0.stringValue?.contains(link) == true }
    }

    func stepIngredients(_ step: Int) -> [String] {
        (self["steps"]?[step - 1]?["ingredients"]?.arrayValue ?? []).compactMap(\.stringValue)
    }
}
