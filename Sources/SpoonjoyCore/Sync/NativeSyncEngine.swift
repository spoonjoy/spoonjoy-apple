import Foundation

public enum NativeSyncBootstrapRequest {
    public static func defaultRequest(cursor: PaginationCursor?) -> APIRequestBuilder {
        PrivateSyncRequests.sync(cursor: cursor, limit: 20)
    }
}

public struct NativeSyncData: Decodable, Equatable, Sendable {
    public let freshness: NativeSyncFreshness
    public let entries: [NativeSyncEntry]
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
}

public struct NativeSyncFreshness: Decodable, Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let schemaVersion: Int
    public let sourceEndpoint: String
    public let generatedAt: String
    public let lastValidatedAt: String

    private enum CodingKeys: String, CodingKey {
        case accountID = "accountId"
        case environment
        case schemaVersion
        case sourceEndpoint
        case generatedAt
        case lastValidatedAt
    }
}

public enum NativeSyncEntryKind: String, Codable, Equatable, Hashable, Sendable {
    case profile
    case notificationPreferences
    case recipe
    case cookbook
    case spoon
    case shoppingItem
}

public enum NativeSyncEntryAction: String, Codable, Equatable, Sendable {
    case upsert
    case delete
}

public enum NativeSyncResourceType: String, Codable, Equatable, Hashable, Sendable {
    case profile
    case notificationPreferences
    case recipe
    case cookbook
    case spoon
    case shoppingItem
}

public struct NativeSyncEntry: Decodable, Equatable, Sendable {
    public let action: NativeSyncEntryAction
    public let kind: NativeSyncEntryKind
    public let resourceID: String
    public let updatedAt: String
    public let payload: JSONValue?
    public let tombstone: NativeSyncTombstone?

    private enum CodingKeys: String, CodingKey {
        case action
        case kind
        case resourceID = "resourceId"
        case updatedAt
        case payload
        case tombstone
    }
}

public struct NativeSyncTombstone: Codable, Equatable, Sendable {
    public let resourceType: NativeSyncResourceType
    public let resourceID: String
    public let parentResourceID: String?
    public let title: String?
    public let deletedAt: String
    public let updatedAt: String

    public var token: String { resourceID }

    public init(
        resourceType: NativeSyncResourceType,
        resourceID: String,
        parentResourceID: String?,
        title: String?,
        deletedAt: String,
        updatedAt: String
    ) {
        self.resourceType = resourceType
        self.resourceID = resourceID
        self.parentResourceID = parentResourceID
        self.title = title
        self.deletedAt = deletedAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case resourceType
        case resourceID = "resourceId"
        case parentResourceID = "parentResourceId"
        case title
        case deletedAt
        case updatedAt
    }
}

public enum NativeSyncCheckpointError: Error, Equatable, Sendable {
    case emptyGlobalCursor
    case emptyShoppingCursor
    case emptyUpdatedAt
}

public struct NativeSyncCheckpoint: Codable, Equatable, Sendable {
    public let globalCursor: PaginationCursor?
    public let shoppingCursor: ShoppingSyncCursor?
    public let updatedAt: String

    public init(
        globalCursor: PaginationCursor?,
        shoppingCursor: ShoppingSyncCursor?,
        updatedAt: String
    ) throws {
        let updatedAt = updatedAt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updatedAt.isEmpty else {
            throw NativeSyncCheckpointError.emptyUpdatedAt
        }

        self.globalCursor = globalCursor
        self.shoppingCursor = shoppingCursor
        self.updatedAt = updatedAt
    }

    public init(globalCursorRaw: String?, shoppingCursorRaw: String?, updatedAt: String) throws {
        let globalCursor = try Self.cursor(rawValue: globalCursorRaw, emptyError: .emptyGlobalCursor, make: PaginationCursor.init(rawValue:))
        let shoppingCursor = try Self.cursor(rawValue: shoppingCursorRaw, emptyError: .emptyShoppingCursor, make: ShoppingSyncCursor.init(rawValue:))
        try self.init(globalCursor: globalCursor, shoppingCursor: shoppingCursor, updatedAt: updatedAt)
    }

    public func updating(
        globalCursor: PaginationCursor?,
        shoppingCursor: ShoppingSyncCursor?,
        at updatedAt: String
    ) throws -> NativeSyncCheckpoint {
        try NativeSyncCheckpoint(globalCursor: globalCursor, shoppingCursor: shoppingCursor, updatedAt: updatedAt)
    }

    private static func cursor<Cursor>(
        rawValue: String?,
        emptyError: NativeSyncCheckpointError,
        make: (String) -> Cursor?
    ) throws -> Cursor? {
        guard let rawValue else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let cursor = make(trimmed) else {
            throw emptyError
        }
        return cursor
    }
}

public enum NativeSyncStoreError: Error, Equatable, Sendable {
    case missingCheckpoint
}

public struct NativeSyncCachedRecord: Codable, Equatable, Sendable {
    public let kind: NativeSyncEntryKind
    public let resourceID: String
    public let payload: JSONValue
    public let serverRevision: NativeServerRevision?

    public init(kind: NativeSyncEntryKind, resourceID: String, payload: JSONValue, serverRevision: NativeServerRevision?) {
        self.kind = kind
        self.resourceID = resourceID
        self.payload = payload
        self.serverRevision = serverRevision
    }

    public var cacheKey: String {
        "\(kind.rawValue):\(resourceID)"
    }
}

public struct NativeSyncApplyResult: Equatable, Sendable {
    public let upsertedCacheKeys: [String]
    public let removedCacheKeys: [String]
    public let tombstones: [NativeSyncTombstone]
}

public struct NativeSyncSnapshot: Codable, Equatable, Sendable {
    public let checkpoint: NativeSyncCheckpoint?
    public let queue: NativeMutationQueue
    public let cachedRecords: [NativeSyncCachedRecord]
    public let tombstones: [NativeSyncTombstone]

    public static let empty = NativeSyncSnapshot(
        checkpoint: nil,
        queue: NativeMutationQueue(),
        cachedRecords: [],
        tombstones: []
    )

    public init(
        checkpoint: NativeSyncCheckpoint?,
        queue: NativeMutationQueue,
        cachedRecords: [NativeSyncCachedRecord] = [],
        tombstones: [NativeSyncTombstone] = []
    ) {
        self.checkpoint = checkpoint
        self.queue = queue
        self.cachedRecords = cachedRecords
        self.tombstones = tombstones
    }
}

public struct NativeSyncTombstoneLog: Equatable, Sendable {
    public private(set) var entries: [NativeSyncTombstone]

    public init(_ entries: [NativeSyncTombstone] = []) {
        self.entries = entries
    }

    public mutating func append(_ tombstone: NativeSyncTombstone) {
        entries.append(tombstone)
    }

    public func map<T>(_ transform: (NativeSyncTombstone) -> T) throws -> [T] {
        entries.map(transform)
    }
}

public protocol NativeSyncStore: Actor {
    func loadQueue() throws -> NativeMutationQueue
    func saveQueue(_ queue: NativeMutationQueue) throws
    func loadCheckpoint() throws -> NativeSyncCheckpoint
    func saveCheckpoint(_ checkpoint: NativeSyncCheckpoint) throws
    func appendTombstone(_ tombstone: NativeSyncTombstone) throws
    func cachedRecord(kind: NativeSyncEntryKind, resourceID: String) throws -> NativeSyncCachedRecord?
    func apply(syncData: NativeSyncData, validatedAt: Date) throws -> NativeSyncApplyResult
}

public actor InMemoryNativeSyncStore: NativeSyncStore {
    private var checkpoint: NativeSyncCheckpoint?
    private var queue: NativeMutationQueue
    private var records: [String: NativeSyncCachedRecord]
    public private(set) var tombstones: NativeSyncTombstoneLog

    public init(
        checkpoint: NativeSyncCheckpoint?,
        queue: NativeMutationQueue,
        cachedRecords: [NativeSyncCachedRecord] = []
    ) {
        self.checkpoint = checkpoint
        self.queue = queue
        self.records = Dictionary(uniqueKeysWithValues: cachedRecords.map { ($0.cacheKey, $0) })
        self.tombstones = NativeSyncTombstoneLog()
    }

    public func loadQueue() throws -> NativeMutationQueue {
        queue
    }

    public func saveQueue(_ queue: NativeMutationQueue) {
        self.queue = queue
    }

    public func loadCheckpoint() throws -> NativeSyncCheckpoint {
        guard let checkpoint else {
            throw NativeSyncStoreError.missingCheckpoint
        }
        return checkpoint
    }

    public func saveCheckpoint(_ checkpoint: NativeSyncCheckpoint) {
        self.checkpoint = checkpoint
    }

    public func appendTombstone(_ tombstone: NativeSyncTombstone) {
        tombstones.append(tombstone)
    }

    public func cachedRecord(kind: NativeSyncEntryKind, resourceID: String) throws -> NativeSyncCachedRecord? {
        records["\(kind.rawValue):\(resourceID)"]
    }

    public func apply(syncData: NativeSyncData, validatedAt: Date) throws -> NativeSyncApplyResult {
        var upserted: [String] = []
        var removed: [String] = []
        var appliedTombstones: [NativeSyncTombstone] = []

        for entry in syncData.entries {
            let key = "\(entry.kind.rawValue):\(entry.resourceID)"
            switch entry.action {
            case .upsert:
                if let payload = entry.payload {
                    records[key] = NativeSyncCachedRecord(
                        kind: entry.kind,
                        resourceID: entry.resourceID,
                        payload: payload,
                        serverRevision: .updatedAt(entry.updatedAt)
                    )
                    upserted.append(key)
                }
            case .delete:
                records.removeValue(forKey: key)
                removed.append(key)
                if let tombstone = entry.tombstone {
                    tombstones.append(tombstone)
                    appliedTombstones.append(tombstone)
                }
            }
        }

        if let cursor = syncData.nextCursor {
            checkpoint = try NativeSyncCheckpoint(
                globalCursor: cursor,
                shoppingCursor: checkpoint?.shoppingCursor,
                updatedAt: Self.isoString(validatedAt)
            )
        }

        return NativeSyncApplyResult(
            upsertedCacheKeys: upserted,
            removedCacheKeys: removed,
            tombstones: appliedTombstones
        )
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

public actor FileBackedNativeSyncStore: NativeSyncStore {
    private let store: JSONFileStore<NativeSyncSnapshot>
    private let mediaResolver: (any NativeStagedMediaResolving)?
    private var checkpoint: NativeSyncCheckpoint?
    private var queue: NativeMutationQueue
    private var records: [String: NativeSyncCachedRecord]
    private var tombstones: [NativeSyncTombstone]

    public init(
        fileURL: URL,
        mediaResolver: (any NativeStagedMediaResolving)? = nil,
        fallback: NativeSyncSnapshot = .empty
    ) throws {
        self.store = JSONFileStore<NativeSyncSnapshot>(fileURL: fileURL)
        self.mediaResolver = mediaResolver

        let snapshot = try store.load()?.value ?? fallback
        let resolvedQueue: NativeMutationQueue
        if let mediaResolver {
            resolvedQueue = try snapshot.queue.resolvingStagedMedia(using: mediaResolver)
        } else {
            resolvedQueue = snapshot.queue
        }

        self.checkpoint = snapshot.checkpoint
        self.queue = resolvedQueue
        self.records = Dictionary(uniqueKeysWithValues: snapshot.cachedRecords.map { ($0.cacheKey, $0) })
        self.tombstones = snapshot.tombstones
    }

    public func loadQueue() throws -> NativeMutationQueue {
        queue
    }

    public func saveQueue(_ queue: NativeMutationQueue) throws {
        if let mediaResolver {
            self.queue = try queue.resolvingStagedMedia(using: mediaResolver)
        } else {
            self.queue = queue
        }
        try persist()
    }

    public func loadCheckpoint() throws -> NativeSyncCheckpoint {
        guard let checkpoint else {
            throw NativeSyncStoreError.missingCheckpoint
        }
        return checkpoint
    }

    public func saveCheckpoint(_ checkpoint: NativeSyncCheckpoint) throws {
        self.checkpoint = checkpoint
        try persist()
    }

    public func appendTombstone(_ tombstone: NativeSyncTombstone) throws {
        tombstones.append(tombstone)
        try persist()
    }

    public func cachedRecord(kind: NativeSyncEntryKind, resourceID: String) throws -> NativeSyncCachedRecord? {
        records["\(kind.rawValue):\(resourceID)"]
    }

    public func apply(syncData: NativeSyncData, validatedAt: Date) throws -> NativeSyncApplyResult {
        var upserted: [String] = []
        var removed: [String] = []
        var appliedTombstones: [NativeSyncTombstone] = []

        for entry in syncData.entries {
            let key = "\(entry.kind.rawValue):\(entry.resourceID)"
            switch entry.action {
            case .upsert:
                if let payload = entry.payload {
                    records[key] = NativeSyncCachedRecord(
                        kind: entry.kind,
                        resourceID: entry.resourceID,
                        payload: payload,
                        serverRevision: .updatedAt(entry.updatedAt)
                    )
                    upserted.append(key)
                }
            case .delete:
                records.removeValue(forKey: key)
                removed.append(key)
                if let tombstone = entry.tombstone {
                    tombstones.append(tombstone)
                    appliedTombstones.append(tombstone)
                }
            }
        }

        if let cursor = syncData.nextCursor {
            checkpoint = try NativeSyncCheckpoint(
                globalCursor: cursor,
                shoppingCursor: checkpoint?.shoppingCursor,
                updatedAt: NativeSyncClockFormatting.isoString(validatedAt)
            )
        }

        try persist()
        return NativeSyncApplyResult(
            upsertedCacheKeys: upserted,
            removedCacheKeys: removed,
            tombstones: appliedTombstones
        )
    }

    public func loadSnapshot() -> NativeSyncSnapshot {
        snapshot()
    }

    private func persist() throws {
        try store.save(snapshot())
    }

    private func snapshot() -> NativeSyncSnapshot {
        NativeSyncSnapshot(
            checkpoint: checkpoint,
            queue: queue,
            cachedRecords: records.values.sorted { $0.cacheKey < $1.cacheKey },
            tombstones: tombstones
        )
    }
}

public enum NativeReplayTarget: String, Codable, Equatable, Sendable {
    case remote
    case localCache
}

public struct NativeStagedMediaUpload: Codable, Equatable, Sendable {
    public let localStageID: String
    public let fileName: String
    public let contentType: String
    public let data: Data

    public init(localStageID: String, fileName: String, contentType: String, data: Data) {
        self.localStageID = localStageID
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
    }

    public static func == (lhs: NativeStagedMediaUpload, rhs: NativeStagedMediaUpload) -> Bool {
        lhs.localStageID == rhs.localStageID &&
            lhs.fileName == rhs.fileName &&
            lhs.contentType == rhs.contentType
    }

    private enum CodingKeys: String, CodingKey {
        case localStageID = "localStageId"
        case fileName
        case contentType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localStageID = try container.decode(String.self, forKey: .localStageID)
        fileName = try container.decode(String.self, forKey: .fileName)
        contentType = try container.decode(String.self, forKey: .contentType)
        data = Data()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localStageID, forKey: .localStageID)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(contentType, forKey: .contentType)
    }

    public func replacingData(_ data: Data) -> NativeStagedMediaUpload {
        NativeStagedMediaUpload(
            localStageID: localStageID,
            fileName: fileName,
            contentType: contentType,
            data: data
        )
    }
}

public enum NativeStagedMediaDirectoryError: Error, Equatable, Sendable {
    case missingStage(String)
    case unreadableStage(String)
}

public protocol NativeStagedMediaResolving: Sendable {
    func data(for upload: NativeStagedMediaUpload) throws -> Data
}

public struct NativeStagedMediaDirectory: NativeStagedMediaResolving {
    private let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func save(_ upload: NativeStagedMediaUpload) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try upload.data.write(to: fileURL(for: upload.localStageID), options: .atomic)
    }

    public func data(for upload: NativeStagedMediaUpload) throws -> Data {
        let url = fileURL(for: upload.localStageID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NativeStagedMediaDirectoryError.missingStage(upload.localStageID)
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw NativeStagedMediaDirectoryError.unreadableStage(upload.localStageID)
        }
    }

    private func fileURL(for localStageID: String) -> URL {
        directoryURL.appendingPathComponent(Self.hex(localStageID), isDirectory: false)
    }

    private static func hex(_ value: String) -> String {
        value.utf8.map { String(format: "%02x", $0) }.joined()
    }
}

public enum NativeMutationSource: Codable, Equatable, Sendable {
    case url(URL)
    case text(String)

    public func jsonValue() -> JSONValue {
        switch self {
        case .url(let url):
            .object(["type": .string("url"), "url": .string(url.absoluteString)])
        case .text(let text):
            .object(["type": .string("text"), "text": .string(text)])
        }
    }
}

public enum NativeQueuedMutationRequestError: Error, Equatable, Sendable {
    case localOnlyMutation
    case missingField(String)
    case missingMedia(String)
}

public enum NativeQueuedMutationKind: String, Codable, CaseIterable, Equatable, Sendable {
    case recipeCreate = "recipe.create"
    case recipeUpdate = "recipe.update"
    case recipeDelete = "recipe.delete"
    case recipeFork = "recipe.fork"
    case recipeStepCreate = "recipe.step.create"
    case recipeStepUpdate = "recipe.step.update"
    case recipeStepDelete = "recipe.step.delete"
    case recipeStepReorder = "recipe.step.reorder"
    case recipeIngredientAdd = "recipe.ingredient.add"
    case recipeIngredientDelete = "recipe.ingredient.delete"
    case recipeOutputUsesReplace = "recipe.outputUses.replace"
    case cookbookCreate = "cookbook.create"
    case cookbookUpdate = "cookbook.update"
    case cookbookDelete = "cookbook.delete"
    case cookbookAddRecipe = "cookbook.addRecipe"
    case cookbookRemoveRecipe = "cookbook.removeRecipe"
    case shoppingAddItem = "shopping.addItem"
    case shoppingCheckItem = "shopping.checkItem"
    case shoppingDeleteItem = "shopping.deleteItem"
    case shoppingAddFromRecipe = "shopping.addFromRecipe"
    case shoppingClearCompleted = "shopping.clearCompleted"
    case shoppingClearAll = "shopping.clearAll"
    case spoonCreate = "spoon.create"
    case spoonCreatePhoto = "spoon.createPhoto"
    case spoonUpdate = "spoon.update"
    case spoonDelete = "spoon.delete"
    case coverUpload = "cover.upload"
    case coverSetActive = "cover.setActive"
    case coverArchive = "cover.archive"
    case coverRegenerate = "cover.regenerate"
    case coverFromSpoon = "cover.fromSpoon"
    case profileDisplayUpdate = "profile.display.update"
    case profilePhotoUpload = "profile.photo.upload"
    case profilePhotoRemove = "profile.photo.remove"
    case notificationPreferenceUpdate = "notification.preference.update"
    case apnsDeviceRegister = "apns.device.register"
    case apnsDeviceRevoke = "apns.device.revoke"
    case captureDraftCreate = "capture.draft.create"
    case captureDraftEdit = "capture.draft.edit"
    case captureDraftDiscard = "capture.draft.discard"
    case recipeImportSubmit = "recipe.import.submit"

    public var type: String { rawValue }

    public static let allOfflineProductKinds: [NativeQueuedMutationKind] = [
        .recipeCreate,
        .recipeUpdate,
        .recipeDelete,
        .recipeFork,
        .recipeStepCreate,
        .recipeStepUpdate,
        .recipeStepDelete,
        .recipeStepReorder,
        .recipeIngredientAdd,
        .recipeIngredientDelete,
        .recipeOutputUsesReplace,
        .cookbookCreate,
        .cookbookUpdate,
        .cookbookDelete,
        .cookbookAddRecipe,
        .cookbookRemoveRecipe,
        .shoppingAddItem,
        .shoppingCheckItem,
        .shoppingDeleteItem,
        .shoppingAddFromRecipe,
        .shoppingClearCompleted,
        .shoppingClearAll,
        .spoonCreate,
        .spoonCreatePhoto,
        .spoonUpdate,
        .spoonDelete,
        .coverUpload,
        .coverSetActive,
        .coverArchive,
        .coverRegenerate,
        .coverFromSpoon,
        .profileDisplayUpdate,
        .profilePhotoUpload,
        .profilePhotoRemove,
        .notificationPreferenceUpdate,
        .apnsDeviceRegister,
        .apnsDeviceRevoke,
        .captureDraftCreate,
        .captureDraftEdit,
        .captureDraftDiscard,
        .recipeImportSubmit
    ]
}

public struct NativeQueuedMutation: Codable, Equatable, Sendable {
    public let id: String
    public let clientMutationID: String
    public let createdAt: String
    public let payloadSchemaVersion: Int
    public private(set) var retryCount: Int
    public private(set) var nextRetryAt: String?
    public private(set) var lastError: String?
    public let queueableKind: NativeQueuedMutationKind
    private let values: [String: JSONValue]
    private let media: [String: NativeStagedMediaUpload]

    public var idempotencyKey: String { clientMutationID }

    public var replayTarget: NativeReplayTarget {
        switch queueableKind {
        case .captureDraftCreate, .captureDraftEdit, .captureDraftDiscard:
            .localCache
        default:
            .remote
        }
    }

    public var dependencyKey: String {
        switch queueableKind {
        case .recipeCreate:
            "recipe:new:\(clientMutationID)"
        case .recipeUpdate, .recipeDelete, .recipeFork, .recipeStepCreate, .recipeStepUpdate, .recipeStepDelete, .recipeStepReorder, .recipeIngredientAdd, .recipeIngredientDelete, .recipeOutputUsesReplace, .spoonCreate, .spoonCreatePhoto, .spoonUpdate, .spoonDelete, .coverUpload, .coverSetActive, .coverArchive, .coverRegenerate, .coverFromSpoon:
            "recipe:\(stringValue("recipeId") ?? "")"
        case .cookbookCreate:
            "cookbook:new:\(clientMutationID)"
        case .cookbookUpdate, .cookbookDelete, .cookbookAddRecipe, .cookbookRemoveRecipe:
            "cookbook:\(stringValue("cookbookId") ?? "")"
        case .shoppingAddItem, .shoppingCheckItem, .shoppingDeleteItem, .shoppingAddFromRecipe, .shoppingClearCompleted, .shoppingClearAll:
            "shopping-list"
        case .profileDisplayUpdate, .profilePhotoUpload, .profilePhotoRemove:
            "profile:me"
        case .notificationPreferenceUpdate:
            "notification-preferences"
        case .apnsDeviceRegister, .apnsDeviceRevoke:
            "apns:\(stringValue("deviceId") ?? stringValue("token") ?? clientMutationID)"
        case .captureDraftCreate, .captureDraftEdit, .captureDraftDiscard:
            "capture:\(stringValue("draftId") ?? clientMutationID)"
        case .recipeImportSubmit:
            "import:\(clientMutationID)"
        }
    }

    private init(
        clientMutationID: String,
        createdAt: String,
        queueableKind: NativeQueuedMutationKind,
        values: [String: JSONValue] = [:],
        media: [String: NativeStagedMediaUpload] = [:]
    ) {
        self.id = "native:\(clientMutationID)"
        self.clientMutationID = clientMutationID
        self.createdAt = createdAt
        self.payloadSchemaVersion = 1
        self.retryCount = 0
        self.nextRetryAt = nil
        self.lastError = nil
        self.queueableKind = queueableKind
        self.values = values
        self.media = media
    }

    private init(
        id: String,
        clientMutationID: String,
        createdAt: String,
        payloadSchemaVersion: Int,
        retryCount: Int,
        nextRetryAt: String?,
        lastError: String?,
        queueableKind: NativeQueuedMutationKind,
        values: [String: JSONValue],
        media: [String: NativeStagedMediaUpload]
    ) {
        self.id = id
        self.clientMutationID = clientMutationID
        self.createdAt = createdAt
        self.payloadSchemaVersion = payloadSchemaVersion
        self.retryCount = retryCount
        self.nextRetryAt = nextRetryAt
        self.lastError = lastError
        self.queueableKind = queueableKind
        self.values = values
        self.media = media
    }

    public func recordingRetry(message: String, nextRetryAt: String) -> NativeQueuedMutation {
        var copy = self
        copy.retryCount += 1
        copy.lastError = message
        copy.nextRetryAt = nextRetryAt
        return copy
    }

    public func recordingError(_ message: String) -> NativeQueuedMutation {
        var copy = self
        copy.lastError = message
        return copy
    }

    public func requestBuilder() throws -> APIRequestBuilder {
        switch queueableKind {
        case .recipeCreate:
            return try json(.post, ["api", "v1", "recipes"])
        case .recipeUpdate:
            return try json(.patch, ["api", "v1", "recipes", requiredString("recipeId")], excluding: ["recipeId"])
        case .recipeDelete:
            return try queryDeleteNoBody(["api", "v1", "recipes", requiredString("recipeId")])
        case .recipeFork:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "fork"], excluding: ["recipeId", "titleOverride"])
        case .recipeStepCreate:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "steps"], excluding: ["recipeId"])
        case .recipeStepUpdate:
            return try json(.patch, ["api", "v1", "recipes", requiredString("recipeId"), "steps", requiredString("stepId")], excluding: ["recipeId", "stepId"])
        case .recipeStepDelete:
            return try bodyDelete(["api", "v1", "recipes", requiredString("recipeId"), "steps", requiredString("stepId")], excluding: ["recipeId", "stepId"])
        case .recipeStepReorder:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "steps", "reorder"], excluding: ["recipeId"])
        case .recipeIngredientAdd:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "steps", requiredString("stepId"), "ingredients"], excluding: ["recipeId", "stepId"])
        case .recipeIngredientDelete:
            return try headerDelete(["api", "v1", "recipes", requiredString("recipeId"), "steps", requiredString("stepId"), "ingredients", requiredString("ingredientId")])
        case .recipeOutputUsesReplace:
            return try json(.put, ["api", "v1", "recipes", requiredString("recipeId"), "step-output-uses"], excluding: ["recipeId"])
        case .cookbookCreate:
            return try json(.post, ["api", "v1", "cookbooks"])
        case .cookbookUpdate:
            return try json(.patch, ["api", "v1", "cookbooks", requiredString("cookbookId")], excluding: ["cookbookId"])
        case .cookbookDelete:
            return try queryDeleteNoBody(["api", "v1", "cookbooks", requiredString("cookbookId")])
        case .cookbookAddRecipe:
            return try json(.post, ["api", "v1", "cookbooks", requiredString("cookbookId"), "recipes", requiredString("recipeId")], excluding: ["cookbookId", "recipeId"])
        case .cookbookRemoveRecipe:
            return try bodyDelete(["api", "v1", "cookbooks", requiredString("cookbookId"), "recipes", requiredString("recipeId")], excluding: ["cookbookId", "recipeId"])
        case .shoppingAddItem:
            return try json(.post, ["api", "v1", "shopping-list", "items"])
        case .shoppingCheckItem:
            return try json(.patch, ["api", "v1", "shopping-list", "items", requiredString("itemId")], excluding: ["itemId"])
        case .shoppingDeleteItem:
            return try headerDelete(["api", "v1", "shopping-list", "items", requiredString("itemId")])
        case .shoppingAddFromRecipe:
            return try json(.post, ["api", "v1", "shopping-list", "add-from-recipe"])
        case .shoppingClearCompleted:
            return try json(.post, ["api", "v1", "shopping-list", "clear-completed"])
        case .shoppingClearAll:
            return try json(.post, ["api", "v1", "shopping-list", "clear-all"])
        case .spoonCreate:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "spoons"], excluding: ["recipeId"])
        case .spoonCreatePhoto:
            return try multipart(.post, ["api", "v1", "recipes", requiredString("recipeId"), "spoons"], fileField: "photo", mediaKey: "photo")
        case .spoonUpdate:
            return try json(.patch, ["api", "v1", "recipes", requiredString("recipeId"), "spoons", requiredString("spoonId")], excluding: ["recipeId", "spoonId"])
        case .spoonDelete:
            return try headerDelete(["api", "v1", "recipes", requiredString("recipeId"), "spoons", requiredString("spoonId")])
        case .coverUpload:
            return try multipart(.post, ["api", "v1", "recipes", requiredString("recipeId"), "image"], fileField: "image", mediaKey: "image")
        case .coverSetActive:
            return try json(.patch, ["api", "v1", "recipes", requiredString("recipeId"), "covers", requiredString("coverId")], excluding: ["recipeId", "coverId"])
        case .coverArchive:
            return try queryDeleteWithBody(["api", "v1", "recipes", requiredString("recipeId"), "covers", requiredString("coverId")], excluding: ["recipeId", "coverId"])
        case .coverRegenerate:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "covers", "regenerate"], excluding: ["recipeId"])
        case .coverFromSpoon:
            return try json(.post, ["api", "v1", "recipes", requiredString("recipeId"), "covers", "from-spoon", requiredString("spoonId")], excluding: ["recipeId", "spoonId"])
        case .profileDisplayUpdate:
            return try json(.patch, ["api", "v1", "me"])
        case .profilePhotoUpload:
            return try multipart(.post, ["api", "v1", "me", "photo"], fileField: "photo", mediaKey: "photo")
        case .profilePhotoRemove:
            return headerDelete(["api", "v1", "me", "photo"])
        case .notificationPreferenceUpdate:
            return try json(.patch, ["api", "v1", "me", "notification-preferences"])
        case .apnsDeviceRegister:
            return try json(.post, ["api", "v1", "me", "apns-devices"])
        case .apnsDeviceRevoke:
            return try headerDelete(["api", "v1", "me", "apns-devices", requiredString("deviceId")])
        case .recipeImportSubmit:
            return try json(.post, ["api", "v1", "recipes", "import"])
        case .captureDraftCreate, .captureDraftEdit, .captureDraftDiscard:
            throw NativeQueuedMutationRequestError.localOnlyMutation
        }
    }

    private func json(_ method: APIRequestMethod, _ pathComponents: [String], excluding excludedKeys: Set<String> = []) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(method: method, pathComponents: pathComponents, body: requestBody(includeClientMutation: true, excluding: excludedKeys))
    }

    private func queryDeleteNoBody(_ pathComponents: [String]) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: pathComponents,
            clientMutationID: clientMutationID,
            idempotency: .query
        )
    }

    private func queryDeleteWithBody(_ pathComponents: [String], excluding excludedKeys: Set<String>) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: pathComponents,
            clientMutationID: clientMutationID,
            idempotency: .query,
            body: requestBody(includeClientMutation: false, excluding: excludedKeys)
        )
    }

    private func bodyDelete(_ pathComponents: [String], excluding excludedKeys: Set<String>) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: pathComponents,
            clientMutationID: clientMutationID,
            idempotency: .body,
            body: requestBody(includeClientMutation: false, excluding: excludedKeys)
        )
    }

    private func headerDelete(_ pathComponents: [String]) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .delete,
            pathComponents: pathComponents,
            queryItems: [],
            headers: ["X-Client-Mutation-Id": clientMutationID],
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private func multipart(
        _ method: APIRequestMethod,
        _ pathComponents: [String],
        fileField: String,
        mediaKey: String
    ) throws -> APIRequestBuilder {
        let media = try requiredMedia(mediaKey)
        var fields: [String: String] = ["clientMutationId": clientMutationID]
        for (key, value) in values where key != "recipeId" && key != "photo" && key != "image" {
            switch value {
            case .string(let string):
                fields[key] = string
            case .bool(let bool):
                fields[key] = String(bool)
            case .null, .number, .array, .object:
                break
            }
        }
        return try APIRequestSupport.privateMultipart(
            method: method,
            pathComponents: pathComponents,
            fileField: fileField,
            file: UploadFile(fileName: media.fileName, contentType: media.contentType, data: media.data),
            fields: fields
        )
    }

    private func requestBody(includeClientMutation: Bool, excluding excludedKeys: Set<String>) -> [String: Any] {
        var body: [String: Any] = [:]
        if includeClientMutation {
            body["clientMutationId"] = clientMutationID
        }
        for (key, value) in values where !excludedKeys.contains(key) {
            body[key] = APIRequestSupport.jsonObject(from: value)
        }
        return body
    }

    private func requiredString(_ key: String) throws -> String {
        guard let value = stringValue(key) else {
            throw NativeQueuedMutationRequestError.missingField(key)
        }
        return value
    }

    private func stringValue(_ key: String) -> String? {
        guard case .string(let value)? = values[key] else {
            return nil
        }
        return value
    }

    private func requiredMedia(_ key: String) throws -> NativeStagedMediaUpload {
        guard let value = media[key] else {
            throw NativeQueuedMutationRequestError.missingMedia(key)
        }
        return value
    }

}

public extension NativeQueuedMutation {
    static func recipeCreate(clientMutationID: String, title: String, description: String?, servings: String?, steps: [RecipeStepDraft], createdAt: String) throws -> NativeQueuedMutation {
        try validateCreateRecipeSteps(steps)
        return NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeCreate, values: [
            "title": .string(title),
            "description": stringOrNull(description),
            "servings": stringOrNull(servings),
            "steps": stepDrafts(steps)
        ])
    }

    static func recipeUpdate(recipeID: String, clientMutationID: String, title: String, description: String?, servings: String?, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeUpdate, values: [
            "recipeId": .string(recipeID),
            "title": .string(title),
            "description": stringOrNull(description),
            "servings": stringOrNull(servings)
        ])
    }

    static func recipeDelete(recipeID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeDelete, values: ["recipeId": .string(recipeID)])
    }

    static func recipeFork(recipeID: String, clientMutationID: String, titleOverride: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeFork, values: [
            "recipeId": .string(recipeID),
            "title": .string(titleOverride),
            "titleOverride": .string(titleOverride)
        ])
    }

    static func recipeStepCreate(recipeID: String, clientMutationID: String, stepNum: Int, stepTitle: String?, description: String, duration: Int?, ingredients: [RecipeIngredientDraft], outputStepNums: [Int], createdAt: String) throws -> NativeQueuedMutation {
        try validateIngredients(ingredients, fieldPrefix: "ingredients")
        return NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeStepCreate, values: [
            "recipeId": .string(recipeID),
            "stepNum": .number(Double(stepNum)),
            "stepTitle": stringOrNull(stepTitle),
            "description": .string(description),
            "duration": intOrNull(duration),
            "ingredients": ingredientDrafts(ingredients),
            "outputStepNums": .array(outputStepNums.map { .number(Double($0)) })
        ])
    }

    static func recipeStepUpdate(recipeID: String, stepID: String, clientMutationID: String, stepTitle: String?, description: String, duration: Int?, outputStepNums: [Int], createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeStepUpdate, values: [
            "recipeId": .string(recipeID),
            "stepId": .string(stepID),
            "stepTitle": stringOrNull(stepTitle),
            "description": .string(description),
            "duration": intOrNull(duration),
            "outputStepNums": .array(outputStepNums.map { .number(Double($0)) })
        ])
    }

    static func recipeStepDelete(recipeID: String, stepID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeStepDelete, values: ["recipeId": .string(recipeID), "stepId": .string(stepID)])
    }

    static func recipeStepReorder(recipeID: String, stepID: String, toStepNum: Int, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeStepReorder, values: ["recipeId": .string(recipeID), "stepId": .string(stepID), "toStepNum": .number(Double(toStepNum))])
    }

    static func recipeIngredientAdd(recipeID: String, stepID: String, clientMutationID: String, quantity: Double, unit: String?, name: String, createdAt: String) throws -> NativeQueuedMutation {
        guard let unit else {
            throw NativeQueuedMutationRequestError.missingField("ingredient.unit")
        }
        return NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeIngredientAdd, values: ["recipeId": .string(recipeID), "stepId": .string(stepID), "quantity": .number(quantity), "unit": .string(unit), "name": .string(name)])
    }

    static func recipeIngredientDelete(recipeID: String, stepID: String, ingredientID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeIngredientDelete, values: ["recipeId": .string(recipeID), "stepId": .string(stepID), "ingredientId": .string(ingredientID)])
    }

    static func recipeOutputUsesReplace(recipeID: String, inputStepID: String, outputStepNums: [Int], clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeOutputUsesReplace, values: ["recipeId": .string(recipeID), "inputStepId": .string(inputStepID), "outputStepNums": .array(outputStepNums.map { .number(Double($0)) })])
    }

    static func cookbookCreate(clientMutationID: String, title: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .cookbookCreate, values: ["title": .string(title)])
    }

    static func cookbookUpdate(cookbookID: String, title: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .cookbookUpdate, values: ["cookbookId": .string(cookbookID), "title": .string(title)])
    }

    static func cookbookDelete(cookbookID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .cookbookDelete, values: ["cookbookId": .string(cookbookID)])
    }

    static func cookbookAddRecipe(cookbookID: String, recipeID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .cookbookAddRecipe, values: ["cookbookId": .string(cookbookID), "recipeId": .string(recipeID)])
    }

    static func cookbookRemoveRecipe(cookbookID: String, recipeID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .cookbookRemoveRecipe, values: ["cookbookId": .string(cookbookID), "recipeId": .string(recipeID)])
    }

    static func shoppingAddItem(name: String, quantity: Double?, unit: String?, categoryKey: String?, iconKey: String?, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingAddItem, values: ["name": .string(name), "quantity": doubleOrNull(quantity), "unit": stringOrNull(unit), "categoryKey": stringOrNull(categoryKey), "iconKey": stringOrNull(iconKey)])
    }

    static func shoppingCheckItem(itemID: String, checked: Bool, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingCheckItem, values: ["itemId": .string(itemID), "checked": .bool(checked)])
    }

    static func shoppingDeleteItem(itemID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingDeleteItem, values: ["itemId": .string(itemID)])
    }

    static func shoppingAddFromRecipe(recipeID: String, scaleFactor: Double, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingAddFromRecipe, values: ["recipeId": .string(recipeID), "scaleFactor": .number(scaleFactor)])
    }

    static func shoppingClearCompleted(clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingClearCompleted)
    }

    static func shoppingClearAll(clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingClearAll)
    }

    static func spoonCreate(recipeID: String, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, photoURL: String, useAsRecipeCover: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonCreate, values: ["recipeId": .string(recipeID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "photoUrl": .string(photoURL), "useAsRecipeCover": .bool(useAsRecipeCover)])
    }

    static func spoonCreatePhoto(recipeID: String, photo: NativeStagedMediaUpload, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, useAsRecipeCover: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonCreatePhoto, values: ["recipeId": .string(recipeID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "useAsRecipeCover": .bool(useAsRecipeCover)], media: ["photo": photo])
    }

    static func spoonUpdate(recipeID: String, spoonID: String, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, photoURL: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonUpdate, values: ["recipeId": .string(recipeID), "spoonId": .string(spoonID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "photoUrl": .string(photoURL)])
    }

    static func spoonDelete(recipeID: String, spoonID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonDelete, values: ["recipeId": .string(recipeID), "spoonId": .string(spoonID)])
    }

    static func coverUpload(recipeID: String, image: NativeStagedMediaUpload, clientMutationID: String, activate: Bool, generateEditorial: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverUpload, values: ["recipeId": .string(recipeID), "activate": .bool(activate), "generateEditorial": .bool(generateEditorial)], media: ["image": image])
    }

    static func coverSetActive(recipeID: String, coverID: String, clientMutationID: String, variant: RecipeCoverVariant, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverSetActive, values: ["recipeId": .string(recipeID), "coverId": .string(coverID), "variant": .string(variant.rawValue)])
    }

    static func coverArchive(recipeID: String, coverID: String, clientMutationID: String, replacementCoverID: String?, replacementVariant: RecipeCoverVariant?, confirmNoCover: Bool, deleteSafeObjects: Bool, createdAt: String) -> NativeQueuedMutation {
        let replacementVariantValue: JSONValue
        if let replacementVariant {
            replacementVariantValue = .string(replacementVariant.rawValue)
        } else {
            replacementVariantValue = .null
        }

        return NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverArchive, values: [
            "recipeId": .string(recipeID),
            "coverId": .string(coverID),
            "replacementCoverId": stringOrNull(replacementCoverID),
            "replacementVariant": replacementVariantValue,
            "confirmNoCover": .bool(confirmNoCover),
            "deleteSafeObjects": .bool(deleteSafeObjects)
        ])
    }

    static func coverRegenerate(recipeID: String, coverID: String, activateWhenReady: Bool, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverRegenerate, values: ["recipeId": .string(recipeID), "coverId": .string(coverID), "activateWhenReady": .bool(activateWhenReady)])
    }

    static func coverFromSpoon(recipeID: String, spoonID: String, clientMutationID: String, activate: Bool, generateEditorial: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverFromSpoon, values: ["recipeId": .string(recipeID), "spoonId": .string(spoonID), "activate": .bool(activate), "generateEditorial": .bool(generateEditorial)])
    }

    static func profileDisplayUpdate(email: String, username: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .profileDisplayUpdate, values: ["email": .string(email), "username": .string(username)])
    }

    static func profilePhotoUpload(photo: NativeStagedMediaUpload, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .profilePhotoUpload, media: ["photo": photo])
    }

    static func profilePhotoRemove(clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .profilePhotoRemove)
    }

    static func notificationPreferenceUpdate(
        notifySpoonOnMyRecipe: Bool,
        notifyForkOfMyRecipe: Bool,
        notifyCookbookSaveOfMine: Bool,
        notifyFellowChefOriginCook: Bool,
        clientMutationID: String,
        createdAt: String
    ) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .notificationPreferenceUpdate, values: [
            "notifySpoonOnMyRecipe": .bool(notifySpoonOnMyRecipe),
            "notifyForkOfMyRecipe": .bool(notifyForkOfMyRecipe),
            "notifyCookbookSaveOfMine": .bool(notifyCookbookSaveOfMine),
            "notifyFellowChefOriginCook": .bool(notifyFellowChefOriginCook)
        ])
    }

    static func apnsDeviceRegister(deviceID: String, platform: NativeAPNSPlatform, environment: APNSEnvironment, token: String, deviceName: String?, appVersion: String?, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .apnsDeviceRegister, values: [
            "deviceId": .string(deviceID),
            "platform": .string(platform.rawValue),
            "environment": .string(environment.rawValue),
            "token": .string(token),
            "deviceName": stringOrNull(deviceName),
            "appVersion": stringOrNull(appVersion)
        ])
    }

    static func apnsDeviceRevoke(deviceID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .apnsDeviceRevoke, values: ["deviceId": .string(deviceID)])
    }

    static func captureDraftCreate(draftID: String, source: NativeMutationSource, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .captureDraftCreate, values: ["draftId": .string(draftID), "source": source.jsonValue()])
    }

    static func captureDraftEdit(draftID: String, source: NativeMutationSource, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .captureDraftEdit, values: ["draftId": .string(draftID), "source": source.jsonValue()])
    }

    static func captureDraftDiscard(draftID: String, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .captureDraftDiscard, values: ["draftId": .string(draftID)])
    }

    static func recipeImportSubmit(source: NativeMutationSource, clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .recipeImportSubmit, values: ["source": source.jsonValue()])
    }

    private static func stringOrNull(_ value: String?) -> JSONValue {
        value.map(JSONValue.string) ?? .null
    }

    private static func intOrNull(_ value: Int?) -> JSONValue {
        value.map { .number(Double($0)) } ?? .null
    }

    private static func doubleOrNull(_ value: Double?) -> JSONValue {
        if let value {
            return .number(value)
        }

        return .null
    }

    private static func stepDrafts(_ steps: [RecipeStepDraft]) -> JSONValue {
        .array(steps.map { step in
            .object([
                "stepTitle": stringOrNull(step.stepTitle),
                "description": .string(step.description),
                "duration": intOrNull(step.duration),
                "ingredients": ingredientDrafts(step.ingredients)
            ])
        })
    }

    private static func ingredientDrafts(_ ingredients: [RecipeIngredientDraft]) -> JSONValue {
        .array(ingredients.map { ingredient in
            var object: [String: JSONValue] = [
                "quantity": .number(ingredient.quantity),
                "name": .string(ingredient.name)
            ]
            if let unit = ingredient.unit {
                object["unit"] = .string(unit)
            }
            return .object(object)
        })
    }

    private static func validateCreateRecipeSteps(_ steps: [RecipeStepDraft]) throws {
        for (stepIndex, step) in steps.enumerated() {
            for (ingredientIndex, ingredient) in step.ingredients.enumerated() {
                if ingredient.unit == nil {
                    throw NativeQueuedMutationRequestError.missingField("steps.\(stepIndex).ingredients.\(ingredientIndex).unit")
                }
            }
        }
    }

    private static func validateIngredients(_ ingredients: [RecipeIngredientDraft], fieldPrefix: String) throws {
        for (ingredientIndex, ingredient) in ingredients.enumerated() {
            if ingredient.unit == nil {
                throw NativeQueuedMutationRequestError.missingField("\(fieldPrefix).\(ingredientIndex).unit")
            }
        }
    }
}

extension NativeQueuedMutation {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case clientMutationID = "clientMutationId"
        case createdAt
        case retryCount
        case nextRetryAt
        case lastError
        case kind
    }

    private static let encodedSchemaVersion = 1

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.encodedSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported native queued mutation schema version \(schemaVersion)."
            )
        }

        let kindContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .kind)
        let typeKey = DynamicCodingKey("type")
        let type = try kindContainer.decode(String.self, forKey: typeKey)
        guard let queueableKind = NativeQueuedMutationKind(rawValue: type) else {
            throw DecodingError.dataCorruptedError(
                forKey: typeKey,
                in: kindContainer,
                debugDescription: "Unknown native queued mutation type \(type)."
            )
        }

        var values: [String: JSONValue] = [:]
        var media: [String: NativeStagedMediaUpload] = [:]
        for key in kindContainer.allKeys {
            guard key.stringValue != "type" else { continue }
            if queueableKind.mediaFieldNames.contains(key.stringValue) {
                media[key.stringValue] = try kindContainer.decode(NativeStagedMediaUpload.self, forKey: key)
            } else {
                values[key.stringValue] = try kindContainer.decode(JSONValue.self, forKey: key)
            }
        }

        self.init(
            id: try container.decode(String.self, forKey: .id),
            clientMutationID: try container.decode(String.self, forKey: .clientMutationID),
            createdAt: try container.decode(String.self, forKey: .createdAt),
            payloadSchemaVersion: schemaVersion,
            retryCount: try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0,
            nextRetryAt: try container.decodeIfPresent(String.self, forKey: .nextRetryAt),
            lastError: try container.decodeIfPresent(String.self, forKey: .lastError),
            queueableKind: queueableKind,
            values: values,
            media: media
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.encodedSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(clientMutationID, forKey: .clientMutationID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(nextRetryAt, forKey: .nextRetryAt)
        try container.encodeIfPresent(lastError, forKey: .lastError)

        var kindContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .kind)
        try kindContainer.encode(queueableKind.rawValue, forKey: DynamicCodingKey("type"))
        for key in values.keys.sorted() {
            try kindContainer.encode(values[key], forKey: DynamicCodingKey(key))
        }
        for key in media.keys.sorted() {
            try kindContainer.encode(media[key], forKey: DynamicCodingKey(key))
        }
    }

    func resolvingStagedMedia(using resolver: any NativeStagedMediaResolving) throws -> NativeQueuedMutation {
        var resolvedMedia: [String: NativeStagedMediaUpload] = [:]
        for (key, upload) in media {
            resolvedMedia[key] = upload.data.isEmpty ? upload.replacingData(try resolver.data(for: upload)) : upload
        }

        return NativeQueuedMutation(
            id: id,
            clientMutationID: clientMutationID,
            createdAt: createdAt,
            payloadSchemaVersion: payloadSchemaVersion,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt,
            lastError: lastError,
            queueableKind: queueableKind,
            values: values,
            media: resolvedMedia
        )
    }
}

private extension NativeQueuedMutationKind {
    var mediaFieldNames: Set<String> {
        switch self {
        case .spoonCreatePhoto, .profilePhotoUpload:
            ["photo"]
        case .coverUpload:
            ["image"]
        default:
            []
        }
    }
}

struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

public enum NativeMutationQueueError: Error, Equatable, Sendable {
    case emptyClientMutationID
    case duplicateClientMutationID(String)
}

public struct NativeMutationQueue: Codable, Equatable, Sendable {
    public let mutations: [NativeQueuedMutation]

    public init() {
        mutations = []
    }

    public init(mutations: [NativeQueuedMutation]) throws {
        self.mutations = try Self.validatedMutations(mutations)
    }

    public func appending(_ mutation: NativeQueuedMutation) throws -> NativeMutationQueue {
        try NativeMutationQueue(mutations: mutations + [mutation])
    }

    public func removing(clientMutationIDs drainedIDs: Set<String>) throws -> NativeMutationQueue {
        try NativeMutationQueue(mutations: mutations.filter { !drainedIDs.contains($0.clientMutationID) })
    }

    public func resolvingStagedMedia(using resolver: any NativeStagedMediaResolving) throws -> NativeMutationQueue {
        try NativeMutationQueue(mutations: mutations.map { try $0.resolvingStagedMedia(using: resolver) })
    }

    private static func validatedMutations(_ mutations: [NativeQueuedMutation]) throws -> [NativeQueuedMutation] {
        var seenClientMutationIDs = Set<String>()
        for mutation in mutations {
            let clientMutationID = mutation.clientMutationID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clientMutationID.isEmpty else {
                throw NativeMutationQueueError.emptyClientMutationID
            }
            guard seenClientMutationIDs.insert(clientMutationID).inserted else {
                throw NativeMutationQueueError.duplicateClientMutationID(clientMutationID)
            }
        }
        return mutations
    }
}

public enum NativeOfflineAction: Equatable, Sendable {
    case queuedMutation(NativeQueuedMutation)
    case oauthSignIn
    case oauthCallback
    case apiTokenCreate
    case apiTokenRevoke
    case providerConnectionDisconnect
    case logout
    case sessionRevoke
    case passkeyOrPasswordChange
    case providerLink
    case apnsPermissionPrompt
    case apnsDeviceTokenAcquisition
    case providerSecretBlockedCoverRegeneration
    case providerSecretBlockedImport
    case destructiveProductionApproval
}

public struct NativeOfflineMutationDecision: Equatable, Sendable {
    public let queueableKind: NativeQueuedMutationKind?
    public let onlineOnlyReason: String?
}

public enum NativeOfflineMutationPolicy {
    public static func decision(for action: NativeOfflineAction) throws -> NativeOfflineMutationDecision {
        switch action {
        case .queuedMutation(let mutation):
            NativeOfflineMutationDecision(queueableKind: mutation.queueableKind, onlineOnlyReason: nil)
        case .oauthSignIn:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "OAuth sign-in is online-only and was not queued.")
        case .oauthCallback:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "OAuth callback exchange is online-only and was not queued.")
        case .apiTokenCreate:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "API token creation is online-only and was not queued.")
        case .apiTokenRevoke:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "API token revocation is online-only and was not queued.")
        case .providerConnectionDisconnect:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Provider disconnect is online-only and was not queued.")
        case .logout:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Logout is online-only and was not queued.")
        case .sessionRevoke:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Session revocation is online-only and was not queued.")
        case .passkeyOrPasswordChange:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Credential changes are online-only and were not queued.")
        case .providerLink:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Provider linking is online-only and was not queued.")
        case .apnsPermissionPrompt:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Notification permission prompts are online-only and were not queued.")
        case .apnsDeviceTokenAcquisition:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Device token acquisition is online-only and was not queued.")
        case .providerSecretBlockedCoverRegeneration:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Provider-secret-blocked cover regeneration is online-only and was not queued.")
        case .providerSecretBlockedImport:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Provider-secret-blocked import is online-only and was not queued.")
        case .destructiveProductionApproval:
            NativeOfflineMutationDecision(queueableKind: nil, onlineOnlyReason: "Destructive production approvals are online-only and were not queued.")
        }
    }
}

public struct NativeSyncRetrySchedule: Equatable, Sendable {
    public init() {}

    public func baseDelaySeconds(forRetryCount retryCount: Int) -> Int {
        switch retryCount {
        case ...0:
            5
        case 1:
            30
        case 2:
            300
        default:
            1_800
        }
    }

    public func jitteredDelaySeconds(forRetryCount retryCount: Int, randomUnit: Double) -> Int {
        let unit = min(max(randomUnit, 0.0), 1.0)
        let multiplier = 0.8 + (unit * 0.4)
        return Int((Double(baseDelaySeconds(forRetryCount: retryCount)) * multiplier).rounded())
    }
}

public enum NativeVisibleStaleSurface: Equatable, Sendable {
    case recipeDetail(id: String)
    case cookbookDetail(id: String)
    case profile(id: String)
    case shoppingList
}

public enum NativeSyncTriggerEvent: Equatable, Sendable {
    case launch
    case foreground
    case accountChanged(accountID: String)
    case environmentChanged(NativeCacheEnvironment)
    case networkRecovered
    case visibleStaleSurface(NativeVisibleStaleSurface)
}

public protocol NativeSyncTriggerRunning: Sendable {
    func bootstrapAndDrain(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger
    ) async throws -> NativeSyncReport
}

public struct NativeSyncTriggerCoordinator: Sendable {
    private let runner: any NativeSyncTriggerRunning
    private let configuration: APIClientConfiguration

    public init(runner: any NativeSyncTriggerRunning, configuration: APIClientConfiguration) {
        self.runner = runner
        self.configuration = configuration
    }

    @discardableResult
    public func handle(_ event: NativeSyncTriggerEvent) async throws -> NativeSyncReport {
        try await runner.bootstrapAndDrain(configuration: configuration, trigger: event.cacheTrigger)
    }
}

private extension NativeSyncTriggerEvent {
    var cacheTrigger: NativeCacheRevalidationTrigger {
        switch self {
        case .launch:
            .launch
        case .foreground:
            .foreground
        case .accountChanged:
            .accountChanged
        case .environmentChanged:
            .environmentChanged
        case .networkRecovered:
            .networkRecovered
        case .visibleStaleSurface:
            .visibleSurfaceOpened
        }
    }
}

public enum NativeServerRevision: Codable, Equatable, Sendable {
    case updatedAt(String)
    case tombstone(String)
    case etag(String)
}

public enum NativeSyncConflictKind: Equatable, Sendable {
    case validation
}

public struct NativeSyncConflict: Equatable, Sendable {
    public let clientMutationID: String
    public let kind: NativeSyncConflictKind
    public let serverRevision: NativeServerRevision?
    public let message: String

    public init(clientMutationID: String, kind: NativeSyncConflictKind, serverRevision: NativeServerRevision?, message: String) {
        self.clientMutationID = clientMutationID
        self.kind = kind
        self.serverRevision = serverRevision
        self.message = message
    }
}

public enum NativeSyncPauseReason: Equatable, Sendable {
    case authRequired(String)
}

public struct NativeSyncReport: Equatable, Sendable {
    public let trigger: NativeCacheRevalidationTrigger
    public let bootstrapCursor: PaginationCursor?
    public let drainedClientMutationIDs: [String]
    public let conflicts: [NativeSyncConflict]
    public let pausedReason: NativeSyncPauseReason?
    public let retryAfterSeconds: Int?

    public init(
        trigger: NativeCacheRevalidationTrigger,
        bootstrapCursor: PaginationCursor?,
        drainedClientMutationIDs: [String],
        conflicts: [NativeSyncConflict],
        pausedReason: NativeSyncPauseReason?,
        retryAfterSeconds: Int?
    ) {
        self.trigger = trigger
        self.bootstrapCursor = bootstrapCursor
        self.drainedClientMutationIDs = drainedClientMutationIDs
        self.conflicts = conflicts
        self.pausedReason = pausedReason
        self.retryAfterSeconds = retryAfterSeconds
    }
}

public enum NativeSyncBootstrapResult: Equatable, Sendable {
    case success(cursor: PaginationCursor?, tombstones: [NativeSyncTombstone])
}

public enum NativeSyncMutationResult: Equatable, Sendable {
    case success(serverRevision: NativeServerRevision?)
    case conflict(kind: NativeSyncConflictKind, serverRevision: NativeServerRevision?, message: String)
    case authFailure(message: String)
    case retry(afterSeconds: Int, message: String)
}

public protocol NativeSyncTransport: Sendable {
    func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult
    func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult
}

public final class NativeSyncEngine: NativeSyncTriggerRunning, @unchecked Sendable {
    private let store: any NativeSyncStore
    private let transport: any NativeSyncTransport
    private let clock: @Sendable () -> Date

    public init(store: any NativeSyncStore, transport: any NativeSyncTransport, clock: @escaping @Sendable () -> Date = Date.init) {
        self.store = store
        self.transport = transport
        self.clock = clock
    }

    public func bootstrapAndDrain(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger
    ) async throws -> NativeSyncReport {
        let previousCheckpoint = try? await store.loadCheckpoint()
        let bootstrapRequest = try NativeSyncBootstrapRequest.defaultRequest(cursor: previousCheckpoint?.globalCursor)
            .urlRequest(configuration: configuration)
        let bootstrapResult = try await transport.bootstrap(request: bootstrapRequest, configuration: configuration)

        let bootstrapCursor: PaginationCursor?
        switch bootstrapResult {
        case .success(let cursor, let tombstones):
            bootstrapCursor = cursor
            for tombstone in tombstones {
                try await store.appendTombstone(tombstone)
            }
            if let cursor {
                let checkpoint = try NativeSyncCheckpoint(
                    globalCursor: cursor,
                    shoppingCursor: previousCheckpoint?.shoppingCursor,
                    updatedAt: NativeSyncClockFormatting.isoString(clock())
                )
                try await store.saveCheckpoint(checkpoint)
            }
        }

        let originalQueue = try await store.loadQueue()
        var remaining: [NativeQueuedMutation] = []
        var drainedClientMutationIDs: [String] = []
        var conflicts: [NativeSyncConflict] = []
        var blockedDependencyKeys = Set<String>()
        var pausedReason: NativeSyncPauseReason?
        var retryAfterSeconds: Int?

        var index = 0
        while index < originalQueue.mutations.count {
            let mutation = originalQueue.mutations[index]
            guard !blockedDependencyKeys.contains(mutation.dependencyKey) else {
                remaining.append(mutation)
                index += 1
                continue
            }

            guard mutation.replayTarget == .remote else {
                remaining.append(mutation)
                index += 1
                continue
            }

            if let delay = mutation.retryDelayRemaining(at: clock()), delay > 0 {
                remaining.append(mutation)
                blockedDependencyKeys.insert(mutation.dependencyKey)
                retryAfterSeconds = Self.shortestRetryDelay(retryAfterSeconds, delay)
                index += 1
                continue
            }

            let result = try await transport.send(mutation, configuration: configuration)
            switch result {
            case .success(let revision):
                drainedClientMutationIDs.append(mutation.clientMutationID)
                if case .tombstone(let token)? = revision {
                    try await store.appendTombstone(mutation.tombstone(token: token, at: clock()))
                }
            case .conflict(let kind, let revision, let message):
                remaining.append(mutation.recordingError(message))
                conflicts.append(NativeSyncConflict(
                    clientMutationID: mutation.clientMutationID,
                    kind: kind,
                    serverRevision: revision,
                    message: message
                ))
                blockedDependencyKeys.insert(mutation.dependencyKey)
            case .authFailure(let message):
                pausedReason = .authRequired(message)
                remaining.append(mutation)
                remaining.append(contentsOf: originalQueue.mutations.dropFirst(index + 1))
                index = originalQueue.mutations.count
                continue
            case .retry(let afterSeconds, let message):
                retryAfterSeconds = Self.shortestRetryDelay(retryAfterSeconds, afterSeconds)
                remaining.append(mutation.recordingRetry(
                    message: message,
                    nextRetryAt: NativeSyncClockFormatting.isoString(clock().addingTimeInterval(TimeInterval(afterSeconds)))
                ))
                blockedDependencyKeys.insert(mutation.dependencyKey)
            }

            index += 1
        }

        try await store.saveQueue(NativeMutationQueue(mutations: remaining))

        return NativeSyncReport(
            trigger: trigger,
            bootstrapCursor: bootstrapCursor,
            drainedClientMutationIDs: drainedClientMutationIDs,
            conflicts: conflicts,
            pausedReason: pausedReason,
            retryAfterSeconds: retryAfterSeconds
        )
    }

    private static func shortestRetryDelay(_ current: Int?, _ candidate: Int) -> Int {
        guard let current else {
            return candidate
        }

        return min(current, candidate)
    }
}

private extension NativeQueuedMutation {
    func retryDelayRemaining(at date: Date) -> Int? {
        guard let nextRetryAt,
              let scheduled = NativeSyncClockFormatting.date(from: nextRetryAt) else {
            return nil
        }

        let remaining = scheduled.timeIntervalSince(date)
        guard remaining > 0 else {
            return nil
        }

        return Int(ceil(remaining))
    }

    func tombstone(token: String, at date: Date) -> NativeSyncTombstone {
        let timestamp = NativeSyncClockFormatting.isoString(date)
        return NativeSyncTombstone(
            resourceType: tombstoneResourceType,
            resourceID: token,
            parentResourceID: stringValue("recipeId") ?? stringValue("cookbookId"),
            title: nil,
            deletedAt: timestamp,
            updatedAt: timestamp
        )
    }

    var tombstoneResourceType: NativeSyncResourceType {
        switch queueableKind {
        case .recipeDelete:
            .recipe
        case .cookbookDelete:
            .cookbook
        case .spoonDelete:
            .spoon
        case .shoppingDeleteItem, .shoppingClearCompleted, .shoppingClearAll:
            .shoppingItem
        default:
            .recipe
        }
    }
}

private enum NativeSyncClockFormatting {
    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractionalDate = formatter.date(from: string)
        if fractionalDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }

        return fractionalDate
    }
}
