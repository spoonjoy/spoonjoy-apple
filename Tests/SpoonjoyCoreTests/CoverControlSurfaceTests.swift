import Foundation
import Testing
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
        #expect(imageCover.variants.first?.provenanceLabel == "Chef photo")

        let stylizedSnapshot = RecipeCoverControlsData.snapshot(recipe: Self.recipe(coverVariant: .stylized))
        let stylizedCover = try #require(stylizedSnapshot.covers.first)
        #expect(stylizedCover.imageURL == nil)
        #expect(stylizedCover.stylizedImageURL == URL(string: "https://spoonjoy.app/covers/lemon.jpg")!)
        #expect(stylizedCover.activeVariant == .stylized)
        #expect(stylizedCover.variants.first?.provenanceLabel == "Editorialized chef photo")

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
        #expect(ready.variants.map(\.provenanceLabel) == ["Chef photo", "Editorialized chef photo"])
        #expect(Self.cover(stylizedImageURL: URL(string: "https://spoonjoy.app/covers/stylized.jpg")!, displayURL: nil).thumbnailURL == URL(string: "https://spoonjoy.app/covers/stylized.jpg")!)
        #expect(Self.cover(imageURL: URL(string: "https://spoonjoy.app/covers/raw.jpg")!, stylizedImageURL: nil, displayURL: nil).thumbnailURL == URL(string: "https://spoonjoy.app/covers/raw.jpg")!)
        #expect(Self.cover(imageURL: nil, stylizedImageURL: nil, displayURL: nil).thumbnailURL == nil)

        #expect(Self.cover(status: "processing", generationStatus: "none").statusLabel == "Processing")
        #expect(Self.cover(status: "processing", generationStatus: "none").canActivate)
        #expect(Self.cover(status: "processing", generationStatus: "none").canMutate)
        #expect(Self.cover(status: "ready", generationStatus: "processing").statusLabel == "Processing")
        #expect(Self.cover(status: "ready", generationStatus: "failed").statusLabel == "Editorial failed")
        #expect(Self.cover(generationStatus: "failed", failureReason: "missing_image_provider_config").providerBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover generation needs an image provider secret before it can run.",
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
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "import", variant: .image) == "Imported photo")
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "ai-placeholder", variant: .image) == "AI generated")
        #expect(RecipeCoverCandidate.provenanceLabel(sourceType: "unknown", variant: .image) == "Unknown source")
        #expect(RecipeCoverSpoonImage(
            id: "spoon",
            photoURL: URL(string: "https://spoonjoy.app/spoon.jpg")!,
            cookedAt: Self.createdAt,
            chef: ChefSummary(id: "chef", username: "chef")
        ).cookedAtLabel == "Jun 27, 2026")
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
            message: "Image provider secret is missing.",
            ownerActionRequired: true,
            retryAfterSeconds: 45
        ))
        #expect(blocker.offlineIndicatorDisplay == .blocker(.providerSecret(resourceID: "Image provider secret is missing.")))

        let directBlocker = try #require(RecipeCoverProviderBlockerDisplay.from(apiError: APIError(
            requestID: "req_direct_blocked",
            code: "provider_secret",
            message: "Configure image provider.",
            status: 409,
            details: ["capability": .string("ProviderSecret"), "ownerAction": .bool(false), "retryAfterSeconds": .number(12)]
        )))
        #expect(directBlocker == RecipeCoverProviderBlockerDisplay(
            message: "Configure image provider.",
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
            message: "Configure the image provider.",
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
            message: "Image provider unavailable.",
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
        #expect(RecipeCoverControlsAction.regenerate(coverID: "cover", activateWhenReady: false, clientMutationID: "cm").successMessage == "Cover regeneration queued.")
        #expect(RecipeCoverControlsAction.archive(coverID: "cover", replacementCoverID: nil, replacementVariant: nil, confirmNoCover: true, deleteSafeObjects: false, clientMutationID: "cm").successMessage == "Cover archived.")
        #expect(RecipeCoverControlsAction.createFromSpoon(spoonID: "spoon", activate: false, generateEditorial: true, clientMutationID: "cm").successMessage == "Spoon photo queued as a cover.")
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
                .regenerate(coverID: "cover/raw", activateWhenReady: false, clientMutationID: "cm_regen"),
                .post,
                "/api/v1/recipes/recipe%2Flemon/covers/regenerate",
                ["clientMutationId": "cm_regen", "coverId": "cover/raw", "activateWhenReady": false],
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
