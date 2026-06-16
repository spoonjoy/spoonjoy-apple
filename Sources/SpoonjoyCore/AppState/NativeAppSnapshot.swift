import Foundation

public enum NativeAppSnapshotError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

public struct NativeAppSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let hasCompletedFirstRun: Bool
    public let cookProgressByRecipeID: [String: CookModeProgress]
    public let shoppingList: ShoppingListState?
    public let captureDraft: CaptureDraft?
    public let pendingMutations: MutationQueue
    public let savedAt: String

    public static func bootstrap(shoppingList: ShoppingListState?, savedAt: String) -> NativeAppSnapshot {
        NativeAppSnapshot(
            schemaVersion: 1,
            hasCompletedFirstRun: false,
            cookProgressByRecipeID: [:],
            shoppingList: shoppingList,
            captureDraft: nil,
            pendingMutations: MutationQueue(),
            savedAt: savedAt
        )
    }

    public var pendingMutationCount: Int {
        pendingMutations.mutations.count
    }

    public var offlineState: OfflineState {
        shoppingList == nil
            ? .unavailable
            : .available(snapshotCount: max(1, pendingMutationCount), lastRestoredAt: savedAt)
    }

    public func validated() throws -> NativeAppSnapshot {
        guard schemaVersion == 1 else {
            throw NativeAppSnapshotError.unsupportedSchemaVersion(schemaVersion)
        }

        return self
    }

    public func cookProgress(for recipeID: String) -> CookModeProgress? {
        cookProgressByRecipeID[recipeID]
    }

    public func completingFirstRun(savedAt: String) -> NativeAppSnapshot {
        copy(hasCompletedFirstRun: true, savedAt: savedAt)
    }

    public func updatingCookProgress(_ progress: CookModeProgress, savedAt: String) -> NativeAppSnapshot {
        var nextProgress = cookProgressByRecipeID
        nextProgress[progress.recipeID] = progress

        return copy(cookProgressByRecipeID: nextProgress, savedAt: savedAt)
    }

    public func updatingShoppingList(
        _ shoppingList: ShoppingListState,
        queuedMutation: QueuedMutation?,
        savedAt: String
    ) throws -> NativeAppSnapshot {
        let nextMutations: MutationQueue
        if let queuedMutation {
            nextMutations = try pendingMutations.appending(queuedMutation)
        } else {
            nextMutations = pendingMutations
        }

        return copy(
            shoppingList: shoppingList,
            pendingMutations: nextMutations,
            savedAt: savedAt
        )
    }

    public func updatingCaptureDraft(_ captureDraft: CaptureDraft, savedAt: String) -> NativeAppSnapshot {
        copy(captureDraft: captureDraft, savedAt: savedAt)
    }

    private func copy(
        hasCompletedFirstRun: Bool? = nil,
        cookProgressByRecipeID: [String: CookModeProgress]? = nil,
        shoppingList: ShoppingListState?? = nil,
        captureDraft: CaptureDraft?? = nil,
        pendingMutations: MutationQueue? = nil,
        savedAt: String
    ) -> NativeAppSnapshot {
        NativeAppSnapshot(
            schemaVersion: schemaVersion,
            hasCompletedFirstRun: hasCompletedFirstRun ?? self.hasCompletedFirstRun,
            cookProgressByRecipeID: cookProgressByRecipeID ?? self.cookProgressByRecipeID,
            shoppingList: shoppingList ?? self.shoppingList,
            captureDraft: captureDraft ?? self.captureDraft,
            pendingMutations: pendingMutations ?? self.pendingMutations,
            savedAt: savedAt
        )
    }
}

public struct NativeAppStateStore {
    private let store: JSONFileStore<NativeAppSnapshot>

    public init(fileURL: URL) {
        store = JSONFileStore<NativeAppSnapshot>(fileURL: fileURL)
    }

    public func loadOrCreate(fallback: NativeAppSnapshot) throws -> JSONFileStoreRecord<NativeAppSnapshot> {
        if let record = try store.load() {
            return JSONFileStoreRecord(value: try record.value.validated(), source: record.source)
        }

        return JSONFileStoreRecord(value: fallback, source: .fallback)
    }

    public func save(_ snapshot: NativeAppSnapshot) throws {
        try store.save(try snapshot.validated())
    }
}
