import Foundation

public struct SearchState: Equatable {
    public private(set) var query: String
    public private(set) var scope: SearchScope

    public init(query: String = "", scope: SearchScope = .all) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
    }

    public var hasQuery: Bool {
        !query.isEmpty
    }

    public var route: AppRoute {
        .search(query: query, scope: scope)
    }

    public mutating func update(query: String, scope: SearchScope) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
    }
}
