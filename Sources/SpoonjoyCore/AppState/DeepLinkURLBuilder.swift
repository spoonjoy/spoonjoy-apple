import Foundation

public enum DeepLinkURLBuilder {
    public static func url(for route: AppRoute) -> URL {
        var components = URLComponents()
        components.scheme = DeepLinkManifest.urlSchemes[0]

        switch route {
        case .kitchen:
            components.host = "kitchen"
        case .recipes:
            components.host = "recipes"
        case .savedRecipes:
            components.host = "saved-recipes"
        case .recipeDetail(let id, .detail):
            components.host = "recipes"
            components.path = "/\(id)"
        case .recipeDetail(let id, .cook):
            components.host = "recipes"
            components.path = "/\(id)/cook"
        case .recipeEditor(.some(let id)):
            components.host = "recipes"
            components.path = "/\(id)/edit"
        case .recipeEditor(nil):
            components.host = "recipes"
            components.path = "/new/edit"
        case .recipeCoverControls(let id):
            components.host = "recipes"
            components.path = "/\(id)/covers"
        case .cookbooks:
            components.host = "cookbooks"
        case .cookbookDetail(let id):
            components.host = "cookbooks"
            components.path = "/\(id)"
        case .chefs:
            components.host = "chefs"
        case .profile(let identifier):
            components.host = "users"
            components.percentEncodedPath = "/\(AppRoute.encodedProfileIdentifier(identifier))"
        case .profileGraph(let identifier, let direction, let page):
            components.host = "users"
            components.percentEncodedPath = "/\(AppRoute.encodedProfileIdentifier(identifier))/\(direction.rawValue)"
            components.queryItems = [
                URLQueryItem(name: "page", value: String(page))
            ]
        case .shoppingList:
            components.host = "shopping-list"
        case .search(let query, let scope):
            components.host = "search"
            if query.isEmpty && scope == .all {
                components.queryItems = nil
            } else if query.isEmpty {
                components.queryItems = [
                    URLQueryItem(name: "scope", value: scope.rawValue)
                ]
            } else {
                components.queryItems = [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "scope", value: scope.rawValue)
                ]
            }
        case .capture:
            components.host = "capture"
        case .settings:
            components.host = "settings"
        case .unknownLink:
            components.host = "unknown"
        }

        return components.url!
    }
}
