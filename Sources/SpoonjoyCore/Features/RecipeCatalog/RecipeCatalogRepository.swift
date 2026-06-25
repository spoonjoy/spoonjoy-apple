import Foundation

public struct RecipeCatalogListRequest: Equatable, Sendable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?

    public init(query: String?, limit: Int, cursor: PaginationCursor? = nil) {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = trimmedQuery?.isEmpty == false ? trimmedQuery : nil
        self.limit = limit
        self.cursor = cursor
    }
}

public enum RecipeCatalogDataSource: Equatable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
}

public struct RecipeCatalogPage: Equatable, Sendable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let rows: [RecipeSummary]
    public let source: RecipeCatalogDataSource

    public init(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?,
        nextCursor: PaginationCursor?,
        hasMore: Bool,
        rows: [RecipeSummary],
        source: RecipeCatalogDataSource
    ) {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = trimmedQuery?.isEmpty == false ? trimmedQuery : nil
        self.limit = limit
        self.cursor = cursor
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.rows = rows
        self.source = source
    }

    public func offlineIndicator(
        now: Date,
        freshnessPolicy: NativeCacheFreshnessPolicy = .offlineProductContract
    ) -> OfflineIndicatorState {
        switch source {
        case .live:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let serverRevision, let lastValidatedAt):
            return Self.offlineIndicator(
                domain: NativeCacheDomain.recipeCatalog,
                payload: .recipeCatalog(recipeIDs: rows.map(\.id)),
                serverRevision: serverRevision,
                lastValidatedAt: lastValidatedAt,
                now: now,
                freshnessPolicy: freshnessPolicy
            )
        }
    }

    static func offlineIndicator(
        domain: NativeCacheDomain,
        payload: NativeCachePayload,
        serverRevision: NativeCacheServerRevision?,
        lastValidatedAt: Date,
        now: Date,
        freshnessPolicy: NativeCacheFreshnessPolicy
    ) -> OfflineIndicatorState {
        let record = try? NativeCacheRecord(
            id: domain.stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "recipe-catalog",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: lastValidatedAt,
                lastValidatedAt: lastValidatedAt,
                sourceEndpoint: domain.sourceEndpoint,
                serverRevision: serverRevision
            ),
            payload: payload
        )

        guard let record else {
            return OfflineIndicatorState(display: .stale(domain: domain), dismissal: nil)
        }

        switch freshnessPolicy.freshness(for: record, now: now) {
        case .fresh, .locallyAuthoritative:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .stale:
            return OfflineIndicatorState(display: .stale(domain: domain), dismissal: nil)
        }
    }
}

public struct RecipeCatalogDetailResult: Equatable, Sendable {
    public let recipe: Recipe
    public let source: RecipeCatalogDataSource

    public init(recipe: Recipe, source: RecipeCatalogDataSource) {
        self.recipe = recipe
        self.source = source
    }

    public func offlineIndicator(
        now: Date,
        freshnessPolicy: NativeCacheFreshnessPolicy = .offlineProductContract
    ) -> OfflineIndicatorState {
        switch source {
        case .live:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let serverRevision, let lastValidatedAt):
            let domain = NativeCacheDomain.recipeDetail(id: recipe.id)
            return RecipeCatalogPage.offlineIndicator(
                domain: domain,
                payload: .recipeDetail(id: recipe.id, title: recipe.title),
                serverRevision: serverRevision,
                lastValidatedAt: lastValidatedAt,
                now: now,
                freshnessPolicy: freshnessPolicy
            )
        }
    }
}

public protocol RecipeCatalogRepository: Sendable {
    func listRecipes(request: RecipeCatalogListRequest) async throws -> RecipeCatalogPage
    func recipeDetail(id: String) async throws -> RecipeCatalogDetailResult
}

public struct LiveRecipeCatalogRepository: RecipeCatalogRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration
    private let now: @Sendable () -> Date

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transport = transport
        self.configuration = configuration
        self.now = now
    }

    public func listRecipes(request: RecipeCatalogListRequest) async throws -> RecipeCatalogPage {
        let envelope = try await transport.send(
            PublicCatalogRequests.listRecipes(query: request.query, limit: request.limit, cursor: request.cursor),
            configuration: configuration,
            decode: RecipeListData.self
        )
        let data = envelope.data
        return RecipeCatalogPage(
            query: data.query ?? request.query,
            limit: data.limit,
            cursor: data.cursor,
            nextCursor: data.nextCursor,
            hasMore: data.hasMore,
            rows: data.recipes,
            source: .live(requestID: envelope.requestID, validatedAt: now())
        )
    }

    public func recipeDetail(id: String) async throws -> RecipeCatalogDetailResult {
        let envelope = try await transport.send(
            PublicCatalogRequests.recipeDetail(id: id),
            configuration: configuration,
            decode: RecipeDetailData.self
        )
        return RecipeCatalogDetailResult(
            recipe: envelope.data.recipe,
            source: .live(requestID: envelope.requestID, validatedAt: now())
        )
    }
}

public struct SnapshotRecipeCatalogRepository: RecipeCatalogRepository {
    private let page: RecipeCatalogPage
    private let detailsByID: [String: RecipeCatalogDetailResult]

    public init(page: RecipeCatalogPage, details: [RecipeCatalogDetailResult]) {
        self.page = page
        detailsByID = Dictionary(uniqueKeysWithValues: details.map { ($0.recipe.id, $0) })
    }

    public func listRecipes(request: RecipeCatalogListRequest) async throws -> RecipeCatalogPage {
        let filteredRows = filteredRows(for: request)
        return RecipeCatalogPage(
            query: request.query,
            limit: request.limit,
            cursor: request.cursor,
            nextCursor: nil,
            hasMore: filteredRows.count > request.limit,
            rows: Array(filteredRows.prefix(request.limit)),
            source: page.source
        )
    }

    public func recipeDetail(id: String) async throws -> RecipeCatalogDetailResult {
        if let detail = detailsByID[id] {
            return detail
        }

        throw RecipeCatalogRepositoryError.recipeNotFound(id)
    }

    private func filteredRows(for request: RecipeCatalogListRequest) -> [RecipeSummary] {
        guard let query = request.query?.lowercased(), !query.isEmpty else {
            return page.rows
        }

        return page.rows.filter { row in
            row.title.localizedCaseInsensitiveContains(query) ||
                row.description?.localizedCaseInsensitiveContains(query) == true ||
                row.chef.username.localizedCaseInsensitiveContains(query)
        }
    }
}

public struct FallbackRecipeCatalogRepository: RecipeCatalogRepository {
    private let primary: any RecipeCatalogRepository
    private let fallback: any RecipeCatalogRepository

    public init(primary: any RecipeCatalogRepository, fallback: any RecipeCatalogRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func listRecipes(request: RecipeCatalogListRequest) async throws -> RecipeCatalogPage {
        do {
            return try await primary.listRecipes(request: request)
        } catch {
            return try await fallback.listRecipes(request: request)
        }
    }

    public func recipeDetail(id: String) async throws -> RecipeCatalogDetailResult {
        do {
            return try await primary.recipeDetail(id: id)
        } catch {
            return try await fallback.recipeDetail(id: id)
        }
    }
}

public enum RecipeCatalogRepositoryError: Error, Equatable, Sendable {
    case recipeNotFound(String)
}

private extension NativeCacheDomain {
    var sourceEndpoint: String {
        switch self {
        case .recipeCatalog:
            "/api/v1/recipes"
        case .recipeDetail(let id):
            "/api/v1/recipes/\(id)"
        default:
            stableRecordID
        }
    }
}
