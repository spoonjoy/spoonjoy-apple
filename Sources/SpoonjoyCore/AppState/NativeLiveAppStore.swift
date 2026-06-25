import Combine
import Foundation

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
        self.now = now
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

public struct NativeShellContentState {
    public let recipes: [Recipe]
    public let cookbooks: [Cookbook]
    public let kitchen: KitchenFixtureState
    public let shoppingList: ShoppingListState?
    public let captureDraft: CaptureDraft?
    public let cookProgressByRecipeID: [String: CookModeProgress]
    public let queuedMutations: [NativeQueuedMutation]
    public let searchResultsByScope: [SearchScope: [String]]
    public let authSessionState: NativeAuthSessionState
    public let environment: NativeCacheEnvironment
    public let configuration: APIClientConfiguration
    public let offlineIndicatorState: OfflineIndicatorState

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

    public func cookProgress(for recipeID: String) -> CookModeProgress? {
        cookProgressByRecipeID[recipeID]
    }

    func copy(
        queuedMutations: [NativeQueuedMutation]? = nil,
        environment: NativeCacheEnvironment? = nil,
        configuration: APIClientConfiguration? = nil,
        offlineIndicatorState: OfflineIndicatorState? = nil
    ) -> NativeShellContentState {
        NativeShellContentState(
            recipes: recipes,
            cookbooks: cookbooks,
            kitchen: kitchen,
            shoppingList: shoppingList,
            captureDraft: captureDraft,
            cookProgressByRecipeID: cookProgressByRecipeID,
            queuedMutations: queuedMutations ?? self.queuedMutations,
            authSessionState: authSessionState,
            environment: environment ?? self.environment,
            configuration: configuration ?? self.configuration,
            offlineIndicatorState: offlineIndicatorState ?? self.offlineIndicatorState
        )
    }

    static func empty(
        authSessionState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        configuration: APIClientConfiguration,
        offlineIndicatorState: OfflineIndicatorState
    ) -> NativeShellContentState {
        NativeShellContentState(
            recipes: [],
            cookbooks: [],
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
            queuedMutations: [],
            authSessionState: authSessionState,
            environment: environment,
            configuration: configuration,
            offlineIndicatorState: offlineIndicatorState
        )
    }

    static func restored(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot,
        appSnapshot: NativeAppSnapshot?,
        authSessionState: NativeAuthSessionState,
        configuration: APIClientConfiguration,
        offlineIndicatorState: OfflineIndicatorState
    ) -> NativeShellContentState {
        let recipes = restoredRecipes(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let cookbooks = restoredCookbooks(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let shoppingList = restoredShoppingList(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: appSnapshot,
            recipes: recipes
        )
        let captureDraft = restoredCaptureDraft(cacheSnapshot: cacheSnapshot, appSnapshot: appSnapshot)
        let cookProgressByRecipeID = restoredCookProgress(cacheSnapshot: cacheSnapshot, appSnapshot: appSnapshot)
        return NativeShellContentState(
            recipes: recipes,
            cookbooks: cookbooks,
            kitchen: restoredKitchen(
                cacheSnapshot: cacheSnapshot,
                recipes: recipes,
                cookbooks: cookbooks,
                shoppingList: shoppingList
            ),
            shoppingList: shoppingList,
            captureDraft: captureDraft,
            cookProgressByRecipeID: cookProgressByRecipeID,
            queuedMutations: syncSnapshot.queue.mutations,
            authSessionState: authSessionState,
            environment: cacheSnapshot.environment,
            configuration: configuration,
            offlineIndicatorState: offlineIndicatorState
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
        return (decoded + placeholders).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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

    private static func restoredShoppingList(
        cacheSnapshot: NativeDurableCacheSnapshot,
        syncSnapshot: NativeSyncSnapshot,
        appSnapshot: NativeAppSnapshot?,
        recipes: [Recipe]
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
        guard !items.isEmpty else {
            return appSnapshot?.shoppingList
        }
        let chef = recipes.first?.chef ?? ChefSummary(id: cacheSnapshot.accountID, username: "Spoonjoy")
        let cursor = syncSnapshot.checkpoint?.shoppingCursor?.rawValue ?? cacheSnapshot.records.compactMap { record -> String? in
            guard case .shoppingList(_, let syncCursor) = record.payload else {
                return nil
            }
            return syncCursor
        }.first ?? ""
        return ShoppingListState(
            id: "native-shopping-list",
            chef: chef,
            items: items,
            nextCursor: cursor,
            updatedAt: syncSnapshot.checkpoint?.updatedAt ?? NativeLiveAppStoreClock.isoString(cacheSnapshot.createdAt)
        )
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
            result[recipeID] = CookModeProgress(
                recipeID: recipeID,
                completedStepIDs: completedStepIDs,
                currentStepID: currentStepID
            )
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
        kitchen: KitchenFixtureState,
        shoppingList: ShoppingListState?,
        captureDraft: CaptureDraft?,
        cookProgressByRecipeID: [String: CookModeProgress],
        queuedMutations: [NativeQueuedMutation],
        authSessionState: NativeAuthSessionState,
        environment: NativeCacheEnvironment,
        configuration: APIClientConfiguration,
        offlineIndicatorState: OfflineIndicatorState
    ) {
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.kitchen = kitchen
        self.shoppingList = shoppingList
        self.captureDraft = captureDraft
        self.cookProgressByRecipeID = cookProgressByRecipeID
        self.queuedMutations = queuedMutations
        self.searchResultsByScope = Self.searchResultsByScope(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList
        )
        self.authSessionState = authSessionState
        self.environment = environment
        self.configuration = configuration
        self.offlineIndicatorState = offlineIndicatorState
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

    private let dependencies: NativeLiveAppStoreDependencies
    private var configuration: APIClientConfiguration
    private var cacheEnvironment: NativeCacheEnvironment
    private var currentContentState: NativeShellContentState

    public var authSessionRepository: NativeAuthSessionRepository {
        dependencies.authSessionRepository
    }

    public var syncTriggerCoordinator: NativeSyncTriggerCoordinator {
        NativeSyncTriggerCoordinator(
            runner: dependencies.syncEngine,
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
    }

    public func bootstrap() async {
        do {
            guard !dependencies.fixtureFallbackPolicy.allowsProductionFallback() else {
                throw NativeLiveAppStoreError.fixtureFallbackEnabledInProduction
            }

            let restoredAuthState = try await dependencies.authSessionRepository.restoreState()
            let authState = try await authorizedAuthState(from: restoredAuthState)

            guard case .authenticated(let session) = authState else {
                let restoringContent = try await restoreFromCache(authSessionState: authState)
                apply(.signedOut(restoringContent))
                return
            }

            apply(.restoringCache(emptyContent(authSessionState: authState, display: .offline)))
            try await bootstrapFromLiveAPI(session: session, trigger: .launch)
        } catch let error as APITransportError where error.isOffline {
            let offlineContent = (try? await restoreFromCache(authSessionState: currentContentState.authSessionState)) ?? currentContentState
            apply(.offlineStale(offlineContent.copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))))
        } catch {
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "bootstrap", retryAfter: nil), dismissal: nil)),
                message: String(describing: error)
            ))
        }
    }

    public func switchEnvironment(_ environment: NativeCacheEnvironment) async {
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
            let offlineContent = (try? await restoreFromCache(authSessionState: authSessionState)) ?? currentContentState
            apply(.offlineStale(offlineContent.copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))))
        } catch {
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "environment", retryAfter: nil), dismissal: nil)),
                message: String(describing: error)
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

    public func queueMutation(_ mutation: NativeQueuedMutation) async {
        do {
            let scopedQueue = try await queueForCurrentScope()
            let queue = scopedQueue.queue
            let nextQueue = try queue.appending(mutation)
            try await dependencies.syncStore.saveQueue(
                nextQueue,
                accountID: scopedQueue.accountID,
                environment: scopedQueue.environment
            )
            let indicator = OfflineIndicatorState(
                display: .queuedWork(
                    count: nextQueue.mutations.count,
                    oldestClientMutationID: nextQueue.mutations.first?.clientMutationID
                ),
                dismissal: nil
            )
            apply(.queuedWork(currentContentState.copy(queuedMutations: nextQueue.mutations, offlineIndicatorState: indicator)))
        } catch {
            apply(.syncFailed(
                currentContentState.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "queue", retryAfter: nil), dismissal: nil)),
                message: String(describing: error)
            ))
        }
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
            try appStateStore.save(baseSnapshot.recordingOpenedRoute(route, savedAt: savedAt))
        } catch {
            return
        }
    }

    private func restoreFromCache(authSessionState: NativeAuthSessionState) async throws -> NativeShellContentState {
        let record = try loadOrCreateCacheSnapshot(authSessionState: authSessionState)
        let syncSnapshot = try await scopedSyncSnapshot(authSessionState: authSessionState)
        let appSnapshot = loadAppSnapshot(
            authSessionState: authSessionState,
            savedAt: NativeLiveAppStoreClock.isoString(dependencies.now())
        )
        restoredRoute = appSnapshot?.lastOpenedRoute.flatMap(AppRoute.init(stateIdentifier:))
        let display: OfflineIndicatorDisplay
        if !syncSnapshot.queue.mutations.isEmpty {
            display = .queuedWork(
                count: syncSnapshot.queue.mutations.count,
                oldestClientMutationID: syncSnapshot.queue.mutations.first?.clientMutationID
            )
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
            offlineIndicatorState: OfflineIndicatorState(display: display, dismissal: record.value.dismissedIndicators.first)
        )
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
        return snapshot
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
        let report = try await syncTriggerCoordinator.handle(trigger)
        let boundAuthState = try await authSessionStateByBindingReport(report, session: session)
        let content = try await restoreFromCache(authSessionState: boundAuthState)
            .copy(offlineIndicatorState: OfflineIndicatorState.synced(lastSyncedAt: dependencies.now()))

        if let conflict = report.conflicts.first {
            apply(.conflict(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID), dismissal: nil))))
        } else if case .authRequired(let message)? = report.pausedReason {
            apply(.blocker(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .blocker(.providerSecret(resourceID: message)), dismissal: nil))))
        } else if let retryAfterSeconds = report.retryAfterSeconds {
            apply(.syncFailed(
                content.copy(offlineIndicatorState: OfflineIndicatorState(display: .syncFailure(errorID: "sync", retryAfter: .seconds(retryAfterSeconds)), dismissal: nil)),
                message: "Sync will retry."
            ))
        } else if !content.queuedMutations.isEmpty {
            apply(.queuedWork(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .queuedWork(count: content.queuedMutations.count, oldestClientMutationID: content.queuedMutations.first?.clientMutationID), dismissal: nil))))
        } else {
            apply(.liveSynced(content))
        }
    }

    private func apply(_ state: NativeAppBootstrapState) {
        currentContentState = state.contentState
        bootstrapState = state
    }

    private func stateMatchingCurrentSeverity(with content: NativeShellContentState) -> NativeAppBootstrapState {
        bootstrapState.replacingContent(content)
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

    private func trustedAccountID(for authSessionState: NativeAuthSessionState) -> String? {
        switch authSessionState {
        case .signedOut:
            nil
        case .authenticated(let session), .refreshRequired(let session):
            session.accountID
        }
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

    private func authorizedAuthState(from restoredAuthState: NativeAuthSessionState) async throws -> NativeAuthSessionState {
        switch restoredAuthState {
        case .signedOut:
            configuration = APIClientConfiguration(baseURL: dependencies.configuration.baseURL)
            return .signedOut
        case .authenticated, .refreshRequired:
            let session = try await dependencies.authSessionRepository.validSession()
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

enum NativeLiveAppStoreClock {
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
