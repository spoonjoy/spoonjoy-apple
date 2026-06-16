import Foundation

public struct ShoppingSyncCursor: RawRepresentable, Codable, Equatable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        self.rawValue = trimmed
    }
}

public struct ShoppingListResponse: Decodable, Equatable {
    public let id: String
    public let chef: ChefSummary
    public let items: [ShoppingListItem]
    public let updatedAt: String
}

public struct ShoppingListReadData: Decodable, Equatable {
    public let shoppingList: ShoppingListResponse
    public let nextCursor: ShoppingSyncCursor
}

public struct ShoppingListSyncData: Decodable, Equatable {
    public let items: [ShoppingListItem]
    public let nextCursor: ShoppingSyncCursor
    public let hasMore: Bool
}

public struct ShoppingItemMutationData: Decodable, Equatable {
    public let created: Bool
    public let updated: Bool
    public let removed: Bool?
    public let item: ShoppingListItem
    public let mutation: ShoppingListMutationMetadata

    private enum CodingKeys: String, CodingKey {
        case created
        case updated
        case removed
        case item
        case mutation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        created = try container.decodeIfPresent(Bool.self, forKey: .created) ?? false
        updated = try container.decodeIfPresent(Bool.self, forKey: .updated) ?? false
        removed = try container.decodeIfPresent(Bool.self, forKey: .removed)
        item = try container.decode(ShoppingListItem.self, forKey: .item)
        mutation = try container.decode(ShoppingListMutationMetadata.self, forKey: .mutation)
    }
}
