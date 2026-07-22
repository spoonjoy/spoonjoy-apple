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

        navigation.navigate(to: .savedRecipes)
        #expect(navigation.route == .savedRecipes)
        #expect(navigation.sidebarSelection == .savedRecipes)

        navigation.navigate(to: .chefs)
        #expect(navigation.route == .chefs)
        #expect(navigation.sidebarSelection == .chefs)

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

    @Test("compact navigation preserves an independent native path for every tab")
    func compactNavigationPreservesIndependentTabPaths() {
        var navigation = AppNavigationState()
        let recipe = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)
        let cookbook = AppRoute.cookbookDetail(id: "cookbook_weeknights")

        navigation.pushCompact(recipe)
        #expect(navigation.compactTabSelection == .kitchen)
        #expect(navigation.compactPath(for: .kitchen) == [recipe])
        #expect(navigation.route == recipe)

        navigation.selectCompactTab(.cookbooks)
        navigation.pushCompact(cookbook)
        #expect(navigation.compactTabSelection == .cookbooks)
        #expect(navigation.compactPath(for: .cookbooks) == [cookbook])
        #expect(navigation.compactPath(for: .kitchen) == [recipe])

        navigation.selectCompactTab(.kitchen)
        #expect(navigation.route == recipe)
        navigation.setCompactPath([], for: .kitchen)
        #expect(navigation.route == .kitchen)
        #expect(navigation.compactPath(for: .cookbooks) == [cookbook])
    }

    @Test("deep links seed the appropriate compact tab without erasing another tab history")
    func deepLinksSeedAppropriateCompactTab() throws {
        var navigation = AppNavigationState()
        let kitchenRecipe = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)

        navigation.pushCompact(kitchenRecipe)
        navigation.applyDeepLink(try url("https://spoonjoy.app/cookbooks/cookbook_weeknights"))

        #expect(navigation.compactTabSelection == .cookbooks)
        #expect(navigation.compactPath(for: .cookbooks) == [.cookbookDetail(id: "cookbook_weeknights")])
        #expect(navigation.compactPath(for: .kitchen) == [kitchenRecipe])
    }

    @Test("desktop navigation binds native pushes and pops to the selected sidebar root")
    func desktopNavigationBindsNativePathToSidebarRoot() {
        var navigation = AppNavigationState()
        let detail = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)

        navigation.pushDesktop(detail)
        #expect(navigation.desktopRootRoute == .kitchen)
        #expect(navigation.desktopPath == [detail])
        #expect(navigation.route == detail)

        navigation.setDesktopPath([])
        #expect(navigation.route == .kitchen)

        navigation.selectSidebar(.cookbooks)
        #expect(navigation.desktopRootRoute == .cookbooks)
        #expect(navigation.desktopPath.isEmpty)
        #expect(navigation.route == .cookbooks)
    }

    @Test("desktop navigation covers root selection duplicate pushes and top replacement")
    func desktopNavigationCoversRootSelectionDuplicatePushesAndTopReplacement() {
        var navigation = AppNavigationState()
        let detail = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)
        let editor = AppRoute.recipeEditor(id: "recipe_lemon_pantry_pasta")

        navigation.pushDesktop(.recipes)
        #expect(navigation.sidebarSelection == .recipes)
        #expect(navigation.desktopPath.isEmpty)

        navigation.pushDesktop(detail)
        navigation.pushDesktop(detail)
        #expect(navigation.desktopPath == [detail])

        navigation.replaceDesktopTop(with: editor)
        #expect(navigation.desktopPath == [editor])
        #expect(navigation.route == editor)

        navigation.selectSidebar(.kitchen)
        navigation.replaceDesktopTop(with: detail)
        #expect(navigation.desktopPath == [detail])
        #expect(navigation.route == detail)
    }

    @Test("compact navigation covers every root invalid sections duplicate pushes and replacement")
    func compactNavigationCoversRootsInvalidSectionsDuplicatePushesAndReplacement() {
        var navigation = AppNavigationState()
        let roots: [(AppRoute, AppSection)] = [
            (.kitchen, .kitchen),
            (.recipes, .recipes),
            (.savedRecipes, .savedRecipes),
            (.cookbooks, .cookbooks),
            (.shoppingList, .shoppingList)
        ]

        for (route, section) in roots {
            navigation.pushCompact(route)
            #expect(navigation.compactTabSelection == section)
            #expect(navigation.route == route)
        }

        navigation.selectCompactTab(.settings)
        #expect(navigation.compactTabSelection == .shoppingList)
        navigation.setCompactPath([.settings], for: .settings)
        #expect(navigation.compactPath(for: .settings).isEmpty)

        navigation.setCompactPath([.recipeDetail(id: "recipe_other", presentation: .detail)], for: .recipes)
        #expect(navigation.route == .shoppingList)

        navigation.selectCompactTab(.recipes)
        let detail = AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)
        let editor = AppRoute.recipeEditor(id: "recipe_lemon_pantry_pasta")
        navigation.pushCompact(detail)
        navigation.pushCompact(detail)
        #expect(navigation.compactPath(for: .recipes).suffix(1) == [detail])

        navigation.replaceCompactTop(with: editor)
        #expect(navigation.compactPath(for: .recipes).last == editor)
        navigation.setCompactPath([], for: .recipes)
        navigation.replaceCompactTop(with: detail)
        #expect(navigation.compactPath(for: .recipes) == [detail])
    }

    @Test("every desktop sidebar section maps to its native root route")
    func everyDesktopSidebarSectionMapsToItsNativeRootRoute() {
        let expected: [(AppSection, AppRoute)] = [
            (.kitchen, .kitchen),
            (.recipes, .recipes),
            (.savedRecipes, .savedRecipes),
            (.cookbooks, .cookbooks),
            (.shoppingList, .shoppingList),
            (.chefs, .chefs),
            (.search, .search(query: "", scope: .all)),
            (.capture, .capture),
            (.settings, .settings)
        ]

        for (section, route) in expected {
            var navigation = AppNavigationState()
            navigation.selectSidebar(section)
            #expect(navigation.desktopRootRoute == route)
            #expect(navigation.route == route)
        }
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

    @Test("personal recipe catalogs derive from the current chef and owned cookbooks")
    func personalRecipeCatalogsDeriveFromCurrentChefAndOwnedCookbooks() throws {
        let currentChef = ChefSummary(id: "chef_ari", username: "ari")
        let otherChef = ChefSummary(id: "chef_jules", username: "jules")
        let ownRecipe = Self.recipe(id: "recipe_own", title: "My Weeknight Beans", chef: currentChef, updatedAt: "2026-07-01T10:00:00.000Z")
        let otherRecipe = Self.recipe(id: "recipe_other", title: "Jules Salad", chef: otherChef, updatedAt: "2026-07-02T10:00:00.000Z")
        let savedShared = Self.recipe(id: "recipe_saved_shared", title: "Saved Rice", chef: otherChef, updatedAt: "2026-07-03T10:00:00.000Z")
        let savedUnique = Self.recipe(id: "recipe_saved_unique", title: "Saved Lentils", chef: currentChef, updatedAt: "2026-07-04T10:00:00.000Z")
        let foreignSaved = Self.recipe(id: "recipe_foreign_saved", title: "Foreign Saved Toast", chef: otherChef, updatedAt: "2026-07-05T10:00:00.000Z")
        let content = NativeShellContentState.empty(
            authSessionState: .authenticated(try Self.authSession(accountID: currentChef.id)),
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        .copy(
            recipes: [otherRecipe, ownRecipe, savedShared, savedUnique, foreignSaved],
            cookbooks: [
                Self.cookbook(id: "cookbook_owned_one", title: "Ari Shelf One", chef: currentChef, recipes: [RecipeSummary(recipe: savedShared), RecipeSummary(recipe: savedUnique)]),
                Self.cookbook(id: "cookbook_foreign", title: "Jules Shelf", chef: otherChef, recipes: [RecipeSummary(recipe: foreignSaved)]),
                Self.cookbook(id: "cookbook_owned_two", title: "Ari Shelf Two", chef: currentChef, recipes: [RecipeSummary(recipe: savedShared)])
            ]
        )

        #expect(content.currentChefID == currentChef.id)
        #expect(content.myRecipesCatalog.rows.map(\.id) == ["recipe_own", "recipe_saved_unique"])
        #expect(content.savedRecipesCatalog.rows.map(\.id) == ["recipe_saved_shared", "recipe_saved_unique"])
        #expect(content.savedRecipesCatalog.rows.map(\.id).contains("recipe_foreign_saved") == false)
    }

    @Test("personal recipe catalogs are empty when the current chef is unavailable")
    func personalRecipeCatalogsAreEmptyWhenCurrentChefIsUnavailable() throws {
        let currentChef = ChefSummary(id: "chef_ari", username: "ari")
        let content = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        .copy(
            recipes: [Self.recipe(id: "recipe_own", title: "Should Not Leak", chef: currentChef, updatedAt: "2026-07-01T10:00:00.000Z")],
            cookbooks: [
                Self.cookbook(
                    id: "cookbook_owned",
                    title: "Should Not Leak Shelf",
                    chef: currentChef,
                    recipes: [RecipeSummary(recipe: Self.recipe(id: "recipe_saved", title: "Should Not Leak Saved", chef: currentChef, updatedAt: "2026-07-02T10:00:00.000Z"))]
                )
            ]
        )

        #expect(content.currentChefID == nil)
        #expect(content.myRecipesCatalog.rows.isEmpty)
        #expect(content.savedRecipesCatalog.rows.isEmpty)
    }

    @Test("screen view models delegate to existing domain state")
    func screenViewModelsDelegateToExistingDomainState() throws {
        let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let recipeViewModel = RecipeDetailViewModel(recipe: recipe)
        let recipeViewModelID = recipeViewModel.id
        let recipeViewModelTitle = recipeViewModel.title
        let recipeViewModelRoute = recipeViewModel.startCookingRoute
        let recipeViewModelSections = recipeViewModel.stepSections
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
        #expect(captureCanCreateServerRecipe)
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
                updatedAt: "2026-06-16T13:33:00.000Z",
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

    @Test("native shell derives profile surfaces from cached public chef content")
    func nativeShellDerivesProfileSurfacesFromCachedPublicChefContent() async throws {
        let recipe = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        let cookbook = try #require(CookbookFixtureCatalog.decodeFromBundle().cookbooks.first)
        let visitorSpoon = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_visitor",
            chefID: "chef_jules",
            recipeID: recipe.id,
            cookedAt: "2026-06-24T18:30:00.000Z",
            photoURL: URL(string: "https://spoonjoy.app/photos/spoons/profile-shell.jpg"),
            note: "Visitor spoon for native profile parity.",
            nextTime: "Add more parsley.",
            deletedAt: nil,
            createdAt: "2026-06-24T18:30:00.000Z",
            updatedAt: "2026-06-24T18:31:00.000Z",
            chef: ChefSummary(id: "chef_jules", username: "jules")
        )
        let visitorSpoonRepeat = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_visitor_repeat",
            chefID: "chef_jules",
            recipeID: recipe.id,
            cookedAt: "2026-06-24T18:45:00.000Z",
            photoURL: nil,
            note: "Second visitor spoon for graph aggregation.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T18:45:00.000Z",
            updatedAt: "2026-06-24T18:46:00.000Z",
            chef: ChefSummary(id: "chef_jules", username: "jules")
        )
        let visitorSpoonTie = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_visitor_tie",
            chefID: "chef_mira",
            recipeID: recipe.id,
            cookedAt: "2026-06-24T18:45:00.000Z",
            photoURL: nil,
            note: "Second visitor chef at the same latest time.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T18:45:00.000Z",
            updatedAt: "2026-06-24T18:46:00.000Z",
            chef: ChefSummary(id: "chef_mira", username: "mira")
        )
        let visitorSpoonOlder = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_visitor_older",
            chefID: "chef_ada",
            recipeID: recipe.id,
            cookedAt: "2026-06-24T18:15:00.000Z",
            photoURL: nil,
            note: "Older visitor spoon for graph ordering.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T18:15:00.000Z",
            updatedAt: "2026-06-24T18:16:00.000Z",
            chef: ChefSummary(id: "chef_ada", username: "ada")
        )
        let ownSpoon = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_own",
            chefID: recipe.chef.id,
            recipeID: "recipe_jules_profile_shell",
            cookedAt: "2026-06-24T19:30:00.000Z",
            photoURL: URL(string: "https://spoonjoy.app/photos/spoons/profile-shell-own.jpg"),
            note: "Profile chef cooked another chef's recipe.",
            nextTime: "More lemon.",
            deletedAt: nil,
            createdAt: "2026-06-24T19:30:00.000Z",
            updatedAt: "2026-06-24T19:31:00.000Z",
            chef: recipe.chef
        )
        let ownSpoonRepeat = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_own_repeat",
            chefID: recipe.chef.id,
            recipeID: "recipe_jules_profile_shell",
            cookedAt: "2026-06-24T19:45:00.000Z",
            photoURL: nil,
            note: "Profile chef cooked the same fellow chef again.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T19:45:00.000Z",
            updatedAt: "2026-06-24T19:46:00.000Z",
            chef: recipe.chef
        )
        let ownRecipeSpoon = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_own_recipe",
            chefID: recipe.chef.id,
            recipeID: recipe.id,
            cookedAt: "2026-06-24T20:30:00.000Z",
            photoURL: nil,
            note: "Profile chef cooked their own recipe.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T20:30:00.000Z",
            updatedAt: "2026-06-24T20:31:00.000Z",
            chef: recipe.chef
        )
        let ownFallbackDateSpoon = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_created_at_fallback",
            chefID: recipe.chef.id,
            recipeID: recipe.id,
            cookedAt: nil,
            photoURL: nil,
            note: "Profile chef fallback-created spoon.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-24T21:30:00.000Z",
            updatedAt: "2026-06-24T21:31:00.000Z",
            chef: recipe.chef
        )
        let cappedRecentSpoons = (0..<8).map { index in
            let idSuffix: String
            let cookedAt: String
            if index == 6 {
                idSuffix = "tie_y"
                cookedAt = "2026-06-24T22:07:00.000Z"
            } else if index == 7 {
                idSuffix = "tie_z"
                cookedAt = "2026-06-24T22:07:00.000Z"
            } else {
                idSuffix = "\(index)"
                cookedAt = "2026-06-24T22:0\(index):00.000Z"
            }
            return RecipeDetailRecentSpoon(
                id: "spoon_profile_shell_recent_\(idSuffix)",
                chefID: recipe.chef.id,
                recipeID: recipe.id,
                cookedAt: cookedAt,
                photoURL: nil,
                note: "Recent capped spoon \(idSuffix).",
                nextTime: nil,
                deletedAt: nil,
                createdAt: cookedAt,
                updatedAt: cookedAt,
                chef: recipe.chef
            )
        }
        let deletedOwnSpoon = RecipeDetailRecentSpoon(
            id: "spoon_profile_shell_deleted",
            chefID: recipe.chef.id,
            recipeID: recipe.id,
            cookedAt: "2026-06-24T23:00:00.000Z",
            photoURL: nil,
            note: "Deleted spoon should not appear in cached profile activity.",
            nextTime: nil,
            deletedAt: "2026-06-24T23:01:00.000Z",
            createdAt: "2026-06-24T23:00:00.000Z",
            updatedAt: "2026-06-24T23:01:00.000Z",
            chef: recipe.chef
        )
        let recipeWithVisitorSpoon = Recipe(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: recipe.href,
            canonicalURL: recipe.canonicalURL,
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            steps: recipe.steps,
            cookbooks: recipe.cookbooks,
            recentSpoons: [visitorSpoon, visitorSpoonRepeat, visitorSpoonTie, visitorSpoonOlder, ownRecipeSpoon, ownFallbackDateSpoon, deletedOwnSpoon] + cappedRecentSpoons
        )
        let julesRecipe = Recipe(
            id: "recipe_jules_profile_shell",
            title: "Jules's Lemon Toast",
            description: "A cached public recipe from another chef.",
            servings: recipe.servings,
            chef: ChefSummary(id: "chef_jules", username: "jules"),
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/recipe_jules_profile_shell",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_jules_profile_shell")),
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: "2026-06-24T19:32:00.000Z",
            steps: recipe.steps,
            cookbooks: [],
            recentSpoons: [ownSpoon, ownSpoonRepeat]
        )
        let session = try AuthSession(
            clientID: "client_profile_shell",
            accessToken: "sj_access_profile_shell",
            refreshToken: "sj_refresh_profile_shell",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_780_020_600),
            scope: NativeAuthSession.defaultScope,
            accountID: recipe.chef.id
        )
        let cacheSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: recipe.chef.id,
            environment: .production,
            createdAt: Date(timeIntervalSince1970: 1_780_020_600),
            records: [],
            dismissedIndicators: []
        )
        let syncSnapshot = NativeSyncSnapshot(
            accountID: recipe.chef.id,
            environment: .production,
            checkpoint: nil,
            queue: NativeMutationQueue(),
            cachedRecords: [
                NativeSyncCachedRecord(kind: .recipe, resourceID: recipeWithVisitorSpoon.id, payload: try Self.jsonValue(recipeWithVisitorSpoon), serverRevision: .updatedAt(recipeWithVisitorSpoon.updatedAt)),
                NativeSyncCachedRecord(kind: .recipe, resourceID: julesRecipe.id, payload: try Self.jsonValue(julesRecipe), serverRevision: .updatedAt(julesRecipe.updatedAt)),
                NativeSyncCachedRecord(kind: .cookbook, resourceID: cookbook.id, payload: try Self.jsonValue(cookbook), serverRevision: .updatedAt(cookbook.updatedAt))
            ],
            tombstones: []
        )
        let content = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: nil,
            authSessionState: .authenticated(session),
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        let profile = try #require(content.profileSurfaceViewModel)
        let repository = try #require(content.profileGraphRepository)
        let cachedProfile = try await repository.profile(identifier: recipe.chef.username)
        let fellowChefs = try await repository.graph(identifier: recipe.chef.id, direction: ProfileGraphDirection.fellowChefs, page: 1, limit: 50)
        let kitchenVisitors = try await repository.graph(identifier: recipe.chef.id, direction: ProfileGraphDirection.kitchenVisitors, page: 1, limit: 50)
        let signedOutOffline = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        let signedOutProfile = try #require(signedOutOffline.profileSurfaceViewModel)
        let emptyContent = content.copy(recipes: [], cookbooks: [])
        let profileWithoutInteractions = Recipe(
            id: "recipe_profile_shell_quiet",
            title: "Quiet Lemon Porridge",
            description: "A cached public recipe with no spoon graph edges.",
            servings: recipe.servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/recipe_profile_shell_quiet",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_profile_shell_quiet")),
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: "2026-06-24T21:32:00.000Z",
            steps: recipe.steps,
            cookbooks: [],
            recentSpoons: []
        )
        let quietContent = content.copy(recipes: [profileWithoutInteractions], cookbooks: [])
        let quietRepository = try #require(quietContent.profileGraphRepository)
        let emptyFellowChefs = try await quietRepository.graph(identifier: recipe.chef.id, direction: .fellowChefs, page: 1, limit: 50)
        let emptyKitchenVisitors = try await quietRepository.graph(identifier: recipe.chef.id, direction: .kitchenVisitors, page: 1, limit: 50)
        let profileOnlyRevision = "2026-06-24T22:30:00.000Z"
        let profileOnlyCheckpoint = try NativeSyncCheckpoint(globalCursor: nil, shoppingCursor: nil, updatedAt: profileOnlyRevision)
        let profileOnlySyncSnapshot = NativeSyncSnapshot(
            accountID: recipe.chef.id,
            environment: .production,
            checkpoint: profileOnlyCheckpoint,
            queue: NativeMutationQueue(),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: recipe.chef.id,
                    payload: .object(["username": .string(recipe.chef.username)]),
                    serverRevision: .updatedAt(profileOnlyRevision)
                )
            ],
            tombstones: []
        )
        let profileOnlyContent = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: profileOnlySyncSnapshot,
            appSnapshot: nil,
            authSessionState: .authenticated(session),
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        let profileOnlyResult = try #require(profileOnlyContent.profileSurfaceResult(identifier: recipe.chef.username))
        let profileOnlyRepository = try #require(profileOnlyContent.profileGraphRepository)
        let profileOnlyFellowChefs = try await profileOnlyRepository.graph(identifier: recipe.chef.id, direction: .fellowChefs, page: 1, limit: 50)
        let profileOnlyLastValidatedAt = try #require(Self.iso8601Date(profileOnlyRevision))
        let expectedRecentIDs = [
            "spoon_profile_shell_recent_tie_z",
            "spoon_profile_shell_recent_tie_y",
            "spoon_profile_shell_recent_5",
            "spoon_profile_shell_recent_4",
            "spoon_profile_shell_recent_3",
            "spoon_profile_shell_recent_2",
            "spoon_profile_shell_recent_1",
            "spoon_profile_shell_recent_0",
            ownFallbackDateSpoon.id,
            ownRecipeSpoon.id
        ]

        #expect(profile.header.id == recipe.chef.id)
        #expect(profile.ownerActions.isVisible)
        #expect(profile.recipes.map { $0.id } == [recipe.id])
        #expect(profile.cookbooks.map { $0.id } == [cookbook.id])
        #expect(profile.recentSpoons.map { $0.id } == expectedRecentIDs)
        #expect(profile.recentSpoons.map { $0.recipe.id } == Array(repeating: recipe.id, count: expectedRecentIDs.count))
        #expect(profile.recentSpoons.first?.note == "Recent capped spoon tie_z.")
        #expect(profile.recentSpoons.contains { $0.id == deletedOwnSpoon.id } == false)
        #expect(profile.offlineIndicator.display == .stale(domain: .profile(id: recipe.chef.id)))
        #expect(cachedProfile.data.profile.username == recipe.chef.username)
        #expect(cachedProfile.source == .cache(serverRevision: .updatedAt(julesRecipe.updatedAt), lastValidatedAt: .distantPast))
        #expect(cachedProfile.data.fellowChefsCount == 1)
        #expect(cachedProfile.data.kitchenVisitorsCount == 3)
        #expect(fellowChefs.rows.map(\.chefID) == ["chef_jules"])
        #expect(fellowChefs.rows.map(\.interactionSummary) == ["2 spoons"])
        #expect(fellowChefs.rows.first?.latestInteractionAt == ownSpoonRepeat.cookedAt)
        #expect(fellowChefs.emptyState == nil)
        #expect(kitchenVisitors.rows.map(\.chefID) == ["chef_mira", "chef_jules", "chef_ada"])
        #expect(kitchenVisitors.rows.map(\.interactionSummary) == ["1 spoon", "2 spoons", "1 spoon"])
        #expect(kitchenVisitors.rows.map(\.latestInteractionAt) == [visitorSpoonTie.cookedAt, visitorSpoonRepeat.cookedAt, visitorSpoonOlder.cookedAt])
        #expect(kitchenVisitors.emptyState == nil)
        #expect(emptyFellowChefs.rows.isEmpty)
        #expect(emptyFellowChefs.emptyState == ProfileGraphPage.emptyState(for: .fellowChefs))
        #expect(emptyKitchenVisitors.rows.isEmpty)
        #expect(emptyKitchenVisitors.emptyState == ProfileGraphPage.emptyState(for: .kitchenVisitors))
        #expect(profileOnlyContent.profileSurfaceViewModel?.header.username == recipe.chef.username)
        #expect(profileOnlyResult.data.recipes.isEmpty)
        #expect(profileOnlyResult.data.cookbooks.isEmpty)
        #expect(profileOnlyResult.source == .cache(serverRevision: .updatedAt(profileOnlyRevision), lastValidatedAt: profileOnlyLastValidatedAt))
        #expect(profileOnlyFellowChefs.rows.isEmpty)
        #expect(profileOnlyFellowChefs.emptyState == ProfileGraphPage.emptyState(for: .fellowChefs))
        #expect(signedOutProfile.ownerActions.isVisible == false)
        #expect(signedOutProfile.offlineIndicator.display == OfflineIndicatorDisplay.offline)
        if let emptyProfile = emptyContent.profileSurfaceViewModel {
            Issue.record("Expected no profile surface without recipe or cookbook chefs; got \(String(emptyProfile.header.username))")
        }
        if let emptyRepository = emptyContent.profileGraphRepository {
            _ = emptyRepository
            Issue.record("Expected no graph repository without recipe or cookbook chefs.")
        }
    }

    @Test("profile cache restore covers durable sync metadata and invalid edges")
    func profileCacheRestoreCoversDurableSyncMetadataAndInvalidEdges() throws {
        let durableValidatedAt = try #require(Self.iso8601Date("2026-06-24T20:00:00.000Z"))
        let fallbackValidatedAt = try #require(Self.iso8601Date("2026-06-24T22:30:00Z"))
        let cacheSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "chef_profile_cache",
            environment: .production,
            createdAt: durableValidatedAt,
            records: [
                try Self.cacheRecord(
                    id: "chef_zed",
                    username: "zed",
                    serverRevision: .etag("\"durable-zed\""),
                    lastValidatedAt: durableValidatedAt
                )
            ],
            dismissedIndicators: []
        )
        let syncSnapshot = NativeSyncSnapshot(
            accountID: nil,
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(globalCursor: nil, shoppingCursor: nil, updatedAt: "2026-06-24T22:30:00Z"),
            queue: NativeMutationQueue(),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: "chef_alpha",
                    payload: .object([
                        "username": .string("alpha/space"),
                        "photoUrl": .string("https://spoonjoy.app/photos/alpha.jpg"),
                        "joinedLabel": .string("Joined June 2026")
                    ]),
                    serverRevision: .etag("\"alpha\"")
                ),
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: "chef_beta",
                    payload: .object(["username": .string("beta")]),
                    serverRevision: .tombstone("profile-beta-tombstone")
                ),
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: "chef_invalid",
                    payload: .object(["username": .string("   ")]),
                    serverRevision: .updatedAt("2026-06-24T22:31:00.000Z")
                )
            ],
            tombstones: []
        )
        let content = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: .synced(lastSyncedAt: durableValidatedAt)
        )
        guard let alpha = content.profileSurfaceResult(identifier: "alpha/space") else {
            Issue.record("Expected restored sync profile for alpha.")
            return
        }
        guard let beta = content.profileSurfaceResult(identifier: "chef_beta") else {
            Issue.record("Expected restored sync profile for beta.")
            return
        }
        guard let zed = content.profileSurfaceResult(identifier: "zed") else {
            Issue.record("Expected restored durable profile for zed.")
            return
        }

        #expect(content.profileSurfaceViewModel?.header.username == "alpha/space")
        #expect(alpha.data.profile.photoURL == URL(string: "https://spoonjoy.app/photos/alpha.jpg"))
        #expect(alpha.data.profile.joinedLabel == "Joined June 2026")
        #expect(alpha.data.profile.href == "/users/alpha%2Fspace")
        #expect(alpha.data.profile.canonicalURL == URL(string: "https://spoonjoy.app/users/alpha%2Fspace"))
        #expect(alpha.source == ProfileSurfaceDataSource.cache(serverRevision: NativeCacheServerRevision.etag("\"alpha\""), lastValidatedAt: fallbackValidatedAt))
        #expect(beta.source == ProfileSurfaceDataSource.cache(serverRevision: NativeCacheServerRevision.localRevision("profile-beta-tombstone"), lastValidatedAt: fallbackValidatedAt))
        #expect(zed.source == ProfileSurfaceDataSource.cache(serverRevision: NativeCacheServerRevision.etag("\"durable-zed\""), lastValidatedAt: durableValidatedAt))
        #expect(content.profileSurfaceResult(identifier: "   ") == nil)
        #expect(content.profileSurfaceResult(identifier: "chef_invalid") == nil)

        let noCheckpointSnapshot = NativeSyncSnapshot(
            accountID: nil,
            environment: .production,
            checkpoint: nil,
            queue: NativeMutationQueue(),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: "chef_gamma",
                    payload: .object(["username": .string("gamma")]),
                    serverRevision: nil
                )
            ],
            tombstones: []
        )
        let noCheckpointContent = NativeShellContentState.restored(
            cacheSnapshot: try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_profile_cache",
                environment: .production,
                createdAt: durableValidatedAt,
                records: [],
                dismissedIndicators: []
            ),
            syncSnapshot: noCheckpointSnapshot,
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: .synced(lastSyncedAt: durableValidatedAt)
        )
        guard let gamma = noCheckpointContent.profileSurfaceResult(identifier: "gamma") else {
            Issue.record("Expected restored sync profile for gamma.")
            return
        }
        #expect(gamma.source == ProfileSurfaceDataSource.cache(serverRevision: nil, lastValidatedAt: Date.distantPast))
    }

    @Test("route identifiers and native URLs cover every app route")
    func routeIdentifiersAndNativeURLsCoverEveryAppRoute() throws {
        let cases: [(AppRoute, String, String)] = [
            (.kitchen, "kitchen", "spoonjoy://kitchen"),
            (.recipes, "recipes", "spoonjoy://recipes"),
            (.savedRecipes, "saved-recipes", "spoonjoy://saved-recipes"),
            (.recipeDetail(id: "recipe_lemon", presentation: .detail), "recipe:recipe_lemon", "spoonjoy://recipes/recipe_lemon"),
            (.recipeDetail(id: "recipe_lemon", presentation: .cook), "recipe-cook:recipe_lemon", "spoonjoy://recipes/recipe_lemon/cook"),
            (.recipeEditor(id: "recipe_lemon"), "recipe-editor:recipe_lemon", "spoonjoy://recipes/recipe_lemon/edit"),
            (.recipeEditor(id: nil), "recipe-editor:new", "spoonjoy://recipes/new/edit"),
            (.recipeCoverControls(id: "recipe_lemon"), "recipe-covers:recipe_lemon", "spoonjoy://recipes/recipe_lemon/covers"),
            (.cookbooks, "cookbooks", "spoonjoy://cookbooks"),
            (.cookbookDetail(id: "cookbook_weeknights"), "cookbook:cookbook_weeknights", "spoonjoy://cookbooks/cookbook_weeknights"),
            (.chefs, "chefs", "spoonjoy://chefs"),
            (.profile(identifier: "ari"), "profile:ari", "spoonjoy://users/ari"),
            (.profile(identifier: "ari/space"), "profile:ari%2Fspace", "spoonjoy://users/ari%2Fspace"),
            (.profile(identifier: "ari space"), "profile:ari%20space", "spoonjoy://users/ari%20space"),
            (.profileGraph(identifier: "ari", direction: .fellowChefs, page: 2), "profile-graph:ari:fellow-chefs:2", "spoonjoy://users/ari/fellow-chefs?page=2"),
            (.profileGraph(identifier: "ari/space", direction: .fellowChefs, page: 2), "profile-graph:ari%2Fspace:fellow-chefs:2", "spoonjoy://users/ari%2Fspace/fellow-chefs?page=2"),
            (.shoppingList, "shopping-list", "spoonjoy://shopping-list"),
            (.search(query: "", scope: .all), "search:all:", "spoonjoy://search"),
            (.search(query: "", scope: .recipes), "search:recipes:", "spoonjoy://search?scope=recipes"),
            (.search(query: "lemon pasta", scope: .shoppingList), "search:shopping-list:lemon pasta", "spoonjoy://search?q=lemon%20pasta&scope=shopping-list"),
            (.capture, "capture", "spoonjoy://capture"),
            (.settings, "settings", "spoonjoy://settings"),
            (.unknownLink, "unknown-link", "spoonjoy://unknown")
        ]

        for (route, identifier, rawURL) in cases {
            #expect(route.stateIdentifier == identifier)
            #expect(AppRoute(stateIdentifier: identifier) == route)
            #expect(DeepLinkURLBuilder.url(for: route) == URL(string: rawURL), "\(route)")
        }

        let colonSearchRoute = AppRoute.search(query: "lemon:quick", scope: .recipes)
        #expect(AppRoute(stateIdentifier: colonSearchRoute.stateIdentifier) == colonSearchRoute)
        #expect(AppRoute(stateIdentifier: "recipe:../secret") == nil)
        #expect(AppRoute(stateIdentifier: "recipe: padded ") == nil)
        #expect(AppRoute(stateIdentifier: "recipe-covers:../secret") == nil)
        #expect(AppRoute(stateIdentifier: "profile:../secret") == nil)
        #expect(AppRoute(stateIdentifier: "profile-graph:ari:not-real:1") == nil)
        #expect(AppRoute(stateIdentifier: "profile-graph:ari:fellow-chefs:0") == nil)
        #expect(AppRoute(stateIdentifier: "search:recipes:   ") == nil)
        #expect(AppRoute(stateIdentifier: "search:not-a-scope:lemon") == nil)
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }

    private static func authSession(accountID: String?) throws -> AuthSession {
        try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            scope: NativeAuthSession.defaultScope,
            accountID: accountID
        )
    }

    private static func recipe(id: String, title: String, chef: ChefSummary, updatedAt: String) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: title,
            description: nil,
            servings: nil,
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "Recipe by \(chef.username)",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: updatedAt,
            updatedAt: updatedAt,
            steps: [],
            cookbooks: []
        )
    }

    private static func cookbook(id: String, title: String, chef: ChefSummary, recipes: [RecipeSummary]) -> Cookbook {
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
        return Cookbook(
            id: id,
            title: title,
            chef: chef,
            recipeCount: recipes.count,
            cover: CookbookCover(imageURLs: recipes.map(\.displayCoverImageURL)),
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(creditText: "Cookbook by \(chef.username)", canonicalURL: canonicalURL),
            createdAt: recipes.first?.createdAt ?? "2026-07-01T10:00:00.000Z",
            updatedAt: recipes.first?.updatedAt ?? "2026-07-01T10:00:00.000Z",
            recipes: recipes
        )
    }

    private static func jsonValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    private static func iso8601Date(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func cacheRecord(
        id: String,
        username: String,
        serverRevision: NativeCacheServerRevision?,
        lastValidatedAt: Date
    ) throws -> NativeCacheRecord {
        let domain = NativeCacheDomain.profile(id: id)
        return try NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "chef_profile_cache",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: lastValidatedAt,
                lastValidatedAt: lastValidatedAt,
                sourceEndpoint: "/api/v1/users/\(username)",
                serverRevision: serverRevision
            ),
            payload: .profile(id: id, username: username)
        )
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-app-state-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
