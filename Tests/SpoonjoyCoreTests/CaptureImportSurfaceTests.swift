import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native capture and import parity")
struct CaptureImportSurfaceTests {
    @Test("capture draft sources produce canonical REST import mutations")
    func captureDraftSourcesProduceCanonicalRESTImportMutations() throws {
        let cases: [(CaptureDraft, [String: Any])] = [
            (
                try CaptureDraft.importURL(
                    id: "draft_url",
                    url: URL(string: "https://example.com/recipes/lemon-pasta")!,
                    createdAt: Self.createdAt
                ),
                [
                    "type": "url",
                    "url": "https://example.com/recipes/lemon-pasta"
                ]
            ),
            (
                try CaptureDraft.localText(
                    id: "draft_text",
                    rawText: "Grandma sauce\n2 tomatoes",
                    sourceURL: URL(string: "https://captures.example/grandma-sauce")!,
                    createdAt: Self.createdAt
                ),
                [
                    "type": "text",
                    "text": "Grandma sauce\n2 tomatoes",
                    "url": "https://captures.example/grandma-sauce"
                ]
            ),
            (
                try CaptureDraft.shareSheetURL(
                    id: "draft_share_url",
                    url: URL(string: "https://spoonjoy.app/imported/from-share-sheet")!,
                    createdAt: Self.createdAt
                ),
                [
                    "type": "url",
                    "url": "https://spoonjoy.app/imported/from-share-sheet"
                ]
            ),
            (
                try CaptureDraft.cameraImage(
                    id: "draft_camera",
                    assetIdentifier: "local-camera-asset-1",
                    recognizedText: "Camera card stew\nBake until bubbling.",
                    createdAt: Self.createdAt
                ),
                [
                    "type": "text",
                    "text": "Camera card stew\nBake until bubbling.",
                    "capture": [
                        "source": "camera",
                        "assetIdentifier": "local-camera-asset-1"
                    ]
                ]
            ),
            (
                try CaptureDraft.photoLibraryImage(
                    id: "draft_photo_library",
                    assetIdentifier: "photo-library-asset-1",
                    recognizedText: "Album cake\nWhisk batter.",
                    createdAt: Self.createdAt
                ),
                [
                    "type": "text",
                    "text": "Album cake\nWhisk batter.",
                    "capture": [
                        "source": "photo-library",
                        "assetIdentifier": "photo-library-asset-1"
                    ]
                ]
            ),
            (
                try CaptureDraft.jsonLD(
                    id: "draft_jsonld",
                    jsonLD: JSONValue.object([
                        "@context": JSONValue.string("https://schema.org"),
                        "@type": JSONValue.string("Recipe"),
                        "name": JSONValue.string("Native JSON-LD Soup")
                    ]),
                    sourceURL: Optional<URL>.none,
                    createdAt: Self.createdAt
                ),
                [
                    "type": "json-ld",
                    "jsonLd": [
                        "@context": "https://schema.org",
                        "@type": "Recipe",
                        "name": "Native JSON-LD Soup"
                    ],
                    "url": NSNull()
                ]
            ),
            (
                try CaptureDraft.videoURL(
                    id: "draft_video",
                    url: URL(string: "https://www.youtube.com/watch?v=spoonjoy")!,
                    createdAt: Self.createdAt
                ),
                [
                    "type": "video-url",
                    "url": "https://www.youtube.com/watch?v=spoonjoy"
                ]
            )
        ]

        for (index, testCase) in cases.enumerated() {
            let mutation = NativeQueuedMutation.recipeImportSubmit(
                source: try testCase.0.importSource(),
                clientMutationID: "cm_import_\(index)",
                createdAt: Self.createdAt
            )
            let request = try mutation.requestBuilder().urlRequest(configuration: Self.privateConfiguration)

            try Self.assertJSONRequest(request, expected: [
                "clientMutationId": "cm_import_\(index)",
                "source": testCase.1
            ])
        }
    }

    @Test("image drafts without recognized text stay local until native OCR produces importable text")
    func imageDraftsWithoutRecognizedTextStayLocalUntilOCR() throws {
        let draft = try CaptureDraft.cameraImage(
            id: "draft_camera_needs_ocr",
            assetIdentifier: "camera-pending-ocr",
            recognizedText: Optional<String>.none,
            createdAt: Self.createdAt
        )

        #expect(!draft.canCreateServerRecipe)
        #expect(draft.importReadiness == CaptureDraftImportReadiness.needsTextRecognition)
        #expect(throws: CaptureDraftImportError.needsTextRecognition) {
            _ = try draft.importSource()
        }
    }

    @Test("recipe import mutations expose source for visible draft matching")
    func recipeImportMutationsExposeSourceForVisibleDraftMatching() throws {
        let urlDraft = try CaptureDraft.importURL(
            id: "draft_import_source_url",
            url: URL(string: "https://example.com/source-match")!,
            createdAt: Self.createdAt
        )
        let textDraft = try CaptureDraft.localText(
            id: "draft_import_source_text",
            rawText: "Ingredient source matching\nBake until golden.",
            sourceURL: URL(string: "https://example.com/text-source")!,
            createdAt: Self.createdAt
        )
        let mutation = NativeQueuedMutation.recipeImportSubmit(
            source: try urlDraft.importSource(),
            clientMutationID: "cm_import_source_match",
            createdAt: Self.createdAt
        )
        let urlSource = try urlDraft.importSource()
        let textSource = try textDraft.importSource()

        #expect(mutation.recipeImportSource == urlSource)
        #expect(mutation.recipeImportSource != textSource)
    }

    @Test("capture drafts and import retry survive snapshot and sync-store round trips")
    func captureDraftsAndImportRetrySurviveRoundTrips() async throws {
        let draft = try CaptureDraft.shareSheetURL(
            id: "draft_share_roundtrip",
            url: URL(string: "https://example.com/roundtrip")!,
            createdAt: Self.createdAt
        )
        let mutation = NativeQueuedMutation.recipeImportSubmit(
            source: try draft.importSource(),
            clientMutationID: "cm_import_roundtrip",
            createdAt: Self.createdAt
        )
        let snapshot = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.createdAt
            )
            .recordingCaptureDraft(draft, savedAt: Self.createdAt)
            .recordingCaptureImportRetry(mutation, savedAt: Self.createdAt)

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(NativeAppSnapshot.self, from: encoded)
        let syncStoreURL = Self.temporaryDirectory().appendingPathComponent("native-sync.json")
        let syncStore = try FileBackedNativeSyncStore(fileURL: syncStoreURL)
        try await syncStore.saveQueue(
            try NativeMutationQueue(mutations: [mutation]),
            accountID: "chef_ari",
            environment: .production
        )
        let restoredSyncStore = try FileBackedNativeSyncStore(fileURL: syncStoreURL)

        #expect(decoded.captureDraft == draft)
        #expect(decoded.pendingCaptureImport?.clientMutationID == "cm_import_roundtrip")
        #expect(try await restoredSyncStore.loadQueue().mutations == [mutation])
        #expect(decoded.discardingCaptureDraft(id: draft.id, savedAt: Self.createdAt).captureDraft == nil)
    }

    @Test("replacing capture drafts clears stale pending import metadata")
    func replacingCaptureDraftsClearsStalePendingImportMetadata() throws {
        let firstDraft = try CaptureDraft.importURL(
            id: "draft_pending_import_original",
            url: URL(string: "https://example.com/original-import")!,
            createdAt: Self.createdAt
        )
        let secondDraft = try CaptureDraft.localText(
            id: "draft_pending_import_replacement",
            rawText: "Replacement draft\nDo not retry the old URL.",
            createdAt: Self.createdAt
        )
        let mutation = NativeQueuedMutation.recipeImportSubmit(
            source: try firstDraft.importSource(),
            clientMutationID: "cm_original_import",
            createdAt: Self.createdAt
        )
        let retrying = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.createdAt
            )
            .recordingCaptureDraft(firstDraft, savedAt: Self.createdAt)
            .recordingCaptureImportRetry(mutation, savedAt: Self.createdAt)
        let blocked = retrying.recordingCaptureImportProviderBlocker(resourceID: "recipe-import", savedAt: Self.createdAt)
        let sameRetryingDraft = retrying.recordingCaptureDraft(firstDraft, savedAt: Self.createdAt)
        let replacedRetryingDraft = retrying.recordingCaptureDraft(secondDraft, savedAt: Self.createdAt)
        let sameBlockedDraft = blocked.recordingCaptureDraft(firstDraft, savedAt: Self.createdAt)
        let replacedBlockedDraft = blocked.recordingCaptureDraft(secondDraft, savedAt: Self.createdAt)

        #expect(sameRetryingDraft.pendingCaptureImport?.clientMutationID == "cm_original_import")
        #expect(replacedRetryingDraft.captureDraft == secondDraft)
        #expect(replacedRetryingDraft.pendingCaptureImport == nil)
        #expect(replacedRetryingDraft.captureImportProviderBlocker == nil)
        #expect(sameBlockedDraft.captureImportProviderBlocker == "recipe-import")
        #expect(replacedBlockedDraft.captureDraft == secondDraft)
        #expect(replacedBlockedDraft.pendingCaptureImport == nil)
        #expect(replacedBlockedDraft.captureImportProviderBlocker == nil)
    }

    @Test("capture import provider blockers persist and clear with retry or drained import")
    func captureImportProviderBlockersPersistAndClearWithRetryOrDrainedImport() throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_provider_blocker_roundtrip",
            url: URL(string: "https://example.com/provider-blocker")!,
            createdAt: Self.createdAt
        )
        let mutation = NativeQueuedMutation.recipeImportSubmit(
            source: try draft.importSource(),
            clientMutationID: "cm_provider_blocker",
            createdAt: Self.createdAt
        )
        let blocked = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.createdAt
            )
            .recordingCaptureDraft(draft, savedAt: Self.createdAt)
            .recordingCaptureImportProviderBlocker(resourceID: "recipe-import", savedAt: Self.createdAt)
        let decoded = try JSONDecoder().decode(NativeAppSnapshot.self, from: JSONEncoder().encode(blocked))
        let retrying = decoded.recordingCaptureImportRetry(mutation, savedAt: Self.createdAt)
        let blockedRetry = retrying.recordingCaptureImportProviderBlocker(resourceID: "recipe-import", savedAt: Self.createdAt)
        let drained = retrying.clearingDrainedCaptureImport(
            clientMutationIDs: ["cm_provider_blocker"],
            savedAt: Self.createdAt
        )

        #expect(decoded.captureDraft == draft)
        #expect(decoded.captureImportProviderBlocker == "recipe-import")
        #expect(retrying.pendingCaptureImport == mutation)
        #expect(retrying.captureImportProviderBlocker == nil)
        #expect(blockedRetry.captureImportProviderBlocker == "recipe-import")
        #expect(blockedRetry.pendingCaptureImport == nil)
        #expect(blockedRetry.captureDraft == draft)
        #expect(drained.captureDraft == nil)
        #expect(drained.pendingCaptureImport == nil)
        #expect(drained.captureImportProviderBlocker == nil)
    }

    @Test("provider-secret blockers produce user-facing blocked state without remote retry work")
    func providerSecretBlockersProduceBlockedStateWithoutRetryWork() throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_provider_secret",
            url: URL(string: "https://example.com/private-recipe")!,
            createdAt: Self.createdAt
        )
        let response = try Self.providerSecretBlockedImportResponse()
        let viewModel = CaptureImportViewModel(draft: draft, connectivity: CaptureImportConnectivity.online)
        let plan = try viewModel.planImportResult(
            response,
            clientMutationID: "cm_provider_secret",
            createdAt: Self.createdAt
        )

        #expect(plan.blocker == CaptureImportBlocker.providerSecret(retryAfterSeconds: 30))
        #expect(plan.offlineRetryMutation == nil)
        #expect(plan.requestBuilder == nil)
        #expect(plan.importedRecipeRoute == nil)
        #expect(plan.userFacingMessage.contains("ProviderSecret"))
    }

    @Test("offline import queues retry, restores it, drains on reconnect, and routes imported recipe")
    func offlineImportQueuesRestoresDrainsAndRoutesImportedRecipe() throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_offline_retry",
            url: URL(string: "https://example.com/offline-import")!,
            createdAt: Self.createdAt
        )
        let offlineViewModel = CaptureImportViewModel(draft: draft, connectivity: CaptureImportConnectivity.offline)
        let offlinePlan = try offlineViewModel.planSubmit(
            clientMutationID: "cm_import_offline",
            createdAt: Self.createdAt
        )

        #expect(offlinePlan.requestBuilder == nil)
        #expect(offlinePlan.offlineRetryMutation?.queueableKind == .recipeImportSubmit)
        #expect(offlinePlan.offlineRetryMutation?.clientMutationID == "cm_import_offline")
        #expect(offlinePlan.userFacingMessage.localizedCaseInsensitiveContains("offline"))

        guard let retryMutation = offlinePlan.offlineRetryMutation else {
            Issue.record("Offline import should produce a retry mutation.")
            return
        }
        let restoredViewModel = CaptureImportViewModel(
            draft: draft,
            connectivity: CaptureImportConnectivity.online,
            pendingRetryMutation: retryMutation
        )
        let submitPlan = try restoredViewModel.planSubmit(
            clientMutationID: "cm_import_offline",
            createdAt: Self.createdAt
        )
        let request = try #require(submitPlan.requestBuilder)
            .urlRequest(configuration: Self.privateConfiguration)
        try Self.assertJSONRequest(request, expected: [
            "clientMutationId": "cm_import_offline",
            "source": [
                "type": "url",
                "url": "https://example.com/offline-import"
            ]
        ])

        let importedResponse = try Self.importedRecipeResponse(id: "recipe_imported", title: "Imported Lemon Pasta")
        let completedPlan = try restoredViewModel.planImportResult(
            importedResponse,
            clientMutationID: "cm_import_offline",
            createdAt: Self.createdAt
        )

        #expect(completedPlan.drainedClientMutationID == "cm_import_offline")
        #expect(completedPlan.importedRecipeRoute == AppRoute.recipeDetail(id: "recipe_imported", presentation: .detail))
        #expect(completedPlan.captureDraftAfterCompletion == nil)
    }

    @Test("capture draft changes record and clear through durable app state store")
    func captureDraftChangesRecordAndClearThroughDurableAppStateStore() throws {
        let draft = try CaptureDraft.localText(
            id: "draft_store_roundtrip",
            rawText: "State store soup\nSimmer gently.",
            sourceURL: Optional<URL>.none,
            createdAt: Self.createdAt
        )
        let fileURL = Self.temporaryDirectory().appendingPathComponent("native-app-state.json")
        let store = NativeAppStateStore(fileURL: fileURL)
        let fallback = NativeAppSnapshot.bootstrap(
            shoppingList: nil,
            accountID: "chef_ari",
            environment: .production,
            savedAt: Self.createdAt
        )
        let recorded = fallback.recordingCaptureDraft(draft, savedAt: Self.createdAt)

        try store.save(recorded)
        let restored = try store.loadOrCreate(fallback: fallback).value
        try store.save(restored.discardingCaptureDraft(id: draft.id, savedAt: Self.createdAt))
        let cleared = try store.loadOrCreate(fallback: fallback).value

        #expect(restored.captureDraft == draft)
        #expect(cleared.captureDraft == nil)
    }

    private static let createdAt = "2026-06-24T09:00:00.000Z"
    private static let privateConfiguration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    private static func providerSecretBlockedImportResponse() throws -> RecipeImportResponse {
        try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "importCode": "provider-secret",
              "blockers": [
                {
                  "capability": "ProviderSecret",
                  "retryAfterSeconds": 30,
                  "ownerAction": true
                }
              ]
            }
            """.utf8
        ))
    }

    private static func importedRecipeResponse(id: String, title: String) throws -> RecipeImportResponse {
        try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "recipe": {
                "id": "\(id)",
                "title": "\(title)",
                "description": "Imported from native capture.",
                "servings": "4",
                "chef": {
                  "id": "chef_ari",
                  "username": "ari",
                  "photoUrl": null
                },
                "coverImageUrl": null,
                "coverProvenanceLabel": null,
                "coverSourceType": null,
                "coverVariant": null,
                "href": "/recipes/\(id)",
                "canonicalUrl": "https://spoonjoy.app/recipes/\(id)",
                "attribution": {
                  "creditText": "Imported from native capture",
                  "canonicalUrl": "https://spoonjoy.app/recipes/\(id)",
                  "sourceUrl": null,
                  "sourceHost": null,
                  "sourceRecipe": null
                },
                "createdAt": "2026-06-24T09:00:00.000Z",
                "updatedAt": "2026-06-24T09:00:00.000Z",
                "steps": [],
                "cookbooks": [],
                "recentSpoons": []
              }
            }
            """.utf8
        ))
    }

    private static func assertJSONRequest(_ request: APIRequest, expected: [String: Any]) throws {
        #expect(request.method == .post)
        #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
        #expect(request.url.path == "/api/v1/recipes/import")
        #expect(request.queryItems.isEmpty)
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Authorization"] == "Bearer sj_private_token")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.responseCachePolicy == .privateNoStore)
        let body = try #require(request.body)
        let object = try JSONSerialization.jsonObject(with: body)
        let dictionary = try #require(object as? [String: Any])
        #expect(NSDictionary(dictionary: dictionary).isEqual(to: expected))
    }

    private static func temporaryDirectory() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = root.appendingPathComponent("spoonjoy-capture-import-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

}
