import Foundation

public enum OfflineSnapshotError: Error, Equatable {
    case emptyCapturedAt
    case missingShoppingList
    case unsupportedSchemaVersion(Int)
}

public struct OfflineSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let capturedAt: String
    public let shoppingList: ShoppingListState?
    public let syncCheckpoint: SyncCheckpoint?
    public let pendingMutations: MutationQueue

    public init(
        schemaVersion: Int,
        capturedAt: String,
        shoppingList: ShoppingListState?,
        syncCheckpoint: SyncCheckpoint?,
        pendingMutations: MutationQueue
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.shoppingList = shoppingList
        self.syncCheckpoint = syncCheckpoint
        self.pendingMutations = pendingMutations
    }

    public func restore() throws -> OfflineRestoreState {
        guard schemaVersion == 1 else {
            throw OfflineSnapshotError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !capturedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OfflineSnapshotError.emptyCapturedAt
        }
        guard let shoppingList else {
            throw OfflineSnapshotError.missingShoppingList
        }

        return OfflineRestoreState(
            shoppingList: shoppingList,
            syncCheckpoint: syncCheckpoint,
            pendingMutations: pendingMutations
        )
    }
}

public struct OfflineRestoreState: Equatable {
    public let shoppingList: ShoppingListState
    public let syncCheckpoint: SyncCheckpoint?
    public let pendingMutations: MutationQueue

    public var pendingMutationCount: Int {
        pendingMutations.mutations.count
    }
}
