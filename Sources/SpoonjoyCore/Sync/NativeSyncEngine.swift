import Foundation
#if canImport(OSLog)
import OSLog
#endif

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

extension NativeSyncData {
    func scoped(to environment: NativeCacheEnvironment?) -> NativeSyncData {
        guard let environment,
              freshness.environment == .preview,
              environment.isPreview,
              freshness.environment != environment else {
            return self
        }
        return NativeSyncData(
            freshness: NativeSyncFreshness(
                accountID: freshness.accountID,
                environment: environment,
                schemaVersion: freshness.schemaVersion,
                sourceEndpoint: freshness.sourceEndpoint,
                generatedAt: freshness.generatedAt,
                lastValidatedAt: freshness.lastValidatedAt
            ),
            entries: entries,
            nextCursor: nextCursor,
            hasMore: hasMore
        )
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
    case unavailable(String)
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
    public let accountID: String?
    public let environment: NativeCacheEnvironment?
    public let checkpoint: NativeSyncCheckpoint?
    public let queue: NativeMutationQueue
    public let cachedRecords: [NativeSyncCachedRecord]
    public let tombstones: [NativeSyncTombstone]

    public static let empty = NativeSyncSnapshot(
        accountID: nil,
        environment: nil,
        checkpoint: nil,
        queue: NativeMutationQueue(),
        cachedRecords: [],
        tombstones: []
    )

    public init(
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil,
        checkpoint: NativeSyncCheckpoint?,
        queue: NativeMutationQueue,
        cachedRecords: [NativeSyncCachedRecord] = [],
        tombstones: [NativeSyncTombstone] = []
    ) {
        self.accountID = accountID
        self.environment = environment
        self.checkpoint = checkpoint
        self.queue = queue
        self.cachedRecords = cachedRecords
        self.tombstones = tombstones
    }
}

extension NativeSyncSnapshot {
    private enum CodingKeys: String, CodingKey {
        case accountID
        case environment
        case checkpoint
        case queue
        case cachedRecords
        case tombstones
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
        environment = try container.decodeIfPresent(NativeCacheEnvironment.self, forKey: .environment)
        checkpoint = try container.decodeIfPresent(NativeSyncCheckpoint.self, forKey: .checkpoint)
        queue = try container.decodeIfPresent(NativeMutationQueue.self, forKey: .queue) ?? NativeMutationQueue()
        cachedRecords = try container.decodeIfPresent([NativeSyncCachedRecord].self, forKey: .cachedRecords) ?? []
        tombstones = try container.decodeIfPresent([NativeSyncTombstone].self, forKey: .tombstones) ?? []
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
    func saveQueue(_ queue: NativeMutationQueue, accountID: String?, environment: NativeCacheEnvironment?) throws
    func saveQueue(
        _ queue: NativeMutationQueue,
        accountID: String?,
        environment: NativeCacheEnvironment?,
        upsertingCachedRecords cachedRecords: [NativeSyncCachedRecord],
        deletingCachedRecordKeys deletedCacheKeys: Set<String>
    ) throws
    func loadCheckpoint() throws -> NativeSyncCheckpoint
    func saveCheckpoint(_ checkpoint: NativeSyncCheckpoint) throws
    func appendTombstone(_ tombstone: NativeSyncTombstone) throws
    func cachedRecord(kind: NativeSyncEntryKind, resourceID: String) throws -> NativeSyncCachedRecord?
    func apply(syncData: NativeSyncData, validatedAt: Date) throws -> NativeSyncApplyResult
    func loadSnapshot() throws -> NativeSyncSnapshot
}

public actor InMemoryNativeSyncStore: NativeSyncStore {
    private var accountID: String?
    private var environment: NativeCacheEnvironment?
    private var checkpoint: NativeSyncCheckpoint?
    private var queue: NativeMutationQueue
    private var records: [String: NativeSyncCachedRecord]
    public private(set) var tombstones: NativeSyncTombstoneLog

    public init(
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil,
        checkpoint: NativeSyncCheckpoint?,
        queue: NativeMutationQueue,
        cachedRecords: [NativeSyncCachedRecord] = []
    ) {
        self.accountID = accountID
        self.environment = environment
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

    public func saveQueue(_ queue: NativeMutationQueue, accountID: String?, environment: NativeCacheEnvironment?) {
        saveQueue(queue, accountID: accountID, environment: environment, upsertingCachedRecords: [], deletingCachedRecordKeys: [])
    }

    public func saveQueue(
        _ queue: NativeMutationQueue,
        accountID: String?,
        environment: NativeCacheEnvironment?,
        upsertingCachedRecords cachedRecords: [NativeSyncCachedRecord],
        deletingCachedRecordKeys deletedCacheKeys: Set<String>
    ) {
        let scopeChanged = self.accountID != accountID || self.environment != environment
        self.accountID = accountID
        self.environment = environment
        if scopeChanged {
            checkpoint = nil
            records = [:]
            tombstones = NativeSyncTombstoneLog()
        }
        for deletedCacheKey in deletedCacheKeys {
            records.removeValue(forKey: deletedCacheKey)
        }
        for cachedRecord in cachedRecords {
            records[cachedRecord.cacheKey] = cachedRecord
        }
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
        if shouldResetForIncomingSyncData(syncData) {
            checkpoint = nil
            queue = NativeMutationQueue()
            records = [:]
            tombstones = NativeSyncTombstoneLog()
        }
        accountID = syncData.freshness.accountID
        environment = syncData.freshness.environment

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

    public func loadSnapshot() -> NativeSyncSnapshot {
        return NativeSyncSnapshot(
            accountID: accountID,
            environment: environment,
            checkpoint: checkpoint,
            queue: queue,
            cachedRecords: records.values.sorted { $0.cacheKey < $1.cacheKey },
            tombstones: tombstones.entries
        )
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func shouldResetForIncomingSyncData(_ syncData: NativeSyncData) -> Bool {
        guard let accountID, let environment else {
            return checkpoint != nil || !queue.mutations.isEmpty || !records.isEmpty || !tombstones.entries.isEmpty
        }
        return accountID != syncData.freshness.accountID || environment != syncData.freshness.environment
    }
}

public actor FileBackedNativeSyncStore: NativeSyncStore {
    private let store: JSONFileStore<NativeSyncSnapshot>
    private let mediaResolver: (any NativeStagedMediaResolving)?
    private var accountID: String?
    private var environment: NativeCacheEnvironment?
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
        self.accountID = snapshot.accountID
        self.environment = snapshot.environment
        self.checkpoint = snapshot.checkpoint
        self.queue = snapshot.queue
        self.records = Dictionary(uniqueKeysWithValues: snapshot.cachedRecords.map { ($0.cacheKey, $0) })
        self.tombstones = snapshot.tombstones
    }

    public func loadQueue() throws -> NativeMutationQueue {
        if let mediaResolver {
            return try queue.resolvingStagedMedia(using: mediaResolver)
        }
        return queue
    }

    public func saveQueue(_ queue: NativeMutationQueue) throws {
        if let mediaResolver {
            self.queue = try queue.resolvingStagedMedia(using: mediaResolver)
        } else {
            self.queue = queue
        }
        try persist()
    }

    public func saveQueue(_ queue: NativeMutationQueue, accountID: String?, environment: NativeCacheEnvironment?) throws {
        try saveQueue(queue, accountID: accountID, environment: environment, upsertingCachedRecords: [], deletingCachedRecordKeys: [])
    }

    public func saveQueue(
        _ queue: NativeMutationQueue,
        accountID: String?,
        environment: NativeCacheEnvironment?,
        upsertingCachedRecords cachedRecords: [NativeSyncCachedRecord],
        deletingCachedRecordKeys deletedCacheKeys: Set<String>
    ) throws {
        let scopeChanged = self.accountID != accountID || self.environment != environment
        self.accountID = accountID
        self.environment = environment
        if scopeChanged {
            checkpoint = nil
            records = [:]
            tombstones = []
        }
        for deletedCacheKey in deletedCacheKeys {
            records.removeValue(forKey: deletedCacheKey)
        }
        for cachedRecord in cachedRecords {
            records[cachedRecord.cacheKey] = cachedRecord
        }
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
        if shouldResetForIncomingSyncData(syncData) {
            checkpoint = nil
            queue = NativeMutationQueue()
            records = [:]
            tombstones = []
        }
        accountID = syncData.freshness.accountID
        environment = syncData.freshness.environment

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

    public func loadSnapshot() throws -> NativeSyncSnapshot {
        snapshot()
    }

    private func persist() throws {
        try store.save(snapshot())
    }

    private func snapshot() -> NativeSyncSnapshot {
        return NativeSyncSnapshot(
            accountID: accountID,
            environment: environment,
            checkpoint: checkpoint,
            queue: queue,
            cachedRecords: records.values.sorted { $0.cacheKey < $1.cacheKey },
            tombstones: tombstones
        )
    }

    private func shouldResetForIncomingSyncData(_ syncData: NativeSyncData) -> Bool {
        guard let accountID, let environment else {
            return checkpoint != nil || !queue.mutations.isEmpty || !records.isEmpty || !tombstones.isEmpty
        }
        return accountID != syncData.freshness.accountID || environment != syncData.freshness.environment
    }
}

public actor UnavailableNativeSyncStore: NativeSyncStore {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public func loadQueue() throws -> NativeMutationQueue {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func saveQueue(_: NativeMutationQueue) throws {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func saveQueue(_: NativeMutationQueue, accountID _: String?, environment _: NativeCacheEnvironment?) throws {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func saveQueue(
        _: NativeMutationQueue,
        accountID _: String?,
        environment _: NativeCacheEnvironment?,
        upsertingCachedRecords _: [NativeSyncCachedRecord],
        deletingCachedRecordKeys _: Set<String>
    ) throws {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func loadCheckpoint() throws -> NativeSyncCheckpoint {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func saveCheckpoint(_: NativeSyncCheckpoint) throws {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func appendTombstone(_: NativeSyncTombstone) throws {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func cachedRecord(kind _: NativeSyncEntryKind, resourceID _: String) throws -> NativeSyncCachedRecord? {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func apply(syncData _: NativeSyncData, validatedAt _: Date) throws -> NativeSyncApplyResult {
        throw NativeSyncStoreError.unavailable(message)
    }

    public func loadSnapshot() throws -> NativeSyncSnapshot {
        throw NativeSyncStoreError.unavailable(message)
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
    public let byteCount: Int
    public let data: Data

    public init(localStageID: String, fileName: String, contentType: String, data: Data) {
        self.init(
            localStageID: localStageID,
            fileName: fileName,
            contentType: contentType,
            byteCount: data.count,
            data: data
        )
    }

    public init(localStageID: String, fileName: String, contentType: String, byteCount: Int, data: Data = Data()) {
        self.localStageID = localStageID
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = max(byteCount, data.count)
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
        case byteCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localStageID = try container.decode(String.self, forKey: .localStageID)
        fileName = try container.decode(String.self, forKey: .fileName)
        contentType = try container.decode(String.self, forKey: .contentType)
        byteCount = try container.decodeIfPresent(Int.self, forKey: .byteCount) ?? 0
        data = Data()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localStageID, forKey: .localStageID)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(byteCount, forKey: .byteCount)
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

    public func delete(_ upload: NativeStagedMediaUpload) throws {
        try delete(localStageID: upload.localStageID)
    }

    public func delete(localStageID: String) throws {
        let url = fileURL(for: localStageID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
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

public enum NativeCaptureTextSource: String, Codable, Equatable, Sendable {
    case camera
    case photoLibrary = "photo-library"
}

public struct NativeCaptureTextMetadata: Codable, Equatable, Sendable {
    public let source: NativeCaptureTextSource
    public let assetIdentifier: String?

    public init(source: NativeCaptureTextSource, assetIdentifier: String?) {
        self.source = source
        self.assetIdentifier = assetIdentifier
    }

    public init?(jsonValue: JSONValue) {
        guard case .object(let object) = jsonValue,
              case .string(let sourceRawValue)? = object["source"],
              let source = NativeCaptureTextSource(rawValue: sourceRawValue) else {
            return nil
        }

        let assetIdentifier: String?
        if case .string(let value)? = object["assetIdentifier"] {
            assetIdentifier = value
        } else {
            assetIdentifier = nil
        }

        self.init(source: source, assetIdentifier: assetIdentifier)
    }

    func jsonValue() -> JSONValue {
        var object: [String: JSONValue] = ["source": .string(source.rawValue)]
        if let assetIdentifier {
            object["assetIdentifier"] = .string(assetIdentifier)
        }
        return .object(object)
    }
}

public enum NativeMutationSource: Codable, Equatable, Sendable {
    case url(URL)
    case text(String)
    case textWithMetadata(String, sourceURL: URL?, capture: NativeCaptureTextMetadata?)
    case jsonLD(JSONValue, sourceURL: URL?)
    case videoURL(URL)

    public init?(jsonValue: JSONValue) {
        guard case .object(let object) = jsonValue,
              case .string(let type)? = object["type"] else {
            return nil
        }

        switch type {
        case "url":
            guard case .string(let value)? = object["url"],
                  let url = URL(string: value) else {
                return nil
            }
            self = .url(url)
        case "text":
            guard case .string(let text)? = object["text"] else {
                return nil
            }
            let sourceURL: URL?
            if case .string(let value)? = object["url"] {
                sourceURL = URL(string: value)
            } else {
                sourceURL = nil
            }
            let capture: NativeCaptureTextMetadata?
            if let value = object["capture"] {
                capture = NativeCaptureTextMetadata(jsonValue: value)
            } else {
                capture = nil
            }
            self = .textWithMetadata(text, sourceURL: sourceURL, capture: capture)
        case "json-ld":
            guard let jsonLD = object["jsonLd"] else {
                return nil
            }
            let sourceURL: URL?
            if case .string(let value)? = object["url"] {
                sourceURL = URL(string: value)
            } else {
                sourceURL = nil
            }
            self = .jsonLD(jsonLD, sourceURL: sourceURL)
        case "video-url":
            guard case .string(let value)? = object["url"],
                  let url = URL(string: value) else {
                return nil
            }
            self = .videoURL(url)
        default:
            return nil
        }
    }

    public func jsonValue() -> JSONValue {
        switch self {
        case .url(let url):
            return JSONValue.object([
                "type": JSONValue.string("url"),
                "url": JSONValue.string(url.absoluteString)
            ])
        case .text(let text):
            return JSONValue.object([
                "type": JSONValue.string("text"),
                "text": JSONValue.string(text)
            ])
        case .textWithMetadata(let text, let sourceURL, let capture):
            var object: [String: JSONValue] = [
                "type": .string("text"),
                "text": .string(text)
            ]
            if let sourceURL {
                object["url"] = .string(sourceURL.absoluteString)
            }
            if let capture {
                object["capture"] = capture.jsonValue()
            }
            return .object(object)
        case .jsonLD(let jsonLD, let sourceURL):
            return .object([
                "type": .string("json-ld"),
                "jsonLd": jsonLD,
                "url": sourceURL.map { .string($0.absoluteString) } ?? .null
            ])
        case .videoURL(let url):
            return .object(["type": .string("video-url"), "url": .string(url.absoluteString)])
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
    case coverSetNoCover = "cover.setNoCover"
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
        .coverSetNoCover,
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

    public var stagedMediaUploadCount: Int { media.count }

    public var stagedMediaUploadByteCount: Int {
        media.values.reduce(0) { $0 + $1.byteCount }
    }

    public var stagedMediaUploadStageIDs: Set<String> {
        Set(media.values.map(\.localStageID))
    }

    public var recipeImportSource: NativeMutationSource? {
        guard queueableKind == .recipeImportSubmit,
              let source = values["source"] else {
            return nil
        }

        return NativeMutationSource(jsonValue: source)
    }

    public var recipeID: String? {
        stringValue("recipeId")
    }

    public var optimisticRecipeID: String? {
        queueableKind == .recipeCreate ? "recipe_local_\(clientMutationID)" : recipeID
    }

    public var optimisticCookbookID: String? {
        queueableKind == .cookbookCreate ? stringValue("serverCookbookId") ?? "cookbook_local_\(clientMutationID)" : stringValue("cookbookId")
    }

    public var optimisticSpoonID: String? {
        switch queueableKind {
        case .spoonCreate, .spoonCreatePhoto:
            stringValue("serverSpoonId") ?? "spoon_local_\(clientMutationID)"
        case .spoonUpdate, .spoonDelete:
            stringValue("spoonId")
        default:
            nil
        }
    }

    public var profileDisplayUpdateValues: (email: String, username: String)? {
        guard queueableKind == .profileDisplayUpdate,
              let email = stringValue("email"),
              let username = stringValue("username") else {
            return nil
        }
        return (email, username)
    }

    public var notificationPreferenceUpdateValues: SettingsNotificationPreferences? {
        guard queueableKind == .notificationPreferenceUpdate,
              let notifySpoonOnMyRecipe = boolValue("notifySpoonOnMyRecipe"),
              let notifyForkOfMyRecipe = boolValue("notifyForkOfMyRecipe"),
              let notifyCookbookSaveOfMine = boolValue("notifyCookbookSaveOfMine"),
              let notifyFellowChefOriginCook = boolValue("notifyFellowChefOriginCook") else {
            return nil
        }
        return SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: notifySpoonOnMyRecipe,
            notifyForkOfMyRecipe: notifyForkOfMyRecipe,
            notifyCookbookSaveOfMine: notifyCookbookSaveOfMine,
            notifyFellowChefOriginCook: notifyFellowChefOriginCook
        )
    }

    public func blocksDependencyKey(_ dependencyKey: String) -> Bool {
        self.dependencyKey == dependencyKey || dependentDependencyKeysBlockedWithThisMutation.contains(dependencyKey)
    }

    public func applyingOptimisticCookbookMutation(
        to cookbooks: [Cookbook],
        fallbackChef: ChefSummary,
        recipes: [Recipe],
        now: String
    ) -> [Cookbook] {
        switch queueableKind {
        case .cookbookCreate:
            return upsertingCookbook(optimisticCreatedCookbook(fallbackChef: fallbackChef, now: now), into: cookbooks)
        case .cookbookUpdate:
            guard let cookbookID = stringValue("cookbookId") else {
                return cookbooks
            }
            return cookbooks.map { cookbook in
                guard cookbook.id == cookbookID else {
                    return cookbook
                }
                return cookbook.copy(
                    title: stringValue("title") ?? cookbook.title,
                    updatedAt: now
                )
            }
        case .cookbookDelete:
            guard let cookbookID = stringValue("cookbookId") else {
                return cookbooks
            }
            return cookbooks.filter { $0.id != cookbookID }
        case .cookbookAddRecipe:
            guard let cookbookID = stringValue("cookbookId"),
                  let recipeID = stringValue("recipeId"),
                  let recipe = recipes.first(where: { $0.id == recipeID }) else {
                return cookbooks
            }
            let summary = RecipeSummary(recipe: recipe)
            return cookbooks.map { cookbook in
                guard cookbook.id == cookbookID,
                      !cookbook.recipes.contains(where: { $0.id == recipeID }) else {
                    return cookbook
                }
                return cookbook.copy(
                    updatedAt: now,
                    recipes: cookbook.recipes + [summary]
                )
            }
        case .cookbookRemoveRecipe:
            guard let cookbookID = stringValue("cookbookId"),
                  let recipeID = stringValue("recipeId") else {
                return cookbooks
            }
            return cookbooks.map { cookbook in
                guard cookbook.id == cookbookID else {
                    return cookbook
                }
                return cookbook.copy(
                    updatedAt: now,
                    recipes: cookbook.recipes.filter { $0.id != recipeID }
                )
            }
        default:
            return cookbooks
        }
    }

    public func applyingOptimisticRecipeMutation(
        to recipes: [Recipe],
        fallbackChef: ChefSummary,
        now: String
    ) -> [Recipe] {
        switch queueableKind {
        case .recipeCreate:
            return upsertingRecipe(optimisticCreatedRecipe(fallbackChef: fallbackChef, now: now), into: recipes)
        case .recipeUpdate:
            return recipes.map { recipe in
                guard recipe.id == recipeID else {
                    return recipe
                }
                return recipe.copy(
                    title: stringValue("title") ?? recipe.title,
                    description: optionalStringValue("description"),
                    servings: optionalStringValue("servings"),
                    updatedAt: now
                )
            }
        case .recipeDelete:
            guard let recipeID else {
                return recipes
            }
            return recipes.filter { $0.id != recipeID }
        case .recipeStepCreate:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                recipe.copy(
                    updatedAt: now,
                    steps: recipe.steps.inserting(
                        optimisticStep(now: now),
                        outputStepNumsForInsertedStep: intArrayValue("outputStepNums"),
                        clientMutationID: clientMutationID
                    )
                )
            }
        case .recipeStepUpdate:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                recipe.copy(updatedAt: now, steps: recipe.steps.map { step in
                    guard step.id == stringValue("stepId") else {
                        return step
                    }
                    return step.copy(
                        stepTitle: optionalStringValue("stepTitle"),
                        description: stringValue("description") ?? step.description,
                        duration: intValue("duration"),
                        usingSteps: outputUses(inputStepNum: step.stepNum, recipe: recipe)
                    )
                })
            }
        case .recipeStepDelete:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                guard let stepID = stringValue("stepId") else {
                    return recipe
                }
                return recipe.copy(updatedAt: now, steps: recipe.steps.deleting(stepID: stepID, clientMutationID: clientMutationID))
            }
        case .recipeStepReorder:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                guard let stepID = stringValue("stepId"), let toStepNum = intValue("toStepNum") else {
                    return recipe
                }
                return recipe.copy(updatedAt: now, steps: recipe.steps.reordered(stepID: stepID, toStepNum: toStepNum, clientMutationID: clientMutationID))
            }
        case .recipeIngredientAdd:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                guard let stepID = stringValue("stepId") else {
                    return recipe
                }
                return recipe.copy(updatedAt: now, steps: recipe.steps.map { step in
                    guard step.id == stepID else {
                        return step
                    }
                    return step.copy(ingredients: step.ingredients + [optimisticIngredient()])
                })
            }
        case .recipeIngredientDelete:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                guard let stepID = stringValue("stepId"), let ingredientID = stringValue("ingredientId") else {
                    return recipe
                }
                return recipe.copy(updatedAt: now, steps: recipe.steps.map { step in
                    guard step.id == stepID else {
                        return step
                    }
                    return step.copy(ingredients: step.ingredients.filter { $0.id != ingredientID })
                })
            }
        case .recipeOutputUsesReplace:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                guard let inputStepID = stringValue("inputStepId") else {
                    return recipe
                }
                return recipe.copy(updatedAt: now, steps: recipe.steps.map { step in
                    guard step.id == inputStepID else {
                        return step
                    }
                    return step.copy(usingSteps: outputUses(inputStepNum: step.stepNum, recipe: recipe))
                })
            }
        case .spoonCreate, .spoonCreatePhoto:
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                recipe.copy(
                    updatedAt: now,
                    recentSpoons: recipe.recentSpoons.upsertingRecentSpoon(
                        optimisticCreatedSpoon(for: recipe, fallbackChef: fallbackChef, now: now)
                    )
                )
            }
        case .spoonUpdate:
            guard let spoonID = stringValue("spoonId") else {
                return recipes
            }
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                return recipe.copy(
                    updatedAt: now,
                    recentSpoons: recipe.recentSpoons.updatingRecentSpoon(id: spoonID) { spoon in
                        updatedSpoon(spoon, updatedAt: now)
                    }
                )
            }
        case .spoonDelete:
            guard let spoonID = stringValue("spoonId") else {
                return recipes
            }
            return applyingToRecipe(in: recipes, updatedAt: now) { recipe in
                return recipe.copy(
                    updatedAt: now,
                    recentSpoons: recipe.recentSpoons.markingRecentSpoonDeleted(id: spoonID, deletedAt: now)
                )
            }
        case .coverSetNoCover, .coverSetActive:
            return clearingActiveRecipeCover(in: recipes, updatedAt: now)
        case .coverArchive:
            guard boolValue("confirmNoCover") == true || optionalStringValue("replacementCoverId") != nil else {
                return recipes
            }
            return clearingActiveRecipeCover(in: recipes, updatedAt: now)
        case .coverFromSpoon:
            guard boolValue("activate") == true else {
                return recipes
            }
            return clearingActiveRecipeCover(in: recipes, updatedAt: now)
        case .coverRegenerate:
            guard boolValue("activateWhenReady") == true else {
                return recipes
            }
            return clearingActiveRecipeCover(in: recipes, updatedAt: now)
        default:
            return recipes
        }
    }

    public func applyingOptimisticShoppingMutation(
        to shoppingList: ShoppingListState?,
        recipes: [Recipe],
        fallbackChef: ChefSummary,
        now: String
    ) -> ShoppingListState? {
        switch queueableKind {
        case .shoppingAddItem:
            guard let name = stringValue("name") else {
                return shoppingList
            }
            let base = optimisticShoppingListBase(shoppingList, fallbackChef: fallbackChef, now: now)
            guard let updated = try? base.addingOrRestoringItem(
                name: name,
                quantity: doubleValue("quantity"),
                unit: optionalStringValue("unit"),
                categoryKey: optionalStringValue("categoryKey"),
                iconKey: optionalStringValue("iconKey"),
                clientMutationID: clientMutationID
            ).shoppingList else {
                return shoppingList
            }
            return updated.replacingShoppingItemID(
                "item_local_\(clientMutationID)",
                with: optionalStringValue("serverItemId")
            )
        case .shoppingCheckItem:
            guard let itemID = stringValue("itemId"),
                  let checked = boolValue("checked"),
                  let shoppingList else {
                return shoppingList
            }
            return (try? shoppingList.settingChecked(
                checked,
                itemID: itemID,
                checkedAt: checked ? now : nil,
                updatedAt: now,
                nextSortIndex: (shoppingList.activeItems.map(\.sortIndex).max() ?? -1) + 1
            )) ?? shoppingList
        case .shoppingDeleteItem:
            guard let itemID = stringValue("itemId"),
                  let shoppingList else {
                return shoppingList
            }
            return (try? shoppingList.removingItem(id: itemID, deletedAt: now)) ?? shoppingList
        case .shoppingAddFromRecipe:
            let ingredients = shoppingRecipeIngredientsForReplay(recipes: recipes)
            guard !ingredients.isEmpty else {
                return shoppingList
            }
            return ingredients.enumerated().reduce(
                optimisticShoppingListBase(shoppingList, fallbackChef: fallbackChef, now: now)
            ) { currentList, pair in
                let (index, ingredientValue) = pair
                guard case .object(let ingredient) = ingredientValue else {
                    return currentList
                }
                let ingredientMutationID = "\(clientMutationID)-ingredient-\(index + 1)"
                let quantity = doubleValue("quantity", in: ingredient)
                let updated = (try? currentList.addingOrRestoringItem(
                    name: stringValue("name", in: ingredient) ?? "",
                    quantity: quantity,
                    unit: optionalStringValue("unit", in: ingredient),
                    categoryKey: nil,
                    iconKey: nil,
                    clientMutationID: ingredientMutationID
                ).shoppingList) ?? currentList
                return updated.replacingShoppingItemID(
                    "item_local_\(ingredientMutationID)",
                    with: serverShoppingItemID(at: index)
                )
            }
        case .shoppingClearCompleted:
            return removingShoppingItems(from: shoppingList, deletedAt: now) { $0.checked || $0.checkedAt != nil }
        case .shoppingClearAll:
            return removingShoppingItems(from: shoppingList, deletedAt: now) { _ in true }
        default:
            return shoppingList
        }
    }

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
        case .recipeUpdate, .recipeDelete, .recipeFork, .recipeStepCreate, .recipeStepUpdate, .recipeStepDelete, .recipeStepReorder, .recipeIngredientAdd, .recipeIngredientDelete, .recipeOutputUsesReplace, .spoonCreate, .spoonCreatePhoto, .spoonUpdate, .spoonDelete, .coverUpload, .coverSetActive, .coverSetNoCover, .coverArchive, .coverRegenerate, .coverFromSpoon:
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

    var dependentDependencyKeysBlockedWithThisMutation: Set<String> {
        switch queueableKind {
        case .recipeCreate:
            ["recipe:recipe_local_\(clientMutationID)"]
        case .cookbookCreate:
            ["cookbook:cookbook_local_\(clientMutationID)"]
        default:
            []
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

    public func replacingResourceIDs(_ replacements: [String: String]) -> NativeQueuedMutation {
        guard !replacements.isEmpty else {
            return self
        }

        var nextValues = values
        for key in Self.resourceIdentifierValueKeys {
            guard case .string(let value)? = nextValues[key],
                  let replacement = replacements[value] else {
                continue
            }
            nextValues[key] = .string(replacement)
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
            values: nextValues,
            media: media
        )
    }

    public func recordingIDRemaps(_ idRemaps: [NativeSyncIDRemap]) -> NativeQueuedMutation {
        let replacements = Dictionary(idRemaps.map { ($0.localID, $0.serverID) }, uniquingKeysWith: { _, latest in latest })
        guard !replacements.isEmpty else {
            return self
        }

        var nextValues = values
        switch queueableKind {
        case .recipeCreate:
            nextValues["serverRecipeId"] = replacements["recipe_local_\(clientMutationID)"].map(JSONValue.string)
            let serverStepIDs = stepsValue("steps").indices.map { index in
                replacements["step_local_\(clientMutationID)_\(index + 1)"].map(JSONValue.string) ?? .null
            }
            nextValues["serverStepIds"] = .array(serverStepIDs)
            nextValues["serverStepIngredientIds"] = .array(stepsValue("steps").enumerated().map { stepIndex, step in
                guard case .object(let object) = step else {
                    return .array([])
                }
                return .array(ingredientsValue("ingredients", in: object).indices.map { ingredientIndex in
                    replacements["ingredient_local_\(clientMutationID)_\(stepIndex + 1)_\(ingredientIndex + 1)"].map(JSONValue.string) ?? .null
                })
            })
        case .recipeStepCreate:
            nextValues["serverStepId"] = replacements["step_local_\(clientMutationID)"].map(JSONValue.string)
            nextValues["serverIngredientIds"] = .array(ingredientsValue("ingredients").indices.map { index in
                replacements["ingredient_local_\(clientMutationID)_\(index + 1)"].map(JSONValue.string) ?? .null
            })
        case .recipeIngredientAdd:
            nextValues["serverIngredientId"] = replacements["ingredient_local_\(clientMutationID)"].map(JSONValue.string)
        case .shoppingAddItem:
            nextValues["serverItemId"] = replacements["item_local_\(clientMutationID)"].map(JSONValue.string)
        case .shoppingAddFromRecipe:
            let serverItemIDs = indexedServerShoppingItemIDs(from: replacements)
            if !serverItemIDs.isEmpty {
                nextValues["serverItemIds"] = .array(serverItemIDs)
            }
        case .cookbookCreate:
            nextValues["serverCookbookId"] = replacements["cookbook_local_\(clientMutationID)"].map(JSONValue.string)
        case .spoonCreate, .spoonCreatePhoto:
            nextValues["serverSpoonId"] = replacements["spoon_local_\(clientMutationID)"].map(JSONValue.string)
        default:
            break
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
            values: nextValues,
            media: media
        )
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
        case .coverSetNoCover:
            return try json(.patch, ["api", "v1", "recipes", requiredString("recipeId"), "covers"], excluding: ["recipeId"])
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
        for (key, value) in values where !excludedKeys.contains(key) && !Self.internalValueKeys.contains(key) {
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

    private static let internalValueKeys: Set<String> = [
        "serverRecipeId",
        "serverStepId",
        "serverStepIds",
        "serverIngredientId",
        "serverIngredientIds",
        "serverStepIngredientIds",
        "serverItemId",
        "serverItemIds",
        "serverCookbookId",
        "serverSpoonId",
        "shoppingRecipeIngredients"
    ]

    private static let resourceIdentifierValueKeys: Set<String> = [
        "recipeId",
        "stepId",
        "inputStepId",
        "ingredientId",
        "cookbookId",
        "itemId",
        "spoonId",
        "coverId",
        "replacementCoverId",
        "deviceId",
        "draftId"
    ]
}

extension NativeQueuedMutation {
    var mutatesRecipeCache: Bool {
        switch queueableKind {
        case .recipeCreate,
             .recipeUpdate,
             .recipeDelete,
             .recipeStepCreate,
             .recipeStepUpdate,
             .recipeStepDelete,
             .recipeStepReorder,
             .recipeIngredientAdd,
             .recipeIngredientDelete,
             .recipeOutputUsesReplace,
             .spoonCreate,
             .spoonCreatePhoto,
             .spoonUpdate,
             .spoonDelete,
             .coverSetNoCover,
             .coverSetActive:
            return true
        case .coverArchive:
            return boolValue("confirmNoCover") == true || optionalStringValue("replacementCoverId") != nil
        case .coverFromSpoon:
            return boolValue("activate") == true
        case .coverRegenerate:
            return boolValue("activateWhenReady") == true
        default:
            return false
        }
    }

    var mutatesShoppingCache: Bool {
        switch queueableKind {
        case .shoppingAddItem,
             .shoppingCheckItem,
             .shoppingDeleteItem,
             .shoppingAddFromRecipe,
             .shoppingClearCompleted,
             .shoppingClearAll:
            return true
        default:
            return false
        }
    }

    var mutatesCookbookCache: Bool {
        switch queueableKind {
        case .cookbookCreate,
             .cookbookUpdate,
             .cookbookDelete,
             .cookbookAddRecipe,
             .cookbookRemoveRecipe:
            return true
        default:
            return false
        }
    }
}

extension NativeQueuedMutation {
    func applyingToRecipe(in recipes: [Recipe], updatedAt: String, update: (Recipe) -> Recipe) -> [Recipe] {
        guard let recipeID else {
            return recipes
        }
        return recipes.map { recipe in
            recipe.id == recipeID ? update(recipe).copy(updatedAt: updatedAt) : recipe
        }
    }

    func clearingActiveRecipeCover(in recipes: [Recipe], updatedAt: String) -> [Recipe] {
        applyingToRecipe(in: recipes, updatedAt: updatedAt) { recipe in
            recipe.copy(
                coverImageURL: .some(nil),
                coverProvenanceLabel: .some(nil),
                coverSourceType: .some(nil),
                coverVariant: .some(nil),
                updatedAt: updatedAt
            )
        }
    }

    func upsertingRecipe(_ recipe: Recipe, into recipes: [Recipe]) -> [Recipe] {
        guard recipes.contains(where: { $0.id == recipe.id }) else {
            return (recipes + [recipe]).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return recipes.map { $0.id == recipe.id ? recipe : $0 }
    }

    func optimisticCreatedRecipe(fallbackChef: ChefSummary, now: String) -> Recipe {
        let id = stringValue("serverRecipeId") ?? "recipe_local_\(clientMutationID)"
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: stringValue("title") ?? "Untitled Recipe",
            description: optionalStringValue("description"),
            servings: optionalStringValue("servings"),
            chef: fallbackChef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "Queued offline by \(fallbackChef.username) on Spoonjoy",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: createdAt,
            updatedAt: now,
            steps: stepsValue("steps").enumerated().map { index, step in
                optimisticStep(from: step, index: index + 1, now: now)
            },
            cookbooks: []
        )
    }

    func upsertingCookbook(_ cookbook: Cookbook, into cookbooks: [Cookbook]) -> [Cookbook] {
        guard cookbooks.contains(where: { $0.id == cookbook.id }) else {
            return (cookbooks + [cookbook]).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return cookbooks.map { $0.id == cookbook.id ? cookbook : $0 }
    }

    func optimisticCreatedCookbook(fallbackChef: ChefSummary, now: String) -> Cookbook {
        let id = optimisticCookbookID ?? "cookbook_local_\(clientMutationID)"
        let title = stringValue("title") ?? "Untitled Cookbook"
        let canonicalURL = URL(string: "https://spoonjoy.app/cookbooks/\(id)")!
        return Cookbook(
            id: id,
            title: title,
            chef: fallbackChef,
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(
                creditText: "\(title) by \(fallbackChef.username) on Spoonjoy",
                canonicalURL: canonicalURL
            ),
            createdAt: createdAt,
            updatedAt: now,
            recipes: []
        )
    }

    func optimisticCreatedSpoon(for recipe: Recipe, fallbackChef: ChefSummary, now: String) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: stringValue("serverSpoonId") ?? "spoon_local_\(clientMutationID)",
            chefID: fallbackChef.id,
            recipeID: recipeID ?? recipe.id,
            cookedAt: optionalStringValue("cookedAt") ?? now,
            photoURL: optionalURLValue("photoUrl"),
            note: optionalStringValue("note"),
            nextTime: optionalStringValue("nextTime"),
            deletedAt: nil,
            createdAt: createdAt,
            updatedAt: now,
            chef: fallbackChef
        )
    }

    func updatedSpoon(_ spoon: RecipeDetailRecentSpoon, updatedAt: String) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: spoon.id,
            chefID: spoon.chefID,
            recipeID: spoon.recipeID,
            cookedAt: containsValue("cookedAt") ? optionalStringValue("cookedAt") : spoon.cookedAt,
            photoURL: containsValue("photoUrl") ? optionalURLValue("photoUrl") : spoon.photoURL,
            note: containsValue("note") ? optionalStringValue("note") : spoon.note,
            nextTime: containsValue("nextTime") ? optionalStringValue("nextTime") : spoon.nextTime,
            deletedAt: spoon.deletedAt,
            createdAt: spoon.createdAt,
            updatedAt: updatedAt,
            chef: spoon.chef
        )
    }

    func optimisticStep(now: String) -> RecipeStep {
        let stepNum = intValue("stepNum") ?? 1
        return RecipeStep(
            id: stringValue("serverStepId") ?? "step_local_\(clientMutationID)",
            stepNum: stepNum,
            stepTitle: optionalStringValue("stepTitle"),
            description: stringValue("description") ?? "",
            duration: intValue("duration"),
            ingredients: ingredientsValue("ingredients").enumerated().map { index, ingredient in
                optimisticIngredient(from: ingredient, index: index + 1)
            },
            usingSteps: outputUses(inputStepNum: stepNum, recipe: nil)
        )
    }

    func optimisticStep(from value: JSONValue, index: Int, now _: String) -> RecipeStep {
        guard case .object(let object) = value else {
            return RecipeStep(id: serverStepID(at: index) ?? "step_local_\(clientMutationID)_\(index)", stepNum: index, stepTitle: nil, description: "", duration: nil, ingredients: [])
        }
        let stepNum = intValue("stepNum", in: object) ?? index
        return RecipeStep(
            id: serverStepID(at: index) ?? "step_local_\(clientMutationID)_\(index)",
            stepNum: stepNum,
            stepTitle: optionalStringValue("stepTitle", in: object),
            description: stringValue("description", in: object) ?? "",
            duration: intValue("duration", in: object),
            ingredients: ingredientsValue("ingredients", in: object).enumerated().map { ingredientIndex, ingredient in
                optimisticIngredient(from: ingredient, stepIndex: index, ingredientIndex: ingredientIndex + 1)
            },
            usingSteps: outputUses(inputStepNum: stepNum, outputStepNums: intArrayValue("outputStepNums", in: object), recipe: nil)
        )
    }

    func optimisticIngredient() -> RecipeIngredient {
        RecipeIngredient(
            id: stringValue("serverIngredientId") ?? "ingredient_local_\(clientMutationID)",
            name: stringValue("name") ?? "",
            quantity: doubleValue("quantity") ?? 1,
            unit: optionalStringValue("unit")
        )
    }

    func optimisticIngredient(from value: JSONValue, index: Int) -> RecipeIngredient {
        guard case .object(let object) = value else {
            return RecipeIngredient(id: serverIngredientID(at: index) ?? "ingredient_local_\(clientMutationID)_\(index)", name: "", quantity: 1, unit: nil)
        }
        return RecipeIngredient(
            id: serverIngredientID(at: index) ?? "ingredient_local_\(clientMutationID)_\(index)",
            name: stringValue("name", in: object) ?? "",
            quantity: doubleValue("quantity", in: object) ?? 1,
            unit: optionalStringValue("unit", in: object)
        )
    }

    func optimisticIngredient(from value: JSONValue, stepIndex: Int, ingredientIndex: Int) -> RecipeIngredient {
        let id = serverIngredientID(stepIndex: stepIndex, ingredientIndex: ingredientIndex)
            ?? "ingredient_local_\(clientMutationID)_\(stepIndex)_\(ingredientIndex)"
        guard case .object(let object) = value else {
            return RecipeIngredient(id: id, name: "", quantity: 1, unit: nil)
        }
        return RecipeIngredient(
            id: id,
            name: stringValue("name", in: object) ?? "",
            quantity: doubleValue("quantity", in: object) ?? 1,
            unit: optionalStringValue("unit", in: object)
        )
    }

    func outputUses(inputStepNum: Int, recipe: Recipe?) -> [RecipeStepOutputUse] {
        outputUses(inputStepNum: inputStepNum, outputStepNums: intArrayValue("outputStepNums"), recipe: recipe)
    }

    func outputUses(inputStepNum: Int, outputStepNums: [Int], recipe: Recipe?) -> [RecipeStepOutputUse] {
        outputStepNums.filter { $0 < inputStepNum }.uniqued().map { outputStepNum in
            let source = recipe?.steps.first { $0.stepNum == outputStepNum }
            return RecipeStepOutputUse(
                id: "use_local_\(clientMutationID)_\(inputStepNum)_\(outputStepNum)",
                inputStepNum: inputStepNum,
                outputStepNum: outputStepNum,
                outputOfStep: RecipeStepOutputReference(stepNum: outputStepNum, stepTitle: source?.stepTitle)
            )
        }
    }

    func optionalStringValue(_ key: String) -> String? {
        optionalStringValue(key, in: values)
    }

    func optionalURLValue(_ key: String) -> URL? {
        optionalStringValue(key).flatMap(URL.init(string:))
    }

    func containsValue(_ key: String) -> Bool {
        values[key] != nil
    }

    func optionalStringValue(_ key: String, in object: [String: JSONValue]) -> String? {
        guard let value = object[key] else {
            return nil
        }
        if case .null = value {
            return nil
        }
        guard case .string(let string) = value else {
            return nil
        }
        return string
    }

    func stringValue(_ key: String, in object: [String: JSONValue]) -> String? {
        guard case .string(let value)? = object[key] else {
            return nil
        }
        return value
    }

    func serverStepID(at oneBasedIndex: Int) -> String? {
        guard oneBasedIndex > 0,
              case .array(let values)? = values["serverStepIds"],
              values.indices.contains(oneBasedIndex - 1),
              case .string(let value) = values[oneBasedIndex - 1],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    func serverIngredientID(at oneBasedIndex: Int) -> String? {
        guard oneBasedIndex > 0,
              case .array(let values)? = values["serverIngredientIds"],
              values.indices.contains(oneBasedIndex - 1),
              case .string(let value) = values[oneBasedIndex - 1],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    func serverIngredientID(stepIndex: Int, ingredientIndex: Int) -> String? {
        guard stepIndex > 0,
              ingredientIndex > 0,
              case .array(let stepValues)? = values["serverStepIngredientIds"],
              stepValues.indices.contains(stepIndex - 1),
              case .array(let ingredientValues) = stepValues[stepIndex - 1],
              ingredientValues.indices.contains(ingredientIndex - 1),
              case .string(let value) = ingredientValues[ingredientIndex - 1],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    func intValue(_ key: String) -> Int? {
        intValue(key, in: values)
    }

    func intValue(_ key: String, in object: [String: JSONValue]) -> Int? {
        guard case .number(let value)? = object[key], value.rounded() == value else {
            return nil
        }
        return Int(value)
    }

    func doubleValue(_ key: String) -> Double? {
        doubleValue(key, in: values)
    }

    func doubleValue(_ key: String, in object: [String: JSONValue]) -> Double? {
        guard case .number(let value)? = object[key] else {
            return nil
        }
        return value
    }

    func boolValue(_ key: String) -> Bool? {
        guard case .bool(let value)? = values[key] else {
            return nil
        }
        return value
    }

    func optimisticShoppingListBase(
        _ shoppingList: ShoppingListState?,
        fallbackChef: ChefSummary,
        now: String
    ) -> ShoppingListState {
        shoppingList ?? ShoppingListState(
            id: "native-shopping-list",
            chef: fallbackChef,
            items: [],
            nextCursor: "",
            updatedAt: now
        )
    }

    func removingShoppingItems(
        from shoppingList: ShoppingListState?,
        deletedAt: String,
        matching predicate: (ShoppingListItem) -> Bool
    ) -> ShoppingListState? {
        guard var updated = shoppingList else {
            return nil
        }

        for item in updated.activeItems where predicate(item) {
            updated = try! updated.removingItem(id: item.id, deletedAt: deletedAt)
        }

        return updated
    }

    func shoppingRecipeIngredientsForReplay(recipes: [Recipe]) -> [JSONValue] {
        let descriptors = shoppingRecipeIngredientsValue()
        if !descriptors.isEmpty {
            return descriptors
        }

        guard let recipeID = stringValue("recipeId"),
              let recipe = recipes.first(where: { $0.id == recipeID }) else {
            return []
        }

        let scaleFactor = doubleValue("scaleFactor") ?? 1
        return recipe.steps.flatMap(\.ingredients).map { ingredient in
            .object([
                "name": .string(ingredient.name),
                "quantity": .number(ingredient.quantity * scaleFactor),
                "unit": ingredient.unit.map(JSONValue.string) ?? .null
            ])
        }
    }

    func intArrayValue(_ key: String) -> [Int] {
        intArrayValue(key, in: values)
    }

    func intArrayValue(_ key: String, in object: [String: JSONValue]) -> [Int] {
        guard case .array(let values)? = object[key] else {
            return []
        }
        return values.compactMap { value in
            guard case .number(let number) = value, number.rounded() == number else {
                return nil
            }
            return Int(number)
        }
    }

    func stepsValue(_ key: String) -> [JSONValue] {
        guard case .array(let values)? = values[key] else {
            return []
        }
        return values
    }

    func ingredientsValue(_ key: String) -> [JSONValue] {
        ingredientsValue(key, in: values)
    }

    func ingredientsValue(_ key: String, in object: [String: JSONValue]) -> [JSONValue] {
        guard case .array(let values)? = object[key] else {
            return []
        }
        return values
    }

    func idRemaps(from responseData: JSONValue) -> [NativeSyncIDRemap] {
        switch queueableKind {
        case .recipeCreate:
            let recipe = responseData.objectValue("recipe") ?? [:]
            let requestSteps = stepsValue("steps")
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "recipe_local_\(clientMutationID)",
                serverID: recipe.stringValue("id") ?? responseData.objectStringValue("recipeId"),
                to: &remaps
            )
            for (responseIndex, step) in recipe.arrayValue("steps").enumerated() {
                let localStepIndex = localStepIndex(forResponseStep: step, fallbackIndex: responseIndex + 1)
                guard requestSteps.indices.contains(localStepIndex - 1) else {
                    continue
                }
                appendRemap(
                    localID: "step_local_\(clientMutationID)_\(localStepIndex)",
                    serverID: step.objectStringValue("id"),
                    to: &remaps
                )
                appendIngredientRemaps(
                    localIDPrefix: "ingredient_local_\(clientMutationID)_\(localStepIndex)",
                    requestIngredients: requestIngredients(forStepAt: localStepIndex - 1, in: requestSteps),
                    responseIngredients: step.objectArrayValue("ingredients"),
                    to: &remaps
                )
            }
            return remaps
        case .recipeStepCreate:
            let step = responseData.objectValue("step") ?? [:]
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "step_local_\(clientMutationID)",
                serverID: step.stringValue("id") ?? responseData.objectStringValue("stepId"),
                to: &remaps
            )
            appendIngredientRemaps(
                localIDPrefix: "ingredient_local_\(clientMutationID)",
                requestIngredients: ingredientsValue("ingredients"),
                responseIngredients: step.arrayValue("ingredients"),
                to: &remaps
            )
            return remaps
        case .recipeIngredientAdd:
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "ingredient_local_\(clientMutationID)",
                serverID: responseData.objectValue("ingredient")?.stringValue("id") ?? responseData.objectStringValue("ingredientId"),
                to: &remaps
            )
            return remaps
        case .shoppingAddItem:
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "item_local_\(clientMutationID)",
                serverID: responseData.objectValue("item")?.stringValue("id") ?? responseData.objectStringValue("itemId"),
                to: &remaps
            )
            return remaps
        case .shoppingAddFromRecipe:
            var remaps = [NativeSyncIDRemap]()
            let requestIngredients = shoppingRecipeIngredientsValue()
            let responseItems = responseData.objectArrayValue("items")
            if requestIngredients.isEmpty {
                for (index, item) in responseItems.enumerated() {
                    appendRemap(
                        localID: "item_local_\(clientMutationID)-ingredient-\(index + 1)",
                        serverID: item.objectStringValue("id"),
                        to: &remaps
                    )
                }
            } else {
                appendShoppingItemRemaps(
                    localIDPrefix: "item_local_\(clientMutationID)-ingredient",
                    requestIngredients: requestIngredients,
                    responseItems: responseItems,
                    to: &remaps
                )
            }
            return remaps
        case .cookbookCreate:
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "cookbook_local_\(clientMutationID)",
                serverID: responseData.objectValue("cookbook")?.stringValue("id") ?? responseData.objectStringValue("cookbookId"),
                to: &remaps
            )
            return remaps
        case .spoonCreate, .spoonCreatePhoto:
            var remaps = [NativeSyncIDRemap]()
            appendRemap(
                localID: "spoon_local_\(clientMutationID)",
                serverID: responseData.objectValue("spoon")?.stringValue("id") ?? responseData.objectStringValue("spoonId"),
                to: &remaps
            )
            return remaps
        default:
            return []
        }
    }

    func localStepIndex(forResponseStep step: JSONValue, fallbackIndex: Int) -> Int {
        guard case .object(let object) = step,
              let stepNum = intValue("stepNum", in: object),
              stepNum > 0 else {
            return fallbackIndex
        }
        return stepNum
    }

    func requestIngredients(forStepAt index: Int, in steps: [JSONValue]) -> [JSONValue] {
        guard steps.indices.contains(index),
              case .object(let object) = steps[index] else {
            return []
        }
        return ingredientsValue("ingredients", in: object)
    }

    func appendIngredientRemaps(
        localIDPrefix: String,
        requestIngredients: [JSONValue],
        responseIngredients: [JSONValue],
        to remaps: inout [NativeSyncIDRemap]
    ) {
        var usedResponseIndexes = Set<Int>()
        for (requestIndex, requestIngredient) in requestIngredients.enumerated() {
            appendRemap(
                localID: "\(localIDPrefix)_\(requestIndex + 1)",
                serverID: matchingResponseIngredientID(
                    for: requestIngredient,
                    in: responseIngredients,
                    usedResponseIndexes: &usedResponseIndexes
                ),
                to: &remaps
            )
        }
    }

    func appendShoppingItemRemaps(
        localIDPrefix: String,
        requestIngredients: [JSONValue],
        responseItems: [JSONValue],
        to remaps: inout [NativeSyncIDRemap]
    ) {
        var usedResponseIndexes = Set<Int>()
        for (requestIndex, requestIngredient) in requestIngredients.enumerated() {
            appendRemap(
                localID: "\(localIDPrefix)-\(requestIndex + 1)",
                serverID: matchingResponseShoppingItemID(
                    for: requestIngredient,
                    requestIngredients: requestIngredients,
                    in: responseItems,
                    usedResponseIndexes: &usedResponseIndexes
                ),
                to: &remaps
            )
        }
    }

    func matchingResponseIngredientID(
        for requestIngredient: JSONValue,
        in responseIngredients: [JSONValue],
        usedResponseIndexes: inout Set<Int>
    ) -> String? {
        guard case .object(let requestObject) = requestIngredient,
              let requestName = normalizedIngredientText(stringValue("name", in: requestObject) ?? stringValue("ingredientName", in: requestObject)),
              let requestUnit = normalizedIngredientText(optionalStringValue("unit", in: requestObject)),
              let requestQuantity = doubleValue("quantity", in: requestObject) else {
            return nil
        }

        for (responseIndex, responseIngredient) in responseIngredients.enumerated() where !usedResponseIndexes.contains(responseIndex) {
            guard case .object(let responseObject) = responseIngredient,
                  let serverID = responseObject.stringValue("id"),
                  let responseName = normalizedIngredientText(responseObject.stringValue("name")),
                  let responseUnit = normalizedIngredientText(responseObject.stringValue("unit")),
                  let responseQuantity = doubleValue("quantity", in: responseObject),
                  responseName == requestName,
                  responseUnit == requestUnit,
                  quantitiesMatch(responseQuantity, requestQuantity) else {
                continue
            }

            usedResponseIndexes.insert(responseIndex)
            return serverID
        }

        return nil
    }

    func matchingResponseShoppingItemID(
        for requestIngredient: JSONValue,
        requestIngredients: [JSONValue],
        in responseItems: [JSONValue],
        usedResponseIndexes: inout Set<Int>
    ) -> String? {
        guard case .object(let requestObject) = requestIngredient,
              let requestName = normalizedIngredientText(stringValue("name", in: requestObject)),
              let requestQuantity = doubleValue("quantity", in: requestObject) else {
            return nil
        }
        let requestUnit = normalizedOptionalIngredientText(optionalStringValue("unit", in: requestObject))

        for (responseIndex, responseItem) in responseItems.enumerated() where !usedResponseIndexes.contains(responseIndex) {
            guard case .object(let responseObject) = responseItem,
                  let serverID = responseObject.stringValue("id"),
                  let responseName = normalizedIngredientText(responseObject.stringValue("name")),
                  let responseQuantity = doubleValue("quantity", in: responseObject),
                  responseName == requestName,
                  normalizedOptionalIngredientText(responseObject.stringValue("unit")) == requestUnit,
                  quantitiesMatch(responseQuantity, requestQuantity) else {
                continue
            }

            usedResponseIndexes.insert(responseIndex)
            return serverID
        }

        guard let aggregateQuantity = aggregateShoppingQuantity(
            matchingName: requestName,
            matchingUnit: requestUnit,
            in: requestIngredients
        ) else {
            return nil
        }

        for responseItem in responseItems {
            guard case .object(let responseObject) = responseItem,
                  let serverID = responseObject.stringValue("id"),
                  let responseName = normalizedIngredientText(responseObject.stringValue("name")),
                  let responseQuantity = doubleValue("quantity", in: responseObject),
                  responseName == requestName,
                  normalizedOptionalIngredientText(responseObject.stringValue("unit")) == requestUnit,
                  quantitiesMatch(responseQuantity, aggregateQuantity) else {
                continue
            }

            return serverID
        }

        return nil
    }

    func aggregateShoppingQuantity(
        matchingName requestName: String,
        matchingUnit requestUnit: String?,
        in requestIngredients: [JSONValue]
    ) -> Double? {
        let matchingQuantities = requestIngredients.compactMap { ingredient -> Double? in
            guard case .object(let object) = ingredient,
                  normalizedIngredientText(stringValue("name", in: object)) == requestName,
                  normalizedOptionalIngredientText(optionalStringValue("unit", in: object)) == requestUnit else {
                return nil
            }
            return doubleValue("quantity", in: object)
        }

        guard matchingQuantities.count > 1 else {
            return nil
        }
        return matchingQuantities.reduce(0, +)
    }

    func normalizedIngredientText(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    func normalizedOptionalIngredientText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }

    func quantitiesMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_000_1
    }

    func appendRemap(localID: String, serverID: String?, to remaps: inout [NativeSyncIDRemap]) {
        guard let serverID,
              !serverID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              localID != serverID else {
            return
        }

        remaps.append(NativeSyncIDRemap(localID: localID, serverID: serverID))
    }

    func indexedServerShoppingItemIDs(from replacements: [String: String]) -> [JSONValue] {
        let prefix = "item_local_\(clientMutationID)-ingredient-"
        let indexedReplacements = replacements.compactMap { localID, serverID -> (Int, String)? in
            guard localID.hasPrefix(prefix),
                  let index = Int(localID.dropFirst(prefix.count)),
                  index > 0 else {
                return nil
            }
            return (index, serverID)
        }
        guard let maxIndex = indexedReplacements.map(\.0).max() else {
            return []
        }

        var serverItemIDs = Array(repeating: JSONValue.null, count: maxIndex)
        for (index, serverID) in indexedReplacements {
            serverItemIDs[index - 1] = .string(serverID)
        }
        return serverItemIDs
    }

    func serverShoppingItemID(at index: Int) -> String? {
        guard case .array(let serverItemIDs)? = values["serverItemIds"],
              serverItemIDs.indices.contains(index),
              case .string(let serverItemID) = serverItemIDs[index] else {
            return nil
        }
        return serverItemID
    }

    func shoppingRecipeIngredientsValue() -> [JSONValue] {
        arrayValue("shoppingRecipeIngredients")
    }

    func arrayValue(_ key: String) -> [JSONValue] {
        guard case .array(let array)? = values[key] else {
            return []
        }
        return array
    }
}

private extension JSONValue {
    static func encoded<Value: Encodable>(_ value: Value) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    func decoded<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }

    func objectValue(_ key: String) -> [String: JSONValue]? {
        guard case .object(let object) = self,
              case .object(let child)? = object[key] else {
            return nil
        }
        return child
    }

    func objectStringValue(_ key: String) -> String? {
        guard case .object(let object) = self else {
            return nil
        }
        return object.stringValue(key)
    }

    func objectArrayValue(_ key: String) -> [JSONValue] {
        guard case .object(let object) = self else {
            return []
        }
        return object.arrayValue(key)
    }

}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(_ key: String) -> String? {
        guard case .string(let value)? = self[key] else {
            return nil
        }
        return value
    }

    func arrayValue(_ key: String) -> [JSONValue] {
        guard case .array(let values)? = self[key] else {
            return []
        }
        return values
    }
}

private extension Recipe {
    func copy(
        title: String? = nil,
        description: String?? = nil,
        servings: String?? = nil,
        coverImageURL: URL?? = nil,
        coverProvenanceLabel: String?? = nil,
        coverSourceType: RecipeCoverSourceType?? = nil,
        coverVariant: RecipeCoverVariant?? = nil,
        updatedAt: String,
        steps: [RecipeStep]? = nil,
        recentSpoons: [RecipeDetailRecentSpoon]? = nil
    ) -> Recipe {
        Recipe(
            id: id,
            title: title ?? self.title,
            description: description ?? self.description,
            servings: servings ?? self.servings,
            chef: chef,
            coverImageURL: coverImageURL ?? self.coverImageURL,
            coverProvenanceLabel: coverProvenanceLabel ?? self.coverProvenanceLabel,
            coverSourceType: coverSourceType ?? self.coverSourceType,
            coverVariant: coverVariant ?? self.coverVariant,
            href: href,
            canonicalURL: canonicalURL,
            attribution: attribution,
            createdAt: createdAt,
            updatedAt: updatedAt,
            steps: steps ?? self.steps,
            cookbooks: cookbooks,
            recentSpoons: recentSpoons ?? self.recentSpoons
        )
    }
}

private extension Cookbook {
    func copy(title: String? = nil, updatedAt: String, recipes: [RecipeSummary]? = nil) -> Cookbook {
        let nextRecipes = recipes ?? self.recipes
        let nextTitle = title ?? self.title
        let nextCover = recipes.map { CookbookCover(imageURLs: $0.map(\.coverImageURL)) } ?? cover
        return Cookbook(
            id: id,
            title: nextTitle,
            chef: chef,
            recipeCount: nextRecipes.count,
            cover: nextCover,
            href: href,
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(
                creditText: "\(nextTitle) by \(chef.username) on Spoonjoy",
                canonicalURL: canonicalURL
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
            recipes: nextRecipes
        )
    }
}

private extension Array where Element == RecipeDetailRecentSpoon {
    func upsertingRecentSpoon(_ spoon: RecipeDetailRecentSpoon) -> [RecipeDetailRecentSpoon] {
        var remaining = filter { $0.id != spoon.id }
        remaining.insert(spoon, at: 0)
        return remaining.sorted {
            ($0.cookedAt ?? $0.createdAt) > ($1.cookedAt ?? $1.createdAt)
        }
    }

    func updatingRecentSpoon(
        id: String,
        update: (RecipeDetailRecentSpoon) -> RecipeDetailRecentSpoon
    ) -> [RecipeDetailRecentSpoon] {
        map { spoon in
            spoon.id == id ? update(spoon) : spoon
        }
    }

    func markingRecentSpoonDeleted(id: String, deletedAt: String) -> [RecipeDetailRecentSpoon] {
        updatingRecentSpoon(id: id) { spoon in
            RecipeDetailRecentSpoon(
                id: spoon.id,
                chefID: spoon.chefID,
                recipeID: spoon.recipeID,
                cookedAt: spoon.cookedAt,
                photoURL: spoon.photoURL,
                note: spoon.note,
                nextTime: spoon.nextTime,
                deletedAt: deletedAt,
                createdAt: spoon.createdAt,
                updatedAt: deletedAt,
                chef: spoon.chef
            )
        }
    }
}

private extension RecipeStep {
    func copy(
        stepNum: Int? = nil,
        stepTitle: String?? = nil,
        description: String? = nil,
        duration: Int?? = nil,
        ingredients: [RecipeIngredient]? = nil,
        usingSteps: [RecipeStepOutputUse]? = nil
    ) -> RecipeStep {
        RecipeStep(
            id: id,
            stepNum: stepNum ?? self.stepNum,
            stepTitle: stepTitle ?? self.stepTitle,
            description: description ?? self.description,
            duration: duration ?? self.duration,
            ingredients: ingredients ?? self.ingredients,
            usingSteps: usingSteps ?? self.usingSteps
        )
    }
}

private extension [RecipeStep] {
    func sortedByStepNumber() -> [RecipeStep] {
        sorted { left, right in
            if left.stepNum == right.stepNum {
                return left.id < right.id
            }
            return left.stepNum < right.stepNum
        }
    }

    func inserting(
        _ step: RecipeStep,
        outputStepNumsForInsertedStep outputStepNums: [Int],
        clientMutationID: String
    ) -> [RecipeStep] {
        var steps = sortedByStepNumber()
        let oldStepIDByStepNum = steps.stepIDByStepNum()
        let existingStepIDs = Set(steps.map(\.id))
        let boundedStepNum = Swift.min(Swift.max(step.stepNum, 1), steps.count + 1)
        steps.insert(step.copy(stepNum: boundedStepNum, usingSteps: []), at: boundedStepNum - 1)
        var renumbered = steps.renumberedRemappingOutputUses(
            oldStepIDByStepNum: oldStepIDByStepNum,
            remappedStepIDs: existingStepIDs,
            clientMutationID: clientMutationID
        )
        if let insertedIndex = renumbered.firstIndex(where: { $0.id == step.id }) {
            let inputStepNum = renumbered[insertedIndex].stepNum
            renumbered[insertedIndex] = renumbered[insertedIndex].copy(
                usingSteps: renumbered.outputUses(
                    inputStepNum: inputStepNum,
                    outputStepNums: outputStepNums,
                    clientMutationID: clientMutationID
                )
            )
        }
        return renumbered
    }

    func deleting(stepID: String, clientMutationID: String) -> [RecipeStep] {
        let steps = sortedByStepNumber()
        let oldStepIDByStepNum = steps.stepIDByStepNum()
        let remaining = steps.filter { $0.id != stepID }
        return remaining.renumberedRemappingOutputUses(
            oldStepIDByStepNum: oldStepIDByStepNum,
            remappedStepIDs: Set(remaining.map(\.id)),
            clientMutationID: clientMutationID
        )
    }

    func reordered(stepID: String, toStepNum: Int, clientMutationID: String) -> [RecipeStep] {
        var steps = sortedByStepNumber()
        let oldStepIDByStepNum = steps.stepIDByStepNum()
        guard let currentIndex = steps.firstIndex(where: { $0.id == stepID }) else {
            return steps
        }

        let moving = steps.remove(at: currentIndex)
        let boundedStepNum = Swift.min(Swift.max(toStepNum, 1), steps.count + 1)
        steps.insert(moving, at: boundedStepNum - 1)
        return steps.renumberedRemappingOutputUses(
            oldStepIDByStepNum: oldStepIDByStepNum,
            remappedStepIDs: Set(steps.map(\.id)),
            clientMutationID: clientMutationID
        )
    }

    private func renumberedRemappingOutputUses(
        oldStepIDByStepNum: [Int: String],
        remappedStepIDs: Set<String>,
        clientMutationID: String
    ) -> [RecipeStep] {
        let numbered = enumerated().map { index, step in
            step.copy(stepNum: index + 1)
        }
        var newStepNumByID: [String: Int] = [:]
        for step in numbered {
            newStepNumByID[step.id] = step.stepNum
        }
        return numbered.map { step in
            guard remappedStepIDs.contains(step.id) else {
                return step
            }

            let remappedOutputStepNums = step.usingSteps.compactMap { outputUse -> Int? in
                guard let outputStepID = oldStepIDByStepNum[outputUse.outputStepNum],
                      let newOutputStepNum = newStepNumByID[outputStepID],
                      newOutputStepNum < step.stepNum else {
                    return nil
                }
                return newOutputStepNum
            }
            return step.copy(usingSteps: numbered.outputUses(
                inputStepNum: step.stepNum,
                outputStepNums: remappedOutputStepNums,
                clientMutationID: clientMutationID
            ))
        }
    }

    private func outputUses(inputStepNum: Int, outputStepNums: [Int], clientMutationID: String) -> [RecipeStepOutputUse] {
        outputStepNums
            .filter { $0 < inputStepNum }
            .uniqued()
            .map { outputStepNum in
                let source = first { $0.stepNum == outputStepNum }
                return RecipeStepOutputUse(
                    id: "use_local_\(clientMutationID)_\(inputStepNum)_\(outputStepNum)",
                    inputStepNum: inputStepNum,
                    outputStepNum: outputStepNum,
                    outputOfStep: RecipeStepOutputReference(stepNum: outputStepNum, stepTitle: source?.stepTitle)
                )
            }
    }

    private func stepIDByStepNum() -> [Int: String] {
        var stepIDByStepNum: [Int: String] = [:]
        for step in self {
            stepIDByStepNum[step.stepNum] = step.id
        }
        return stepIDByStepNum
    }
}

private extension Array where Element == Int {
    func uniqued() -> [Int] {
        var seen = Set<Int>()
        return sorted().filter { seen.insert($0).inserted }
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

    static func shoppingAddFromRecipe(
        recipeID: String,
        scaleFactor: Double,
        recipeIngredients: [RecipeIngredient] = [],
        clientMutationID: String,
        createdAt: String
    ) -> NativeQueuedMutation {
        var values: [String: JSONValue] = [
            "recipeId": .string(recipeID),
            "scaleFactor": .number(scaleFactor)
        ]
        if !recipeIngredients.isEmpty {
            values["shoppingRecipeIngredients"] = .array(recipeIngredients.map { ingredient in
                .object([
                    "name": .string(ingredient.name),
                    "quantity": .number(ingredient.quantity * scaleFactor),
                    "unit": stringOrNull(ingredient.unit)
                ])
            })
        }
        return NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingAddFromRecipe, values: values)
    }

    static func shoppingClearCompleted(clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingClearCompleted)
    }

    static func shoppingClearAll(clientMutationID: String, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .shoppingClearAll)
    }

    static func intentMutation(from mutation: QueuedMutation) throws -> NativeQueuedMutation {
        switch mutation.kind {
        case .shoppingAdd(let name, let quantity, let unit, let categoryKey, let iconKey):
            NativeQueuedMutation.shoppingAddItem(
                name: name,
                quantity: quantity,
                unit: unit,
                categoryKey: categoryKey,
                iconKey: iconKey,
                clientMutationID: mutation.clientMutationID,
                createdAt: mutation.createdAt
            )
        case .shoppingCheck(let itemID, let checked):
            NativeQueuedMutation.shoppingCheckItem(
                itemID: itemID,
                checked: checked,
                clientMutationID: mutation.clientMutationID,
                createdAt: mutation.createdAt
            )
        case .shoppingDelete(let itemID):
            NativeQueuedMutation.shoppingDeleteItem(
                itemID: itemID,
                clientMutationID: mutation.clientMutationID,
                createdAt: mutation.createdAt
            )
        }
    }

    static func spoonCreate(recipeID: String, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, photoURL: String?, useAsRecipeCover: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonCreate, values: ["recipeId": .string(recipeID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "photoUrl": stringOrNull(photoURL), "useAsRecipeCover": .bool(useAsRecipeCover)])
    }

    static func spoonCreatePhoto(recipeID: String, photo: NativeStagedMediaUpload, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, useAsRecipeCover: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonCreatePhoto, values: ["recipeId": .string(recipeID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "useAsRecipeCover": .bool(useAsRecipeCover)], media: ["photo": photo])
    }

    static func spoonUpdate(recipeID: String, spoonID: String, clientMutationID: String, note: String?, nextTime: String?, cookedAt: String?, photoURL: String?, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .spoonUpdate, values: ["recipeId": .string(recipeID), "spoonId": .string(spoonID), "note": stringOrNull(note), "nextTime": stringOrNull(nextTime), "cookedAt": stringOrNull(cookedAt), "photoUrl": stringOrNull(photoURL)])
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

    static func coverSetNoCover(recipeID: String, clientMutationID: String, confirmNoCover: Bool, createdAt: String) -> NativeQueuedMutation {
        NativeQueuedMutation(clientMutationID: clientMutationID, createdAt: createdAt, queueableKind: .coverSetNoCover, values: ["recipeId": .string(recipeID), "confirmNoCover": .bool(confirmNoCover)])
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
                "ingredients": ingredientDrafts(step.ingredients),
                "outputStepNums": .array(step.outputStepNums.map { .number(Double($0)) })
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

    func saveStagedMedia(to directory: NativeStagedMediaDirectory?) throws {
        guard let directory else {
            return
        }
        for upload in media.values where !upload.data.isEmpty {
            try directory.save(upload)
        }
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

    public func appending(contentsOf nextMutations: [NativeQueuedMutation]) throws -> NativeMutationQueue {
        try NativeMutationQueue(mutations: mutations + nextMutations)
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
        trigger: NativeCacheRevalidationTrigger,
        scope: NativeSyncExecutionScope
    ) async throws -> NativeSyncReport
}

public struct NativeSyncExecutionScope: Equatable, Sendable {
    public let expectedAccountID: String?
    public let environment: NativeCacheEnvironment?

    public static let unbound = NativeSyncExecutionScope(expectedAccountID: nil, environment: nil)

    public init(expectedAccountID: String?, environment: NativeCacheEnvironment?) {
        self.expectedAccountID = expectedAccountID
        self.environment = environment
    }
}

public struct NativeSyncTriggerCoordinator: Sendable {
    private let runner: any NativeSyncTriggerRunning
    private let configuration: APIClientConfiguration
    private let scope: NativeSyncExecutionScope

    public init(
        runner: any NativeSyncTriggerRunning,
        configuration: APIClientConfiguration,
        scope: NativeSyncExecutionScope = .unbound
    ) {
        self.runner = runner
        self.configuration = configuration
        self.scope = scope
    }

    @discardableResult
    public func handle(_ event: NativeSyncTriggerEvent) async throws -> NativeSyncReport {
        try await runner.bootstrapAndDrain(configuration: configuration, trigger: event.cacheTrigger, scope: scope)
    }

    public func scoped(
        configuration: APIClientConfiguration,
        scope: NativeSyncExecutionScope
    ) -> NativeSyncTriggerCoordinator {
        NativeSyncTriggerCoordinator(runner: runner, configuration: configuration, scope: scope)
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
    case optimistic(String)
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

public enum NativeSyncMutationBlocker: Equatable, Sendable {
    case providerSecret(resourceID: String)
}

public struct NativeSyncReport: Equatable, Sendable {
    public let trigger: NativeCacheRevalidationTrigger
    public let bootstrapCursor: PaginationCursor?
    public let accountID: String?
    public let environment: NativeCacheEnvironment?
    public let shoppingEntityPurgeIdentifiers: [String]
    public let shoppingEntityPurgeDomainIdentifiers: [String]
    public let shoppingEntityPurgeRequests: [NativeShoppingEntityIndexPurgeRequest]
    public let spoonEntityPurgeIdentifiers: [String]
    public let spoonEntityPurgeDomainIdentifiers: [String]
    public let spoonEntityPurgeRequests: [NativeSpoonEntityIndexPurgeRequest]
    public let captureDraftEntityPurgeIdentifiers: [String]
    public let captureDraftEntityPurgeDomainIdentifiers: [String]
    public let captureDraftEntityPurgeRequests: [NativeCaptureDraftEntityIndexPurgeRequest]
    public let chefProfileEntityPurgeIdentifiers: [String]
    public let chefProfileEntityPurgeDomainIdentifiers: [String]
    public let chefProfileEntityPurgeRequests: [NativeChefProfileEntityIndexPurgeRequest]
    public let recipeCookbookEntityPurgeIdentifiers: [String]
    public let recipeCookbookEntityPurgeDomainIdentifiers: [String]
    public let recipeCookbookEntityPurgeRequests: [NativeRecipeCookbookEntityIndexPurgeRequest]
    public let drainedClientMutationIDs: [String]
    public let drainedMutations: [NativeQueuedMutation]
    public let conflicts: [NativeSyncConflict]
    public let blockers: [NativeSyncMutationBlocker]
    public let pausedReason: NativeSyncPauseReason?
    public let retryAfterSeconds: Int?

    public init(
        trigger: NativeCacheRevalidationTrigger,
        bootstrapCursor: PaginationCursor?,
        accountID: String? = nil,
        environment: NativeCacheEnvironment? = nil,
        shoppingEntityPurgeIdentifiers: [String] = [],
        shoppingEntityPurgeDomainIdentifiers: [String] = [],
        shoppingEntityPurgeRequests: [NativeShoppingEntityIndexPurgeRequest] = [],
        spoonEntityPurgeIdentifiers: [String] = [],
        spoonEntityPurgeDomainIdentifiers: [String] = [],
        spoonEntityPurgeRequests: [NativeSpoonEntityIndexPurgeRequest] = [],
        captureDraftEntityPurgeIdentifiers: [String] = [],
        captureDraftEntityPurgeDomainIdentifiers: [String] = [],
        captureDraftEntityPurgeRequests: [NativeCaptureDraftEntityIndexPurgeRequest] = [],
        chefProfileEntityPurgeIdentifiers: [String] = [],
        chefProfileEntityPurgeDomainIdentifiers: [String] = [],
        chefProfileEntityPurgeRequests: [NativeChefProfileEntityIndexPurgeRequest] = [],
        recipeCookbookEntityPurgeIdentifiers: [String] = [],
        recipeCookbookEntityPurgeDomainIdentifiers: [String] = [],
        recipeCookbookEntityPurgeRequests: [NativeRecipeCookbookEntityIndexPurgeRequest] = [],
        drainedClientMutationIDs: [String],
        drainedMutations: [NativeQueuedMutation] = [],
        conflicts: [NativeSyncConflict],
        blockers: [NativeSyncMutationBlocker] = [],
        pausedReason: NativeSyncPauseReason?,
        retryAfterSeconds: Int?
    ) {
        self.trigger = trigger
        self.bootstrapCursor = bootstrapCursor
        self.accountID = accountID
        self.environment = environment
        self.shoppingEntityPurgeIdentifiers = shoppingEntityPurgeIdentifiers
        self.shoppingEntityPurgeDomainIdentifiers = shoppingEntityPurgeDomainIdentifiers
        self.shoppingEntityPurgeRequests = Self.purgeRequests(
            explicit: shoppingEntityPurgeRequests,
            fallbackIdentifiers: shoppingEntityPurgeIdentifiers,
            fallbackDomainIdentifiers: shoppingEntityPurgeDomainIdentifiers,
            accountID: accountID,
            environment: environment,
            makeRequest: { NativeShoppingEntityIndexPurgeRequest(identifiers: $0, domainIdentifiers: $1, accountID: $2, environment: $3) }
        )
        self.spoonEntityPurgeIdentifiers = spoonEntityPurgeIdentifiers
        self.spoonEntityPurgeDomainIdentifiers = spoonEntityPurgeDomainIdentifiers
        self.spoonEntityPurgeRequests = Self.purgeRequests(
            explicit: spoonEntityPurgeRequests,
            fallbackIdentifiers: spoonEntityPurgeIdentifiers,
            fallbackDomainIdentifiers: spoonEntityPurgeDomainIdentifiers,
            accountID: accountID,
            environment: environment,
            makeRequest: { NativeSpoonEntityIndexPurgeRequest(identifiers: $0, domainIdentifiers: $1, accountID: $2, environment: $3) }
        )
        self.captureDraftEntityPurgeIdentifiers = captureDraftEntityPurgeIdentifiers
        self.captureDraftEntityPurgeDomainIdentifiers = captureDraftEntityPurgeDomainIdentifiers
        self.captureDraftEntityPurgeRequests = Self.purgeRequests(
            explicit: captureDraftEntityPurgeRequests,
            fallbackIdentifiers: captureDraftEntityPurgeIdentifiers,
            fallbackDomainIdentifiers: captureDraftEntityPurgeDomainIdentifiers,
            accountID: accountID,
            environment: environment,
            makeRequest: { NativeCaptureDraftEntityIndexPurgeRequest(identifiers: $0, domainIdentifiers: $1, accountID: $2, environment: $3) }
        )
        self.chefProfileEntityPurgeIdentifiers = chefProfileEntityPurgeIdentifiers
        self.chefProfileEntityPurgeDomainIdentifiers = chefProfileEntityPurgeDomainIdentifiers
        self.chefProfileEntityPurgeRequests = Self.purgeRequests(
            explicit: chefProfileEntityPurgeRequests,
            fallbackIdentifiers: chefProfileEntityPurgeIdentifiers,
            fallbackDomainIdentifiers: chefProfileEntityPurgeDomainIdentifiers,
            accountID: accountID,
            environment: environment,
            makeRequest: { NativeChefProfileEntityIndexPurgeRequest(identifiers: $0, domainIdentifiers: $1, accountID: $2, environment: $3) }
        )
        self.recipeCookbookEntityPurgeIdentifiers = recipeCookbookEntityPurgeIdentifiers
        self.recipeCookbookEntityPurgeDomainIdentifiers = recipeCookbookEntityPurgeDomainIdentifiers
        self.recipeCookbookEntityPurgeRequests = Self.purgeRequests(
            explicit: recipeCookbookEntityPurgeRequests,
            fallbackIdentifiers: recipeCookbookEntityPurgeIdentifiers,
            fallbackDomainIdentifiers: recipeCookbookEntityPurgeDomainIdentifiers,
            accountID: accountID,
            environment: environment,
            makeRequest: { NativeRecipeCookbookEntityIndexPurgeRequest(identifiers: $0, domainIdentifiers: $1, accountID: $2, environment: $3) }
        )
        self.drainedClientMutationIDs = drainedClientMutationIDs
        self.drainedMutations = drainedMutations
        self.conflicts = conflicts
        self.blockers = blockers
        self.pausedReason = pausedReason
        self.retryAfterSeconds = retryAfterSeconds
    }

    private static func purgeRequests<Request>(
        explicit: [Request],
        fallbackIdentifiers: [String],
        fallbackDomainIdentifiers: [String],
        accountID: String?,
        environment: NativeCacheEnvironment?,
        makeRequest: (_ identifiers: [String], _ domainIdentifiers: [String], _ accountID: String?, _ environment: NativeCacheEnvironment?) -> Request
    ) -> [Request] {
        guard explicit.isEmpty,
              !fallbackIdentifiers.isEmpty || !fallbackDomainIdentifiers.isEmpty else {
            return explicit
        }
        return [makeRequest(fallbackIdentifiers, fallbackDomainIdentifiers, accountID, environment)]
    }
}

public enum NativeSyncBootstrapResult: Equatable, Sendable {
    case success(cursor: PaginationCursor?, tombstones: [NativeSyncTombstone])
    case syncData(NativeSyncData)
}

public enum NativeSyncBootstrapPagingError: Error, Equatable, Sendable {
    case missingNextCursor(page: Int)
    case repeatedCursor(String, page: Int)
}

private struct NativeSyncBootstrapApplication: Sendable {
    var cursor: PaginationCursor?
    var accountID: String?
    var environment: NativeCacheEnvironment?
    var tombstones: [NativeSyncTombstone] = []
    var removedCacheKeys: [String] = []
    var pagesApplied: Int = 0
    var entriesApplied: Int = 0
    var kindCounts: [NativeSyncEntryKind: Int] = [:]

    mutating func recordPage(syncData: NativeSyncData, applyResult: NativeSyncApplyResult) {
        cursor = syncData.nextCursor
        accountID = syncData.freshness.accountID
        environment = syncData.freshness.environment
        tombstones.append(contentsOf: applyResult.tombstones)
        removedCacheKeys.append(contentsOf: applyResult.removedCacheKeys)
        pagesApplied += 1
        entriesApplied += syncData.entries.count
        for entry in syncData.entries {
            kindCounts[entry.kind, default: 0] += 1
        }
    }

    mutating func recordLegacy(cursor: PaginationCursor?, tombstones: [NativeSyncTombstone]) {
        self.cursor = cursor
        self.tombstones.append(contentsOf: tombstones)
    }
}

private enum NativeSyncTelemetry {
#if canImport(OSLog)
    private static let logger = Logger(subsystem: "app.spoonjoy", category: "sync")
#endif

    static func bootstrapStarted(
        trigger: NativeCacheRevalidationTrigger,
        cursor: PaginationCursor?,
        scope: NativeSyncExecutionScope
    ) {
#if canImport(OSLog)
        logger.info(
            "native_sync_bootstrap_started trigger=\(trigger.rawValue, privacy: .public) cursor_present=\(cursor != nil, privacy: .public) scope_account_bound=\(scope.expectedAccountID != nil, privacy: .public) scope_environment=\(scope.environment?.rawValue ?? "unbound", privacy: .public)"
        )
#endif
    }

    static func bootstrapPageApplied(
        trigger: NativeCacheRevalidationTrigger,
        page: Int,
        syncData: NativeSyncData,
        applyResult: NativeSyncApplyResult
    ) {
#if canImport(OSLog)
        logger.info(
            "native_sync_bootstrap_page_applied trigger=\(trigger.rawValue, privacy: .public) page=\(page, privacy: .public) account_id=\(syncData.freshness.accountID, privacy: .public) environment=\(syncData.freshness.environment.rawValue, privacy: .public) entries=\(syncData.entries.count, privacy: .public) removed=\(applyResult.removedCacheKeys.count, privacy: .public) tombstones=\(applyResult.tombstones.count, privacy: .public) has_more=\(syncData.hasMore, privacy: .public) next_cursor_present=\(syncData.nextCursor != nil, privacy: .public) kind_counts=\(kindCountsSummary(syncData.entries), privacy: .public)"
        )
#endif
    }

    static func bootstrapCompleted(
        trigger: NativeCacheRevalidationTrigger,
        application: NativeSyncBootstrapApplication
    ) {
#if canImport(OSLog)
        logger.info(
            "native_sync_bootstrap_completed trigger=\(trigger.rawValue, privacy: .public) pages=\(application.pagesApplied, privacy: .public) entries=\(application.entriesApplied, privacy: .public) account_id=\(application.accountID ?? "none", privacy: .public) environment=\(application.environment?.rawValue ?? "none", privacy: .public) final_cursor_present=\(application.cursor != nil, privacy: .public) tombstones=\(application.tombstones.count, privacy: .public) removed=\(application.removedCacheKeys.count, privacy: .public) kind_counts=\(kindCountsSummary(application.kindCounts), privacy: .public)"
        )
#endif
    }

    static func bootstrapFailed(
        trigger: NativeCacheRevalidationTrigger,
        page: Int,
        error: Error
    ) {
#if canImport(OSLog)
        let context = errorContext(error)
        logger.error(
            "native_sync_bootstrap_failed trigger=\(trigger.rawValue, privacy: .public) page=\(page, privacy: .public) error_type=\(context.type, privacy: .public) request_id=\(context.requestID, privacy: .public) status=\(context.status, privacy: .public) code=\(context.code, privacy: .public) retry=\(context.retry, privacy: .public)"
        )
#endif
    }

#if canImport(OSLog)
    private static func kindCountsSummary(_ entries: [NativeSyncEntry]) -> String {
        kindCountsSummary(Dictionary(grouping: entries, by: \.kind).mapValues(\.count))
    }

    private static func kindCountsSummary(_ counts: [NativeSyncEntryKind: Int]) -> String {
        counts
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue):\($0.value)" }
            .joined(separator: ",")
    }

    private static func errorContext(_ error: Error) -> (type: String, requestID: String, status: String, code: String, retry: String) {
        let type = String(describing: Swift.type(of: error))
        guard let transportError = error as? APITransportError else {
            return (type, "none", "none", "none", "none")
        }

        let retry: String
        switch transportError.retryDecision {
        case .retrySameRequest(let afterSeconds):
            retry = afterSeconds.map { "retry_same_request:\($0)" } ?? "retry_same_request"
        case .refreshAuthentication:
            retry = "refresh_authentication"
        case .doNotRetry:
            retry = "do_not_retry"
        }

        return (
            type,
            transportError.requestID ?? transportError.apiError?.requestID ?? "none",
            transportError.statusCode.map(String.init) ?? "none",
            transportError.apiError?.code ?? "none",
            retry
        )
    }
#endif
}

public struct NativeSyncIDRemap: Equatable, Sendable {
    public let localID: String
    public let serverID: String

    public init(localID: String, serverID: String) {
        self.localID = localID
        self.serverID = serverID
    }
}

public enum NativeSyncMutationResult: Equatable, Sendable {
    case success(serverRevision: NativeServerRevision?, idRemaps: [NativeSyncIDRemap] = [])
    case conflict(kind: NativeSyncConflictKind, serverRevision: NativeServerRevision?, message: String)
    case authFailure(message: String)
    case blocked(NativeSyncMutationBlocker, message: String)
    case retry(afterSeconds: Int, message: String)
}

public protocol NativeSyncTransport: Sendable {
    func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult
    func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult
}

public struct URLSessionNativeSyncTransport: NativeSyncTransport {
    private let apiTransport: URLSessionAPITransport

    public init(apiTransport: URLSessionAPITransport = URLSessionAPITransport()) {
        self.apiTransport = apiTransport
    }

    public func bootstrap(request: APIRequest, configuration: APIClientConfiguration) async throws -> NativeSyncBootstrapResult {
        let envelope = try await apiTransport.send(
            request,
            configuration: configuration,
            decode: NativeSyncData.self
        )
        return .syncData(envelope.data)
    }

    public func send(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        do {
            if mutation.queueableKind == .recipeImportSubmit {
                return try await sendRecipeImportSubmit(mutation, configuration: configuration)
            }
            if mutation.queueableKind == .coverRegenerate || mutation.queueableKind == .coverFromSpoon {
                return try await sendProviderCoverMutation(mutation, configuration: configuration)
            }
            let envelope = try await apiTransport.send(
                try mutation.requestBuilder(),
                configuration: configuration,
                decode: JSONValue.self
            )
            return .success(serverRevision: nil, idRemaps: mutation.idRemaps(from: envelope.data))
        } catch let error as APITransportError {
            return try Self.mutationResult(for: error, mutation: mutation)
        }
    }

    private func sendRecipeImportSubmit(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        let envelope = try await apiTransport.send(
            try mutation.requestBuilder(),
            configuration: configuration,
            decode: RecipeImportResponse.self
        )
        if let providerSecretResourceID = envelope.data.providerSecretBlockerResourceID {
            return .blocked(
                .providerSecret(resourceID: providerSecretResourceID),
                message: "Recipe import setup is required before Spoonjoy can finish this import."
            )
        }
        return .success(serverRevision: nil)
    }

    private func sendProviderCoverMutation(_ mutation: NativeQueuedMutation, configuration: APIClientConfiguration) async throws -> NativeSyncMutationResult {
        let envelope = try await apiTransport.send(
            try mutation.requestBuilder(),
            configuration: configuration,
            decode: JSONValue.self
        )
        if let providerSecretResourceID = Self.providerSecretBlockerResourceID(in: envelope.data, defaultResourceID: "recipe-covers") {
            return .blocked(
                .providerSecret(resourceID: providerSecretResourceID),
                message: "Image provider setup is required before Spoonjoy can finish cover generation."
            )
        }
        return .success(serverRevision: nil, idRemaps: mutation.idRemaps(from: envelope.data))
    }

    private static func mutationResult(
        for error: APITransportError,
        mutation: NativeQueuedMutation
    ) throws -> NativeSyncMutationResult {
        let message = error.apiError?.message ?? "Native sync request failed."

        if mutation.queueableKind == .coverRegenerate || mutation.queueableKind == .coverFromSpoon,
           let apiError = error.apiError,
           let providerSecretResourceID = coverProviderSecretBlockerResourceID(in: apiError) {
            return .blocked(.providerSecret(resourceID: providerSecretResourceID), message: message)
        }

        if error.statusCode == 401 {
            return .authFailure(message: message)
        }

        if case .retrySameRequest(let afterSeconds) = error.retryDecision {
            return .retry(
                afterSeconds: afterSeconds ?? NativeSyncRetrySchedule().baseDelaySeconds(forRetryCount: mutation.retryCount),
                message: message
            )
        }

        if error.statusCode == 409 {
            return .conflict(kind: .validation, serverRevision: nil, message: message)
        }

        throw error
    }

    private static func coverProviderSecretBlockerResourceID(in apiError: APIError) -> String? {
        if let resourceID = providerSecretBlockerResourceID(in: .object(apiError.details), defaultResourceID: "recipe-covers") {
            return resourceID
        }
        return apiError.code.lowercased().contains("provider_secret") ? "recipe-covers" : nil
    }

    private static func providerSecretBlockerResourceID(in value: JSONValue, defaultResourceID: String) -> String? {
        switch value {
        case .object(let object):
            if isProviderSecretBlocker(object) {
                return normalizedProviderSecretResourceID(object["resource"], defaultResourceID: defaultResourceID)
            }
            if case .array(let blockers)? = object["blockers"] {
                for blocker in blockers {
                    if let resourceID = providerSecretBlockerResourceID(in: blocker, defaultResourceID: defaultResourceID) {
                        return resourceID
                    }
                }
            }
            return nil
        case .array(let values):
            for value in values {
                if let resourceID = providerSecretBlockerResourceID(in: value, defaultResourceID: defaultResourceID) {
                    return resourceID
                }
            }
            return nil
        case .string, .number, .bool, .null:
            return nil
        }
    }

    private static func isProviderSecretBlocker(_ object: [String: JSONValue]) -> Bool {
        guard case .string(let capability)? = object["capability"] else {
            return false
        }
        return capability.caseInsensitiveCompare("ProviderSecret") == .orderedSame
    }

    private static func normalizedProviderSecretResourceID(_ value: JSONValue?, defaultResourceID: String) -> String {
        guard case .string(let resourceID)? = value else {
            return defaultResourceID
        }
        let trimmed = resourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultResourceID : trimmed
    }
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
        try await bootstrapAndDrain(configuration: configuration, trigger: trigger, scope: .unbound)
    }

    public func bootstrapAndDrain(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger,
        scope: NativeSyncExecutionScope
    ) async throws -> NativeSyncReport {
        let previousSnapshot = try await store.loadSnapshot()
        let previousCheckpoint = Self.reusableCheckpoint(from: previousSnapshot, scope: scope)
        let bootstrapApplication = try await applyBootstrap(
            configuration: configuration,
            trigger: trigger,
            startingCursor: previousCheckpoint?.globalCursor,
            previousCheckpoint: previousCheckpoint,
            scope: scope
        )
        let bootstrapCursor = bootstrapApplication.cursor
        let bootstrapAccountID = bootstrapApplication.accountID
        let bootstrapEnvironment = bootstrapApplication.environment
        let bootstrapTombstones = bootstrapApplication.tombstones
        let bootstrapRemovedCacheKeys = bootstrapApplication.removedCacheKeys

        let canReplayStoredQueue = Self.canReuseStoredState(previousSnapshot, scope: scope)
        let queueAccountID = bootstrapAccountID ?? scope.expectedAccountID
        let queueEnvironment = bootstrapEnvironment ?? scope.environment
        var shoppingEntityPurgeIdentifiers: [String] = []
        var shoppingEntityPurgeDomainIdentifiers: [String] = []
        var shoppingEntityPurgeRequests: [NativeShoppingEntityIndexPurgeRequest] = []
        var spoonEntityPurgeIdentifiers: [String] = []
        var spoonEntityPurgeDomainIdentifiers: [String] = []
        var spoonEntityPurgeRequests: [NativeSpoonEntityIndexPurgeRequest] = []
        let captureDraftEntityPurgeIdentifiers: [String] = []
        let captureDraftEntityPurgeDomainIdentifiers: [String] = []
        let captureDraftEntityPurgeRequests: [NativeCaptureDraftEntityIndexPurgeRequest] = []
        var chefProfileEntityPurgeIdentifiers: [String] = []
        var chefProfileEntityPurgeDomainIdentifiers: [String] = []
        var chefProfileEntityPurgeRequests: [NativeChefProfileEntityIndexPurgeRequest] = []
        var recipeCookbookEntityPurgeIdentifiers: [String] = []
        var recipeCookbookEntityPurgeDomainIdentifiers: [String] = []
        var recipeCookbookEntityPurgeRequests: [NativeRecipeCookbookEntityIndexPurgeRequest] = []
        if let accountScopePurge = Self.shoppingEntityAccountScopePurgePlan(
            previousSnapshot: previousSnapshot,
            nextAccountID: queueAccountID,
            nextEnvironment: queueEnvironment
        ) {
            let identifiers = ShoppingEntityCatalog.purgeEntityIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            let domainIdentifiers = ShoppingEntityCatalog.purgeDomainIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            shoppingEntityPurgeIdentifiers.append(contentsOf: identifiers)
            shoppingEntityPurgeDomainIdentifiers.append(contentsOf: domainIdentifiers)
            if !identifiers.isEmpty || !domainIdentifiers.isEmpty {
                shoppingEntityPurgeRequests.append(NativeShoppingEntityIndexPurgeRequest(
                    identifiers: identifiers,
                    domainIdentifiers: domainIdentifiers,
                    accountID: accountScopePurge.accountID,
                    environment: accountScopePurge.environment
                ))
            }
        }
        if let accountScopePurge = Self.spoonEntityAccountScopePurgePlan(
            previousSnapshot: previousSnapshot,
            nextAccountID: queueAccountID,
            nextEnvironment: queueEnvironment
        ) {
            let identifiers = SpoonEntityCatalog.purgeEntityIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            let domainIdentifiers = SpoonEntityCatalog.purgeDomainIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            spoonEntityPurgeIdentifiers.append(contentsOf: identifiers)
            spoonEntityPurgeDomainIdentifiers.append(contentsOf: domainIdentifiers)
            if !identifiers.isEmpty || !domainIdentifiers.isEmpty {
                spoonEntityPurgeRequests.append(NativeSpoonEntityIndexPurgeRequest(
                    identifiers: identifiers,
                    domainIdentifiers: domainIdentifiers,
                    accountID: accountScopePurge.accountID,
                    environment: accountScopePurge.environment
                ))
            }
        }
        if let accountScopePurge = Self.recipeCookbookEntityAccountScopePurgePlan(
            previousSnapshot: previousSnapshot,
            nextAccountID: queueAccountID,
            nextEnvironment: queueEnvironment
        ) {
            let identifiers = RecipeCookbookEntityCatalog.purgeEntityIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            let domainIdentifiers = RecipeCookbookEntityCatalog.purgeDomainIdentifiers(
                accountID: accountScopePurge.accountID,
                environment: accountScopePurge.environment,
                plan: accountScopePurge.plan
            )
            recipeCookbookEntityPurgeIdentifiers.append(contentsOf: identifiers)
            recipeCookbookEntityPurgeDomainIdentifiers.append(contentsOf: domainIdentifiers)
            if !identifiers.isEmpty || !domainIdentifiers.isEmpty {
                recipeCookbookEntityPurgeRequests.append(NativeRecipeCookbookEntityIndexPurgeRequest(
                    identifiers: identifiers,
                    domainIdentifiers: domainIdentifiers,
                    accountID: accountScopePurge.accountID,
                    environment: accountScopePurge.environment
                ))
            }
        }
        let originalQueue: NativeMutationQueue
        if canReplayStoredQueue {
            originalQueue = try await store.loadQueue()
        } else {
            originalQueue = NativeMutationQueue()
            if !previousSnapshot.queue.mutations.isEmpty {
                try await store.saveQueue(
                    NativeMutationQueue(),
                    accountID: queueAccountID,
                    environment: queueEnvironment
                )
            }
        }
        var remaining: [NativeQueuedMutation] = []
        var drainedClientMutationIDs: [String] = []
        var drainedMutations: [NativeQueuedMutation] = []
        var conflicts: [NativeSyncConflict] = []
        var blockers: [NativeSyncMutationBlocker] = []
        var blockedDependencyKeys = Set<String>()
        var pausedReason: NativeSyncPauseReason?
        var retryAfterSeconds: Int?
        var idReplacements: [String: String] = [:]

        var index = 0
        while index < originalQueue.mutations.count {
            let mutation = originalQueue.mutations[index].replacingResourceIDs(idReplacements)
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
            case .success(let revision, let idRemaps):
                drainedClientMutationIDs.append(mutation.clientMutationID)
                drainedMutations.append(mutation.recordingIDRemaps(idRemaps))
                for remap in idRemaps {
                    idReplacements[remap.localID] = remap.serverID
                }
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
                blockedDependencyKeys.formUnion(mutation.dependentDependencyKeysBlockedWithThisMutation)
            case .authFailure(let message):
                pausedReason = .authRequired(message)
                remaining.append(mutation)
                remaining.append(contentsOf: originalQueue.mutations.dropFirst(index + 1).map { $0.replacingResourceIDs(idReplacements) })
                index = originalQueue.mutations.count
                continue
            case .blocked(let blocker, let message):
                blockers.append(blocker)
                remaining.append(mutation.recordingError(message))
                blockedDependencyKeys.insert(mutation.dependencyKey)
                blockedDependencyKeys.formUnion(mutation.dependentDependencyKeysBlockedWithThisMutation)
            case .retry(let afterSeconds, let message):
                retryAfterSeconds = Self.shortestRetryDelay(retryAfterSeconds, afterSeconds)
                remaining.append(mutation.recordingRetry(
                    message: message,
                    nextRetryAt: NativeSyncClockFormatting.isoString(clock().addingTimeInterval(TimeInterval(afterSeconds)))
                ))
                blockedDependencyKeys.insert(mutation.dependencyKey)
                blockedDependencyKeys.formUnion(mutation.dependentDependencyKeysBlockedWithThisMutation)
            }

            index += 1
        }

        let drainedRecipeMutations = drainedMutations.filter(\.mutatesRecipeCache)
        let drainedShoppingMutations = drainedMutations.filter(\.mutatesShoppingCache)
        let drainedCookbookMutations = drainedMutations.filter(\.mutatesCookbookCache)
        var cachePatch: (upserting: [NativeSyncCachedRecord], deletingCacheKeys: Set<String>) = ([], [])
        if !drainedRecipeMutations.isEmpty || !drainedShoppingMutations.isEmpty || !drainedCookbookMutations.isEmpty {
            let snapshot = try await store.loadSnapshot()
            if !drainedRecipeMutations.isEmpty {
                let cachePatchAccountID = queueAccountID!
                let recipePatch = try Self.drainedRecipeCachePatch(
                    drainedMutations: drainedRecipeMutations,
                    snapshot: snapshot,
                    accountID: cachePatchAccountID
                )
                cachePatch.upserting.append(contentsOf: recipePatch.upserting)
                cachePatch.deletingCacheKeys.formUnion(recipePatch.deletingCacheKeys)
            }
            if !drainedShoppingMutations.isEmpty {
                let cachePatchAccountID = queueAccountID!
                let shoppingPatch = try Self.drainedShoppingCachePatch(
                    drainedMutations: drainedShoppingMutations,
                    snapshot: snapshot,
                    accountID: cachePatchAccountID
                )
                cachePatch.upserting.append(contentsOf: shoppingPatch.upserting)
                cachePatch.deletingCacheKeys.formUnion(shoppingPatch.deletingCacheKeys)
            }
            if !drainedCookbookMutations.isEmpty {
                let cachePatchAccountID = queueAccountID!
                let cookbookPatch = try Self.drainedCookbookCachePatch(
                    drainedMutations: drainedCookbookMutations,
                    snapshot: snapshot,
                    accountID: cachePatchAccountID
                )
                cachePatch.upserting.append(contentsOf: cookbookPatch.upserting)
                cachePatch.deletingCacheKeys.formUnion(cookbookPatch.deletingCacheKeys)
            }
        }
        try await store.saveQueue(
            NativeMutationQueue(mutations: remaining),
            accountID: queueAccountID,
            environment: queueEnvironment,
            upsertingCachedRecords: cachePatch.upserting,
            deletingCachedRecordKeys: cachePatch.deletingCacheKeys
        )
        let removedCacheKeys = Set(bootstrapRemovedCacheKeys).union(cachePatch.deletingCacheKeys)
        let currentShoppingRequestStart = shoppingEntityPurgeIdentifiers.count
        let currentShoppingDomainRequestStart = shoppingEntityPurgeDomainIdentifiers.count
        let currentSpoonRequestStart = spoonEntityPurgeIdentifiers.count
        let currentSpoonDomainRequestStart = spoonEntityPurgeDomainIdentifiers.count
        let currentChefProfileRequestStart = chefProfileEntityPurgeIdentifiers.count
        let currentChefProfileDomainRequestStart = chefProfileEntityPurgeDomainIdentifiers.count
        let currentRecipeCookbookRequestStart = recipeCookbookEntityPurgeIdentifiers.count
        let currentRecipeCookbookDomainRequestStart = recipeCookbookEntityPurgeDomainIdentifiers.count
        if let queueAccountID, let queueEnvironment {
            let makeTombstonePurge = ShoppingEntityIndexPurgePlan.tombstonePurge(tombstones:accountID:environment:)
            let makeCacheDeletePurge = ShoppingEntityIndexPurgePlan.cacheDeletePurge(accountID:environment:shoppingItemIDs:)
            let purgeShoppingEntityIdentifiers = ShoppingEntityCatalog.purgeEntityIdentifiers(accountID:environment:plan:)
            let makeSpoonTombstonePurge = SpoonEntityIndexPurgePlan.tombstonePurge(tombstones:accountID:environment:)
            let makeSpoonCacheDeletePurge = SpoonEntityIndexPurgePlan.cacheDeletePurge(accountID:environment:spoonIDs:)
            let purgeSpoonEntityIdentifiers = SpoonEntityCatalog.purgeEntityIdentifiers(accountID:environment:plan:)
            let makeChefProfileTombstonePurge = ChefProfileEntityIndexPurgePlan.tombstonePurge(tombstones:accountID:environment:)
            let makeChefProfileCacheDeletePurge = ChefProfileEntityIndexPurgePlan.cacheDeletePurge(accountID:environment:profileIDs:)
            let purgeChefProfileEntityIdentifiers = ChefProfileEntityCatalog.purgeEntityIdentifiers(accountID:environment:plan:)
            let makeRecipeCookbookTombstonePurge = RecipeCookbookEntityIndexPurgePlan.tombstonePurge(tombstones:accountID:environment:)
            let makeRecipeCookbookCacheDeletePurge = RecipeCookbookEntityIndexPurgePlan.cacheDeletePurge(accountID:environment:recipeIDs:cookbookIDs:)
            let purgeRecipeCookbookEntityIdentifiers = RecipeCookbookEntityCatalog.purgeEntityIdentifiers(accountID:environment:plan:)
            let shoppingItemTombstones = bootstrapTombstones.filter { $0.resourceType == NativeSyncResourceType.shoppingItem }
            let tombstonePurgePlan = makeTombstonePurge(shoppingItemTombstones, queueAccountID, queueEnvironment)
            shoppingEntityPurgeIdentifiers.append(contentsOf: purgeShoppingEntityIdentifiers(queueAccountID, queueEnvironment, tombstonePurgePlan))
            shoppingEntityPurgeDomainIdentifiers.append(contentsOf: ShoppingEntityCatalog.purgeDomainIdentifiers(
                accountID: queueAccountID,
                environment: queueEnvironment,
                    plan: tombstonePurgePlan
                ))
            let deletedShoppingItemIDs = removedCacheKeys.compactMap { cacheKey -> String? in
                let prefix = "\(NativeSyncEntryKind.shoppingItem.rawValue):"
                guard cacheKey.hasPrefix(prefix) else {
                    return nil
                }
                return String(cacheKey.dropFirst(prefix.count))
            }
            if !deletedShoppingItemIDs.isEmpty {
                let cacheDeletePurgePlan = makeCacheDeletePurge(queueAccountID, queueEnvironment, deletedShoppingItemIDs)
                shoppingEntityPurgeIdentifiers.append(contentsOf: purgeShoppingEntityIdentifiers(queueAccountID, queueEnvironment, cacheDeletePurgePlan))
                shoppingEntityPurgeDomainIdentifiers.append(contentsOf: ShoppingEntityCatalog.purgeDomainIdentifiers(
                    accountID: queueAccountID,
                    environment: queueEnvironment,
                    plan: cacheDeletePurgePlan
                ))
            }
            let spoonTombstones = bootstrapTombstones.filter { $0.resourceType == NativeSyncResourceType.spoon }
            let spoonTombstonePurgePlan = makeSpoonTombstonePurge(spoonTombstones, queueAccountID, queueEnvironment)
            spoonEntityPurgeIdentifiers.append(contentsOf: purgeSpoonEntityIdentifiers(queueAccountID, queueEnvironment, spoonTombstonePurgePlan))
            spoonEntityPurgeDomainIdentifiers.append(contentsOf: SpoonEntityCatalog.purgeDomainIdentifiers(
                accountID: queueAccountID,
                environment: queueEnvironment,
                plan: spoonTombstonePurgePlan
            ))
            let deletedSpoonIDs = removedCacheKeys.compactMap { cacheKey -> String? in
                let prefix = "\(NativeSyncEntryKind.spoon.rawValue):"
                guard cacheKey.hasPrefix(prefix) else {
                    return nil
                }
                return String(cacheKey.dropFirst(prefix.count))
            }
            if !deletedSpoonIDs.isEmpty {
                let spoonCacheDeletePurgePlan = makeSpoonCacheDeletePurge(queueAccountID, queueEnvironment, deletedSpoonIDs)
                spoonEntityPurgeIdentifiers.append(contentsOf: purgeSpoonEntityIdentifiers(queueAccountID, queueEnvironment, spoonCacheDeletePurgePlan))
                spoonEntityPurgeDomainIdentifiers.append(contentsOf: SpoonEntityCatalog.purgeDomainIdentifiers(
                    accountID: queueAccountID,
                    environment: queueEnvironment,
                    plan: spoonCacheDeletePurgePlan
                ))
            }
            let chefProfileTombstones = bootstrapTombstones.filter { $0.resourceType == NativeSyncResourceType.profile }
            let chefProfileTombstonePurgePlan = makeChefProfileTombstonePurge(chefProfileTombstones, queueAccountID, queueEnvironment)
            chefProfileEntityPurgeIdentifiers.append(contentsOf: purgeChefProfileEntityIdentifiers(queueAccountID, queueEnvironment, chefProfileTombstonePurgePlan))
            chefProfileEntityPurgeDomainIdentifiers.append(contentsOf: ChefProfileEntityCatalog.purgeDomainIdentifiers(
                accountID: queueAccountID,
                environment: queueEnvironment,
                plan: chefProfileTombstonePurgePlan
            ))
            let deletedChefProfileIDs = removedCacheKeys.compactMap { cacheKey -> String? in
                let prefix = "\(NativeSyncEntryKind.profile.rawValue):"
                guard cacheKey.hasPrefix(prefix) else {
                    return nil
                }
                return String(cacheKey.dropFirst(prefix.count))
            }
            if !deletedChefProfileIDs.isEmpty {
                let chefProfileCacheDeletePurgePlan = makeChefProfileCacheDeletePurge(queueAccountID, queueEnvironment, deletedChefProfileIDs)
                chefProfileEntityPurgeIdentifiers.append(contentsOf: purgeChefProfileEntityIdentifiers(queueAccountID, queueEnvironment, chefProfileCacheDeletePurgePlan))
                chefProfileEntityPurgeDomainIdentifiers.append(contentsOf: ChefProfileEntityCatalog.purgeDomainIdentifiers(
                    accountID: queueAccountID,
                    environment: queueEnvironment,
                    plan: chefProfileCacheDeletePurgePlan
                ))
            }
            let recipeCookbookTombstones = bootstrapTombstones.filter {
                $0.resourceType == NativeSyncResourceType.recipe || $0.resourceType == NativeSyncResourceType.cookbook
            }
            let recipeCookbookTombstonePurgePlan = makeRecipeCookbookTombstonePurge(recipeCookbookTombstones, queueAccountID, queueEnvironment)
            recipeCookbookEntityPurgeIdentifiers.append(contentsOf: purgeRecipeCookbookEntityIdentifiers(queueAccountID, queueEnvironment, recipeCookbookTombstonePurgePlan))
            recipeCookbookEntityPurgeDomainIdentifiers.append(contentsOf: RecipeCookbookEntityCatalog.purgeDomainIdentifiers(
                accountID: queueAccountID,
                environment: queueEnvironment,
                plan: recipeCookbookTombstonePurgePlan
            ))
            let deletedRecipeIDs = removedCacheKeys.compactMap { cacheKey -> String? in
                let prefix = "\(NativeSyncEntryKind.recipe.rawValue):"
                guard cacheKey.hasPrefix(prefix) else {
                    return nil
                }
                return String(cacheKey.dropFirst(prefix.count))
            }
            let deletedCookbookIDs = removedCacheKeys.compactMap { cacheKey -> String? in
                let prefix = "\(NativeSyncEntryKind.cookbook.rawValue):"
                guard cacheKey.hasPrefix(prefix) else {
                    return nil
                }
                return String(cacheKey.dropFirst(prefix.count))
            }
            if !deletedRecipeIDs.isEmpty || !deletedCookbookIDs.isEmpty {
                let recipeCookbookCacheDeletePurgePlan = makeRecipeCookbookCacheDeletePurge(
                    queueAccountID,
                    queueEnvironment,
                    deletedRecipeIDs,
                    deletedCookbookIDs
                )
                recipeCookbookEntityPurgeIdentifiers.append(contentsOf: purgeRecipeCookbookEntityIdentifiers(queueAccountID, queueEnvironment, recipeCookbookCacheDeletePurgePlan))
                recipeCookbookEntityPurgeDomainIdentifiers.append(contentsOf: RecipeCookbookEntityCatalog.purgeDomainIdentifiers(
                    accountID: queueAccountID,
                    environment: queueEnvironment,
                    plan: recipeCookbookCacheDeletePurgePlan
                ))
            }
            let currentShoppingIdentifiers = Array(shoppingEntityPurgeIdentifiers[currentShoppingRequestStart...])
            let currentShoppingDomainIdentifiers = Array(shoppingEntityPurgeDomainIdentifiers[currentShoppingDomainRequestStart...])
            if !currentShoppingIdentifiers.isEmpty || !currentShoppingDomainIdentifiers.isEmpty {
                shoppingEntityPurgeRequests.append(NativeShoppingEntityIndexPurgeRequest(
                    identifiers: Self.uniquePreservingOrder(currentShoppingIdentifiers),
                    domainIdentifiers: Self.uniquePreservingOrder(currentShoppingDomainIdentifiers),
                    accountID: queueAccountID,
                    environment: queueEnvironment
                ))
            }
            let currentSpoonIdentifiers = Array(spoonEntityPurgeIdentifiers[currentSpoonRequestStart...])
            let currentSpoonDomainIdentifiers = Array(spoonEntityPurgeDomainIdentifiers[currentSpoonDomainRequestStart...])
            if !currentSpoonIdentifiers.isEmpty || !currentSpoonDomainIdentifiers.isEmpty {
                spoonEntityPurgeRequests.append(NativeSpoonEntityIndexPurgeRequest(
                    identifiers: Self.uniquePreservingOrder(currentSpoonIdentifiers),
                    domainIdentifiers: Self.uniquePreservingOrder(currentSpoonDomainIdentifiers),
                    accountID: queueAccountID,
                    environment: queueEnvironment
                ))
            }
            let currentChefProfileIdentifiers = Array(chefProfileEntityPurgeIdentifiers[currentChefProfileRequestStart...])
            let currentChefProfileDomainIdentifiers = Array(chefProfileEntityPurgeDomainIdentifiers[currentChefProfileDomainRequestStart...])
            if !currentChefProfileIdentifiers.isEmpty || !currentChefProfileDomainIdentifiers.isEmpty {
                chefProfileEntityPurgeRequests.append(NativeChefProfileEntityIndexPurgeRequest(
                    identifiers: Self.uniquePreservingOrder(currentChefProfileIdentifiers),
                    domainIdentifiers: Self.uniquePreservingOrder(currentChefProfileDomainIdentifiers),
                    accountID: queueAccountID,
                    environment: queueEnvironment
                ))
            }
            let currentRecipeCookbookIdentifiers = Array(recipeCookbookEntityPurgeIdentifiers[currentRecipeCookbookRequestStart...])
            let currentRecipeCookbookDomainIdentifiers = Array(recipeCookbookEntityPurgeDomainIdentifiers[currentRecipeCookbookDomainRequestStart...])
            if !currentRecipeCookbookIdentifiers.isEmpty || !currentRecipeCookbookDomainIdentifiers.isEmpty {
                recipeCookbookEntityPurgeRequests.append(NativeRecipeCookbookEntityIndexPurgeRequest(
                    identifiers: Self.uniquePreservingOrder(currentRecipeCookbookIdentifiers),
                    domainIdentifiers: Self.uniquePreservingOrder(currentRecipeCookbookDomainIdentifiers),
                    accountID: queueAccountID,
                    environment: queueEnvironment
                ))
            }
        }
        shoppingEntityPurgeIdentifiers = Self.uniquePreservingOrder(shoppingEntityPurgeIdentifiers)
        shoppingEntityPurgeDomainIdentifiers = Self.uniquePreservingOrder(shoppingEntityPurgeDomainIdentifiers)
        spoonEntityPurgeIdentifiers = Self.uniquePreservingOrder(spoonEntityPurgeIdentifiers)
        spoonEntityPurgeDomainIdentifiers = Self.uniquePreservingOrder(spoonEntityPurgeDomainIdentifiers)
        chefProfileEntityPurgeIdentifiers = Self.uniquePreservingOrder(chefProfileEntityPurgeIdentifiers)
        chefProfileEntityPurgeDomainIdentifiers = Self.uniquePreservingOrder(chefProfileEntityPurgeDomainIdentifiers)
        recipeCookbookEntityPurgeIdentifiers = Self.uniquePreservingOrder(recipeCookbookEntityPurgeIdentifiers)
        recipeCookbookEntityPurgeDomainIdentifiers = Self.uniquePreservingOrder(recipeCookbookEntityPurgeDomainIdentifiers)

        return NativeSyncReport(
            trigger: trigger,
            bootstrapCursor: bootstrapCursor,
            accountID: bootstrapAccountID,
            environment: bootstrapEnvironment,
            shoppingEntityPurgeIdentifiers: shoppingEntityPurgeIdentifiers,
            shoppingEntityPurgeDomainIdentifiers: shoppingEntityPurgeDomainIdentifiers,
            shoppingEntityPurgeRequests: shoppingEntityPurgeRequests,
            spoonEntityPurgeIdentifiers: spoonEntityPurgeIdentifiers,
            spoonEntityPurgeDomainIdentifiers: spoonEntityPurgeDomainIdentifiers,
            spoonEntityPurgeRequests: spoonEntityPurgeRequests,
            captureDraftEntityPurgeIdentifiers: captureDraftEntityPurgeIdentifiers,
            captureDraftEntityPurgeDomainIdentifiers: captureDraftEntityPurgeDomainIdentifiers,
            captureDraftEntityPurgeRequests: captureDraftEntityPurgeRequests,
            chefProfileEntityPurgeIdentifiers: chefProfileEntityPurgeIdentifiers,
            chefProfileEntityPurgeDomainIdentifiers: chefProfileEntityPurgeDomainIdentifiers,
            chefProfileEntityPurgeRequests: chefProfileEntityPurgeRequests,
            recipeCookbookEntityPurgeIdentifiers: recipeCookbookEntityPurgeIdentifiers,
            recipeCookbookEntityPurgeDomainIdentifiers: recipeCookbookEntityPurgeDomainIdentifiers,
            recipeCookbookEntityPurgeRequests: recipeCookbookEntityPurgeRequests,
            drainedClientMutationIDs: drainedClientMutationIDs,
            drainedMutations: drainedMutations,
            conflicts: conflicts,
            blockers: blockers,
            pausedReason: pausedReason,
            retryAfterSeconds: retryAfterSeconds
        )
    }

    private func applyBootstrap(
        configuration: APIClientConfiguration,
        trigger: NativeCacheRevalidationTrigger,
        startingCursor: PaginationCursor?,
        previousCheckpoint: NativeSyncCheckpoint?,
        scope: NativeSyncExecutionScope
    ) async throws -> NativeSyncBootstrapApplication {
        NativeSyncTelemetry.bootstrapStarted(trigger: trigger, cursor: startingCursor, scope: scope)

        var application = NativeSyncBootstrapApplication()
        var cursor = startingCursor
        var seenCursors = Set<String>()
        if let cursor {
            seenCursors.insert(cursor.rawValue)
        }

        var page = 0
        var shouldContinue = true
        do {
            while shouldContinue {
                page += 1
                let bootstrapRequest = try NativeSyncBootstrapRequest.defaultRequest(cursor: cursor)
                    .urlRequest(configuration: configuration)
                let bootstrapResult = try await transport.bootstrap(request: bootstrapRequest, configuration: configuration)

                switch bootstrapResult {
                case .success(let cursor, let tombstones):
                    application.recordLegacy(cursor: cursor, tombstones: tombstones)
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
                    NativeSyncTelemetry.bootstrapCompleted(trigger: trigger, application: application)
                    return application
                case .syncData(let syncData):
                    let scopedSyncData = syncData.scoped(to: scope.environment)
                    let applyResult = try await store.apply(syncData: scopedSyncData, validatedAt: clock())
                    application.recordPage(syncData: scopedSyncData, applyResult: applyResult)
                    NativeSyncTelemetry.bootstrapPageApplied(
                        trigger: trigger,
                        page: page,
                        syncData: scopedSyncData,
                        applyResult: applyResult
                    )

                    if !scopedSyncData.hasMore {
                        shouldContinue = false
                        continue
                    }

                    guard let nextCursor = scopedSyncData.nextCursor else {
                        throw NativeSyncBootstrapPagingError.missingNextCursor(page: page)
                    }

                    guard seenCursors.insert(nextCursor.rawValue).inserted else {
                        throw NativeSyncBootstrapPagingError.repeatedCursor(nextCursor.rawValue, page: page)
                    }

                    cursor = nextCursor
                }
            }
            NativeSyncTelemetry.bootstrapCompleted(trigger: trigger, application: application)
            return application
        } catch {
            NativeSyncTelemetry.bootstrapFailed(trigger: trigger, page: max(page, 1), error: error)
            throw error
        }
    }

    private static func shortestRetryDelay(_ current: Int?, _ candidate: Int) -> Int {
        guard let current else {
            return candidate
        }

        return min(current, candidate)
    }

    private static func shoppingEntityAccountScopePurgePlan(
        previousSnapshot: NativeSyncSnapshot,
        nextAccountID: String?,
        nextEnvironment: NativeCacheEnvironment?
    ) -> (accountID: String, environment: NativeCacheEnvironment, plan: ShoppingEntityIndexPurgePlan)? {
        guard let previousAccountID = previousSnapshot.accountID,
              let previousEnvironment = previousSnapshot.environment,
              let nextAccountID,
              let nextEnvironment,
              (previousAccountID != nextAccountID || previousEnvironment != nextEnvironment) else {
            return nil
        }

        let shoppingItemIDs = previousSnapshot.cachedRecords.compactMap { record in
            record.kind == .shoppingItem ? record.resourceID : nil
        }
        return (
            accountID: previousAccountID,
            environment: previousEnvironment,
            plan: ShoppingEntityIndexPurgePlan.accountScopePurge(
                accountID: previousAccountID,
                environment: previousEnvironment,
                shoppingItemIDs: shoppingItemIDs
            )
        )
    }

    private static func spoonEntityAccountScopePurgePlan(
        previousSnapshot: NativeSyncSnapshot,
        nextAccountID: String?,
        nextEnvironment: NativeCacheEnvironment?
    ) -> (accountID: String, environment: NativeCacheEnvironment, plan: SpoonEntityIndexPurgePlan)? {
        guard let previousAccountID = previousSnapshot.accountID,
              let previousEnvironment = previousSnapshot.environment,
              let nextAccountID,
              let nextEnvironment,
              (previousAccountID != nextAccountID || previousEnvironment != nextEnvironment) else {
            return nil
        }

        let spoonIDs = previousSnapshot.cachedRecords.flatMap { record -> [String] in
            if record.kind == .spoon {
                return [record.resourceID]
            }
            guard record.kind == .recipe,
                  let recipe = try? JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(record.payload)) else {
                return []
            }
            return recipe.recentSpoons.map(\.id)
        }
        return (
            accountID: previousAccountID,
            environment: previousEnvironment,
            plan: SpoonEntityIndexPurgePlan.accountScopePurge(
                accountID: previousAccountID,
                environment: previousEnvironment,
                spoonIDs: uniquePreservingOrder(spoonIDs)
            )
        )
    }

    private static func recipeCookbookEntityAccountScopePurgePlan(
        previousSnapshot: NativeSyncSnapshot,
        nextAccountID: String?,
        nextEnvironment: NativeCacheEnvironment?
    ) -> (accountID: String, environment: NativeCacheEnvironment, plan: RecipeCookbookEntityIndexPurgePlan)? {
        guard let previousAccountID = previousSnapshot.accountID,
              let previousEnvironment = previousSnapshot.environment,
              let nextAccountID,
              let nextEnvironment,
              (previousAccountID != nextAccountID || previousEnvironment != nextEnvironment) else {
            return nil
        }

        let recipeIDs = previousSnapshot.cachedRecords.compactMap { record in
            record.kind == .recipe ? record.resourceID : nil
        }
        let cookbookIDs = previousSnapshot.cachedRecords.compactMap { record in
            record.kind == .cookbook ? record.resourceID : nil
        }
        return (
            accountID: previousAccountID,
            environment: previousEnvironment,
            plan: RecipeCookbookEntityIndexPurgePlan.accountScopePurge(
                accountID: previousAccountID,
                environment: previousEnvironment,
                recipeIDs: recipeIDs,
                cookbookIDs: cookbookIDs
            )
        )
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func optimisticRevision(for drainedMutations: [NativeQueuedMutation]) -> NativeServerRevision? {
        drainedMutations.first.map { .optimistic($0.clientMutationID) }
    }

    private static func drainedRecipeCachePatch(
        drainedMutations: [NativeQueuedMutation],
        snapshot: NativeSyncSnapshot,
        accountID: String
    ) throws -> (upserting: [NativeSyncCachedRecord], deletingCacheKeys: Set<String>) {
        let cachedRecipes = try snapshot.cachedRecords
            .filter { $0.kind == .recipe }
            .map { try $0.payload.decoded(Recipe.self) }
        let fallbackChef = cachedRecipes.first?.chef ?? ChefSummary(id: accountID, username: "Spoonjoy")
        let updatedRecipes = drainedMutations.reduce(cachedRecipes) { recipes, mutation in
            mutation.applyingOptimisticRecipeMutation(to: recipes, fallbackChef: fallbackChef, now: mutation.createdAt)
        }
        var deletedCacheKeys = Set(Set(cachedRecipes.map(\.id)).subtracting(updatedRecipes.map(\.id)).map { "\(NativeSyncEntryKind.recipe.rawValue):\($0)" })
        let deletedSpoonCacheKeys = drainedMutations.compactMap { mutation -> String? in
            guard mutation.queueableKind == .spoonDelete,
                  let spoonID = mutation.optimisticSpoonID else {
                return nil
            }
            return "\(NativeSyncEntryKind.spoon.rawValue):\(spoonID)"
        }
        deletedCacheKeys.formUnion(deletedSpoonCacheKeys)
        let upserts = try updatedRecipes.map { recipe in
            NativeSyncCachedRecord(
                kind: .recipe,
                resourceID: recipe.id,
                payload: try JSONValue.encoded(recipe),
                serverRevision: optimisticRevision(for: drainedMutations)
            )
        }
        return (upserts, deletedCacheKeys)
    }

    private static func drainedShoppingCachePatch(
        drainedMutations: [NativeQueuedMutation],
        snapshot: NativeSyncSnapshot,
        accountID: String
    ) throws -> (upserting: [NativeSyncCachedRecord], deletingCacheKeys: Set<String>) {
        let cachedItems = try snapshot.cachedRecords
            .filter { $0.kind == .shoppingItem }
            .map { try $0.payload.decoded(ShoppingListItem.self) }
        let cachedRecipes = try snapshot.cachedRecords
            .filter { $0.kind == .recipe }
            .map { try $0.payload.decoded(Recipe.self) }
        let fallbackChef = cachedRecipes.first?.chef ?? ChefSummary(id: accountID, username: "Spoonjoy")
        let baseShoppingList: ShoppingListState? = cachedItems.isEmpty
            ? nil
            : ShoppingListState(
                id: "native-shopping-list",
                chef: fallbackChef,
                items: cachedItems,
                nextCursor: snapshot.checkpoint?.shoppingCursor?.rawValue ?? "",
                updatedAt: snapshot.checkpoint?.updatedAt ?? drainedMutations.first!.createdAt
            )
        let updated = drainedMutations.reduce(baseShoppingList) { shoppingList, mutation in
            mutation.applyingOptimisticShoppingMutation(
                to: shoppingList,
                recipes: cachedRecipes,
                fallbackChef: fallbackChef,
                now: mutation.createdAt
            )
        }
        guard let updatedShoppingList = updated else {
            return ([], [])
        }

        let activeItems = updatedShoppingList.activeItems
        let activeItemIDs = Set(activeItems.map(\.id))
        let deletedCacheKeys = Set(cachedItems.map(\.id).filter { !activeItemIDs.contains($0) }.map { "\(NativeSyncEntryKind.shoppingItem.rawValue):\($0)" })
        let upserts = try activeItems.map { item in
            NativeSyncCachedRecord(
                kind: .shoppingItem,
                resourceID: item.id,
                payload: try JSONValue.encoded(item),
                serverRevision: optimisticRevision(for: drainedMutations)
            )
        }
        return (upserts, deletedCacheKeys)
    }

    private static func drainedCookbookCachePatch(
        drainedMutations: [NativeQueuedMutation],
        snapshot: NativeSyncSnapshot,
        accountID: String
    ) throws -> (upserting: [NativeSyncCachedRecord], deletingCacheKeys: Set<String>) {
        let cachedCookbooks = try snapshot.cachedRecords
            .filter { $0.kind == .cookbook }
            .map { try $0.payload.decoded(Cookbook.self) }
        let cachedRecipes = try snapshot.cachedRecords
            .filter { $0.kind == .recipe }
            .map { try $0.payload.decoded(Recipe.self) }
        let fallbackChef = cachedRecipes.first?.chef ?? cachedCookbooks.first?.chef ?? ChefSummary(id: accountID, username: "Spoonjoy")
        let updatedCookbooks = drainedMutations.reduce(cachedCookbooks) { cookbooks, mutation in
            mutation.applyingOptimisticCookbookMutation(
                to: cookbooks,
                fallbackChef: fallbackChef,
                recipes: cachedRecipes,
                now: mutation.createdAt
            )
        }
        let deletedCacheKeys = Set(Set(cachedCookbooks.map(\.id)).subtracting(updatedCookbooks.map(\.id)).map { "\(NativeSyncEntryKind.cookbook.rawValue):\($0)" })
        let upserts = try updatedCookbooks.map { cookbook in
            NativeSyncCachedRecord(
                kind: .cookbook,
                resourceID: cookbook.id,
                payload: try JSONValue.encoded(cookbook),
                serverRevision: optimisticRevision(for: drainedMutations)
            )
        }
        return (upserts, deletedCacheKeys)
    }

    private static func reusableCheckpoint(
        from snapshot: NativeSyncSnapshot,
        scope: NativeSyncExecutionScope
    ) -> NativeSyncCheckpoint? {
        guard canReuseStoredState(snapshot, scope: scope) else {
            return nil
        }
        return snapshot.checkpoint
    }

    private static func canReuseStoredState(
        _ snapshot: NativeSyncSnapshot,
        scope: NativeSyncExecutionScope
    ) -> Bool {
        guard let expectedAccountID = scope.expectedAccountID,
              let expectedEnvironment = scope.environment else {
            return false
        }
        return snapshot.accountID == expectedAccountID && snapshot.environment == expectedEnvironment
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

private extension ShoppingListState {
    func replacingShoppingItemID(_ localID: String, with serverID: String?) -> ShoppingListState {
        guard let serverID,
              !serverID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              serverID != localID else {
            return self
        }

        return ShoppingListState(
            id: id,
            chef: chef,
            items: items.map { item in
                item.id == localID ? item.replacingShoppingItemID(serverID) : item
            },
            nextCursor: nextCursor,
            updatedAt: updatedAt
        )
    }
}

private extension ShoppingListItem {
    func replacingShoppingItemID(_ itemID: String) -> ShoppingListItem {
        ShoppingListItem(
            id: itemID,
            name: name,
            quantity: quantity,
            unit: unit,
            checked: checked,
            checkedAt: checkedAt,
            deletedAt: deletedAt,
            categoryKey: categoryKey,
            iconKey: iconKey,
            sortIndex: sortIndex,
            updatedAt: updatedAt
        )
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
