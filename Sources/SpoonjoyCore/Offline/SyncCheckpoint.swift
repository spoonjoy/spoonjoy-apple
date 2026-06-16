import Foundation

public enum SyncCheckpointError: Error, Equatable {
    case emptyUpdatedAt
}

public struct SyncCheckpoint: Codable, Equatable {
    public let shoppingCursor: ShoppingSyncCursor?
    public let updatedAt: String

    public init(shoppingCursor: ShoppingSyncCursor?, updatedAt: String) throws {
        let updatedAt = updatedAt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updatedAt.isEmpty else {
            throw SyncCheckpointError.emptyUpdatedAt
        }

        self.shoppingCursor = shoppingCursor
        self.updatedAt = updatedAt
    }

    public func updatingShoppingCursor(_ cursor: ShoppingSyncCursor, at updatedAt: String) throws -> SyncCheckpoint {
        try SyncCheckpoint(shoppingCursor: cursor, updatedAt: updatedAt)
    }
}
