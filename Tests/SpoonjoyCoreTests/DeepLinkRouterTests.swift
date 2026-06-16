import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Deep link router")
struct DeepLinkRouterTests {
    @Test("routes every accepted web and scheme URL")
    func routesEveryAcceptedWebAndSchemeURL() throws {
        let cases: [(String, AppRoute)] = [
            ("https://spoonjoy.app/", .kitchen),
            ("https://spoonjoy.app/recipes", .recipes),
            ("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta", .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)),
            ("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta#cook", .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook)),
            ("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta?mode=cook", .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook)),
            ("https://spoonjoy.app/cookbooks", .cookbooks),
            ("https://spoonjoy.app/cookbooks/cookbook_weeknight", .cookbookDetail(id: "cookbook_weeknight")),
            ("https://spoonjoy.app/shopping-list", .shoppingList),
            ("https://spoonjoy.app/search?q=lemon%20pasta&scope=all", .search(query: "lemon pasta", scope: .all)),
            ("https://spoonjoy.app/search?q=lemon%20pasta&scope=recipes", .search(query: "lemon pasta", scope: .recipes)),
            ("https://spoonjoy.app/search?q=lemon%20pasta&scope=cookbooks", .search(query: "lemon pasta", scope: .cookbooks)),
            ("https://spoonjoy.app/search?q=lemon%20pasta&scope=chefs", .search(query: "lemon pasta", scope: .chefs)),
            ("https://spoonjoy.app/search?q=lemon%20pasta&scope=shopping-list", .search(query: "lemon pasta", scope: .shoppingList)),
            ("https://spoonjoy.app/recipes/new", .capture),
            ("https://spoonjoy.app/account/settings", .settings),
            ("spoonjoy://kitchen", .kitchen),
            ("spoonjoy://recipes", .recipes),
            ("spoonjoy://recipes/recipe_lemon_pantry_pasta", .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail)),
            ("spoonjoy://recipes/recipe_lemon_pantry_pasta/cook", .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook)),
            ("spoonjoy://cookbooks", .cookbooks),
            ("spoonjoy://cookbooks/cookbook_weeknight", .cookbookDetail(id: "cookbook_weeknight")),
            ("spoonjoy://shopping-list", .shoppingList),
            ("spoonjoy://search?q=lemon%20pasta&scope=shopping-list", .search(query: "lemon pasta", scope: .shoppingList)),
            ("spoonjoy://capture", .capture),
            ("spoonjoy://settings", .settings)
        ]

        for (rawURL, expectedRoute) in cases {
            #expect(DeepLinkRouter.spoonjoy.route(for: try url(rawURL)) == expectedRoute, "\(rawURL)")
        }
    }

    @Test("rejects unsafe or unsupported links as unknown")
    func rejectsUnsafeOrUnsupportedLinksAsUnknown() throws {
        let unknownURLs = [
            "http://spoonjoy.app/",
            "https://example.com/recipes/recipe_lemon_pantry_pasta",
            "https://spoonjoy.app/recipes/",
            "https://spoonjoy.app/recipes/%20%20",
            "https://spoonjoy.app/recipes/..",
            "https://spoonjoy.app/recipes/%2E%2E%2Fsecret",
            "https://spoonjoy.app/cookbooks/%2E%2E%2Fsecret",
            "https://spoonjoy.app/search?q=lemon%20pasta&scope=shopping",
            "https://spoonjoy.app/search?scope=recipes",
            "https://spoonjoy.app/search?q=%20%20&scope=recipes",
            "https://spoonjoy.app/unknown",
            "spoonjoy:///recipes/recipe_lemon_pantry_pasta",
            "spoonjoy://recipes/",
            "spoonjoy://recipes/%2E%2E%2Fsecret",
            "spoonjoy://recipes/%2E%2E%2Fsecret/cook",
            "spoonjoy://cookbooks/%2E%2E%2Fsecret",
            "spoonjoy://search?q=lemon&scope=bad-scope",
            "spoonjoy://unknown"
        ]

        for rawURL in unknownURLs {
            #expect(DeepLinkRouter.spoonjoy.route(for: try url(rawURL)) == .unknownLink, "\(rawURL)")
        }
    }

    @Test("preserves decoded search query and defaults missing scope to all")
    func preservesDecodedSearchQueryAndDefaultsMissingScopeToAll() throws {
        #expect(
            DeepLinkRouter.spoonjoy.route(for: try url("https://spoonjoy.app/search?q=crispy%20rice")) ==
                .search(query: "crispy rice", scope: .all)
        )
        #expect(
            DeepLinkRouter.spoonjoy.route(for: try url("spoonjoy://search?q=crispy%20rice")) ==
                .search(query: "crispy rice", scope: .all)
        )
    }

    @Test("custom router configuration and route sections stay explicit")
    func customRouterConfigurationAndRouteSectionsStayExplicit() throws {
        let router = DeepLinkRouter(webHost: "staging.spoonjoy.app", scheme: "spoonjoy-beta")

        #expect(router.route(for: try url("https://staging.spoonjoy.app/")) == .kitchen)
        #expect(router.route(for: try url("spoonjoy-beta://settings")) == .settings)
        #expect(router.route(for: try url("https://spoonjoy.app/")) == .unknownLink)

        #expect(AppRoute.cookbooks.section == .cookbooks)
        #expect(AppRoute.cookbookDetail(id: "cookbook_weeknight").section == .cookbooks)
        #expect(AppRoute.search(query: "rice", scope: .all).section == .search)
        #expect(AppRoute.capture.section == .capture)
        #expect(AppRoute.settings.section == .settings)
        #expect(AppRoute.unknownLink.section == nil)
        #expect(AppRoute.cookbookDetail(id: "cookbook_weeknight").selectedRecipeID == nil)
        #expect(!AppRoute.search(query: "rice", scope: .recipes).isCookModeActive)
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }
}
