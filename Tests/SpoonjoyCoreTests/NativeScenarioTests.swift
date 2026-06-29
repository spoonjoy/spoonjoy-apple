import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native scenario metadata")
struct NativeScenarioTests {
    private let expectedAppIntents = [
        "OpenRecipeIntent",
        "OpenCookbookIntent",
        "OpenProfileIntent",
        "SearchSpoonjoyIntent",
        "ShareRecipeIntent",
        "ShareCookbookIntent",
        "ShareShoppingListIntent",
        "StartCookModeIntent",
        "ContinueCookModeIntent",
        "ForkRecipeIntent",
        "SaveRecipeToCookbookIntent",
        "RemoveRecipeFromCookbookIntent",
        "DeleteRecipeIntent",
        "AddShoppingListItemIntent",
        "SetShoppingListItemCheckedIntent",
        "RemoveShoppingListItemIntent",
        "AddRecipeIngredientsToShoppingListIntent",
        "ClearCompletedShoppingItemsIntent",
        "ClearShoppingListIntent",
        "SpoonjoyRecipeEntity",
        "SpoonjoyCookbookEntity",
        "SpoonjoyRecipeEntityQuery",
        "SpoonjoyCookbookEntityQuery"
    ]
    private let expectedSpotlightIndexedTypes = ["recipe", "cookbook", "shopping-list-item"]
    private let expectedSearchableScopes = ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
    private let expectedShareActions = [
        "capture-recipe-url",
        "capture-recipe-text",
        "capture-recipe-camera",
        "capture-recipe-photo-library",
        "capture-recipe-json-ld",
        "capture-recipe-video-url",
        "recipe-import-submit",
        "share-recipe",
        "share-cookbook",
        "native-shopping-list-transfer"
    ]
    private let expectedOfflineFlows = [
        "fixture-offline-restore",
        "shopping-queue-replay",
        "cook-mode-progress-restore",
        "capture-draft-offline",
        "capture-import-offline-retry",
        "provider-secret-blocked-import"
    ]
    private let expectedAssociatedDomains = ["applinks:spoonjoy.app"]
    private let expectedURLSchemes = ["spoonjoy"]
    private let expectedDeepLinkRoutes = [
        "https://spoonjoy.app/",
        "https://spoonjoy.app/recipes",
        "https://spoonjoy.app/recipes/{id}",
        "https://spoonjoy.app/recipes/{id}/edit",
        "https://spoonjoy.app/recipes/{id}#cook",
        "https://spoonjoy.app/recipes/{id}?mode=cook",
        "https://spoonjoy.app/cookbooks",
        "https://spoonjoy.app/cookbooks/{id}",
        "https://spoonjoy.app/users/{identifier}",
        "https://spoonjoy.app/users/{identifier}/fellow-chefs?page={page}",
        "https://spoonjoy.app/users/{identifier}/kitchen-visitors?page={page}",
        "https://spoonjoy.app/shopping-list",
        "https://spoonjoy.app/search",
        "https://spoonjoy.app/search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "https://spoonjoy.app/recipes/new",
        "https://spoonjoy.app/account/settings",
        "spoonjoy://kitchen",
        "spoonjoy://recipes",
        "spoonjoy://recipes/{id}",
        "spoonjoy://recipes/{id}/edit",
        "spoonjoy://recipes/{id}/covers",
        "spoonjoy://recipes/{id}/cook",
        "spoonjoy://recipes/new/edit",
        "spoonjoy://cookbooks",
        "spoonjoy://cookbooks/{id}",
        "spoonjoy://users/{identifier}",
        "spoonjoy://users/{identifier}/fellow-chefs?page={page}",
        "spoonjoy://users/{identifier}/kitchen-visitors?page={page}",
        "spoonjoy://shopping-list",
        "spoonjoy://search",
        "spoonjoy://search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "spoonjoy://capture",
        "spoonjoy://settings"
    ]

    @Test("native metadata report exposes Apple-native capabilities")
    func nativeMetadataReportExposesAppleNativeCapabilities() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)
        let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

        #expect(report.ok)
        #expect(report.stage == .nativeMetadata)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["app surfaces"])
        #expect(checksByName["fixture bundle"] == .pass)
        #expect(checksByName["native metadata"] == .pass)
        #expect(checksByName["app intents source"] == .pass)
        #expect(checksByName["spotlight source"] == .pass)
        #expect(checksByName["deep link metadata"] == .pass)
        #expect(report.checks.first { $0.name == "app surfaces" }?.detail.contains("Units 14-16") == true)
        #expect(Set(report.nativeCapabilities.appIntents).isSuperset(of: Set(expectedAppIntents)))
        #expect(report.nativeCapabilities.appIntents.contains("SpoonjoyRecipeEntity"))
        #expect(Set(report.nativeCapabilities.spotlightIndexedTypes).isSuperset(of: Set(expectedSpotlightIndexedTypes)))
        #expect(Set(report.nativeCapabilities.searchableScopes) == Set(expectedSearchableScopes))
        #expect(Set(report.nativeCapabilities.shareActions) == Set(expectedShareActions))
        #expect(Set(report.nativeCapabilities.offlineFlows) == Set(expectedOfflineFlows))
        #expect(report.nativeCapabilities.associatedDomains == expectedAssociatedDomains)
        #expect(report.nativeCapabilities.urlSchemes == expectedURLSchemes)
        #expect(Set(report.nativeCapabilities.deepLinkRoutes) == Set(expectedDeepLinkRoutes))
        #expect(report.nativeCapabilities.deepLinkRoutes.count == expectedDeepLinkRoutes.count)
    }

    @Test("native metadata report encoding is deterministic")
    func nativeMetadataReportEncodingIsDeterministic() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)
        let first = try #require(String(data: try ScenarioCommand.reportData(report), encoding: .utf8))
        let second = try #require(String(data: try ScenarioCommand.reportData(report), encoding: .utf8))

        #expect(first == second)
        #expect(first.contains(#""stage" : "native-metadata""#))
        #expect(first.contains(#""applinks:spoonjoy.app""#))
        #expect(first.contains(#""https:\/\/spoonjoy.app\/shopping-list""#))
        #expect(first.contains(#""spoonjoy:\/\/shopping-list""#))
        #expect(first.contains(#""all""#))
        #expect(first.contains(#""shopping-list""#))
    }

    @Test("native intent actions resolve routes local mutations and capture drafts")
    func nativeIntentActionsResolveRoutesLocalMutationsAndCaptureDrafts() throws {
        let resolver = NativeIntentActionResolver()
        let openRecipe = try resolver.openRecipe(recipeID: " recipe_lemon_pantry_pasta ")
        let cookMode = try resolver.startCookMode(recipeID: "recipe_lemon_pantry_pasta")
        let shoppingAction = try resolver.addShoppingListItem(
            name: " Preserved Lemons ",
            quantity: 2,
            unit: " jar ",
            createdAt: "2026-06-16T14:00:00.000Z"
        )
        let captureAction = try resolver.captureRecipe(
            source: " https://example.com/lemon-pasta\nAdd parsley. ",
            createdAt: "2026-06-16T14:02:00.000Z"
        )
        let pantryAction = try resolver.addShoppingListItem(
            name: " Flaky Salt ",
            quantity: nil,
            unit: "   ",
            createdAt: "2026-06-16T14:04:00.000Z"
        )
        let checkAction = try resolver.setShoppingListItemChecked(
            itemID: " item_lemons ",
            checked: true,
            createdAt: "2026-06-16T14:05:00.000Z"
        )
        let uncheckAction = try resolver.setShoppingListItemChecked(
            itemID: "item_lemons",
            checked: false,
            createdAt: "2026-06-16T14:06:00.000Z"
        )
        let addRecipeAction = try resolver.addRecipeIngredientsToShoppingList(
            recipeID: " recipe_lemon_pantry_pasta ",
            scaleFactor: 2,
            createdAt: "2026-06-16T14:07:00.000Z"
        )
        let clearCompletedAction = resolver.clearCompletedShoppingItems(createdAt: "2026-06-16T14:08:00.000Z")
        let clearAllAction = resolver.clearShoppingList(createdAt: "2026-06-16T14:09:00.000Z")
        let shoppingMutation = try #require(shoppingAction.queuedMutation)
        let nativeShoppingMutation = try #require(shoppingAction.nativeQueuedMutation)
        let checkMutation = try #require(checkAction.nativeQueuedMutation)
        let uncheckMutation = try #require(uncheckAction.nativeQueuedMutation)
        let addRecipeMutation = try #require(addRecipeAction.nativeQueuedMutation)
        let clearCompletedMutation = try #require(clearCompletedAction.nativeQueuedMutation)
        let clearAllMutation = try #require(clearAllAction.nativeQueuedMutation)
        let captureDraft = try #require(captureAction.captureDraft)
        let pantryMutation = try #require(pantryAction.queuedMutation)

        #expect(openRecipe.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(openRecipe.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(openRecipe.queuedMutation == nil)
        #expect(openRecipe.nativeQueuedMutation == nil)
        #expect(openRecipe.captureDraft == nil)
        #expect(cookMode.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook))
        #expect(cookMode.url == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta/cook"))
        #expect(cookMode.nativeQueuedMutation == nil)
        #expect(cookMode.captureDraft == nil)
        #expect(shoppingMutation.id == "intent-shopping-add-preserved-lemons-2026-06-16T14-00-00-000Z")
        #expect(shoppingMutation.clientMutationID == "intent-shopping-add-preserved-lemons-2026-06-16T14-00-00-000Z")
        #expect(shoppingMutation.createdAt == "2026-06-16T14:00:00.000Z")
        #expect(
            shoppingMutation.kind == .shoppingAdd(
                name: "preserved lemons",
                quantity: 2,
                unit: "jar",
                categoryKey: nil,
                iconKey: nil
            )
        )
        #expect(shoppingAction.route == .shoppingList)
        #expect(shoppingAction.url == URL(string: "spoonjoy://shopping-list"))
        #expect(shoppingAction.captureDraft == nil)
        #expect(nativeShoppingMutation.queueableKind == .shoppingAddItem)
        #expect(
            pantryMutation.kind == .shoppingAdd(
                name: "flaky salt",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil
            )
        )
        #expect(checkAction.route == .shoppingList)
        #expect(checkAction.url == URL(string: "spoonjoy://shopping-list"))
        #expect(checkAction.queuedMutation == nil)
        #expect(checkMutation.queueableKind == .shoppingCheckItem)
        #expect(checkMutation.clientMutationID == "intent-shopping-check-item_lemons-checked-2026-06-16T14-05-00-000Z")
        #expect(uncheckMutation.queueableKind == .shoppingCheckItem)
        #expect(uncheckMutation.clientMutationID == "intent-shopping-check-item_lemons-unchecked-2026-06-16T14-06-00-000Z")
        #expect(addRecipeAction.route == .shoppingList)
        #expect(addRecipeAction.url == URL(string: "spoonjoy://shopping-list"))
        #expect(addRecipeMutation.queueableKind == .shoppingAddFromRecipe)
        #expect(addRecipeMutation.clientMutationID == "intent-shopping-recipe-recipe_lemon_pantry_pasta-2026-06-16T14-07-00-000Z")
        #expect(clearCompletedMutation.queueableKind == .shoppingClearCompleted)
        #expect(clearCompletedMutation.clientMutationID == "intent-shopping-clear-completed-2026-06-16T14-08-00-000Z")
        #expect(clearAllMutation.queueableKind == .shoppingClearAll)
        #expect(clearAllMutation.clientMutationID == "intent-shopping-clear-all-2026-06-16T14-09-00-000Z")
        #expect(captureDraft.id == "intent-capture-2026-06-16T14-02-00-000Z")
        #expect(captureDraft.previewLines == ["https://example.com/lemon-pasta", "Add parsley."])
        #expect(captureDraft.status == .localOnly)
        #expect(captureAction.route == .capture)
        #expect(captureAction.url == URL(string: "spoonjoy://capture"))
        #expect(captureAction.queuedMutation == nil)
        #expect(captureAction.nativeQueuedMutation == nil)

        #expect(throws: NativeIntentActionError.self) {
            try resolver.openRecipe(recipeID: "../secret")
        }
        #expect(throws: NativeIntentActionError.self) {
            try resolver.addShoppingListItem(
                name: "   ",
                quantity: nil,
                unit: nil,
                createdAt: "2026-06-16T14:01:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.self) {
            try resolver.captureRecipe(source: "  ", createdAt: "2026-06-16T14:03:00.000Z")
        }
        #expect(throws: NativeIntentActionError.self) {
            try resolver.setShoppingListItemChecked(
                itemID: "../item",
                checked: true,
                createdAt: "2026-06-16T14:10:00.000Z"
            )
        }
        #expect(throws: NativeIntentActionError.self) {
            try resolver.addRecipeIngredientsToShoppingList(
                recipeID: "recipe_lemon_pantry_pasta",
                scaleFactor: 0,
                createdAt: "2026-06-16T14:11:00.000Z"
            )
        }
        #expect(NativeIntentActionError.authRequired.description == "Sign in to Spoonjoy before queueing this Siri action.")
        #expect(NativeIntentActionError.unresolvedRecipeEntity.description == "Choose a Spoonjoy recipe before running this Siri action.")
    }

    @Test("spotlight index plan builds route aware searchable documents")
    func spotlightIndexPlanBuildsRouteAwareSearchableDocuments() throws {
        let recipes = try RecipeFixtureCatalog.decodeFromBundle().recipes
        let cookbooks = try CookbookFixtureCatalog.decodeFromBundle().cookbooks
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let scope = SpotlightIndexScope(accountID: "chef_ari", environment: .production)
        let documents = SpotlightIndexPlan.documents(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList,
            scope: scope
        )
        let recipe = try #require(documents.first { $0.uniqueIdentifier == "production|chef_ari|recipe|recipe_lemon_pantry_pasta" })
        let cookbook = try #require(documents.first { $0.uniqueIdentifier == "production|chef_ari|cookbook|cookbook_weeknights" })
        let shoppingItem = try #require(documents.first { $0.uniqueIdentifier == "production|chef_ari|shopping-list-item|item_lemons" })

        #expect(documents.count == recipes.count + cookbooks.count + shoppingList.activeItems.count)
        #expect(recipe.type == .recipe)
        #expect(recipe.domainIdentifier == "app.spoonjoy.production.chef_ari.recipe")
        #expect(recipe.title == "Lemon Pantry Pasta")
        #expect(recipe.contentDescription.contains("ari"))
        #expect(recipe.keywords.contains("Spoonjoy"))
        #expect(recipe.keywords.contains("recipe"))
        #expect(recipe.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: recipe.uniqueIdentifier) == recipe.route)
        #expect(DeepLinkURLBuilder.url(for: recipe.route) == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(cookbook.type == .cookbook)
        #expect(cookbook.domainIdentifier == "app.spoonjoy.production.chef_ari.cookbook")
        #expect(cookbook.contentDescription.contains("2 recipes"))
        #expect(cookbook.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: cookbook.uniqueIdentifier) == cookbook.route)
        #expect(DeepLinkURLBuilder.url(for: cookbook.route) == URL(string: "spoonjoy://cookbooks/cookbook_weeknights"))
        #expect(shoppingItem.type == .shoppingListItem)
        #expect(shoppingItem.domainIdentifier == "app.spoonjoy.production.chef_ari.shopping-list-item")
        #expect(shoppingItem.title == "lemons")
        #expect(shoppingItem.contentDescription.contains("Shopping list"))
        #expect(shoppingItem.route == .shoppingList)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: shoppingItem.uniqueIdentifier) == .shoppingList)
        #expect(DeepLinkURLBuilder.url(for: shoppingItem.route) == URL(string: "spoonjoy://shopping-list"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "recipe:recipe_lemon_pantry_pasta") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "recipe:../secret") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "cookbook:../secret") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|chef_ari|shopping-list-item|../secret") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "unknown:item") == .unknownLink)
    }

    @Test("spotlight index plan covers fallback copy singular counts and uncategorized items")
    func spotlightIndexPlanCoversFallbackCopySingularCountsAndUncategorizedItems() throws {
        let chef = ChefSummary(id: "chef_ari", username: "ari")
        let attribution = RecipeAttribution(
            creditText: "ari",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_spotlight_fallback")),
            sourceURLRaw: nil,
            sourceHost: nil,
            sourceRecipe: nil
        )
        let servingRecipe = Recipe(
            id: "recipe_spotlight_servings",
            title: "Servings Recipe",
            description: nil,
            servings: "1 bowl",
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/recipe_spotlight_servings",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_spotlight_servings")),
            attribution: attribution,
            createdAt: "2026-06-16T14:05:00.000Z",
            updatedAt: "2026-06-16T14:05:00.000Z",
            steps: [
                RecipeStep(
                    id: "step_spotlight_servings",
                    stepNum: 1,
                    stepTitle: nil,
                    description: "Serve.",
                    duration: nil,
                    ingredients: []
                )
            ],
            cookbooks: []
        )
        let readyRecipe = Recipe(
            id: "recipe_spotlight_ready",
            title: "Ready Recipe",
            description: nil,
            servings: nil,
            chef: chef,
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/recipe_spotlight_ready",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_spotlight_ready")),
            attribution: attribution,
            createdAt: "2026-06-16T14:06:00.000Z",
            updatedAt: "2026-06-16T14:06:00.000Z",
            steps: [
                RecipeStep(
                    id: "step_spotlight_ready",
                    stepNum: 1,
                    stepTitle: nil,
                    description: "Cook.",
                    duration: nil,
                    ingredients: []
                )
            ],
            cookbooks: []
        )
        let cookbook = Cookbook(
            id: "cookbook_spotlight_one",
            title: "One Recipe",
            chef: chef,
            recipeCount: 1,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/cookbook_spotlight_one",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_spotlight_one")),
            attribution: CookbookAttribution(
                creditText: "ari",
                canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_spotlight_one"))
            ),
            createdAt: "2026-06-16T14:07:00.000Z",
            updatedAt: "2026-06-16T14:07:00.000Z",
            recipes: [RecipeSummary(recipe: servingRecipe)]
        )
        let shoppingItem = ShoppingListItem(
            id: "item_uncategorized",
            name: "salt",
            quantity: nil,
            unit: nil,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: "2026-06-16T14:08:00.000Z"
        )

        let scope = SpotlightIndexScope(accountID: "chef fallback@example.com", environment: .local)
        let servingsDocument = SpotlightIndexPlan.document(recipe: servingRecipe, scope: scope)
        let readyDocument = SpotlightIndexPlan.document(recipe: readyRecipe, scope: scope)
        let cookbookDocument = SpotlightIndexPlan.document(cookbook: cookbook, scope: scope)
        let shoppingDocument = SpotlightIndexPlan.document(shoppingListItem: shoppingItem, scope: scope)

        #expect(servingsDocument.contentDescription.contains("1 bowl"))
        #expect(servingsDocument.uniqueIdentifier == "local|chef-fallback-example-com|recipe|recipe_spotlight_servings")
        #expect(servingsDocument.domainIdentifier == "app.spoonjoy.local.chef-fallback-example-com.recipe")
        #expect(readyDocument.contentDescription.contains("Ready to cook in Spoonjoy."))
        #expect(cookbookDocument.contentDescription.contains("1 recipe"))
        #expect(shoppingDocument.keywords.contains("shopping"))
    }

    @Test("shell content exposes spotlight scope only for bound signed in accounts")
    func shellContentExposesSpotlightScopeOnlyForBoundSignedInAccounts() throws {
        let signedOut = NativeShellContentState.empty(
            authSessionState: .signedOut,
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        let session = try AuthSession(
            clientID: "client_spotlight_scope",
            accessToken: "sj_access_spotlight_scope",
            refreshToken: "sj_refresh_spotlight_scope",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
        let signedIn = NativeShellContentState.empty(
            authSessionState: .authenticated(session),
            environment: .production,
            configuration: .spoonjoyProduction,
            offlineIndicatorState: OfflineIndicatorState(display: .synced, dismissal: nil)
        )
        let scope = try #require(signedIn.spotlightIndexScope)

        #expect(signedOut.spotlightIndexScope == nil)
        #expect(scope.identifierPrefix == "production|chef_ari")
        #expect(scope.domainPrefix == "app.spoonjoy.production.chef_ari")
    }

    @Test("surfaces report proves kitchen recipe cook and shopping slices")
    func surfacesReportProvesKitchenRecipeCookAndShoppingSlices() throws {
        let report = try ScenarioReporter.report(for: .surfaces)
        let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

        #expect(report.ok)
        #expect(report.stage == .surfaces)
        #expect(checksByName["fixture kitchen browsing"] == .pass)
        #expect(checksByName["recipe detail"] == .pass)
        #expect(checksByName["cook progress persistence"] == .pass)
        #expect(checksByName["shopping checkoff"] == .pass)
        #expect(checksByName["kitchen surface source"] == .pass)
        #expect(checksByName["recipe detail surface source"] == .pass)
        #expect(checksByName["cook mode surface source"] == .pass)
        #expect(checksByName["shopping surface source"] == .pass)
        #expect(checksByName["receipt controls source"] == .pass)
        #expect(checksByName["kitchen safe controls source"] == .pass)
        #expect(checksByName["navigation surface source"] == .pass)
        #expect(checksByName["search surface source"] == .pass)
        #expect(checksByName["capture surface source"] == .pass)
        #expect(checksByName["settings surface source"] == .pass)
        #expect(checksByName["offline status source"] == .pass)
        #expect(checksByName["navigation final surface source"] == .pass)
        #expect(report.checks.filter { $0.status == .pending }.isEmpty)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(Set(report.nativeCapabilities.deepLinkRoutes) == Set(expectedDeepLinkRoutes))
    }

    @Test("final report proves search capture settings and deep link safety")
    func finalReportProvesSearchCaptureSettingsAndDeepLinkSafety() throws {
        let report = try ScenarioReporter.report(for: .final)
        let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

        #expect(report.ok)
        #expect(report.stage == .final)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(report.checks.filter { $0.status == .pending }.isEmpty)
        #expect(checksByName["fixture kitchen browsing"] == .pass)
        #expect(checksByName["first-run session setup"] == .pass)
        #expect(checksByName["recipe detail"] == .pass)
        #expect(checksByName["cook progress persistence"] == .pass)
        #expect(checksByName["durable native state"] == .pass)
        #expect(checksByName["shopping checkoff"] == .pass)
        #expect(checksByName["search"] == .pass)
        #expect(checksByName["capture import submission"] == .pass)
        #expect(checksByName["settings state"] == .pass)
        #expect(checksByName["offline status"] == .pass)
        #expect(checksByName["safe unknown link"] == .pass)
        #expect(checksByName["first-run setup source"] == .pass)
        #expect(checksByName["native persistence source"] == .pass)
        #expect(checksByName["search surface source"] == .pass)
        #expect(checksByName["capture surface source"] == .pass)
        #expect(checksByName["settings surface source"] == .pass)
        #expect(checksByName["offline status source"] == .pass)
        #expect(Set(report.nativeCapabilities.deepLinkRoutes) == Set(expectedDeepLinkRoutes))
    }

    @Test("surfaces report fails when surface sources are missing")
    func surfacesReportFailsWhenSurfaceSourcesAreMissing() throws {
        try withTemporaryDirectory { directory in
            let report = ScenarioVerifier.surfacesReport(rootURL: directory)
            let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

            #expect(!report.ok)
            #expect(checksByName["kitchen surface source"] == .fail)
            #expect(checksByName["recipe detail surface source"] == .fail)
            #expect(checksByName["cook mode surface source"] == .fail)
            #expect(checksByName["shopping surface source"] == .fail)
            #expect(checksByName["receipt controls source"] == .fail)
            #expect(checksByName["kitchen safe controls source"] == .fail)
            #expect(checksByName["navigation surface source"] == .fail)
        }
    }

    @Test("surface behavioral checks fail closed for missing or throwing fixture data")
    func surfaceBehavioralChecksFailClosedForMissingOrThrowingFixtureData() throws {
        let defaultRecipeCheck = ScenarioVerifier.cookProgressPersistenceCheck()
        let defaultShoppingCheck = ScenarioVerifier.shoppingCheckoffCheck()
        let staleShoppingCheck = ScenarioVerifier.shoppingCheckoffCheck(selectedItemID: "item_missing")
        let throwingShoppingAddCheck = ScenarioVerifier.shoppingAddItemCheck(loadShoppingList: {
            throw FixtureLoadError.unavailable
        })
        let malformedShoppingRecipeCheck = ScenarioVerifier.shoppingAddRecipeIngredientsCheck(planBuilder: { _, _, _, _ in
            throw FixtureLoadError.unavailable
        })
        let throwingShoppingClearCheck = ScenarioVerifier.shoppingClearConfirmationCheck(loadShoppingList: {
            throw FixtureLoadError.unavailable
        })
        let throwingCaptureImportCheck = ScenarioVerifier.captureDraftCreationCheck(makeDraft: {
            throw FixtureLoadError.unavailable
        })
        let missingRecipeCheck = ScenarioVerifier.cookProgressPersistenceCheck(loadRecipes: { [] })
        let throwingRecipeCheck = ScenarioVerifier.cookProgressPersistenceCheck(loadRecipes: {
            throw FixtureLoadError.unavailable
        })
        let emptyShoppingList = ShoppingListState(
            id: "shopping-empty",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [
                ShoppingListItem(
                    id: "item_deleted",
                    name: "deleted basil",
                    quantity: nil,
                    unit: nil,
                    checked: false,
                    checkedAt: nil,
                    deletedAt: "2026-06-16T11:45:00.000Z",
                    categoryKey: nil,
                    iconKey: nil,
                    sortIndex: 0,
                    updatedAt: "2026-06-16T11:45:00.000Z"
                )
            ],
            nextCursor: "cursor-empty",
            updatedAt: "2026-06-16T11:45:00.000Z"
        )
        let missingShoppingCheck = ScenarioVerifier.shoppingCheckoffCheck(loadShoppingList: { emptyShoppingList })
        let throwingShoppingCheck = ScenarioVerifier.shoppingCheckoffCheck(loadShoppingList: {
            throw FixtureLoadError.unavailable
        })
        let throwingCookbookDetailCheck = ScenarioVerifier.cookbookDetailCheck(loadCookbook: {
            throw FixtureLoadError.unavailable
        })
        let missingCookbookDetailCheck = ScenarioVerifier.cookbookDetailCheck(loadCookbook: {
            try ScenarioVerifier.scenarioCookbook(from: [])
        })
        let throwingCookbookOwnerToolsCheck = ScenarioVerifier.cookbookOwnerToolsCheck(loadCookbook: {
            throw FixtureLoadError.unavailable
        })
        let throwingCookbookCreateCheck = ScenarioVerifier.cookbookCreateCheck(rootURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath), planBuilder: {
            throw FixtureLoadError.unavailable
        })
        let throwingCookbookRenameCheck = ScenarioVerifier.cookbookRenameCheck(viewModel: {
            throw FixtureLoadError.unavailable
        })
        let throwingCookbookDeleteCheck = ScenarioVerifier.cookbookDeleteCheck(viewModel: {
            throw FixtureLoadError.unavailable
        })
        let throwingCookbookAddRecipeCheck = ScenarioVerifier.cookbookAddRecipeCheck(viewModel: { _ in
            throw FixtureLoadError.unavailable
        })
        let throwingSettingsProfileCheck = ScenarioVerifier.settingsProfileUpdateCheck(planBuilder: { _ in
            throw FixtureLoadError.unavailable
        })
        let throwingSettingsTokenCheck = ScenarioVerifier.settingsTokenCreateOnlineOnlyCheck(planBuilder: { _ in
            throw FixtureLoadError.unavailable
        })
        let throwingSettingsConnectionCheck = ScenarioVerifier.settingsConnectionDisconnectOnlineOnlyCheck(planBuilder: { _ in
            throw FixtureLoadError.unavailable
        })
        let throwingSettingsHandoffCheck = ScenarioVerifier.settingsSecureHandoffCheck(planBuilder: { _ in
            throw FixtureLoadError.unavailable
        })
        let weakSettingsProfileCheck = ScenarioVerifier.settingsProfileUpdateCheck(planBuilder: { _ in
            SettingsActionPlan()
        })
        let weakSettingsTokenCheck = ScenarioVerifier.settingsTokenCreateOnlineOnlyCheck(planBuilder: { _ in
            SettingsActionPlan()
        })
        let weakSettingsConnectionCheck = ScenarioVerifier.settingsConnectionDisconnectOnlineOnlyCheck(planBuilder: { _ in
            SettingsActionPlan()
        })
        let weakSettingsHandoffCheck = ScenarioVerifier.settingsSecureHandoffCheck(planBuilder: { _ in
            (nil, nil)
        })
        let baseCookbook = try #require(CookbookFixtureCatalog.decodeFromBundle().cookbooks.first)
        let emptyCookbook = Cookbook(
            id: baseCookbook.id,
            title: baseCookbook.title,
            chef: baseCookbook.chef,
            recipeCount: 0,
            cover: baseCookbook.cover,
            href: baseCookbook.href,
            canonicalURL: baseCookbook.canonicalURL,
            attribution: baseCookbook.attribution,
            createdAt: baseCookbook.createdAt,
            updatedAt: baseCookbook.updatedAt,
            recipes: []
        )
        let emptyCookbookRemoveCheck = ScenarioVerifier.cookbookRemoveRecipeCheck(loadCookbook: { emptyCookbook })
        let throwingCookbookRemoveCheck = ScenarioVerifier.cookbookRemoveRecipeCheck(loadCookbook: {
            throw FixtureLoadError.unavailable
        })

        #expect(defaultRecipeCheck.status == .pass)
        #expect(defaultShoppingCheck.status == .pass)
        #expect(staleShoppingCheck.status == .fail)
        #expect(staleShoppingCheck.detail.contains("Shopping checkoff failed"))
        #expect(throwingShoppingAddCheck.status == .fail)
        #expect(throwingShoppingAddCheck.detail.contains("Shopping add item failed"))
        #expect(malformedShoppingRecipeCheck.status == .fail)
        #expect(malformedShoppingRecipeCheck.detail.contains("Shopping add recipe ingredients failed"))
        #expect(throwingShoppingClearCheck.status == .fail)
        #expect(throwingShoppingClearCheck.detail.contains("Shopping clear confirmation failed"))
        #expect(throwingCaptureImportCheck.status == .fail)
        #expect(throwingCaptureImportCheck.detail.contains("Capture import scenario failed"))
        #expect(missingRecipeCheck.status == .fail)
        #expect(missingRecipeCheck.detail.contains("no cookable steps"))
        #expect(throwingRecipeCheck.status == .fail)
        #expect(throwingRecipeCheck.detail.contains("failed"))
        #expect(missingShoppingCheck.status == .fail)
        #expect(missingShoppingCheck.detail.contains("no active checkoff items"))
        #expect(throwingShoppingCheck.status == .fail)
        #expect(throwingShoppingCheck.detail.contains("failed"))
        #expect(throwingCookbookDetailCheck.status == .fail)
        #expect(throwingCookbookDetailCheck.detail.contains("Cookbook detail failed"))
        #expect(missingCookbookDetailCheck.status == .fail)
        #expect(missingCookbookDetailCheck.detail.contains("Cookbook detail failed"))
        #expect(throwingCookbookOwnerToolsCheck.status == .fail)
        #expect(throwingCookbookOwnerToolsCheck.detail.contains("Cookbook owner tools failed"))
        #expect(throwingCookbookCreateCheck.status == .fail)
        #expect(throwingCookbookCreateCheck.detail.contains("Cookbook create failed"))
        #expect(throwingCookbookRenameCheck.status == .fail)
        #expect(throwingCookbookRenameCheck.detail.contains("Cookbook rename failed"))
        #expect(throwingCookbookDeleteCheck.status == .fail)
        #expect(throwingCookbookDeleteCheck.detail.contains("Cookbook delete failed"))
        #expect(throwingCookbookAddRecipeCheck.status == .fail)
        #expect(throwingCookbookAddRecipeCheck.detail.contains("Cookbook add recipe failed"))
        #expect(throwingSettingsProfileCheck.status == .fail)
        #expect(throwingSettingsProfileCheck.detail.contains("Settings profile update failed"))
        #expect(throwingSettingsTokenCheck.status == .fail)
        #expect(throwingSettingsTokenCheck.detail.contains("Settings token create failed"))
        #expect(throwingSettingsConnectionCheck.status == .fail)
        #expect(throwingSettingsConnectionCheck.detail.contains("Settings connection disconnect failed"))
        #expect(throwingSettingsHandoffCheck.status == .fail)
        #expect(throwingSettingsHandoffCheck.detail.contains("Settings secure handoff failed"))
        #expect(weakSettingsProfileCheck.status == .fail)
        #expect(weakSettingsTokenCheck.status == .fail)
        #expect(weakSettingsConnectionCheck.status == .fail)
        #expect(weakSettingsHandoffCheck.status == .fail)
        #expect(emptyCookbookRemoveCheck.status == .fail)
        #expect(emptyCookbookRemoveCheck.detail.contains("no removable recipe"))
        #expect(throwingCookbookRemoveCheck.status == .fail)
        #expect(throwingCookbookRemoveCheck.detail.contains("Cookbook remove recipe failed"))
    }

    @Test("final behavioral checks fail closed for weak settings offline and link safety")
    func finalBehavioralChecksFailClosedForWeakSettingsOfflineAndLinkSafety() throws {
        try withTemporaryDirectory { directory in
            let weakSettings = SettingsState(
                auth: .signedOut,
                environment: .local(baseURL: URL(fileURLWithPath: "/tmp/spoonjoy-local")),
                offline: .unavailable,
                preferredCookModeTextSize: .standard
            )
            let weakOffline = ScenarioVerifier.offlineStatusCheck(
                available: .available(snapshotCount: 1, lastRestoredAt: nil),
                unavailable: .unavailable
            )
            let unsafeLink = ScenarioVerifier.safeUnknownLinkCheck(routes: [.kitchen, .unknownLink])
            let missingFirstRunSource = ScenarioVerifier.firstRunSessionSetupCheck(rootURL: directory)
            let missingDurableInputs = ScenarioVerifier.durableNativeStateCheck(
                loadShoppingList: { try ShoppingListState.decodeFromBundle() },
                loadRecipes: { [] }
            )
            let throwingDurableInputs = ScenarioVerifier.durableNativeStateCheck(
                loadShoppingList: { throw FixtureLoadError.unavailable },
                loadRecipes: { throw FixtureLoadError.unavailable }
            )

            #expect(ScenarioVerifier.settingsStateCheck(settings: weakSettings).status == .fail)
            #expect(weakOffline.status == .fail)
            #expect(unsafeLink.status == .fail)
            #expect(missingFirstRunSource.status == .fail)
            #expect(missingDurableInputs.status == .fail)
            #expect(missingDurableInputs.detail.contains("missing durable-state inputs"))
            #expect(throwingDurableInputs.status == .fail)
            #expect(throwingDurableInputs.detail.contains("Durable native state failed"))
        }
    }

    @Test("scenario command parses surfaces stage")
    func scenarioCommandParsesSurfacesStage() throws {
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "surfaces",
            "--output", "/tmp/spoonjoy-surfaces.json"
        ])

        #expect(command == ScenarioCommand(stage: .surfaces, outputPath: "/tmp/spoonjoy-surfaces.json"))
    }

    @Test("native metadata command parses stage and output path")
    func nativeMetadataCommandParsesStageAndOutputPath() throws {
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "native-metadata",
            "--output", "/tmp/spoonjoy-native-metadata.json"
        ])

        #expect(command == ScenarioCommand(stage: .nativeMetadata, outputPath: "/tmp/spoonjoy-native-metadata.json"))
    }

    @Test("scenario command writes output and supports stdout mode")
    func scenarioCommandWritesOutputAndSupportsStdoutMode() throws {
        try withTemporaryDirectory { directory in
            let outputURL = directory.appendingPathComponent("native-metadata.json")
            let outputReport = try ScenarioCommand.run(arguments: [
                "--stage", "native-metadata",
                "--output", outputURL.path
            ])
            let outputData = try Data(contentsOf: outputURL)
            let decodedReport = try JSONDecoder().decode(ScenarioReport.self, from: outputData)
            let stdoutReport = try ScenarioCommand.run(arguments: ["--stage", "bootstrap"])

            #expect(outputReport.stage == .nativeMetadata)
            #expect(decodedReport == outputReport)
            #expect(stdoutReport == ScenarioReporter.bootstrapReport())
        }
    }

    @Test("scenario verifier covers root override and failing native metadata checks")
    func scenarioVerifierCoversRootOverrideAndFailingNativeMetadataChecks() throws {
        try withTemporaryDirectory { directory in
            let fallbackRoot = ScenarioVerifier.defaultRootURL(
                environment: [:],
                currentDirectoryPath: repoURL.path
            )
            let overrideRoot = ScenarioVerifier.defaultRootURL(
                environment: ["SPOONJOY_SCENARIO_ROOT": "  \(directory.path)  "],
                currentDirectoryPath: repoURL.path
            )
            let missingSourceReport = ScenarioVerifier.nativeMetadataReport(rootURL: directory)
            let missingSourceChecks = Dictionary(uniqueKeysWithValues: missingSourceReport.checks.map { ($0.name, $0.status) })
            let emptyMetadata = NativeCapabilityMetadata(
                appIntents: [],
                spotlightIndexedTypes: [],
                searchableScopes: [],
                shareActions: [],
                offlineFlows: [],
                associatedDomains: [],
                urlSchemes: [],
                deepLinkRoutes: []
            )
            let emptyMetadataReport = ScenarioVerifier.nativeMetadataReport(rootURL: repoURL, metadata: emptyMetadata)
            let emptyMetadataChecks = Dictionary(uniqueKeysWithValues: emptyMetadataReport.checks.map { ($0.name, $0.status) })

            #expect(fallbackRoot.path == repoURL.path)
            #expect(overrideRoot.path == directory.path)
            #expect(!missingSourceReport.ok)
            #expect(missingSourceChecks["app intents source"] == .fail)
            #expect(missingSourceChecks["spotlight source"] == .fail)
            #expect(ScenarioVerifier.fixtureFallbackDisabledCheck(rootURL: directory).status == .fail)
            #expect(!emptyMetadataReport.ok)
            #expect(emptyMetadataChecks["native metadata"] == .fail)
            #expect(emptyMetadataChecks["deep link metadata"] == .fail)
        }
    }

    @Test("app integration sources typecheck and declare expected native types")
    func appIntegrationSourcesTypecheckAndDeclareExpectedNativeTypes() throws {
        let appIntentsPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"
        let appEntitiesPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift"
        let shoppingEntitiesPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyShoppingEntities.swift"
        let spoonEntitiesPath = "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift"
        let captureDraftEntitiesPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift"
        let chefProfileEntitiesPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift"
        let spotlightPath = "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
        let rootViewPath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"
        let platformNavigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let appIntentsSource = try readRepoFile(appIntentsPath)
        let appEntitiesSource = try readRepoFile(appEntitiesPath)
        let shoppingEntitiesSource = try readRepoFile(shoppingEntitiesPath)
        let spoonEntitiesSource = try readRepoFile(spoonEntitiesPath)
        let spotlightSource = try readRepoFile(spotlightPath)
        let rootViewSource = try readRepoFile(rootViewPath)
        let platformNavigationSource = try readRepoFile(platformNavigationPath)

        for declaration in [
            "struct OpenRecipeIntent: AppIntent",
            "struct OpenCookbookIntent: AppIntent",
            "struct OpenProfileIntent: AppIntent",
            "struct SearchSpoonjoyIntent: AppIntent",
            "struct ShareRecipeIntent: AppIntent",
            "struct ShareCookbookIntent: AppIntent",
            "struct ShareShoppingListIntent: AppIntent",
            "struct StartCookModeIntent: AppIntent",
            "struct ContinueCookModeIntent: AppIntent",
            "struct ForkRecipeIntent: AppIntent",
            "struct SaveRecipeToCookbookIntent: AppIntent",
            "struct RemoveRecipeFromCookbookIntent: AppIntent",
            "struct DeleteRecipeIntent: AppIntent",
            "struct LogCookIntent: AppIntent",
            "struct EditCookLogIntent: AppIntent",
            "struct DeleteCookLogIntent: AppIntent",
            "struct CreateCoverFromSpoonIntent: AppIntent",
            "struct AddShoppingListItemIntent: AppIntent",
            "struct SetShoppingListItemCheckedIntent: AppIntent",
            "struct RemoveShoppingListItemIntent: AppIntent",
            "struct AddRecipeIngredientsToShoppingListIntent: AppIntent",
            "struct ClearCompletedShoppingItemsIntent: AppIntent",
            "struct ClearShoppingListIntent: AppIntent",
            "struct CaptureRecipeIntent: AppIntent"
        ] {
            #expect(appIntentsSource.contains(declaration))
        }
        #expect(appIntentsSource.contains("#if canImport(AppIntents)"))
        #expect(appIntentsSource.contains("import AppIntents"))
        #expect(appIntentsSource.contains("import SpoonjoyCore"))
        #expect(appIntentsSource.contains("@available(iOS 27.0, macOS 27.0, *)"))
        #expect(appIntentsSource.contains("NativeIntentActionResolver"))
        #expect(appIntentsSource.contains("OpenURLIntent"))
        #expect(appIntentsSource.contains(".result(opensIntent:"))
        #expect(appIntentsSource.contains("dialog:"))
        #expect(appIntentsSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(appIntentsSource.contains("FileBackedNativeSyncStore"))
        #expect(appIntentsSource.contains("NativeQueuedMutation.intentMutation(from:"))
        #expect(appIntentsSource.contains("saveQueue"))
        #expect(appIntentsSource.contains("KeychainTokenVault()"))
        #expect(appIntentsSource.contains("trustedIntentScope"))
        #expect(appIntentsSource.contains("NativeIntentActionError.authRequired"))
        #expect(appIntentsSource.contains("accountID: scope.accountID"))
        #expect(appIntentsSource.contains("environment: scope.environment"))
        #expect(appIntentsSource.contains("try await SpoonjoyIntentStateWriter().apply"))
        #expect(appIntentsSource.contains("var recipe: SpoonjoyRecipeEntity"))
        #expect(appIntentsSource.contains("try recipe.resolvedRecipeID()"))
        #expect(appIntentsSource.contains("var spoon: SpoonjoySpoonEntity"))
        #expect(appIntentsSource.contains("var item: SpoonjoyShoppingItemEntity"))
        #expect(appIntentsSource.contains("try item.resolvedShoppingItemID()"))
        #expect(!appIntentsSource.contains("recipe.descriptor.id"))
        #expect(!appIntentsSource.contains("@Parameter(title: \"Recipe ID\")"))
        #expect(!appIntentsSource.contains("@Parameter(title: \"Item ID\")"))
        #expect(!appIntentsSource.contains("native-app-snapshot.json"))
        #expect(!appIntentsSource.contains("ShoppingListState.decodeFromBundle()"))
        #expect(!appIntentsSource.contains("func perform() async throws -> some IntentResult {\n        .result()\n    }"))

        for declaration in [
            "struct SpoonjoyRecipeEntity: AppEntity, IndexedEntity, Transferable",
            "struct SpoonjoyCookbookEntity: AppEntity, IndexedEntity, Transferable",
            "struct SpoonjoyRecipeEntityQuery: EntityQuery, EntityStringQuery",
            "struct SpoonjoyCookbookEntityQuery: EntityQuery, EntityStringQuery"
        ] {
            #expect(appEntitiesSource.contains(declaration))
        }
        #expect(appEntitiesSource.contains("RecipeCookbookEntityCatalog.loading(syncStore:"))
        #expect(appEntitiesSource.contains("FileBackedNativeSyncStore"))
        #expect(appEntitiesSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(appEntitiesSource.contains("NativeIntentActionError.unresolvedRecipeEntity"))
        #expect(appEntitiesSource.contains("descriptor.isPlaceholder"))
        #expect(appEntitiesSource.contains("trustedIntentScope"))
        #expect(appEntitiesSource.contains("KeychainTokenVault()"))
        #expect(appEntitiesSource.contains("scope.accountID"))
        #expect(appEntitiesSource.contains("scope.environment"))

        for declaration in [
            "struct SpoonjoyShoppingListEntity: AppEntity, IndexedEntity, Transferable",
            "struct SpoonjoyShoppingItemEntity: AppEntity, IndexedEntity, Transferable",
            "struct SpoonjoyShoppingListEntityQuery: EntityQuery",
            "struct SpoonjoyShoppingItemEntityQuery: EntityQuery, EntityStringQuery"
        ] {
            #expect(shoppingEntitiesSource.contains(declaration))
        }
        #expect(shoppingEntitiesSource.contains("ShoppingEntityCatalog.loading(syncStore:"))
        #expect(shoppingEntitiesSource.contains("FileBackedNativeSyncStore"))
        #expect(shoppingEntitiesSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(shoppingEntitiesSource.contains("NativeIntentActionError.unresolvedShoppingItemEntity"))
        #expect(shoppingEntitiesSource.contains("descriptor.isPlaceholder"))
        #expect(shoppingEntitiesSource.contains("trustedIntentScope"))
        #expect(shoppingEntitiesSource.contains("KeychainTokenVault()"))
        #expect(shoppingEntitiesSource.contains("scope.accountID"))
        #expect(shoppingEntitiesSource.contains("scope.environment"))

        for declaration in [
            "struct SpoonjoySpoonEntity: AppEntity, IndexedEntity, Transferable",
            "struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery"
        ] {
            #expect(spoonEntitiesSource.contains(declaration))
        }
        #expect(spoonEntitiesSource.contains("SpoonEntityCatalog.loading(syncStore:"))
        #expect(spoonEntitiesSource.contains("FileBackedNativeSyncStore"))
        #expect(spoonEntitiesSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(spoonEntitiesSource.contains("NativeIntentActionError.unresolvedSpoonEntity"))
        #expect(spoonEntitiesSource.contains("descriptor.isPlaceholder"))
        #expect(spoonEntitiesSource.contains("trustedIntentScope"))
        #expect(spoonEntitiesSource.contains("KeychainTokenVault()"))
        #expect(spoonEntitiesSource.contains("scope.accountID"))
        #expect(spoonEntitiesSource.contains("scope.environment"))

        for declaration in [
            "struct SpoonjoySpotlightIndexer",
            "CSSearchableItem",
            "CSSearchableItemAttributeSet",
            "CSSearchableIndex.default()",
            "indexSearchableItems",
            "SpotlightIndexPlan",
            "SpotlightIndexDocument",
            "SpotlightIndexScope",
            "SpotlightIndexType",
            "shoppingListItem",
            "indexAppEntities",
            "deleteAppEntities",
            "CSSearchableIndex.isIndexingAvailable()",
            "deleteSearchableItems(withIdentifiers:",
            "deleteSearchableItems(withDomainIdentifiers:",
            ".spoon",
            ".captureDraft",
            ".chefProfile"
        ] {
            #expect(spotlightSource.contains(declaration))
        }
        #expect(spotlightSource.contains("attributes.contentURL"))
        #expect(spotlightSource.contains("DeepLinkURLBuilder.url(for: document.route)"))
        #expect(spotlightSource.contains("#if canImport(CoreSpotlight)"))
        #expect(spotlightSource.contains("import CoreSpotlight"))
        #expect(spotlightSource.contains("import SpoonjoyCore"))
        #expect(spotlightSource.contains("@available(iOS 27.0, macOS 27.0, *)"))
        #expect(!spotlightSource.contains("deleteAllSearchableItems"))
        #expect(!spotlightSource.contains("replaceAll(documents: [SpotlightIndexDocument])"))
        #expect(spotlightSource.contains("replaceAll("))
        #expect(rootViewSource.contains("import CoreSpotlight"))
        #expect(rootViewSource.contains("onContinueUserActivity(CSSearchableItemActionType)"))
        #expect(rootViewSource.contains("CSSearchableItemActivityIdentifier"))
        #expect(rootViewSource.contains("SpotlightIndexPlan.route(uniqueIdentifier: uniqueIdentifier)"))
        #expect(rootViewSource.contains("recordingOpenedRoute(route"))
        #expect(rootViewSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(!rootViewSource.contains("native-app-snapshot.json"))
        #expect(platformNavigationSource.contains(".task(id: spotlightIndexIdentity)"))
        #expect(platformNavigationSource.contains("contentState.spotlightIndexScope"))
        #expect(platformNavigationSource.contains("document.contentDescription"))
        #expect(platformNavigationSource.contains("document.keywords"))
        #expect(platformNavigationSource.contains("spotlightIdentityComponent"))
        #expect(platformNavigationSource.contains("indexer.replaceAll("))
        #expect(platformNavigationSource.contains("spotlightIndexIdentity"))

        try assertSwiftSourcesTypecheck([appEntitiesPath, shoppingEntitiesPath, spoonEntitiesPath, chefProfileEntitiesPath, appIntentsPath])
        try assertSwiftSourcesTypecheck([
            appEntitiesPath,
            shoppingEntitiesPath,
            spoonEntitiesPath,
            captureDraftEntitiesPath,
            chefProfileEntitiesPath,
            appIntentsPath,
            spotlightPath
        ])
    }

    @Test("AASA validation requires app IDs and every deep link route component")
    func aasaValidationRequiresAppIDsAndEveryDeepLinkRouteComponent() throws {
        try withTemporaryDirectory { directory in
            let completeFixture = directory.appendingPathComponent("complete-aasa.json")
            let missingComponentFixture = directory.appendingPathComponent("missing-component-aasa.json")
            let placeholderAppIDFixture = directory.appendingPathComponent("placeholder-app-id-aasa.json")
            let ambiguousTeamFixture = directory.appendingPathComponent("ambiguous-team-aasa.json")
            let validRoot = directory.appendingPathComponent("valid", isDirectory: true)
            let missingRoot = directory.appendingPathComponent("missing", isDirectory: true)
            let placeholderRoot = directory.appendingPathComponent("placeholder", isDirectory: true)
            let ambiguousRoot = directory.appendingPathComponent("ambiguous", isDirectory: true)
            let ambiguousOverrideRoot = directory.appendingPathComponent("ambiguous-override", isDirectory: true)
            let nonSuccessfulRoot = directory.appendingPathComponent("non-successful", isDirectory: true)
            let invalidTeamRoot = directory.appendingPathComponent("invalid-team", isDirectory: true)
            let script = repoURL.appendingPathComponent("scripts/validate-aasa.rb")

            try """
            {"applinks":{"apps":[],"details":[{"appIDs":["743GT2AJ24.app.spoonjoy.Spoonjoy","743GT2AJ24.app.spoonjoy.Spoonjoy.mac"],"components":[{"/":"/"},{"/":"/recipes"},{"/":"/recipes/*"},{"/":"/cookbooks"},{"/":"/cookbooks/*"},{"/":"/users/*"},{"/":"/shopping-list"},{"/":"/search"},{"/":"/search","?":{"*":"*"}},{"/":"/recipes/new"},{"/":"/account/settings"}]}]}}
            """.write(to: completeFixture, atomically: true, encoding: .utf8)
            try """
            {"applinks":{"apps":[],"details":[{"appIDs":["743GT2AJ24.app.spoonjoy.Spoonjoy","743GT2AJ24.app.spoonjoy.Spoonjoy.mac"],"components":[{"/":"/"},{"/":"/recipes"},{"/":"/recipes/*"},{"/":"/cookbooks"},{"/":"/cookbooks/*"},{"/":"/users/*"},{"/":"/shopping-list"},{"/":"/search"},{"/":"/search","?":{"*":"*"}},{"/":"/recipes/new"}]}]}}
            """.write(to: missingComponentFixture, atomically: true, encoding: .utf8)
            try """
            {"applinks":{"apps":[],"details":[{"appIDs":["TEAMID.app.spoonjoy.Spoonjoy","TEAMID.app.spoonjoy.Spoonjoy.mac"],"components":[{"/":"/"},{"/":"/recipes"},{"/":"/recipes/*"},{"/":"/cookbooks"},{"/":"/cookbooks/*"},{"/":"/users/*"},{"/":"/shopping-list"},{"/":"/search"},{"/":"/search","?":{"*":"*"}},{"/":"/recipes/new"},{"/":"/account/settings"}]}]}}
            """.write(to: placeholderAppIDFixture, atomically: true, encoding: .utf8)
            try """
            {"applinks":{"apps":[],"details":[{"appIDs":["A123456789.app.spoonjoy.Spoonjoy","A123456789.app.spoonjoy.Spoonjoy.mac","B123456789.app.spoonjoy.Spoonjoy","B123456789.app.spoonjoy.Spoonjoy.mac"],"components":[{"/":"/"},{"/":"/recipes"},{"/":"/recipes/*"},{"/":"/cookbooks"},{"/":"/cookbooks/*"},{"/":"/users/*"},{"/":"/shopping-list"},{"/":"/search"},{"/":"/search","?":{"*":"*"}},{"/":"/recipes/new"},{"/":"/account/settings"}]}]}}
            """.write(to: ambiguousTeamFixture, atomically: true, encoding: .utf8)

            let valid = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", validRoot.path],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": completeFixture.path],
                currentDirectoryURL: repoURL
            )
            let missing = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", missingRoot.path],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": missingComponentFixture.path],
                currentDirectoryURL: repoURL
            )
            let placeholder = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", placeholderRoot.path],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": placeholderAppIDFixture.path],
                currentDirectoryURL: repoURL
            )
            let ambiguous = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", ambiguousRoot.path],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": ambiguousTeamFixture.path],
                currentDirectoryURL: repoURL
            )
            let ambiguousOverride = try runProcess(
                "/usr/bin/ruby",
                arguments: [
                    script.path,
                    "--artifact-root",
                    ambiguousOverrideRoot.path,
                    "--team-id",
                    "A123456789"
                ],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": ambiguousTeamFixture.path],
                currentDirectoryURL: repoURL
            )
            let nonSuccessful = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", nonSuccessfulRoot.path],
                environment: [
                    "SPOONJOY_AASA_FIXTURE_PATH": completeFixture.path,
                    "SPOONJOY_AASA_FIXTURE_STATUS": "404"
                ],
                currentDirectoryURL: repoURL
            )
            let invalidTeam = try runProcess(
                "/usr/bin/ruby",
                arguments: [script.path, "--artifact-root", invalidTeamRoot.path, "--team-id", "TEAMID"],
                environment: ["SPOONJOY_AASA_FIXTURE_PATH": completeFixture.path],
                currentDirectoryURL: repoURL
            )
            let validValidation = try String(
                contentsOf: validRoot.appendingPathComponent("aasa-validation.json"),
                encoding: .utf8
            )
            let missingBlocker = try String(
                contentsOf: missingRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )
            let placeholderBlocker = try String(
                contentsOf: placeholderRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )
            let ambiguousBlocker = try String(
                contentsOf: ambiguousRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )
            let ambiguousOverrideBlocker = try String(
                contentsOf: ambiguousOverrideRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )
            let nonSuccessfulBlocker = try String(
                contentsOf: nonSuccessfulRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )
            let invalidTeamBlocker = try String(
                contentsOf: invalidTeamRoot.appendingPathComponent("aasa-production-blocker.json"),
                encoding: .utf8
            )

            #expect(valid.exitCode == 0)
            #expect(valid.output.contains("aasa validation ok"))
            #expect(FileManager.default.fileExists(atPath: validRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(!FileManager.default.fileExists(atPath: validRoot.appendingPathComponent("aasa-production-blocker.json").path))
            #expect(validValidation.contains(#""expectedAppleTeamID": null"#))
            #expect(validValidation.contains(#""validatedAppleTeamID": "743GT2AJ24""#))
            #expect(validValidation.contains(#""requiredBundleIDs""#))
            #expect(missing.exitCode == 0)
            #expect(missing.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: missingRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(missingBlocker.contains(#""capability": "AASAProductionValidation""#))
            #expect(missingBlocker.contains("AASA endpoint is missing required route components."))
            #expect(missingBlocker.contains(#""/": "/account/settings""#))
            #expect(placeholder.exitCode == 0)
            #expect(placeholder.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: placeholderRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(placeholderBlocker.contains("AASA endpoint is missing valid app IDs for bundle identifiers: app.spoonjoy.Spoonjoy, app.spoonjoy.Spoonjoy.mac."))
            #expect(placeholderBlocker.contains(#""validatedAppleTeamID": null"#))
            #expect(placeholderBlocker.contains(#""missingAppIDBundles""#))
            #expect(placeholderBlocker.contains(#""app.spoonjoy.Spoonjoy.mac""#))
            #expect(ambiguous.exitCode == 0)
            #expect(ambiguous.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: ambiguousRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(ambiguousBlocker.contains("AASA endpoint publishes multiple common valid Apple Team IDs"))
            #expect(ambiguousBlocker.contains(#""validatedAppleTeamID": null"#))
            #expect(ambiguousBlocker.contains(#""discoveredCommonAppleTeamIDs""#))
            #expect(ambiguousBlocker.contains(#""ambiguousAppleTeamIDs""#))
            #expect(ambiguousBlocker.contains(#""A123456789""#))
            #expect(ambiguousBlocker.contains(#""B123456789""#))
            #expect(ambiguousOverride.exitCode == 0)
            #expect(ambiguousOverride.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: ambiguousOverrideRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(ambiguousOverrideBlocker.contains("AASA endpoint publishes multiple common valid Apple Team IDs"))
            #expect(ambiguousOverrideBlocker.contains(#""expectedAppleTeamID": "A123456789""#))
            #expect(ambiguousOverrideBlocker.contains(#""validatedAppleTeamID": "A123456789""#))
            #expect(ambiguousOverrideBlocker.contains(#""ambiguousAppleTeamIDs""#))
            #expect(ambiguousOverrideBlocker.contains(#""A123456789""#))
            #expect(ambiguousOverrideBlocker.contains(#""B123456789""#))
            #expect(nonSuccessful.exitCode == 0)
            #expect(nonSuccessful.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: nonSuccessfulRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(nonSuccessfulBlocker.contains("AASA endpoint returned HTTP 404"))
            #expect(nonSuccessfulBlocker.contains(#""successfulStatus": false"#))
            #expect(invalidTeam.exitCode == 0)
            #expect(invalidTeam.output.contains("aasa production blocked"))
            #expect(!FileManager.default.fileExists(atPath: invalidTeamRoot.appendingPathComponent("aasa-validation.json").path))
            #expect(invalidTeamBlocker.contains("Apple Developer Team ID must be 10 alphanumeric characters."))
            #expect(invalidTeamBlocker.contains(#""appleTeamIDValidationError": "Apple Developer Team ID must be 10 alphanumeric characters.""#))
            #expect(invalidTeamBlocker.contains(#""capability": "AASAProductionValidation""#))
            #expect(invalidTeamBlocker.contains(#""outputPath""#))
        }
    }

    @Test("verify native scenarios script gates native metadata behavior")
    func verifyNativeScenariosScriptGatesNativeMetadataBehavior() throws {
        let scriptPath = "scripts/verify-native-scenarios.sh"
        let scriptURL = repoURL.appendingPathComponent(scriptPath)
        let attributes = try FileManager.default.attributesOfItem(atPath: scriptURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber).intValue

        #expect(permissions & 0o111 != 0)

        try withTemporaryDirectory { directory in
            let outputURL = directory.appendingPathComponent("native-metadata.json")
            let scratchURL = directory.appendingPathComponent("swiftpm-scratch")
            let success = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata", "--output", outputURL.path],
                environment: ["SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path],
                currentDirectoryURL: repoURL
            )

            #expect(success.exitCode == 0, Comment(rawValue: success.combinedOutput))

            let data = try Data(contentsOf: outputURL)
            let report = try JSONDecoder().decode(ScenarioReport.self, from: data)
            #expect(report.ok)
            #expect(report.stage == .nativeMetadata)
            #expect(report.checks.filter { $0.status == .fail }.isEmpty)
            #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["app surfaces"])

            let missingSourceRoot = directory.appendingPathComponent("missing-source-root")
            try FileManager.default.createDirectory(at: missingSourceRoot, withIntermediateDirectories: true)
            let missingOutputURL = directory.appendingPathComponent("native-metadata-missing.json")
            let failure = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata", "--output", missingOutputURL.path],
                environment: [
                    "SPOONJOY_SCENARIO_ROOT": missingSourceRoot.path,
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path
                ],
                currentDirectoryURL: repoURL
            )

            #expect(failure.exitCode != 0)
            #expect(failure.combinedOutput.contains("app intents source"))
            #expect(failure.combinedOutput.contains("spotlight source"))

            let surfacesOutputURL = directory.appendingPathComponent("surfaces.json")
            let surfaces = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "surfaces", "--output", surfacesOutputURL.path],
                environment: ["SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path],
                currentDirectoryURL: repoURL
            )
            let surfacesData = try Data(contentsOf: surfacesOutputURL)
            let surfacesReport = try JSONDecoder().decode(ScenarioReport.self, from: surfacesData)

            #expect(surfaces.exitCode == 0, Comment(rawValue: surfaces.combinedOutput))
            #expect(surfacesReport.ok)
            #expect(surfacesReport.stage == .surfaces)
            #expect(surfacesReport.checks.filter { $0.status == .pending }.isEmpty)

            let defaultOutputDirectory = directory.appendingPathComponent("default-output", isDirectory: true)
            try FileManager.default.createDirectory(at: defaultOutputDirectory, withIntermediateDirectories: true)
            let firstDefaultOutput = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata"],
                environment: [
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path,
                    "TMPDIR": defaultOutputDirectory.path + "/"
                ],
                currentDirectoryURL: repoURL
            )
            let secondDefaultOutput = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata"],
                environment: [
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path,
                    "TMPDIR": defaultOutputDirectory.path + "/"
                ],
                currentDirectoryURL: repoURL
            )
            let defaultArtifacts = try FileManager.default.contentsOfDirectory(
                atPath: defaultOutputDirectory.path
            ).filter {
                $0.hasPrefix("spoonjoy-scenario-native-metadata.") && $0.hasSuffix(".json")
            }

            #expect(firstDefaultOutput.exitCode == 0, Comment(rawValue: firstDefaultOutput.combinedOutput))
            #expect(secondDefaultOutput.exitCode == 0, Comment(rawValue: secondDefaultOutput.combinedOutput))
            #expect(defaultArtifacts.count == 2)
        }
    }

    private var repoURL: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func readRepoFile(_ relativePath: String) throws -> String {
        let url = repoURL.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertSwiftSourceTypechecks(_ relativePath: String) throws {
        try assertSwiftSourcesTypecheck([relativePath])
    }

    private func assertSwiftSourcesTypecheck(_ relativePaths: [String]) throws {
        let result = try runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "swiftc",
                "-typecheck",
                "-warnings-as-errors",
                "-I", repoURL.appendingPathComponent(".build/arm64-apple-macosx/debug/Modules").path
            ] + relativePaths.map { repoURL.appendingPathComponent($0).path },
            currentDirectoryURL: repoURL
        )

        #expect(result.exitCode == 0, Comment(rawValue: result.combinedOutput))
    }

    private func runProcess(
        _ executablePath: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL
    ) throws -> ProcessResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = output
        process.standardError = error
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, output: outputText, error: errorText)
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("spoonjoy-native-scenario-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try body(directory)
    }
}

private enum FixtureLoadError: Error {
    case unavailable
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
    let error: String

    var combinedOutput: String {
        output + error
    }
}
