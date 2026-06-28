import Foundation

public struct SearchSurfaceRequest: Equatable, Hashable, Sendable {
    public static let maxLimit = 50

    public static func normalizedLimit(_ limit: Int) -> Int {
        min(maxLimit, max(1, limit))
    }

    public let query: String
    public let scope: SearchScope
    public let limit: Int

    public init(query: String, scope: SearchScope, limit: Int) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        self.limit = Self.normalizedLimit(limit)
    }
}

public enum SearchSurfaceResultType: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case recipe
    case cookbook
    case chef
    case shoppingListItem = "shopping-list-item"
}

public struct SearchSurfaceResult: Codable, Equatable, Hashable, Sendable {
    public let type: SearchSurfaceResultType
    public let id: String
    public let ownerID: String?
    public let ownerUsername: String?
    public let title: String
    public let subtitle: String?
    public let snippet: String?
    public let href: String
    public let canonicalURL: URL
    public let imageURL: URL?
    public let score: Double
    public let metadata: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case ownerID = "ownerId"
        case ownerUsername
        case title
        case subtitle
        case snippet
        case href
        case canonicalURL = "canonicalUrl"
        case imageURL = "imageUrl"
        case score
        case metadata
    }

    public init(
        type: SearchSurfaceResultType,
        id: String,
        ownerID: String?,
        ownerUsername: String?,
        title: String,
        subtitle: String?,
        snippet: String?,
        href: String,
        canonicalURL: URL,
        imageURL: URL?,
        score: Double,
        metadata: [String: JSONValue]
    ) {
        self.type = type
        self.id = id
        self.ownerID = ownerID
        self.ownerUsername = ownerUsername
        self.title = title
        self.subtitle = subtitle
        self.snippet = snippet
        self.href = href
        self.canonicalURL = canonicalURL
        self.imageURL = imageURL
        self.score = score
        self.metadata = metadata
    }

    public var openRoute: AppRoute {
        switch type {
        case .recipe:
            AppRoute.recipeDetail(id: id, presentation: .detail)
        case .cookbook:
            AppRoute.cookbookDetail(id: id)
        case .chef:
            AppRoute.profile(identifier: ownerUsername ?? title)
        case .shoppingListItem:
            AppRoute.shoppingList
        }
    }
}

public struct SearchSurfaceData: Codable, Equatable, Sendable {
    public let query: String
    public let scope: SearchScope
    public let limit: Int
    public let isAuthenticated: Bool
    public let results: [SearchSurfaceResult]

    public init(
        query: String,
        scope: SearchScope,
        limit: Int,
        isAuthenticated: Bool,
        results: [SearchSurfaceResult]
    ) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        self.limit = SearchSurfaceRequest.normalizedLimit(limit)
        self.isAuthenticated = isAuthenticated
        self.results = results
    }
}

public enum SearchSurfaceDataSource: Equatable, Hashable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
    case offlineCache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
}

public struct SearchSurfacePage: Equatable, Sendable {
    public let query: String
    public let scope: SearchScope
    public let limit: Int
    public let isAuthenticated: Bool
    public let results: [SearchSurfaceResult]
    public let source: SearchSurfaceDataSource

    public init(
        query: String,
        scope: SearchScope,
        limit: Int,
        isAuthenticated: Bool,
        results: [SearchSurfaceResult],
        source: SearchSurfaceDataSource
    ) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        self.limit = SearchSurfaceRequest.normalizedLimit(limit)
        self.isAuthenticated = isAuthenticated
        self.results = results
        self.source = source
    }

    public func offlineIndicator(now _: Date) -> OfflineIndicatorState {
        switch source {
        case .live:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache:
            return OfflineIndicatorState(display: .stale(domain: NativeCacheDomain.searchResults(query: query, scope: scope)), dismissal: nil)
        case .offlineCache:
            return OfflineIndicatorState(display: .offline, dismissal: nil)
        }
    }

    func withOfflineFallback() -> SearchSurfacePage {
        switch source {
        case .live:
            return SearchSurfacePage(
                query: query,
                scope: scope,
                limit: limit,
                isAuthenticated: isAuthenticated,
                results: results,
                source: .offlineCache(serverRevision: nil, lastValidatedAt: Date(timeIntervalSince1970: 0))
            )
        case .cache(let serverRevision, let lastValidatedAt), .offlineCache(let serverRevision, let lastValidatedAt):
            return SearchSurfacePage(
                query: query,
                scope: scope,
                limit: limit,
                isAuthenticated: isAuthenticated,
                results: results,
                source: .offlineCache(serverRevision: serverRevision, lastValidatedAt: lastValidatedAt)
            )
        }
    }
}

public struct SearchSurfaceRecentQuery: Codable, Equatable, Hashable, Sendable {
    public let query: String
    public let scope: SearchScope
    public let lastSearchedAt: Date

    public init(query: String, scope: SearchScope, lastSearchedAt: Date) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        self.lastSearchedAt = lastSearchedAt
    }
}

public struct SearchSurfaceCacheSnapshot: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let environment: NativeCacheEnvironment
    public let query: String
    public let scope: SearchScope
    public let limit: Int
    public let results: [SearchSurfaceResult]
    public let recentSearches: [SearchSurfaceRecentQuery]
    public let serverRevision: NativeCacheServerRevision?
    public let lastValidatedAt: Date

    public init(
        accountID: String,
        environment: NativeCacheEnvironment,
        query: String,
        scope: SearchScope,
        limit: Int,
        results: [SearchSurfaceResult],
        recentSearches: [SearchSurfaceRecentQuery],
        serverRevision: NativeCacheServerRevision?,
        lastValidatedAt: Date
    ) {
        self.accountID = accountID
        self.environment = environment
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        self.limit = SearchSurfaceRequest.normalizedLimit(limit)
        self.results = results
        self.recentSearches = recentSearches
        self.serverRevision = serverRevision
        self.lastValidatedAt = lastValidatedAt
    }

    public func page(
        context: SearchSurfaceContext,
        currentAccountID: String?,
        source: SearchSurfaceDataSource? = nil
    ) -> SearchSurfacePage {
        SearchSurfacePage(
            query: query,
            scope: scope,
            limit: limit,
            isAuthenticated: context.isAuthenticated,
            results: filteredResults(context: context, currentAccountID: currentAccountID),
            source: source ?? .cache(serverRevision: serverRevision, lastValidatedAt: lastValidatedAt)
        )
    }

    public func filteredResults(context: SearchSurfaceContext, currentAccountID: String?) -> [SearchSurfaceResult] {
        results.filter { result in
            guard result.type == .shoppingListItem else {
                return true
            }
            return context.isAuthenticated &&
                context.canReadShoppingList &&
                currentAccountID == accountID &&
                result.ownerID == accountID
        }
    }
}

public enum SearchSurfaceRepositoryError: Error, Equatable, Sendable {
    case authenticationRequired(scope: SearchScope)
    case authorizationRequired(scope: SearchScope, requiredScope: String)
    case offline
    case cancelled
    case searchFailed(message: String)
}

public protocol SearchSurfaceRepository: Sendable {
    func search(request: SearchSurfaceRequest) async throws -> SearchSurfacePage
    func recentSearches(limit: Int) async throws -> [SearchSurfaceRecentQuery]
}

public struct LiveSearchSurfaceRepository: SearchSurfaceRepository {
    private static let shoppingReadScope = "shopping_list:read"
    private static let privateShoppingListSearchScope = SearchScope.shoppingList

    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration
    private let context: SearchSurfaceContext
    private let now: @Sendable () -> Date
    private let recentSearchMemory: SearchSurfaceRecentSearchMemory

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration,
        context: SearchSurfaceContext,
        recentSearchMemory: SearchSurfaceRecentSearchMemory = SearchSurfaceRecentSearchMemory(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transport = transport
        self.configuration = configuration
        self.context = context
        self.recentSearchMemory = recentSearchMemory
        self.now = now
    }

    public func search(request: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        try authorize(request)
        let builder = requestBuilder(for: request)

        do {
            let envelope = try await transport.send(builder, configuration: configuration, decode: SearchSurfaceData.self)
            let page = SearchSurfacePage(
                query: envelope.data.query,
                scope: envelope.data.scope,
                limit: envelope.data.limit,
                isAuthenticated: envelope.data.isAuthenticated,
                results: envelope.data.results,
                source: .live(requestID: envelope.requestID, validatedAt: now())
            )
            await recentSearchMemory.record(SearchSurfaceRecentQuery(
                query: page.query,
                scope: page.scope,
                lastSearchedAt: now()
            ))
            return page
        } catch let error as SearchSurfaceRepositoryError {
            throw error
        } catch let error as APITransportError {
            throw Self.searchError(from: error, scope: request.scope)
        } catch {
            throw SearchSurfaceRepositoryError.searchFailed(message: String(describing: error))
        }
    }

    public func recentSearches(limit: Int) async throws -> [SearchSurfaceRecentQuery] {
        await recentSearchMemory.recentSearches(limit: limit)
    }

    private func authorize(_ request: SearchSurfaceRequest) throws {
        guard request.scope == .shoppingList else {
            return
        }
        guard context.isAuthenticated else {
            throw SearchSurfaceRepositoryError.authenticationRequired(scope: request.scope)
        }
        guard context.canReadShoppingList else {
            throw SearchSurfaceRepositoryError.authorizationRequired(
                scope: request.scope,
                requiredScope: Self.shoppingReadScope
            )
        }
    }

    private func requestBuilder(for request: SearchSurfaceRequest) -> APIRequestBuilder {
        let publicRequest = SearchRequests.search(query: request.query, scope: request.scope, limit: request.limit)
        guard shouldIncludeBearerToken(for: request.scope) else {
            return publicRequest
        }

        return APIRequestBuilder(
            method: publicRequest.method,
            pathComponents: publicRequest.pathComponents,
            queryItems: publicRequest.queryItems,
            headers: publicRequest.headers,
            body: publicRequest.body,
            defaultAuthorization: .includeBearerToken,
            responseCachePolicy: .privateNoStore
        )
    }

    private func shouldIncludeBearerToken(for scope: SearchScope) -> Bool {
        switch scope {
        case .all:
            context.isAuthenticated && context.canReadShoppingList
        case .shoppingList:
            true
        case .recipes, .cookbooks, .chefs:
            false
        }
    }

    private static func searchError(from error: APITransportError, scope: SearchScope) -> SearchSurfaceRepositoryError {
        if error.isOffline {
            return .offline
        }
        if error.isCancelled {
            return .cancelled
        }
        if let apiError = error.apiError {
            switch apiError.code {
            case "authentication_required", "invalid_token":
                return .authenticationRequired(scope: scope)
            case "insufficient_scope":
                return .authorizationRequired(scope: scope, requiredScope: shoppingReadScope)
            default:
                return .searchFailed(message: apiError.message)
            }
        }
        return .searchFailed(message: String(describing: error))
    }
}

public struct SnapshotSearchSurfaceRepository: SearchSurfaceRepository {
    private let snapshot: SearchSurfaceCacheSnapshot
    private let currentAccountID: String?
    private let environment: NativeCacheEnvironment
    private let context: SearchSurfaceContext

    public init(
        snapshot: SearchSurfaceCacheSnapshot,
        currentAccountID: String?,
        environment: NativeCacheEnvironment,
        context: SearchSurfaceContext
    ) {
        self.snapshot = snapshot
        self.currentAccountID = currentAccountID
        self.environment = environment
        self.context = context
    }

    public func search(request: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        guard environment == snapshot.environment,
              request.query == snapshot.query,
              request.scope == snapshot.scope else {
            throw SearchSurfaceRepositoryError.offline
        }

        return SearchSurfacePage(
            query: snapshot.query,
            scope: snapshot.scope,
            limit: snapshot.limit,
            isAuthenticated: context.isAuthenticated,
            results: snapshot.filteredResults(context: context, currentAccountID: currentAccountID),
            source: .cache(serverRevision: snapshot.serverRevision, lastValidatedAt: snapshot.lastValidatedAt)
        )
    }

    public func recentSearches(limit: Int) async throws -> [SearchSurfaceRecentQuery] {
        Array(snapshot.recentSearches.prefix(max(0, limit)))
    }
}

public struct FallbackSearchSurfaceRepository: SearchSurfaceRepository {
    private let primary: any SearchSurfaceRepository
    private let fallback: any SearchSurfaceRepository

    public init(primary: any SearchSurfaceRepository, fallback: any SearchSurfaceRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func search(request: SearchSurfaceRequest) async throws -> SearchSurfacePage {
        do {
            return try await primary.search(request: request)
        } catch SearchSurfaceRepositoryError.offline {
            return try await fallback.search(request: request).withOfflineFallback()
        }
    }

    public func recentSearches(limit: Int) async throws -> [SearchSurfaceRecentQuery] {
        do {
            return try await primary.recentSearches(limit: limit)
        } catch {
            return try await fallback.recentSearches(limit: limit)
        }
    }
}

public actor SearchSurfaceRecentSearchMemory {
    private var recentQueries: [SearchSurfaceRecentQuery] = []

    public init(recentQueries: [SearchSurfaceRecentQuery] = []) {
        self.recentQueries = recentQueries
    }

    public func record(_ query: SearchSurfaceRecentQuery) {
        recentQueries.removeAll { $0.query == query.query && $0.scope == query.scope }
        recentQueries.insert(query, at: 0)
    }

    public func recentSearches(limit: Int) -> [SearchSurfaceRecentQuery] {
        Array(recentQueries.prefix(max(0, limit)))
    }
}
