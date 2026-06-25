import Foundation

public enum NativeCacheEnvironment: String, Codable, Equatable, Hashable, Sendable {
    case production
    case local
}

public enum NativeCacheDomain: Codable, Equatable, Hashable, Sendable {
    case accountBootstrap
    case settings
    case recipeCatalog
    case recipeDetail(id: String)
    case cookbookList
    case cookbookDetail(id: String)
    case shoppingList
    case cookProgress(recipeID: String)
    case captureDraft(id: String)
    case profile(id: String)
    case notificationPreferences
    case tokenMetadata
    case connectionStatus
    case apnsStatus
    case spoonList(recipeID: String)
    case cookModeBackingData(recipeID: String)
    case searchResults(query: String)
    case stagedMedia(id: String)

    public var stableRecordID: String {
        switch self {
        case .accountBootstrap:
            "account-bootstrap"
        case .settings:
            "settings"
        case .recipeCatalog:
            "recipe-catalog"
        case .recipeDetail(let id):
            "recipe-detail:\(id)"
        case .cookbookList:
            "cookbook-list"
        case .cookbookDetail(let id):
            "cookbook-detail:\(id)"
        case .shoppingList:
            "shopping-list"
        case .cookProgress(let recipeID):
            "cook-progress:\(recipeID)"
        case .captureDraft(let id):
            "capture-draft:\(id)"
        case .profile(let id):
            "profile:\(id)"
        case .notificationPreferences:
            "notification-preferences"
        case .tokenMetadata:
            "token-metadata"
        case .connectionStatus:
            "connection-status"
        case .apnsStatus:
            "apns-status"
        case .spoonList(let recipeID):
            "spoon-list:\(recipeID)"
        case .cookModeBackingData(let recipeID):
            "cook-mode-backing-data:\(recipeID)"
        case .searchResults(let query):
            "search-results:\(query)"
        case .stagedMedia(let id):
            "staged-media:\(id)"
        }
    }
}

public enum NativeCacheServerRevision: Codable, Equatable, Hashable, Sendable {
    case etag(String)
    case cursor(String)
    case updatedAt(String)
    case localRevision(String)
}

public struct NativeTokenMetadata: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let scopes: [String]

    public init(id: String, name: String, scopes: [String]) {
        self.id = id
        self.name = name
        self.scopes = scopes
    }
}

public enum NativeConnectionStatusValue: String, Codable, Equatable, Hashable, Sendable {
    case connected
    case disconnected
}

public struct NativeConnectionStatus: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let provider: String
    public let status: NativeConnectionStatusValue

    public init(id: String, provider: String, status: NativeConnectionStatusValue) {
        self.id = id
        self.provider = provider
        self.status = status
    }
}

public enum NativeAPNSRegistrationState: String, Codable, Equatable, Hashable, Sendable {
    case registered
    case unregistered
}

public enum NativeCaptureDraftCacheSource: Codable, Equatable, Hashable, Sendable {
    case shareSheetURL(String)
    case text(String)
    case imageAsset(String)
}

public enum NativeCachePayload: Codable, Equatable, Hashable, Sendable {
    case empty
    case recipeCatalog(recipeIDs: [String])
    case recipeDetail(id: String, title: String)
    case cookbookList(cookbookIDs: [String])
    case cookbookDetail(id: String, title: String)
    case shoppingList(itemIDs: [String], syncCursor: String?)
    case cookProgress(recipeID: String, completedStepIDs: [String], currentStepID: String?)
    case captureDraft(id: String, source: NativeCaptureDraftCacheSource)
    case profile(id: String, username: String)
    case notificationPreferences(marketingEnabled: Bool, cookingRemindersEnabled: Bool)
    case tokenMetadata(credentials: [NativeTokenMetadata])
    case connectionStatus(connections: [NativeConnectionStatus])
    case apnsStatus(deviceID: String, registrationState: NativeAPNSRegistrationState)
}

public struct NativeCacheRecordMetadata: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let schemaVersion: Int
    public let domain: NativeCacheDomain
    public let fetchedAt: Date
    public let lastValidatedAt: Date
    public let sourceEndpoint: String
    public let serverRevision: NativeCacheServerRevision?

    public init(
        accountID: String,
        environment: NativeCacheEnvironment,
        schemaVersion: Int,
        domain: NativeCacheDomain,
        fetchedAt: Date,
        lastValidatedAt: Date,
        sourceEndpoint: String,
        serverRevision: NativeCacheServerRevision?
    ) {
        self.accountID = accountID
        self.environment = environment
        self.schemaVersion = schemaVersion
        self.domain = domain
        self.fetchedAt = fetchedAt
        self.lastValidatedAt = lastValidatedAt
        self.sourceEndpoint = sourceEndpoint
        self.serverRevision = serverRevision
    }
}

public struct NativeCacheRecord: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let metadata: NativeCacheRecordMetadata
    public let payload: NativeCachePayload

    public init(id: String, metadata: NativeCacheRecordMetadata, payload: NativeCachePayload) throws {
        self.id = id
        self.metadata = metadata
        self.payload = payload
    }
}

public enum NativeCacheRecoveryError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case corruptCache(String)
}

public enum NativeCacheSecretMaterial: Equatable, Sendable {
    case bearerToken(String)
    case refreshToken(String)
    case oneTimeTokenValue(String)
    case providerSecret(String)
    case passkey(String)
    case rawMediaPath(String)
    case signedURL(String)
}

public struct NativeDurableCacheSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public static let recordLookupSignature = "record(for:"
    public static let offlineProductContractEndpoints = [
        "/api/v1/recipes",
        "/api/v1/cookbooks",
        "/api/v1/shopping-list",
        "/api/v1/me/notification-preferences",
        "/api/v1/tokens",
        "/api/v1/me/connections",
        "/api/v1/me/apns-devices",
        "local://cook-progress",
        "local://capture-drafts"
    ]

    public let schemaVersion: Int
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let createdAt: Date
    public let records: [NativeCacheRecord]
    public let dismissedIndicators: [NativeIndicatorDismissal]
    public let pendingMutationQueue: MutationQueue
    public let secretMaterial: NativeCacheSecretMaterial?

    public init(
        schemaVersion: Int,
        accountID: String,
        environment: NativeCacheEnvironment,
        createdAt: Date,
        records: [NativeCacheRecord],
        dismissedIndicators: [NativeIndicatorDismissal],
        pendingMutationQueue: MutationQueue = MutationQueue(),
        secretMaterial: NativeCacheSecretMaterial? = nil
    ) throws {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.environment = environment
        self.createdAt = createdAt
        self.records = records
        self.dismissedIndicators = dismissedIndicators
        self.pendingMutationQueue = pendingMutationQueue
        self.secretMaterial = secretMaterial
    }

    public func validatedForRestore() throws -> NativeDurableCacheSnapshot {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw NativeCacheRecoveryError.unsupportedSchemaVersion(schemaVersion)
        }

        return self
    }

    public func record(for domain: NativeCacheDomain) -> NativeCacheRecord? {
        records.first { $0.metadata.domain == domain }
    }

    public func copy(
        schemaVersion: Int? = nil,
        records: [NativeCacheRecord]? = nil,
        dismissedIndicators: [NativeIndicatorDismissal]? = nil,
        pendingMutationQueue: MutationQueue? = nil,
        insertingSecret secretMaterial: NativeCacheSecretMaterial? = nil
    ) throws -> NativeDurableCacheSnapshot {
        try NativeDurableCacheSnapshot(
            schemaVersion: schemaVersion ?? self.schemaVersion,
            accountID: accountID,
            environment: environment,
            createdAt: createdAt,
            records: records ?? self.records,
            dismissedIndicators: dismissedIndicators ?? self.dismissedIndicators,
            pendingMutationQueue: pendingMutationQueue ?? self.pendingMutationQueue,
            secretMaterial: secretMaterial ?? self.secretMaterial
        )
    }

    public static func migratingSchemaVersionOne(
        _ snapshot: NativeAppSnapshot,
        accountID: String,
        environment: NativeCacheEnvironment,
        migratedAt: Date
    ) throws -> NativeDurableCacheSnapshot {
        var records: [NativeCacheRecord] = []
        if let shoppingList = snapshot.shoppingList {
            records.append(try localRecord(
                accountID: accountID,
                environment: environment,
                domain: .shoppingList,
                sourceEndpoint: "/api/v1/shopping-list",
                payload: .shoppingList(itemIDs: shoppingList.items.map(\.id), syncCursor: shoppingList.nextCursor),
                migratedAt: migratedAt
            ))
        }

        for progress in snapshot.cookProgressByRecipeID.values.sorted(by: { $0.recipeID < $1.recipeID }) {
            records.append(try localRecord(
                accountID: accountID,
                environment: environment,
                domain: .cookProgress(recipeID: progress.recipeID),
                sourceEndpoint: "local://cook-progress/\(progress.recipeID)",
                payload: .cookProgress(
                    recipeID: progress.recipeID,
                    completedStepIDs: progress.completedStepIDs,
                    currentStepID: progress.currentStepID
                ),
                migratedAt: migratedAt
            ))
        }

        if let draft = snapshot.captureDraft {
            records.append(try localRecord(
                accountID: accountID,
                environment: environment,
                domain: .captureDraft(id: draft.id),
                sourceEndpoint: "local://capture-drafts/\(draft.id)",
                payload: .captureDraft(id: draft.id, source: .text(draft.rawText)),
                migratedAt: migratedAt
            ))
        }

        return try NativeDurableCacheSnapshot(
            schemaVersion: currentSchemaVersion,
            accountID: accountID,
            environment: environment,
            createdAt: migratedAt,
            records: records,
            dismissedIndicators: [],
            pendingMutationQueue: snapshot.pendingMutations
        )
    }

    private static func localRecord(
        accountID: String,
        environment: NativeCacheEnvironment,
        domain: NativeCacheDomain,
        sourceEndpoint: String,
        payload: NativeCachePayload,
        migratedAt: Date
    ) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: accountID,
                environment: environment,
                schemaVersion: currentSchemaVersion,
                domain: domain,
                fetchedAt: migratedAt,
                lastValidatedAt: migratedAt,
                sourceEndpoint: sourceEndpoint,
                serverRevision: .localRevision("\(domain.stableRecordID)-migration")
            ),
            payload: payload
        )
    }
}

extension NativeDurableCacheSnapshot {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case accountID
        case environment
        case createdAt
        case records
        case dismissedIndicators
        case pendingMutationQueue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.accountID = try container.decode(String.self, forKey: .accountID)
        self.environment = try container.decode(NativeCacheEnvironment.self, forKey: .environment)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.records = try container.decode([NativeCacheRecord].self, forKey: .records)
        self.dismissedIndicators = try container.decode([NativeIndicatorDismissal].self, forKey: .dismissedIndicators)
        self.pendingMutationQueue = try container.decodeIfPresent(MutationQueue.self, forKey: .pendingMutationQueue) ?? MutationQueue()
        self.secretMaterial = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(environment, forKey: .environment)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(records, forKey: .records)
        try container.encode(dismissedIndicators, forKey: .dismissedIndicators)
        try container.encode(pendingMutationQueue, forKey: .pendingMutationQueue)
    }
}
