import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Public API v1 read client")
struct APIReadClientTests {
    @Test("recipe list request builds anonymous GET with query parameters")
    func recipeListRequestBuildsAnonymousGETWithQueryParameters() throws {
        let request = try PublicCatalogRequests.listRecipes(
            query: "lemon pasta",
            limit: 20,
            cursor: PaginationCursor(rawValue: "v1.cursor.next")
        )
        .urlRequest(configuration: .spoonjoyProduction)

        #expect(request.method == .get)
        #expect(request.url.path == "/api/v1/recipes")
        #expect(request.queryItems == [
            URLQueryItem(name: "query", value: "lemon pasta"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "cursor", value: "v1.cursor.next")
        ])
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Authorization"] == nil)
        #expect(request.body == nil)
    }

    @Test("recipe detail request encodes path ids and omits stale bearer token by default")
    func recipeDetailRequestEncodesPathAndOmitsBearerByDefault() throws {
        let configuration = APIClientConfiguration(
            baseURL: URL(string: "https://spoonjoy.app")!,
            bearerToken: "stale-token"
        )
        let anonymousRequest = try PublicCatalogRequests.recipeDetail(id: "recipe/with spaces")
            .urlRequest(configuration: configuration)
        let authenticatedRequest = try PublicCatalogRequests.recipeDetail(id: "recipe_1")
            .urlRequest(configuration: configuration, authorization: .includeBearerToken)

        #expect(anonymousRequest.method == .get)
        #expect(anonymousRequest.url.path == "/api/v1/recipes/recipe%2Fwith%20spaces")
        #expect(anonymousRequest.headers["Authorization"] == nil)
        #expect(authenticatedRequest.headers["Authorization"] == "Bearer stale-token")
    }

    @Test("public reads keep blank bearer tokens and blank queries out of requests")
    func publicReadsKeepBlankBearerTokensAndQueriesOutOfRequests() throws {
        let configuration = APIClientConfiguration(
            baseURL: URL(string: "https://spoonjoy.app")!,
            bearerToken: " \n "
        )
        let authenticatedRequest = try PublicCatalogRequests.recipeDetail(id: "recipe_1")
            .urlRequest(configuration: configuration, authorization: .includeBearerToken)
        let list = try PublicCatalogRequests.listRecipes(query: " \n ", limit: 25, cursor: nil)
            .urlRequest(configuration: .spoonjoyProduction)

        #expect(authenticatedRequest.headers["Authorization"] == nil)
        #expect(list.queryItems == [URLQueryItem(name: "limit", value: "25")])
    }

    @Test("cookbook list and detail requests share public read policy")
    func cookbookRequestsSharePublicReadPolicy() throws {
        let list = try PublicCatalogRequests.listCookbooks(query: nil, limit: 10, cursor: nil)
            .urlRequest(configuration: .spoonjoyProduction)
        let detail = try PublicCatalogRequests.cookbookDetail(id: "cookbook weeknights/été")
            .urlRequest(configuration: .spoonjoyProduction)

        #expect(list.method == .get)
        #expect(list.url.path == "/api/v1/cookbooks")
        #expect(list.queryItems == [URLQueryItem(name: "limit", value: "10")])
        #expect(list.headers["Authorization"] == nil)
        #expect(detail.method == .get)
        #expect(detail.url.path == "/api/v1/cookbooks/cookbook%20weeknights%2F%C3%A9t%C3%A9")
        #expect(detail.queryItems.isEmpty)
        #expect(detail.headers["Authorization"] == nil)
    }

    @Test("success envelopes decode recipe list data and pagination metadata")
    func successEnvelopesDecodeRecipeListAndPagination() throws {
        let envelope = try APIEnvelope<RecipeListData>.decode(Self.recipeListEnvelopeData)
        let result = try APIEnvelope<RecipeListData>.decodeResult(Self.recipeListEnvelopeData)

        #expect(envelope.requestID == "req_recipe_list")
        #expect(envelope.data.query == "lemon")
        #expect(envelope.data.nextCursor == PaginationCursor(rawValue: "v1.next"))
        #expect(envelope.data.hasMore)
        #expect(envelope.data.recipes.first?.id == "recipe_lemon_pantry_pasta")
        #expect(result == .success(envelope))
    }

    @Test("cookbook list data decodes summary rows without detail recipes")
    func cookbookListDataDecodesSummaryRowsWithoutDetailRecipes() throws {
        let envelope = try APIEnvelope<CookbookListData>.decode(
            Data(
                """
                {
                  "ok": true,
                  "requestId": "req_cookbook_list",
                  "data": {
                    "query": "weeknight",
                    "limit": 20,
                    "cursor": null,
                    "nextCursor": null,
                    "hasMore": false,
                    "cookbooks": [
                      {
                        "id": "cookbook_weeknights",
                        "title": "Weeknight Brights",
                        "chef": { "id": "chef_ari", "username": "ari" },
                        "recipeCount": 2,
                        "coverImageUrls": [
                          "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg"
                        ],
                        "href": "/cookbooks/cookbook_weeknights",
                        "canonicalUrl": "https://spoonjoy.app/cookbooks/cookbook_weeknights",
                        "attribution": {
                          "creditText": "Weeknight Brights by ari on Spoonjoy",
                          "canonicalUrl": "https://spoonjoy.app/cookbooks/cookbook_weeknights"
                        },
                        "createdAt": "2026-06-01T00:00:00.000Z",
                        "updatedAt": "2026-06-01T00:00:00.000Z"
                      }
                    ]
                  }
                }
                """.utf8
            )
        )

        let cookbook = try #require(envelope.data.cookbooks.first)

        #expect(envelope.requestID == "req_cookbook_list")
        #expect(cookbook.id == "cookbook_weeknights")
        #expect(cookbook.recipeCount == 2)
        #expect(cookbook.cover.primaryImageURL?.absoluteString == "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg")
    }

    @Test("error envelopes map API errors without losing status or request id")
    func errorEnvelopesMapAPIErrors() throws {
        let result = try APIEnvelope<RecipeListData>.decodeResult(Self.errorEnvelopeData)

        #expect(result == .failure(APIError(requestID: "req_error", code: "not_found", message: "Recipe not found", status: 404)))
        #expect(throws: DecodingError.self) {
            try APIEnvelope<RecipeListData>.decode(Self.errorEnvelopeData)
        }
    }

    @Test("pagination cursor rejects blank raw values")
    func paginationCursorRejectsBlankValues() throws {
        #expect(PaginationCursor(rawValue: "v1.valid")?.rawValue == "v1.valid")
        #expect(PaginationCursor(rawValue: "  v1.valid  ")?.rawValue == "v1.valid")
        #expect(PaginationCursor(rawValue: "   ") == nil)
        #expect(try JSONDecoder().decode(PaginationCursor.self, from: Data(#""v1.valid""#.utf8)).rawValue == "v1.valid")
        #expect(try JSONEncoder().encode(PaginationCursor(rawValue: "v1.valid")).isEmpty == false)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PaginationCursor.self, from: Data(#""   ""#.utf8))
        }
    }

    private static let recipeListEnvelopeData = Data(
        """
        {
          "ok": true,
          "requestId": "req_recipe_list",
          "data": {
            "query": "lemon",
            "limit": 20,
            "cursor": null,
            "nextCursor": "v1.next",
            "hasMore": true,
            "recipes": [
              {
                "id": "recipe_lemon_pantry_pasta",
                "title": "Lemon Pantry Pasta",
                "description": "Bright pantry pasta with lemon, garlic, and parmesan.",
                "servings": "4",
                "chef": { "id": "chef_ari", "username": "ari" },
                "coverImageUrl": "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg",
                "coverProvenanceLabel": "Chef photo",
                "coverSourceType": "chef-upload",
                "coverVariant": "image",
                "href": "/recipes/recipe_lemon_pantry_pasta",
                "canonicalUrl": "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta",
                "attribution": {
                  "creditText": "Lemon Pantry Pasta by ari on Spoonjoy",
                  "canonicalUrl": "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta",
                  "sourceUrl": null,
                  "sourceHost": null,
                  "sourceRecipe": null
                },
                "createdAt": "2026-06-01T00:00:00.000Z",
                "updatedAt": "2026-06-01T00:00:00.000Z"
              }
            ]
          }
        }
        """.utf8
    )

    private static let errorEnvelopeData = Data(
        """
        {
          "ok": false,
          "requestId": "req_error",
          "error": {
            "code": "not_found",
            "message": "Recipe not found",
            "status": 404
          }
        }
        """.utf8
    )
}
