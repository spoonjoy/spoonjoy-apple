import SpoonjoyCore
import Foundation
import SwiftUI

#if canImport(AppIntents)
import AppIntents
#endif

struct PlatformNavigationView: View {
    private static let screenshotDisableSearchFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS"

    @Binding var navigation: AppNavigationState
    @Binding var search: SearchState

    @Environment(\.openURL) private var openURL
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isSearchPresented = false
    @State private var activeSearch: ActiveSearchSurfaceState?
    @State private var liveSearchRequestMarker: LiveSearchRequestMarker?

    private let contentState: NativeShellContentState
    private let allowsLiveEffects: Bool
    private let offlineIndicatorState: OfflineIndicatorState
    private let dismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let queueMutation: @Sendable (NativeQueuedMutation) async throws -> Void
    private let queueMutations: @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    private let discardQueuedMutation: @Sendable (String) async throws -> Void
    private let executeRecipeEditorRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> Void
    private let executeSettingsActionRequest: @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?
    private let executeCaptureImportRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse
    private let performSettingsSessionOperation: @MainActor @Sendable (SettingsSessionOperation) async throws -> Void
    private let retrySync: @MainActor @Sendable () async -> Void
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
    private let purgeShoppingEntityIndexesHandler: @Sendable (NativeShoppingEntityIndexPurgeRequest) async -> Void
    private let purgeSpoonEntityIndexesHandler: @Sendable (NativeSpoonEntityIndexPurgeRequest) async -> Void
    private let purgeCaptureDraftEntityIndexesHandler: @Sendable (NativeCaptureDraftEntityIndexPurgeRequest) async -> Void
    private let purgeChefProfileEntityIndexesHandler: @Sendable (NativeChefProfileEntityIndexPurgeRequest) async -> Void
    private let purgeRecipeCookbookEntityIndexesHandler: @Sendable (NativeRecipeCookbookEntityIndexPurgeRequest) async -> Void

    init(
        navigation: Binding<AppNavigationState>,
        search: Binding<SearchState>,
        contentState: NativeShellContentState,
        allowsLiveEffects: Bool,
        offlineIndicatorState: OfflineIndicatorState,
        dismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void,
        queueMutation: @escaping @Sendable (NativeQueuedMutation) async throws -> Void,
        queueMutations: @escaping @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        discardQueuedMutation: @escaping @Sendable (String) async throws -> Void,
        executeRecipeEditorRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> Void,
        executeSettingsActionRequest: @escaping @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?,
        executeCaptureImportRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse,
        performSettingsSessionOperation: @escaping @MainActor @Sendable (SettingsSessionOperation) async throws -> Void,
        retrySync: @escaping @MainActor @Sendable () async -> Void,
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
        syncTriggerCoordinator: NativeSyncTriggerCoordinator,
        purgeShoppingEntityIndexes: @escaping @Sendable (NativeShoppingEntityIndexPurgeRequest) async -> Void,
        purgeSpoonEntityIndexes: @escaping @Sendable (NativeSpoonEntityIndexPurgeRequest) async -> Void,
        purgeCaptureDraftEntityIndexes: @escaping @Sendable (NativeCaptureDraftEntityIndexPurgeRequest) async -> Void,
        purgeChefProfileEntityIndexes: @escaping @Sendable (NativeChefProfileEntityIndexPurgeRequest) async -> Void,
        purgeRecipeCookbookEntityIndexes: @escaping @Sendable (NativeRecipeCookbookEntityIndexPurgeRequest) async -> Void
    ) {
        _navigation = navigation
        _search = search
        self.contentState = contentState
        self.allowsLiveEffects = allowsLiveEffects
        self.offlineIndicatorState = offlineIndicatorState
        self.dismissOfflineIndicator = dismissOfflineIndicator
        self.queueMutation = queueMutation
        self.queueMutations = queueMutations
        self.discardQueuedMutation = discardQueuedMutation
        self.executeRecipeEditorRequest = executeRecipeEditorRequest
        self.executeSettingsActionRequest = executeSettingsActionRequest
        self.executeCaptureImportRequest = executeCaptureImportRequest
        self.performSettingsSessionOperation = performSettingsSessionOperation
        self.retrySync = retrySync
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
        self.purgeShoppingEntityIndexesHandler = purgeShoppingEntityIndexes
        self.purgeSpoonEntityIndexesHandler = purgeSpoonEntityIndexes
        self.purgeCaptureDraftEntityIndexesHandler = purgeCaptureDraftEntityIndexes
        self.purgeChefProfileEntityIndexesHandler = purgeChefProfileEntityIndexes
        self.purgeRecipeCookbookEntityIndexesHandler = purgeRecipeCookbookEntityIndexes
    }

    var body: some View {
        let spotlightPayload = spotlightIndexPayload
        Group {
            if navigation.route.isCookModeActive && !usesCompactMobileShell {
                focusedCookModeShell(spotlightPayload: spotlightPayload)
            } else if usesCompactMobileShell {
                compactMobileShell(spotlightPayload: spotlightPayload)
            } else {
                desktopClassShell(spotlightPayload: spotlightPayload)
            }
        }
    }

    private var usesCompactMobileShell: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    @ViewBuilder private func compactMobileShell(spotlightPayload: SpotlightIndexPayload) -> some View {
#if os(iOS)
        if routeKeepsSearchFocus(navigation.route) {
            compactMobileNavigationStack(spotlightPayload: spotlightPayload)
                .searchable(text: searchText, isPresented: $isSearchPresented, placement: .toolbarPrincipal, prompt: "Search Spoonjoy")
                .searchFocused($isSearchFieldFocused)
                .searchScopes(searchScope) {
                    ForEach(availableSearchScopes, id: \.rawValue) { scope in
                        Text(SearchSurfaceScopeGrammar.title(for: scope)).tag(scope)
                    }
                }
                .onSubmit(of: .search) {
                    Task {
                        await performSearch(search)
                    }
                }
                .onAppear {
                    focusCompactSearchFieldIfNeeded()
                }
        } else {
            compactMobileNavigationStack(spotlightPayload: spotlightPayload)
        }
#else
        compactMobileNavigationStack(spotlightPayload: spotlightPayload)
#endif
    }

    private func compactMobileNavigationStack(spotlightPayload: SpotlightIndexPayload) -> some View {
        NavigationStack {
            compactNavigationRootContent
        }
        .navigationDestination(for: AppRoute.self) { route in
            destinationContent(for: route)
        }
        .task(id: spotlightIndexIdentity) {
            await Self.indexSpotlightIfAvailable(payload: spotlightPayload)
        }
#if canImport(AppIntents)
        .spoonjoyEntityActivity(routeEntityIdentifier)
#endif
        .task(id: contentState.environment.rawValue) {
            guard allowsLiveEffects else {
                return
            }
            if let report = try? await syncTriggerCoordinator.handle(.foreground) {
                for request in report.shoppingEntityPurgeRequests {
                    await purgeShoppingEntityIndexesHandler(request)
                }
                for request in report.spoonEntityPurgeRequests {
                    await purgeSpoonEntityIndexesHandler(request)
                }
                for request in report.captureDraftEntityPurgeRequests {
                    await purgeCaptureDraftEntityIndexesHandler(request)
                }
                for request in report.chefProfileEntityPurgeRequests {
                    await purgeChefProfileEntityIndexesHandler(request)
                }
                for request in report.recipeCookbookEntityPurgeRequests {
                    await purgeRecipeCookbookEntityIndexesHandler(request)
                }
            }
        }
        .onChange(of: navigation.route) { _, route in
            if !routeKeepsSearchFocus(route) {
                isSearchFieldFocused = false
                isSearchPresented = false
            } else {
                focusCompactSearchFieldIfNeeded()
            }
            if liveSearchRequestMarker?.routeIdentifier != route.stateIdentifier {
                liveSearchRequestMarker = nil
            }
        }
    }

    @ViewBuilder private var compactNavigationRootContent: some View {
        if isRecipeEditorRoute {
            compactNavigationBaseContent
        } else {
            compactNavigationBaseContent
                .toolbar {
                    compactNavigationToolbar
                }
        }
    }

    private var compactNavigationBaseContent: some View {
        compactNavigationContent
            .navigationTitle(compactNavigationTitle(for: navigation.route))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
            .toolbarBackground(KitchenTableTheme.bone, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
#endif
    }

    @ViewBuilder private func desktopClassShell(spotlightPayload: SpotlightIndexPayload) -> some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
                .navigationTitle("Spoonjoy")
        } detail: {
            routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: true, showsSearchChrome: true)
        }
        .tint(KitchenTableTheme.charcoal)
    }

    private func focusedCookModeShell(spotlightPayload: SpotlightIndexPayload) -> some View {
        routeNavigationStack(
            spotlightPayload: spotlightPayload,
            showsToolbar: false,
            showsSearchChrome: false
        )
    }

    @ViewBuilder private func routeNavigationStack(spotlightPayload: SpotlightIndexPayload, showsToolbar: Bool, showsSearchChrome: Bool) -> some View {
        if showsToolbar {
            searchableRouteNavigationStack(spotlightPayload: spotlightPayload, showsSearchChrome: showsSearchChrome, hidesNavigationBar: false)
                .spoonjoyToolbar(navigation: $navigation, search: $search)
        } else {
            searchableRouteNavigationStack(spotlightPayload: spotlightPayload, showsSearchChrome: showsSearchChrome, hidesNavigationBar: usesCompactMobileShell)
        }
    }

    @ViewBuilder private func searchableRouteNavigationStack(
        spotlightPayload: SpotlightIndexPayload,
        showsSearchChrome: Bool,
        hidesNavigationBar: Bool
    ) -> some View {
        if showsSearchChrome {
            baseRouteNavigationStack(spotlightPayload: spotlightPayload, hidesNavigationBar: hidesNavigationBar)
                .searchable(text: searchText, prompt: "Search Spoonjoy")
                .searchFocused($isSearchFieldFocused)
                .searchScopes(searchScope) {
                    ForEach(availableSearchScopes, id: \.rawValue) { scope in
                        Text(SearchSurfaceScopeGrammar.title(for: scope)).tag(scope)
                    }
                }
                .onSubmit(of: .search) {
                    Task {
                        await performSearch(search)
                    }
                }
        } else {
            baseRouteNavigationStack(spotlightPayload: spotlightPayload, hidesNavigationBar: hidesNavigationBar)
        }
    }

    private func baseRouteNavigationStack(spotlightPayload: SpotlightIndexPayload, hidesNavigationBar: Bool) -> some View {
        NavigationStack {
            detailContentWithShellStatus
                .navigationTitle(usesCompactMobileShell ? title(for: navigation.route) : "")
#if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                .toolbar(hidesNavigationBar ? .hidden : .automatic, for: .navigationBar)
#endif
        }
        .navigationDestination(for: AppRoute.self) { route in
            destinationContent(for: route)
        }
        .task(id: spotlightIndexIdentity) {
            await Self.indexSpotlightIfAvailable(payload: spotlightPayload)
        }
#if canImport(AppIntents)
        .spoonjoyEntityActivity(routeEntityIdentifier)
#endif
        .task(id: contentState.environment.rawValue) {
            guard allowsLiveEffects else {
                return
            }
            if let report = try? await syncTriggerCoordinator.handle(.foreground) {
                for request in report.shoppingEntityPurgeRequests {
                    await purgeShoppingEntityIndexesHandler(request)
                }
                for request in report.spoonEntityPurgeRequests {
                    await purgeSpoonEntityIndexesHandler(request)
                }
                for request in report.captureDraftEntityPurgeRequests {
                    await purgeCaptureDraftEntityIndexesHandler(request)
                }
                for request in report.chefProfileEntityPurgeRequests {
                    await purgeChefProfileEntityIndexesHandler(request)
                }
                for request in report.recipeCookbookEntityPurgeRequests {
                    await purgeRecipeCookbookEntityIndexesHandler(request)
                }
            }
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

    @ViewBuilder private var compactNavigationContent: some View {
        if navigation.route.isCookModeActive || navigation.route.usesCompactAuxiliaryShell {
            compactImmersiveRouteContent(for: navigation.route)
        } else {
            compactTabShell
        }
    }

    private var compactTabShell: some View {
        compactTabShellContent
    }

    private var compactTabShellContent: some View {
        TabView(selection: compactTabSelection) {
            compactTabContent(for: .kitchen)
                .tabItem {
                    Label("Kitchen", systemImage: "house")
                }
                .tag(AppSection.kitchen)

            compactTabContent(for: .recipes)
                .tabItem {
                    Label("My Recipes", systemImage: "book.closed")
                }
                .tag(AppSection.recipes)

            compactTabContent(for: .savedRecipes)
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
                .tag(AppSection.savedRecipes)

            compactTabContent(for: .cookbooks)
                .tabItem {
                    Label("Cookbooks", systemImage: "books.vertical")
                }
                .tag(AppSection.cookbooks)

            compactTabContent(for: .shoppingList)
                .tabItem {
                    Label("Shopping List", systemImage: "checklist")
                }
                .tag(AppSection.shoppingList)
        }
        .tint(KitchenTableTheme.action)
        .background(KitchenTableTheme.bone.ignoresSafeArea())
#if os(iOS)
        .toolbarBackground(KitchenTableTheme.bone, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tabBarMinimizeBehavior(.never)
#endif
    }

    private var shouldShowShellOfflineStatus: Bool {
        guard !routeOwnsOfflineStatus(navigation.route) else {
            return false
        }
        switch offlineIndicatorState.display {
        case .synced, .dismissed:
            return false
        case .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            return true
        }
    }

    private func routeOwnsOfflineStatus(_ route: AppRoute) -> Bool {
        switch route {
        case .recipeDetail(_, .detail),
             .recipeDetail(_, .cook),
             .recipeEditor,
             .recipeCoverControls,
             .cookbooks,
             .cookbookDetail,
             .profile,
             .profileGraph,
             .capture,
             .settings,
             .shoppingList,
             .search:
            true
        case .kitchen,
             .recipes,
             .savedRecipes,
             .chefs,
             .unknownLink:
            false
        }
    }

    @ViewBuilder private var detailContentWithShellStatus: some View {
        VStack(spacing: 0) {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowShellOfflineStatus && !usesCompactMobileShell {
                shellOfflineStatusBar
            }
        }
    }

    @ViewBuilder private var compactOfflineStatusBar: some View {
        if offlineIndicatorState.display.informationalOnly {
            OfflineStatusView(display: offlineIndicatorState.display, prominence: .quiet, onDismiss: dismissOfflineIndicator)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .padding(.horizontal, 4)
        } else {
            OfflineStatusView(display: offlineIndicatorState.display, onDismiss: dismissOfflineIndicator)
                .frame(maxWidth: 372, minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .center)
                .padding(.horizontal, 12)
                .background(KitchenTableTheme.paper.opacity(0.94), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(KitchenTableTheme.line.opacity(0.7), lineWidth: 1)
                }
        }
    }

    private var shellOfflineStatusBar: some View {
        OfflineStatusView(
            display: offlineIndicatorState.display,
            prominence: offlineIndicatorState.display.informationalOnly ? .quiet : .standard,
            onDismiss: dismissOfflineIndicator
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(KitchenTableTheme.bone.opacity(0.98))
            .overlay(alignment: .top) {
                Divider()
            }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            sidebarLink(section: .kitchen, title: "Kitchen", systemImage: "house")
            sidebarLink(section: .recipes, title: "My Recipes", systemImage: "book.closed")
            sidebarLink(section: .savedRecipes, title: "Saved Recipes", systemImage: "bookmark")
            sidebarLink(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical")
            sidebarLink(section: .shoppingList, title: "Shopping List", systemImage: "checklist")
            sidebarLink(section: .chefs, title: "Chefs", systemImage: "person.2")
            sidebarLink(section: .search, title: "Kitchen Search", systemImage: "magnifyingglass")
            sidebarLink(section: .capture, title: "Imports", systemImage: "tray.and.arrow.down")
            sidebarLink(section: .settings, title: "Settings", systemImage: "gearshape")
        }
    }

    @ViewBuilder private var detailContent: some View {
        destinationContent(for: navigation.route)
    }

    @ViewBuilder private func compactImmersiveRouteContent(for route: AppRoute) -> some View {
        VStack(spacing: 0) {
            if shouldShowShellOfflineStatus {
                compactOfflineStatusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            destinationContent(for: route)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KitchenTableTheme.bone.ignoresSafeArea())
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
            RecipesView(viewModel: myRecipesCatalogViewModel, openRoute: openRoute)
        case .savedRecipes:
            SavedRecipesView(viewModel: savedRecipesCatalogViewModel, openRoute: openRoute)
        case .recipeDetail(let id, .detail):
            RecipeDetailRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                spoonRepository: spoonCookLogRepository,
                initialViewModel: recipe(id: id).map(recipeDetailScreenViewModel(for:)),
                loadingTitle: recipeLoadingTitle(id: id),
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
                performShoppingAction: performShoppingAction,
                onDismissOfflineIndicator: dismissOfflineIndicator
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
                    close: openRoute,
                    shellOfflineIndicatorState: offlineIndicatorState,
                    onDismissOfflineIndicator: dismissOfflineIndicator
                )
            } else {
                ShellPlaceholderView(title: "Recipe Editor", systemImage: "pencil", detail: "We couldn't open this recipe editor.")
            }
        case .recipeCoverControls(let id):
            RecipeCoverControlsRouteView(
                recipeID: id,
                initialRecipe: recipe(id: id),
                recipeRepository: recipeCatalogRepository,
                configuration: contentState.configuration,
                connectivity: recipeCoverControlsConnectivity,
                stagedMediaUsage: RecipeCoverPhotoStagedMediaUsage(queuedMutations: contentState.queuedMutations),
                performCoverAction: performCoverAction,
                close: {
                    openRecipe(id)
                },
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .cookbooks:
            CookbooksView(
                viewModel: cookbookSurfaceViewModel,
                openRoute: openRoute,
                performCookbookAction: performCookbookAction,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .cookbookDetail(let id):
            CookbookDetailRouteView(
                cookbookID: id,
                viewModel: cookbookSurfaceViewModel,
                openRoute: openRoute,
                performCookbookAction: performCookbookAction,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case AppRoute.profile(let identifier):
            ProfileRouteView(
                identifier: identifier,
                viewModel: profileSurfaceViewModel(identifier: identifier),
                openRoute: openRoute,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case AppRoute.profileGraph(let identifier, let direction, let page):
            ProfileGraphRouteView(
                identifier: identifier,
                direction: direction,
                page: page,
                viewModel: profileSurfaceViewModel(identifier: identifier),
                openRoute: openRoute,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .chefs:
            ChefsView(profiles: chefProfiles, openRoute: openRoute)
        case .shoppingList:
            ShoppingListView(
                viewModel: shoppingViewModel,
                actionDidPlan: performShoppingAction,
                openSearch: openSearchFromDock,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .search(let query, let scope):
            let routeSearch = normalizedSearch(SearchState(query: query, scope: scope))
            SearchView(
                search: $search,
                viewModel: searchViewModel(for: routeSearch),
                openRoute: openRoute,
                searchTask: performSearch,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
            .onAppear {
                search.apply(route: routeSearch.route)
                if routeSearch.route != navigation.route {
                    navigation.navigate(to: routeSearch.route)
                }
                if shouldAutoFocusSearchField {
                    isSearchFieldFocused = true
                }
            }
            .task(id: liveSearchTaskIdentity(for: routeSearch)) {
                await refreshRouteSearchIfNeeded(routeSearch)
            }
        case .capture:
            CaptureDraftView(
                viewModel: captureViewModel,
                importViewModel: captureImportViewModel,
                shellOfflineIndicatorState: offlineIndicatorState,
                draftDidChange: recordCaptureDraft(_:),
                draftDidDiscard: discardCaptureDraft(_:),
                importDidSubmit: performCaptureImport(draft:),
                onDismissOfflineIndicator: dismissOfflineIndicator
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
                onRetrySync: retrySync,
                onDismissOfflineIndicator: dismissOfflineIndicator
            )
        case .unknownLink:
            ShellPlaceholderView(
                title: "Link Not Found",
                systemImage: "link.badge.plus",
                detail: "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.",
                screenshotRoute: "unknown-link",
                screenshotSource: "ShellPlaceholderView",
                accessibilityIdentifier: "unknown-link.message"
            )
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

    private var shouldAutoFocusSearchField: Bool {
#if DEBUG
        guard let rawValue = ProcessInfo.processInfo.environment[Self.screenshotDisableSearchFocusEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return true
        }
        return !["1", "true", "yes"].contains(rawValue.lowercased())
#else
        return true
#endif
    }

    private func focusCompactSearchFieldIfNeeded() {
        guard usesCompactMobileShell,
              routeKeepsSearchFocus(navigation.route),
              shouldAutoFocusSearchField else {
            return
        }
        isSearchFieldFocused = true
        isSearchPresented = true
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

    private var compactTabSelection: Binding<AppSection> {
        Binding(
            get: { compactTabSection(for: navigation.route) },
            set: { section in
                navigateToCompactTab(section)
            }
        )
    }

    @ViewBuilder private func compactTabContent(for section: AppSection) -> some View {
        VStack(spacing: 0) {
            if shouldShowShellOfflineStatus && section == compactTabSection(for: navigation.route) {
                compactOfflineStatusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            destinationContent(for: compactPresentedRoute(for: section))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.spoonjoyCompactNavigation, true)
                .safeAreaPadding(.bottom, KitchenTableTheme.compactTabBarContentInset)
        }
        .background(KitchenTableTheme.bone)
    }

    private func compactPresentedRoute(for section: AppSection) -> AppRoute {
        compactTabSection(for: navigation.route) == section
            ? navigation.route
            : compactRootRoute(for: section)
    }

    private func compactRootRoute(for section: AppSection) -> AppRoute {
        switch section {
        case .kitchen:
            .kitchen
        case .recipes:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .chefs:
            .chefs
        case .search:
            normalizedSearch(search).route
        case .capture:
            .capture
        case .settings:
            .settings
        }
    }

    private func compactTabSection(for route: AppRoute) -> AppSection {
        switch route {
        case .kitchen:
            .kitchen
        case .recipes, .recipeDetail, .recipeEditor, .recipeCoverControls:
            .recipes
        case .savedRecipes:
            .savedRecipes
        case .cookbooks, .cookbookDetail:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .search:
            .kitchen
        case .chefs, .profile, .profileGraph:
            .chefs
        case .capture, .settings, .unknownLink:
            .kitchen
        }
    }

    private func navigateToCompactTab(_ section: AppSection) {
        if section != .search {
            isSearchFieldFocused = false
        }
        switch section {
        case .kitchen:
            navigation.navigate(to: .kitchen)
        case .recipes:
            navigation.navigate(to: .recipes)
        case .savedRecipes:
            navigation.navigate(to: .savedRecipes)
        case .cookbooks:
            navigation.navigate(to: .cookbooks)
        case .shoppingList:
            navigation.navigate(to: .shoppingList)
        case .chefs:
            navigation.navigate(to: .chefs)
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

    @ToolbarContentBuilder private var compactNavigationToolbar: some ToolbarContent {
#if os(iOS)
        if let backAction = compactBackAction(for: navigation.route) {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    openRoute(backAction.route)
                } label: {
                    Label(backAction.title, systemImage: "chevron.backward")
                }
                .accessibilityLabel(backAction.accessibilityLabel)
            }
        }

        if !isRecipeEditorRoute {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Imports", systemImage: "tray.and.arrow.down") {
                        openRoute(.capture)
                    }
                    Button("Chefs", systemImage: "person.2") {
                        openRoute(.chefs)
                    }
                    Button("Search", systemImage: "magnifyingglass") {
                        Task {
                            await performSearch(search)
                        }
                    }
                    Button("Settings", systemImage: "gearshape") {
                        openRoute(.settings)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(
                            width: KitchenTableTheme.minimumTouchTarget,
                            height: KitchenTableTheme.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .frame(
                    width: KitchenTableTheme.minimumTouchTarget,
                    height: KitchenTableTheme.minimumTouchTarget
                )
                .contentShape(Rectangle())
                .accessibilityLabel("More")
                .tint(KitchenTableTheme.charcoal)
            }
        }
#else
        ToolbarItem(placement: .automatic) {
            EmptyView()
        }
#endif
    }

    private var isRecipeEditorRoute: Bool {
        if case .recipeEditor = navigation.route {
            true
        } else {
            false
        }
    }

    private func compactBackAction(for route: AppRoute) -> (title: String, accessibilityLabel: String, route: AppRoute)? {
        switch route {
        case .recipeDetail(let id, .cook):
            (title: "Recipe", accessibilityLabel: "Back to recipe", route: .recipeDetail(id: id, presentation: .detail))
        case .recipeDetail(_, .detail), .recipeEditor, .recipeCoverControls:
            (title: "My Recipes", accessibilityLabel: "Back to My Recipes", route: .recipes)
        case .cookbookDetail:
            (title: "Cookbooks", accessibilityLabel: "Back to Cookbooks", route: .cookbooks)
        case .profile, .profileGraph:
            (title: "Chefs", accessibilityLabel: "Back to Chefs", route: .chefs)
        case .capture, .settings, .unknownLink:
            (title: "Kitchen", accessibilityLabel: "Back to Kitchen", route: .kitchen)
        case .kitchen, .recipes, .savedRecipes, .cookbooks, .shoppingList, .chefs, .search:
            nil
        }
    }

    private func openSearchFromDock() {
        Task {
            await performSearch(search)
        }
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
        case .savedRecipes:
            navigation.navigate(to: .savedRecipes)
        case .cookbooks:
            navigation.navigate(to: .cookbooks)
        case .shoppingList:
            navigation.navigate(to: .shoppingList)
        case .chefs:
            navigation.navigate(to: .chefs)
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
        case .recipeDetail(_, .cook):
            "Cook"
        case .recipes:
            "My Recipes"
        case .savedRecipes:
            "Saved Recipes"
        case .recipeDetail(_, .detail), .recipeEditor, .recipeCoverControls:
            "Recipes"
        case .cookbooks, .cookbookDetail:
            "Cookbooks"
        case .chefs:
            "Chefs"
        case .profile:
            "Profile"
        case .profileGraph(_, let direction, _):
            direction == .fellowChefs ? "Fellow Chefs" : "Kitchen Visitors"
        case .shoppingList:
            "Shopping List"
        case .search:
            "Kitchen Search"
        case .capture:
            "Imports"
        case .settings:
            "Settings"
        case .unknownLink:
            "Unknown Link"
        }
    }

    private func compactNavigationTitle(for route: AppRoute) -> String {
        switch route {
        case .kitchen:
            ""
        default:
            title(for: route)
        }
    }

    private func recipe(id: String) -> Recipe? {
        contentState.recipes.first { $0.id == id }
    }

    private func recipeLoadingTitle(id: String) -> String? {
        if let recipe = recipe(id: id) {
            return recipe.title
        }
        let routeSearch = normalizedSearch(search)
        return searchViewModel(for: routeSearch)
            .sections
            .flatMap(\.rows)
            .first { row in
                if case .recipeDetail(let rowID, .detail) = row.openRoute {
                    rowID == id
                } else {
                    false
                }
            }?
            .title
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
        guard allowsLiveEffects else {
            liveSearchRequestMarker = nil
            activeSearch = ActiveSearchSurfaceState(
                identity: identity,
                viewModel: contentState.performSearch(nextSearch)
            )
            return
        }
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

    private var myRecipesCatalogRepository: any RecipeCatalogRepository {
        personalRecipeCatalogRepository(page: contentState.myRecipesCatalog)
    }

    private var myRecipesCatalogViewModel: RecipeCatalogViewModel {
        let viewModel = RecipeCatalogViewModel(repository: myRecipesCatalogRepository)
        viewModel.apply(page: contentState.myRecipesCatalog)
        return viewModel
    }

    private var savedRecipesCatalogRepository: any RecipeCatalogRepository {
        personalRecipeCatalogRepository(page: contentState.savedRecipesCatalog)
    }

    private var savedRecipesCatalogViewModel: RecipeCatalogViewModel {
        let viewModel = RecipeCatalogViewModel(repository: savedRecipesCatalogRepository)
        viewModel.apply(page: contentState.savedRecipesCatalog)
        return viewModel
    }

    private func personalRecipeCatalogRepository(page: RecipeCatalogPage) -> any RecipeCatalogRepository {
        let savedRecipeIDs = Set(page.rows.map(\.id))
        return SnapshotRecipeCatalogRepository(
            page: page,
            details: contentState.recipes
                .filter { savedRecipeIDs.contains($0.id) }
                .map { RecipeCatalogDetailResult(recipe: $0, source: page.source) }
        )
    }

    private var chefProfiles: [NativeCachedProfile] {
        var profilesByID: [String: NativeCachedProfile] = [:]
        var orderedIDs: [String] = []

        func append(_ profile: NativeCachedProfile) {
            guard profile.profile.id != currentChefID,
                  profilesByID[profile.profile.id] == nil else {
                return
            }
            profilesByID[profile.profile.id] = profile
            orderedIDs.append(profile.profile.id)
        }

        for profile in contentState.cachedProfiles {
            append(profile)
        }

        for chef in contentState.recipes.map(\.chef) + contentState.cookbooks.map(\.chef) {
            append(profileCandidate(chef: chef))
        }

        return orderedIDs.compactMap { profilesByID[$0] }
    }

    private func profileCandidate(chef: ChefSummary) -> NativeCachedProfile {
        let encodedUsername = AppRoute.encodedProfileIdentifier(chef.username)
        let href = "/users/\(encodedUsername)"
        return NativeCachedProfile(
            profile: ProfileSummary(
                id: chef.id,
                username: chef.username,
                photoURL: chef.photoURL,
                joinedLabel: "Joined Spoonjoy",
                href: href,
                canonicalURL: URL(string: "https://spoonjoy.app\(href)")!
            ),
            source: .cache(serverRevision: latestRecipeRevision, lastValidatedAt: .distantPast)
        )
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
        if !allowsLiveEffects || offlineIndicatorState.display == .offline {
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
            openNotificationSettings: openNotificationSettings,
            onDismissOfflineIndicator: dismissOfflineIndicator
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
        let payload = spotlightIndexPayload
        return Self.spotlightIdentityComponent(
            [contentState.spotlightIndexScope?.identifierPrefix ?? "signed-out"] +
                payload.documents.map { document in
                    Self.spotlightIdentityComponent([
                        document.uniqueIdentifier,
                        document.domainIdentifier,
                        document.title,
                        document.contentDescription,
                        document.keywords.joined(separator: ","),
                        document.route.stateIdentifier
                    ])
                }
        )
    }

    private var spotlightIndexDocuments: [SpotlightIndexDocument] {
        spotlightIndexPayload.documents
    }

    private var spotlightIndexPayload: SpotlightIndexPayload {
        guard let shoppingList = contentState.shoppingList,
              let scope = contentState.spotlightIndexScope else {
            return .empty
        }

        let spoonScope = SpoonEntityScope(accountID: scope.accountID, environment: scope.environment)
        let recentSpoons = contentState.recipes.flatMap { recipe in
            recipe.recentSpoons.compactMap { spoon -> SpoonEntityDescriptor? in
                guard spoon.deletedAt == nil else {
                    return nil
                }
                return SpoonEntityDescriptor(spoon: spoon, recipe: recipe, scope: spoonScope)
            }
        }
        let captureDrafts = contentState.captureDraft.map { draft in
            [
                CaptureDraftEntityDescriptor(
                    draft: draft,
                    scope: CaptureDraftEntityScope(accountID: scope.accountID, environment: scope.environment),
                    hasPendingImport: pendingCaptureImportMutation != nil,
                    pendingImport: pendingCaptureImportMutation
                )
            ]
        } ?? []
        let chefProfiles = contentState.cachedProfiles.map { cachedProfile in
            let profile = cachedProfile.profile
            let route = AppRoute.profile(identifier: profile.username)
            let summary = "\(profile.username) on Spoonjoy"
            return ChefProfileEntityDescriptor(
                id: profile.id,
                profileID: profile.id,
                username: profile.username,
                title: profile.username,
                subtitle: profile.joinedLabel,
                disambiguationLabel: summary,
                route: route,
                canonicalURL: profile.canonicalURL,
                photoURL: profile.photoURL,
                fellowChefsCount: 0,
                kitchenVisitorsCount: 0,
                interactionSummary: nil,
                transferValue: ChefProfileEntityTransferValue(
                    kind: .chefProfile,
                    profileID: profile.id,
                    username: profile.username,
                    title: profile.username,
                    routeIdentifier: route.stateIdentifier,
                    canonicalURL: profile.canonicalURL,
                    photoURL: profile.photoURL,
                    userVisibleSummary: summary
                )
            )
        }
        let shoppingScope = ShoppingEntityScope(accountID: scope.accountID, environment: scope.environment)
        let shoppingListEntity = ShoppingListEntityDescriptor(scope: shoppingScope, activeItems: shoppingList.activeItems)
        let shoppingItems = shoppingList.activeItems.map { item in
            ShoppingItemEntityDescriptor(item: item, scope: shoppingScope)
        }
        let documents = SpotlightIndexPlan.documents(
            recipes: contentState.recipes,
            cookbooks: contentState.cookbooks,
            shoppingList: shoppingList,
            spoons: recentSpoons,
            captureDrafts: captureDrafts,
            chefProfiles: chefProfiles,
            scope: scope
        )

        let recipeCookbookScope = RecipeCookbookEntityScope(accountID: scope.accountID, environment: scope.environment)
        return SpotlightIndexPayload(
            scope: scope,
            documents: documents,
            recipes: contentState.recipes.compactMap { try? RecipeEntityDescriptor(recipe: $0, scope: recipeCookbookScope) },
            cookbooks: contentState.cookbooks.compactMap { try? CookbookEntityDescriptor(cookbook: $0, scope: recipeCookbookScope) },
            shoppingLists: [shoppingListEntity],
            shoppingItems: shoppingItems,
            spoons: recentSpoons,
            captureDrafts: captureDrafts,
            chefProfiles: chefProfiles
        )
    }

#if canImport(AppIntents)
    private var routeEntityIdentifier: EntityIdentifier? {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            return nil
        }

        switch navigation.route {
        case .recipeDetail(let id, _):
            guard let scope = contentState.spotlightIndexScope else {
                return nil
            }
            return EntityIdentifier(
                for: SpoonjoyRecipeEntity.self,
                identifier: RecipeCookbookEntityCatalog.recipeEntityIdentifier(
                    recipeID: id,
                    accountID: scope.accountID,
                    environment: scope.environment
                )
            )
        case .cookbookDetail(let id):
            guard let scope = contentState.spotlightIndexScope else {
                return nil
            }
            return EntityIdentifier(
                for: SpoonjoyCookbookEntity.self,
                identifier: RecipeCookbookEntityCatalog.cookbookEntityIdentifier(
                    cookbookID: id,
                    accountID: scope.accountID,
                    environment: scope.environment
                )
            )
        case .profile(let identifier), .profileGraph(let identifier, _, _):
            guard let profileID = chefProfileEntityIdentifier(for: identifier) else {
                return nil
            }
            return EntityIdentifier(for: SpoonjoyChefProfileEntity.self, identifier: profileID)
        case .shoppingList:
            guard let scope = contentState.spotlightIndexScope else {
                return nil
            }
            return EntityIdentifier(
                for: SpoonjoyShoppingListEntity.self,
                identifier: ShoppingEntityCatalog.shoppingListEntityIdentifier(
                    accountID: scope.accountID,
                    environment: scope.environment
                )
            )
        case .capture:
            guard let scope = contentState.spotlightIndexScope,
                  let draft = contentState.captureDraft else {
                return nil
            }
            return EntityIdentifier(
                for: SpoonjoyCaptureDraftEntity.self,
                identifier: CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
                    draftID: draft.id,
                    accountID: scope.accountID,
                    environment: scope.environment
                )
            )
        case .kitchen,
             .recipes,
             .savedRecipes,
             .chefs,
             .cookbooks,
             .recipeEditor,
             .recipeCoverControls,
             .search,
             .settings,
             .unknownLink:
            return nil
        }
    }

    private func chefProfileEntityIdentifier(for routeIdentifier: String) -> String? {
        contentState.cachedProfiles.first { cachedProfile in
            cachedProfile.profile.id == routeIdentifier || cachedProfile.profile.username == routeIdentifier
        }?.profile.id
    }
#endif

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

    private static func indexSpotlightIfAvailable(payload: SpotlightIndexPayload) async {
#if canImport(CoreSpotlight)
        if #available(iOS 27.0, macOS 27.0, *) {
            let indexer = SpoonjoySpotlightIndexer()
            try? await indexer.replaceAll(payload.documents, scope: payload.scope)
            try? await indexer.replaceAllAppEntities(
                recipes: payload.recipes.map(SpoonjoyRecipeEntity.init),
                cookbooks: payload.cookbooks.map(SpoonjoyCookbookEntity.init),
                shoppingLists: payload.shoppingLists.map(SpoonjoyShoppingListEntity.init),
                shoppingItems: payload.shoppingItems.map(SpoonjoyShoppingItemEntity.init),
                spoons: payload.spoons.map(SpoonjoySpoonEntity.init),
                captureDrafts: payload.captureDrafts.map(SpoonjoyCaptureDraftEntity.init),
                chefProfiles: payload.chefProfiles.map(SpoonjoyChefProfileEntity.init)
            )
        }
#endif
    }

    private static func spotlightIdentityComponent(_ values: [String]) -> String {
        values.map { "\($0.count):\($0)" }.joined(separator: "")
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

private struct SpotlightIndexPayload {
    let scope: SpotlightIndexScope
    let documents: [SpotlightIndexDocument]
    let recipes: [RecipeEntityDescriptor]
    let cookbooks: [CookbookEntityDescriptor]
    let shoppingLists: [ShoppingListEntityDescriptor]
    let shoppingItems: [ShoppingItemEntityDescriptor]
    let spoons: [SpoonEntityDescriptor]
    let captureDrafts: [CaptureDraftEntityDescriptor]
    let chefProfiles: [ChefProfileEntityDescriptor]

    static let empty = SpotlightIndexPayload(
        scope: SpotlightIndexScope(accountID: "signed-out", environment: .production),
        documents: [],
        recipes: [],
        cookbooks: [],
        shoppingLists: [],
        shoppingItems: [],
        spoons: [],
        captureDrafts: [],
        chefProfiles: []
    )
}

#if canImport(AppIntents)
private extension View {
    func spoonjoyEntityActivity(_ entityIdentifier: EntityIdentifier?) -> some View {
        userActivity("app.spoonjoy.entity", isActive: entityIdentifier != nil) { activity in
            activity.appEntityIdentifier = entityIdentifier
        }
    }
}
#endif

private extension AppRoute {
    var usesCompactAuxiliaryShell: Bool {
        switch self {
        case .chefs, .profile, .profileGraph, .search, .capture, .settings, .unknownLink:
            true
        case .kitchen,
             .recipes,
             .savedRecipes,
             .recipeDetail,
             .recipeEditor,
             .recipeCoverControls,
             .cookbooks,
             .cookbookDetail,
             .shoppingList:
            false
        }
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
    var screenshotRoute: String? = nil
    var screenshotSource: String? = nil
    var accessibilityIdentifier: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title)
            Text(detail)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .task(id: screenshotRoute) {
            guard let screenshotRoute, let screenshotSource else { return }
            await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                route: screenshotRoute,
                source: screenshotSource,
                runtimeContext: ScreenshotAccessibilityRuntimeContext(
                    dynamicTypeSize: String(describing: dynamicTypeSize),
                    reduceMotionEnabled: accessibilityReduceMotion
                )
            )
        }
    }
}
