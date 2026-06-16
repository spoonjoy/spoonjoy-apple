import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Shopping API v1 client")
struct ShoppingAPIClientTests {
    @Test("shopping list read and sync requests require bearer auth")
    func shoppingListReadAndSyncRequestsRequireBearerAuth() throws {
        let configuration = APIClientConfiguration(
            baseURL: URL(string: "https://spoonjoy.app")!,
            bearerToken: "sj_read_token"
        )
        let read = try ShoppingListRequests.readShoppingList()
            .urlRequest(configuration: configuration)
        let sync = try ShoppingListRequests.syncShoppingList(
            cursor: ShoppingSyncCursor(rawValue: "v1.cursor.next"),
            limit: 50
        )
        .urlRequest(configuration: configuration)

        #expect(read.method == .get)
        #expect(read.url.path == "/api/v1/shopping-list")
        #expect(read.queryItems.isEmpty)
        #expect(read.headers["Authorization"] == "Bearer sj_read_token")
        #expect(read.headers["Accept"] == "application/json")
        #expect(read.body == nil)

        #expect(sync.method == .get)
        #expect(sync.url.path == "/api/v1/shopping-list/sync")
        #expect(sync.queryItems == [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "cursor", value: "v1.cursor.next")
        ])
        #expect(sync.headers["Authorization"] == "Bearer sj_read_token")
        #expect(sync.body == nil)
    }

    @Test("add item request sends JSON mutation body")
    func addItemRequestSendsJSONMutationBody() throws {
        let request = try ShoppingListRequests.addItem(
            name: "Eggs",
            quantity: 12,
            unit: "Each",
            categoryKey: "dairy",
            iconKey: "egg",
            clientMutationID: "shopping-add-eggs"
        )
        .urlRequest(configuration: Self.writeConfiguration)
        let body = try decodeBody(AddShoppingItemBody.self, from: request)

        #expect(request.method == .post)
        #expect(request.url.path == "/api/v1/shopping-list/items")
        #expect(request.headers["Authorization"] == "Bearer sj_write_token")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.queryItems.isEmpty)
        #expect(body == AddShoppingItemBody(
            clientMutationId: "shopping-add-eggs",
            name: "Eggs",
            quantity: 12,
            unit: "Each",
            categoryKey: "dairy",
            iconKey: "egg"
        ))
    }

    @Test("check item request encodes item id and checked state")
    func checkItemRequestEncodesItemIDAndCheckedState() throws {
        let request = try ShoppingListRequests.setItemChecked(
            id: "item/check 123",
            checked: true,
            clientMutationID: "shopping-check-item-123"
        )
        .urlRequest(configuration: Self.writeConfiguration)
        let body = try decodeBody(CheckShoppingItemBody.self, from: request)

        #expect(request.method == .patch)
        #expect(request.url.path == "/api/v1/shopping-list/items/item%2Fcheck%20123")
        #expect(request.headers["Authorization"] == "Bearer sj_write_token")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(body == CheckShoppingItemBody(clientMutationId: "shopping-check-item-123", checked: true))
    }

    @Test("delete item request supports header body and query idempotency")
    func deleteItemRequestSupportsHeaderBodyAndQueryIdempotency() throws {
        let header = try ShoppingListRequests.deleteItem(
            id: "item/delete 123",
            clientMutationID: "shopping-delete-item-123",
            idempotency: .header
        )
        .urlRequest(configuration: Self.writeConfiguration)
        let body = try ShoppingListRequests.deleteItem(
            id: "item-delete-body",
            clientMutationID: "shopping-delete-body",
            idempotency: .body
        )
        .urlRequest(configuration: Self.writeConfiguration)
        let query = try ShoppingListRequests.deleteItem(
            id: "item-delete-query",
            clientMutationID: "shopping-delete-query",
            idempotency: .query
        )
        .urlRequest(configuration: Self.writeConfiguration)

        #expect(header.method == .delete)
        #expect(header.url.path == "/api/v1/shopping-list/items/item%2Fdelete%20123")
        #expect(header.headers["X-Client-Mutation-Id"] == "shopping-delete-item-123")
        #expect(header.headers["Content-Type"] == nil)
        #expect(header.body == nil)

        #expect(body.method == .delete)
        #expect(body.headers["X-Client-Mutation-Id"] == nil)
        #expect(body.headers["Content-Type"] == "application/json")
        #expect(try decodeBody(DeleteShoppingItemBody.self, from: body) == DeleteShoppingItemBody(clientMutationId: "shopping-delete-body"))

        #expect(query.method == .delete)
        #expect(query.headers["X-Client-Mutation-Id"] == nil)
        #expect(query.body == nil)
        #expect(query.queryItems == [URLQueryItem(name: "clientMutationId", value: "shopping-delete-query")])
    }

    @Test("shopping list envelopes decode read sync and mutation payloads")
    func shoppingListEnvelopesDecodeReadSyncAndMutationPayloads() throws {
        let read = try APIEnvelope<ShoppingListReadData>.decode(Self.shoppingListReadEnvelope)
        let sync = try APIEnvelope<ShoppingListSyncData>.decode(Self.shoppingListSyncEnvelope)
        let mutation = try APIEnvelope<ShoppingItemMutationData>.decode(Self.shoppingItemMutationEnvelope)
        let removal = try APIEnvelope<ShoppingItemMutationData>.decode(Self.shoppingItemRemovalEnvelope)

        #expect(read.data.shoppingList.id == "shopping_list_ari")
        #expect(read.data.shoppingList.chef == ChefSummary(id: "chef_ari", username: "ari"))
        #expect(read.data.nextCursor == ShoppingSyncCursor(rawValue: "2026-06-01T00:00:00.000Z"))
        #expect(read.data.shoppingList.items.first?.name == "eggs")

        #expect(sync.data.items.count == 2)
        #expect(sync.data.items.last?.deletedAt == "2026-06-01T00:05:00.000Z")
        #expect(sync.data.nextCursor == ShoppingSyncCursor(rawValue: "v1.cursor.after-sync"))
        #expect(sync.data.hasMore)

        #expect(mutation.data.created)
        #expect(mutation.data.updated == false)
        #expect(mutation.data.removed == nil)
        #expect(mutation.data.item.name == "eggs")
        #expect(mutation.data.mutation == ShoppingListMutationMetadata(clientMutationID: "shopping-add-eggs", replayed: false))

        #expect(removal.data.created == false)
        #expect(removal.data.updated == false)
        #expect(removal.data.removed == true)
        #expect(removal.data.mutation == ShoppingListMutationMetadata(clientMutationID: "shopping-delete-eggs", replayed: true))
    }

    @Test("shopping sync cursor rejects blank values")
    func shoppingSyncCursorRejectsBlankValues() throws {
        #expect(ShoppingSyncCursor(rawValue: "  v1.cursor  ")?.rawValue == "v1.cursor")
        #expect(ShoppingSyncCursor(rawValue: " \n ") == nil)
        #expect(try JSONDecoder().decode(ShoppingSyncCursor.self, from: Data(#""v1.cursor""#.utf8)).rawValue == "v1.cursor")
    }

    @Test("retry policy classifies idempotency and HTTP error responses")
    func retryPolicyClassifiesIdempotencyAndHTTPErrorResponses() throws {
        let inProgress = try apiError(from: Self.idempotencyInProgressEnvelope)
        let conflict = try apiError(from: Self.idempotencyConflictEnvelope)

        #expect(inProgress.code == "idempotency_in_progress")
        #expect(inProgress.status == 409)
        #expect(inProgress.retryAfterSeconds == 2)
        #expect(APIRetryPolicy.decision(for: inProgress) == .retrySameRequest(afterSeconds: 2))

        #expect(conflict.code == "idempotency_conflict")
        #expect(conflict.status == 409)
        #expect(APIRetryPolicy.decision(for: conflict) == .doNotRetry)
        #expect(APIRetryPolicy.decision(for: APIError(
            requestID: "req_rate_limited",
            code: "rate_limited",
            message: "Slow down",
            status: 429,
            retryAfterSeconds: 5
        )) == .retrySameRequest(afterSeconds: 5))
        #expect(APIRetryPolicy.decision(for: APIError(
            requestID: "req_server_error",
            code: "internal_error",
            message: "Try again",
            status: 503
        )) == .retrySameRequest(afterSeconds: nil))
        #expect(APIRetryPolicy.decision(for: APIError(
            requestID: "req_invalid_token",
            code: "invalid_token",
            message: "Refresh required",
            status: 401
        )) == .refreshAuthentication)
        #expect(APIRetryPolicy.decision(for: APIError(
            requestID: "req_validation",
            code: "validation_error",
            message: "Nope",
            status: 400
        )) == .doNotRetry)
    }

    private static let writeConfiguration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_write_token"
    )

    private static let shoppingListReadEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_shopping_list",
          "data": {
            "shoppingList": {
              "id": "shopping_list_ari",
              "chef": { "id": "chef_ari", "username": "ari" },
              "items": [
                {
                  "id": "item_eggs",
                  "name": "eggs",
                  "quantity": 12,
                  "unit": "each",
                  "checked": false,
                  "checkedAt": null,
                  "deletedAt": null,
                  "categoryKey": "dairy",
                  "iconKey": "egg",
                  "sortIndex": 0,
                  "updatedAt": "2026-06-01T00:00:00.000Z"
                }
              ],
              "updatedAt": "2026-06-01T00:00:00.000Z"
            },
            "nextCursor": "2026-06-01T00:00:00.000Z"
          }
        }
        """.utf8
    )

    private static let shoppingListSyncEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_shopping_sync",
          "data": {
            "items": [
              {
                "id": "item_eggs",
                "name": "eggs",
                "quantity": 12,
                "unit": "each",
                "checked": false,
                "checkedAt": null,
                "deletedAt": null,
                "categoryKey": "dairy",
                "iconKey": "egg",
                "sortIndex": 0,
                "updatedAt": "2026-06-01T00:00:00.000Z"
              },
              {
                "id": "item_removed",
                "name": "basil",
                "quantity": null,
                "unit": null,
                "checked": false,
                "checkedAt": null,
                "deletedAt": "2026-06-01T00:05:00.000Z",
                "categoryKey": "produce",
                "iconKey": "leaf",
                "sortIndex": 1,
                "updatedAt": "2026-06-01T00:05:00.000Z"
              }
            ],
            "nextCursor": "v1.cursor.after-sync",
            "hasMore": true
          }
        }
        """.utf8
    )

    private static let shoppingItemMutationEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_shopping_mutation",
          "data": {
            "created": true,
            "updated": false,
            "item": {
              "id": "item_eggs",
              "name": "eggs",
              "quantity": 12,
              "unit": "each",
              "checked": false,
              "checkedAt": null,
              "deletedAt": null,
              "categoryKey": "dairy",
              "iconKey": "egg",
              "sortIndex": 0,
              "updatedAt": "2026-06-01T00:00:00.000Z"
            },
            "mutation": {
              "clientMutationId": "shopping-add-eggs",
              "replayed": false
            }
          }
        }
        """.utf8
    )

    private static let shoppingItemRemovalEnvelope = Data(
        """
        {
          "ok": true,
          "requestId": "req_shopping_removal",
          "data": {
            "removed": true,
            "item": {
              "id": "item_eggs",
              "name": "eggs",
              "quantity": 12,
              "unit": "each",
              "checked": false,
              "checkedAt": null,
              "deletedAt": "2026-06-01T00:10:00.000Z",
              "categoryKey": "dairy",
              "iconKey": "egg",
              "sortIndex": 0,
              "updatedAt": "2026-06-01T00:10:00.000Z"
            },
            "mutation": {
              "clientMutationId": "shopping-delete-eggs",
              "replayed": true
            }
          }
        }
        """.utf8
    )

    private static let idempotencyInProgressEnvelope = Data(
        """
        {
          "ok": false,
          "requestId": "req_in_progress",
          "error": {
            "code": "idempotency_in_progress",
            "message": "clientMutationId is already in progress; retry after the Retry-After header",
            "status": 409,
            "details": { "retryAfterSeconds": 2 }
          }
        }
        """.utf8
    )

    private static let idempotencyConflictEnvelope = Data(
        """
        {
          "ok": false,
          "requestId": "req_conflict",
          "error": {
            "code": "idempotency_conflict",
            "message": "clientMutationId was already used for a different request",
            "status": 409
          }
        }
        """.utf8
    )
}

private struct AddShoppingItemBody: Decodable, Equatable {
    let clientMutationId: String
    let name: String
    let quantity: Double?
    let unit: String?
    let categoryKey: String?
    let iconKey: String?
}

private struct CheckShoppingItemBody: Decodable, Equatable {
    let clientMutationId: String
    let checked: Bool
}

private struct DeleteShoppingItemBody: Decodable, Equatable {
    let clientMutationId: String
}

private func decodeBody<Value: Decodable>(_ type: Value.Type, from request: APIRequest) throws -> Value {
    let body = try #require(request.body)
    return try JSONDecoder().decode(type, from: body)
}

private func apiError(from data: Data) throws -> APIError {
    let result = try APIEnvelope<ShoppingItemMutationData>.decodeResult(data)

    switch result {
    case .success:
        throw TestFailure("Expected API error envelope.")
    case .failure(let error):
        return error
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
