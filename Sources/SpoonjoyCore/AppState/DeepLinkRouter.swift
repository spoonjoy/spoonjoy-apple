import Foundation

public struct DeepLinkRouter: Equatable, Sendable {
    public let webHost: String
    public let scheme: String

    public init(webHost: String, scheme: String) {
        self.webHost = webHost
        self.scheme = scheme
    }

    public static let spoonjoy = DeepLinkRouter(webHost: "spoonjoy.app", scheme: "spoonjoy")

    public func route(for url: URL) -> AppRoute {
        route(for: URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    func route(for components: URLComponents?) -> AppRoute {
        guard let components else {
            return .unknownLink
        }

        switch components.scheme?.lowercased() {
        case "https":
            guard components.host?.lowercased() == webHost else {
                return .unknownLink
            }
            return routeWebPath(components)
        case scheme:
            return routeSchemePath(components)
        default:
            return .unknownLink
        }
    }

    private func routeWebPath(_ components: URLComponents) -> AppRoute {
        let path = components.percentEncodedPath
        guard path == "/" || !path.hasSuffix("/") else {
            return .unknownLink
        }

        let segments = decodedSegments(path)
        let rawSegments = encodedSegments(path)

        if segments.isEmpty {
            return .kitchen
        }

        if segments == ["recipes"] {
            return .recipes
        }

        if segments == ["recipes", "new"] {
            return .capture
        }

        if segments.count == 3, segments[0] == "recipes", segments[2] == "edit" {
            let id = segments[1]
            guard safeID(id), id != "new" else {
                return .unknownLink
            }
            return .recipeEditor(id: id)
        }

        if segments.count == 2, segments[0] == "recipes" {
            let id = segments[1]
            guard safeID(id) else {
                return .unknownLink
            }
            return .recipeDetail(id: id, presentation: recipePresentation(components))
        }

        if segments == ["cookbooks"] {
            return .cookbooks
        }

        if segments.count == 2, segments[0] == "cookbooks" {
            let id = segments[1]
            guard safeID(id) else {
                return .unknownLink
            }
            return .cookbookDetail(id: id)
        }

        if segments.count == 2, segments[0] == "users" {
            guard let identifier = AppRoute.decodedProfileIdentifier(rawSegments[1]) else {
                return .unknownLink
            }
            return .profile(identifier: identifier)
        }

        if segments.count == 3, segments[0] == "users" {
            guard let identifier = AppRoute.decodedProfileIdentifier(rawSegments[1]),
                  let direction = ProfileGraphDirection(rawValue: segments[2]) else {
                return .unknownLink
            }
            return .profileGraph(identifier: identifier, direction: direction, page: graphPage(components))
        }

        if segments == ["shopping-list"] {
            return .shoppingList
        }

        if segments == ["search"] {
            return searchRoute(components)
        }

        if segments == ["account", "settings"] {
            return .settings
        }

        return .unknownLink
    }

    private func routeSchemePath(_ components: URLComponents) -> AppRoute {
        guard let host = components.host, !host.isEmpty else {
            return .unknownLink
        }
        guard components.percentEncodedPath.isEmpty || !components.percentEncodedPath.hasSuffix("/") else {
            return .unknownLink
        }

        let segments = [host] + decodedSegments(components.percentEncodedPath)
        let rawSegments = [host] + encodedSegments(components.percentEncodedPath)

        if segments == ["kitchen"] {
            return .kitchen
        }

        if segments == ["recipes"] {
            return .recipes
        }

        if segments.count == 2, segments[0] == "recipes" {
            let id = segments[1]
            guard safeID(id) else {
                return .unknownLink
            }
            return .recipeDetail(id: id, presentation: .detail)
        }

        if segments.count == 3, segments[0] == "recipes", segments[2] == "cook" {
            let id = segments[1]
            guard safeID(id) else {
                return .unknownLink
            }
            return .recipeDetail(id: id, presentation: .cook)
        }

        if segments.count == 3, segments[0] == "recipes", segments[2] == "edit" {
            let id = segments[1]
            if id == "new" {
                return .recipeEditor(id: nil)
            }
            guard safeID(id) else {
                return .unknownLink
            }
            return .recipeEditor(id: id)
        }

        if segments.count == 3, segments[0] == "recipes", segments[2] == "covers" {
            let id = segments[1]
            guard safeID(id), id != "new" else {
                return .unknownLink
            }
            return .recipeCoverControls(id: id)
        }

        if segments == ["cookbooks"] {
            return .cookbooks
        }

        if segments.count == 2, segments[0] == "cookbooks" {
            let id = segments[1]
            guard safeID(id) else {
                return .unknownLink
            }
            return .cookbookDetail(id: id)
        }

        if segments.count == 2, segments[0] == "users" {
            guard let identifier = AppRoute.decodedProfileIdentifier(rawSegments[1]) else {
                return .unknownLink
            }
            return .profile(identifier: identifier)
        }

        if segments.count == 3, segments[0] == "users" {
            guard let identifier = AppRoute.decodedProfileIdentifier(rawSegments[1]),
                  let direction = ProfileGraphDirection(rawValue: segments[2]) else {
                return .unknownLink
            }
            return .profileGraph(identifier: identifier, direction: direction, page: graphPage(components))
        }

        if segments == ["shopping-list"] {
            return .shoppingList
        }

        if segments == ["search"] {
            return searchRoute(components)
        }

        if segments == ["capture"] {
            return .capture
        }

        if segments == ["settings"] {
            return .settings
        }

        return .unknownLink
    }

    private func recipePresentation(_ components: URLComponents) -> RecipePresentation {
        if components.percentEncodedFragment == "cook" {
            return .cook
        }

        let mode = components.queryItems?.first { $0.name == "mode" }?.value
        return mode == "cook" ? .cook : .detail
    }

    private func searchRoute(_ components: URLComponents) -> AppRoute {
        guard
            let rawQuery = components.queryItems?.first(where: { $0.name == "q" })?.value,
            !rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .unknownLink
        }

        let rawScope = components.queryItems?.first(where: { $0.name == "scope" })?.value ?? SearchScope.all.rawValue
        guard let scope = SearchScope(rawValue: rawScope) else {
            return .unknownLink
        }

        return .search(query: rawQuery, scope: scope)
    }

    private func graphPage(_ components: URLComponents) -> Int {
        guard let rawPage = components.queryItems?.first(where: { $0.name == "page" })?.value,
              let page = Int(rawPage),
              page > 0 else {
            return 1
        }
        return page
    }

    func decodedSegments(_ percentEncodedPath: String) -> [String] {
        encodedSegments(percentEncodedPath)
            .map { $0.removingPercentEncoding ?? $0 }
    }

    private func encodedSegments(_ percentEncodedPath: String) -> [String] {
        percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func safeID(_ id: String) -> Bool {
        guard id.trimmingCharacters(in: .whitespacesAndNewlines) == id, !id.isEmpty else {
            return false
        }
        guard !id.contains("/"), !id.contains("\\"), !id.contains(".."), id != ".", id != ".." else {
            return false
        }

        return id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }
}
