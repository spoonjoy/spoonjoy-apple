import Foundation

public struct RecipeCatalogRowViewModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let chefLine: String
    public let servingsLabel: String?
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let openRoute: AppRoute

    public init(summary: RecipeSummary) {
        id = summary.id
        title = summary.title
        subtitle = summary.description
        chefLine = "By \(summary.chef.username)"
        servingsLabel = Self.servingsLabel(summary.servings)
        coverImageURL = summary.displayCoverImageURL
        coverProvenanceLabel = summary.displayCoverProvenanceLabel
        openRoute = .recipeDetail(id: summary.id, presentation: .detail)
    }

    private static func servingsLabel(_ servings: String?) -> String? {
        guard let servings = servings?.trimmingCharacters(in: .whitespacesAndNewlines), !servings.isEmpty else {
            return nil
        }

        return "Serves \(servings)"
    }
}

public struct RecipeCatalogState: Equatable, Sendable {
    public let query: String
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let rows: [RecipeCatalogRowViewModel]
    public let source: RecipeCatalogDataSource?
    public let offlineIndicator: OfflineIndicatorState
    public let emptyState: String?

    public var resultCountLabel: String {
        "\(rows.count) \(rows.count == 1 ? "recipe" : "recipes")"
    }

    public init(
        query: String,
        limit: Int,
        cursor: PaginationCursor?,
        nextCursor: PaginationCursor?,
        hasMore: Bool,
        rows: [RecipeCatalogRowViewModel],
        source: RecipeCatalogDataSource?,
        offlineIndicator: OfflineIndicatorState,
        emptyState: String?
    ) {
        self.query = query
        self.limit = limit
        self.cursor = cursor
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.rows = rows
        self.source = source
        self.offlineIndicator = offlineIndicator
        self.emptyState = emptyState
    }

    public static func empty(query: String = "", limit: Int = 48) -> RecipeCatalogState {
        RecipeCatalogState(
            query: query,
            limit: limit,
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: [],
            source: nil,
            offlineIndicator: OfflineIndicatorState(display: .synced, dismissal: nil),
            emptyState: "No recipes yet"
        )
    }
}

@MainActor public final class RecipeCatalogViewModel {
    private let repository: any RecipeCatalogRepository
    private let now: @Sendable () -> Date

    public private(set) var state: RecipeCatalogState

    public init(
        repository: any RecipeCatalogRepository,
        initialState: RecipeCatalogState = .empty(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.state = initialState
        self.now = now
    }

    public convenience init(page: RecipeCatalogPage, now: @escaping @Sendable () -> Date = Date.init) {
        let repository = SnapshotRecipeCatalogRepository(page: page, details: [])
        self.init(repository: repository, initialState: Self.state(from: page, now: now()), now: now)
    }

    public func load(query: String?, limit: Int = 48, cursor: PaginationCursor? = nil) async throws {
        let request = RecipeCatalogListRequest(query: query, limit: limit, cursor: cursor)
        let page = try await repository.listRecipes(request: request)
        state = Self.state(from: page, now: now())
    }

    public func apply(page: RecipeCatalogPage) {
        state = Self.state(from: page, now: now())
    }

    public func openRecipeRoute(id: String) -> AppRoute {
        .recipeDetail(id: id, presentation: .detail)
    }

    private static func state(from page: RecipeCatalogPage, now: Date) -> RecipeCatalogState {
        let query = page.query ?? ""
        let rows = page.rows.map(RecipeCatalogRowViewModel.init(summary:))
        return RecipeCatalogState(
            query: query,
            limit: page.limit,
            cursor: page.cursor,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            rows: rows,
            source: page.source,
            offlineIndicator: page.offlineIndicator(now: now),
            emptyState: rows.isEmpty ? emptyState(for: query) : nil
        )
    }

    private static func emptyState(for query: String) -> String {
        query.isEmpty ? "No recipes yet" : "No matching recipes"
    }
}
