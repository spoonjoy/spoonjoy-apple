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
    case recipeEditor(id: String?)
    case recipeCoverControls(id: String)
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
        case .recipes, .recipeDetail, .recipeEditor, .recipeCoverControls:
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
        case .recipeDetail(let id, _), .recipeEditor(.some(let id)), .recipeCoverControls(let id):
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
        case .recipeEditor(.some(let id)):
            "recipe-editor:\(id)"
        case .recipeEditor(nil):
            "recipe-editor:new"
        case .recipeCoverControls(let id):
            "recipe-covers:\(id)"
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

    public init?(stateIdentifier: String) {
        let parts = stateIdentifier.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts == ["kitchen"] {
            self = .kitchen
        } else if parts == ["recipes"] {
            self = .recipes
        } else if parts.count == 2, parts[0] == "recipe", Self.isSafeID(parts[1]) {
            self = .recipeDetail(id: parts[1], presentation: .detail)
        } else if parts.count == 2, parts[0] == "recipe-cook", Self.isSafeID(parts[1]) {
            self = .recipeDetail(id: parts[1], presentation: .cook)
        } else if parts.count == 2, parts[0] == "recipe-editor", parts[1] == "new" {
            self = .recipeEditor(id: nil)
        } else if parts.count == 2, parts[0] == "recipe-editor", Self.isSafeID(parts[1]) {
            self = .recipeEditor(id: parts[1])
        } else if parts.count == 2, parts[0] == "recipe-covers", Self.isSafeID(parts[1]) {
            self = .recipeCoverControls(id: parts[1])
        } else if parts == ["cookbooks"] {
            self = .cookbooks
        } else if parts.count == 2, parts[0] == "cookbook", Self.isSafeID(parts[1]) {
            self = .cookbookDetail(id: parts[1])
        } else if parts == ["shopping-list"] {
            self = .shoppingList
        } else if parts.count >= 3, parts[0] == "search" {
            let rawScope = parts[1]
            let query = parts.dropFirst(2).joined(separator: ":")
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            guard let scope = SearchScope(rawValue: rawScope) else {
                return nil
            }
            self = .search(query: query, scope: scope)
        } else if parts == ["capture"] {
            self = .capture
        } else if parts == ["settings"] {
            self = .settings
        } else if parts == ["unknown-link"] {
            self = .unknownLink
        } else {
            return nil
        }
    }

    private static func isSafeID(_ id: String) -> Bool {
        guard id.trimmingCharacters(in: .whitespacesAndNewlines) == id, !id.isEmpty else {
            return false
        }
        guard !id.contains("/"), !id.contains("\\"), !id.contains(".."), id != ".", id != ".." else {
            return false
        }
        return id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}
