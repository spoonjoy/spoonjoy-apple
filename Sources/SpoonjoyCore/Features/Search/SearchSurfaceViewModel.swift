import Foundation

public enum SearchSurfaceScopeGrammar {
    public static func title(for scope: SearchScope) -> String {
        switch scope {
        case .all:
            "Everything"
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
}

public struct SearchSurfaceRenderFingerprint: Codable, Equatable, Hashable, Sendable {
    public struct Row: Codable, Equatable, Hashable, Sendable {
        public let type: String
        public let id: String
        public let title: String

        public init(type: String, id: String, title: String) {
            self.type = type
            self.id = id
            self.title = title
        }
    }

    public struct EmptyState: Codable, Equatable, Hashable, Sendable {
        public let scope: String
        public let title: String
        public let message: String

        public init(scope: String, title: String, message: String) {
            self.scope = scope
            self.title = title
            self.message = message
        }
    }

    public enum DataSource: Codable, Equatable, Hashable, Sendable {
        case live(requestID: String)
        case cache(serverRevision: String?)
        case offlineCache(serverRevision: String?)
        case unavailable(reason: String)
    }

    public let rows: [Row]
    public let dataSource: DataSource
    public let emptyState: EmptyState?

    public init(rows: [Row], dataSource: DataSource, emptyState: EmptyState?) {
        self.rows = rows
        self.dataSource = dataSource
        self.emptyState = emptyState
    }
}

public struct SearchSurfaceContext: Equatable, Hashable, Sendable {
    public let isAuthenticated: Bool
    public let canReadShoppingList: Bool

    public init(isAuthenticated: Bool, canReadShoppingList: Bool) {
        self.isAuthenticated = isAuthenticated
        self.canReadShoppingList = canReadShoppingList
    }
}

public enum NativeSearchTelemetryOutcome: String, Equatable, Sendable {
    case started
    case completed
    case cancelled
    case failed

    fileprivate var eventName: NativeTelemetryEvent.Name {
        switch self {
        case .started: .searchStarted
        case .completed: .searchCompleted
        case .cancelled, .failed: .searchFailed
        }
    }
}

public struct NativeSearchTelemetryDescriptor: Equatable, Sendable {
    public let outcome: NativeSearchTelemetryOutcome
    public let scope: SearchScope
    public let queryLength: Int
    public let resultCount: Int?
    public let durationMilliseconds: Int?
    public let requestID: String?
    public let errorType: String?
    public let hasCachedResults: Bool

    public static func started(state: SearchState, hasCachedResults: Bool) -> Self {
        Self(
            outcome: .started,
            state: state,
            resultCount: nil,
            durationMilliseconds: nil,
            requestID: nil,
            errorType: nil,
            hasCachedResults: hasCachedResults
        )
    }

    public static func completed(
        state: SearchState,
        page: SearchSurfacePage,
        durationMilliseconds: Int
    ) -> Self {
        let requestID: String? = if case .live(let value, _) = page.source { value } else { nil }
        return Self(
            outcome: .completed,
            state: state,
            resultCount: page.results.count,
            durationMilliseconds: durationMilliseconds,
            requestID: requestID,
            errorType: nil,
            hasCachedResults: false
        )
    }

    public static func failed(
        state: SearchState,
        error: SearchSurfaceRepositoryError,
        durationMilliseconds: Int,
        hasCachedResults: Bool
    ) -> Self {
        Self(
            outcome: .failed,
            state: state,
            resultCount: nil,
            durationMilliseconds: durationMilliseconds,
            requestID: nil,
            errorType: sanitizedErrorType(error),
            hasCachedResults: hasCachedResults
        )
    }

    public static func cancelled(
        state: SearchState,
        durationMilliseconds: Int,
        hasCachedResults: Bool
    ) -> Self {
        Self(
            outcome: .cancelled,
            state: state,
            resultCount: nil,
            durationMilliseconds: durationMilliseconds,
            requestID: nil,
            errorType: "cancelled",
            hasCachedResults: hasCachedResults
        )
    }

    private init(
        outcome: NativeSearchTelemetryOutcome,
        state: SearchState,
        resultCount: Int?,
        durationMilliseconds: Int?,
        requestID: String?,
        errorType: String?,
        hasCachedResults: Bool
    ) {
        self.outcome = outcome
        scope = state.scope
        queryLength = min(max(state.query.count, 0), 4_096)
        self.resultCount = resultCount.map { min(max($0, 0), 100_000) }
        self.durationMilliseconds = durationMilliseconds.map { min(max($0, 0), 600_000) }
        self.requestID = requestID
        self.errorType = errorType
        self.hasCachedResults = hasCachedResults
    }

    public func telemetryEvent(
        environment: String,
        metadata: NativeTelemetryAppMetadata
    ) -> NativeTelemetryEvent {
        NativeTelemetryEvent(
            name: outcome.eventName,
            stage: "request_\(outcome.rawValue)",
            environment: environment,
            metadata: metadata,
            route: "search",
            errorType: errorType,
            requestID: requestID,
            hasRenderableCacheContent: hasCachedResults,
            searchScope: scope.rawValue,
            searchQueryLength: queryLength,
            searchResultCount: resultCount,
            durationMilliseconds: durationMilliseconds
        )
    }

    private static func sanitizedErrorType(_ error: SearchSurfaceRepositoryError) -> String {
        switch error {
        case .authenticationRequired: "authentication_required"
        case .authorizationRequired: "authorization_required"
        case .offline: "offline"
        case .cancelled: "cancelled"
        case .searchFailed: "search_failed"
        }
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
    public let isLoading: Bool
    public let searchableScopes: [SearchScope]
    public let unsupportedScopes: [SearchScope]
    public let sections: [SearchSurfaceSection]
    public let emptyState: SearchSurfaceEmptyState?
    public let errorState: SearchSurfaceErrorState?
    public let offlineIndicator: OfflineIndicatorState
    public let renderFingerprint: SearchSurfaceRenderFingerprint

    public init(
        page: SearchSurfacePage,
        state: SearchState,
        context: SearchSurfaceContext,
        offlineIndicator: OfflineIndicatorState? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.state = state
        isLoading = false
        let scopes = Self.searchableScopes(context: context)
        searchableScopes = scopes
        unsupportedScopes = SearchScope.allCases.filter { !scopes.contains($0) }
        let renderedSections = Self.sections(for: page.results, state: state)
        sections = renderedSections
        let renderedEmptyState = Self.emptyState(
            hasRenderedResults: !renderedSections.isEmpty,
            state: state,
            context: context
        )
        emptyState = renderedEmptyState
        errorState = nil
        self.offlineIndicator = offlineIndicator ?? page.offlineIndicator(now: now())
        renderFingerprint = Self.renderFingerprint(
            sections: renderedSections,
            dataSource: page.source,
            emptyState: renderedEmptyState,
            state: state
        )
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
        isLoading = false
        let scopes = Self.searchableScopes(context: context)
        searchableScopes = scopes
        unsupportedScopes = SearchScope.allCases.filter { !scopes.contains($0) }
        let recoveredSections = cachedPage.map { Self.sections(for: $0.results, state: state) } ?? []
        sections = recoveredSections
        let renderedErrorState = recoveredSections.isEmpty ? Self.errorState(error) : nil
        let recoveredEmptyState: SearchSurfaceEmptyState? = if renderedErrorState == nil, cachedPage != nil {
            Self.emptyState(
                hasRenderedResults: !recoveredSections.isEmpty,
                state: state,
                context: context
            )
        } else {
            nil
        }
        emptyState = recoveredEmptyState
        errorState = renderedErrorState
        self.offlineIndicator = offlineIndicator ?? Self.offlineIndicator(
            error: error,
            state: state,
            cachedPage: cachedPage,
            now: now
        )
        renderFingerprint = Self.renderFingerprint(
            sections: recoveredSections,
            dataSource: cachedPage?.source,
            emptyState: recoveredEmptyState,
            state: state,
            unavailableReason: String(describing: error)
        )
    }

    public static func loading(
        state: SearchState,
        context: SearchSurfaceContext,
        cachedPage: SearchSurfacePage?,
        now: @escaping @Sendable () -> Date = Date.init
    ) -> SearchSurfaceViewModel {
        SearchSurfaceViewModel(
            loadingState: state,
            context: context,
            cachedPage: cachedPage,
            now: now
        )
    }

    private init(
        loadingState state: SearchState,
        context: SearchSurfaceContext,
        cachedPage: SearchSurfacePage?,
        now: @escaping @Sendable () -> Date
    ) {
        self.state = state
        isLoading = true
        let scopes = Self.searchableScopes(context: context)
        searchableScopes = scopes
        unsupportedScopes = SearchScope.allCases.filter { !scopes.contains($0) }
        let cachedSections = cachedPage.map { Self.sections(for: $0.results, state: state) } ?? []
        sections = cachedSections
        emptyState = nil
        errorState = nil
        offlineIndicator = cachedPage?.offlineIndicator(now: now())
            ?? OfflineIndicatorState(display: .synced, dismissal: nil)
        renderFingerprint = Self.renderFingerprint(
            sections: cachedSections,
            dataSource: cachedPage?.source,
            emptyState: nil,
            state: state,
            unavailableReason: "loading"
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
        var seenRowIDs = Set<String>()
        let rows = scopedResults.compactMap { result -> SearchSurfaceRow? in
            let row = SearchSurfaceRow(result: result)
            guard seenRowIDs.insert(row.id).inserted else {
                return nil
            }
            return row
        }

        return [
            SearchSurfaceSection(kind: .recipes, rows: rows.filter { $0.result.type == .recipe }),
            SearchSurfaceSection(kind: .cookbooks, rows: rows.filter { $0.result.type == .cookbook }),
            SearchSurfaceSection(kind: .chefs, rows: rows.filter { $0.result.type == .chef }),
            SearchSurfaceSection(kind: .shoppingList, rows: rows.filter { $0.result.type == .shoppingListItem })
        ].filter { !$0.rows.isEmpty }
    }

    private static func emptyState(
        hasRenderedResults: Bool,
        state: SearchState,
        context: SearchSurfaceContext
    ) -> SearchSurfaceEmptyState? {
        guard !hasRenderedResults else {
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
            "No recipes match \"\(query)\"."
        case .cookbooks:
            "No cookbooks match \"\(query)\"."
        case .chefs:
            "No chefs match \"\(query)\"."
        case .shoppingList:
            "No shopping items match \"\(query)\"."
        }
    }

    private static func renderFingerprint(
        sections: [SearchSurfaceSection],
        dataSource: SearchSurfaceDataSource?,
        emptyState: SearchSurfaceEmptyState?,
        state: SearchState,
        unavailableReason: String = "missing-page"
    ) -> SearchSurfaceRenderFingerprint {
        SearchSurfaceRenderFingerprint(
            rows: sections.flatMap(\.rows).map { row in
                SearchSurfaceRenderFingerprint.Row(
                    type: row.result.type.rawValue,
                    id: row.id,
                    title: row.title
                )
            },
            dataSource: renderDataSource(dataSource, unavailableReason: unavailableReason),
            emptyState: emptyState.map {
                SearchSurfaceRenderFingerprint.EmptyState(
                    scope: state.scope.rawValue,
                    title: $0.title,
                    message: $0.message
                )
            }
        )
    }

    private static func renderDataSource(
        _ dataSource: SearchSurfaceDataSource?,
        unavailableReason: String
    ) -> SearchSurfaceRenderFingerprint.DataSource {
        switch dataSource {
        case .live(let requestID, _):
            .live(requestID: requestID)
        case .cache(let serverRevision, _):
            .cache(serverRevision: renderServerRevision(serverRevision))
        case .offlineCache(let serverRevision, _):
            .offlineCache(serverRevision: renderServerRevision(serverRevision))
        case nil:
            .unavailable(reason: unavailableReason)
        }
    }

    private static func renderServerRevision(_ revision: NativeCacheServerRevision?) -> String? {
        switch revision {
        case .etag(let value):
            "etag:\(value)"
        case .cursor(let value):
            "cursor:\(value)"
        case .updatedAt(let value):
            "updated-at:\(value)"
        case .localRevision(let value):
            "local:\(value)"
        case nil:
            nil
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
