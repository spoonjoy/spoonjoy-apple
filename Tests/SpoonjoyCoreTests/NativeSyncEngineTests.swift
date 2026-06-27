import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native sync engine and mutation queue")
struct NativeSyncEngineTests {
    private let now = Date(timeIntervalSince1970: 1_780_010_000)
    private let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_access"
    )
    private var boundScope: NativeSyncExecutionScope {
        NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .local)
    }

    @Test("bootstrap request and sync envelope use the private /me/sync contract")
    func bootstrapRequestAndSyncEnvelopeUsePrivateSyncContract() throws {
        let defaultRequest = try NativeSyncBootstrapRequest.defaultRequest(cursor: nil)
            .urlRequest(configuration: configuration)
        let cursorRequest = try NativeSyncBootstrapRequest.defaultRequest(cursor: PaginationCursor(rawValue: "v1.cursor.before"))
            .urlRequest(configuration: configuration)
        let envelope = try APIEnvelope<NativeSyncData>.decode(Self.nativeSyncEnvelope)

        assertRequest(defaultRequest, method: .get, path: "/api/v1/me/sync", queryItems: [URLQueryItem(name: "limit", value: "20")])
        assertRequest(
            cursorRequest,
            method: .get,
            path: "/api/v1/me/sync",
            queryItems: [
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "cursor", value: "v1.cursor.before")
            ]
        )
        #expect(defaultRequest.body == nil)
        #expect(cursorRequest.body == nil)
        #expect(defaultRequest.responseCachePolicy == APIResponseCachePolicy.privateNoStore)
        #expect(envelope.requestID == "req_native_sync")
        #expect(envelope.data.freshness.accountID == "chef_ari")
        #expect(envelope.data.freshness.environment == .local)
        #expect(envelope.data.freshness.schemaVersion == 1)
        #expect(envelope.data.freshness.sourceEndpoint == "/api/v1/me/sync")
        #expect(envelope.data.nextCursor?.rawValue == "v1.cursor.after")
        #expect(envelope.data.hasMore == false)
        #expect(envelope.data.entries.map(\.kind) == [.profile, .recipe, .cookbook, .spoon, .shoppingItem])
        #expect(envelope.data.entries.map(\.action) == [.upsert, .delete, .delete, .delete, .delete])
        #expect(envelope.data.entries[0].payload == .object(["username": .string("ari")]))
        #expect(envelope.data.entries[1].payload == nil)
        #expect(envelope.data.entries[1].tombstone == NativeSyncTombstone(
            resourceType: .recipe,
            resourceID: "recipe_deleted",
            parentResourceID: nil,
            title: "Deleted Lemon Pasta",
            deletedAt: "2026-06-16T09:09:00.000Z",
            updatedAt: "2026-06-16T09:10:00.000Z"
        ))
        #expect(envelope.data.entries[2].tombstone?.resourceType == .cookbook)
        #expect(envelope.data.entries[3].tombstone?.parentResourceID == "recipe_deleted")
        #expect(envelope.data.entries[4].tombstone?.parentResourceID == "shopping_list_1")
    }

    @Test("sync tombstones apply to local cache records and checkpoint revisions")
    func syncTombstonesApplyToLocalCacheRecordsAndCheckpointRevisions() async throws {
        let syncData = try APIEnvelope<NativeSyncData>.decode(Self.nativeSyncEnvelope).data
        let store = InMemoryNativeSyncStore(
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: []),
            cachedRecords: [
                NativeSyncCachedRecord(kind: .profile, resourceID: "chef_ari", payload: .object(["username": .string("old")]), serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")),
                NativeSyncCachedRecord(kind: .recipe, resourceID: "recipe_deleted", payload: .object(["title": .string("Old recipe")]), serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")),
                NativeSyncCachedRecord(kind: .cookbook, resourceID: "cookbook_deleted", payload: .object(["title": .string("Old cookbook")]), serverRevision: .updatedAt("2026-06-16T09:00:01.000Z")),
                NativeSyncCachedRecord(kind: .spoon, resourceID: "spoon_deleted", payload: .object(["note": .string("Old spoon")]), serverRevision: .updatedAt("2026-06-16T09:00:02.000Z")),
                NativeSyncCachedRecord(kind: .shoppingItem, resourceID: "item_deleted", payload: .object(["name": .string("Old item")]), serverRevision: .updatedAt("2026-06-16T09:00:03.000Z"))
            ]
        )

        let application = try await store.apply(syncData: syncData, validatedAt: now)

        #expect(application.upsertedCacheKeys == ["profile:chef_ari"])
        #expect(application.removedCacheKeys == [
            "recipe:recipe_deleted",
            "cookbook:cookbook_deleted",
            "spoon:spoon_deleted",
            "shoppingItem:item_deleted"
        ])
        #expect(application.tombstones.map(\.resourceID) == ["recipe_deleted", "cookbook_deleted", "spoon_deleted", "item_deleted"])
        #expect(try await store.cachedRecord(kind: .profile, resourceID: "chef_ari")?.payload == .object(["username": .string("ari")]))
        #expect(try await store.cachedRecord(kind: .profile, resourceID: "chef_ari")?.serverRevision == .updatedAt("2026-06-16T09:08:00.000Z"))
        #expect(try await store.cachedRecord(kind: .recipe, resourceID: "recipe_deleted") == nil)
        #expect(try await store.cachedRecord(kind: .cookbook, resourceID: "cookbook_deleted") == nil)
        #expect(try await store.cachedRecord(kind: .spoon, resourceID: "spoon_deleted") == nil)
        #expect(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_deleted") == nil)
        #expect(try await store.loadCheckpoint().globalCursor?.rawValue == "v1.cursor.after")
        #expect(try await store.tombstones.map(\.resourceID) == ["recipe_deleted", "cookbook_deleted", "spoon_deleted", "item_deleted"])
    }

    @Test("sync engine applies bootstrap sync data before draining queued mutations")
    func syncEngineAppliesBootstrapSyncDataBeforeDrainingQueuedMutations() async throws {
        let syncData = try APIEnvelope<NativeSyncData>.decode(Self.nativeSyncEnvelope).data
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [
                .shoppingAddItem(
                    name: "lemons",
                    quantity: 4,
                    unit: "each",
                    categoryKey: nil,
                    iconKey: nil,
                    clientMutationID: "cm_after_bootstrap",
                    createdAt: Self.createdAt(0)
                )
            ]),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: "recipe_deleted",
                    payload: .object(["title": .string("Old recipe")]),
                    serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
                )
            ]
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .syncData(syncData),
            mutationResults: [.success(serverRevision: nil)]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch, scope: boundScope)
        let snapshot = await store.loadSnapshot()

        #expect(report.bootstrapCursor?.rawValue == "v1.cursor.after")
        #expect(report.drainedClientMutationIDs == ["cm_after_bootstrap"])
        #expect(snapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_ari", "shoppingItem:item_local_cm_after_bootstrap"])
        let persistedItemRecord = try #require(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_after_bootstrap"))
        let persistedItem = try Self.shoppingItem(from: persistedItemRecord.payload)
        #expect(persistedItem.name == "lemons")
        #expect(persistedItem.quantity == 4)
        #expect(snapshot.tombstones.map(\.resourceID) == ["recipe_deleted", "cookbook_deleted", "spoon_deleted", "item_deleted"])
        #expect(snapshot.queue.mutations.isEmpty)
    }

    @Test("native sync checkpoints validate global and shopping cursors")
    func nativeSyncCheckpointsValidateGlobalAndShoppingCursors() throws {
        let checkpoint = try NativeSyncCheckpoint(
            globalCursor: PaginationCursor(rawValue: " v1.global "),
            shoppingCursor: ShoppingSyncCursor(rawValue: " v1.shopping "),
            updatedAt: " 2026-06-16T09:00:00.000Z "
        )
        let updated = try checkpoint.updating(
            globalCursor: PaginationCursor(rawValue: "v1.global.next"),
            shoppingCursor: ShoppingSyncCursor(rawValue: "v1.shopping.next"),
            at: "2026-06-16T09:01:00.000Z"
        )

        #expect(checkpoint.globalCursor?.rawValue == "v1.global")
        #expect(checkpoint.shoppingCursor?.rawValue == "v1.shopping")
        #expect(checkpoint.updatedAt == "2026-06-16T09:00:00.000Z")
        #expect(updated.globalCursor?.rawValue == "v1.global.next")
        #expect(updated.shoppingCursor?.rawValue == "v1.shopping.next")
        #expect(updated.updatedAt == "2026-06-16T09:01:00.000Z")
        #expect(throws: NativeSyncCheckpointError.emptyGlobalCursor) {
            _ = try NativeSyncCheckpoint(globalCursorRaw: "  ", shoppingCursorRaw: nil, updatedAt: "2026-06-16T09:00:00.000Z")
        }
        #expect(throws: NativeSyncCheckpointError.emptyShoppingCursor) {
            _ = try NativeSyncCheckpoint(globalCursorRaw: nil, shoppingCursorRaw: "  ", updatedAt: "2026-06-16T09:00:00.000Z")
        }
        #expect(throws: NativeSyncCheckpointError.emptyUpdatedAt) {
            _ = try NativeSyncCheckpoint(globalCursorRaw: nil, shoppingCursorRaw: nil, updatedAt: "  ")
        }
        let rawCheckpoint = try NativeSyncCheckpoint(
            globalCursorRaw: " raw.global ",
            shoppingCursorRaw: " raw.shopping ",
            updatedAt: "2026-06-16T09:02:00.000Z"
        )
        #expect(rawCheckpoint.globalCursor?.rawValue == "raw.global")
        #expect(rawCheckpoint.shoppingCursor?.rawValue == "raw.shopping")
    }

    @Test("sync stores expose simple queue checkpoint and unavailable errors")
    func syncStoresExposeSimpleQueueCheckpointAndUnavailableErrors() async throws {
        let queue = try NativeMutationQueue(mutations: [
            .shoppingAddItem(
                name: "lemons",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_simple_queue",
                createdAt: Self.createdAt(0)
            )
        ])
        let store = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
        await store.saveQueue(queue)
        #expect(try await store.loadQueue() == queue)
        let minimalSnapshot = try JSONDecoder().decode(
            NativeSyncSnapshot.self,
            from: Data(#"{"accountID":"chef_ari","environment":"production"}"#.utf8)
        )
        #expect(minimalSnapshot.queue.mutations.isEmpty)
        #expect(minimalSnapshot.cachedRecords.isEmpty)
        #expect(minimalSnapshot.tombstones.isEmpty)
        do {
            _ = try await store.loadCheckpoint()
            Issue.record("Expected in-memory store to throw missing checkpoint")
        } catch NativeSyncStoreError.missingCheckpoint {
        }

        let syncData = try APIEnvelope<NativeSyncData>.decode(Self.nativeSyncEnvelope).data
        let queueResetStore = InMemoryNativeSyncStore(checkpoint: nil, queue: queue)
        _ = try await queueResetStore.apply(syncData: syncData, validatedAt: now)
        #expect((await queueResetStore.loadSnapshot()).queue.mutations.isEmpty)
        let recordResetStore = InMemoryNativeSyncStore(
            checkpoint: nil,
            queue: NativeMutationQueue(),
            cachedRecords: [NativeSyncCachedRecord(kind: .recipe, resourceID: "recipe_cached", payload: .object(["title": .string("Cached")]), serverRevision: .updatedAt(Self.createdAt(0)))]
        )
        _ = try await recordResetStore.apply(syncData: syncData, validatedAt: now)
        #expect((await recordResetStore.loadSnapshot()).cachedRecords.map(\.cacheKey) == ["profile:chef_ari"])
        let tombstoneResetStore = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
        await tombstoneResetStore.appendTombstone(NativeSyncTombstone(
            resourceType: .recipe,
            resourceID: "recipe_deleted_before_scope",
            parentResourceID: nil,
            title: "Before scope",
            deletedAt: Self.createdAt(0),
            updatedAt: Self.createdAt(0)
        ))
        _ = try await tombstoneResetStore.apply(syncData: syncData, validatedAt: now)
        #expect((await tombstoneResetStore.loadSnapshot()).tombstones.map(\.resourceID) == ["recipe_deleted", "cookbook_deleted", "spoon_deleted", "item_deleted"])

        try await withTemporaryDirectory { directory in
            let fileQueueResetStore = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("queue-reset.json"),
                fallback: NativeSyncSnapshot(checkpoint: nil, queue: queue)
            )
            _ = try await fileQueueResetStore.apply(syncData: syncData, validatedAt: now)
            #expect((await fileQueueResetStore.loadSnapshot()).queue.mutations.isEmpty)

            let fileRecordResetStore = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("record-reset.json"),
                fallback: NativeSyncSnapshot(
                    checkpoint: nil,
                    queue: NativeMutationQueue(),
                    cachedRecords: [NativeSyncCachedRecord(kind: .recipe, resourceID: "recipe_cached_file", payload: .object(["title": .string("Cached file")]), serverRevision: .updatedAt(Self.createdAt(0)))]
                )
            )
            _ = try await fileRecordResetStore.apply(syncData: syncData, validatedAt: now)
            #expect((await fileRecordResetStore.loadSnapshot()).cachedRecords.map(\.cacheKey) == ["profile:chef_ari"])

            let fileTombstoneResetStore = try FileBackedNativeSyncStore(
                fileURL: directory.appendingPathComponent("tombstone-reset.json"),
                fallback: NativeSyncSnapshot(
                    checkpoint: nil,
                    queue: NativeMutationQueue(),
                    tombstones: [NativeSyncTombstone(
                        resourceType: .recipe,
                        resourceID: "recipe_deleted_before_file_scope",
                        parentResourceID: nil,
                        title: "Before file scope",
                        deletedAt: Self.createdAt(0),
                        updatedAt: Self.createdAt(0)
                    )]
                )
            )
            _ = try await fileTombstoneResetStore.apply(syncData: syncData, validatedAt: now)
            #expect((await fileTombstoneResetStore.loadSnapshot()).tombstones.map(\.resourceID) == ["recipe_deleted", "cookbook_deleted", "spoon_deleted", "item_deleted"])
        }

        let localMutation = NativeQueuedMutation.captureDraftCreate(
            draftID: "draft_previous_scope",
            source: .text("https://example.com/previous-scope"),
            clientMutationID: "cm_previous_scope",
            createdAt: Self.createdAt(1)
        )
        let previousScopedStore = InMemoryNativeSyncStore(
            accountID: "chef_previous",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [localMutation])
        )
        let previousScopedTransport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: []
        )
        let previousScopedEngine = NativeSyncEngine(store: previousScopedStore, transport: previousScopedTransport, clock: { now })
        _ = try await previousScopedEngine.bootstrapAndDrain(
            configuration: configuration,
            trigger: .foreground,
            scope: NativeSyncExecutionScope(expectedAccountID: "chef_previous", environment: .local)
        )
        let previousScopedSnapshot = await previousScopedStore.loadSnapshot()
        #expect(previousScopedSnapshot.accountID == "chef_previous")
        #expect(previousScopedSnapshot.environment == .local)
        #expect(previousScopedSnapshot.queue.mutations == [localMutation])

        let unavailable = UnavailableNativeSyncStore(message: "native sync unavailable")
        do {
            _ = try await unavailable.loadQueue()
            Issue.record("Expected unavailable loadQueue to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            try await unavailable.saveQueue(queue)
            Issue.record("Expected unavailable saveQueue to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            try await unavailable.saveQueue(queue, accountID: "chef_ari", environment: .production)
            Issue.record("Expected unavailable scoped saveQueue to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            try await unavailable.saveQueue(
                queue,
                accountID: "chef_ari",
                environment: .production,
                upsertingCachedRecords: [],
                deletingCachedRecordKeys: []
            )
            Issue.record("Expected unavailable combined saveQueue/cache update to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            _ = try await unavailable.loadCheckpoint()
            Issue.record("Expected unavailable loadCheckpoint to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            try await unavailable.saveCheckpoint(try NativeSyncCheckpoint(globalCursor: PaginationCursor(rawValue: "cursor"), shoppingCursor: nil, updatedAt: Self.createdAt(1)))
            Issue.record("Expected unavailable saveCheckpoint to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            try await unavailable.appendTombstone(NativeSyncTombstone(
                resourceType: .recipe,
                resourceID: "recipe_missing",
                parentResourceID: nil,
                title: "Missing",
                deletedAt: Self.createdAt(2),
                updatedAt: Self.createdAt(2)
            ))
            Issue.record("Expected unavailable appendTombstone to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            _ = try await unavailable.cachedRecord(kind: .recipe, resourceID: "recipe_missing")
            Issue.record("Expected unavailable cachedRecord to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            _ = try await unavailable.apply(syncData: try APIEnvelope<NativeSyncData>.decode(Self.nativeSyncEnvelope).data, validatedAt: now)
            Issue.record("Expected unavailable apply to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
        do {
            _ = try await unavailable.loadSnapshot()
            Issue.record("Expected unavailable loadSnapshot to throw")
        } catch NativeSyncStoreError.unavailable(let message) {
            #expect(message == "native sync unavailable")
        }
    }

    @Test("native mutation queue persists every offline product domain with durable replay metadata")
    func nativeMutationQueuePersistsEveryOfflineProductDomainWithDurableReplayMetadata() throws {
        let mutations = try Self.representativeMutations()
        let queue = try NativeMutationQueue(mutations: mutations)
        let encoded = try JSONEncoder().encode(queue)
        let decoded = try JSONDecoder().decode(NativeMutationQueue.self, from: encoded)
        let json = try #require(String(data: encoded, encoding: .utf8))
        let dependencies = Dictionary(uniqueKeysWithValues: queue.mutations.map { ($0.clientMutationID, $0.dependencyKey) })

        #expect(decoded == queue)
        #expect(queue.mutations.map(\.clientMutationID).count == Set(queue.mutations.map(\.clientMutationID)).count)
        #expect(queue.mutations.map(\.payloadSchemaVersion).allSatisfy { $0 == 1 })
        #expect(queue.mutations.map(\.retryCount).allSatisfy { $0 == 0 })
        #expect(queue.mutations.map(\.nextRetryAt).allSatisfy { $0 == nil })
        #expect(queue.mutations.map(\.lastError).allSatisfy { $0 == nil })
        #expect(queue.mutations.map(\.idempotencyKey) == queue.mutations.map(\.clientMutationID))
        #expect(queue.mutations.map(\.queueableKind) == NativeQueuedMutationKind.allOfflineProductKinds)
        #expect(dependencies["cm_recipe_create"] == "recipe:new:cm_recipe_create")
        #expect(dependencies["cm_recipe_update"] == "recipe:recipe_lemon")
        #expect(dependencies["cm_step_create"] == "recipe:recipe_lemon")
        #expect(dependencies["cm_ingredient_delete"] == "recipe:recipe_lemon")
        #expect(dependencies["cm_cookbook_add"] == "cookbook:cookbook_weeknight")
        #expect(dependencies["cm_shopping_clear_all"] == "shopping-list")
        #expect(dependencies["cm_spoon_photo"] == "recipe:recipe_lemon")
        #expect(dependencies["cm_cover_upload"] == "recipe:recipe_lemon")
        #expect(dependencies["cm_profile_update"] == "profile:me")
        #expect(dependencies["cm_notifications_update"] == "notification-preferences")
        #expect(dependencies["cm_apns_register"] == "apns:device_ios")
        #expect(dependencies["cm_capture_create"] == "capture:capture_draft_1")
        #expect(dependencies["cm_import_submit"] == "import:cm_import_submit")
        for type in NativeQueuedMutationKind.allOfflineProductKinds.map(\.type) {
            #expect(json.contains(#""type":"\#(type)""#))
        }
        let persistedKinds = try persistedKindObjects(from: encoded)
        let requiredPersistedFieldsByType: [String: Set<String>] = [
            "recipe.create": ["title", "description", "servings", "steps"],
            "recipe.update": ["recipeId", "title", "description", "servings"],
            "recipe.delete": ["recipeId"],
            "recipe.fork": ["recipeId", "titleOverride"],
            "recipe.step.create": ["recipeId", "stepNum", "stepTitle", "description", "duration", "ingredients", "outputStepNums"],
            "recipe.step.update": ["recipeId", "stepId", "stepTitle", "description", "duration", "outputStepNums"],
            "recipe.step.delete": ["recipeId", "stepId"],
            "recipe.step.reorder": ["recipeId", "stepId", "toStepNum"],
            "recipe.ingredient.add": ["recipeId", "stepId", "quantity", "unit", "name"],
            "recipe.ingredient.delete": ["recipeId", "stepId", "ingredientId"],
            "recipe.outputUses.replace": ["recipeId", "inputStepId", "outputStepNums"],
            "cookbook.create": ["title"],
            "cookbook.update": ["cookbookId", "title"],
            "cookbook.delete": ["cookbookId"],
            "cookbook.addRecipe": ["cookbookId", "recipeId"],
            "cookbook.removeRecipe": ["cookbookId", "recipeId"],
            "shopping.addItem": ["name", "quantity", "unit", "categoryKey", "iconKey"],
            "shopping.checkItem": ["itemId", "checked"],
            "shopping.deleteItem": ["itemId"],
            "shopping.addFromRecipe": ["recipeId", "scaleFactor"],
            "shopping.clearCompleted": [],
            "shopping.clearAll": [],
            "spoon.create": ["recipeId", "note", "nextTime", "cookedAt", "photoUrl", "useAsRecipeCover"],
            "spoon.createPhoto": ["recipeId", "photo", "note", "nextTime", "cookedAt", "useAsRecipeCover"],
            "spoon.update": ["recipeId", "spoonId", "note", "nextTime", "cookedAt", "photoUrl"],
            "spoon.delete": ["recipeId", "spoonId"],
            "cover.upload": ["recipeId", "image", "activate", "generateEditorial"],
            "cover.setActive": ["recipeId", "coverId", "variant"],
            "cover.archive": ["recipeId", "coverId", "replacementCoverId", "replacementVariant", "confirmNoCover", "deleteSafeObjects"],
            "cover.regenerate": ["recipeId", "coverId", "activateWhenReady"],
            "cover.fromSpoon": ["recipeId", "spoonId", "activate", "generateEditorial"],
            "profile.display.update": ["email", "username"],
            "profile.photo.upload": ["photo"],
            "profile.photo.remove": [],
            "notification.preference.update": ["notifySpoonOnMyRecipe", "notifyForkOfMyRecipe", "notifyCookbookSaveOfMine", "notifyFellowChefOriginCook"],
            "apns.device.register": ["deviceId", "platform", "environment", "token", "deviceName", "appVersion"],
            "apns.device.revoke": ["deviceId"],
            "capture.draft.create": ["draftId", "source"],
            "capture.draft.edit": ["draftId", "source"],
            "capture.draft.discard": ["draftId"],
            "recipe.import.submit": ["source"]
        ]
        #expect(Set(persistedKinds.keys) == Set(requiredPersistedFieldsByType.keys))
        for (type, fields) in requiredPersistedFieldsByType {
            let kind = try #require(persistedKinds[type])
            #expect(Set(fields).isSubset(of: Set(kind.keys)))
        }
        #expect(persistedKinds["recipe.update"]?["recipeId"] as? String == "recipe_lemon")
        #expect(persistedKinds["recipe.step.reorder"]?["toStepNum"] as? Int == 1)
        #expect(persistedKinds["cookbook.addRecipe"]?["cookbookId"] as? String == "cookbook_weeknight")
        #expect(persistedKinds["shopping.addItem"]?["name"] as? String == "lemons")
        #expect(dictionaryEquals(persistedKinds["spoon.createPhoto"]?["photo"] as? [String: Any] ?? [:], [
            "localStageId": "stage_spoon_1",
            "fileName": "spoon.webp",
            "contentType": "image/webp"
        ]))
        #expect(dictionaryEquals(persistedKinds["cover.upload"]?["image"] as? [String: Any] ?? [:], [
            "localStageId": "stage_cover_1",
            "fileName": "cover.png",
            "contentType": "image/png"
        ]))
        #expect(dictionaryEquals(persistedKinds["profile.photo.upload"]?["photo"] as? [String: Any] ?? [:], [
            "localStageId": "stage_profile_1",
            "fileName": "profile.jpg",
            "contentType": "image/jpeg"
        ]))
        #expect((persistedKinds["recipe.import.submit"]?["source"] as? [String: Any])?["url"] as? String == "https://example.com/recipe")
        #expect(json.contains("stage_cover_1"))
        #expect(json.contains("stage_spoon_1"))
        #expect(json.contains("stage_profile_1"))
        #expect(json.contains("rawMediaPath") == false)
        #expect(json.contains("signedURL") == false)
    }

    @Test("file backed sync store restores queue checkpoint tombstones and staged media for restart")
    func fileBackedSyncStoreRestoresQueueCheckpointTombstonesAndStagedMediaForRestart() async throws {
        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let mediaDirectory = NativeStagedMediaDirectory(directoryURL: directory.appendingPathComponent("media", isDirectory: true))
            let profilePhoto = Self.stagedMedia("stage_profile_restart", fileName: "profile.jpg", contentType: "image/jpeg")
            try mediaDirectory.save(profilePhoto)

            let checkpoint = try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "cursor_before_restart"),
                shoppingCursor: ShoppingSyncCursor(rawValue: "shopping_before_restart"),
                updatedAt: "2026-06-16T09:12:00.000Z"
            )
            let tombstone = NativeSyncTombstone(
                resourceType: .recipe,
                resourceID: "recipe_deleted_restart",
                parentResourceID: nil,
                title: "Deleted restart recipe",
                deletedAt: "2026-06-16T09:12:01.000Z",
                updatedAt: "2026-06-16T09:12:02.000Z"
            )
            let queue = try NativeMutationQueue(mutations: [
                .profilePhotoUpload(photo: profilePhoto, clientMutationID: "cm_profile_restart", createdAt: Self.createdAt(41))
            ])
            let store = try FileBackedNativeSyncStore(fileURL: storeURL, mediaResolver: mediaDirectory)

            try await store.saveQueue(queue)
            try await store.saveCheckpoint(checkpoint)
            try await store.appendTombstone(tombstone)

            let restored = try FileBackedNativeSyncStore(fileURL: storeURL, mediaResolver: mediaDirectory)
            let restoredQueue = try await restored.loadQueue()
            let request = try restoredQueue.mutations[0].requestBuilder().urlRequest(configuration: configuration)
            let snapshot = await restored.loadSnapshot()

            #expect(try await restored.loadCheckpoint() == checkpoint)
            #expect(restoredQueue.mutations.map(\.clientMutationID) == ["cm_profile_restart"])
            #expect(snapshot.tombstones.map(\.resourceID) == ["recipe_deleted_restart"])
            #expect(request.body?.range(of: profilePhoto.data) != nil)
            #expect(try String(contentsOf: storeURL, encoding: .utf8).contains("stage_profile_restart"))
            #expect(try String(contentsOf: storeURL, encoding: .utf8).contains("rawMediaPath") == false)
            #expect(try String(contentsOf: storeURL, encoding: .utf8).contains("signedURL") == false)
        }
    }

    @Test("scoped queue save clears previous owner checkpoint records and tombstones")
    func scopedQueueSaveClearsPreviousOwnerCheckpointRecordsAndTombstones() async throws {
        let checkpoint = try NativeSyncCheckpoint(
            globalCursor: PaginationCursor(rawValue: "previous.owner.cursor"),
            shoppingCursor: ShoppingSyncCursor(rawValue: "previous.shopping.cursor"),
            updatedAt: "2026-06-16T09:12:00.000Z"
        )
        let previousRecord = NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: "recipe_previous_owner",
            payload: .object(["title": .string("Previous Owner Pasta")]),
            serverRevision: .updatedAt("2026-06-16T09:12:01.000Z")
        )
        let tombstone = NativeSyncTombstone(
            resourceType: .recipe,
            resourceID: "recipe_previous_deleted",
            parentResourceID: nil,
            title: "Previous deleted recipe",
            deletedAt: "2026-06-16T09:12:02.000Z",
            updatedAt: "2026-06-16T09:12:03.000Z"
        )
        let currentQueue = try NativeMutationQueue(mutations: [
            .shoppingAddItem(
                name: "current limes",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "cm_current_limes",
                createdAt: Self.createdAt(42)
            )
        ])
        let memoryStore = InMemoryNativeSyncStore(
            accountID: "chef_previous",
            environment: .production,
            checkpoint: checkpoint,
            queue: NativeMutationQueue(),
            cachedRecords: [previousRecord]
        )
        await memoryStore.appendTombstone(tombstone)

        await memoryStore.saveQueue(
            NativeMutationQueue(),
            accountID: "chef_previous",
            environment: .production,
            upsertingCachedRecords: [],
            deletingCachedRecordKeys: [previousRecord.cacheKey]
        )
        #expect(try await memoryStore.cachedRecord(kind: .recipe, resourceID: "recipe_previous_owner") == nil)

        await memoryStore.saveQueue(currentQueue, accountID: "chef_current", environment: .production)
        let memorySnapshot = await memoryStore.loadSnapshot()

        #expect(memorySnapshot.accountID == "chef_current")
        #expect(memorySnapshot.environment == .production)
        #expect(memorySnapshot.checkpoint == nil)
        #expect(memorySnapshot.cachedRecords.isEmpty)
        #expect(memorySnapshot.tombstones.isEmpty)
        #expect(memorySnapshot.queue.mutations.map(\.clientMutationID) == ["cm_current_limes"])

        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let fileStore = try FileBackedNativeSyncStore(
                fileURL: storeURL,
                fallback: NativeSyncSnapshot(
                    accountID: "chef_previous",
                    environment: .production,
                    checkpoint: checkpoint,
                    queue: NativeMutationQueue(),
                    cachedRecords: [previousRecord],
                    tombstones: [tombstone]
                )
            )

            try await fileStore.saveQueue(currentQueue, accountID: "chef_current", environment: .production)
            let snapshot = await fileStore.loadSnapshot()
            let restored = try FileBackedNativeSyncStore(fileURL: storeURL)
            let restoredSnapshot = await restored.loadSnapshot()

            #expect(snapshot.accountID == "chef_current")
            #expect(snapshot.environment == .production)
            #expect(snapshot.checkpoint == nil)
            #expect(snapshot.cachedRecords.isEmpty)
            #expect(snapshot.tombstones.isEmpty)
            #expect(snapshot.queue.mutations.map(\.clientMutationID) == ["cm_current_limes"])
            #expect(restoredSnapshot == snapshot)
        }
    }

    @Test("sync apply rebinds account and clears previous owner queue before replay")
    func syncApplyRebindsAccountAndClearsPreviousOwnerQueueBeforeReplay() async throws {
        let previousRecipe = NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: "recipe_previous_owner",
            payload: .object(["title": .string("Previous")]),
            serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
        )
        let previousMutation = NativeQueuedMutation.shoppingAddItem(
            name: "previous lemons",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_previous_owner",
            createdAt: Self.createdAt(0)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_previous",
            environment: .production,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [previousMutation]),
            cachedRecords: [previousRecipe]
        )
        let syncData = NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: "chef_current",
                environment: .production,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: "2026-06-16T09:11:00.000Z",
                lastValidatedAt: "2026-06-16T09:11:00.000Z"
            ),
            entries: [
                NativeSyncEntry(
                    action: .upsert,
                    kind: .profile,
                    resourceID: "chef_current",
                    updatedAt: "2026-06-16T09:11:01.000Z",
                    payload: .object(["username": .string("ari")]),
                    tombstone: nil
                )
            ],
            nextCursor: PaginationCursor(rawValue: "current.after"),
            hasMore: false
        )

        _ = try await store.apply(syncData: syncData, validatedAt: now)
        let snapshot = await store.loadSnapshot()

        #expect(snapshot.accountID == "chef_current")
        #expect(snapshot.environment == .production)
        #expect(snapshot.queue.mutations.isEmpty)
        #expect(snapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_current"])
        #expect(try await store.cachedRecord(kind: .recipe, resourceID: "recipe_previous_owner") == nil)
    }

    @Test("sync engine ignores previous owner checkpoint and queue on first scoped bootstrap")
    func syncEngineIgnoresPreviousOwnerCheckpointAndQueueOnFirstScopedBootstrap() async throws {
        let previousRecipe = NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: "recipe_previous_owner",
            payload: .object(["title": .string("Previous")]),
            serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
        )
        let previousMutation = NativeQueuedMutation.shoppingAddItem(
            name: "previous lemons",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_previous_owner",
            createdAt: Self.createdAt(0)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_previous",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "previous.cursor"),
                shoppingCursor: nil,
                updatedAt: "2026-06-16T09:00:00.000Z"
            ),
            queue: try NativeMutationQueue(mutations: [previousMutation]),
            cachedRecords: [previousRecipe]
        )
        let currentSyncData = NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: "chef_current",
                environment: .production,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: "2026-06-16T09:11:00.000Z",
                lastValidatedAt: "2026-06-16T09:11:00.000Z"
            ),
            entries: [
                NativeSyncEntry(
                    action: .upsert,
                    kind: .profile,
                    resourceID: "chef_current",
                    updatedAt: "2026-06-16T09:11:01.000Z",
                    payload: .object(["username": .string("ari")]),
                    tombstone: nil
                )
            ],
            nextCursor: PaginationCursor(rawValue: "current.after"),
            hasMore: false
        )
        let transport = RecordingNativeSyncTransport(bootstrap: .syncData(currentSyncData), mutationResults: [])
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })
        let currentScope = NativeSyncExecutionScope(expectedAccountID: "chef_current", environment: .production)

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch, scope: currentScope)
        let snapshot = await store.loadSnapshot()

        #expect(await transport.bootstrapQueryItems == [URLQueryItem(name: "limit", value: "20")])
        #expect(await transport.requestPaths == ["/api/v1/me/sync"])
        #expect(await transport.clientMutationIDs.isEmpty)
        #expect(report.accountID == "chef_current")
        #expect(report.environment == .production)
        #expect(report.drainedClientMutationIDs.isEmpty)
        #expect(snapshot.accountID == "chef_current")
        #expect(snapshot.environment == .production)
        #expect(snapshot.queue.mutations.isEmpty)
        #expect(snapshot.checkpoint?.globalCursor?.rawValue == "current.after")
        #expect(snapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_current"])
        #expect(try await store.cachedRecord(kind: .recipe, resourceID: "recipe_previous_owner") == nil)
    }

    @Test("file backed sync store lets scoped bootstrap discard previous owner staged media")
    func fileBackedSyncStoreLetsScopedBootstrapDiscardPreviousOwnerStagedMedia() async throws {
        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let mediaDirectory = NativeStagedMediaDirectory(directoryURL: directory.appendingPathComponent("media", isDirectory: true))
            let previousPhoto = Self.stagedMedia("missing_previous_owner_stage", fileName: "previous.jpg", contentType: "image/jpeg")
            let previousMutation = NativeQueuedMutation.profilePhotoUpload(
                photo: previousPhoto,
                clientMutationID: "cm_previous_owner_photo",
                createdAt: Self.createdAt(0)
            )
            let fallback = NativeSyncSnapshot(
                accountID: "chef_previous",
                environment: .production,
                checkpoint: try NativeSyncCheckpoint(
                    globalCursor: PaginationCursor(rawValue: "previous.cursor"),
                    shoppingCursor: nil,
                    updatedAt: "2026-06-16T09:00:00.000Z"
                ),
                queue: try NativeMutationQueue(mutations: [previousMutation]),
                cachedRecords: [
                    NativeSyncCachedRecord(
                        kind: .profile,
                        resourceID: "chef_previous",
                        payload: .object(["username": .string("previous")]),
                        serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
                    )
                ]
            )
            let store = try FileBackedNativeSyncStore(fileURL: storeURL, mediaResolver: mediaDirectory, fallback: fallback)
            let currentSyncData = NativeSyncData(
                freshness: NativeSyncFreshness(
                    accountID: "chef_current",
                    environment: .production,
                    schemaVersion: 1,
                    sourceEndpoint: "/api/v1/me/sync",
                    generatedAt: "2026-06-16T09:11:00.000Z",
                    lastValidatedAt: "2026-06-16T09:11:00.000Z"
                ),
                entries: [
                    NativeSyncEntry(
                        action: .upsert,
                        kind: .profile,
                        resourceID: "chef_current",
                        updatedAt: "2026-06-16T09:11:01.000Z",
                        payload: .object(["username": .string("ari")]),
                        tombstone: nil
                    )
                ],
                nextCursor: PaginationCursor(rawValue: "current.after"),
                hasMore: false
            )
            let transport = RecordingNativeSyncTransport(bootstrap: .syncData(currentSyncData), mutationResults: [])
            let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

            let report = try await engine.bootstrapAndDrain(
                configuration: configuration,
                trigger: .launch,
                scope: NativeSyncExecutionScope(expectedAccountID: "chef_current", environment: .production)
            )
            let snapshot = await store.loadSnapshot()

            #expect(await transport.bootstrapQueryItems == [URLQueryItem(name: "limit", value: "20")])
            #expect(await transport.clientMutationIDs.isEmpty)
            #expect(report.accountID == "chef_current")
            #expect(snapshot.accountID == "chef_current")
            #expect(snapshot.queue.mutations.isEmpty)
            #expect(snapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_current"])
        }
    }

    @Test("sync apply clears legacy unscoped snapshots before binding current account")
    func syncApplyClearsLegacyUnscopedSnapshotsBeforeBindingCurrentAccount() async throws {
        let previousRecipe = NativeSyncCachedRecord(
            kind: .recipe,
            resourceID: "recipe_legacy_owner",
            payload: .object(["title": .string("Legacy")]),
            serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
        )
        let previousMutation = NativeQueuedMutation.profileDisplayUpdate(
            email: "legacy@example.com",
            username: "legacy",
            clientMutationID: "cm_legacy_owner",
            createdAt: Self.createdAt(0)
        )
        let previousCheckpoint = try NativeSyncCheckpoint(
            globalCursor: PaginationCursor(rawValue: "legacy.cursor"),
            shoppingCursor: nil,
            updatedAt: "2026-06-16T09:00:00.000Z"
        )
        let previousTombstone = NativeSyncTombstone(
            resourceType: .recipe,
            resourceID: "recipe_legacy_deleted",
            parentResourceID: nil,
            title: "Legacy deleted",
            deletedAt: "2026-06-16T09:00:01.000Z",
            updatedAt: "2026-06-16T09:00:02.000Z"
        )
        let currentSyncData = NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: "chef_current",
                environment: .production,
                schemaVersion: 1,
                sourceEndpoint: "/api/v1/me/sync",
                generatedAt: "2026-06-16T09:11:00.000Z",
                lastValidatedAt: "2026-06-16T09:11:00.000Z"
            ),
            entries: [
                NativeSyncEntry(
                    action: .upsert,
                    kind: .profile,
                    resourceID: "chef_current",
                    updatedAt: "2026-06-16T09:11:01.000Z",
                    payload: .object(["username": .string("ari")]),
                    tombstone: nil
                )
            ],
            nextCursor: PaginationCursor(rawValue: "current.after"),
            hasMore: false
        )
        let memoryStore = InMemoryNativeSyncStore(
            checkpoint: previousCheckpoint,
            queue: try NativeMutationQueue(mutations: [previousMutation]),
            cachedRecords: [previousRecipe]
        )
        await memoryStore.appendTombstone(previousTombstone)

        _ = try await memoryStore.apply(syncData: currentSyncData, validatedAt: now)
        let memorySnapshot = await memoryStore.loadSnapshot()

        #expect(memorySnapshot.accountID == "chef_current")
        #expect(memorySnapshot.environment == .production)
        #expect(memorySnapshot.queue.mutations.isEmpty)
        #expect(memorySnapshot.tombstones.isEmpty)
        #expect(memorySnapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_current"])
        #expect(try await memoryStore.cachedRecord(kind: .recipe, resourceID: "recipe_legacy_owner") == nil)

        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let fallback = NativeSyncSnapshot(
                checkpoint: previousCheckpoint,
                queue: try NativeMutationQueue(mutations: [previousMutation]),
                cachedRecords: [previousRecipe],
                tombstones: [previousTombstone]
            )
            let fileStore = try FileBackedNativeSyncStore(fileURL: storeURL, fallback: fallback)

            _ = try await fileStore.apply(syncData: currentSyncData, validatedAt: now)
            let fileSnapshot = await fileStore.loadSnapshot()

            #expect(fileSnapshot.accountID == "chef_current")
            #expect(fileSnapshot.environment == .production)
            #expect(fileSnapshot.queue.mutations.isEmpty)
            #expect(fileSnapshot.tombstones.isEmpty)
            #expect(fileSnapshot.cachedRecords.map(\.cacheKey) == ["profile:chef_current"])
            #expect(try await fileStore.cachedRecord(kind: .recipe, resourceID: "recipe_legacy_owner") == nil)
        }
    }

    @Test("file backed sync store applies records checkpoints and missing staged media errors")
    func fileBackedSyncStoreAppliesRecordsCheckpointsAndMissingStagedMediaErrors() async throws {
        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let store = try FileBackedNativeSyncStore(fileURL: storeURL)
            do {
                _ = try await store.loadCheckpoint()
                Issue.record("Expected missing checkpoint before file-backed sync apply")
            } catch NativeSyncStoreError.missingCheckpoint {
            }

            let staleRecord = NativeSyncCachedRecord(
                kind: .recipe,
                resourceID: "recipe_deleted_file",
                payload: .object(["title": .string("Stale")]),
                serverRevision: .updatedAt("2026-06-16T09:00:00.000Z")
            )
            let fallback = NativeSyncSnapshot(
                accountID: "chef_ari",
                environment: .local,
                checkpoint: nil,
                queue: NativeMutationQueue(),
                cachedRecords: [staleRecord],
                tombstones: []
            )
            let fallbackStore = try FileBackedNativeSyncStore(fileURL: storeURL, fallback: fallback)
            let tombstone = NativeSyncTombstone(
                resourceType: .recipe,
                resourceID: "recipe_deleted_file",
                parentResourceID: nil,
                title: "Deleted file recipe",
                deletedAt: "2026-06-16T09:10:00.000Z",
                updatedAt: "2026-06-16T09:10:01.000Z"
            )
            let result = try await fallbackStore.apply(
                syncData: NativeSyncData(
                    freshness: NativeSyncFreshness(
                        accountID: "chef_ari",
                        environment: .local,
                        schemaVersion: 1,
                        sourceEndpoint: "/api/v1/me/sync",
                        generatedAt: "2026-06-16T09:11:00.000Z",
                        lastValidatedAt: "2026-06-16T09:11:00.000Z"
                    ),
                    entries: [
                        NativeSyncEntry(action: .upsert, kind: .profile, resourceID: "chef_ari", updatedAt: "2026-06-16T09:11:01.000Z", payload: .object(["username": .string("ari")]), tombstone: nil),
                        NativeSyncEntry(action: .upsert, kind: .cookbook, resourceID: "cookbook_file", updatedAt: "2026-06-16T09:11:01.500Z", payload: .object(["title": .string("Weeknights")]), tombstone: nil),
                        NativeSyncEntry(action: .delete, kind: .recipe, resourceID: "recipe_deleted_file", updatedAt: "2026-06-16T09:11:02.000Z", payload: nil, tombstone: tombstone)
                    ],
                    nextCursor: PaginationCursor(rawValue: "file.cursor.after"),
                    hasMore: false
                ),
                validatedAt: now
            )

            #expect(result.upsertedCacheKeys == ["profile:chef_ari", "cookbook:cookbook_file"])
            #expect(result.removedCacheKeys == ["recipe:recipe_deleted_file"])
            #expect(result.tombstones == [tombstone])
            #expect(try await fallbackStore.cachedRecord(kind: .profile, resourceID: "chef_ari")?.payload == .object(["username": .string("ari")]))
            #expect(try await fallbackStore.cachedRecord(kind: .cookbook, resourceID: "cookbook_file")?.payload == .object(["title": .string("Weeknights")]))
            #expect(try await fallbackStore.cachedRecord(kind: .recipe, resourceID: "recipe_deleted_file") == nil)
            #expect(try await fallbackStore.loadCheckpoint().globalCursor?.rawValue == "file.cursor.after")

            let restored = try FileBackedNativeSyncStore(fileURL: storeURL)
            #expect(try await restored.cachedRecord(kind: .profile, resourceID: "chef_ari")?.serverRevision == .updatedAt("2026-06-16T09:11:01.000Z"))
            #expect(await restored.loadSnapshot().cachedRecords.map(\.cacheKey) == ["cookbook:cookbook_file", "profile:chef_ari"])
            #expect(await restored.loadSnapshot().tombstones == [tombstone])
            let plainQueue = try NativeMutationQueue(mutations: [
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_file_plain_queue", createdAt: Self.createdAt(42))
            ])
            try await restored.saveQueue(plainQueue)
            #expect(try await restored.loadQueue() == plainQueue)

            let mediaDirectoryURL = directory.appendingPathComponent("media", isDirectory: true)
            let mediaDirectory = NativeStagedMediaDirectory(directoryURL: mediaDirectoryURL)
            #expect(throws: NativeStagedMediaDirectoryError.missingStage("missing_stage")) {
                _ = try mediaDirectory.data(for: Self.stagedMedia("missing_stage", fileName: "missing.jpg", contentType: "image/jpeg"))
            }
            let unreadableStageID = "unreadable_stage"
            let unreadableFileName = unreadableStageID.utf8.map { String(format: "%02x", $0) }.joined()
            try FileManager.default.createDirectory(at: mediaDirectoryURL.appendingPathComponent(unreadableFileName), withIntermediateDirectories: true)
            #expect(throws: NativeStagedMediaDirectoryError.unreadableStage(unreadableStageID)) {
                _ = try mediaDirectory.data(for: Self.stagedMedia(unreadableStageID, fileName: "unreadable.jpg", contentType: "image/jpeg"))
            }
        }
    }

    @Test("mutation queue and durable decode edge cases fail closed")
    func mutationQueueAndDurableDecodeEdgeCasesFailClosed() throws {
        let mutation = NativeQueuedMutation.profileDisplayUpdate(
            email: "ari@example.com",
            username: "ari",
            clientMutationID: "cm_append",
            createdAt: Self.createdAt(0)
        )
        let appended = try NativeMutationQueue().appending(mutation)
        let removed = try appended.removing(clientMutationIDs: ["cm_append"])
        #expect(appended.mutations.map(\.clientMutationID) == ["cm_append"])
        #expect(removed.mutations.isEmpty)
        #expect(throws: NativeMutationQueueError.emptyClientMutationID) {
            _ = try NativeMutationQueue(mutations: [
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "   ", createdAt: Self.createdAt(1))
            ])
        }
        #expect(throws: NativeMutationQueueError.duplicateClientMutationID("cm_append")) {
            _ = try NativeMutationQueue(mutations: [mutation, mutation])
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 99, type: "profile.display.update", fields: ["email": "ari@example.com", "username": "ari"]))
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 1, type: "recipe.unknown", fields: [:]))
        }

        let decodedWithoutRetryCount = try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1,
                "id": "native:cm_without_retry_count",
                "clientMutationId": "cm_without_retry_count",
                "createdAt": Self.createdAt(0),
                "kind": [
                    "type": "profile.display.update",
                    "email": "ari@example.com",
                    "username": "ari"
                ]
            ])
        )
        #expect(decodedWithoutRetryCount.retryCount == 0)

        let missingRouteMutation = try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: Self.queuedMutationJSON(schemaVersion: 1, type: "recipe.update", fields: ["recipeId": 42, "title": "Bad route"])
        )
        #expect(missingRouteMutation.dependencyKey == "recipe:")
        #expect(throws: NativeQueuedMutationRequestError.missingField("recipeId")) {
            _ = try missingRouteMutation.requestBuilder()
        }

        let missingMediaMutation = try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: Self.queuedMutationJSON(schemaVersion: 1, type: "cover.upload", fields: ["recipeId": "recipe_lemon"])
        )
        #expect(throws: NativeQueuedMutationRequestError.missingMedia("image")) {
            _ = try missingMediaMutation.requestBuilder()
        }

        let fallbackDependencies = try [
            JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 1, type: "cookbook.update", fields: ["title": "Missing cookbook"])).dependencyKey,
            JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 1, type: "apns.device.register", fields: ["token": "apns-token"])).dependencyKey,
            JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 1, type: "apns.device.revoke", fields: [:])).dependencyKey,
            JSONDecoder().decode(NativeQueuedMutation.self, from: Self.queuedMutationJSON(schemaVersion: 1, type: "capture.draft.discard", fields: [:])).dependencyKey
        ]
        #expect(fallbackDependencies == ["cookbook:", "apns:apns-token", "apns:cm_decode", "capture:cm_decode"])
        let intKey = try #require(DynamicCodingKey(intValue: 7))
        #expect(intKey.stringValue == "7")
        #expect(intKey.intValue == 7)
    }

    @Test("queued remote mutations build exact REST requests with idempotency keys and bearer auth")
    func queuedRemoteMutationsBuildExactRESTRequestsWithIdempotencyKeysAndBearerAuth() throws {
        let recipeCreateSteps = [
            RecipeStepDraft(
                stepNum: 1,
                stepTitle: nil,
                description: "Boil.",
                duration: nil,
                ingredients: [
                    RecipeIngredientDraft(quantity: 1, unit: "lb", name: "pasta")
                ],
                outputStepNums: []
            ),
            RecipeStepDraft(
                stepNum: 2,
                stepTitle: "Sauce",
                description: "Use the pasta water.",
                duration: 5,
                ingredients: [],
                outputStepNums: [1]
            )
        ]
        let stepCreateIngredients = [
            RecipeIngredientDraft(quantity: 2, unit: "cloves", name: "garlic")
        ]
        let cases: [ExpectedRemoteMutationRequest] = [
            .json(try .recipeCreate(clientMutationID: "cm_recipe_create", title: "Lemon Pasta", description: "Bright", servings: "4", steps: recipeCreateSteps, createdAt: Self.createdAt(0)), .post, "/api/v1/recipes", [
                "clientMutationId": "cm_recipe_create",
                "title": "Lemon Pasta",
                "description": "Bright",
                "servings": "4",
                "steps": [
                    [
                        "stepTitle": NSNull(),
                        "description": "Boil.",
                        "duration": NSNull(),
                        "ingredients": [
                            [
                                "quantity": 1.0,
                                "unit": "lb",
                                "name": "pasta"
                            ]
                        ],
                        "outputStepNums": []
                    ],
                    [
                        "stepTitle": "Sauce",
                        "description": "Use the pasta water.",
                        "duration": 5.0,
                        "ingredients": [],
                        "outputStepNums": [1.0]
                    ]
                ]
            ]),
            .json(.recipeUpdate(recipeID: "recipe/lemon", clientMutationID: "cm_recipe_update", title: "Lemon Pasta", description: nil, servings: "4", createdAt: Self.createdAt(1)), .patch, "/api/v1/recipes/recipe%2Flemon", [
                "clientMutationId": "cm_recipe_update",
                "title": "Lemon Pasta",
                "description": NSNull(),
                "servings": "4"
            ]),
            .noBody(.recipeDelete(recipeID: "recipe/lemon", clientMutationID: "cm_recipe_delete", createdAt: Self.createdAt(2)), .delete, "/api/v1/recipes/recipe%2Flemon", queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_recipe_delete")]),
            .json(.recipeFork(recipeID: "recipe/lemon", clientMutationID: "cm_recipe_fork", titleOverride: "My Lemon Pasta", createdAt: Self.createdAt(3)), .post, "/api/v1/recipes/recipe%2Flemon/fork", [
                "clientMutationId": "cm_recipe_fork",
                "title": "My Lemon Pasta"
            ]),
            .json(try .recipeStepCreate(recipeID: "recipe/lemon", clientMutationID: "cm_step_create", stepNum: 2, stepTitle: "Sauce", description: "Toss.", duration: 3, ingredients: stepCreateIngredients, outputStepNums: [1], createdAt: Self.createdAt(4)), .post, "/api/v1/recipes/recipe%2Flemon/steps", [
                "clientMutationId": "cm_step_create",
                "stepNum": 2,
                "stepTitle": "Sauce",
                "description": "Toss.",
                "duration": 3,
                "ingredients": [
                    [
                        "quantity": 2.0,
                        "unit": "cloves",
                        "name": "garlic"
                    ]
                ],
                "outputStepNums": [1]
            ]),
            .json(.recipeStepUpdate(recipeID: "recipe/lemon", stepID: "step/two", clientMutationID: "cm_step_update", stepTitle: nil, description: "Toss until glossy.", duration: nil, outputStepNums: [1], createdAt: Self.createdAt(5)), .patch, "/api/v1/recipes/recipe%2Flemon/steps/step%2Ftwo", [
                "clientMutationId": "cm_step_update",
                "stepTitle": NSNull(),
                "description": "Toss until glossy.",
                "duration": NSNull(),
                "outputStepNums": [1]
            ]),
            .json(.recipeStepDelete(recipeID: "recipe/lemon", stepID: "step/two", clientMutationID: "cm_step_delete", createdAt: Self.createdAt(6)), .delete, "/api/v1/recipes/recipe%2Flemon/steps/step%2Ftwo", ["clientMutationId": "cm_step_delete"]),
            .json(.recipeStepReorder(recipeID: "recipe/lemon", stepID: "step/two", toStepNum: 1, clientMutationID: "cm_step_reorder", createdAt: Self.createdAt(7)), .post, "/api/v1/recipes/recipe%2Flemon/steps/reorder", [
                "clientMutationId": "cm_step_reorder",
                "stepId": "step/two",
                "toStepNum": 1
            ]),
            .json(try .recipeIngredientAdd(recipeID: "recipe/lemon", stepID: "step/two", clientMutationID: "cm_ingredient_add", quantity: 2, unit: "cloves", name: "garlic", createdAt: Self.createdAt(8)), .post, "/api/v1/recipes/recipe%2Flemon/steps/step%2Ftwo/ingredients", [
                "clientMutationId": "cm_ingredient_add",
                "quantity": 2,
                "unit": "cloves",
                "name": "garlic"
            ]),
            .noBody(.recipeIngredientDelete(recipeID: "recipe/lemon", stepID: "step/two", ingredientID: "ingredient/garlic", clientMutationID: "cm_ingredient_delete", createdAt: Self.createdAt(9)), .delete, "/api/v1/recipes/recipe%2Flemon/steps/step%2Ftwo/ingredients/ingredient%2Fgarlic", extraHeaders: ["X-Client-Mutation-Id": "cm_ingredient_delete"]),
            .json(.recipeOutputUsesReplace(recipeID: "recipe/lemon", inputStepID: "step/two", outputStepNums: [1, 3], clientMutationID: "cm_output_uses", createdAt: Self.createdAt(10)), .put, "/api/v1/recipes/recipe%2Flemon/step-output-uses", [
                "clientMutationId": "cm_output_uses",
                "inputStepId": "step/two",
                "outputStepNums": [1, 3]
            ]),
            .json(.cookbookCreate(clientMutationID: "cm_cookbook_create", title: "Weeknights", createdAt: Self.createdAt(11)), .post, "/api/v1/cookbooks", [
                "clientMutationId": "cm_cookbook_create",
                "title": "Weeknights"
            ]),
            .json(.cookbookUpdate(cookbookID: "cookbook/week", title: "Dinner Parties", clientMutationID: "cm_cookbook_update", createdAt: Self.createdAt(12)), .patch, "/api/v1/cookbooks/cookbook%2Fweek", [
                "clientMutationId": "cm_cookbook_update",
                "title": "Dinner Parties"
            ]),
            .noBody(.cookbookDelete(cookbookID: "cookbook/week", clientMutationID: "cm_cookbook_delete", createdAt: Self.createdAt(13)), .delete, "/api/v1/cookbooks/cookbook%2Fweek", queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_cookbook_delete")]),
            .json(.cookbookAddRecipe(cookbookID: "cookbook/week", recipeID: "recipe/lemon", clientMutationID: "cm_cookbook_add", createdAt: Self.createdAt(14)), .post, "/api/v1/cookbooks/cookbook%2Fweek/recipes/recipe%2Flemon", ["clientMutationId": "cm_cookbook_add"]),
            .json(.cookbookRemoveRecipe(cookbookID: "cookbook/week", recipeID: "recipe/lemon", clientMutationID: "cm_cookbook_remove", createdAt: Self.createdAt(15)), .delete, "/api/v1/cookbooks/cookbook%2Fweek/recipes/recipe%2Flemon", ["clientMutationId": "cm_cookbook_remove"]),
            .json(.shoppingAddItem(name: "lemons", quantity: 4, unit: "each", categoryKey: "produce", iconKey: "lemon", clientMutationID: "cm_shopping_add", createdAt: Self.createdAt(16)), .post, "/api/v1/shopping-list/items", [
                "clientMutationId": "cm_shopping_add",
                "name": "lemons",
                "quantity": 4,
                "unit": "each",
                "categoryKey": "produce",
                "iconKey": "lemon"
            ]),
            .json(.shoppingAddItem(name: "salt", quantity: nil, unit: nil, categoryKey: nil, iconKey: nil, clientMutationID: "cm_shopping_add_plain", createdAt: Self.createdAt(16)), .post, "/api/v1/shopping-list/items", [
                "clientMutationId": "cm_shopping_add_plain",
                "name": "salt",
                "quantity": NSNull(),
                "unit": NSNull(),
                "categoryKey": NSNull(),
                "iconKey": NSNull()
            ]),
            .json(.shoppingCheckItem(itemID: "item/lemons", checked: true, clientMutationID: "cm_shopping_check", createdAt: Self.createdAt(17)), .patch, "/api/v1/shopping-list/items/item%2Flemons", [
                "clientMutationId": "cm_shopping_check",
                "checked": true
            ]),
            .noBody(.shoppingDeleteItem(itemID: "item/lemons", clientMutationID: "cm_shopping_delete", createdAt: Self.createdAt(18)), .delete, "/api/v1/shopping-list/items/item%2Flemons", extraHeaders: ["X-Client-Mutation-Id": "cm_shopping_delete"]),
            .json(.shoppingAddFromRecipe(recipeID: "recipe/lemon", scaleFactor: 1.5, clientMutationID: "cm_shopping_recipe", createdAt: Self.createdAt(19)), .post, "/api/v1/shopping-list/add-from-recipe", [
                "clientMutationId": "cm_shopping_recipe",
                "recipeId": "recipe/lemon",
                "scaleFactor": 1.5
            ]),
            .json(.shoppingClearCompleted(clientMutationID: "cm_clear_completed", createdAt: Self.createdAt(20)), .post, "/api/v1/shopping-list/clear-completed", ["clientMutationId": "cm_clear_completed"]),
            .json(.shoppingClearAll(clientMutationID: "cm_clear_all", createdAt: Self.createdAt(21)), .post, "/api/v1/shopping-list/clear-all", ["clientMutationId": "cm_clear_all"]),
            .json(.spoonCreate(recipeID: "recipe/lemon", clientMutationID: "cm_spoon_create", note: "Loved it.", nextTime: nil, cookedAt: "2026-06-16T09:20:00.000Z", photoURL: "/photos/spoons/lemon.jpg", useAsRecipeCover: true, createdAt: Self.createdAt(22)), .post, "/api/v1/recipes/recipe%2Flemon/spoons", [
                "clientMutationId": "cm_spoon_create",
                "note": "Loved it.",
                "nextTime": NSNull(),
                "cookedAt": "2026-06-16T09:20:00.000Z",
                "photoUrl": "/photos/spoons/lemon.jpg",
                "useAsRecipeCover": true
            ]),
            .multipart(.spoonCreatePhoto(recipeID: "recipe/lemon", photo: Self.stagedMedia("stage_spoon_1", fileName: "spoon.webp", contentType: "image/webp"), clientMutationID: "cm_spoon_photo", note: "Photo cook.", nextTime: "More lemon", cookedAt: nil, useAsRecipeCover: false, createdAt: Self.createdAt(23)), .post, "/api/v1/recipes/recipe%2Flemon/spoons", "photo", "spoon.webp", "image/webp", [
                "clientMutationId": "cm_spoon_photo",
                "note": "Photo cook.",
                "nextTime": "More lemon",
                "useAsRecipeCover": "false"
            ]),
            .json(.spoonUpdate(recipeID: "recipe/lemon", spoonID: "spoon/cooked", clientMutationID: "cm_spoon_update", note: nil, nextTime: "More lemon", cookedAt: "2026-06-16T10:00:00.000Z", photoURL: "/photos/spoons/updated.jpg", createdAt: Self.createdAt(24)), .patch, "/api/v1/recipes/recipe%2Flemon/spoons/spoon%2Fcooked", [
                "clientMutationId": "cm_spoon_update",
                "note": NSNull(),
                "nextTime": "More lemon",
                "cookedAt": "2026-06-16T10:00:00.000Z",
                "photoUrl": "/photos/spoons/updated.jpg"
            ]),
            .noBody(.spoonDelete(recipeID: "recipe/lemon", spoonID: "spoon/cooked", clientMutationID: "cm_spoon_delete", createdAt: Self.createdAt(25)), .delete, "/api/v1/recipes/recipe%2Flemon/spoons/spoon%2Fcooked", extraHeaders: ["X-Client-Mutation-Id": "cm_spoon_delete"]),
            .multipart(.coverUpload(recipeID: "recipe/lemon", image: Self.stagedMedia("stage_cover_1", fileName: "cover.png", contentType: "image/png"), clientMutationID: "cm_cover_upload", activate: true, generateEditorial: false, createdAt: Self.createdAt(26)), .post, "/api/v1/recipes/recipe%2Flemon/image", "image", "cover.png", "image/png", [
                "clientMutationId": "cm_cover_upload",
                "activate": "true",
                "generateEditorial": "false"
            ]),
            .json(.coverSetActive(recipeID: "recipe/lemon", coverID: "cover/raw", clientMutationID: "cm_cover_active", variant: .stylized, createdAt: Self.createdAt(27)), .patch, "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fraw", [
                "clientMutationId": "cm_cover_active",
                "variant": "stylized"
            ]),
            .json(.coverArchive(recipeID: "recipe/lemon", coverID: "cover/raw", clientMutationID: "cm_cover_archive", replacementCoverID: "cover/replacement", replacementVariant: .image, confirmNoCover: false, deleteSafeObjects: true, createdAt: Self.createdAt(28)), .delete, "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fraw", [
                "replacementCoverId": "cover/replacement",
                "replacementVariant": "image",
                "confirmNoCover": false,
                "deleteSafeObjects": true
            ], queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_cover_archive")]),
            .json(.coverArchive(recipeID: "recipe/lemon", coverID: "cover/raw-empty", clientMutationID: "cm_cover_archive_empty", replacementCoverID: nil, replacementVariant: nil, confirmNoCover: true, deleteSafeObjects: false, createdAt: Self.createdAt(28)), .delete, "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fraw-empty", [
                "replacementCoverId": NSNull(),
                "replacementVariant": NSNull(),
                "confirmNoCover": true,
                "deleteSafeObjects": false
            ], queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_cover_archive_empty")]),
            .json(.coverRegenerate(recipeID: "recipe/lemon", coverID: "cover/editorial", activateWhenReady: true, clientMutationID: "cm_cover_retry", createdAt: Self.createdAt(29)), .post, "/api/v1/recipes/recipe%2Flemon/covers/regenerate", [
                "clientMutationId": "cm_cover_retry",
                "coverId": "cover/editorial",
                "activateWhenReady": true
            ]),
            .json(.coverFromSpoon(recipeID: "recipe/lemon", spoonID: "spoon/cooked", clientMutationID: "cm_cover_spoon", activate: true, generateEditorial: true, createdAt: Self.createdAt(30)), .post, "/api/v1/recipes/recipe%2Flemon/covers/from-spoon/spoon%2Fcooked", [
                "clientMutationId": "cm_cover_spoon",
                "activate": true,
                "generateEditorial": true
            ]),
            .json(.profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_update", createdAt: Self.createdAt(31)), .patch, "/api/v1/me", [
                "clientMutationId": "cm_profile_update",
                "email": "ari@example.com",
                "username": "ari"
            ]),
            .multipart(.profilePhotoUpload(photo: Self.stagedMedia("stage_profile_1", fileName: "profile.jpg", contentType: "image/jpeg"), clientMutationID: "cm_profile_photo", createdAt: Self.createdAt(32)), .post, "/api/v1/me/photo", "photo", "profile.jpg", "image/jpeg", ["clientMutationId": "cm_profile_photo"]),
            .noBody(.profilePhotoRemove(clientMutationID: "cm_profile_photo_remove", createdAt: Self.createdAt(33)), .delete, "/api/v1/me/photo", extraHeaders: ["X-Client-Mutation-Id": "cm_profile_photo_remove"]),
            .json(.notificationPreferenceUpdate(notifySpoonOnMyRecipe: true, notifyForkOfMyRecipe: false, notifyCookbookSaveOfMine: true, notifyFellowChefOriginCook: false, clientMutationID: "cm_notifications_update", createdAt: Self.createdAt(34)), .patch, "/api/v1/me/notification-preferences", [
                "clientMutationId": "cm_notifications_update",
                "notifySpoonOnMyRecipe": true,
                "notifyForkOfMyRecipe": false,
                "notifyCookbookSaveOfMine": true,
                "notifyFellowChefOriginCook": false
            ]),
            .json(.apnsDeviceRegister(deviceID: "device/ios", platform: .ios, environment: .development, token: "apns-token", deviceName: "Ari's iPhone", appVersion: "1.0.0", clientMutationID: "cm_apns_register", createdAt: Self.createdAt(35)), .post, "/api/v1/me/apns-devices", [
                "clientMutationId": "cm_apns_register",
                "deviceId": "device/ios",
                "platform": "ios",
                "environment": "development",
                "token": "apns-token",
                "deviceName": "Ari's iPhone",
                "appVersion": "1.0.0"
            ]),
            .noBody(.apnsDeviceRevoke(deviceID: "device/ios", clientMutationID: "cm_apns_revoke", createdAt: Self.createdAt(36)), .delete, "/api/v1/me/apns-devices/device%2Fios", extraHeaders: ["X-Client-Mutation-Id": "cm_apns_revoke"]),
            .json(.recipeImportSubmit(source: .url(URL(string: "https://example.com/recipe")!), clientMutationID: "cm_import_submit", createdAt: Self.createdAt(37)), .post, "/api/v1/recipes/import", [
                "clientMutationId": "cm_import_submit",
                "source": [
                    "type": "url",
                    "url": "https://example.com/recipe"
                ]
            ])
        ]

        for expected in cases {
            try assertExpectedRemoteMutationRequest(expected, configuration: configuration)
        }

        #expect(throws: NativeQueuedMutationRequestError.missingField("steps.0.ingredients.0.unit")) {
            _ = try NativeQueuedMutation.recipeCreate(
                clientMutationID: "cm_recipe_bad_unit",
                title: "Bad Unit",
                description: nil,
                servings: nil,
                steps: [
                    RecipeStepDraft(
                        stepNum: 1,
                        stepTitle: nil,
                        description: "Boil.",
                        duration: nil,
                        ingredients: [RecipeIngredientDraft(quantity: 1, unit: nil, name: "pasta")],
                        outputStepNums: []
                    )
                ],
                createdAt: Self.createdAt(42)
            )
        }
        #expect(throws: NativeQueuedMutationRequestError.missingField("ingredients.0.unit")) {
            _ = try NativeQueuedMutation.recipeStepCreate(
                recipeID: "recipe/lemon",
                clientMutationID: "cm_step_bad_unit",
                stepNum: 1,
                stepTitle: nil,
                description: "Boil.",
                duration: nil,
                ingredients: [RecipeIngredientDraft(quantity: 1, unit: nil, name: "pasta")],
                outputStepNums: [],
                createdAt: Self.createdAt(43)
            )
        }
        #expect(throws: NativeQueuedMutationRequestError.missingField("ingredient.unit")) {
            _ = try NativeQueuedMutation.recipeIngredientAdd(
                recipeID: "recipe/lemon",
                stepID: "step/one",
                clientMutationID: "cm_ingredient_bad_unit",
                quantity: 1,
                unit: nil,
                name: "pasta",
                createdAt: Self.createdAt(44)
            )
        }
    }

    @Test("capture draft mutations are durable local cache mutations and never build network requests")
    func captureDraftMutationsAreDurableLocalCacheMutationsAndNeverBuildNetworkRequests() throws {
        let captureMutations: [NativeQueuedMutation] = [
            .captureDraftCreate(draftID: "capture_draft_1", source: .url(URL(string: "https://example.com/recipe")!), clientMutationID: "cm_capture_create", createdAt: Self.createdAt(0)),
            .captureDraftEdit(draftID: "capture_draft_1", source: .text("Grandma notes"), clientMutationID: "cm_capture_edit", createdAt: Self.createdAt(1)),
            .captureDraftDiscard(draftID: "capture_draft_1", clientMutationID: "cm_capture_discard", createdAt: Self.createdAt(2))
        ]

        #expect(captureMutations.map(\.replayTarget) == [.localCache, .localCache, .localCache])
        #expect(captureMutations.map(\.dependencyKey) == Array(repeating: "capture:capture_draft_1", count: 3))
        for mutation in captureMutations {
            #expect(throws: NativeQueuedMutationRequestError.localOnlyMutation) {
                _ = try mutation.requestBuilder()
            }
        }
    }

    @Test("legacy intent shopping mutations convert into native durable queued mutations")
    func legacyIntentShoppingMutationsConvertIntoNativeDurableQueuedMutations() throws {
        let legacyAdd = QueuedMutation(
            id: "intent-add",
            clientMutationID: "intent-add",
            createdAt: Self.createdAt(0),
            kind: .shoppingAdd(name: " Lemons ", quantity: 3, unit: " each ", categoryKey: "produce", iconKey: "lemon")
        )
        let legacyCheck = QueuedMutation(
            id: "intent-check",
            clientMutationID: "intent-check",
            createdAt: Self.createdAt(1),
            kind: .shoppingCheck(itemID: "item_lemons", checked: true)
        )
        let legacyDelete = QueuedMutation(
            id: "intent-delete",
            clientMutationID: "intent-delete",
            createdAt: Self.createdAt(2),
            kind: .shoppingDelete(itemID: "item_limes")
        )

        let nativeAdd = try NativeQueuedMutation.intentMutation(from: legacyAdd)
        let nativeCheck = try NativeQueuedMutation.intentMutation(from: legacyCheck)
        let nativeDelete = try NativeQueuedMutation.intentMutation(from: legacyDelete)
        let addRequest = try nativeAdd.requestBuilder().urlRequest(configuration: configuration)
        let checkRequest = try nativeCheck.requestBuilder().urlRequest(configuration: configuration)
        let deleteRequest = try nativeDelete.requestBuilder().urlRequest(configuration: configuration)
        let addBody = try decodedJSONBody(from: addRequest)
        let checkBody = try decodedJSONBody(from: checkRequest)

        #expect(nativeAdd.queueableKind == .shoppingAddItem)
        #expect(nativeCheck.queueableKind == .shoppingCheckItem)
        #expect(nativeDelete.queueableKind == .shoppingDeleteItem)
        #expect(addRequest.url.path == "/api/v1/shopping-list/items")
        #expect(addBody["clientMutationId"] as? String == "intent-add")
        #expect(addBody["name"] as? String == " Lemons ")
        #expect(addBody["unit"] as? String == " each ")
        #expect(checkRequest.url.path == "/api/v1/shopping-list/items/item_lemons")
        #expect(checkBody["checked"] as? Bool == true)
        #expect(deleteRequest.url.path == "/api/v1/shopping-list/items/item_limes")
        #expect(deleteRequest.headers["X-Client-Mutation-Id"] == "intent-delete")
    }

    @Test("sync engine keeps local capture draft mutations out of remote drain")
    func syncEngineKeepsLocalCaptureDraftMutationsOutOfRemoteDrain() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                .captureDraftCreate(draftID: "capture_draft_1", source: .text("Grandma notes"), clientMutationID: "cm_capture_create", createdAt: Self.createdAt(0)),
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_remote", createdAt: Self.createdAt(1))
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [.success(serverRevision: .updatedAt("2026-06-16T09:07:00.000Z"))]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: boundScope)

        #expect(report.drainedClientMutationIDs == ["cm_profile_remote"])
        #expect(await transport.clientMutationIDs == ["cm_profile_remote"])
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_capture_create"])
    }

    @Test("offline mutation policy queues allowed writes and refuses online only account security and provider actions")
    func offlineMutationPolicyQueuesAllowedWritesAndRefusesOnlineOnlyAccountSecurityAndProviderActions() throws {
        for mutation in try Self.representativeMutations() {
            #expect(try NativeOfflineMutationPolicy.decision(for: .queuedMutation(mutation)).queueableKind == mutation.queueableKind)
        }

        let onlineOnlyCases: [(NativeOfflineAction, String)] = [
            (.oauthSignIn, "OAuth sign-in is online-only and was not queued."),
            (.oauthCallback, "OAuth callback exchange is online-only and was not queued."),
            (.apiTokenCreate, "API token creation is online-only and was not queued."),
            (.apiTokenRevoke, "API token revocation is online-only and was not queued."),
            (.providerConnectionDisconnect, "Provider disconnect is online-only and was not queued."),
            (.logout, "Logout is online-only and was not queued."),
            (.sessionRevoke, "Session revocation is online-only and was not queued."),
            (.passkeyOrPasswordChange, "Credential changes are online-only and were not queued."),
            (.providerLink, "Provider linking is online-only and was not queued."),
            (.apnsPermissionPrompt, "Notification permission prompts are online-only and were not queued."),
            (.apnsDeviceTokenAcquisition, "Device token acquisition is online-only and was not queued."),
            (.providerSecretBlockedCoverRegeneration, "Provider-secret-blocked cover regeneration is online-only and was not queued."),
            (.providerSecretBlockedImport, "Provider-secret-blocked import is online-only and was not queued."),
            (.destructiveProductionApproval, "Destructive production approvals are online-only and were not queued.")
        ]

        for (action, reason) in onlineOnlyCases {
            #expect(try NativeOfflineMutationPolicy.decision(for: action).onlineOnlyReason == reason)
        }
    }

    @Test("retry schedule uses exact Offline Product Contract backoff with capped jitter")
    func retryScheduleUsesExactOfflineProductContractBackoffWithCappedJitter() {
        let schedule = NativeSyncRetrySchedule()

        #expect(schedule.baseDelaySeconds(forRetryCount: 0) == 5)
        #expect(schedule.baseDelaySeconds(forRetryCount: 1) == 30)
        #expect(schedule.baseDelaySeconds(forRetryCount: 2) == 300)
        #expect(schedule.baseDelaySeconds(forRetryCount: 3) == 1_800)
        #expect(schedule.baseDelaySeconds(forRetryCount: 99) == 1_800)
        #expect(schedule.jitteredDelaySeconds(forRetryCount: 1, randomUnit: 0.0) == 24)
        #expect(schedule.jitteredDelaySeconds(forRetryCount: 1, randomUnit: 0.5) == 30)
        #expect(schedule.jitteredDelaySeconds(forRetryCount: 1, randomUnit: 1.0) == 36)
        #expect(schedule.jitteredDelaySeconds(forRetryCount: 3, randomUnit: 1.0) == 2_160)
    }

    @Test("sync trigger coordinator starts bootstrap and drain for lifecycle network account environment and stale surface events")
    func syncTriggerCoordinatorStartsBootstrapAndDrainForLifecycleNetworkAccountEnvironmentAndStaleSurfaceEvents() async throws {
        let runner = RecordingNativeSyncTriggerRunner()
        let scope = NativeSyncExecutionScope(expectedAccountID: "chef_ari", environment: .production)
        let coordinator = NativeSyncTriggerCoordinator(runner: runner, configuration: configuration, scope: scope)

        try await coordinator.handle(.launch)
        try await coordinator.handle(.foreground)
        try await coordinator.handle(.accountChanged(accountID: "chef_new"))
        try await coordinator.handle(.environmentChanged(.production))
        try await coordinator.handle(.networkRecovered)
        try await coordinator.handle(.visibleStaleSurface(.recipeDetail(id: "recipe_lemon")))

        #expect(await runner.triggers == [
            .launch,
            .foreground,
            .accountChanged,
            .environmentChanged,
            .networkRecovered,
            .visibleSurfaceOpened
        ])
        #expect(await runner.configurationBaseURLs == Array(repeating: configuration.baseURL, count: 6))
        #expect(await runner.scopes == Array(repeating: scope, count: 6))
    }

    @Test("sync engine bootstraps reads drains FIFO per dependency key and removes replayed mutations")
    func syncEngineBootstrapsReadsDrainsFIFOPerDependencyKeyAndRemovesReplayedMutations() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                .recipeUpdate(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_first", title: "One", description: nil, servings: nil, createdAt: Self.createdAt(0)),
                .recipeDelete(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_second", createdAt: Self.createdAt(1)),
                .shoppingAddItem(name: "lemons", quantity: 4, unit: "each", categoryKey: nil, iconKey: nil, clientMutationID: "cm_shopping_parallel", createdAt: Self.createdAt(2))
            ]
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: try NativeSyncCheckpoint(globalCursor: PaginationCursor(rawValue: "cursor_before"), shoppingCursor: nil, updatedAt: "2026-06-16T09:02:00.000Z"),
            queue: queue
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: PaginationCursor(rawValue: "cursor_after_bootstrap"), tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt("2026-06-16T09:03:00.000Z")),
                .success(serverRevision: .tombstone("recipe_lemon_deleted")),
                .success(serverRevision: .updatedAt("2026-06-16T09:03:02.000Z"))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: boundScope)

        #expect(report.trigger == .foreground)
        #expect(report.bootstrapCursor?.rawValue == "cursor_after_bootstrap")
        #expect(report.drainedClientMutationIDs == ["cm_recipe_first", "cm_recipe_second", "cm_shopping_parallel"])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/recipes/recipe_lemon",
            "/api/v1/recipes/recipe_lemon",
            "/api/v1/shopping-list/items"
        ])
        #expect(await transport.bootstrapQueryItems == [
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "cursor", value: "cursor_before")
        ])
        #expect(await transport.clientMutationIDs == ["cm_recipe_first", "cm_recipe_second", "cm_shopping_parallel"])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(try await store.loadCheckpoint().globalCursor?.rawValue == "cursor_after_bootstrap")
        #expect(try await store.tombstones.map(\.token) == ["recipe_lemon_deleted"])
    }

    @Test("sync engine rewrites local optimistic recipe and step ids after create responses")
    func syncEngineRewritesLocalOptimisticRecipeAndStepIDsAfterCreateResponses() async throws {
        let create = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_create_local",
            title: "Offline Toast",
            description: nil,
            servings: "2",
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Toast",
                    description: "Toast bread.",
                    duration: 120,
                    ingredients: [
                        RecipeIngredientDraft(quantity: 2, unit: "cup", name: "zucchini"),
                        RecipeIngredientDraft(quantity: 1, unit: "whole", name: "apple")
                    ],
                    outputStepNums: []
                )
            ],
            createdAt: Self.createdAt(0)
        )
        let updateRecipe = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_local_cm_recipe_create_local",
            clientMutationID: "cm_recipe_update_local",
            title: "Offline Toast Edited",
            description: nil,
            servings: "4",
            createdAt: Self.createdAt(1)
        )
        let updateStep = NativeQueuedMutation.recipeStepUpdate(
            recipeID: "recipe_local_cm_recipe_create_local",
            stepID: "step_local_cm_recipe_create_local_1",
            clientMutationID: "cm_step_update_local",
            stepTitle: "Toast bread",
            description: "Toast bread until deeply golden.",
            duration: 180,
            outputStepNums: [],
            createdAt: Self.createdAt(2)
        )
        let deleteIngredient = NativeQueuedMutation.recipeIngredientDelete(
            recipeID: "recipe_local_cm_recipe_create_local",
            stepID: "step_local_cm_recipe_create_local_1",
            ingredientID: "ingredient_local_cm_recipe_create_local_1_1",
            clientMutationID: "cm_ingredient_delete_local",
            createdAt: Self.createdAt(3)
        )
        let queue = try NativeMutationQueue(mutations: [create, updateRecipe, updateStep, deleteIngredient])
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: nil, idRemaps: [
                    NativeSyncIDRemap(localID: "recipe_local_cm_recipe_create_local", serverID: "recipe_server_created"),
                    NativeSyncIDRemap(localID: "step_local_cm_recipe_create_local_1", serverID: "step_server_created"),
                    NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_local_1_1", serverID: "ingredient_server_zucchini"),
                    NativeSyncIDRemap(localID: "ingredient_local_cm_recipe_create_local_1_2", serverID: "ingredient_server_apple")
                ]),
                .success(serverRevision: .updatedAt("2026-06-16T09:03:00.000Z")),
                .success(serverRevision: .updatedAt("2026-06-16T09:04:00.000Z")),
                .success(serverRevision: .tombstone("ingredient_server_zucchini_deleted"))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let drainedCreate = try #require(report.drainedMutations.first)
        let optimisticCreated = drainedCreate.applyingOptimisticRecipeMutation(
            to: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(3)
        )
        let persistedRecord = try #require(await store.cachedRecord(kind: .recipe, resourceID: "recipe_server_created"))
        let persistedRecipe = try Self.recipe(from: persistedRecord.payload)

        #expect(report.drainedClientMutationIDs == [
            "cm_recipe_create_local",
            "cm_recipe_update_local",
            "cm_step_update_local",
            "cm_ingredient_delete_local"
        ])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/recipes",
            "/api/v1/recipes/recipe_server_created",
            "/api/v1/recipes/recipe_server_created/steps/step_server_created",
            "/api/v1/recipes/recipe_server_created/steps/step_server_created/ingredients/ingredient_server_zucchini"
        ])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(optimisticCreated.map(\.id) == ["recipe_server_created"])
        #expect(optimisticCreated.first?.steps.map(\.id) == ["step_server_created"])
        #expect(optimisticCreated.first?.steps.first?.ingredients.map(\.id) == ["ingredient_server_zucchini", "ingredient_server_apple"])
        #expect(persistedRecipe.id == "recipe_server_created")
        #expect(persistedRecipe.title == "Offline Toast Edited")
        #expect(persistedRecipe.servings == "4")
        #expect(persistedRecipe.steps.map(\.id) == ["step_server_created"])
        #expect(persistedRecipe.steps.first?.description == "Toast bread until deeply golden.")
        #expect(persistedRecipe.steps.first?.ingredients.map(\.id) == ["ingredient_server_apple"])
    }

    @Test("drained recipe mutations persist to file backed cache for restart")
    func drainedRecipeMutationsPersistToFileBackedCacheForRestart() async throws {
        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let lemonRecipe = Self.optimisticRecipe()
            let archivedRecipe = Self.optimisticRecipe(id: "recipe_archived", title: "Archived Recipe")
            let update = NativeQueuedMutation.recipeUpdate(
                recipeID: lemonRecipe.id,
                clientMutationID: "cm_recipe_restart_update",
                title: "Restart Lemon Pasta",
                description: "Still bright after restart.",
                servings: "6",
                createdAt: Self.createdAt(2)
            )
            let delete = NativeQueuedMutation.recipeDelete(
                recipeID: archivedRecipe.id,
                clientMutationID: "cm_recipe_restart_delete",
                createdAt: Self.createdAt(3)
            )
            let fallback = NativeSyncSnapshot(
                accountID: "chef_ari",
                environment: .local,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [update, delete]),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .recipe, resourceID: lemonRecipe.id, payload: try Self.jsonValue(lemonRecipe), serverRevision: .updatedAt(lemonRecipe.updatedAt)),
                    NativeSyncCachedRecord(kind: .recipe, resourceID: archivedRecipe.id, payload: try Self.jsonValue(archivedRecipe), serverRevision: .updatedAt(archivedRecipe.updatedAt))
                ],
                tombstones: []
            )
            let store = try FileBackedNativeSyncStore(fileURL: storeURL, fallback: fallback)
            let transport = RecordingNativeSyncTransport(
                bootstrap: .success(cursor: nil, tombstones: []),
                mutationResults: [
                    .success(serverRevision: .updatedAt(Self.createdAt(4))),
                    .success(serverRevision: .tombstone("recipe_archived_deleted"))
                ]
            )
            let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

            let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
            let restored = try FileBackedNativeSyncStore(fileURL: storeURL)
            let restoredLemonRecord = try #require(try await restored.cachedRecord(kind: .recipe, resourceID: lemonRecipe.id))
            let restoredLemon = try Self.recipe(from: restoredLemonRecord.payload)

            #expect(report.drainedClientMutationIDs == ["cm_recipe_restart_update", "cm_recipe_restart_delete"])
            #expect(try await restored.loadQueue().mutations.isEmpty)
            #expect(restoredLemon.title == "Restart Lemon Pasta")
            #expect(restoredLemon.description == "Still bright after restart.")
            #expect(restoredLemon.servings == "6")
            #expect(try await restored.cachedRecord(kind: .recipe, resourceID: archivedRecipe.id) == nil)
            #expect(await transport.requestPaths == [
                "/api/v1/me/sync",
                "/api/v1/recipes/recipe_lemon",
                "/api/v1/recipes/recipe_archived"
            ])
        }
    }

    @Test("sync engine rewrites dependent shopping item ids after add drains")
    func syncEngineRewritesDependentShoppingItemIDsAfterAddDrains() async throws {
        let add = NativeQueuedMutation.shoppingAddItem(
            name: "pepper",
            quantity: 1,
            unit: "jar",
            categoryKey: "pantry",
            iconKey: "jar",
            clientMutationID: "cm_shopping_add_pepper",
            createdAt: Self.createdAt(0)
        )
        let check = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_local_cm_shopping_add_pepper",
            checked: true,
            clientMutationID: "cm_shopping_check_pepper",
            createdAt: Self.createdAt(1)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [add, check])
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt(Self.createdAt(2)), idRemaps: [
                    NativeSyncIDRemap(localID: "item_local_cm_shopping_add_pepper", serverID: "item_server_pepper")
                ]),
                .success(serverRevision: .updatedAt(Self.createdAt(3)))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let optimisticList = report.drainedMutations.reduce(
            ShoppingListState(
                id: "shopping_list_test",
                chef: ChefSummary(id: "chef_ari", username: "ari"),
                items: [],
                nextCursor: "",
                updatedAt: Self.createdAt(0)
            )
        ) { list, mutation in
            mutation.applyingOptimisticShoppingMutation(
                to: list,
                recipes: [],
                fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
                now: mutation.createdAt
            ) ?? list
        }

        #expect(report.drainedClientMutationIDs == ["cm_shopping_add_pepper", "cm_shopping_check_pepper"])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/shopping-list/items",
            "/api/v1/shopping-list/items/item_server_pepper"
        ])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(optimisticList.item(id: "item_server_pepper")?.name == "pepper")
        #expect(optimisticList.item(id: "item_server_pepper")?.checked == true)
        #expect(optimisticList.item(id: "item_local_cm_shopping_add_pepper") == nil)
    }

    @Test("sync engine rewrites dependent shopping item ids after add-from-recipe drains")
    func syncEngineRewritesDependentShoppingItemIDsAfterAddFromRecipeDrains() async throws {
        let addRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_lemon",
            scaleFactor: 2,
            clientMutationID: "cm_shopping_recipe",
            createdAt: Self.createdAt(0)
        )
        let checkLemon = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_local_cm_shopping_recipe-ingredient-2",
            checked: true,
            clientMutationID: "cm_shopping_check_recipe_lemon",
            createdAt: Self.createdAt(1)
        )
        let recipe = Self.optimisticRecipe()
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [addRecipe, checkLemon]),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: recipe.id,
                    payload: try Self.jsonValue(recipe),
                    serverRevision: .updatedAt(recipe.updatedAt)
                )
            ]
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt(Self.createdAt(2)), idRemaps: [
                    NativeSyncIDRemap(localID: "item_local_cm_shopping_recipe-ingredient-1", serverID: "item_server_water"),
                    NativeSyncIDRemap(localID: "item_local_cm_shopping_recipe-ingredient-2", serverID: "item_server_lemon")
                ]),
                .success(serverRevision: .updatedAt(Self.createdAt(3)))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let lemonRecord = try #require(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_server_lemon"))
        let lemon = try Self.shoppingItem(from: lemonRecord.payload)

        #expect(report.drainedClientMutationIDs == ["cm_shopping_recipe", "cm_shopping_check_recipe_lemon"])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/shopping-list/add-from-recipe",
            "/api/v1/shopping-list/items/item_server_lemon"
        ])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(lemon.name == "lemon")
        #expect(lemon.quantity == 2)
        #expect(lemon.checked == true)
        #expect(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_shopping_recipe-ingredient-2") == nil)
    }

    @Test("drained add-from-recipe replays queued ingredient descriptors without cached recipe")
    func drainedAddFromRecipeReplaysQueuedIngredientDescriptorsWithoutCachedRecipe() async throws {
        let addRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_uncached_layer_cake",
            scaleFactor: 2,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar_a", name: "sugar", quantity: 1, unit: "cup"),
                RecipeIngredient(id: "ingredient_sugar_b", name: "sugar", quantity: 0.5, unit: "cup")
            ],
            clientMutationID: "cm_shopping_uncached_recipe",
            createdAt: Self.createdAt(0)
        )
        let checkSugar = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_local_cm_shopping_uncached_recipe-ingredient-1",
            checked: true,
            clientMutationID: "cm_shopping_check_uncached_sugar",
            createdAt: Self.createdAt(1)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [addRecipe, checkSugar])
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt(Self.createdAt(2)), idRemaps: [
                    NativeSyncIDRemap(localID: "item_local_cm_shopping_uncached_recipe-ingredient-1", serverID: "item_server_sugar"),
                    NativeSyncIDRemap(localID: "item_local_cm_shopping_uncached_recipe-ingredient-2", serverID: "item_server_sugar")
                ]),
                .success(serverRevision: .updatedAt(Self.createdAt(3)))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let sugarRecord = try #require(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_server_sugar"))
        let sugar = try Self.shoppingItem(from: sugarRecord.payload)

        #expect(report.drainedClientMutationIDs == ["cm_shopping_uncached_recipe", "cm_shopping_check_uncached_sugar"])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/shopping-list/add-from-recipe",
            "/api/v1/shopping-list/items/item_server_sugar"
        ])
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(sugar.name == "sugar")
        #expect(sugar.quantity == 3)
        #expect(sugar.unit == "cup")
        #expect(sugar.checked == true)
        #expect(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_shopping_uncached_recipe-ingredient-1") == nil)
        #expect(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_shopping_uncached_recipe-ingredient-2") == nil)
    }

    @Test("drained shopping mutations persist to file backed cache for restart")
    func drainedShoppingMutationsPersistToFileBackedCacheForRestart() async throws {
        try await withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("sync.json")
            let salt = Self.shoppingItem(id: "item_salt", name: "salt", quantity: 1, unit: "pinch")
            let add = NativeQueuedMutation.shoppingAddItem(
                name: "pepper",
                quantity: 1,
                unit: "jar",
                categoryKey: "pantry",
                iconKey: "jar",
                clientMutationID: "cm_shopping_restart_add",
                createdAt: Self.createdAt(2)
            )
            let check = NativeQueuedMutation.shoppingCheckItem(
                itemID: "item_local_cm_shopping_restart_add",
                checked: true,
                clientMutationID: "cm_shopping_restart_check",
                createdAt: Self.createdAt(3)
            )
            let fallback = NativeSyncSnapshot(
                accountID: "chef_ari",
                environment: .local,
                checkpoint: nil,
                queue: try NativeMutationQueue(mutations: [add, check]),
                cachedRecords: [
                    NativeSyncCachedRecord(kind: .shoppingItem, resourceID: salt.id, payload: try Self.jsonValue(salt), serverRevision: .updatedAt(salt.updatedAt))
                ],
                tombstones: []
            )
            let store = try FileBackedNativeSyncStore(fileURL: storeURL, fallback: fallback)
            let transport = RecordingNativeSyncTransport(
                bootstrap: .success(cursor: nil, tombstones: []),
                mutationResults: [
                    .success(serverRevision: .updatedAt(Self.createdAt(4)), idRemaps: [
                        NativeSyncIDRemap(localID: "item_local_cm_shopping_restart_add", serverID: "item_server_pepper")
                    ]),
                    .success(serverRevision: .updatedAt(Self.createdAt(5)))
                ]
            )
            let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

            let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
            let restored = try FileBackedNativeSyncStore(fileURL: storeURL)
            let restoredPepperRecord = try #require(try await restored.cachedRecord(kind: .shoppingItem, resourceID: "item_server_pepper"))
            let restoredSaltRecord = try #require(try await restored.cachedRecord(kind: .shoppingItem, resourceID: "item_salt"))
            let restoredPepper = try Self.shoppingItem(from: restoredPepperRecord.payload)
            let restoredSalt = try Self.shoppingItem(from: restoredSaltRecord.payload)

            #expect(report.drainedClientMutationIDs == ["cm_shopping_restart_add", "cm_shopping_restart_check"])
            #expect(try await restored.loadQueue().mutations.isEmpty)
            #expect(restoredSalt.name == "salt")
            #expect(restoredPepper.id == "item_server_pepper")
            #expect(restoredPepper.name == "pepper")
            #expect(restoredPepper.checked == true)
            #expect(try await restored.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_shopping_restart_add") == nil)
            #expect(await transport.requestPaths == [
                "/api/v1/me/sync",
                "/api/v1/shopping-list/items",
                "/api/v1/shopping-list/items/item_server_pepper"
            ])
        }
    }

    @Test("drained shopping cache patch deletes removed cached rows and timestamps from first drained mutation")
    func drainedShoppingCachePatchDeletesRemovedCachedRowsAndTimestampsFromFirstDrainedMutation() async throws {
        let salt = Self.shoppingItem(id: "item_salt", name: "salt", quantity: 1, unit: "pinch")
        let clearAll = NativeQueuedMutation.shoppingClearAll(
            clientMutationID: "cm_clear_cached_shopping",
            createdAt: Self.createdAt(3)
        )
        let add = NativeQueuedMutation.shoppingAddItem(
            name: "pepper",
            quantity: 1,
            unit: "jar",
            categoryKey: "pantry",
            iconKey: "jar",
            clientMutationID: "cm_add_after_clear",
            createdAt: Self.createdAt(4)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [clearAll, add]),
            cachedRecords: [
                NativeSyncCachedRecord(
                    kind: .shoppingItem,
                    resourceID: salt.id,
                    payload: try Self.jsonValue(salt),
                    serverRevision: .updatedAt(salt.updatedAt)
                )
            ]
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt(Self.createdAt(5))),
                .success(serverRevision: .updatedAt(Self.createdAt(6)))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let pepperRecord = try #require(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_local_cm_add_after_clear"))
        let pepper = try Self.shoppingItem(from: pepperRecord.payload)

        #expect(report.drainedClientMutationIDs == ["cm_clear_cached_shopping", "cm_add_after_clear"])
        #expect(try await store.cachedRecord(kind: .shoppingItem, resourceID: "item_salt") == nil)
        #expect(pepper.name == "pepper")
        #expect(pepper.updatedAt == Self.createdAt(3))
    }

    @Test("sync engine records step and ingredient create id remaps for drained optimistic mutations")
    func syncEngineRecordsStepAndIngredientCreateIDRemapsForDrainedOptimisticMutations() async throws {
        let createStep = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_step_create_remote",
            stepNum: 2,
            stepTitle: "Plate",
            description: "Plate with herbs.",
            duration: nil,
            ingredients: [RecipeIngredientDraft(quantity: 3, unit: "leaf", name: "basil")],
            outputStepNums: [1],
            createdAt: Self.createdAt(0)
        )
        let addIngredient = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_lemon",
            stepID: "step_one",
            clientMutationID: "cm_ingredient_add_remote",
            quantity: 2,
            unit: "tbsp",
            name: "olive oil",
            createdAt: Self.createdAt(1)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [createStep, addIngredient])
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: nil, idRemaps: [
                    NativeSyncIDRemap(localID: "step_local_cm_step_create_remote", serverID: "step_server_created_remote"),
                    NativeSyncIDRemap(localID: "ingredient_local_cm_step_create_remote_1", serverID: "ingredient_server_stale_remote"),
                    NativeSyncIDRemap(localID: "ingredient_local_cm_step_create_remote_1", serverID: "ingredient_server_created_remote")
                ]),
                .success(serverRevision: nil, idRemaps: [
                    NativeSyncIDRemap(localID: "ingredient_local_cm_ingredient_add_remote", serverID: "ingredient_server_created_remote")
                ])
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let stepOverlay = report.drainedMutations[0].applyingOptimisticRecipeMutation(
            to: [Self.optimisticRecipe()],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(2)
        )
        let ingredientOverlay = report.drainedMutations[1].applyingOptimisticRecipeMutation(
            to: [Self.optimisticRecipe()],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(3)
        )

        #expect(report.drainedClientMutationIDs == ["cm_step_create_remote", "cm_ingredient_add_remote"])
        #expect(await transport.requestPaths == [
            "/api/v1/me/sync",
            "/api/v1/recipes/recipe_lemon/steps",
            "/api/v1/recipes/recipe_lemon/steps/step_one/ingredients"
        ])
        #expect(stepOverlay.first?.steps.map(\.id).contains("step_server_created_remote") == true)
        #expect(stepOverlay.first?.steps.first(where: { $0.id == "step_server_created_remote" })?.ingredients.map(\.id) == ["ingredient_server_created_remote"])
        #expect(ingredientOverlay.first?.steps.first?.ingredients.map(\.id).contains("ingredient_server_created_remote") == true)

        let recordedStepWithoutIngredientRemap = createStep.recordingIDRemaps([
            NativeSyncIDRemap(localID: "step_local_cm_step_create_remote", serverID: "step_server_without_ingredient_remap")
        ])
        let stepWithoutIngredientRemap = recordedStepWithoutIngredientRemap.applyingOptimisticRecipeMutation(
            to: [Self.optimisticRecipe()],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(4)
        )
        #expect(stepWithoutIngredientRemap.first?.steps.first(where: { $0.id == "step_server_without_ingredient_remap" })?.ingredients.map(\.id) == ["ingredient_local_cm_step_create_remote_1"])

        let malformedRecipeCreate = try Self.decodedMutation(
            type: .recipeCreate,
            fields: [
                "steps": [
                    "not-a-step-object",
                    [
                        "ingredients": [
                            ["name": "salt", "quantity": 1, "unit": "pinch"],
                            ["name": "oil", "quantity": 2, "unit": "tbsp"]
                        ]
                    ]
                ]
            ]
        )
        let recordedMalformedRecipeCreate = malformedRecipeCreate.recordingIDRemaps([
            NativeSyncIDRemap(localID: "recipe_local_cm_decode", serverID: "recipe_server_decode"),
            NativeSyncIDRemap(localID: "step_local_cm_decode_2", serverID: "step_server_decode")
        ])
        let malformedRecipeOverlay = recordedMalformedRecipeCreate.applyingOptimisticRecipeMutation(
            to: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(5)
        )
        #expect(malformedRecipeOverlay.first?.id == "recipe_server_decode")
        #expect(malformedRecipeOverlay.first?.steps.map(\.id) == ["step_local_cm_decode_1", "step_server_decode"])
        #expect(malformedRecipeOverlay.first?.steps[1].ingredients.map(\.id) == [
            "ingredient_local_cm_decode_2_1",
            "ingredient_local_cm_decode_2_2"
        ])
    }

    @Test("queued mutation resource id replacement targets identifier fields only")
    func queuedMutationResourceIDReplacementTargetsIdentifierFieldsOnly() throws {
        let stepUpdate = NativeQueuedMutation.recipeStepUpdate(
            recipeID: "recipe_local_target",
            stepID: "step_local_target",
            clientMutationID: "cm_targeted_step",
            stepTitle: nil,
            description: "recipe_local_target remains ordinary text here",
            duration: nil,
            outputStepNums: [1],
            createdAt: Self.createdAt(0)
        )
        let replacedStepUpdate = stepUpdate.replacingResourceIDs([
            "recipe_local_target": "recipe_server_target",
            "step_local_target": "step_server_target"
        ])
        let stepUpdateRequest = try replacedStepUpdate.requestBuilder().urlRequest(configuration: configuration)
        let stepUpdateBody = try decodedJSONBody(from: stepUpdateRequest)

        #expect(stepUpdateRequest.url.path == "/api/v1/recipes/recipe_server_target/steps/step_server_target")
        #expect(stepUpdateBody["description"] as? String == "recipe_local_target remains ordinary text here")
        #expect(stepUpdateBody["stepId"] == nil)

        let outputUses = NativeQueuedMutation.recipeOutputUsesReplace(
            recipeID: "recipe_local_target",
            inputStepID: "step_local_target",
            outputStepNums: [1, 3],
            clientMutationID: "cm_targeted_output",
            createdAt: Self.createdAt(1)
        )
        let replacedOutputUses = outputUses.replacingResourceIDs([
            "recipe_local_target": "recipe_server_target",
            "step_local_target": "step_server_target"
        ])
        let outputRequest = try replacedOutputUses.requestBuilder().urlRequest(configuration: configuration)
        let outputBody = try decodedJSONBody(from: outputRequest)

        #expect(outputRequest.url.path == "/api/v1/recipes/recipe_server_target/step-output-uses")
        #expect(outputBody["inputStepId"] as? String == "step_server_target")

        let ingredientDelete = NativeQueuedMutation.recipeIngredientDelete(
            recipeID: "recipe_local_target",
            stepID: "step_local_target",
            ingredientID: "ingredient_local_target",
            clientMutationID: "cm_targeted_ingredient",
            createdAt: Self.createdAt(2)
        )
        let replacedIngredientDelete = ingredientDelete.replacingResourceIDs([
            "recipe_local_target": "recipe_server_target",
            "step_local_target": "step_server_target",
            "ingredient_local_target": "ingredient_server_target"
        ])
        let ingredientDeleteRequest = try replacedIngredientDelete.requestBuilder().urlRequest(configuration: configuration)

        #expect(ingredientDeleteRequest.url.path == "/api/v1/recipes/recipe_server_target/steps/step_server_target/ingredients/ingredient_server_target")

        let captureMutation = NativeQueuedMutation.captureDraftCreate(
            draftID: "draft_nested_source",
            source: .text("recipe_local_target"),
            clientMutationID: "cm_nested_source",
            createdAt: Self.createdAt(3)
        )
        let replacedCapture = captureMutation.replacingResourceIDs([
            "recipe_local_target": "recipe_server_target"
        ])
        let captureJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [replacedCapture])), encoding: .utf8))

        #expect(captureJSON.contains("recipe_local_target"))
        #expect(captureJSON.contains("recipe_server_target") == false)

        let recipeCreate = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_nested_array",
            title: "Nested Array",
            description: nil,
            servings: nil,
            steps: [
                RecipeStepDraft(
                    stepNum: 1,
                    stepTitle: "Prep",
                    description: "step_local_target",
                    duration: nil,
                    ingredients: [],
                    outputStepNums: []
                )
            ],
            createdAt: Self.createdAt(4)
        )
        let arrayReplaced = recipeCreate.replacingResourceIDs([
            "step_local_target": "step_server_target"
        ])
        let arrayJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [arrayReplaced])), encoding: .utf8))
        let partialRecorded = recipeCreate.recordingIDRemaps([
            NativeSyncIDRemap(localID: "recipe_local_cm_nested_array", serverID: "recipe_server_partial")
        ])
        let partialOptimistic = partialRecorded.applyingOptimisticRecipeMutation(
            to: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(5)
        )
        let shopping = NativeQueuedMutation.shoppingAddItem(
            name: "recipe_local_target",
            quantity: 2,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_default_remap",
            createdAt: Self.createdAt(6)
        )
        let shoppingReplaced = shopping.replacingResourceIDs([
            "recipe_local_target": "recipe_server_target"
        ])
        let shoppingJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [shoppingReplaced])), encoding: .utf8))

        #expect(arrayJSON.contains("step_local_target"))
        #expect(arrayJSON.contains("step_server_target") == false)
        #expect(partialOptimistic.first?.id == "recipe_server_partial")
        #expect(partialOptimistic.first?.steps.map(\.id) == ["step_local_cm_nested_array_1"])
        #expect(shoppingJSON.contains("recipe_local_target"))
        #expect(shoppingJSON.contains("recipe_server_target") == false)
        let recordedShopping = shopping.recordingIDRemaps([
            NativeSyncIDRemap(localID: "item_local_cm_default_remap", serverID: "item_server_default")
        ])
        let recordedShoppingList = recordedShopping.applyingOptimisticShoppingMutation(
            to: nil,
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(7)
        )
        let recordedShoppingJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [recordedShopping])), encoding: .utf8))
        let recordedShoppingRequestBody = try #require(
            try recordedShopping.requestBuilder().urlRequest(configuration: configuration).body.flatMap { String(data: $0, encoding: .utf8) }
        )
        #expect(recordedShoppingList?.item(id: "item_server_default")?.name == "recipe_local_target")
        #expect(recordedShoppingList?.item(id: "item_local_cm_default_remap") == nil)
        #expect(recordedShoppingJSON.contains("serverItemId") == true)
        #expect(recordedShoppingRequestBody.contains("serverItemId") == false)

        let addRecipe = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_lemon",
            scaleFactor: 1,
            clientMutationID: "cm_recipe_items_remap",
            createdAt: Self.createdAt(8)
        ).recordingIDRemaps([
            NativeSyncIDRemap(localID: "item_local_cm_recipe_items_remap-ingredient-1", serverID: "item_server_water"),
            NativeSyncIDRemap(localID: "item_local_cm_recipe_items_remap-ingredient-2", serverID: "item_server_lemon")
        ])
        let addRecipeJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [addRecipe])), encoding: .utf8))
        let addRecipeRequestBody = try #require(
            try addRecipe.requestBuilder().urlRequest(configuration: configuration).body.flatMap { String(data: $0, encoding: .utf8) }
        )
        let addRecipeList = addRecipe.applyingOptimisticShoppingMutation(
            to: nil,
            recipes: [Self.optimisticRecipe()],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(9)
        )
        #expect(addRecipeList?.activeItems.map(\.id) == ["item_server_water", "item_server_lemon"])
        #expect(addRecipeJSON.contains("serverItemIds") == true)
        #expect(addRecipeRequestBody.contains("serverItemIds") == false)
        #expect(addRecipeRequestBody.contains("item_server_lemon") == false)
    }

    @Test("stale shopping check mutations preserve the current list")
    func staleShoppingCheckMutationsPreserveTheCurrentList() {
        let salt = Self.shoppingItem(id: "item_salt", name: "salt", quantity: 1, unit: "pinch")
        let list = ShoppingListState(
            id: "shopping_list_test",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [salt],
            nextCursor: "",
            updatedAt: Self.createdAt(0)
        )
        let staleCheck = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_missing",
            checked: true,
            clientMutationID: "cm_stale_check",
            createdAt: Self.createdAt(1)
        )

        let updated = staleCheck.applyingOptimisticShoppingMutation(
            to: list,
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(2)
        )

        #expect(updated == list)
    }

    @Test("optimistic shopping check and clear completed update stale timestamps")
    func optimisticShoppingCheckAndClearCompletedUpdateStaleTimestamps() throws {
        let checkedSalt = ShoppingListItem(
            id: "item_salt",
            name: "salt",
            quantity: 1,
            unit: "pinch",
            checked: true,
            checkedAt: Self.createdAt(1),
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: Self.createdAt(1)
        )
        let staleCompletedPepper = ShoppingListItem(
            id: "item_pepper",
            name: "pepper",
            quantity: 1,
            unit: "pinch",
            checked: false,
            checkedAt: Self.createdAt(2),
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 1,
            updatedAt: Self.createdAt(2)
        )
        let list = ShoppingListState(
            id: "shopping_list_test",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [checkedSalt, staleCompletedPepper],
            nextCursor: "",
            updatedAt: Self.createdAt(0)
        )
        let emptyList = ShoppingListState(
            id: "shopping_list_empty",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [],
            nextCursor: "",
            updatedAt: Self.createdAt(0)
        )
        let unchecked = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_salt",
            checked: false,
            clientMutationID: "cm_uncheck_salt",
            createdAt: Self.createdAt(3)
        ).applyingOptimisticShoppingMutation(
            to: list,
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(3)
        )

        #expect(unchecked?.item(id: "item_salt")?.checked == false)
        #expect(unchecked?.item(id: "item_salt")?.checkedAt == nil)
        #expect(unchecked?.item(id: "item_salt")?.updatedAt == Self.createdAt(3))

        let uncheckedOnlyCompleted = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_salt",
            checked: false,
            clientMutationID: "cm_uncheck_only_completed",
            createdAt: Self.createdAt(3)
        ).applyingOptimisticShoppingMutation(
            to: ShoppingListState(
                id: "shopping_list_completed_only",
                chef: ChefSummary(id: "chef_ari", username: "ari"),
                items: [checkedSalt],
                nextCursor: "",
                updatedAt: Self.createdAt(0)
            ),
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(3)
        )
        #expect(uncheckedOnlyCompleted?.item(id: "item_salt")?.sortIndex == 0)

        let checkedMissingOnEmptyList = NativeQueuedMutation.shoppingCheckItem(
            itemID: "item_missing",
            checked: true,
            clientMutationID: "cm_check_missing_empty",
            createdAt: Self.createdAt(3)
        ).applyingOptimisticShoppingMutation(
            to: emptyList,
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(3)
        )
        #expect(checkedMissingOnEmptyList == emptyList)

        let cleared = NativeQueuedMutation.shoppingClearCompleted(
            clientMutationID: "cm_clear_completed",
            createdAt: Self.createdAt(4)
        ).applyingOptimisticShoppingMutation(
            to: list,
            recipes: [],
            fallbackChef: ChefSummary(id: "chef_ari", username: "ari"),
            now: Self.createdAt(4)
        )

        #expect(cleared?.activeItems.isEmpty == true)
        #expect(cleared?.item(id: "item_salt")?.deletedAt == Self.createdAt(4))
        #expect(cleared?.item(id: "item_pepper")?.deletedAt == Self.createdAt(4))
    }

    @Test("optimistic shopping mutations fail closed for malformed replay payloads")
    func optimisticShoppingMutationsFailClosedForMalformedReplayPayloads() throws {
        let salt = Self.shoppingItem(id: "item_salt", name: "salt", quantity: 1, unit: "pinch")
        let list = ShoppingListState(
            id: "shopping_list_test",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [salt],
            nextCursor: "",
            updatedAt: Self.createdAt(0)
        )
        let fallbackChef = ChefSummary(id: "chef_ari", username: "ari")

        let missingNameAdd = try Self.decodedMutation(type: .shoppingAddItem, fields: [:])
        let blankNameAdd = try Self.decodedMutation(type: .shoppingAddItem, fields: ["name": "  "])
        let missingChecked = try Self.decodedMutation(type: .shoppingCheckItem, fields: ["itemId": "item_salt"])
        let missingNameRecipeIngredient = try Self.decodedMutation(
            type: .shoppingAddFromRecipe,
            fields: [
                "recipeId": "recipe_missing_name",
                "scaleFactor": 1,
                "shoppingRecipeIngredients": [
                    ["quantity": 1, "unit": "cup"]
                ]
            ]
        )
        let fallbackRecipeIngredients = try Self.decodedMutation(
            type: .shoppingAddFromRecipe,
            fields: [
                "recipeId": "recipe_missing_scale"
            ]
        )
        let noRecipeIngredients = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_missing",
            scaleFactor: 1,
            clientMutationID: "cm_missing_recipe",
            createdAt: Self.createdAt(1)
        )
        let malformedRecipeIngredients = try Self.decodedMutation(
            type: .shoppingAddFromRecipe,
            fields: [
                "recipeId": "recipe_malformed",
                "scaleFactor": 1,
                "shoppingRecipeIngredients": [
                    "not-an-object"
                ]
            ]
        )
        let deleteSalt = NativeQueuedMutation.shoppingDeleteItem(
            itemID: "item_salt",
            clientMutationID: "cm_delete_salt",
            createdAt: Self.createdAt(2)
        )
        let deleteMissing = NativeQueuedMutation.shoppingDeleteItem(
            itemID: "item_missing",
            clientMutationID: "cm_delete_missing",
            createdAt: Self.createdAt(2)
        )
        let clearAll = NativeQueuedMutation.shoppingClearAll(
            clientMutationID: "cm_clear_all",
            createdAt: Self.createdAt(3)
        )
        let nilUnitRecipe = Self.optimisticRecipe(
            id: "recipe_missing_scale",
            steps: [
                RecipeStep(
                    id: "step_nil_unit",
                    stepNum: 1,
                    stepTitle: nil,
                    description: "Add water.",
                    duration: nil,
                    ingredients: [
                        RecipeIngredient(id: "ingredient_water", name: "water", quantity: 2, unit: nil)
                    ]
                )
            ]
        )

        #expect(missingNameAdd.optimisticRecipeID == nil)
        #expect(missingNameAdd.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4)) == list)
        #expect(blankNameAdd.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4)) == list)
        #expect(missingChecked.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4)) == list)
        #expect(missingNameRecipeIngredient.applyingOptimisticShoppingMutation(to: nil, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4))?.activeItems.isEmpty == true)
        let fallbackRecipeList = try #require(fallbackRecipeIngredients.applyingOptimisticShoppingMutation(
            to: nil,
            recipes: [nilUnitRecipe],
            fallbackChef: fallbackChef,
            now: Self.createdAt(4)
        ))
        #expect(fallbackRecipeList.item(id: "item_local_cm_decode-ingredient-1")?.quantity == 2)
        #expect(fallbackRecipeList.item(id: "item_local_cm_decode-ingredient-1")?.unit == nil)
        #expect(noRecipeIngredients.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4)) == list)
        #expect(malformedRecipeIngredients.applyingOptimisticShoppingMutation(to: nil, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(4))?.activeItems.isEmpty == true)
        #expect(deleteSalt.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(5))?.item(id: "item_salt")?.deletedAt == Self.createdAt(5))
        #expect(deleteMissing.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(5)) == list)
        #expect(clearAll.applyingOptimisticShoppingMutation(to: list, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(6))?.activeItems.isEmpty == true)
        #expect(
            NativeQueuedMutation.shoppingClearCompleted(
                clientMutationID: "cm_clear_completed_nil",
                createdAt: Self.createdAt(7)
            ).applyingOptimisticShoppingMutation(to: nil, recipes: [], fallbackChef: fallbackChef, now: Self.createdAt(7)) == nil
        )

        let aggregateMismatch = NativeQueuedMutation.shoppingAddFromRecipe(
            recipeID: "recipe_aggregate_mismatch",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_sugar_a", name: "sugar", quantity: 1, unit: "cup"),
                RecipeIngredient(id: "ingredient_sugar_b", name: "sugar", quantity: 2, unit: "cup")
            ],
            clientMutationID: "cm_aggregate_mismatch",
            createdAt: Self.createdAt(8)
        )

        let unrelatedRecorded = aggregateMismatch.recordingIDRemaps([
            NativeSyncIDRemap(localID: "item_local_other", serverID: "item_server_other")
        ])
        let unrelatedJSON = try #require(String(data: JSONEncoder().encode(NativeMutationQueue(mutations: [unrelatedRecorded])), encoding: .utf8))
        #expect(unrelatedJSON.contains("serverItemIds") == false)

        let clearRecorded = clearAll.recordingIDRemaps([
            NativeSyncIDRemap(localID: "item_local_clear", serverID: "item_server_clear")
        ])
        #expect(clearRecorded == clearAll)
    }

    @Test("sync engine blocks local recipe dependent replay when create has not drained")
    func syncEngineBlocksLocalRecipeDependentReplayWhenCreateHasNotDrained() async throws {
        let create = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_create_blocked",
            title: "Offline Pie",
            description: nil,
            servings: nil,
            steps: [],
            createdAt: Self.createdAt(0)
        )
        let update = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_local_cm_recipe_create_blocked",
            clientMutationID: "cm_recipe_update_blocked",
            title: "Offline Pie Edited",
            description: nil,
            servings: nil,
            createdAt: Self.createdAt(1)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [create, update])
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [.retry(afterSeconds: 5, message: "Recipe create still in progress.")]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let remainingQueue = try await store.loadQueue()

        #expect(report.drainedClientMutationIDs.isEmpty)
        #expect(report.retryAfterSeconds == 5)
        #expect(await transport.clientMutationIDs == ["cm_recipe_create_blocked"])
        #expect(remainingQueue.mutations.map(\.clientMutationID) == ["cm_recipe_create_blocked", "cm_recipe_update_blocked"])
        #expect(remainingQueue.mutations[0].lastError == "Recipe create still in progress.")
    }

    @Test("sync engine rewrites remaining local ids when auth failure pauses after create success")
    func syncEngineRewritesRemainingLocalIDsWhenAuthFailurePausesAfterCreateSuccess() async throws {
        let create = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_recipe_create_before_auth",
            title: "Offline Tart",
            description: nil,
            servings: nil,
            steps: [],
            createdAt: Self.createdAt(0)
        )
        let authFailure = NativeQueuedMutation.profileDisplayUpdate(
            email: "ari@example.com",
            username: "ari",
            clientMutationID: "cm_profile_auth_after_create",
            createdAt: Self.createdAt(1)
        )
        let tailUpdate = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_local_cm_recipe_create_before_auth",
            clientMutationID: "cm_recipe_tail_after_auth",
            title: "Offline Tart Edited",
            description: nil,
            servings: nil,
            createdAt: Self.createdAt(2)
        )
        let store = InMemoryNativeSyncStore(
            accountID: "chef_ari",
            environment: .local,
            checkpoint: nil,
            queue: try NativeMutationQueue(mutations: [create, authFailure, tailUpdate])
        )
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: nil, idRemaps: [
                    NativeSyncIDRemap(localID: "recipe_local_cm_recipe_create_before_auth", serverID: "recipe_server_before_auth")
                ]),
                .authFailure(message: "Session expired.")
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let remainingQueue = try await store.loadQueue()
        let tailRequest = try remainingQueue.mutations[1].requestBuilder().urlRequest(configuration: configuration)

        #expect(report.drainedClientMutationIDs == ["cm_recipe_create_before_auth"])
        #expect(report.pausedReason == .authRequired("Session expired."))
        #expect(await transport.clientMutationIDs == ["cm_recipe_create_before_auth", "cm_profile_auth_after_create"])
        #expect(remainingQueue.mutations.map(\.clientMutationID) == ["cm_profile_auth_after_create", "cm_recipe_tail_after_auth"])
        #expect(tailRequest.url.path == "/api/v1/recipes/recipe_server_before_auth")
    }

    @Test("sync engine pauses on auth failure classifies conflicts and retains the blocked queue")
    func syncEnginePausesOnAuthFailureClassifiesConflictsAndRetainsTheBlockedQueue() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                .cookbookUpdate(cookbookID: "cookbook_weeknight", title: "Weeknights", clientMutationID: "cm_cookbook_conflict", createdAt: Self.createdAt(0)),
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_auth", createdAt: Self.createdAt(1))
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: PaginationCursor(rawValue: "cursor_after_bootstrap"), tombstones: []),
            mutationResults: [
                .conflict(kind: .validation, serverRevision: .etag("\"cookbook-v8\""), message: "Cookbook was changed elsewhere."),
                .authFailure(message: "Session expired.")
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)

        #expect(report.trigger == .networkRecovered)
        #expect(report.conflicts == [
            NativeSyncConflict(
                clientMutationID: "cm_cookbook_conflict",
                kind: .validation,
                serverRevision: .etag("\"cookbook-v8\""),
                message: "Cookbook was changed elsewhere."
            )
        ])
        #expect(report.pausedReason == .authRequired("Session expired."))
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_cookbook_conflict", "cm_profile_auth"])
        #expect(try await store.loadQueue().mutations.first?.lastError == "Cookbook was changed elsewhere.")
    }

    @Test("retry results block the failed dependency key while independent mutations can still drain")
    func retryResultsBlockTheFailedDependencyKeyWhileIndependentMutationsCanStillDrain() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                .coverRegenerate(recipeID: "recipe_lemon", coverID: "cover_old", activateWhenReady: true, clientMutationID: "cm_cover_retry", createdAt: Self.createdAt(0)),
                .spoonCreate(recipeID: "recipe_lemon", clientMutationID: "cm_spoon_same_key", note: "Same recipe waits.", nextTime: nil, cookedAt: nil, photoURL: "/photos/spoons/wait.jpg", useAsRecipeCover: false, createdAt: Self.createdAt(1)),
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_independent", createdAt: Self.createdAt(2))
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .retry(afterSeconds: 30, message: "Server busy."),
                .success(serverRevision: .updatedAt("2026-06-16T09:06:00.000Z"))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch, scope: boundScope)
        let remaining = try await store.loadQueue().mutations

        #expect(report.retryAfterSeconds == 30)
        #expect(report.drainedClientMutationIDs == ["cm_profile_independent"])
        #expect(await transport.clientMutationIDs == ["cm_cover_retry", "cm_profile_independent"])
        #expect(remaining.map(\.clientMutationID) == ["cm_cover_retry", "cm_spoon_same_key"])
        #expect(remaining.first?.retryCount == 1)
        #expect(remaining.first?.nextRetryAt == "2026-05-28T23:13:50.000Z")
        #expect(remaining.first?.lastError == "Server busy.")
        #expect(remaining.last?.retryCount == 0)
    }

    @Test("scheduled retry timestamps are honored before replaying a dependency key")
    func scheduledRetryTimestampsAreHonoredBeforeReplayingADependencyKey() async throws {
        let retrying = NativeQueuedMutation
            .coverRegenerate(recipeID: "recipe_lemon", coverID: "cover_old", activateWhenReady: true, clientMutationID: "cm_cover_retry", createdAt: Self.createdAt(0))
            .recordingRetry(message: "Server busy.", nextRetryAt: "2026-05-28T23:14:20.000Z")
        let queue = try NativeMutationQueue(
            mutations: [
                retrying,
                .spoonCreate(recipeID: "recipe_lemon", clientMutationID: "cm_spoon_same_key", note: "Same recipe waits.", nextTime: nil, cookedAt: nil, photoURL: "/photos/spoons/wait.jpg", useAsRecipeCover: false, createdAt: Self.createdAt(1)),
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_independent", createdAt: Self.createdAt(2))
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [.success(serverRevision: .updatedAt("2026-06-16T09:06:00.000Z"))]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)
        let remaining = try await store.loadQueue().mutations

        #expect(report.retryAfterSeconds == 60)
        #expect(report.drainedClientMutationIDs == ["cm_profile_independent"])
        #expect(await transport.clientMutationIDs == ["cm_profile_independent"])
        #expect(remaining.map(\.clientMutationID) == ["cm_cover_retry", "cm_spoon_same_key"])
        #expect(remaining.first?.retryCount == 1)
        #expect(remaining.first?.nextRetryAt == "2026-05-28T23:14:20.000Z")
    }

    @Test("scheduled retry report keeps the shortest independent retry delay")
    func scheduledRetryReportKeepsTheShortestIndependentRetryDelay() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                NativeQueuedMutation
                    .coverRegenerate(recipeID: "recipe_lemon", coverID: "cover_old", activateWhenReady: true, clientMutationID: "cm_cover_retry_later", createdAt: Self.createdAt(0))
                    .recordingRetry(message: "Server busy.", nextRetryAt: "2026-05-28T23:14:20.000Z"),
                NativeQueuedMutation
                    .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_retry_sooner", createdAt: Self.createdAt(1))
                    .recordingRetry(message: "Server busy.", nextRetryAt: "2026-05-28T23:13:40Z")
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: []
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered, scope: boundScope)

        #expect(report.retryAfterSeconds == 20)
        #expect(report.drainedClientMutationIDs.isEmpty)
        #expect(await transport.clientMutationIDs.isEmpty)
        #expect(try await store.loadQueue().mutations.map(\.clientMutationID) == ["cm_cover_retry_later", "cm_profile_retry_sooner"])
    }

    @Test("expired retry schedules drain and tombstone revisions preserve resource families")
    func expiredRetrySchedulesDrainAndTombstoneRevisionsPreserveResourceFamilies() async throws {
        let retrying = NativeQueuedMutation
            .coverRegenerate(recipeID: "recipe_lemon", coverID: "cover_old", activateWhenReady: true, clientMutationID: "cm_retry_expired", createdAt: Self.createdAt(0))
            .recordingRetry(message: "Previous retry.", nextRetryAt: "2026-05-28T23:12:20.000Z")
        let queue = try NativeMutationQueue(
            mutations: [
                retrying,
                .cookbookDelete(cookbookID: "cookbook_weeknight", clientMutationID: "cm_cookbook_delete_tombstone", createdAt: Self.createdAt(1)),
                .spoonDelete(recipeID: "recipe_lemon", spoonID: "spoon_cooked", clientMutationID: "cm_spoon_delete_tombstone", createdAt: Self.createdAt(2)),
                .shoppingDeleteItem(itemID: "item_lemons", clientMutationID: "cm_shopping_delete_tombstone", createdAt: Self.createdAt(3)),
                .recipeUpdate(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_update_tombstone", title: "Lemon Pasta", description: nil, servings: nil, createdAt: Self.createdAt(4))
            ]
        )
        let store = InMemoryNativeSyncStore(accountID: "chef_ari", environment: .local, checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .success(serverRevision: .updatedAt("2026-06-16T09:30:00.000Z")),
                .success(serverRevision: .tombstone("cookbook_weeknight_deleted")),
                .success(serverRevision: .tombstone("spoon_cooked_deleted")),
                .success(serverRevision: .tombstone("item_lemons_deleted")),
                .success(serverRevision: .tombstone("recipe_lemon_default_deleted"))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .foreground, scope: boundScope)

        #expect(report.drainedClientMutationIDs == [
            "cm_retry_expired",
            "cm_cookbook_delete_tombstone",
            "cm_spoon_delete_tombstone",
            "cm_shopping_delete_tombstone",
            "cm_recipe_update_tombstone"
        ])
        #expect(report.retryAfterSeconds == nil)
        #expect(try await store.loadQueue().mutations.isEmpty)
        #expect(try await store.tombstones.map(\.resourceType) == [.cookbook, .spoon, .shoppingItem, .recipe])
        #expect(try await store.tombstones.map(\.parentResourceID) == [
            "cookbook_weeknight",
            "recipe_lemon",
            nil,
            "recipe_lemon"
        ])
    }

    @Test("bootstrap tombstones are recorded with checkpoint cursors")
    func bootstrapTombstonesAreRecordedWithCheckpointCursors() async throws {
        let tombstone = NativeSyncTombstone(
            resourceType: .cookbook,
            resourceID: "cookbook_removed_bootstrap",
            parentResourceID: nil,
            title: "Removed cookbook",
            deletedAt: "2026-06-16T09:30:00.000Z",
            updatedAt: "2026-06-16T09:31:00.000Z"
        )
        let store = InMemoryNativeSyncStore(checkpoint: nil, queue: NativeMutationQueue())
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: PaginationCursor(rawValue: "cursor_with_tombstone"), tombstones: [tombstone]),
            mutationResults: []
        )
        let engine = NativeSyncEngine(store: store, transport: transport)

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch)

        #expect(report.bootstrapCursor?.rawValue == "cursor_with_tombstone")
        #expect(report.drainedClientMutationIDs.isEmpty)
        #expect(try await store.loadCheckpoint().globalCursor?.rawValue == "cursor_with_tombstone")
        #expect(await store.tombstones.entries == [tombstone])
    }

    @Test("optimistic recipe mutations cover every recipe branch and malformed payload fallback")
    func optimisticRecipeMutationsCoverEveryRecipeBranchAndMalformedPayloadFallback() throws {
        let chef = ChefSummary(id: "chef_ari", username: "ari")
        let recipe = Self.optimisticRecipe()
        let otherRecipe = Self.optimisticRecipe(id: "recipe_other", title: "Other Recipe")
        let now = "2026-06-16T10:30:00.000Z"

        let update = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_update_optimistic",
            title: "Updated Lemon Pasta",
            description: nil,
            servings: "6",
            createdAt: Self.createdAt(1)
        )
        let updated = update.applyingOptimisticRecipeMutation(to: [otherRecipe, recipe], fallbackChef: chef, now: now)
        #expect(updated.map(\.id) == ["recipe_other", "recipe_lemon"])
        #expect(updated[0] == otherRecipe)
        #expect(updated[1].title == "Updated Lemon Pasta")
        #expect(updated[1].description == nil)
        #expect(updated[1].servings == "6")
        #expect(updated[1].updatedAt == now)

        let deleted = NativeQueuedMutation.recipeDelete(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_delete_optimistic",
            createdAt: Self.createdAt(2)
        )
        .applyingOptimisticRecipeMutation(to: updated, fallbackChef: chef, now: now)
        #expect(deleted.map(\.id) == ["recipe_other"])

        let created = try NativeQueuedMutation.recipeCreate(
            clientMutationID: "cm_create_optimistic",
            title: "Queued Toast",
            description: "Buttery.",
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
            createdAt: Self.createdAt(3)
        )
        let createdRecipes = created.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)
        #expect(created.recipeID == nil)
        #expect(created.optimisticRecipeID == "recipe_local_cm_create_optimistic")
        #expect(createdRecipes.map(\.title) == ["Lemon Pasta", "Queued Toast"])
        #expect(createdRecipes[1].steps[0].ingredients.map(\.id) == ["ingredient_local_cm_create_optimistic_1_1"])
        #expect(created.applyingOptimisticRecipeMutation(to: createdRecipes, fallbackChef: chef, now: now).count == 2)

        let stepCreated = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_step_create_optimistic",
            stepNum: 3,
            stepTitle: "Serve",
            description: "Serve with basil.",
            duration: nil,
            ingredients: [RecipeIngredientDraft(quantity: 3, unit: "leaf", name: "basil")],
            outputStepNums: [1],
            createdAt: Self.createdAt(4)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)
        #expect(stepCreated[0].steps.map(\.id).contains("step_local_cm_step_create_optimistic"))
        #expect(stepCreated[0].steps[2].usingSteps.map(\.outputStepNum) == [1])

        let middleStepCreated = try NativeQueuedMutation.recipeStepCreate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_step_create_middle_optimistic",
            stepNum: 2,
            stepTitle: "Bloom",
            description: "Bloom garlic.",
            duration: nil,
            ingredients: [],
            outputStepNums: [1],
            createdAt: Self.createdAt(4)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(middleStepCreated.steps.map(\.id) == ["step_one", "step_local_cm_step_create_middle_optimistic", "step_two"])
        #expect(middleStepCreated.steps.map(\.stepNum) == [1, 2, 3])
        #expect(middleStepCreated.steps[1].usingSteps.map(\.outputStepNum) == [1])
        #expect(middleStepCreated.steps[2].usingSteps.map(\.outputStepNum) == [1])

        let stepUpdated = NativeQueuedMutation.recipeStepUpdate(
            recipeID: "recipe_lemon",
            stepID: "step_two",
            clientMutationID: "cm_step_update_optimistic",
            stepTitle: nil,
            description: "Toss until glossy.",
            duration: nil,
            outputStepNums: [1],
            createdAt: Self.createdAt(5)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(stepUpdated.steps.map(\.description) == ["Boil pasta.", "Toss until glossy."])
        #expect(stepUpdated.steps[1].stepTitle == nil)
        #expect(stepUpdated.steps[1].duration == nil)
        #expect(stepUpdated.steps[1].usingSteps.map(\.outputOfStep.stepTitle) == ["Boil"])

        let stepDeleted = NativeQueuedMutation.recipeStepDelete(
            recipeID: "recipe_lemon",
            stepID: "step_one",
            clientMutationID: "cm_step_delete_optimistic",
            createdAt: Self.createdAt(6)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(stepDeleted.steps.map(\.id) == ["step_two"])
        #expect(stepDeleted.steps.map(\.stepNum) == [1])
        #expect(stepDeleted.steps[0].usingSteps.isEmpty)

        let reordered = NativeQueuedMutation.recipeStepReorder(
            recipeID: "recipe_lemon",
            stepID: "step_two",
            toStepNum: 1,
            clientMutationID: "cm_step_reorder_optimistic",
            createdAt: Self.createdAt(7)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(reordered.steps.map(\.id) == ["step_two", "step_one"])
        #expect(reordered.steps.map(\.stepNum) == [1, 2])
        #expect(reordered.steps[0].usingSteps.isEmpty)

        let unknownReorder = NativeQueuedMutation.recipeStepReorder(
            recipeID: "recipe_lemon",
            stepID: "step_missing",
            toStepNum: 1,
            clientMutationID: "cm_step_reorder_missing",
            createdAt: Self.createdAt(7)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(unknownReorder.steps == recipe.steps)

        let duplicateStepNumRecipe = Self.optimisticRecipe(steps: [
            RecipeStep(id: "step_b", stepNum: 1, stepTitle: "B", description: "B.", duration: nil, ingredients: []),
            RecipeStep(id: "step_a", stepNum: 1, stepTitle: "A", description: "A.", duration: nil, ingredients: []),
            RecipeStep(
                id: "step_c",
                stepNum: 2,
                stepTitle: "C",
                description: "C.",
                duration: nil,
                ingredients: [],
                usingSteps: [
                    RecipeStepOutputUse(
                        id: "use_duplicate",
                        inputStepNum: 2,
                        outputStepNum: 1,
                        outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "B")
                    )
                ]
            )
        ])
        let duplicateSorted = NativeQueuedMutation.recipeStepReorder(
            recipeID: "recipe_lemon",
            stepID: "step_c",
            toStepNum: 2,
            clientMutationID: "cm_duplicate_sort",
            createdAt: Self.createdAt(7)
        )
        .applyingOptimisticRecipeMutation(to: [duplicateStepNumRecipe], fallbackChef: chef, now: now)[0]
        #expect(duplicateSorted.steps.map(\.id) == ["step_a", "step_c", "step_b"])

        let futureOutputFiltered = NativeQueuedMutation.recipeStepUpdate(
            recipeID: "recipe_lemon",
            stepID: "step_two",
            clientMutationID: "cm_future_output",
            stepTitle: "Finish",
            description: "Finish.",
            duration: nil,
            outputStepNums: [1, 1, 2, 3],
            createdAt: Self.createdAt(7)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(futureOutputFiltered.steps[1].usingSteps.map(\.outputStepNum) == [1])

        let ingredientAdded = try NativeQueuedMutation.recipeIngredientAdd(
            recipeID: "recipe_lemon",
            stepID: "step_two",
            clientMutationID: "cm_ingredient_add_optimistic",
            quantity: 2,
            unit: "tbsp",
            name: "parmesan",
            createdAt: Self.createdAt(8)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(ingredientAdded.steps[0].ingredients.map(\.name) == ["water"])
        #expect(ingredientAdded.steps[1].ingredients.map(\.name) == ["lemon", "parmesan"])

        let ingredientDeleted = NativeQueuedMutation.recipeIngredientDelete(
            recipeID: "recipe_lemon",
            stepID: "step_two",
            ingredientID: "ingredient_lemon",
            clientMutationID: "cm_ingredient_delete_optimistic",
            createdAt: Self.createdAt(9)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(ingredientDeleted.steps[1].ingredients.isEmpty)

        let outputReplaced = NativeQueuedMutation.recipeOutputUsesReplace(
            recipeID: "recipe_lemon",
            inputStepID: "step_two",
            outputStepNums: [1],
            clientMutationID: "cm_output_optimistic",
            createdAt: Self.createdAt(10)
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(outputReplaced.steps[1].usingSteps.map(\.outputOfStep.stepTitle) == ["Boil"])

        let stepUpdateMinimal = try Self.decodedMutation(
            type: .recipeStepUpdate,
            fields: [
                "recipeId": "recipe_lemon",
                "stepId": "step_two"
            ]
        )
        .applyingOptimisticRecipeMutation(to: [otherRecipe, recipe], fallbackChef: chef, now: now)
        #expect(stepUpdateMinimal.map(\.id) == ["recipe_other", "recipe_lemon"])
        #expect(stepUpdateMinimal[0] == otherRecipe)
        #expect(stepUpdateMinimal[1].steps[1].description == "Toss with lemon.")

        let stepCreateMinimal = try Self.decodedMutation(
            type: .recipeStepCreate,
            fields: ["recipeId": "recipe_lemon"]
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        let fallbackStep = try #require(stepCreateMinimal.steps.first { $0.id == "step_local_cm_decode" })
        #expect(fallbackStep.stepNum == 1)
        #expect(fallbackStep.description == "")
        #expect(fallbackStep.ingredients.isEmpty)

        let malformedStepCreate = try Self.decodedMutation(
            type: .recipeStepCreate,
            fields: [
                "recipeId": "recipe_lemon",
                "ingredients": [
                    "bad-ingredient",
                    [
                        "name": 10,
                        "quantity": "many",
                        "unit": NSNull()
                    ]
                ]
            ]
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        let malformedStep = try #require(malformedStepCreate.steps.first { $0.id == "step_local_cm_decode" })
        #expect(malformedStep.ingredients.map(\.id) == ["ingredient_local_cm_decode_1", "ingredient_local_cm_decode_2"])
        #expect(malformedStep.ingredients.map(\.name) == ["", ""])
        #expect(malformedStep.ingredients.map(\.quantity) == [1, 1])

        let ingredientAddMinimal = try Self.decodedMutation(
            type: .recipeIngredientAdd,
            fields: [
                "recipeId": "recipe_lemon",
                "stepId": "step_two"
            ]
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(ingredientAddMinimal.steps[1].ingredients.last?.name == "")
        #expect(ingredientAddMinimal.steps[1].ingredients.last?.quantity == 1)

        let missingRecipeID = try Self.decodedMutation(
            type: .recipeStepCreate,
            fields: ["stepNum": 2]
        )
        #expect(missingRecipeID.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now) == [recipe])

        let missingDeleteID = try Self.decodedMutation(
            type: .recipeDelete,
            fields: [:]
        )
        #expect(missingDeleteID.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now) == [recipe])

        let missingStepDeleteID = try Self.decodedMutation(
            type: .recipeStepDelete,
            fields: ["recipeId": "recipe_lemon"]
        )
        #expect(missingStepDeleteID.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0].steps == recipe.steps)

        let missingReorderTarget = try Self.decodedMutation(
            type: .recipeStepReorder,
            fields: [
                "recipeId": "recipe_lemon",
                "stepId": "step_two"
            ]
        )
        #expect(missingReorderTarget.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0].steps == recipe.steps)

        let missingIngredientStep = try Self.decodedMutation(
            type: .recipeIngredientAdd,
            fields: ["recipeId": "recipe_lemon"]
        )
        #expect(missingIngredientStep.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0].steps == recipe.steps)

        let missingIngredientID = try Self.decodedMutation(
            type: .recipeIngredientDelete,
            fields: [
                "recipeId": "recipe_lemon",
                "stepId": "step_two"
            ]
        )
        #expect(missingIngredientID.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0].steps == recipe.steps)

        let missingOutputInput = try Self.decodedMutation(
            type: .recipeOutputUsesReplace,
            fields: ["recipeId": "recipe_lemon"]
        )
        #expect(missingOutputInput.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0].steps == recipe.steps)

        let malformedUpdate = try Self.decodedMutation(
            type: .recipeUpdate,
            fields: [
                "recipeId": "recipe_lemon",
                "title": 42,
                "description": 42,
                "servings": 42
            ]
        )
        .applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now)[0]
        #expect(malformedUpdate.title == "Lemon Pasta")

        let createWithoutSteps = try Self.decodedMutation(
            type: .recipeCreate,
            fields: [:]
        )
        .applyingOptimisticRecipeMutation(to: [], fallbackChef: chef, now: now)[0]
        #expect(createWithoutSteps.title == "Untitled Recipe")
        #expect(createWithoutSteps.steps.isEmpty)

        let malformedCreate = try Self.decodedMutation(
            type: .recipeCreate,
            fields: [
                "description": NSNull(),
                "servings": NSNull(),
                "steps": [
                    "bad-step",
                    [
                        "stepNum": 2.5,
                        "stepTitle": NSNull(),
                        "description": 42,
                        "duration": 1.5,
                        "ingredients": [
                            "bad-ingredient",
                            [
                                "name": 10,
                                "quantity": "a lot",
                                "unit": NSNull()
                            ]
                        ],
                        "outputStepNums": [1, 1.5, "bad"]
                    ]
                ]
            ]
        )
        let malformedRecipe = try #require(malformedCreate.applyingOptimisticRecipeMutation(to: [], fallbackChef: chef, now: now).first)
        #expect(malformedRecipe.title == "Untitled Recipe")
        #expect(malformedRecipe.description == nil)
        #expect(malformedRecipe.servings == nil)
        #expect(malformedRecipe.steps.map(\.stepNum) == [1, 2])
        #expect(malformedRecipe.steps.map(\.description) == ["", ""])
        #expect(malformedRecipe.steps[0].ingredients.isEmpty)
        #expect(malformedRecipe.steps[1].ingredients.map(\.name) == ["", ""])
        #expect(malformedRecipe.steps[1].ingredients.map(\.quantity) == [1, 1])
        #expect(malformedRecipe.steps[1].ingredients.map(\.unit) == [nil, nil])
        #expect(malformedRecipe.steps[1].usingSteps.map(\.outputStepNum) == [1])

        let unrelated = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_unrelated",
            createdAt: Self.createdAt(11)
        )
        #expect(unrelated.applyingOptimisticRecipeMutation(to: [recipe], fallbackChef: chef, now: now) == [recipe])
    }

    private static func representativeMutations() throws -> [NativeQueuedMutation] {
        let recipe: [NativeQueuedMutation] = [
            try .recipeCreate(clientMutationID: "cm_recipe_create", title: "Lemon Pasta", description: "Bright", servings: "4", steps: [], createdAt: createdAt(0)),
            .recipeUpdate(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_update", title: "Lemon Pasta", description: nil, servings: "4", createdAt: createdAt(1)),
            .recipeDelete(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_delete", createdAt: createdAt(2)),
            .recipeFork(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_fork", titleOverride: "My Lemon Pasta", createdAt: createdAt(3)),
            try .recipeStepCreate(recipeID: "recipe_lemon", clientMutationID: "cm_step_create", stepNum: 2, stepTitle: "Sauce", description: "Toss.", duration: 3, ingredients: [], outputStepNums: [1], createdAt: createdAt(4)),
            .recipeStepUpdate(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_step_update", stepTitle: nil, description: "Toss until glossy.", duration: nil, outputStepNums: [1], createdAt: createdAt(5)),
            .recipeStepDelete(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_step_delete", createdAt: createdAt(6)),
            .recipeStepReorder(recipeID: "recipe_lemon", stepID: "step_two", toStepNum: 1, clientMutationID: "cm_step_reorder", createdAt: createdAt(7)),
            try .recipeIngredientAdd(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_ingredient_add", quantity: 2, unit: "cloves", name: "garlic", createdAt: createdAt(8)),
            .recipeIngredientDelete(recipeID: "recipe_lemon", stepID: "step_two", ingredientID: "ingredient_garlic", clientMutationID: "cm_ingredient_delete", createdAt: createdAt(9)),
            .recipeOutputUsesReplace(recipeID: "recipe_lemon", inputStepID: "step_two", outputStepNums: [1, 3], clientMutationID: "cm_output_uses", createdAt: createdAt(10))
        ]
        let cookbook: [NativeQueuedMutation] = [
            .cookbookCreate(clientMutationID: "cm_cookbook_create", title: "Weeknights", createdAt: createdAt(11)),
            .cookbookUpdate(cookbookID: "cookbook_weeknight", title: "Dinner Parties", clientMutationID: "cm_cookbook_update", createdAt: createdAt(12)),
            .cookbookDelete(cookbookID: "cookbook_weeknight", clientMutationID: "cm_cookbook_delete", createdAt: createdAt(13)),
            .cookbookAddRecipe(cookbookID: "cookbook_weeknight", recipeID: "recipe_lemon", clientMutationID: "cm_cookbook_add", createdAt: createdAt(14)),
            .cookbookRemoveRecipe(cookbookID: "cookbook_weeknight", recipeID: "recipe_lemon", clientMutationID: "cm_cookbook_remove", createdAt: createdAt(15))
        ]
        let shopping: [NativeQueuedMutation] = [
            .shoppingAddItem(name: "lemons", quantity: 4, unit: "each", categoryKey: "produce", iconKey: "lemon", clientMutationID: "cm_shopping_add", createdAt: createdAt(16)),
            .shoppingCheckItem(itemID: "item_lemons", checked: true, clientMutationID: "cm_shopping_check", createdAt: createdAt(17)),
            .shoppingDeleteItem(itemID: "item_lemons", clientMutationID: "cm_shopping_delete", createdAt: createdAt(18)),
            .shoppingAddFromRecipe(recipeID: "recipe_lemon", scaleFactor: 1.5, clientMutationID: "cm_shopping_recipe", createdAt: createdAt(19)),
            .shoppingClearCompleted(clientMutationID: "cm_shopping_clear_completed", createdAt: createdAt(20)),
            .shoppingClearAll(clientMutationID: "cm_shopping_clear_all", createdAt: createdAt(21))
        ]
        let spoon: [NativeQueuedMutation] = [
            .spoonCreate(recipeID: "recipe_lemon", clientMutationID: "cm_spoon_create", note: "Loved it.", nextTime: nil, cookedAt: nil, photoURL: "/photos/spoons/lemon.jpg", useAsRecipeCover: true, createdAt: createdAt(22)),
            .spoonCreatePhoto(recipeID: "recipe_lemon", photo: stagedMedia("stage_spoon_1", fileName: "spoon.webp", contentType: "image/webp"), clientMutationID: "cm_spoon_photo", note: "Photo cook.", nextTime: nil, cookedAt: nil, useAsRecipeCover: false, createdAt: createdAt(23)),
            .spoonUpdate(recipeID: "recipe_lemon", spoonID: "spoon_cooked", clientMutationID: "cm_spoon_update", note: nil, nextTime: "More lemon", cookedAt: nil, photoURL: "/photos/spoons/updated.jpg", createdAt: createdAt(24)),
            .spoonDelete(recipeID: "recipe_lemon", spoonID: "spoon_cooked", clientMutationID: "cm_spoon_delete", createdAt: createdAt(25))
        ]
        let cover: [NativeQueuedMutation] = [
            .coverUpload(recipeID: "recipe_lemon", image: stagedMedia("stage_cover_1", fileName: "cover.png", contentType: "image/png"), clientMutationID: "cm_cover_upload", activate: true, generateEditorial: false, createdAt: createdAt(26)),
            .coverSetActive(recipeID: "recipe_lemon", coverID: "cover_raw", clientMutationID: "cm_cover_active", variant: .stylized, createdAt: createdAt(27)),
            .coverArchive(recipeID: "recipe_lemon", coverID: "cover_raw", clientMutationID: "cm_cover_archive", replacementCoverID: "cover_replacement", replacementVariant: .image, confirmNoCover: false, deleteSafeObjects: true, createdAt: createdAt(28)),
            .coverRegenerate(recipeID: "recipe_lemon", coverID: "cover_editorial", activateWhenReady: true, clientMutationID: "cm_cover_regen", createdAt: createdAt(29)),
            .coverFromSpoon(recipeID: "recipe_lemon", spoonID: "spoon_cooked", clientMutationID: "cm_cover_spoon", activate: true, generateEditorial: true, createdAt: createdAt(30))
        ]
        let account: [NativeQueuedMutation] = [
            .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_update", createdAt: createdAt(31)),
            .profilePhotoUpload(photo: stagedMedia("stage_profile_1", fileName: "profile.jpg", contentType: "image/jpeg"), clientMutationID: "cm_profile_photo", createdAt: createdAt(32)),
            .profilePhotoRemove(clientMutationID: "cm_profile_photo_remove", createdAt: createdAt(33)),
            .notificationPreferenceUpdate(notifySpoonOnMyRecipe: true, notifyForkOfMyRecipe: false, notifyCookbookSaveOfMine: true, notifyFellowChefOriginCook: false, clientMutationID: "cm_notifications_update", createdAt: createdAt(34)),
            .apnsDeviceRegister(deviceID: "device_ios", platform: .ios, environment: .development, token: "apns-token", deviceName: "Ari's iPhone", appVersion: "1.0.0", clientMutationID: "cm_apns_register", createdAt: createdAt(35)),
            .apnsDeviceRevoke(deviceID: "device_ios", clientMutationID: "cm_apns_revoke", createdAt: createdAt(36))
        ]
        let captureAndImport: [NativeQueuedMutation] = [
            .captureDraftCreate(draftID: "capture_draft_1", source: .url(URL(string: "https://example.com/recipe")!), clientMutationID: "cm_capture_create", createdAt: createdAt(37)),
            .captureDraftEdit(draftID: "capture_draft_1", source: .text("Grandma notes"), clientMutationID: "cm_capture_edit", createdAt: createdAt(38)),
            .captureDraftDiscard(draftID: "capture_draft_1", clientMutationID: "cm_capture_discard", createdAt: createdAt(39)),
            .recipeImportSubmit(source: .url(URL(string: "https://example.com/recipe")!), clientMutationID: "cm_import_submit", createdAt: createdAt(40))
        ]

        var all: [NativeQueuedMutation] = []
        all.append(contentsOf: recipe)
        all.append(contentsOf: cookbook)
        all.append(contentsOf: shopping)
        all.append(contentsOf: spoon)
        all.append(contentsOf: cover)
        all.append(contentsOf: account)
        all.append(contentsOf: captureAndImport)
        return all
    }

    private static func createdAt(_ offset: Int) -> String {
        String(format: "2026-06-16T09:%02d:00.000Z", offset)
    }

    private static func decodedMutation(type: NativeQueuedMutationKind, fields: [String: Any]) throws -> NativeQueuedMutation {
        try JSONDecoder().decode(
            NativeQueuedMutation.self,
            from: queuedMutationJSON(schemaVersion: 1, type: type.rawValue, fields: fields)
        )
    }

    private static func jsonValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    private static func recipe(from payload: JSONValue) throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(payload))
    }

    private static func shoppingItem(from payload: JSONValue) throws -> ShoppingListItem {
        try JSONDecoder().decode(ShoppingListItem.self, from: JSONEncoder().encode(payload))
    }

    private static func shoppingItem(
        id: String,
        name: String,
        quantity: Double?,
        unit: String?
    ) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: createdAt(0)
        )
    }

    private static func optimisticRecipe(
        id: String = "recipe_lemon",
        title: String = "Lemon Pasta",
        steps: [RecipeStep]? = nil
    ) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: title,
            description: "Bright.",
            servings: "4",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "\(title) by ari on Spoonjoy",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: createdAt(0),
            updatedAt: createdAt(1),
            steps: steps ?? [
                RecipeStep(
                    id: "step_one",
                    stepNum: 1,
                    stepTitle: "Boil",
                    description: "Boil pasta.",
                    duration: 600,
                    ingredients: [
                        RecipeIngredient(id: "ingredient_water", name: "water", quantity: 1, unit: "pot")
                    ]
                ),
                RecipeStep(
                    id: "step_two",
                    stepNum: 2,
                    stepTitle: "Finish",
                    description: "Toss with lemon.",
                    duration: 180,
                    ingredients: [
                        RecipeIngredient(id: "ingredient_lemon", name: "lemon", quantity: 1, unit: "each")
                    ],
                    usingSteps: [
                        RecipeStepOutputUse(
                            id: "use_step_one",
                            inputStepNum: 2,
                            outputStepNum: 1,
                            outputOfStep: RecipeStepOutputReference(stepNum: 1, stepTitle: "Boil")
                        )
                    ]
                )
            ],
            cookbooks: []
        )
    }

    private static func stagedMedia(_ id: String, fileName: String, contentType: String) -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(
            localStageID: id,
            fileName: fileName,
            contentType: contentType,
            data: Data([0x73, 0x6A, 0x6D])
        )
    }

    private static func queuedMutationJSON(schemaVersion: Int, type: String, fields: [String: Any]) throws -> Data {
        var kind = fields
        kind["type"] = type
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": schemaVersion,
            "id": "native:cm_decode",
            "clientMutationId": "cm_decode",
            "createdAt": createdAt(0),
            "retryCount": 0,
            "kind": kind
        ])
    }

    private static let nativeSyncEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_native_sync",
          "data": {
            "freshness": {
              "accountId": "chef_ari",
              "environment": "local",
              "schemaVersion": 1,
              "sourceEndpoint": "/api/v1/me/sync",
              "generatedAt": "2026-06-16T09:10:00.000Z",
              "lastValidatedAt": "2026-06-16T09:10:00.000Z"
            },
            "entries": [
              {
                "action": "upsert",
                "kind": "profile",
                "resourceId": "chef_ari",
                "updatedAt": "2026-06-16T09:08:00.000Z",
                "payload": { "username": "ari" },
                "tombstone": null
              },
              {
                "action": "delete",
                "kind": "recipe",
                "resourceId": "recipe_deleted",
                "updatedAt": "2026-06-16T09:10:00.000Z",
                "payload": null,
                "tombstone": {
                  "resourceType": "recipe",
                  "resourceId": "recipe_deleted",
                  "parentResourceId": null,
                  "title": "Deleted Lemon Pasta",
                  "deletedAt": "2026-06-16T09:09:00.000Z",
                  "updatedAt": "2026-06-16T09:10:00.000Z"
                }
              },
              {
                "action": "delete",
                "kind": "cookbook",
                "resourceId": "cookbook_deleted",
                "updatedAt": "2026-06-16T09:10:01.000Z",
                "payload": null,
                "tombstone": {
                  "resourceType": "cookbook",
                  "resourceId": "cookbook_deleted",
                  "parentResourceId": null,
                  "title": "Deleted Cookbook",
                  "deletedAt": "2026-06-16T09:09:01.000Z",
                  "updatedAt": "2026-06-16T09:10:01.000Z"
                }
              },
              {
                "action": "delete",
                "kind": "spoon",
                "resourceId": "spoon_deleted",
                "updatedAt": "2026-06-16T09:10:02.000Z",
                "payload": null,
                "tombstone": {
                  "resourceType": "spoon",
                  "resourceId": "spoon_deleted",
                  "parentResourceId": "recipe_deleted",
                  "title": null,
                  "deletedAt": "2026-06-16T09:09:02.000Z",
                  "updatedAt": "2026-06-16T09:10:02.000Z"
                }
              },
              {
                "action": "delete",
                "kind": "shoppingItem",
                "resourceId": "item_deleted",
                "updatedAt": "2026-06-16T09:10:03.000Z",
                "payload": null,
                "tombstone": {
                  "resourceType": "shoppingItem",
                  "resourceId": "item_deleted",
                  "parentResourceId": "shopping_list_1",
                  "title": null,
                  "deletedAt": "2026-06-16T09:09:03.000Z",
                  "updatedAt": "2026-06-16T09:10:03.000Z"
                }
              }
            ],
            "nextCursor": "v1.cursor.after",
            "hasMore": false
          }
        }
        """.utf8
    )
}

private func assertRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    queryItems: [URLQueryItem] = []
) {
    #expect(request.method == method)
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    #expect(request.headers["Authorization"] == "Bearer sj_access")
}

private struct ExpectedRemoteMutationRequest {
    let mutation: NativeQueuedMutation
    let method: APIRequestMethod
    let path: String
    let queryItems: [URLQueryItem]
    let extraHeaders: [String: String]
    let jsonBody: [String: Any]?
    let multipart: ExpectedMultipartRequest?

    static func json(
        _ mutation: NativeQueuedMutation,
        _ method: APIRequestMethod,
        _ path: String,
        _ body: [String: Any],
        queryItems: [URLQueryItem] = [],
        extraHeaders: [String: String] = [:]
    ) -> ExpectedRemoteMutationRequest {
        ExpectedRemoteMutationRequest(
            mutation: mutation,
            method: method,
            path: path,
            queryItems: queryItems,
            extraHeaders: extraHeaders,
            jsonBody: body,
            multipart: nil as ExpectedMultipartRequest?
        )
    }

    static func noBody(
        _ mutation: NativeQueuedMutation,
        _ method: APIRequestMethod,
        _ path: String,
        queryItems: [URLQueryItem] = [],
        extraHeaders: [String: String] = [:]
    ) -> ExpectedRemoteMutationRequest {
        ExpectedRemoteMutationRequest(
            mutation: mutation,
            method: method,
            path: path,
            queryItems: queryItems,
            extraHeaders: extraHeaders,
            jsonBody: nil as [String: Any]?,
            multipart: nil as ExpectedMultipartRequest?
        )
    }

    static func multipart(
        _ mutation: NativeQueuedMutation,
        _ method: APIRequestMethod,
        _ path: String,
        _ fileField: String,
        _ fileName: String,
        _ contentType: String,
        _ fields: [String: String]
    ) -> ExpectedRemoteMutationRequest {
        ExpectedRemoteMutationRequest(
            mutation: mutation,
            method: method,
            path: path,
            queryItems: [],
            extraHeaders: [:],
            jsonBody: nil as [String: Any]?,
            multipart: ExpectedMultipartRequest(
                fileField: fileField,
                fileName: fileName,
                contentType: contentType,
                fields: fields
            )
        )
    }
}

private struct ExpectedMultipartRequest {
    let fileField: String
    let fileName: String
    let contentType: String
    let fields: [String: String]
}

private func assertExpectedRemoteMutationRequest(
    _ expected: ExpectedRemoteMutationRequest,
    configuration: APIClientConfiguration
) throws {
    let request = try expected.mutation.requestBuilder().urlRequest(configuration: configuration)
    #expect(request.method == expected.method)
    #expect(request.url.path == expected.path)
    #expect(request.queryItems == expected.queryItems)
    #expect(request.responseCachePolicy == APIResponseCachePolicy.privateNoStore)

    var expectedHeaders = [
        "Accept": "application/json",
        "Authorization": "Bearer sj_access"
    ]
    for (name, value) in expected.extraHeaders {
        expectedHeaders[name] = value
    }

    if let jsonBody = expected.jsonBody {
        expectedHeaders["Content-Type"] = "application/json"
        #expect(request.headers == expectedHeaders)
        #expect(NSDictionary(dictionary: try decodedJSONBody(from: request)).isEqual(to: jsonBody))
        return
    }

    if let multipart = expected.multipart {
        #expect(request.headers["Accept"] == expectedHeaders["Accept"])
        #expect(request.headers["Authorization"] == expectedHeaders["Authorization"])
        let contentType = request.headers["Content-Type"] ?? ""
        #expect(contentType.isEmpty == false)
        #expect(contentType.hasPrefix("multipart/form-data; boundary=SpoonjoyBoundary-"))
        try assertMultipartBody(request, expected: multipart)
        #expect(Set(request.headers.keys) == ["Accept", "Authorization", "Content-Type"])
        return
    }

    #expect(request.headers == expectedHeaders)
    #expect(request.body == nil)
}

private func decodedJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func assertMultipartBody(_ request: APIRequest, expected: ExpectedMultipartRequest) throws {
    let body = try #require(request.body)
    let bodyString = try #require(String(data: body, encoding: .isoLatin1))
    #expect(bodyString.contains(#"name="\#(expected.fileField)"; filename="\#(expected.fileName)""#))
    #expect(bodyString.contains("Content-Type: \(expected.contentType)\r\n\r\n"))

    let expectedFieldNames = Set(expected.fields.keys).union([expected.fileField])
    let actualFieldNames = multipartFieldNames(in: bodyString)
    #expect(actualFieldNames == expectedFieldNames)
    for (name, value) in expected.fields {
        #expect(bodyString.contains(#"name="\#(name)""#))
        #expect(bodyString.contains("\r\n\r\n\(value)\r\n"))
    }
}

private func multipartFieldNames(in bodyString: String) -> Set<String> {
    Set(bodyString.split(separator: "\r\n").compactMap { line in
        let prefix = #"Content-Disposition: form-data; name=""#
        guard line.hasPrefix(prefix) else {
            return nil
        }

        let start = line.index(line.startIndex, offsetBy: prefix.count)
        guard let end = line[start...].firstIndex(of: "\"") else {
            return nil
        }

        return String(line[start..<end])
    })
}

private func persistedKindObjects(from data: Data) throws -> [String: [String: Any]] {
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let mutations = try #require(root["mutations"] as? [[String: Any]])
    return Dictionary(
        uniqueKeysWithValues: try mutations.map { mutation in
            let kind = try #require(mutation["kind"] as? [String: Any])
            let type = try #require(kind["type"] as? String)
            return (type, kind)
        }
    )
}

private func dictionaryEquals(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
    NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try await body(directory)
}

private actor RecordingNativeSyncTransport: NativeSyncTransport {
    private let bootstrapResult: NativeSyncBootstrapResult
    private var mutationResults: [NativeSyncMutationResult]
    private(set) var requestPaths: [String] = []
    private(set) var bootstrapQueryItems: [URLQueryItem] = []
    private(set) var clientMutationIDs: [String] = []

    init(bootstrap: NativeSyncBootstrapResult, mutationResults: [NativeSyncMutationResult]) {
        self.bootstrapResult = bootstrap
        self.mutationResults = mutationResults
    }

    func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        requestPaths.append(request.url.path)
        bootstrapQueryItems = request.queryItems
        return bootstrapResult
    }

    func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        let request = try mutation.requestBuilder().urlRequest(configuration: configuration)
        requestPaths.append(request.url.path)
        clientMutationIDs.append(mutation.clientMutationID)
        return mutationResults.isEmpty ? .success(serverRevision: nil) : mutationResults.removeFirst()
    }
}

private actor RecordingNativeSyncTriggerRunner: NativeSyncTriggerRunning {
    private(set) var triggers: [NativeCacheRevalidationTrigger] = []
    private(set) var configurationBaseURLs: [URL] = []
    private(set) var scopes: [NativeSyncExecutionScope] = []

    func bootstrapAndDrain(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger,
        scope: NativeSyncExecutionScope
    ) async throws -> NativeSyncReport {
        triggers.append(trigger)
        configurationBaseURLs.append(configuration.baseURL)
        scopes.append(scope)
        return NativeSyncReport(
            trigger: trigger,
            bootstrapCursor: nil,
            accountID: nil,
            environment: nil,
            drainedClientMutationIDs: [],
            conflicts: [],
            pausedReason: nil,
            retryAfterSeconds: nil
        )
    }
}
