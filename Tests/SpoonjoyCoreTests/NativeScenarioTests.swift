import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native scenario metadata")
struct NativeScenarioTests {
    private let expectedAppIntents = [
        "OpenRecipeIntent",
        "StartCookModeIntent",
        "AddShoppingListItemIntent",
        "SetShoppingListItemCheckedIntent",
        "AddRecipeIngredientsToShoppingListIntent",
        "ClearCompletedShoppingItemsIntent",
        "ClearShoppingListIntent"
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
        "share-cookbook"
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
        #expect(!report.nativeCapabilities.appIntents.contains { $0.hasPrefix("Spoonjoy") })
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
    }

    @Test("spotlight index plan builds route aware searchable documents")
    func spotlightIndexPlanBuildsRouteAwareSearchableDocuments() throws {
        let recipes = try RecipeFixtureCatalog.decodeFromBundle().recipes
        let cookbooks = try CookbookFixtureCatalog.decodeFromBundle().cookbooks
        let shoppingList = try ShoppingListState.decodeFromBundle()
        let documents = SpotlightIndexPlan.documents(
            recipes: recipes,
            cookbooks: cookbooks,
            shoppingList: shoppingList
        )
        let recipe = try #require(documents.first { $0.uniqueIdentifier == "recipe:recipe_lemon_pantry_pasta" })
        let cookbook = try #require(documents.first { $0.uniqueIdentifier == "cookbook:cookbook_weeknights" })
        let shoppingItem = try #require(documents.first { $0.uniqueIdentifier == "shopping-list-item:item_lemons" })

        #expect(documents.count == recipes.count + cookbooks.count + shoppingList.activeItems.count)
        #expect(recipe.type == .recipe)
        #expect(recipe.domainIdentifier == "app.spoonjoy.recipe")
        #expect(recipe.title == "Lemon Pantry Pasta")
        #expect(recipe.contentDescription.contains("ari"))
        #expect(recipe.keywords.contains("Spoonjoy"))
        #expect(recipe.keywords.contains("recipe"))
        #expect(recipe.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: recipe.uniqueIdentifier) == recipe.route)
        #expect(DeepLinkURLBuilder.url(for: recipe.route) == URL(string: "spoonjoy://recipes/recipe_lemon_pantry_pasta"))
        #expect(cookbook.type == .cookbook)
        #expect(cookbook.domainIdentifier == "app.spoonjoy.cookbook")
        #expect(cookbook.contentDescription.contains("2 recipes"))
        #expect(cookbook.route == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: cookbook.uniqueIdentifier) == cookbook.route)
        #expect(DeepLinkURLBuilder.url(for: cookbook.route) == URL(string: "spoonjoy://cookbooks/cookbook_weeknights"))
        #expect(shoppingItem.type == .shoppingListItem)
        #expect(shoppingItem.domainIdentifier == "app.spoonjoy.shopping-list-item")
        #expect(shoppingItem.title == "lemons")
        #expect(shoppingItem.contentDescription.contains("Shopping list"))
        #expect(shoppingItem.route == .shoppingList)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: shoppingItem.uniqueIdentifier) == .shoppingList)
        #expect(DeepLinkURLBuilder.url(for: shoppingItem.route) == URL(string: "spoonjoy://shopping-list"))
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "recipe:../secret") == .unknownLink)
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

        let servingsDocument = SpotlightIndexPlan.document(recipe: servingRecipe)
        let readyDocument = SpotlightIndexPlan.document(recipe: readyRecipe)
        let cookbookDocument = SpotlightIndexPlan.document(cookbook: cookbook)
        let shoppingDocument = SpotlightIndexPlan.document(shoppingListItem: shoppingItem)

        #expect(servingsDocument.contentDescription.contains("1 bowl"))
        #expect(readyDocument.contentDescription.contains("Ready to cook in Spoonjoy."))
        #expect(cookbookDocument.contentDescription.contains("1 recipe"))
        #expect(shoppingDocument.keywords.contains("shopping"))
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
        let spotlightPath = "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
        let rootViewPath = "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift"
        let platformNavigationPath = "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
        let appIntentsSource = try readRepoFile(appIntentsPath)
        let spotlightSource = try readRepoFile(spotlightPath)
        let rootViewSource = try readRepoFile(rootViewPath)
        let platformNavigationSource = try readRepoFile(platformNavigationPath)

        for declaration in [
            "struct OpenRecipeIntent: AppIntent",
            "struct StartCookModeIntent: AppIntent",
            "struct AddShoppingListItemIntent: AppIntent",
            "struct SetShoppingListItemCheckedIntent: AppIntent",
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
        #expect(!appIntentsSource.contains("native-app-snapshot.json"))
        #expect(!appIntentsSource.contains("ShoppingListState.decodeFromBundle()"))
        #expect(!appIntentsSource.contains("func perform() async throws -> some IntentResult {\n        .result()\n    }"))

        for declaration in [
            "struct SpoonjoySpotlightIndexer",
            "CSSearchableItem",
            "CSSearchableItemAttributeSet",
            "CSSearchableIndex.default()",
            "indexSearchableItems",
            "SpotlightIndexPlan",
            "SpotlightIndexDocument",
            "SpotlightIndexType",
            "shoppingListItem"
        ] {
            #expect(spotlightSource.contains(declaration))
        }
        #expect(spotlightSource.contains("attributes.contentURL"))
        #expect(spotlightSource.contains("DeepLinkURLBuilder.url(for: document.route)"))
        #expect(spotlightSource.contains("#if canImport(CoreSpotlight)"))
        #expect(spotlightSource.contains("import CoreSpotlight"))
        #expect(spotlightSource.contains("import SpoonjoyCore"))
        #expect(spotlightSource.contains("@available(iOS 27.0, macOS 27.0, *)"))
        #expect(rootViewSource.contains("import CoreSpotlight"))
        #expect(rootViewSource.contains("onContinueUserActivity(CSSearchableItemActionType)"))
        #expect(rootViewSource.contains("CSSearchableItemActivityIdentifier"))
        #expect(rootViewSource.contains("SpotlightIndexPlan.route(uniqueIdentifier: uniqueIdentifier)"))
        #expect(rootViewSource.contains("recordingOpenedRoute(route"))
        #expect(rootViewSource.contains("NativeAppStateLocation.defaultFileURL()"))
        #expect(!rootViewSource.contains("native-app-snapshot.json"))
        #expect(platformNavigationSource.contains(".task(id: spotlightIndexIdentity)"))
        #expect(platformNavigationSource.contains("SpoonjoySpotlightIndexer().index("))
        #expect(platformNavigationSource.contains("spotlightIndexIdentity"))

        try assertSwiftSourceTypechecks(appIntentsPath)
        try assertSwiftSourceTypechecks(spotlightPath)
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
        let result = try runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "swiftc",
                "-typecheck",
                "-warnings-as-errors",
                "-I", repoURL.appendingPathComponent(".build/arm64-apple-macosx/debug/Modules").path,
                repoURL.appendingPathComponent(relativePath).path
            ],
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
