import Foundation

public enum ShoppingListRequests {
    public static func readShoppingList() -> APIRequestBuilder {
        APIRequestSupport.privateRead(
            pathComponents: ["api", "v1", "shopping-list"],
            queryItems: []
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

        return APIRequestSupport.privateRead(
            pathComponents: ["api", "v1", "shopping-list", "sync"],
            queryItems: queryItems
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
        var body: [String: Any] = [
            "clientMutationId": clientMutationID,
            "name": name
        ]
        if let quantity {
            body["quantity"] = quantity
        }
        if let unit {
            body["unit"] = unit
        }
        if let categoryKey {
            body["categoryKey"] = categoryKey
        }
        if let iconKey {
            body["iconKey"] = iconKey
        }

        return try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "shopping-list", "items"],
            body: body
        )
    }

    public static func setItemChecked(
        id: String,
        checked: Bool,
        clientMutationID: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .patch,
            pathComponents: ["api", "v1", "shopping-list", "items", id],
            body: [
                "clientMutationId": clientMutationID,
                "checked": checked
            ]
        )
    }

    public static func deleteItem(
        id: String,
        clientMutationID: String,
        idempotency: ShoppingDeleteIdempotency
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSONDelete(
            pathComponents: ["api", "v1", "shopping-list", "items", id],
            clientMutationID: clientMutationID,
            idempotency: idempotency
        )
    }

    public static func addIngredientsFromRecipe(
        recipeID: String,
        scaleFactor: Double,
        clientMutationID: String
    ) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "shopping-list", "add-from-recipe"],
            body: [
                "clientMutationId": clientMutationID,
                "recipeId": recipeID,
                "scaleFactor": scaleFactor
            ]
        )
    }

    public static func clearCompleted(clientMutationID: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "shopping-list", "clear-completed"],
            body: ["clientMutationId": clientMutationID]
        )
    }

    public static func clearAll(clientMutationID: String) throws -> APIRequestBuilder {
        try APIRequestSupport.privateJSON(
            method: .post,
            pathComponents: ["api", "v1", "shopping-list", "clear-all"],
            body: ["clientMutationId": clientMutationID]
        )
    }
}
