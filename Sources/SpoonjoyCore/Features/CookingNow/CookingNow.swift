import Foundation

/// A running timer on a recipe the chef is cooking, when the server reports one.
public struct CookingNowTimer: Codable, Hashable, Sendable {
    public let label: String?
    public let endsAt: Date

    public init(label: String?, endsAt: Date) {
        self.label = label
        self.endsAt = endsAt
    }
}

/// One recipe the chef is part-way through: a card in the Kitchen's "Cooking now" strip and a row in the tab bar's
/// switcher. Rows come from `GET /api/v1/cooking-now` (progress from every device) and from this device's own cook
/// progress, merged by `CookingNowBoard`.
public struct CookingNowEntry: Codable, Hashable, Sendable, Identifiable {
    public let recipeID: String
    public let title: String
    public let slug: String?
    public let coverURL: URL?
    public let activeStepID: String?
    /// The current step, counted from zero.
    public let stepIndex: Int
    public let stepCount: Int
    public let checkedCount: Int
    public let totalCount: Int
    public let lastTouchedAt: Date
    public let timers: [CookingNowTimer]

    public init(
        recipeID: String,
        title: String,
        slug: String? = nil,
        coverURL: URL? = nil,
        activeStepID: String? = nil,
        stepIndex: Int,
        stepCount: Int,
        checkedCount: Int,
        totalCount: Int,
        lastTouchedAt: Date,
        timers: [CookingNowTimer] = []
    ) {
        self.recipeID = recipeID
        self.title = title
        self.slug = slug
        self.coverURL = coverURL
        self.activeStepID = activeStepID
        self.stepIndex = max(0, stepIndex)
        self.stepCount = max(0, stepCount)
        self.checkedCount = max(0, checkedCount)
        self.totalCount = max(0, totalCount)
        self.lastTouchedAt = lastTouchedAt
        self.timers = timers
    }

    public var id: String {
        recipeID
    }

    /// The step the chef is on, counted from one and never past the last step.
    public var stepNumber: Int {
        stepCount == 0 ? 0 : min(stepIndex + 1, stepCount)
    }

    /// "Step 3 of 7", the same words the web strip uses.
    public var stepLabel: String {
        stepCount == 0 ? "Cooking" : "Step \(stepNumber) of \(stepCount)"
    }

    /// How far through the steps the chef is, from 0 to 1, for the card's progress bar.
    public var fractionComplete: Double {
        stepCount == 0 ? 0 : Double(stepNumber) / Double(stepCount)
    }

    public var isEverythingChecked: Bool {
        totalCount > 0 && checkedCount >= totalCount
    }

    /// Cook mode for this recipe; cook mode reopens on the step its saved progress is on.
    public var route: AppRoute {
        .recipeDetail(id: recipeID, presentation: .cook)
    }

    /// The timer that ends soonest and has not ended yet.
    public func nextTimer(now: Date) -> CookingNowTimer? {
        timers.filter { $0.endsAt > now }.min { $0.endsAt < $1.endsAt }
    }

    /// The same entry with the other one's running timers, for a local row the server knows timers for.
    func carryingTimers(from other: CookingNowEntry) -> CookingNowEntry {
        CookingNowEntry(
            recipeID: recipeID,
            title: title,
            slug: slug ?? other.slug,
            coverURL: coverURL ?? other.coverURL,
            activeStepID: activeStepID,
            stepIndex: stepIndex,
            stepCount: stepCount,
            checkedCount: checkedCount,
            totalCount: totalCount,
            lastTouchedAt: lastTouchedAt,
            timers: timers.isEmpty ? other.timers : timers
        )
    }
}

/// Decides which recipes are "cooking now": merges the server's list with this device's cook progress and drops what
/// the server would drop.
public enum CookingNowBoard {
    /// A recipe leaves the list three days after it was last touched.
    public static let staleInterval: TimeInterval = 3 * 24 * 60 * 60
    /// A recipe with everything checked leaves the list 30 minutes after its last touch.
    public static let finishedInterval: TimeInterval = 30 * 60
    /// A server list read at `fetchedAt` speaks for progress touched before it, less this allowance for a cook-session
    /// push that had not reached the server yet.
    public static let pushAllowance: TimeInterval = 2 * 60

    public static func isCurrent(_ entry: CookingNowEntry, now: Date) -> Bool {
        let age = now.timeIntervalSince(entry.lastTouchedAt)
        guard age < staleInterval else {
            return false
        }
        return !(entry.isEverythingChecked && age >= finishedInterval)
    }

    /// This device's cook progress as rows, for recipes the kitchen knows. Progress that never left the first step
    /// with nothing checked or done is not cooking yet.
    public static func localEntries(progress: [String: CookModeProgress], recipes: [Recipe]) -> [CookingNowEntry] {
        let recipesByID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return progress.values.compactMap { progress -> CookingNowEntry? in
            guard let recipe = recipesByID[progress.recipeID],
                  let touchedAt = date(progress.updatedAt) ?? date(progress.startedAt),
                  progress.hasStarted else {
                return nil
            }
            return CookingNowEntry(
                recipeID: recipe.id,
                title: recipe.title,
                coverURL: recipe.displayCoverImageURL,
                activeStepID: progress.currentStepID,
                stepIndex: progress.activeStepIndex,
                stepCount: progress.stepIDs.count,
                checkedCount: progress.checkedIngredientIDs.count,
                totalCount: progress.ingredientIDs.count,
                lastTouchedAt: touchedAt
            )
        }
    }

    /// The rows to show, newest first. For a recipe both lists hold, the one touched last wins and keeps any timers the
    /// server reported. A row only this device has is kept unless a server list read after it was touched left it out,
    /// which means the server cleared it (Clear progress, a logged cook, or another device's rules).
    public static func merge(
        server: [CookingNowEntry],
        serverFetchedAt: Date?,
        local: [CookingNowEntry],
        now: Date
    ) -> [CookingNowEntry] {
        var byRecipe = Dictionary(server.map { ($0.recipeID, $0) }, uniquingKeysWith: { first, second in
            first.lastTouchedAt >= second.lastTouchedAt ? first : second
        })
        for entry in local {
            if let known = byRecipe[entry.recipeID] {
                byRecipe[entry.recipeID] = entry.lastTouchedAt >= known.lastTouchedAt ? entry.carryingTimers(from: known) : known
            } else if serverFetchedAt.map({ entry.lastTouchedAt > $0.addingTimeInterval(-pushAllowance) }) ?? true {
                byRecipe[entry.recipeID] = entry
            }
        }
        return byRecipe.values
            .filter { isCurrent($0, now: now) }
            .sorted { lhs, rhs in
                lhs.lastTouchedAt == rhs.lastTouchedAt ? lhs.recipeID < rhs.recipeID : lhs.lastTouchedAt > rhs.lastTouchedAt
            }
    }

    static func date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

extension CookModeProgress {
    /// True once the chef has moved past the first step or checked or finished anything.
    var hasStarted: Bool {
        activeStepIndex > 0 || !completedStepIDs.isEmpty || !checkedIngredientIDs.isEmpty || !checkedStepOutputUseIDs.isEmpty
    }
}

// MARK: - Server list

/// The `data` of `GET /api/v1/cooking-now`: the signed-in chef's recipes in progress, newest first.
public struct CookingNowServerList: Decodable, Equatable, Sendable {
    public let entries: [CookingNowEntry]

    public init(entries: [CookingNowEntry]) {
        self.entries = entries
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode([CookingNowServerRow].self) {
            entries = rows.map(\.entry)
        } else {
            entries = try decoder.container(keyedBy: CodingKeys.self).decode([CookingNowServerRow].self, forKey: .items).map(\.entry)
        }
    }
}

/// One server row. Unknown or missing optional fields fall back instead of failing the whole list.
struct CookingNowServerRow: Decodable {
    let entry: CookingNowEntry

    private enum CodingKeys: String, CodingKey {
        case recipeId
        case title
        case slug
        case coverUrl
        case activeStepId
        case stepIndex
        case stepCount
        case checkedCount
        case totalCount
        case lastTouchedAt
        case timers
    }

    private struct Timer: Decodable {
        let label: String?
        let endsAt: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastTouched = try container.decode(String.self, forKey: .lastTouchedAt)
        guard let lastTouchedAt = CookingNowBoard.date(lastTouched) else {
            throw DecodingError.dataCorruptedError(forKey: .lastTouchedAt, in: container, debugDescription: "Not an ISO 8601 date: \(lastTouched)")
        }
        // A timer shape this build does not know drops the timers, not the row.
        let timers = (try? container.decodeIfPresent([Timer].self, forKey: .timers)) ?? []
        entry = CookingNowEntry(
            recipeID: try container.decode(String.self, forKey: .recipeId),
            title: try container.decode(String.self, forKey: .title),
            slug: try container.decodeIfPresent(String.self, forKey: .slug),
            coverURL: (try container.decodeIfPresent(String.self, forKey: .coverUrl)).flatMap(URL.init(string:)),
            activeStepID: try container.decodeIfPresent(String.self, forKey: .activeStepId),
            stepIndex: try container.decode(Int.self, forKey: .stepIndex),
            stepCount: try container.decode(Int.self, forKey: .stepCount),
            checkedCount: try container.decodeIfPresent(Int.self, forKey: .checkedCount) ?? 0,
            totalCount: try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0,
            lastTouchedAt: lastTouchedAt,
            timers: timers.compactMap { timer in
                CookingNowBoard.date(timer.endsAt).map { CookingNowTimer(label: timer.label, endsAt: $0) }
            }
        )
    }
}

public enum NativeCookingNowRequests {
    /// The signed-in chef's recipes in progress on every device, newest first.
    public static func list() -> APIRequestBuilder {
        APIRequestSupport.privateRead(pathComponents: ["api", "v1", "cooking-now"])
    }
}

public protocol CookingNowRepository: Sendable {
    func fetchCookingNow() async throws -> [CookingNowEntry]
}

public struct LiveCookingNowRepository: CookingNowRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func fetchCookingNow() async throws -> [CookingNowEntry] {
        try await transport.send(
            NativeCookingNowRequests.list(),
            configuration: configuration,
            decode: CookingNowServerList.self
        ).data.entries
    }
}

// MARK: - Offline copy

/// The last server list this device read, kept so the strip shows other devices' recipes offline.
public struct CookingNowCache: Codable, Equatable, Sendable {
    /// Account and environment the list belongs to; a different account never sees it.
    public let scope: String
    public let fetchedAt: Date
    public let entries: [CookingNowEntry]

    public init(scope: String, fetchedAt: Date, entries: [CookingNowEntry]) {
        self.scope = scope
        self.fetchedAt = fetchedAt
        self.entries = entries
    }

    public static func scope(accountID: String, environment: NativeCacheEnvironment) -> String {
        "\(environment.rawValue):\(accountID)"
    }
}

public struct CookingNowCacheStore {
    public static let fileName = "cooking-now.json"
    private let store: JSONFileStore<CookingNowCache>

    public init(directory: URL) {
        store = JSONFileStore(fileURL: directory.appendingPathComponent(Self.fileName))
    }

    /// The saved list for `scope`, or nil when there is none, it belongs to another account or it cannot be read.
    public func load(scope: String) -> CookingNowCache? {
        guard let cache = (try? store.load())?.value, cache.scope == scope else {
            return nil
        }
        return cache
    }

    public func save(_ cache: CookingNowCache) {
        try? store.save(cache)
    }
}
