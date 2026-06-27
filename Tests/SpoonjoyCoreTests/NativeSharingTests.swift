import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native sharing payloads")
struct NativeSharingTests {
    @Test("public share route policy only exposes recipe and cookbook object URLs")
    func publicShareRoutePolicyOnlyExposesRecipeAndCookbookObjectURLs() throws {
        let recipeURL = try url("https://spoonjoy.app/recipes/recipe_lemon")
        let cookbookURL = try url("https://spoonjoy.app/cookbooks/cookbook_weeknight")

        #expect(NativePublicShareRoutePolicy.publicURL(for: .recipeDetail(id: "recipe_lemon", presentation: .detail)) == recipeURL)
        #expect(NativePublicShareRoutePolicy.publicURL(for: .recipeDetail(id: "recipe_lemon", presentation: .cook)) == recipeURL)
        #expect(NativePublicShareRoutePolicy.publicURL(for: .cookbookDetail(id: "cookbook_weeknight")) == cookbookURL)

        let privateOrNativeOnlyRoutes: [AppRoute] = [
            .kitchen,
            .recipes,
            .cookbooks,
            .recipeEditor(id: "recipe_lemon"),
            .recipeEditor(id: nil),
            .recipeCoverControls(id: "recipe_lemon"),
            .shoppingList,
            .search(query: "lemons", scope: .all),
            .search(query: "lemons", scope: .shoppingList),
            .capture,
            .settings,
            .unknownLink
        ]
        for route in privateOrNativeOnlyRoutes {
            #expect(NativePublicShareRoutePolicy.publicURL(for: route) == nil, "\(route)")
        }

        let unsafeObjectRoutes: [AppRoute] = [
            .recipeDetail(id: "../secret", presentation: .detail),
            .recipeDetail(id: "recipe/secret", presentation: .detail),
            .cookbookDetail(id: "cookbook/secret"),
            .cookbookDetail(id: "  cookbook_weeknight  ")
        ]
        for route in unsafeObjectRoutes {
            #expect(NativePublicShareRoutePolicy.publicURL(for: route) == nil, "\(route)")
        }
    }

    @Test("recipe and cookbook public payloads use canonical model URLs exactly")
    func recipeAndCookbookPublicPayloadsUseCanonicalModelURLsExactly() throws {
        let recipe = try Self.recipeFixture(canonicalURL: try url("https://spoonjoy.app/recipes/canonical-not-derived"))
        let cookbook = try Self.cookbookFixture(canonicalURL: try url("https://spoonjoy.app/cookbooks/canonical-cookbook"))

        let recipePayload = try NativeSharePayload.publicRecipe(recipe)
        let cookbookPayload = try NativeSharePayload.publicCookbook(cookbook)

        #expect(recipePayload.domain == .recipe)
        #expect(recipePayload.kind == .publicURL)
        #expect(recipePayload.publicURL == recipe.canonicalURL)
        #expect(recipePayload.route == .recipeDetail(id: recipe.id, presentation: .detail))
        #expect(recipePayload.title == recipe.title)
        #expect(recipePayload.subtitle.contains(recipe.chef.username))
        #expect(recipePayload.nativeTransfer == .publicURL(recipe.canonicalURL))

        #expect(cookbookPayload.domain == .cookbook)
        #expect(cookbookPayload.kind == .publicURL)
        #expect(cookbookPayload.publicURL == cookbook.canonicalURL)
        #expect(cookbookPayload.route == .cookbookDetail(id: cookbook.id))
        #expect(cookbookPayload.title == cookbook.title)
        #expect(cookbookPayload.subtitle.contains("\(cookbook.recipeCount)"))
        #expect(cookbookPayload.nativeTransfer == .publicURL(cookbook.canonicalURL))
    }

    @Test("private product values use native transfers without fake public URLs")
    func privateProductValuesUseNativeTransfersWithoutFakePublicURLs() throws {
        let recipe = try RecipeFixtureCatalog.decodeFromBundle().recipes[0]
        let spoon = try #require(recipe.recentSpoons.first)
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let shoppingItem = try #require(shoppingList.activeItems.first)
        let draft = try CaptureDraft.shareSheetURL(
            id: "draft_share_private",
            url: try url("https://example.com/recipe-to-import"),
            createdAt: "2026-06-27T14:45:00.000Z"
        )

        let privatePayloads = [
            NativeSharePayload.privateShoppingList(shoppingList),
            NativeSharePayload.privateShoppingItem(shoppingItem, listID: shoppingList.id),
            NativeSharePayload.privateSpoon(spoon, recipeTitle: recipe.title),
            NativeSharePayload.privateCaptureDraft(draft)
        ]

        #expect(privatePayloads.map(\.domain) == [.shoppingList, .shoppingItem, .spoon, .captureDraft])
        for payload in privatePayloads {
            #expect(payload.kind == .privateTransfer, "\(payload.domain)")
            #expect(payload.publicURL == nil, "\(payload.domain)")
            #expect(payload.route == nil, "\(payload.domain)")
            #expect(payload.nativeTransfer != nil, "\(payload.domain)")
            #expect(!payload.serializedTransferValue.contains("https://spoonjoy.app/"), "\(payload.domain)")
            #expect(!payload.serializedTransferValue.contains("spoonjoy.app/shopping-list"), "\(payload.domain)")
            #expect(!payload.serializedTransferValue.contains("spoonjoy.app/recipes/new"), "\(payload.domain)")
        }
    }

    @Test("sharing catalog stays system-share only and does not invent social surfaces")
    func sharingCatalogStaysSystemShareOnlyAndDoesNotInventSocialSurfaces() {
        let catalog = NativeShareSurfaceCatalog.spoonjoy
        let forbiddenFragments = [
            "comment",
            "feed",
            "message",
            "mail",
            "inbox",
            "mailto:",
            "/comments",
            "/feeds",
            "/messages"
        ]

        #expect(catalog.publicURLDomains == [.recipe, .cookbook])
        #expect(Set(catalog.privateTransferDomains) == Set<NativeShareDomain>([
            .shoppingList,
            .shoppingItem,
            .spoon,
            .captureDraft
        ]))
        #expect(catalog.systemDestinations == [.shareSheet])
        #expect(catalog.productDestinations.isEmpty)

        for identifier in catalog.allSurfaceIdentifiers {
            let normalized = identifier.lowercased()
            for fragment in forbiddenFragments {
                #expect(!normalized.contains(fragment), "\(identifier) contains \(fragment)")
            }
        }
        #expect(NativeCapabilityMetadata.spoonjoy.shareActions.contains("share-recipe"))
        #expect(NativeCapabilityMetadata.spoonjoy.shareActions.contains("share-cookbook"))
        #expect(!NativeCapabilityMetadata.spoonjoy.shareActions.contains("share-message"))
        #expect(!NativeCapabilityMetadata.spoonjoy.shareActions.contains("share-mail"))
        #expect(!NativeCapabilityMetadata.spoonjoy.shareActions.contains("share-comment"))
    }

    private static func recipeFixture(canonicalURL: URL) throws -> Recipe {
        let recipe = try RecipeFixtureCatalog.decodeFromBundle().recipes[0]
        return Recipe(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: recipe.href,
            canonicalURL: canonicalURL,
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            steps: recipe.steps,
            cookbooks: recipe.cookbooks,
            recentSpoons: recipe.recentSpoons
        )
    }

    private static func cookbookFixture(canonicalURL: URL) throws -> Cookbook {
        let cookbook = try CookbookFixtureCatalog.decodeFromBundle().cookbooks[0]
        return Cookbook(
            id: cookbook.id,
            title: cookbook.title,
            chef: cookbook.chef,
            recipeCount: cookbook.recipeCount,
            cover: cookbook.cover,
            href: cookbook.href,
            canonicalURL: canonicalURL,
            attribution: cookbook.attribution,
            createdAt: cookbook.createdAt,
            updatedAt: cookbook.updatedAt,
            recipes: cookbook.recipes
        )
    }

    private func url(_ rawURL: String) throws -> URL {
        try #require(URL(string: rawURL))
    }
}
