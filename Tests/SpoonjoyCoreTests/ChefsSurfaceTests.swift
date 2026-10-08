import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native Chefs screen parity with the website")
struct ChefsSurfaceTests {
    static let json = """
    {
      "ok": true,
      "requestId": "req_chefs",
      "data": {
        "viewer": { "id": "chef_me", "username": "me", "photoUrl": null },
        "fellowChefs": {
          "total": 2,
          "rows": [
            { "chefId": "chef_julia", "username": "julia", "photoUrl": "https://spoonjoy.app/photos/julia.jpg",
              "interactionCounts": { "spoons": 2, "forks": 1, "cookbookSaves": 0 },
              "latestInteractionAt": "2026-06-03T10:00:00.000Z" },
            { "chefId": "chef_sam", "username": "sam", "photoUrl": null,
              "interactionCounts": { "spoons": 0, "forks": 0, "cookbookSaves": 0 },
              "latestInteractionAt": "2026-06-02T10:00:00.000Z" }
          ]
        },
        "chefsUsingMyRecipes": {
          "total": 1,
          "rows": [
            { "chefId": "chef_sam", "username": "sam", "photoUrl": null,
              "interactionCounts": { "spoons": 0, "forks": 0, "cookbookSaves": 3 },
              "latestInteractionAt": "2026-06-02T10:00:00.000Z" }
          ]
        },
        "activity": [
          { "id": "outbound:spoon:s1", "kind": "spooned", "direction": "outbound", "eventAt": "2026-06-03T10:00:00.000Z",
            "actor": { "id": "chef_me", "username": "me", "photoUrl": null },
            "otherChef": { "id": "chef_julia", "username": "julia", "photoUrl": null },
            "recipe": { "id": "recipe_1", "title": "Lemon Pasta" }, "cookbook": null,
            "label": "You cooked Lemon Pasta from julia." },
          { "id": "inbound:save:c1", "kind": "saved", "direction": "inbound", "eventAt": "2026-06-02T10:00:00.000Z",
            "actor": { "id": "chef_sam", "username": "sam", "photoUrl": null },
            "otherChef": { "id": "chef_sam", "username": "sam", "photoUrl": null },
            "recipe": null, "cookbook": { "id": "cb_1", "title": "Weeknights" },
            "label": "sam saved your Soup." }
        ]
      }
    }
    """

    static func decoded() throws -> NativeChefsData {
        try APIEnvelope<NativeChefsData>.decode(Data(json.utf8)).data
    }

    @Test("decodes the me/chefs payload and requests it with the bearer token")
    func decodesAndRequests() async throws {
        let transport = ChefsStubTransport(result: .success(Data(Self.json.utf8)))
        let repository = LiveChefsSurfaceRepository(
            transport: transport,
            configuration: APIClientConfiguration(baseURL: URL(string: "https://qa.spoonjoy.app")!, bearerToken: "sj_token")
        )
        let data = try await repository.fetchChefs()
        #expect(transport.requestedPaths == ["/api/v1/me/chefs"])
        #expect(transport.requestedAuthorization == ["Bearer sj_token"])
        #expect(data == (try Self.decoded()))
        #expect(data.fellowChefs.rows.map(\.chefID) == ["chef_julia", "chef_sam"])
        #expect(data.fellowChefs.rows[0].photoURL == URL(string: "https://spoonjoy.app/photos/julia.jpg"))
        #expect(data.activity[1].recipe == nil)
        #expect(data.activity[1].cookbook == NativeChefActivityRecipe(id: "cb_1", title: "Weeknights"))
    }

    @Test("default transport initializer is usable")
    func defaultTransport() {
        _ = LiveChefsSurfaceRepository(configuration: .spoonjoyProduction)
    }

    @Test("live content exposes fellow chefs, visitors and activity like the web page")
    func liveContent() async throws {
        let data = try Self.decoded()
        let content = await ChefsSurfaceContent.load(repository: ChefsStubRepository(result: .success(data)), fallbackChefs: [])
        #expect(content == .live(data))
        #expect(content.fellowChefCount == 2)
        #expect(content.subtitle == "2 chefs")
        #expect(content.fellowChefs.map(\.username) == ["julia", "sam"])
        #expect(content.fellowChefs.first?.profileRoute == .profile(identifier: "julia"))
        #expect(content.fellowChefRows.map(\.interactionSummary) == ["2 cooked, 1 forked", ""])
        #expect(content.fellowChefRows.first?.profileRoute == .profile(identifier: "julia"))
        #expect(content.chefsUsingMyRecipes.map(\.interactionSummary) == ["3 saved"])
        #expect(content.activity.map(\.directionLabel) == ["From your kitchen", "In your kitchen"])
        #expect(content.activity[0].recipeRoute == .recipeDetail(id: "recipe_1", presentation: .detail))
        #expect(content.activity[1].recipeRoute == nil)
        #expect(data.fellowChefs.rows.first?.id == "chef_julia")
        #expect(data.activity.first?.id == "outbound:spoon:s1")
    }

    @Test("single chef uses the singular subtitle")
    func singular() {
        let content = ChefsSurfaceContent.cachedFallback([NativeChefRef(id: "c", username: "solo", photoURL: nil)])
        #expect(content.subtitle == "1 chef")
    }

    @Test("falls back to cached chefs when the request fails or no repository is available")
    func fallback() async {
        let cached = [NativeChefRef(id: "chef_a", username: "alpha", photoURL: nil)]
        let failed = await ChefsSurfaceContent.load(
            repository: ChefsStubRepository(result: .failure(URLError(.notConnectedToInternet))),
            fallbackChefs: cached
        )
        let missing = await ChefsSurfaceContent.load(repository: nil, fallbackChefs: cached)
        for content in [failed, missing] {
            #expect(content == .cachedFallback(cached))
            #expect(content.fellowChefs == cached)
            #expect(content.fellowChefRows.isEmpty)
            #expect(content.chefsUsingMyRecipes.isEmpty)
            #expect(content.activity.isEmpty)
            #expect(content.fellowChefCount == 1)
        }
    }
}

private struct ChefsStubRepository: ChefsSurfaceRepository {
    let result: Result<NativeChefsData, Error>

    func fetchChefs() async throws -> NativeChefsData {
        try result.get()
    }
}

private final class ChefsStubTransport: SpoonjoyAPITransport, @unchecked Sendable {
    let result: Result<Data, Error>
    private(set) var requestedPaths: [String] = []
    private(set) var requestedAuthorization: [String] = []

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let built = try request.urlRequest(configuration: configuration)
        requestedPaths.append(built.url.path)
        requestedAuthorization.append(built.headers["Authorization"] ?? "")
        return try APIEnvelope<Value>.decode(try result.get())
    }
}
