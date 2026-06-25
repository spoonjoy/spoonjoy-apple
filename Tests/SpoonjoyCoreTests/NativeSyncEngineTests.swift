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
        #expect(NSDictionary(dictionary: persistedKinds["spoon.createPhoto"]?["photo"] as? [String: Any] ?? [:]).isEqual(to: [
            "localStageId": "stage_spoon_1",
            "fileName": "spoon.webp",
            "contentType": "image/webp"
        ]))
        #expect(NSDictionary(dictionary: persistedKinds["cover.upload"]?["image"] as? [String: Any] ?? [:]).isEqual(to: [
            "localStageId": "stage_cover_1",
            "fileName": "cover.png",
            "contentType": "image/png"
        ]))
        #expect(NSDictionary(dictionary: persistedKinds["profile.photo.upload"]?["photo"] as? [String: Any] ?? [:]).isEqual(to: [
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

    @Test("queued remote mutations build exact REST requests with idempotency keys and bearer auth")
    func queuedRemoteMutationsBuildExactRESTRequestsWithIdempotencyKeysAndBearerAuth() throws {
        let cases: [ExpectedRemoteMutationRequest] = [
            .json(.recipeCreate(clientMutationID: "cm_recipe_create", title: "Lemon Pasta", description: "Bright", servings: "4", steps: [], createdAt: Self.createdAt(0)), .post, "/api/v1/recipes", [
                "clientMutationId": "cm_recipe_create",
                "title": "Lemon Pasta",
                "description": "Bright",
                "servings": "4",
                "steps": []
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
            .json(.recipeStepCreate(recipeID: "recipe/lemon", clientMutationID: "cm_step_create", stepNum: 2, stepTitle: "Sauce", description: "Toss.", duration: 3, ingredients: [], outputStepNums: [1], createdAt: Self.createdAt(4)), .post, "/api/v1/recipes/recipe%2Flemon/steps", [
                "clientMutationId": "cm_step_create",
                "stepNum": 2,
                "stepTitle": "Sauce",
                "description": "Toss.",
                "duration": 3,
                "ingredients": [],
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
            .json(.recipeIngredientAdd(recipeID: "recipe/lemon", stepID: "step/two", clientMutationID: "cm_ingredient_add", quantity: 2, unit: "cloves", name: "garlic", createdAt: Self.createdAt(8)), .post, "/api/v1/recipes/recipe%2Flemon/steps/step%2Ftwo/ingredients", [
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
        let coordinator = NativeSyncTriggerCoordinator(runner: runner, configuration: configuration)

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

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .foreground)

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

    @Test("sync engine pauses on auth failure classifies conflicts and retains the blocked queue")
    func syncEnginePausesOnAuthFailureClassifiesConflictsAndRetainsTheBlockedQueue() async throws {
        let queue = try NativeMutationQueue(
            mutations: [
                .cookbookUpdate(cookbookID: "cookbook_weeknight", title: "Weeknights", clientMutationID: "cm_cookbook_conflict", createdAt: Self.createdAt(0)),
                .profileDisplayUpdate(email: "ari@example.com", username: "ari", clientMutationID: "cm_profile_auth", createdAt: Self.createdAt(1))
            ]
        )
        let store = InMemoryNativeSyncStore(checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: PaginationCursor(rawValue: "cursor_after_bootstrap"), tombstones: []),
            mutationResults: [
                .conflict(kind: .validation, serverRevision: .etag("\"cookbook-v8\""), message: "Cookbook was changed elsewhere."),
                .authFailure(message: "Session expired.")
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .networkRecovered)

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
        let store = InMemoryNativeSyncStore(checkpoint: nil, queue: queue)
        let transport = RecordingNativeSyncTransport(
            bootstrap: .success(cursor: nil, tombstones: []),
            mutationResults: [
                .retry(afterSeconds: 30, message: "Server busy."),
                .success(serverRevision: .updatedAt("2026-06-16T09:06:00.000Z"))
            ]
        )
        let engine = NativeSyncEngine(store: store, transport: transport, clock: { now })

        let report = try await engine.bootstrapAndDrain(configuration: configuration, trigger: .launch)
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

    private static func representativeMutations() throws -> [NativeQueuedMutation] {
        let recipe: [NativeQueuedMutation] = [
            .recipeCreate(clientMutationID: "cm_recipe_create", title: "Lemon Pasta", description: "Bright", servings: "4", steps: [], createdAt: createdAt(0)),
            .recipeUpdate(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_update", title: "Lemon Pasta", description: nil, servings: "4", createdAt: createdAt(1)),
            .recipeDelete(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_delete", createdAt: createdAt(2)),
            .recipeFork(recipeID: "recipe_lemon", clientMutationID: "cm_recipe_fork", titleOverride: "My Lemon Pasta", createdAt: createdAt(3)),
            .recipeStepCreate(recipeID: "recipe_lemon", clientMutationID: "cm_step_create", stepNum: 2, stepTitle: "Sauce", description: "Toss.", duration: 3, ingredients: [], outputStepNums: [1], createdAt: createdAt(4)),
            .recipeStepUpdate(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_step_update", stepTitle: nil, description: "Toss until glossy.", duration: nil, outputStepNums: [1], createdAt: createdAt(5)),
            .recipeStepDelete(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_step_delete", createdAt: createdAt(6)),
            .recipeStepReorder(recipeID: "recipe_lemon", stepID: "step_two", toStepNum: 1, clientMutationID: "cm_step_reorder", createdAt: createdAt(7)),
            .recipeIngredientAdd(recipeID: "recipe_lemon", stepID: "step_two", clientMutationID: "cm_ingredient_add", quantity: 2, unit: "cloves", name: "garlic", createdAt: createdAt(8)),
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

    private static func stagedMedia(_ id: String, fileName: String, contentType: String) -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(
            localStageID: id,
            fileName: fileName,
            contentType: contentType,
            data: Data([0x73, 0x6A, 0x6D])
        )
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
    let actualFieldNames = Set(bodyString.matches(of: /name="([^"]+)"/).map { String($0.1) })
    #expect(actualFieldNames == expectedFieldNames)
    for (name, value) in expected.fields {
        #expect(bodyString.contains(#"name="\#(name)""#))
        #expect(bodyString.contains("\r\n\r\n\(value)\r\n"))
    }
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

    func bootstrapAndDrain(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger
    ) async throws -> NativeSyncReport {
        triggers.append(trigger)
        configurationBaseURLs.append(configuration.baseURL)
        return NativeSyncReport(
            trigger: trigger,
            bootstrapCursor: nil,
            drainedClientMutationIDs: [],
            conflicts: [],
            pausedReason: nil,
            retryAfterSeconds: nil
        )
    }
}
