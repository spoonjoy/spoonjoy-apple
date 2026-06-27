import SpoonjoyCore
import SwiftUI

struct ShareActions: View {
    let route: AppRoute

    var body: some View {
        ShareLink(item: shareURL) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private var shareURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "spoonjoy.app"

        switch route {
        case .kitchen:
            components.path = "/"
        case .recipes:
            components.path = "/recipes"
        case .recipeDetail(let id, .detail):
            components.path = "/recipes/\(id)"
        case .recipeDetail(let id, .cook):
            components.path = "/recipes/\(id)"
            components.queryItems = [URLQueryItem(name: "mode", value: "cook")]
        case .recipeEditor(.some(let id)):
            components.path = "/recipes/\(id)"
        case .recipeEditor(nil):
            components.path = "/recipes"
        case .recipeCoverControls(let id):
            components.path = "/recipes/\(id)"
        case .cookbooks:
            components.path = "/cookbooks"
        case .cookbookDetail(let id):
            components.path = "/cookbooks/\(id)"
        case .shoppingList:
            components.path = "/shopping-list"
        case .search(let query, let scope):
            components.path = "/search"
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "scope", value: scope.rawValue)
            ]
        case .capture:
            components.path = "/recipes/new"
        case .settings:
            components.path = "/account/settings"
        case .unknownLink:
            components.path = "/"
        }

        return components.url ?? Self.fallbackURL
    }

    private static let fallbackURL = URL(string: "https://spoonjoy.app") ?? URL(fileURLWithPath: "/")
}
