import Foundation

public struct SearchSurfaceContext: Equatable, Hashable, Sendable {
    public let isAuthenticated: Bool
    public let canReadShoppingList: Bool

    public init(isAuthenticated: Bool, canReadShoppingList: Bool) {
        self.isAuthenticated = isAuthenticated
        self.canReadShoppingList = canReadShoppingList
    }
}

public struct SearchSurfaceSection: Identifiable, Equatable, Sendable {
    public let kind: SearchScope
    public let rows: [SearchSurfaceRow]

    public var id: SearchScope {
        kind
    }

    public var title: String {
        switch kind {
        case .all:
            "All"
        case .recipes:
            "Recipes"
        case .cookbooks:
            "Cookbooks"
        case .chefs:
            "Chefs"
        case .shoppingList:
            "Shopping"
        }
    }

    public init(kind: SearchScope, rows: [SearchSurfaceRow]) {
        self.kind = kind
        self.rows = rows
    }
}

public struct SearchSurfaceRow: Identifiable, Equatable, Sendable {
    public let result: SearchSurfaceResult

    public var id: String {
        "\(result.type.rawValue)-\(result.id)"
    }

    public var title: String {
        result.title
    }

    public var subtitle: String {
        result.subtitle ?? result.snippet ?? ""
    }

    public var imageURL: URL? {
        result.imageURL
    }

    public var openRoute: AppRoute {
        switch result.type {
        case .recipe:
            AppRoute.recipeDetail(id: result.id, presentation: .detail)
        case .cookbook:
            AppRoute.cookbookDetail(id: result.id)
        case .chef:
            AppRoute.profile(identifier: result.ownerUsername ?? result.title)
        case .shoppingListItem:
            AppRoute.shoppingList
        }
    }

    public var systemImage: String {
        switch result.type {
        case .recipe:
            "book.closed"
        case .cookbook:
            "books.vertical"
        case .chef:
            "person.crop.circle"
        case .shoppingListItem:
            "cart"
        }
    }

    public var accessibilityLabel: String {
        let kind = switch result.type {
        case .recipe: "Recipe"
        case .cookbook: "Cookbook"
        case .chef: "Chef"
        case .shoppingListItem: "Shopping item"
        }
        if subtitle.isEmpty {
            return "\(kind), \(title)"
        }
        return "\(kind), \(title), \(subtitle)"
    }

    public init(result: SearchSurfaceResult) {
        self.result = result
    }
}

public struct SearchSurfaceEmptyState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct SearchSurfaceErrorState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct SearchSurfaceDebounceDecision: Equatable, Sendable {
    public let cancelsInFlightSearch: Bool
    public let scheduledRequest: SearchSurfaceRequest?
    public let delayMilliseconds: Int

    public init(
        cancelsInFlightSearch: Bool,
        scheduledRequest: SearchSurfaceRequest?,
        delayMilliseconds: Int
    ) {
        self.cancelsInFlightSearch = cancelsInFlightSearch
        self.scheduledRequest = scheduledRequest
        self.delayMilliseconds = delayMilliseconds
    }
}

public struct SearchSurfaceDebouncePolicy: Equatable, Sendable {
    public let delayMilliseconds: Int
    public let defaultLimit: Int

    public init(delayMilliseconds: Int, defaultLimit: Int) {
        self.delayMilliseconds = max(0, delayMilliseconds)
        self.defaultLimit = SearchSurfaceRequest.normalizedLimit(defaultLimit)
    }

    public func plan(
        previous: SearchState,
        next: SearchState,
        inFlight: SearchSurfaceRequest?
    ) -> SearchSurfaceDebounceDecision {
        let scheduledRequest = next.hasQuery && previous != next
            ? SearchSurfaceRequest(query: next.query, scope: next.scope, limit: defaultLimit)
            : nil
        let cancelsInFlightSearch = inFlight != nil && previous != next

        return SearchSurfaceDebounceDecision(
            cancelsInFlightSearch: cancelsInFlightSearch,
            scheduledRequest: scheduledRequest,
            delayMilliseconds: scheduledRequest == nil ? 0 : delayMilliseconds
        )
    }
}

public struct SearchSurfaceViewModel: Equatable, Sendable {
    public let state: SearchState
    public let searchableScopes: [SearchScope]
    public let unsupportedScopes: [SearchScope]
    public let sections: [SearchSurfaceSection]
    public let emptyState: SearchSurfaceEmptyState?
    public let errorState: SearchSurfaceErrorState?
    public let offlineIndicator: OfflineIndicatorState

    public init(
        page: SearchSurfacePage,
        state: SearchState,
        context: SearchSurfaceContext,
        offlineIndicator: OfflineIndicatorState? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.state = state
        let scopes = Self.searchableScopes(context: context)
        searchableScopes = scopes
        unsupportedScopes = SearchScope.allCases.filter { !scopes.contains($0) }
        sections = Self.sections(for: page.results, state: state)
        emptyState = Self.emptyState(page: page, state: state, context: context)
        errorState = nil
        self.offlineIndicator = offlineIndicator ?? page.offlineIndicator(now: now())
    }

    public init(
        error: SearchSurfaceRepositoryError,
        state: SearchState,
        cachedPage: SearchSurfacePage?,
        context: SearchSurfaceContext,
        offlineIndicator: OfflineIndicatorState? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.state = state
        let scopes = Self.searchableScopes(context: context)
        searchableScopes = scopes
        unsupportedScopes = SearchScope.allCases.filter { !scopes.contains($0) }
        let recoveredSections = cachedPage.map { Self.sections(for: $0.results, state: state) } ?? []
        sections = recoveredSections
        emptyState = cachedPage.map { Self.emptyState(page: $0, state: state, context: context) } ?? nil
        errorState = recoveredSections.isEmpty ? Self.errorState(error) : nil
        self.offlineIndicator = offlineIndicator ?? Self.offlineIndicator(
            error: error,
            state: state,
            cachedPage: cachedPage,
            now: now
        )
    }

    private static func searchableScopes(context: SearchSurfaceContext) -> [SearchScope] {
        context.isAuthenticated && context.canReadShoppingList
            ? SearchScope.allCases
            : SearchScope.allCases.filter { $0 != .shoppingList }
    }

    private static func sections(for results: [SearchSurfaceResult], state: SearchState) -> [SearchSurfaceSection] {
        let scopedResults = results.filter { result in
            switch (state.scope, result.type) {
            case (.all, _), (.recipes, .recipe), (.cookbooks, .cookbook), (.chefs, .chef), (.shoppingList, .shoppingListItem):
                true
            default:
                false
            }
        }
        let rows = scopedResults.map(SearchSurfaceRow.init(result:))

        return [
            SearchSurfaceSection(kind: .recipes, rows: rows.filter { $0.result.type == .recipe }),
            SearchSurfaceSection(kind: .cookbooks, rows: rows.filter { $0.result.type == .cookbook }),
            SearchSurfaceSection(kind: .chefs, rows: rows.filter { $0.result.type == .chef }),
            SearchSurfaceSection(kind: .shoppingList, rows: rows.filter { $0.result.type == .shoppingListItem })
        ].filter { !$0.rows.isEmpty }
    }

    private static func emptyState(
        page: SearchSurfacePage,
        state: SearchState,
        context: SearchSurfaceContext
    ) -> SearchSurfaceEmptyState? {
        guard page.results.isEmpty else {
            return nil
        }
        if state.scope == .shoppingList && (!context.isAuthenticated || !context.canReadShoppingList) {
            return SearchSurfaceEmptyState(
                title: "Sign in to search your shopping list",
                message: "Shopping-list matches are private to your Spoonjoy account.",
                systemImage: "lock"
            )
        }
        if state.hasQuery {
            let query = state.query
            return SearchSurfaceEmptyState(
                title: "No matches for \"\(query)\"",
                message: Self.noResultsMessage(query: query, scope: state.scope),
                systemImage: "magnifyingglass"
            )
        }
        return SearchSurfaceEmptyState(
            title: "Search Spoonjoy",
            message: "Recipes, cookbooks, chefs, and shopping list items will gather here.",
            systemImage: "magnifyingglass"
        )
    }

    private static func noResultsMessage(query: String, scope: SearchScope) -> String {
        switch scope {
        case .all:
            "No Spoonjoy results match \"\(query)\"."
        case .recipes:
            "No saved recipes match \"\(query)\"."
        case .cookbooks:
            "No cookbooks match \"\(query)\"."
        case .chefs:
            "No chefs match \"\(query)\"."
        case .shoppingList:
            "No shopping items match \"\(query)\"."
        }
    }

    private static func errorState(_ error: SearchSurfaceRepositoryError) -> SearchSurfaceErrorState {
        let message: String
        switch error {
        case .authenticationRequired:
            message = "Sign in to search private Spoonjoy results."
        case .authorizationRequired(_, let requiredScope):
            message = "Your token needs \(requiredScope) to search private shopping-list matches."
        case .offline:
            message = "Spoonjoy search is offline."
        case .cancelled:
            message = "Search was cancelled."
        case .searchFailed(let failureMessage):
            message = failureMessage
        }
        return SearchSurfaceErrorState(
            title: "Search could not load",
            message: message,
            systemImage: "wifi.exclamationmark"
        )
    }

    private static func offlineIndicator(
        error: SearchSurfaceRepositoryError,
        state: SearchState,
        cachedPage: SearchSurfacePage?,
        now: @escaping @Sendable () -> Date
    ) -> OfflineIndicatorState {
        if let cachedPage {
            if error == .offline {
                return cachedPage.withOfflineFallback().offlineIndicator(now: now())
            }
            return cachedPage.offlineIndicator(now: now())
        }

        switch error {
        case .offline:
            return OfflineIndicatorState(display: .offline, dismissal: nil)
        case .cancelled:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .authenticationRequired, .authorizationRequired, .searchFailed:
            return OfflineIndicatorState(
                display: .syncFailure(errorID: "search-\(state.scope.rawValue)", retryAfter: nil),
                dismissal: nil
            )
        }
    }
}
