import SpoonjoyCore
import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    @State private var compactTabs: CompactTabNavigation
    // One cover-zoom namespace per tab stack: a cover tapped in a tab zooms into the recipe that tab pushes.
    @Namespace private var kitchenRecipeZoom
    @Namespace private var recipesRecipeZoom
    @Namespace private var cookbooksRecipeZoom
    @Namespace private var shoppingRecipeZoom
    @Namespace private var searchRecipeZoom
    @State private var activeSearch: ActiveSearchSurfaceState?
    @State private var liveSearchRequestMarker: LiveSearchRequestMarker?
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .automatic
    /// The split view's detail stack: the sidebar destination at the root and the pages opened from it pushed on top.
    @State private var splitDetail = SplitDetailNavigation()
    @State private var isSidebarCookbookContentsExpanded = true
    /// Photos chosen on create whose upload failed, by recipe ID. The recipe page shows a retry for each.
    @Environment(\.scenePhase) private var scenePhase
    /// What the chef is part-way through, for the tab bar's switcher; absent in previews and fixtures.
    @Environment(CookingNowCenter.self) private var cookingNow: CookingNowCenter?
#if os(iOS)
    /// Where the tab bar's Cooking now accessory sits on screen, while it shows.
    @State private var cookingNowAccessoryFrame: CGRect?
    /// Cook mode on the phone, kept while it closes, and where its Cook buttons are and how far open it is.
    @State private var cookSheet: CookSheet?
    @State private var cookLaunchSources = CookLaunchSources()
    @State private var compactShellAppearedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#endif
    @State private var pendingCoverUploads: [String: PendingRecipeCoverUpload] = [:]
    @State private var isRetryingCoverUpload = false
    /// Add a recipe replaces the old New Recipe form: every create entry, ⌘N and `/recipes/new` open this sheet.
    @State private var isAddRecipePresented = false
    /// What happened after a recipe row's Add to list, shown briefly over the page.
    @State private var listAddNotice: RecipeListAddNotice?
#if os(iOS)
    @State private var shellWindowSize: CGSize = .zero
    @State private var shellHingeDivision: SpreadDivision?
    @State private var spreadSidebarHiddenAt: Date?
#endif

    private let contentState: NativeShellContentState
    private let offlineIndicatorState: OfflineIndicatorState
    private let dismissOfflineIndicator: @MainActor @Sendable () -> Void
    private let queueMutation: @Sendable (NativeQueuedMutation) async throws -> Void
    private let queueMutations: @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult
    private let discardQueuedMutation: @Sendable (String) async throws -> Void
    private let retryHeldChanges: @Sendable () async -> Void
    private let resolveRecipeEditConflict: @Sendable (String, NativeRecipeEditChoice) async throws -> Void
    /// Asks the live store to sync. The store owns the sync task, so this view going away cannot cancel it.
    /// Nil only for the hermetic fixture, which supplies its own coordinator.
    private let requestSync: (@MainActor @Sendable () async -> Void)?
    private let executeRecipeEditorRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> Void
    private let executeRecipeCreateRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> String?
    private let executeSettingsActionRequest: @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?
    private let executeCaptureImportRequest: @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse
    private let performShoppingMutationHandler: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    private let shoppingMutationFeedback: ShoppingMutationFeedback?
    private let retryShoppingMutationRecovery: @MainActor @Sendable () async throws -> ShoppingSurfaceMutationOutcome
    private let performSettingsSessionOperation: @MainActor @Sendable (SettingsSessionOperation) async throws -> Void
    private let retrySync: @MainActor @Sendable () async -> Void
    private let requestNotificationPermission: @MainActor @Sendable () async throws -> APNsPermissionState
    private let requestDeviceRegistrationAction: @MainActor @Sendable (String) async throws -> NotificationAPNsAction
    private let openNotificationSettings: @MainActor @Sendable () -> Void
    private let recordNotificationAPNsBlockerHandler: @MainActor @Sendable (AppleDeveloperProgramBlocker) -> Void
    private let recordShoppingList: @MainActor @Sendable (ShoppingListState) -> Void
    private let recordCookProgress: @MainActor @Sendable (CookModeProgress) -> Void
    private let cookModeOpened: @MainActor @Sendable (String) -> Void
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
        offlineIndicatorState: OfflineIndicatorState,
        dismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void,
        queueMutation: @escaping @Sendable (NativeQueuedMutation) async throws -> Void,
        queueMutations: @escaping @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult,
        discardQueuedMutation: @escaping @Sendable (String) async throws -> Void,
        retryHeldChanges: @escaping @Sendable () async -> Void = {},
        resolveRecipeEditConflict: @escaping @Sendable (String, NativeRecipeEditChoice) async throws -> Void = { _, _ in },
        requestSync: (@MainActor @Sendable () async -> Void)? = nil,
        executeRecipeEditorRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> Void,
        executeRecipeCreateRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> String?,
        executeSettingsActionRequest: @escaping @MainActor @Sendable (APIRequestBuilder, SettingsActionResponseHandling) async throws -> SettingsActionOutcome?,
        executeCaptureImportRequest: @escaping @MainActor @Sendable (APIRequestBuilder) async throws -> RecipeImportResponse,
        performShoppingMutation: @escaping @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome,
        shoppingMutationFeedback: ShoppingMutationFeedback?,
        retryShoppingMutationRecovery: @escaping @MainActor @Sendable () async throws -> ShoppingSurfaceMutationOutcome,
        performSettingsSessionOperation: @escaping @MainActor @Sendable (SettingsSessionOperation) async throws -> Void,
        retrySync: @escaping @MainActor @Sendable () async -> Void,
        requestNotificationPermission: @escaping @MainActor @Sendable () async throws -> APNsPermissionState,
        requestDeviceRegistrationAction: @escaping @MainActor @Sendable (String) async throws -> NotificationAPNsAction,
        openNotificationSettings: @escaping @MainActor @Sendable () -> Void,
        recordNotificationAPNsBlocker: @escaping @MainActor @Sendable (AppleDeveloperProgramBlocker) -> Void,
        recordShoppingList: @escaping @MainActor @Sendable (ShoppingListState) -> Void,
        recordCookProgress: @escaping @MainActor @Sendable (CookModeProgress) -> Void,
        cookModeOpened: @escaping @MainActor @Sendable (String) -> Void = { _ in },
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
        _compactTabs = State(initialValue: CompactTabNavigation(route: navigation.wrappedValue.route))
        self.contentState = contentState
        self.offlineIndicatorState = offlineIndicatorState
        self.dismissOfflineIndicator = dismissOfflineIndicator
        self.queueMutation = queueMutation
        self.queueMutations = queueMutations
        self.discardQueuedMutation = discardQueuedMutation
        self.retryHeldChanges = retryHeldChanges
        self.resolveRecipeEditConflict = resolveRecipeEditConflict
        self.requestSync = requestSync
        self.executeRecipeEditorRequest = executeRecipeEditorRequest
        self.executeRecipeCreateRequest = executeRecipeCreateRequest
        self.executeSettingsActionRequest = executeSettingsActionRequest
        self.executeCaptureImportRequest = executeCaptureImportRequest
        self.performShoppingMutationHandler = performShoppingMutation
        self.shoppingMutationFeedback = shoppingMutationFeedback
        self.retryShoppingMutationRecovery = retryShoppingMutationRecovery
        self.performSettingsSessionOperation = performSettingsSessionOperation
        self.retrySync = retrySync
        self.requestNotificationPermission = requestNotificationPermission
        self.requestDeviceRegistrationAction = requestDeviceRegistrationAction
        self.openNotificationSettings = openNotificationSettings
        self.recordNotificationAPNsBlockerHandler = recordNotificationAPNsBlocker
        self.recordShoppingList = recordShoppingList
        self.recordCookProgress = recordCookProgress
        self.cookModeOpened = cookModeOpened
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
        .sheet(isPresented: $isAddRecipePresented) {
            AddRecipeSheet(onPasteLink: importPastedLink)
        }
        // A blank editor route (a `/recipes/new` link, a restored page, or anything else that still names it)
        // opens Add a recipe over the page the chef was on instead of a form.
        .onChange(of: navigation.route, initial: true) { previous, route in
            guard route == .recipeEditor(id: nil) else {
                return
            }
            // At launch (no previous page) the route was not a tap, so it lands on the Kitchen without a sheet.
            let isLaunch = previous == route
            navigation.navigate(to: isLaunch ? .kitchen : previous, restoring: true)
            if !isLaunch {
                isAddRecipePresented = true
            }
        }
        .overlay(alignment: .bottom) {
            if let listAddNotice {
                RecipeListAddNoticeView(notice: listAddNotice)
                    .padding(.horizontal, 16)
                    .padding(.bottom, usesCompactMobileShell ? 96 : 24)
                    .transition(.opacity)
                    .task(id: listAddNotice) {
                        try? await Task.sleep(for: .seconds(4))
                        if self.listAddNotice == listAddNotice {
                            self.listAddNotice = nil
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: listAddNotice)
        .sensoryFeedback(trigger: listAddNotice) { _, notice in
            guard let notice else {
                return nil
            }
            return notice.isFailure ? .error : .success
        }
        // ⌘N on the Mac opens Add a recipe in the focused window only.
        .focusedSceneValue(\.spoonjoyAddRecipe, createRecipe)
    }

    private var usesCompactMobileShell: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    private func compactMobileShell(spotlightPayload: SpotlightIndexPayload) -> some View {
        shellLifecycle(compactTabShellContent, spotlightPayload: spotlightPayload)
#if os(iOS)
            .environment(\.cookLaunchSources, cookLaunchSources)
            // Cook mode grows out of the Cook button it was opened from and shrinks back into it, as Music's player
            // does from its mini player. It lies over the tabs rather than replacing them, so the page and its tab bar
            // stay put underneath and are there the moment it starts to close.
            .accessibilityHidden(cookSheet != nil)
            .overlay {
                if let cookSheet {
                    CookSheetLayer(
                        sheet: cookSheet,
                        sources: cookLaunchSources,
                        reduceMotion: reduceMotion,
                        onDrag: dragCookSheet,
                        onDragEnd: endCookSheetDrag
                    ) {
                        compactFullScreenContent(for: cookSheet.route)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { closeCookSheet() }
                }
            }
            .onChange(of: compactTabs.fullScreenRoute, initial: true) { old, route in
                // Cook mode restored as the app opens is simply there; it grows only from something on screen.
                let settled = compactShellAppearedAt.map { Date.now.timeIntervalSince($0) > 1 } ?? false
                presentCookSheet(route, animated: old != route && settled)
            }
            .onChange(of: scenePhase) { _, phase in
                // Leaving the app never strands cook mode part-way: a close in flight finishes now, so a Live Activity
                // or link that brings the app back can reopen it, and a drag the system cancelled springs back open.
                if phase != .active {
                    settleCookSheet()
                }
            }
            .onAppear {
                compactShellAppearedAt = .now
            }
            .onDisappear {
                compactShellAppearedAt = nil
                // The wider shell shows cook mode in place; a card left over from the phone layout must not replay.
                cookSheet = nil
                cookLaunchSources.hiddenRecipeID = nil
                cookLaunchSources.closing = false
                cookLaunchSources.progress = 0
            }
#endif
            // Every route change, from a tap, a deep link, Spotlight or an App Intent, moves the tabs. Changes the
            // tabs made themselves come back here as the route they already show, which changes nothing.
            .onChange(of: navigation.route, initial: true) { _, route in
                // The shell turns a blank editor route into the Add a recipe sheet, so no tab pushes a form.
                guard route != .recipeEditor(id: nil) else {
                    return
                }
                compactTabs.apply(route)
                if liveSearchRequestMarker?.routeIdentifier != route.stateIdentifier {
                    liveSearchRequestMarker = nil
                }
            }
    }

    private func shellLifecycle<Content: View>(_ content: Content, spotlightPayload: SpotlightIndexPayload) -> some View {
        content
            .task(id: spotlightIndexIdentity) {
                await Self.indexSpotlightIfAvailable(payload: spotlightPayload)
            }
#if canImport(AppIntents)
            .spoonjoyEntityActivity(routeEntityIdentifier)
#endif
            .task(id: contentState.environment.rawValue) {
                // With a live store, launch and environment changes already sync through the store, so a
                // second sync here would only republish the same content under a screen the person is using.
                guard requestSync == nil else { return }
                await runForegroundSync()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if NativeSceneSyncPolicy.shouldSync(wasActive: oldPhase == .active, isActive: newPhase == .active) {
                    Task { @MainActor in
                        await runForegroundSync()
                    }
                }
            }
    }

    /// Runs the foreground sync and purges any entity indexes it reports. Also backs pull-to-refresh.
    @MainActor private func runForegroundSync() async {
        if let requestSync {
            await requestSync()
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

    @ViewBuilder private func desktopClassShell(spotlightPayload: SpotlightIndexPayload) -> some View {
        NavigationSplitView(columnVisibility: $splitColumnVisibility) {
            sidebar.navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
                .navigationTitle("Spoonjoy")
        } detail: {
            routeNavigationStack(spotlightPayload: spotlightPayload, showsToolbar: true, showsSearchChrome: true, pushes: true)
        }
        .onChange(of: navigation.route, initial: true) { previous, route in
            // The shell turns a blank editor route into the Add a recipe sheet, so the column never pushes a form.
            guard route != .recipeEditor(id: nil) else {
                return
            }
            if previous == route {
                // The split view has just appeared (at launch, or back from a compact window): start from the route
                // rather than from wherever the column was last left, so back never leads to pages the person did
                // not come from. One handler, so the order against a separate onAppear cannot matter.
                splitDetail = splitDetail.resumed(at: route)
            } else {
                splitDetail.apply(route)
            }
            // A new page, from the sidebar or anywhere else, puts away a sidebar squeezing the old one.
            dismissSidebarIfCovering()
        }
        // ⌘[ goes back a page, as the toolbar's back button does.
        .focusedSceneValue(\.spoonjoyGoBack, splitGoBackAction)
#if os(iOS)
        // An open recipe on a wide landscape screen becomes a two-page spread. The library sidebar steps aside so
        // the spread gets the whole screen and its gutter lands on the middle, where the iPhone Duo folds. The
        // sidebar button brings the library back; leaving the recipe restores the sidebar.
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            // A sidebar put away in a narrow window comes back beside the page when the window grows wide.
            let growsWide = shellWindowSize.width < Self.sidebarBesidePageMinimumWidth && size.width >= Self.sidebarBesidePageMinimumWidth
            shellWindowSize = size
            if growsWide && splitColumnVisibility == .detailOnly && !hidesLibrarySidebarForSpread {
                splitColumnVisibility = .automatic
            }
        }
        .readingHingeDivision($shellHingeDivision)
        .onChange(of: hidesLibrarySidebarForSpread, initial: true) { _, hides in
            spreadSidebarHiddenAt = hides ? Date() : nil
            splitColumnVisibility = hides ? .detailOnly : .automatic
        }
        .onChange(of: splitColumnVisibility) { _, visibility in
            // The split view settles its own columns on first layout and can show the sidebar again right after
            // we hide it. Hold the spread for that settling moment only; after it, the sidebar button wins.
            guard visibility != .detailOnly, let hiddenAt = spreadSidebarHiddenAt,
                  Date().timeIntervalSince(hiddenAt) < Self.spreadSidebarSettleInterval else {
                return
            }
            splitColumnVisibility = .detailOnly
        }
#endif
    }

#if os(iOS)
    private static var spreadSidebarSettleInterval: TimeInterval { 1 }

    private var hidesLibrarySidebarForSpread: Bool {
        let windowLayout = BookSpreadLayout.resolve(
            width: shellWindowSize.width,
            height: shellWindowSize.height,
            isRegularWidth: horizontalSizeClass == .regular,
            division: shellHingeDivision
        )
        return BookSpreadLayout.hidesLibrarySidebar(route: navigation.route, windowLayout: windowLayout)
    }
#endif

    private func focusedCookModeShell(spotlightPayload: SpotlightIndexPayload) -> some View {
        routeNavigationStack(
            spotlightPayload: spotlightPayload,
            showsToolbar: false,
            showsSearchChrome: false
        )
    }

    @ViewBuilder private func routeNavigationStack(
        spotlightPayload: SpotlightIndexPayload,
        showsToolbar: Bool,
        showsSearchChrome: Bool,
        pushes: Bool = false
    ) -> some View {
        if showsToolbar {
            searchableRouteNavigationStack(spotlightPayload: spotlightPayload, showsSearchChrome: showsSearchChrome, hidesNavigationBar: false, pushes: pushes)
                .spoonjoyToolbar(navigation: $navigation, search: $search, addRecipe: createRecipe)
        } else {
            searchableRouteNavigationStack(spotlightPayload: spotlightPayload, showsSearchChrome: showsSearchChrome, hidesNavigationBar: usesCompactMobileShell, pushes: pushes)
        }
    }

    @ViewBuilder private func searchableRouteNavigationStack(
        spotlightPayload: SpotlightIndexPayload,
        showsSearchChrome: Bool,
        hidesNavigationBar: Bool,
        pushes: Bool
    ) -> some View {
        if showsSearchChrome {
            baseRouteNavigationStack(spotlightPayload: spotlightPayload, hidesNavigationBar: hidesNavigationBar, pushes: pushes)
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
        } else {
            baseRouteNavigationStack(spotlightPayload: spotlightPayload, hidesNavigationBar: hidesNavigationBar, pushes: pushes)
        }
    }

    @ViewBuilder private func baseRouteNavigationStack(spotlightPayload: SpotlightIndexPayload, hidesNavigationBar: Bool, pushes: Bool) -> some View {
        if pushes {
            splitDetailNavigationStack(spotlightPayload: spotlightPayload)
        } else {
            swappingRouteNavigationStack(spotlightPayload: spotlightPayload, hidesNavigationBar: hidesNavigationBar)
        }
    }

    /// The split view's detail column. A page opened from another is pushed, so it has the back button, the edge
    /// swipe and the Mac's toolbar back button; the column used to swap pages and left no way back.
    private func splitDetailNavigationStack(spotlightPayload: SpotlightIndexPayload) -> some View {
        shellLifecycle(
            NavigationStack(path: splitDetailPath) {
                splitDetailPage(for: splitDetail.root)
                    // Must stay inside this NavigationStack's closure (see swappingRouteNavigationStack).
                    .navigationDestination(for: AppRoute.self) { route in
                        splitDetailPage(for: route)
                    }
            },
            spotlightPayload: spotlightPayload
        )
        .onChange(of: navigation.route) { _, route in
            if !routeKeepsSearchFocus(route) {
                isSearchFieldFocused = false
            }
            if liveSearchRequestMarker?.routeIdentifier != route.stateIdentifier {
                liveSearchRequestMarker = nil
            }
        }
    }

    private func splitDetailPage(for route: AppRoute) -> some View {
        VStack(spacing: 0) {
            destinationContent(for: route)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if shouldShowShellOfflineStatus && route == navigation.route {
                shellOfflineStatusBar
            }
        }
        .navigationTitle(regularBarTitle(for: route))
#if os(iOS)
        .navigationBarTitleDisplayMode(barShowsLargeTitle(for: route) ? .large : .inline)
        // Only where the bar shows the title large does the page's own heading step aside; the Kitchen's inline
        // "Kitchen" and a masthead page's quiet bar leave the heading in place.
        .environment(\.spoonjoyBarShowsPageTitle, barShowsLargeTitle(for: route))
#endif
    }

    private var splitDetailPath: Binding<[AppRoute]> {
        Binding(
            get: { splitDetail.path },
            set: { path in
                let route = splitDetail.setPath(path)
                if route != navigation.route {
                    navigation.navigate(to: route, restoring: true)
                }
            }
        )
    }

    private var splitGoBackAction: (() -> Void)? {
        // An editor leaves only through its Cancel or Save, which ask before dropping a draft.
        guard splitDetail.canGoBack, !splitDetail.showsEditor, !navigation.route.isCookModeActive else {
            return nil
        }
        return goBackInSplitDetail
    }

    private func goBackInSplitDetail() {
        let route = splitDetail.goBack()
        if route != navigation.route {
            navigation.navigate(to: route, restoring: true)
        }
    }

#if os(iOS)
    private var sidebarSqueezesPage: Bool {
        // Before the first layout reports a size, the window scene's width stands in, so a restored or linked page
        // that lands first still puts away a sidebar squeezing it.
        let width = shellWindowSize.width > 0 ? shellWindowSize.width : Self.windowSceneWidth
        return width > 0 && width < Self.sidebarBesidePageMinimumWidth
    }

    @MainActor private static var windowSceneWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .effectiveGeometry.coordinateSpace.bounds.width ?? 0
    }

    /// Below this window width, a sidebar beside the page squeezes it into a narrow column, so it steps aside once
    /// something is chosen; a wider window keeps it beside the page.
    private static var sidebarBesidePageMinimumWidth: CGFloat { 1000 }
#endif

    /// A sidebar that squeezes the page (an upright iPad, the open Duo, a split-screen half) steps aside once
    /// something is chosen, so the page gets the window back. In a wide window it stays beside the page.
    private func dismissSidebarIfCovering() {
#if os(iOS)
        // The split view writes a shown sidebar into the binding, so hiding it is one write. Only a shown sidebar is
        // touched: rewriting a hidden one resets the page stack mid-push.
        if sidebarSqueezesPage && (splitColumnVisibility == .all || splitColumnVisibility == .doubleColumn) {
            splitColumnVisibility = .detailOnly
        }
#endif
    }

    /// Cook mode on iPad, the open Duo and the Mac fills the window with one page, swapped in place.
    private func swappingRouteNavigationStack(spotlightPayload: SpotlightIndexPayload, hidesNavigationBar: Bool) -> some View {
        shellLifecycle(
            NavigationStack {
                regularDetailPage
                    .navigationTitle(regularBarTitle(for: navigation.route))
#if os(iOS)
                    // The Kitchen's and a recipe's photo is the title, so their bar stays inline and the photo runs under it.
                    // Cook mode opens with its own step header, as on the phone.
                    .navigationBarTitleDisplayMode(routeLeadsWithPhoto(navigation.route) || routeIsCookMode(navigation.route) ? .inline : .large)
                    .toolbar(hidesNavigationBar ? .hidden : .automatic, for: .navigationBar)
#endif
                    // Must stay inside this NavigationStack's closure: chained onto the NavigationStack value itself,
                    // SwiftUI cannot associate it with any stack and logs "navigationDestination modifier only works
                    // inside a NavigationStack" at runtime (evidence: CI run 36349596485).
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationContent(for: route)
                    }
            },
            spotlightPayload: spotlightPayload
        )
        .onChange(of: navigation.route) { _, route in
            if !routeKeepsSearchFocus(route) {
                isSearchFieldFocused = false
            }
            if liveSearchRequestMarker?.routeIdentifier != route.stateIdentifier {
                liveSearchRequestMarker = nil
            }
        }
    }

    private var compactTabShellContent: some View {
        TabView(selection: compactTabSelection) {
            Tab("Kitchen", systemImage: "house", value: CompactTab.kitchen) {
                compactTabStack(for: .kitchen).modifier(clearsCookingNowAccessory)
            }
            Tab("Recipes", systemImage: "book.closed", value: CompactTab.recipes) {
                compactTabStack(for: .recipes).modifier(clearsCookingNowAccessory)
            }
            Tab("Cookbooks", systemImage: "books.vertical", value: CompactTab.cookbooks) {
                compactTabStack(for: .cookbooks).modifier(clearsCookingNowAccessory)
            }
            Tab("Shopping", systemImage: "cart", value: CompactTab.shopping) {
                compactTabStack(for: .shopping).modifier(clearsCookingNowAccessory)
            }
            Tab("Search", systemImage: "magnifyingglass", value: CompactTab.search, role: .search) {
                compactTabStack(for: .search).modifier(clearsCookingNowAccessory)
            }
        }
#if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        // While a recipe is part-way cooked, the tab bar carries it: one tap back to its step from any tab, and a
        // menu to switch between recipes on the go. The Kitchen's own page leaves it off: its Cooking now strip is
        // already the switcher, and on the closed Duo the accessory would float over the strip's first plate.
        .modifier(CookingNowTabAccessory(isEnabled: showsCookingNowAccessory) {
            CookingNowAccessory(entries: cookingNow?.entries ?? [], resume: startCooking)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    cookingNowAccessoryFrame = frame
                }
        })
        .modifier(SearchTabActivation(focusesOnSelection: shouldAutoFocusSearchField))
#endif
        // iOS draws unselected tabs in near-black, the same as the charcoal action color, so a charcoal
        // tint made the selected tab look like every other one. Brass (4.5:1 on bone) marks the
        // selected tab, matching the web dock's brass primary button. Pages set their own action tint.
        .tint(KitchenTableTheme.brass)
        .background(KitchenTableTheme.page.ignoresSafeArea())
#if os(iOS)
        .background(DockAccessibilityIdentifiers(selection: compactTabs.selectedTab, depth: compactTabs.path(for: compactTabs.selectedTab).count))
#endif
        // ⌘[ goes back a page in a narrow window with a keyboard too.
        .focusedSceneValue(\.spoonjoyGoBack, compactGoBackAction)
    }

    private var compactGoBackAction: (() -> Void)? {
        let tab = compactTabs.selectedTab
        let path = compactTabs.path(for: tab)
        guard let top = path.last, !navigation.route.isCookModeActive else {
            return nil
        }
        switch top {
        case .recipeEditor, .recipeCoverControls:
            // An editor leaves only through its Cancel or Save, which ask before dropping a draft.
            return nil
        default:
            return { compactPath(for: tab).wrappedValue = Array(path.dropLast()) }
        }
    }

    /// The tab bar carries Cooking now on every page but the Kitchen's own, where the strip does the same job.
    private var showsCookingNowAccessory: Bool {
        guard !(cookingNow?.entries.isEmpty ?? true) else {
            return false
        }
        return compactTabs.selectedTab != .kitchen || !compactTabs.path(for: .kitchen).isEmpty
    }

    /// Each tab owns its stack, so switching tabs keeps every tab where the user left it.
    private var clearsCookingNowAccessory: ClearsBottomAccessory {
#if os(iOS)
        ClearsBottomAccessory(accessory: showsCookingNowAccessory ? cookingNowAccessoryFrame : nil)
#else
        ClearsBottomAccessory(accessory: nil)
#endif
    }

    @ViewBuilder private func compactTabStack(for tab: CompactTab) -> some View {
        let zoom = recipeZoomNamespace(for: tab)
        let stack = NavigationStack(path: compactPath(for: tab)) {
            compactTabRoot(for: tab)
                // Must stay inside this NavigationStack's closure (see swappingRouteNavigationStack).
                .navigationDestination(for: AppRoute.self) { route in
                    compactPushedPage(for: route, recipeZoom: zoom)
                }
        }
        .environment(\.recipeZoomNamespace, zoom)
#if os(iOS)
        .onScrollPhaseChange { _, _ in
            NotificationCenter.default.post(name: DockAccessibilityIdentifiers.dockMayRebuild, object: nil)
        }
#endif
        if tab == .search {
            // Only the Search tab owns the search field. Attached to the TabView, iOS also drew a
            // "Search Spoonjoy" field in the navigation bar of every other tab (it showed on a pull-down
            // of the shopping list, where it does not belong).
            stack
                .searchable(text: searchText, prompt: "Search Spoonjoy")
                .searchScopes(searchScope) {
                    ForEach(availableSearchScopes, id: \.rawValue) { scope in
                        Text(SearchSurfaceNativeChrome.title(for: scope)).tag(scope)
                    }
                }
                .onSubmit(of: .search) {
                    Task {
                        await performSearch(search)
                    }
                }
        } else {
            stack
        }
    }

    @ViewBuilder private func compactTabRoot(for tab: CompactTab) -> some View {
        let root = compactPage(for: compactTabs.root(for: tab))
            .navigationTitle(compactTabTitle(for: tab))
#if os(iOS)
            // The shopping list leads with items: its inline title leaves the room a large one would take. The
            // kitchen leads with its dish edge to edge, so its title stays out of the way too.
            .navigationBarTitleDisplayMode(tab == .shopping || tab == .kitchen ? .inline : .large)
#endif
        switch tab {
        case .kitchen:
#if os(iOS)
            root.toolbar {
                compactKitchenToolbar
            }
#else
            root
#endif
        case .recipes:
            root.safeAreaBar(edge: .top) {
                compactRecipesPicker
            }
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addRecipeButton
                }
            }
#endif
        case .cookbooks, .shopping, .search:
            root
        }
    }

    @ViewBuilder private func compactPushedPage(for route: AppRoute, recipeZoom: Namespace.ID) -> some View {
        let page = compactPage(for: route)
            .navigationTitle(compactPushedTitle(for: route))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .dockFittingClosedCover()
#endif
        if case .recipeDetail(let id, .detail) = route {
            // The recipe grows out of the cover that was tapped, and shrinks back into it on the way out.
            page.recipeZoomDestination(recipeID: id, in: recipeZoom)
        } else {
            page
        }
    }

    /// The split view's detail column swaps its page rather than pushing one, so the system zoom has no push to
    /// run on. A recipe fades in over the page it was opened from, growing slightly from it, and fades back out;
    /// under Reduce Motion it is a plain crossfade. Other route changes swap in place as before.
    private var regularDetailPage: some View {
        ZStack {
            detailContentWithShellStatus
                .id(regularDetailPageIdentity)
                .kitchenTransition(.opacity.combined(with: .scale(scale: 0.97)))
        }
        .kitchenAnimation(.zoom, value: regularDetailPageIdentity)
    }

    private var regularDetailPageIdentity: String {
        if case .recipeDetail(let id, .detail) = navigation.route {
            return "recipe:\(id)"
        }
        return "page"
    }

    private func routeIsCookMode(_ route: AppRoute) -> Bool {
        if case .recipeDetail(_, .cook) = route {
            return true
        }
        return false
    }

    /// The split view's bar title. Cook mode's bar stays quiet on iPad and the open Duo, as it does on a phone: a large
    /// "Cook" title showed on a cold open but not after a relaunch restored cook mode, and the step header already
    /// names the page. The Mac keeps it as the window title.
    private func regularBarTitle(for route: AppRoute) -> String {
#if os(iOS)
        if routeIsCookMode(route) {
            return ""
        }
        // The same titles as the phone: pages that open with their own masthead or heading (a recipe, a cookbook, a
        // chef, Chefs, Imports, Settings) keep the bar quiet rather than repeat it, and editors say what they edit.
        return compactPushedTitle(for: route)
#else
        return title(for: route)
#endif
    }

#if os(iOS)
    /// Whether the iPad's bar shows the page's title large, which then stands in for the page's own heading.
    private func barShowsLargeTitle(for route: AppRoute) -> Bool {
        !routeLeadsWithPhoto(route) && !routeIsCookMode(route) && !regularBarTitle(for: route).isEmpty
    }
#endif

    private func routeLeadsWithPhoto(_ route: AppRoute) -> Bool {
        switch route {
        case .kitchen, .recipeDetail(_, .detail):
            true
        default:
            false
        }
    }

    private func recipeZoomNamespace(for tab: CompactTab) -> Namespace.ID {
        switch tab {
        case .kitchen: kitchenRecipeZoom
        case .recipes: recipesRecipeZoom
        case .cookbooks: cookbooksRecipeZoom
        case .shopping: shoppingRecipeZoom
        case .search: searchRecipeZoom
        }
    }

    private func compactPage(for route: AppRoute) -> some View {
        destinationContent(for: route)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if route == navigation.route && shouldShowShellOfflineStatus {
                    // The Kitchen's photo runs under the status line, so the quiet line gets a paper capsule there.
                    compactOfflineStatusBar(onPhoto: route == .kitchen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            .environment(\.spoonjoyCompactNavigation, true)
            // Screens keep the charcoal action tint; only the tab bar uses brass.
            .tint(KitchenTableTheme.action)
            .background(KitchenTableTheme.page.ignoresSafeArea())
    }

    /// Mine, Saved and Everyone share the Recipes tab.
    private var compactRecipesPicker: some View {
        Picker("Recipes", selection: compactRecipesSelection) {
            Text("Mine").tag(AppRoute.recipes)
            Text("Saved").tag(AppRoute.savedRecipes)
            Text("Everyone").tag(AppRoute.everyoneRecipes)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("recipes.picker")
        .padding(.horizontal, KitchenTableTheme.pagePadding)
        .padding(.bottom, 8)
    }

    /// The persistent create entry. It opens Add a recipe, whatever page the chef is on.
    private var addRecipeButton: some View {
        Button("Add a recipe", systemImage: "plus") {
            createRecipe()
        }
        .accessibilityIdentifier("kitchen.addRecipe")
    }

    private func createRecipe() {
        isSearchFieldFocused = false
        isAddRecipePresented = true
    }

    /// A pasted link becomes a capture draft, the same draft Siri's Capture Recipe makes, and Imports opens on it.
    private func importPastedLink(_ url: URL) {
        let createdAt = ISO8601DateFormatter().string(from: Date())
        guard let draft = try? CaptureDraft.importURL(
            id: "paste-\(UUID().uuidString.lowercased())",
            url: url,
            createdAt: createdAt
        ) else {
            return
        }
        recordCaptureDraft(draft)
        openRoute(.capture)
    }

    private var compactRecipesSelection: Binding<AppRoute> {
        Binding(
            get: { compactTabs.recipesRoot },
            set: { route in
                openRoute(route)
            }
        )
    }

#if os(iOS)
    @ToolbarContentBuilder private var compactKitchenToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            addRecipeButton
            Button("Import queue", systemImage: "tray.and.arrow.down") {
                openRoute(.capture)
            }
            .accessibilityIdentifier("kitchen.imports")
            Button("Chefs", systemImage: "person.2") {
                openRoute(.chefs)
            }
            .accessibilityIdentifier("kitchen.chefs")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "person.crop.circle") {
                openRoute(.settings)
            }
            .accessibilityLabel("Account and settings")
            .accessibilityIdentifier("kitchen.account")
        }
    }

    /// Cook mode covers the tabs, like a full-screen player, so the tab bar never sits over its controls.
    private func compactFullScreenContent(for route: AppRoute) -> some View {
        NavigationStack {
            compactImmersiveRouteContent(for: route)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if case .recipeDetail(let id, .cook) = route {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") {
                                closeCookMode(id)
                            }
                            .accessibilityLabel("Close cook mode")
                            .accessibilityHint("Returns to the recipe.")
                            .accessibilityIdentifier("cook.close")
                        }
                    }
                }
        }
        .tint(KitchenTableTheme.action)
    }
#endif

    /// Cook mode's own Close: on the phone it shrinks back into its button; elsewhere it goes straight to the recipe.
    private func closeCookMode(_ id: String) {
#if os(iOS)
        if cookSheet != nil, usesCompactMobileShell {
            closeCookSheet()
            return
        }
#endif
        openRecipe(id)
    }

#if os(iOS)
    private var cookSheetAnimation: Animation {
        KitchenMotion.animation(.zoom, reduceMotion: reduceMotion)
    }

    /// Opens, swaps or closes cook mode to match the route. Closing keeps the page on screen until it has shrunk away.
    /// How far open it is lives on `cookLaunchSources`, not here, so the shell's body is not re-evaluated as it moves.
    private func presentCookSheet(_ route: AppRoute?, animated: Bool) {
        guard let route else {
            // Closed from elsewhere (a link, Spotlight, a shortcut): shrink away from wherever it is.
            guard cookSheet != nil, !cookLaunchSources.closing else { return }
            shrinkCookSheet { token in
                guard token == cookLaunchSources.closeToken, compactTabs.fullScreenRoute == nil else { return }
                finishCookSheetClose()
            }
            return
        }
        cookLaunchSources.closeToken += 1
        cookLaunchSources.closing = false
        let recipeID: String? = if case .recipeDetail(let id, _) = route { id } else { nil }
        if cookSheet?.route.stateIdentifier != route.stateIdentifier {
            // Another recipe's cook mode while one is open swaps in place; only a closed one grows from its button.
            if cookSheet == nil {
                cookLaunchSources.progress = 0
            }
            cookSheet = CookSheet(route: route, recipeID: recipeID, fallbackSource: cookSheetFallbackSource)
        }
        if let recipeID, cookLaunchSources.frames[recipeID] != nil, !reduceMotion {
            cookLaunchSources.hiddenRecipeID = recipeID
        }
        guard animated else {
            cookLaunchSources.progress = 1
            return
        }
        guard cookLaunchSources.progress == 0 else {
            withAnimation(cookSheetAnimation) {
                cookLaunchSources.progress = 1
            }
            return
        }
        // A layer that has just been added has no earlier frame to animate from, so it is put on screen at its button
        // first and grows on the next turn of the run loop.
        let token = cookLaunchSources.closeToken
        Task { @MainActor in
            guard token == cookLaunchSources.closeToken, cookSheet != nil else { return }
            withAnimation(cookSheetAnimation) {
                cookLaunchSources.progress = 1
            }
            // As the cover did: VoiceOver moves into cook mode.
            AccessibilityNotification.ScreenChanged().post()
        }
    }

    /// Where cook mode grows from when its recipe has no Cook button on screen: the tab bar's Cooking now switcher,
    /// else (nil) a pill just above the tab bar.
    private var cookSheetFallbackSource: CGRect? {
        guard showsCookingNowAccessory, let accessory = cookingNowAccessoryFrame, accessory.width > 0 else {
            return nil
        }
        return accessory
    }

    /// Closes cook mode by shrinking it back into its button first and only then going back to the recipe. Leaving the
    /// cook route rebuilds the page under it, which holds the main thread for about a third of a second; done first,
    /// that froze the card mid-flight, done after, it happens while the card already looks exactly like the button.
    private func closeCookSheet() {
        guard let sheet = cookSheet, let id = sheet.recipeID, !cookLaunchSources.closing else { return }
        shrinkCookSheet { token in
            guard token == cookLaunchSources.closeToken else { return }
            // The button takes over from the card that now looks exactly like it; the heavy part waits a beat so the
            // card's last frames reach the screen first.
            cookLaunchSources.hiddenRecipeID = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard token == cookLaunchSources.closeToken,
                      compactTabs.fullScreenRoute?.stateIdentifier == sheet.route.stateIdentifier else {
                    return
                }
                finishCookSheetClose()
                openRecipe(id)
            }
        }
    }

    /// Takes the card away once it has landed, and VoiceOver back to the page.
    private func finishCookSheetClose() {
        cookSheet = nil
        cookLaunchSources.hiddenRecipeID = nil
        cookLaunchSources.closing = false
        AccessibilityNotification.ScreenChanged().post()
    }

    /// Ends any motion at once: a close lands, anything else is fully open.
    private func settleCookSheet() {
        guard let sheet = cookSheet else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        if cookLaunchSources.closing {
            cookLaunchSources.closeToken += 1
            withTransaction(instant) {
                cookLaunchSources.progress = 0
                finishCookSheetClose()
            }
            if compactTabs.fullScreenRoute != nil, let id = sheet.recipeID {
                openRecipe(id)
            }
        } else if cookLaunchSources.progress < 1 {
            withTransaction(instant) {
                cookLaunchSources.progress = 1
            }
        }
    }

    /// Animates cook mode down to its button. The completion waits for the spring to come fully to rest, so the card is
    /// never swapped for the button a few points short of it.
    private func shrinkCookSheet(then finish: @escaping (Int) -> Void) {
        cookLaunchSources.closeToken += 1
        cookLaunchSources.closing = true
        let token = cookLaunchSources.closeToken
        withAnimation(cookSheetAnimation, completionCriteria: .removed) {
            cookLaunchSources.progress = 0
        } completion: {
            finish(token)
        }
    }

    /// A drag down from the top of cook mode shrinks it towards its button under the finger.
    /// Puts cook mode where the finger has it, stopping any spring in flight, so it can be caught while it moves.
    private func dragCookSheet(_ progress: CGFloat) {
        if cookLaunchSources.closing {
            // Caught on its way down: the close is called off, unless something else closed cook mode.
            guard compactTabs.fullScreenRoute != nil else { return }
            cookLaunchSources.closeToken += 1
            cookLaunchSources.closing = false
        }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            cookLaunchSources.progress = min(max(progress, 0), 1)
        }
    }

    /// Lets go: closes when pulled past halfway or flicked down, otherwise springs back open.
    private func endCookSheetDrag(_ progress: CGFloat, _ predictedProgress: CGFloat) {
        guard cookSheet != nil, !cookLaunchSources.closing else { return }
        if predictedProgress < 0.65 || progress < 0.5 {
            closeCookSheet()
        } else {
            withAnimation(cookSheetAnimation) {
                cookLaunchSources.progress = 1
            }
        }
    }
#endif

    private var compactTabSelection: Binding<CompactTab> {
        Binding(
            get: { compactTabs.selectedTab },
            set: { tab in
                selectCompactTab(tab)
            }
        )
    }

    private func selectCompactTab(_ tab: CompactTab) {
        let route = compactTabs.select(tab)
        if route != navigation.route {
            navigation.navigate(to: route, restoring: true)
        }
        if tab == .search, compactTabs.path(for: .search).isEmpty {
            Task {
                await performSearch(search)
            }
        }
    }

    /// The user's back taps, swipes and tab re-taps change a tab's stack; the route follows.
    private func compactPath(for tab: CompactTab) -> Binding<[AppRoute]> {
        Binding(
            get: { compactTabs.path(for: tab) },
            set: { path in
                let route = compactTabs.setPath(path, for: tab)
                if route != navigation.route {
                    navigation.navigate(to: route, restoring: true)
                }
            }
        )
    }

    private func compactTabTitle(for tab: CompactTab) -> String {
        switch tab {
        case .kitchen:
            "Kitchen"
        case .recipes:
            "Recipes"
        case .cookbooks:
            "Cookbooks"
        case .shopping:
            "Shopping List"
        case .search:
            "Search"
        }
    }

    private func compactPushedTitle(for route: AppRoute) -> String {
        switch route {
        // These pages open with their own masthead, so the bar stays quiet.
        case .recipeDetail, .cookbookDetail, .profile, .chefs, .capture, .settings:
            ""
        case .recipeEditor(nil):
            "Add a recipe"
        case .recipeEditor(.some):
            "Edit Recipe"
        case .recipeCoverControls:
            "Cover"
        default:
            title(for: route)
        }
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
             .everyoneRecipes,
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

    @ViewBuilder private func compactOfflineStatusBar(onPhoto: Bool = false) -> some View {
        if offlineIndicatorState.display.informationalOnly && onPhoto {
            OfflineStatusView(display: offlineIndicatorState.display, prominence: .quiet, onDismiss: dismissOfflineIndicator)
                .frame(minHeight: 28, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(KitchenTableTheme.raised, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if offlineIndicatorState.display.informationalOnly {
            OfflineStatusView(display: offlineIndicatorState.display, prominence: .quiet, onDismiss: dismissOfflineIndicator)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .padding(.horizontal, 4)
        } else {
            OfflineStatusView(display: offlineIndicatorState.display, onDismiss: dismissOfflineIndicator)
                .frame(maxWidth: 372, minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .center)
                .padding(.horizontal, 12)
                .background(KitchenTableTheme.raised.opacity(0.94), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(KitchenTableTheme.hairline.opacity(0.7), lineWidth: 1)
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
            .background(KitchenTableTheme.page.opacity(0.98))
            .overlay(alignment: .top) {
                Divider()
            }
    }

    private var sidebar: some View {
        List(selection: librarySidebarSelection) {
            Section {
                sidebarLink(section: .kitchen, title: "Kitchen", systemImage: "house")
                // Add sits with the recipe drawers, always one tap away, and never takes the selection.
                Button(action: createRecipe) {
                    Label("Add a recipe", systemImage: "plus.circle.fill")
                        .foregroundStyle(KitchenTableTheme.tomato)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar.addRecipe")
                sidebarLink(section: .recipes, title: "My Recipes", systemImage: "book.closed")
                sidebarLink(section: .savedRecipes, title: "Saved Recipes", systemImage: "bookmark")
                sidebarLink(section: .everyoneRecipes, title: "Everyone's Recipes", systemImage: "globe")
                // The chef's own cookbooks sit under Cookbooks like a table of contents, so a book is one tap away.
                DisclosureGroup(isExpanded: $isSidebarCookbookContentsExpanded) {
                    ForEach(sidebarCookbookEntries) { entry in
                        sidebarCookbookLink(entry)
                    }
                } label: {
                    // A disclosure group's label takes no part in the list's selection, so a tap on Cookbooks only
                    // showed or hid the books. The label chooses Cookbooks itself, and opens the books beneath it
                    // as the tap used to.
                    Button {
                        librarySidebarSelection.wrappedValue = .section(.cookbooks)
                        isSidebarCookbookContentsExpanded = true
                    } label: {
                        sidebarLink(section: .cookbooks, title: "Cookbooks", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                sidebarLink(section: .shoppingList, title: "Shopping List", systemImage: "checklist")
                sidebarLink(section: .search, title: "Kitchen Search", systemImage: "magnifyingglass")
            }
            Section("More") {
                sidebarLink(section: .chefs, title: "Chefs", systemImage: "person.2")
                sidebarLink(section: .capture, title: "Imports", systemImage: "tray.and.arrow.down")
                sidebarLink(section: .settings, title: "Settings", systemImage: "gearshape")
            }
        }
        // The selected row is brass, the Spoonjoy selection color, not the system blue.
        .tint(KitchenTableTheme.brass)
    }

    private var sidebarCookbookEntries: [LibrarySidebarCookbookEntry] {
        LibrarySidebar.cookbookEntries(cookbooks: contentState.cookbooks, currentChefID: contentState.currentChefID)
    }

    private func sidebarCookbookLink(_ entry: LibrarySidebarCookbookEntry) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .lineLimit(1)
                Text(entry.recipeCountLabel)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
        } icon: {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(KitchenTableTheme.brass)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.recipeCountLabel)")
        .tag(LibrarySidebarDestination.cookbook(id: entry.id))
    }

    @ViewBuilder private var detailContent: some View {
        destinationContent(for: navigation.route)
    }

    @ViewBuilder private func compactImmersiveRouteContent(for route: AppRoute) -> some View {
        VStack(spacing: 0) {
            if shouldShowShellOfflineStatus {
                compactOfflineStatusBar()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            destinationContent(for: route)
                .shellRefreshable(for: route) { await runForegroundSync() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KitchenTableTheme.page.ignoresSafeArea())
    }

    private func recipeDetailRoute(id: String) -> some View {
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
            onDismissOfflineIndicator: dismissOfflineIndicator,
            shellOfflineIndicatorDisplay: offlineIndicatorState.display,
        )
    }

    private func destinationContent(for route: AppRoute) -> some View {
        destinationRoute(for: route)
            // A missing page offers the way back to the recipes.
            .environment(\.spoonjoyBackToRecipes) { openRoute(.recipes) }
            // A recipe row's long-press menu adds its ingredients to the shopping list.
            .environment(\.spoonjoyAddRecipeToList, addRecipeToList)
    }

    @ViewBuilder private func destinationRoute(for route: AppRoute) -> some View {
        switch route {
        case .kitchen:
            KitchenView(
                kitchen: contentState.kitchen,
                recipes: contentState.recipes,
                cookbooks: contentState.cookbooks,
                cookProgress: { contentState.cookProgress(for: $0) },
                openRecipe: openRecipe,
                startCooking: startCooking,
                openCookbook: openCookbook,
                createRecipe: createRecipe,
                importRecipe: { openRoute(.capture) },
                seeAllRecipes: { openRoute(.recipes) }
            )
        case .recipes:
            RecipesView(
                viewModel: myRecipesCatalogViewModel,
                openRoute: openRoute,
                emptyAction: RecipesEmptyAction(title: "Add a recipe", systemImage: "plus", perform: createRecipe)
            )
        case .savedRecipes:
            SavedRecipesView(viewModel: savedRecipesCatalogViewModel, openRoute: openRoute)
        case .everyoneRecipes:
            EveryoneRecipesView(viewModel: recipeCatalogViewModel, openRoute: openRoute)
        case .recipeDetail(let id, .detail):
            VStack(spacing: 0) {
                if let held = recipeEditorConflict(for: id) {
                    HeldChangeBanner(
                        message: held.message,
                        editConflict: held.recipeEdit,
                        retry: { await retryHeldChanges() },
                        discard: { try? await discardRecipeEditorLocalChange(held) },
                        resolve: { choice in try? await resolveRecipeEditConflict(held.localClientMutationID, choice) }
                    )
                }
                if let pending = pendingCoverUploads[id] {
                    PendingCoverUploadBanner(
                        message: pending.message,
                        isRetrying: isRetryingCoverUpload,
                        retry: { await retryCoverUpload(pending) },
                        dismiss: { pendingCoverUploads[id] = nil }
                    )
                }
                recipeDetailRoute(id: id)
            }
        case .recipeDetail(let id, .cook):
            CookModeRouteView(
                recipeID: id,
                repository: recipeCatalogRepository,
                initialRecipe: recipe(id: id),
                progress: cookProgress(for:),
                progressDidChange: recordCookProgress,
                cookModeOpened: cookModeOpened,
                shoppingViewModel: shoppingViewModel,
                performShoppingAction: performShoppingAction,
                close: {
                    closeCookMode(id)
                }
            )
        case .recipeEditor(let id):
            if let editorViewModel = recipeEditorViewModel(id: id) {
                RecipeEditorView(
                    viewModel: editorViewModel,
                    mutationDidPlan: handleRecipeEditorPlan,
                    mutationsDidQueue: queueMutations,
                    conflictDidDiscardLocalChange: discardRecipeEditorLocalChange,
                    createRecipeWithPhoto: createRecipeWithPhoto,
                    close: openRoute,
                    shellOfflineIndicatorState: offlineIndicatorState,
                    onDismissOfflineIndicator: dismissOfflineIndicator
                )
                // A new identity per visit, so opening New Recipe never reuses the draft of the editor before it.
                .id(navigation.editorIdentity(for: route))
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
            ChefsView(
                repository: contentState.configuration.bearerToken != nil ? LiveChefsSurfaceRepository(configuration: contentState.configuration) : nil,
                fallbackChefs: chefProfiles.map {
                    NativeChefRef(id: $0.profile.id, username: $0.profile.username, photoURL: $0.profile.photoURL)
                },
                openRoute: openRoute
            )
        case .shoppingList:
            ShoppingWithRecipeSources(
                sources: ShoppingRecipeSources.sources(
                    for: contentState.shoppingList?.items ?? [],
                    recipes: contentState.recipes
                ),
                openRecipe: openRecipe
            ) {
                ShoppingListView(
                    viewModel: shoppingViewModel,
                    actionDidPlan: performShoppingAction,
                    shoppingMutationFeedback: shoppingMutationFeedback,
                    retryShoppingMutationRecovery: retryShoppingMutationRecovery,
                    hasRecipes: !contentState.recipes.isEmpty,
                    openSearch: openSearchFromDock,
                    createRecipe: createRecipe,
                    onDismissOfflineIndicator: dismissOfflineIndicator
                )
            }
        case .search(let query, let scope):
            let routeSearch = normalizedSearch(SearchState(query: query, scope: scope))
            SearchView(
                search: $search,
                viewModel: searchViewModel(for: routeSearch),
                openRoute: openRoute,
                recipeCovers: searchRecipeCovers,
                cookbookCovers: contentState.cookbooks.reduce(into: [:]) { covers, cookbook in
                    covers[cookbook.id] = cookbook.cover.primaryImageURL
                },
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
            ShellPlaceholderView(title: "Link Not Found", systemImage: "link.badge.plus", detail: "Open Spoonjoy from a supported recipe, cookbook, shopping, search, capture, or settings link.")
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: { search.text },
            set: { value in
                let nextSearch = normalizedSearch(SearchState(query: value, scope: search.scope))
                search.update(query: value, scope: nextSearch.scope)
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
                let nextSearch = normalizedSearch(SearchState(query: search.text, scope: scope))
                search.update(query: search.text, scope: nextSearch.scope)
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

    private var librarySidebarSelection: Binding<LibrarySidebarDestination?> {
        Binding(
            get: {
                // The column's root, not the page on top: a selection that followed each pushed page made the split
                // view reset the column, popping the page as it landed.
                LibrarySidebar.selection(
                    route: splitDetail.sidebarRoute,
                    sidebarSection: splitDetail.sidebarRoute.section ?? navigation.sidebarSelection,
                    cookbookEntries: sidebarCookbookEntries
                )
            },
            set: { destination in
                switch destination {
                case .section(let section):
                    navigateToSidebar(section)
                case .cookbook(let id):
                    isSearchFieldFocused = false
                    // A book chosen in the sidebar is a sidebar destination like the sections, so it is the root.
                    splitDetail.showRoot(.cookbookDetail(id: id))
                    navigation.navigate(to: .cookbookDetail(id: id))
                case nil:
                    break
                }
                // Choosing the page already showing changes no route, and still puts the sidebar away.
                dismissSidebarIfCovering()

            }
        )
    }

    private func sidebarLink(section: AppSection, title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .tag(LibrarySidebarDestination.section(section))
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
        case .everyoneRecipes:
            navigation.navigate(to: .everyoneRecipes)
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
        case .everyoneRecipes:
            "Everyone's Recipes"
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
            "Import queue"
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

    /// The search a request or route runs: the trimmed query, in a scope this surface offers.
    private func normalizedSearch(_ candidate: SearchState) -> SearchState {
        SearchState(
            query: candidate.query,
            scope: availableSearchScopes.contains(candidate.scope) ? candidate.scope : .all
        )
    }

    private func canApplySearchResult(identity: String, state: SearchState) -> Bool {
        contentState.searchSurfaceIdentity == identity &&
            search.route == state.route &&
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

    /// Every recipe cover the app already holds, so a search result shows the photo the Recipes list shows. The
    /// catalogs carry the lists' covers; a loaded recipe's own cover wins when both are present.
    private var searchRecipeCovers: [String: URL] {
        var covers: [String: URL] = [:]
        for page in [contentState.recipeCatalog, contentState.savedRecipesCatalog, contentState.myRecipesCatalog] {
            for summary in page.rows {
                covers[summary.id] = summary.displayCoverImageURL ?? covers[summary.id]
            }
        }
        for recipe in contentState.recipes {
            covers[recipe.id] = recipe.displayCoverImageURL ?? covers[recipe.id]
        }
        return covers
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
        // The shelf lists only the chef's own cookbooks from the account sync; the live list endpoint
        // returns every cookbook on Spoonjoy. A single cookbook still opens live, with the cache as fallback.
        return OwnCookbookSurfaceRepository(
            ownCookbooks: snapshotRepository,
            detail: FallbackCookbookSurfaceRepository(primary: liveRepository, fallback: snapshotRepository)
        )
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

            return RecipeEditorConflict(resourceID: recipeID, syncConflict: conflict)
        }

        return nil
    }

    private func createRecipeWithPhoto(_ plan: RecipeEditorMutationPlan, photo: NativeStagedMediaUpload) async throws -> AppRoute {
        guard let request = plan.remoteRequestBuilder else {
            // Offline from the start: queue the create with its photo.
            guard let queued = plan.queuedMutation else {
                throw RecipeEditorPlanningError.missingQueuedMutation
            }
            try await queueCreateWithPhoto(queued, photo: photo)
            return plan.successRoute ?? .recipes
        }
        let result: RecipeCreateWithPhotoResult
        do {
            result = try await RecipeCreateWithPhoto.run(
                photo: photo,
                clientMutationID: Self.coverUploadMutationID,
                create: { try await executeRecipeCreateRequest(request) },
                upload: performCoverAction
            )
        } catch let error as APITransportError where error.isOffline {
            // The create never reached the server: queue it with its photo. The photo uploads after the
            // create syncs.
            if let fallback = plan.offlineFallbackMutation {
                try await queueCreateWithPhoto(fallback, photo: photo)
                return plan.successRoute ?? .recipes
            }
            throw error
        }
        if case .photoPending(let pending) = result {
            pendingCoverUploads[pending.recipeID] = pending
        }
        return result.route
    }

    private func queueCreateWithPhoto(_ create: NativeQueuedMutation, photo: NativeStagedMediaUpload) async throws {
        let mutations = RecipeCreateOfflineQueue.mutations(
            create: create,
            photo: photo,
            clientMutationID: Self.coverUploadMutationID("cover-upload"),
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        _ = try await queueMutations(mutations, false)
    }

    @MainActor private func retryCoverUpload(_ pending: PendingRecipeCoverUpload) async {
        guard !isRetryingCoverUpload else {
            return
        }
        isRetryingCoverUpload = true
        defer { isRetryingCoverUpload = false }
        let result = await RecipeCreateWithPhoto.retry(
            pending,
            clientMutationID: Self.coverUploadMutationID,
            upload: performCoverAction
        )
        switch result {
        case .uploaded(let recipeID):
            pendingCoverUploads[recipeID] = nil
        case .photoPending(let stillPending):
            pendingCoverUploads[stillPending.recipeID] = stillPending
        case .createdWithoutID:
            break
        }
    }

    private nonisolated static func coverUploadMutationID(_ prefix: String) -> String {
        "\(prefix)-\(Date().timeIntervalSince1970.formatted(.number.precision(.fractionLength(0))))-\(UUID().uuidString.prefix(8).lowercased())"
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
            } catch let error as APITransportError where error.isRecipeEditConflict {
                // The recipe changed after the editor opened. The queue compares the edit with the current
                // recipe: it sends it if nobody else changed the same fields, and otherwise holds it on the
                // recipe page with both versions, for the cook to choose.
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    _ = try await queueMutations([offlineFallbackMutation], true)
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
        try await performShoppingMutationHandler(plan)
    }

    /// Adds every ingredient of a recipe, at its own yield, to the shopping list, as the recipe page's Add to list does.
    private func addRecipeToList(_ recipe: Recipe) {
        let action: ShoppingSurfaceAction = .addRecipeIngredients(
            recipeID: recipe.id,
            scaleFactor: 1,
            recipeIngredients: recipe.steps.flatMap(\.ingredients),
            clientMutationID: "shopping-recipe-\(UUID().uuidString.lowercased())"
        )
        Task {
            let notice: RecipeListAddNotice
            do {
                let plan = try shoppingViewModel.plan(action)
                let outcome = try await performShoppingAction(plan)
                notice = .added(recipeTitle: recipe.title, outcome: outcome)
            } catch {
                notice = .failed(recipeTitle: recipe.title)
            }
            listAddNotice = notice
            AccessibilityNotification.Announcement(notice.message).post()
        }
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
             .everyoneRecipes,
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

#if os(iOS)
/// Selecting the Search tab focuses its field. A capture run that asks for an unfocused search page
/// (`SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS`) keeps the system default, so the keyboard stays down.
private struct SearchTabActivation: ViewModifier {
    let focusesOnSelection: Bool

    func body(content: Content) -> some View {
        if focusesOnSelection {
            content.tabViewSearchActivation(.searchTabSelection)
        } else {
            content.tabViewSearchActivation(.automatic)
        }
    }
}
#endif

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
                .foregroundStyle(KitchenTableTheme.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

/// A short capsule over the page saying whether a recipe reached the shopping list.
private struct RecipeListAddNoticeView: View {
    let notice: RecipeListAddNotice

    var body: some View {
        Label(notice.message, systemImage: notice.isFailure ? "exclamationmark.triangle" : "checkmark.circle")
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(notice.isFailure ? KitchenTableTheme.tomato : KitchenTableTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .background(KitchenTableTheme.raised, in: Capsule())
            .overlay {
                Capsule().strokeBorder(KitchenTableTheme.hairline, lineWidth: 1)
            }
            .shadow(color: KitchenTableTheme.photoCharcoal.opacity(0.12), radius: 12, y: 4)
            .accessibilityIdentifier("shell.listAddNotice")
    }
}

#if os(iOS)
/// SwiftUI's `Tab` takes no accessibility identifier, so the dock is named through UIKit. Each `UITab` gets
/// `CompactTab.dockAccessibilityIdentifier` for its position (the TabView declares its tabs in `CompactTab.allCases`
/// order). The name goes on the `UITab` itself: UIKit rebuilds the tab bar items and buttons from it whenever the
/// dock's layout or appearance changes, and a name set only on a generated item was lost with it.
private struct DockAccessibilityIdentifiers: UIViewRepresentable {
    /// Only here so that a tab change or a push or pop, which can make UIKit rebuild the dock, runs `updateUIView` again.
    let selection: CompactTab
    let depth: Int

    /// Posted when a page's scroll phase changes: the tab bar minimizes and expands on scroll, and UIKit rebuilds the
    /// dock's buttons as it does, after the observer may have stopped.
    static let dockMayRebuild = Notification.Name("SpoonjoyDockMayRebuild")

    func makeUIView(context: Context) -> Probe {
        Probe()
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        uiView.rearm()
    }

    /// Names the tabs whenever they might have been rebuilt: on layout, on a trait change and on a tab change. Until a
    /// controller is found it retries every `retryInterval` for a few seconds, because on a slow launch the tab bar
    /// controller joins the window late. Once one is found, a main run-loop observer that runs after every Core Animation
    /// commit (where UIKit lays out the dock) names whatever the dock gained in that pass, so a button UIKit builds at any
    /// time is named before the run loop sleeps. SwiftUI owns the tab bar controller and UIKit the dock's containers, so
    /// neither's `layoutSubviews` can be overridden; the observer is the hook that follows every layout pass. It stops
    /// once every dock button has carried its name for `settleInterval` with nothing to rename, and a tab change, a push
    /// or pop, or a trait change (the moments UIKit rebuilds the dock) starts it again, so it doesn't run on every wake
    /// of the app.
    final class Probe: UIView {
        private static let retryInterval: TimeInterval = 0.1
        /// UIKit can rebuild the dock a moment after it first looks complete (a restored page settling, for one), so
        /// the observer waits this long with nothing left to rename before it stops.
        private static let settleInterval: TimeInterval = 3
        private var lastRename = Date.distantPast
        private weak var namedController: UITabBarController?
        private var retriesLeft = 50
        private var retryScheduled = false
        private var layoutObserver: CFRunLoopObserver?
        /// After `CATransaction`'s commit (order 2,000,000), where layout runs, and UIKit's after-commit handler.
        private static let afterLayoutOrder: CFIndex = 2_002_000

        override init(frame: CGRect) {
            super.init(frame: frame)
            registerForTraitChanges([
                UITraitUserInterfaceStyle.self,
                UITraitPreferredContentSizeCategory.self,
                UITraitHorizontalSizeClass.self,
                UITraitVerticalSizeClass.self
            ]) { (probe: Probe, _: UITraitCollection) in
                probe.rearm()
            }
            NotificationCenter.default.addObserver(self, selector: #selector(dockMayRebuild), name: DockAccessibilityIdentifiers.dockMayRebuild, object: nil)
        }

        /// Posted on the main thread by the pages' scroll phase changes.
        @objc private func dockMayRebuild() {
            rearm()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        isolated deinit {
            stopObservingLayout()
        }

        /// A tab or trait change can make UIKit rebuild the dock's buttons, so the observer runs again until they're named.
        func rearm() {
            if window != nil, namedController != nil {
                observeLayout()
            }
            apply()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                stopObservingLayout()
            } else if namedController != nil {
                observeLayout()
            }
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            if let namedController, Self.isNamed(namedController) {
                return
            }
            guard let root = window?.rootViewController else { return }
            var named = false
            for controller in Self.tabBarControllers(from: root) where controller.tabs.count == CompactTab.allCases.count {
                Self.name(controller)
                named = true
                namedController = controller
                observeLayout()
            }
            if !named, retriesLeft > 0, !retryScheduled {
                retriesLeft -= 1
                retryScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self] in
                    self?.retryScheduled = false
                    self?.apply()
                }
            }
        }

        private func observeLayout() {
            guard layoutObserver == nil else {
                return
            }
            let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, Self.afterLayoutOrder) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, let controller = self.namedController else {
                        return
                    }
                    let pass = Self.name(controller)
                    if pass.renamed || !pass.complete {
                        self.lastRename = .now
                    } else if Date.now.timeIntervalSince(self.lastRename) > Self.settleInterval {
                        self.stopObservingLayout()
                    }
                }
            }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            layoutObserver = observer
            lastRename = .now
        }

        private func stopObservingLayout() {
            if let layoutObserver {
                CFRunLoopObserverInvalidate(layoutObserver)
                self.layoutObserver = nil
            }
        }

        /// Names the controller's tabs if SwiftUI replaced them, and any dock button that lacks its tab's name. UIKit reads
        /// the name from the `UITab` only when it builds a button, so a button built before the tab was named keeps the
        /// image name. The walk skips the tabs' pages, where a back button can carry a tab's title; on iOS 27 the floating
        /// dock sits beside them in the controller's view, not inside `tabBar`. Reports whether every tab has a named
        /// button and whether this pass had to name anything.
        @discardableResult
        private static func name(_ controller: UITabBarController) -> (complete: Bool, renamed: Bool) {
            var renamed = false
            if !isNamed(controller) {
                renamed = true
                for (index, tab) in controller.tabs.enumerated() where index < CompactTab.allCases.count {
                    tab.accessibilityIdentifier = CompactTab.allCases[index].dockAccessibilityIdentifier
                }
            }
            var namedTabs = Set<String>()
            Self.nameBuiltButtons(in: controller.view, skipping: Set(controller.children.compactMap(\.viewIfLoaded)), tabs: controller.tabs, named: &namedTabs, renamed: &renamed)
            return (namedTabs.count == controller.tabs.count, renamed)
        }

        private static func nameBuiltButtons(in view: UIView, skipping content: Set<UIView>, tabs: [UITab], named: inout Set<String>, renamed: inout Bool) {
            guard !content.contains(view) else {
                return
            }
            if view is UIControl, let label = view.accessibilityLabel, let tab = tabs.first(where: { $0.title == label }) {
                if view.accessibilityIdentifier != tab.accessibilityIdentifier {
                    view.accessibilityIdentifier = tab.accessibilityIdentifier
                    renamed = true
                }
                named.insert(tab.identifier)
            }
            for subview in view.subviews {
                nameBuiltButtons(in: subview, skipping: content, tabs: tabs, named: &named, renamed: &renamed)
            }
        }

        private static func isNamed(_ controller: UITabBarController) -> Bool {
            controller.tabs.enumerated().allSatisfy { index, tab in
                index < CompactTab.allCases.count && tab.accessibilityIdentifier == CompactTab.allCases[index].dockAccessibilityIdentifier
            }
        }

        private static func tabBarControllers(from controller: UIViewController) -> [UITabBarController] {
            var found: [UITabBarController] = []
            if let tabs = controller as? UITabBarController {
                found.append(tabs)
            }
            for child in controller.children {
                found += tabBarControllers(from: child)
            }
            if let presented = controller.presentedViewController {
                found += tabBarControllers(from: presented)
            }
            return found
        }
    }
}
#endif

/// Gives a tab's scrolling pages room at the foot to scroll clear of the tab bar's floating accessory where the system
/// leaves it out of the safe area, as on the closed iPhone Duo, whose tabs stand in a rail at the side. Where the tab bar
/// runs along the bottom the safe area already ends above the accessory, so this adds nothing.
struct ClearsBottomAccessory: ViewModifier {
    let accessory: CGRect?
    @State private var visibleBottom: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, overlap, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY - proxy.safeAreaInsets.bottom
            } action: { bottom in
                visibleBottom = bottom
            }
    }

    private var overlap: CGFloat {
        guard let accessory, accessory.height > 0 else {
            return 0
        }
        return max(0, visibleBottom - accessory.minY + 12)
    }
}

#if os(iOS)
/// The tab bar's Cooking now switcher. Turning the accessory off per page needs iOS 26.1; the release archive targets
/// iOS 26.0, where the switcher is left off and the Kitchen strip still resumes every recipe.
private struct CookingNowTabAccessory<Accessory: View>: ViewModifier {
    let isEnabled: Bool
    @ViewBuilder let accessory: () -> Accessory

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled, content: accessory)
        } else {
            content
        }
    }
}
#endif

#if os(iOS)
/// Where each recipe's Cook button sits on screen, so cook mode can grow out of it, and which button to hide while
/// cook mode stands in for it.
@Observable
final class CookLaunchSources {
    var frames: [String: CGRect] = [:]
    var hiddenRecipeID: String?
    /// How far cook mode is open: 0 is its button, 1 the whole screen.
    var progress: CGFloat = 0
    /// True from the start of a close until the card has gone; a second close meanwhile does nothing, and a drag that
    /// catches the card calls the close off.
    var closing = false
    /// Counts closes, so a close that finishes after cook mode was reopened or replaced changes nothing.
    @ObservationIgnored var closeToken = 0
}

extension EnvironmentValues {
    @Entry var cookLaunchSources: CookLaunchSources?
}

extension View {
    /// Marks this control as where the recipe's cook mode grows from and shrinks back into.
    func cookLaunchSource(recipeID: String) -> some View {
        modifier(CookLaunchSourceMarker(recipeID: recipeID))
    }
}

private struct CookLaunchSourceMarker: ViewModifier {
    @Environment(\.cookLaunchSources) private var sources
    @State private var lastFrame: CGRect?
    let recipeID: String

    func body(content: Content) -> some View {
        content
            // Cook mode is the button for as long as it is open: one object, never the button and its page at once.
            .opacity(sources?.hiddenRecipeID == recipeID ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                lastFrame = frame
                sources?.frames[recipeID] = frame
            }
            .onDisappear {
                // The same recipe can be open in another tab; leave its button's frame alone.
                if sources?.frames[recipeID] == lastFrame {
                    sources?.frames[recipeID] = nil
                }
            }
    }
}

/// Cook mode on the phone, while it is open or closing.
struct CookSheet {
    let route: AppRoute
    let recipeID: String?
    /// Where it grows from when the recipe's Cook button is not on screen, in global coordinates; nil for a pill just
    /// above the tab bar.
    let fallbackSource: CGRect?
}

/// Cook mode laid over the tabs. It reads how far open it is and where its button is from `sources`, so only this
/// layer, not the whole shell, updates as it moves; the button's frame is read live, so it lands wherever the button
/// is now.
private struct CookSheetLayer<Content: View>: View {
    let sheet: CookSheet
    let sources: CookLaunchSources
    let reduceMotion: Bool
    let onDrag: (CGFloat) -> Void
    let onDragEnd: (CGFloat, CGFloat) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .modifier(CookSheetMorph(
                progress: sources.progress,
                source: sheet.recipeID.flatMap { sources.frames[$0] } ?? sheet.fallbackSource,
                reduceMotion: reduceMotion,
                onDrag: onDrag,
                onDragEnd: onDragEnd
            ))
    }
}

/// Grows cook mode out of its source and back. At 0 it is the Cook button (an ink capsule with its label); at 1 it is
/// the whole screen. In between it is one card: the capsule's ink and label give way to the cook page as it grows,
/// and the page rides the card's top edge at the card's scale. Under Reduce Motion it only crossfades.
struct CookSheetMorph: ViewModifier, Animatable {
    nonisolated var progress: CGFloat
    let source: CGRect?
    let reduceMotion: Bool
    let onDrag: (CGFloat) -> Void
    let onDragEnd: (CGFloat, CGFloat) -> Void

    /// How far open cook mode was when the finger caught it; nil when no drag is under way.
    @State private var caughtAt: CGFloat?
    /// How far open it is on screen this frame, for the pan to read when a finger comes down.
    @State private var onScreen = OnScreenProgress()

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Matches the display's own corners closely enough that the card meets them as it lands.
    private static let screenCornerRadius: CGFloat = 55
    /// Drags that start this far from the top shrink cook mode; lower down they belong to the page.
    private static let dragBand: CGFloat = 140

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let screen = CGRect(origin: .zero, size: proxy.size)
            let origin = proxy.frame(in: .global).origin
            let _ = onScreen.value = min(max(progress, 0), 1)
            ZStack(alignment: .topLeading) {
                if reduceMotion {
                    content
                        .frame(width: screen.width, height: screen.height)
                        .opacity(Double(min(max(progress, 0), 1)))
                } else {
                    morph(content, in: screen, origin: origin)
                }
            }
            .background(dismissDrag(in: screen, origin: origin))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private func morph(_ content: Content, in screen: CGRect, origin: CGPoint) -> some View {
        let p = min(max(progress, 0), 1)
        let start = startRect(in: screen, origin: origin)
        let card = cardRect(in: screen, origin: origin)
        let scale = card.width / screen.width
        // Capsule corners as the button, about the display's own corners on the way, and square as it settles, eased
        // rather than switched so the edge never changes in a single frame.
        let radius = min(start.height / 2 + (Self.screenCornerRadius - start.height / 2) * p, card.height / 2)
            * (1 - Self.ease(p, from: 0.9, to: 1))
        // The button's ink and label give way to the page while the card is moving, not while it idles at button size.
        let label = 1 - Self.ease(p, from: 0.02, to: 0.12)
        let ink = 1 - Self.ease(p, from: 0.06, to: 0.3)
        let page = Self.ease(p, from: 0.04, to: 0.26)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack(alignment: .topLeading) {
            // The page underneath recedes as cook mode rises over it.
            Color.black
                .opacity(0.16 * Double(p))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            ZStack(alignment: .top) {
                KitchenTableTheme.page
                content
                    .frame(width: screen.width, height: screen.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: card.width, height: card.height, alignment: .topLeading)
                    .opacity(page)
                    // Its controls answer only once it has landed: UIKit's hit areas do not follow the scaling.
                    .allowsHitTesting(p >= 0.999)
                KitchenTableTheme.ink
                    .opacity(ink)
                    .allowsHitTesting(false)
                Label("Cook", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(KitchenTableTheme.onInk)
                    .frame(width: start.width, height: start.height)
                    .opacity(label)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: card.width, height: card.height, alignment: .top)
            .clipShape(shape)
            // A soft lift while it travels, gone once it rests as the button or the screen.
            .shadow(color: .black.opacity(0.22 * Double(4 * p * (1 - p))), radius: 24, y: 8)
            .offset(x: card.minX, y: card.minY)
        }
    }

    /// Where the card is at the current progress. It widens with the spring but gains height a little behind it, and
    /// grows up from the button's bottom edge, so on the way down it is pill-shaped before it is pill-sized and lands
    /// as the button, not a box.
    private func cardRect(in screen: CGRect, origin: CGPoint, at shown: CGFloat? = nil) -> CGRect {
        let p = min(max(shown ?? progress, 0), 1)
        let start = startRect(in: screen, origin: origin)
        let width = start.width + (screen.width - start.width) * p
        let height = start.height + (screen.height - start.height) * pow(p, 1.6)
        let bottom = start.maxY + (screen.maxY - start.maxY) * p
        return CGRect(x: start.midX + (screen.midX - start.midX) * p - width / 2, y: bottom - height, width: width, height: height)
    }

    /// The source in this view's coordinates, or a pill just above the tab bar when there is none.
    private func startRect(in screen: CGRect, origin: CGPoint) -> CGRect {
        if let source, source.width > 0, source.height > 0 {
            return source.offsetBy(dx: -origin.x, dy: -origin.y)
        }
        let width = min(screen.width - 64, 280)
        return CGRect(x: (screen.width - width) / 2, y: screen.height - 140, width: width, height: 46)
    }

    /// A pull down on the card's top shrinks it under the finger, from wherever it is, even mid-flight. It is a UIKit
    /// pan on the window, because the cook page's navigation bar and scroll view would keep the touches from a
    /// SwiftUI gesture here.
    private func dismissDrag(in screen: CGRect, origin: CGPoint) -> some View {
        CookSheetPan(
            shouldBegin: { point in
                // Settled, only its top catches a pull, so the page below keeps its own scrolling; on the move, it
                // can be caught anywhere, as Music's player can.
                let shown = onScreen.value
                let card = cardRect(in: screen, origin: origin, at: shown)
                let y = point.y - origin.y
                let band = shown < 0.999 ? card.height : max(Self.dragBand * card.width / screen.width, 44)
                return y >= card.minY - 8 && y <= card.minY + band
            },
            began: {
                caughtAt = onScreen.value
            },
            changed: { translation in
                guard let caughtAt else { return }
                onDrag(caughtAt - max(translation, 0) / screen.height)
            },
            ended: { translation, velocity in
                guard let caught = caughtAt else { return }
                caughtAt = nil
                // Where a flick would carry it, as a scroll view projects its deceleration.
                let predicted = translation + velocity * 0.2
                onDragEnd(caught - max(translation, 0) / screen.height, caught - max(predicted, 0) / screen.height)
            },
            cancelled: {
                // A drag the system takes away settles open rather than leave the card part-way.
                guard caughtAt != nil else { return }
                caughtAt = nil
                onDragEnd(1, 1)
            }
        )
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// 0 before `from`, 1 after `to`, eased between.
    static func ease(_ value: CGFloat, from: CGFloat, to: CGFloat) -> Double {
        let t = min(max((value - from) / (to - from), 0), 1)
        return Double(t * t * (3 - 2 * t))
    }
}
/// The progress cook mode is drawn at, written each frame and read outside rendering.
private final class OnScreenProgress {
    var value: CGFloat = 0
}

/// A downward pan anywhere on the window that `shouldBegin` accepts, reported in points along the screen's height.
private struct CookSheetPan: UIViewRepresentable {
    let shouldBegin: (CGPoint) -> Bool
    let began: () -> Void
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat) -> Void
    let cancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PanHost {
        let view = PanHost()
        view.coordinator = context.coordinator
        context.coordinator.pan.delegate = context.coordinator
        context.coordinator.pan.addTarget(context.coordinator, action: #selector(Coordinator.handle(_:)))
        context.coordinator.update(self)
        return view
    }

    func updateUIView(_ view: PanHost, context: Context) {
        context.coordinator.update(self)
    }

    static func dismantleUIView(_ view: PanHost, coordinator: Coordinator) {
        coordinator.pan.view?.removeGestureRecognizer(coordinator.pan)
    }

    final class PanHost: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let coordinator else { return }
            coordinator.pan.view?.removeGestureRecognizer(coordinator.pan)
            window?.addGestureRecognizer(coordinator.pan)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let pan = UIPanGestureRecognizer()
        private var handlers: CookSheetPan?

        func update(_ pan: CookSheetPan) {
            handlers = pan
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let handlers, let view = recognizer.view else { return false }
            let velocity = pan.velocity(in: view)
            // Where the finger came down, not where it has got to by the time the pan is recognised.
            let location = pan.location(in: view), moved = pan.translation(in: view)
            let start = CGPoint(x: location.x - moved.x, y: location.y - moved.y)
            return velocity.y > abs(velocity.x) && handlers.shouldBegin(start)
        }

        /// The page's own scrolling and bars wait for this pan to fail, which it does at once unless the finger starts
        /// on the card's top and moves down; otherwise the page's scroll view would take the pull first.
        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            guard let window = recognizer.view, let view = other.view else { return false }
            return other is UIPanGestureRecognizer && view.isDescendant(of: window)
        }

        @objc func handle(_ recognizer: UIPanGestureRecognizer) {
            guard let handlers, let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view).y
            switch recognizer.state {
            case .began:
                handlers.began()
                handlers.changed(translation)
            case .changed:
                handlers.changed(translation)
            case .ended:
                handlers.ended(translation, recognizer.velocity(in: view).y)
            case .cancelled, .failed:
                handlers.cancelled()
            default:
                break
            }
        }
    }
}
#endif

