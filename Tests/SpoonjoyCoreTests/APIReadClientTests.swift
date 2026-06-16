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

    @Test("cookbook list and detail requests share public read policy")
    func cookbookRequestsSharePublicReadPolicy() throws {
        let list = try PublicCatalogRequests.listCookbooks(query: nil, limit: 10, cursor: nil)
            .urlRequest(configuration: .spoonjoyProduction)
        let detail = try PublicCatalogRequests.cookbookDetail(id: "cookbook_weeknights")
            .urlRequest(configuration: .spoonjoyProduction)

        #expect(list.method == .get)
        #expect(list.url.path == "/api/v1/cookbooks")
        #expect(list.queryItems == [URLQueryItem(name: "limit", value: "10")])
        #expect(list.headers["Authorization"] == nil)
        #expect(detail.method == .get)
        #expect(detail.url.path == "/api/v1/cookbooks/cookbook_weeknights")
        #expect(detail.queryItems.isEmpty)
        #expect(detail.headers["Authorization"] == nil)
    }

    @Test("success envelopes decode recipe list data and pagination metadata")
    func successEnvelopesDecodeRecipeListAndPagination() throws {
        let envelope = try APIEnvelope<RecipeListData>.decode(
            Data(
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
        )

        #expect(envelope.requestID == "req_recipe_list")
        #expect(envelope.data.query == "lemon")
        #expect(envelope.data.nextCursor == PaginationCursor(rawValue: "v1.next"))
        #expect(envelope.data.hasMore)
        #expect(envelope.data.recipes.first?.id == "recipe_lemon_pantry_pasta")
    }

    @Test("error envelopes map API errors without losing status or request id")
    func errorEnvelopesMapAPIErrors() throws {
        let result = try APIEnvelope<RecipeListData>.decodeResult(
            Data(
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
        )

        #expect(result == .failure(APIError(requestID: "req_error", code: "not_found", message: "Recipe not found", status: 404)))
    }

    @Test("pagination cursor rejects blank raw values")
    func paginationCursorRejectsBlankValues() {
        #expect(PaginationCursor(rawValue: "v1.valid")?.rawValue == "v1.valid")
        #expect(PaginationCursor(rawValue: "   ") == nil)
    }
}
