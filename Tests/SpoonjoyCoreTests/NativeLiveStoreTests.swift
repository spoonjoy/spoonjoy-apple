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
    @Test("live store represents an empty synced shopping list")
    func liveStoreRepresentsAnEmptySyncedShoppingList() async throws {
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
                accountID: "client_live"
            ))
            let recipe = Self.sampleRecipe(id: "recipe_empty_shopping", title: "Empty List Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil)
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            )

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live store to finish in liveSynced; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.shoppingList != nil)
            #expect(content.shoppingList?.activeItems.isEmpty == true)
            #expect(content.kitchen.counts.shoppingItems == 0)
            #expect(content.searchResultsByScope[.shoppingList]?.isEmpty == true)
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

            try await liveStore.queueMutation(mutation)
            let persisted = try await syncStore.loadQueue()

            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queueMutation to show queuedWork; got \(liveStore.bootstrapState)")
                return
            }

            #expect(persisted.mutations == [mutation])
            #expect(content.queuedMutations == [mutation])
            #expect(content.shoppingList?.activeItems.map(\.name) == ["lemons"])
            #expect(content.shoppingList?.activeItems.first?.quantity == 2)
            #expect(content.offlineIndicatorState.display == .queuedWork(count: 1, oldestClientMutationID: "cm_live_queue"))
        }
    }

    @MainActor
    @Test("live store restores queued shopping mutations as optimistic content")
    func liveStoreRestoresQueuedShoppingMutationsAsOptimisticContent() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(
                id: "recipe_offline_shopping",
                title: "Offline Shopping Pasta",
                ingredients: [
                    RecipeIngredient(id: "ingredient_pasta", name: "pasta", quantity: 8, unit: "oz"),
                    RecipeIngredient(id: "ingredient_lemon", name: "lemons", quantity: 1, unit: "each")
                ]
            )
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: Self.sampleShoppingItem(id: "item_salt", name: "salt"))
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let liveStore = Self.liveStore(directory: directory, vault: vault, syncStore: syncStore, transport: transport)

            await liveStore.bootstrap()
            try await liveStore.queueMutations([
                NativeQueuedMutation.shoppingAddItem(
                    name: "limes",
                    quantity: 2,
                    unit: "each",
                    categoryKey: "produce",
                    iconKey: "lemon",
                    clientMutationID: "cm_shopping_add_limes",
                    createdAt: Self.isoString(Self.now)
                ),
                NativeQueuedMutation.shoppingAddFromRecipe(
                    recipeID: "recipe_offline_shopping",
                    scaleFactor: 1.5,
                    clientMutationID: "cm_shopping_recipe",
                    createdAt: Self.isoString(Self.now)
                )
            ])

            guard case .queuedWork(let queuedContent) = liveStore.bootstrapState else {
                Issue.record("Expected queued shopping work; got \(liveStore.bootstrapState)")
                return
            }
            #expect(queuedContent.shoppingList?.activeItems.map(\.name) == ["salt", "limes", "pasta", "lemons"])
            #expect(queuedContent.shoppingList?.item(id: "item_local_cm_shopping_recipe-ingredient-1")?.quantity == 12)
            #expect(queuedContent.queuedMutations.map(\.clientMutationID) == ["cm_shopping_add_limes", "cm_shopping_recipe"])

            let offlineError = APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
            let restoredLiveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ThrowingLiveStoreSyncTransport(error: offlineError)
            )

            await restoredLiveStore.bootstrap()
            guard case .offlineStale(let restoredContent) = restoredLiveStore.bootstrapState else {
                Issue.record("Expected offline restore with queued shopping overlays; got \(restoredLiveStore.bootstrapState)")
                return
            }
            #expect(restoredContent.shoppingList?.activeItems.map(\.name) == ["salt", "limes", "pasta", "lemons"])
            #expect(restoredContent.shoppingList?.item(id: "item_local_cm_shopping_add_limes")?.quantity == 2)
            #expect(restoredContent.shoppingList?.item(id: "item_local_cm_shopping_recipe-ingredient-1")?.quantity == 12)
            #expect(restoredContent.queuedMutations.map(\.clientMutationID) == ["cm_shopping_add_limes", "cm_shopping_recipe"])
        }
    }

    @MainActor
    @Test("live store queueMutation optimistically reflects queued cookbook edits")
    func liveStoreQueueMutationOptimisticallyReflectsQueuedCookbookEdits() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_flatbread", title: "Skillet Flatbread")
            let cookbook = Self.sampleCookbook(id: "cookbook_weeknights", title: "Weeknights")
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                cookbook: cookbook,
                shoppingItem: nil,
                accountID: "chef_ari"
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            )

            await liveStore.bootstrap()
            try await liveStore.queueMutations([
                NativeQueuedMutation.cookbookUpdate(
                    cookbookID: cookbook.id,
                    title: "Dinner Parties",
                    clientMutationID: "cm_cookbook_rename_live",
                    createdAt: Self.isoString(Self.now)
                ),
                NativeQueuedMutation.cookbookAddRecipe(
                    cookbookID: cookbook.id,
                    recipeID: recipe.id,
                    clientMutationID: "cm_cookbook_add_live",
                    createdAt: Self.isoString(Self.now.addingTimeInterval(1))
                ),
                NativeQueuedMutation.cookbookCreate(
                    clientMutationID: "cm_cookbook_create_live",
                    title: "Picnic Plans",
                    createdAt: Self.isoString(Self.now.addingTimeInterval(2))
                )
            ])

            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queued cookbook work; got \(liveStore.bootstrapState)")
                return
            }

            let cookbooksByID = Dictionary(uniqueKeysWithValues: content.cookbooks.map { ($0.id, $0) })
            #expect(content.queuedMutations.map(\.clientMutationID) == [
                "cm_cookbook_rename_live",
                "cm_cookbook_add_live",
                "cm_cookbook_create_live"
            ])
            #expect(cookbooksByID[cookbook.id]?.title == "Dinner Parties")
            #expect(cookbooksByID[cookbook.id]?.recipes.map(\.id) == [recipe.id])
            #expect(cookbooksByID["cookbook_local_cm_cookbook_create_live"]?.title == "Picnic Plans")
            #expect(cookbooksByID["cookbook_local_cm_cookbook_create_live"]?.chef.username == "ari")
            #expect(content.searchResultsByScope[.cookbooks]?.contains("cookbook_local_cm_cookbook_create_live") == true)
            #expect(content.offlineIndicatorState.display == .queuedWork(count: 3, oldestClientMutationID: "cm_cookbook_rename_live"))
        }
    }

    @MainActor
    @Test("live store queueMutation optimistically reflects queued recipe edits")
    func liveStoreQueueMutationOptimisticallyReflectsQueuedRecipeEdits() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_offline_edit", title: "Offline Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: Self.sampleShoppingItem(id: "item_salt", name: "salt"))
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let liveStore = Self.liveStore(directory: directory, vault: vault, syncStore: syncStore, transport: transport)

            await liveStore.bootstrap()
            try await liveStore.queueMutation(NativeQueuedMutation.recipeUpdate(
                recipeID: "recipe_offline_edit",
                clientMutationID: "cm_recipe_update_offline",
                title: "Queued Pasta",
                description: nil,
                servings: "4",
                createdAt: Self.isoString(Self.now)
            ))
            try await liveStore.queueMutation(try NativeQueuedMutation.recipeStepCreate(
                recipeID: "recipe_offline_edit",
                clientMutationID: "cm_step_offline",
                stepNum: 2,
                stepTitle: "Serve",
                description: "Serve while warm.",
                duration: nil,
                ingredients: [RecipeIngredientDraft(quantity: 1, unit: "pinch", name: "salt")],
                outputStepNums: [1],
                createdAt: Self.isoString(Self.now)
            ))
            try await liveStore.queueMutation(try NativeQueuedMutation.recipeCreate(
                clientMutationID: "cm_recipe_create_offline",
                title: "Queued Toast",
                description: "Buttery toast.",
                servings: "2",
                steps: [
                    RecipeStepDraft(
                        stepNum: 1,
                        stepTitle: "Toast",
                        description: "Toast bread.",
                        duration: 120,
                        ingredients: [RecipeIngredientDraft(quantity: 2, unit: "slice", name: "bread")],
                        outputStepNums: []
                    )
                ],
                createdAt: Self.isoString(Self.now)
            ))

            guard case .queuedWork(let content) = liveStore.bootstrapState else {
                Issue.record("Expected queuedWork after recipe mutations; got \(liveStore.bootstrapState)")
                return
            }

            let edited = try #require(content.recipe(id: "recipe_offline_edit"))
            #expect(edited.title == "Queued Pasta")
            #expect(edited.description == nil)
            #expect(edited.servings == "4")
            #expect(edited.steps.map(\.stepTitle) == ["Cook", "Serve"])
            #expect(edited.steps[1].ingredients.map(\.name) == ["salt"])
            #expect(edited.steps[1].usingSteps.map(\.outputStepNum) == [1])
            #expect(content.recipes.contains { $0.id == "recipe_local_cm_recipe_create_offline" && $0.title == "Queued Toast" })
            #expect(content.queuedMutations.map(\.clientMutationID) == [
                "cm_recipe_update_offline",
                "cm_step_offline",
                "cm_recipe_create_offline"
            ])

            let offlineError = APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
            let restoredLiveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ThrowingLiveStoreSyncTransport(error: offlineError)
            )

            await restoredLiveStore.bootstrap()
            guard case .offlineStale(let restoredContent) = restoredLiveStore.bootstrapState else {
                Issue.record("Expected offline restore with queued recipe overlays; got \(restoredLiveStore.bootstrapState)")
                return
            }
            let restoredEdited = try #require(restoredContent.recipe(id: "recipe_offline_edit"))
            #expect(restoredEdited.title == "Queued Pasta")
            #expect(restoredEdited.steps.map(\.stepTitle) == ["Cook", "Serve"])
            #expect(restoredContent.recipes.contains { $0.id == "recipe_local_cm_recipe_create_offline" && $0.title == "Queued Toast" })
            #expect(restoredContent.queuedMutations.map(\.clientMutationID) == [
                "cm_recipe_update_offline",
                "cm_step_offline",
                "cm_recipe_create_offline"
            ])
        }
    }

    @MainActor
    @Test("live store restores queued spoon mutations as optimistic recipe detail")
    func liveStoreRestoresQueuedSpoonMutationsAsOptimisticRecipeDetail() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let mediaDirectory = NativeStagedMediaDirectory(
                directoryURL: directory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
            let chef = ChefSummary(id: "chef_ari", username: "ari")
            let existingSpoon = RecipeDetailRecentSpoon(
                id: "spoon_existing_live",
                chefID: chef.id,
                recipeID: "recipe_offline_spoons",
                cookedAt: Self.isoString(Self.now.addingTimeInterval(-60)),
                photoURL: URL(string: "/photos/spoons/existing.jpg"),
                note: "Needs more lemon.",
                nextTime: nil,
                deletedAt: nil,
                createdAt: Self.isoString(Self.now.addingTimeInterval(-60)),
                updatedAt: Self.isoString(Self.now.addingTimeInterval(-60)),
                chef: chef
            )
            let recipe = Self.sampleRecipe(
                id: "recipe_offline_spoons",
                title: "Offline Spoon Pasta",
                recentSpoons: [existingSpoon]
            )
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                shoppingItem: Self.sampleShoppingItem(id: "item_spoon_salt", name: "salt"),
                accountID: "chef_ari"
            )
            let syncStoreURL = directory.appendingPathComponent("sync.json")
            let syncStore = try FileBackedNativeSyncStore(fileURL: syncStoreURL, mediaResolver: mediaDirectory)
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData)),
                stagedMediaDirectory: mediaDirectory
            )
            let stagedPhoto = NativeStagedMediaUpload(
                localStageID: "stage_spoon_live_photo",
                fileName: "spoon.webp",
                contentType: "image/webp",
                data: Data([0x01, 0x02, 0x03])
            )

            await liveStore.bootstrap()
            try await liveStore.queueMutations([
                NativeQueuedMutation.spoonCreatePhoto(
                    recipeID: recipe.id,
                    photo: stagedPhoto,
                    clientMutationID: "cm_spoon_live_photo",
                    note: "Photo proof.",
                    nextTime: "Less salt.",
                    cookedAt: Self.isoString(Self.now),
                    useAsRecipeCover: false,
                    createdAt: Self.isoString(Self.now)
                ),
                NativeQueuedMutation.spoonUpdate(
                    recipeID: recipe.id,
                    spoonID: existingSpoon.id,
                    clientMutationID: "cm_spoon_live_update",
                    note: nil,
                    nextTime: "Use less salt.",
                    cookedAt: Self.isoString(Self.now.addingTimeInterval(10)),
                    photoURL: nil,
                    createdAt: Self.isoString(Self.now.addingTimeInterval(10))
                ),
                NativeQueuedMutation.spoonDelete(
                    recipeID: recipe.id,
                    spoonID: existingSpoon.id,
                    clientMutationID: "cm_spoon_live_delete",
                    createdAt: Self.isoString(Self.now.addingTimeInterval(20))
                )
            ])

            guard case .queuedWork(let queuedContent) = liveStore.bootstrapState else {
                Issue.record("Expected queued spoon work; got \(liveStore.bootstrapState)")
                return
            }
            let queuedRecipe = try #require(queuedContent.recipe(id: recipe.id))
            let queuedPhotoSpoon = try #require(queuedRecipe.recentSpoons.first { $0.id == "spoon_local_cm_spoon_live_photo" })
            let queuedDeletedSpoon = try #require(queuedRecipe.recentSpoons.first { $0.id == existingSpoon.id })
            #expect(queuedPhotoSpoon.note == "Photo proof.")
            #expect(queuedPhotoSpoon.nextTime == "Less salt.")
            #expect(queuedDeletedSpoon.note == nil)
            #expect(queuedDeletedSpoon.nextTime == "Use less salt.")
            #expect(queuedDeletedSpoon.deletedAt == Self.isoString(Self.now))
            #expect(queuedContent.queuedMutations.map(\.clientMutationID) == [
                "cm_spoon_live_photo",
                "cm_spoon_live_update",
                "cm_spoon_live_delete"
            ])
            #expect(queuedContent.queuedMutations.first?.stagedMediaUploadByteCount == 3)
            #expect(try mediaDirectory.data(for: stagedPhoto) == stagedPhoto.data)

            let offlineError = APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
            let restoredSyncStore = try FileBackedNativeSyncStore(fileURL: syncStoreURL, mediaResolver: mediaDirectory)
            let restoredLiveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: restoredSyncStore,
                transport: ThrowingLiveStoreSyncTransport(error: offlineError),
                stagedMediaDirectory: mediaDirectory
            )

            await restoredLiveStore.bootstrap()
            guard case .offlineStale(let restoredContent) = restoredLiveStore.bootstrapState else {
                Issue.record("Expected offline restore with queued spoon overlays; got \(restoredLiveStore.bootstrapState)")
                return
            }
            let restoredRecipe = try #require(restoredContent.recipe(id: recipe.id))
            let restoredPhotoSpoon = try #require(restoredRecipe.recentSpoons.first { $0.id == "spoon_local_cm_spoon_live_photo" })
            let restoredPhotoMutation = try #require(restoredContent.queuedMutations.first { $0.clientMutationID == "cm_spoon_live_photo" })
            let restoredPhotoRequest = try restoredPhotoMutation.requestBuilder().urlRequest(configuration: .spoonjoyProduction)

            #expect(restoredPhotoSpoon.note == "Photo proof.")
            #expect(restoredRecipe.recentSpoons.first { $0.id == existingSpoon.id }?.deletedAt == Self.isoString(Self.now.addingTimeInterval(20)))
            #expect(restoredPhotoMutation.stagedMediaUploadByteCount == 3)
            #expect(restoredPhotoRequest.body?.range(of: stagedPhoto.data) != nil)
            #expect(restoredContent.queuedMutations.map(\.clientMutationID) == [
                "cm_spoon_live_photo",
                "cm_spoon_live_update",
                "cm_spoon_live_delete"
            ])
        }
    }

    @MainActor
    @Test("live store keeps drained recipe editor mutations visible after immediate online drain")
    func liveStoreKeepsDrainedRecipeEditorMutationsVisibleAfterImmediateOnlineDrain() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_drain_editor", title: "Server Pasta")
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                shoppingItem: Self.sampleShoppingItem(id: "item_drain", name: "salt")
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [
                        .result(.syncData(syncData)),
                        .result(.success(cursor: nil, tombstones: []))
                    ],
                    sends: [.success(serverRevision: .updatedAt("2026-06-25T18:30:00.000Z"))]
                )
            )

            await liveStore.bootstrap()
            let result = try await liveStore.queueMutations([
                NativeQueuedMutation.recipeUpdate(
                    recipeID: "recipe_drain_editor",
                    clientMutationID: "cm_editor_online_batch",
                    title: "Drained Pasta",
                    description: recipe.description,
                    servings: recipe.servings,
                    createdAt: Self.isoString(Self.now)
                )
            ], drainImmediately: true)

            #expect(result.submittedClientMutationIDs == ["cm_editor_online_batch"])
            #expect(result.drainedClientMutationIDs == ["cm_editor_online_batch"])
            #expect(result.remainingSubmittedClientMutationIDs.isEmpty)
            #expect(result.submittedConflicts.isEmpty)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected drained editor mutation to return to liveSynced; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.queuedMutations.isEmpty)
            #expect(content.recipe(id: "recipe_drain_editor")?.title == "Drained Pasta")
            #expect(content.offlineIndicatorState.display == .synced)
        }
    }

    @MainActor
    @Test("live store keeps drained shopping mutations visible and cached after immediate online drain")
    func liveStoreKeepsDrainedShoppingMutationsVisibleAndCachedAfterImmediateOnlineDrain() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_shopping_drain", title: "Shopping Drain Pasta")
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                shoppingItem: Self.sampleShoppingItem(id: "item_salt", name: "salt")
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [
                        .result(.syncData(syncData)),
                        .result(.success(cursor: nil, tombstones: []))
                    ],
                    sends: [
                        .success(serverRevision: .updatedAt("2026-06-25T18:30:00.000Z"), idRemaps: [
                            NativeSyncIDRemap(localID: "item_local_cm_shopping_drain_pepper", serverID: "item_server_pepper")
                        ])
                    ]
                )
            )

            await liveStore.bootstrap()
            let result = try await liveStore.queueMutations([
                NativeQueuedMutation.shoppingAddItem(
                    name: "pepper",
                    quantity: 1,
                    unit: "jar",
                    categoryKey: "pantry",
                    iconKey: "jar",
                    clientMutationID: "cm_shopping_drain_pepper",
                    createdAt: Self.isoString(Self.now)
                )
            ], drainImmediately: true)

            #expect(result.submittedClientMutationIDs == ["cm_shopping_drain_pepper"])
            #expect(result.drainedClientMutationIDs == ["cm_shopping_drain_pepper"])
            #expect(result.remainingSubmittedClientMutationIDs.isEmpty)
            #expect(result.submittedConflicts.isEmpty)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected drained shopping mutation to return to liveSynced; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.queuedMutations.isEmpty)
            #expect(content.shoppingList?.activeItems.map(\.name) == ["salt", "pepper"])
            #expect(content.shoppingList?.item(id: "item_server_pepper")?.quantity == 1)
            #expect(content.shoppingList?.item(id: "item_local_cm_shopping_drain_pepper") == nil)

            let offlineError = APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: nil)
            )
            let restoredLiveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ThrowingLiveStoreSyncTransport(error: offlineError)
            )

            await restoredLiveStore.bootstrap()
            guard case .offlineStale(let restoredContent) = restoredLiveStore.bootstrapState else {
                Issue.record("Expected offline restore with drained shopping cache; got \(restoredLiveStore.bootstrapState)")
                return
            }
            #expect(restoredContent.shoppingList?.activeItems.map(\.name) == ["salt", "pepper"])
            #expect(restoredContent.shoppingList?.item(id: "item_server_pepper")?.quantity == 1)
            #expect(restoredContent.queuedMutations.isEmpty)
        }
    }

    @MainActor
    @Test("live store persists drained shopping checks when the base list came from app snapshot")
    func liveStorePersistsDrainedShoppingChecksWhenBaseListCameFromAppSnapshot() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            let snapshotItem = Self.sampleShoppingItem(id: "item_snapshot", name: "snapshot salt")
            let snapshotList = ShoppingListState(
                id: "shopping_list_snapshot",
                chef: ChefSummary(id: "chef_ari", username: "ari"),
                items: [snapshotItem],
                nextCursor: "",
                updatedAt: Self.isoString(Self.now)
            )
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: snapshotList,
                    accountID: "chef_ari",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [
                        .result(.success(cursor: nil, tombstones: [])),
                        .result(.success(cursor: nil, tombstones: []))
                    ],
                    sends: [.success(serverRevision: .updatedAt("2026-06-25T18:40:00.000Z"))]
                ),
                appStateStoreProvider: { appStateStore }
            )

            await liveStore.bootstrap()
            let result = try await liveStore.queueMutations([
                NativeQueuedMutation.shoppingCheckItem(
                    itemID: "item_snapshot",
                    checked: true,
                    clientMutationID: "cm_snapshot_check",
                    createdAt: Self.isoString(Self.now)
                )
            ], drainImmediately: true)

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected drained snapshot shopping mutation to return to liveSynced; got \(liveStore.bootstrapState)")
                return
            }
            let cachedSnapshotItem = try #require(try await syncStore.cachedRecord(kind: .shoppingItem, resourceID: "item_snapshot"))
            let cachedItem = try JSONDecoder().decode(ShoppingListItem.self, from: JSONEncoder().encode(cachedSnapshotItem.payload))

            #expect(result.drainedClientMutationIDs == ["cm_snapshot_check"])
            #expect(result.remainingSubmittedClientMutationIDs.isEmpty)
            #expect(content.queuedMutations.isEmpty)
            #expect(content.shoppingList?.item(id: "item_snapshot")?.checked == true)
            #expect(cachedItem.checked == true)
        }
    }

    @MainActor
    @Test("live store does not double apply drained structural recipe mutations after immediate online drain")
    func liveStoreDoesNotDoubleApplyDrainedStructuralRecipeMutationsAfterImmediateOnlineDrain() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_drain_structural", title: "Server Pasta")
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                shoppingItem: Self.sampleShoppingItem(id: "item_drain_structural", name: "salt")
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [
                        .result(.syncData(syncData)),
                        .result(.success(cursor: nil, tombstones: []))
                    ],
                    sends: [
                        .success(serverRevision: .updatedAt("2026-06-25T18:30:00.000Z")),
                        .success(serverRevision: .updatedAt("2026-06-25T18:31:00.000Z"))
                    ]
                )
            )

            await liveStore.bootstrap()
            let result = try await liveStore.queueMutations([
                try NativeQueuedMutation.recipeStepCreate(
                    recipeID: "recipe_drain_structural",
                    clientMutationID: "cm_editor_step_drain",
                    stepNum: 2,
                    stepTitle: "Serve",
                    description: "Serve warm.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: [1],
                    createdAt: Self.isoString(Self.now.addingTimeInterval(5))
                ),
                try NativeQueuedMutation.recipeIngredientAdd(
                    recipeID: "recipe_drain_structural",
                    stepID: "step_recipe_drain_structural",
                    clientMutationID: "cm_editor_ingredient_drain",
                    quantity: 1,
                    unit: "pinch",
                    name: "basil",
                    createdAt: Self.isoString(Self.now.addingTimeInterval(10))
                )
            ], drainImmediately: true)

            #expect(result.submittedClientMutationIDs == ["cm_editor_step_drain", "cm_editor_ingredient_drain"])
            #expect(result.drainedClientMutationIDs == ["cm_editor_step_drain", "cm_editor_ingredient_drain"])
            #expect(result.remainingSubmittedClientMutationIDs.isEmpty)
            #expect(result.submittedConflicts.isEmpty)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected drained structural editor mutations to return to liveSynced; got \(liveStore.bootstrapState)")
                return
            }
            let edited = try #require(content.recipe(id: "recipe_drain_structural"))
            #expect(edited.steps.count == 2)
            #expect(edited.steps.filter { $0.id == "step_local_cm_editor_step_drain" }.count == 1)
            let newStep = try #require(edited.steps.first { $0.id == "step_local_cm_editor_step_drain" })
            #expect(newStep.stepNum == 2)
            #expect(newStep.description == "Serve warm.")
            let baseStep = try #require(edited.steps.first { $0.id == "step_recipe_drain_structural" })
            #expect(baseStep.ingredients.map(\.id) == ["ingredient_local_cm_editor_ingredient_drain"])
            #expect(baseStep.ingredients.map(\.name) == ["basil"])
        }
    }

    @MainActor
    @Test("live store reports partial online recipe editor drains before the editor closes")
    func liveStoreReportsPartialOnlineRecipeEditorDrainsBeforeEditorCloses() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_partial_editor", title: "Server Pasta")
            let syncData = try Self.sampleSyncData(
                recipe: recipe,
                shoppingItem: Self.sampleShoppingItem(id: "item_partial", name: "salt")
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [
                        .result(.syncData(syncData)),
                        .result(.success(cursor: nil, tombstones: []))
                    ],
                    sends: [
                        .success(serverRevision: .updatedAt("2026-06-25T18:30:00.000Z")),
                        .conflict(kind: .validation, serverRevision: .updatedAt("server-partial"), message: "Recipe changed elsewhere.")
                    ]
                )
            )

            await liveStore.bootstrap()
            let result = try await liveStore.queueMutations([
                NativeQueuedMutation.recipeUpdate(
                    recipeID: "recipe_partial_editor",
                    clientMutationID: "cm_editor_save_partial",
                    title: "Partially Saved Pasta",
                    description: recipe.description,
                    servings: recipe.servings,
                    createdAt: Self.isoString(Self.now)
                ),
                try NativeQueuedMutation.recipeStepCreate(
                    recipeID: "recipe_partial_editor",
                    clientMutationID: "cm_editor_step_partial",
                    stepNum: 2,
                    stepTitle: "Serve",
                    description: "Serve warm.",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: [1],
                    createdAt: Self.isoString(Self.now.addingTimeInterval(5))
                )
            ], drainImmediately: true)

            #expect(result.submittedClientMutationIDs == ["cm_editor_save_partial", "cm_editor_step_partial"])
            #expect(result.drainedClientMutationIDs == ["cm_editor_save_partial"])
            #expect(result.remainingSubmittedClientMutationIDs == ["cm_editor_step_partial"])
            #expect(result.submittedConflicts == [
                NativeSyncConflict(
                    clientMutationID: "cm_editor_step_partial",
                    kind: .validation,
                    serverRevision: .updatedAt("server-partial"),
                    message: "Recipe changed elsewhere."
                )
            ])
            guard case .conflict(let content) = liveStore.bootstrapState else {
                Issue.record("Expected partial editor drain to surface conflict state; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipe(id: "recipe_partial_editor")?.title == "Partially Saved Pasta")
            #expect(content.queuedMutations.map(\.clientMutationID) == ["cm_editor_step_partial"])
            #expect(content.offlineIndicatorState.display == .conflict(recordID: "cm_editor_step_partial", mutationID: "cm_editor_step_partial"))
        }
    }

    @MainActor
    @Test("live store discards conflicted queued recipe mutation when discarding local edit")
    func liveStoreDiscardsConflictedQueuedRecipeMutationWhenDiscardingLocalEdit() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_conflict", title: "Server Pasta")
            let mutation = NativeQueuedMutation.recipeUpdate(
                recipeID: "recipe_conflict",
                clientMutationID: "cm_conflicted_recipe",
                title: "Local Pasta",
                description: recipe.description,
                servings: recipe.servings,
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [mutation]),
                cachedRecords: [
                    NativeSyncCachedRecord(
                        kind: .recipe,
                        resourceID: recipe.id,
                        payload: try Self.jsonValue(recipe),
                        serverRevision: .updatedAt(recipe.updatedAt)
                    )
                ]
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [.conflict(kind: .validation, serverRevision: nil, message: "Recipe changed elsewhere.")]
                )
            )

            await liveStore.bootstrap()
            guard case .conflict(let conflictContent) = liveStore.bootstrapState else {
                Issue.record("Expected conflict before discard; got \(liveStore.bootstrapState)")
                return
            }
            #expect(conflictContent.syncConflicts.map(\.clientMutationID) == ["cm_conflicted_recipe"])
            #expect(conflictContent.recipe(id: "recipe_conflict")?.title == "Local Pasta")

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_conflicted_recipe")
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
            guard case .offlineStale(let resolvedContent) = liveStore.bootstrapState else {
                Issue.record("Expected resolved conflict to return to stale restored content; got \(liveStore.bootstrapState)")
                return
            }
            #expect(resolvedContent.syncConflicts.isEmpty)
            #expect(resolvedContent.queuedMutations.isEmpty)
            #expect(resolvedContent.recipe(id: "recipe_conflict")?.title == "Server Pasta")
        }
    }

    @MainActor
    @Test("live store queue and conflict discard no-ops leave state untouched")
    func liveStoreQueueAndConflictDiscardNoopsLeaveStateUntouched() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_noop", title: "No-op Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: Self.sampleShoppingItem(id: "item_noop", name: "salt"))
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            )

            await liveStore.bootstrap()
            guard case .liveSynced(let syncedContent) = liveStore.bootstrapState else {
                Issue.record("Expected synced state before no-ops; got \(liveStore.bootstrapState)")
                return
            }

            let emptyQueueResult = try await liveStore.queueMutations([])
            #expect(emptyQueueResult == NativeQueuedMutationBatchResult(
                submittedClientMutationIDs: [],
                drainedClientMutationIDs: [],
                remainingSubmittedClientMutationIDs: [],
                submittedConflicts: []
            ))
            guard case .liveSynced(let afterEmptyQueue) = liveStore.bootstrapState else {
                Issue.record("Expected empty queue to preserve synced state; got \(liveStore.bootstrapState)")
                return
            }
            #expect(afterEmptyQueue.recipes == syncedContent.recipes)
            #expect(afterEmptyQueue.queuedMutations.isEmpty)

            try await liveStore.discardQueuedMutation(clientMutationID: " \n ")
            guard case .liveSynced(let afterBlankDiscard) = liveStore.bootstrapState else {
                Issue.record("Expected blank discard to preserve synced state; got \(liveStore.bootstrapState)")
                return
            }
            #expect(afterBlankDiscard.recipes == syncedContent.recipes)
            #expect(afterBlankDiscard.queuedMutations.isEmpty)

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_missing")
            guard case .liveSynced(let afterMissingDiscard) = liveStore.bootstrapState else {
                Issue.record("Expected missing discard to preserve synced state; got \(liveStore.bootstrapState)")
                return
            }
            #expect(afterMissingDiscard.recipes == syncedContent.recipes)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
        }
    }

    @MainActor
    @Test("live store discard keeps independent conflicts and removes dependent queued recipe work")
    func liveStoreDiscardKeepsIndependentConflictsAndRemovesDependentQueuedRecipeWork() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let firstRecipe = Self.sampleRecipe(id: "recipe_conflict_one", title: "Server One")
            let secondRecipe = Self.sampleRecipe(id: "recipe_conflict_two", title: "Server Two")
            let firstMutation = NativeQueuedMutation.recipeUpdate(
                recipeID: firstRecipe.id,
                clientMutationID: "cm_conflict_one",
                title: "Local One",
                description: firstRecipe.description,
                servings: firstRecipe.servings,
                createdAt: Self.isoString(Self.now)
            )
            let secondMutation = NativeQueuedMutation.recipeUpdate(
                recipeID: secondRecipe.id,
                clientMutationID: "cm_conflict_two",
                title: "Local Two",
                description: secondRecipe.description,
                servings: secondRecipe.servings,
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [firstMutation, secondMutation]),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .recipe, resourceID: firstRecipe.id, payload: try Self.jsonValue(firstRecipe), serverRevision: .updatedAt(firstRecipe.updatedAt)),
                    NativeSyncCachedRecord(kind: .recipe, resourceID: secondRecipe.id, payload: try Self.jsonValue(secondRecipe), serverRevision: .updatedAt(secondRecipe.updatedAt))
                ]
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [
                        .conflict(kind: .validation, serverRevision: .updatedAt("server-one"), message: "First recipe changed elsewhere."),
                        .conflict(kind: .validation, serverRevision: .updatedAt("server-two"), message: "Second recipe changed elsewhere.")
                    ]
                )
            )

            await liveStore.bootstrap()
            guard case .conflict(let conflictContent) = liveStore.bootstrapState else {
                Issue.record("Expected two recipe conflicts before discard; got \(liveStore.bootstrapState)")
                return
            }
            #expect(conflictContent.syncConflicts.map(\.clientMutationID) == ["cm_conflict_one", "cm_conflict_two"])

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_conflict_one")
            guard case .conflict(let remainingConflictContent) = liveStore.bootstrapState else {
                Issue.record("Expected the second conflict to remain visible; got \(liveStore.bootstrapState)")
                return
            }
            #expect(remainingConflictContent.syncConflicts.map(\.clientMutationID) == ["cm_conflict_two"])
            #expect(remainingConflictContent.offlineIndicatorState.display == .conflict(recordID: "cm_conflict_two", mutationID: "cm_conflict_two"))
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_conflict_chain", title: "Server Chain")
            let firstMutation = NativeQueuedMutation.recipeUpdate(
                recipeID: recipe.id,
                clientMutationID: "cm_chain_conflict",
                title: "Local Chain",
                description: recipe.description,
                servings: recipe.servings,
                createdAt: Self.isoString(Self.now)
            )
            let secondMutation = try NativeQueuedMutation.recipeStepCreate(
                recipeID: recipe.id,
                clientMutationID: "cm_chain_followup",
                stepNum: 2,
                stepTitle: "Serve",
                description: "Serve warm.",
                duration: nil,
                ingredients: [],
                outputStepNums: [1],
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [firstMutation, secondMutation]),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .recipe, resourceID: recipe.id, payload: try Self.jsonValue(recipe), serverRevision: .updatedAt(recipe.updatedAt))
                ]
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [.conflict(kind: .validation, serverRevision: nil, message: "Recipe changed elsewhere.")]
                )
            )

            await liveStore.bootstrap()
            guard case .conflict = liveStore.bootstrapState else {
                Issue.record("Expected chained conflict before discard; got \(liveStore.bootstrapState)")
                return
            }

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_chain_conflict")
            guard case .offlineStale(let staleContent) = liveStore.bootstrapState else {
                Issue.record("Expected dependent follow-up recipe work to be discarded with the conflict; got \(liveStore.bootstrapState)")
                return
            }
            #expect(staleContent.syncConflicts.isEmpty)
            #expect(staleContent.queuedMutations.isEmpty)
            #expect(staleContent.recipe(id: "recipe_conflict_chain")?.title == "Server Chain")
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_conflict_with_queued_work", title: "Server Queued")
            let conflictedRecipeMutation = NativeQueuedMutation.recipeUpdate(
                recipeID: recipe.id,
                clientMutationID: "cm_conflict_with_queued_work",
                title: "Local Queued",
                description: recipe.description,
                servings: recipe.servings,
                createdAt: Self.isoString(Self.now)
            )
            let profileMutation = NativeQueuedMutation.profileDisplayUpdate(
                email: "ari@example.com",
                username: "ari",
                clientMutationID: "cm_profile_retry_after_discard",
                createdAt: Self.isoString(Self.now.addingTimeInterval(1))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [conflictedRecipeMutation, profileMutation]),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .recipe, resourceID: recipe.id, payload: try Self.jsonValue(recipe), serverRevision: .updatedAt(recipe.updatedAt))
                ]
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [
                        .conflict(kind: .validation, serverRevision: nil, message: "Recipe changed elsewhere."),
                        .retry(afterSeconds: 120, message: "Profile save is waiting.")
                    ]
                )
            )

            await liveStore.bootstrap()
            guard case .conflict(let conflictContent) = liveStore.bootstrapState else {
                Issue.record("Expected conflict with unrelated queued work before discard; got \(liveStore.bootstrapState)")
                return
            }
            #expect(conflictContent.syncConflicts.map(\.clientMutationID) == ["cm_conflict_with_queued_work"])

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_conflict_with_queued_work")
            guard case .queuedWork(let queuedContent) = liveStore.bootstrapState else {
                Issue.record("Expected unrelated queued work to remain visible after discarding conflict; got \(liveStore.bootstrapState)")
                return
            }
            #expect(queuedContent.syncConflicts.isEmpty)
            #expect(queuedContent.queuedMutations.map(\.clientMutationID) == ["cm_profile_retry_after_discard"])
            #expect(queuedContent.offlineIndicatorState.display == .queuedWork(count: 1, oldestClientMutationID: "cm_profile_retry_after_discard"))
            #expect((try await syncStore.loadQueue()).mutations.map(\.clientMutationID) == ["cm_profile_retry_after_discard"])
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let createMutation = try NativeQueuedMutation.recipeCreate(
                clientMutationID: "cm_local_create_conflict",
                title: "Local Only Cake",
                description: nil,
                servings: nil,
                steps: [],
                createdAt: Self.isoString(Self.now)
            )
            let dependentMutation = NativeQueuedMutation.recipeUpdate(
                recipeID: "recipe_local_cm_local_create_conflict",
                clientMutationID: "cm_local_create_followup",
                title: "Local Only Cake Edited",
                description: nil,
                servings: nil,
                createdAt: Self.isoString(Self.now.addingTimeInterval(1))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [createMutation, dependentMutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(
                    bootstraps: [.result(.success(cursor: nil, tombstones: []))],
                    sends: [.conflict(kind: .validation, serverRevision: nil, message: "Recipe create changed elsewhere.")]
                )
            )

            await liveStore.bootstrap()
            guard case .conflict(let conflictContent) = liveStore.bootstrapState else {
                Issue.record("Expected local create conflict before discard; got \(liveStore.bootstrapState)")
                return
            }
            #expect(conflictContent.syncConflicts.map(\.clientMutationID) == ["cm_local_create_conflict"])
            #expect((try await syncStore.loadQueue()).mutations.map(\.clientMutationID) == ["cm_local_create_conflict", "cm_local_create_followup"])

            try await liveStore.discardQueuedMutation(clientMutationID: "cm_local_create_conflict")
            guard case .offlineStale(let staleContent) = liveStore.bootstrapState else {
                Issue.record("Expected local create and dependent edit to be discarded together; got \(liveStore.bootstrapState)")
                return
            }
            #expect(staleContent.syncConflicts.isEmpty)
            #expect(staleContent.queuedMutations.isEmpty)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)
        }
    }

    @MainActor
    @Test("live store executes recipe editor requests with auth-refreshing transport")
    func liveStoreExecutesRecipeEditorRequestsWithAuthRefreshingTransport() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_expired",
                refreshToken: "sj_refresh_original",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(-60),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_ari"
            ))
            let recipe = Self.sampleRecipe(id: "recipe_editor_execute", title: "Executed Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: Self.sampleShoppingItem(id: "item_execute", name: "pepper"))
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: syncTransport,
                recipeEditorAPITransport: { refresher in
                    RefreshingRecipeEditorAPITransport(
                        refresher: refresher,
                        expectedMethod: .patch,
                        expectedPathComponents: ["api", "v1", "recipes", "recipe_editor_execute"]
                    )
                }
            )
            let request = try RecipeWriteRequests.updateRecipe(
                id: "recipe_editor_execute",
                clientMutationID: "cm_editor_execute",
                title: "Executed Pasta",
                description: nil,
                servings: "4"
            )

            try await liveStore.executeRecipeEditorRequest(request)

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live sync after editor request execution; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.map(\.id) == ["recipe_editor_execute"])
            #expect(await syncTransport.capturedBearerTokens() == ["sj_access_refreshed"])
        }
    }

    @MainActor
    @Test("live store refreshes settings surface cache after sync")
    func liveStoreRefreshesSettingsSurfaceCacheAfterSync() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_settings_cache", title: "Settings Cache Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil, accountID: "chef_ari")
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            let settingsFetchRecorder = SettingsSurfaceFetchRecorder()
            let settingsAccount = SettingsAccountProfile(
                id: "chef_ari",
                email: "settings@example.com",
                username: "settingsari",
                photoURL: nil,
                hasPassword: true,
                linkedProviders: [],
                passkeys: []
            )
            let settingsData = SettingsSurfaceData(
                account: settingsAccount,
                notifications: SettingsNotificationPreferences.disabled,
                apiTokens: [],
                oauthConnections: [],
                environment: .production,
                offline: .available(snapshotCount: 1, lastRestoredAt: nil),
                source: .live(requestID: "req_settings_cache", validatedAt: Self.now)
            )
            let settingsRecords = [
                try Self.cacheRecord(
                    domain: .settings,
                    payload: .settings(account: settingsAccount),
                    accountID: "chef_ari"
                ),
                try Self.cacheRecord(
                    domain: .notificationPreferences,
                    payload: .notificationPreferenceState(.disabled),
                    accountID: "chef_ari"
                )
            ]
            let preexistingRecipeRecord = try Self.cacheRecord(
                domain: .recipeDetail(id: "recipe_settings_cache"),
                payload: .recipeDetail(id: "recipe_settings_cache", title: "Settings Cache Pasta"),
                accountID: "chef_ari"
            )
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [preexistingRecipeRecord],
                dismissedIndicators: []
            ))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: syncStore,
                transport: syncTransport,
                settingsSurfaceFetch: { accountID, environment, configuration, cache, _ in
                    await settingsFetchRecorder.record(
                        accountID: accountID,
                        environment: environment,
                        bearerToken: configuration.bearerToken,
                        existingRecordCount: cache.records.count
                    )
                    return SettingsSurfaceResult(data: settingsData, persistedRecords: settingsRecords)
                }
            )

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live sync with settings surface data; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.settingsSurfaceData?.account == settingsData.account)
            #expect(content.settingsSurfaceData?.notifications == settingsData.notifications)
            #expect(content.settingsSurfaceData?.offline == settingsData.offline)
            #expect(content.settingsSurfaceData?.source == .live(requestID: "req_settings_cache", validatedAt: Self.now))
            #expect(content.settingsSurfaceViewModel.profileDraft?.username == "settingsari")
            #expect(await settingsFetchRecorder.calls() == [
                SettingsSurfaceFetchCall(
                    accountID: "chef_ari",
                    environment: .production,
                    bearerToken: "sj_access_current",
                    existingRecordCount: 1
                )
            ])

            let fallback = try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            )
            let persisted = try cacheStore.loadOrRecover(fallback: fallback).value
            #expect(persisted.records.contains { $0.id == preexistingRecipeRecord.id })
            #expect(persisted.records.contains { $0.metadata.domain == .settings })
            #expect(persisted.records.contains { $0.metadata.domain == .notificationPreferences })
        }
    }

    @MainActor
    @Test("partial settings refresh renders account content and reports section telemetry")
    func partialSettingsRefreshRendersAccountContentAndReportsSectionTelemetry() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let syncData = NativeSyncData(
                freshness: NativeSyncFreshness(
                    accountID: "chef_ari",
                    environment: .production,
                    schemaVersion: 1,
                    sourceEndpoint: "/api/v1/me/sync",
                    generatedAt: Self.isoString(Self.now),
                    lastValidatedAt: Self.isoString(Self.now)
                ),
                entries: [],
                nextCursor: nil,
                hasMore: false
            )
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let telemetryRecorder = NativeTelemetryRecorder()
            let settingsAccount = SettingsAccountProfile(
                id: "chef_ari",
                email: "settings-partial@example.com",
                username: "settingspartial",
                photoURL: nil,
                hasPassword: true,
                linkedProviders: [SettingsLinkedProvider(provider: .apple, providerUsername: "ari@icloud.com")],
                passkeys: []
            )
            let partialFailure = SettingsSurfacePartialFailure(
                component: .notificationPreferences,
                diagnostic: SettingsSurfaceFailureDiagnostic(
                    errorType: "APITransportError",
                    requestID: "req_settings_notifications_partial",
                    status: 403,
                    apiCode: "insufficient_scope",
                    retry: "do_not_retry"
                )
            )
            let metadataFreeFailure = SettingsSurfacePartialFailure(
                component: .apiTokens,
                diagnostic: SettingsSurfaceFailureDiagnostic(
                    errorType: "SettingsSurfaceProbeError",
                    requestID: nil,
                    status: nil,
                    apiCode: nil,
                    retry: nil
                )
            )
            let settingsData = SettingsSurfaceData(
                account: settingsAccount,
                notifications: nil,
                apiTokens: [],
                oauthConnections: [],
                environment: .production,
                offline: .available(snapshotCount: 1, lastRestoredAt: nil),
                source: .live(requestID: "req_settings_partial", validatedAt: Self.now),
                partialFailures: [partialFailure, metadataFreeFailure]
            )
            let settingsRecords = [
                try Self.cacheRecord(
                    domain: .settings,
                    payload: .settings(account: settingsAccount),
                    accountID: "chef_ari"
                )
            ]
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData)),
                settingsSurfaceFetch: { _, _, _, _, _ in
                    SettingsSurfaceResult(data: settingsData, persistedRecords: settingsRecords)
                },
                nativeTelemetryReport: { event, configuration in
                    await telemetryRecorder.record(event, configuration: configuration)
                },
                nativeTelemetryMetadata: NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "13")
            )

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live sync with partial settings content; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.isEmpty)
            #expect(content.settingsSurfaceData?.account == settingsAccount)
            #expect(content.settingsSurfaceData?.partialFailures == [partialFailure, metadataFreeFailure])
            #expect(content.settingsSurfaceViewModel.profileDraft?.username == "settingspartial")
            #expect(content.settingsSurfaceViewModel.partialFailureSummary == "Some account settings could not load: Notifications, API tokens.")
            #expect(content.settingsSurfaceViewModel.offlineIndicator.display == .syncFailure(errorID: "settings.notification_preferences", retryAfter: nil))

            let telemetryEvents = await telemetryRecorder.recordedEvents()
            let telemetry = try #require(telemetryEvents.first)
            #expect(telemetry.name == .settingsRefreshFailed)
            #expect(telemetry.stage == "settings.notification_preferences")
            #expect(telemetry.environment == "production")
            #expect(telemetry.metadata == NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "13"))
            #expect(telemetry.errorType == "APITransportError")
            #expect(telemetry.requestID == "req_settings_notifications_partial")
            #expect(telemetry.status == 403)
            #expect(telemetry.apiCode == "insufficient_scope")
            #expect(telemetry.retry == "do_not_retry")
            #expect(telemetry.accountBound == true)
            #expect(telemetry.hasRenderableCacheContent == false)
            #expect(telemetry.recipes == 0)
            let metadataFreeTelemetry = try #require(telemetryEvents.last)
            #expect(metadataFreeTelemetry.stage == "settings.api_tokens")
            #expect(metadataFreeTelemetry.requestID == nil)
            #expect(metadataFreeTelemetry.status == nil)
            #expect(metadataFreeTelemetry.apiCode == nil)
            #expect(metadataFreeTelemetry.retry == nil)
            #expect(await telemetryRecorder.recordedConfigurations().first?.bearerToken == "sj_access_current")
        }
    }

    @MainActor
    @Test("settings token-scope failure keeps kitchen content but marks sync failed and reports telemetry")
    func settingsTokenScopeFailureKeepsKitchenContentButMarksSyncFailedAndReportsTelemetry() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_settings_scope", title: "Scope-Safe Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil, accountID: "chef_ari")
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let telemetryRecorder = NativeTelemetryRecorder()
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData)),
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw APITransportError(
                        kind: .apiError,
                        requestID: "req_settings_tokens_scope",
                        statusCode: 403,
                        apiError: APIError(
                            requestID: "req_settings_tokens_scope",
                            code: "insufficient_scope",
                            message: "Missing required scope: tokens:read",
                            status: 403
                        ),
                        retryDecision: .doNotRetry
                    )
                },
                nativeTelemetryReport: { event, configuration in
                    await telemetryRecorder.record(event, configuration: configuration)
                },
                nativeTelemetryMetadata: NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "12")
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, let message) = liveStore.bootstrapState else {
                Issue.record("Expected settings refresh failure to mark syncFailed; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.map(\.title) == ["Scope-Safe Pasta"])
            #expect(content.settingsSurfaceData == nil)
            #expect(message.contains("Support code req_settings_tokens_scope."))
            #expect(message.contains("Reason insufficient_scope."))
            #expect(message.contains("HTTP 403."))
            guard case .syncFailure(let errorID, let retryAfter) = content.offlineIndicatorState.display else {
                Issue.record("Expected a settings sync failure indicator; got \(content.offlineIndicatorState.display)")
                return
            }
            #expect(errorID == "settings")
            #expect(retryAfter == nil)

            let telemetryEvents = await telemetryRecorder.recordedEvents()
            let telemetry = try #require(telemetryEvents.first)
            #expect(telemetry.name == .settingsRefreshFailed)
            #expect(telemetry.stage == "settings")
            #expect(telemetry.environment == "production")
            #expect(telemetry.metadata == NativeTelemetryAppMetadata(platform: "ios", appVersion: "1.0", buildNumber: "12"))
            #expect(telemetry.errorType == "APITransportError")
            #expect(telemetry.requestID == "req_settings_tokens_scope")
            #expect(telemetry.status == 403)
            #expect(telemetry.apiCode == "insufficient_scope")
            #expect(telemetry.retry == "do_not_retry")
            #expect(telemetry.accountBound == true)
            #expect(telemetry.hasRenderableCacheContent == true)
            #expect(telemetry.recipes == 1)
            #expect(telemetry.shoppingItems == 0)
            let configurations = await telemetryRecorder.recordedConfigurations()
            #expect(configurations.first?.bearerToken == "sj_access_current")
        }
    }

    @MainActor
    @Test("settings generic refresh failure keeps kitchen content but marks sync failed")
    func settingsGenericRefreshFailureKeepsKitchenContentButMarksSyncFailed() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_settings_generic", title: "Still Loads Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil, accountID: "chef_ari")
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData)),
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw SettingsRefreshProbeError()
                }
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, let message) = liveStore.bootstrapState else {
                Issue.record("Expected generic settings refresh failure to mark syncFailed; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.map(\.title) == ["Still Loads Pasta"])
            #expect(content.settingsSurfaceData == nil)
            #expect(message.contains("SettingsRefreshProbeError"))
            guard case .syncFailure(let errorID, let retryAfter) = content.offlineIndicatorState.display else {
                Issue.record("Expected a settings sync failure indicator; got \(content.offlineIndicatorState.display)")
                return
            }
            #expect(errorID == "settings")
            #expect(retryAfter == nil)
        }
    }

    @MainActor
    @Test("settings transport refresh failure without metadata keeps content and reports retry")
    func settingsTransportRefreshFailureWithoutMetadataKeepsContentAndReportsRetry() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_settings_transport_nil", title: "Metadata-Free Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil, accountID: "chef_ari")
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData)),
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw APITransportError(
                        kind: .networkFailure,
                        requestID: nil,
                        statusCode: nil,
                        apiError: nil,
                        retryDecision: .retrySameRequest(afterSeconds: nil)
                    )
                }
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, _) = liveStore.bootstrapState else {
                Issue.record("Expected metadata-free settings refresh failure to mark syncFailed; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.map(\.title) == ["Metadata-Free Pasta"])
            #expect(content.settingsSurfaceData == nil)
            guard case .syncFailure(let errorID, let retryAfter) = content.offlineIndicatorState.display else {
                Issue.record("Expected a settings sync failure indicator; got \(content.offlineIndicatorState.display)")
                return
            }
            #expect(errorID == "settings")
            #expect(retryAfter == nil)
        }
    }

    @Test("native settings scope helper handles signed out authenticated and refresh-required sessions")
    func nativeSettingsScopeHelperHandlesSessionStates() throws {
        let session = try AuthSession(
            clientID: "client_live",
            accessToken: "sj_access_current",
            refreshToken: "sj_refresh_current",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: "\(NativeAuthSession.defaultScope) tokens:read tokens:write",
            accountID: "chef_ari"
        )

        #expect(nativeGrantedScopes(for: .signedOut).isEmpty)
        #expect(nativeGrantedScopes(for: .authenticated(session)) == Set(session.scope.split(separator: " ").map(String.init)))
        #expect(nativeGrantedScopes(for: .refreshRequired(session)) == Set(session.scope.split(separator: " ").map(String.init)))
    }

    @MainActor
    @Test("restore cache only launch mode renders signed-in settings without live fetch")
    func restoreCacheOnlyLaunchModeRendersSignedInSettingsWithoutLiveFetch() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let accountID = "chef_settings_capture"
            let vault = try await Self.signedInVault(accountID: accountID)
            let settingsAccount = SettingsAccountProfile(
                id: accountID,
                email: "settings-capture@spoonjoy.app",
                username: "settingscapture",
                photoURL: nil,
                hasPassword: true,
                linkedProviders: [SettingsLinkedProvider(provider: .github, providerUsername: "settingscapture")],
                passkeys: []
            )
            let records = [
                try Self.cacheRecord(
                    domain: .settings,
                    payload: .settings(account: settingsAccount),
                    accountID: accountID
                ),
                try Self.cacheRecord(
                    domain: .notificationPreferences,
                    payload: .notificationPreferenceState(SettingsNotificationPreferences(
                        notifySpoonOnMyRecipe: true,
                        notifyForkOfMyRecipe: false,
                        notifyCookbookSaveOfMine: true,
                        notifyFellowChefOriginCook: false
                    )),
                    accountID: accountID
                ),
                try Self.cacheRecord(
                    domain: .tokenMetadata,
                    payload: .tokenMetadata(credentials: [
                        NativeTokenMetadata(
                            id: "credential_capture",
                            name: "Capture validation token",
                            tokenPrefix: "sj_live_1234",
                            scopes: ["recipes:read", "shopping_list:read"],
                            createdAt: Self.isoString(Self.now),
                            updatedAt: Self.isoString(Self.now)
                        )
                    ]),
                    accountID: accountID
                ),
                try Self.cacheRecord(
                    domain: .connectionStatus,
                    payload: .connectionStatus(connections: [
                        NativeConnectionStatus(
                            id: "connection_capture",
                            provider: "oauth",
                            status: .connected,
                            clientID: "client_capture",
                            clientName: "Capture OAuth App",
                            resource: nil,
                            scopes: ["account:read"],
                            createdAt: Self.isoString(Self.now),
                            refreshTokenCount: 1,
                            accessTokenCount: 1
                        )
                    ]),
                    accountID: accountID
                )
            ]
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: accountID,
                environment: .production,
                createdAt: Self.now,
                records: records,
                dismissedIndicators: []
            ))
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(NativeAppSnapshot(
                schemaVersion: 1,
                accountID: accountID,
                environment: .production,
                hasCompletedFirstRun: true,
                cookProgressByRecipeID: [:],
                shoppingList: nil,
                captureDraft: nil,
                pendingMutations: MutationQueue(),
                lastOpenedRoute: "settings",
                savedAt: Self.isoString(Self.now)
            ))
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(accountID: accountID, environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
                transport: syncTransport,
                appStateStoreProvider: { appStateStore },
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                bootstrapMode: .restoreCacheOnly
            )

            await liveStore.bootstrap()

            guard case .offlineStale(let content) = liveStore.bootstrapState else {
                Issue.record("Expected restore-cache-only launch to render offline signed-in cache; got \(liveStore.bootstrapState)")
                return
            }
            #expect(liveStore.restoredRoute == .settings)
            #expect(content.settingsSurfaceViewModel.sections.map(\.id) == [.profile, .security, .notifications, .apiTokens, .connections, .environment, .offline])
            #expect(content.settingsSurfaceViewModel.profileDraft?.username == "settingscapture")
            #expect(content.settingsSurfaceViewModel.apiTokenRows.map(\.name) == ["Capture validation token"])
            #expect(content.settingsSurfaceViewModel.oauthConnectionRows.map(\.clientName) == ["Capture OAuth App"])
            #expect(content.settingsSurfaceViewModel.primaryAuthAction == nil)
            #expect(content.settingsSurfaceViewModel.connectivity == .offline)
            #expect(await syncTransport.capturedBearerTokens().isEmpty)
        }
    }

    @MainActor
    @Test("restore cache only launch mode preserves capture import retry and blocker severity")
    func restoreCacheOnlyLaunchModePreservesCaptureImportRetryAndBlockerSeverity() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let accountID = "chef_capture_restore"
            let draft = try CaptureDraft.importURL(
                id: "draft_restore_capture",
                url: URL(string: "https://example.com/restore-capture")!,
                createdAt: Self.isoString(Self.now)
            )
            let retryMutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_restore_capture_import",
                createdAt: Self.isoString(Self.now)
            )

            let queuedDirectory = directory.appendingPathComponent("queued", isDirectory: true)
            try FileManager.default.createDirectory(at: queuedDirectory, withIntermediateDirectories: true)
            let queuedAppStateStore = NativeAppStateStore(fileURL: queuedDirectory.appendingPathComponent("native-app-state.json"))
            try queuedAppStateStore.save(NativeAppSnapshot(
                schemaVersion: 1,
                accountID: accountID,
                environment: .production,
                hasCompletedFirstRun: true,
                cookProgressByRecipeID: [:],
                shoppingList: nil,
                captureDraft: draft,
                pendingMutations: MutationQueue(),
                lastOpenedRoute: "capture",
                savedAt: Self.isoString(Self.now)
            ))
            let queuedStore = Self.liveStore(
                directory: queuedDirectory,
                vault: try await Self.signedInVault(accountID: accountID),
                syncStore: InMemoryNativeSyncStore(
                    accountID: accountID,
                    environment: .production,
                    checkpoint: nil,
                    queue: try NativeMutationQueue(mutations: [retryMutation])
                ),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: [])),
                appStateStoreProvider: { queuedAppStateStore },
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                bootstrapMode: .restoreCacheOnly
            )

            await queuedStore.bootstrap()

            guard case .queuedWork(let queuedContent) = queuedStore.bootstrapState else {
                Issue.record("Expected restore-cache-only launch to preserve queued capture import; got \(queuedStore.bootstrapState)")
                return
            }
            #expect(queuedStore.restoredRoute == .capture)
            #expect(queuedContent.captureDraft == draft)
            #expect(queuedContent.queuedMutations.map(\.clientMutationID) == ["cm_restore_capture_import"])
            #expect(queuedContent.offlineIndicatorState.display == .queuedWork(count: 1, oldestClientMutationID: "cm_restore_capture_import"))

            let blockerDirectory = directory.appendingPathComponent("blocker", isDirectory: true)
            try FileManager.default.createDirectory(at: blockerDirectory, withIntermediateDirectories: true)
            let blockerAppStateStore = NativeAppStateStore(fileURL: blockerDirectory.appendingPathComponent("native-app-state.json"))
            try blockerAppStateStore.save(NativeAppSnapshot(
                schemaVersion: 1,
                accountID: accountID,
                environment: .production,
                hasCompletedFirstRun: true,
                cookProgressByRecipeID: [:],
                shoppingList: nil,
                captureDraft: draft,
                captureImportProviderBlocker: "recipe-import",
                pendingMutations: MutationQueue(),
                lastOpenedRoute: "capture",
                savedAt: Self.isoString(Self.now)
            ))
            let blockerStore = Self.liveStore(
                directory: blockerDirectory,
                vault: try await Self.signedInVault(accountID: accountID),
                syncStore: InMemoryNativeSyncStore(accountID: accountID, environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: [])),
                appStateStoreProvider: { blockerAppStateStore },
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                bootstrapMode: .restoreCacheOnly
            )

            await blockerStore.bootstrap()

            guard case .blocker(let blockerContent) = blockerStore.bootstrapState else {
                Issue.record("Expected restore-cache-only launch to preserve capture import blocker; got \(blockerStore.bootstrapState)")
                return
            }
            #expect(blockerStore.restoredRoute == .capture)
            #expect(blockerContent.captureDraft == draft)
            #expect(blockerContent.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "recipe-import")))
        }
    }

    @MainActor
    @Test("restore cache only launch mode preserves expired signed-in cache without refreshing")
    func restoreCacheOnlyLaunchModePreservesExpiredSignedInCacheWithoutRefreshing() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let accountID = "chef_settings_capture"
            let expiredSession = try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_expired_cache",
                refreshToken: "sj_refresh_expired_cache",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(-60),
                scope: NativeAuthSession.defaultScope,
                accountID: accountID
            )
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(expiredSession)
            let settingsAccount = SettingsAccountProfile(
                id: accountID,
                email: "expired-cache@spoonjoy.app",
                username: "expiredcache",
                photoURL: nil,
                hasPassword: true,
                linkedProviders: [],
                passkeys: []
            )
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: accountID,
                environment: .production,
                createdAt: Self.now,
                records: [
                    try Self.cacheRecord(
                        domain: .settings,
                        payload: .settings(account: settingsAccount),
                        accountID: accountID
                    )
                ],
                dismissedIndicators: []
            ))
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(NativeAppSnapshot(
                schemaVersion: 1,
                accountID: accountID,
                environment: .production,
                hasCompletedFirstRun: true,
                cookProgressByRecipeID: [:],
                shoppingList: nil,
                captureDraft: nil,
                pendingMutations: MutationQueue(),
                lastOpenedRoute: "settings",
                savedAt: Self.isoString(Self.now)
            ))
            let syncStore = InMemoryNativeSyncStore(accountID: accountID, environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let syncEngine = NativeSyncEngine(store: syncStore, transport: syncTransport, clock: { Self.now })
            let configuration = APIClientConfiguration.spoonjoyProduction
            let authRepository = NativeAuthSessionRepository(
                vault: vault,
                clientName: "Spoonjoy Apple Tests",
                registerClient: { _, _ in "client_live" },
                exchangeCode: { _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                refresh: { _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                revoke: { _, _ in },
                now: { Self.now }
            )
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: authRepository,
                cacheStore: cacheStore,
                syncStore: syncStore,
                syncEngine: syncEngine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: syncEngine, configuration: configuration),
                appStateStoreProvider: { appStateStore },
                configuration: configuration,
                cacheEnvironment: .production,
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                bootstrapMode: .restoreCacheOnly,
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            guard case .offlineStale(let content) = liveStore.bootstrapState else {
                Issue.record("Expected restore-cache-only launch to preserve expired signed-in cache; got \(liveStore.bootstrapState)")
                return
            }
            #expect(liveStore.restoredRoute == .settings)
            #expect(content.authSessionState == .refreshRequired(expiredSession))
            #expect(content.configuration.bearerToken == "sj_access_expired_cache")
            #expect(content.settingsSurfaceViewModel.profileDraft?.username == "expiredcache")
            #expect(content.settingsSurfaceViewModel.primaryAuthAction == nil)
            #expect(await syncTransport.capturedBearerTokens().isEmpty)
        }
    }

    @MainActor
    @Test("restore cache only launch mode preserves signed-out shell without live fetch")
    func restoreCacheOnlyLaunchModePreservesSignedOutShellWithoutLiveFetch() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            try appStateStore.save(NativeAppSnapshot(
                schemaVersion: 1,
                accountID: "signed-out",
                environment: .production,
                hasCompletedFirstRun: true,
                cookProgressByRecipeID: [:],
                shoppingList: nil,
                captureDraft: nil,
                pendingMutations: MutationQueue(),
                lastOpenedRoute: "settings",
                savedAt: Self.isoString(Self.now)
            ))
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(accountID: "chef_untrusted", environment: .production, checkpoint: nil, queue: NativeMutationQueue()),
                transport: syncTransport,
                appStateStoreProvider: { appStateStore },
                settingsSurfaceFetch: { _, _, _, _, _ in
                    throw NativeLiveStoreTestError.unexpectedRequest
                },
                bootstrapMode: .restoreCacheOnly
            )

            await liveStore.bootstrap()

            guard case .signedOut(let content) = liveStore.bootstrapState else {
                Issue.record("Expected restore-cache-only launch to preserve signed-out shell; got \(liveStore.bootstrapState)")
                return
            }
            #expect(liveStore.restoredRoute == .settings)
            #expect(content.authSessionState == .signedOut)
            #expect(content.offlineIndicatorState.display == .offline)
            #expect(content.settingsSurfaceViewModel.profileDraft == nil)
            #expect(content.settingsSurfaceViewModel.primaryAuthAction != nil)
            #expect(await syncTransport.capturedBearerTokens().isEmpty)
        }
    }

    @MainActor
    @Test("live store executes settings action requests and captures created tokens")
    func liveStoreExecutesSettingsActionRequestsAndCapturesCreatedTokens() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            try await vault.saveClientID("client_live")
            try await vault.saveSession(try AuthSession(
                clientID: "client_live",
                accessToken: "sj_access_expired",
                refreshToken: "sj_refresh_original",
                tokenType: "Bearer",
                expiresAt: Self.now.addingTimeInterval(-60),
                scope: NativeAuthSession.defaultScope,
                accountID: "chef_ari"
            ))
            let recipe = Self.sampleRecipe(id: "recipe_settings_execute", title: "Settings Execute Pasta")
            let syncData = try Self.sampleSyncData(recipe: recipe, shoppingItem: nil, accountID: "chef_ari")
            let syncStore = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .production, checkpoint: nil, queue: NativeMutationQueue())
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let recorder = SettingsActionAPITransportRecorder()
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: syncTransport,
                recipeEditorAPITransport: { refresher in
                    RecordingSettingsActionAPITransport(refresher: refresher, recorder: recorder)
                }
            )

            let refreshOnly = try await liveStore.executeSettingsActionRequest(
                PrivateAccountRequests.updateProfile(email: "settings@example.com", username: "settingsari"),
                responseHandling: .refreshOnly
            )
            let tokenOutcome = try await liveStore.executeSettingsActionRequest(
                TokenCredentialRequests.createToken(name: "Kitchen Token", scopes: ["recipes:read"]),
                responseHandling: .captureCreatedAPIToken
            )

            #expect(refreshOnly == nil)
            #expect(tokenOutcome == .createdAPIToken(SettingsCreatedAPIToken(
                token: "sj_created_settings",
                credential: SettingsAPITokenSummary(
                    id: "cred_settings_created",
                    name: "Kitchen Token",
                    tokenPrefix: "sj_created",
                    scopes: ["recipes:read"],
                    createdAt: "2026-06-28T00:00:00.000Z",
                    updatedAt: "2026-06-28T00:00:00.000Z",
                    lastUsedAt: nil,
                    revokedAt: nil,
                    expiresAt: nil
                )
            )))
            #expect(await recorder.requests() == [
                SettingsActionAPIRequest(method: .patch, path: "/api/v1/me", bearerToken: "sj_access_refreshed"),
                SettingsActionAPIRequest(method: .post, path: "/api/v1/tokens", bearerToken: "sj_access_refreshed")
            ])
            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected settings action execution to refresh live synced content; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.recipes.map(\.id) == ["recipe_settings_execute"])
        }
    }

    @MainActor
    @Test("live store performs settings session operations and returns to signed out shell")
    func liveStorePerformsSettingsSessionOperationsAndReturnsToSignedOutShell() async throws {
        for operation in [SettingsSessionOperation.logout, .revokeAndLogout] {
            try await withTemporaryLiveStoreDirectory { directory in
                let vault = try await Self.signedInVault(accountID: "chef_ari")
                let syncStore = InMemoryNativeSyncStore(
                    accountID: "chef_ari",
                    environment: .production,
                    checkpoint: nil,
                    queue: NativeMutationQueue()
                )
                let liveStore = Self.liveStore(
                    directory: directory,
                    vault: vault,
                    syncStore: syncStore,
                    transport: CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
                )

                try await liveStore.performSettingsSessionOperation(operation)

                #expect((try await liveStore.authSessionRepository.restoreState()) == .signedOut)
                guard case .signedOut(let content) = liveStore.bootstrapState else {
                    Issue.record("Expected \(operation) to bootstrap signed out; got \(liveStore.bootstrapState)")
                    return
                }
                #expect(content.authSessionState == .signedOut)
                #expect(content.settingsViewModel.authSessionState == .signedOut)
            }
        }
    }

    @MainActor
    @Test("live store purges shopping and spoon entity indexes on logout and account switch")
    func liveStorePurgesShoppingAndSpoonEntityIndexesOnLogoutAndAccountSwitch() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "client_live")
            let shoppingItem = Self.sampleShoppingItem(id: "item_logout_purge", name: "logout lemons")
            let purgeRecorder = CapturingShoppingEntityIndexPurge()
            let spoonPurgeRecorder = CapturingSpoonEntityIndexPurge()
            let recipeCookbookPurgeRecorder = CapturingRecipeCookbookEntityIndexPurge()
            let chef = ChefSummary(id: "client_live", username: "ari")
            let activeSpoon = RecipeDetailRecentSpoon(
                id: "spoon_logout_active",
                chefID: chef.id,
                recipeID: "recipe_logout_purge",
                cookedAt: Self.isoString(Self.now),
                photoURL: nil,
                note: "Active logout spoon.",
                nextTime: nil,
                deletedAt: nil,
                createdAt: Self.isoString(Self.now),
                updatedAt: Self.isoString(Self.now),
                chef: chef
            )
            let deletedSpoon = RecipeDetailRecentSpoon(
                id: "spoon_logout_deleted",
                chefID: chef.id,
                recipeID: "recipe_logout_purge",
                cookedAt: Self.isoString(Self.now),
                photoURL: nil,
                note: "Deleted logout spoon.",
                nextTime: nil,
                deletedAt: Self.isoString(Self.now),
                createdAt: Self.isoString(Self.now),
                updatedAt: Self.isoString(Self.now),
                chef: chef
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: Self.sampleRecipe(
                        id: "recipe_logout_purge",
                        title: "Logout Purge",
                        recentSpoons: [activeSpoon, deletedSpoon]
                    ),
                    cookbook: Self.sampleCookbook(id: "cookbook_logout_purge", title: "Logout Suppers"),
                    shoppingItem: shoppingItem
                ))),
                shoppingEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                },
                spoonEntityIndexPurge: { request in
                    await spoonPurgeRecorder.purge(request)
                },
                recipeCookbookEntityIndexPurge: { request in
                    await recipeCookbookPurgeRecorder.purge(request)
                }
            )

            await liveStore.bootstrap()
            let manualShoppingIdentifier = SpotlightIndexPlan.shoppingListItemUniqueIdentifier(
                itemID: "item_manual_purge",
                scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
            )
            let manualShoppingDomain = SpotlightIndexPlan.shoppingListItemDomainIdentifier(
                scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
            )
            await liveStore.purgeShoppingEntityIdentifiers([], domainIdentifiers: [])
            await liveStore.purgeShoppingEntityIdentifiers(
                [manualShoppingIdentifier, manualShoppingIdentifier],
                domainIdentifiers: [manualShoppingDomain, manualShoppingDomain]
            )
            await liveStore.purgeRecipeCookbookEntityIdentifiers([], domainIdentifiers: [])
            try await liveStore.performSettingsSessionOperation(.logout)
            await liveStore.purgeSpoonEntityIdentifiers([], domainIdentifiers: [])

            #expect(await purgeRecorder.requests() == [
                NativeShoppingEntityIndexPurgeRequest(
                    identifiers: [
                        manualShoppingIdentifier
                    ],
                    domainIdentifiers: [
                        manualShoppingDomain
                    ],
                    accountID: "client_live",
                    environment: .production
                ),
                NativeShoppingEntityIndexPurgeRequest(
                    identifiers: [
                        SpotlightIndexPlan.shoppingListItemUniqueIdentifier(
                            itemID: "item_logout_purge",
                            scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                        )
                    ],
                    domainIdentifiers: [
                        SpotlightIndexPlan.shoppingListItemDomainIdentifier(
                            scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                        )
                    ],
                    accountID: "client_live",
                    environment: .production
                )
            ])
            let spoonRequests = await spoonPurgeRecorder.requests()
            #expect(spoonRequests.contains(NativeSpoonEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.spoonUniqueIdentifier(
                        spoonID: activeSpoon.id,
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.spoonDomainIdentifier(
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                accountID: "client_live",
                environment: .production
            )))
            #expect(spoonRequests.allSatisfy { $0.accountID == "client_live" && $0.environment == .production })
            let recipeCookbookScope = SpotlightIndexScope(accountID: "client_live", environment: .production)
            #expect(await recipeCookbookPurgeRecorder.requests() == [
                NativeRecipeCookbookEntityIndexPurgeRequest(
                    identifiers: [
                        SpotlightIndexPlan.recipeUniqueIdentifier(recipeID: "recipe_logout_purge", scope: recipeCookbookScope),
                        SpotlightIndexPlan.cookbookUniqueIdentifier(cookbookID: "cookbook_logout_purge", scope: recipeCookbookScope)
                    ],
                    domainIdentifiers: [
                        SpotlightIndexPlan.recipeDomainIdentifier(scope: recipeCookbookScope),
                        SpotlightIndexPlan.cookbookDomainIdentifier(scope: recipeCookbookScope)
                    ],
                    accountID: "client_live",
                    environment: .production
                )
            ])
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "client_live")
            let previousItem = Self.sampleShoppingItem(id: "item_previous_purge", name: "previous carrots")
            let purgeRecorder = CapturingShoppingEntityIndexPurge()
            let recipeCookbookPurgeRecorder = CapturingRecipeCookbookEntityIndexPurge()
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_previous",
                environment: .production,
                createdAt: Self.now,
                records: [
                    try Self.cacheRecord(
                        domain: .recipeCatalog,
                        payload: .recipeCatalog(recipeIDs: ["recipe_previous_catalog"]),
                        accountID: "chef_previous"
                    ),
                    try Self.cacheRecord(
                        domain: .cookbookList,
                        payload: .cookbookList(cookbookIDs: ["cookbook_previous_list"]),
                        accountID: "chef_previous"
                    )
                ],
                dismissedIndicators: []
            ))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(
                    accountID: "chef_previous",
                    environment: .production,
                    checkpoint: nil,
                    queue: NativeMutationQueue(),
                    cachedRecords: [
                        NativeSyncCachedRecord(
                            kind: .shoppingItem,
                            resourceID: previousItem.id,
                            payload: try Self.jsonValue(previousItem),
                            serverRevision: .updatedAt(previousItem.updatedAt)
                        )
                    ]
                ),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: Self.sampleRecipe(id: "recipe_account_switch_purge", title: "Account Switch Purge"),
                    shoppingItem: nil
                ))),
                shoppingEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                },
                recipeCookbookEntityIndexPurge: { request in
                    await recipeCookbookPurgeRecorder.purge(request)
                }
            )

            await liveStore.bootstrap()

            let requests = await purgeRecorder.requests()
            #expect(requests.contains(NativeShoppingEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.shoppingListItemUniqueIdentifier(
                        itemID: "item_previous_purge",
                        scope: SpotlightIndexScope(accountID: "chef_previous", environment: .production)
                    )
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.shoppingListItemDomainIdentifier(
                        scope: SpotlightIndexScope(accountID: "chef_previous", environment: .production)
                    )
                ],
                accountID: "chef_previous",
                environment: .production
            )))
            #expect(requests.allSatisfy { $0.accountID == "chef_previous" && $0.environment == .production })
            let previousRecipeCookbookScope = SpotlightIndexScope(accountID: "chef_previous", environment: .production)
            let recipeCookbookRequests = await recipeCookbookPurgeRecorder.requests()
            #expect(recipeCookbookRequests.contains(NativeRecipeCookbookEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.recipeUniqueIdentifier(recipeID: "recipe_previous_catalog", scope: previousRecipeCookbookScope),
                    SpotlightIndexPlan.cookbookUniqueIdentifier(cookbookID: "cookbook_previous_list", scope: previousRecipeCookbookScope)
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.recipeDomainIdentifier(scope: previousRecipeCookbookScope),
                    SpotlightIndexPlan.cookbookDomainIdentifier(scope: previousRecipeCookbookScope)
                ],
                accountID: "chef_previous",
                environment: .production
            )))
            #expect(recipeCookbookRequests.allSatisfy { $0.accountID == "chef_previous" && $0.environment == .production })
        }
    }

    @MainActor
    @Test("live store purges capture draft entity indexes on logout")
    func liveStorePurgesCaptureDraftEntityIndexesOnLogout() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: nil)
            let captureDraft = try CaptureDraft.localText(
                id: "draft_logout_purge",
                rawText: "logout capture draft",
                createdAt: Self.isoString(Self.now)
            )
            let purgeRecorder = CapturingCaptureDraftEntityIndexPurge()
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: Self.sampleRecipe(id: "recipe_capture_logout_purge", title: "Capture Logout Purge"),
                    shoppingItem: nil
                ))),
                captureDraftEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                }
            )

            await liveStore.bootstrap()
            liveStore.recordCaptureDraft(captureDraft)
            try await liveStore.performSettingsSessionOperation(.logout)

            let expectedCacheDeleteRequest = NativeCaptureDraftEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.captureDraftUniqueIdentifier(
                        draftID: captureDraft.id,
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                domainIdentifiers: [],
                accountID: "client_live",
                environment: .production
            )
            let expectedLogoutRequest = NativeCaptureDraftEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.captureDraftUniqueIdentifier(
                        draftID: captureDraft.id,
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.captureDraftDomainIdentifier(
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                accountID: "client_live",
                environment: .production
            )
            let requests = await purgeRecorder.requests()
            #expect(requests.count == 2)
            #expect(requests.contains(expectedCacheDeleteRequest))
            #expect(requests.contains(expectedLogoutRequest))
        }
    }

    @MainActor
    @Test("live store consumes capture draft entity purge requests from sync reports")
    func liveStoreConsumesCaptureDraftEntityPurgeRequestsFromSyncReports() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "client_live")
            let purgeRecorder = CapturingCaptureDraftEntityIndexPurge()
            let syncStore = InMemoryNativeSyncStore(
                accountID: "client_live",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
            let purgeRequest = NativeCaptureDraftEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.captureDraftUniqueIdentifier(
                        draftID: "draft_report_purge",
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.captureDraftDomainIdentifier(
                        scope: SpotlightIndexScope(accountID: "client_live", environment: .production)
                    )
                ],
                accountID: "client_live",
                environment: .production
            )
            let syncRunner = StaticNativeSyncTriggerRunner(report: NativeSyncReport(
                trigger: .launch,
                bootstrapCursor: nil,
                accountID: "client_live",
                environment: .production,
                captureDraftEntityPurgeRequests: [purgeRequest],
                drainedClientMutationIDs: [],
                conflicts: [],
                pausedReason: nil,
                retryAfterSeconds: nil
            ))
            let configuration = APIClientConfiguration.spoonjoyProduction
            let liveStore = NativeLiveAppStore(dependencies: NativeLiveAppStoreDependencies(
                authSessionRepository: Self.authRepository(vault: vault),
                cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json")),
                syncStore: syncStore,
                syncEngine: engine,
                syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: syncRunner, configuration: configuration),
                appStateStoreProvider: { nil },
                configuration: configuration,
                cacheEnvironment: .production,
                captureDraftEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                },
                now: { Self.now }
            ))

            await liveStore.bootstrap()

            #expect(await syncRunner.triggers() == [.launch])
            #expect(await purgeRecorder.requests() == [purgeRequest])
        }
    }

    @MainActor
    @Test("live store purges chef profile entity indexes with scoped requests")
    func liveStorePurgesChefProfileEntityIndexesWithScopedRequests() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "client_live")
            let profile = Self.profileSummary(id: "chef_live_profile", username: "live-profile")
            let purgeRecorder = CapturingChefProfileEntityIndexPurge()
            let removedProfileTombstone = NativeSyncTombstone(
                resourceType: .profile,
                resourceID: "chef_removed_live_profile",
                parentResourceID: nil,
                title: "Removed live profile",
                deletedAt: Self.isoString(Self.now),
                updatedAt: Self.isoString(Self.now)
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(
                    accountID: "client_live",
                    environment: .production,
                    checkpoint: nil,
                    queue: NativeMutationQueue(),
                    cachedRecords: [
                        NativeSyncCachedRecord(
                            kind: .profile,
                            resourceID: profile.id,
                            payload: try Self.jsonValue(profile),
                            serverRevision: .updatedAt(Self.isoString(Self.now))
                        )
                    ]
                ),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: [removedProfileTombstone])),
                chefProfileEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                }
            )

            await liveStore.bootstrap()
            await liveStore.purgeChefProfileEntityIdentifiers([], domainIdentifiers: [])
            await liveStore.purgeChefProfileEntityIdentifiers(
                ["production|client_live|chef-profile|manual_profile", "production|client_live|chef-profile|manual_profile"],
                domainIdentifiers: ["app.spoonjoy.production.client_live.chef-profile", "app.spoonjoy.production.client_live.chef-profile"]
            )
            try await liveStore.performSettingsSessionOperation(.logout)

            let scope = SpotlightIndexScope(accountID: "client_live", environment: .production)
            let manualRequest = NativeChefProfileEntityIndexPurgeRequest(
                identifiers: ["production|client_live|chef-profile|manual_profile"],
                domainIdentifiers: ["app.spoonjoy.production.client_live.chef-profile"],
                accountID: "client_live",
                environment: .production
            )
            let tombstoneRequest = NativeChefProfileEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: removedProfileTombstone.resourceID, scope: scope)
                ],
                domainIdentifiers: [],
                accountID: "client_live",
                environment: .production
            )
            let logoutRequest = NativeChefProfileEntityIndexPurgeRequest(
                identifiers: [
                    SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: profile.id, scope: scope)
                ],
                domainIdentifiers: [
                    SpotlightIndexPlan.chefProfileDomainIdentifier(scope: scope)
                ],
                accountID: "client_live",
                environment: .production
            )
            let requests = await purgeRecorder.requests()
            #expect(requests == [tombstoneRequest, manualRequest, logoutRequest])
        }

        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_current")
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            try cacheStore.save(NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_previous",
                environment: .production,
                createdAt: Self.now,
                records: [
                    try Self.profileCacheRecord(id: "chef_previous_profile", username: "previous", accountID: "chef_previous", environment: .production),
                    try Self.cacheRecord(domain: .settings, payload: .empty, accountID: "chef_previous", environment: .production)
                ],
                dismissedIndicators: []
            ))
            let purgeRecorder = CapturingChefProfileEntityIndexPurge()
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: Self.sampleRecipe(id: "recipe_current_profile_switch", title: "Current Profile Switch"),
                    shoppingItem: nil,
                    accountID: "chef_current"
                ))),
                chefProfileEntityIndexPurge: { request in
                    await purgeRecorder.purge(request)
                }
            )

            await liveStore.bootstrap()

            let previousScope = SpotlightIndexScope(accountID: "chef_previous", environment: .production)
            #expect(await purgeRecorder.requests() == [
                NativeChefProfileEntityIndexPurgeRequest(
                    identifiers: [
                        SpotlightIndexPlan.chefProfileUniqueIdentifier(profileID: "chef_previous_profile", scope: previousScope)
                    ],
                    domainIdentifiers: [
                        SpotlightIndexPlan.chefProfileDomainIdentifier(scope: previousScope)
                    ],
                    accountID: "chef_previous",
                    environment: .production
                )
            ])
        }
    }

    @MainActor
    @Test("live store executes capture import requests and prepends imported recipes")
    func liveStoreExecutesCaptureImportRequestsAndPrependsImportedRecipes() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let existingRecipe = Self.sampleRecipe(id: "recipe_before_import", title: "Before Import Pasta")
            let importedRecipe = Self.sampleRecipe(id: "recipe_after_import", title: "After Import Soup")
            let syncData = try Self.sampleSyncData(
                recipe: existingRecipe,
                shoppingItem: nil,
                accountID: "chef_ari"
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let syncTransport = CapturingLiveStoreSyncTransport(bootstrap: .syncData(syncData))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: syncTransport,
                recipeEditorAPITransport: { _ in
                    CaptureImportAPITransport(importedRecipe: importedRecipe)
                }
            )
            let draft = try CaptureDraft.importURL(
                id: "draft_direct_capture_import",
                url: URL(string: "https://example.com/direct-import")!,
                createdAt: Self.isoString(Self.now)
            )
            let request = try NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_direct_capture_import",
                createdAt: Self.isoString(Self.now)
            ).requestBuilder()

            await liveStore.bootstrap()
            let response = try await liveStore.executeCaptureImportRequest(request)

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live sync after direct capture import; got \(liveStore.bootstrapState)")
                return
            }
            #expect(response.recipe?.id == "recipe_after_import")
            #expect(content.recipes.map(\.id) == ["recipe_after_import", "recipe_before_import"])
            #expect(content.recipeCatalog.rows.map(\.id) == ["recipe_after_import", "recipe_before_import"])
        }
    }

    @MainActor
    @Test("live store dependencies default recipe editor transport is URLSession-backed")
    func liveStoreDependenciesDefaultRecipeEditorTransportIsURLSessionBacked() async throws {
        let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
        let transport = CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
        let engine = NativeSyncEngine(store: syncStore, transport: transport, clock: { Self.now })
        let dependencies = NativeLiveAppStoreDependencies(
            authSessionRepository: Self.authRepository(vault: InMemoryTokenVault()),
            cacheStore: NativeDurableCacheStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("unused-cache-\(UUID().uuidString).json")),
            syncStore: syncStore,
            syncEngine: engine,
            syncTriggerCoordinator: NativeSyncTriggerCoordinator(runner: engine, configuration: .spoonjoyProduction),
            appStateStoreProvider: { nil },
            configuration: .spoonjoyProduction,
            cacheEnvironment: .production,
            now: { Self.now }
        )

        #expect(dependencies.recipeEditorAPITransport(NoopRecipeEditorAPIRefresher()) is URLSessionAPITransport)
        await dependencies.chefProfileEntityIndexPurge(NativeChefProfileEntityIndexPurgeRequest(
            identifiers: ["production|client_live|chef-profile|chef_default_hook"],
            domainIdentifiers: ["app.spoonjoy.production.client_live.chef-profile"],
            accountID: "client_live",
            environment: .production
        ))
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
            try await liveStore.queueMutation(currentMutation)
            let snapshot = try await syncStore.loadSnapshot()

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
    @Test("live store persists direct capture import provider blocker through successful bootstrap")
    func liveStorePersistsDirectCaptureImportProviderBlockerThroughSuccessfulBootstrap() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { appStateStore }
            )

            await liveStore.bootstrap()
            liveStore.recordCaptureImportBlocker(.providerSecret(retryAfterSeconds: 30))

            guard case .blocker(let blockedContent) = liveStore.bootstrapState else {
                Issue.record("Expected direct provider blocker state; got \(liveStore.bootstrapState)")
                return
            }

            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )
            let savedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(blockedContent.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "recipe-import")))
            #expect(savedSnapshot.captureImportProviderBlocker == "recipe-import")

            let restoredStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { appStateStore }
            )

            await restoredStore.bootstrap()

            guard case .blocker(let restoredContent) = restoredStore.bootstrapState else {
                Issue.record("Expected persisted provider blocker after successful bootstrap; got \(restoredStore.bootstrapState)")
                return
            }
            #expect(restoredContent.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "recipe-import")))
        }
    }

    @MainActor
    @Test("live store persists queued capture import blockers while unrelated work drains")
    func liveStorePersistsQueuedCaptureImportBlockersWhileUnrelatedWorkDrains() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            let draft = try CaptureDraft.importURL(
                id: "draft_queued_provider_blocker",
                url: URL(string: "https://example.com/provider-blocked-import")!,
                createdAt: Self.isoString(Self.now)
            )
            let importMutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_import_provider_blocked",
                createdAt: Self.isoString(Self.now)
            )
            let profileMutation = NativeQueuedMutation.profileDisplayUpdate(
                email: "ari@example.com",
                username: "ari",
                clientMutationID: "cm_profile_after_import_blocker",
                createdAt: Self.isoString(Self.now)
            )
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "chef_ari",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
                .recordingCaptureDraft(draft, savedAt: Self.isoString(Self.now))
                .recordingCaptureImportRetry(importMutation, savedAt: Self.isoString(Self.now))
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [importMutation, profileMutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(sends: [
                    .blocked(
                        .providerSecret(resourceID: "recipe-import"),
                        message: "Recipe import setup is required before Spoonjoy can finish this import."
                    ),
                    .success(serverRevision: .updatedAt(Self.isoString(Self.now)))
                ]),
                appStateStoreProvider: { appStateStore }
            )

            await liveStore.bootstrap()

            guard case .blocker(let content) = liveStore.bootstrapState else {
                Issue.record("Expected provider blocker state after queued import drain; got \(liveStore.bootstrapState)")
                return
            }
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )
            let savedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value

            #expect(content.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "recipe-import")))
            #expect(content.queuedMutations.map(\.clientMutationID) == ["cm_import_provider_blocked"])
            #expect(savedSnapshot.captureDraft == draft)
            #expect(savedSnapshot.captureImportProviderBlocker == "recipe-import")
            #expect(try await syncStore.loadQueue().mutations.map(\.clientMutationID) == ["cm_import_provider_blocked"])
        }
    }

    @MainActor
    @Test("live store handles capture import blockers without durable app state")
    func liveStoreHandlesCaptureImportBlockersWithoutDurableAppState() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let draft = try CaptureDraft.importURL(
                id: "draft_provider_blocker_no_app_state",
                url: URL(string: "https://example.com/no-app-state-provider-blocker")!,
                createdAt: Self.isoString(Self.now)
            )
            let importMutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_import_provider_blocked_no_app_state",
                createdAt: Self.isoString(Self.now)
            )
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [importMutation])
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(sends: [
                    .blocked(
                        .providerSecret(resourceID: "recipe-import"),
                        message: "Recipe import setup is required before Spoonjoy can finish this import."
                    )
                ]),
                appStateStoreProvider: { nil }
            )

            await liveStore.bootstrap()

            guard case .blocker(let content) = liveStore.bootstrapState else {
                Issue.record("Expected provider blocker without app-state store; got \(liveStore.bootstrapState)")
                return
            }
            #expect(content.offlineIndicatorState.display == .blocker(.providerSecret(resourceID: "recipe-import")))
            #expect(content.queuedMutations.map(\.clientMutationID) == ["cm_import_provider_blocked_no_app_state"])
        }
    }

    @MainActor
    @Test("live store clears capture draft and pending import after queued import drains")
    func liveStoreClearsCaptureDraftAndPendingImportAfterQueuedImportDrains() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let draft = try CaptureDraft.importURL(
                id: "draft_drained_import",
                url: URL(string: "https://example.com/drained-import")!,
                createdAt: Self.isoString(Self.now)
            )
            let mutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_drained_import",
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
                .recordingCaptureDraft(draft, savedAt: Self.isoString(Self.now))
                .recordingCaptureImportRetry(mutation, savedAt: Self.isoString(Self.now))
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
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { appStateStore }
            )

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected drained import to reach live synced state; got \(liveStore.bootstrapState)")
                return
            }
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )
            let savedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(content.captureDraft == nil)
            #expect(content.queuedMutations.isEmpty)
            #expect(savedSnapshot.captureDraft == nil)
            #expect(savedSnapshot.pendingCaptureImport == nil)

            let staleClearAppStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("stale-clear-drained-import-state.json"))
            let staleClearMutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_drained_import_stale_app_state",
                createdAt: Self.isoString(Self.now)
            )
            try staleClearAppStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "chef_previous",
                    environment: .production,
                    savedAt: Self.isoString(Self.now.addingTimeInterval(-120))
                )
                .recordingOpenedRoute(.settings, savedAt: Self.isoString(Self.now.addingTimeInterval(-120)))
                .recordingCaptureImportRetry(staleClearMutation, savedAt: Self.isoString(Self.now.addingTimeInterval(-120)))
            )
            let staleClearSyncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [staleClearMutation])
            )
            let staleClearStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: staleClearSyncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { staleClearAppStateStore }
            )

            await staleClearStore.bootstrap()

            guard case .liveSynced(let staleClearContent) = staleClearStore.bootstrapState else {
                Issue.record("Expected drained import to reset stale app-state cleanup; got \(staleClearStore.bootstrapState)")
                return
            }
            let staleClearFallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )
            let staleClearSavedSnapshot = try staleClearAppStateStore.loadOrCreate(fallback: staleClearFallback).value
            #expect(staleClearContent.queuedMutations.isEmpty)
            #expect(staleClearSavedSnapshot.accountID == "chef_ari")
            #expect(staleClearSavedSnapshot.lastOpenedRoute == nil)
            #expect(staleClearSavedSnapshot.pendingCaptureImport == nil)

            let brokenAppStateURL = directory.appendingPathComponent("broken-clear-drained-import-state.json", isDirectory: true)
            try FileManager.default.createDirectory(at: brokenAppStateURL, withIntermediateDirectories: true)
            let brokenClearMutation = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_drained_import_broken_app_state",
                createdAt: Self.isoString(Self.now)
            )
            let brokenClearSyncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [brokenClearMutation])
            )
            let brokenClearStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: brokenClearSyncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { NativeAppStateStore(fileURL: brokenAppStateURL) }
            )

            await brokenClearStore.bootstrap()

            guard case .liveSynced(let brokenClearContent) = brokenClearStore.bootstrapState else {
                Issue.record("Expected drained import to stay live even when app-state cleanup fails; got \(brokenClearStore.bootstrapState)")
                return
            }
            #expect(brokenClearContent.queuedMutations.isEmpty)
            #expect(try await brokenClearSyncStore.loadQueue().mutations.isEmpty)
        }
    }

    @MainActor
    @Test("live store records capture drafts retries and discard through durable app state")
    func liveStoreRecordsCaptureDraftsRetriesAndDiscardThroughDurableAppState() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            let syncStore = InMemoryNativeSyncStore(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { appStateStore }
            )
            let draft = try CaptureDraft.importURL(
                id: "draft_live_store_record",
                url: URL(string: "https://example.com/live-store-record")!,
                createdAt: Self.isoString(Self.now)
            )
            let retry = NativeQueuedMutation.recipeImportSubmit(
                source: try draft.importSource(),
                clientMutationID: "cm_live_store_record",
                createdAt: Self.isoString(Self.now)
            )
            let fallback = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )
            let staleSnapshot = NativeAppSnapshot.bootstrap(
                shoppingList: nil,
                accountID: "chef_previous",
                environment: .production,
                savedAt: Self.isoString(Self.now.addingTimeInterval(-60))
            )

            await liveStore.bootstrap()
            try appStateStore.save(staleSnapshot.recordingOpenedRoute(.settings, savedAt: staleSnapshot.savedAt))
            liveStore.recordCaptureDraft(draft)

            guard case .liveSynced(let recordedContent) = liveStore.bootstrapState else {
                Issue.record("Expected capture draft record to preserve live synced state; got \(liveStore.bootstrapState)")
                return
            }
            let recordedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(recordedContent.captureDraft == draft)
            #expect(recordedSnapshot.accountID == "chef_ari")
            #expect(recordedSnapshot.lastOpenedRoute == nil)
            #expect(recordedSnapshot.captureDraft == draft)

            liveStore.discardCaptureDraft(id: draft.id)
            let scopedDiscardSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(scopedDiscardSnapshot.accountID == "chef_ari")
            #expect(scopedDiscardSnapshot.captureDraft == nil)
            liveStore.recordCaptureDraft(draft)

            liveStore.recordCaptureDraft(draft)
            #expect(try appStateStore.loadOrCreate(fallback: fallback).value.captureDraft == draft)

            try appStateStore.save(staleSnapshot.recordingOpenedRoute(.settings, savedAt: staleSnapshot.savedAt))
            liveStore.recordCaptureImportRetry(retry)
            let retrySnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(retrySnapshot.accountID == "chef_ari")
            #expect(retrySnapshot.lastOpenedRoute == nil)
            #expect(retrySnapshot.pendingCaptureImport == retry)

            liveStore.recordCaptureImportRetry(retry)
            #expect(try appStateStore.loadOrCreate(fallback: fallback).value.pendingCaptureImport == retry)

            try appStateStore.save(staleSnapshot.recordingOpenedRoute(.settings, savedAt: staleSnapshot.savedAt))
            liveStore.discardCaptureDraft(id: "draft_not_visible")
            guard case .liveSynced(let unchangedContent) = liveStore.bootstrapState else {
                Issue.record("Expected wrong draft discard to preserve live synced state; got \(liveStore.bootstrapState)")
                return
            }
            let unchangedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(unchangedContent.captureDraft == draft)
            #expect(unchangedSnapshot.accountID == "chef_previous")
            #expect(unchangedSnapshot.lastOpenedRoute == AppRoute.settings.stateIdentifier)
            #expect(unchangedSnapshot.captureDraft == nil)

            try appStateStore.save(staleSnapshot.recordingOpenedRoute(.settings, savedAt: staleSnapshot.savedAt))
            liveStore.discardCaptureDraft(id: draft.id)
            guard case .liveSynced(let discardedContent) = liveStore.bootstrapState else {
                Issue.record("Expected visible draft discard to preserve live synced state; got \(liveStore.bootstrapState)")
                return
            }
            let savedSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(discardedContent.captureDraft == nil)
            #expect(savedSnapshot.accountID == "chef_ari")
            #expect(savedSnapshot.lastOpenedRoute == nil)
            #expect(savedSnapshot.captureDraft == nil)
            #expect(savedSnapshot.pendingCaptureImport == nil)
            #expect(savedSnapshot.captureImportProviderBlocker == nil)

            try appStateStore.save(staleSnapshot.recordingOpenedRoute(.settings, savedAt: staleSnapshot.savedAt))
            liveStore.recordCaptureImportBlocker(.providerSecret(retryAfterSeconds: nil))
            guard case .blocker = liveStore.bootstrapState else {
                Issue.record("Expected capture import blocker to preserve blocker state; got \(liveStore.bootstrapState)")
                return
            }
            let blockerSnapshot = try appStateStore.loadOrCreate(fallback: fallback).value
            #expect(blockerSnapshot.accountID == "chef_ari")
            #expect(blockerSnapshot.lastOpenedRoute == nil)
            #expect(blockerSnapshot.captureImportProviderBlocker == "recipe-import")

            let brokenDiscardURL = directory.appendingPathComponent("broken-discard-capture-state.json")
            let brokenDiscardStore = NativeAppStateStore(fileURL: brokenDiscardURL)
            let brokenDiscardLiveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(
                    accountID: "chef_ari",
                    environment: .production,
                    checkpoint: nil,
                    queue: NativeMutationQueue()
                ),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { brokenDiscardStore }
            )

            await brokenDiscardLiveStore.bootstrap()
            brokenDiscardLiveStore.recordCaptureDraft(draft)
            try FileManager.default.removeItem(at: brokenDiscardURL)
            try FileManager.default.createDirectory(at: brokenDiscardURL, withIntermediateDirectories: true)
            brokenDiscardLiveStore.discardCaptureDraft(id: draft.id)

            guard case .liveSynced(let brokenDiscardContent) = brokenDiscardLiveStore.bootstrapState else {
                Issue.record("Expected failed draft discard persistence to keep live synced state; got \(brokenDiscardLiveStore.bootstrapState)")
                return
            }
            #expect(brokenDiscardContent.captureDraft == draft)
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
            let previewRecipe = Self.sampleRecipe(id: "recipe_preview", title: "Preview Risotto")
            let productionItem = Self.sampleShoppingItem(id: "item_production", name: "production lemons")
            let localItem = Self.sampleShoppingItem(id: "item_local", name: "local carrots")
            let previewItem = Self.sampleShoppingItem(id: "item_preview", name: "preview peas")
            let previewEnvironment = NativeCacheEnvironment.preview(host: " Branch-Preview.Spoonjoy.App ")
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
                )),
                .syncData(try Self.sampleSyncData(
                    recipe: previewRecipe,
                    shoppingItem: previewItem,
                    accountID: "chef_ari",
                    environment: previewEnvironment
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
            #expect(localContent.settingsViewModel.settings.environment == .local(baseURL: configuration.baseURL))
            #expect(localContent.recipes.map(\.id) == ["recipe_local"])
            #expect(localContent.shoppingList?.activeItems.map(\.id) == ["item_local"])

            await liveStore.switchEnvironment(previewEnvironment)

            guard case .liveSynced(let previewContent) = liveStore.bootstrapState else {
                Issue.record("Expected preview environment switch to apply scoped sync; got \(liveStore.bootstrapState)")
                return
            }
            #expect(previewContent.environment == previewEnvironment)
            #expect(previewContent.settingsViewModel.settings.environment == .preview(baseURL: configuration.baseURL))
            #expect(previewContent.recipes.map(\.id) == ["recipe_preview"])
            #expect(previewContent.shoppingList?.activeItems.map(\.id) == ["item_preview"])
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
                    try Self.cacheRecord(domain: .cookProgress(recipeID: "recipe_cached"), payload: .cookProgress(recipeID: "recipe_cached", completedStepIDs: ["step_1"], currentStepID: "step_2")),
                    try Self.cacheRecord(domain: .cookProgress(recipeID: "recipe_cache_only"), payload: .cookProgress(recipeID: "recipe_cache_only", completedStepIDs: ["step_a"], currentStepID: "step_b"))
                ],
                dismissedIndicators: []
            ))
            let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
            let mediaDirectory = NativeStagedMediaDirectory(
                directoryURL: directory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
            try appStateStore.save(
                NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
                    .updatingCookProgress(
                        CookModeProgress(
                            recipeID: "recipe_cached",
                            completedStepIDs: ["step_1"],
                            currentStepID: "step_2"
                        )
                        .settingScaleFactor(3, updatedAt: Self.isoString(Self.now)),
                        savedAt: Self.isoString(Self.now)
                    )
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
                appStateStoreProvider: { appStateStore },
                stagedMediaDirectory: mediaDirectory
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
            #expect(content.cookProgress(for: "recipe_cached")?.scaleFactor == 3)
            #expect(content.cookProgress(for: "recipe_cache_only")?.currentStepID == "step_b")
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

            let richCookProgress = CookModeProgress(
                recipeID: "recipe_cached",
                stepIDs: ["step_1", "step_2"],
                startedAt: Self.isoString(Self.now)
            )
            .settingScaleFactor(2, updatedAt: Self.isoString(Self.now))
            liveStore.recordCookProgress(richCookProgress)
            let savedCookProgress = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(savedCookProgress.hasCompletedFirstRun)
            #expect(savedCookProgress.lastOpenedRoute == "settings")
            #expect(savedCookProgress.cookProgress(for: "recipe_cached") == richCookProgress)
            #expect(liveStore.bootstrapState.contentState.cookProgress(for: "recipe_cached") == richCookProgress)
            #expect((try await syncStore.loadQueue()).mutations.isEmpty)

            let manualShoppingList = ShoppingListState(
                id: "shopping_list_manual_record",
                chef: ChefSummary(id: "signed-out", username: "Spoonjoy"),
                items: [
                    Self.sampleShoppingItem(id: "item_manual_record", name: "manual lemons")
                ],
                nextCursor: "manual.cursor",
                updatedAt: Self.isoString(Self.now)
            )
            liveStore.recordShoppingList(manualShoppingList)
            let savedShoppingList = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(savedShoppingList.shoppingList == manualShoppingList)
            #expect(liveStore.bootstrapState.contentState.shoppingList == manualShoppingList)

            let spoonDraft = SpoonCookLogDraftState(
                recipeID: "recipe_cached",
                note: "Try more lemon.",
                nextTime: "Less salt.",
                stagedPhoto: nil,
                useAsRecipeCover: false,
                updatedAt: Self.isoString(Self.now)
            )
            liveStore.recordSpoonCookLogDraft(spoonDraft, forRecipeID: "recipe_cached")
            let savedSpoonDraft = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(savedSpoonDraft.spoonCookLogDraft(for: "recipe_cached") == spoonDraft)
            #expect(liveStore.bootstrapState.contentState.spoonCookLogDraft(recipeID: "recipe_cached") == spoonDraft)

            let stagedPhoto = NativeStagedMediaUpload(
                localStageID: "stage_spoon_recipe_cached",
                fileName: "spoon.jpg",
                contentType: "image/jpeg",
                data: Data([0xFF, 0xD8])
            )
            let photoDraft = SpoonCookLogDraftState(
                recipeID: "recipe_cached",
                note: "Photo proof.",
                nextTime: nil,
                stagedPhoto: stagedPhoto,
                useAsRecipeCover: true,
                updatedAt: Self.isoString(Self.now)
            )
            liveStore.recordSpoonCookLogDraft(photoDraft, forRecipeID: "recipe_cached")
            #expect(try mediaDirectory.data(for: stagedPhoto) == Data([0xFF, 0xD8]))
            let savedPhotoDraft = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value.spoonCookLogDraft(for: "recipe_cached")
            #expect(savedPhotoDraft?.stagedPhoto?.data.isEmpty == true)

            let restoredDraftStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { appStateStore },
                stagedMediaDirectory: mediaDirectory
            )
            await restoredDraftStore.bootstrap()
            guard case .signedOut(let restoredDraftContent) = restoredDraftStore.bootstrapState else {
                Issue.record("Expected signed-out restore after spoon draft save; got \(restoredDraftStore.bootstrapState)")
                return
            }
            #expect(restoredDraftContent.spoonCookLogDraft(recipeID: "recipe_cached") == savedPhotoDraft)

            liveStore.recordSpoonCookLogDraft(nil, forRecipeID: "recipe_cached")
            let clearedSpoonDraft = try appStateStore.loadOrCreate(
                fallback: NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "signed-out",
                    environment: .production,
                    savedAt: Self.isoString(Self.now)
                )
            ).value
            #expect(clearedSpoonDraft.spoonCookLogDraft(for: "recipe_cached") == nil)

            let nilStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { nil }
            )
            let nilStoreProgressBefore = nilStore.bootstrapState.contentState.cookProgressByRecipeID
            nilStore.recordCookProgress(CookModeProgress(
                recipeID: "recipe_nil_store",
                stepIDs: ["step_1"],
                startedAt: Self.isoString(Self.now)
            ))
            #expect(nilStore.bootstrapState.contentState.cookProgressByRecipeID == nilStoreProgressBefore)

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

            let legacySnapshotJSON = """
            {
              "schemaVersion": 1,
              "accountID": "signed-out",
              "environment": "production",
              "hasCompletedFirstRun": false,
              "cookProgressByRecipeID": {},
              "shoppingList": null,
              "captureDraft": null,
              "pendingMutations": { "mutations": [] },
              "lastOpenedRoute": null,
              "savedAt": "\(Self.isoString(Self.now))"
            }
            """
            let legacySnapshot = try JSONDecoder().decode(
                NativeAppSnapshot.self,
                from: Data(legacySnapshotJSON.utf8)
            )
            #expect(legacySnapshot.spoonCookLogDraftsByRecipeID.isEmpty)

            let blankRecipeDraftSnapshot = legacySnapshot.updatingSpoonCookLogDraft(
                spoonDraft,
                forRecipeID: "   ",
                savedAt: "2026-06-27T16:05:00.000Z"
            )
            #expect(blankRecipeDraftSnapshot.spoonCookLogDraftsByRecipeID.isEmpty)
            #expect(blankRecipeDraftSnapshot.savedAt == "2026-06-27T16:05:00.000Z")
        }
    }

    @MainActor
    @Test("signed out search recording does not overwrite mismatched durable account cache")
    func signedOutSearchRecordingDoesNotOverwriteMismatchedDurableAccountCache() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            let realAccountRecord = try Self.cacheRecord(
                domain: .recipeDetail(id: "recipe_real_account"),
                payload: .recipeDetail(id: "recipe_real_account", title: "Real Account Pasta"),
                accountID: "chef_real"
            )
            try cacheStore.save(try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_real",
                environment: .production,
                createdAt: Self.now,
                records: [realAccountRecord],
                dismissedIndicators: []
            ))
            let liveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport()
            )
            let page = SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: false,
                results: [
                    SearchSurfaceResult(
                        type: .recipe,
                        id: "recipe_public_search",
                        ownerID: "chef_public",
                        ownerUsername: "ari",
                        title: "Public Tomato Toast",
                        subtitle: "Recipe by ari",
                        snippet: "tomato toast",
                        href: "/recipes/recipe_public_search",
                        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_public_search")!,
                        imageURL: nil,
                        score: -0.1,
                        metadata: [:]
                    )
                ],
                source: .live(requestID: "req_search_signed_out", validatedAt: Self.now)
            )

            try liveStore.recordSearchSurfacePage(page, expectedIdentity: liveStore.currentSearchSurfaceIdentity)

            let fallback = try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_real",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            )
            let persisted = try cacheStore.loadOrRecover(fallback: fallback).value
            let persistedSearchRecordCount = persisted.records.filter { record in
                if case .searchResults = record.payload {
                    return true
                }
                return false
            }.count
            #expect(persisted.accountID == "chef_real")
            #expect(persisted.records.map(\.id) == [realAccountRecord.id])
            #expect(persistedSearchRecordCount == 0)

            let viewModel = liveStore.bootstrapState.contentState.performSearch(SearchState(query: "tomato", scope: .all))
            #expect(viewModel.sections.flatMap(\.rows).map(\.title) == ["Public Tomato Toast"])
        }
    }

    @MainActor
    @Test("signed in search recording persists scoped cache and filters private rows")
    func signedInSearchRecordingPersistsScopedCacheAndFiltersPrivateRows() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_search_cache", title: "Search Cache Pasta")
            let cookbook = Self.sampleCookbook(id: "cookbook_search_cache", title: "Search Cache Suppers")
            let shoppingItem = Self.sampleShoppingItem(id: "item_search_cache", name: "tomatoes")
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                cacheStore: cacheStore,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: recipe,
                    cookbook: cookbook,
                    shoppingItem: shoppingItem,
                    accountID: "chef_ari"
                )))
            )

            await liveStore.bootstrap()

            guard case .liveSynced(let content) = liveStore.bootstrapState else {
                Issue.record("Expected live store to bootstrap signed-in search cache content; got \(liveStore.bootstrapState)")
                return
            }
            let defaultSearch = content.searchSurfaceViewModel
            #expect(defaultSearch.sections.flatMap(\.rows).map(\.title).contains("Search Cache Pasta"))
            #expect(defaultSearch.sections.flatMap(\.rows).map(\.title).contains("Search Cache Suppers"))
            #expect(defaultSearch.sections.flatMap(\.rows).map(\.title).contains("ari"))
            #expect(defaultSearch.sections.flatMap(\.rows).map(\.title).contains("tomatoes"))

            let repository = liveStore.searchSurfaceRepository(context: content.searchSurfaceContext)
            #expect(try await repository.recentSearches(limit: 1).isEmpty)

            let ownShoppingResult = SearchSurfaceResult(
                type: .shoppingListItem,
                id: "item_own_search",
                ownerID: "chef_ari",
                ownerUsername: "ari",
                title: "tomatoes",
                subtitle: "3 each",
                snippet: "produce",
                href: "/shopping-list",
                canonicalURL: URL(string: "https://spoonjoy.app/shopping-list")!,
                imageURL: nil,
                score: -0.5,
                metadata: ["checked": .bool(false)]
            )
            let otherShoppingResult = SearchSurfaceResult(
                type: .shoppingListItem,
                id: "item_other_search",
                ownerID: "chef_other",
                ownerUsername: "other",
                title: "secret shallots",
                subtitle: "1 each",
                snippet: "produce",
                href: "/shopping-list",
                canonicalURL: URL(string: "https://spoonjoy.app/shopping-list")!,
                imageURL: nil,
                score: -0.4,
                metadata: ["checked": .bool(false)]
            )
            let page = SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [
                    SearchSurfaceResult(
                        type: .recipe,
                        id: "recipe_public_search",
                        ownerID: "chef_ari",
                        ownerUsername: "ari",
                        title: "Public Tomato Toast",
                        subtitle: "Recipe by ari",
                        snippet: "tomato toast",
                        href: "/recipes/recipe_public_search",
                        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_public_search")!,
                        imageURL: nil,
                        score: -0.1,
                        metadata: [:]
                    ),
                    ownShoppingResult,
                    otherShoppingResult
                ],
                source: .cache(serverRevision: .cursor("search-cache-v2"), lastValidatedAt: Self.now)
            )

            try liveStore.recordSearchSurfacePage(page, expectedIdentity: "stale-search-identity")
            try liveStore.recordSearchSurfacePage(page, expectedIdentity: liveStore.currentSearchSurfaceIdentity)

            let fallback = try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            )
            let persisted = try cacheStore.loadOrRecover(fallback: fallback).value
            let persistedSearchSnapshot = try #require(persisted.records.compactMap { record -> SearchSurfaceCacheSnapshot? in
                if case .searchResults(let snapshot) = record.payload {
                    return snapshot
                }
                return nil
            }.first)

            #expect(persisted.accountID == "chef_ari")
            #expect(persistedSearchSnapshot.results.map(\.id) == ["recipe_public_search", "item_own_search"])
            #expect(persistedSearchSnapshot.recentSearches.map(\.query) == ["tomato"])
            #expect(persistedSearchSnapshot.serverRevision == .cursor("search-cache-v2"))

            let restored = liveStore.bootstrapState.contentState.performSearch(SearchState(query: "tomato", scope: .all))
            #expect(restored.sections.flatMap(\.rows).map(\.result.id) == ["recipe_public_search", "item_own_search"])

            let replacementPage = SearchSurfacePage(
                query: "tomato",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [
                    SearchSurfaceResult(
                        type: .recipe,
                        id: "recipe_replacement_search",
                        ownerID: "chef_ari",
                        ownerUsername: "ari",
                        title: "Replacement Tomato Toast",
                        subtitle: "Recipe by ari",
                        snippet: "tomato toast",
                        href: "/recipes/recipe_replacement_search",
                        canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_replacement_search")!,
                        imageURL: nil,
                        score: -0.1,
                        metadata: [:]
                    )
                ],
                source: .live(requestID: "req_search_replacement", validatedAt: Self.now.addingTimeInterval(5))
            )
            try liveStore.recordSearchSurfacePage(replacementPage, expectedIdentity: liveStore.currentSearchSurfaceIdentity)

            let replacementRestored = liveStore.bootstrapState.contentState.performSearch(SearchState(query: "tomato", scope: .all))
            #expect(replacementRestored.sections.flatMap(\.rows).map(\.result.id) == ["recipe_replacement_search"])

            let blankPage = SearchSurfacePage(
                query: "",
                scope: .all,
                limit: 20,
                isAuthenticated: true,
                results: [ownShoppingResult],
                source: .cache(serverRevision: .cursor("search-blank"), lastValidatedAt: Self.now.addingTimeInterval(10))
            )
            try liveStore.recordSearchSurfacePage(blankPage, expectedIdentity: liveStore.currentSearchSurfaceIdentity)
            let persistedAfterBlank = try cacheStore.loadOrRecover(fallback: fallback).value
            let blankSnapshot = try #require(persistedAfterBlank.records.compactMap { record -> SearchSurfaceCacheSnapshot? in
                if case .searchResults(let snapshot) = record.payload, snapshot.query.isEmpty {
                    return snapshot
                }
                return nil
            }.first)
            #expect(blankSnapshot.recentSearches.isEmpty)
        }
    }

    @MainActor
    @Test("live store deletes superseded spoon draft media unless queued")
    func liveStoreDeletesSupersededSpoonDraftMediaUnlessQueued() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let recipe = Self.sampleRecipe(id: "recipe_draft_media", title: "Draft Media Pasta")
            let mediaDirectory = NativeStagedMediaDirectory(
                directoryURL: directory.appendingPathComponent("native-staged-media", isDirectory: true)
            )
            let appStateURL = directory.appendingPathComponent("app-state.json")
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: CapturingLiveStoreSyncTransport(bootstrap: .syncData(try Self.sampleSyncData(
                    recipe: recipe,
                    shoppingItem: nil,
                    accountID: "chef_ari"
                ))),
                appStateStoreProvider: { NativeAppStateStore(fileURL: appStateURL) },
                stagedMediaDirectory: mediaDirectory
            )
            let firstPhoto = NativeStagedMediaUpload(
                localStageID: "stage_draft_first",
                fileName: "first.webp",
                contentType: "image/webp",
                data: Data([0x01])
            )
            let queuedPhoto = NativeStagedMediaUpload(
                localStageID: "stage_draft_queued",
                fileName: "queued.webp",
                contentType: "image/webp",
                data: Data([0x02, 0x03])
            )
            let unqueuedPhoto = NativeStagedMediaUpload(
                localStageID: "stage_draft_unqueued",
                fileName: "unqueued.webp",
                contentType: "image/webp",
                data: Data([0x04])
            )

            await liveStore.bootstrap()
            liveStore.recordSpoonCookLogDraft(SpoonCookLogDraftState(
                recipeID: recipe.id,
                note: "First.",
                nextTime: nil,
                stagedPhoto: firstPhoto,
                useAsRecipeCover: true,
                updatedAt: Self.isoString(Self.now)
            ), forRecipeID: recipe.id)
            #expect(try mediaDirectory.data(for: firstPhoto) == firstPhoto.data)

            liveStore.recordSpoonCookLogDraft(SpoonCookLogDraftState(
                recipeID: recipe.id,
                note: "Queued.",
                nextTime: nil,
                stagedPhoto: queuedPhoto,
                useAsRecipeCover: true,
                updatedAt: Self.isoString(Self.now.addingTimeInterval(1))
            ), forRecipeID: recipe.id)
            #expect(throws: NativeStagedMediaDirectoryError.missingStage(firstPhoto.localStageID)) {
                _ = try mediaDirectory.data(for: firstPhoto)
            }
            #expect(try mediaDirectory.data(for: queuedPhoto) == queuedPhoto.data)

            try await liveStore.queueMutations([
                NativeQueuedMutation.spoonCreatePhoto(
                    recipeID: recipe.id,
                    photo: queuedPhoto,
                    clientMutationID: "cm_draft_media_queued",
                    note: "Queued.",
                    nextTime: nil,
                    cookedAt: nil,
                    useAsRecipeCover: true,
                    createdAt: Self.isoString(Self.now.addingTimeInterval(2))
                )
            ])
            liveStore.recordSpoonCookLogDraft(nil, forRecipeID: recipe.id)
            #expect(try mediaDirectory.data(for: queuedPhoto) == queuedPhoto.data)

            liveStore.recordSpoonCookLogDraft(SpoonCookLogDraftState(
                recipeID: recipe.id,
                note: "Unqueued.",
                nextTime: nil,
                stagedPhoto: unqueuedPhoto,
                useAsRecipeCover: false,
                updatedAt: Self.isoString(Self.now.addingTimeInterval(3))
            ), forRecipeID: recipe.id)
            #expect(try mediaDirectory.data(for: unqueuedPhoto) == unqueuedPhoto.data)

            liveStore.recordSpoonCookLogDraft(nil, forRecipeID: recipe.id)
            #expect(throws: NativeStagedMediaDirectoryError.missingStage(unqueuedPhoto.localStageID)) {
                _ = try mediaDirectory.data(for: unqueuedPhoto)
            }
            #expect(try mediaDirectory.data(for: queuedPhoto) == queuedPhoto.data)

            let brokenAppStateURL = directory.appendingPathComponent("broken-draft-state.json", isDirectory: true)
            try FileManager.default.createDirectory(at: brokenAppStateURL, withIntermediateDirectories: true)
            let failedPhoto = NativeStagedMediaUpload(
                localStageID: "stage_draft_failed_save",
                fileName: "failed.webp",
                contentType: "image/webp",
                data: Data([0x05])
            )
            let brokenDraftStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { NativeAppStateStore(fileURL: brokenAppStateURL) },
                stagedMediaDirectory: mediaDirectory
            )
            brokenDraftStore.recordSpoonCookLogDraft(SpoonCookLogDraftState(
                recipeID: recipe.id,
                note: "This save will fail.",
                nextTime: nil,
                stagedPhoto: failedPhoto,
                useAsRecipeCover: false,
                updatedAt: Self.isoString(Self.now.addingTimeInterval(4))
            ), forRecipeID: recipe.id)
            guard case .syncFailed = brokenDraftStore.bootstrapState else {
                Issue.record("Expected failed spoon draft save; got \(brokenDraftStore.bootstrapState)")
                return
            }
            #expect(throws: NativeStagedMediaDirectoryError.missingStage(failedPhoto.localStageID)) {
                _ = try mediaDirectory.data(for: failedPhoto)
            }
        }
    }

    @MainActor
    @Test("live store resets mismatched app snapshots before recording local state")
    func liveStoreResetsMismatchedAppSnapshotsBeforeRecordingLocalState() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            func mismatchedStore(_ name: String) throws -> NativeAppStateStore {
                let store = NativeAppStateStore(fileURL: directory.appendingPathComponent("\(name).json"))
                try store.save(NativeAppSnapshot.bootstrap(
                    shoppingList: nil,
                    accountID: "other-account",
                    environment: .local,
                    savedAt: Self.isoString(Self.now.addingTimeInterval(-60))
                ))
                return store
            }

            let routeStore = try mismatchedStore("route")
            let routeLiveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { routeStore }
            )
            routeLiveStore.recordingOpenedRoute(.settings)
            #expect(try routeStore.loadOrCreate(fallback: .bootstrap(
                shoppingList: nil,
                accountID: "signed-out",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )).value.isScoped(accountID: "signed-out", environment: .production))

            let progressStore = try mismatchedStore("progress")
            let progressLiveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { progressStore }
            )
            progressLiveStore.recordCookProgress(CookModeProgress(
                recipeID: "recipe_progress_reset",
                stepIDs: ["step_1"],
                startedAt: Self.isoString(Self.now)
            ))
            #expect(try progressStore.loadOrCreate(fallback: .bootstrap(
                shoppingList: nil,
                accountID: "signed-out",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )).value.isScoped(accountID: "signed-out", environment: .production))

            let shoppingStore = try mismatchedStore("shopping")
            let shoppingLiveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { shoppingStore }
            )
            shoppingLiveStore.recordShoppingList(ShoppingListState(
                id: "shopping_reset",
                chef: ChefSummary(id: "signed-out", username: "Spoonjoy"),
                items: [],
                nextCursor: "",
                updatedAt: Self.isoString(Self.now)
            ))
            #expect(try shoppingStore.loadOrCreate(fallback: .bootstrap(
                shoppingList: nil,
                accountID: "signed-out",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )).value.isScoped(accountID: "signed-out", environment: .production))

            let draftStore = try mismatchedStore("draft")
            let draftLiveStore = Self.liveStore(
                directory: directory,
                vault: InMemoryTokenVault(),
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(),
                appStateStoreProvider: { draftStore }
            )
            draftLiveStore.recordSpoonCookLogDraft(SpoonCookLogDraftState(
                recipeID: "recipe_draft_reset",
                note: "Scoped fresh.",
                nextTime: nil,
                stagedPhoto: nil,
                useAsRecipeCover: false,
                updatedAt: Self.isoString(Self.now)
            ), forRecipeID: "recipe_draft_reset")
            #expect(try draftStore.loadOrCreate(fallback: .bootstrap(
                shoppingList: nil,
                accountID: "signed-out",
                environment: .production,
                savedAt: Self.isoString(Self.now)
            )).value.isScoped(accountID: "signed-out", environment: .production))
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
            brokenRouteStore.recordCookProgress(CookModeProgress(
                recipeID: "recipe_broken_store",
                stepIDs: ["step_1"],
                startedAt: Self.isoString(Self.now)
            ))
            brokenRouteStore.recordShoppingList(ShoppingListState(
                id: "shopping_list_broken_store",
                chef: ChefSummary(id: "chef_ari", username: "ari"),
                items: [],
                nextCursor: "",
                updatedAt: Self.isoString(Self.now)
            ))
            let brokenDraft = SpoonCookLogDraftState(
                recipeID: "recipe_broken_store",
                note: "Still visible.",
                nextTime: nil,
                stagedPhoto: nil,
                useAsRecipeCover: false,
                updatedAt: Self.isoString(Self.now)
            )
            brokenRouteStore.recordSpoonCookLogDraft(brokenDraft, forRecipeID: "recipe_broken_store")
            guard case .syncFailed(let brokenDraftContent, let brokenDraftMessage) = brokenRouteStore.bootstrapState else {
                Issue.record("Expected spoon draft persistence failure; got \(brokenRouteStore.bootstrapState)")
                return
            }
            #expect(brokenDraftMessage == "Cook log draft could not be saved offline.")
            #expect(brokenDraftContent.offlineIndicatorState.display == .syncFailure(errorID: "spoon-draft", retryAfter: nil))
            #expect(brokenDraftContent.spoonCookLogDraft(recipeID: "recipe_broken_store") == nil)
            let brokenCaptureDraft = try CaptureDraft.importURL(
                id: "draft_broken_capture_store",
                url: URL(string: "https://example.com/broken-capture-store")!,
                createdAt: Self.isoString(Self.now)
            )
            let brokenCaptureRetry = NativeQueuedMutation.recipeImportSubmit(
                source: try brokenCaptureDraft.importSource(),
                clientMutationID: "cm_broken_capture_retry",
                createdAt: Self.isoString(Self.now)
            )

            brokenRouteStore.recordCaptureDraft(brokenCaptureDraft)
            guard case .syncFailed(let brokenCaptureContent, let brokenCaptureMessage) = brokenRouteStore.bootstrapState else {
                Issue.record("Expected capture draft persistence failure; got \(brokenRouteStore.bootstrapState)")
                return
            }
            #expect(brokenCaptureMessage == "Capture draft could not be saved offline.")
            #expect(brokenCaptureContent.offlineIndicatorState.display == .syncFailure(errorID: "capture-draft", retryAfter: nil))

            brokenRouteStore.discardCaptureDraft(id: brokenCaptureDraft.id)
            brokenRouteStore.recordCaptureImportRetry(brokenCaptureRetry)
            brokenRouteStore.recordCaptureImportRetry(NativeQueuedMutation.profileDisplayUpdate(
                email: "ari@example.com",
                username: "ari",
                clientMutationID: "cm_broken_capture_non_import",
                createdAt: Self.isoString(Self.now)
            ))
            brokenRouteStore.recordCaptureImportBlocker(.providerSecret(retryAfterSeconds: nil))
            guard case .syncFailed(let brokenBlockerContent, let brokenBlockerMessage) = brokenRouteStore.bootstrapState else {
                Issue.record("Expected capture blocker persistence failure; got \(brokenRouteStore.bootstrapState)")
                return
            }
            #expect(brokenBlockerMessage == "Capture import blocker could not be saved offline.")
            #expect(brokenBlockerContent.offlineIndicatorState.display == .syncFailure(errorID: "capture-import-blocker", retryAfter: nil))

            let draftsBeforeBlankID = brokenDraftContent.spoonCookLogDraftsByRecipeID
            brokenRouteStore.recordSpoonCookLogDraft(brokenDraft, forRecipeID: "   ")
            #expect(brokenRouteStore.bootstrapState.contentState.spoonCookLogDraftsByRecipeID == draftsBeforeBlankID)
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

            do {
                try await queueFailureStore.queueMutation(mutation)
                Issue.record("Expected queueMutation to throw when sync store is unavailable.")
            } catch {
                #expect(String(describing: error).contains("sync store unavailable"))
            }

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
    @Test("live store surfaces sanitized support codes for signed in bootstrap API failures")
    func liveStoreSurfacesSanitizedSupportCodesForSignedInBootstrapAPIFailures() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let transportError = APITransportError(
                kind: .apiError,
                requestID: "req_bootstrap_invalid_token",
                statusCode: 401,
                apiError: APIError(
                    requestID: "req_bootstrap_invalid_token",
                    code: "invalid_token",
                    message: "Invalid API token",
                    status: 401
                ),
                retryDecision: .refreshAuthentication
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(bootstraps: [.failure(transportError)])
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, let message) = liveStore.bootstrapState else {
                Issue.record("Expected signed-in bootstrap API failure to produce syncFailed; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.offlineIndicatorState.display == .syncFailure(errorID: "bootstrap", retryAfter: nil))
            #expect(message.contains("Support code req_bootstrap_invalid_token."))
            #expect(message.contains("Reason invalid_token."))
            #expect(message.contains("HTTP 401."))
            #expect(!message.contains("accessToken"))
            #expect(!message.contains("refreshToken"))
        }
    }

    @MainActor
    @Test("live store surfaces non-retryable signed in bootstrap API failures")
    func liveStoreSurfacesNonRetryableSignedInBootstrapAPIFailures() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let transportError = APITransportError(
                kind: .apiError,
                requestID: "req_bootstrap_bad_request",
                statusCode: 400,
                apiError: APIError(
                    requestID: "req_bootstrap_bad_request",
                    code: "bad_request",
                    message: "Bad request",
                    status: 400
                ),
                retryDecision: .doNotRetry
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(bootstraps: [.failure(transportError)])
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, let message) = liveStore.bootstrapState else {
                Issue.record("Expected non-retryable bootstrap API failure to produce syncFailed; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.offlineIndicatorState.display == .syncFailure(errorID: "bootstrap", retryAfter: nil))
            #expect(message.contains("Support code req_bootstrap_bad_request."))
            #expect(message.contains("Reason bad_request."))
            #expect(message.contains("HTTP 400."))
        }
    }

    @MainActor
    @Test("live store surfaces retryable signed in bootstrap transport failures")
    func liveStoreSurfacesRetryableSignedInBootstrapTransportFailures() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = try await Self.signedInVault(accountID: "chef_ari")
            let transportError = APITransportError(
                kind: .networkFailure,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .retrySameRequest(afterSeconds: 12)
            )
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue()),
                transport: ScriptedLiveStoreSyncTransport(bootstraps: [.failure(transportError)])
            )

            await liveStore.bootstrap()

            guard case .syncFailed(let content, let message) = liveStore.bootstrapState else {
                Issue.record("Expected retryable bootstrap transport failure to produce syncFailed; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.offlineIndicatorState.display == .syncFailure(errorID: "bootstrap", retryAfter: nil))
            #expect(message == "Spoonjoy could not finish syncing your account.")
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
            #expect(content.syncConflicts == [
                NativeSyncConflict(
                    clientMutationID: "cm_sync_outcome",
                    kind: .validation,
                    serverRevision: .updatedAt("server-v2"),
                    message: "Recipe changed on another device."
                )
            ])
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
            let appendResult = try await liveStore.queueMutations([nextMutation])

            let snapshot = await syncStore.loadSnapshot()
            #expect(snapshot.queue.mutations.map(\.clientMutationID) == ["cm_existing", "cm_next"])
            #expect(appendResult.submittedClientMutationIDs == ["cm_next"])
            #expect(appendResult.drainedClientMutationIDs.isEmpty)
            #expect(appendResult.remainingSubmittedClientMutationIDs == ["cm_next"])
            #expect(appendResult.submittedConflicts.isEmpty)
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

    @Test("shell content settings surface view model covers signed-out loaded and signed-in unloaded states")
    func shellContentSettingsSurfaceViewModelCoversSignedOutLoadedAndSignedInUnloadedStates() throws {
        let signedOut = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        #expect(signedOut.settingsSurfaceViewModel.sections.map(\.id) == [.session, .environment, .offline])
        #expect(signedOut.settingsSurfaceViewModel.primaryAuthAction?.target == .login)
        #expect(signedOut.notificationAPNsSurfaceViewModel == nil)
        #expect(try signedOut.settingsSurfaceViewModel.actionPlanner.plan(.updateProfile(
            email: "signed-out@example.com",
            username: "signedout",
            clientMutationID: "cm_signed_out_settings"
        )).offlineFallbackMutation?.queueableKind == .profileDisplayUpdate)

        let session = try AuthSession(
            clientID: "client_live",
            accessToken: "sj_access_current",
            refreshToken: "sj_refresh_current",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
        let signedInWithoutSettings = NativeShellContentState.empty(
            authSessionState: .authenticated(session),
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        #expect(signedInWithoutSettings.settingsSurfaceViewModel.sections.map(\.id) == [.environment, .offline])
        #expect(signedInWithoutSettings.settingsSurfaceViewModel.primaryAuthAction == nil)
        #expect(signedInWithoutSettings.settingsSurfaceViewModel.offlineIndicator.display == .offline)
        #expect(try signedInWithoutSettings.settingsSurfaceViewModel.actionPlanner.plan(.updateProfile(
            email: "signed-in@example.com",
            username: "signedin",
            clientMutationID: "cm_signed_in_settings"
        )).queuedMutation?.queueableKind == .profileDisplayUpdate)
        let signedInOnlineWithoutSettings = signedInWithoutSettings.copy(
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        #expect(signedInOnlineWithoutSettings.settingsSurfaceViewModel.connectivity == .online)

        let settingsData = SettingsSurfaceData(
            account: SettingsAccountProfile(
                id: "chef_ari",
                email: "ari@example.com",
                username: "ari",
                photoURL: nil,
                hasPassword: true,
                linkedProviders: [],
                passkeys: []
            ),
            notifications: .disabled,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .live(requestID: "req_shell_settings", validatedAt: Self.now)
        )
        let loadedSettings = signedInWithoutSettings.copy(
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil),
            settingsSurfaceData: .some(settingsData)
        )
        #expect(loadedSettings.settingsSurfaceViewModel.sections.map(\.id).starts(with: [.profile, .security]))
        #expect(loadedSettings.settingsSurfaceViewModel.profileDraft?.username == "ari")
        #expect(loadedSettings.settingsSurfaceViewModel.connectivity == .online)
        #expect(try loadedSettings.settingsSurfaceViewModel.actionPlanner.plan(.updateProfile(
            email: "loaded@example.com",
            username: "loaded",
            clientMutationID: "cm_loaded_settings"
        )).offlineFallbackMutation?.queueableKind == .profileDisplayUpdate)
    }

    @Test("shell content restores notification APNs status from durable cache")
    func shellContentRestoresNotificationAPNsStatusFromDurableCache() throws {
        let validatedAt = Self.now.addingTimeInterval(-600)
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: true
        )
        let notificationDomain = NativeCacheDomain.notificationPreferences
        let apnsDomain = NativeCacheDomain.apnsStatus
        let cacheSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "chef_ari",
            environment: .production,
            createdAt: validatedAt,
            records: [
                try NativeCacheRecord(
                    id: notificationDomain.stableRecordID,
                    metadata: NativeCacheRecordMetadata(
                        accountID: "chef_ari",
                        environment: .production,
                        schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                        domain: notificationDomain,
                        fetchedAt: validatedAt,
                        lastValidatedAt: validatedAt,
                        sourceEndpoint: "/api/v1/me/notification-preferences",
                        serverRevision: .etag("\"notification-preferences-v2\"")
                    ),
                    payload: .notificationPreferenceState(preferences)
                ),
                try NativeCacheRecord(
                    id: apnsDomain.stableRecordID,
                    metadata: NativeCacheRecordMetadata(
                        accountID: "chef_ari",
                        environment: .production,
                        schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                        domain: apnsDomain,
                        fetchedAt: validatedAt,
                        lastValidatedAt: validatedAt,
                        sourceEndpoint: "/api/v1/me/apns-devices",
                        serverRevision: .etag("\"apns-device-v2\"")
                    ),
                    payload: .apnsStatus(deviceID: "device_apns_restore", registrationState: .registered)
                )
            ],
            dismissedIndicators: []
        )
        let content = NativeShellContentState.restored(
            cacheSnapshot: cacheSnapshot,
            syncSnapshot: NativeSyncSnapshot(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue(),
                cachedRecords: [],
                tombstones: []
            ),
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        let viewModel = try #require(content.notificationAPNsSurfaceViewModel)

        #expect(content.notificationAPNsSurfaceData?.apnsRegistration?.deviceID == "device_apns_restore")
        #expect(viewModel.notificationDraft == preferences)
        #expect(viewModel.apnsRegistration == APNsRegistrationSummary(
            deviceID: "device_apns_restore",
            platform: NativeAPNSRuntimeDefaults.currentPlatform,
            environment: NativeAPNSRuntimeDefaults.currentEnvironment,
            registrationState: .registered,
            lastValidatedAt: validatedAt
        ))
        #expect(viewModel.deliveryBlockerState == .developmentOnly(.localValidation))
        #expect(viewModel.productionBlocker == .localValidation)
        let onlineContent = content.copy(
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        #expect(onlineContent.notificationAPNsSurfaceViewModel?.connectivity == .online)
    }

    @MainActor
    @Test("live store records notification APNs Apple Developer Program blocker")
    func liveStoreRecordsNotificationAPNsAppleDeveloperProgramBlocker() async throws {
        try await withTemporaryLiveStoreDirectory { directory in
            let vault = InMemoryTokenVault()
            let syncStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
            let liveStore = Self.liveStore(
                directory: directory,
                vault: vault,
                syncStore: syncStore,
                transport: CapturingLiveStoreSyncTransport(bootstrap: .success(cursor: nil, tombstones: []))
            )

            liveStore.recordNotificationAPNsBlocker(.localValidation)

            guard case .blocker(let content) = liveStore.bootstrapState else {
                Issue.record("Expected notification APNs blocker state; got \(liveStore.bootstrapState)")
                return
            }

            #expect(content.offlineIndicatorState.display == .blocker(.appleDeveloperProgram(capability: AppleDeveloperProgramBlocker.capabilityName)))
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
                ),
                NativeSyncCachedRecord(
                    kind: .profile,
                    resourceID: "chef_optimistic",
                    payload: .object(["username": .string("optimistic-chef")]),
                    serverRevision: .optimistic("cm_profile_drain")
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

        let optimisticProfileResult = try #require(syncedContent.profileSurfaceResult(identifier: "chef_optimistic"))
        if case .cache(let serverRevision, let lastValidatedAt) = optimisticProfileResult.source {
            #expect(serverRevision == .localRevision("optimistic:cm_profile_drain"))
            #expect(lastValidatedAt == .distantPast)
        } else {
            Issue.record("Expected optimistic profile to expose a cache source; got \(optimisticProfileResult.source)")
        }

        let imageOnlyCaptureSnapshot = try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "signed-out",
            environment: .production,
            createdAt: Self.now,
            records: [
                try Self.cacheRecord(
                    domain: .captureDraft(id: "draft_blank_text"),
                    payload: .captureDraft(id: "draft_blank_text", source: .text("   "))
                ),
                try Self.cacheRecord(
                    domain: .captureDraft(id: "draft_image_only"),
                    payload: .captureDraft(id: "draft_image_only", source: .imageAsset("local-image-only"))
                )
            ],
            dismissedIndicators: []
        )
        let imageOnlyContent = NativeShellContentState.restored(
            cacheSnapshot: imageOnlyCaptureSnapshot,
            syncSnapshot: NativeSyncSnapshot(
                accountID: "signed-out",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue()
            ),
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: .synced(lastSyncedAt: Self.now)
        )
        #expect(imageOnlyContent.captureDraft == nil)
    }

    @Test("shell content folds synced spoon records and tombstones into restored recipes")
    func shellContentFoldsSyncedSpoonRecordsAndTombstonesIntoRestoredRecipes() throws {
        let oldSummarySpoon = RecipeDetailRecentSpoon(
            id: "spoon_summary_replace",
            chefID: "chef_ari",
            recipeID: "recipe_synced_spoons",
            cookedAt: Self.isoString(Self.now.addingTimeInterval(-60)),
            photoURL: nil,
            note: "Old summary note.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(-60)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(-60)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let tombstonedSummarySpoon = RecipeDetailRecentSpoon(
            id: "spoon_summary_deleted",
            chefID: "chef_ari",
            recipeID: "recipe_synced_spoons",
            cookedAt: Self.isoString(Self.now.addingTimeInterval(-50)),
            photoURL: nil,
            note: "Delete me.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(-50)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(-50)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let recipe = Self.sampleRecipe(
            id: "recipe_synced_spoons",
            title: "Synced Spoon Pasta",
            recentSpoons: [oldSummarySpoon, tombstonedSummarySpoon]
        )
        let unchangedSpoon = RecipeDetailRecentSpoon(
            id: "spoon_summary_unchanged",
            chefID: "chef_ari",
            recipeID: "recipe_unchanged_spoons",
            cookedAt: Self.isoString(Self.now.addingTimeInterval(-10)),
            photoURL: nil,
            note: "Already current.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(-10)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(-10)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let unchangedRecipe = Self.sampleRecipe(
            id: "recipe_unchanged_spoons",
            title: "Unchanged Spoon Pasta",
            recentSpoons: [unchangedSpoon]
        )
        let syncedReplacement = RecipeDetailRecentSpoon(
            id: oldSummarySpoon.id,
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: Self.isoString(Self.now.addingTimeInterval(10)),
            photoURL: URL(string: "https://spoonjoy.app/photos/spoons/synced-replacement.jpg"),
            note: "Synced replacement note.",
            nextTime: "Use less salt.",
            deletedAt: nil,
            createdAt: oldSummarySpoon.createdAt,
            updatedAt: Self.isoString(Self.now.addingTimeInterval(10)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let syncedNewSpoon = RecipeDetailRecentSpoon(
            id: "spoon_synced_new",
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: Self.isoString(Self.now.addingTimeInterval(30)),
            photoURL: nil,
            note: "Other-device cook.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(30)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(30)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let syncedNewTieSpoon = RecipeDetailRecentSpoon(
            id: "spoon_synced_new_z",
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: syncedNewSpoon.cookedAt,
            photoURL: nil,
            note: "Other-device cook with matching timestamp.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: syncedNewSpoon.createdAt,
            updatedAt: syncedNewSpoon.updatedAt,
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let syncedUndatedNewerSpoon = RecipeDetailRecentSpoon(
            id: "spoon_synced_undated_newer",
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: nil,
            photoURL: nil,
            note: "Undated newer cook.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(5)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(5)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let syncedUndatedOlderSpoon = RecipeDetailRecentSpoon(
            id: "spoon_synced_undated_older",
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: nil,
            photoURL: nil,
            note: "Undated older cook.",
            nextTime: nil,
            deletedAt: nil,
            createdAt: Self.isoString(Self.now.addingTimeInterval(4)),
            updatedAt: Self.isoString(Self.now.addingTimeInterval(4)),
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        let content = NativeShellContentState.restored(
            cacheSnapshot: try NativeDurableCacheSnapshot(
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                accountID: "chef_ari",
                environment: .production,
                createdAt: Self.now,
                records: [],
                dismissedIndicators: []
            ),
            syncSnapshot: NativeSyncSnapshot(
                accountID: "chef_ari",
                environment: .production,
                checkpoint: nil,
                queue: NativeMutationQueue(),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .recipe, resourceID: recipe.id, payload: try Self.jsonValue(recipe), serverRevision: .updatedAt(recipe.updatedAt)),
                    NativeSyncCachedRecord(kind: .recipe, resourceID: unchangedRecipe.id, payload: try Self.jsonValue(unchangedRecipe), serverRevision: .updatedAt(unchangedRecipe.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: syncedReplacement.id, payload: try Self.jsonValue(syncedReplacement), serverRevision: .updatedAt(syncedReplacement.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: syncedNewSpoon.id, payload: try Self.jsonValue(syncedNewSpoon), serverRevision: .updatedAt(syncedNewSpoon.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: syncedNewTieSpoon.id, payload: try Self.jsonValue(syncedNewTieSpoon), serverRevision: .updatedAt(syncedNewTieSpoon.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: syncedUndatedNewerSpoon.id, payload: try Self.jsonValue(syncedUndatedNewerSpoon), serverRevision: .updatedAt(syncedUndatedNewerSpoon.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: syncedUndatedOlderSpoon.id, payload: try Self.jsonValue(syncedUndatedOlderSpoon), serverRevision: .updatedAt(syncedUndatedOlderSpoon.updatedAt)),
                    NativeSyncCachedRecord(kind: .spoon, resourceID: unchangedSpoon.id, payload: try Self.jsonValue(unchangedSpoon), serverRevision: .updatedAt(unchangedSpoon.updatedAt))
                ],
                tombstones: [
                    NativeSyncTombstone(
                        resourceType: .spoon,
                        resourceID: tombstonedSummarySpoon.id,
                        parentResourceID: recipe.id,
                        title: nil,
                        deletedAt: Self.isoString(Self.now.addingTimeInterval(20)),
                        updatedAt: Self.isoString(Self.now.addingTimeInterval(20))
                    ),
                    NativeSyncTombstone(
                        resourceType: .recipe,
                        resourceID: "recipe_not_a_spoon_tombstone",
                        parentResourceID: nil,
                        title: nil,
                        deletedAt: Self.isoString(Self.now.addingTimeInterval(25)),
                        updatedAt: Self.isoString(Self.now.addingTimeInterval(25))
                    )
                ]
            ),
            appSnapshot: nil,
            authSessionState: .signedOut,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .offline, dismissal: nil)
        )
        let restoredRecipe = try #require(content.recipe(id: recipe.id))

        #expect(restoredRecipe.recentSpoons.map(\.id) == [
            "spoon_synced_new_z",
            "spoon_synced_new",
            "spoon_summary_replace",
            "spoon_synced_undated_newer",
            "spoon_synced_undated_older"
        ])
        #expect(restoredRecipe.recentSpoons.first { $0.id == oldSummarySpoon.id }?.note == "Synced replacement note.")
        #expect(restoredRecipe.recentSpoons.first { $0.id == tombstonedSummarySpoon.id } == nil)
        #expect(content.recipe(id: unchangedRecipe.id)?.recentSpoons == unchangedRecipe.recentSpoons)
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
                "NativeShoppingEntityIndexPurgeOperation",
                "NativeShoppingEntityIndexPurgeRequest",
                "appStateStoreProvider",
                "restoredRoute",
                "trustedAccountID",
                "bindAccountID",
                "shoppingEntityIndexPurge",
                "shoppingEntityPurgeRequests",
                "purgeShoppingEntityIdentifiers",
                "APIClientConfiguration",
                "loadOrCreate",
                "restoreFromCache",
                "loadSnapshot",
                "bootstrapFromLiveAPI",
                "NativeLiveAppStoreTelemetry.bootstrapFailed",
                "NativeLiveAppStoreTelemetry.bootstrapOffline",
                "native_app_bootstrap_failed",
                "failureMessage(for:",
                "request_id",
                "account_bound",
                "has_cache_content",
                "validSession()",
                "recipeEditorAPITransport",
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
                "dismissOfflineIndicator",
                "syncFailureBodyText",
                "syncFailureDiagnosticText",
                "Support code:",
                "navigation.route == .settings",
                "settingsContent(contentState: contentState, syncFailureMessage: message)",
                "NavigationStack",
                "openKitchenFromStandaloneSettings",
                "Label(\"Kitchen\", systemImage: \"chevron.left\")",
                "Label(\"Retry\", systemImage: \"arrow.clockwise\")",
                "onRetrySync:",
                "navigation.navigate(to: .settings)",
                "purgeShoppingEntityIdentifiers",
                "shoppingEntityIndexPurge",
                "SpoonjoySpotlightIndexer().delete",
                "domainIdentifiers"
            ],
            forbids: [
                "NativeDeferredSyncTransport",
                "try? FileBackedNativeSyncStore",
                "NativeAppSnapshot.bootstrap",
                "ShoppingListState.decodeFromBundle()",
                "hasCompletedFirstRun",
                "completeFirstRun(opening:",
                "openKitchen: { completeFirstRun",
                ".safeAreaInset(edge: .bottom)",
                "Text(message)"
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
                "spotlightIndexDocuments",
                "contentState.captureDraft",
                "NativeQueuedMutation",
                "queueMutation",
                "queueMutations",
                "discardQueuedMutation",
                "let pendingImportClientMutationIDs = contentState.queuedMutations",
                "$0.recipeImportSource == draftImportSource",
                "try await discardQueuedMutation(pendingImportClientMutationID)",
                "executeRecipeEditorRequest",
                "syncTriggerCoordinator",
                "OfflineStatusView(display:",
                "offlineIndicatorState",
                "dismissOfflineIndicator",
                "spotlightIdentityComponent",
                "document.contentDescription",
                "document.keywords",
                "document.route.stateIdentifier",
                "SettingsView(",
                "settingsViewModel",
                "onRetrySync:",
                "detailContentWithShellStatus",
                "shellOfflineStatusBar",
                "VStack(spacing: 0)"
            ],
            forbids: [
                "RecipeFixtureCatalog.decodeFromBundle()",
                "CookbookFixtureCatalog.decodeFromBundle()",
                "KitchenFixtureState.decodeFromBundle()",
                "KitchenFixtureState.bootstrapFallback",
                "SettingsState(\n                auth: .signedOut",
                "NativeQueuedMutation(",
                "startedAt: \"2026-06-16T11:45:00.000Z\"",
                ".safeAreaInset(edge: .bottom)"
            ]
        )
    }

    @Test("settings unavailable account state offers live sync retry instead of a dead offline cache message")
    func settingsUnavailableAccountStateOffersLiveSyncRetry() throws {
        let relativePath = "Apps/Spoonjoy/Shared/Views/SettingsView.swift"
        let content = uncommentedSwift(try readRepoFile(relativePath))

        expectContent(
            content,
            in: relativePath,
            contains: [
                "var onRetrySync: @MainActor @Sendable () async -> Void",
                "var syncFailureDiagnosticText: String?",
                "Account sync has not finished yet.",
                "latest sync did not finish loading your profile",
                "Text(syncFailureDiagnosticText)",
                "Try Sync Again",
                "Task { await onRetrySync() }",
                "Label(\"Try Sync Again\", systemImage: \"arrow.clockwise\")",
                "effectiveOfflineIndicator(surface.offlineIndicator.display)"
            ],
            forbids: [
                "Account data has not loaded yet.",
                "Account settings need a live load before they are available offline."
            ]
        )
    }

    @Test("recipe editor app surface drains online structural batches and labels conflict discard honestly")
    func recipeEditorAppSurfaceDrainsOnlineStructuralBatchesAndLabelsConflictDiscardHonestly() throws {
        let editor = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"))
        let platform = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"))
        let root = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"))

        expectContent(
            editor,
            in: "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift",
            contains: [
                "mutationsDidQueue: @escaping @MainActor @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult",
                "let batchResult = try await mutationsDidQueue(mutations, editor.connectivity == .online)",
                "submittedBatchNeedsAttention(batchResult, mutations: mutations)",
                "Button(conflictBanner.discardActionTitle)",
                "conflictDidDiscardLocalChange"
            ],
            forbids: [
                "Button(\"Keep Draft\")",
                "keepLocalDraft",
                "conflictDidKeepDraft"
            ]
        )
        expectContent(
            platform,
            in: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
            contains: [
                "queueMutations: @escaping @Sendable ([NativeQueuedMutation], Bool) async throws -> NativeQueuedMutationBatchResult",
                "mutation.optimisticRecipeID == recipeID",
                "conflictDidDiscardLocalChange: discardRecipeEditorLocalChange"
            ]
        )
        expectContent(
            root,
            in: "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
            contains: [
                "queueMutations: { mutations, drainImmediately in",
                "queueMutations(mutations, drainImmediately: drainImmediately)",
                "cacheEnvironment: Self.defaultCacheEnvironment(configuration: configuration)",
                "private static func defaultCacheEnvironment(configuration: APIClientConfiguration) -> NativeCacheEnvironment",
                #"host == "localhost""#,
                "return .preview"
            ],
            forbids: [
                "cacheEnvironment: .production,"
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
        let platformNavigation = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"))
        let liveStore = uncommentedSwift(try readRepoFile("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift"))

        expectContent(
            signedOut,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "NativeAuthSessionRepository",
                "SignInWithAppleButton",
                "NativeAppleSignInCredential",
                "NativePasswordSignInCredential",
                "handleAppleSignInCredential",
                "handlePasswordSignInCredential",
                "restoreState",
                "revokeAndLogout",
                "isSigningIn",
                "emailOrUsername",
                "spoonjoyCredentialIdentifierEntry",
                "textInputAutocapitalization(.never)",
                "keyboardType(.emailAddress)",
                "native password sign-in",
                "passwordSignInFailureMessage",
                "SpoonjoyIdentityMark",
                "#if os(macOS)",
                "HStack(spacing: 0)",
                "signedOutBrandColumn",
                "credentialPanel",
                ".frame(minWidth: 900, minHeight: 620)",
                "#else",
                "GeometryReader",
                "ScrollView",
                #"Image("SpoonjoyMark")"#,
                "currentAppleSignInCapability",
                "SecTaskCopyValueForEntitlement",
                #"value == "Default""#,
                "#elseif SPOONJOY_SIGNED_APPLE_AUTH",
                "return .missingEntitlement",
                "signInFailureMessage",
                "Sign in with Apple needs a signed Spoonjoy build",
                "authorization_request_started",
                "backend_exchange_started",
                "NativeAppleSignInTelemetry.logFailure"
            ],
            forbids: [
                "offlineIndicatorDisplay",
                "OfflineStatusView(display:",
                "safeAreaInset(edge: .bottom)",
                "Open Kitchen",
                "keep offline fixtures nearby",
                "Could not finish sign-in: \\(error)",
                "SpoonjoyLogoPath"
            ]
        )

        let appleTelemetry = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift"))
        expectContent(
            appleTelemetry,
            in: "Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift",
            contains: [
                "Logger(subsystem: \"app.spoonjoy\", category: \"auth.apple\")",
                "diagnosticCode(for error: Error)",
                "providerCode"
            ],
            forbids: []
        )
        let markSource = try readRepoFile("Apps/Spoonjoy/Shared/Assets.xcassets/SpoonjoyMark.imageset/source.svg")
        #expect(markSource.contains(#"viewBox="0 0 500 300""#))
        #expect(!markSource.contains("<rect"), "SpoonjoyMark must be a transparent UI glyph, not the square app icon tile.")
        let appIconSource = try readRepoFile("Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/source.svg")
        #expect(appIconSource.contains("<rect"), "The app icon should remain a square tile.")

        expectContent(
            settings,
            in: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
            contains: [
                "OfflineStatusView(display:",
                "viewModel.offlineIndicatorDisplay",
                "viewModel.dismissOfflineIndicator",
                "viewModel.authSessionState",
                "viewModel.environmentSwitcher",
                "ScrollViewReader",
                "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS",
                "SPOONJOY_SCREENSHOT_PROOF_PATH",
                "writeScreenshotProof(",
                #""source": "SettingsView""#,
                "settings-section-notification-apns-device",
                "proxy.scrollTo(Self.notificationsFocusID, anchor: .top)",
                "shellOfflineIndicatorState",
                "effectiveOfflineIndicator(",
                "!shellOfflineIndicatorState.display.informationalOnly",
                "localDisplay.informationalOnly"
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
                "onDismiss",
                "if let onDismiss"
            ],
            forbids: [
                "legacyStatusLabel"
            ]
        )
        expectContent(
            platformNavigation,
            in: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                contains: [
                    "RecipeDetailRouteView(",
                    "RecipeEditorView(",
                    "shellOfflineIndicatorState: offlineIndicatorState",
                    "case .synced, .dismissed:",
                    "case .offline, .stale, .queuedWork, .syncFailure, .conflict, .blocker, .destructiveConfirmation:",
                    "RecipeCoverControlsRouteView(",
                    "CookbooksView(",
                    "CookbookDetailRouteView(",
                "ProfileRouteView(",
                "ProfileGraphRouteView(",
                "ShoppingListView(",
                "SearchView(",
                "NotificationAPNsSettingsView(",
                "onDismissOfflineIndicator: dismissOfflineIndicator"
            ]
        )
        expectContent(
            liveStore,
            in: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
            contains: [
                "emptyContent(authSessionState: authState, display: .synced)",
                "catch let error as APITransportError where error.isOffline",
                "OfflineIndicatorState(display: .offline, dismissal: nil)"
            ]
        )
        let routeOwnedOfflineViews = [
            "Apps/Spoonjoy/Shared/Views/SearchView.swift",
            "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
            "Apps/Spoonjoy/Shared/Views/ProfileView.swift",
            "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
            "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
            "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift",
            "Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift",
            "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift",
            "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift"
        ]
        for relativePath in routeOwnedOfflineViews {
            let source = uncommentedSwift(try readRepoFile(relativePath))
            var requiredTokens = [
                "onDismissOfflineIndicator",
                "OfflineStatusView(display:",
                "onDismiss: onDismissOfflineIndicator"
            ]
            if relativePath.hasSuffix("RecipeEditorView.swift") {
                requiredTokens.append(contentsOf: [
                    "shellOfflineIndicatorState",
                    "effectiveOfflineIndicator"
                ])
            }
            if relativePath.hasSuffix("RecipeDetailView.swift") {
                requiredTokens.append(
                    "let performShoppingAction: @MainActor @Sendable (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome\n    let onDismissOfflineIndicator: @MainActor @Sendable () -> Void"
                )
            }
            expectContent(
                source,
                in: relativePath,
                contains: requiredTokens,
                forbids: [
                    "OfflineStatusView(display: viewModel.offlineIndicator.display)",
                    "OfflineStatusView(display: list.offlineIndicator.display)",
                    "OfflineStatusView(display: blocker.offlineIndicatorDisplay)",
                    "OfflineStatusView(display: providerBlocker.offlineIndicatorDisplay)"
                ]
            )
        }
        let settingsViewSource = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/SettingsView.swift"))
        expectContent(
            settingsViewSource,
            in: "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
            contains: [
                "var onDismissOfflineIndicator: @MainActor @Sendable () -> Void = {}",
                "NotificationAPNsSettingsView(",
                "onDismissOfflineIndicator: onDismissOfflineIndicator"
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

    func saveQueue(
        _: NativeMutationQueue,
        accountID _: String?,
        environment _: NativeCacheEnvironment?,
        upsertingCachedRecords _: [NativeSyncCachedRecord],
        deletingCachedRecordKeys _: Set<String>
    ) throws {}

    func loadCheckpoint() throws -> NativeSyncCheckpoint {
        throw NativeSyncStoreError.missingCheckpoint
    }

    func saveCheckpoint(_: NativeSyncCheckpoint) throws {}

    func clearCheckpoint() throws {}

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

private actor StaticNativeSyncTriggerRunner: NativeSyncTriggerRunning {
    let report: NativeSyncReport
    private var recordedTriggers: [NativeCacheRevalidationTrigger] = []

    init(report: NativeSyncReport) {
        self.report = report
    }

    func bootstrapAndDrain(
        configuration _: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger,
        scope _: NativeSyncExecutionScope
    ) async throws -> NativeSyncReport {
        recordedTriggers.append(trigger)
        return report
    }

    func triggers() -> [NativeCacheRevalidationTrigger] {
        recordedTriggers
    }
}

private actor CapturingShoppingEntityIndexPurge {
    private var recordedRequests: [NativeShoppingEntityIndexPurgeRequest] = []

    func purge(_ request: NativeShoppingEntityIndexPurgeRequest) {
        recordedRequests.append(request)
    }

    func requests() -> [NativeShoppingEntityIndexPurgeRequest] {
        recordedRequests
    }
}

private actor CapturingSpoonEntityIndexPurge {
    private var recordedRequests: [NativeSpoonEntityIndexPurgeRequest] = []

    func purge(_ request: NativeSpoonEntityIndexPurgeRequest) {
        recordedRequests.append(request)
    }

    func requests() -> [NativeSpoonEntityIndexPurgeRequest] {
        recordedRequests
    }
}

private actor CapturingCaptureDraftEntityIndexPurge {
    private var recordedRequests: [NativeCaptureDraftEntityIndexPurgeRequest] = []

    func purge(_ request: NativeCaptureDraftEntityIndexPurgeRequest) {
        recordedRequests.append(request)
    }

    func requests() -> [NativeCaptureDraftEntityIndexPurgeRequest] {
        recordedRequests
    }
}

private actor CapturingChefProfileEntityIndexPurge {
    private var recordedRequests: [NativeChefProfileEntityIndexPurgeRequest] = []

    func purge(_ request: NativeChefProfileEntityIndexPurgeRequest) {
        recordedRequests.append(request)
    }

    func requests() -> [NativeChefProfileEntityIndexPurgeRequest] {
        recordedRequests
    }
}

private actor CapturingRecipeCookbookEntityIndexPurge {
    private var recordedRequests: [NativeRecipeCookbookEntityIndexPurgeRequest] = []

    func purge(_ request: NativeRecipeCookbookEntityIndexPurgeRequest) {
        recordedRequests.append(request)
    }

    func requests() -> [NativeRecipeCookbookEntityIndexPurgeRequest] {
        recordedRequests
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

private struct RefreshingRecipeEditorAPITransport: SpoonjoyAPITransport {
    let refresher: any APIAuthenticationRefresher
    let expectedMethod: APIRequestMethod
    let expectedPathComponents: [String]

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        guard request.method == expectedMethod,
              request.pathComponents == expectedPathComponents else {
            throw NativeLiveStoreTestError.unexpectedRequest
        }
        guard configuration.bearerToken == "sj_access_refreshed" else {
            throw NativeLiveStoreTestError.unexpectedBearerToken(configuration.bearerToken)
        }

        let refreshed = try await refresher.refreshedConfiguration(
            after: APIError(
                requestID: "recipe-editor-refresh",
                code: "UNAUTHENTICATED",
                message: "Refresh editor auth.",
                status: 401
            ),
            configuration: configuration
        )
        guard refreshed.bearerToken == "sj_access_refreshed" else {
            throw NativeLiveStoreTestError.unexpectedBearerToken(refreshed.bearerToken)
        }
        guard let data = JSONValue.object(["saved": .bool(true)]) as? Value else {
            throw NativeLiveStoreTestError.unexpectedEnvelopeType
        }
        return APIEnvelope(requestID: "recipe-editor-ok", data: data)
    }
}

private struct CaptureImportAPITransport: SpoonjoyAPITransport {
    let importedRecipe: Recipe

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        guard request.method == .post,
              request.pathComponents == ["api", "v1", "recipes", "import"] else {
            throw NativeLiveStoreTestError.unexpectedRequest
        }
        guard configuration.bearerToken == "sj_access_current" else {
            throw NativeLiveStoreTestError.unexpectedBearerToken(configuration.bearerToken)
        }

        let responseData = try JSONEncoder().encode(RecipeImportTestResponse(recipe: importedRecipe))
        let response = try JSONDecoder().decode(Value.self, from: responseData)
        return APIEnvelope(requestID: "capture-import-ok", data: response)
    }
}

private struct RecipeImportTestResponse: Encodable {
    let recipe: Recipe
}

private struct SettingsSurfaceFetchCall: Equatable, Sendable {
    let accountID: String
    let environment: NativeCacheEnvironment
    let bearerToken: String?
    let existingRecordCount: Int
}

private actor SettingsSurfaceFetchRecorder {
    private var recordedCalls: [SettingsSurfaceFetchCall] = []

    func record(accountID: String, environment: NativeCacheEnvironment, bearerToken: String?, existingRecordCount: Int) {
        recordedCalls.append(SettingsSurfaceFetchCall(
            accountID: accountID,
            environment: environment,
            bearerToken: bearerToken,
            existingRecordCount: existingRecordCount
        ))
    }

    func calls() -> [SettingsSurfaceFetchCall] {
        recordedCalls
    }
}

private struct SettingsActionAPIRequest: Equatable, Sendable {
    let method: APIRequestMethod
    let path: String
    let bearerToken: String?
}

private actor SettingsActionAPITransportRecorder {
    private var recordedRequests: [SettingsActionAPIRequest] = []

    func record(method: APIRequestMethod, path: String, bearerToken: String?) {
        recordedRequests.append(SettingsActionAPIRequest(method: method, path: path, bearerToken: bearerToken))
    }

    func requests() -> [SettingsActionAPIRequest] {
        recordedRequests
    }
}

private struct RecordingSettingsActionAPITransport: SpoonjoyAPITransport {
    let recorder: SettingsActionAPITransportRecorder

    init(refresher _: any APIAuthenticationRefresher, recorder: SettingsActionAPITransportRecorder) {
        self.recorder = recorder
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let apiRequest = try request.urlRequest(configuration: configuration)
        await recorder.record(method: apiRequest.method, path: apiRequest.url.path, bearerToken: configuration.bearerToken)

        if Value.self == JSONValue.self,
           let data = JSONValue.object(["saved": .bool(true)]) as? Value {
            return APIEnvelope(requestID: "settings-action-ok", data: data)
        }
        if Value.self == SettingsCreatedAPIToken.self,
           let data = SettingsCreatedAPIToken(
            token: "sj_created_settings",
            credential: SettingsAPITokenSummary(
                id: "cred_settings_created",
                name: "Kitchen Token",
                tokenPrefix: "sj_created",
                scopes: ["recipes:read"],
                createdAt: "2026-06-28T00:00:00.000Z",
                updatedAt: "2026-06-28T00:00:00.000Z",
                lastUsedAt: nil,
                revokedAt: nil,
                expiresAt: nil
            )
           ) as? Value {
            return APIEnvelope(requestID: "settings-token-created", data: data)
        }

        throw NativeLiveStoreTestError.unexpectedEnvelopeType
    }
}

private struct NoopRecipeEditorAPIRefresher: APIAuthenticationRefresher {
    func refreshedConfiguration(
        after _: APIError,
        configuration: APIClientConfiguration
    ) async throws -> APIClientConfiguration {
        configuration
    }
}

private actor NativeTelemetryRecorder {
    private var events: [NativeTelemetryEvent] = []
    private var configurations: [APIClientConfiguration] = []

    func record(_ event: NativeTelemetryEvent, configuration: APIClientConfiguration) {
        events.append(event)
        configurations.append(configuration)
    }

    func recordedEvents() -> [NativeTelemetryEvent] {
        events
    }

    func recordedConfigurations() -> [APIClientConfiguration] {
        configurations
    }
}

private enum NativeLiveStoreTestError: Error, CustomStringConvertible {
    case missingFile(String)
    case processFailed(String)
    case unexpectedRequest
    case unexpectedBearerToken(String?)
    case unexpectedEnvelopeType

    var description: String {
        switch self {
        case .missingFile(let path):
            "Missing repo file: \(path)"
        case .processFailed(let output):
            output
        case .unexpectedRequest:
            "Unexpected recipe editor request."
        case .unexpectedBearerToken(let token):
            "Unexpected bearer token: \(token ?? "nil")"
        case .unexpectedEnvelopeType:
            "Unexpected recipe editor envelope decode type."
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
        bootstrapMode: NativeLiveAppBootstrapMode = .liveFirst
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
            recipeEditorAPITransport: recipeEditorAPITransport,
            settingsSurfaceFetch: settingsSurfaceFetch,
            stagedMediaDirectory: stagedMediaDirectory,
            shoppingEntityIndexPurge: shoppingEntityIndexPurge,
            spoonEntityIndexPurge: spoonEntityIndexPurge,
            captureDraftEntityIndexPurge: captureDraftEntityIndexPurge,
            chefProfileEntityIndexPurge: chefProfileEntityIndexPurge,
            recipeCookbookEntityIndexPurge: recipeCookbookEntityIndexPurge,
            nativeTelemetryReport: nativeTelemetryReport,
            nativeTelemetryMetadata: nativeTelemetryMetadata,
            bootstrapMode: bootstrapMode,
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
        cookbook: Cookbook? = nil,
        shoppingItem: ShoppingListItem?,
        accountID: String = "client_live",
        environment: NativeCacheEnvironment = .production
    ) throws -> NativeSyncData {
        var entries = [
            NativeSyncEntry(
                action: .upsert,
                kind: .recipe,
                resourceID: recipe.id,
                updatedAt: recipe.updatedAt,
                payload: try jsonValue(recipe),
                tombstone: nil
            )
        ]
        if let cookbook {
            entries.append(NativeSyncEntry(
                action: .upsert,
                kind: .cookbook,
                resourceID: cookbook.id,
                updatedAt: cookbook.updatedAt,
                payload: try jsonValue(cookbook),
                tombstone: nil
            ))
        }
        if let shoppingItem {
            entries.append(NativeSyncEntry(
                action: .upsert,
                kind: .shoppingItem,
                resourceID: shoppingItem.id,
                updatedAt: shoppingItem.updatedAt,
                payload: try jsonValue(shoppingItem),
                tombstone: nil
            ))
        }
        return NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: accountID,
                environment: environment,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: isoString(now),
                lastValidatedAt: isoString(now)
            ),
            entries: entries,
            nextCursor: PaginationCursor(rawValue: "v1.live.after"),
            hasMore: false
        )
    }

    static func sampleRecipe(
        id: String,
        title: String,
        ingredients: [RecipeIngredient] = [],
        recentSpoons: [RecipeDetailRecentSpoon] = []
    ) -> Recipe {
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
                    ingredients: ingredients
                )
            ],
            cookbooks: [],
            recentSpoons: recentSpoons
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

    static func profileSummary(id: String, username: String) -> ProfileSummary {
        let href = "/users/\(AppRoute.encodedProfileIdentifier(username))"
        return ProfileSummary(
            id: id,
            username: username,
            photoURL: nil,
            joinedLabel: "Joined Spoonjoy",
            href: href,
            canonicalURL: URL(string: "https://spoonjoy.app\(href)")!
        )
    }

    static func profileCacheRecord(
        id: String,
        username: String,
        accountID: String,
        environment: NativeCacheEnvironment
    ) throws -> NativeCacheRecord {
        try cacheRecord(
            domain: .profile(id: id),
            payload: .profile(id: id, username: username),
            accountID: accountID,
            environment: environment
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

private struct SettingsRefreshProbeError: Error {}

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
