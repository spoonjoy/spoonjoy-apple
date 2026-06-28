import SpoonjoyCore
import SwiftUI

struct PlatformNavigationView: View {
    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState

    @Environment(\.openURL) private var openURL
    @FocusState private var isSearchFieldFocused: Bool
    @State private var activeSearch: ActiveSearchSurfaceState?
    @State private var liveSearchRequestMarker: LiveSearchRequestMarker?

    private let contentState: NativeShellContentState
    private let offlineIndicatorState: OfflineIndicatorState
    private let dismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let queueMutation: @Sendable (NativeQueuedMutation) async throws -> Void
    private let queueMutations: @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    private let discardQueuedMutation: @Sendable (String) async throws -> Void
    private let executeRecipeEditorRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> Void
    private let executeSettingsActionRequest: @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?
    private let executeCaptureImportRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse
    private let performSettingsSessionOperation: @MainActor @Sendable (SettingsSessionOperation) async throws -> Void
    private let requestNotificationPermission: @MainActor @Sendable () async throws -> APNsPermissionState
    private let requestDeviceRegistrationAction: @MainActor @Sendable (String) async throws -> NotificationAPNsAction
    private let openNotificationSettings: @MainActor @Sendable () -> Void
    private let recordNotificationAPNsBlockerHandler: @MainActor @Sendable (AppleDeveloperProgramBlocker) -> Void
    private let recordShoppingList: @MainActor @Sendable (ShoppingListState) -> Void
    private let recordCookProgress: @MainActor @Sendable (CookModeProgress) -> Void
    private let recordCaptureDraftHandler: @MainActor @Sendable (CaptureDraft) -> Void
    private let discardCaptureDraftHandler: @MainActor @Sendable (String) -> Void
    private let recordCaptureImportRetryHandler: @MainActor @Sendable (NativeQueuedMutation) -> Void
    private let recordCaptureImportBlockerHandler: @MainActor @Sendable (CaptureImportBlocker) -> Void
    private let recordSpoonCookLogDraftHandler: @MainActor @Sendable (SpoonCookLogDraftState?, String) -> Void
    private let recordSearchSurfacePageHandler: @MainActor @Sendable (SearchSurfacePage, String) async throws -> Void
    private let searchSurfaceRepositoryHandler: @MainActor @Sendable (SearchSurfaceContext) -> any SearchSurfaceRepository
    private let syncTriggerCoordinator: NativeSyncTriggerCoordinator

    init(
        navigation: Binding<AppNavigationState>,
        search: Binding<SearchState>,
        contentState: NativeShellContentState,
        offlineIndicatorState: OfflineIndicatorState,
        dismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void,
        queueMutation: @escaping @Sendable (NativeQueuedMutation) async throws -> Void,
        queueMutations: @escaping @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        discardQueuedMutation: @escaping @Sendable (String) async throws -> Void,
        executeRecipeEditorRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> Void,
        executeSettingsActionRequest: @escaping @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?,
        executeCaptureImportRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse,
        performSettingsSessionOperation: @escaping @MainActor @Sendable (SettingsSessionOperation) async throws -> Void,
        requestNotificationPermission: @escaping @MainActor @Sendable () async throws -> APNsPermissionState,
        requestDeviceRegistrationAction: @escaping @MainActor @Sendable (String) async throws -> NotificationAPNsAction,
        openNotificationSettings: @escaping @MainActor @Sendable () -> Void,
        recordNotificationAPNsBlocker: @escaping @MainActor @Sendable (AppleDeveloperProgramBlocker) -> Void,
        recordShoppingList: @escaping @MainActor @Sendable (ShoppingListState) -> Void,
        recordCookProgress: @escaping @MainActor @Sendable (CookModeProgress) -> Void,
        recordCaptureDraft: @escaping @MainActor @Sendable (CaptureDraft) -> Void,
        discardCaptureDraft: @escaping @MainActor @Sendable (String) -> Void,
        recordCaptureImportRetry: @escaping @MainActor @Sendable (NativeQueuedMutation) -> Void,
        recordCaptureImportBlocker: @escaping @MainActor @Sendable (CaptureImportBlocker) -> Void,
        recordSpoonCookLogDraft: @escaping @MainActor @Sendable (SpoonCookLogDraftState?, String) -> Void,
        recordSearchSurfacePage: @escaping @MainActor @Sendable (SearchSurfacePage, String) async throws -> Void,
        searchSurfaceRepository: @escaping @MainActor @Sendable (SearchSurfaceContext) -> any SearchSurfaceRepository,
        syncTriggerCoordinator: NativeSyncTriggerCoordinator
    ) {
        _navigation = navigation
        _search = search
        self.contentState = contentState
        self.offlineIndicatorState = offlineIndicatorState
        self.dismissOfflineIndicator = dismissOfflineIndicator
        self.queueMutation = queueMutation
        self.queueMutations = queueMutations
        self.discardQueuedMutation = discardQueuedMutation
        self.executeRecipeEditorRequest = executeRecipeEditorRequest
        self.executeSettingsActionRequest = executeSettingsActionRequest
        self.executeCaptureImportRequest = executeCaptureImportRequest
        self.performSettingsSessionOperation = performSettingsSessionOperation
        self.requestNotificationPermission = requestNotificationPermission
        self.requestDeviceRegistrationAction = requestDeviceRegistrationAction
        self.openNotificationSettings = openNotificationSettings
        self.recordNotificationAPNsBlockerHandler = recordNotificationAPNsBlocker
        self.recordShoppingList = recordShoppingList
        self.recordCookProgress = recordCookProgress
        self.recordCaptureDraftHandler = recordCaptureDraft
        self.discardCaptureDraftHandler = discardCaptureDraft
        self.recordCaptureImportRetryHandler = recordCaptureImportRetry
        self.recordCaptureImportBlockerHandler = recordCaptureImportBlocker
        self.recordSpoonCookLogDraftHandler = recordSpoonCookLogDraft
        self.recordSearchSurfacePageHandler = recordSearchSurfacePage
        self.searchSurfaceRepositoryHandler = searchSurfaceRepository
        self.syncTriggerCoordinator = syncTriggerCoordinator
    }

    var body: some View {
        let spotlightDocuments = spotlightIndexDocuments
        NavigationSplitView {
            sidebar
                .navigationTitle("Spoonjoy")
        } detail: {
            NavigationStack {
                detailContent
                    .safeAreaPadding(.bottom, shellOfflineStatusContentReserve)
                    .navigationTitle(title(for: navigation.route))
#if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
#endif
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationContent(for: route)
            }
            .searchable(text: searchText, prompt: "Search Spoonjoy")
            .searchFocused($isSearchFieldFocused)
            .searchScopes(searchScope) {
                ForEach(availableSearchScopes, id: \.rawValue) { scope in
                    Text(label(for: scope)).tag(scope)
                }
            }
            .onSubmit(of: .search) {
                Task {
                    await performSearch(search)
                }
            }
            .spoonjoyToolbar(navigation: $navigation, search: $search)
            .safeAreaInset(edge: .bottom) {
                if shouldShowShellOfflineStatus {
                    OfflineStatusView(display: offlineIndicatorState.display, onDismiss: dismissOfflineIndicator)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .background(KitchenTableTheme.bone.opacity(0.94))
                }
            }
            .task(id: spotlightIndexIdentity) {
                await Self.indexSpotlightIfAvailable(documents: spotlightDocuments)
            }
            .task(id: contentState.environment.rawValue) {
                _ = try? await syncTriggerCoordinator.handle(.foreground)
            }
            .onChange(of: navigation.route) { _, route in
                if !routeKeepsSearchFocus(route) {
                    isSearchFieldFocused = false
                }
                if liveSearchRequestMarker?.routeIdentifier != route.stateIdentifier {
                    liveSearchRequestMarker = nil
                }
            }
        }
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
    }

    private var shellOfflineStatusContentReserve: CGFloat {
        guard shouldShowShellOfflineStatus else {
            return 0
        }
        switch offlineIndicatorState.display {
        case .dismissed:
            return 0
        case .synced, .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            return 96
        }
    }

    private var shouldShowShellOfflineStatus: Bool {
        guard !routeOwnsOfflineStatus(navigation.route) else {
            return false
        }
        switch offlineIndicatorState.display {
        case .dismissed:
            return false
        case .synced, .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            return true
        }
    }

    private func routeOwnsOfflineStatus(_ route: AppRoute) -> Bool {
        switch route {
        case .recipeDetail(_, .detail),
             .recipeEditor,
             .recipeCoverControls,
             .cookbooks,
             .cookbookDetail,
             .profile,
             .profileGraph,
             .shoppingList,
             .search,
             .settings:
            true
        case .kitchen, .recipes, .recipeDetail(_, .cook), .capture, .unknownLink:
            false
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            sidebarLink(section: .kitchen, title: "Kitchen", systemImage: "house")
            sidebarLink(section: .recipes, title: "Recipes", systemImage: "book.closed")
            sidebarLink(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical")
            sidebarLink(section: .shoppingList, title: "Shopping", systemImage: "checklist")
            sidebarLink(section: .search, title: "Search", systemImage: "magnifyingglass")
            sidebarLink(section: .capture, title: "Capture", systemImage: "camera")
            sidebarLink(section: .settings, title: "Settings", systemImage: "gearshape")
        }
    }

    @ViewBuilder private var detailContent: some View {
        destinationContent(for: navigation.route)
    }

    @ViewBuilder private func destinationContent(for route: AppRoute) -> some View {
        switch route {
        case .kitchen:
            KitchenView(
                kitchen: contentState.kitchen,
                recipes: contentState.recipes,
                cookbooks: contentState.cookbooks,
                openRecipe: openRecipe,
                startCooking: startCooking,
                openCookbook: openCookbook
            )
        case .recipes:
            RecipesView(viewModel: recipeCatalogViewModel, openRoute: openRoute)
        case .recipeDetail(let id, .detail):
            RecipeDetailRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                spoonRepository: spoonCookLogRepository,
                initialViewModel: recipe(id: id).map(recipeDetailScreenViewModel(for:)),
                actionConnectivity: recipeActionConnectivity,
                shoppingViewModel: shoppingViewModel,
                context: recipeDetailContext(for:),
                actionPlanner: { viewModel, context in
                    recipeActionsViewModel(for: viewModel, context: context)
                },
                spoonCookLogViewModel: spoonCookLogViewModel(for:summary:),
                spoonCookLogDraft: spoonCookLogDraft(for:),
                openRoute: openRoute,
                performRecipeAction: performRecipeAction,
                performSpoonCookLogAction: performSpoonCookLogAction,
                recordSpoonCookLogDraft: recordSpoonCookLogDraft(_:forRecipeID:),
                discardSpoonCookLogConflict: discardSpoonCookLogConflict(clientMutationID:),
                performShoppingAction: performShoppingAction
            )
        case .recipeDetail(let id, .cook):
            CookModeRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                initialRecipe: recipe(id: id),
                progress: cookProgress(for:),
                progressDidChange: recordCookProgress,
                shoppingViewModel: shoppingViewModel,
                performShoppingAction: performShoppingAction,
                close: {
                    openRecipe(id)
                }
            )
        case .recipeEditor(let id):
            if let editorViewModel = recipeEditorViewModel(id: id) {
                RecipeEditorView(
                    viewModel: editorViewModel,
                    mutationDidPlan: handleRecipeEditorPlan,
                    mutationsDidQueue: queueMutations,
                    conflictDidDiscardLocalChange: discardRecipeEditorLocalChange,
                    close: openRoute
                )
            } else {
                ShellPlaceholderView(title: "Recipe Editor", systemImage: "pencil", detail: "Recipe unavailable.")
            }
        case .recipeCoverControls(let id):
            RecipeCoverControlsRouteView(
                recipeID: id,
                initialRecipe: recipe(id: id),
                recipeRepository: recipeCatalogRepository,
                configuration: contentState.configuration,
                connectivity: recipeCoverControlsConnectivity,
                performCoverAction: performCoverAction,
                close: {
                    openRecipe(id)
                }
            )
        case .cookbooks:
            CookbooksView(
                viewModel: cookbookSurfaceViewModel,
                openRoute: openRoute,
                performCookbookAction: performCookbookAction
            )
        case .cookbookDetail(let id):
            CookbookDetailRouteView(
                cookbookID: id,
                viewModel: cookbookSurfaceViewModel,
                openRoute: openRoute,
                performCookbookAction: performCookbookAction
            )
        case AppRoute.profile(let identifier):
            ProfileRouteView(
                identifier: identifier,
                viewModel: profileSurfaceViewModel(identifier: identifier),
                openRoute: openRoute
            )
        case AppRoute.profileGraph(let identifier, let direction, let page):
            ProfileGraphRouteView(
                identifier: identifier,
                direction: direction,
                page: page,
                viewModel: profileSurfaceViewModel(identifier: identifier),
                openRoute: openRoute
            )
        case .shoppingList:
            ShoppingListView(
                viewModel: shoppingViewModel,
                actionDidPlan: performShoppingAction
            )
        case .search(let query, let scope):
            let routeSearch = normalizedSearch(SearchState(query: query, scope: scope))
            SearchView(
                search: $search,
                viewModel: searchViewModel(for: routeSearch),
                openRoute: openRoute,
                searchTask: performSearch
            )
            .onAppear {
                search.apply(route: routeSearch.route)
                if routeSearch.route != navigation.route {
                    navigation.navigate(to: routeSearch.route)
                }
                isSearchFieldFocused = true
            }
            .task(id: liveSearchTaskIdentity(for: routeSearch)) {
                await refreshRouteSearchIfNeeded(routeSearch)
            }
        case .capture:
            CaptureDraftView(
                viewModel: captureViewModel,
                importViewModel: captureImportViewModel,
                draftDidChange: recordCaptureDraft(_:),
                draftDidDiscard: discardCaptureDraft(_:),
                importDidSubmit: performCaptureImport(draft:)
            )
        case .settings:
            SettingsView(
                viewModel: contentState.settingsViewModel,
                settingsSurfaceViewModel: contentState.settingsSurfaceViewModel,
                notificationAPNsSurfaceViewModel: contentState.notificationAPNsSurfaceViewModel,
                performSettingsAction: performSettingsAction,
                performNotificationAPNsAction: performNotificationAPNsAction,
                requestNotificationPermission: requestNotificationPermission,
                requestDeviceRegistrationAction: requestDeviceRegistrationAction,
                openNotificationSettings: openNotificationSettings,
                notificationAPNsSettingsContent: { AnyView(notificationAPNsSettingsView($0)) },
                shellOfflineIndicatorState: offlineIndicatorState,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .unknownLink:
            ShellPlaceholderView(title: "Link Not Found", systemImage: "link.badge.plus", detail: "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.")
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search.query },
            set: { value in
                let nextSearch = normalizedSearch(SearchState(query: value, scope: search.scope))
                search.update(query: nextSearch.query, scope: nextSearch.scope)
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                        await performSearch(nextSearch)
                    }
                }
            }
        )
    }

    private var searchScope: Binding<SearchScope> {
        Binding(
            get: {
                normalizedSearch(search).scope
            },
            set: { scope in
                let nextSearch = normalizedSearch(SearchState(query: search.query, scope: scope))
                search.update(query: nextSearch.query, scope: nextSearch.scope)
                if !nextSearch.hasQuery {
                    Task {
                        await performSearch(nextSearch)
                    }
                }
            }
        )
    }

    private var availableSearchScopes: [SearchScope] {
        contentState.searchSurfaceViewModel.searchableScopes
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { navigation.sidebarSelection },
            set: { section in
                guard let section else { return }
                navigateToSidebar(section)
            }
        )
    }

    private func sidebarLink(section: AppSection, title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .tag(section)
    }

    private func navigateToSidebar(_ section: AppSection) {
        if section != .search {
            isSearchFieldFocused = false
        }
        switch section {
        case .kitchen:
            navigation.navigate(to: .kitchen)
        case .recipes:
            navigation.navigate(to: .recipes)
        case .cookbooks:
            navigation.navigate(to: .cookbooks)
        case .shoppingList:
            navigation.navigate(to: .shoppingList)
        case .search:
            Task {
                await performSearch(search)
            }
        case .capture:
            navigation.navigate(to: .capture)
        case .settings:
            navigation.navigate(to: .settings)
        }
    }

    private func title(for route: AppRoute) -> String {
        switch route {
        case .kitchen:
            "Kitchen"
        case .recipes, .recipeDetail, .recipeEditor, .recipeCoverControls:
            "Recipes"
        case .cookbooks, .cookbookDetail:
            "Cookbooks"
        case .profile:
            "Profile"
        case .profileGraph(_, let direction, _):
            direction == .fellowChefs ? "Fellow Chefs" : "Kitchen Visitors"
        case .shoppingList:
            "Shopping"
        case .search:
            "Search"
        case .capture:
            "Capture"
        case .settings:
            "Settings"
        case .unknownLink:
            "Unknown Link"
        }
    }

    private func label(for scope: SearchScope) -> String {
        switch scope {
        case .all:
            "All"
        case .recipes:
            "Recipes"
        case .cookbooks:
            "Cookbooks"
        case .chefs:
            "Chefs"
        case .shoppingList:
            "Shopping"
        }
    }

    private func recipe(id: String) -> Recipe? {
        contentState.recipes.first { $0.id == id }
    }

    private func cookbook(id: String) -> Cookbook? {
        contentState.cookbooks.first { $0.id == id }
    }

    private func cookProgress(for recipe: Recipe) -> CookModeProgress {
        contentState.cookProgress(for: recipe.id) ?? CookModeProgress.starting(recipe: recipe, startedAt: timestamp())
    }

    private func openRecipe(_ id: String) {
        isSearchFieldFocused = false
        navigation.navigate(to: .recipeDetail(id: id, presentation: .detail))
    }

    private func openRoute(_ route: AppRoute) {
        if !routeKeepsSearchFocus(route) {
            isSearchFieldFocused = false
        }
        navigation.navigate(to: route)
    }

    @MainActor
    private func performSearch(_ nextSearch: SearchState) async {
        let nextSearch = normalizedSearch(nextSearch)
        let identity = contentState.searchSurfaceIdentity
        search.apply(route: .search(query: nextSearch.query, scope: nextSearch.scope))
        navigation.navigate(to: search.route)
        let requestMarker = LiveSearchRequestMarker(identity: identity, routeIdentifier: nextSearch.route.stateIdentifier)

        guard nextSearch.hasQuery else {
            liveSearchRequestMarker = nil
            activeSearch = ActiveSearchSurfaceState(
                identity: identity,
                viewModel: contentState.performSearch(nextSearch)
            )
            return
        }
        guard liveSearchRequestMarker != requestMarker else {
            return
        }
        liveSearchRequestMarker = requestMarker
        defer {
            clearLiveSearchRequestMarker(requestMarker)
        }

        let cachedPage = contentState.searchSurfacePage(for: nextSearch)
        let context = contentState.searchSurfaceContext
        let repository = searchSurfaceRepositoryHandler(context)
        do {
            let page = try await repository.search(
                request: SearchSurfaceRequest(query: nextSearch.query, scope: nextSearch.scope, limit: 20)
            )
            guard canApplySearchResult(identity: identity, state: nextSearch) else {
                clearLiveSearchRequestMarker(requestMarker)
                return
            }
            try? await recordSearchSurfacePageHandler(page, identity)
            activeSearch = ActiveSearchSurfaceState(
                identity: identity,
                viewModel: contentState.performSearch(
                    page: page,
                    state: nextSearch
                )
            )
        } catch SearchSurfaceRepositoryError.cancelled {
            clearLiveSearchRequestMarker(requestMarker)
            return
        } catch let error as SearchSurfaceRepositoryError {
            guard canApplySearchResult(identity: identity, state: nextSearch) else {
                clearLiveSearchRequestMarker(requestMarker)
                return
            }
            activeSearch = ActiveSearchSurfaceState(
                identity: identity,
                viewModel: contentState.performSearch(
                    error: error,
                    state: nextSearch,
                    cachedPage: cachedPage
                )
            )
        } catch {
            guard canApplySearchResult(identity: identity, state: nextSearch) else {
                clearLiveSearchRequestMarker(requestMarker)
                return
            }
            activeSearch = ActiveSearchSurfaceState(
                identity: identity,
                viewModel: contentState.performSearch(
                    error: .searchFailed(message: String(describing: error)),
                    state: nextSearch,
                    cachedPage: cachedPage
                )
            )
        }
    }

    private func liveSearchRequestMarker(for state: SearchState) -> LiveSearchRequestMarker {
        LiveSearchRequestMarker(identity: contentState.searchSurfaceIdentity, routeIdentifier: state.route.stateIdentifier)
    }

    private func liveSearchTaskIdentity(for state: SearchState) -> String {
        "\(contentState.searchSurfaceIdentity)|\(state.route.stateIdentifier)"
    }

    @MainActor
    private func refreshRouteSearchIfNeeded(_ routeSearch: SearchState) async {
        guard routeSearch.hasQuery,
              !hasActiveSearch(for: routeSearch),
              liveSearchRequestMarker != liveSearchRequestMarker(for: routeSearch) else {
            return
        }
        await performSearch(routeSearch)
    }

    private func clearLiveSearchRequestMarker(_ marker: LiveSearchRequestMarker) {
        if liveSearchRequestMarker == marker {
            liveSearchRequestMarker = nil
        }
    }

    private func hasActiveSearch(for routeSearch: SearchState) -> Bool {
        guard let activeSearch else {
            return false
        }
        return activeSearch.identity == contentState.searchSurfaceIdentity &&
            activeSearch.viewModel.state == routeSearch
    }

    private func searchViewModel(for routeSearch: SearchState) -> SearchSurfaceViewModel {
        if hasActiveSearch(for: routeSearch), let activeSearch {
            return activeSearch.viewModel
        }
        if routeSearch.query.isEmpty && routeSearch.scope == .all {
            return contentState.searchSurfaceViewModel
        }
        return contentState.performSearch(routeSearch)
    }

    private func normalizedSearch(_ candidate: SearchState) -> SearchState {
        availableSearchScopes.contains(candidate.scope)
            ? candidate
            : SearchState(query: candidate.query, scope: .all)
    }

    private func canApplySearchResult(identity: String, state: SearchState) -> Bool {
        contentState.searchSurfaceIdentity == identity &&
            search == state &&
            navigation.route == state.route &&
            !Task.isCancelled
    }

    private func routeKeepsSearchFocus(_ route: AppRoute) -> Bool {
        if case .search = route {
            return true
        }
        return false
    }

    private func openProfileRoute(_ route: AppRoute) {
        navigation.navigate(to: route)
    }

    private func startCooking(_ id: String) {
        isSearchFieldFocused = false
        navigation.navigate(to: .recipeDetail(id: id, presentation: .cook))
    }

    private func openCookbook(_ id: String) {
        isSearchFieldFocused = false
        navigation.navigate(to: .cookbookDetail(id: id))
    }

    private var shoppingViewModel: ShoppingSurfaceViewModel {
        ShoppingSurfaceViewModel(
            shoppingList: contentState.shoppingList,
            queuedMutations: contentState.queuedMutations,
            conflicts: contentState.syncConflicts,
            connectivity: shoppingSurfaceConnectivity,
            now: { ISO8601DateFormatter().string(from: Date()) }
        )
    }

    private var recipeCatalogRepository: any RecipeCatalogRepository {
        let catalog = contentState.recipeCatalog
        let snapshotRepository = SnapshotRecipeCatalogRepository(
            page: catalog,
            details: contentState.recipes.map { entry in
                RecipeCatalogDetailResult(recipe: entry, source: catalog.source)
            }
        )
        let liveRepository = LiveRecipeCatalogRepository(configuration: contentState.configuration)
        return FallbackRecipeCatalogRepository(primary: liveRepository, fallback: snapshotRepository)
    }

    private var spoonCookLogRepository: any SpoonCookLogRepository {
        LiveSpoonCookLogRepository(configuration: contentState.configuration)
    }

    private var recipeCatalogViewModel: RecipeCatalogViewModel {
        let viewModel = RecipeCatalogViewModel(repository: recipeCatalogRepository)
        viewModel.apply(page: contentState.recipeCatalog)
        return viewModel
    }

    private var cookbookSurfaceRepository: any CookbookSurfaceRepository {
        let page = cookbookSurfacePage(source: cookbookSurfaceDataSource)
        let snapshotRepository = SnapshotCookbookSurfaceRepository(
            page: page,
            details: contentState.cookbooks.map { cookbook in
                CookbookSurfaceDetailResult(
                    cookbook: cookbook,
                    source: cookbookSurfaceDataSource,
                    availableRecipes: availableCookbookRecipes(for: cookbook)
                )
            }
        )
        let liveRepository = LiveCookbookSurfaceRepository(
            configuration: contentState.configuration,
            availableRecipes: contentState.recipes.map(RecipeSummary.init(recipe:))
        )
        return FallbackCookbookSurfaceRepository(primary: liveRepository, fallback: snapshotRepository)
    }

    private var cookbookSurfaceViewModel: CookbookSurfaceViewModel {
        let viewModel = CookbookSurfaceViewModel(
            repository: cookbookSurfaceRepository,
            context: CookbookSurfaceContext(currentChefID: currentChefID, currentChef: currentChefSummary),
            queuedMutations: contentState.queuedMutations,
            conflicts: contentState.syncConflicts,
            connectivity: cookbookSurfaceConnectivity,
            now: Date.init,
            timestamp: { ISO8601DateFormatter().string(from: Date()) }
        )
        viewModel.apply(page: cookbookSurfacePage(source: cookbookSurfaceDataSource))
        return viewModel
    }

    private func profileGraphRepository(identifier: String) -> any ProfileChefGraphSurfaceRepository {
        let liveRepository = LiveProfileChefGraphSurfaceRepository(configuration: contentState.configuration)
        guard let profileResult = contentState.profileSurfaceResult(identifier: identifier) else {
            return FallbackProfileChefGraphSurfaceRepository(
                primary: liveRepository,
                fallback: UnavailableProfileChefGraphSurfaceRepository()
            )
        }
        let snapshotRepository = SnapshotProfileChefGraphSurfaceRepository(
            profileResult: profileResult,
            graphPages: contentState.profileGraphPages(profileResult: profileResult)
        )
        return FallbackProfileChefGraphSurfaceRepository(primary: liveRepository, fallback: snapshotRepository)
    }

    private func profileSurfaceViewModel(identifier: String) -> ProfileChefGraphSurfaceViewModel {
        ProfileChefGraphSurfaceViewModel(
            repository: profileGraphRepository(identifier: identifier),
            context: ProfileSurfaceContext(currentChefID: currentChefID),
            queuedMutations: contentState.queuedMutations,
            conflicts: contentState.syncConflicts,
            connectivity: profileSurfaceConnectivity,
            now: Date.init
        )
    }

    private func cookbookSurfacePage(source: CookbookSurfaceDataSource) -> CookbookSurfacePage {
        CookbookSurfacePage(
            query: nil,
            limit: max(20, contentState.cookbooks.count),
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: contentState.cookbooks.map(CookbookSummary.init(cookbook:)),
            source: source
        )
    }

    private var cookbookSurfaceDataSource: CookbookSurfaceDataSource {
        switch offlineIndicatorState.display {
        case .synced:
            .live(requestID: "native-shell", validatedAt: Date())
        case .offline, .stale, .dismissed, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            .cache(serverRevision: latestCookbookRevision, lastValidatedAt: .distantPast)
        }
    }

    private var latestRecipeRevision: NativeCacheServerRevision? {
        contentState.recipes
            .map(\.updatedAt)
            .max()
            .map(NativeCacheServerRevision.updatedAt)
    }

    private var latestCookbookRevision: NativeCacheServerRevision? {
        contentState.cookbooks
            .map(\.updatedAt)
            .max()
            .map(NativeCacheServerRevision.updatedAt)
    }

    private func availableCookbookRecipes(for cookbook: Cookbook) -> [RecipeSummary] {
        let savedRecipeIDs = Set(cookbook.recipes.map(\.id))
        return contentState.recipes
            .filter { !savedRecipeIDs.contains($0.id) }
            .map(RecipeSummary.init(recipe:))
    }

    private func recipeDetailScreenViewModel(for recipe: Recipe) -> RecipeDetailScreenViewModel {
        RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(recipe: recipe, source: contentState.recipeCatalog.source),
            context: recipeDetailContext(for: recipe)
        )
    }

    private func recipeActionsViewModel(for viewModel: RecipeDetailScreenViewModel, context: RecipeDetailContext) -> RecipeActionsViewModel {
        let plannedAt = timestamp()
        return RecipeActionsViewModel(
            recipe: viewModel.recipe,
            context: context,
            connectivity: recipeActionConnectivity,
            now: { plannedAt }
        )
    }

    private func spoonCookLogViewModel(
        for viewModel: RecipeDetailScreenViewModel,
        summary: RecipeDetailSpoonSummary
    ) -> SpoonCookLogViewModel {
        SpoonCookLogViewModel(
            recipeID: viewModel.id,
            data: SpoonCookLogData(summary: summary),
            currentChefID: currentChefID,
            queuedMutations: contentState.queuedMutations,
            conflicts: contentState.syncConflicts,
            connectivity: spoonCookLogConnectivity,
            draftMediaUsage: SpoonCookLogStagedMediaUsage(drafts: Array(contentState.spoonCookLogDraftsByRecipeID.values)),
            now: { ISO8601DateFormatter().string(from: Date()) }
        )
    }

    private func spoonCookLogDraft(for viewModel: RecipeDetailScreenViewModel) -> SpoonCookLogDraftState? {
        contentState.spoonCookLogDraft(recipeID: viewModel.id)
    }

    private func recordSpoonCookLogDraft(_ draft: SpoonCookLogDraftState?, forRecipeID recipeID: String) {
        recordSpoonCookLogDraftHandler(draft, recipeID)
    }

    private func recipeDetailContext(for recipe: Recipe) -> RecipeDetailContext {
        RecipeDetailContext(
            currentChefID: currentChefID,
            availableCookbooks: contentState.cookbooks.map { cookbook in
                RecipeCookbookSaveOption(id: cookbook.id, title: cookbook.title)
            },
            savedInCookbookIDs: Set(recipe.cookbooks.map(\.id)),
            hasIngredientsInShoppingList: hasShoppingListIngredient(for: recipe),
            now: Date()
        )
    }

    private var currentChefID: String? {
        switch contentState.authSessionState {
        case .signedOut:
            nil
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        }
    }

    private var currentChefSummary: ChefSummary? {
        contentState.recipes.first?.chef ?? contentState.cookbooks.first?.chef ?? currentChefID.map {
            ChefSummary(id: $0, username: "Spoonjoy")
        }
    }

    private func recipeEditorViewModel(id: String?) -> RecipeEditorViewModel? {
        let chefID = currentChefID ?? "signed-out"
        switch id {
        case .some(let recipeID):
            guard let recipe = recipe(id: recipeID) else {
                return nil
            }
            return RecipeEditorViewModel(
                mode: .edit(recipe: recipe, currentChefID: chefID),
                connectivity: recipeEditorConnectivity,
                conflict: recipeEditorConflict(for: recipeID),
                queuedRecipeMutations: contentState.queuedMutations,
                now: timestamp
            )
        case nil:
            return RecipeEditorViewModel(
                mode: .create(currentChefID: chefID, draft: .blank(currentChefID: chefID)),
                connectivity: recipeEditorConnectivity,
                conflict: nil,
                queuedRecipeMutations: contentState.queuedMutations,
                now: timestamp
            )
        }
    }

    private var recipeEditorConnectivity: RecipeEditorConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var recipeActionConnectivity: RecipeActionConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var recipeCoverControlsConnectivity: RecipeCoverControlsConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var cookbookSurfaceConnectivity: CookbookSurfaceConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var profileSurfaceConnectivity: ProfileSurfaceConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var settingsSurfaceConnectivity: SettingsSurfaceConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var spoonCookLogConnectivity: SpoonCookLogConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var shoppingSurfaceConnectivity: ShoppingSurfaceConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var captureImportConnectivity: CaptureImportConnectivity {
        if offlineIndicatorState.display == .offline {
            return .offline
        }

        return .online
    }

    private var pendingCaptureImportMutation: NativeQueuedMutation? {
        guard let draft = contentState.captureDraft,
              let draftImportSource = try? draft.importSource() else {
            return nil
        }

        return contentState.queuedMutations.first {
            $0.queueableKind == .recipeImportSubmit &&
                $0.recipeImportSource == draftImportSource
        }
    }

    private func recipeEditorConflict(for recipeID: String) -> RecipeEditorConflict? {
        for conflict in contentState.syncConflicts {
            guard let mutation = contentState.queuedMutations.first(where: { $0.clientMutationID == conflict.clientMutationID }),
                  mutation.optimisticRecipeID == recipeID else {
                continue
            }

            return RecipeEditorConflict(
                resourceID: recipeID,
                serverRevision: conflict.serverRevision,
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message
            )
        }

        return nil
    }

    private func handleRecipeEditorPlan(_ plan: RecipeEditorMutationPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func performRecipeAction(_ plan: RecipeActionPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func performCookbookAction(_ plan: CookbookSurfaceActionPlan) async throws -> NativeQueuedMutation? {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return queuedMutation
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return offlineFallbackMutation
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return offlineFallbackMutation
                }
                throw error
            }
        }
        return nil
    }

    private func performCoverAction(_ plan: RecipeCoverControlsMutationPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func performSpoonCookLogAction(_ plan: SpoonCookLogMutationPlan) async throws {
        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            return
        }

        if let offlineFallbackMutation = plan.offlineFallbackMutation,
           hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey) {
            _ = try await queueMutations([offlineFallbackMutation], true)
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRecipeEditorRequest(requestBuilder)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func performSettingsAction(_ plan: SettingsActionPlan) async throws -> SettingsActionOutcome? {
        if let preflight = plan.queuePreflightDecision(queuedMutations: contentState.queuedMutations) {
            switch preflight {
            case .queueMutation(let mutation, drainImmediately: false):
                try await queueSettingsMutationIfNeeded(mutation)
            case .queueMutation(let mutation, drainImmediately: true):
                _ = try await queueMutations([mutation], true)
            }
            return nil
        }

        var outcome: SettingsActionOutcome?
        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                outcome = try await executeSettingsActionRequest(requestBuilder, plan.responseHandling)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueSettingsMutationIfNeeded(offlineFallbackMutation)
                    return nil
                }
                throw error
            }
        }

        if let sessionOperation = plan.sessionOperation {
            try await performSettingsSessionOperation(sessionOperation)
        }

        if let handoff = plan.secureHandoff {
            openURL(handoff.url)
        }

        return outcome
    }

    private func queueSettingsMutationIfNeeded(_ mutation: NativeQueuedMutation) async throws {
        try await queueMutation(mutation)
    }

    private func notificationAPNsSettingsView(_ viewModel: NotificationAPNsSurfaceViewModel) -> some View {
        NotificationAPNsSettingsView(
            viewModel: viewModel,
            performNotificationAPNsAction: performNotificationAPNsAction,
            requestNotificationPermission: requestNotificationPermission,
            requestDeviceRegistrationAction: requestDeviceRegistrationAction,
            openNotificationSettings: openNotificationSettings
        )
    }

    private func performNotificationAPNsAction(_ plan: NotificationAPNsActionPlan) async throws {
        if let blocker = plan.deliveryBlocker {
            recordNotificationAPNsBlocker(blocker)
            return
        }

        if let preflight = plan.queuePreflightDecision(queuedMutations: contentState.queuedMutations) {
            switch preflight {
            case .queueMutation(let mutation, drainImmediately: false):
                try await queueNotificationAPNsMutationIfNeeded(mutation)
            case .queueMutation(let mutation, drainImmediately: true):
                _ = try await queueMutations([mutation], true)
            }
            return
        }

        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                _ = try await executeSettingsActionRequest(requestBuilder, .refreshOnly)
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueNotificationAPNsMutationIfNeeded(offlineFallbackMutation)
                    return
                }
                throw error
            }
        }
    }

    private func queueNotificationAPNsMutationIfNeeded(_ mutation: NativeQueuedMutation) async throws {
        try await queueMutation(mutation)
    }

    private func recordNotificationAPNsBlocker(_ blocker: AppleDeveloperProgramBlocker) {
        recordNotificationAPNsBlockerHandler(blocker)
    }

    @MainActor private func discardSpoonCookLogConflict(clientMutationID: String) async throws {
        try await discardQueuedMutation(clientMutationID)
    }

    private func hasQueuedMutation(withDependencyKey dependencyKey: String) -> Bool {
        contentState.queuedMutations.contains { mutation in
            mutation.blocksDependencyKey(dependencyKey)
        }
    }

    private func performShoppingAction(_ plan: ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome {
        try await ShoppingSurfaceMutationExecutor.perform(
            plan,
            queueMutation: queueMutation,
            executeRemoteRequest: executeRecipeEditorRequest,
            recordShoppingList: recordShoppingList
        )
    }

    private func discardRecipeEditorLocalChange(_ conflict: RecipeEditorConflict) async throws {
        try await discardQueuedMutation(conflict.localClientMutationID)
    }

    private func hasShoppingListIngredient(for recipe: Recipe) -> Bool {
        RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: contentState.shoppingList)
    }

    private var spotlightIndexIdentity: String {
        [
            contentState.spotlightIndexScope?.identifierPrefix ?? "signed-out",
            contentState.recipes.map(\.id).joined(separator: ","),
            contentState.cookbooks.map(\.id).joined(separator: ","),
            contentState.searchResultsByScope[search.scope]?.joined(separator: ",") ?? "search-unavailable",
            contentState.shoppingList?.activeItems.map(\.id).joined(separator: ",") ?? "shopping-unavailable"
        ].joined(separator: "|")
    }

    private var spotlightIndexDocuments: [SpotlightIndexDocument] {
        guard let shoppingList = contentState.shoppingList,
              let scope = contentState.spotlightIndexScope else {
            return []
        }

        return SpotlightIndexPlan.documents(
            recipes: contentState.recipes,
            cookbooks: contentState.cookbooks,
            shoppingList: shoppingList,
            scope: scope
        )
    }

    private var captureViewModel: CaptureDraftViewModel? {
        contentState.captureDraft.map(CaptureDraftViewModel.init(draft:))
    }

    private var captureImportViewModel: CaptureImportViewModel? {
        contentState.captureDraft.map {
            CaptureImportViewModel(
                draft: $0,
                connectivity: captureImportConnectivity,
                pendingRetryMutation: pendingCaptureImportMutation
            )
        }
    }

    private func recordCaptureDraft(_ draft: CaptureDraft) {
        recordCaptureDraftHandler(draft)
    }

    private func discardCaptureDraft(_ draft: CaptureDraft) async throws {
        let draftImportSource = try? draft.importSource()
        let pendingImportClientMutationIDs = contentState.queuedMutations
            .filter {
                $0.queueableKind == .recipeImportSubmit &&
                    draftImportSource != nil &&
                    $0.recipeImportSource == draftImportSource
            }
            .map(\.clientMutationID)

        for pendingImportClientMutationID in pendingImportClientMutationIDs {
            try await discardQueuedMutation(pendingImportClientMutationID)
        }

        discardCaptureDraftHandler(draft.id)
    }

    private func performCaptureImport(draft: CaptureDraft) async throws -> CaptureImportPlan {
        let clientMutationID = pendingCaptureImportMutation?.clientMutationID ?? "cm_capture_import_\(UUID().uuidString)"
        let plannedAt = timestamp()
        let viewModel = CaptureImportViewModel(
            draft: draft,
            connectivity: captureImportConnectivity,
            pendingRetryMutation: pendingCaptureImportMutation
        )
        let submitPlan = try viewModel.planSubmit(clientMutationID: clientMutationID, createdAt: plannedAt)

        if let mutation = submitPlan.offlineRetryMutation {
            try await queueCaptureImportRetryIfNeeded(mutation)
            recordCaptureImportRetryHandler(mutation)
            return submitPlan
        }

        guard let request = submitPlan.requestBuilder else {
            return submitPlan
        }

        do {
            let response = try await executeCaptureImportRequest(request)
            let completionPlan = try viewModel.planImportResult(
                response,
                clientMutationID: clientMutationID,
                createdAt: timestamp()
            )
            if let blocker = completionPlan.blocker {
                recordCaptureImportBlockerHandler(blocker)
            }
            if let drainedClientMutationID = completionPlan.drainedClientMutationID,
               pendingCaptureImportMutation?.clientMutationID == drainedClientMutationID {
                try? await discardQueuedMutation(drainedClientMutationID)
            }
            if completionPlan.captureDraftAfterCompletion == nil {
                discardCaptureDraftHandler(draft.id)
            }
            if let route = completionPlan.importedRecipeRoute {
                openRoute(route)
            }
            return completionPlan
        } catch let error as APITransportError where error.isOffline {
            let offlinePlan = try CaptureImportViewModel(draft: draft, connectivity: .offline)
                .planSubmit(clientMutationID: clientMutationID, createdAt: timestamp())
            if let mutation = offlinePlan.offlineRetryMutation {
                try await queueCaptureImportRetryIfNeeded(mutation)
                recordCaptureImportRetryHandler(mutation)
            }
            return offlinePlan
        }
    }

    private func queueCaptureImportRetryIfNeeded(_ mutation: NativeQueuedMutation) async throws {
        guard pendingCaptureImportMutation?.clientMutationID != mutation.clientMutationID else {
            return
        }
        try await queueMutation(mutation)
    }

    private static func indexSpotlightIfAvailable(documents: [SpotlightIndexDocument]) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            try? await SpoonjoySpotlightIndexer().replaceAll(documents: documents)
        }
#endif
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func safeIdentifier(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
    }
}

private struct ActiveSearchSurfaceState: Equatable {
    let identity: String
    let viewModel: SearchSurfaceViewModel
}

private struct LiveSearchRequestMarker: Equatable {
    let identity: String
    let routeIdentifier: String
}

private struct ShellPlaceholderView: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
