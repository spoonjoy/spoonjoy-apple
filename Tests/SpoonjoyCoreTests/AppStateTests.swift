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

    @Test("native app snapshot persists first run cook shopping capture and queued mutations")
    func nativeAppSnapshotPersistsFirstRunCookShoppingCaptureAndQueuedMutations() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("native-state.json")
            let store = NativeAppStateStore(fileURL: fileURL)
            let shoppingList = try ShoppingListState.decodeFromBundle()
            let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipes.first)
            let progress = try CookModeProgress(
                recipeID: recipe.id,
                stepIDs: recipe.steps.map(\.id),
                startedAt: "2026-06-16T13:30:00.000Z"
            )
            .markingStepCompleted(
                try #require(recipe.steps.first?.id),
                updatedAt: "2026-06-16T13:31:00.000Z"
            )
            let draft = try CaptureDraft.localText(
                id: "draft-local-pasta",
                rawText: "https://example.com/pasta\nsave this",
                createdAt: "2026-06-16T13:32:00.000Z"
            )
            let queuedMutation = QueuedMutation(
                id: "queued-check-lemons",
                clientMutationID: "mutation-check-lemons",
                createdAt: "2026-06-16T13:33:00.000Z",
                kind: .shoppingCheck(itemID: "item_lemons", checked: true)
            )
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: shoppingList,
                savedAt: "2026-06-16T13:29:00.000Z"
            )
            let missingRecord = try store.loadOrCreate(fallback: fallback)

            let changedShoppingList = try shoppingList.settingChecked(
                true,
                itemID: "item_lemons",
                checkedAt: "2026-06-16T13:33:00.000Z",
                nextSortIndex: 99
            )
            let saved = try missingRecord.value
                .completingFirstRun(savedAt: "2026-06-16T13:30:00.000Z")
                .updatingCookProgress(progress, savedAt: "2026-06-16T13:31:00.000Z")
                .updatingCaptureDraft(draft, savedAt: "2026-06-16T13:32:00.000Z")
                .updatingShoppingList(
                    changedShoppingList,
                    queuedMutation: queuedMutation,
                    savedAt: "2026-06-16T13:33:00.000Z"
                )

            try store.save(saved)
            let reloaded = try store.loadOrCreate(fallback: fallback).value

            #expect(missingRecord.source == .fallback)
            #expect(reloaded.hasCompletedFirstRun)
            #expect(reloaded.cookProgress(for: recipe.id) == progress)
            #expect(reloaded.shoppingList?.item(id: "item_lemons")?.checked == true)
            #expect(reloaded.captureDraft == draft)
            #expect(reloaded.pendingMutationCount == 1)
            #expect(reloaded.pendingMutations.mutations.first == queuedMutation)
            #expect(reloaded.offlineState.statusLabel == "Offline cache ready: 1 snapshot")
            #expect(reloaded.lastOpenedRoute == nil)

            let routeRecorded = reloaded.recordingOpenedRoute(
                .search(query: "codex-smoke-route", scope: .recipes),
                savedAt: "2026-06-16T13:34:00.000Z"
            )
            #expect(routeRecorded.lastOpenedRoute == "search:recipes:codex-smoke-route")
            #expect(routeRecorded.savedAt == "2026-06-16T13:34:00.000Z")
        }
    }

    @Test("native app snapshot covers unavailable offline no-op queue and schema errors")
    func nativeAppSnapshotCoversUnavailableOfflineNoOpQueueAndSchemaErrors() throws {
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let empty = NativeAppSnapshot.bootstrap(
            shoppingList: nil,
            savedAt: "2026-06-16T13:41:00.000Z"
        )
        let withoutMutation = try empty.updatingShoppingList(
            shoppingList,
            queuedMutation: nil,
            savedAt: "2026-06-16T13:42:00.000Z"
        )
        let invalid = NativeAppSnapshot(
            schemaVersion: 2,
            hasCompletedFirstRun: false,
            cookProgressByRecipeID: [:],
            shoppingList: nil,
            captureDraft: nil,
            pendingMutations: MutationQueue(),
            lastOpenedRoute: nil,
            savedAt: "2026-06-16T13:43:00.000Z"
        )

        #expect(empty.offlineState == .unavailable)
        #expect(withoutMutation.shoppingList == shoppingList)
        #expect(withoutMutation.pendingMutationCount == 0)
        #expect(withoutMutation.cookProgress(for: "missing-recipe") == nil)
        #expect(throws: NativeAppSnapshotError.self) {
            try invalid.validated()
        }
        #expect(throws: NativeAppSnapshotError.self) {
            try NativeAppStateStore(
                fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("unused-native-state.json")
            ).save(invalid)
        }
    }

    @Test("native app state location is shared by app and native intents")
    func nativeAppStateLocationIsSharedByAppAndNativeIntents() {
        let fileURL = NativeAppStateLocation.defaultFileURL()
        let fallbackURL = NativeAppStateLocation.defaultFileURL(
            applicationSupportURLs: [],
            temporaryDirectory: URL(fileURLWithPath: "/tmp/spoonjoy-native-state-fallback", isDirectory: true)
        )

        #expect(NativeAppStateLocation.appDirectoryName == "Spoonjoy")
        #expect(NativeAppStateLocation.fileName == "native-app-state.json")
        #expect(fileURL.lastPathComponent == NativeAppStateLocation.fileName)
        #expect(fileURL.deletingLastPathComponent().lastPathComponent == NativeAppStateLocation.appDirectoryName)
        #expect(fallbackURL.path == "/tmp/spoonjoy-native-state-fallback/Spoonjoy/native-app-state.json")
    }

    @Test("route identifiers and native URLs cover every app route")
    func routeIdentifiersAndNativeURLsCoverEveryAppRoute() throws {
        let cases: [(AppRoute, String, String)] = [
            (.kitchen, "kitchen", "spoonjoy://kitchen"),
            (.recipes, "recipes", "spoonjoy://recipes"),
            (.recipeDetail(id: "recipe_lemon", presentation: .detail), "recipe:recipe_lemon", "spoonjoy://recipes/recipe_lemon"),
            (.recipeDetail(id: "recipe_lemon", presentation: .cook), "recipe-cook:recipe_lemon", "spoonjoy://recipes/recipe_lemon/cook"),
            (.cookbooks, "cookbooks", "spoonjoy://cookbooks"),
            (.cookbookDetail(id: "cookbook_weeknights"), "cookbook:cookbook_weeknights", "spoonjoy://cookbooks/cookbook_weeknights"),
            (.shoppingList, "shopping-list", "spoonjoy://shopping-list"),
            (.search(query: "lemon pasta", scope: .shoppingList), "search:shopping-list:lemon pasta", "spoonjoy://search?q=lemon%20pasta&scope=shopping-list"),
            (.capture, "capture", "spoonjoy://capture"),
            (.settings, "settings", "spoonjoy://settings"),
            (.unknownLink, "unknown-link", "spoonjoy://unknown")
        ]

        for (route, identifier, rawURL) in cases {
            #expect(route.stateIdentifier == identifier)
            #expect(DeepLinkURLBuilder.url(for: route) == URL(string: rawURL), "\(route)")
        }
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-app-state-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
