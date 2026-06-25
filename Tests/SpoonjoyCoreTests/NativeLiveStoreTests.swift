import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native live store and shell wiring")
struct NativeLiveStoreTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)

    @MainActor
    @Test("live store refreshes auth before sync and hydrates applied sync cache")
    func liveStoreRefreshesAuthBeforeSyncAndHydratesAppliedSyncCache() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_expired",
                refreshToken: "sj_refresh_original",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(-60),
                scope: NativeAuthSession.defaultScope
            ))
            let recipe = Self.sampleRecipe(id: "recipe_live", title: "Live Lemon Pasta")
            let shoppingItem = Self.sampleShoppingItem(id: "item_lemons", name: "lemons")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: shoppingItem)
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live store to finish in liveSynced; got \(liveStore.bootstrapState)")
                return
            }

            #expect(await transport.capturedBearerTokens() == ["sj_access_refreshed"])
            #expect(content.configuration.bearerToken == "sj_access_refreshed")
            #expect(content.recipes.map(\.title) == ["Live Lemon Pasta"])
            #expect(content.shoppingList?.activeItems.map(\.name) == ["lemons"])
            #expect(content.searchResultsByScope[.all] == ["recipe_live", "item_lemons"])
            #expect(await syncStore.loadSnapshot().cachedRecords.map(\.cacheKey) == ["recipe:recipe_live", "shoppingItem:item_lemons"])
        }
    }

    @MainActor
    @Test("live store queueMutation persists mutations through native sync store")
    func liveStoreQueueMutationPersistsMutationsThroughNativeSyncStore() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))
            let mutation = NativeQueuedMutation.shoppingAddItem(
                name: "lemons",
                quantity: 2,
                unit: "each",
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_live_queue",
                createdAt: "2026-06-16T12:00:00.000Z"
            )

            await liveStore.queueMutation(mutation)
            let persisted = try await syncStore.loadQueue()

            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queueMutation to show queuedWork; got \(liveStore.bootstrapState)")
                return
            }

            #expect(persisted.mutations == [mutation])
            #expect(content.queuedMutations == [mutation])
            #expect(content.offlineIndicatorState.display == .queuedWork(count: 1, oldestClientMutationID: "cm_live_queue"))
        }
    }

    @MainActor
    @Test("live store queueMutation discards previous owner media queue before appending current work")
    func liveStoreQueueMutationDiscardsPreviousOwnerMediaQueueBeforeAppendingCurrentWork() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_current",
                refreshToken: "sj_refresh_current",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_current"
            ))
            let previousPhoto = NativeStagedMediaUpload(
                localStageID: "missing_previous_owner_stage",
                fileName: "previous.jpg",
                contentType: "image/jpeg",
                data: Data()
            )
            let previousMutation = NativeQueuedMutation.profilePhotoUpload(
                photo: previousPhoto,
                clientMutationID: "cm_previous_owner_photo",
                createdAt: Self.isoString(Self.now)
            )
            let previousRecord = NativeSyncCachedRecord(
                kind: .recipe,
                resourceID: "recipe_previous_owner",
                payload: .object(["title": .string("Previous Owner Cache")]),
                serverRevision: .updatedAt("2026-06-16T09:12:01.000Z")
            )
            let previousTombstone = NativeSyncTombstone(
                resourceType: .recipe,
                resourceID: "recipe_previous_deleted",
                parentResourceID: nil,
                title: "Previous deleted recipe",
                deletedAt: "2026-06-16T09:12:02.000Z",
                updatedAt: "2026-06-16T09:12:03.000Z"
            )
            let mediaDirectory = NativeStagedMediaDirectory(directoryURL: directory.appendingPathComponent("media", isDirectory: true))
            let syncStore = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("sync.json"),
                mediaResolver: mediaDirectory,
                fallback: NativeSyncSnapshot(
                    accountID: "chef_previous",
                    environment: .production,
                    checkpoint: try NativeSyncCheckpoint(
                        globalCursor: PaginationCursor(rawValue: "previous.owner.cursor"),
                        shoppingCursor: ShoppingSyncCursor(rawValue: "previous.shopping.cursor"),
                        updatedAt: "2026-06-16T09:12:00.000Z"
                    ),
                    queue: try NativeMutationQueue(mutations: [previousMutation]),
                    cachedRecords: [previousRecord],
                    tombstones: [previousTombstone]
                )
            )
            let transport = ThrowingLiveStoreSyncTransport(error: APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            ))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))
            let currentMutation = NativeQueuedMutation.shoppingAddItem(
                name: "current lemons",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_current_owner",
                createdAt: Self.isoString(Self.now)
            )

            await liveStore.bootstrap()
            await liveStore.queueMutation(currentMutation)
            let snapshot = await syncStore.loadSnapshot()

            #expect(snapshot.accountID == "chef_current")
            #expect(snapshot.environment == .production)
            #expect(snapshot.checkpoint == nil)
            #expect(snapshot.cachedRecords.isEmpty)
            #expect(snapshot.tombstones.isEmpty)
            #expect(snapshot.queue.mutations.map(\.clientMutationID) == ["cm_current_owner"])
            #expect(snapshot.queue.mutations.first == currentMutation)
        }
    }

    @MainActor
    @Test("live store restores only bound account cache route and Siri capture draft")
    func liveStoreRestoresOnlyBoundAccountCacheRouteAndSiriCaptureDraft() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_bound",
                refreshToken: "sj_refresh_bound",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_ari"
            ))
            let recipe = Self.sampleRecipe(id: "recipe_bound", title: "Bound Cache Pasta")
            let draft = try CaptureDraft.localText(
                id: "draft_siri_bound",
                rawText: "https://example.com/siri-capture",
                createdAt: Self.isoString(Self.now)
            )
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "chef_ari",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
                    .updatingCaptureDraft(draft, savedAt: Self.isoString(Self.now))
                    .recordingOpenedRoute(.capture, savedAt: Self.isoString(Self.now))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue(),
                cachedRecords: [
                    NativeSyncCachedRecord(
                        kind: .recipe,
                        resourceID: recipe.id,
                        payload: try Self.jsonValue(recipe),
                        serverRevision: .updatedAt(recipe.updatedAt)
                    )
                ]
            )
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { appStateStore },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected bound account cache to restore; got \(liveStore.bootstrapState)")
                return
            }

            let savedSession = try #require(try await vault.loadSession())
            #expect(content.recipes.map(\.id) == ["recipe_bound"])
            #expect(content.captureDraft == draft)
            #expect(content.authSessionState == .authenticated(savedSession))
            #expect(liveStore.restoredRoute == .capture)
        }
    }

    @MainActor
    @Test("live store ignores app snapshot state from another account")
    func liveStoreIgnoresAppSnapshotStateFromAnotherAccount() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_current",
                refreshToken: "sj_refresh_current",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_current"
            ))
            let previousDraft = try CaptureDraft.localText(
                id: "draft_previous_owner",
                rawText: "https://example.com/previous-owner",
                createdAt: Self.isoString(Self.now)
            )
            let previousShoppingList = try ShoppingListState.decodeFromBundle()
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: previousShoppingList,
                    accountID: "chef_previous",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
                    .updatingCaptureDraft(previousDraft, savedAt: Self.isoString(Self.now))
                    .recordingOpenedRoute(.capture, savedAt: Self.isoString(Self.now))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_current",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { appStateStore },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected current account to sync without previous app state; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.shoppingList == nil)
            #expect(content.captureDraft == nil)
            #expect(liveStore.restoredRoute == nil)
        }
    }

    @MainActor
    @Test("live store ignores legacy unscoped app snapshot state")
    func liveStoreIgnoresLegacyUnscopedAppSnapshotState() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_current",
                refreshToken: "sj_refresh_current",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_current"
            ))
            let legacyDraft = try CaptureDraft.localText(
                id: "draft_legacy",
                rawText: "https://example.com/legacy",
                createdAt: Self.isoString(Self.now)
            )
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(shoppingList: try ShoppingListState.decodeFromBundle(), savedAt: Self.isoString(Self.now))
                    .updatingCaptureDraft(legacyDraft, savedAt: Self.isoString(Self.now))
                    .recordingOpenedRoute(.capture, savedAt: Self.isoString(Self.now))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_current",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { appStateStore },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected current account to ignore legacy app state; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.shoppingList == nil)
            #expect(content.captureDraft == nil)
            #expect(liveStore.restoredRoute == nil)
        }
    }

    @MainActor
    @Test("environment switch clears previous environment content and applies scoped sync")
    func environmentSwitchClearsPreviousEnvironmentContentAndAppliesScopedSync() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_current",
                refreshToken: "sj_refresh_current",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_ari"
            ))
            let productionRecipe = Self.sampleRecipe(id: "recipe_production", title: "Production Pasta")
            let localRecipe = Self.sampleRecipe(id: "recipe_local", title: "Local Soup")
            let productionItem = Self.sampleShoppingItem(id: "item_production", name: "production lemons")
            let localItem = Self.sampleShoppingItem(id: "item_local", name: "local carrots")
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let transport = CapturingLiveStoreSyncTransport(bootstraps: [
                .syncData(try Self.sampleSyncData(
                    recipe: productionRecipe,
                    shoppingItem: productionItem,
                    accountID: "chef_ari",
                    environment: .production
                )),
                .syncData(try Self.sampleSyncData(
                    recipe: localRecipe,
                    shoppingItem: localItem,
                    accountID: "chef_ari",
                    environment: .local
                ))
            ])
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()
            guard case .liveSynced(let productionContent) = liveStore.bootstrapState else {
                Issue.record("Expected production bootstrap to sync; got \(liveStore.bootstrapState)")
                return
            }

            await liveStore.switchEnvironment(.local)

            guard case .liveSynced(let localContent) = liveStore.bootstrapState else {
                Issue.record("Expected local environment switch to apply scoped sync; got \(liveStore.bootstrapState)")
                return
            }

            #expect(productionContent.environment == .production)
            #expect(productionContent.recipes.map(\.id) == ["recipe_production"])
            #expect(localContent.environment == .local)
            #expect(localContent.recipes.map(\.id) == ["recipe_local"])
            #expect(localContent.shoppingList?.activeItems.map(\.id) == ["item_local"])
        }
    }

    @MainActor
    @Test("unbound authenticated offline restore fails closed for private sync cache")
    func unboundAuthenticatedOfflineRestoreFailsClosedForPrivateSyncCache() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_unbound",
                refreshToken: "sj_refresh_unbound",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(600),
                scope: NativeAuthSession.defaultScope
            ))
            let recipe = Self.sampleRecipe(id: "recipe_previous_owner", title: "Previous Owner")
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_previous",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [
                    .shoppingAddItem(
                        name: "previous lemons",
                        quantity: nil,
                        unit: nil,
                        categoryKey: nil,
                        iconKey: nil,
                        clientMutationID: "cm_previous_owner",
                        createdAt: Self.isoString(Self.now)
                    )
                ]),
                cachedRecords: [
                    NativeSyncCachedRecord(
                        kind: .recipe,
                        resourceID: recipe.id,
                        payload: try Self.jsonValue(recipe),
                        serverRevision: .updatedAt(recipe.updatedAt)
                    )
                ]
            )
            let transport = ThrowingLiveStoreSyncTransport(error: APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            ))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .offlineStale(let content) = liveStore.bootstrapState else {
                Issue.record("Expected offline stale fail-closed state; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.recipes.isEmpty)
            #expect(content.queuedMutations.isEmpty)
            #expect(content.offlineIndicatorState.display == .offline)
        }
    }

    @MainActor
    @Test("signed out live store restores durable fallback content and records scoped routes")
    func signedOutLiveStoreRestoresDurableFallbackContentAndRecordsScopedRoutes() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "signed-out",
                environment: .production,
                createdAt: Self.now,
                records: [
                    try Self.cacheRecord(domain: .recipeDetail(id: "recipe_alpha"), payload: .recipeDetail(id: "recipe_alpha", title: "Aardvark Toast")),
                    try Self.cacheRecord(domain: .recipeDetail(id: "recipe_cached"), payload: .recipeDetail(id: "recipe_cached", title: "Cached Pantry Pasta")),
                    try Self.cacheRecord(domain: .cookbookDetail(id: "cookbook_alpha"), payload: .cookbookDetail(id: "cookbook_alpha", title: "Aardvark Suppers")),
                    try Self.cacheRecord(domain: .cookbookDetail(id: "cookbook_cached"), payload: .cookbookDetail(id: "cookbook_cached", title: "Cached Weeknights")),
                    try Self.cacheRecord(domain: .shoppingList, payload: .shoppingList(itemIDs: ["fallback_item_b", "fallback_item_a"], syncCursor: "cached.shopping.cursor")),
                    try Self.cacheRecord(domain: .captureDraft(id: "draft_image"), payload: .captureDraft(id: "draft_image", source: .imageAsset("local-image"))),
                    try Self.cacheRecord(domain: .captureDraft(id: "draft_text"), payload: .captureDraft(id: "draft_text", source: .shareSheetURL("https://example.com/cache-draft"))),
                    try Self.cacheRecord(domain: .cookProgress(recipeID: "recipe_cached"), payload: .cookProgress(recipeID: "recipe_cached", completedStepIDs: ["step_1"], currentStepID: "step_2"))
                ],
                dismissedIndicators: []
            ))
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(shoppingList: nil, savedAt: Self.isoString(Self.now))
                    .recordingOpenedRoute(.settings, savedAt: Self.isoString(Self.now))
            )
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let transport = ScriptedLiveStoreSyncTransport()
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: syncStore,
                transport: transport,
                configuration: configuration,
                appStateStoreProvider: { appStateStore }
            )

            await liveStore.bootstrap()

            guard case .signedOut(let content) = liveStore.bootstrapState else {
                Issue.record("Expected signed-out cache restore; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.recipes.map(\.id) == ["recipe_alpha", "recipe_cached"])
            #expect(content.recipes.first?.attribution.creditText == "Restored from Spoonjoy cache")
            #expect(content.cookbooks.map(\.id) == ["cookbook_alpha", "cookbook_cached"])
            #expect(content.shoppingList?.activeItems.map(\.id) == ["fallback_item_b", "fallback_item_a"])
            #expect(content.shoppingList?.nextCursor == "cached.shopping.cursor")
            #expect(content.captureDraft?.previewLines == ["https://example.com/cache-draft"])
            #expect(content.cookProgress(for: "recipe_cached")?.currentStepID == "step_2")
            #expect(content.settingsViewModel.settings.auth == .signedOut)
            #expect(content.settingsViewModel.settings.offline == .unavailable)
            #expect(liveStore.offlineIndicatorState.display == .stale(domain: .accountBootstrap))
            #expect((try await liveStore.authSessionRepository.restoreState()) == .signedOut)

            liveStore.recordingOpenedRoute(.recipeDetail(id: "recipe_cached", presentation: .detail))
            let savedRoute = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(savedRoute.accountID == "signed-out")
            #expect(savedRoute.environment == .production)
            #expect(savedRoute.hasCompletedFirstRun)
            #expect(savedRoute.lastOpenedRoute == "recipe:recipe_cached")
            liveStore.recordingOpenedRoute(.settings)
            let resavedRoute = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(resavedRoute.hasCompletedFirstRun)
            #expect(resavedRoute.lastOpenedRoute == "settings")

            liveStore.dismissOfflineIndicator()
            guard case .signedOut(let dismissedContent) = liveStore.bootstrapState else {
                Issue.record("Expected signed-out state after dismiss; got \(liveStore.bootstrapState)")
                return
            }
            if case .dismissed(let previousDisplay, let reason) = dismissedContent.offlineIndicatorState.display {
                #expect(previousDisplay == .stale(domain: .accountBootstrap))
                #expect(reason == .informationalOnly)
            } else {
                Issue.record("Expected dismissed offline indicator; got \(dismissedContent.offlineIndicatorState.display)")
            }

            await liveStore.switchEnvironment(.local)
            guard case .signedOut(let localContent) = liveStore.bootstrapState else {
                Issue.record("Expected signed-out local restore; got \(liveStore.bootstrapState)")
                return
            }
            #expect(localContent.environment == .local)
            #expect(localContent.recipes.isEmpty)
            #expect(localContent.settingsViewModel.settings.environment == .local(baseURL: configuration.baseURL))
        }
    }

    @MainActor
    @Test("live store covers shopping merge ties signed-in settings and environment failures")
    func liveStoreCoversShoppingMergeTiesSignedInSettingsAndEnvironmentFailures() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [
                    try Self.cacheRecord(
                        domain: .shoppingList,
                        payload: .shoppingList(itemIDs: ["item_decoded_b", "item_fallback"], syncCursor: nil),
                        accountID: "chef_ari"
                    )
                ],
                dismissedIndicators: []
            ))
            let decodedA = Self.sampleShoppingItem(id: "item_decoded_a", name: "apples")
            let decodedB = Self.sampleShoppingItem(id: "item_decoded_b", name: "bananas")
            let cookbook = Self.sampleCookbook(id: "cookbook_decoded", title: "Decoded Suppers")
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue(),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .cookbook, resourceID: cookbook.id, payload: try Self.jsonValue(cookbook), serverRevision: .updatedAt(cookbook.updatedAt)),
                    NativeSyncCachedRecord(kind: .shoppingItem, resourceID: decodedB.id, payload: try Self.jsonValue(decodedB), serverRevision: .updatedAt(decodedB.updatedAt)),
                    NativeSyncCachedRecord(kind: .shoppingItem, resourceID: decodedA.id, payload: try Self.jsonValue(decodedA), serverRevision: .updatedAt(decodedA.updatedAt))
                ]
            )
            let transport = ScriptedLiveStoreSyncTransport(bootstraps: [
                .result(.success(cursor: nil, tombstones: [])),
                .failure(APITransportError(
                    kind: .offline,
                    requestID: nil,
                    statusCode: nil,
                    apiError: nil,
                    retryDecision: .retrySameRequest(afterSeconds: nil)
                )),
                .failure(NativeLiveStoreTestError.processFailed("environment exploded"))
            ])
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: syncStore,
                transport: transport
            )

            await liveStore.bootstrap()
            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live sync from cached shopping records; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.shoppingList?.activeItems.map(\.id) == ["item_decoded_a", "item_decoded_b", "item_fallback"])
            #expect(content.cookbooks.map(\.id) == ["cookbook_decoded"])
            if case .signedIn(let username, let scopes, let tokenExpiresAt) = content.settingsViewModel.settings.auth {
                #expect(username == "Spoonjoy")
                #expect(scopes == NativeAuthSession.defaultScope.split(separator: " ").map(String.init))
                #expect(tokenExpiresAt != nil)
            } else {
                Issue.record("Expected signed-in settings auth; got \(content.settingsViewModel.settings.auth)")
            }
            #expect(content.settingsViewModel.settings.offline == .available(snapshotCount: 4, lastRestoredAt: nil))

            await liveStore.switchEnvironment(.local)
            guard case .offlineStale(let offlineContent) = liveStore.bootstrapState else {
                Issue.record("Expected offline environment switch; got \(liveStore.bootstrapState)")
                return
            }
            #expect(offlineContent.offlineIndicatorState.display == .offline)

            await liveStore.switchEnvironment(.production)
            guard case .syncFailed(let failedContent, let message) = liveStore.bootstrapState else {
                Issue.record("Expected failed environment switch; got \(liveStore.bootstrapState)")
                return
            }
            #expect(message.contains("environment exploded"))
            #expect(failedContent.offlineIndicatorState.display == .syncFailure(errorID: "environment", retryAfter: nil))

            liveStore.recordingOpenedRoute(.settings)

            let brokenDirectoryURL = directory.appendingPathComponent("broken-app-state.json", isDirectory: true)
            try FileManager.default.createDirectory(at: brokenDirectoryURL, withIntermediateDirectories: true)
            let brokenRouteStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { NativeAppStateStore(fileURL: brokenDirectoryURL) }
            )
            brokenRouteStore.recordingOpenedRoute(.settings)
        }
    }

    @MainActor
    @Test("live store reports fixture fallback and queue persistence failures as sync failures")
    func liveStoreReportsFixtureFallbackAndQueuePersistenceFailuresAsSyncFailures() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            setenv("SPOONJOY_ALLOW_FIXTURE_FALLBACK", "1", 1)
            defer { unsetenv("SPOONJOY_ALLOW_FIXTURE_FALLBACK") }
            let fallbackStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                fixtureFallbackPolicy: .testsAndDemoOnly
            )

            await fallbackStore.bootstrap()
            guard case .syncFailed(let fallbackContent, let fallbackMessage) = fallbackStore.bootstrapState else {
                Issue.record("Expected fixture fallback guard to produce syncFailed; got \(fallbackStore.bootstrapState)")
                return
            }
            #expect(fallbackMessage.contains("fixtureFallbackEnabledInProduction"))
            #expect(fallbackContent.offlineIndicatorState.display == .syncFailure(errorID: "bootstrap", retryAfter: nil))
            #expect(fallbackStore.bootstrapState.contentState.offlineIndicatorState.display == fallbackContent.offlineIndicatorState.display)

            let queueFailureStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: UnavailableNativeSyncStore(message: "sync store unavailable"),
                transport: ScriptedLiveStoreSyncTransport()
            )
            let mutation = NativeQueuedMutation.shoppingAddItem(
                name: "lemons",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_queue_failure",
                createdAt: Self.isoString(Self.now)
            )

            await queueFailureStore.queueMutation(mutation)

            guard case .syncFailed(let queueContent, let queueMessage) = queueFailureStore.bootstrapState else {
                Issue.record("Expected queue failure to produce syncFailed; got \(queueFailureStore.bootstrapState)")
                return
            }
            #expect(queueMessage.contains("sync store unavailable"))
            #expect(queueContent.offlineIndicatorState.display == .syncFailure(errorID: "queue", retryAfter: nil))

            let signedInVault = try await Self.signedInVault(accountID: "chef_ari")
            let flakyRestoreSyncStore = FlakyRestoreNativeSyncStore(failingLoadSnapshotCalls: [2, 4])
            let configuration = APIClientConfiguration.spoonjoyProduction
            let offlineError = APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
            let engine = NativeSyncEngine(
                store: flakyRestoreSyncStore,
                transport: ScriptedLiveStoreSyncTransport(bootstraps: [
                    .failure(offlineError),
                    .failure(offlineError)
                ]),
                clock: { Self.now }
            )
            let offlineFallbackStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: signedInVault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("offline-fallback-cache.json")),
                syncStore: flakyRestoreSyncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(
                    runner: engine,
                    configuration: configuration
                ),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                now: { Self.now }
            ))

            await offlineFallbackStore.bootstrap()
            guard case .offlineStale(let bootstrapOfflineContent) = offlineFallbackStore.bootstrapState else {
                Issue.record("Expected offline fallback when restore fails; got \(offlineFallbackStore.bootstrapState)")
                return
            }
            #expect(bootstrapOfflineContent.offlineIndicatorState.display == .offline)

            await offlineFallbackStore.switchEnvironment(.local)
            guard case .offlineStale(let environmentOfflineContent) = offlineFallbackStore.bootstrapState else {
                Issue.record("Expected environment offline fallback when restore fails; got \(offlineFallbackStore.bootstrapState)")
                return
            }
            #expect(environmentOfflineContent.offlineIndicatorState.display == .offline)
        }
    }

    @MainActor
    @Test("live store maps sync conflict auth retry and local queue outcomes to shell states")
    func liveStoreMapsSyncConflictAuthRetryAndLocalQueueOutcomesToShellStates() async throws {
        try await assertSyncOutcome(
            sendResult: .conflict(kind: .validation, serverRevision: .updatedAt("server-v2"), message: "Recipe changed on another device."),
            expectedState: "conflict"
        ) { state in
            guard case .conflict(let content) = state else {
                Issue.record("Expected conflict state; got \(state)")
                return
            }
            #expect(content.offlineIndicatorState.display == .conflict(recordID: "cm_sync_outcome", mutationID: "cm_sync_outcome"))
        }

        try await assertSyncOutcome(
            sendResult: .authFailure(message: "Provider secret expired."),
            expectedState: "blocker"
        ) { state in
            guard case .blocker(let content) = state else {
                Issue.record("Expected blocker state; got \(state)")
                return
            }
            #expect(content.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "Provider secret expired.")))
        }

        try await assertSyncOutcome(
            sendResult: .retry(afterSeconds: 90, message: "Rate limited."),
            expectedState: "syncFailed"
        ) { state in
            guard case .syncFailed(let content, let message) = state else {
                Issue.record("Expected syncFailed state; got \(state)")
                return
            }
            #expect(message == "Sync will retry.")
            #expect(content.offlineIndicatorState.display == .syncFailure(errorID: "sync", retryAfter: .seconds(90)))
            #expect(content.queuedMutations.first?.lastError == "Rate limited.")
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let localMutation = NativeQueuedMutation.captureDraftCreate(
                draftID: "draft_local",
                source: .text("https://example.com/local-only"),
                clientMutationID: "cm_local_only",
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [localMutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(bootstraps: [.result(.success(cursor: nil, tombstones: []))])
            )

            await liveStore.bootstrap()

            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queuedWork for local-only queue; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.queuedMutations.map(\.clientMutationID) == ["cm_local_only"])
            #expect(content.offlineIndicatorState.display == .queuedWork(count: 1, oldestClientMutationID: "cm_local_only"))
        }
    }

    @MainActor
    @Test("live store appends mutations to matching scoped queue")
    func liveStoreAppendsMutationsToMatchingScopedQueue() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let existingMutation = NativeQueuedMutation.captureDraftCreate(
                draftID: "draft_existing",
                source: .text("https://example.com/existing"),
                clientMutationID: "cm_existing",
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [existingMutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport()
            )
            let nextMutation = NativeQueuedMutation.shoppingAddItem(
                name: "pepper",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_next",
                createdAt: Self.isoString(Self.now.addingTimeInterval(5))
            )

            await liveStore.bootstrap()
            await liveStore.queueMutation(nextMutation)

            let snapshot = await syncStore.loadSnapshot()
            #expect(snapshot.queue.mutations.map(\.clientMutationID) == ["cm_existing", "cm_next"])
            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queuedWork after append; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.offlineIndicatorState.display == .queuedWork(count: 2, oldestClientMutationID: "cm_existing"))
        }
    }

    @Test("bootstrap states replace content without changing severity")
    func bootstrapStatesReplaceContentWithoutChangingSeverity() {
        let original = Self.emptyContent(environment: .production)
        let replacement = Self.emptyContent(environment: .local)
        #expect(original.copy().offlineIndicatorState == original.offlineIndicatorState)
        let syncedEmpty = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        #expect(syncedEmpty.settingsViewModel.settings.offline == .available(snapshotCount: 1, lastRestoredAt: nil))
        let states: [NativeAppBootstrapState] = [
            .signedOut(original),
            .restoringCache(original),
            .liveSynced(original),
            .offlineStale(original),
            .queuedWork(original),
            .conflict(original),
            .blocker(original),
            .destructiveConfirmation(original),
            .syncFailed(original, message: "Still retrying.")
        ]

        for state in states {
            let replaced = state.replacingContent(replacement)
            #expect(replaced.contentState.environment == .local)
            switch (state, replaced) {
            case (.signedOut, .signedOut),
                 (.restoringCache, .restoringCache),
                 (.liveSynced, .liveSynced),
                 (.offlineStale, .offlineStale),
                 (.queuedWork, .queuedWork),
                 (.conflict, .conflict),
                 (.blocker, .blocker),
                 (.destructiveConfirmation, .destructiveConfirmation):
                break
            case (.syncFailed(_, let originalMessage), .syncFailed(_, let replacedMessage)):
                #expect(replacedMessage == originalMessage)
            default:
                Issue.record("Expected \(state) to preserve state kind after content replacement; got \(replaced)")
            }
        }
    }

    @Test("shell content exposes recipe catalog source for live and offline states")
    func shellContentExposesRecipeCatalogSourceForLiveAndOfflineStates() throws {
        let recipe = Self.sampleRecipe(id: "recipe_catalog_source", title: "Catalog Source")
        let cacheSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "chef_ari",
            environment: .production,
            createdAt: Self.now,
            records: [],
            dismissedIndicators: []
        )
        let syncSnapshot = NativeSyncSnapshot(
            accountID: "chef_ari",
            environment: .production,
            checkpoint: nil,
            queue: NativeMutationQueue(),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: recipe.id,
                    payload: try Self.jsonValue(recipe),
                    serverRevision: .updatedAt(recipe.updatedAt)
                )
            ],
            tombstones: []
        )
        let syncedContent = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: syncSnapshot,
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: .synced(lastSyncedAt: Self.now)
        )

        let liveCatalog = syncedContent.recipeCatalog
        #expect(liveCatalog.rows.map(\.id) == ["recipe_catalog_source"])
        #expect(liveCatalog.limit == 48)
        if case .live(let requestID, _) = liveCatalog.source {
            #expect(requestID == "native-shell")
        } else {
            Issue.record("Expected synced content to expose a live recipe catalog source; got \(liveCatalog.source)")
        }

        let offlineCatalog = syncedContent
            .copy(offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil))
            .recipeCatalog
        if case .cache(let serverRevision, let lastValidatedAt) = offlineCatalog.source {
            #expect(serverRevision == .updatedAt(recipe.updatedAt))
            #expect(lastValidatedAt == .distantPast)
        } else {
            Issue.record("Expected offline content to expose a cache recipe catalog source; got \(offlineCatalog.source)")
        }
    }

    @MainActor
    private func assertSyncOutcome(
        sendResult: NativeSyncMutationResult,
        expectedState: String,
        verify: (NativeAppBootstrapState) -> Void
    ) async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let mutation = NativeQueuedMutation.shoppingAddItem(
                name: expectedState,
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_sync_outcome",
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [mutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [sendResult]
                )
            )

            await liveStore.bootstrap()
            verify(liveStore.bootstrapState)
        }
    }

    @Test("core declares live app bootstrap state and repository dependencies")
    func coreDeclaresLiveAppBootstrapStateAndRepositoryDependencies() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define the live app store contract."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "NativeLiveAppStore",
                "public struct NativeLiveAppStoreDependencies",
                "public enum NativeAppBootstrapState",
                "public struct NativeShellContentState",
                "case signedOut",
                "case restoringCache",
                "case liveSynced",
                "case offlineStale",
                "case queuedWork",
                "case conflict",
                "case blocker",
                "case destructiveConfirmation",
                "case syncFailed",
                "NativeAuthSessionRepository",
                "NativeDurableCacheStore",
                "NativeSyncStore",
                "NativeSyncEngine",
                "NativeSyncTriggerCoordinator",
                "NativeSyncExecutionScope",
                "appStateStoreProvider",
                "restoredRoute",
                "trustedAccountID",
                "bindAccountID",
                "APIClientConfiguration",
                "loadOrCreate",
                "restoreFromCache",
                "loadSnapshot",
                "bootstrapFromLiveAPI",
                "validSession()",
                "switchEnvironment",
                "recordingOpenedRoute",
                "offlineIndicatorState",
                "settingsViewModel"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "ShoppingListState.decodeFromBundle()"
            ]
        )
    }

    @Test("root view bootstraps through live store instead of fixture first run")
    func rootViewBootstrapsThroughLiveStoreInsteadOfFixtureFirstRun() throws {
        let relativePath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"
        let content = uncommentedSwift(try readRepoFile(relativePath))

        expectContent(
            content,
            in: relativePath,
            contains: [
                "liveStore",
                "NativeLiveAppStore",
                "NativeLiveAppStoreDependencies",
                "FileBackedNativeSyncStore",
                "URLSessionNativeSyncTransport",
                "NativeStagedMediaDirectory",
                "UnavailableNativeSyncStore",
                "bootstrap()",
                "bootstrapState",
                "case .signedOut",
                "case .restoringCache",
                "case .liveSynced",
                "case .offlineStale",
                "case .queuedWork",
                "case .conflict",
                "case .blocker",
                "case .destructiveConfirmation",
                "case .syncFailed",
                "PlatformNavigationView(",
                "contentState:",
                "offlineIndicatorState:",
                "dismissOfflineIndicator"
            ],
            forbids: [
                "NativeDeferredSyncTransport",
                "try? FileBackedNativeSyncStore",
                "NativeAppSnapshot.bootstrap",
                "ShoppingListState.decodeFromBundle()",
                "hasCompletedFirstRun",
                "completeFirstRun(opening:",
                "openKitchen: { completeFirstRun"
            ]
        )
    }

    @Test("platform navigation consumes live content state and never decodes production fixtures")
    func platformNavigationConsumesLiveContentStateAndNeverDecodesProductionFixtures() throws {
        let relativePath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let content = uncommentedSwift(try readRepoFile(relativePath))

        expectContent(
            content,
            in: relativePath,
            contains: [
                "NativeShellContentState",
                "contentState.recipes",
                "contentState.cookbooks",
                "contentState.kitchen",
                "contentState.shoppingList",
                "contentState.searchResults",
                "contentState.captureDraft",
                "NativeQueuedMutation",
                "queueMutation",
                "syncTriggerCoordinator",
                "OfflineStatusView(display:",
                "offlineIndicatorState",
                "dismissOfflineIndicator",
                "SettingsView(",
                "settingsViewModel"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "KitchenFixtureState.bootstrapFallback",
                "SettingsState(\n                auth: .signedOut",
                "QueuedMutation(",
                "startedAt: \"2026-06-16T11:45:00.000Z\""
            ]
        )
    }

    @Test("live store contract covers global search scopes and environment rebinding")
    func liveStoreContractCoversGlobalSearchScopesAndEnvironmentRebinding() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define live search and environment rebinding."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "SearchScope.allCases",
                ".all",
                ".recipes",
                ".cookbooks",
                ".chefs",
                ".shoppingList",
                "searchResultsByScope",
                "switchEnvironment",
                "APIClientConfiguration",
                "NativeCacheEnvironment",
                "NativeDurableCacheStore",
                "NativeSyncTriggerEvent.environmentChanged",
                "NativeSyncTriggerCoordinator"
            ]
        )
    }

    @Test("production sources cannot silently use fixture bundles")
    func productionSourcesCannotSilentlyUseFixtureBundles() throws {
        let forbiddenTokens = [
            "RecipeFixtureCatalog.decodeFromBundle()",
            "CookbookFixtureCatalog.decodeFromBundle()",
            "KitchenFixtureState.decodeFromBundle()",
            "ShoppingListState.decodeFromBundle()"
        ]
        let allowedRelativePaths: Set<String> = [
            "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
            "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift"
        ]
        let roots = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Apps/Spoonjoy"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/SpoonjoyCore")
        ]
        let productionSwiftFiles = try roots.flatMap { try collectSwiftFiles(under: $0) }
        var violations: [String] = []

        for file in productionSwiftFiles {
            let relativePath = file.path.replacingOccurrences(
                of: FileManager.default.currentDirectoryPath + "/",
                with: ""
            )
            guard !allowedRelativePaths.contains(relativePath) else { continue }
            let content = uncommentedSwift(try String(contentsOf: file, encoding: .utf8))
            for token in forbiddenTokens where content.contains(token) {
                violations.append("\(relativePath) contains \(token)")
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: "Fixture fallback must be test/demo/policy gated only: \(violations.joined(separator: "; "))"))
    }

    @Test("signed out settings and offline indicator cover every live shell state")
    func signedOutSettingsAndOfflineIndicatorCoverEveryLiveShellState() throws {
        let signedOut = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift"))
        let settings = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/SettingsView.swift"))
        let offline = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift"))

        expectContent(
            signedOut,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "NativeAuthSessionRepository",
                "SpoonjoyWebAuthenticationSession",
                "startSignIn",
                "restoreState",
                "revokeAndLogout",
                "isSigningIn",
                "SecureAuthWebHandoff.login",
                "authRequired"
            ],
            forbids: [
                "Open Kitchen",
                "keep offline fixtures nearby"
            ]
        )
        expectContent(
            settings,
            in: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
            contains: [
                "OfflineStatusView(display:",
                "viewModel.offlineIndicatorDisplay",
                "viewModel.dismissOfflineIndicator",
                "viewModel.authSessionState",
                "viewModel.environmentSwitcher"
            ],
            forbids: [
                "OfflineStatusView(state:",
                "settings.offline"
            ]
        )
        expectContent(
            offline,
            in: "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
            contains: [
                "queuedWork",
                "syncFailure",
                "conflict",
                "blocker",
                "destructiveConfirmation",
                "informationalOnly",
                "Button",
                "onDismiss"
            ],
            forbids: [
                "legacyStatusLabel"
            ]
        )
    }

    @Test("scenario verifier reports live store as structured checks and capabilities")
    func scenarioVerifierReportsLiveStoreAsStructuredChecksAndCapabilities() throws {
        let report = ScenarioVerifier.finalReport(rootURL: repoRootURL())
        let checksByName = report.checks.reduce(into: [String: ScenarioCheckStatus]()) { result, check in
            result[check.name] = check.status
        }
        let requiredPassingChecks = [
            "live store source",
            "signed-out live bootstrap",
            "restoring cache",
            "live synced shell",
            "offline stale shell",
            "queued work shell",
            "conflict shell",
            "blocker shell",
            "destructive confirmation shell",
            "sync failed shell",
            "fixture fallback disabled"
        ]

        for checkName in requiredPassingChecks {
            #expect(
                checksByName[checkName] == .pass,
                Comment(rawValue: "ScenarioVerifier.finalReport should pass structured check \(checkName).")
            )
        }

        let requiredOfflineFlows: Set<String> = [
            "live-store-source",
            "signed-out-state",
            "restoring-cache",
            "live-synced",
            "offline-stale",
            "queued-work",
            "conflict",
            "blocker",
            "destructive-confirmation",
            "sync-failed",
            "fixture-fallback-disabled"
        ]
        let reportedOfflineFlows = Set(report.nativeCapabilities.offlineFlows)
        #expect(
            requiredOfflineFlows.isSubset(of: reportedOfflineFlows),
            Comment(rawValue: "ScenarioVerifier.finalReport should expose live-store offline flows: \(requiredOfflineFlows.subtracting(reportedOfflineFlows).sorted().joined(separator: ", "))")
        )
    }

    @Test("shell contract gate live store instead of fixture parity")
    func shellContractGatesLiveStoreInsteadOfFixtureParity() throws {
        let shellContract = try readRepoFile("scripts/check-native-shell-contract.rb")

        expectContent(
            shellContract,
            in: "scripts/check-native-shell-contract.rb",
            contains: [
                "NativeLiveAppStore",
                "NativeShellContentState",
                "NativeLiveAppStoreDependencies",
                "OfflineStatusView(display:",
                "fixture fallback disabled"
            ]
        )
    }

    @Test("production fixture fallback is an explicit test and demo only policy")
    func productionFixtureFallbackIsAnExplicitTestAndDemoOnlyPolicy() throws {
        let relativePath = "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift"
        let content = try? readRepoFile(relativePath)
        #expect(content != nil, Comment(rawValue: "\(relativePath) should define fixture fallback policy."))
        guard let content else { return }

        expectContent(
            uncommentedSwift(content),
            in: relativePath,
            contains: [
                "public enum NativeFixtureFallbackPolicy",
                "case disabledInProduction",
                "case testsAndDemoOnly",
                "allowsProductionFallback",
                "SPOONJOY_ALLOW_FIXTURE_FALLBACK",
                "isTestOrDemoBuild"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()"
            ]
        )

        let executableURL = try compileFixtureFallbackPolicyHarness(policySource: content)
        let run = try runProcess(executableURL.path, [])
        #expect(run.status == 0, Comment(rawValue: "NativeFixtureFallbackPolicy runtime contract failed:\n\(run.output)"))
    }
}

private enum LiveStoreBootstrapResponse {
    case result(NativeSyncBootstrapResult)
    case failure(any Error)
}

private actor ScriptedLiveStoreSyncTransport: NativeSyncTransport {
    private var bootstrapResponses: [LiveStoreBootstrapResponse]
    private var sendResults: [NativeSyncMutationResult]

    init(
        bootstraps: [LiveStoreBootstrapResponse] = [],
        sends: [NativeSyncMutationResult] = []
    ) {
        self.bootstrapResponses = bootstraps
        self.sendResults = sends
    }

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        guard !bootstrapResponses.isEmpty else {
            return .success(cursor: nil, tombstones: [])
        }

        switch bootstrapResponses.removeFirst() {
        case .result(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        guard !sendResults.isEmpty else {
            return .success(serverRevision: .updatedAt(mutation.createdAt))
        }

        return sendResults.removeFirst()
    }
}

private actor FlakyRestoreNativeSyncStore: NativeSyncStore {
    private let failingLoadSnapshotCalls: Set<Int>
    private var loadSnapshotCallCount = 0

    init(failingLoadSnapshotCalls: Set<Int>) {
        self.failingLoadSnapshotCalls = failingLoadSnapshotCalls
    }

    func loadQueue() throws -> NativeMutationQueue {
        NativeMutationQueue()
    }

    func saveQueue(_: NativeMutationQueue) throws {}

    func saveQueue(_: NativeMutationQueue, accountID _: String?, environment _: NativeCacheEnvironment?) throws {}

    func loadCheckpoint() throws -> NativeSyncCheckpoint {
        throw NativeSyncStoreError.missingCheckpoint
    }

    func saveCheckpoint(_: NativeSyncCheckpoint) throws {}

    func appendTombstone(_: NativeSyncTombstone) throws {}

    func cachedRecord(kind _: NativeSyncEntryKind, resourceID _: String) throws -> NativeSyncCachedRecord? {
        nil
    }

    func apply(syncData _: NativeSyncData, validatedAt _: Date) throws -> NativeSyncApplyResult {
        NativeSyncApplyResult(upsertedCacheKeys: [], removedCacheKeys: [], tombstones: [])
    }

    func loadSnapshot() throws -> NativeSyncSnapshot {
        loadSnapshotCallCount += 1
        if failingLoadSnapshotCalls.contains(loadSnapshotCallCount) {
            throw NativeSyncStoreError.unavailable("restore unavailable")
        }
        return .empty
    }
}

private actor CapturingLiveStoreSyncTransport: NativeSyncTransport {
    private var bootstrapResults: [NativeSyncBootstrapResult]
    private var bearerTokens: [String?] = []

    init(bootstrap: NativeSyncBootstrapResult) {
        self.bootstrapResults = [bootstrap]
    }

    init(bootstraps: [NativeSyncBootstrapResult]) {
        self.bootstrapResults = bootstraps
    }

    func bootstrap(request _: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        bearerTokens.append(configuration.bearerToken)
        guard bootstrapResults.count > 1 else {
            return bootstrapResults.first ?? .success(cursor: nil, tombstones: [])
        }
        return bootstrapResults.removeFirst()
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        .success(serverRevision: .updatedAt(mutation.createdAt))
    }

    func capturedBearerTokens() -> [String?] {
        bearerTokens
    }
}

private struct ThrowingLiveStoreSyncTransport: NativeSyncTransport {
    let error: APITransportError

    func bootstrap(request _: APIRequest, configuration _: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        throw error
    }

    func send(_ mutation: NativeQueuedMutation, configuration _: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        .success(serverRevision: .updatedAt(mutation.createdAt))
    }
}

private enum NativeLiveStoreTestError: Error, CustomStringConvertible {
    case missingFile(String)
    case processFailed(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            "Missing repo file: \(path)"
        case .processFailed(let output):
            output
        }
    }
}

@MainActor
private func withTemporaryLiveStoreDirectory<T>(_ body: @MainActor (URL) async throws -> T) async throws -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-live-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try await body(directory)
}

private extension NativeLiveStoreTests {
    @MainActor
    static func liveStore(
        directory: URL,
        vault: InMemoryTokenVault,
        cacheStore: NativeDurableCacheStore? = nil,
        syncStore: any NativeSyncStore,
        transport: any NativeSyncTransport,
        configuration: APIClientConfiguration = .spoonjoyProduction,
        cacheEnvironment: NativeCacheEnvironment = .production,
        appStateStoreProvider: @escaping @MainActor () -> NativeAppStateStore? = { nil },
        fixtureFallbackPolicy: NativeFixtureFallbackPolicy = .disabledInProduction
    ) -> NativeLiveAppStore {
        let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
        return NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
            authSessionRepository: authRepository(vault: vault),
            cacheStore: cacheStore ?? NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: configuration),
            appStateStoreProvider: appStateStoreProvider,
            configuration: configuration,
            cacheEnvironment: cacheEnvironment,
            fixtureFallbackPolicy: fixtureFallbackPolicy,
            now: { Self.now }
        ))
    }

    static func signedInVault(accountID: String?) async throws -> InMemoryTokenVault {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID("client_live")
        try await vault.saveSession(try AuthSession(
            clientID: "client_live",
            accessToken: "sj_access_current",
            refreshToken: "sj_refresh_current",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: accountID
        ))
        return vault
    }

    static func authRepository(vault: InMemoryTokenVault) -> NativeAuthSessionRepository {
        NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in
                OAuthTokenResponse(
                    accessToken: "sj_access_exchanged",
                    refreshToken: "sj_refresh_exchanged",
                    tokenType: "Bearer",
                    expiresIn: 3_600,
                    scope: NativeAuthSession.defaultScope
                )
            },
            refresh: { _, _ in
                OAuthTokenResponse(
                    accessToken: "sj_access_refreshed",
                    refreshToken: "sj_refresh_refreshed",
                    tokenType: "Bearer",
                    expiresIn: 3_600,
                    scope: NativeAuthSession.defaultScope
                )
            },
            revoke: { _, _ in },
            now: { Self.now }
        )
    }

    static func emptyContent(environment: NativeCacheEnvironment) -> NativeShellContentState {
        NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: environment,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
    }

    static func cacheRecord(
        domain: NativeCacheDomain,
        payload: NativeCachePayload,
        accountID: String = "signed-out",
        environment: NativeCacheEnvironment = .production
    ) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: accountID,
                environment: environment,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: now,
                lastValidatedAt: now,
                sourceEndpoint: "local://unit-test/\(domain.stableRecordID)",
                serverRevision: .localRevision("unit-test")
            ),
            payload: payload
        )
    }

    static func sampleSyncData(
        recipe: Recipe,
        shoppingItem: ShoppingListItem,
        accountID: String = "client_live",
        environment: NativeCacheEnvironment = .production
    ) throws -> NativeSyncData {
        NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: accountID,
                environment: environment,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: isoString(now),
                lastValidatedAt: isoString(now)
            ),
            entries: [
                NativeSyncEntry(
                    action: .upsert,
                    kind: .recipe,
                    resourceID: recipe.id,
                    updatedAt: recipe.updatedAt,
                    payload: try jsonValue(recipe),
                    tombstone: nil
                ),
                NativeSyncEntry(
                    action: .upsert,
                    kind: .shoppingItem,
                    resourceID: shoppingItem.id,
                    updatedAt: shoppingItem.updatedAt,
                    payload: try jsonValue(shoppingItem),
                    tombstone: nil
                )
            ],
            nextCursor: PaginationCursor(rawValue: "v1.live.after"),
            hasMore: false
        )
    }

    static func sampleRecipe(id: String, title: String) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        let chef = ChefSummary(id: "chef_ari", username: "ari")
        return Recipe(
            id: id,
            title: title,
            description: "Bright and quick.",
            servings: "2",
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "By ari",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: isoString(now),
            updatedAt: isoString(now),
            steps: [
                RecipeStep(
                    id: "step_\(id)",
                    stepNum: 1,
                    stepTitle: "Cook",
                    description: "Toss with lemon.",
                    duration: 5,
                    ingredients: []
                )
            ],
            cookbooks: []
        )
    }

    static func sampleCookbook(id: String, title: String) -> Cookbook {
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
        return Cookbook(
            id: id,
            title: title,
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(creditText: "By ari", canonicalURL: canonicalURL),
            createdAt: isoString(now),
            updatedAt: isoString(now),
            recipes: []
        )
    }

    static func sampleShoppingItem(id: String, name: String) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: 3,
            unit: "each",
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: "produce",
            iconKey: "lemon",
            sortIndex: 0,
            updatedAt: isoString(now)
        )
    }

    static func jsonValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRootURL().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeLiveStoreTestError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
}

private func repoRootURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func collectSwiftFiles(under root: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return try enumerator.compactMap { item in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }
        let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
        return resourceValues.isRegularFile == true ? url : nil
    }
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(
            of: #"/\*.*?\*/"#,
            with: "",
            options: [.regularExpression]
        )
        .replacingOccurrences(
            of: #"(?m)//.*$"#,
            with: "",
            options: [.regularExpression]
        )
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String] = []
) {
    for token in requiredTokens {
        let isPresent = content.contains(token)
        #expect(isPresent, Comment(rawValue: "\(relativePath) missing token: \(token)"))
    }

    for token in forbiddenTokens {
        let isAbsent = !content.contains(token)
        #expect(isAbsent, Comment(rawValue: "\(relativePath) should not contain token: \(token)"))
    }
}

private struct ProcessRunResult: Equatable {
    let status: Int32
    let output: String
}

private func compileFixtureFallbackPolicyHarness(policySource: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-fixture-policy-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let policyURL = directory.appendingPathComponent("NativeFixtureFallbackPolicy.swift")
    let harnessURL = directory.appendingPathComponent("main.swift")
    let executableURL = directory.appendingPathComponent("fixture-policy-check")
    try policySource.write(to: policyURL, atomically: true, encoding: .utf8)
    try fixtureFallbackPolicyHarnessSource.write(to: harnessURL, atomically: true, encoding: .utf8)

    let compile = try runProcess(
        "/usr/bin/xcrun",
        [
            "swiftc",
            policyURL.path,
            harnessURL.path,
            "-o",
            executableURL.path
        ]
    )
    #expect(compile.status == 0, Comment(rawValue: "NativeFixtureFallbackPolicy should compile in isolation:\n\(compile.output)"))
    guard compile.status == 0 else {
        throw NativeLiveStoreTestError.processFailed(compile.output)
    }
    return executableURL
}

private func runProcess(_ executablePath: String, _ arguments: [String]) throws -> ProcessRunResult {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return ProcessRunResult(status: process.terminationStatus, output: output)
}

private let fixtureFallbackPolicyHarnessSource = """
import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition {
        FileHandle.standardError.write(Data((message + "\\n").utf8))
        exit(1)
    }
}

let disabled = NativeFixtureFallbackPolicy.disabledInProduction
require(!disabled.allowsProductionFallback(isTestOrDemoBuild: false, environment: [:]), "production fallback must be denied by default")
require(!disabled.allowsProductionFallback(isTestOrDemoBuild: true, environment: ["SPOONJOY_ALLOW_FIXTURE_FALLBACK": "1"]), "disabled policy must deny even explicit test/demo opt-in")

let testsAndDemo = NativeFixtureFallbackPolicy.testsAndDemoOnly
require(!testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: false, environment: [:]), "tests/demo policy must deny production by default")
require(testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: true, environment: [:]), "tests/demo policy must allow test builds")
require(testsAndDemo.allowsProductionFallback(isTestOrDemoBuild: false, environment: ["SPOONJOY_ALLOW_FIXTURE_FALLBACK": "1"]), "tests/demo policy must allow explicit environment opt-in")
require(NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctest"]), "XCTest environment should be recognized")
require(NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: ["SPOONJOY_DEMO_MODE": "1"]), "demo environment should be recognized")
require(!NativeFixtureFallbackPolicy.isTestOrDemoBuild(environment: [:]), "empty environment should not be treated as test/demo")
"""
