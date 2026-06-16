import Foundation

public enum PublicCatalogRequests {
    public static func listRecipes(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?
    ) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "recipes"],
            queryItems: listQueryItems(query: query, limit: limit, cursor: cursor)
        )
    }

    public static func recipeDetail(id: String) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "recipes", id],
            queryItems: []
        )
    }

    public static func listCookbooks(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?
    ) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "cookbooks"],
            queryItems: listQueryItems(query: query, limit: limit, cursor: cursor)
        )
    }

    public static func cookbookDetail(id: String) -> APIRequestBuilder {
        APIRequestBuilder(
            method: .get,
            pathComponents: ["api", "v1", "cookbooks", id],
            queryItems: []
        )
    }

    private static func listQueryItems(
        query: String?,
        limit: Int,
        cursor: PaginationCursor?
    ) -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            items.append(URLQueryItem(name: "query", value: query))
        }

        items.append(URLQueryItem(name: "limit", value: String(limit)))

        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor.rawValue))
        }

        return items
    }
}

public struct RecipeListData: Decodable, Equatable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let recipes: [RecipeSummary]
}

public struct RecipeDetailData: Decodable, Equatable {
    public let recipe: Recipe
}

public struct CookbookListData: Decodable, Equatable {
    public let query: String?
    public let limit: Int
    public let cursor: PaginationCursor?
    public let nextCursor: PaginationCursor?
    public let hasMore: Bool
    public let cookbooks: [CookbookSummary]
}

public struct CookbookDetailData: Decodable, Equatable {
    public let cookbook: Cookbook
}
