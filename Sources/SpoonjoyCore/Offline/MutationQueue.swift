import Foundation

public enum MutationQueueError: Error, Equatable {
    case emptyClientMutationID
    case duplicateClientMutationID(String)
}

public enum QueuedMutationKind: Equatable {
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

    public init() {
        mutations = []
    }

    public init(mutations: [QueuedMutation]) throws {
        self.mutations = try Self.validatedMutations(mutations)
    }

    private init(validatedMutations: [QueuedMutation]) {
        self.mutations = validatedMutations
    }

    public func appending(_ mutation: QueuedMutation) throws -> MutationQueue {
        let canonicalMutation = try Self.canonicalMutation(mutation)
        let clientMutationID = canonicalMutation.clientMutationID
        guard !mutations.contains(where: { $0.clientMutationID == clientMutationID }) else {
            throw MutationQueueError.duplicateClientMutationID(clientMutationID)
        }

        return MutationQueue(validatedMutations: mutations + [canonicalMutation])
    }

    public func removing(clientMutationID: String) -> MutationQueue {
        let clientMutationID = clientMutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        return MutationQueue(validatedMutations: mutations.filter { $0.clientMutationID != clientMutationID })
    }

    private static func validatedMutations(_ mutations: [QueuedMutation]) throws -> [QueuedMutation] {
        var seenClientMutationIDs = Set<String>()
        var canonicalMutations: [QueuedMutation] = []

        for mutation in mutations {
            let canonicalMutation = try canonicalMutation(mutation)
            guard seenClientMutationIDs.insert(canonicalMutation.clientMutationID).inserted else {
                throw MutationQueueError.duplicateClientMutationID(canonicalMutation.clientMutationID)
            }

            canonicalMutations.append(canonicalMutation)
        }

        return canonicalMutations
    }

    private static func canonicalMutation(_ mutation: QueuedMutation) throws -> QueuedMutation {
        let clientMutationID = mutation.clientMutationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientMutationID.isEmpty else {
            throw MutationQueueError.emptyClientMutationID
        }

        return QueuedMutation(
            id: mutation.id,
            clientMutationID: clientMutationID,
            createdAt: mutation.createdAt,
            kind: mutation.kind
        )
    }
}

extension MutationQueue {
    private enum CodingKeys: String, CodingKey {
        case mutations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mutations = try Self.validatedMutations(
            container.decode([QueuedMutation].self, forKey: .mutations)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mutations, forKey: .mutations)
    }
}

extension QueuedMutationKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case name
        case quantity
        case unit
        case categoryKey
        case iconKey
        case itemID = "itemId"
        case checked
    }

    private enum KindType: String {
        case shoppingAdd = "shopping.add"
        case shoppingCheck = "shopping.check"
        case shoppingDelete = "shopping.delete"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch KindType(rawValue: type) {
        case .shoppingAdd:
            self = .shoppingAdd(
                name: try container.decode(String.self, forKey: .name),
                quantity: try container.decodeIfPresent(Double.self, forKey: .quantity),
                unit: try container.decodeIfPresent(String.self, forKey: .unit),
                categoryKey: try container.decodeIfPresent(String.self, forKey: .categoryKey),
                iconKey: try container.decodeIfPresent(String.self, forKey: .iconKey)
            )
        case .shoppingCheck:
            self = .shoppingCheck(
                itemID: try container.decode(String.self, forKey: .itemID),
                checked: try container.decode(Bool.self, forKey: .checked)
            )
        case .shoppingDelete:
            self = .shoppingDelete(itemID: try container.decode(String.self, forKey: .itemID))
        case nil:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown queued mutation type \(type)."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .shoppingAdd(let name, let quantity, let unit, let categoryKey, let iconKey):
            try container.encode(KindType.shoppingAdd.rawValue, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(quantity, forKey: .quantity)
            try container.encodeIfPresent(unit, forKey: .unit)
            try container.encodeIfPresent(categoryKey, forKey: .categoryKey)
            try container.encodeIfPresent(iconKey, forKey: .iconKey)
        case .shoppingCheck(let itemID, let checked):
            try container.encode(KindType.shoppingCheck.rawValue, forKey: .type)
            try container.encode(itemID, forKey: .itemID)
            try container.encode(checked, forKey: .checked)
        case .shoppingDelete(let itemID):
            try container.encode(KindType.shoppingDelete.rawValue, forKey: .type)
            try container.encode(itemID, forKey: .itemID)
        }
    }
}

extension QueuedMutation {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case clientMutationID = "clientMutationId"
        case createdAt
        case kind
    }

    private static let schemaVersion = 1

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported queued mutation schema version \(schemaVersion)."
            )
        }

        self.init(
            id: try container.decode(String.self, forKey: .id),
            clientMutationID: try container.decode(String.self, forKey: .clientMutationID),
            createdAt: try container.decode(String.self, forKey: .createdAt),
            kind: try container.decode(QueuedMutationKind.self, forKey: .kind)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(clientMutationID, forKey: .clientMutationID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(kind, forKey: .kind)
    }
}
