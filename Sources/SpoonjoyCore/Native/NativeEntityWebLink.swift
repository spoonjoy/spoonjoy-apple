import Foundation

/// The spoonjoy.app page an App Entity's transfer carries, so "send this to Mail" gives a link anyone with access can
/// open in a browser. Recipes and cookbooks get their public page, the one the share policy allows. Everything else
/// gets the page that shows it to its signed-in owner: a shopping list, a cook log or settings never get a public URL.
public enum NativeEntityWebLink {
    public static func url(for route: AppRoute) -> URL {
        if let publicURL = NativePublicShareRoutePolicy.publicURL(for: route) {
            return publicURL
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = DeepLinkManifest.webDomain
        components.percentEncodedPath = path(for: route)
        // Every path below starts with "/" and percent-encodes its identifiers, so the URL always builds.
        return components.url!
    }

    /// The page for a route when it has no public URL. Internal so tests can reach the routes the public policy takes.
    static func path(for route: AppRoute) -> String {
        switch route {
        case .kitchen, .unknownLink:
            "/"
        case .recipes, .everyoneRecipes:
            "/recipes"
        case .savedRecipes:
            "/saved-recipes"
        case .recipeDetail(let id, _), .recipeEditor(.some(let id)), .recipeCoverControls(let id):
            "/recipes/\(segment(id))"
        case .recipeEditor(nil), .capture:
            "/recipes/new"
        case .cookbooks:
            "/cookbooks"
        case .cookbookDetail(let id):
            "/cookbooks/\(segment(id))"
        case .chefs:
            "/chefs"
        case .profile(let identifier), .profileGraph(let identifier, _, _):
            "/users/\(segment(identifier))"
        case .shoppingList:
            "/shopping-list"
        case .search:
            "/search"
        case .settings:
            "/account/settings"
        }
    }

    /// The recipe that shared text links to: the first spoonjoy.app recipe page in it, as a recipe's share text carries.
    /// What turns a pasted or shared recipe link back into the recipe.
    public static func recipeID(inSharedText text: String) -> String? {
        for word in text.split(whereSeparator: \.isWhitespace) {
            guard let url = URL(string: String(word)),
                  case .recipeDetail(let id, _) = DeepLinkRouter.spoonjoy.route(for: url) else {
                continue
            }
            return id
        }
        return nil
    }

    /// One path segment, percent-encoded so an identifier can never add a segment of its own.
    private static func segment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        // Only a String holding unpaired UTF-16 surrogates fails to encode, and Swift's String can't hold one.
        return value.addingPercentEncoding(withAllowedCharacters: allowed)!
    }
}
