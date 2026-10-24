import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Cooking now: the recipes the chef is part-way through")
struct CookingNowTests {
    static let now = Date(timeIntervalSince1970: 1_793_000_000)

    static let listJSON = """
    {
      "ok": true,
      "requestId": "req_cooking_now",
      "data": {
        "recipes": [
          { "recipe": { "id": "recipe_pasta", "title": "Lemon pasta", "coverImageUrl": "https://spoonjoy.app/covers/pasta.jpg",
                        "href": "/recipes/recipe_pasta", "canonicalUrl": "https://spoonjoy.app/recipes/recipe_pasta" },
            "activeStepId": "step_2", "activeStepIndex": 2, "stepCount": 7, "checkedCount": 3, "totalCount": 9,
            "allCheckedAt": null, "touchedAt": "2026-10-24T10:00:00.000Z", "expiresAt": "2026-10-27T10:00:00.000Z",
            "timers": [ { "label": "Boil", "endsAt": "2026-10-24T10:08:00Z" }, { "label": null, "endsAt": "not a date" } ] },
          { "recipe": { "id": "recipe_tart", "title": "Jam tart", "coverImageUrl": null, "href": "/recipes/recipe_tart",
                        "canonicalUrl": "https://spoonjoy.app/recipes/recipe_tart" },
            "activeStepId": null, "activeStepIndex": 0, "stepCount": 2, "touchedAt": "2026-10-24T09:00:00Z",
            "expiresAt": "2026-10-27T09:00:00Z" }
        ]
      }
    }
    """

    @Test("decodes the server list and requests it with the bearer token")
    func decodesAndRequests() async throws {
        let transport = CookingNowStubTransport(body: Data(Self.listJSON.utf8))
        let repository = LiveCookingNowRepository(
            transport: transport,
            configuration: APIClientConfiguration(baseURL: URL(string: "https://qa.spoonjoy.app")!, bearerToken: "sj_token")
        )
        let entries = try await repository.fetchCookingNow()
        #expect(transport.requestedPaths == ["/api/v1/cooking-now"])
        #expect(transport.requestedAuthorization == ["Bearer sj_token"])
        #expect(entries.map(\.recipeID) == ["recipe_pasta", "recipe_tart"])
        let pasta = try #require(entries.first)
        #expect(pasta.title == "Lemon pasta")
        #expect(pasta.slug == nil)
        #expect(pasta.coverURL == URL(string: "https://spoonjoy.app/covers/pasta.jpg"))
        #expect(pasta.activeStepID == "step_2")
        #expect(pasta.stepLabel == "Step 3 of 7")
        #expect(pasta.checkedCount == 3)
        #expect(pasta.totalCount == 9)
        #expect(pasta.timers.map(\.label) == ["Boil"])
        #expect(pasta.route == .recipeDetail(id: "recipe_pasta", presentation: .cook))
        #expect(pasta.id == "recipe_pasta")
        let tart = entries[1]
        #expect(tart.coverURL == nil)
        #expect(tart.checkedCount == 0)
        #expect(tart.totalCount == 0)
        #expect(tart.timers.isEmpty)
        _ = LiveCookingNowRepository(configuration: .spoonjoyProduction)
    }

    @Test("a row with a bad date fails the list, and timers of an unknown shape are dropped, not the row")
    func decodingShapes() throws {
        let oddTimers = """
        { "recipes": [ { "recipe": { "id": "r1", "title": "Soup", "coverImageUrl": null }, "activeStepIndex": 1,
            "stepCount": 3, "touchedAt": "2026-10-24T10:00:00Z", "timers": { "unexpected": true } } ] }
        """
        let list = try JSONDecoder().decode(CookingNowServerList.self, from: Data(oddTimers.utf8))
        #expect(list.entries.map(\.stepLabel) == ["Step 2 of 3"])
        #expect(list.entries[0].timers.isEmpty)
        #expect(CookingNowServerList(entries: list.entries) == list)

        let badDate = """
        { "recipes": [ { "recipe": { "id": "r1", "title": "Soup" }, "activeStepIndex": 1, "stepCount": 3, "touchedAt": "yesterday" } ] }
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CookingNowServerList.self, from: Data(badDate.utf8))
        }
    }

    @Test("step label, progress and timers")
    func entryPresentation() {
        let empty = Self.entry("r0", stepIndex: 4, stepCount: 0, touched: 0)
        #expect(empty.stepLabel == "Cooking")
        #expect(empty.stepNumber == 0)
        #expect(empty.fractionComplete == 0)
        let past = Self.entry("r1", stepIndex: 9, stepCount: 4, touched: 0)
        #expect(past.stepNumber == 4)
        #expect(past.fractionComplete == 1)
        let negative = CookingNowEntry(recipeID: "r2", title: "T", stepIndex: -3, stepCount: -1, checkedCount: -2, totalCount: -5, lastTouchedAt: Self.now)
        #expect(negative.stepIndex == 0)
        #expect(negative.stepCount == 0)
        #expect(negative.checkedCount == 0)
        #expect(negative.totalCount == 0)
        #expect(!negative.isEverythingChecked)

        let soon = CookingNowTimer(label: "Rest", endsAt: Self.now.addingTimeInterval(60))
        let later = CookingNowTimer(label: "Bake", endsAt: Self.now.addingTimeInterval(600))
        let done = CookingNowTimer(label: nil, endsAt: Self.now.addingTimeInterval(-60))
        let timed = Self.entry("r3", stepIndex: 0, stepCount: 2, touched: 0, timers: [later, done, soon])
        #expect(timed.nextTimer(now: Self.now) == soon)
        #expect(Self.entry("r4", stepIndex: 0, stepCount: 2, touched: 0, timers: [done]).nextTimer(now: Self.now) == nil)
    }

    @Test("a recipe leaves after three days, or 30 minutes after everything is checked")
    func currentRules() {
        #expect(CookingNowBoard.isCurrent(Self.entry("a", stepIndex: 1, stepCount: 3, touched: -60), now: Self.now))
        #expect(!CookingNowBoard.isCurrent(Self.entry("a", stepIndex: 1, stepCount: 3, touched: -CookingNowBoard.staleInterval), now: Self.now))
        let finished = Self.entry("b", stepIndex: 2, stepCount: 3, touched: -60, checked: 4, total: 4)
        #expect(finished.isEverythingChecked)
        #expect(CookingNowBoard.isCurrent(finished, now: Self.now))
        let finishedLongAgo = Self.entry("b", stepIndex: 2, stepCount: 3, touched: -CookingNowBoard.finishedInterval, checked: 4, total: 4)
        #expect(!CookingNowBoard.isCurrent(finishedLongAgo, now: Self.now))
    }

    @Test("this device's progress becomes rows for the recipes the kitchen knows, once cooking has started")
    func localEntries() throws {
        let pasta = Self.recipe("recipe_pasta", title: "Lemon pasta", cover: URL(string: "https://spoonjoy.app/c.jpg"))
        let tart = Self.recipe("recipe_tart", title: "Jam tart", cover: nil)
        let started = try Self.progress(
            recipeID: "recipe_pasta", steps: ["s1", "s2", "s3"], active: 1, ingredients: ["i1", "i2"], checked: ["i1"],
            updatedAt: "2026-10-24T10:00:00.000Z"
        )
        let untouched = try Self.progress(recipeID: "recipe_tart", steps: ["t1", "t2"], active: 0, ingredients: ["j1"], checked: [], updatedAt: "2026-10-24T10:00:00Z")
        let checkedOnly = try Self.progress(recipeID: "recipe_tart", steps: ["t1", "t2"], active: 0, ingredients: [], checked: [], outputs: ["o1"], checkedOutputs: ["o1"], updatedAt: "")
        let unknownRecipe = try Self.progress(recipeID: "recipe_gone", steps: ["g1", "g2"], active: 1, ingredients: [], checked: [], updatedAt: "2026-10-24T10:00:00Z")
        let undated = try Self.progress(recipeID: "recipe_pasta", steps: ["s1", "s2"], active: 1, ingredients: [], checked: [], updatedAt: "", startedAt: "")

        let rows = CookingNowBoard.localEntries(
            progress: ["recipe_pasta": started, "recipe_tart": untouched, "recipe_gone": unknownRecipe],
            recipes: [pasta, tart, pasta]
        )
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.title == "Lemon pasta")
        #expect(row.coverURL == URL(string: "https://spoonjoy.app/c.jpg"))
        #expect(row.activeStepID == "s2")
        #expect(row.stepLabel == "Step 2 of 3")
        #expect(row.checkedCount == 1)
        #expect(row.totalCount == 2)
        #expect(row.lastTouchedAt == CookingNowBoard.date("2026-10-24T10:00:00Z"))

        // Falls back to when cooking started when the progress has no update time.
        let byStart = CookingNowBoard.localEntries(progress: ["recipe_tart": checkedOnly], recipes: [tart])
        #expect(byStart.map(\.recipeID) == ["recipe_tart"])
        #expect(CookingNowBoard.localEntries(progress: ["recipe_pasta": undated], recipes: [pasta]).isEmpty)
        #expect(try Self.progress(recipeID: "x", steps: ["a"], active: 0, ingredients: [], checked: [], completed: ["a"], updatedAt: "").hasStarted)
        #expect(CookingNowBoard.date(nil) == nil)
        #expect(CookingNowBoard.date("") == nil)
    }

    @Test("merging keeps the newest row per recipe, keeps server timers, drops what the server cleared, newest first")
    func merge() {
        let fetchedAt = Self.now.addingTimeInterval(-60)
        let timer = CookingNowTimer(label: "Boil", endsAt: Self.now.addingTimeInterval(300))
        let serverPasta = Self.entry("pasta", stepIndex: 1, stepCount: 5, touched: -900, timers: [timer], slug: "lemon-pasta", cover: URL(string: "https://spoonjoy.app/p.jpg"))
        let localPasta = Self.entry("pasta", stepIndex: 3, stepCount: 5, touched: -30)
        let serverTart = Self.entry("tart", stepIndex: 1, stepCount: 2, touched: -100)
        let staleLocalTart = Self.entry("tart", stepIndex: 0, stepCount: 2, touched: -400)
        let duplicateOlderServerSoup = Self.entry("soup", stepIndex: 0, stepCount: 4, touched: -800)
        let serverSoup = Self.entry("soup", stepIndex: 2, stepCount: 4, touched: -200)
        let clearedLocal = Self.entry("bread", stepIndex: 1, stepCount: 3, touched: -3600)
        let freshLocal = Self.entry("salad", stepIndex: 1, stepCount: 3, touched: -10)
        let ancient = Self.entry("stew", stepIndex: 1, stepCount: 3, touched: -CookingNowBoard.staleInterval - 1)

        let merged = CookingNowBoard.merge(
            server: [serverPasta, serverTart, duplicateOlderServerSoup, serverSoup, ancient],
            serverFetchedAt: fetchedAt,
            local: [localPasta, staleLocalTart, clearedLocal, freshLocal],
            now: Self.now
        )
        #expect(merged.map(\.recipeID) == ["salad", "pasta", "tart", "soup"])
        let pasta = merged[1]
        #expect(pasta.stepIndex == 3)
        #expect(pasta.timers == [timer])
        #expect(pasta.slug == nil)
        #expect(pasta.coverURL == URL(string: "https://spoonjoy.app/p.jpg"))
        #expect(merged[2].stepIndex == 1)
        #expect(merged[3].stepIndex == 2)

        // Signed out or offline with nothing saved: every local row stays. Equal times sort by recipe.
        let offline = CookingNowBoard.merge(
            server: [],
            serverFetchedAt: nil,
            local: [Self.entry("b", stepIndex: 0, stepCount: 1, touched: -5), Self.entry("a", stepIndex: 0, stepCount: 1, touched: -5), clearedLocal],
            now: Self.now
        )
        #expect(offline.map(\.recipeID) == ["a", "b", "bread"])

        // A local row with its own timers keeps them.
        let ownTimer = CookingNowTimer(label: "Mine", endsAt: Self.now.addingTimeInterval(30))
        let localWithTimer = Self.entry("pasta", stepIndex: 4, stepCount: 5, touched: -1, timers: [ownTimer])
        let kept = CookingNowBoard.merge(server: [serverPasta], serverFetchedAt: fetchedAt, local: [localWithTimer], now: Self.now)
        #expect(kept.first?.timers == [ownTimer])
    }

    @Test("the offline copy belongs to one account")
    func cache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cooking-now-\(UUID().uuidString)", isDirectory: true)
        let store = CookingNowCacheStore(directory: directory)
        let scope = CookingNowCache.scope(accountID: "chef_ari", environment: .production)
        #expect(store.load(scope: scope) == nil)
        let cache = CookingNowCache(scope: scope, fetchedAt: Self.now, entries: [Self.entry("pasta", stepIndex: 1, stepCount: 3, touched: 0)])
        store.save(cache)
        #expect(store.load(scope: scope) == cache)
        #expect(store.load(scope: CookingNowCache.scope(accountID: "chef_sam", environment: .production)) == nil)
        try Data("not json".utf8).write(to: directory.appendingPathComponent(CookingNowCacheStore.fileName))
        #expect(store.load(scope: scope) == nil)
    }

    // MARK: - Fixtures

    static func entry(
        _ id: String,
        stepIndex: Int,
        stepCount: Int,
        touched offset: TimeInterval,
        checked: Int = 0,
        total: Int = 0,
        timers: [CookingNowTimer] = [],
        slug: String? = nil,
        cover: URL? = nil
    ) -> CookingNowEntry {
        CookingNowEntry(
            recipeID: id,
            title: id.capitalized,
            slug: slug,
            coverURL: cover,
            stepIndex: stepIndex,
            stepCount: stepCount,
            checkedCount: checked,
            totalCount: total,
            lastTouchedAt: now.addingTimeInterval(offset),
            timers: timers
        )
    }

    static func progress(
        recipeID: String,
        steps: [String],
        active: Int,
        ingredients: [String],
        checked: [String],
        outputs: [String] = [],
        checkedOutputs: [String] = [],
        completed: [String] = [],
        updatedAt: String,
        startedAt: String = "2026-10-24T09:00:00Z"
    ) throws -> CookModeProgress {
        let object: [String: Any] = [
            "recipeID": recipeID,
            "stepIDs": steps,
            "activeStepIndex": active,
            "completedStepIDs": completed,
            "ingredientIDs": ingredients,
            "stepOutputUseIDs": outputs,
            "scaleFactor": 1,
            "checkedIngredientIDs": checked,
            "checkedStepOutputUseIDs": checkedOutputs,
            "startedAt": startedAt,
            "updatedAt": updatedAt
        ]
        return try JSONDecoder().decode(CookModeProgress.self, from: JSONSerialization.data(withJSONObject: object))
    }

    static func recipe(_ id: String, title: String, cover: URL?) -> Recipe {
        let url = URL(string: "https://spoonjoy.app/recipes/\(id)")!
        return Recipe(
            id: id,
            title: title,
            description: nil,
            servings: nil,
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: cover,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/\(id)",
            canonicalURL: url,
            attribution: RecipeAttribution(creditText: "By ari", canonicalURL: url, sourceURLRaw: nil, sourceHost: nil, sourceRecipe: nil),
            createdAt: "2026-10-01T00:00:00Z",
            updatedAt: "2026-10-01T00:00:00Z",
            steps: [],
            cookbooks: []
        )
    }
}

private final class CookingNowStubTransport: SpoonjoyAPITransport, @unchecked Sendable {
    let body: Data
    private(set) var requestedPaths: [String] = []
    private(set) var requestedAuthorization: [String] = []

    init(body: Data) {
        self.body = body
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let built = try request.urlRequest(configuration: configuration)
        requestedPaths.append(built.url.path)
        requestedAuthorization.append(built.headers["Authorization"] ?? "")
        return try APIEnvelope<Value>.decode(body)
    }
}
