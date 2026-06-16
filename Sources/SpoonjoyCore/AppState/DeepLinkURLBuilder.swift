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
        case .recipeDetail(let id, .detail):
            components.host = "recipes"
            components.path = "/\(id)"
        case .recipeDetail(let id, .cook):
            components.host = "recipes"
            components.path = "/\(id)/cook"
        case .cookbooks:
            components.host = "cookbooks"
        case .cookbookDetail(let id):
            components.host = "cookbooks"
            components.path = "/\(id)"
        case .shoppingList:
            components.host = "shopping-list"
        case .search(let query, let scope):
            components.host = "search"
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "scope", value: scope.rawValue)
            ]
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
