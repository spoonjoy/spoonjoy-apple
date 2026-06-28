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
        #expect(NativePublicShareRoutePolicy.publicURL(for: .cookbookDetail(id: "cookbook_weeknight")) == cookbookURL)

        let privateOrNativeOnlyRoutes: [AppRoute] = [
            .kitchen,
            .recipes,
            .cookbooks,
            .recipeDetail(id: "recipe_lemon", presentation: .cook),
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
            #expect(NativePublicShareRoutePolicy.publicURL(for: route) == nil)
        }

        let unsafeObjectRoutes: [AppRoute] = [
            .recipeDetail(id: "../secret", presentation: .detail),
            .recipeDetail(id: "recipe/secret", presentation: .detail),
            .cookbookDetail(id: "cookbook/secret"),
            .cookbookDetail(id: "  cookbook_weeknight  ")
        ]
        for route in unsafeObjectRoutes {
            #expect(NativePublicShareRoutePolicy.publicURL(for: route) == nil)
        }
    }

    @Test("public route payloads back toolbar sharing without leaking native-only routes")
    func publicRoutePayloadsBackToolbarSharingWithoutLeakingNativeOnlyRoutes() throws {
        let recipeURL = try url("https://spoonjoy.app/recipes/recipe_lemon")
        let cookbookURL = try url("https://spoonjoy.app/cookbooks/cookbook_weeknight")
        let recipePayload = try #require(NativeSharePayload.publicRoute(.recipeDetail(id: "recipe_lemon", presentation: .detail)))
        #expect(recipePayload.id == "recipe:recipe_lemon")
        #expect(recipePayload.domain == .recipe)
        #expect(recipePayload.kind == .publicURL)
        #expect(recipePayload.publicURL == recipeURL)
        #expect(recipePayload.route == .recipeDetail(id: "recipe_lemon", presentation: .detail))
        #expect(recipePayload.nativeTransfer == .publicURL(recipeURL))

        let cookbookPayload = try #require(NativeSharePayload.publicRoute(.cookbookDetail(id: "cookbook_weeknight")))
        #expect(cookbookPayload.id == "cookbook:cookbook_weeknight")
        #expect(cookbookPayload.domain == .cookbook)
        #expect(cookbookPayload.publicURL == cookbookURL)
        #expect(cookbookPayload.route == .cookbookDetail(id: "cookbook_weeknight"))
        #expect(cookbookPayload.nativeTransfer == .publicURL(cookbookURL))

        #expect(NativeSharePayload.publicRoute(.recipeDetail(id: "../secret", presentation: .detail)) == nil)
        #expect(NativeSharePayload.publicRoute(.cookbookDetail(id: "cookbook/secret")) == nil)
        #expect(NativeSharePayload.publicRoute(.recipeDetail(id: "recipe_lemon", presentation: .cook)) == nil)
        #expect(NativeSharePayload.publicRoute(.shoppingList) == nil)
        #expect(NativeSharePayload.publicRoute(.settings) == nil)
    }

    @Test("recipe and cookbook public payloads use canonical model URLs exactly")
    func recipeAndCookbookPublicPayloadsUseCanonicalModelURLsExactly() throws {
        let recipe = try Self.recipeFixture(canonicalURL: try url("https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta"))
        let cookbook = try Self.cookbookFixture(canonicalURL: try url("https://spoonjoy.app/cookbooks/cookbook_weeknights"))

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

    @Test("public payload builders reject non-object and non-spoonjoy canonical URLs")
    func publicPayloadBuildersRejectNonObjectAndNonSpoonjoyCanonicalURLs() throws {
        let invalidRecipeURLs = [
            "http://spoonjoy.app/recipes/recipe_lemon_pantry_pasta",
            "https://evil.example/recipes/recipe_lemon_pantry_pasta",
            "https://spoonjoy.app/account/settings",
            "https://spoonjoy.app/recipes",
            "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta/edit",
            "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta/covers",
            "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta?mode=cook",
            "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta#cook",
            "https://spoonjoy.app/shopping-list"
        ]
        for rawURL in invalidRecipeURLs {
            let recipe = try Self.recipeFixture(canonicalURL: try url(rawURL))
            #expect(throws: NativeSharePayloadError.invalidPublicURL(domain: .recipe, url: recipe.canonicalURL)) {
                try NativeSharePayload.publicRecipe(recipe)
            }
        }

        let invalidCookbookURLs = [
            "http://spoonjoy.app/cookbooks/cookbook_weeknight",
            "https://evil.example/cookbooks/cookbook_weeknight",
            "https://spoonjoy.app/cookbooks",
            "https://spoonjoy.app/account/settings",
            "https://spoonjoy.app/cookbooks/cookbook_weeknight/edit",
            "https://spoonjoy.app/search?q=weeknight&scope=cookbooks"
        ]
        for rawURL in invalidCookbookURLs {
            let cookbook = try Self.cookbookFixture(canonicalURL: try url(rawURL))
            #expect(throws: NativeSharePayloadError.invalidPublicURL(domain: .cookbook, url: cookbook.canonicalURL)) {
                try NativeSharePayload.publicCookbook(cookbook)
            }
        }
    }

    @Test("private product values use native transfers without fake public URLs")
    func privateProductValuesUseNativeTransfersWithoutFakePublicURLs() throws {
        let recipe = try RecipeFixtureCatalog.decodeFromBundle().recipes[0]
        let spoon = RecipeDetailRecentSpoon(
            id: "spoon_share_private",
            chefID: "chef_ari",
            recipeID: recipe.id,
            cookedAt: "2026-06-27T14:40:00.000Z",
            photoURL: nil,
            note: "More lemon next time.",
            nextTime: "Use the good olive oil.",
            deletedAt: nil,
            createdAt: "2026-06-27T14:40:00.000Z",
            updatedAt: "2026-06-27T14:41:00.000Z",
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
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
            #expect(payload.kind == .privateTransfer)
            #expect(payload.publicURL == nil)
            #expect(payload.route == nil)
            #expect(payload.nativeTransfer != nil)
            #expect(!payload.serializedTransferValue.contains("https://spoonjoy.app/"))
            #expect(!payload.serializedTransferValue.contains("spoonjoy.app/shopping-list"))
            #expect(!payload.serializedTransferValue.contains("spoonjoy.app/recipes/new"))
        }
    }

    @Test("capture draft private transfers redact credential URLs and local media identifiers")
    func captureDraftPrivateTransfersRedactCredentialURLsAndLocalMediaIdentifiers() throws {
        let signedURLDraft = try CaptureDraft.shareSheetURL(
            id: "draft_signed_url",
            url: try url("https://recipes.example/import/card?token=secret-token&signature=sig#private"),
            createdAt: "2026-06-27T15:04:00.000Z"
        )
        let signedURLPayload = NativeSharePayload.privateCaptureDraft(signedURLDraft)
        #expect(signedURLPayload.title == "recipes.example")
        #expect(signedURLPayload.serializedTransferValue.contains("capturedHost=recipes.example"))

        let localPathDraft = try CaptureDraft.localText(
            id: "draft_local_path",
            rawText: "/Users/ari/Library/Mobile Documents/Recipes/private-card.jpg\naccess_token=abc",
            sourceURL: try url("https://captures.example/raw?access_token=abc&key=def"),
            createdAt: "2026-06-27T15:05:00.000Z"
        )
        let localPathPayload = NativeSharePayload.privateCaptureDraft(localPathDraft)
        #expect(localPathPayload.title == "Capture Draft")
        #expect(localPathPayload.serializedTransferValue.contains("sourceHost=captures.example"))

        let jsonDraft = try CaptureDraft.jsonLD(
            id: "draft_json_signed_source",
            jsonLD: .object(["name": .string("Imported recipe")]),
            sourceURL: try url("https://json.example/schema?sig=signed-secret"),
            createdAt: "2026-06-27T15:06:00.000Z"
        )
        let jsonPayload = NativeSharePayload.privateCaptureDraft(jsonDraft)
        #expect(jsonPayload.title == "json.example")
        #expect(jsonPayload.serializedTransferValue.contains("sourceHost=json.example"))

        let mediaDraft = try CaptureDraft.cameraImage(
            id: "draft_private_media_identifier",
            assetIdentifier: "/private/var/mobile/Media/DCIM/secret-card.jpg",
            recognizedText: nil,
            createdAt: "2026-06-27T15:07:00.000Z"
        )
        let mediaPayload = NativeSharePayload.privateCaptureDraft(mediaDraft)
        #expect(mediaPayload.title == "Capture Draft")

        for payload in [signedURLPayload, localPathPayload, jsonPayload, mediaPayload] {
            assertNoSensitiveShareFragments(payload)
        }
    }

    @Test("private transfer edge labels cover checked items and sanitized capture titles")
    func privateTransferEdgeLabelsCoverCheckedItemsAndSanitizedCaptureTitles() throws {
        let checkedItem = ShoppingListItem(
            id: "item_checked",
            name: "olive oil",
            quantity: 2,
            unit: "tbsp",
            checked: true,
            checkedAt: "2026-06-27T15:08:00.000Z",
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 2,
            updatedAt: "2026-06-27T15:08:00.000Z"
        )
        let checkedPayload = NativeSharePayload.privateShoppingItem(checkedItem, listID: "list_private")
        #expect(checkedPayload.subtitle == "2 tbsp")
        #expect(checkedPayload.serializedTransferValue.contains("checked=true"))

        let httpURLDraft = try CaptureDraft.shareSheetURL(
            id: "draft_http_url",
            url: try url("http://plain.example/recipe?token=hidden"),
            createdAt: "2026-06-27T15:09:00.000Z"
        )
        let httpPayload = NativeSharePayload.privateCaptureDraft(httpURLDraft)
        #expect(httpPayload.title == "plain.example")
        #expect(httpPayload.serializedTransferValue.contains("capturedHost=plain.example"))
        assertNoSensitiveShareFragments(httpPayload)

        let textURLDraft = try CaptureDraft.localText(
            id: "draft_text_url",
            rawText: "https://text.example/recipe?signature=hidden",
            createdAt: "2026-06-27T15:10:00.000Z"
        )
        let textURLPayload = NativeSharePayload.privateCaptureDraft(textURLDraft)
        #expect(textURLPayload.title == "text.example")
        assertNoSensitiveShareFragments(textURLPayload)

        let plainTextDraft = try CaptureDraft.localText(
            id: "draft_plain_text",
            rawText: "Grandma's lemon card",
            createdAt: "2026-06-27T15:11:00.000Z"
        )
        #expect(NativeSharePayload.privateCaptureDraft(plainTextDraft).title == "Grandma's lemon card")

        let missingCapturedURLDraft = CaptureDraft(
            id: "draft_missing_capture_url",
            source: .url,
            rawText: "",
            imageAssetIdentifier: nil,
            capturedURL: nil,
            createdAt: "2026-06-27T15:12:00.000Z"
        )
        #expect(NativeSharePayload.privateCaptureDraft(missingCapturedURLDraft).title == "Capture Draft")

        let jsonDraftWithoutSource = try CaptureDraft.jsonLD(
            id: "draft_json_without_source",
            jsonLD: .object(["name": .string("No source")]),
            sourceURL: nil,
            createdAt: "2026-06-27T15:13:00.000Z"
        )
        #expect(NativeSharePayload.privateCaptureDraft(jsonDraftWithoutSource).title == "Capture Draft")
    }

    @Test("private transfer fallback labels cover sparse shopping spoon and capture values")
    func privateTransferFallbackLabelsCoverSparseShoppingSpoonAndCaptureValues() throws {
        let sparseItem = ShoppingListItem(
            id: "item_sparse",
            name: "salt",
            quantity: nil,
            unit: nil,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 1,
            updatedAt: "2026-06-27T15:00:00.000Z"
        )
        let sparseItemPayload = NativeSharePayload.privateShoppingItem(sparseItem, listID: "list_private")
        #expect(sparseItemPayload.subtitle == "Shopping list item")
        #expect(sparseItemPayload.serializedTransferValue.contains("checked=false"))
        #expect(!sparseItemPayload.serializedTransferValue.contains("quantity="))

        let cookedAtOnlySpoon = RecipeDetailRecentSpoon(
            id: "spoon_cooked_at_only",
            chefID: "chef_ari",
            recipeID: "recipe_lemon_pantry_pasta",
            cookedAt: "2026-06-27T15:01:00.000Z",
            photoURL: nil,
            note: nil,
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-27T15:01:00.000Z",
            updatedAt: "2026-06-27T15:01:00.000Z",
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        #expect(NativeSharePayload.privateSpoon(cookedAtOnlySpoon, recipeTitle: "Lemon Pantry Pasta").subtitle == "2026-06-27T15:01:00.000Z")

        let untimedSpoon = RecipeDetailRecentSpoon(
            id: "spoon_no_note_or_time",
            chefID: "chef_ari",
            recipeID: "recipe_lemon_pantry_pasta",
            cookedAt: nil,
            photoURL: nil,
            note: nil,
            nextTime: nil,
            deletedAt: nil,
            createdAt: "2026-06-27T15:02:00.000Z",
            updatedAt: "2026-06-27T15:02:00.000Z",
            chef: ChefSummary(id: "chef_ari", username: "ari")
        )
        #expect(NativeSharePayload.privateSpoon(untimedSpoon, recipeTitle: "Lemon Pantry Pasta").subtitle == "Cook log")

        let imageDraft = try CaptureDraft.cameraImage(
            id: "draft_no_preview",
            assetIdentifier: "asset_private_camera",
            recognizedText: nil,
            createdAt: "2026-06-27T15:03:00.000Z"
        )
        let imageDraftPayload = NativeSharePayload.privateCaptureDraft(imageDraft)
        #expect(imageDraftPayload.title == "Capture Draft")
        #expect(imageDraftPayload.subtitle == "camera-image")
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
        #expect(catalog.publicURLRouteTemplates == [
            "https://spoonjoy.app/recipes/{id}",
            "https://spoonjoy.app/cookbooks/{id}"
        ])
        #expect(Set(catalog.publicURLRouteTemplates).isSubset(of: Set(DeepLinkManifest.routes)))
        #expect(!catalog.publicURLRouteTemplates.contains("https://spoonjoy.app/recipes/{id}/edit"))
        #expect(!catalog.publicURLRouteTemplates.contains("https://spoonjoy.app/recipes/{id}#cook"))
        #expect(!catalog.publicURLRouteTemplates.contains("https://spoonjoy.app/shopping-list"))
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

    private func assertNoSensitiveShareFragments(_ payload: NativeSharePayload) {
        let combined = [
            payload.title,
            payload.subtitle,
            payload.serializedTransferValue
        ].joined(separator: "\n")
        let forbiddenFragments = [
            "https://recipes.example/import",
            "https://captures.example/raw",
            "https://json.example/schema",
            "http://plain.example/recipe",
            "https://text.example/recipe",
            "token=",
            "access_token",
            "signature=",
            "sig=",
            "key=",
            "secret-token",
            "signed-secret",
            "/Users/",
            "/private/",
            "file://",
            "Media/DCIM",
            "private-card.jpg",
            "secret-card.jpg"
        ]

        for fragment in forbiddenFragments {
            #expect(!combined.contains(fragment), "private transfer leaked \(fragment)")
        }
    }
}
