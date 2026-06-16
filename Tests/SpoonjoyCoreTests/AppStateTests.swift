import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("App state and screen view models")
struct AppStateTests {
    @Test("navigation state tracks route sidebar recipe and cook mode")
    func navigationStateTracksRouteSidebarRecipeAndCookMode() {
        var navigation = AppNavigationState()
        let unknownNavigation = AppNavigationState(route: .unknownLink)

        #expect(navigation.route == .kitchen)
        #expect(navigation.sidebarSelection == .kitchen)
        #expect(unknownNavigation.sidebarSelection == .kitchen)
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
        var search = SearchState(query: "  pantry  ", scope: .cookbooks)

        #expect(search.query == "pantry")
        #expect(search.scope == .cookbooks)
        #expect(search.hasQuery)

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

    @Test("search state hydrates from search routes")
    func searchStateHydratesFromSearchRoutes() {
        var search = SearchState(query: "old", scope: .all)
        let ignoredNonSearchRoute = search.apply(route: .recipes)

        #expect(ignoredNonSearchRoute == false)
        #expect(search.query == "old")
        #expect(search.scope == .all)

        let appliedSearchRoute = search.apply(route: .search(query: "  lemon  ", scope: .recipes))

        #expect(appliedSearchRoute)
        #expect(search.query == "lemon")
        #expect(search.scope == .recipes)
        #expect(search.route == .search(query: "lemon", scope: .recipes))
    }

    @Test("screen view models delegate to existing domain state")
    func screenViewModelsDelegateToExistingDomainState() throws {
        let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let recipeViewModel = RecipeDetailViewModel(recipe: recipe)
        let recipeViewModelID = recipeViewModel.id
        let recipeViewModelTitle = recipeViewModel.title
        let recipeViewModelRoute = recipeViewModel.startCookingRoute
        let recipeViewModelSections = recipeViewModel.methodSections
        let progress = CookModeProgress(
            recipeID: recipe.id,
            stepIDs: recipe.steps.map(\.id),
            startedAt: "2026-06-16T09:45:00.000Z"
        )
        let cookViewModel = CookModeViewModel(recipe: recipe, progress: progress)
        let cookCurrentStepID = cookViewModel.currentStepID
        let cookCompletionFraction = cookViewModel.completionFraction
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let shoppingViewModel = ShoppingListViewModel(shoppingList: shoppingList)
        let toggledShoppingViewModel = try shoppingViewModel.togglingItem(
            id: "item_lemons",
            checked: true,
            at: "2026-06-16T09:48:00.000Z"
        )
        let deletedOnlyShoppingList = ShoppingListState(
            id: "shopping-empty-active",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [
                ShoppingListItem(
                    id: "item_archived",
                    name: "archived basil",
                    quantity: nil,
                    unit: nil,
                    checked: false,
                    checkedAt: nil,
                    deletedAt: "2026-06-16T09:47:00.000Z",
                    categoryKey: nil,
                    iconKey: nil,
                    sortIndex: 42,
                    updatedAt: "2026-06-16T09:47:00.000Z"
                )
            ],
            nextCursor: "cursor-empty-active",
            updatedAt: "2026-06-16T09:47:00.000Z"
        )
        let restoredFromEmptyActiveList = try ShoppingListViewModel(
            shoppingList: deletedOnlyShoppingList
        ).togglingItem(
            id: "item_archived",
            checked: true,
            at: "2026-06-16T09:49:00.000Z"
        )
        let draft = try CaptureDraft.localText(
            id: "draft-local",
            rawText: "https://example.com/recipe\nadd later",
            createdAt: "2026-06-16T09:46:00.000Z"
        )
        let captureViewModel = CaptureDraftViewModel(draft: draft)
        let capturePreviewLines = captureViewModel.previewLines
        let captureStatus = captureViewModel.status
        let captureCanCreateServerRecipe = captureViewModel.canCreateServerRecipe
        let settings = SettingsState(
            auth: .signedIn(username: "ari", scopes: ["shopping_list:read", "shopping_list:write"], tokenExpiresAt: nil),
            environment: .production(baseURL: try #require(URL(string: "https://spoonjoy.app"))),
            offline: .available(snapshotCount: 2, lastRestoredAt: "2026-06-16T09:47:00.000Z"),
            preferredCookModeTextSize: .large
        )
        let settingsViewModel = SettingsViewModel(settings: settings)
        let settingsRows = settingsViewModel.rows
        let settingsCanReadShoppingList = settingsViewModel.canReadShoppingList
        let settingsCanWriteShoppingList = settingsViewModel.canWriteShoppingList

        #expect(recipeViewModelID == recipe.id)
        #expect(recipeViewModelTitle == recipe.title)
        #expect(recipeViewModelRoute == .recipeDetail(id: recipe.id, presentation: .cook))
        #expect(recipeViewModelSections.map(\.stepNumber) == Array(1...recipe.steps.count))
        #expect(cookCurrentStepID == recipe.steps.first?.id)
        #expect(cookCompletionFraction == 0)
        #expect(shoppingViewModel.sections.map(\.title) == shoppingList.receiptSections.map(\.title))
        #expect(shoppingViewModel.checkControlItemIDs == shoppingList.activeItems.map(\.id))
        #expect(toggledShoppingViewModel.shoppingList.item(id: "item_lemons")?.checked == true)
        #expect(restoredFromEmptyActiveList.shoppingList.item(id: "item_archived")?.sortIndex == 0)
        #expect(capturePreviewLines == draft.previewLines)
        #expect(captureStatus == .localOnly)
        #expect(!captureCanCreateServerRecipe)
        #expect(settingsRows == settings.statusRows)
        #expect(settingsCanReadShoppingList)
        #expect(settingsCanWriteShoppingList)
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }
}
