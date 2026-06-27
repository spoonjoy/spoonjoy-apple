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
    public let recipeEditorAPITransport: @Sendable (any APIAuthenticationRefresher) -> any SpoonjoyAPITransport
    public let stagedMediaDirectory: NativeStagedMediaDirectory?
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
        stagedMediaDirectory: NativeStagedMediaDirectory? = nil,
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
        self.stagedMediaDirectory = stagedMediaDirectory
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

public struct NativeShellContentState {
    public let recipes: [Recipe]
    public let cookbooks: [Cookbook]
    public let kitchen: KitchenFixtureState
    public let shoppingList: ShoppingListState?
    public let captureDraft: CaptureDraft?
    public let cookProgressByRecipeID: [String: CookModeProgress]
    public let spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]
    public let queuedMutations: [NativeQueuedMutation]
    public let syncConflicts: [NativeSyncConflict]
    public let searchResultsByScope: [SearchScope: [String]]
    public let authSessionState: NativeAuthSessionState
    public let environment: NativeCacheEnvironment
    public let configuration: APIClientConfiguration
    public let offlineIndicatorState: OfflineIndicatorState

    public func recipe(id: String) -> Recipe? {
        recipes.first { $0.id == id }
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

    public func cookProgress(for recipeID: String) -> CookModeProgress? {
        cookProgressByRecipeID[recipeID]
    }

    public func spoonCookLogDraft(recipeID: String) -> SpoonCookLogDraftState? {
        spoonCookLogDraftsByRecipeID[recipeID]
    }

    func copy(
        recipes: [Recipe]? = nil,
        shoppingList: ShoppingListState? = nil,
        captureDraft: CaptureDraft?? = nil,
        cookProgressByRecipeID: [String: CookModeProgress]? = nil,
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState]? = nil,
        queuedMutations: [NativeQueuedMutation]? = nil,
        syncConflicts: [NativeSyncConflict]? = nil,
        environment: NativeCacheEnvironment? = nil,
        configuration: APIClientConfiguration? = nil,
        offlineIndicatorState: OfflineIndicatorState? = nil
    ) -> NativeShellContentState {
        NativeShellContentState(
            recipes: recipes ?? self.recipes,
            cookbooks: cookbooks,
            kitchen: kitchen,
            shoppingList: shoppingList ?? self.shoppingList,
            captureDraft: captureDraft ?? self.captureDraft,
            cookProgressByRecipeID: cookProgressByRecipeID ?? self.cookProgressByRecipeID,
            spoonCookLogDraftsByRecipeID: spoonCookLogDraftsByRecipeID ?? self.spoonCookLogDraftsByRecipeID,
            queuedMutations: queuedMutations ?? self.queuedMutations,
            syncConflicts: syncConflicts ?? self.syncConflicts,
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
            spoonCookLogDraftsByRecipeID: [:],
            queuedMutations: [],
            syncConflicts: [],
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
        optimisticMutations: [NativeQueuedMutation] = [],
        offlineIndicatorState: OfflineIndicatorState
    ) -> NativeShellContentState {
        let cachedRecipes = restoredRecipes(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
        let recipes = recipesByApplyingQueuedRecipeMutations(
            optimisticMutations + syncSnapshot.queue.mutations,
            to: cachedRecipes,
            authSessionState: authSessionState
        )
        let cookbooks = restoredCookbooks(cacheSnapshot: cacheSnapshot, syncSnapshot: syncSnapshot)
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
            spoonCookLogDraftsByRecipeID: spoonCookLogDraftsByRecipeID,
            queuedMutations: syncSnapshot.queue.mutations,
            syncConflicts: [],
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
        if let chef = recipes.first?.chef {
            return chef
        }

        switch authSessionState {
        case .authenticated(let session), .refreshRequired(let session):
            return ChefSummary(id: session.accountID ?? "signed-out", username: "Spoonjoy")
        case .signedOut:
            return ChefSummary(id: "signed-out", username: "Spoonjoy")
        }
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
        kitchen: KitchenFixtureState,
        shoppingList: ShoppingListState?,
        captureDraft: CaptureDraft?,
        cookProgressByRecipeID: [String: CookModeProgress],
        spoonCookLogDraftsByRecipeID: [String: SpoonCookLogDraftState],
        queuedMutations: [NativeQueuedMutation],
        syncConflicts: [NativeSyncConflict],
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
        self.spoonCookLogDraftsByRecipeID = spoonCookLogDraftsByRecipeID
        self.queuedMutations = queuedMutations
        self.syncConflicts = syncConflicts
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

    public func queueMutation(_ mutation: NativeQueuedMutation) async throws {
        try await queueMutations([mutation])
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
            apply(.queuedWork(currentContentState.copy(
                recipes: optimisticRecipes,
                shoppingList: optimisticShoppingList,
                queuedMutations: nextQueue.mutations,
                offlineIndicatorState: indicator
            )))
            if drainImmediately {
                await bootstrap()
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

    private var optimisticRecipeChef: ChefSummary {
        currentContentState.recipes.first?.chef ?? ChefSummary(id: accountID, username: "Spoonjoy")
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
        } catch {
            return
        }
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

        apply(stateMatchingCurrentSeverity(with: currentContentState.copy(captureDraft: .some(draft))))
    }

    public func discardCaptureDraft(id draftID: String) {
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

        guard currentContentState.captureDraft?.id == draftID else {
            return
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
        let report = try await syncTriggerCoordinator.handle(trigger)
        let boundAuthState = try await authSessionStateByBindingReport(report, session: session)
        clearDrainedCaptureImports(
            Set(report.drainedMutations.filter { $0.queueableKind == .recipeImportSubmit }.map(\.clientMutationID)),
            authSessionState: boundAuthState
        )
        let drainedOverlayMutations = report.drainedMutations.filter {
            !$0.mutatesRecipeCache && !$0.mutatesShoppingCache
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
                : OfflineIndicatorState.synced(lastSyncedAt: dependencies.now())
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
        } else if !content.queuedMutations.isEmpty {
            apply(.queuedWork(content.copy(offlineIndicatorState: OfflineIndicatorState(display: .queuedWork(count: content.queuedMutations.count, oldestClientMutationID: content.queuedMutations.first?.clientMutationID), dismissal: nil))))
        } else if case .blocker = content.offlineIndicatorState.display {
            apply(.blocker(content))
        } else {
            apply(.liveSynced(content))
        }
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
            ($0.cookedAt ?? $0.createdAt) > ($1.cookedAt ?? $1.createdAt)
        }
    }
}
