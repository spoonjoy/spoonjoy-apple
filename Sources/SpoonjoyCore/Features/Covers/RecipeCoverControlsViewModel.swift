import Foundation

public protocol RecipeCoverControlsRepository: Sendable {
    func fetchCoverControls(recipeID: String) async throws -> RecipeCoverControlsData
}

public struct LiveRecipeCoverControlsRepository: RecipeCoverControlsRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func fetchCoverControls(recipeID: String) async throws -> RecipeCoverControlsData {
        let envelope = try await transport.send(
            RecipeCoverRequests.listCovers(recipeID: recipeID, includeArchived: true, limit: 50, offset: 0),
            configuration: configuration,
            decode: RecipeCoverListData.self
        )
        return RecipeCoverControlsData(
            covers: envelope.data.covers,
            spoonImages: envelope.data.spoonImages
        )
    }
}

public enum RecipeCoverControlsConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum RecipeCoverControlsAction: Equatable, Sendable {
    case setNoCover(clientMutationID: String)
    case activate(coverID: String, variant: RecipeCoverAPIVariant, clientMutationID: String)
    case regenerate(coverID: String, activateWhenReady: Bool, clientMutationID: String)
    case archive(coverID: String, replacementCoverID: String?, replacementVariant: RecipeCoverAPIVariant?, confirmNoCover: Bool, deleteSafeObjects: Bool, clientMutationID: String)
    case createFromSpoon(spoonID: String, activate: Bool, generateEditorial: Bool, clientMutationID: String)

    public var successMessage: String {
        switch self {
        case .setNoCover:
            "No-cover state saved."
        case .activate:
            "Cover updated."
        case .regenerate:
            "Cover regeneration queued."
        case .archive:
            "Cover archived."
        case .createFromSpoon:
            "Spoon photo queued as a cover."
        }
    }
}

public struct RecipeCoverControlsMutationPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?

    public init(
        remoteRequestBuilder: APIRequestBuilder?,
        queuedMutation: NativeQueuedMutation?,
        offlineFallbackMutation: NativeQueuedMutation?
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
    }

    public static func plan(
        _ action: RecipeCoverControlsAction,
        recipeID: String,
        connectivity: RecipeCoverControlsConnectivity,
        createdAt: () -> String = { ISO8601DateFormatter().string(from: Date()) }
    ) throws -> RecipeCoverControlsMutationPlan {
        let online: APIRequestBuilder
        let offline: NativeQueuedMutation
        let mutationCreatedAt = createdAt()

        switch action {
        case .setNoCover(let clientMutationID):
            online = try RecipeCoverRequests.setNoCover(
                recipeID: recipeID,
                clientMutationID: clientMutationID,
                confirmNoCover: true
            )
            offline = NativeQueuedMutation.coverSetNoCover(
                recipeID: recipeID,
                clientMutationID: clientMutationID,
                confirmNoCover: true,
                createdAt: mutationCreatedAt
            )
        case .activate(let coverID, let variant, let clientMutationID):
            online = try RecipeCoverRequests.activate(
                recipeID: recipeID,
                coverID: coverID,
                clientMutationID: clientMutationID,
                variant: variant
            )
            offline = NativeQueuedMutation.coverSetActive(
                recipeID: recipeID,
                coverID: coverID,
                clientMutationID: clientMutationID,
                variant: variant.recipeCoverVariant,
                createdAt: mutationCreatedAt
            )
        case .regenerate(let coverID, let activateWhenReady, let clientMutationID):
            online = try RecipeCoverRequests.regenerate(
                recipeID: recipeID,
                clientMutationID: clientMutationID,
                coverID: coverID,
                activateWhenReady: activateWhenReady
            )
            offline = NativeQueuedMutation.coverRegenerate(
                recipeID: recipeID,
                coverID: coverID,
                activateWhenReady: activateWhenReady,
                clientMutationID: clientMutationID,
                createdAt: mutationCreatedAt
            )
        case .archive(let coverID, let replacementCoverID, let replacementVariant, let confirmNoCover, let deleteSafeObjects, let clientMutationID):
            online = try RecipeCoverRequests.archive(
                recipeID: recipeID,
                coverID: coverID,
                clientMutationID: clientMutationID,
                replacementCoverID: replacementCoverID,
                replacementVariant: replacementVariant,
                confirmNoCover: confirmNoCover,
                deleteSafeObjects: deleteSafeObjects,
                idempotency: .query
            )
            offline = NativeQueuedMutation.coverArchive(
                recipeID: recipeID,
                coverID: coverID,
                clientMutationID: clientMutationID,
                replacementCoverID: replacementCoverID,
                replacementVariant: replacementVariant?.recipeCoverVariant,
                confirmNoCover: confirmNoCover,
                deleteSafeObjects: deleteSafeObjects,
                createdAt: mutationCreatedAt
            )
        case .createFromSpoon(let spoonID, let activate, let generateEditorial, let clientMutationID):
            online = try RecipeCoverRequests.createFromSpoon(
                recipeID: recipeID,
                spoonID: spoonID,
                clientMutationID: clientMutationID,
                activate: activate,
                generateEditorial: generateEditorial
            )
            offline = NativeQueuedMutation.coverFromSpoon(
                recipeID: recipeID,
                spoonID: spoonID,
                clientMutationID: clientMutationID,
                activate: activate,
                generateEditorial: generateEditorial,
                createdAt: mutationCreatedAt
            )
        }

        switch connectivity {
        case .online:
            return RecipeCoverControlsMutationPlan(remoteRequestBuilder: online, queuedMutation: nil, offlineFallbackMutation: offline)
        case .offline:
            return RecipeCoverControlsMutationPlan(remoteRequestBuilder: nil, queuedMutation: offline, offlineFallbackMutation: nil)
        }
    }
}

public struct RecipeCoverControlsData: Equatable, Sendable {
    public let covers: [RecipeCoverCandidate]
    public let spoonImages: [RecipeCoverSpoonImage]

    public init(covers: [RecipeCoverCandidate], spoonImages: [RecipeCoverSpoonImage]) {
        self.covers = covers
        self.spoonImages = spoonImages
    }

    public static func snapshot(recipe: Recipe) -> RecipeCoverControlsData {
        let cover = recipe.coverImageURL.map { imageURL in
            RecipeCoverCandidate(
                id: "active-\(recipe.id)",
                recipeID: recipe.id,
                status: "ready",
                sourceType: recipe.coverSourceType?.rawValue ?? "chef-upload",
                imageURL: recipe.coverVariant == .stylized ? nil : imageURL,
                stylizedImageURL: recipe.coverVariant == .stylized ? imageURL : nil,
                displayURL: imageURL,
                activeVariant: recipe.coverVariant?.apiVariant,
                provenanceLabel: recipe.coverProvenanceLabel,
                archivedAt: nil,
                generationStatus: "none",
                failureReason: nil,
                isServerBacked: false,
                sourceImageURL: nil,
                createdAt: recipe.updatedAt
            )
        }
        return RecipeCoverControlsData(covers: cover.map { [$0] } ?? [], spoonImages: [])
    }

    public static func live(
        recipeID: String,
        configuration: APIClientConfiguration,
        transport: any SpoonjoyAPITransport = URLSessionAPITransport()
    ) async throws -> RecipeCoverControlsData {
        try await LiveRecipeCoverControlsRepository(
            transport: transport,
            configuration: configuration
        )
        .fetchCoverControls(recipeID: recipeID)
    }

    public func replacementOptions(for cover: RecipeCoverCandidate) -> [RecipeCoverReplacementOption] {
        covers
            .filter { candidate in
                candidate.id != cover.id && candidate.canActivate
            }
            .flatMap { candidate in
                candidate.variants.map { variant in
                    RecipeCoverReplacementOption(
                        coverID: candidate.id,
                        variant: variant.variant,
                        label: "\(candidate.createdAtLabel) - \(variant.variant.label)"
                    )
                }
            }
    }
}

public struct RecipeCoverListData: Decodable, Equatable, Sendable {
    public let covers: [RecipeCoverCandidate]
    public let spoonImages: [RecipeCoverSpoonImage]
}

public struct RecipeCoverCandidate: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let recipeID: String
    public let status: String
    public let sourceType: String
    public let imageURL: URL?
    public let stylizedImageURL: URL?
    public let displayURL: URL?
    public let activeVariant: RecipeCoverAPIVariant?
    public let provenanceLabel: String?
    public let archivedAt: String?
    public let generationStatus: String
    public let failureReason: String?
    public let isServerBacked: Bool
    public let sourceImageURL: URL?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeID = "recipeId"
        case status
        case sourceType
        case imageURL = "imageUrl"
        case stylizedImageURL = "stylizedImageUrl"
        case displayURL = "displayUrl"
        case activeVariant
        case provenanceLabel
        case archivedAt
        case generationStatus
        case failureReason
        case isServerBacked
        case sourceImageURL = "sourceImageUrl"
        case createdAt
    }

    public init(
        id: String,
        recipeID: String,
        status: String,
        sourceType: String,
        imageURL: URL?,
        stylizedImageURL: URL?,
        displayURL: URL?,
        activeVariant: RecipeCoverAPIVariant?,
        provenanceLabel: String?,
        archivedAt: String?,
        generationStatus: String,
        failureReason: String?,
        isServerBacked: Bool = true,
        sourceImageURL: URL?,
        createdAt: String
    ) {
        self.id = id
        self.recipeID = recipeID
        self.status = status
        self.sourceType = sourceType
        self.imageURL = imageURL
        self.stylizedImageURL = stylizedImageURL
        self.displayURL = displayURL
        self.activeVariant = activeVariant
        self.provenanceLabel = provenanceLabel
        self.archivedAt = archivedAt
        self.generationStatus = generationStatus
        self.failureReason = failureReason
        self.isServerBacked = isServerBacked
        self.sourceImageURL = sourceImageURL
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        recipeID = try container.decode(String.self, forKey: .recipeID)
        status = try container.decode(String.self, forKey: .status)
        sourceType = try container.decode(String.self, forKey: .sourceType)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        stylizedImageURL = try container.decodeIfPresent(URL.self, forKey: .stylizedImageURL)
        displayURL = try container.decodeIfPresent(URL.self, forKey: .displayURL)
        activeVariant = try container.decodeIfPresent(RecipeCoverAPIVariant.self, forKey: .activeVariant)
        provenanceLabel = try container.decodeIfPresent(String.self, forKey: .provenanceLabel)
        archivedAt = try container.decodeIfPresent(String.self, forKey: .archivedAt)
        generationStatus = try container.decode(String.self, forKey: .generationStatus)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        isServerBacked = try container.decodeIfPresent(Bool.self, forKey: .isServerBacked) ?? true
        sourceImageURL = try container.decodeIfPresent(URL.self, forKey: .sourceImageURL)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    public var thumbnailURL: URL? {
        displayURL ?? stylizedImageURL ?? imageURL
    }

    public var isActive: Bool {
        activeVariant != nil
    }

    public var canActivate: Bool {
        isServerBacked && (status == "ready" || status == "processing") && archivedAt == nil
    }

    public var canMutate: Bool {
        isServerBacked && (status == "ready" || status == "processing" || status == "failed") && archivedAt == nil
    }

    public var statusLabel: String {
        if status == "archived" || archivedAt != nil { return "Archived" }
        if status == "failed" { return "Failed" }
        if status == "processing" || generationStatus == "processing" { return "Processing" }
        if generationStatus == "failed" { return "Editorial failed" }
        return "Ready"
    }

    public var providerBlocker: RecipeCoverProviderBlockerDisplay? {
        RecipeCoverProviderBlockerDisplay.from(failureReason: failureReason)
    }

    public var createdAtLabel: String {
        Self.dateLabel(createdAt)
    }

    public var variants: [RecipeCoverCandidateVariant] {
        var result: [RecipeCoverCandidateVariant] = []
        if let imageURL {
            result.append(RecipeCoverCandidateVariant(
                id: "\(id)-image",
                variant: .image,
                imageURL: imageURL,
                provenanceLabel: Self.provenanceLabel(sourceType: sourceType, variant: .image),
                isActive: activeVariant == .image
            ))
        }
        if let stylizedImageURL {
            result.append(RecipeCoverCandidateVariant(
                id: "\(id)-stylized",
                variant: .stylized,
                imageURL: stylizedImageURL,
                provenanceLabel: Self.provenanceLabel(sourceType: sourceType, variant: .stylized),
                isActive: activeVariant == .stylized
            ))
        }
        return result
    }

    public static func dateLabel(_ value: String) -> String {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        guard let date = fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value) else {
            return "Saved cover"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    public static func provenanceLabel(sourceType: String, variant: RecipeCoverAPIVariant) -> String {
        if (sourceType == "chef-upload" || sourceType == "spoon") && variant == .stylized {
            return "Editorialized chef photo"
        }
        if sourceType == "chef-upload" || sourceType == "spoon" {
            return "Chef photo"
        }
        if sourceType == "import" {
            return "Imported photo"
        }
        if sourceType == "ai-placeholder" {
            return "AI generated"
        }
        return "Unknown source"
    }
}

public struct RecipeCoverProviderBlockerDisplay: Equatable, Sendable {
    public let message: String
    public let ownerActionRequired: Bool
    public let retryAfterSeconds: Int?

    public init(message: String, ownerActionRequired: Bool, retryAfterSeconds: Int?) {
        self.message = message
        self.ownerActionRequired = ownerActionRequired
        self.retryAfterSeconds = retryAfterSeconds
    }

    public var offlineIndicatorDisplay: OfflineIndicatorDisplay {
        .blocker(.providerSecret(resourceID: message))
    }

    public static func from(failureReason: String?) -> RecipeCoverProviderBlockerDisplay? {
        guard failureReason == "missing_image_provider_config" else { return nil }
        return RecipeCoverProviderBlockerDisplay(
            message: "Recipe cover generation needs an image provider secret before it can run.",
            ownerActionRequired: true,
            retryAfterSeconds: nil
        )
    }

    public static func from(error: Error) -> RecipeCoverProviderBlockerDisplay? {
        if let transportError = error as? APITransportError, let apiError = transportError.apiError {
            return from(apiError: apiError)
        }
        if let apiError = error as? APIError {
            return from(apiError: apiError)
        }
        return nil
    }

    public static func from(apiError: APIError) -> RecipeCoverProviderBlockerDisplay? {
        if let blocker = firstProviderSecretBlocker(in: apiError.details["blockers"]) {
            return RecipeCoverProviderBlockerDisplay(
                message: apiError.message,
                ownerActionRequired: blocker.ownerActionRequired,
                retryAfterSeconds: blocker.retryAfterSeconds
            )
        }
        if value(apiError.details["capability"]) == "ProviderSecret" || apiError.code == "provider_secret" {
            return RecipeCoverProviderBlockerDisplay(
                message: apiError.message,
                ownerActionRequired: boolValue(apiError.details["ownerAction"]) ?? true,
                retryAfterSeconds: intValue(apiError.details["retryAfterSeconds"])
            )
        }
        return nil
    }

    private static func firstProviderSecretBlocker(in value: JSONValue?) -> (ownerActionRequired: Bool, retryAfterSeconds: Int?)? {
        guard case .array(let blockers) = value else { return nil }
        for blocker in blockers {
            guard case .object(let fields) = blocker,
                  RecipeCoverProviderBlockerDisplay.value(fields["capability"]) == "ProviderSecret" else {
                continue
            }
            return (
                ownerActionRequired: boolValue(fields["ownerAction"]) ?? true,
                retryAfterSeconds: intValue(fields["retryAfterSeconds"])
            )
        }
        return nil
    }

    private static func value(_ value: JSONValue?) -> String? {
        guard case .string(let value) = value else { return nil }
        return value
    }

    private static func boolValue(_ value: JSONValue?) -> Bool? {
        guard case .bool(let value) = value else { return nil }
        return value
    }

    private static func intValue(_ value: JSONValue?) -> Int? {
        guard case .number(let value) = value, value.rounded() == value else { return nil }
        return Int(value)
    }
}

public struct RecipeCoverCandidateVariant: Equatable, Identifiable, Sendable {
    public let id: String
    public let variant: RecipeCoverAPIVariant
    public let imageURL: URL
    public let provenanceLabel: String
    public let isActive: Bool

    public init(
        id: String,
        variant: RecipeCoverAPIVariant,
        imageURL: URL,
        provenanceLabel: String,
        isActive: Bool
    ) {
        self.id = id
        self.variant = variant
        self.imageURL = imageURL
        self.provenanceLabel = provenanceLabel
        self.isActive = isActive
    }
}

public struct RecipeCoverReplacementOption: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(coverID)-\(variant.rawValue)"
    }

    public let coverID: String
    public let variant: RecipeCoverAPIVariant
    public let label: String

    public init(coverID: String, variant: RecipeCoverAPIVariant, label: String) {
        self.coverID = coverID
        self.variant = variant
        self.label = label
    }
}

public struct RecipeCoverSpoonImage: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let photoURL: URL
    public let cookedAt: String
    public let chef: ChefSummary

    enum CodingKeys: String, CodingKey {
        case id
        case photoURL = "photoUrl"
        case cookedAt
        case chef
    }

    public init(id: String, photoURL: URL, cookedAt: String, chef: ChefSummary) {
        self.id = id
        self.photoURL = photoURL
        self.cookedAt = cookedAt
        self.chef = chef
    }

    public var cookedAtLabel: String {
        RecipeCoverCandidate.dateLabel(cookedAt)
    }
}

extension RecipeCoverAPIVariant {
    var recipeCoverVariant: RecipeCoverVariant {
        switch self {
        case .image:
            .image
        case .stylized:
            .stylized
        }
    }

    public var label: String {
        switch self {
        case .image:
            "Original"
        case .stylized:
            "Editorial"
        }
    }
}

private extension RecipeCoverVariant {
    var apiVariant: RecipeCoverAPIVariant? {
        switch self {
        case .image:
            .image
        case .stylized:
            .stylized
        case .illustration:
            nil
        }
    }
}
