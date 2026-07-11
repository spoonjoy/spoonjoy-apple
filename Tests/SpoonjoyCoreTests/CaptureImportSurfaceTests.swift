import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native capture and import parity")
struct CaptureImportSurfaceTests {
    @Test("capture surface only presents truthful agent and Shortcuts import paths")
    func captureSurfaceOnlyPresentsTruthfulAgentAndShortcutsImportPaths() throws {
        let failures = captureImportSurfaceSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
                "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "scripts/capture-native-screenshots.sh",
                "scripts/validate-design-review.rb"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift": [
                    "CaptureImportEntryPoint",
                    "agentMCP",
                    "appIntent",
                    "Spoonjoy agent",
                    "Shortcuts & Siri",
                    "Shortcuts and Siri",
                    "Import queue",
                    "Siri",
                    "Submit import",
                    "Retry sync",
                    "Retry when online",
                    "Resolve import setup",
                    "shellOfflineIndicatorState",
                    "OfflineStatusView",
                    "ImportStatusPanel("
                ],
                "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift": [
                    "Import queue",
                    "Submit import",
                    "Retry when online",
                    "SignedOutSetupView",
                    "Opening Capture after sign-in"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "CaptureImportEntryPoint",
                    "agentMCP",
                    "appIntent",
                    "Spoonjoy agent",
                    "Shortcuts & Siri",
                    "Shortcuts and Siri",
                    "Import queue",
                    "ImportStatusPanel(",
                    "shellOfflineIndicatorState",
                    "OfflineStatusView",
                    "Submit import",
                    "Retry sync",
                    "Retry when online",
                    "Resolve import setup",
                    "Capture surface reviews Spoonjoy agent and Shortcuts drafts"
                ],
                "scripts/capture-native-screenshots.sh": [
                    "\"Import queue\"",
                    "\"Submit import\"",
                    "\"Retry when online\"",
                    "capture_surface_variant",
                    "captureSignedOutSurface",
                    "SignedOutSetupView"
                ],
                "scripts/validate-design-review.rb": [
                    "\"Import queue\"",
                    "\"Submit import\"",
                    "\"Retry when online\"",
                    "EXPECTED_CAPTURE_VARIANTS",
                    "captureSurfaceVariant",
                    "captureSignedOutSurface"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift": [
                    "Agent import",
                    "MCP agent",
                    "MCP agent imports",
                    "Use the Spoonjoy MCP agent",
                    "App Intents",
                    "textSourceURLText",
                    "recipeURLText",
                    "videoURLText",
                    "jsonLDText",
                    "selectedPhoto",
                    "isCameraPresented",
                    "PhotosPickerItem",
                    "CameraCaptureView",
                    "CaptureImageTextRecognizer",
                    "CaptureDraft.localText(",
                    "CaptureDraft.importURL(",
                    "CaptureDraft.videoURL(",
                    "CaptureDraft.jsonLD(",
                    "CaptureDraft.cameraImage(",
                    "CaptureDraft.photoLibraryImage(",
                    "private func createTextDraft",
                    "private func createURLDraft",
                    "private func createVideoDraft",
                    "private func createJSONLDDraft",
                    "createPhotoLibraryDraft",
                    "createCameraDraft",
                    "createImageDraft",
                    "\"Recipe links, text, and photos sent to Spoonjoy appear here for review.\"",
                    "\"Send recipes to Spoonjoy. New captures will appear here for review.\"",
                    "\"Ready for imports\"",
                    "\"Send to Spoonjoy\"",
                    "\"Sending\"",
                    "\"Local draft saved.\"",
                    "\"Recipe URL saved.\"",
                    "\"Import source saved.\"",
                    "\"JSON-LD draft saved.\"",
                    "shareSheetComingSoon",
                    "siriComingSoon",
                    "cameraComingSoon",
                    "photoLibraryComingSoon",
                    "Share Sheet",
                    "Future entry points are listed"
                ],
                "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift": [
                    "\"Send to Spoonjoy\"",
                    "\"Import Status\""
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "\"Send to Spoonjoy\"",
                    "\"Capture surface creates native drafts and submits import-ready sources.\"",
                    "shareSheetComingSoon",
                    "siriComingSoon",
                    "cameraComingSoon",
                    "photoLibraryComingSoon"
                ],
                "scripts/capture-native-screenshots.sh": [
                    "\"Import Status\"",
                    "\"Spoonjoy Capture\"",
                    "\"Send to Spoonjoy\""
                ],
                "scripts/validate-design-review.rb": [
                    "\"Import Status\"",
                    "\"Spoonjoy Capture\"",
                    "\"Send to Spoonjoy\""
                ]
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

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

    @Test("queued import sources decode every persisted source variant and fail closed for malformed payloads")
    func queuedImportSourcesDecodeEveryPersistedSourceVariantAndFailClosedForMalformedPayloads() throws {
        let jsonLD = JSONValue.object(["@type": .string("Recipe"), "name": .string("Decoder Soup")])
        let decodedCases: [(JSONValue, NativeMutationSource)] = [
            (
                .object(["type": .string("url"), "url": .string("https://example.com/queued-url")]),
                .url(URL(string: "https://example.com/queued-url")!)
            ),
            (
                .object(["type": .string("text"), "text": .string("Plain text import")]),
                .textWithMetadata("Plain text import", sourceURL: nil, capture: nil)
            ),
            (
                .object([
                    "type": .string("text"),
                    "text": .string("Camera import"),
                    "url": .string("https://example.com/source-card"),
                    "capture": .object([
                        "source": .string("camera"),
                        "assetIdentifier": .string("camera-asset")
                    ])
                ]),
                .textWithMetadata(
                    "Camera import",
                    sourceURL: URL(string: "https://example.com/source-card")!,
                    capture: NativeCaptureTextMetadata(source: .camera, assetIdentifier: "camera-asset")
                )
            ),
            (
                .object([
                    "type": .string("text"),
                    "text": .string("Photo import"),
                    "capture": .object(["source": .string("photo-library")])
                ]),
                .textWithMetadata(
                    "Photo import",
                    sourceURL: nil,
                    capture: NativeCaptureTextMetadata(source: .photoLibrary, assetIdentifier: nil)
                )
            ),
            (
                .object(["type": .string("json-ld"), "jsonLd": jsonLD, "url": .string("https://example.com/jsonld")]),
                .jsonLD(jsonLD, sourceURL: URL(string: "https://example.com/jsonld")!)
            ),
            (
                .object(["type": .string("json-ld"), "jsonLd": .array([jsonLD])]),
                .jsonLD(.array([jsonLD]), sourceURL: nil)
            ),
            (
                .object(["type": .string("video-url"), "url": .string("https://example.com/watch?v=queued")]),
                .videoURL(URL(string: "https://example.com/watch?v=queued")!)
            )
        ]

        for (sourceJSON, expectedSource) in decodedCases {
            #expect(NativeMutationSource(jsonValue: sourceJSON) == expectedSource)
        }

        let malformedSources: [JSONValue] = [
            .array([]),
            .object(["url": .string("https://example.com/missing-type")]),
            .object(["type": .string("url")]),
            .object(["type": .string("text")]),
            .object(["type": .string("json-ld")]),
            .object(["type": .string("video-url")]),
            .object(["type": .string("unsupported")])
        ]
        for sourceJSON in malformedSources {
            #expect(NativeMutationSource(jsonValue: sourceJSON) == nil)
        }
        #expect(NativeCaptureTextMetadata(jsonValue: .object(["source": .string("scanner")])) == nil)

        let malformedImportMutation = try JSONDecoder().decode(NativeQueuedMutation.self, from: Data(
            """
            {
              "schemaVersion": 1,
              "id": "mutation_malformed_import",
              "clientMutationId": "cm_malformed_import",
              "createdAt": "\(Self.createdAt)",
              "kind": {
                "type": "recipe.import.submit",
                "source": {
                  "type": "url"
                }
              }
            }
            """.utf8
        ))
        let nonImportMutation = NativeQueuedMutation.profileDisplayUpdate(
            email: "ari@example.com",
            username: "ari",
            clientMutationID: "cm_profile_not_import",
            createdAt: Self.createdAt
        )

        #expect(malformedImportMutation.recipeImportSource == nil)
        #expect(nonImportMutation.recipeImportSource == nil)
    }

    @Test("capture drafts fail closed for incomplete native source state")
    func captureDraftsFailClosedForIncompleteNativeSourceState() throws {
        let urlDraft = try CaptureDraft.importURL(
            id: "draft_preview_url",
            url: URL(string: "https://example.com/preview-url")!,
            createdAt: Self.createdAt
        )
        let legacyImageDraft = CaptureDraft(
            id: "draft_legacy_image",
            source: .image,
            rawText: "Legacy image stew",
            imageAssetIdentifier: "legacy-asset",
            createdAt: Self.createdAt
        )
        let legacyImageNeedsOCR = CaptureDraft(
            id: "draft_legacy_image_needs_ocr",
            source: .image,
            rawText: "   ",
            imageAssetIdentifier: "legacy-empty-asset",
            createdAt: Self.createdAt
        )

        #expect(urlDraft.previewLines == ["https://example.com/preview-url"])
        #expect(legacyImageDraft.importReadiness == .ready)
        #expect(try legacyImageDraft.importSource() == .textWithMetadata(
            "Legacy image stew",
            sourceURL: nil,
            capture: NativeCaptureTextMetadata(source: .camera, assetIdentifier: "legacy-asset")
        ))
        #expect(legacyImageNeedsOCR.importReadiness == .needsTextRecognition)
        #expect(throws: CaptureDraftImportError.needsTextRecognition) {
            _ = try legacyImageNeedsOCR.importSource()
        }

        #expect(throws: CaptureDraftImportError.missingImportSource("draft_missing_url")) {
            _ = try CaptureDraft(
                id: "draft_missing_url",
                source: .url,
                rawText: "",
                imageAssetIdentifier: nil,
                createdAt: Self.createdAt
            ).importSource()
        }
        #expect(throws: CaptureDraftImportError.missingImportSource("draft_missing_video")) {
            _ = try CaptureDraft(
                id: "draft_missing_video",
                source: .videoURL,
                rawText: "",
                imageAssetIdentifier: nil,
                createdAt: Self.createdAt
            ).importSource()
        }
        #expect(throws: CaptureDraftImportError.missingImportSource("draft_missing_jsonld")) {
            _ = try CaptureDraft(
                id: "draft_missing_jsonld",
                source: .jsonLD,
                rawText: "",
                imageAssetIdentifier: nil,
                createdAt: Self.createdAt
            ).importSource()
        }
        #expect(throws: CaptureDraftValidationError.emptyDraft("draft_invalid_url")) {
            _ = try CaptureDraft.importURL(
                id: "draft_invalid_url",
                url: URL(string: "spoonjoy://capture")!,
                createdAt: Self.createdAt
            )
        }
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
        let wrongIDDiscard = blocked.discardingCaptureDraft(id: "draft_not_visible", savedAt: Self.createdAt)
        let defaultBlocked = retrying.recordingCaptureImportProviderBlocker(resourceID: "   ", savedAt: Self.createdAt)
        let notDrained = retrying.clearingDrainedCaptureImport(
            clientMutationIDs: ["cm_different_import"],
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
        #expect(wrongIDDiscard.captureDraft == draft)
        #expect(defaultBlocked.captureImportProviderBlocker == "recipe-import")
        #expect(notDrained.captureDraft == draft)
        #expect(notDrained.pendingCaptureImport == mutation)
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
        #expect(plan.userFacingMessage == "Recipe import setup is required before Spoonjoy can finish this import.")
        #expect(!plan.userFacingMessage.contains("ProviderSecret"))
    }

    @Test("non-provider import blockers and empty responses keep the visible draft")
    func nonProviderImportBlockersAndEmptyResponsesKeepTheVisibleDraft() throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_empty_import",
            url: URL(string: "https://example.com/empty-import")!,
            createdAt: Self.createdAt
        )
        let viewModel = CaptureImportViewModel(draft: draft, connectivity: .online)
        let response = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "importCode": "provider returned no recipe",
              "blockers": [
                {
                  "capability": "NotProviderSecret",
                  "resource": "ignored"
                }
              ]
            }
            """.utf8
        ))
        let defaultProviderResource = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "blockers": [
                {
                  "capability": "ProviderSecret"
                }
              ]
            }
            """.utf8
        ))
        let trimmedProviderResource = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "blockers": [
                {
                  "capability": "ProviderSecret",
                  "resource": "   "
                }
              ]
            }
            """.utf8
        ))
        let namedProviderResource = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "blockers": [
                {
                  "capability": "Other",
                  "resource": "ignored"
                },
                {
                  "capability": "ProviderSecret",
                  "resource": "recipe-import-custom"
                }
              ]
            }
            """.utf8
        ))
        let noBlockersResponse = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
            """
            {
              "importCode": null
            }
            """.utf8
        ))

        let plan = try viewModel.planImportResult(
            response,
            clientMutationID: "cm_empty_import",
            createdAt: Self.createdAt
        )
        let defaultMessagePlan = try viewModel.planImportResult(
            noBlockersResponse,
            clientMutationID: "cm_empty_import_default",
            createdAt: Self.createdAt
        )

        #expect(response.providerSecretBlockerResourceID == nil)
        #expect(noBlockersResponse.providerSecretBlockerResourceID == nil)
        #expect(defaultProviderResource.providerSecretBlockerResourceID == "recipe-import")
        #expect(trimmedProviderResource.providerSecretBlockerResourceID == "recipe-import")
        #expect(namedProviderResource.providerSecretBlockerResourceID == "recipe-import-custom")
        #expect(plan.blocker == nil)
        #expect(plan.importedRecipeRoute == nil)
        #expect(plan.drainedClientMutationID == nil)
        #expect(plan.captureDraftAfterCompletion == draft)
        #expect(plan.userFacingMessage == "Import did not return a recipe.")
        #expect(defaultMessagePlan.userFacingMessage == "Import did not return a recipe.")
    }

    @Test("empty import result copy never exposes machine import codes")
    func emptyImportResultCopyNeverExposesMachineImportCodes() throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_machine_import_code",
            url: URL(string: "https://example.com/machine-code-import")!,
            createdAt: Self.createdAt
        )
        let viewModel = CaptureImportViewModel(draft: draft, connectivity: .online)
        let cases = [
            ("provider-secret", "Recipe import setup is required before Spoonjoy can finish this import."),
            ("provider_secret_required", "Recipe import setup is required before Spoonjoy can finish this import."),
            ("authRequired:Session expired.", "Import did not return a recipe."),
            ("fetch-blocked", "That recipe source could not be imported."),
            ("fetch-timeout", "Recipe import is busy. Try again soon."),
            ("rate-limited", "Recipe import is busy. Try again soon."),
            ("not-html", "That link does not look like an importable recipe."),
            ("video-unavailable", "That link does not look like an importable recipe."),
            ("internal.provider.missing", "Import did not return a recipe.")
        ]
        let forbiddenFragments = [
            "provider-secret",
            "provider_secret",
            "authRequired",
            "fetch-blocked",
            "not-html",
            "video-unavailable",
            "internal."
        ]

        for (importCode, expectedMessage) in cases {
            let response = try JSONDecoder().decode(RecipeImportResponse.self, from: Data(
                """
                {
                  "importCode": "\(importCode)"
                }
                """.utf8
            ))
            let plan = try viewModel.planImportResult(
                response,
                clientMutationID: "cm_\(importCode)",
                createdAt: Self.createdAt
            )

            #expect(plan.userFacingMessage == expectedMessage)
            for forbiddenFragment in forbiddenFragments {
                #expect(!plan.userFacingMessage.localizedCaseInsensitiveContains(forbiddenFragment))
            }
        }
    }

    @Test("compact capture import fallbacks stay covered and intentional")
    func compactCaptureImportFallbacksStayCoveredAndIntentional() throws {
        let jsonLD = JSONValue.object(["@type": .string("Recipe"), "name": .string("Fallback Cake")])
        let jsonLDSource = try CaptureDraft.jsonLD(
            id: "draft_jsonld_with_source",
            jsonLD: jsonLD,
            sourceURL: URL(string: "https://example.com/jsonld-source")!,
            createdAt: Self.createdAt
        ).importSource()
        let needsOCRDraft = try CaptureDraft.cameraImage(
            id: "draft_pending_ocr_replacement",
            assetIdentifier: "pending-ocr",
            recognizedText: nil,
            createdAt: Self.createdAt
        )
        let importDraft = try CaptureDraft.importURL(
            id: "draft_pending_before_ocr",
            url: URL(string: "https://example.com/pending-before-ocr")!,
            createdAt: Self.createdAt
        )
        let pendingImport = NativeQueuedMutation.recipeImportSubmit(
            source: try importDraft.importSource(),
            clientMutationID: "cm_pending_before_ocr",
            createdAt: Self.createdAt
        )
        let pendingSnapshot = NativeAppSnapshot
            .bootstrap(
                shoppingList: nil,
                accountID: "chef_ari",
                environment: .production,
                savedAt: Self.createdAt
            )
            .recordingCaptureImportRetry(pendingImport, savedAt: Self.createdAt)
        let replacedWithNeedsOCR = pendingSnapshot.recordingCaptureDraft(needsOCRDraft, savedAt: Self.createdAt)
        let emptyPreviewDraft = CaptureDraft(
            id: "draft_empty_preview",
            source: .jsonLD,
            rawText: "",
            imageAssetIdentifier: nil,
            createdAt: Self.createdAt
        )

        #expect(jsonLDSource.jsonValue() == .object([
            "type": .string("json-ld"),
            "jsonLd": jsonLD,
            "url": .string("https://example.com/jsonld-source")
        ]))
        #expect(replacedWithNeedsOCR.pendingCaptureImport == nil)
        #expect(emptyPreviewDraft.previewLines.isEmpty)
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
        #expect(offlinePlan.userFacingMessage == "Saved locally. Import will retry when Spoonjoy reconnects.")

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

private func captureImportSurfaceSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? captureImportSurfaceReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = relativePath.hasSuffix(".swift") ? captureImportSurfaceUncommentedSwift(content) : content
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func captureImportSurfaceReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func captureImportSurfaceUncommentedSwift(_ content: String) -> String {
    var output = ""
    var index = content.startIndex
    var inLineComment = false
    var blockDepth = 0
    var inString = false
    var escaped = false

    while index < content.endIndex {
        let character = content[index]
        let next = content.index(after: index)
        let nextCharacter = next < content.endIndex ? content[next] : nil

        if inLineComment {
            if character == "\n" {
                inLineComment = false
                output.append(character)
            }
        } else if blockDepth > 0 {
            if character == "/", nextCharacter == "*" {
                blockDepth += 1
                index = next
            } else if character == "*", nextCharacter == "/" {
                blockDepth -= 1
                index = next
            } else if character == "\n" {
                output.append(character)
            }
        } else if inString {
            output.append(character)
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                inString = false
            }
        } else if character == "/", nextCharacter == "/" {
            inLineComment = true
            index = next
        } else if character == "/", nextCharacter == "*" {
            blockDepth = 1
            index = next
        } else {
            output.append(character)
            if character == "\"" {
                inString = true
            }
        }

        index = content.index(after: index)
    }

    return output
}
