import Foundation

public enum SpotlightIndexType: String, Equatable, Sendable {
    case recipe
    case cookbook
    case shoppingListItem = "shopping-list-item"
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
        title: String,
        contentDescription: String,
        keywords: [String],
        route: AppRoute
    ) {
        self.type = type
        self.id = id
        uniqueIdentifier = "\(type.rawValue):\(id)"
        domainIdentifier = "app.spoonjoy.\(type.rawValue)"
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

public enum SpotlightIndexPlan {
    public static func documents(
        recipes: [Recipe],
        cookbooks: [Cookbook],
        shoppingList: ShoppingListState
    ) -> [SpotlightIndexDocument] {
        recipes.map(document(recipe:)) +
            cookbooks.map(document(cookbook:)) +
            shoppingList.activeItems.map(document(shoppingListItem:))
    }

    public static func document(recipe: Recipe) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .recipe,
            id: recipe.id,
            title: recipe.title,
            contentDescription: "Recipe by \(recipe.chef.username). \(recipe.description ?? recipe.servings ?? "Ready to cook in Spoonjoy.")",
            keywords: [recipe.chef.username] + recipe.steps.flatMap { step in
                step.ingredients.map(\.name)
            },
            route: .recipeDetail(id: recipe.id, presentation: .detail)
        )
    }

    public static func document(cookbook: Cookbook) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .cookbook,
            id: cookbook.id,
            title: cookbook.title,
            contentDescription: "Cookbook by \(cookbook.chef.username) with \(cookbook.recipeCount) \(recipeCountLabel(cookbook.recipeCount)).",
            keywords: [cookbook.chef.username] + cookbook.recipes.map(\.title),
            route: .cookbookDetail(id: cookbook.id)
        )
    }

    public static func document(shoppingListItem item: ShoppingListItem) -> SpotlightIndexDocument {
        SpotlightIndexDocument(
            type: .shoppingListItem,
            id: item.id,
            title: item.name,
            contentDescription: "Shopping list item in Spoonjoy. \(item.displayQuantity)",
            keywords: [item.name, item.categoryKey ?? "shopping"],
            route: .shoppingList
        )
    }

    public static func route(uniqueIdentifier: String) -> AppRoute {
        let parts = uniqueIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let type = SpotlightIndexType(rawValue: parts[0]) else {
            return .unknownLink
        }

        let id = parts[1]
        switch type {
        case .recipe:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .recipeDetail(id: id, presentation: .detail)
        case .cookbook:
            guard isSafeObjectID(id) else { return .unknownLink }
            return .cookbookDetail(id: id)
        case .shoppingListItem:
            return .shoppingList
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
