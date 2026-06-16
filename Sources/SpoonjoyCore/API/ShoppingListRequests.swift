import Foundation

public enum ShoppingDeleteIdempotency: Equatable {
    case header
    case body
    case query
}

public enum ShoppingListRequests {
    public static func readShoppingList() -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "shopping-list"],
            queryItems: [],
            defaultAuthorization: .includeBearerToken
        )
    }

    public static func syncShoppingList(
        cursor: ShoppingSyncCursor?,
        limit: Int
    ) -> APIRequestBuilder {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor.rawValue))
        }

        return APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "shopping-list", "sync"],
            queryItems: queryItems,
            defaultAuthorization: .includeBearerToken
        )
    }

    public static func addItem(
        name: String,
        quantity: Double?,
        unit: String?,
        categoryKey: String?,
        iconKey: String?,
        clientMutationID: String
    ) throws -> APIRequestBuilder {
        try jsonRequest(
            method: .post,
            pathComponents: ["api", "v1", "shopping-list", "items"],
            body: AddShoppingItemBody(
                clientMutationID: clientMutationID,
                name: name,
                quantity: quantity,
                unit: unit,
                categoryKey: categoryKey,
                iconKey: iconKey
            )
        )
    }

    public static func setItemChecked(
        id: String,
        checked: Bool,
        clientMutationID: String
    ) throws -> APIRequestBuilder {
        try jsonRequest(
            method: .patch,
            pathComponents: ["api", "v1", "shopping-list", "items", id],
            body: CheckShoppingItemBody(
                clientMutationID: clientMutationID,
                checked: checked
            )
        )
    }

    public static func deleteItem(
        id: String,
        clientMutationID: String,
        idempotency: ShoppingDeleteIdempotency
    ) throws -> APIRequestBuilder {
        let pathComponents = ["api", "v1", "shopping-list", "items", id]

        switch idempotency {
        case .header:
            return APIRequestBuilder(
                method: .delete,
                pathComponents: pathComponents,
                queryItems: [],
                headers: ["X-Client-Mutation-Id": clientMutationID],
                defaultAuthorization: .includeBearerToken
            )
        case .body:
            return try jsonRequest(
                method: .delete,
                pathComponents: pathComponents,
                body: DeleteShoppingItemBody(clientMutationID: clientMutationID)
            )
        case .query:
            return APIRequestBuilder(
                method: .delete,
                pathComponents: pathComponents,
                queryItems: [URLQueryItem(name: "clientMutationId", value: clientMutationID)],
                defaultAuthorization: .includeBearerToken
            )
        }
    }

    private static func jsonRequest<Body: Encodable>(
        method: APIRequestMethod,
        pathComponents: [String],
        body: Body
    ) throws -> APIRequestBuilder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return APIRequestBuilder(
            method: method,
            pathComponents: pathComponents,
            queryItems: [],
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(body),
            defaultAuthorization: .includeBearerToken
        )
    }
}

private struct AddShoppingItemBody: Encodable {
    let clientMutationID: String
    let name: String
    let quantity: Double?
    let unit: String?
    let categoryKey: String?
    let iconKey: String?

    private enum CodingKeys: String, CodingKey {
        case clientMutationID = "clientMutationId"
        case name
        case quantity
        case unit
        case categoryKey
        case iconKey
    }
}

private struct CheckShoppingItemBody: Encodable {
    let clientMutationID: String
    let checked: Bool

    private enum CodingKeys: String, CodingKey {
        case clientMutationID = "clientMutationId"
        case checked
    }
}

private struct DeleteShoppingItemBody: Encodable {
    let clientMutationID: String

    private enum CodingKeys: String, CodingKey {
        case clientMutationID = "clientMutationId"
    }
}
