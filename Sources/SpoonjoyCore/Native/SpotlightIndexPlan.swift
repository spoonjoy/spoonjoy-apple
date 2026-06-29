import Foundation

public enum SpotlightIndexType: String, Equatable, Sendable {
    case recipe
    case cookbook
    case spoon
    case shoppingListItem = "shopping-list-item"
    case captureDraft = "capture-draft"
}

public struct SpotlightIndexDocument: Equatable, Sendable {
    public let type: SpotlightIndexType
    public let id: String
    public let uniqueIdentifier: String
    public let domainIdentifier: String
    public let title: String
    public let contentDescription: String
    public let keywords: [String]
    public let route: AppRoute

    public init(
        type: SpotlightIndexType,
        id: String,
        scope: SpotlightIndexScope,
        title: String,
        contentDescription: String,
        keywords: [String],
        route: AppRoute
    ) {
        self.type = type
        self.id = id
        uniqueIdentifier = "\(scope.identifierPrefix)|\(type.rawValue)|\(id)"
        domainIdentifier = "\(scope.domainPrefix).\(type.rawValue)"
        self.title = title
        self.contentDescription = contentDescription
        self.keywords = Self.keywords(type: type, title: title, keywords: keywords)
        self.route = route
    }

    private static func keywords(
        type: SpotlightIndexType,
        title: String,
        keywords: [String]
    ) -> [String] {
        var seen = Set<String>()
        return (["Spoonjoy", type.rawValue, title] + keywords).filter { keyword in
            seen.insert(keyword).inserted
        }
    }
}

public struct SpotlightIndexScope: Equatable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment

    public init(accountID: String, environment: NativeCacheEnvironment) {
        self.accountID = accountID
        self.environment = environment
    }

    public var identifierPrefix: String {
        "\(environment.rawValue)|\(Self.safeComponent(accountID))"
    }

    public var domainPrefix: String {
        "app.spoonjoy.\(environment.rawValue).\(Self.safeComponent(accountID))"
    }

    private static func safeComponent(_ value: String) -> String {
        let filtered = value.map { character in
            character.isLetter || character.isNumber || character == "_" || character == "-" ? String(character) : "-"
        }.joined()
        return filtered.isEmpty ? "unbound" : filtered
    }
}

public enum SpotlightIndexPlan {
    public static func documents(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState,
        scope: SpotlightIndexScope
    ) -> [SpotlightIndexDocument] {
        recipes.map { document(recipe: $0, scope: scope) } +
            cookbooks.map { document(cookbook: $0, scope: scope) } +
            shoppingList.activeItems.map { document(shoppingListItem: $0, scope: scope) }
    }

    public static func document(recipe: Recipe, scope: SpotlightIndexScope) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .recipe,
            id: recipe.id,
            scope: scope,
            title: recipe.title,
            contentDescription: "Recipe by \(recipe.chef.username). \(recipe.description ?? recipe.servings ?? "Ready to cook in Spoonjoy.")",
            keywords: [recipe.chef.username] + recipe.steps.flatMap { step in
                step.ingredients.map(\.name)
            },
            route: .recipeDetail(id: recipe.id, presentation: .detail)
        )
    }

    public static func document(cookbook: Cookbook, scope: SpotlightIndexScope) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .cookbook,
            id: cookbook.id,
            scope: scope,
            title: cookbook.title,
            contentDescription: "Cookbook by \(cookbook.chef.username) with \(cookbook.recipeCount) \(recipeCountLabel(cookbook.recipeCount)).",
            keywords: [cookbook.chef.username] + cookbook.recipes.map(\.title),
            route: .cookbookDetail(id: cookbook.id)
        )
    }

    public static func document(shoppingListItem item: ShoppingListItem, scope: SpotlightIndexScope) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .shoppingListItem,
            id: item.id,
            scope: scope,
            title: item.name,
            contentDescription: "Shopping list item in Spoonjoy. \(item.displayQuantity)",
            keywords: [item.name, item.categoryKey ?? "shopping"],
            route: .shoppingList
        )
    }

    public static func shoppingListItemUniqueIdentifier(itemID: String, scope: SpotlightIndexScope) -> String {
        "\(scope.identifierPrefix)|\(SpotlightIndexType.shoppingListItem.rawValue)|\(itemID)"
    }

    public static func shoppingListItemDomainIdentifier(scope: SpotlightIndexScope) -> String {
        "\(scope.domainPrefix).\(SpotlightIndexType.shoppingListItem.rawValue)"
    }

    public static func spoonUniqueIdentifier(spoonID: String, scope: SpotlightIndexScope) -> String {
        "\(scope.identifierPrefix)|\(SpotlightIndexType.spoon.rawValue)|\(spoonID)"
    }

    public static func spoonDomainIdentifier(scope: SpotlightIndexScope) -> String {
        "\(scope.domainPrefix).\(SpotlightIndexType.spoon.rawValue)"
    }

    public static func captureDraftUniqueIdentifier(draftID: String, scope: SpotlightIndexScope) -> String {
        "\(scope.identifierPrefix)|\(SpotlightIndexType.captureDraft.rawValue)|\(draftID)"
    }

    public static func captureDraftDomainIdentifier(scope: SpotlightIndexScope) -> String {
        "\(scope.domainPrefix).\(SpotlightIndexType.captureDraft.rawValue)"
    }

    public static func route(uniqueIdentifier: String) -> AppRoute {
        let parts = uniqueIdentifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4,
              NativeCacheEnvironment(rawValue: parts[0]) != nil,
              isSafeObjectID(parts[1]),
              let type = SpotlightIndexType(rawValue: parts[2]) else {
            return .unknownLink
        }

        let id = parts[3]
        switch type {
        case .recipe:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .recipeDetail(id: id, presentation: .detail)
        case .cookbook:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .cookbookDetail(id: id)
        case .spoon:
            return .unknownLink
        case .shoppingListItem:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .shoppingList
        case .captureDraft:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .capture
        }
    }

    private static func recipeCountLabel(_ recipeCount: Int) -> String {
        recipeCount == 1 ? "recipe" : "recipes"
    }

    private static func isSafeObjectID(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { character in
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }
    }
}
