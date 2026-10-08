import Foundation

public struct NativeChefRef: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let username: String
    public let photoURL: URL?

    public init(id: String, username: String, photoURL: URL?) {
        self.id = id
        self.username = username
        self.photoURL = photoURL
    }

    public var profileRoute: AppRoute {
        .profile(identifier: username)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case photoURL = "photoUrl"
    }
}

public struct NativeChefInteractionCounts: Codable, Equatable, Hashable, Sendable {
    public let spoons: Int
    public let forks: Int
    public let cookbookSaves: Int

    public init(spoons: Int, forks: Int, cookbookSaves: Int) {
        self.spoons = spoons
        self.forks = forks
        self.cookbookSaves = cookbookSaves
    }
}

public struct NativeChefRow: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let chefID: String
    public let username: String
    public let photoURL: URL?
    public let interactionCounts: NativeChefInteractionCounts
    public let latestInteractionAt: String

    public var id: String { chefID }

    public init(
        chefID: String,
        username: String,
        photoURL: URL?,
        interactionCounts: NativeChefInteractionCounts,
        latestInteractionAt: String
    ) {
        self.chefID = chefID
        self.username = username
        self.photoURL = photoURL
        self.interactionCounts = interactionCounts
        self.latestInteractionAt = latestInteractionAt
    }

    public var profileRoute: AppRoute {
        .profile(identifier: username)
    }

    /// "2 cooked, 1 forked, 1 saved", omitting zero counts. Empty when the chef has no counted interactions.
    public var interactionSummary: String {
        [
            (interactionCounts.spoons, "cooked"),
            (interactionCounts.forks, "forked"),
            (interactionCounts.cookbookSaves, "saved")
        ]
        .filter { $0.0 > 0 }
        .map { "\($0.0) \($0.1)" }
        .joined(separator: ", ")
    }

    private enum CodingKeys: String, CodingKey {
        case chefID = "chefId"
        case username
        case photoURL = "photoUrl"
        case interactionCounts
        case latestInteractionAt
    }
}

public struct NativeChefList: Codable, Equatable, Sendable {
    public let total: Int
    public let rows: [NativeChefRow]

    public init(total: Int, rows: [NativeChefRow]) {
        self.total = total
        self.rows = rows
    }
}

public struct NativeChefActivityRecipe: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct NativeChefActivity: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case spooned
        case forked
        case saved
    }

    public enum Direction: String, Codable, Equatable, Sendable {
        case outbound
        case inbound
    }

    public let id: String
    public let kind: Kind
    public let direction: Direction
    public let eventAt: String
    public let actor: NativeChefRef
    public let otherChef: NativeChefRef
    public let recipe: NativeChefActivityRecipe?
    public let cookbook: NativeChefActivityRecipe?
    public let label: String

    public init(
        id: String,
        kind: Kind,
        direction: Direction,
        eventAt: String,
        actor: NativeChefRef,
        otherChef: NativeChefRef,
        recipe: NativeChefActivityRecipe?,
        cookbook: NativeChefActivityRecipe?,
        label: String
    ) {
        self.id = id
        self.kind = kind
        self.direction = direction
        self.eventAt = eventAt
        self.actor = actor
        self.otherChef = otherChef
        self.recipe = recipe
        self.cookbook = cookbook
        self.label = label
    }

    /// Matches the web Chefs page heading for each activity row.
    public var directionLabel: String {
        direction == .inbound ? "In your kitchen" : "From your kitchen"
    }

    public var recipeRoute: AppRoute? {
        recipe.map { .recipeDetail(id: $0.id, presentation: .detail) }
    }
}

/// Decoded `GET /api/v1/me/chefs` payload.
public struct NativeChefsData: Codable, Equatable, Sendable {
    public let viewer: NativeChefRef
    public let fellowChefs: NativeChefList
    public let chefsUsingMyRecipes: NativeChefList
    public let activity: [NativeChefActivity]

    public init(
        viewer: NativeChefRef,
        fellowChefs: NativeChefList,
        chefsUsingMyRecipes: NativeChefList,
        activity: [NativeChefActivity]
    ) {
        self.viewer = viewer
        self.fellowChefs = fellowChefs
        self.chefsUsingMyRecipes = chefsUsingMyRecipes
        self.activity = activity
    }
}

public protocol ChefsSurfaceRepository: Sendable {
    func fetchChefs() async throws -> NativeChefsData
}

public struct LiveChefsSurfaceRepository: ChefsSurfaceRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func fetchChefs() async throws -> NativeChefsData {
        try await transport.send(
            NativeChefsRequests.chefs(),
            configuration: configuration,
            decode: NativeChefsData.self
        ).data
    }
}

/// What the Chefs screen shows. Live data matches the website; when the chef graph cannot be loaded
/// (offline, signed out, request failure) the screen falls back to the chefs already known from the local cache.
public enum ChefsSurfaceContent: Equatable, Sendable {
    case live(NativeChefsData)
    case cachedFallback([NativeChefRef])

    public static func load(
        repository: (any ChefsSurfaceRepository)?,
        fallbackChefs: [NativeChefRef]
    ) async -> ChefsSurfaceContent {
        guard let repository, let data = try? await repository.fetchChefs() else {
            return .cachedFallback(fallbackChefs)
        }
        return .live(data)
    }

    public var fellowChefCount: Int {
        switch self {
        case .live(let data):
            data.fellowChefs.total
        case .cachedFallback(let chefs):
            chefs.count
        }
    }

    public var subtitle: String {
        "\(fellowChefCount) \(fellowChefCount == 1 ? "chef" : "chefs")"
    }

    public var fellowChefs: [NativeChefRef] {
        switch self {
        case .live(let data):
            data.fellowChefs.rows.map { NativeChefRef(id: $0.chefID, username: $0.username, photoURL: $0.photoURL) }
        case .cachedFallback(let chefs):
            chefs
        }
    }

    public var chefsUsingMyRecipes: [NativeChefRow] {
        switch self {
        case .live(let data):
            data.chefsUsingMyRecipes.rows
        case .cachedFallback:
            []
        }
    }

    public var fellowChefRows: [NativeChefRow] {
        switch self {
        case .live(let data):
            data.fellowChefs.rows
        case .cachedFallback:
            []
        }
    }

    public var activity: [NativeChefActivity] {
        switch self {
        case .live(let data):
            data.activity
        case .cachedFallback:
            []
        }
    }
}
