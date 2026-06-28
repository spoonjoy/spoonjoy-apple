import Foundation

public enum ProfileGraphDirection: String, Codable, Equatable, Hashable, Sendable {
    case fellowChefs = "fellow-chefs"
    case kitchenVisitors = "kitchen-visitors"
}

public struct ProfileSurfaceRequest: Equatable, Sendable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum ProfileSurfaceDataSource: Codable, Equatable, Sendable {
    case live(requestID: String, validatedAt: Date)
    case cache(serverRevision: NativeCacheServerRevision?, lastValidatedAt: Date)
}

public struct ProfileSummary: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let photoURL: URL?
    public let joinedLabel: String
    public let href: String
    public let canonicalURL: URL

    public init(id: String, username: String, photoURL: URL?, joinedLabel: String, href: String, canonicalURL: URL) {
        self.id = id
        self.username = username
        self.photoURL = photoURL
        self.joinedLabel = joinedLabel
        self.href = href
        self.canonicalURL = canonicalURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case photoURL = "photoUrl"
        case joinedLabel
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct ProfileRecipeSummary: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String?
    public let servings: String?
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let href: String
    public let canonicalURL: URL

    public var openRoute: AppRoute {
        .recipeDetail(id: id, presentation: .detail)
    }

    public init(
        id: String,
        title: String,
        description: String?,
        servings: String?,
        coverImageURL: URL?,
        coverProvenanceLabel: String?,
        href: String,
        canonicalURL: URL
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.servings = servings
        self.coverImageURL = coverImageURL
        self.coverProvenanceLabel = coverProvenanceLabel
        self.href = href
        self.canonicalURL = canonicalURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case servings
        case coverImageURL = "coverImageUrl"
        case coverProvenanceLabel
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct ProfileCookbookRecipePreview: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?
    public let href: String
    public let canonicalURL: URL

    public var openRoute: AppRoute {
        .recipeDetail(id: id, presentation: .detail)
    }

    public init(
        id: String,
        title: String,
        coverImageURL: URL?,
        coverProvenanceLabel: String?,
        href: String,
        canonicalURL: URL
    ) {
        self.id = id
        self.title = title
        self.coverImageURL = coverImageURL
        self.coverProvenanceLabel = coverProvenanceLabel
        self.href = href
        self.canonicalURL = canonicalURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverImageURL = "coverImageUrl"
        case coverProvenanceLabel
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct ProfileCookbookSummary: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let recipeCount: Int
    public let recipePreviews: [ProfileCookbookRecipePreview]
    public let href: String
    public let canonicalURL: URL

    public var recipeCountLabel: String {
        "\(recipeCount) \(recipeCount == 1 ? "recipe" : "recipes")"
    }

    public var openRoute: AppRoute {
        .cookbookDetail(id: id)
    }

    public init(
        id: String,
        title: String,
        recipeCount: Int,
        recipePreviews: [ProfileCookbookRecipePreview],
        href: String,
        canonicalURL: URL
    ) {
        self.id = id
        self.title = title
        self.recipeCount = recipeCount
        self.recipePreviews = recipePreviews
        self.href = href
        self.canonicalURL = canonicalURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case recipeCount
        case recipePreviews = "recipes"
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct ProfileRecentSpoonRecipe: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let chefID: String

    public var openRoute: AppRoute {
        .recipeDetail(id: id, presentation: .detail)
    }

    public init(id: String, title: String, chefID: String) {
        self.id = id
        self.title = title
        self.chefID = chefID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case chefID = "chefId"
    }
}

public struct ProfileRecentSpoon: Codable, Equatable, Sendable {
    public let id: String
    public let cookedAt: String?
    public let photoURL: URL?
    public let note: String?
    public let nextTime: String?
    public let chef: ChefSummary
    public let recipe: ProfileRecentSpoonRecipe
    public let coverImageURL: URL?
    public let coverProvenanceLabel: String?

    public init(
        id: String,
        cookedAt: String?,
        photoURL: URL?,
        note: String?,
        nextTime: String?,
        chef: ChefSummary,
        recipe: ProfileRecentSpoonRecipe,
        coverImageURL: URL?,
        coverProvenanceLabel: String?
    ) {
        self.id = id
        self.cookedAt = cookedAt
        self.photoURL = photoURL
        self.note = note
        self.nextTime = nextTime
        self.chef = chef
        self.recipe = recipe
        self.coverImageURL = coverImageURL
        self.coverProvenanceLabel = coverProvenanceLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case cookedAt
        case photoURL = "photoUrl"
        case note
        case nextTime
        case chef
        case recipe
        case coverImageURL = "coverImageUrl"
        case coverProvenanceLabel
    }
}

public struct ProfileSurfaceData: Codable, Equatable, Sendable {
    public let profile: ProfileSummary
    public let isOwner: Bool
    public let recipes: [ProfileRecipeSummary]
    public let cookbooks: [ProfileCookbookSummary]
    public let recentSpoons: [ProfileRecentSpoon]
    public let fellowChefsCount: Int
    public let kitchenVisitorsCount: Int

    public init(
        profile: ProfileSummary,
        isOwner: Bool,
        recipes: [ProfileRecipeSummary],
        cookbooks: [ProfileCookbookSummary],
        recentSpoons: [ProfileRecentSpoon],
        fellowChefsCount: Int,
        kitchenVisitorsCount: Int
    ) {
        self.profile = profile
        self.isOwner = isOwner
        self.recipes = recipes
        self.cookbooks = cookbooks
        self.recentSpoons = recentSpoons
        self.fellowChefsCount = fellowChefsCount
        self.kitchenVisitorsCount = kitchenVisitorsCount
    }
}

public struct ProfileSurfaceResult: Codable, Equatable, Sendable {
    public let data: ProfileSurfaceData
    public let source: ProfileSurfaceDataSource

    public init(data: ProfileSurfaceData, source: ProfileSurfaceDataSource) {
        self.data = data
        self.source = source
    }

    public var offlineIndicator: OfflineIndicatorState {
        offlineIndicator(now: Date())
    }

    public func offlineIndicator(
        now: Date,
        freshnessPolicy: NativeCacheFreshnessPolicy = .offlineProductContract
    ) -> OfflineIndicatorState {
        switch source {
        case .live:
            return OfflineIndicatorState(display: .synced, dismissal: nil)
        case .cache(let serverRevision, let lastValidatedAt):
            let domain = NativeCacheDomain.profile(id: data.profile.id)
            let payload = NativeCachePayload.profile(id: data.profile.id, username: data.profile.username)
            let record = try? NativeCacheRecord(
                id: domain.stableRecordID,
                metadata: NativeCacheRecordMetadata(
                    accountID: data.profile.id,
                    environment: .production,
                    schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                    domain: domain,
                    fetchedAt: lastValidatedAt,
                    lastValidatedAt: lastValidatedAt,
                    sourceEndpoint: "/api/v1/users/\(data.profile.username)",
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
}

public struct ProfileGraphProfile: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let href: String
    public let canonicalURL: URL

    public init(id: String, username: String, href: String, canonicalURL: URL) {
        self.id = id
        self.username = username
        self.href = href
        self.canonicalURL = canonicalURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case href
        case canonicalURL = "canonicalUrl"
    }
}

public struct ProfileGraphInteractionCounts: Codable, Equatable, Sendable {
    public let spoons: Int
    public let forks: Int
    public let cookbookSaves: Int

    public init(spoons: Int, forks: Int, cookbookSaves: Int) {
        self.spoons = spoons
        self.forks = forks
        self.cookbookSaves = cookbookSaves
    }
}

public struct ProfileGraphRow: Codable, Identifiable, Equatable, Sendable {
    public let chefID: String
    public let username: String
    public let photoURL: URL?
    public let href: String
    public let canonicalURL: URL
    public let interactionCounts: ProfileGraphInteractionCounts
    public let latestInteractionAt: String?

    public var id: String { chefID }

    public var openRoute: AppRoute {
        .profile(identifier: username)
    }

    public var interactionSummary: String {
        let parts = [
            countLabel(interactionCounts.spoons, singular: "spoon"),
            countLabel(interactionCounts.forks, singular: "fork"),
            countLabel(interactionCounts.cookbookSaves, singular: "cookbook save")
        ].compactMap { $0 }
        return parts.isEmpty ? "No interactions yet" : parts.joined(separator: ", ")
    }

    public init(
        chefID: String,
        username: String,
        photoURL: URL?,
        href: String,
        canonicalURL: URL,
        interactionCounts: ProfileGraphInteractionCounts,
        latestInteractionAt: String?
    ) {
        self.chefID = chefID
        self.username = username
        self.photoURL = photoURL
        self.href = href
        self.canonicalURL = canonicalURL
        self.interactionCounts = interactionCounts
        self.latestInteractionAt = latestInteractionAt
    }

    private enum CodingKeys: String, CodingKey {
        case chefID = "chefId"
        case username
        case photoURL = "photoUrl"
        case href
        case canonicalURL = "canonicalUrl"
        case interactionCounts
        case latestInteractionAt
    }

    private func countLabel(_ count: Int, singular: String) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(count) \(singular)\(count == 1 ? "" : "s")"
    }
}

public struct ProfileSurfaceEmptyState: Codable, Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct ProfileGraphPage: Codable, Equatable, Sendable {
    public let profile: ProfileGraphProfile
    public let direction: ProfileGraphDirection
    public let page: Int
    public let pageSize: Int
    public let total: Int
    public let nextCursor: String?
    public let rows: [ProfileGraphRow]
    public let source: ProfileSurfaceDataSource
    public let emptyState: ProfileSurfaceEmptyState?

    public init(
        profile: ProfileGraphProfile,
        direction: ProfileGraphDirection,
        page: Int,
        pageSize: Int,
        total: Int,
        nextCursor: String?,
        rows: [ProfileGraphRow],
        source: ProfileSurfaceDataSource,
        emptyState: ProfileSurfaceEmptyState? = nil
    ) {
        self.profile = profile
        self.direction = direction
        self.page = page
        self.pageSize = pageSize
        self.total = total
        self.nextCursor = nextCursor
        self.rows = rows
        self.source = source
        self.emptyState = emptyState
    }

    public func with(direction: ProfileGraphDirection, source: ProfileSurfaceDataSource) -> ProfileGraphPage {
        ProfileGraphPage(
            profile: profile,
            direction: direction,
            page: page,
            pageSize: pageSize,
            total: total,
            nextCursor: nextCursor,
            rows: rows,
            source: source,
            emptyState: rows.isEmpty ? Self.emptyState(for: direction) : emptyState
        )
    }

    public static func empty(
        profile: ProfileGraphProfile,
        direction: ProfileGraphDirection,
        page: Int,
        pageSize: Int,
        source: ProfileSurfaceDataSource
    ) -> ProfileGraphPage {
        ProfileGraphPage(
            profile: profile,
            direction: direction,
            page: page,
            pageSize: pageSize,
            total: 0,
            nextCursor: nil,
            rows: [],
            source: source,
            emptyState: emptyState(for: direction)
        )
    }

    public static func emptyState(for direction: ProfileGraphDirection) -> ProfileSurfaceEmptyState {
        switch direction {
        case .fellowChefs:
            ProfileSurfaceEmptyState(
                title: "No fellow chefs yet",
                message: "Fellow chefs appear after this chef cooks, forks, or saves recipes from other chefs.",
                systemImage: "person.2"
            )
        case .kitchenVisitors:
            ProfileSurfaceEmptyState(
                title: "No kitchen visitors yet",
                message: "Kitchen visitors appear after other chefs cook, fork, or save this chef's recipes.",
                systemImage: "person.crop.circle.badge.clock"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case direction
        case page
        case pageSize
        case total
        case nextCursor
        case rows
        case source
        case emptyState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(ProfileGraphProfile.self, forKey: .profile)
        direction = try container.decodeIfPresent(ProfileGraphDirection.self, forKey: .direction) ?? .fellowChefs
        page = try container.decode(Int.self, forKey: .page)
        pageSize = try container.decode(Int.self, forKey: .pageSize)
        total = try container.decode(Int.self, forKey: .total)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        rows = try container.decode([ProfileGraphRow].self, forKey: .rows)
        source = try container.decodeIfPresent(ProfileSurfaceDataSource.self, forKey: .source) ?? .cache(serverRevision: nil, lastValidatedAt: .distantPast)
        emptyState = try container.decodeIfPresent(ProfileSurfaceEmptyState.self, forKey: .emptyState)
    }
}

public protocol ProfileChefGraphSurfaceRepository: Sendable {
    func profile(identifier: String) async throws -> ProfileSurfaceResult
    func graph(identifier: String, direction: ProfileGraphDirection, page: Int, limit: Int) async throws -> ProfileGraphPage
}

public struct LiveProfileChefGraphSurfaceRepository: ProfileChefGraphSurfaceRepository {
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

    public func profile(identifier: String) async throws -> ProfileSurfaceResult {
        let envelope = try await transport.send(
            PublicProfileRequests.profile(identifier: identifier),
            configuration: configuration,
            decode: ProfileSurfaceData.self
        )
        return ProfileSurfaceResult(
            data: envelope.data,
            source: .live(requestID: envelope.requestID, validatedAt: now())
        )
    }

    public func graph(identifier: String, direction: ProfileGraphDirection, page: Int, limit: Int) async throws -> ProfileGraphPage {
        let request: APIRequestBuilder
        switch direction {
        case .fellowChefs:
            request = PublicProfileRequests.fellowChefs(identifier: identifier, page: page, limit: limit)
        case .kitchenVisitors:
            request = PublicProfileRequests.kitchenVisitors(identifier: identifier, page: page, limit: limit)
        }
        let envelope = try await transport.send(
            request,
            configuration: configuration,
            decode: ProfileGraphPage.self
        )
        return envelope.data.with(
            direction: direction,
            source: .live(requestID: envelope.requestID, validatedAt: now())
        )
    }
}

public struct SnapshotProfileChefGraphSurfaceRepository: ProfileChefGraphSurfaceRepository {
    private let profileResult: ProfileSurfaceResult
    private let graphPages: [ProfileGraphPage]

    public init(profileResult: ProfileSurfaceResult, graphPages: [ProfileGraphPage]) {
        self.profileResult = profileResult
        self.graphPages = graphPages
    }

    public func profile(identifier _: String) async throws -> ProfileSurfaceResult {
        profileResult
    }

    public func graph(identifier _: String, direction: ProfileGraphDirection, page: Int, limit: Int) async throws -> ProfileGraphPage {
        if let graphPage = graphPages.first(where: { $0.direction == direction && $0.page == page }) {
            return graphPage
        }
        return ProfileGraphPage.empty(
            profile: ProfileGraphProfile(
                id: profileResult.data.profile.id,
                username: profileResult.data.profile.username,
                href: profileResult.data.profile.href,
                canonicalURL: profileResult.data.profile.canonicalURL
            ),
            direction: direction,
            page: page,
            pageSize: limit,
            source: profileResult.source
        )
    }
}

public struct FallbackProfileChefGraphSurfaceRepository: ProfileChefGraphSurfaceRepository {
    private let primary: any ProfileChefGraphSurfaceRepository
    private let fallback: any ProfileChefGraphSurfaceRepository

    public init(primary: any ProfileChefGraphSurfaceRepository, fallback: any ProfileChefGraphSurfaceRepository) {
        self.primary = primary
        self.fallback = fallback
    }

    public func profile(identifier: String) async throws -> ProfileSurfaceResult {
        do {
            return try await primary.profile(identifier: identifier)
        } catch {
            return try await fallback.profile(identifier: identifier)
        }
    }

    public func graph(identifier: String, direction: ProfileGraphDirection, page: Int, limit: Int) async throws -> ProfileGraphPage {
        do {
            return try await primary.graph(identifier: identifier, direction: direction, page: page, limit: limit)
        } catch {
            return try await fallback.graph(identifier: identifier, direction: direction, page: page, limit: limit)
        }
    }
}
