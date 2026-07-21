import Foundation
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SpoonjoyCore

@Suite("Native cover control surface parity")
struct CoverControlSurfaceTests {
    private static let createdAt = "2026-06-27T12:00:00.000Z"
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("live cover repository fetches archived cover history and spoon images")
    func liveCoverRepositoryFetchesArchivedHistoryAndSpoonImages() async throws {
        let data = RecipeCoverControlsData(
            covers: [
                Self.cover(id: "cover/raw", activeVariant: .image),
                Self.cover(id: "cover/archived", status: "archived", archivedAt: "2026-06-20T12:00:00.000Z")
            ],
            spoonImages: [
                RecipeCoverSpoonImage(
                    id: "spoon/one",
                    photoURL: URL(string: "https://spoonjoy.app/photos/spoons/one.jpg")!,
                    cookedAt: "2026-06-26T12:00:00.000Z",
                    chef: ChefSummary(id: "chef_ari", username: "ari")
                )
            ]
        )
        let transport = RecordingCoverControlsAPITransport(envelope: APIEnvelope(
            requestID: "req_cover_list",
            data: RecipeCoverListData(covers: data.covers, spoonImages: data.spoonImages)
        ))
        let repository = LiveRecipeCoverControlsRepository(
            transport: transport,
            configuration: Self.configuration
        )

        let result = try await repository.fetchCoverControls(recipeID: "recipe/lemon")
        let request = try #require(transport.requests.first)

        #expect(result == data)
        #expect(request.method == .get)
        #expect(request.url.path == "/api/v1/recipes/recipe%2Flemon/covers")
        #expect(request.queryItems == [
            URLQueryItem(name: "includeArchived", value: "true"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "offset", value: "0")
        ])
        #expect(request.headers["Authorization"] == "Bearer sj_private_token")

        let staticResult = try await RecipeCoverControlsData.live(
            recipeID: "recipe/lemon",
            configuration: Self.configuration,
            transport: transport
        )
        #expect(staticResult == data)
        #expect(transport.requests.count == 2)
    }

    @Test("snapshot and cover rows expose current variant labels replacement options and empty states")
    func snapshotAndCoverRowsExposeCurrentVariantLabelsReplacementOptionsAndEmptyStates() throws {
        let imageSnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverVariant: .image))
        let imageCover = try #require(imageSnapshot.covers.first)
        #expect(imageCover.id == "active-recipe_lemon")
        #expect(imageCover.thumbnailURL == URL(string: "https://spoonjoy.app/covers/lemon.jpg")!)
        #expect(imageCover.activeVariant == .image)
        #expect(imageCover.variants.map(\.variant) == [.image])
        #expect(imageCover.variants.first?.provenanceLabel == "Cooked cover")
        #expect(!imageCover.isServerBacked)
        #expect(!imageCover.canActivate)
        #expect(!imageCover.canMutate)

        let stylizedSnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverVariant: .stylized))
        let stylizedCover = try #require(stylizedSnapshot.covers.first)
        #expect(stylizedCover.imageURL == nil)
        #expect(stylizedCover.stylizedImageURL == URL(string: "https://spoonjoy.app/covers/lemon.jpg")!)
        #expect(stylizedCover.activeVariant == .stylized)
        #expect(stylizedCover.variants.first?.provenanceLabel == "Editorial cover")

        let illustrationSnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverVariant: .illustration))
        #expect(illustrationSnapshot.covers.first?.activeVariant == nil)
        let fallbackSourceSnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverSourceType: nil, coverVariant: .image))
        #expect(fallbackSourceSnapshot.covers.first?.sourceType == "chef-upload")
        let emptySnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverURL: nil, coverVariant: nil))
        #expect(emptySnapshot.covers.isEmpty)

        let active = Self.cover(id: "cover/active", activeVariant: .image)
        let replacement = Self.cover(id: "cover/replacement", activeVariant: nil)
        let archived = Self.cover(id: "cover/archived", status: "archived", archivedAt: Self.createdAt)
        let options = RecipeCoverControlsData(covers: [active, replacement, archived], spoonImages: [])
            .replacementOptions(for: active)

        #expect(options == [
            RecipeCoverReplacementOption(
                coverID: "cover/replacement",
                variant: .image,
                label: "Jun 27, 2026 - Original"
            ),
            RecipeCoverReplacementOption(
                coverID: "cover/replacement",
                variant: .stylized,
                label: "Jun 27, 2026 - Editorial"
            )
        ])
        #expect(options.map(\.id) == ["cover/replacement-image", "cover/replacement-stylized"])
    }

    @Test("cover rows classify status provenance variants and dates")
    func coverRowsClassifyStatusProvenanceVariantsAndDates() throws {
        let ready = Self.cover(sourceType: "spoon")
        #expect(ready.statusLabel == "Ready")
        #expect(!ready.isActive)
        #expect(ready.canActivate)
        #expect(ready.canMutate)
        #expect(ready.createdAtLabel == "Jun 27, 2026")
        #expect(ready.variants.map(\.provenanceLabel) == ["Cooked cover", "Editorial cover"])
        #expect(Self.cover(stylizedImageURL: URL(string: "https://spoonjoy.app/covers/stylized.jpg")!, displayURL: nil).thumbnailURL == URL(string: "https://spoonjoy.app/covers/stylized.jpg")!)
        #expect(Self.cover(imageURL: URL(string: "https://spoonjoy.app/covers/raw.jpg")!, stylizedImageURL: nil, displayURL: nil).thumbnailURL == URL(string: "https://spoonjoy.app/covers/raw.jpg")!)
        #expect(Self.cover(imageURL: nil, stylizedImageURL: nil, displayURL: nil).thumbnailURL == nil)

        #expect(Self.cover(status: "processing", generationStatus: "none").statusLabel == "Processing")
        #expect(Self.cover(status: "processing", generationStatus: "none").canActivate)
        #expect(Self.cover(status: "processing", generationStatus: "none").canMutate)
        #expect(Self.cover(status: "ready", generationStatus: "processing").statusLabel == "Processing")
        #expect(Self.cover(status: "ready", generationStatus: "failed").statusLabel == "Editorial failed")
        #expect(Self.cover(generationStatus: "failed", failureReason: "missing_image_provider_config").providerBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover setup is required before Spoonjoy can finish this cover.",
            ownerActionRequired: true,
            retryAfterSeconds: nil
        ))
        #expect(Self.cover(generationStatus: "failed", failureReason: "provider_timeout").providerBlocker == nil)
        #expect(Self.cover(status: "failed").statusLabel == "Failed")
        #expect(!Self.cover(status: "failed").canActivate)
        #expect(Self.cover(status: "failed").canMutate)
        #expect(Self.cover(status: "archived").statusLabel == "Archived")
        #expect(Self.cover(archivedAt: Self.createdAt).statusLabel == "Archived")
        #expect(!Self.cover(archivedAt: Self.createdAt).canActivate)
        #expect(!Self.cover(archivedAt: Self.createdAt).canMutate)

        #expect(RecipeCoverCandidate.dateLabel("2026-06-27T12:00:00Z") == "Jun 27, 2026")
        #expect(RecipeCoverCandidate.dateLabel("not-a-date") == "Saved cover")
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "import", variant: .image) == "Imported cover")
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "ai-placeholder", variant: .image) == "AI generated")
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "unknown", variant: .image) == "Unknown source")
        #expect(RecipeCoverSpoonImage(
            id: "spoon",
            photoURL: URL(string: "https://spoonjoy.app/spoon.jpg")!,
            cookedAt: Self.createdAt,
            chef: ChefSummary(id: "chef", username: "chef")
        ).cookedAtLabel == "Jun 27, 2026")
    }

    @Test("cover candidates decode server backing default and explicit fallback flag")
    func coverCandidatesDecodeServerBackingDefaultAndExplicitFallbackFlag() throws {
        let defaultServerBacked = try JSONDecoder().decode(RecipeCoverCandidate.self, from: Data("""
        {
          "id": "cover/default",
          "recipeId": "recipe/lemon",
          "status": "ready",
          "sourceType": "chef-upload",
          "imageUrl": "https://spoonjoy.app/covers/raw.jpg",
          "stylizedImageUrl": null,
          "displayUrl": null,
          "activeVariant": "image",
          "provenanceLabel": "Chef photo",
          "archivedAt": null,
          "generationStatus": "none",
          "failureReason": null,
          "sourceImageUrl": null,
          "createdAt": "2026-06-27T12:00:00.000Z"
        }
        """.utf8))
        #expect(defaultServerBacked.isServerBacked)
        #expect(defaultServerBacked.canMutate)

        let explicitLocalFallback = try JSONDecoder().decode(RecipeCoverCandidate.self, from: Data("""
        {
          "id": "active-recipe_lemon",
          "recipeId": "recipe/lemon",
          "status": "ready",
          "sourceType": "chef-upload",
          "imageUrl": "https://spoonjoy.app/covers/raw.jpg",
          "stylizedImageUrl": null,
          "displayUrl": null,
          "activeVariant": "image",
          "provenanceLabel": "Chef photo",
          "archivedAt": null,
          "generationStatus": "none",
          "failureReason": null,
          "isServerBacked": false,
          "sourceImageUrl": null,
          "createdAt": "2026-06-27T12:00:00.000Z"
        }
        """.utf8))
        #expect(!explicitLocalFallback.isServerBacked)
        #expect(!explicitLocalFallback.canActivate)
        #expect(!explicitLocalFallback.canMutate)
    }

    @Test("provider-secret blockers classify API errors and expose shell blocker display")
    func providerSecretBlockersClassifyAPIErrorsAndExposeShellDisplay() throws {
        let apiError = APIError(
            requestID: "req_cover_blocked",
            code: "validation_error",
            message: "Image provider secret is missing.",
            status: 400,
            details: [
                "blockers": .array([
                    .object([
                        "capability": .string("ProviderSecret"),
                        "ownerAction": .bool(true),
                        "retryAfterSeconds": .number(45)
                    ])
                ])
            ]
        )
        let blocker = try #require(RecipeCoverProviderBlockerDisplay.from(apiError: apiError))
        #expect(blocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover setup is required before Spoonjoy can finish this cover.",
            ownerActionRequired: true,
            retryAfterSeconds: 45
        ))
        #expect(blocker.offlineIndicatorDisplay == .blocker(.providerSecret(resourceID: "Recipe cover setup is required before Spoonjoy can finish this cover.")))

        let directBlocker = try #require(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_direct_blocked",
            code: "provider_secret",
            message: "Configure image provider.",
            status: 409,
            details: ["capability": .string("ProviderSecret"), "ownerAction": .bool(false), "retryAfterSeconds": .number(12)]
        )))
        #expect(directBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover setup is required before Spoonjoy can finish this cover.",
            ownerActionRequired: false,
            retryAfterSeconds: 12
        ))
        let directDefaultBlocker = try #require(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_direct_default_blocked",
            code: "provider_secret",
            message: "Configure the image provider.",
            status: 409,
            details: ["capability": .string("ProviderSecret")]
        )))
        #expect(directDefaultBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover setup is required before Spoonjoy can finish this cover.",
            ownerActionRequired: true,
            retryAfterSeconds: nil
        ))
        let arrayDefaultBlocker = try #require(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_array_default_blocked",
            code: "validation_error",
            message: "Image provider unavailable.",
            status: 400,
            details: [
                "blockers": .array([
                    .object([
                        "capability": .string("ProviderSecret"),
                        "retryAfterSeconds": .number(12.5)
                    ])
                ])
            ]
        )))
        #expect(arrayDefaultBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover setup is required before Spoonjoy can finish this cover.",
            ownerActionRequired: true,
            retryAfterSeconds: nil
        ))

        let transportError = APITransportError(
            kind: .apiError,
            requestID: apiError.requestID,
            statusCode: apiError.status,
            apiError: apiError,
            retryDecision: .doNotRetry
        )
        #expect(RecipeCoverProviderBlockerDisplay.from(error: transportError) == blocker)
        #expect(RecipeCoverProviderBlockerDisplay.from(error: apiError) == blocker)
        #expect(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_malformed_blockers",
            code: "validation_error",
            message: "Malformed blockers",
            status: 400,
            details: ["blockers": .object(["capability": .string("ProviderSecret")])]
        )) == nil)
        #expect(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_non_provider_blockers",
            code: "validation_error",
            message: "Different blocker",
            status: 400,
            details: ["blockers": .array([
                .string("unexpected"),
                .object(["capability": .string("OtherCapability")])
            ])]
        )) == nil)
        #expect(RecipeCoverProviderBlockerDisplay.from(error: CoverControlSurfaceTestFailure("ordinary failure")) == nil)
    }

    @Test("cover action success messages stay stable for Siri and UI feedback")
    func coverActionSuccessMessagesStayStable() {
        #expect(RecipeCoverControlsAction.setNoCover(clientMutationID: "cm").successMessage == "No-cover state saved.")
        #expect(RecipeCoverControlsAction.activate(coverID: "cover", variant: .image, clientMutationID: "cm").successMessage == "Cover updated.")
        #expect(RecipeCoverControlsAction.uploadPhoto(photo: Self.stagedCoverPhoto(), activate: true, generateEditorial: true, postAsSpoon: false, note: nil, nextTime: nil, cookedAt: nil, clientMutationID: "cm").successMessage == "Photo queued for cover review.")
        let activateWhenReadyUpload = RecipeCoverControlsAction.uploadPhoto(
            photo: Self.stagedCoverPhoto(),
            activateWhenReady: false,
            generateEditorial: true,
            postAsSpoon: true,
            note: "Loved it.",
            nextTime: "More herbs.",
            cookedAt: Self.createdAt,
            clientMutationID: "cm_activate_when_ready"
        )
        #expect(activateWhenReadyUpload == .uploadPhoto(
            photo: Self.stagedCoverPhoto(),
            activate: false,
            generateEditorial: true,
            postAsSpoon: true,
            note: "Loved it.",
            nextTime: "More herbs.",
            cookedAt: Self.createdAt,
            clientMutationID: "cm_activate_when_ready"
        ))
        #expect(RecipeCoverControlsAction.generatePlaceholder(promptAddition: nil, activateWhenReady: true, clientMutationID: "cm").successMessage == "Placeholder cover queued.")
        #expect(RecipeCoverControlsAction.regenerate(coverID: "cover", promptAddition: "warmer light", activateWhenReady: false, clientMutationID: "cm").successMessage == "Cover regeneration queued.")
        #expect(RecipeCoverControlsAction.archive(coverID: "cover", replacementCoverID: nil, replacementVariant: nil, confirmNoCover: true, deleteSafeObjects: false, clientMutationID: "cm").successMessage == "Cover archived.")
        #expect(RecipeCoverControlsAction.createFromSpoon(spoonID: "spoon", activate: false, generateEditorial: true, clientMutationID: "cm").successMessage == "Spoon photo queued as a cover.")
    }

    @Test("cover action preparation copy hides raw implementation errors")
    func coverActionPreparationCopyHidesRawImplementationErrors() {
        let message = RecipeCoverControlsMutationPlan.userFacingPreparationFailureMessage(
            for: CoverControlSurfaceTestFailure("provider-secret requestBuilder authRequired: /internal/path")
        )

        #expect(message == "Cover change could not be saved.")
        for forbidden in ["provider-secret", "requestBuilder", "authRequired", "/internal", "ordinary failure"] {
            #expect(!message.localizedCaseInsensitiveContains(forbidden))
        }

        let onlineOnlyMessage = RecipeCoverControlsMutationPlan.userFacingPreparationFailureMessage(
            for: RecipeCoverControlsActionPlanningError.onlineOnlyPlaceholderGeneration
        )
        #expect(onlineOnlyMessage == "AI placeholder covers need an internet connection.")

        let runtimeOfflineMessage = RecipeCoverControlsMutationPlan.userFacingExecutionFailureMessage(
            for: .generatePlaceholder(
                promptAddition: "moody window light",
                activateWhenReady: true,
                clientMutationID: "cm_generate_offline_runtime"
            ),
            error: APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        )
        #expect(runtimeOfflineMessage == "AI placeholder covers need an internet connection.")

        let genericRuntimeMessage = RecipeCoverControlsMutationPlan.userFacingExecutionFailureMessage(
            for: .setNoCover(clientMutationID: "cm_no_cover"),
            error: APITransportError(
                kind: .offline,
                requestID: nil,
                statusCode: nil,
                apiError: nil,
                retryDecision: .doNotRetry
            )
        )
        #expect(genericRuntimeMessage == "Cover change could not be saved.")
    }

    @Test("online cover actions plan exact REST mutations with offline fallbacks")
    func onlineCoverActionsPlanExactRESTMutationsWithOfflineFallbacks() throws {
        let actions: [(RecipeCoverControlsAction, APIRequestMethod, String, [String: Any], NativeQueuedMutationKind)] = [
            (
                .setNoCover(clientMutationID: "cm_none"),
                .patch,
                "/api/v1/recipes/recipe%2Flemon/covers",
                ["clientMutationId": "cm_none", "confirmNoCover": true],
                .coverSetNoCover
            ),
            (
                .activate(coverID: "cover/raw", variant: .stylized, clientMutationID: "cm_active"),
                .patch,
                "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fraw",
                ["clientMutationId": "cm_active", "variant": "stylized"],
                .coverSetActive
            ),
            (
                .regenerate(coverID: "cover/raw", promptAddition: "warmer light", activateWhenReady: false, clientMutationID: "cm_regen"),
                .post,
                "/api/v1/recipes/recipe%2Flemon/covers/regenerate",
                ["clientMutationId": "cm_regen", "coverId": "cover/raw", "promptAddition": "warmer light", "activateWhenReady": false],
                .coverRegenerate
            ),
            (
                .createFromSpoon(spoonID: "spoon/one", activate: false, generateEditorial: true, clientMutationID: "cm_spoon"),
                .post,
                "/api/v1/recipes/recipe%2Flemon/covers/from-spoon/spoon%2Fone",
                ["clientMutationId": "cm_spoon", "activate": false, "generateEditorial": true],
                .coverFromSpoon
            )
        ]

        for (action, method, path, body, kind) in actions {
            let plan = try RecipeCoverControlsMutationPlan.plan(
                action,
                recipeID: "recipe/lemon",
                connectivity: .online,
                createdAt: { Self.createdAt }
            )
            let remoteRequest = try coverRemoteRequest(from: plan)
            try assertJSONRequest(remoteRequest, method: method, path: path, expected: body)
            let fallback = try requireCoverMutation(plan.offlineFallbackMutation, "offline fallback")
            #expect(fallback.queueableKind == kind)
            #expect(fallback.dependencyKey == "recipe:recipe/lemon")
            let queuedRequest = try coverQueuedRequest(from: fallback)
            #expect(queuedRequest.method == method)
            #expect(queuedRequest.url.path == path)
        }
    }

    @Test("photo studio upload and generation actions plan exact requests")
    func photoStudioUploadAndGenerationActionsPlanExactRequests() throws {
        let stagedPhoto = Self.stagedCoverPhoto()
        let uploadPlan = try RecipeCoverControlsMutationPlan.plan(
            .uploadPhoto(
                photo: stagedPhoto,
                activate: true,
                generateEditorial: true,
                postAsSpoon: true,
                note: "Loved this batch.",
                nextTime: "Less salt.",
                cookedAt: Self.createdAt,
                clientMutationID: "cm_cover_upload"
            ),
            recipeID: "recipe/lemon",
            connectivity: .online,
            createdAt: { Self.createdAt }
        )
        let uploadFields = [
            "clientMutationId": "cm_cover_upload",
            "activateWhenReady": "true",
            "generateEditorial": "true",
            "postAsSpoon": "true",
            "note": "Loved this batch.",
            "nextTime": "Less salt.",
            "cookedAt": Self.createdAt
        ]
        try assertMultipartRequest(
            coverRemoteRequest(from: uploadPlan),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/image",
            fileField: "photo",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            fields: uploadFields
        )
        try assertNormalizedCoverFilePart(coverRemoteRequest(from: uploadPlan))
        let uploadFallback = try requireCoverMutation(uploadPlan.offlineFallbackMutation, "upload fallback")
        #expect(uploadFallback.queueableKind == .coverUpload)
        try assertMultipartRequest(
            coverQueuedRequest(from: uploadFallback),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/image",
            fileField: "photo",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            fields: uploadFields
        )
        try assertNormalizedCoverFilePart(coverQueuedRequest(from: uploadFallback))

        let offlineUploadPlan = try RecipeCoverControlsMutationPlan.plan(
            .uploadPhoto(
                photo: stagedPhoto,
                activate: true,
                generateEditorial: true,
                postAsSpoon: false,
                note: nil,
                nextTime: nil,
                cookedAt: nil,
                clientMutationID: "cm_cover_upload_offline"
            ),
            recipeID: "recipe/lemon",
            connectivity: .offline,
            createdAt: { Self.createdAt }
        )
        #expect(offlineUploadPlan.remoteRequestBuilder == nil)
        #expect(offlineUploadPlan.offlineFallbackMutation == nil)
        let queuedUpload = try requireCoverMutation(offlineUploadPlan.queuedMutation, "offline upload")
        #expect(queuedUpload.queueableKind == .coverUpload)
        try assertMultipartRequest(
            coverQueuedRequest(from: queuedUpload),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/image",
            fileField: "photo",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            fields: [
                "clientMutationId": "cm_cover_upload_offline",
                "activateWhenReady": "true",
                "generateEditorial": "true",
                "postAsSpoon": "false"
            ]
        )
        try assertNormalizedCoverFilePart(coverQueuedRequest(from: queuedUpload))

        let placeholderPlan = try RecipeCoverControlsMutationPlan.plan(
            .generatePlaceholder(
                promptAddition: "brighter window light",
                activateWhenReady: true,
                clientMutationID: "cm_generate"
            ),
            recipeID: "recipe/lemon",
            connectivity: .online,
            createdAt: { Self.createdAt }
        )
        #expect(placeholderPlan.queuedMutation == nil)
        #expect(placeholderPlan.offlineFallbackMutation == nil)
        try assertJSONRequest(
            coverRemoteRequest(from: placeholderPlan),
            method: .post,
            path: "/api/v1/recipes/recipe%2Flemon/covers/generate",
            expected: [
                "clientMutationId": "cm_generate",
                "promptAddition": "brighter window light",
                "activateWhenReady": true
            ]
        )
    }

    @Test("AI placeholder generation is explicitly online only")
    func aiPlaceholderGenerationIsExplicitlyOnlineOnly() throws {
        #expect(throws: RecipeCoverControlsActionPlanningError.onlineOnlyPlaceholderGeneration) {
            _ = try RecipeCoverControlsMutationPlan.plan(
                .generatePlaceholder(
                    promptAddition: "moody window light",
                    activateWhenReady: true,
                    clientMutationID: "cm_generate_offline"
                ),
                recipeID: "recipe/lemon",
                connectivity: .offline,
                createdAt: { Self.createdAt }
            )
        }
    }

    @Test("archive cover action carries nullable replacement values and query idempotency")
    func archiveCoverActionCarriesNullableReplacementValuesAndQueryIdempotency() throws {
        let replace = try RecipeCoverControlsMutationPlan.plan(
            .archive(
                coverID: "cover/old",
                replacementCoverID: "cover/new",
                replacementVariant: .image,
                confirmNoCover: false,
                deleteSafeObjects: false,
                clientMutationID: "cm_replace"
            ),
            recipeID: "recipe/lemon",
            connectivity: .online,
            createdAt: { Self.createdAt }
        )
        let replaceRequest = try coverRemoteRequest(from: replace)
        try assertJSONRequest(
            replaceRequest,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fold",
            expected: [
                "replacementCoverId": "cover/new",
                "replacementVariant": "image",
                "confirmNoCover": false,
                "deleteSafeObjects": false
            ]
        )
        #expect(replaceRequest.queryItems == [URLQueryItem(name: "clientMutationId", value: "cm_replace")])

        let clear = try RecipeCoverControlsMutationPlan.plan(
            .archive(
                coverID: "cover/old",
                replacementCoverID: nil,
                replacementVariant: nil,
                confirmNoCover: true,
                deleteSafeObjects: true,
                clientMutationID: "cm_clear"
            ),
            recipeID: "recipe/lemon",
            connectivity: .online,
            createdAt: { Self.createdAt }
        )
        let clearRequest = try coverRemoteRequest(from: clear)
        try assertJSONRequest(
            clearRequest,
            method: .delete,
            path: "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fold",
            expected: [
                "replacementCoverId": NSNull(),
                "replacementVariant": NSNull(),
                "confirmNoCover": true,
                "deleteSafeObjects": true
            ]
        )
        let fallback = try requireCoverMutation(clear.offlineFallbackMutation, "clear fallback")
        #expect(fallback.queueableKind == .coverArchive)
        #expect(fallback.dependencyKey == "recipe:recipe/lemon")
    }

    @Test("offline cover actions queue without remote requests")
    func offlineCoverActionsQueueWithoutRemoteRequests() throws {
        let defaultTimestampPlan = try RecipeCoverControlsMutationPlan.plan(
            .setNoCover(clientMutationID: "cm_default_time"),
            recipeID: "recipe/lemon",
            connectivity: .online
        )
        #expect(defaultTimestampPlan.offlineFallbackMutation?.queueableKind == .coverSetNoCover)

        let plan = try RecipeCoverControlsMutationPlan.plan(
            .activate(coverID: "cover/raw", variant: .image, clientMutationID: "cm_offline"),
            recipeID: "recipe/lemon",
            connectivity: .offline,
            createdAt: { Self.createdAt }
        )

        #expect(plan.remoteRequestBuilder == nil)
        #expect(plan.offlineFallbackMutation == nil)
        let queued = try requireCoverMutation(plan.queuedMutation, "queued mutation")
        #expect(queued.queueableKind == .coverSetActive)
        #expect(queued.clientMutationID == "cm_offline")
        let request = try coverQueuedRequest(from: queued)
        try assertJSONRequest(
            request,
            method: .patch,
            path: "/api/v1/recipes/recipe%2Flemon/covers/cover%2Fraw",
            expected: ["clientMutationId": "cm_offline", "variant": "image"]
        )
    }

    @Test("cover photo staging uses real picker bytes and preserves existing staged media on rejection")
    func coverPhotoStagingUsesRealPickerBytesAndPreservesExistingStagedMediaOnRejection() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        #expect(policy.acceptedContentTypes == ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"])
        #expect(policy.fileExtension(for: "image/jpeg") == "jpg")
        #expect(policy.fileExtension(for: "image/png") == "jpg")
        #expect(policy.fileExtension(for: "image/webp") == "jpg")
        #expect(policy.fileExtension(for: "image/heic") == "jpg")
        #expect(policy.fileExtension(for: "image/heif") == "jpg")
        #expect(policy.fileExtension(for: "image/gif") == nil)

        let heicBytes = orientedHEICFixtureData()
        let accepted = policy.stageSelection(
            existing: nil,
            data: heicBytes,
            contentType: "image/heic",
            localStageID: "cover-stage-heic",
            existingUsage: .zero
        )
        let staged = try #require(accepted.stagedPhoto)
        #expect(accepted.rejection == nil)
        #expect(staged.localStageID == "cover-stage-heic")
        #expect(staged.fileName == "cover.jpg")
        #expect(staged.contentType == "image/jpeg")
        #expect(staged.byteCount <= coverUploadServerByteCeiling)
        #expect(staged.data != heicBytes)
        let orientedSize = try assertNormalizedCoverJPEG(staged)
        #expect(orientedSize.width == 20)
        #expect(orientedSize.height == 32)

        let queuedCover = NativeQueuedMutation.coverUpload(
            recipeID: "recipe/lemon",
            photo: staged,
            clientMutationID: "cm_cover_upload_staged",
            activate: true,
            generateEditorial: true,
            postAsSpoon: true,
            note: "First cook.",
            nextTime: "Less salt.",
            cookedAt: "2026-06-27T12:00:00.000Z",
            createdAt: Self.createdAt
        )
        #expect(RecipeCoverPhotoStagedMediaUsage(queuedMutations: [queuedCover]) == RecipeCoverPhotoStagedMediaUsage(byteCount: staged.byteCount, fileCount: 1))

        let cancel = policy.cancel(existing: staged)
        #expect(cancel == RecipeCoverPhotoStagingResult(stagedPhoto: staged, rejection: nil))

        let unsupported = policy.stageSelection(
            existing: staged,
            data: Data([0x47, 0x49, 0x46]),
            contentType: "image/gif",
            localStageID: "cover-stage-gif",
            existingUsage: .zero
        )
        #expect(unsupported == RecipeCoverPhotoStagingResult(
            stagedPhoto: staged,
            rejection: .unsupportedContentType("image/gif")
        ))

        let empty = policy.stageSelection(
            existing: staged,
            data: Data(),
            contentType: "image/jpeg",
            localStageID: "cover-stage-empty",
            existingUsage: .zero
        )
        #expect(empty == RecipeCoverPhotoStagingResult(stagedPhoto: staged, rejection: .emptyData))
        let emptyCandidate = policy.stageSelection(
            existing: staged,
            candidate: NativeStagedMediaUpload(
                localStageID: "cover-stage-empty-candidate",
                fileName: "cover.jpg",
                contentType: "image/jpeg",
                data: Data()
            ),
            existingUsage: .zero
        )
        #expect(emptyCandidate == RecipeCoverPhotoStagingResult(stagedPhoto: staged, rejection: .emptyData))

        let metadataOnlyCandidate = NativeStagedMediaUpload(
            localStageID: "cover-stage-metadata-only",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            byteCount: 1
        )
        let metadataOnly = policy.stageSelection(
            existing: staged,
            candidate: metadataOnlyCandidate,
            existingUsage: .zero
        )
        #expect(metadataOnly == RecipeCoverPhotoStagingResult(
            stagedPhoto: metadataOnlyCandidate,
            rejection: nil
        ))

        let oversized = policy.stageSelection(
            existing: staged,
            data: Data(),
            contentType: "image/jpeg",
            byteCount: policy.mediaPolicy.maxIndividualUserSelectedBytes + 1,
            localStageID: "cover-stage-large",
            existingUsage: .zero
        )
        #expect(oversized == RecipeCoverPhotoStagingResult(
            stagedPhoto: staged,
            rejection: .media(.individualFileTooLarge(limitBytes: policy.mediaPolicy.maxIndividualUserSelectedBytes))
        ))

        let tinyOutputPolicy = RecipeCoverPhotoStagingPolicy(
            mediaPolicy: policy.mediaPolicy,
            normalizer: RecipeCoverImageNormalizer(maxOutputBytes: 1, jpegQualityCandidates: [0.92])
        )
        let unfit = tinyOutputPolicy.stageSelection(
            existing: staged,
            data: try fixtureImageData(width: 32, height: 32, typeIdentifier: UTType.jpeg.identifier),
            contentType: "image/jpeg",
            localStageID: "cover-stage-unfit",
            existingUsage: .zero
        )
        #expect(unfit == RecipeCoverPhotoStagingResult(
            stagedPhoto: staged,
            rejection: .media(.individualFileTooLarge(limitBytes: 1))
        ))
    }

    @Test("cover photo staging enforces the original nonempty picker byte limit before normalization")
    func coverPhotoStagingEnforcesOriginalNonemptyPickerByteLimit() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        let existing = NativeStagedMediaUpload(
            localStageID: "cover-stage-existing",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            data: try fixtureImageData(width: 24, height: 16, typeIdentifier: UTType.jpeg.identifier)
        )
        let limit = policy.mediaPolicy.maxIndividualUserSelectedBytes

        let boundary = policy.stageSelection(
            existing: existing,
            data: existing.data,
            contentType: "image/jpeg",
            byteCount: limit,
            localStageID: "cover-stage-boundary",
            existingUsage: .zero
        )
        #expect(boundary.rejection == nil)
        #expect(boundary.stagedPhoto?.localStageID == "cover-stage-boundary")

        let oversizedData = Data(repeating: 0, count: limit + 1)
        let oversized = policy.stageSelection(
            existing: existing,
            data: oversizedData,
            contentType: "image/jpeg",
            localStageID: "cover-stage-runtime-oversized",
            existingUsage: .zero
        )

        #expect(oversized.rejection == .media(.individualFileTooLarge(limitBytes: limit)))
        #expect(oversized.stagedPhoto?.localStageID == existing.localStageID)
        #expect(oversized.stagedPhoto?.byteCount == existing.byteCount)
        #expect(oversized.stagedPhoto?.data == existing.data)
    }

    @Test("cover photo staging worker owns normalization away from the main actor")
    @MainActor
    func coverPhotoStagingWorkerOwnsNormalizationAwayFromMainActor() async throws {
        let worker = RecipeCoverPhotoStagingWorker()
        let source = try fixtureImageData(width: 48, height: 32, typeIdentifier: UTType.png.identifier)
        let result = await worker.stageSelection(
            existing: nil,
            candidate: NativeStagedMediaUpload(
                localStageID: "cover-stage-worker",
                fileName: "cover.png",
                contentType: "image/png",
                data: source
            ),
            existingUsage: .zero
        )

        let staged = try #require(result.stagedPhoto)
        #expect(result.rejection == nil)
        #expect(staged.localStageID == "cover-stage-worker")
        #expect(staged.data != source)
        try assertNormalizedCoverJPEG(staged)
    }

    @Test("cover photo staging normalizes HEIF PNG JPEG WebP and oversized input to bounded JPEG")
    func coverPhotoStagingNormalizesSupportedFormatsToBoundedJPEG() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        let samples: [(label: String, data: Data, contentType: String, expectedMaxDimension: Int)] = [
            (
                "heif",
                orientedHEICFixtureData(),
                "image/heif",
                32
            ),
            (
                "jpeg",
                try fixtureImageData(width: 640, height: 480, typeIdentifier: UTType.jpeg.identifier),
                "image/jpeg",
                640
            ),
            (
                "png",
                try fixtureImageData(width: 2050, height: 32, typeIdentifier: UTType.png.identifier),
                "image/png",
                2048
            ),
            (
                "webp",
                webPFixtureData(),
                "image/webp",
                1
            )
        ]

        for sample in samples {
            let result = policy.stageSelection(
                existing: nil,
                data: sample.data,
                contentType: sample.contentType,
                localStageID: "cover-stage-\(sample.label)",
                existingUsage: .zero
            )
            let staged = try #require(result.stagedPhoto)
            #expect(result.rejection == nil)
            #expect(staged.localStageID == "cover-stage-\(sample.label)")
            #expect(staged.fileName == "cover.jpg")
            #expect(staged.contentType == "image/jpeg")
            #expect(staged.byteCount <= coverUploadServerByteCeiling)
            let size = try assertNormalizedCoverJPEG(staged)
            #expect(max(size.width, size.height) <= sample.expectedMaxDimension)
        }

        let oversizedPNG = try fixtureImageData(
            width: 1600,
            height: 1200,
            typeIdentifier: UTType.png.identifier,
            pattern: .noisy
        )
        #expect(oversizedPNG.count > coverUploadServerByteCeiling)
        let oversizedResult = policy.stageSelection(
            existing: nil,
            data: oversizedPNG,
            contentType: "image/png",
            localStageID: "cover-stage-oversized",
            existingUsage: .zero
        )
        let oversizedStage = try #require(oversizedResult.stagedPhoto)
        #expect(oversizedResult.rejection == nil)
        #expect(oversizedStage.contentType == "image/jpeg")
        #expect(oversizedStage.byteCount <= coverUploadServerByteCeiling)
        #expect(oversizedStage.data.count <= coverUploadServerByteCeiling)
        #expect(oversizedStage.data.count < oversizedPNG.count)
        let oversizedSize = try assertNormalizedCoverJPEG(oversizedStage)
        #expect(max(oversizedSize.width, oversizedSize.height) <= 2048)
    }

    @Test("cover image normalizer rejects unsupported unreadable and unfit output")
    func coverImageNormalizerRejectsUnsupportedUnreadableAndUnfitOutput() throws {
        let normalizer = RecipeCoverImageNormalizer.serverUpload
        #expect(throws: RecipeCoverImageNormalizationError.unsupportedContentType("image/gif")) {
            _ = try normalizer.normalize(
                data: Data([0x47, 0x49, 0x46]),
                contentType: "image/gif",
                localStageID: "cover-stage-gif"
            )
        }
        #expect(throws: RecipeCoverImageNormalizationError.unreadableImage) {
            _ = try normalizer.normalize(
                data: Data(),
                contentType: "image/jpeg",
                localStageID: "cover-stage-empty"
            )
        }
        #expect(throws: RecipeCoverImageNormalizationError.unreadableImage) {
            _ = try normalizer.normalize(
                data: Data([0xFF, 0xD8, 0x00, 0x00]),
                contentType: "image/jpeg",
                localStageID: "cover-stage-corrupt"
            )
        }
        let tinyOutputNormalizer = RecipeCoverImageNormalizer(maxOutputBytes: 1, jpegQualityCandidates: [0.92])
        #expect(throws: RecipeCoverImageNormalizationError.byteLimitExceeded(limitBytes: 1)) {
            _ = try tinyOutputNormalizer.normalize(
                data: fixtureImageData(width: 32, height: 32, typeIdentifier: UTType.jpeg.identifier),
                contentType: "image/jpeg",
                localStageID: "cover-stage-unfit"
            )
        }
    }

    @Test("cover image normalizer lowers JPEG quality only when required by the server byte limit")
    func coverImageNormalizerAdaptsJPEGQualityToByteLimit() throws {
        let source = try fixtureImageData(
            width: 256,
            height: 256,
            typeIdentifier: UTType.png.identifier,
            pattern: .noisy
        )
        let highQuality = try RecipeCoverImageNormalizer(
            maxOutputBytes: .max,
            jpegQualityCandidates: [0.92]
        ).normalize(data: source, contentType: "image/png", localStageID: "cover-stage-high-quality")
        let adaptiveLimit = highQuality.byteCount - 1
        let adapted = try RecipeCoverImageNormalizer(
            maxOutputBytes: adaptiveLimit,
            jpegQualityCandidates: [0.92, 0.36]
        ).normalize(data: source, contentType: "image/png", localStageID: "cover-stage-adapted")

        #expect(adapted.byteCount <= adaptiveLimit)
        #expect(adapted.byteCount < highQuality.byteCount)
        try assertNormalizedCoverJPEG(adapted)
    }

    @Test("cover image normalizer preserves compliant JPEG bytes across repeated safety checks")
    func coverImageNormalizerPreservesCompliantJPEGBytes() throws {
        let source = try fixtureImageData(
            width: 640,
            height: 480,
            typeIdentifier: UTType.jpeg.identifier
        )
        let normalizer = RecipeCoverImageNormalizer.serverUpload

        let first = try normalizer.normalize(
            data: source,
            contentType: "image/jpeg",
            localStageID: "cover-stage-first"
        )
        let replay = try normalizer.normalize(upload: first)
        let jpegAlias = try normalizer.normalize(
            data: source,
            contentType: "image/jpg",
            localStageID: "cover-stage-jpg-alias"
        )

        let orientedJPEG = try fixtureImageData(
            width: 320,
            height: 180,
            typeIdentifier: UTType.jpeg.identifier,
            orientation: CGImagePropertyOrientation.right.rawValue
        )
        let normalizedOrientedJPEG = try normalizer.normalize(
            data: orientedJPEG,
            contentType: "image/jpeg",
            localStageID: "cover-stage-oriented"
        )

        let mislabeledPNG = try fixtureImageData(
            width: 64,
            height: 48,
            typeIdentifier: UTType.png.identifier
        )
        let normalizedMislabeledPNG = try normalizer.normalize(
            data: mislabeledPNG,
            contentType: "image/jpeg",
            localStageID: "cover-stage-mislabeled"
        )

        #expect(first.fileName == "cover.jpg")
        #expect(first.contentType == "image/jpeg")
        #expect(first.data == source)
        #expect(replay == first)
        #expect(replay.byteCount == first.byteCount)
        #expect(replay.data == first.data)
        #expect(jpegAlias.contentType == "image/jpeg")
        #expect(jpegAlias.data == source)
        #expect(normalizedOrientedJPEG.data != orientedJPEG)
        let orientedSize = try assertNormalizedCoverJPEG(normalizedOrientedJPEG)
        #expect(orientedSize.width == 180)
        #expect(orientedSize.height == 320)
        #expect(normalizedMislabeledPNG.data != mislabeledPNG)
        try assertNormalizedCoverJPEG(normalizedMislabeledPNG)
    }

    @Test("staged media equality includes byte count and payload data")
    func stagedMediaEqualityIncludesByteCountAndPayloadData() {
        let upload = NativeStagedMediaUpload(
            localStageID: "cover-stage-equality",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            byteCount: 3,
            data: Data([1, 2, 3])
        )
        let changedByteCount = NativeStagedMediaUpload(
            localStageID: upload.localStageID,
            fileName: upload.fileName,
            contentType: upload.contentType,
            byteCount: 4,
            data: upload.data
        )
        let changedData = NativeStagedMediaUpload(
            localStageID: upload.localStageID,
            fileName: upload.fileName,
            contentType: upload.contentType,
            byteCount: upload.byteCount,
            data: Data([3, 2, 1])
        )

        #expect(upload != changedByteCount)
        #expect(upload != changedData)
    }

    @Test("cover photo staging preserves prior stage on corrupt supported input")
    func coverPhotoStagingPreservesPriorStageOnCorruptSupportedInput() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        let existing = NativeStagedMediaUpload(
            localStageID: "cover-stage-existing",
            fileName: "cover.jpg",
            contentType: "image/jpeg",
            data: try fixtureImageData(width: 16, height: 16, typeIdentifier: UTType.jpeg.identifier)
        )

        for (contentType, data) in [
            ("image/heic", Data([0x48, 0x45, 0x49, 0x43])),
            ("image/heif", Data([0x00, 0x00, 0x00, 0x18])),
            ("image/jpeg", Data([0xFF, 0xD8, 0x00, 0x00]))
        ] {
            let result = policy.stageSelection(
                existing: existing,
                data: data,
                contentType: contentType,
                localStageID: "cover-stage-corrupt-\(contentType)",
                existingUsage: .zero
            )
            #expect(result.stagedPhoto == existing)
            #expect(result.rejection != nil)
        }
    }

    @Test("cover upload immediate durable and queued replay all emit normalized bounded JPEG")
    func coverUploadImmediateDurableAndQueuedReplayEmitNormalizedBoundedJPEG() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        let staged = try #require(policy.stageSelection(
            existing: nil,
            data: orientedHEICFixtureData(),
            contentType: "image/heic",
            localStageID: "cover-stage-durable",
            existingUsage: .zero
        ).stagedPhoto)
        try assertNormalizedCoverJPEG(staged)

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-cover-normalization-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let directory = NativeStagedMediaDirectory(directoryURL: directoryURL)
        try directory.save(staged)
        let restored = staged.replacingData(try directory.data(for: staged))
        #expect(restored.fileName == "cover.jpg")
        #expect(restored.contentType == "image/jpeg")
        #expect(restored.byteCount <= coverUploadServerByteCeiling)
        try assertNormalizedCoverJPEG(restored)

        let onlinePlan = try RecipeCoverControlsMutationPlan.plan(
            .uploadPhoto(
                photo: restored,
                activate: true,
                generateEditorial: true,
                postAsSpoon: false,
                note: nil,
                nextTime: nil,
                cookedAt: nil,
                clientMutationID: "cm_cover_normalized_online"
            ),
            recipeID: "recipe/lemon",
            connectivity: .online,
            createdAt: { Self.createdAt }
        )
        try assertNormalizedCoverFilePart(coverRemoteRequest(from: onlinePlan))
        let onlineFallback = try requireCoverMutation(onlinePlan.offlineFallbackMutation, "online fallback")
        try assertNormalizedCoverFilePart(coverQueuedRequest(from: onlineFallback))

        let offlinePlan = try RecipeCoverControlsMutationPlan.plan(
            .uploadPhoto(
                photo: restored,
                activate: true,
                generateEditorial: false,
                postAsSpoon: true,
                note: "Cooked outside.",
                nextTime: "Less char.",
                cookedAt: Self.createdAt,
                clientMutationID: "cm_cover_normalized_offline"
            ),
            recipeID: "recipe/lemon",
            connectivity: .offline,
            createdAt: { Self.createdAt }
        )
        let queuedMutation = try requireCoverMutation(offlinePlan.queuedMutation, "offline normalized upload")
        try assertNormalizedCoverFilePart(coverQueuedRequest(from: queuedMutation))
    }

    @Test("cover photo staging accounts for queued uploads and replacement drafts without silent eviction")
    func coverPhotoStagingAccountsForQueuedUploadsAndReplacementDraftsWithoutSilentEviction() throws {
        let policy = RecipeCoverPhotoStagingPolicy.offlineProductContract
        let maxBytes = policy.mediaPolicy.maxUnsyncedUserSelectedBytesPerAccount
        let existingDraft = NativeStagedMediaUpload(
            localStageID: "cover-stage-existing",
            fileName: "cover.webp",
            contentType: "image/webp",
            byteCount: maxBytes
        )
        let fullUsage = RecipeCoverPhotoStagedMediaUsage(byteCount: maxBytes, fileCount: 1)

        let rejected = policy.stageSelection(
            existing: nil,
            data: Data([0x01]),
            contentType: "image/png",
            localStageID: "cover-stage-over-cap",
            existingUsage: fullUsage
        )
        #expect(rejected == RecipeCoverPhotoStagingResult(
            stagedPhoto: nil,
            rejection: .media(.accountByteCapReached(limitBytes: maxBytes, silentEvictionAllowed: false))
        ))
        let fileCapRejected = policy.stageSelection(
            existing: nil,
            data: Data([0x01]),
            contentType: "image/png",
            localStageID: "cover-stage-file-cap",
            existingUsage: RecipeCoverPhotoStagedMediaUsage(
                byteCount: maxBytes - 1,
                fileCount: policy.mediaPolicy.maxUnsyncedUserSelectedFilesPerAccount
            )
        )
        #expect(fileCapRejected == RecipeCoverPhotoStagingResult(
            stagedPhoto: nil,
            rejection: .media(.accountFileCapReached(
                limitFiles: policy.mediaPolicy.maxUnsyncedUserSelectedFilesPerAccount,
                silentEvictionAllowed: false
            ))
        ))

        let validJPEG = try fixtureImageData(width: 16, height: 16, typeIdentifier: UTType.jpeg.identifier)
        let remainingByteRejected = policy.stageSelection(
            existing: nil,
            data: validJPEG,
            contentType: "image/jpeg",
            localStageID: "cover-stage-remaining-byte-cap",
            existingUsage: RecipeCoverPhotoStagedMediaUsage(byteCount: maxBytes - 1, fileCount: 0)
        )
        #expect(remainingByteRejected == RecipeCoverPhotoStagingResult(
            stagedPhoto: nil,
            rejection: .media(.accountByteCapReached(limitBytes: maxBytes, silentEvictionAllowed: false))
        ))

        let replacement = policy.stageSelection(
            existing: existingDraft,
            data: try fixtureImageData(width: 32, height: 20, typeIdentifier: UTType.png.identifier),
            contentType: "image/png",
            localStageID: "cover-stage-replacement",
            existingUsage: fullUsage
        )
        let replacementStage = try #require(replacement.stagedPhoto)
        #expect(replacementStage.localStageID == "cover-stage-replacement")
        #expect(replacementStage.fileName == "cover.jpg")
        #expect(replacementStage.contentType == "image/jpeg")
        try assertNormalizedCoverJPEG(replacementStage)
        #expect(replacement.rejection == nil)
        #expect(policy.mediaPolicy.allowsSilentEvictionOfUnsyncedUserMedia == false)
    }

    @Test("native photo studio view loads PhotosPicker bytes through cover staging policy")
    func nativePhotoStudioViewLoadsPhotosPickerBytesThroughCoverStagingPolicy() throws {
        let coverControlsSource = try readCoverControlsRepoFile("Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift")
        let platformNavigationSource = try readCoverControlsRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")

        #expect(coverControlsSource.contains("import PhotosUI"))
        #expect(coverControlsSource.contains("import UniformTypeIdentifiers"))
        #expect(coverControlsSource.contains("@State private var selectedCoverPhotoItem: PhotosPickerItem?"))
        #expect(coverControlsSource.contains("@State private var stagedCoverPhoto: NativeStagedMediaUpload?"))
        #expect(coverControlsSource.contains("let stagedMediaUsage: RecipeCoverPhotoStagedMediaUsage"))
        #expect(coverControlsSource.contains("PhotosPicker(selection: $selectedCoverPhotoItem, matching: .images)"))
        #expect(coverControlsSource.contains("loadTransferable(type: Data.self)"))
        #expect(coverControlsSource.contains("RecipeCoverPhotoStagingPolicy.offlineProductContract"))
        #expect(coverControlsSource.contains("private static let photoStagingWorker = RecipeCoverPhotoStagingWorker()"))
        #expect(coverControlsSource.contains("stageSelectedCoverPhoto"))
        #expect(coverControlsSource.contains("NativeStagedMediaUpload("))
        #expect(coverControlsSource.contains("\"image/heic\""))
        #expect(coverControlsSource.contains("\"image/webp\""))
        #expect(coverControlsSource.contains("existingUsage: stagedMediaUsage"))
        #expect(!coverControlsSource.contains("existingUsage: .zero"))
        #expect(platformNavigationSource.contains("stagedMediaUsage: RecipeCoverPhotoStagedMediaUsage(queuedMutations: contentState.queuedMutations)"))

        let stagingRange = try #require(coverControlsSource.range(of: "@MainActor private func stageSelectedCoverPhoto"))
        let stagingEndRange = try #require(coverControlsSource.range(of: "@MainActor private func rejectSelectedCoverPhoto"))
        let stagingSource = coverControlsSource[stagingRange.lowerBound..<stagingEndRange.lowerBound]
        #expect(stagingSource.contains("await Self.photoStagingWorker.stageSelection("))
        #expect(!stagingSource.contains("policy.stageSelection("))

        let rejectionRange = try #require(coverControlsSource.range(of: "@MainActor private func rejectSelectedCoverPhoto"))
        let clearRange = try #require(coverControlsSource.range(of: "@MainActor private func clearSelectedCoverPhoto"))
        let rejectionSource = coverControlsSource[rejectionRange.lowerBound..<clearRange.lowerBound]
        #expect(rejectionSource.contains("selectedCoverPhotoItem = nil"))
        #expect(rejectionSource.contains("actionError = message"))
        #expect(!rejectionSource.contains("stagedCoverPhoto = nil"))
    }

    @Test("native photo studio exposes upload spoon editorial placeholder and regeneration controls")
    func nativePhotoStudioExposesUploadSpoonEditorialPlaceholderAndRegenerationControls() throws {
        let coverControlsSource = try readCoverControlsRepoFile("Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift")

        let uploadTokens = [
            #"Text("Photo Studio")"#,
            #".padding(.vertical, 12)"#,
            #"@State private var shouldGenerateEditorialCover = true"#,
            #"@State private var shouldPostUploadedPhotoAsSpoon = true"#,
            #"@State private var spoonNote = """#,
            #"@State private var spoonNextTime = """#,
            #"@State private var spoonCookedAt = """#,
            #"Toggle("Editorialize cover", isOn: $shouldGenerateEditorialCover)"#,
            #"Toggle("Post original as a Spoon", isOn: $shouldPostUploadedPhotoAsSpoon)"#,
            #".padding(.vertical, 8)"#,
            #"DisclosureGroup {"#,
            #"Text("Spoon details")"#,
            #"TextField("Note", text: $spoonNote)"#,
            #"TextField("Next time", text: $spoonNextTime)"#,
            #"TextField("Cooked at", text: $spoonCookedAt)"#,
            #"Button { submitStagedCoverPhoto() }"#,
            #"runAction(.uploadPhoto("#,
            #"activateWhenReady: true"#,
            #"generateEditorial: shouldGenerateEditorialCover"#,
            #"postAsSpoon: shouldPostUploadedPhotoAsSpoon"#,
            #"note: trimmedOptional(spoonNote)"#,
            #"nextTime: trimmedOptional(spoonNextTime)"#,
            #"cookedAt: trimmedOptional(spoonCookedAt)"#
        ]
        let missingUploadTokens = uploadTokens.filter { !coverControlsSource.contains($0) }
        #expect(missingUploadTokens.isEmpty, "Missing native upload/Spoon control tokens: \(missingUploadTokens)")

        let generationTokens = [
            #"@State private var placeholderPromptAddition = """#,
            #"TextField("Placeholder direction", text: $placeholderPromptAddition)"#,
            #"runAction(.generatePlaceholder("#,
            #"promptAddition: trimmedOptional(placeholderPromptAddition)"#,
            #"activateWhenReady: true"#,
            #"@State private var regenerationPromptAdditions: [String: String] = [:]"#,
            #"TextField("Regeneration direction", text: regenerationPromptBinding(for: cover.id))"#,
            #"promptAddition: trimmedOptional(regenerationPromptAdditions[cover.id] ?? "")"#,
            #"activateWhenReady: cover.isActive"#
        ]
        let missingGenerationTokens = generationTokens.filter { !coverControlsSource.contains($0) }
        #expect(missingGenerationTokens.isEmpty, "Missing native generation control tokens: \(missingGenerationTokens)")

        let placeholderGenerationSource = try swiftMemberBody(
            named: "placeholderGenerationControl",
            in: coverControlsSource
        )
        for token in [
            #"Button { generatePlaceholderCover() }"#,
            #".controlSize(.large)"#
        ] {
            #expect(
                placeholderGenerationSource.contains(token),
                "placeholderGenerationControl missing scoped token \(token)"
            )
        }

        let processingTokens = [
            "ProgressView()",
            #"Label("Editorializing cover", systemImage: "sparkles")"#,
            #"cover.generationStatus == "processing""#,
            #"Text("Original photo stays on the Spoon.")"#
        ]
        let missingProcessingTokens = processingTokens.filter { !coverControlsSource.contains($0) }
        #expect(missingProcessingTokens.isEmpty, "Missing native processing/copy tokens: \(missingProcessingTokens)")

        let forbiddenTokens = [
            #"Text("Recipe Covers")"#,
            #"@State private var shouldActivateUploadedCover = true"#,
            #"Toggle("Use as recipe cover", isOn: $shouldActivateUploadedCover)"#,
            #"activateWhenReady: shouldActivateUploadedCover"#,
            #".disabled(connectivity == .offline)"#
        ].filter { coverControlsSource.contains($0) }
        #expect(forbiddenTokens.isEmpty, "Native Photo Studio still renders stale copy: \(forbiddenTokens)")
    }

    private static func cover(
        id: String = "cover/raw",
        status: String = "ready",
        sourceType: String = "chef-upload",
        imageURL: URL? = URL(string: "https://spoonjoy.app/covers/raw.jpg")!,
        stylizedImageURL: URL? = URL(string: "https://spoonjoy.app/covers/stylized.jpg")!,
        displayURL: URL? = URL(string: "https://spoonjoy.app/covers/display.jpg")!,
        activeVariant: RecipeCoverAPIVariant? = nil,
        archivedAt: String? = nil,
        generationStatus: String = "none",
        failureReason: String? = nil
    ) -> RecipeCoverCandidate {
        RecipeCoverCandidate(
            id: id,
            recipeID: "recipe/lemon",
            status: status,
            sourceType: sourceType,
            imageURL: imageURL,
            stylizedImageURL: stylizedImageURL,
            displayURL: displayURL,
            activeVariant: activeVariant,
            provenanceLabel: nil,
            archivedAt: archivedAt,
            generationStatus: generationStatus,
            failureReason: failureReason,
            sourceImageURL: nil,
            createdAt: Self.createdAt
        )
    }

    private static func stagedCoverPhoto() -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(
            localStageID: "stage_cover_photo",
            fileName: "cover.webp",
            contentType: "image/webp",
            data: webPFixtureData()
        )
    }

    private static func recipe(
        coverURL: URL? = URL(string: "https://spoonjoy.app/covers/lemon.jpg")!,
        coverSourceType: RecipeCoverSourceType? = .chefUpload,
        coverVariant: RecipeCoverVariant?
    ) -> Recipe {
        Recipe(
            id: "recipe_lemon",
            title: "Lemon Pasta",
            description: nil,
            servings: "4",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: coverURL,
            coverProvenanceLabel: "Ari's chef photo",
            coverSourceType: coverSourceType,
            coverVariant: coverVariant,
            href: "/recipes/recipe_lemon",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon")!,
            attribution: RecipeAttribution(
                creditText: "Ari",
                canonicalURL: URL(string: "https://spoonjoy.app/recipes/recipe_lemon")!,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: "2026-06-25T12:00:00.000Z",
            updatedAt: Self.createdAt,
            steps: [],
            cookbooks: []
        )
    }
}

private final class RecordingCoverControlsAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let envelope: APIEnvelope<RecipeCoverListData>
    private(set) var requests: [APIRequest] = []

    init(envelope: APIEnvelope<RecipeCoverListData>) {
        self.envelope = envelope
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        requests.append(try request.urlRequest(configuration: configuration))
        guard valueType == RecipeCoverListData.self else {
            throw CoverControlSurfaceTestFailure("Unexpected value type \(valueType).")
        }
        return envelope as! APIEnvelope<Value>
    }
}

private func coverRemoteRequest(from plan: RecipeCoverControlsMutationPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw CoverControlSurfaceTestFailure("Expected an online cover action to provide a remote request builder.")
    }
    return try builder.urlRequest(configuration: CoverControlSurfaceTests.configuration)
}

private func coverQueuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: CoverControlSurfaceTests.configuration)
}

private func requireCoverMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    guard let mutation else {
        throw CoverControlSurfaceTestFailure("Expected \(label) to provide a native queued mutation.")
    }
    return mutation
}

private let coverUploadServerByteCeiling = 5 * 1_024 * 1_024

@discardableResult
private func assertNormalizedCoverJPEG(
    _ upload: NativeStagedMediaUpload,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> (width: Int, height: Int) {
    #expect(upload.fileName == "cover.jpg", sourceLocation: sourceLocation)
    #expect(upload.contentType == "image/jpeg", sourceLocation: sourceLocation)
    #expect(upload.byteCount == upload.data.count, sourceLocation: sourceLocation)
    #expect(upload.byteCount > 0, sourceLocation: sourceLocation)
    #expect(upload.byteCount <= coverUploadServerByteCeiling, sourceLocation: sourceLocation)
    return try assertJPEGData(upload.data, sourceLocation: sourceLocation)
}

@discardableResult
private func assertNormalizedCoverFilePart(
    _ request: APIRequest,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> (width: Int, height: Int) {
    #expect(request.headers["Content-Type"]?.contains("multipart/form-data") == true, sourceLocation: sourceLocation)
    let fileData = try multipartFileData(in: request, fileField: "photo", fileName: "cover.jpg", contentType: "image/jpeg")
    #expect(fileData.count <= coverUploadServerByteCeiling, sourceLocation: sourceLocation)
    return try assertJPEGData(fileData, sourceLocation: sourceLocation)
}

@discardableResult
private func assertJPEGData(
    _ data: Data,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> (width: Int, height: Int) {
    #expect(Array(data.prefix(2)) == [0xFF, 0xD8], sourceLocation: sourceLocation)
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil), sourceLocation: sourceLocation)
    #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier, sourceLocation: sourceLocation)
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), sourceLocation: sourceLocation)
    #expect(max(image.width, image.height) <= 2048, sourceLocation: sourceLocation)
    return (image.width, image.height)
}

private func multipartFileData(
    in request: APIRequest,
    fileField: String,
    fileName: String,
    contentType: String
) throws -> Data {
    let body = try #require(request.body)
    let contentTypeHeader = try #require(request.headers["Content-Type"])
    let boundaryPrefix = "boundary="
    let boundaryStart = try #require(contentTypeHeader.range(of: boundaryPrefix)?.upperBound)
    let boundary = String(contentTypeHeader[boundaryStart...])
    let header = "Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n" +
        "Content-Type: \(contentType)\r\n\r\n"
    let headerData = Data(header.utf8)
    let startRange = try #require(body.range(of: headerData))
    let fileStart = startRange.upperBound
    let endMarker = Data("\r\n--\(boundary)".utf8)
    let suffix = body[fileStart...]
    let endRange = try #require(suffix.range(of: endMarker))
    return Data(suffix[..<endRange.lowerBound])
}

private enum FixtureImagePattern {
    case gradient
    case noisy
}

private func fixtureImageData(
    width: Int,
    height: Int,
    typeIdentifier: String,
    orientation: UInt32? = nil,
    pattern: FixtureImagePattern = .gradient
) throws -> Data {
    let image = try fixtureCGImage(width: width, height: height, pattern: pattern)
    let destinationData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        destinationData,
        typeIdentifier as CFString,
        1,
        nil
    ) else {
        throw CoverControlSurfaceTestFailure("Could not create image destination for \(typeIdentifier).")
    }
    var properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.95
    ]
    if let orientation {
        properties[kCGImagePropertyOrientation] = orientation
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw CoverControlSurfaceTestFailure("Could not finalize image destination for \(typeIdentifier).")
    }
    return destinationData as Data
}

private func fixtureCGImage(width: Int, height: Int, pattern: FixtureImagePattern) throws -> CGImage {
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            switch pattern {
            case .gradient:
                pixels[offset] = UInt8((x * 255) / max(1, width - 1))
                pixels[offset + 1] = UInt8((y * 255) / max(1, height - 1))
                pixels[offset + 2] = UInt8(((x + y) * 255) / max(1, width + height - 2))
            case .noisy:
                var value = UInt32(truncatingIfNeeded: x)
                value = value &* 1_664_525 &+ UInt32(truncatingIfNeeded: y) &* 1_013_904_223
                value ^= value >> 13
                value = value &* 1_274_126_177
                pixels[offset] = UInt8(truncatingIfNeeded: value)
                pixels[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
                pixels[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
            }
            pixels[offset + 3] = 255
        }
    }

    let data = Data(pixels)
    let provider = try #require(CGDataProvider(data: data as CFData))
    let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
    return try #require(image)
}

private func webPFixtureData() -> Data {
    Data(base64Encoded: "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA")!
}

private func orientedHEICFixtureData() -> Data {
    Data(base64Encoded: "AAAAJGZ0eXBoZWljAAAAAG1pZjFNaVBybWlhZk1pSEJoZWljAAABw21ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAHBpY3QAAAAAAAAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAAADnBpdG0AAAAAAAEAAAA4aWluZgAAAAAAAgAAABVpbmZlAgAAAAABAABodmMxAAAAABVpbmZlAgAAAQACAABFeGlmAAAAABppcmVmAAAAAAAAAA5jZHNjAAIAAQABAAAA5mlwcnAAAADFaXBjbwAAABNjb2xybmNseAACAAIABoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAAAAAAAAAgAAAAFAAAAAlpcm90AwAAABBwaXhpAAAAAAMICAgAAABxaHZjQwEDcAAAALAAAAAAAB7wAPz9+PgAAAsDoAABABdAAQwB//8DcAAAAwCwAAADAAADAB5wJKEAAQAjQgEBA3AAAAMAsAAAAwAAAwAeoBQgQcCDC+Ie5FlU3AgIGAKiAAEACUQBwGCsshAUyQAAABlpcG1hAAAAAAAAAAEAAQaBAgMFhoQAAAAsaWxvYwAAAABEAAACAAEAAAABAAACGwAAARAAAgAAAAEAAAH3AAAAJAAAAAFtZGF0AAAAAAAAAUQAAAAGRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAAAAAEMKAGvoR+wU6FZ6vWpo0wGyMw7MqCtu7r/Ip2W/j22jrAPHjczIDZ3qpbauwkOYbeMUjme+orlDuO+OZylTV/YYzetDyM9w6406sDhjl0bJ0SIrEjuiFgvAy5b7DvP31Ege0GtcF6Uyx+3DQ/bRz3GfFOH/7tup8pt8T47g7IQ7FPBZe9Y1TgQ/aY29a4rCOtuuSpY86XLSnliCIy5Gxhchyh3Jmo5kUUyE1r74Ve8nRd2byPeQCDp4P/C6kZaZtktAmn8EsO4Rr+Pu1itDoBni1ruvKg9GpmCZoI3PjtSMNQd5K75fGNH+E7i/PXsPoWCLf7//v/0f//iLPf/86K6E4MJ/YBZWN4T0F5VYA==")!
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any],
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    #expect(request.method == method, sourceLocation: sourceLocation)
    #expect(request.url.path == path, sourceLocation: sourceLocation)
    let body = try jsonBody(from: request)
    #expect(NSDictionary(dictionary: body).isEqual(to: expected), sourceLocation: sourceLocation)
}

private func assertMultipartRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    fileField: String,
    fileName: String,
    contentType: String,
    fields: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    #expect(request.method == method, sourceLocation: sourceLocation)
    #expect(request.url.path == path, sourceLocation: sourceLocation)
    let body = try #require(request.body)
    let bodyString = try #require(String(data: body, encoding: .isoLatin1))
    #expect(bodyString.contains(#"name="\#(fileField)"; filename="\#(fileName)""#), sourceLocation: sourceLocation)
    #expect(bodyString.contains("Content-Type: \(contentType)\r\n\r\n"), sourceLocation: sourceLocation)

    let expectedFieldNames = Set(fields.keys).union([fileField])
    #expect(multipartFieldNames(in: bodyString) == expectedFieldNames, sourceLocation: sourceLocation)
    for (name, value) in fields {
        #expect(bodyString.contains(#"name="\#(name)""#), sourceLocation: sourceLocation)
        #expect(bodyString.contains("\r\n\r\n\(value)\r\n"), sourceLocation: sourceLocation)
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

private func jsonBody(from request: APIRequest) throws -> [String: Any] {
    let data = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private struct CoverControlSurfaceTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private func readCoverControlsRepoFile(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func swiftMemberBody(named name: String, in source: String) throws -> String {
    guard let declarationRange = source.range(of: "private var \(name): some View") else {
        throw CoverControlSurfaceTestFailure("Missing Swift member \(name)")
    }
    guard let bodyStart = source[declarationRange.upperBound...].firstIndex(of: "{") else {
        throw CoverControlSurfaceTestFailure("Missing body for Swift member \(name)")
    }

    var depth = 0
    var index = bodyStart
    while index < source.endIndex {
        let character = source[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[bodyStart...index])
            }
        }
        index = source.index(after: index)
    }

    throw CoverControlSurfaceTestFailure("Unterminated Swift member \(name)")
}
