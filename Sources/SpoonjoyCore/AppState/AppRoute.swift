import Foundation

public enum RecipePresentation: Hashable, Sendable {
    case detail
    case cook
}

public enum SearchScope: String, CaseIterable, Hashable, Sendable {
    case all
    case recipes
    case cookbooks
    case chefs
    case shoppingList = "shopping-list"
}

public enum AppSection: Hashable, Sendable {
    case kitchen
    case recipes
    case cookbooks
    case shoppingList
    case search
    case capture
    case settings
}

public enum AppRoute: Hashable, Sendable {
    case kitchen
    case recipes
    case recipeDetail(id: String, presentation: RecipePresentation)
    case cookbooks
    case cookbookDetail(id: String)
    case shoppingList
    case search(query: String, scope: SearchScope)
    case capture
    case settings
    case unknownLink

    public var section: AppSection? {
        switch self {
        case .kitchen:
            .kitchen
        case .recipes, .recipeDetail:
            .recipes
        case .cookbooks, .cookbookDetail:
            .cookbooks
        case .shoppingList:
            .shoppingList
        case .search:
            .search
        case .capture:
            .capture
        case .settings:
            .settings
        case .unknownLink:
            nil
        }
    }

    public var selectedRecipeID: String? {
        switch self {
        case .recipeDetail(let id, _):
            id
        default:
            nil
        }
    }

    public var isCookModeActive: Bool {
        switch self {
        case .recipeDetail(_, .cook):
            true
        default:
            false
        }
    }

    public var stateIdentifier: String {
        switch self {
        case .kitchen:
            "kitchen"
        case .recipes:
            "recipes"
        case .recipeDetail(let id, .detail):
            "recipe:\(id)"
        case .recipeDetail(let id, .cook):
            "recipe-cook:\(id)"
        case .cookbooks:
            "cookbooks"
        case .cookbookDetail(let id):
            "cookbook:\(id)"
        case .shoppingList:
            "shopping-list"
        case .search(let query, let scope):
            "search:\(scope.rawValue):\(query)"
        case .capture:
            "capture"
        case .settings:
            "settings"
        case .unknownLink:
            "unknown-link"
        }
    }
}
