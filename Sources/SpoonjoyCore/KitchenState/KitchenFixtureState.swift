import Foundation

public enum KitchenFixtureStatus: String, Codable, Equatable {
    case bootstrap
    case ready
}

public enum KitchenLeadObject: Equatable {
    case recipe(id: String, title: String)
}

extension KitchenLeadObject: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case title
    }

    private enum Kind: String, Codable {
        case recipe
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .recipe:
            self = .recipe(
                id: try container.decode(String.self, forKey: .id),
                title: try container.decode(String.self, forKey: .title)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .recipe(let id, let title):
            try container.encode(Kind.recipe, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
        }
    }
}

public enum KitchenPrimaryAction: Equatable {
    case startCookMode(recipeID: String)
}

extension KitchenPrimaryAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case recipeID
    }

    private enum Kind: String, Codable {
        case startCookMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .startCookMode:
            self = .startCookMode(recipeID: try container.decode(String.self, forKey: .recipeID))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .startCookMode(let recipeID):
            try container.encode(Kind.startCookMode, forKey: .kind)
            try container.encode(recipeID, forKey: .recipeID)
        }
    }
}

public struct KitchenCounts: Codable, Equatable {
    public let recipes: Int
    public let cookbooks: Int
    public let shoppingItems: Int

    public init(recipes: Int, cookbooks: Int, shoppingItems: Int) {
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.shoppingItems = shoppingItems
    }
}

public struct OfflineRestoreMetadata: Codable, Equatable {
    public let snapshotID: String
    public let includesShoppingList: Bool
}

public struct KitchenFixtureState: Codable, Equatable {
    public let status: KitchenFixtureStatus
    public let leadObject: KitchenLeadObject
    public let primaryAction: KitchenPrimaryAction
    public let counts: KitchenCounts
    public let offlineRestore: OfflineRestoreMetadata

    public static func decodeFromBundle() throws -> KitchenFixtureState {
        try JSONDecoder().decode(KitchenFixtureState.self, from: SpoonjoyFixture.data(named: "kitchen-fixture"))
    }
}
