import Combine
import Foundation
#if canImport(OSLog)
import OSLog
#endif

public typealias NativeSettingsSurfaceFetchOperation = @Sendable (
    _ accountID: String,
    _ environment: NativeCacheEnvironment,
    _ configuration: APIClientConfiguration,
    _ cache: NativeDurableCache,
    _ grantedScopes: Set<String>
) async throws -> SettingsSurfaceResult

public struct NativeShoppingEntityIndexPurgeRequest: Equatable, Sendable {
    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let accountID: String?
    public let environment: NativeCacheEnvironment?

    public init(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.accountID = accountID
        self.environment = environment
    }

    public var isEmpty: Bool {
        identifiers.isEmpty && domainIdentifiers.isEmpty
    }
}

public typealias NativeShoppingEntityIndexPurgeOperation = @Sendable (_ request: NativeShoppingEntityIndexPurgeRequest) async -> Void

public struct NativeSpoonEntityIndexPurgeRequest: Equatable, Sendable {
    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let accountID: String?
    public let environment: NativeCacheEnvironment?

    public init(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.accountID = accountID
        self.environment = environment
    }

    public var isEmpty: Bool {
        identifiers.isEmpty && domainIdentifiers.isEmpty
    }
}

public typealias NativeSpoonEntityIndexPurgeOperation = @Sendable (_ request: NativeSpoonEntityIndexPurgeRequest) async -> Void

public struct NativeCaptureDraftEntityIndexPurgeRequest: Equatable, Sendable {
    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let accountID: String?
    public let environment: NativeCacheEnvironment?

    public init(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.accountID = accountID
        self.environment = environment
    }

    public var isEmpty: Bool {
        identifiers.isEmpty && domainIdentifiers.isEmpty
    }
}

public typealias NativeCaptureDraftEntityIndexPurgeOperation = @Sendable (_ request: NativeCaptureDraftEntityIndexPurgeRequest) async -> Void

public struct NativeChefProfileEntityIndexPurgeRequest: Equatable, Sendable {
    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let accountID: String?
    public let environment: NativeCacheEnvironment?

    public init(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.accountID = accountID
        self.environment = environment
    }

    public var isEmpty: Bool {
        identifiers.isEmpty && domainIdentifiers.isEmpty
    }
}

public typealias NativeChefProfileEntityIndexPurgeOperation = @Sendable (_ request: NativeChefProfileEntityIndexPurgeRequest) async -> Void

public struct NativeRecipeCookbookEntityIndexPurgeRequest: Equatable, Sendable {
    public let identifiers: [String]
    public let domainIdentifiers: [String]
    public let accountID: String?
    public let environment: NativeCacheEnvironment?

    public init(
        identifiers: [String],
        domainIdentifiers: [String],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) {
        self.identifiers = identifiers
        self.domainIdentifiers = domainIdentifiers
        self.accountID = accountID
        self.environment = environment
    }

    public var isEmpty: Bool {
        identifiers.isEmpty && domainIdentifiers.isEmpty
    }
}

public typealias NativeRecipeCookbookEntityIndexPurgeOperation = @Sendable (_ request: NativeRecipeCookbookEntityIndexPurgeRequest) async -> Void
public typealias NativeTelemetryReportOperation = @Sendable (_ event: NativeTelemetryEvent, _ configuration: APIClientConfiguration) async -> Void

public enum NativeLiveAppBootstrapMode: Equatable, Sendable {
    case liveFirst
    case restoreCacheOnly
}

public struct NativeLiveAppStoreDependencies {
    public let authSessionRepository: NativeAuthSessionRepository
    public let cacheStore: NativeDurableCacheStore
    public let syncStore: any NativeSyncStore
    public let syncEngine: NativeSyncEngine
    public let syncTriggerCoordinator: NativeSyncTriggerCoordinator
    public let appStateStoreProvider: @MainActor () -> NativeAppStateStore?
    public let configuration: APIClientConfiguration
    public let cacheEnvironment: NativeCacheEnvironment
    public let fixtureFallbackPolicy: NativeFixtureFallbackPolicy
    public let recipeEditorAPITransport: @Sendable (any APIAuthenticationRefresher) -> any SpoonjoyAPITransport
    public let settingsSurfaceFetch: NativeSettingsSurfaceFetchOperation?
    public let stagedMediaDirectory: NativeStagedMediaDirectory?
    public let shoppingEntityIndexPurge: NativeShoppingEntityIndexPurgeOperation
    public let spoonEntityIndexPurge: NativeSpoonEntityIndexPurgeOperation
    public let captureDraftEntityIndexPurge: NativeCaptureDraftEntityIndexPurgeOperation
    public let chefProfileEntityIndexPurge: NativeChefProfileEntityIndexPurgeOperation
    public let recipeCookbookEntityIndexPurge: NativeRecipeCookbookEntityIndexPurgeOperation
    public let nativeTelemetryReport: NativeTelemetryReportOperation
    public let nativeTelemetryMetadata: NativeTelemetryAppMetadata
    public let bootstrapMode: NativeLiveAppBootstrapMode
    /// Makes the client that exchanges cook progress with the server, for a signed-in configuration.
    public let cookSessionClient: @Sendable (APIClientConfiguration) -> any CookSessionClient
    /// How long a change to cook progress waits for more changes before a sync is requested.
    public let cookSessionPushDelay: Duration
    public let now: @Sendable () -> Date

    public init(
        authSessionRepository: NativeAuthSessionRepository,
        cacheStore: NativeDurableCacheStore,
        syncStore: any NativeSyncStore,
        syncEngine: NativeSyncEngine,
        syncTriggerCoordinator: NativeSyncTriggerCoordinator,
        appStateStoreProvider: @escaping @MainActor () -> NativeAppStateStore?,
        configuration: APIClientConfiguration,
        cacheEnvironment: NativeCacheEnvironment,
        fixtureFallbackPolicy: NativeFixtureFallbackPolicy = .disabledInProduction,
        recipeEditorAPITransport: @escaping @Sendable (any APIAuthenticationRefresher) -> any SpoonjoyAPITransport = { refresher in
            URLSessionAPITransport(authenticationRefresher: refresher)
        },
        settingsSurfaceFetch: NativeSettingsSurfaceFetchOperation? = nil,
        stagedMediaDirectory: NativeStagedMediaDirectory? = nil,
        shoppingEntityIndexPurge: @escaping NativeShoppingEntityIndexPurgeOperation = { _ in },
        spoonEntityIndexPurge: @escaping NativeSpoonEntityIndexPurgeOperation = { _ in },
        captureDraftEntityIndexPurge: @escaping NativeCaptureDraftEntityIndexPurgeOperation = { _ in },
        chefProfileEntityIndexPurge: @escaping NativeChefProfileEntityIndexPurgeOperation = { _ in },
        recipeCookbookEntityIndexPurge: @escaping NativeRecipeCookbookEntityIndexPurgeOperation = { _ in },
        nativeTelemetryReport: @escaping NativeTelemetryReportOperation = { _, _ in },
        nativeTelemetryMetadata: NativeTelemetryAppMetadata = .unknown,
        bootstrapMode: NativeLiveAppBootstrapMode = .liveFirst,
        cookSessionClient: @escaping @Sendable (APIClientConfiguration) -> any CookSessionClient = { configuration in
            URLSessionCookSessionClient(configuration: configuration)
        },
        cookSessionPushDelay: Duration = .milliseconds(800),
        now: @escaping @Sendable () -> Date
    ) {
        self.authSessionRepository = authSessionRepository
        self.cacheStore = cacheStore
        self.syncStore = syncStore
        self.syncEngine = syncEngine
        self.syncTriggerCoordinator = syncTriggerCoordinator
        self.appStateStoreProvider = appStateStoreProvider
        self.configuration = configuration
        self.cacheEnvironment = cacheEnvironment
        self.fixtureFallbackPolicy = fixtureFallbackPolicy
        self.recipeEditorAPITransport = recipeEditorAPITransport
        self.settingsSurfaceFetch = settingsSurfaceFetch
        self.stagedMediaDirectory = stagedMediaDirectory
        self.shoppingEntityIndexPurge = shoppingEntityIndexPurge
        self.spoonEntityIndexPurge = spoonEntityIndexPurge
        self.captureDraftEntityIndexPurge = captureDraftEntityIndexPurge
        self.chefProfileEntityIndexPurge = chefProfileEntityIndexPurge
        self.recipeCookbookEntityIndexPurge = recipeCookbookEntityIndexPurge
        self.nativeTelemetryReport = nativeTelemetryReport
        self.nativeTelemetryMetadata = nativeTelemetryMetadata
        self.bootstrapMode = bootstrapMode
        self.cookSessionClient = cookSessionClient
        self.cookSessionPushDelay = cookSessionPushDelay
        self.now = now
    }
}

public struct NativeQueuedMutationBatchResult: Equatable, Sendable {
    public let submittedClientMutationIDs: [String]
    public let drainedClientMutationIDs: [String]
    public let remainingSubmittedClientMutationIDs: [String]
    public let submittedConflicts: [NativeSyncConflict]

    public init(
        submittedClientMutationIDs: [String],
        drainedClientMutationIDs: [String],
        remainingSubmittedClientMutationIDs: [String],
        submittedConflicts: [NativeSyncConflict]
    ) {
        self.submittedClientMutationIDs = submittedClientMutationIDs
        self.drainedClientMutationIDs = drainedClientMutationIDs
        self.remainingSubmittedClientMutationIDs = remainingSubmittedClientMutationIDs
        self.submittedConflicts = submittedConflicts
    }
}

public enum NativeAppBootstrapState {
    case signedOut(NativeShellContentState)
    case restoringCache(NativeShellContentState)
    case liveSynced(NativeShellContentState)
    case offlineStale(NativeShellContentState)
    case queuedWork(NativeShellContentState)
    case conflict(NativeShellContentState)
    case blocker(NativeShellContentState)
    case destructiveConfirmation(NativeShellContentState)
    case syncFailed(NativeShellContentState, message: String)

    public var contentState: NativeShellContentState {
        switch self {
        case .signedOut(let contentState),
             .restoringCache(let contentState),
             .liveSynced(let contentState),
             .offlineStale(let contentState),
             .queuedWork(let contentState),
             .conflict(let contentState),
             .blocker(let contentState),
             .destructiveConfirmation(let contentState):
            contentState
        case .syncFailed(let contentState, _):
            contentState
        }
    }

    public func replacingContent(_ contentState: NativeShellContentState) -> NativeAppBootstrapState {
        switch self {
        case .signedOut:
            .signedOut(contentState)
        case .restoringCache:
            .restoringCache(contentState)
        case .liveSynced:
            .liveSynced(contentState)
        case .offlineStale:
            .offlineStale(contentState)
        case .queuedWork:
            .queuedWork(contentState)
        case .conflict:
            .conflict(contentState)
        case .blocker:
            .blocker(contentState)
        case .destructiveConfirmation:
            .destructiveConfirmation(contentState)
        case .syncFailed(_, let message):
            .syncFailed(contentState, message: message)
        }
    }
}

public struct NativeCachedProfile: Equatable, Sendable {
    public let profile: ProfileSummary
    public let source: ProfileSurfaceDataSource

    public init(profile: ProfileSummary, source: ProfileSurfaceDataSource) {
        self.profile = profile
        self.source = source
    }
}

public struct NativeShellContentState {
    public let recipes: [Recipe]
    public let cookbooks: [Cookbook]
    public let cachedProfiles: [NativeCachedProfile]
    public let kitchen: KitchenFixtureState
    public let shoppingList: ShoppingListState?
    public let captureDraft: CaptureDraft?
    public let cookProgressByRecipeID: [String: CookModeProgress]
    public let spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]
    public let queuedMutations: [NativeQueuedMutation]
    public let syncConflicts: [NativeSyncConflict]
    public let searchResultsByScope: [SearchScope: [String]]
    public let searchSurfaceSnapshots: [SearchSurfaceCacheSnapshot]
    public let authSessionState: NativeAuthSessionState
    public let environment: NativeCacheEnvironment
    public let configuration: APIClientConfiguration
    public let offlineIndicatorState: OfflineIndicatorState
    public let settingsSurfaceData: SettingsSurfaceData?
    public let notificationAPNsSurfaceData: NotificationAPNsSurfaceData?
    /// When the app last finished a real sync with the server, or nil if it never has. Surfaces that have no
    /// per-record freshness of their own derive "out of date" from this, not from a placeholder.
    public let lastSyncedAt: Date?
    /// True while the server has refused the stored session for good. The cached kitchen and its unsynced
    /// work stay in place under the same account (`authSessionState` keeps the stored session); only syncing
    /// stops, until the chef signs in again.
    public let isSessionExpired: Bool

    public func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    public var currentChefID: String? {
        trustedAccountID
    }

    public var myRecipesCatalog: RecipeCatalogPage {
        guard let currentChefID else {
            return personalRecipeCatalogPage(rows: [])
        }

        return personalRecipeCatalogPage(
            rows: recipes
                .filter { $0.chef.id == currentChefID }
                .map(RecipeSummary.init(recipe:))
        )
    }

    public var savedRecipesCatalog: RecipeCatalogPage {
        guard let currentChefID else {
            return personalRecipeCatalogPage(rows: [])
        }

        var seenRecipeIDs = Set<String>()
        let rows = cookbooks
            .filter { $0.chef.id == currentChefID }
            .flatMap(\.recipes)
            .filter { recipe in
                seenRecipeIDs.insert(recipe.id).inserted
            }
        return personalRecipeCatalogPage(rows: rows)
    }

    private func personalRecipeCatalogPage(rows: [RecipeSummary]) -> RecipeCatalogPage {
        RecipeCatalogPage(
            query: nil,
            limit: max(48, rows.count),
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: rows,
            source: recipeCatalogSource
        )
    }

    public var settingsViewModel: SettingsViewModel {
        SettingsViewModel(
            settings: SettingsState(
                auth: authState,
                environment: spoonjoyEnvironment,
                offline: offlineState,
                preferredCookModeTextSize: .large
            ),
            offlineIndicatorDisplay: offlineIndicatorState.display,
            authSessionState: authSessionState,
            environmentSwitcher: environment,
            dismissOfflineIndicator: OfflineIndicatorDismissCommand(
                id: "dismiss-\(environment.rawValue)",
                title: "Hide offline status"
            )
        )
    }

    public var settingsSurfaceViewModel: SettingsSurfaceViewModel {
        if let settingsSurfaceData {
            return SettingsSurfaceViewModel(
                data: settingsSurfaceData,
                queuedMutations: queuedMutations,
                conflicts: syncConflicts,
                connectivity: offlineIndicatorState.display == .offline ? .offline : .online,
                secureHandoffRoutes: SettingsSecureHandoffRoutes(baseURL: configuration.baseURL),
                now: Date.init
            )
        }

        guard trustedAccountID != nil else {
            return SettingsSurfaceViewModel.signedOut(
                environment: environment,
                offline: offlineState,
                secureHandoffRoutes: SettingsSecureHandoffRoutes(baseURL: configuration.baseURL)
            )
        }

        let data = SettingsSurfaceData(
            account: nil,
            notifications: nil,
            apiTokens: [],
            oauthConnections: [],
            environment: environment,
            offline: .unavailable,
            source: .cache(lastValidatedAt: lastSyncedAt ?? .distantPast)
        )
        return SettingsSurfaceViewModel(
            data: data,
            queuedMutations: queuedMutations,
            conflicts: syncConflicts,
            connectivity: offlineIndicatorState.display == .offline ? .offline : .online,
            secureHandoffRoutes: SettingsSecureHandoffRoutes(baseURL: configuration.baseURL),
            now: Date.init,
            showsPrimaryAuthActionWhenSignedOut: false
        )
    }

    public var notificationAPNsSurfaceViewModel: NotificationAPNsSurfaceViewModel? {
        guard let data = notificationAPNsSurfaceData else {
            return nil
        }
        return NotificationAPNsSurfaceViewModel(
            data: data,
            queuedMutations: queuedMutations,
            connectivity: offlineIndicatorState.display == .offline ? .offline : .online,
            now: Date.init
        )
    }

    public var searchSurfaceViewModel: SearchSurfaceViewModel {
        performSearch(SearchState())
    }

    public func performSearch(_ state: SearchState) -> SearchSurfaceViewModel {
        let page = searchSurfacePage(for: state)
        return SearchSurfaceViewModel(
            page: page,
            state: state,
            context: searchSurfaceContext,
            offlineIndicator: searchSurfaceSevereOfflineIndicator ?? page.offlineIndicator(now: Date())
        )
    }

    public func performSearch(
        page: SearchSurfacePage,
        state: SearchState
    ) -> SearchSurfaceViewModel {
        SearchSurfaceViewModel(
            page: page,
            state: state,
            context: searchSurfaceContext,
            offlineIndicator: searchSurfaceSevereOfflineIndicator ?? page.offlineIndicator(now: Date())
        )
    }

    public func performSearch(
        error: SearchSurfaceRepositoryError,
        state: SearchState,
        cachedPage: SearchSurfacePage?
    ) -> SearchSurfaceViewModel {
        return SearchSurfaceViewModel(
            error: error,
            state: state,
            cachedPage: cachedPage,
            context: searchSurfaceContext,
            offlineIndicator: searchSurfaceSevereOfflineIndicator,
            now: Date.init
        )
    }

    public var searchSurfaceIdentity: String {
        "\(environment.rawValue)|\(searchSurfaceAccountID)|\(searchSurfaceContext.isAuthenticated)|\(searchSurfaceContext.canReadShoppingList)|\(searchSurfaceSeverityIdentity)"
    }

    public var spotlightIndexScope: SpotlightIndexScope? {
        trustedAccountID.map { SpotlightIndexScope(accountID: $0, environment: environment) }
    }

    public var profileGraphRepository: (any ProfileChefGraphSurfaceRepository)? {
        guard let profileResult = firstProfileSurfaceResult else {
            return nil
        }
        return SnapshotProfileChefGraphSurfaceRepository(
            profileResult: profileResult,
            graphPages: profileGraphPages(profileResult: profileResult)
        )
    }

    public func profileGraphPages(profileResult result: ProfileSurfaceResult) -> [ProfileGraphPage] {
        let graphProfile = ProfileGraphProfile(
            id: result.data.profile.id,
            username: result.data.profile.username,
            href: result.data.profile.href,
            canonicalURL: result.data.profile.canonicalURL
        )
        let fellowChefs = fellowChefRows(chefID: result.data.profile.id)
        let kitchenVisitors = kitchenVisitorRows(chefID: result.data.profile.id)
        return [
            ProfileGraphPage(
                profile: graphProfile,
                direction: .fellowChefs,
                page: 1,
                pageSize: 50,
                total: fellowChefs.count,
                nextCursor: nil,
                rows: fellowChefs,
                source: result.source,
                emptyState: fellowChefs.isEmpty ? ProfileGraphPage.emptyState(for: .fellowChefs) : nil
            ),
            ProfileGraphPage(
                profile: graphProfile,
                direction: .kitchenVisitors,
                page: 1,
                pageSize: 50,
                total: kitchenVisitors.count,
                nextCursor: nil,
                rows: kitchenVisitors,
                source: result.source,
                emptyState: kitchenVisitors.isEmpty ? ProfileGraphPage.emptyState(for: .kitchenVisitors) : nil
            )
        ]
    }

    private func fellowChefRows(chefID: String) -> [ProfileGraphRow] {
        let aggregates = recipes.reduce(into: [String: NativeProfileGraphAggregate]()) { partial, recipe in
            guard recipe.chef.id != chefID else {
                return
            }
            recipe.recentSpoons.forEach { spoon in
                guard spoon.chef.id == chefID, spoon.deletedAt == nil else {
                    return
                }
                partial.recordSpoon(for: recipe.chef, at: Self.profileRecentSpoonSortKey(spoon))
            }
        }
        return graphRows(from: aggregates)
    }

    private func kitchenVisitorRows(chefID: String) -> [ProfileGraphRow] {
        let aggregates = recipes
            .filter { $0.chef.id == chefID }
            .reduce(into: [String: NativeProfileGraphAggregate]()) { partial, recipe in
                recipe.recentSpoons.forEach { spoon in
                    guard spoon.chef.id != chefID, spoon.deletedAt == nil else {
                        return
                    }
                    partial.recordSpoon(for: spoon.chef, at: Self.profileRecentSpoonSortKey(spoon))
                }
            }
        return graphRows(from: aggregates)
    }

    private func graphRows(from aggregates: [String: NativeProfileGraphAggregate]) -> [ProfileGraphRow] {
        aggregates.values
            .sorted { lhs, rhs in
                if lhs.latestInteractionAt != rhs.latestInteractionAt {
                    return lhs.latestInteractionAt > rhs.latestInteractionAt
                }
                return lhs.chef.id > rhs.chef.id
            }
            .map(profileGraphRow)
    }

    private func profileGraphRow(aggregate: NativeProfileGraphAggregate) -> ProfileGraphRow {
        let link = Self.profileLink(username: aggregate.chef.username)
        return ProfileGraphRow(
            chefID: aggregate.chef.id,
            username: aggregate.chef.username,
            photoURL: aggregate.chef.photoURL,
            href: link.href,
            canonicalURL: link.canonicalURL,
            interactionCounts: ProfileGraphInteractionCounts(spoons: aggregate.spoons, forks: 0, cookbookSaves: 0),
            latestInteractionAt: aggregate.latestInteractionAt
        )
    }

    public var profileSurfaceViewModel: ProfileViewModel? {
        guard let profileResult = firstProfileSurfaceResult else {
            return nil
        }
        return ProfileViewModel(
            result: profileResult,
            context: ProfileSurfaceContext(currentChefID: trustedAccountID),
            queuedMutations: queuedMutations,
            conflicts: syncConflicts,
            connectivity: offlineIndicatorState.display == .offline ? .offline : .online,
            now: Date.init
        )
    }

    public var recipeCatalog: RecipeCatalogPage {
        RecipeCatalogPage(
            query: nil,
            limit: max(48, recipes.count),
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: recipes.map(RecipeSummary.init(recipe:)),
            source: recipeCatalogSource
        )
    }

    private var firstProfileSurfaceResult: ProfileSurfaceResult? {
        guard let profile = firstProfileCandidate else {
            return nil
        }
        return profileSurfaceResult(identifier: profile.profile.id)
    }

    public var searchSurfaceContext: SearchSurfaceContext {
        switch authSessionState {
        case .signedOut:
            return SearchSurfaceContext(isAuthenticated: false, canReadShoppingList: false)
        case .authenticated(let session), .refreshRequired(let session):
            let scopes = Set(session.scope.split(separator: " ").map(String.init))
            let shoppingReadScopes: Set<String> = ["shopping_list:read", "kitchen:read"]
            return SearchSurfaceContext(
                isAuthenticated: true,
                canReadShoppingList: !scopes.isDisjoint(with: shoppingReadScopes)
            )
        }
    }

    public func searchSurfacePage(for state: SearchState) -> SearchSurfacePage {
        if let snapshot = restoreSearchSurfaceSnapshot(state: state) {
            return snapshot.page(
                context: searchSurfaceContext,
                currentAccountID: trustedAccountID,
                source: .cache(serverRevision: snapshot.serverRevision, lastValidatedAt: snapshot.lastValidatedAt)
            )
        }

        let snapshot = SearchSurfaceCacheSnapshot(
            accountID: searchSurfaceAccountID,
            environment: environment,
            query: state.query,
            scope: state.scope,
            limit: 20,
            results: searchSurfaceResults(for: state),
            recentSearches: state.hasQuery ? [SearchSurfaceRecentQuery(query: state.query, scope: state.scope, lastSearchedAt: Date())] : [],
            serverRevision: latestSearchRevision,
            lastValidatedAt: Date()
        )
        return SearchSurfacePage(
            query: snapshot.query,
            scope: snapshot.scope,
            limit: snapshot.limit,
            isAuthenticated: searchSurfaceContext.isAuthenticated,
            results: snapshot.results,
            source: offlineIndicatorState.display == .synced
                ? .live(requestID: "native-shell-search", validatedAt: snapshot.lastValidatedAt)
                : .cache(serverRevision: snapshot.serverRevision, lastValidatedAt: snapshot.lastValidatedAt)
        )
    }

    private func restoreSearchSurfaceSnapshot(state: SearchState) -> SearchSurfaceCacheSnapshot? {
        guard state.hasQuery else {
            return nil
        }
        return searchSurfaceSnapshots.first { snapshot in
            snapshot.environment == environment &&
                snapshot.query == state.query &&
                snapshot.scope == state.scope &&
                snapshot.accountID == searchSurfaceAccountID
        }
    }

    private var searchSurfaceAccountID: String {
        switch authSessionState {
        case .signedOut:
            return "signed-out"
        case .authenticated(let session), .refreshRequired(let session):
            return session.accountID ?? "unbound:\(session.clientID)"
        }
    }

    private var searchSurfaceSevereOfflineIndicator: OfflineIndicatorState? {
        switch offlineIndicatorState.display {
        case .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            return offlineIndicatorState
        case .synced, .offline, .stale, .dismissed:
            return nil
        }
    }

    private var searchSurfaceSeverityIdentity: String {
        switch offlineIndicatorState.display {
        case .queuedWork(let count, let oldestClientMutationID):
            return "queued:\(count):\(oldestClientMutationID ?? "")"
        case .syncFailure(let errorID, let retryAfter):
            return "sync-failure:\(errorID):\(String(describing: retryAfter))"
        case .conflict(let recordID, let mutationID):
            return "conflict:\(recordID):\(mutationID)"
        case .blocker(let blocker):
            return "blocker:\(String(describing: blocker))"
        case .destructiveConfirmation(let actionID):
            return "destructive:\(actionID)"
        case .synced, .offline, .stale, .dismissed:
            return "informational"
        }
    }

    private var latestSearchRevision: NativeCacheServerRevision? {
        (recipes.map(\.updatedAt) + cookbooks.map(\.updatedAt) + [shoppingList?.updatedAt].compactMap { $0 })
            .max()
            .map(NativeCacheServerRevision.updatedAt)
    }

    private func searchSurfaceResults(for state: SearchState) -> [SearchSurfaceResult] {
        let chefRows = searchSurfaceChefResults()
        let shoppingRows = searchSurfaceContext.canReadShoppingList
            ? (shoppingList?.activeItems ?? []).map { item in Self.searchResult(item: item, chef: shoppingList?.chef) }
            : []
        let allRows = recipes.map(Self.searchResult(recipe:)) +
            cookbooks.map(Self.searchResult(cookbook:)) +
            chefRows +
            shoppingRows
        return allRows.filter { result in
            Self.searchResult(result, isVisibleIn: state.scope) &&
                Self.searchResult(result, matches: state.query)
        }
    }

    private func searchSurfaceChefResults() -> [SearchSurfaceResult] {
        let allChefs = recipes.map(\.chef) + cookbooks.map(\.chef) + [shoppingList?.chef].compactMap { $0 }
        var seenChefIDs = Set<String>()
        return allChefs.compactMap { chef in
            guard seenChefIDs.insert(chef.id).inserted else {
                return nil
            }
            return Self.searchResult(chef: chef)
        }
    }

    private static func searchResult(recipe: Recipe) -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .recipe,
            id: recipe.id,
            ownerID: recipe.chef.id,
            ownerUsername: recipe.chef.username,
            title: recipe.title,
            subtitle: recipe.description ?? "Recipe by \(recipe.chef.username)",
            snippet: recipe.servings,
            href: recipe.href,
            canonicalURL: recipe.canonicalURL,
            imageURL: recipe.coverImageURL,
            score: 0,
            metadata: [
                "chefUsername": .string(recipe.chef.username),
                "updatedAt": .string(recipe.updatedAt)
            ]
        )
    }

    private static func searchResult(cookbook: Cookbook) -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .cookbook,
            id: cookbook.id,
            ownerID: cookbook.chef.id,
            ownerUsername: cookbook.chef.username,
            title: cookbook.title,
            subtitle: "\(cookbook.recipeCount) \(cookbook.recipeCount == 1 ? "recipe" : "recipes")",
            snippet: "Cookbook by \(cookbook.chef.username)",
            href: cookbook.href,
            canonicalURL: cookbook.canonicalURL,
            imageURL: cookbook.cover.primaryImageURL,
            score: 0,
            metadata: [
                "chefUsername": .string(cookbook.chef.username),
                "recipeCount": .number(Double(cookbook.recipeCount)),
                "updatedAt": .string(cookbook.updatedAt)
            ]
        )
    }

    private static func searchResult(chef: ChefSummary) -> SearchSurfaceResult {
        let link = profileLink(username: chef.username)
        return SearchSurfaceResult(
            type: .chef,
            id: chef.id,
            ownerID: chef.id,
            ownerUsername: chef.username,
            title: chef.username,
            subtitle: "Chef",
            snippet: nil,
            href: link.href,
            canonicalURL: link.canonicalURL,
            imageURL: chef.photoURL,
            score: 0,
            metadata: [:]
        )
    }

    private static func searchResult(item: ShoppingListItem, chef: ChefSummary?) -> SearchSurfaceResult {
        SearchSurfaceResult(
            type: .shoppingListItem,
            id: item.id,
            ownerID: chef?.id,
            ownerUsername: chef?.username,
            title: item.name,
            subtitle: item.displayQuantity.isEmpty ? "Shopping list" : item.displayQuantity,
            snippet: item.categoryKey,
            href: "/shopping-list",
            canonicalURL: URL(string: "https://spoonjoy.app/shopping-list")!,
            imageURL: nil,
            score: 0,
            metadata: [
                "checked": .bool(item.checked),
                "categoryKey": item.categoryKey.map(JSONValue.string) ?? .null
            ]
        )
    }

    private static func searchResult(_ result: SearchSurfaceResult, isVisibleIn scope: SearchScope) -> Bool {
        switch (scope, result.type) {
        case (.all, _), (.recipes, .recipe), (.cookbooks, .cookbook), (.chefs, .chef), (.shoppingList, .shoppingListItem):
            return true
        default:
            return false
        }
    }

    private static func searchResult(_ result: SearchSurfaceResult, matches query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }
        let searchableText = [
            result.title,
            result.subtitle,
            result.snippet,
            result.ownerUsername
        ]
            .compactMap { $0 }
            .joined(separator: " ")
        return searchableText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    public func profileSurfaceResult(identifier: String) -> ProfileSurfaceResult? {
        guard let profile = profileCandidate(identifier: identifier) else {
            return nil
        }
        let chefID = profile.profile.id
        let chefRecipes = recipes.filter { $0.chef.id == chefID }
        let chefCookbooks = cookbooks.filter { $0.chef.id == chefID }
        let fellowChefs = fellowChefRows(chefID: chefID)
        let kitchenVisitors = kitchenVisitorRows(chefID: chefID)
        return ProfileSurfaceResult(
            data: ProfileSurfaceData(
                profile: profile.profile,
                isOwner: trustedAccountID == chefID,
                recipes: chefRecipes.map(profileRecipeSummary),
                cookbooks: chefCookbooks.map(profileCookbookSummary),
                recentSpoons: profileRecentSpoons(chefID: chefID),
                fellowChefsCount: fellowChefs.count,
                kitchenVisitorsCount: kitchenVisitors.count
            ),
            source: profile.source
        )
    }

    public func profileRecentSpoons(chefID: String) -> [ProfileRecentSpoon] {
        let matches: [(recipe: Recipe, spoon: RecipeDetailRecentSpoon)] = recipes.flatMap { recipe in
            recipe.recentSpoons.compactMap { spoon -> (recipe: Recipe, spoon: RecipeDetailRecentSpoon)? in
                guard spoon.chef.id == chefID, spoon.deletedAt == nil else {
                    return nil
                }
                return (recipe, spoon)
            }
        }
        return matches
            .sorted { lhs, rhs in
                let lhsKey = Self.profileRecentSpoonSortKey(lhs.spoon)
                let rhsKey = Self.profileRecentSpoonSortKey(rhs.spoon)
                if lhsKey != rhsKey {
                    return lhsKey > rhsKey
                }
                return lhs.spoon.id > rhs.spoon.id
            }
            .prefix(Self.profileRecentSpoonLimit)
            .map { recipe, spoon in
                ProfileRecentSpoon(
                    id: spoon.id,
                    cookedAt: spoon.cookedAt,
                    photoURL: spoon.photoURL,
                    note: spoon.note,
                    nextTime: spoon.nextTime,
                    chef: spoon.chef,
                    recipe: ProfileRecentSpoonRecipe(id: recipe.id, title: recipe.title, chefID: recipe.chef.id),
                    coverImageURL: recipe.coverImageURL,
                    coverProvenanceLabel: recipe.coverProvenanceLabel
                )
            }
    }

    private static let profileRecentSpoonLimit = 10

    private static func profileRecentSpoonSortKey(_ spoon: RecipeDetailRecentSpoon) -> String {
        if let cookedAt = spoon.cookedAt {
            return cookedAt
        }
        return spoon.createdAt
    }

    private var firstProfileCandidate: NativeCachedProfile? {
        if let trustedAccountID,
           let profile = profileCandidate(identifier: trustedAccountID) {
            return profile
        }
        return cachedProfiles.first ?? (recipes.first?.chef ?? cookbooks.first?.chef).map(profileCandidate(chef:))
    }

    private func profileCandidate(identifier: String) -> NativeCachedProfile? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if let profile = cachedProfiles.first(where: { $0.profile.id == trimmed || $0.profile.username == trimmed }) {
            return profile
        }
        if let chef = profileChef(identifier: trimmed) {
            return profileCandidate(chef: chef)
        }
        return nil
    }

    private func profileCandidate(chef: ChefSummary) -> NativeCachedProfile {
        NativeCachedProfile(
            profile: Self.profileSummary(chef: chef),
            source: profileSurfaceSource
        )
    }

    private func profileChef(identifier: String) -> ChefSummary? {
        let chefs = recipes.map(\.chef) + cookbooks.map(\.chef)
        return chefs.first { $0.id == identifier || $0.username == identifier }
    }

    private func profileRecipeSummary(recipe: Recipe) -> ProfileRecipeSummary {
        ProfileRecipeSummary(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            href: recipe.href,
            canonicalURL: recipe.canonicalURL
        )
    }

    private func profileCookbookSummary(cookbook: Cookbook) -> ProfileCookbookSummary {
        ProfileCookbookSummary(
            id: cookbook.id,
            title: cookbook.title,
            recipeCount: cookbook.recipeCount,
            recipePreviews: cookbook.recipes.prefix(4).map { recipe in
                ProfileCookbookRecipePreview(
                    id: recipe.id,
                    title: recipe.title,
                    coverImageURL: recipe.coverImageURL,
                    coverProvenanceLabel: recipe.coverProvenanceLabel,
                    href: recipe.href,
                    canonicalURL: recipe.canonicalURL
                )
            },
            href: cookbook.href,
            canonicalURL: cookbook.canonicalURL
        )
    }

    private static func profileSummary(chef: ChefSummary) -> ProfileSummary {
        let link = profileLink(username: chef.username)
        return ProfileSummary(
            id: chef.id,
            username: chef.username,
            photoURL: chef.photoURL,
            joinedLabel: "Joined Spoonjoy",
            href: link.href,
            canonicalURL: link.canonicalURL
        )
    }

    private static func profileSummary(id: String, username: String, photoURL: URL? = nil, joinedLabel: String = "Joined Spoonjoy") -> ProfileSummary {
        let link = profileLink(username: username)
        return ProfileSummary(
            id: id,
            username: username,
            photoURL: photoURL,
            joinedLabel: joinedLabel,
            href: link.href,
            canonicalURL: link.canonicalURL
        )
    }

    private static func profileLink(username: String) -> (href: String, canonicalURL: URL) {
        ProfileSurfaceLinks.link(username: username)
    }

    private var trustedAccountID: String? {
        switch authSessionState {
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        case .signedOut:
            nil
        }
    }

    private var profileSurfaceSource: ProfileSurfaceDataSource {
        .cache(serverRevision: latestProfileRevision, lastValidatedAt: .distantPast)
    }

    private var latestProfileRevision: NativeCacheServerRevision? {
        (recipes.map(\.updatedAt) + cookbooks.map(\.updatedAt))
            .max()
            .map(NativeCacheServerRevision.updatedAt)
    }

    public func cookProgress(for recipeID: String) -> CookModeProgress? {
        cookProgressByRecipeID[recipeID]
    }

    public func spoonCookLogDraft(recipeID: String) -> SpoonCookLogDraftState? {
        spoonCookLogDraftsByRecipeID[recipeID]
    }

    func copy(
        recipes: [Recipe]? = nil,
        cookbooks: [Cookbook]? = nil,
        cachedProfiles: [NativeCachedProfile]? = nil,
        shoppingList: ShoppingListState? = nil,
        captureDraft: CaptureDraft?? = nil,
        cookProgressByRecipeID: [String: CookModeProgress]? = nil,
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]? = nil,
        queuedMutations: [NativeQueuedMutation]? = nil,
        syncConflicts: [NativeSyncConflict]? = nil,
        searchSurfaceSnapshots: [SearchSurfaceCacheSnapshot]? = nil,
        environment: NativeCacheEnvironment? = nil,
        configuration: APIClientConfiguration? = nil,
        offlineIndicatorState: OfflineIndicatorState? = nil,
        settingsSurfaceData: SettingsSurfaceData?? = nil,
        notificationAPNsSurfaceData: NotificationAPNsSurfaceData?? = nil,
        authSessionState: NativeAuthSessionState? = nil,
        lastSyncedAt: Date?? = nil,
        isSessionExpired: Bool? = nil
    ) -> NativeShellContentState {
        NativeShellContentState(
            recipes: recipes ?? self.recipes,
            cookbooks: cookbooks ?? self.cookbooks,
            cachedProfiles: cachedProfiles ?? self.cachedProfiles,
            kitchen: kitchen,
            shoppingList: shoppingList ?? self.shoppingList,
            captureDraft: captureDraft ?? self.captureDraft,
            cookProgressByRecipeID: cookProgressByRecipeID ?? self.cookProgressByRecipeID,
            spoonCookLogDraftsByRecipeID: spoonCookLogDraftsByRecipeID ?? self.spoonCookLogDraftsByRecipeID,
            queuedMutations: queuedMutations ?? self.queuedMutations,
            syncConflicts: syncConflicts ?? self.syncConflicts,
            searchSurfaceSnapshots: searchSurfaceSnapshots ?? self.searchSurfaceSnapshots,
            authSessionState: authSessionState ?? self.authSessionState,
            environment: environment ?? self.environment,
            configuration: configuration ?? self.configuration,
            offlineIndicatorState: offlineIndicatorState ?? self.offlineIndicatorState,
            settingsSurfaceData: settingsSurfaceData ?? self.settingsSurfaceData,
            notificationAPNsSurfaceData: notificationAPNsSurfaceData ?? self.notificationAPNsSurfaceData,
            lastSyncedAt: lastSyncedAt ?? self.lastSyncedAt,
            isSessionExpired: isSessionExpired ?? self.isSessionExpired
        )
    }

#if DEBUG
    public func debugApplyingNotificationAPNsSurfaceData(
        _ notificationAPNsSurfaceData: NotificationAPNsSurfaceData
    ) -> NativeShellContentState {
        copy(notificationAPNsSurfaceData: .some(notificationAPNsSurfaceData))
    }

    public func debugApplyingSyncOverlay(
        conflicts: [NativeSyncConflict],
        conflictMutationID: String
    ) -> NativeShellContentState {
        let offlineIndicatorState = OfflineIndicatorState(
            display: .conflict(recordID: conflictMutationID, mutationID: conflictMutationID),
            dismissal: nil
        )
        return copy(syncConflicts: conflicts, offlineIndicatorState: offlineIndicatorState)
    }
#endif

    static func empty(
        authSessionState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        configuration: APIClientConfiguration,
        offlineIndicatorState: OfflineIndicatorState
    ) -> NativeShellContentState {
        NativeShellContentState(
            recipes: [],
            cookbooks: [],
            cachedProfiles: [],
            kitchen: KitchenFixtureState(
                status: .bootstrap,
                leadObject: .recipe(id: "live-empty", title: "Spoonjoy"),
                primaryAction: .startCookMode(recipeID: "live-empty"),
                counts: KitchenCounts(recipes: 0, cookbooks: 0, shoppingItems: 0),
                offlineRestore: OfflineRestoreMetadata(snapshotID: "live-empty", includesShoppingList: false)
            ),
            shoppingList: nil,
            captureDraft: nil,
            cookProgressByRecipeID: [:],
            spoonCookLogDraftsByRecipeID: [:],
            queuedMutations: [],
            syncConflicts: [],
            searchSurfaceSnapshots: [],
            authSessionState: authSessionState,
            environment: environment,
            configuration: configuration,
            offlineIndicatorState: offlineIndicatorState,
            settingsSurfaceData: nil,
            notificationAPNsSurfaceData: nil
        )
    }

#if DEBUG
    public static func debugShoppingFixture(_ shoppingList: ShoppingListState) -> NativeShellContentState {
        empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        ).copy(shoppingList: shoppingList)
    }
#endif

    static func restored(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot,
        appSnapshot: NativeAppSnapshot?,
        authSessionState: NativeAuthSessionState,
        configuration: APIClientConfiguration,
        optimisticMutations: [NativeQueuedMutation] = [],
        offlineIndicatorState: OfflineIndicatorState
    ) -> NativeShellContentState {
        let cachedRecipes = restoredRecipes(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let recipes = recipesByApplyingQueuedRecipeMutations(
            optimisticMutations + syncSnapshot.queue.mutations,
            to: cachedRecipes,
            authSessionState: authSessionState
        )
        let cachedCookbooks = restoredCookbooks(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let cookbooks = cookbooksByApplyingQueuedCookbookMutations(
            optimisticMutations + syncSnapshot.queue.mutations,
            to: cachedCookbooks,
            recipes: recipes,
            authSessionState: authSessionState
        )
        let cachedProfiles = restoredProfiles(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let shoppingList = restoredShoppingList(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: appSnapshot,
            recipes: recipes,
            authSessionState: authSessionState,
            optimisticMutations: optimisticMutations
        )
        let captureDraft = restoredCaptureDraft(cacheSnapshot: cacheSnapshot, appSnapshot: appSnapshot)
        let cookProgressByRecipeID = restoredCookProgress(cacheSnapshot: cacheSnapshot, appSnapshot: appSnapshot)
        let spoonCookLogDraftsByRecipeID = appSnapshot?.spoonCookLogDraftsByRecipeID ?? [:]
        let settingsSurfaceData = restoredSettingsSurfaceData(cacheSnapshot: cacheSnapshot)
        let notificationAPNsSurfaceData = restoreNotificationAPNsSnapshot(cacheSnapshot: cacheSnapshot)
        let searchSurfaceSnapshots = restoredSearchSurfaceSnapshots(cacheSnapshot: cacheSnapshot)
        return NativeShellContentState(
            recipes: recipes,
            cookbooks: cookbooks,
            cachedProfiles: cachedProfiles,
            kitchen: restoredKitchen(
                cacheSnapshot: cacheSnapshot,
                recipes: recipes,
                cookbooks: cookbooks,
                shoppingList: shoppingList
            ),
            shoppingList: shoppingList,
            captureDraft: captureDraft,
            cookProgressByRecipeID: cookProgressByRecipeID,
            spoonCookLogDraftsByRecipeID: spoonCookLogDraftsByRecipeID,
            queuedMutations: syncSnapshot.queue.mutations,
            syncConflicts: [],
            searchSurfaceSnapshots: searchSurfaceSnapshots,
            authSessionState: authSessionState,
            environment: cacheSnapshot.environment,
            configuration: configuration,
            offlineIndicatorState: offlineIndicatorState,
            settingsSurfaceData: settingsSurfaceData,
            notificationAPNsSurfaceData: notificationAPNsSurfaceData,
            lastSyncedAt: date(from: syncSnapshot.checkpoint?.updatedAt)
        )
    }

    private static func restoredRecipes(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot
    ) -> [Recipe] {
        let decoded = syncSnapshot.cachedRecords
            .filter { $0.kind == .recipe }
            .compactMap { decodedPayload(Recipe.self, from: $0.payload) }
        let decodedIDs = Set(decoded.map(\.id))
        let placeholders = cacheSnapshot.records.compactMap { record -> Recipe? in
            guard case .recipeDetail(let id, let title) = record.payload, !decodedIDs.contains(id) else {
                return nil
            }
            return placeholderRecipe(id: id, title: title, date: record.metadata.lastValidatedAt)
        }
        let syncedSpoonsByRecipeID = Dictionary(
            grouping: syncSnapshot.cachedRecords
                .filter { $0.kind == .spoon }
                .compactMap { decodedPayload(RecipeDetailRecentSpoon.self, from: $0.payload) },
            by: \.recipeID
        )
        let tombstonedSpoonIDs = Set(syncSnapshot.tombstones.compactMap { tombstone in
            tombstone.resourceType == .spoon ? tombstone.resourceID : nil
        })
        return (decoded + placeholders)
            .map { recipe in
                let syncedSpoons = syncedSpoonsByRecipeID[recipe.id] ?? []
                guard !syncedSpoons.isEmpty || !tombstonedSpoonIDs.isEmpty else {
                    return recipe
                }
                let retainedSummarySpoons = recipe.recentSpoons.filter { !tombstonedSpoonIDs.contains($0.id) }
                let restoredSpoons = syncedSpoons
                    .filter { !tombstonedSpoonIDs.contains($0.id) }
                    .reduce(retainedSummarySpoons) { $0.upsertingRestoredRecentSpoon($1) }
                guard restoredSpoons != recipe.recentSpoons else {
                    return recipe
                }
                return recipe.replacingRestoredRecentSpoons(restoredSpoons)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func recipesByApplyingQueuedRecipeMutations(
        _ mutations: [NativeQueuedMutation],
        to recipes: [Recipe],
        authSessionState: NativeAuthSessionState
    ) -> [Recipe] {
        let fallbackChef = optimisticRecipeChef(authSessionState: authSessionState, recipes: recipes)
        return mutations.reduce(recipes) { currentRecipes, mutation in
            mutation.applyingOptimisticRecipeMutation(
                to: currentRecipes,
                fallbackChef: fallbackChef,
                now: mutation.createdAt
            )
        }
    }

    private static func optimisticRecipeChef(authSessionState: NativeAuthSessionState, recipes: [Recipe]) -> ChefSummary {
        optimisticChef(authSessionState: authSessionState, recipes: recipes, cookbooks: [])
    }

    private static func restoredCookbooks(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot
    ) -> [Cookbook] {
        let decoded = syncSnapshot.cachedRecords
            .filter { $0.kind == .cookbook }
            .compactMap { decodedPayload(Cookbook.self, from: $0.payload) }
        let decodedIDs = Set(decoded.map(\.id))
        let placeholders = cacheSnapshot.records.compactMap { record -> Cookbook? in
            guard case .cookbookDetail(let id, let title) = record.payload, !decodedIDs.contains(id) else {
                return nil
            }
            return placeholderCookbook(id: id, title: title, date: record.metadata.lastValidatedAt)
        }
        return (decoded + placeholders).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func restoredProfiles(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot
    ) -> [NativeCachedProfile] {
        var profilesByID = [String: NativeCachedProfile]()
        cacheSnapshot.records
            .compactMap(restoredProfile(cacheRecord:))
            .forEach { profilesByID[$0.profile.id] = $0 }
        syncSnapshot.cachedRecords
            .filter { $0.kind == .profile }
            .compactMap { restoredProfile(syncRecord: $0, checkpoint: syncSnapshot.checkpoint) }
            .forEach { profilesByID[$0.profile.id] = $0 }
        return profilesByID.values.sorted {
            $0.profile.username.localizedCaseInsensitiveCompare($1.profile.username) == .orderedAscending
        }
    }

    private static func restoredProfile(cacheRecord record: NativeCacheRecord) -> NativeCachedProfile? {
        guard case .profile(let id, let username) = record.payload,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return NativeCachedProfile(
            profile: profileSummary(id: id, username: username),
            source: .cache(
                serverRevision: record.metadata.serverRevision,
                lastValidatedAt: record.metadata.lastValidatedAt
            )
        )
    }

    private static func restoredProfile(syncRecord record: NativeSyncCachedRecord, checkpoint: NativeSyncCheckpoint?) -> NativeCachedProfile? {
        let profile = (decodedPayload(ProfileSurfaceResult.self, from: record.payload)?.data.profile
            ?? decodedPayload(ProfileSurfaceData.self, from: record.payload)?.profile
            ?? decodedPayload(ProfileSummary.self, from: record.payload)
            ?? profileSummary(resourceID: record.resourceID, payload: record.payload))?
            .withNormalizedProfileLink()
        guard let profile else {
            return nil
        }
        return NativeCachedProfile(
            profile: profile,
            source: .cache(
                serverRevision: cacheServerRevision(from: record.serverRevision),
                lastValidatedAt: date(from: checkpoint?.updatedAt) ?? .distantPast
            )
        )
    }

    private static func profileSummary(resourceID: String, payload: JSONValue) -> ProfileSummary? {
        guard case .object(let fields) = payload,
              case .string(let username)? = fields["username"],
              !resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let photoURL: URL?
        if case .string(let photoURLRaw)? = fields["photoUrl"] {
            photoURL = URL(string: photoURLRaw)
        } else {
            photoURL = nil
        }
        let joinedLabel: String
        if case .string(let rawJoinedLabel)? = fields["joinedLabel"], !rawJoinedLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            joinedLabel = rawJoinedLabel
        } else {
            joinedLabel = "Joined Spoonjoy"
        }
        return profileSummary(id: resourceID, username: username, photoURL: photoURL, joinedLabel: joinedLabel)
    }

    private static func cacheServerRevision(from revision: NativeServerRevision?) -> NativeCacheServerRevision? {
        switch revision {
        case .updatedAt(let value):
            return .updatedAt(value)
        case .etag(let value):
            return .etag(value)
        case .tombstone(let value):
            return .localRevision(value)
        case .optimistic(let value):
            return .localRevision("optimistic:\(value)")
        case nil:
            return nil
        }
    }

    static func date(from isoString: String?) -> Date? {
        guard let isoString else {
            return nil
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: isoString) {
            return date
        }
        return ISO8601DateFormatter().date(from: isoString)
    }

    private static func cookbooksByApplyingQueuedCookbookMutations(
        _ mutations: [NativeQueuedMutation],
        to cookbooks: [Cookbook],
        recipes: [Recipe],
        authSessionState: NativeAuthSessionState
    ) -> [Cookbook] {
        let fallbackChef = optimisticChef(authSessionState: authSessionState, recipes: recipes, cookbooks: cookbooks)
        return mutations.reduce(cookbooks) { currentCookbooks, mutation in
            mutation.applyingOptimisticCookbookMutation(
                to: currentCookbooks,
                fallbackChef: fallbackChef,
                recipes: recipes,
                now: mutation.createdAt
            )
        }
    }

    private static func optimisticChef(
        authSessionState: NativeAuthSessionState,
        recipes: [Recipe],
        cookbooks: [Cookbook]
    ) -> ChefSummary {
        if let chef = recipes.first?.chef ?? cookbooks.first?.chef {
            return chef
        }

        switch authSessionState {
        case .authenticated(let session), .refreshRequired(let session):
            return ChefSummary(id: session.accountID ?? "signed-out", username: "Spoonjoy")
        case .signedOut:
            return ChefSummary(id: "signed-out", username: "Spoonjoy")
        }
    }

    private static func restoredShoppingList(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot,
        appSnapshot: NativeAppSnapshot?,
        recipes: [Recipe],
        authSessionState: NativeAuthSessionState,
        optimisticMutations: [NativeQueuedMutation]
    ) -> ShoppingListState? {
        let decodedItems = syncSnapshot.cachedRecords
            .filter { $0.kind == .shoppingItem }
            .compactMap { decodedPayload(ShoppingListItem.self, from: $0.payload) }
        let decodedIDs = Set(decodedItems.map(\.id))
        let durableItemIDs = cacheSnapshot.records.compactMap { record -> [String]? in
            guard case .shoppingList(let itemIDs, _) = record.payload else {
                return nil
            }
            return itemIDs
        }.flatMap { $0 }
        let fallbackItems = durableItemIDs.enumerated().compactMap { index, id -> ShoppingListItem? in
            guard !decodedIDs.contains(id) else {
                return nil
            }
            return ShoppingListItem(
                id: id,
                name: id,
                quantity: nil,
                unit: nil,
                checked: false,
                checkedAt: nil,
                deletedAt: nil,
                categoryKey: nil,
                iconKey: nil,
                sortIndex: index,
                updatedAt: NativeLiveAppStoreClock.isoString(cacheSnapshot.createdAt)
            )
        }
        let items = (decodedItems + fallbackItems).sorted { left, right in
            if left.sortIndex == right.sortIndex {
                return left.id < right.id
            }
            return left.sortIndex < right.sortIndex
        }
        let chef = recipes.first?.chef ?? ChefSummary(id: cacheSnapshot.accountID, username: "Spoonjoy")
        let baseShoppingList: ShoppingListState?
        if items.isEmpty {
            if let appShoppingList = appSnapshot?.shoppingList {
                baseShoppingList = appShoppingList
            } else if let checkpoint = syncSnapshot.checkpoint {
                baseShoppingList = ShoppingListState(
                    id: "native-shopping-list",
                    chef: chef,
                    items: [],
                    nextCursor: checkpoint.shoppingCursor?.rawValue ?? "",
                    updatedAt: checkpoint.updatedAt
                )
            } else {
                baseShoppingList = nil
            }
        } else {
            let cursor = syncSnapshot.checkpoint?.shoppingCursor?.rawValue ?? cacheSnapshot.records.compactMap { record -> String? in
                guard case .shoppingList(_, let syncCursor) = record.payload else {
                    return nil
                }
                return syncCursor
            }.first ?? ""
            baseShoppingList = ShoppingListState(
                id: "native-shopping-list",
                chef: chef,
                items: items,
                nextCursor: cursor,
                updatedAt: syncSnapshot.checkpoint?.updatedAt ?? NativeLiveAppStoreClock.isoString(cacheSnapshot.createdAt)
            )
        }
        let fallbackChef = optimisticRecipeChef(authSessionState: authSessionState, recipes: recipes)
        return (optimisticMutations + syncSnapshot.queue.mutations).reduce(baseShoppingList) { shoppingList, mutation in
            mutation.applyingOptimisticShoppingMutation(
                to: shoppingList,
                recipes: recipes,
                fallbackChef: fallbackChef,
                now: mutation.createdAt
            )
        }
    }

    private static func restoredCaptureDraft(cacheSnapshot: NativeDurableCacheSnapshot, appSnapshot: NativeAppSnapshot?) -> CaptureDraft? {
        if let captureDraft = appSnapshot?.captureDraft {
            return captureDraft
        }
        for record in cacheSnapshot.records {
            guard case .captureDraft(let id, let source) = record.payload else {
                continue
            }
            let createdAt = NativeLiveAppStoreClock.isoString(record.metadata.fetchedAt)
            switch source {
            case .shareSheetURL(let url), .text(let url):
                if let draft = try? CaptureDraft.localText(id: id, rawText: url, createdAt: createdAt) {
                    return draft
                }
            case .imageAsset:
                continue
            }
        }
        return nil
    }

    private static func restoredCookProgress(
        cacheSnapshot: NativeDurableCacheSnapshot,
        appSnapshot: NativeAppSnapshot?
    ) -> [String: CookModeProgress] {
        cacheSnapshot.records.reduce(into: appSnapshot?.cookProgressByRecipeID ?? [:]) { result, record in
            guard case .cookProgress(let recipeID, let completedStepIDs, let currentStepID) = record.payload else {
                return
            }
            guard result[recipeID] == nil else {
                return
            }
            result[recipeID] = CookModeProgress(
                recipeID: recipeID,
                completedStepIDs: completedStepIDs,
                currentStepID: currentStepID
            )
        }
    }

    private static func restoredSettingsSurfaceData(cacheSnapshot: NativeDurableCacheSnapshot) -> SettingsSurfaceData? {
        let settingsRecords = cacheSnapshot.records.filter { record in
            switch record.metadata.domain {
            case .settings, .notificationPreferences, .tokenMetadata, .connectionStatus:
                return true
            default:
                return false
            }
        }
        guard !settingsRecords.isEmpty else {
            return nil
        }

        let snapshot = SettingsSurfaceCacheSnapshot(
            accountID: cacheSnapshot.accountID,
            environment: cacheSnapshot.environment,
            records: settingsRecords
        )
        return try? SnapshotSettingsSurfaceRepository(snapshot: snapshot).fetchSettingsSurface().data
    }

    private static func restoreNotificationAPNsSnapshot(cacheSnapshot: NativeDurableCacheSnapshot) -> NotificationAPNsSurfaceData? {
        NotificationAPNsSurfaceData.restoredFromCacheSnapshot(cacheSnapshot, fallbackValidatedAt: cacheSnapshot.createdAt)
    }

    private static func restoredSearchSurfaceSnapshots(cacheSnapshot: NativeDurableCacheSnapshot) -> [SearchSurfaceCacheSnapshot] {
        cacheSnapshot.records.compactMap { record in
            guard case .searchResults(let snapshot) = record.payload,
                  snapshot.accountID == cacheSnapshot.accountID,
                  snapshot.environment == cacheSnapshot.environment,
                  record.metadata.domain == .searchResults(query: snapshot.query, scope: snapshot.scope) else {
                return nil
            }
            return snapshot
        }
    }

    private static func restoredKitchen(
        cacheSnapshot: NativeDurableCacheSnapshot,
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState?
    ) -> KitchenFixtureState {
        let leadRecipe = recipes.first
        let leadID = leadRecipe?.id ?? "live-empty"
        let leadTitle = leadRecipe?.title ?? "Spoonjoy"
        return KitchenFixtureState(
            status: recipes.isEmpty && cookbooks.isEmpty && shoppingList == nil ? .bootstrap : .ready,
            leadObject: .recipe(id: leadID, title: leadTitle),
            primaryAction: .startCookMode(recipeID: leadID),
            counts: KitchenCounts(
                recipes: recipes.count,
                cookbooks: cookbooks.count,
                shoppingItems: shoppingList?.activeItems.count ?? 0
            ),
            offlineRestore: OfflineRestoreMetadata(
                snapshotID: "\(cacheSnapshot.accountID):\(cacheSnapshot.environment.rawValue)",
                includesShoppingList: shoppingList != nil
            )
        )
    }

    private static func decodedPayload<Value: Decodable>(_ type: Value.Type, from payload: JSONValue) -> Value? {
        try? JSONDecoder().decode(type, from: JSONEncoder().encode(payload))
    }

    fileprivate static func encodedPayload<Value: Encodable>(_ value: Value) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    fileprivate static func shoppingCacheRecords(from shoppingList: ShoppingListState?) throws -> [NativeSyncCachedRecord] {
        guard let shoppingList else {
            return []
        }

        return try shoppingList.activeItems.map { item in
            NativeSyncCachedRecord(
                kind: .shoppingItem,
                resourceID: item.id,
                payload: try encodedPayload(item),
                serverRevision: .updatedAt(item.updatedAt)
            )
        }
    }

    private static func placeholderRecipe(id: String, title: String, date: Date) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: title,
            description: nil,
            servings: nil,
            chef: ChefSummary(id: "offline", username: "Spoonjoy"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "Restored from Spoonjoy cache",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: NativeLiveAppStoreClock.isoString(date),
            updatedAt: NativeLiveAppStoreClock.isoString(date),
            steps: [],
            cookbooks: []
        )
    }

    private static func placeholderCookbook(id: String, title: String, date: Date) -> Cookbook {
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
        return Cookbook(
            id: id,
            title: title,
            chef: ChefSummary(id: "offline", username: "Spoonjoy"),
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(creditText: "Restored from Spoonjoy cache", canonicalURL: canonicalURL),
            createdAt: NativeLiveAppStoreClock.isoString(date),
            updatedAt: NativeLiveAppStoreClock.isoString(date),
            recipes: []
        )
    }

    private init(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        cachedProfiles: [NativeCachedProfile],
        kitchen: KitchenFixtureState,
        shoppingList: ShoppingListState?,
        captureDraft: CaptureDraft?,
        cookProgressByRecipeID: [String: CookModeProgress],
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState],
        queuedMutations: [NativeQueuedMutation],
        syncConflicts: [NativeSyncConflict],
        searchSurfaceSnapshots: [SearchSurfaceCacheSnapshot],
        authSessionState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        configuration: APIClientConfiguration,
        offlineIndicatorState: OfflineIndicatorState,
        settingsSurfaceData: SettingsSurfaceData?,
        notificationAPNsSurfaceData: NotificationAPNsSurfaceData?,
        lastSyncedAt: Date? = nil,
        isSessionExpired: Bool = false
    ) {
        self.isSessionExpired = isSessionExpired
        self.lastSyncedAt = lastSyncedAt
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.cachedProfiles = cachedProfiles
        self.kitchen = kitchen
        self.shoppingList = shoppingList
        self.captureDraft = captureDraft
        self.cookProgressByRecipeID = cookProgressByRecipeID
        self.spoonCookLogDraftsByRecipeID = spoonCookLogDraftsByRecipeID
        self.queuedMutations = queuedMutations
        self.syncConflicts = syncConflicts
        self.searchSurfaceSnapshots = searchSurfaceSnapshots
        self.searchResultsByScope = Self.searchResultsByScope(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList
        )
        self.authSessionState = authSessionState
        self.environment = environment
        self.configuration = configuration
        self.offlineIndicatorState = offlineIndicatorState
        self.settingsSurfaceData = settingsSurfaceData
        self.notificationAPNsSurfaceData = notificationAPNsSurfaceData
    }

    private var authState: AuthState {
        switch authSessionState {
        case .signedOut:
            .signedOut
        case .authenticated(let session), .refreshRequired(let session):
            .signedIn(
                username: "Spoonjoy",
                scopes: session.scope.split(separator: " ").map(String.init),
                tokenExpiresAt: NativeLiveAppStoreClock.isoString(session.expiresAt)
            )
        }
    }

    private var spoonjoyEnvironment: SpoonjoyEnvironment {
        switch environment {
        case .production:
            .production(baseURL: configuration.baseURL)
        case .preview, .previewHost:
            .preview(baseURL: configuration.baseURL)
        case .local:
            .local(baseURL: configuration.baseURL)
        }
    }

    private var offlineState: OfflineState {
        switch offlineIndicatorState.display {
        case .synced:
            .available(snapshotCount: max(1, recipes.count + cookbooks.count + (shoppingList?.activeItems.count ?? 0)), lastRestoredAt: nil)
        case .offline, .stale, .dismissed, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            .unavailable
        }
    }

    private var recipeCatalogSource: RecipeCatalogDataSource {
        switch offlineIndicatorState.display {
        case .synced:
            .live(requestID: "native-shell", validatedAt: Date())
        case .offline, .stale, .dismissed, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:
            .cache(serverRevision: latestRecipeRevision, lastValidatedAt: .distantPast)
        }
    }

    private var latestRecipeRevision: NativeCacheServerRevision? {
        recipes
            .map(\.updatedAt)
            .max()
            .map(NativeCacheServerRevision.updatedAt)
    }

    private static func searchResultsByScope(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState?
    ) -> [SearchScope: [String]] {
        SearchScope.allCases.reduce(into: [:]) { results, scope in
            switch scope {
            case .all:
                results[.all] = recipes.map(\.id) + cookbooks.map(\.id) + (shoppingList?.activeItems.map(\.id) ?? [])
            case .recipes:
                results[.recipes] = recipes.map(\.id)
            case .cookbooks:
                results[.cookbooks] = cookbooks.map(\.id)
            case .chefs:
                results[.chefs] = Array(Set((recipes.map(\.chef.id) + cookbooks.map(\.chef.id)))).sorted()
            case .shoppingList:
                results[.shoppingList] = shoppingList?.activeItems.map(\.id) ?? []
            }
        }
    }
}

@MainActor
public final class NativeLiveAppStore: ObservableObject {
    @Published public private(set) var bootstrapState: NativeAppBootstrapState
    @Published public private(set) var restoredRoute: AppRoute?
    @Published public private(set) var shoppingMutationFeedback: ShoppingMutationFeedback?

    private let dependencies: NativeLiveAppStoreDependencies
    private var configuration: APIClientConfiguration
    private var cacheEnvironment: NativeCacheEnvironment
    private var currentContentState: NativeShellContentState
    /// Set when the server refuses the stored session for good, cleared once a session refreshes or signs in.
    private var sessionExpired = false
    private lazy var shoppingMutationCoordinator = ShoppingMutationCoordinator(
        persistAlreadyAppliedBatch: { [unowned self] mutations in
            try await self.persistAlreadyAppliedShoppingBatch(mutations)
        },
        executeRemote: { [unowned self] request in
            try await self.executeShoppingMutationRequest(request)
        },
        fetchShoppingList: { [unowned self] in
            return try await self.fetchShoppingListForReconciliation()
        },
        recordShoppingList: { [weak self] shoppingList in
            self?.recordShoppingList(shoppingList)
        },
        recordFeedback: { [weak self] feedback in
            self?.shoppingMutationFeedback = feedback
        }
    )

    public var authSessionRepository: NativeAuthSessionRepository {
        dependencies.authSessionRepository
    }

    public var syncTriggerCoordinator: NativeSyncTriggerCoordinator {
        dependencies.syncTriggerCoordinator.scoped(
            configuration: configuration,
            scope: NativeSyncExecutionScope(
                expectedAccountID: trustedAccountID(for: currentContentState.authSessionState),
                environment: cacheEnvironment
            )
        )
    }

    public var offlineIndicatorState: OfflineIndicatorState {
        currentContentState.offlineIndicatorState
    }

    public init(dependencies: NativeLiveAppStoreDependencies) {
        self.dependencies = dependencies
        self.configuration = dependencies.configuration
        self.cacheEnvironment = dependencies.cacheEnvironment
        let initialContent = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: dependencies.cacheEnvironment,
            configuration: dependencies.configuration,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        self.currentContentState = initialContent
        self.bootstrapState = .restoringCache(initialContent)
        self.shoppingMutationFeedback = nil
    }

    /// The one task that runs syncs and drains the queue. The store owns it, so no view can cancel a sync by
    /// going away: a screen change, a closed editor or a dismissed sheet only stops waiting for the result.
    private var activeSync: Task<Void, Never>?
    /// Counts edits added to the queue. A run goes again only when this changed while it was running, so a
    /// screen that asks for a sync each time it appears cannot keep the store syncing in a loop.
    private var queueVersion = 0
    /// Recipes whose cook progress should be read from the server at the next sync (a recipe was opened).
    private var cookPullRecipeIDs = Set<String>()
    /// Recipes the server would not take progress for (sync is off, access refused). They are not retried
    /// until the recipe is opened again.
    private var cookSyncOffRecipeIDs = Set<String>()
    /// The change that is waiting for more changes before it asks for a sync.
    var cookPushTask: Task<Void, Never>?
    /// The one task that runs cook-session exchanges on their own, without a full sync.
    private var activeCookSync: Task<Void, Never>?
    /// Counts cook requests; the run goes again only when this changed while it was running.
    private var cookQueueVersion = 0
    /// The last cook-session exchange started, from either kind of sync. A new exchange waits for it, so a
    /// full sync and a cook-only sync never send for the same recipe at the same time.
    private var cookExchangeTail: Task<Void, Never>?

    /// Asks the store to sync and drain the queue. If a sync is already running, this request joins it. The run
    /// goes once more if an edit was queued while it ran, so that edit is still sent. Views call this
    /// and never run the network work themselves. Await the returned task only to wait for the result;
    /// cancelling the waiter does not cancel the sync.
    @discardableResult
    public func requestSync(trigger: NativeSyncTriggerEvent = .foreground) -> Task<Void, Never> {
        if let activeSync {
            return activeSync
        }
        let task = Task { @MainActor [self] in
            var versionAtStart: Int
            repeat {
                versionAtStart = queueVersion
                await performSync(trigger: trigger)
            } while queueVersion != versionAtStart
            activeSync = nil
        }
        activeSync = task
        return task
    }

    /// Waits for the sync that is running now, if any. Safe to await from a view task.
    public func waitForSync() async {
        await activeSync?.value
        await activeCookSync?.value
    }

    /// Asks the store to exchange cook progress with the server and nothing else: no recipe, shopping or
    /// kitchen refresh. Joins a cook sync already running, which goes once more so this request is covered.
    /// Cancelling the waiter does not cancel the sync.
    @discardableResult
    public func requestCookSync() -> Task<Void, Never> {
        if let activeCookSync {
            cookQueueVersion += 1
            return activeCookSync
        }
        let task = Task { @MainActor [self] in
            var versionAtStart: Int
            repeat {
                versionAtStart = cookQueueVersion
                await performCookSync()
            } while cookQueueVersion != versionAtStart
            activeCookSync = nil
        }
        activeCookSync = task
        return task
    }

    private func performCookSync() async {
        guard case .authenticated = currentContentState.authSessionState,
              let session = try? await dependencies.authSessionRepository.validSession() else {
            return
        }
        await runCookExchange(session: session)
    }

    private func runCookExchange(session: AuthSession) async {
        let previous = cookExchangeTail
        let exchange = Task { @MainActor [self] in
            await previous?.value
            await syncCookSessions(session: session)
        }
        cookExchangeTail = exchange
        await exchange.value
    }

    public func bootstrap() async {
        await requestSync(trigger: .launch).value
    }

    /// True when the app is already showing content, so a sync can update it in place instead of covering the
    /// app with the cold-launch loading screen. A fresh account with an empty kitchen counts: it has loaded.
    private var isShowingLoadedContent: Bool {
        switch bootstrapState {
        case .restoringCache, .signedOut:
            return false
        case .syncFailed:
            // A failed first load has nothing to keep on screen: it shows the sync-failed screen with a retry,
            // and that retry shows the loading screen as feedback. A failure after content loaded keeps it.
            let content = currentContentState
            return !content.recipes.isEmpty || !content.cookbooks.isEmpty || !(content.shoppingList?.items.isEmpty ?? true)
        default:
            return true
        }
    }

    private func performSync(trigger: NativeSyncTriggerEvent) async {
        // Set once the vault has been read, so a failure after that point can still show the cached kitchen
        // under the stored account instead of an empty signed-out scope.
        var restoredForRecovery = currentContentState.authSessionState
        do {
            guard !dependencies.fixtureFallbackPolicy.allowsProductionFallback() else {
                throw NativeLiveAppStoreError.fixtureFallbackEnabledInProduction
            }

            let restoredAuthState = try await dependencies.authSessionRepository.restoreState()
            restoredForRecovery = restoredAuthState
            if dependencies.bootstrapMode == .restoreCacheOnly {
                configureForRestoredAuthState(restoredAuthState)
                let restoredContent = try await restoreFromCache(authSessionState: restoredAuthState)
                if case .signedOut = restoredAuthState {
                    apply(.signedOut(restoredContent.copy(
                        offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
                    )))
                } else {
                    apply(Self.restoreCacheOnlyBootstrapState(for: restoredContent))
                }
                return
            }

            let authState = try await authorizedAuthState(from: restoredAuthState)
            guard case .authenticated(let session) = authState else {
                let restoringContent = try await restoreFromCache(authSessionState: authState)
                apply(.signedOut(restoringContent))
                return
            }

            // The loading screen is for a cold launch with nothing cached. A sync that starts with content on
            // screen (a saved edit draining, the app becoming active) updates that content in place.
            if !(isShowingLoadedContent && currentContentState.authSessionState == authState) {
                apply(.restoringCache(emptyContent(authSessionState: authState, display: .synced)))
            }
            try await bootstrapFromLiveAPI(session: session, trigger: trigger)
        } catch let error as APITransportError where error.isOffline {
            NativeLiveAppStoreTelemetry.bootstrapOffline(
                stage: "launch",
                error: error,
                authState: currentContentState.authSessionState,
                environment: cacheEnvironment,
                route: restoredRoute,
                contentState: currentContentState
            )
            await reportNativeTelemetry(
                name: .bootstrapOffline,
                stage: "launch",
                error: error,
                authState: currentContentState.authSessionState,
                route: restoredRoute,
                contentState: currentContentState
            )
            let offlineContent = (try? await restoreFromCache(authSessionState: restoredForRecovery)) ?? currentContentState
            apply(.offlineStale(offlineContent.copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))))
        } catch TokenRefreshError.sessionExpired {
            await applySessionExpired(restoredAuthState: restoredForRecovery)
        } catch TokenRefreshError.sessionRevoked {
            await applySessionRevoked(restoredAuthState: restoredForRecovery)
        } catch {
            NativeLiveAppStoreTelemetry.bootstrapFailed(
                stage: "launch",
                error: error,
                authState: currentContentState.authSessionState,
                environment: cacheEnvironment,
                route: restoredRoute,
                contentState: currentContentState
            )
            await reportNativeTelemetry(
                name: .bootstrapFailed,
                stage: "launch",
                error: error,
                authState: currentContentState.authSessionState,
                route: restoredRoute,
                contentState: currentContentState
            )
            if !hasKitchenContent(currentContentState),
               let cached = try? await restoreFromCache(authSessionState: restoredForRecovery) {
                currentContentState = cached
            }
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "bootstrap", retryAfter: nil), dismissal: nil)),
                message: NativeLiveAppStoreTelemetry.failureMessage(for: error)
            ))
        }
    }

    /// The server refused the stored refresh token for good. Syncing stops and a sign-in is offered, but the
    /// account scope does not change: the cached kitchen, the queued edits and every unsynced draft stay under
    /// the chef's own account, still readable and still editable. The expired session stays in the vault (a
    /// later sync tries it once more at launch), and a fresh sign-in replaces it.
    private func applySessionExpired(restoredAuthState: NativeAuthSessionState) async {
        sessionExpired = true
        configuration = APIClientConfiguration(baseURL: dependencies.configuration.baseURL)
        let scope = restoredAuthState.keepingStoredScope
        let cached = (try? await restoreFromCache(authSessionState: scope)) ?? emptyContent(authSessionState: scope, display: .stale(domain: .accountBootstrap))
        let content = cached.copy(
            offlineIndicatorState: OfflineIndicatorState(display: .stale(domain: .accountBootstrap), dismissal: nil),
            authSessionState: scope
        )
        currentContentState = content
        if hasKitchenContent(content) {
            apply(.offlineStale(content))
        } else {
            apply(.signedOut(content))
        }
    }

    /// The server said the chef revoked this session on purpose ("sign out everywhere", a password change,
    /// account deletion). Unlike an expiry, the device forgets the account: search indexes, the cached kitchen
    /// and its drafts, and the Keychain session.
    private func applySessionRevoked(restoredAuthState: NativeAuthSessionState) async {
        sessionExpired = false
        let scope = restoredAuthState.keepingStoredScope
        if let cached = try? await restoreFromCache(authSessionState: scope) {
            currentContentState = cached
        }
        await purgeLocalAccountData()
        try? await dependencies.authSessionRepository.clearLocalSession()
        configuration = APIClientConfiguration(baseURL: dependencies.configuration.baseURL)
        let content = (try? await restoreFromCache(authSessionState: .signedOut)) ?? emptyContent(authSessionState: .signedOut, display: .synced)
        apply(.signedOut(content))
    }

    private func hasKitchenContent(_ content: NativeShellContentState) -> Bool {
        !content.recipes.isEmpty || !content.cookbooks.isEmpty || !(content.shoppingList?.activeItems.isEmpty ?? true)
    }

    public func switchEnvironment(_ environment: NativeCacheEnvironment) async {
        shoppingMutationCoordinator.resetScope()
        cacheEnvironment = environment
        configuration = APIClientConfiguration(baseURL: configuration.baseURL, bearerToken: configuration.bearerToken)
        let authSessionState = currentContentState.authSessionState
        apply(.restoringCache(emptyContent(authSessionState: authSessionState, display: .stale(domain: .accountBootstrap))))

        do {
            guard case .authenticated(let session) = authSessionState else {
                let content = try await restoreFromCache(authSessionState: authSessionState)
                apply(.signedOut(content))
                return
            }
            try await bootstrapFromLiveAPI(
                session: session,
                trigger: NativeSyncTriggerEvent.environmentChanged(environment)
            )
        } catch let error as APITransportError where error.isOffline {
            NativeLiveAppStoreTelemetry.bootstrapOffline(
                stage: "environment",
                error: error,
                authState: authSessionState,
                environment: cacheEnvironment,
                route: restoredRoute,
                contentState: currentContentState
            )
            await reportNativeTelemetry(
                name: .bootstrapOffline,
                stage: "environment",
                error: error,
                authState: authSessionState,
                route: restoredRoute,
                contentState: currentContentState
            )
            let offlineContent = (try? await restoreFromCache(authSessionState: authSessionState)) ?? currentContentState
            apply(.offlineStale(offlineContent.copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))))
        } catch TokenRefreshError.sessionExpired {
            await applySessionExpired(restoredAuthState: authSessionState)
        } catch TokenRefreshError.sessionRevoked {
            await applySessionRevoked(restoredAuthState: authSessionState)
        } catch {
            NativeLiveAppStoreTelemetry.bootstrapFailed(
                stage: "environment",
                error: error,
                authState: authSessionState,
                environment: cacheEnvironment,
                route: restoredRoute,
                contentState: currentContentState
            )
            await reportNativeTelemetry(
                name: .bootstrapFailed,
                stage: "environment",
                error: error,
                authState: authSessionState,
                route: restoredRoute,
                contentState: currentContentState
            )
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "environment", retryAfter: nil), dismissal: nil)),
                message: NativeLiveAppStoreTelemetry.failureMessage(for: error)
            ))
        }
    }

    public func dismissOfflineIndicator() {
        let reducer = OfflineIndicatorReducer(accountID: accountID, environment: cacheEnvironment)
        let reduced = reducer.reduce(
            currentContentState.offlineIndicatorState,
            .dismissCurrentIndicator(at: dependencies.now(), cacheFingerprint: cacheFingerprint)
        )
        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(offlineIndicatorState: reduced)))
    }

    public var currentSearchSurfaceIdentity: String {
        currentContentState.searchSurfaceIdentity
    }

    public func searchSurfaceRepository(context: SearchSurfaceContext) -> any SearchSurfaceRepository {
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        return LiveSearchSurfaceRepository(
            transport: dependencies.recipeEditorAPITransport(refresher),
            configuration: configuration,
            context: context
        )
    }

    public func recordSearchSurfacePage(_ page: SearchSurfacePage, expectedIdentity: String) throws {
        guard currentSearchSurfaceIdentity == expectedIdentity else {
            return
        }

        let snapshot = searchSurfaceCacheSnapshot(from: page)
        let domain = NativeCacheDomain.searchResults(query: snapshot.query, scope: snapshot.scope)
        let record = try NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: snapshot.accountID,
                environment: snapshot.environment,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: dependencies.now(),
                lastValidatedAt: snapshot.lastValidatedAt,
                sourceEndpoint: "/api/v1/search",
                serverRevision: snapshot.serverRevision
            ),
            payload: .searchResults(snapshot)
        )
        let fallbackSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: snapshot.accountID,
            environment: snapshot.environment,
            createdAt: dependencies.now(),
            records: [],
            dismissedIndicators: []
        )
        let currentSnapshot = try dependencies.cacheStore.loadOrRecover(fallback: fallbackSnapshot)
        let canSaveDurableSnapshot = currentSnapshot.source != .file ||
            (currentSnapshot.value.accountID == snapshot.accountID && currentSnapshot.value.environment == snapshot.environment)
        if canSaveDurableSnapshot {
            let nextRecords = currentSnapshot.value.records.filter { $0.id != record.id } + [record]
            try dependencies.cacheStore.save(try currentSnapshot.value.copy(records: nextRecords))
        }

        let nextSearchSnapshots = currentContentState.searchSurfaceSnapshots.filter { existing in
            existing.environment != snapshot.environment ||
                existing.accountID != snapshot.accountID ||
                existing.query != snapshot.query ||
                existing.scope != snapshot.scope
        } + [snapshot]
        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(searchSurfaceSnapshots: nextSearchSnapshots)))
    }

    public func queueMutation(_ mutation: NativeQueuedMutation) async throws {
        try await queueMutations([mutation])
    }

    public func performShoppingMutation(_ plan: ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome {
        try await shoppingMutationCoordinator.submit(plan)
    }

    public func retryShoppingMutationRecovery() async throws -> ShoppingSurfaceMutationOutcome {
        try await shoppingMutationCoordinator.retryCurrentRecovery()
    }

    private func persistAlreadyAppliedShoppingBatch(_ mutations: [NativeQueuedMutation]) async throws {
        let scopedQueue = try await queueForCurrentScope()
        let nextQueue = try scopedQueue.queue.appending(contentsOf: mutations)
        for mutation in mutations {
            try mutation.saveStagedMedia(to: dependencies.stagedMediaDirectory)
        }
        try await dependencies.syncStore.saveQueue(
            nextQueue,
            accountID: scopedQueue.accountID,
            environment: scopedQueue.environment,
            upsertingCachedRecords: try NativeShellContentState.shoppingCacheRecords(from: currentContentState.shoppingList),
            deletingCachedRecordKeys: []
        )
        let indicator = OfflineIndicatorState(
            display: .queuedWork(
                count: nextQueue.mutations.count,
                oldestClientMutationID: nextQueue.mutations.first?.clientMutationID
            ),
            dismissal: nil
        )
        apply(.queuedWork(currentContentState.copy(
            queuedMutations: nextQueue.mutations,
            offlineIndicatorState: indicator
        )))
    }

    @discardableResult
    public func queueMutations(_ mutations: [NativeQueuedMutation], drainImmediately: Bool = false) async throws -> NativeQueuedMutationBatchResult {
        let submittedClientMutationIDs = mutations.map(\.clientMutationID)
        guard !mutations.isEmpty else {
            return NativeQueuedMutationBatchResult(
                submittedClientMutationIDs: [],
                drainedClientMutationIDs: [],
                remainingSubmittedClientMutationIDs: [],
                submittedConflicts: []
            )
        }

        do {
            let scopedQueue = try await queueForCurrentScope()
            let queue = scopedQueue.queue
            let nextQueue = try queue.appending(contentsOf: mutations)
            let baseShoppingCacheRecords = try NativeShellContentState.shoppingCacheRecords(from: currentContentState.shoppingList)
            for mutation in mutations {
                try mutation.saveStagedMedia(to: dependencies.stagedMediaDirectory)
            }
            try await dependencies.syncStore.saveQueue(
                nextQueue,
                accountID: scopedQueue.accountID,
                environment: scopedQueue.environment,
                upsertingCachedRecords: baseShoppingCacheRecords,
                deletingCachedRecordKeys: []
            )
            let indicator = OfflineIndicatorState(
                display: .queuedWork(
                    count: nextQueue.mutations.count,
                    oldestClientMutationID: nextQueue.mutations.first?.clientMutationID
                ),
                dismissal: nil
            )
            let fallbackChef = optimisticRecipeChef
            let optimisticRecipes = mutations.reduce(currentContentState.recipes) { recipes, mutation in
                mutation.applyingOptimisticRecipeMutation(
                    to: recipes,
                    fallbackChef: fallbackChef,
                    now: NativeLiveAppStoreClock.isoString(dependencies.now())
                )
            }
            let optimisticShoppingList = mutations.reduce(currentContentState.shoppingList) { shoppingList, mutation in
                mutation.applyingOptimisticShoppingMutation(
                    to: shoppingList,
                    recipes: optimisticRecipes,
                    fallbackChef: fallbackChef,
                    now: mutation.createdAt
                )
            }
            let optimisticCookbooks = mutations.reduce(currentContentState.cookbooks) { cookbooks, mutation in
                mutation.applyingOptimisticCookbookMutation(
                    to: cookbooks,
                    fallbackChef: fallbackChef,
                    recipes: optimisticRecipes,
                    now: mutation.createdAt
                )
            }
            queueVersion += 1
            apply(.queuedWork(currentContentState.copy(
                recipes: optimisticRecipes,
                cookbooks: optimisticCookbooks,
                shoppingList: optimisticShoppingList,
                queuedMutations: nextQueue.mutations,
                offlineIndicatorState: indicator
            )))
            if drainImmediately {
                // The store's own sync task drains the queue, so the caller going away cannot cancel it.
                await requestSync(trigger: .foreground).value
            }
            return queuedMutationBatchResult(submittedClientMutationIDs: submittedClientMutationIDs)
        } catch {
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "queue", retryAfter: nil), dismissal: nil)),
                message: String(describing: error)
            ))
            throw error
        }
    }

    private func queuedMutationBatchResult(submittedClientMutationIDs: [String]) -> NativeQueuedMutationBatchResult {
        let submitted = Set(submittedClientMutationIDs)
        let remaining = currentContentState.queuedMutations
            .map(\.clientMutationID)
            .filter { submitted.contains($0) }
        let conflicts = currentContentState.syncConflicts
            .filter { submitted.contains($0.clientMutationID) }
        let blocked = Set(remaining).union(conflicts.map(\.clientMutationID))
        let drained = submittedClientMutationIDs.filter { !blocked.contains($0) }
        return NativeQueuedMutationBatchResult(
            submittedClientMutationIDs: submittedClientMutationIDs,
            drainedClientMutationIDs: drained,
            remainingSubmittedClientMutationIDs: remaining,
            submittedConflicts: conflicts
        )
    }

    public func discardQueuedMutation(clientMutationID: String) async throws {
        let trimmedClientMutationID = clientMutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientMutationID.isEmpty else {
            return
        }

        let scopedQueue = try await queueForCurrentScope()
        guard scopedQueue.queue.mutations.contains(where: { $0.clientMutationID == trimmedClientMutationID }) else {
            return
        }

        let existingConflicts = currentContentState.syncConflicts
        let clientMutationIDsToDiscard = Self.clientMutationIDsToDiscard(
            from: scopedQueue.queue,
            startingAt: trimmedClientMutationID
        )
        let nextQueue = try scopedQueue.queue.removing(clientMutationIDs: clientMutationIDsToDiscard)
        try await dependencies.syncStore.saveQueue(
            nextQueue,
            accountID: scopedQueue.accountID,
            environment: scopedQueue.environment
        )

        let restoredContent = try await restoreFromCache(authSessionState: currentContentState.authSessionState)
        let remainingConflicts = existingConflicts.filter { !clientMutationIDsToDiscard.contains($0.clientMutationID) }
        let content = restoredContent.copy(syncConflicts: remainingConflicts)
        if let conflict = remainingConflicts.first {
            apply(.conflict(content.copy(
                offlineIndicatorState: OfflineIndicatorState(display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID), dismissal: nil)
            )))
        } else if !content.queuedMutations.isEmpty {
            apply(.queuedWork(content.copy(
                offlineIndicatorState: OfflineIndicatorState(
                    display: .queuedWork(count: content.queuedMutations.count, oldestClientMutationID: content.queuedMutations.first?.clientMutationID),
                    dismissal: nil
                )
            )))
        } else {
            apply(.offlineStale(content))
        }
    }

    /// Sends held changes to the server again. A change the server turned down stays in the queue with its
    /// message; this runs another sync so it is submitted once more. If the server still turns it down it
    /// returns to the held state with the new message.
    public func retryHeldChanges() async {
        await bootstrap()
    }

    public func executeRecipeEditorRequest(_ request: APIRequestBuilder) async throws {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        let transport = dependencies.recipeEditorAPITransport(refresher)
        _ = try await transport.send(
            request,
            configuration: configuration,
            decode: JSONValue.self
        )
        await bootstrap()
    }

    /// Sends a create-recipe request and returns the new recipe's ID, so a photo chosen in the editor can
    /// be uploaded to it.
    public func executeRecipeCreateRequest(_ request: APIRequestBuilder) async throws -> String? {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        let transport = dependencies.recipeEditorAPITransport(refresher)
        let envelope = try await transport.send(
            request,
            configuration: configuration,
            decode: JSONValue.self
        )
        await bootstrap()
        return RecipeCreateResponse.recipeID(from: envelope.data)
    }

    private func executeShoppingMutationRequest(_ request: APIRequestBuilder) async throws {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        let transport = dependencies.recipeEditorAPITransport(refresher)
        _ = try await transport.send(request, configuration: configuration, decode: JSONValue.self)
    }

    private func fetchShoppingListForReconciliation() async throws -> ShoppingListState {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        return try await LiveShoppingSurfaceRepository(
            transport: dependencies.recipeEditorAPITransport(refresher),
            configuration: configuration
        ).fetchShoppingList()
    }

    public func executeSettingsActionRequest(
        _ request: APIRequestBuilder,
        responseHandling: SettingsActionResponseHandling
    ) async throws -> SettingsActionOutcome? {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        let transport = dependencies.recipeEditorAPITransport(refresher)

        switch responseHandling {
        case .refreshOnly:
            _ = try await transport.send(
                request,
                configuration: configuration,
                decode: JSONValue.self
            )
            await bootstrap()
            return nil
        case .captureCreatedAPIToken:
            let envelope = try await transport.send(
                request,
                configuration: configuration,
                decode: SettingsCreatedAPIToken.self
            )
            await bootstrap()
            return .createdAPIToken(envelope.data)
        }
    }

    public func executeCaptureImportRequest(_ request: APIRequestBuilder) async throws -> RecipeImportResponse {
        let session = try await dependencies.authSessionRepository.validSession()
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: session.accessToken
        )
        let refresher = NativeLiveAppStoreAPIRefresher(
            authSessionRepository: dependencies.authSessionRepository,
            baseURL: dependencies.configuration.baseURL
        )
        let transport = dependencies.recipeEditorAPITransport(refresher)
        let envelope = try await transport.send(
            request,
            configuration: configuration,
            decode: RecipeImportResponse.self
        )
        if let recipe = envelope.data.recipe {
            var recipes = currentContentState.recipes.filter { $0.id != recipe.id }
            recipes.insert(recipe, at: 0)
            apply(stateMatchingCurrentSeverity(with: currentContentState.copy(recipes: recipes)))
        }
        return envelope.data
    }

    /// Removes the signed-in account's private data from the system search and entity indexes on this device.
    private func purgeLocalAccountData() async {
        shoppingMutationCoordinator.resetScope()
        let currentAccountID = accountID
        let shoppingItemIDs = currentContentState.shoppingList?.activeItems.map(\.id) ?? []
        let makePurgePlan = ShoppingEntityIndexPurgePlan.accountScopePurge(accountID:environment:shoppingItemIDs:)
        let purgePlan = makePurgePlan(currentAccountID, cacheEnvironment, shoppingItemIDs)
        await purgeShoppingEntityIdentifiers(ShoppingEntityCatalog.purgeEntityIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: purgePlan
        ), domainIdentifiers: ShoppingEntityCatalog.purgeDomainIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: purgePlan
        ), accountID: currentAccountID, environment: cacheEnvironment)
        let spoonIDs = currentContentState.recipes.flatMap { recipe in
            recipe.recentSpoons.compactMap { spoon in
                spoon.deletedAt == nil ? spoon.id : nil
            }
        }
        let spoonPurgePlan = SpoonEntityIndexPurgePlan.accountScopePurge(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            spoonIDs: spoonIDs
        )
        await purgeSpoonEntityIdentifiers(SpoonEntityCatalog.purgeEntityIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: spoonPurgePlan
        ), domainIdentifiers: SpoonEntityCatalog.purgeDomainIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: spoonPurgePlan
        ), accountID: currentAccountID, environment: cacheEnvironment)
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        let captureDraftSnapshot = currentContentState.captureDraft.map { draft in
            NativeAppSnapshot.bootstrap(
                shoppingList: currentContentState.shoppingList,
                accountID: currentAccountID,
                environment: cacheEnvironment,
                savedAt: savedAt
            ).recordingCaptureDraft(draft, savedAt: savedAt)
        }
        let captureDraftPurgePlan = CaptureDraftEntityIndexPurgePlan.accountScopePurge(
            appSnapshot: captureDraftSnapshot,
            cacheSnapshot: nil,
            accountID: currentAccountID,
            environment: cacheEnvironment
        )
        await purgeCaptureDraftEntityIdentifiers(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: captureDraftPurgePlan
        ), domainIdentifiers: CaptureDraftEntityCatalog.purgeDomainIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: captureDraftPurgePlan
        ), accountID: currentAccountID, environment: cacheEnvironment)
        let chefProfileIDs = currentContentState.cachedProfiles.map(\.profile.id)
        let chefProfilePurgePlan = ChefProfileEntityIndexPurgePlan.accountScopePurge(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            profileIDs: chefProfileIDs
        )
        await purgeChefProfileEntityIdentifiers(ChefProfileEntityCatalog.purgeEntityIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: chefProfilePurgePlan
        ), domainIdentifiers: ChefProfileEntityCatalog.purgeDomainIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: chefProfilePurgePlan
        ), accountID: currentAccountID, environment: cacheEnvironment)
        let recipeCookbookPurgePlan = RecipeCookbookEntityIndexPurgePlan.accountScopePurge(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            recipeIDs: currentContentState.recipes.map(\.id),
            cookbookIDs: currentContentState.cookbooks.map(\.id)
        )
        await purgeRecipeCookbookEntityIdentifiers(RecipeCookbookEntityCatalog.purgeEntityIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: recipeCookbookPurgePlan
        ), domainIdentifiers: RecipeCookbookEntityCatalog.purgeDomainIdentifiers(
            accountID: currentAccountID,
            environment: cacheEnvironment,
            plan: recipeCookbookPurgePlan
        ), accountID: currentAccountID, environment: cacheEnvironment)
    }

    public func performSettingsSessionOperation(_ operation: SettingsSessionOperation) async throws {
        switch operation {
        case .logout, .revokeAndLogout:
            await purgeLocalAccountData()
            try await dependencies.authSessionRepository.revokeAndLogout()
        }
        await bootstrap()
    }

    public func purgeShoppingEntityIdentifiers(
        _ identifiers: [String],
        domainIdentifiers: [String] = [],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async {
        let uniqueIdentifiers = Self.uniquePreservingOrder(identifiers)
        let uniqueDomainIdentifiers = Self.uniquePreservingOrder(domainIdentifiers)
        let request = NativeShoppingEntityIndexPurgeRequest(
            identifiers: uniqueIdentifiers,
            domainIdentifiers: uniqueDomainIdentifiers,
            accountID: accountID ?? self.accountID,
            environment: environment ?? cacheEnvironment
        )
        guard !request.isEmpty else {
            return
        }

        await dependencies.shoppingEntityIndexPurge(request)
    }

    public func purgeSpoonEntityIdentifiers(
        _ identifiers: [String],
        domainIdentifiers: [String] = [],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async {
        let uniqueIdentifiers = Self.uniquePreservingOrder(identifiers)
        let uniqueDomainIdentifiers = Self.uniquePreservingOrder(domainIdentifiers)
        let request = NativeSpoonEntityIndexPurgeRequest(
            identifiers: uniqueIdentifiers,
            domainIdentifiers: uniqueDomainIdentifiers,
            accountID: accountID ?? self.accountID,
            environment: environment ?? cacheEnvironment
        )
        guard !request.isEmpty else {
            return
        }

        await dependencies.spoonEntityIndexPurge(request)
    }

    public func purgeCaptureDraftEntityIdentifiers(
        _ identifiers: [String],
        domainIdentifiers: [String] = [],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async {
        let uniqueIdentifiers = Self.uniquePreservingOrder(identifiers)
        let uniqueDomainIdentifiers = Self.uniquePreservingOrder(domainIdentifiers)
        let request = NativeCaptureDraftEntityIndexPurgeRequest(
            identifiers: uniqueIdentifiers,
            domainIdentifiers: uniqueDomainIdentifiers,
            accountID: accountID ?? self.accountID,
            environment: environment ?? cacheEnvironment
        )
        guard !request.isEmpty else {
            return
        }

        await dependencies.captureDraftEntityIndexPurge(request)
    }

    public func purgeChefProfileEntityIdentifiers(
        _ identifiers: [String],
        domainIdentifiers: [String] = [],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async {
        let uniqueIdentifiers = Self.uniquePreservingOrder(identifiers)
        let uniqueDomainIdentifiers = Self.uniquePreservingOrder(domainIdentifiers)
        let request = NativeChefProfileEntityIndexPurgeRequest(
            identifiers: uniqueIdentifiers,
            domainIdentifiers: uniqueDomainIdentifiers,
            accountID: accountID ?? self.accountID,
            environment: environment ?? cacheEnvironment
        )
        guard !request.isEmpty else {
            return
        }

        await dependencies.chefProfileEntityIndexPurge(request)
    }

    public func purgeRecipeCookbookEntityIdentifiers(
        _ identifiers: [String],
        domainIdentifiers: [String] = [],
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil
    ) async {
        let uniqueIdentifiers = Self.uniquePreservingOrder(identifiers)
        let uniqueDomainIdentifiers = Self.uniquePreservingOrder(domainIdentifiers)
        let request = NativeRecipeCookbookEntityIndexPurgeRequest(
            identifiers: uniqueIdentifiers,
            domainIdentifiers: uniqueDomainIdentifiers,
            accountID: accountID ?? self.accountID,
            environment: environment ?? cacheEnvironment
        )
        guard !request.isEmpty else {
            return
        }

        await dependencies.recipeCookbookEntityIndexPurge(request)
    }

    private var optimisticRecipeChef: ChefSummary {
        currentContentState.recipes.first?.chef ?? currentContentState.cookbooks.first?.chef ?? ChefSummary(id: accountID, username: "Spoonjoy")
    }

    private static func clientMutationIDsToDiscard(
        from queue: NativeMutationQueue,
        startingAt clientMutationID: String
    ) -> Set<String> {
        let discarded = queue.mutations.first { $0.clientMutationID == clientMutationID }
        let discardedDependencyKey = discarded?.dependencyKey
        let discardedLocalRecipeID = discarded?.queueableKind == .recipeCreate ? discarded?.optimisticRecipeID : nil
        return Set(queue.mutations.compactMap { mutation in
            if mutation.clientMutationID == clientMutationID {
                return mutation.clientMutationID
            }
            if let discardedDependencyKey, mutation.dependencyKey == discardedDependencyKey {
                return mutation.clientMutationID
            }
            if let discardedLocalRecipeID, mutation.recipeID == discardedLocalRecipeID {
                return mutation.clientMutationID
            }
            return nil
        })
    }

    private func queueForCurrentScope() async throws -> (queue: NativeMutationQueue, accountID: String?, environment: NativeCacheEnvironment?) {
        let snapshot = try await dependencies.syncStore.loadSnapshot()
        guard let expectedAccountID = trustedAccountID(for: currentContentState.authSessionState) else {
            return (NativeMutationQueue(), nil, nil)
        }
        guard snapshot.accountID == expectedAccountID,
              snapshot.environment == cacheEnvironment else {
            return (NativeMutationQueue(), expectedAccountID, cacheEnvironment)
        }
        return (try await dependencies.syncStore.loadQueue(), expectedAccountID, cacheEnvironment)
    }

    public func recordingOpenedRoute(_ route: AppRoute) {
        guard let appStateStore = dependencies.appStateStoreProvider() else {
            return
        }

        do {
            let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: currentContentState.shoppingList,
                accountID: accountID,
                environment: cacheEnvironment,
                savedAt: savedAt
            )
            let record = try appStateStore.loadOrCreate(fallback: fallback)
            let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                ? record.value
                : fallback
            try appStateStore.save(
                baseSnapshot
                    .completingFirstRun(savedAt: savedAt)
                    .recordingOpenedRoute(route, savedAt: savedAt)
            )
        } catch {
            return
        }
    }

    public func recordCookProgress(_ progress: CookModeProgress) {
        guard let appStateStore = dependencies.appStateStoreProvider() else {
            return
        }

        do {
            let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: currentContentState.shoppingList,
                accountID: accountID,
                environment: cacheEnvironment,
                savedAt: savedAt
            )
            let record = try appStateStore.loadOrCreate(fallback: fallback)
            let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                ? record.value
                : fallback
            try appStateStore.save(
                baseSnapshot
                    .completingFirstRun(savedAt: savedAt)
                    .updatingCookProgress(progress, savedAt: savedAt)
            )

            var nextProgress = currentContentState.cookProgressByRecipeID
            nextProgress[progress.recipeID] = progress
            apply(stateMatchingCurrentSeverity(with: currentContentState.copy(cookProgressByRecipeID: nextProgress)))
            scheduleCookSessionPush(recipeID: progress.recipeID)
        } catch {
            return
        }
    }

    /// A recipe was opened in cook mode: read its progress from the server at the next sync, so a step or
    /// checked ingredient from another device shows up. Returns at once; the store's sync does the network work.
    public func cookModeOpened(recipeID: String) {
        guard case .authenticated = currentContentState.authSessionState else {
            return
        }
        cookPullRecipeIDs.insert(recipeID)
        cookSyncOffRecipeIDs.remove(recipeID)
        requestCookSync()
    }

    // A tap on an ingredient, then another, then a step: the exchange waits for a short pause so they go together.
    private func scheduleCookSessionPush(recipeID: String) {
        guard case .authenticated = currentContentState.authSessionState else {
            return
        }
        cookSyncOffRecipeIDs.remove(recipeID)
        cookPushTask?.cancel()
        let delay = dependencies.cookSessionPushDelay
        cookPushTask = Task { @MainActor [self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            await requestCookSync().value
        }
    }

    /// Exchanges cook progress with the server for recipes with changes the server has not seen and for
    /// recipes just opened. Runs as part of the store's full sync and on its own through `requestCookSync`. Nothing here shows an error: when the server will
    /// not take progress (sync off, 403) or cannot be reached, progress stays on the device and goes later.
    private func syncCookSessions(session: AuthSession) async {
        guard dependencies.bootstrapMode == .liveFirst,
              let appStateStore = dependencies.appStateStoreProvider() else {
            return
        }
        let reconciler = CookSessionReconciler(client: dependencies.cookSessionClient(
            APIClientConfiguration(baseURL: configuration.baseURL, bearerToken: session.accessToken)
        ))
        let pulls = cookPullRecipeIDs
        var recipeIDs = pulls
        if let snapshot = try? scopedAppSnapshot(appStateStore) {
            for (recipeID, progress) in snapshot.cookProgressByRecipeID
            where !cookSyncOffRecipeIDs.contains(recipeID) &&
                !progress.syncProgress.isSame(as: snapshot.cookSessionServerByRecipeID[recipeID]?.progress ?? .initial) {
                recipeIDs.insert(recipeID)
            }
        }

        for recipeID in recipeIDs.sorted() {
            guard let snapshot = try? scopedAppSnapshot(appStateStore),
                  let progress = snapshot.cookProgress(for: recipeID) ?? startingCookProgress(recipeID: recipeID),
                  !progress.stepIDs.isEmpty else {
                cookPullRecipeIDs.remove(recipeID)
                continue
            }
            let sent = progress.syncProgress
            let result = await reconciler.reconcile(
                recipeID: recipeID,
                local: sent,
                known: snapshot.cookSessionServerByRecipeID[recipeID],
                pull: pulls.contains(recipeID),
                bounds: progress.syncBounds
            )

            switch result.outcome {
            case .synced:
                cookPullRecipeIDs.remove(recipeID)
                applyCookSyncResult(result, sent: sent, recipeID: recipeID, appStateStore: appStateStore)
            case .off:
                cookPullRecipeIDs.remove(recipeID)
                cookSyncOffRecipeIDs.insert(recipeID)
            case .retryLater, .signedOut:
                return
            }
        }
    }

    private func startingCookProgress(recipeID: String) -> CookModeProgress? {
        currentContentState.recipes.first { $0.id == recipeID }.map {
            CookModeProgress.starting(recipe: $0, startedAt: NativeLiveAppStoreClock.isoString(dependencies.now()))
        }
    }

    // Saves the exchange's result. Changes made on this device while the exchange was running are replayed on
    // top of the server's progress so they are not lost; they go out at the next sync.
    private func applyCookSyncResult(
        _ result: CookSyncReconciliation,
        sent: CookSyncProgress,
        recipeID: String,
        appStateStore: NativeAppStateStore
    ) {
        do {
            let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
            let snapshot = try scopedAppSnapshot(appStateStore)
            let existing = snapshot.cookProgress(for: recipeID) ?? startingCookProgress(recipeID: recipeID)
            var next = existing
            if let existing {
                let merged = CookSyncProgress.merge(base: sent, local: existing.syncProgress, remote: result.progress)
                    .normalized(to: existing.syncBounds)
                if !merged.isSame(as: existing.syncProgress) {
                    next = existing.applyingSyncProgress(merged, updatedAt: savedAt)
                }
            }
            let keepsRecord = snapshot.cookProgress(for: recipeID) != nil || next != existing ||
                result.server != nil
            try appStateStore.save(
                snapshot
                    .completingFirstRun(savedAt: savedAt)
                    .updatingCookSync(
                        progress: keepsRecord ? next : nil,
                        server: result.server,
                        recipeID: recipeID,
                        savedAt: savedAt
                    )
            )
            if keepsRecord, let next {
                var nextProgress = currentContentState.cookProgressByRecipeID
                nextProgress[recipeID] = next
                apply(stateMatchingCurrentSeverity(with: currentContentState.copy(cookProgressByRecipeID: nextProgress)))
            }
        } catch {
            return
        }
    }

    private func scopedAppSnapshot(_ appStateStore: NativeAppStateStore) throws -> NativeAppSnapshot {
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        let fallback = NativeAppSnapshot.bootstrap(
            shoppingList: currentContentState.shoppingList,
            accountID: accountID,
            environment: cacheEnvironment,
            savedAt: savedAt
        )
        let record = try appStateStore.loadOrCreate(fallback: fallback)
        return record.value.isScoped(accountID: accountID, environment: cacheEnvironment) ? record.value : fallback
    }

    public func recordShoppingList(_ shoppingList: ShoppingListState) {
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        if let appStateStore = dependencies.appStateStoreProvider() {
            do {
                let fallback = NativeAppSnapshot.bootstrap(
                    shoppingList: currentContentState.shoppingList,
                    accountID: accountID,
                    environment: cacheEnvironment,
                    savedAt: savedAt
                )
                let record = try appStateStore.loadOrCreate(fallback: fallback)
                let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                    ? record.value
                    : fallback
                try appStateStore.save(
                    try baseSnapshot
                        .completingFirstRun(savedAt: savedAt)
                        .updatingShoppingList(shoppingList, queuedMutation: nil, savedAt: savedAt)
                )
            } catch {
                // Keep the live app responsive even if the optional app snapshot write fails.
            }
        }

        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(shoppingList: shoppingList)))
    }

    public func recordCaptureDraft(_ draft: CaptureDraft) {
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        if let appStateStore = dependencies.appStateStoreProvider() {
            do {
                let fallback = NativeAppSnapshot.bootstrap(
                    shoppingList: currentContentState.shoppingList,
                    accountID: accountID,
                    environment: cacheEnvironment,
                    savedAt: savedAt
                )
                let record = try appStateStore.loadOrCreate(fallback: fallback)
                let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                    ? record.value
                    : fallback
                try appStateStore.save(
                    baseSnapshot
                        .completingFirstRun(savedAt: savedAt)
                        .recordingCaptureDraft(draft, savedAt: savedAt)
                )
            } catch {
                apply(.syncFailed(
                    currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "capture-draft", retryAfter: nil), dismissal: nil)),
                    message: "Capture draft could not be saved offline."
                ))
                return
            }
        }

        let cacheDeletePlan = CaptureDraftEntityIndexPurgePlan.cacheDeletePurge(
            deletedRecordDomains: [.captureDraft(id: draft.id)],
            accountID: accountID,
            environment: cacheEnvironment
        )
        Task {
            await purgeCaptureDraftEntityIdentifiers(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
                accountID: accountID,
                environment: cacheEnvironment,
                plan: cacheDeletePlan
            ))
        }
        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(captureDraft: .some(draft))))
    }

    public func discardCaptureDraft(id draftID: String) {
        guard currentContentState.captureDraft?.id == draftID else {
            return
        }

        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        if let appStateStore = dependencies.appStateStoreProvider() {
            do {
                let fallback = NativeAppSnapshot.bootstrap(
                    shoppingList: currentContentState.shoppingList,
                    accountID: accountID,
                    environment: cacheEnvironment,
                    savedAt: savedAt
                )
                let record = try appStateStore.loadOrCreate(fallback: fallback)
                let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                    ? record.value
                    : fallback
                try appStateStore.save(
                    baseSnapshot
                        .completingFirstRun(savedAt: savedAt)
                        .discardingCaptureDraft(id: draftID, savedAt: savedAt)
                )
            } catch {
                return
            }
        }

        let discardPlan = CaptureDraftEntityIndexPurgePlan.draftDiscardPurge(
            draftID: draftID,
            accountID: accountID,
            environment: cacheEnvironment
        )
        Task {
            await purgeCaptureDraftEntityIdentifiers(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
                accountID: accountID,
                environment: cacheEnvironment,
                plan: discardPlan
            ))
        }
        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(captureDraft: .some(nil))))
    }

    public func recordCaptureImportRetry(_ mutation: NativeQueuedMutation) {
        guard mutation.queueableKind == .recipeImportSubmit,
              let appStateStore = dependencies.appStateStoreProvider() else {
            return
        }

        do {
            let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: currentContentState.shoppingList,
                accountID: accountID,
                environment: cacheEnvironment,
                savedAt: savedAt
            )
            let record = try appStateStore.loadOrCreate(fallback: fallback)
            let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                ? record.value
                : fallback
            try appStateStore.save(
                baseSnapshot
                    .completingFirstRun(savedAt: savedAt)
                    .recordingCaptureImportRetry(mutation, savedAt: savedAt)
            )
        } catch {
            return
        }
    }

    public func recordCaptureImportBlocker(_ blocker: CaptureImportBlocker) {
        let resourceID: String
        switch blocker {
        case .providerSecret:
            resourceID = "recipe-import"
        }

        if let appStateStore = dependencies.appStateStoreProvider() {
            do {
                try persistCaptureImportProviderBlocker(
                    resourceID: resourceID,
                    authSessionState: currentContentState.authSessionState,
                    appStateStore: appStateStore
                )
            } catch {
                apply(.syncFailed(
                    currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "capture-import-blocker", retryAfter: nil), dismissal: nil)),
                    message: "Capture import blocker could not be saved offline."
                ))
                return
            }
        }

        apply(.blocker(currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(
            display: .blocker(.providerSecret(resourceID: resourceID)),
            dismissal: nil
        ))))
    }

    public func recordNotificationAPNsBlocker(_ blocker: AppleDeveloperProgramBlocker) {
        apply(.blocker(currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(
            display: .blocker(.appleDeveloperProgram(capability: blocker.capability)),
            dismissal: nil
        ))))
    }

    private func persistCaptureImportProviderBlocker(
        resourceID: String,
        authSessionState: NativeAuthSessionState,
        appStateStore: NativeAppStateStore? = nil
    ) throws {
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        let scopedAccountID = accountID(for: authSessionState)
        let store = appStateStore ?? dependencies.appStateStoreProvider()
        guard let store else {
            return
        }
        let fallback = NativeAppSnapshot.bootstrap(
            shoppingList: currentContentState.shoppingList,
            accountID: scopedAccountID,
            environment: cacheEnvironment,
            savedAt: savedAt
        )
        let record = try store.loadOrCreate(fallback: fallback)
        let baseSnapshot = record.value.isScoped(accountID: scopedAccountID, environment: cacheEnvironment)
            ? record.value
            : fallback
        try store.save(
            baseSnapshot
                .completingFirstRun(savedAt: savedAt)
                .recordingCaptureImportProviderBlocker(resourceID: resourceID, savedAt: savedAt)
        )
    }

    public func recordSpoonCookLogDraft(_ draft: SpoonCookLogDraftState?, forRecipeID recipeID: String) {
        let trimmedRecipeID = recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecipeID.isEmpty else {
            return
        }

        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        let nextPersistableDraft = draft?.persistable
        let previousDraft = currentContentState.spoonCookLogDraft(recipeID: trimmedRecipeID)
        var previousStoredDraft = previousDraft
        if let appStateStore = dependencies.appStateStoreProvider() {
            var newlySavedStagedPhoto: NativeStagedMediaUpload?
            do {
                if let stagedPhoto = draft?.stagedPhoto, !stagedPhoto.data.isEmpty {
                    try dependencies.stagedMediaDirectory?.save(stagedPhoto)
                    if previousDraft?.stagedPhoto?.localStageID != stagedPhoto.localStageID {
                        newlySavedStagedPhoto = stagedPhoto
                    }
                }
                let fallback = NativeAppSnapshot.bootstrap(
                    shoppingList: currentContentState.shoppingList,
                    accountID: accountID,
                    environment: cacheEnvironment,
                    savedAt: savedAt
                )
                let record = try appStateStore.loadOrCreate(fallback: fallback)
                let baseSnapshot = record.value.isScoped(accountID: accountID, environment: cacheEnvironment)
                    ? record.value
                    : fallback
                previousStoredDraft = baseSnapshot.spoonCookLogDraft(for: trimmedRecipeID) ?? previousDraft
                try appStateStore.save(
                    baseSnapshot
                        .completingFirstRun(savedAt: savedAt)
                        .updatingSpoonCookLogDraft(draft, forRecipeID: trimmedRecipeID, savedAt: savedAt)
                )
            } catch {
                if let newlySavedStagedPhoto {
                    deleteSpoonDraftMediaIfUnqueued(newlySavedStagedPhoto)
                }
                apply(.syncFailed(
                    currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "spoon-draft", retryAfter: nil), dismissal: nil)),
                    message: "Cook log draft could not be saved offline."
                ))
                return
            }
        }
        deleteSupersededSpoonDraftMedia(
            previous: previousStoredDraft?.stagedPhoto,
            next: nextPersistableDraft?.stagedPhoto
        )

        var nextDrafts = currentContentState.spoonCookLogDraftsByRecipeID
        if let draft = nextPersistableDraft {
            nextDrafts[draft.recipeID] = draft
        } else {
            nextDrafts.removeValue(forKey: trimmedRecipeID)
        }
        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(spoonCookLogDraftsByRecipeID: nextDrafts)))
    }

    private func deleteSupersededSpoonDraftMedia(
        previous: NativeStagedMediaUpload?,
        next: NativeStagedMediaUpload?
    ) {
        guard let previous, previous.localStageID != next?.localStageID else {
            return
        }
        deleteSpoonDraftMediaIfUnqueued(previous)
    }

    private func deleteSpoonDraftMediaIfUnqueued(_ upload: NativeStagedMediaUpload) {
        guard !currentContentState.queuedMutations.contains(where: { $0.stagedMediaUploadStageIDs.contains(upload.localStageID) }) else {
            return
        }
        try? dependencies.stagedMediaDirectory?.delete(upload)
    }

    private func restoreFromCache(
        authSessionState: NativeAuthSessionState,
        optimisticMutations: [NativeQueuedMutation] = []
    ) async throws -> NativeShellContentState {
        let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
        let preFilterCacheFallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: accountID(for: authSessionState),
            environment: cacheEnvironment,
            createdAt: dependencies.now(),
            records: [],
            dismissedIndicators: []
        )
        let preFilterCacheRecord = try dependencies.cacheStore.loadOrRecover(fallback: preFilterCacheFallback)
        let previousCacheSnapshot = preFilterCacheRecord.value
        if previousCacheSnapshot.accountID != accountID(for: authSessionState) ||
            previousCacheSnapshot.environment != cacheEnvironment {
            let captureDraftPurgePlan = CaptureDraftEntityIndexPurgePlan.accountScopePurge(
                appSnapshot: nil,
                cacheSnapshot: previousCacheSnapshot,
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment
            )
            await purgeCaptureDraftEntityIdentifiers(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: captureDraftPurgePlan
            ), domainIdentifiers: CaptureDraftEntityCatalog.purgeDomainIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: captureDraftPurgePlan
            ), accountID: previousCacheSnapshot.accountID, environment: previousCacheSnapshot.environment)
            let profileIDs = previousCacheSnapshot.records.compactMap { record -> String? in
                guard case NativeCacheDomain.profile(let id) = record.metadata.domain else {
                    return nil
                }
                return id
            }
            let chefProfilePurgePlan = ChefProfileEntityIndexPurgePlan.accountScopePurge(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                profileIDs: profileIDs
            )
            await purgeChefProfileEntityIdentifiers(ChefProfileEntityCatalog.purgeEntityIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: chefProfilePurgePlan
            ), domainIdentifiers: ChefProfileEntityCatalog.purgeDomainIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: chefProfilePurgePlan
            ), accountID: previousCacheSnapshot.accountID, environment: previousCacheSnapshot.environment)
            let recipeIDs = previousCacheSnapshot.records.flatMap { record -> [String] in
                switch record.payload {
                case .recipeCatalog(let recipeIDs):
                    return recipeIDs
                case .recipeDetail(let id, _):
                    return [id]
                default:
                    return []
                }
            }
            let cookbookIDs = previousCacheSnapshot.records.flatMap { record -> [String] in
                switch record.payload {
                case .cookbookList(let cookbookIDs):
                    return cookbookIDs
                case .cookbookDetail(let id, _):
                    return [id]
                default:
                    return []
                }
            }
            let recipeCookbookPurgePlan = RecipeCookbookEntityIndexPurgePlan.accountScopePurge(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                recipeIDs: Self.uniquePreservingOrder(recipeIDs),
                cookbookIDs: Self.uniquePreservingOrder(cookbookIDs)
            )
            await purgeRecipeCookbookEntityIdentifiers(RecipeCookbookEntityCatalog.purgeEntityIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: recipeCookbookPurgePlan
            ), domainIdentifiers: RecipeCookbookEntityCatalog.purgeDomainIdentifiers(
                accountID: previousCacheSnapshot.accountID,
                environment: previousCacheSnapshot.environment,
                plan: recipeCookbookPurgePlan
            ), accountID: previousCacheSnapshot.accountID, environment: previousCacheSnapshot.environment)
        }

        if let appStateStore = dependencies.appStateStoreProvider() {
            let preFilterAppStateFallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: accountID(for: authSessionState),
                environment: cacheEnvironment,
                savedAt: savedAt
            )
            if let preFilterAppStateRecord = try? appStateStore.loadOrCreate(fallback: preFilterAppStateFallback) {
                let previousAppSnapshot = preFilterAppStateRecord.value
                if previousAppSnapshot.accountID != accountID(for: authSessionState) ||
                    previousAppSnapshot.environment != cacheEnvironment {
                    let captureDraftPurgePlan = CaptureDraftEntityIndexPurgePlan.accountScopePurge(
                        appSnapshot: previousAppSnapshot,
                        cacheSnapshot: nil,
                        accountID: previousAppSnapshot.accountID,
                        environment: previousAppSnapshot.environment
                    )
                    let previousAccountID = previousAppSnapshot.accountID ?? ""
                    let previousEnvironment = previousAppSnapshot.environment ?? cacheEnvironment
                    await purgeCaptureDraftEntityIdentifiers(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
                        accountID: previousAccountID,
                        environment: previousEnvironment,
                        plan: captureDraftPurgePlan
                    ), domainIdentifiers: CaptureDraftEntityCatalog.purgeDomainIdentifiers(
                        accountID: previousAccountID,
                        environment: previousEnvironment,
                        plan: captureDraftPurgePlan
                    ), accountID: previousAppSnapshot.accountID, environment: previousAppSnapshot.environment)
                }
            }
        }

        let record = try loadOrCreateCacheSnapshot(authSessionState: authSessionState)
        let syncSnapshot = try await scopedSyncSnapshot(authSessionState: authSessionState)
        let appSnapshot = loadAppSnapshot(
            authSessionState: authSessionState,
            savedAt: savedAt
        )
        let display: OfflineIndicatorDisplay
        if !syncSnapshot.queue.mutations.isEmpty {
            display = .queuedWork(
                count: syncSnapshot.queue.mutations.count,
                oldestClientMutationID: syncSnapshot.queue.mutations.first?.clientMutationID
            )
        } else if let resourceID = appSnapshot?.captureImportProviderBlocker {
            display = .blocker(.providerSecret(resourceID: resourceID))
        } else if record.source == .file || syncSnapshot.checkpoint != nil || !syncSnapshot.cachedRecords.isEmpty {
            display = .stale(domain: .accountBootstrap)
        } else {
            display = .offline
        }
        let content = NativeShellContentState.restored(
            cacheSnapshot: record.value,
            syncSnapshot: syncSnapshot,
            appSnapshot: appSnapshot,
            authSessionState: authSessionState,
            configuration: configuration,
            optimisticMutations: optimisticMutations,
            offlineIndicatorState: OfflineIndicatorState(display: display, dismissal: record.value.dismissedIndicators.first)
        )
        restoredRoute = appSnapshot?.lastOpenedRoute
            .flatMap(AppRoute.init(stateIdentifier:))?
            .restorable(recipeIDs: Set(content.recipes.map(\.id)), cookbookIDs: Set(content.cookbooks.map(\.id)))
        currentContentState = content
        return content
    }

    private func loadOrCreateCacheSnapshot(authSessionState: NativeAuthSessionState) throws -> NativeDurableCacheStoreRecord {
        let fallback = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: accountID(for: authSessionState),
            environment: cacheEnvironment,
            createdAt: dependencies.now(),
            records: [],
            dismissedIndicators: []
        )
        let record = try dependencies.cacheStore.loadOrRecover(fallback: fallback)
        guard record.value.accountID == fallback.accountID,
              record.value.environment == fallback.environment else {
            return NativeDurableCacheStoreRecord(value: fallback, source: .fallback, recovery: record.recovery)
        }
        return record
    }

    private func scopedSyncSnapshot(authSessionState: NativeAuthSessionState) async throws -> NativeSyncSnapshot {
        let snapshot = try await dependencies.syncStore.loadSnapshot()
        guard let expectedAccountID = trustedAccountID(for: authSessionState),
              snapshot.accountID == expectedAccountID,
              snapshot.environment == cacheEnvironment else {
            return .empty
        }
        return NativeSyncSnapshot(
            accountID: snapshot.accountID,
            environment: snapshot.environment,
            checkpoint: snapshot.checkpoint,
            queue: try await dependencies.syncStore.loadQueue(),
            cachedRecords: snapshot.cachedRecords,
            tombstones: snapshot.tombstones
        )
    }

    private func loadAppSnapshot(authSessionState: NativeAuthSessionState, savedAt: String) -> NativeAppSnapshot? {
        guard let appStateStore = dependencies.appStateStoreProvider() else {
            return nil
        }
        let scopedAccountID = accountID(for: authSessionState)
        let fallback = NativeAppSnapshot.bootstrap(
            shoppingList: nil,
            accountID: scopedAccountID,
            environment: cacheEnvironment,
            savedAt: savedAt
        )
        guard let snapshot = try? appStateStore.loadOrCreate(fallback: fallback).value,
              snapshot.isScoped(accountID: scopedAccountID, environment: cacheEnvironment) else {
            return nil
        }
        return snapshot
    }

    private func bootstrapFromLiveAPI(
        session: AuthSession,
        trigger: NativeSyncTriggerEvent
    ) async throws {
        do {
        let report = try await syncTriggerCoordinator.handle(trigger)
        for request in report.shoppingEntityPurgeRequests {
            await purgeShoppingEntityIdentifiers(
                request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
        for request in report.spoonEntityPurgeRequests {
            await purgeSpoonEntityIdentifiers(
                request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
        for request in report.captureDraftEntityPurgeRequests {
            await purgeCaptureDraftEntityIdentifiers(
                request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
        for request in report.chefProfileEntityPurgeRequests {
            await purgeChefProfileEntityIdentifiers(
                request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
        for request in report.recipeCookbookEntityPurgeRequests {
            await purgeRecipeCookbookEntityIdentifiers(
                request.identifiers,
                domainIdentifiers: request.domainIdentifiers,
                accountID: request.accountID,
                environment: request.environment
            )
        }
        dependencies.stagedMediaDirectory?.deleteMedia(ofDrained: report.drainedMutations)
        let boundAuthState = try await authSessionStateByBindingReport(report, session: session)
        clearDrainedCaptureImports(
            Set(report.drainedMutations.filter { $0.queueableKind == .recipeImportSubmit }.map(\.clientMutationID)),
            authSessionState: boundAuthState
        )
        await runCookExchange(session: session)
        var settingsRefreshError: Error?
        var settingsRefreshResult: SettingsSurfaceResult?
        do {
            settingsRefreshResult = try await refreshSettingsSurfaceCache(authSessionState: boundAuthState)
        } catch {
            NativeLiveAppStoreTelemetry.settingsRefreshFailed(error)
            settingsRefreshError = error
        }
        let drainedOverlayMutations = report.drainedMutations.filter {
            !$0.mutatesRecipeCache && !$0.mutatesShoppingCache && !$0.mutatesCookbookCache
        }
        let restoredContent = try await restoreFromCache(
            authSessionState: boundAuthState,
            optimisticMutations: drainedOverlayMutations
        )
        let shouldPreserveRestoredBlocker: Bool
        if case .blocker = restoredContent.offlineIndicatorState.display {
            shouldPreserveRestoredBlocker = true
        } else {
            shouldPreserveRestoredBlocker = false
        }
        let content = restoredContent.copy(
            offlineIndicatorState: shouldPreserveRestoredBlocker
                ? restoredContent.offlineIndicatorState
                : OfflineIndicatorState.synced(lastSyncedAt: dependencies.now()),
            settingsSurfaceData: settingsRefreshResult?.data,
            lastSyncedAt: dependencies.now()
        )

        let providerSecretResourceID = report.blockers.first.map { blocker -> String in
            switch blocker {
            case .providerSecret(let resourceID):
                return resourceID
            }
        }

        if let conflict = report.conflicts.first {
            apply(.conflict(content.copy(
                syncConflicts: report.conflicts,
                offlineIndicatorState: OfflineIndicatorState(display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID), dismissal: nil)
            )))
        } else if case .authRequired(let message)? = report.pausedReason {
            apply(.blocker(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .blocker(.providerSecret(resourceID: message)), dismissal: nil))))
        } else if let providerSecretResourceID {
            try? persistCaptureImportProviderBlocker(resourceID: providerSecretResourceID, authSessionState: boundAuthState)
            apply(.blocker(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .blocker(.providerSecret(resourceID: providerSecretResourceID)), dismissal: nil))))
        } else if let retryAfterSeconds = report.retryAfterSeconds {
            apply(.syncFailed(
                content.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "sync", retryAfter: .seconds(retryAfterSeconds)), dismissal: nil)),
                message: "Sync will retry."
            ))
        } else if let settingsRefreshError {
            await reportNativeTelemetry(
                name: .settingsRefreshFailed,
                stage: "settings",
                error: settingsRefreshError,
                authState: boundAuthState,
                route: restoredRoute,
                contentState: content
            )
            apply(.syncFailed(
                content.copy(offlineIndicatorState: OfflineIndicatorState(
                    display: .syncFailure(
                        errorID: "settings",
                        retryAfter: NativeLiveAppStoreTelemetry.retryAfterSeconds(for: settingsRefreshError).map(OfflineIndicatorRetryAfter.seconds)
                    ),
                    dismissal: nil
                )),
                message: NativeLiveAppStoreTelemetry.failureMessage(for: settingsRefreshError)
            ))
        } else {
            for partialFailure in settingsRefreshResult?.data.partialFailures ?? [] {
                NativeLiveAppStoreTelemetry.settingsRefreshPartiallyFailed(partialFailure)
                await reportNativeTelemetry(
                    name: .settingsRefreshFailed,
                    stage: "settings.\(partialFailure.component.rawValue)",
                    diagnostic: partialFailure.diagnostic,
                    authState: boundAuthState,
                    route: restoredRoute,
                    contentState: content
                )
            }
            if !content.queuedMutations.isEmpty {
                apply(.queuedWork(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .queuedWork(count: content.queuedMutations.count, oldestClientMutationID: content.queuedMutations.first?.clientMutationID), dismissal: nil))))
            } else if case .blocker = content.offlineIndicatorState.display {
                apply(.blocker(content))
            } else {
                apply(.liveSynced(content))
            }
        }
        } catch {
            NativeLiveAppStoreTelemetry.bootstrapFailed(
                stage: "liveAPI:\(String(describing: trigger))",
                error: error,
                authState: currentContentState.authSessionState,
                environment: cacheEnvironment,
                route: restoredRoute,
                contentState: currentContentState
            )
            throw error
        }
    }

    private func refreshSettingsSurfaceCache(authSessionState: NativeAuthSessionState) async throws -> SettingsSurfaceResult? {
        guard let accountID = trustedAccountID(for: authSessionState),
              let settingsSurfaceFetch = dependencies.settingsSurfaceFetch else {
            return nil
        }

        let currentSnapshot = try loadOrCreateCacheSnapshot(authSessionState: authSessionState).value
        let result = try await settingsSurfaceFetch(
            accountID,
            cacheEnvironment,
            configuration,
            NativeDurableCache(records: currentSnapshot.records),
            grantedScopes(for: authSessionState)
        )
        let recordIDs = Set(result.persistedRecords.map(\.id))
        let nextRecords = currentSnapshot.records.filter { !recordIDs.contains($0.id) } + result.persistedRecords
        try dependencies.cacheStore.save(try currentSnapshot.copy(records: nextRecords))
        return result
    }

    private func reportNativeTelemetry(
        name: NativeTelemetryEvent.Name,
        stage: String,
        error: Error,
        authState: NativeAuthSessionState,
        route: AppRoute?,
        contentState: NativeShellContentState
    ) async {
        let diagnostic = NativeLiveAppStoreTelemetry.diagnosticContext(for: error)
        let hasRenderableContent = !contentState.recipes.isEmpty ||
            !contentState.cookbooks.isEmpty ||
            !(contentState.shoppingList?.activeItems.isEmpty ?? true)
        await dependencies.nativeTelemetryReport(NativeTelemetryEvent(
            name: name,
            stage: stage,
            environment: cacheEnvironment.rawValue,
            metadata: dependencies.nativeTelemetryMetadata,
            route: route?.stateIdentifier,
            errorType: diagnostic.type,
            requestID: diagnostic.requestID,
            status: diagnostic.status,
            apiCode: diagnostic.code,
            retry: diagnostic.retry,
            accountBound: trustedAccountID(for: authState) != nil,
            hasRenderableCacheContent: hasRenderableContent,
            recipes: contentState.recipes.count,
            cookbooks: contentState.cookbooks.count,
            shoppingItems: contentState.shoppingList?.activeItems.count ?? 0,
            queuedMutations: contentState.queuedMutations.count
        ), configuration)
    }

    private func reportNativeTelemetry(
        name: NativeTelemetryEvent.Name,
        stage: String,
        diagnostic: SettingsSurfaceFailureDiagnostic,
        authState: NativeAuthSessionState,
        route: AppRoute?,
        contentState: NativeShellContentState
    ) async {
        let hasRenderableContent = !contentState.recipes.isEmpty ||
            !contentState.cookbooks.isEmpty ||
            !(contentState.shoppingList?.activeItems.isEmpty ?? true)
        await dependencies.nativeTelemetryReport(NativeTelemetryEvent(
            name: name,
            stage: stage,
            environment: cacheEnvironment.rawValue,
            metadata: dependencies.nativeTelemetryMetadata,
            route: route?.stateIdentifier,
            errorType: diagnostic.errorType,
            requestID: diagnostic.requestID,
            status: diagnostic.status,
            apiCode: diagnostic.apiCode,
            retry: diagnostic.retry,
            accountBound: trustedAccountID(for: authState) != nil,
            hasRenderableCacheContent: hasRenderableContent,
            recipes: contentState.recipes.count,
            cookbooks: contentState.cookbooks.count,
            shoppingItems: contentState.shoppingList?.activeItems.count ?? 0,
            queuedMutations: contentState.queuedMutations.count
        ), configuration)
    }

    private func clearDrainedCaptureImports(_ clientMutationIDs: Set<String>, authSessionState: NativeAuthSessionState) {
        guard !clientMutationIDs.isEmpty,
              let appStateStore = dependencies.appStateStoreProvider() else {
            return
        }

        do {
            let savedAt = NativeLiveAppStoreClock.isoString(dependencies.now())
            let scopedAccountID = accountID(for: authSessionState)
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: currentContentState.shoppingList,
                accountID: scopedAccountID,
                environment: cacheEnvironment,
                savedAt: savedAt
            )
            let record = try appStateStore.loadOrCreate(fallback: fallback)
            let baseSnapshot = record.value.isScoped(accountID: scopedAccountID, environment: cacheEnvironment)
                ? record.value
                : fallback
            try appStateStore.save(
                baseSnapshot
                    .completingFirstRun(savedAt: savedAt)
                    .clearingDrainedCaptureImport(clientMutationIDs: clientMutationIDs, savedAt: savedAt)
            )
        } catch {
            return
        }
    }

    private func apply(_ state: NativeAppBootstrapState) {
        var state = state
        if state.contentState.isSessionExpired != sessionExpired {
            state = state.replacingContent(state.contentState.copy(isSessionExpired: sessionExpired))
        }
        currentContentState = state.contentState
        bootstrapState = state
    }

    private func stateMatchingCurrentSeverity(with content: NativeShellContentState) -> NativeAppBootstrapState {
        bootstrapState.replacingContent(content)
    }

    #if DEBUG
    nonisolated public static func debugRestoreCacheOnlyBootstrapState(for content: NativeShellContentState) -> NativeAppBootstrapState {
        restoreCacheOnlyBootstrapState(for: content)
    }
    #endif

    nonisolated private static func restoreCacheOnlyBootstrapState(for content: NativeShellContentState) -> NativeAppBootstrapState {
        switch content.offlineIndicatorState.display {
        case .queuedWork:
            return .queuedWork(content)
        case .conflict:
            return .conflict(content)
        case .blocker:
            return .blocker(content)
        case .destructiveConfirmation:
            return .destructiveConfirmation(content)
        case .syncFailure:
            return .syncFailed(content, message: "Spoonjoy could not finish syncing your account.")
        case .synced, .offline, .stale, .dismissed:
            return .offlineStale(content.copy(
                offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
            ))
        }
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private var accountID: String {
        accountID(for: currentContentState.authSessionState)
    }

    private func accountID(for authSessionState: NativeAuthSessionState) -> String {
        switch authSessionState {
        case .signedOut:
            "signed-out"
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID ?? "unbound:\(session.clientID)"
        }
    }

    private func searchSurfaceCacheSnapshot(from page: SearchSurfacePage) -> SearchSurfaceCacheSnapshot {
        let serverRevision: NativeCacheServerRevision?
        let lastValidatedAt: Date
        switch page.source {
        case .live(let requestID, let validatedAt):
            serverRevision = .localRevision("search:\(requestID)")
            lastValidatedAt = validatedAt
        case .cache(let revision, let validatedAt), .offlineCache(let revision, let validatedAt):
            serverRevision = revision
            lastValidatedAt = validatedAt
        }

        let context = currentContentState.searchSurfaceContext
        let currentAccountID = trustedAccountID(for: currentContentState.authSessionState)
        let persistedResults = page.results.filter { result in
            guard result.type == .shoppingListItem else {
                return true
            }
            return context.isAuthenticated &&
                context.canReadShoppingList &&
                currentAccountID != nil &&
                result.ownerID == currentAccountID
        }

        return SearchSurfaceCacheSnapshot(
            accountID: accountID,
            environment: cacheEnvironment,
            query: page.query,
            scope: page.scope,
            limit: page.limit,
            results: persistedResults,
            recentSearches: page.query.isEmpty ? [] : [
                SearchSurfaceRecentQuery(query: page.query, scope: page.scope, lastSearchedAt: lastValidatedAt)
            ],
            serverRevision: serverRevision,
            lastValidatedAt: lastValidatedAt
        )
    }

    private func trustedAccountID(for authSessionState: NativeAuthSessionState) -> String? {
        switch authSessionState {
        case .signedOut:
            nil
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        }
    }

    private func grantedScopes(for authSessionState: NativeAuthSessionState) -> Set<String> {
        nativeGrantedScopes(for: authSessionState)
    }

    private func authSessionStateByBindingReport(
        _ report: NativeSyncReport,
        session: AuthSession
    ) async throws -> NativeAuthSessionState {
        guard let accountID = report.accountID else {
            return .authenticated(session)
        }

        if session.accountID == accountID {
            return .authenticated(session)
        }

        let boundSession = try await dependencies.authSessionRepository.bindAccountID(accountID)
        configuration = APIClientConfiguration(
            baseURL: dependencies.configuration.baseURL,
            bearerToken: boundSession.accessToken
        )
        return .authenticated(boundSession)
    }

    private func configureForRestoredAuthState(_ restoredAuthState: NativeAuthSessionState) {
        switch restoredAuthState {
        case .signedOut:
            configuration = APIClientConfiguration(baseURL: dependencies.configuration.baseURL)
        case .authenticated(let session), .refreshRequired(let session):
            configuration = APIClientConfiguration(
                baseURL: dependencies.configuration.baseURL,
                bearerToken: session.accessToken
            )
        }
    }

    private func authorizedAuthState(from restoredAuthState: NativeAuthSessionState) async throws -> NativeAuthSessionState {
        switch restoredAuthState {
        case .signedOut:
            configuration = APIClientConfiguration(baseURL: dependencies.configuration.baseURL)
            return .signedOut
        case .authenticated, .refreshRequired:
            let session = try await dependencies.authSessionRepository.validSession()
            sessionExpired = false
            configuration = APIClientConfiguration(
                baseURL: dependencies.configuration.baseURL,
                bearerToken: session.accessToken
            )
            return .authenticated(session)
        }
    }

    private var cacheFingerprint: String {
        "\(cacheEnvironment.rawValue)-\(currentContentState.recipes.count)-\(currentContentState.cookbooks.count)-\(currentContentState.queuedMutations.count)"
    }

    private func emptyContent(authSessionState: NativeAuthSessionState, display: OfflineIndicatorDisplay) -> NativeShellContentState {
        NativeShellContentState.empty(
            authSessionState: authSessionState,
            environment: cacheEnvironment,
            configuration: configuration,
            offlineIndicatorState: OfflineIndicatorState(display: display, dismissal: nil)
        )
    }
}

public enum NativeLiveAppStoreError: Error, Equatable, Sendable {
    case fixtureFallbackEnabledInProduction
}

func nativeGrantedScopes(for authSessionState: NativeAuthSessionState) -> Set<String> {
    switch authSessionState {
    case .signedOut:
        []
    case .authenticated(let session), .refreshRequired(let session):
        Set(session.scope.split(separator: " ").map(String.init))
    }
}

private enum NativeLiveAppStoreTelemetry {
#if canImport(OSLog)
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "app.bootstrap")
#endif

    static func failureMessage(for error: Error) -> String {
        guard let transportError = error as? APITransportError else {
            return String(describing: error)
        }
        let context = errorContext(transportError)
        var parts = ["Spoonjoy could not finish syncing your account."]
        if context.requestID != "none" {
            parts.append("Support code \(context.requestID).")
        }
        if context.code != "none" {
            parts.append("Reason \(context.code).")
        }
        if context.status != "none" {
            parts.append("HTTP \(context.status).")
        }
        return parts.joined(separator: " ")
    }

    static func bootstrapFailed(
        stage: String,
        error: Error,
        authState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        route: AppRoute?,
        contentState: NativeShellContentState
    ) {
#if canImport(OSLog)
        let context = errorContext(error)
        logger.error(
            "native_app_bootstrap_failed stage=\(stage, privacy: .public) error_type=\(context.type, privacy: .public) request_id=\(context.requestID, privacy: .public) status=\(context.status, privacy: .public) code=\(context.code, privacy: .public) retry=\(context.retry, privacy: .public) account_bound=\(accountBound(authState), privacy: .public) environment=\(environment.rawValue, privacy: .public) route=\(route?.stateIdentifier ?? "none", privacy: .public) has_cache_content=\(hasRenderableCacheContent(contentState), privacy: .public) recipes=\(contentState.recipes.count, privacy: .public) cookbooks=\(contentState.cookbooks.count, privacy: .public) shopping_items=\(contentState.shoppingList?.activeItems.count ?? 0, privacy: .public) queued=\(contentState.queuedMutations.count, privacy: .public)"
        )
#endif
    }

    static func bootstrapOffline(
        stage: String,
        error: APITransportError,
        authState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        route: AppRoute?,
        contentState: NativeShellContentState
    ) {
#if canImport(OSLog)
        let context = errorContext(error)
        logger.info(
            "native_app_bootstrap_offline stage=\(stage, privacy: .public) error_type=\(context.type, privacy: .public) retry=\(context.retry, privacy: .public) account_bound=\(accountBound(authState), privacy: .public) environment=\(environment.rawValue, privacy: .public) route=\(route?.stateIdentifier ?? "none", privacy: .public) has_cache_content=\(hasRenderableCacheContent(contentState), privacy: .public) recipes=\(contentState.recipes.count, privacy: .public) cookbooks=\(contentState.cookbooks.count, privacy: .public) shopping_items=\(contentState.shoppingList?.activeItems.count ?? 0, privacy: .public) queued=\(contentState.queuedMutations.count, privacy: .public)"
        )
#endif
    }

    static func settingsRefreshFailed(_ error: Error) {
#if canImport(OSLog)
        let type = String(describing: Swift.type(of: error))
        if let transportError = error as? APITransportError {
            logger.error(
                "native_settings_refresh_failed error_type=\(type, privacy: .public) request_id=\(transportError.requestID ?? "none", privacy: .public) status=\(transportError.statusCode.map(String.init) ?? "none", privacy: .public) code=\(transportError.apiError?.code ?? "none", privacy: .public)"
            )
        } else {
            logger.error("native_settings_refresh_failed error_type=\(type, privacy: .public)")
        }
#endif
    }

    static func settingsRefreshPartiallyFailed(_ failure: SettingsSurfacePartialFailure) {
#if canImport(OSLog)
        logger.error(
            "native_settings_refresh_partial_failed component=\(failure.component.rawValue, privacy: .public) error_type=\(failure.diagnostic.errorType, privacy: .public) request_id=\(failure.diagnostic.requestID ?? "none", privacy: .public) status=\(failure.diagnostic.status.map(String.init) ?? "none", privacy: .public) code=\(failure.diagnostic.apiCode ?? "none", privacy: .public)"
        )
#endif
    }

    static func diagnosticContext(for error: Error) -> (type: String, requestID: String?, status: Int?, code: String?, retry: String?) {
        let type = String(describing: Swift.type(of: error))
        guard let transportError = error as? APITransportError else {
            return (type, nil, nil, nil, nil)
        }
        return (
            type,
            transportError.requestID ?? transportError.apiError?.requestID,
            transportError.statusCode ?? transportError.apiError?.status,
            transportError.apiError?.code,
            retryDescription(transportError.retryDecision)
        )
    }

    static func retryAfterSeconds(for error: Error) -> Int? {
        guard let transportError = error as? APITransportError else {
            return nil
        }
        switch transportError.retryDecision {
        case .retrySameRequest(let seconds):
            return seconds
        case .refreshAuthentication, .doNotRetry:
            return nil
        }
    }

    private static func errorContext(_ error: Error) -> (type: String, requestID: String, status: String, code: String, retry: String) {
        let type = String(describing: Swift.type(of: error))
        guard let transportError = error as? APITransportError else {
            return (type, "none", "none", "none", "none")
        }
        return errorContext(transportError)
    }

    private static func errorContext(_ transportError: APITransportError) -> (type: String, requestID: String, status: String, code: String, retry: String) {
        (
            String(describing: Swift.type(of: transportError)),
            transportError.requestID ?? transportError.apiError?.requestID ?? "none",
            transportError.statusCode.map(String.init) ?? transportError.apiError?.status.description ?? "none",
            transportError.apiError?.code ?? "none",
            retryDescription(transportError.retryDecision)
        )
    }

    private static func retryDescription(_ decision: APIRetryDecision) -> String {
        switch decision {
        case .retrySameRequest(let seconds):
            "retry_same_request:\(seconds.map(String.init) ?? "unspecified")"
        case .refreshAuthentication:
            "refresh_authentication"
        case .doNotRetry:
            "do_not_retry"
        }
    }

    private static func accountBound(_ authState: NativeAuthSessionState) -> Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    private static func hasRenderableCacheContent(_ contentState: NativeShellContentState) -> Bool {
        !contentState.recipes.isEmpty ||
            !contentState.cookbooks.isEmpty ||
            !(contentState.shoppingList?.activeItems.isEmpty ?? true)
    }
}

private struct NativeLiveAppStoreAPIRefresher: APIAuthenticationRefresher {
    let authSessionRepository: NativeAuthSessionRepository
    let baseURL: URL

    func refreshedConfiguration(
        after _: APIError,
        configuration _: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        let session = try await authSessionRepository.validSession()
        return APIClientConfiguration(baseURL: baseURL, bearerToken: session.accessToken)
    }
}

enum NativeLiveAppStoreClock {
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private extension Recipe {
    func replacingRestoredRecentSpoons(_ recentSpoons: [RecipeDetailRecentSpoon]) -> Recipe {
        Recipe(
            id: id,
            title: title,
            description: description,
            servings: servings,
            chef: chef,
            coverImageURL: coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel,
            coverSourceType: coverSourceType,
            coverVariant: coverVariant,
            href: href,
            canonicalURL: canonicalURL,
            attribution: attribution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            steps: steps,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons
        )
    }
}

private extension Array where Element == RecipeDetailRecentSpoon {
    func upsertingRestoredRecentSpoon(_ spoon: RecipeDetailRecentSpoon) -> [RecipeDetailRecentSpoon] {
        var remaining = filter { $0.id != spoon.id }
        remaining.insert(spoon, at: 0)
        return remaining.sorted {
            let lhsKey = $0.cookedAt ?? $0.createdAt
            let rhsKey = $1.cookedAt ?? $1.createdAt
            if lhsKey != rhsKey {
                return lhsKey > rhsKey
            }
            return $0.id > $1.id
        }
    }
}

private struct NativeProfileGraphAggregate: Equatable {
    var chef: ChefSummary
    var spoons: Int
    var latestInteractionAt: String

    init(chef: ChefSummary, latestInteractionAt: String) {
        self.chef = chef
        self.spoons = 1
        self.latestInteractionAt = latestInteractionAt
    }

    mutating func recordSpoon(chef: ChefSummary, at interactionAt: String) {
        spoons += 1
        if interactionAt > latestInteractionAt {
            self.chef = chef
            latestInteractionAt = interactionAt
        }
    }
}

private extension Dictionary where Key == String, Value == NativeProfileGraphAggregate {
    mutating func recordSpoon(for chef: ChefSummary, at interactionAt: String) {
        if var aggregate = self[chef.id] {
            aggregate.recordSpoon(chef: chef, at: interactionAt)
            self[chef.id] = aggregate
        } else {
            self[chef.id] = NativeProfileGraphAggregate(chef: chef, latestInteractionAt: interactionAt)
        }
    }
}
