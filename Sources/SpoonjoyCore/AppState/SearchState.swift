import Foundation

public struct SearchState: Equatable, Hashable, Sendable {
    /// Exactly what the person typed into the search field, including leading and trailing spaces.
    /// The field reads this back, so trimming it while typing would delete a space before the next word.
    public private(set) var text: String
    public private(set) var scope: SearchScope

    public init(query: String = "", scope: SearchScope = .all) {
        self.text = query
        self.scope = scope
    }

    /// The trimmed query that requests and routes use.
    public var query: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var hasQuery: Bool {
        !query.isEmpty
    }

    public var route: AppRoute {
        .search(query: query, scope: scope)
    }

    public mutating func update(query: String, scope: SearchScope) {
        self.text = query
        self.scope = scope
    }

    /// Hydrates from a search route. When the route names the query already in the field, the field text is kept
    /// as typed, so a search that runs while someone is still typing does not remove their trailing space.
    @discardableResult
    public mutating func apply(route: AppRoute) -> Bool {
        guard case .search(let routeQuery, let scope) = route else {
            return false
        }

        let trimmedRouteQuery = routeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        update(query: trimmedRouteQuery == query ? text : trimmedRouteQuery, scope: scope)
        return true
    }
}
