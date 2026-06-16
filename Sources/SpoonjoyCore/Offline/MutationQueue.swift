import Foundation

public enum MutationQueueError: Error, Equatable {
    case emptyClientMutationID
    case duplicateClientMutationID(String)
}

public enum QueuedMutationKind: Codable, Equatable {
    case shoppingAdd(
        name: String,
        quantity: Double?,
        unit: String?,
        categoryKey: String?,
        iconKey: String?
    )
    case shoppingCheck(itemID: String, checked: Bool)
    case shoppingDelete(itemID: String)
}

public struct QueuedMutation: Codable, Equatable {
    public let id: String
    public let clientMutationID: String
    public let createdAt: String
    public let kind: QueuedMutationKind

    public init(id: String, clientMutationID: String, createdAt: String, kind: QueuedMutationKind) {
        self.id = id
        self.clientMutationID = clientMutationID
        self.createdAt = createdAt
        self.kind = kind
    }
}

public struct MutationQueue: Codable, Equatable {
    public let mutations: [QueuedMutation]

    public init(mutations: [QueuedMutation] = []) {
        self.mutations = mutations
    }

    public func appending(_ mutation: QueuedMutation) throws -> MutationQueue {
        let clientMutationID = mutation.clientMutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientMutationID.isEmpty else {
            throw MutationQueueError.emptyClientMutationID
        }
        guard !mutations.contains(where: { $0.clientMutationID == clientMutationID }) else {
            throw MutationQueueError.duplicateClientMutationID(clientMutationID)
        }

        return MutationQueue(mutations: mutations + [mutation])
    }

    public func removing(clientMutationID: String) -> MutationQueue {
        MutationQueue(mutations: mutations.filter { $0.clientMutationID != clientMutationID })
    }
}
