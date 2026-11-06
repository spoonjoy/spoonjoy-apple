import Foundation
import SpoonjoyCore

/// A Spoonjoy API in the test process, behind the production clients' own `URLSessionPerforming` seam: the app builds
/// the same requests and decodes the same envelopes it would against spoonjoy.app, and nothing leaves the process, so
/// `ReinsNetworkGuard` never sees it. It records every request, so a journey can assert what was sent.
///
/// It serves what the recipe journeys need: the public recipe list (Everyone), search over the recipes by title and
/// ingredient, the sync feed (empty, for the signed-in kitchen), and recipe edits, which it applies only to the version
/// they were based on and otherwise answers `409 edit_conflict` with its own version, as the real server does.
/// Any other request is answered 404 and recorded under `unexpected`.
public actor SpoonjoyFakeAPI: URLSessionPerforming {
    public struct Request: Sendable, Equatable {
        public let method: String
        public let path: String
        public let query: [String: String]
        public let body: Data?

        /// The JSON body, decoded.
        public var json: [String: Any]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    /// The fields of a recipe a recipe edit changes, as the server holds them.
    public struct RecipeVersion: Sendable, Equatable {
        public var title: String
        public var description: String?
        public var servings: String?
        public var updatedAt: String
    }

    private var recipes: [Recipe]
    private var versions: [String: RecipeVersion]
    private let accountID: String
    private var revision = 0
    public private(set) var requests: [Request] = []
    public private(set) var unexpected: [Request] = []

    public init(recipes: [Recipe], accountID: String = SpoonjoyFixtureKitchen.accountID) {
        self.recipes = recipes
        self.accountID = accountID
        versions = Dictionary(uniqueKeysWithValues: recipes.map {
            ($0.id, RecipeVersion(title: $0.title, description: $0.description, servings: $0.servings, updatedAt: $0.updatedAt))
        })
    }

    /// The recipe as the server holds it now.
    public func version(of recipeID: String) -> RecipeVersion? {
        versions[recipeID]
    }

    /// Another device renames the recipe: the server's version moves on, and an edit based on the old one conflicts.
    public func rename(_ recipeID: String, to title: String) {
        guard var version = versions[recipeID] else {
            return
        }
        version.title = title
        version.updatedAt = nextUpdatedAt()
        versions[recipeID] = version
    }

    public func requests(_ method: String, _ path: String) -> [Request] {
        requests.filter { $0.method == method && $0.path == path }
    }

    public nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await answer(request)
    }

    private func answer(_ urlRequest: URLRequest) throws -> (Data, URLResponse) {
        let url = urlRequest.url ?? URL(string: "https://spoonjoy.app/")!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = Dictionary((components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        let request = Request(method: urlRequest.httpMethod ?? "GET", path: url.path, query: query, body: urlRequest.httpBody)
        requests.append(request)
        let parts = url.path.split(separator: "/").map(String.init)

        if request.method == "PATCH", parts.count == 4, parts[0...2] == ["api", "v1", "recipes"], versions[parts[3]] != nil {
            return try edit(url, recipeID: parts[3], body: request.json ?? [:])
        }
        switch (request.method, parts) {
        case ("GET", ["api", "v1", "me", "sync"]):
            return try ok(url, [
                "freshness": [
                    "accountId": accountID,
                    "environment": "production",
                    "schemaVersion": 1,
                    "sourceEndpoint": "/api/v1/me/sync",
                    "generatedAt": "2026-06-01T00:00:00.000Z",
                    "lastValidatedAt": "2026-06-01T00:00:00.000Z",
                ],
                "entries": [Any](),
                "nextCursor": NSNull(),
                "hasMore": false,
            ])
        case ("GET", ["api", "v1", "recipes"]):
            let summaries = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipes))
            return try ok(url, ["query": NSNull(), "limit": 48, "cursor": NSNull(), "nextCursor": NSNull(), "hasMore": false, "recipes": summaries])
        case ("GET", ["api", "v1", "search"]):
            return try search(url, query: query["q"] ?? "", scope: query["scope"] ?? "all", limit: Int(query["limit"] ?? "") ?? 20)
        default:
            unexpected.append(request)
            return try respond(url, 404, ["ok": false, "requestId": "req_fake_404", "error": ["code": "not_found", "message": "Not in the fake Spoonjoy API: \(request.method) \(url.path)", "status": 404]])
        }
    }

    private func search(_ url: URL, query: String, scope: String, limit: Int) throws -> (Data, URLResponse) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = recipes.filter { recipe in
            guard !needle.isEmpty else {
                return false
            }
            let title = versions[recipe.id]?.title ?? recipe.title
            return title.lowercased().contains(needle)
                || recipe.steps.contains { $0.ingredients.contains { $0.name.lowercased().contains(needle) } }
        }
        let results = matches.prefix(limit).map { recipe in
            SearchSurfaceResult(
                type: .recipe,
                id: recipe.id,
                ownerID: recipe.chef.id,
                ownerUsername: recipe.chef.username,
                title: versions[recipe.id]?.title ?? recipe.title,
                subtitle: recipe.chef.username,
                snippet: nil,
                href: "/recipes/\(recipe.id)",
                canonicalURL: URL(string: "https://spoonjoy.app/recipes/\(recipe.id)")!,
                imageURL: nil,
                score: 1,
                metadata: [:]
            )
        }
        let data = SearchSurfaceData(query: query, scope: SearchScope(rawValue: scope) ?? .all, limit: limit, isAuthenticated: true, results: Array(results))
        return try ok(url, JSONSerialization.jsonObject(with: JSONEncoder().encode(data)))
    }

    private func edit(_ url: URL, recipeID: String, body: [String: Any]) throws -> (Data, URLResponse) {
        guard var version = versions[recipeID] else {
            throw URLError(.badServerResponse)
        }
        let expected = body["expectedUpdatedAt"] as? String
        if let expected, expected != version.updatedAt {
            return try respond(url, 409, [
                "ok": false,
                "requestId": "req_fake_conflict",
                "error": [
                    "code": "edit_conflict",
                    "message": "The recipe changed after expectedUpdatedAt; nothing was updated",
                    "status": 409,
                    "details": [
                        "reason": "recipe_changed",
                        "expectedUpdatedAt": expected,
                        "currentUpdatedAt": version.updatedAt,
                        "recipe": [
                            "id": recipeID,
                            "title": version.title,
                            "description": version.description ?? NSNull(),
                            "servings": version.servings ?? NSNull(),
                            "updatedAt": version.updatedAt,
                        ] as [String: Any],
                    ] as [String: Any],
                ] as [String: Any],
            ])
        }
        if let title = body["title"] as? String { version.title = title }
        if body.keys.contains("description") { version.description = body["description"] as? String }
        if body.keys.contains("servings") { version.servings = body["servings"] as? String }
        version.updatedAt = nextUpdatedAt()
        versions[recipeID] = version
        return try ok(url, ["recipe": ["id": recipeID, "title": version.title, "updatedAt": version.updatedAt]])
    }

    private func nextUpdatedAt() -> String {
        revision += 1
        return String(format: "2026-06-02T00:00:%02d.000Z", revision % 60)
    }

    private func ok(_ url: URL, _ data: Any) throws -> (Data, URLResponse) {
        try respond(url, 200, ["ok": true, "requestId": "req_fake_ok", "data": data])
    }

    private func respond(_ url: URL, _ status: Int, _ body: [String: Any]) throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (try JSONSerialization.data(withJSONObject: body), response)
    }
}

/// Cook sessions switched off: every call answers `.stopped`, so cook mode keeps its progress on the device.
public struct SpoonjoyOffCookSessionClient: CookSessionClient {
    public init() {}
    public func read(recipeID _: String) async -> CookSyncResult { .stopped }
    public func start(recipeID _: String) async -> CookSyncResult { .stopped }
    public func patch(recipeID _: String, server _: CookServerSnapshot, changes _: CookSyncChanges, mutationID _: String) async -> CookSyncResult { .stopped }
}

extension SpoonjoyReinsFixtures {
    /// The fixtures for a signed-in, online kitchen served by `api`: the editor, search and Everyone's catalog send to
    /// it, the sync engine syncs with it, and cook sessions are off.
    public static func online(_ api: SpoonjoyFakeAPI, base: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures()) -> SpoonjoyReinsFixtures {
        var fixtures = base
        fixtures.bootstrapMode = .liveFirst
        fixtures.apiTransport = { URLSessionAPITransport(session: api, authenticationRefresher: $0) }
        fixtures.syncTransport = URLSessionNativeSyncTransport(apiTransport: URLSessionAPITransport(session: api))
        fixtures.catalogTransport = URLSessionAPITransport(session: api)
        fixtures.cookSessionClient = { _ in SpoonjoyOffCookSessionClient() }
        return fixtures
    }

    /// The fixtures for a cache-only kitchen whose search and Everyone's catalog are served by `api`. Edits queue on
    /// the device, as they do offline.
    public static func cacheOnly(searchingWith api: SpoonjoyFakeAPI, base: SpoonjoyReinsFixtures = SpoonjoyReinsFixtures()) -> SpoonjoyReinsFixtures {
        var fixtures = base
        fixtures.apiTransport = { URLSessionAPITransport(session: api, authenticationRefresher: $0) }
        fixtures.catalogTransport = URLSessionAPITransport(session: api)
        return fixtures
    }
}
