import Foundation

public struct CookbookSurfaceListRequest: Equatable, Sendable {
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

public enum CookbookSurfaceDataSource: Equatable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
}

public struct CookbookSurfacePage: Equatable, Sendable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let rows: [CookbookSummary]
    public let source: CookbookSurfaceDataSource

    public init(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?,
        nextCursor: PaginationCursor?,
        hasMore: Bool,
        rows: [CookbookSummary],
        source: CookbookSurfaceDataSource
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
            OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let serverRevision, let lastValidatedAt):
            Self.offlineIndicator(
                domain: NativeCacheDomain.cookbookList,
                payload: .cookbookList(cookbookIDs: rows.map(\.id)),
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
                accountID: "cookbook-surface",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: domain,
                fetchedAt: lastValidatedAt,
                lastValidatedAt: lastValidatedAt,
                sourceEndpoint: domain.cookbookSurfaceSourceEndpoint,
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

public struct CookbookSurfaceDetailResult: Equatable, Sendable {
    public let cookbook: Cookbook
    public let source: CookbookSurfaceDataSource
    public let availableRecipes: [RecipeSummary]

    public init(cookbook: Cookbook, source: CookbookSurfaceDataSource, availableRecipes: [RecipeSummary]) {
        self.cookbook = cookbook
        self.source = source
        self.availableRecipes = availableRecipes
    }

    public func offlineIndicator(
        now: Date,
        freshnessPolicy: NativeCacheFreshnessPolicy = .offlineProductContract
    ) -> OfflineIndicatorState {
        switch source {
        case .live:
            OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let serverRevision, let lastValidatedAt):
            CookbookSurfacePage.offlineIndicator(
                domain: NativeCacheDomain.cookbookDetail(id: cookbook.id),
                payload: .cookbookDetail(id: cookbook.id, title: cookbook.title),
                serverRevision: serverRevision,
                lastValidatedAt: lastValidatedAt,
                now: now,
                freshnessPolicy: freshnessPolicy
            )
        }
    }
}

public protocol CookbookSurfaceRepository: Sendable {
    func listCookbooks(request: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage
    func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult
}

public struct LiveCookbookSurfaceRepository: CookbookSurfaceRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration
    private let availableRecipes: [RecipeSummary]
    private let now: @Sendable () -> Date

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration,
        availableRecipes: [RecipeSummary] = [],
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transport = transport
        self.configuration = configuration
        self.availableRecipes = availableRecipes
        self.now = now
    }

    public func listCookbooks(request: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage {
        let envelope = try await transport.send(
            PublicCatalogRequests.listCookbooks(query: request.query, limit: request.limit, cursor: request.cursor),
            configuration: configuration,
            decode: CookbookListData.self
        )
        let data = envelope.data
        return CookbookSurfacePage(
            query: data.query ?? request.query,
            limit: data.limit,
            cursor: data.cursor,
            nextCursor: data.nextCursor,
            hasMore: data.hasMore,
            rows: data.cookbooks,
            source: .live(requestID: envelope.requestID, validatedAt: now())
        )
    }

    public func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult {
        let envelope = try await transport.send(
            PublicCatalogRequests.cookbookDetail(id: id),
            configuration: configuration,
            decode: CookbookDetailData.self
        )
        let savedRecipeIDs = Set(envelope.data.cookbook.recipes.map(\.id))
        return CookbookSurfaceDetailResult(
            cookbook: envelope.data.cookbook,
            source: .live(requestID: envelope.requestID, validatedAt: now()),
            availableRecipes: availableRecipes.filter { !savedRecipeIDs.contains($0.id) }
        )
    }
}

public struct SnapshotCookbookSurfaceRepository: CookbookSurfaceRepository {
    private let page: CookbookSurfacePage
    private let detailsByID: [String: CookbookSurfaceDetailResult]

    public init(page: CookbookSurfacePage, details: [CookbookSurfaceDetailResult]) {
        self.page = page
        detailsByID = Dictionary(uniqueKeysWithValues: details.map { ($0.cookbook.id, $0) })
    }

    public func listCookbooks(request: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage {
        let filteredRows = filteredRows(for: request)
        return CookbookSurfacePage(
            query: request.query,
            limit: request.limit,
            cursor: request.cursor,
            nextCursor: nil,
            hasMore: filteredRows.count > request.limit,
            rows: Array(filteredRows.prefix(request.limit)),
            source: page.source
        )
    }

    public func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult {
        if let detail = detailsByID[id] {
            return detail
        }

        throw CookbookSurfaceRepositoryError.cookbookNotFound(id)
    }

    private func filteredRows(for request: CookbookSurfaceListRequest) -> [CookbookSummary] {
        guard let query = request.query?.lowercased(), !query.isEmpty else {
            return page.rows
        }

        return page.rows.filter { row in
            row.title.localizedCaseInsensitiveContains(query) ||
                row.chef.username.localizedCaseInsensitiveContains(query)
        }
    }
}

public struct FallbackCookbookSurfaceRepository: CookbookSurfaceRepository {
    private let primary: any CookbookSurfaceRepository
    private let fallback: any CookbookSurfaceRepository

    public init(primary: any CookbookSurfaceRepository, fallback: any CookbookSurfaceRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func listCookbooks(request: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage {
        do {
            return try await primary.listCookbooks(request: request)
        } catch {
            return try await fallback.listCookbooks(request: request)
        }
    }

    public func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult {
        do {
            return try await primary.cookbookDetail(id: id)
        } catch {
            return try await fallback.cookbookDetail(id: id)
        }
    }
}

public enum CookbookSurfaceRepositoryError: Error, Equatable, Sendable {
    case cookbookNotFound(String)
}

private extension NativeCacheDomain {
    var cookbookSurfaceSourceEndpoint: String {
        switch self {
        case .cookbookList:
            "/api/v1/cookbooks"
        case .cookbookDetail(let id):
            "/api/v1/cookbooks/\(id)"
        default:
            stableRecordID
        }
    }
}
