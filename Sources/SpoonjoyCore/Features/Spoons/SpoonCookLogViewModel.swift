import Foundation

public protocol SpoonCookLogRepository: Sendable {
    func fetchCookLog(recipeID: String, cursor: PaginationCursor?, limit: Int) async throws -> SpoonCookLogListData
}

public struct LiveSpoonCookLogRepository: SpoonCookLogRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func fetchCookLog(recipeID: String, cursor: PaginationCursor?, limit: Int) async throws -> SpoonCookLogListData {
        let envelope = try await transport.send(
            RecipeSpoonRequests.listSpoons(recipeID: recipeID, cursor: cursor, limit: limit),
            configuration: configuration,
            decode: SpoonCookLogListData.self
        )
        return envelope.data
    }
}

public enum SpoonCookLogConnectivity: Equatable, Sendable {
    case online
    case offline
}

public struct SpoonCookLogData: Decodable, Equatable, Sendable {
    public let spoons: [RecipeDetailRecentSpoon]
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool

    public init(spoons: [RecipeDetailRecentSpoon], nextCursor: PaginationCursor? = nil, hasMore: Bool = false) {
        self.spoons = spoons
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    public init(summary: RecipeDetailSpoonSummary) {
        self.spoons = summary.rows.map(\.spoon)
        self.nextCursor = nil
        self.hasMore = false
    }

    public init(list: SpoonCookLogListData) {
        self.spoons = list.spoons
        self.nextCursor = list.nextCursor
        self.hasMore = list.hasMore
    }

    private enum CodingKeys: String, CodingKey {
        case spoons
        case nextCursor
        case hasMore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spoons = try container.decodeIfPresent([RecipeDetailRecentSpoon].self, forKey: .spoons) ?? []
        nextCursor = try container.decodeIfPresent(PaginationCursor.self, forKey: .nextCursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

public struct SpoonCookLogListData: Decodable, Equatable, Sendable {
    public let spoons: [RecipeDetailRecentSpoon]
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool

    public init(spoons: [RecipeDetailRecentSpoon], nextCursor: PaginationCursor?, hasMore: Bool) {
        self.spoons = spoons
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    private enum CodingKeys: String, CodingKey {
        case spoons
        case nextCursor
        case hasMore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spoons = try container.decodeIfPresent([RecipeDetailRecentSpoon].self, forKey: .spoons) ?? []
        nextCursor = try container.decodeIfPresent(PaginationCursor.self, forKey: .nextCursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
    }
}

public struct SpoonCookLogEmptyState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct SpoonCookLogConflictBanner: Equatable, Sendable {
    public let localClientMutationID: String
    public let message: String
    public let actionTitle: String

    public init(localClientMutationID: String, message: String, actionTitle: String) {
        self.localClientMutationID = localClientMutationID
        self.message = message
        self.actionTitle = actionTitle
    }
}

public struct SpoonCookLogPhotoAttachment: Equatable, Sendable {
    public let localStageID: String
    public let fileName: String
    public let contentType: String
    public let byteCount: Int
    public let data: Data

    public init(localStageID: String, fileName: String, contentType: String, data: Data, byteCount: Int? = nil) {
        self.localStageID = localStageID
        self.fileName = fileName
        self.contentType = contentType
        self.byteCount = max(byteCount ?? data.count, data.count)
        self.data = data
    }

    var uploadFile: UploadFile {
        UploadFile(fileName: fileName, contentType: contentType, data: data)
    }

    public var stagedMedia: NativeStagedMediaUpload {
        NativeStagedMediaUpload(localStageID: localStageID, fileName: fileName, contentType: contentType, byteCount: byteCount, data: data)
    }
}

public struct SpoonCookLogStagedMediaUsage: Equatable, Sendable {
    public let byteCount: Int
    public let fileCount: Int

    public init(byteCount: Int, fileCount: Int) {
        self.byteCount = byteCount
        self.fileCount = fileCount
    }

    public static let zero = SpoonCookLogStagedMediaUsage(byteCount: 0, fileCount: 0)

    public init(drafts: [SpoonCookLogDraftState]) {
        self.init(
            byteCount: drafts.reduce(0) { $0 + ($1.stagedPhoto?.byteCount ?? 0) },
            fileCount: drafts.reduce(0) { $0 + ($1.stagedPhoto == nil ? 0 : 1) }
        )
    }

    public static func + (lhs: SpoonCookLogStagedMediaUsage, rhs: SpoonCookLogStagedMediaUsage) -> SpoonCookLogStagedMediaUsage {
        SpoonCookLogStagedMediaUsage(
            byteCount: lhs.byteCount + rhs.byteCount,
            fileCount: lhs.fileCount + rhs.fileCount
        )
    }

    public func removing(byteCount removedByteCount: Int, fileCount removedFileCount: Int) -> SpoonCookLogStagedMediaUsage {
        SpoonCookLogStagedMediaUsage(
            byteCount: max(0, byteCount - removedByteCount),
            fileCount: max(0, fileCount - removedFileCount)
        )
    }
}

public struct SpoonCookLogDraftState: Codable, Equatable, Sendable {
    public let recipeID: String
    public let note: String?
    public let nextTime: String?
    public let stagedPhoto: NativeStagedMediaUpload?
    public let useAsRecipeCover: Bool
    public let updatedAt: String

    public init(
        recipeID: String,
        note: String?,
        nextTime: String?,
        stagedPhoto: NativeStagedMediaUpload?,
        useAsRecipeCover: Bool,
        updatedAt: String
    ) {
        self.recipeID = Self.clean(recipeID) ?? recipeID
        self.note = Self.clean(note)
        self.nextTime = Self.clean(nextTime)
        self.stagedPhoto = stagedPhoto
        self.useAsRecipeCover = stagedPhoto != nil && useAsRecipeCover
        self.updatedAt = updatedAt
    }

    public var hasContent: Bool {
        note != nil || nextTime != nil || stagedPhoto != nil
    }

    public var persistable: SpoonCookLogDraftState? {
        hasContent ? self : nil
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

public enum SpoonCookLogAction: Equatable, Sendable {
    case create(note: String?, nextTime: String?, cookedAt: String?, photo: SpoonCookLogPhotoAttachment?, photoURL: String?, useAsRecipeCover: Bool, clientMutationID: String)
    case update(spoonID: String, note: String?, nextTime: String?, cookedAt: String?, photoURL: String?, clientMutationID: String)
    case delete(spoonID: String, clientMutationID: String)

    public var successMessage: String {
        switch self {
        case .create:
            "Cook logged."
        case .update:
            "Cook log updated."
        case .delete:
            "Cook log deleted."
        }
    }
}

public struct SpoonCookLogMutationPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let blockedReason: String?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        blockedReason: String? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.blockedReason = blockedReason
    }
}

public struct SpoonCookLogRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let spoon: RecipeDetailRecentSpoon
    public let chefLine: String
    public let note: String?
    public let nextTime: String?
    public let photoURL: URL?
    public let cookedAtLabel: String
    public let isOwnedByCurrentChef: Bool
    public let canEdit: Bool
    public let canDelete: Bool

    public init(spoon: RecipeDetailRecentSpoon, currentChefID: String?) {
        id = spoon.id
        self.spoon = spoon
        chefLine = "\(spoon.chef.username) cooked this"
        note = Self.clean(spoon.note)
        nextTime = Self.clean(spoon.nextTime)
        photoURL = spoon.photoURL
        cookedAtLabel = spoon.cookedAt.map(RecipeCoverCandidate.dateLabel) ?? RecipeCoverCandidate.dateLabel(spoon.createdAt)
        isOwnedByCurrentChef = currentChefID == spoon.chefID
        canEdit = isOwnedByCurrentChef && spoon.deletedAt == nil
        canDelete = canEdit
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

public struct SpoonCookLogViewModel: Equatable, Sendable {
    public let recipeID: String
    public let data: SpoonCookLogData
    public let currentChefID: String?
    public let queuedMutations: [NativeQueuedMutation]
    public let conflicts: [NativeSyncConflict]
    public let connectivity: SpoonCookLogConnectivity
    public let draftMediaUsage: SpoonCookLogStagedMediaUsage
    private let now: @Sendable () -> String

    public init(
        recipeID: String,
        data: SpoonCookLogData,
        currentChefID: String?,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: SpoonCookLogConnectivity,
        draftMediaUsage: SpoonCookLogStagedMediaUsage = .zero,
        now: @escaping @Sendable () -> String
    ) {
        self.recipeID = recipeID
        self.data = data
        self.currentChefID = currentChefID
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.draftMediaUsage = draftMediaUsage
        self.now = now
    }

    public static func == (lhs: SpoonCookLogViewModel, rhs: SpoonCookLogViewModel) -> Bool {
        lhs.recipeID == rhs.recipeID &&
            lhs.data == rhs.data &&
            lhs.currentChefID == rhs.currentChefID &&
            lhs.queuedMutations == rhs.queuedMutations &&
            lhs.conflicts == rhs.conflicts &&
            lhs.connectivity == rhs.connectivity &&
            lhs.draftMediaUsage == rhs.draftMediaUsage
    }

    public var rows: [SpoonCookLogRow] {
        data.spoons
            .filter { $0.deletedAt == nil }
            .map { SpoonCookLogRow(spoon: $0, currentChefID: currentChefID) }
    }

    public var emptyState: SpoonCookLogEmptyState? {
        guard rows.isEmpty else { return nil }
        return SpoonCookLogEmptyState(
            title: "No cooks logged yet",
            message: "No cooks logged yet.",
            systemImage: "fork.knife"
        )
    }

    public var queuedWorkSummary: String? {
        let count = spoonQueuedMutations.count
        guard count > 0 else { return nil }
        return "\(count) cook-log \(count == 1 ? "change" : "changes") waiting to sync"
    }

    public var stagedMediaUsage: SpoonCookLogStagedMediaUsage {
        draftMediaUsage + SpoonCookLogStagedMediaUsage(
            byteCount: spoonQueuedMutations.reduce(0) { $0 + $1.stagedMediaUploadByteCount },
            fileCount: spoonQueuedMutations.reduce(0) { $0 + $1.stagedMediaUploadCount }
        )
    }

    public func evaluateNewPhoto(byteCount: Int, replacing existingPhoto: SpoonCookLogPhotoAttachment? = nil) -> NativeMediaStagingDecision {
        let usage = stagedMediaUsage.removing(
            byteCount: existingPhoto?.byteCount ?? 0,
            fileCount: existingPhoto == nil ? 0 : 1
        )
        return NativeMediaStagingPolicy.offlineProductContract.evaluateNewUserSelectedMedia(
            byteCount: byteCount,
            existingUnsyncedBytes: usage.byteCount,
            existingUnsyncedFileCount: usage.fileCount
        )
    }

    public var conflictBanner: SpoonCookLogConflictBanner? {
        for conflict in conflicts {
            guard spoonQueuedMutations.contains(where: { $0.clientMutationID == conflict.clientMutationID }) else {
                continue
            }
            return SpoonCookLogConflictBanner(
                localClientMutationID: conflict.clientMutationID,
                message: conflict.message,
                actionTitle: "Discard local cook-log change"
            )
        }
        return nil
    }

    public var offlineIndicator: OfflineIndicatorState {
        if let conflictBanner {
            return OfflineIndicatorState(
                display: .conflict(recordID: conflictBanner.localClientMutationID, mutationID: conflictBanner.localClientMutationID),
                dismissal: nil
            )
        }
        switch connectivity {
        case .offline:
            return OfflineIndicatorState(display: .offline, dismissal: nil)
        case .online:
            if let firstMutation = spoonQueuedMutations.first {
                return OfflineIndicatorState(
                    display: .queuedWork(count: spoonQueuedMutations.count, oldestClientMutationID: firstMutation.clientMutationID),
                    dismissal: nil
                )
            }
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        }
    }

    public func plan(_ action: SpoonCookLogAction) throws -> SpoonCookLogMutationPlan {
        switch action {
        case .create(let note, let nextTime, let cookedAt, let photo, let photoURL, let useAsRecipeCover, let clientMutationID):
            let draft = SpoonCookLogDraft(
                note: note,
                nextTime: nextTime,
                cookedAt: cookedAt,
                photoURL: photoURL
            )
            guard draft.hasContent || photo != nil else {
                return SpoonCookLogMutationPlan(blockedReason: "Add a note, next-time thought, or photo before logging this cook.")
            }
            if let photo {
                let queuedPhotoMutation = NativeQueuedMutation.spoonCreatePhoto(
                    recipeID: recipeID,
                    photo: photo.stagedMedia,
                    clientMutationID: clientMutationID,
                    note: draft.note,
                    nextTime: draft.nextTime,
                    cookedAt: draft.cookedAt,
                    useAsRecipeCover: useAsRecipeCover,
                    createdAt: now()
                )
                if photo.data.isEmpty {
                    return SpoonCookLogMutationPlan(queuedMutation: queuedPhotoMutation)
                }
                return try mutationPlan(
                    online: RecipeSpoonRequests.createSpoon(
                        recipeID: recipeID,
                        photo: photo.uploadFile,
                        clientMutationID: clientMutationID,
                        note: draft.note,
                        nextTime: draft.nextTime,
                        cookedAt: draft.cookedAt,
                        useAsRecipeCover: useAsRecipeCover
                    ),
                    offline: queuedPhotoMutation
                )
            }
            return try mutationPlan(
                online: RecipeSpoonRequests.createSpoon(
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    note: draft.note,
                    nextTime: draft.nextTime,
                    cookedAt: draft.cookedAt,
                    photoURL: draft.photoURL,
                    useAsRecipeCover: useAsRecipeCover
                ),
                offline: NativeQueuedMutation.spoonCreate(
                    recipeID: recipeID,
                    clientMutationID: clientMutationID,
                    note: draft.note,
                    nextTime: draft.nextTime,
                    cookedAt: draft.cookedAt,
                    photoURL: draft.photoURL,
                    useAsRecipeCover: useAsRecipeCover,
                    createdAt: now()
                )
            )
        case .update(let spoonID, let note, let nextTime, let cookedAt, let photoURL, let clientMutationID):
            guard row(id: spoonID)?.canEdit == true else {
                return SpoonCookLogMutationPlan(blockedReason: "Only the cook who logged this can edit it.")
            }
            let draft = SpoonCookLogDraft(
                note: note,
                nextTime: nextTime,
                cookedAt: cookedAt,
                photoURL: photoURL
            )
            guard draft.hasContent else {
                return SpoonCookLogMutationPlan(blockedReason: "A cook log needs a note, next-time thought, or photo.")
            }
            return try mutationPlan(
                online: RecipeSpoonRequests.updateSpoon(
                    recipeID: recipeID,
                    spoonID: spoonID,
                    clientMutationID: clientMutationID,
                    note: draft.note,
                    nextTime: draft.nextTime,
                    cookedAt: draft.cookedAt,
                    photoURL: draft.photoURL
                ),
                offline: NativeQueuedMutation.spoonUpdate(
                    recipeID: recipeID,
                    spoonID: spoonID,
                    clientMutationID: clientMutationID,
                    note: draft.note,
                    nextTime: draft.nextTime,
                    cookedAt: draft.cookedAt,
                    photoURL: draft.photoURL,
                    createdAt: now()
                )
            )
        case .delete(let spoonID, let clientMutationID):
            guard row(id: spoonID)?.canDelete == true else {
                return SpoonCookLogMutationPlan(blockedReason: "Only the cook who logged this can delete it.")
            }
            return mutationPlan(
                online: try RecipeSpoonRequests.deleteSpoon(
                    recipeID: recipeID,
                    spoonID: spoonID,
                    clientMutationID: clientMutationID,
                    idempotency: .header
                ),
                offline: NativeQueuedMutation.spoonDelete(
                    recipeID: recipeID,
                    spoonID: spoonID,
                    clientMutationID: clientMutationID,
                    createdAt: now()
                )
            )
        }
    }

    private var spoonQueuedMutations: [NativeQueuedMutation] {
        queuedMutations.filter { mutation in
            mutation.recipeID == recipeID && [
                .spoonCreate,
                .spoonCreatePhoto,
                .spoonUpdate,
                .spoonDelete
            ].contains(mutation.queueableKind)
        }
    }

    private func row(id: String) -> SpoonCookLogRow? {
        rows.first { $0.id == id }
    }

    private func mutationPlan(online: APIRequestBuilder, offline: NativeQueuedMutation) -> SpoonCookLogMutationPlan {
        switch connectivity {
        case .online:
            SpoonCookLogMutationPlan(remoteRequestBuilder: online, offlineFallbackMutation: offline)
        case .offline:
            SpoonCookLogMutationPlan(queuedMutation: offline)
        }
    }
}

private struct SpoonCookLogDraft {
    let note: String?
    let nextTime: String?
    let cookedAt: String?
    let photoURL: String?

    init(note: String?, nextTime: String?, cookedAt: String?, photoURL: String?) {
        self.note = Self.clean(note)
        self.nextTime = Self.clean(nextTime)
        self.cookedAt = Self.clean(cookedAt)
        self.photoURL = Self.clean(photoURL)
    }

    var hasContent: Bool {
        note != nil || nextTime != nil || photoURL != nil
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
