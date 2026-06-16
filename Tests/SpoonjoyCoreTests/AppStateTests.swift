import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("App state and screen view models")
struct AppStateTests {
    @Test("navigation state tracks route sidebar recipe and cook mode")
    func navigationStateTracksRouteSidebarRecipeAndCookMode() {
        var navigation = AppNavigationState()

        #expect(navigation.route == .kitchen)
        #expect(navigation.sidebarSelection == .kitchen)
        #expect(navigation.selectedRecipeID == nil)
        #expect(!navigation.isCookModeActive)

        navigation.navigate(to: .recipes)
        #expect(navigation.route == .recipes)
        #expect(navigation.sidebarSelection == .recipes)

        navigation.navigate(to: .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(navigation.selectedRecipeID == "recipe_lemon_pantry_pasta")
        #expect(navigation.sidebarSelection == .recipes)
        #expect(!navigation.isCookModeActive)

        navigation.navigate(to: .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook))
        #expect(navigation.selectedRecipeID == "recipe_lemon_pantry_pasta")
        #expect(navigation.isCookModeActive)

        navigation.navigate(to: .shoppingList)
        #expect(navigation.sidebarSelection == .shoppingList)
        #expect(navigation.selectedRecipeID == nil)
    }

    @Test("navigation applies deep links through the shared router")
    func navigationAppliesDeepLinksThroughSharedRouter() throws {
        var navigation = AppNavigationState()

        navigation.applyDeepLink(try url("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta#cook"))
        #expect(navigation.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook))
        #expect(navigation.isCookModeActive)

        navigation.applyDeepLink(try url("https://spoonjoy.app/unknown"))
        #expect(navigation.route == .unknownLink)
        #expect(navigation.sidebarSelection == .recipes)
    }

    @Test("search state trims queries and exposes a route")
    func searchStateTrimsQueriesAndExposesRoute() {
        var search = SearchState()

        #expect(search.query == "")
        #expect(search.scope == .all)
        #expect(!search.hasQuery)

        search.update(query: "  lemon pasta  ", scope: .recipes)
        #expect(search.query == "lemon pasta")
        #expect(search.scope == .recipes)
        #expect(search.hasQuery)
        #expect(search.route == .search(query: "lemon pasta", scope: .recipes))

        search.update(query: "   ", scope: .chefs)
        #expect(search.query == "")
        #expect(search.scope == .chefs)
        #expect(!search.hasQuery)
        #expect(search.route == .search(query: "", scope: .chefs))
    }

    @Test("screen view models delegate to existing domain state")
    func screenViewModelsDelegateToExistingDomainState() throws {
        let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let recipeViewModel = RecipeDetailViewModel(recipe: recipe)
        let progress = CookModeProgress(
            recipeID: recipe.id,
            stepIDs: recipe.steps.map(\.id),
            startedAt: "2026-06-16T09:45:00.000Z"
        )
        let cookViewModel = CookModeViewModel(recipe: recipe, progress: progress)
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let shoppingViewModel = ShoppingListViewModel(shoppingList: shoppingList)
        let draft = try CaptureDraft.localText(
            id: "draft-local",
            rawText: "https://example.com/recipe\nadd later",
            createdAt: "2026-06-16T09:46:00.000Z"
        )
        let captureViewModel = CaptureDraftViewModel(draft: draft)
        let settings = SettingsState(
            auth: .signedIn(username: "ari", scopes: ["shopping_list:read", "shopping_list:write"], tokenExpiresAt: nil),
            environment: .production(baseURL: try #require(URL(string: "https://spoonjoy.app"))),
            offline: .available(snapshotCount: 2, lastRestoredAt: "2026-06-16T09:47:00.000Z"),
            preferredCookModeTextSize: .large
        )
        let settingsViewModel = SettingsViewModel(settings: settings)

        #expect(recipeViewModel.id == recipe.id)
        #expect(recipeViewModel.title == recipe.title)
        #expect(recipeViewModel.startCookingRoute == .recipeDetail(id: recipe.id, presentation: .cook))
        #expect(recipeViewModel.methodSections.map(\.stepNumber) == Array(1...recipe.steps.count))
        #expect(cookViewModel.currentStepID == recipe.steps.first?.id)
        #expect(cookViewModel.completionFraction == 0)
        #expect(shoppingViewModel.sections.map(\.title) == shoppingList.receiptSections.map(\.title))
        #expect(shoppingViewModel.checkControlItemIDs == shoppingList.activeItems.map(\.id))
        #expect(captureViewModel.previewLines == draft.previewLines)
        #expect(captureViewModel.status == .localOnly)
        #expect(!captureViewModel.canCreateServerRecipe)
        #expect(settingsViewModel.rows == settings.statusRows)
        #expect(settingsViewModel.canReadShoppingList)
        #expect(settingsViewModel.canWriteShoppingList)
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }
}
