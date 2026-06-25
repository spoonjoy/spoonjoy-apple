import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Recipe catalog and detail native parity")
struct RecipeCatalogDetailTests {
    private static let now = Date(timeIntervalSince1970: 1_780_020_000)
    private static let staleValidatedAt = Date(timeIntervalSince1970: 1_779_900_000)

    @Test("public recipe detail decodes dependencies recent spoons and provenance")
    func publicRecipeDetailDecodesDependenciesRecentSpoonsAndProvenance() throws {
        let envelope = try APIEnvelope<RecipeDetailData>.decode(Self.recipeDetailEnvelopeData)
        let recipe = envelope.data.recipe

        #expect(envelope.requestID == "req_recipe_detail")
        #expect(recipe.title == "Lemon Pantry Pasta")
        #expect(recipe.servings == "4")
        #expect(recipe.coverProvenanceLabel == "Chef photo")
        #expect(recipe.attribution.sourceHost == "example.com")
        #expect(recipe.attribution.sourceRecipe?.title == "Original Lemon Pasta")
        #expect(recipe.attribution.sourceRecipe?.safeCanonicalURL?.absoluteString == "https://spoonjoy.app/recipes/recipe_source_pasta")
        #expect(recipe.steps.map(\.stepNum) == [1, 2])
        #expect(recipe.steps[0].usingSteps.isEmpty)
        #expect(recipe.steps[1].usingSteps.map(\.id) == ["use_sauce_base"])
        #expect(recipe.steps[1].usingSteps.first?.outputOfStep.stepTitle == "Boil Pasta")
        #expect(recipe.steps[1].ingredients.map(\.name) == ["garlic", "lemon"])
        #expect(recipe.cookbooks.map(\.id) == ["cookbook_weeknights"])
        #expect(recipe.recentSpoons.map(\.id) == ["spoon_jules_lemon"])
        #expect(recipe.recentSpoons.first?.chef.username == "jules")
        #expect(recipe.recentSpoons.first?.chef.photoURL?.absoluteString == "https://spoonjoy.app/photos/users/jules.jpg")
        #expect(recipe.recentSpoons.first?.note == "More lemon next time.")
        #expect(recipe.recentSpoons.first?.nextTime == "Add parsley.")
    }

    @Test("catalog view model trims query loads live rows and exposes route actions")
    func catalogViewModelTrimsQueryLoadsLiveRowsAndExposesRouteActions() async throws {
        let recipe = try Self.recipeDetail()
        let repository = RecordingRecipeCatalogRepository(
            page: RecipeCatalogPage(
                query: "lemon",
                limit: 20,
                cursor: nil,
                nextCursor: PaginationCursor(rawValue: "v1.next"),
                hasMore: true,
                rows: [RecipeSummary(recipe: recipe)],
                source: .live(requestID: "req_recipe_list", validatedAt: Self.now)
            ),
            detail: RecipeCatalogDetailResult(
                recipe: recipe,
                source: .live(requestID: "req_recipe_detail", validatedAt: Self.now)
            )
        )
        let viewModel = RecipeCatalogViewModel(repository: repository)

        try await viewModel.load(query: "  lemon  ", limit: 20)
        let state = viewModel.state

        #expect(state.query == "lemon")
        #expect(state.limit == 20)
        #expect(state.hasMore)
        #expect(state.nextCursor == PaginationCursor(rawValue: "v1.next"))
        #expect(state.resultCountLabel == "1 recipe")
        #expect(state.emptyState == nil)
        #expect(state.rows.map(\.id) == ["recipe_lemon_pantry_pasta"])
        #expect(state.rows.first?.title == "Lemon Pantry Pasta")
        #expect(state.rows.first?.subtitle == "Bright pantry pasta with lemon, garlic, and parmesan.")
        #expect(state.rows.first?.chefLine == "By ari")
        #expect(state.rows.first?.servingsLabel == "Serves 4")
        #expect(state.rows.first?.coverProvenanceLabel == "Chef photo")
        #expect(state.rows.first?.openRoute == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(state.offlineIndicator.display == .synced)
        #expect(viewModel.openRecipeRoute(id: "recipe_lemon_pantry_pasta") == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(await repository.listRequests == [
            RecipeCatalogListRequest(query: "lemon", limit: 20, cursor: nil)
        ])
    }

    @Test("detail screen view model exposes current web read parity without inventing comments")
    func detailScreenViewModelExposesCurrentWebReadParityWithoutInventingComments() throws {
        let recipe = try Self.recipeDetail()
        let result = RecipeCatalogDetailResult(
            recipe: recipe,
            source: .cache(
                serverRevision: .updatedAt(recipe.updatedAt),
                lastValidatedAt: Self.staleValidatedAt
            )
        )
        let viewModel = RecipeDetailScreenViewModel(
            result: result,
            context: RecipeDetailContext(
                currentChefID: "chef_ari",
                availableCookbooks: [
                    RecipeCookbookSaveOption(id: "cookbook_weeknights", title: "Weeknights"),
                    RecipeCookbookSaveOption(id: "cookbook_pantry", title: "Pantry")
                ],
                savedInCookbookIDs: ["cookbook_weeknights"],
                hasIngredientsInShoppingList: true,
                now: Self.now
            )
        )

        #expect(viewModel.id == "recipe_lemon_pantry_pasta")
        #expect(viewModel.title == "Lemon Pantry Pasta")
        #expect(viewModel.description == "Bright pantry pasta with lemon, garlic, and parmesan.")
        #expect(viewModel.chefAttribution == "By ari")
        #expect(viewModel.servingsLabel == "Serves 4")
        #expect(viewModel.cover.imageURL?.absoluteString == "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg")
        #expect(viewModel.cover.provenanceLabel == "Chef photo")
        #expect(viewModel.sourceAttribution?.title == "Original Lemon Pasta")
        #expect(viewModel.sourceAttribution?.host == "example.com")
        #expect(viewModel.ingredientReceipt.rows.map(\.name) == ["kosher salt", "spaghetti", "garlic", "lemon"])
        #expect(viewModel.methodSections.map(\.stepNumber) == [1, 2])
        #expect(viewModel.methodSections[1].dependencies.map(\.label) == ["Uses Boil Pasta"])
        #expect(viewModel.spoonSummary.rows.map(\.chefLine) == ["jules cooked this"])
        #expect(viewModel.spoonSummary.rows.first?.note == "More lemon next time.")
        #expect(viewModel.cookbookSave.availableCookbooks.map(\.title) == ["Weeknights", "Pantry"])
        #expect(viewModel.cookbookSave.savedCookbookIDs == ["cookbook_weeknights"])
        #expect(viewModel.cookbookSave.isSaved(in: "cookbook_weeknights"))
        #expect(viewModel.hasIngredientsInShoppingList)
        #expect(viewModel.ownerTools.isVisible)
        #expect(viewModel.ownerTools.editPath == "/recipes/recipe_lemon_pantry_pasta/edit")
        #expect(viewModel.actions.startCookingRoute == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .cook))
        #expect(viewModel.actions.shareURL.absoluteString == "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")
        #expect(viewModel.actions.chefProfilePath == "/users/ari")
        #expect(viewModel.offlineIndicator.display == .stale(domain: .recipeDetail(id: "recipe_lemon_pantry_pasta")))
        #expect(viewModel.offlineIndicator.display.informationalOnly)
        #expect(Set(viewModel.supportedReadSurfaces) == Set([
            .identity,
            .cover,
            .chefAttribution,
            .sourceAttribution,
            .ingredientReceipt,
            .method,
            .recentSpoons,
            .cookbookSave,
            .shoppingList,
            .ownerTools,
            .share,
            .startCooking
        ]))
    }

    @Test("detail cache restore keeps full recipe payload instead of placeholder shell")
    func detailCacheRestoreKeepsFullRecipePayloadInsteadOfPlaceholderShell() throws {
        let recipe = try Self.recipeDetail()
        let cached = RecipeCatalogDetailResult(
            recipe: recipe,
            source: .cache(
                serverRevision: .updatedAt(recipe.updatedAt),
                lastValidatedAt: Self.staleValidatedAt
            )
        )

        #expect(cached.recipe.id == "recipe_lemon_pantry_pasta")
        #expect(cached.recipe.attribution.creditText == "Lemon Pantry Pasta by ari on Spoonjoy")
        #expect(cached.recipe.steps.flatMap(\.ingredients).map(\.name) == ["kosher salt", "spaghetti", "garlic", "lemon"])
        #expect(cached.recipe.steps[1].usingSteps.map(\.outputStepNum) == [1])
        #expect(cached.recipe.recentSpoons.map(\.id) == ["spoon_jules_lemon"])
        #expect(cached.offlineIndicator(now: Self.now, freshnessPolicy: .offlineProductContract).display == .stale(domain: .recipeDetail(id: "recipe_lemon_pantry_pasta")))
    }

    @Test("recipe surfaces require feature layer wiring rather than raw fixture arrays")
    func recipeSurfacesRequireFeatureLayerWiringRatherThanRawFixtureArrays() throws {
        let requiredFiles = [
            "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogRepository.swift",
            "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift",
            "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
        ]
        for path in requiredFiles {
            #expect(
                FileManager.default.fileExists(atPath: repoURL.appendingPathComponent(path).path),
                Comment(rawValue: "\(path) should exist before native recipe parity can pass.")
            )
        }

        let navigation = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"))
        let recipesView = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipesView.swift"))
        let detailView = uncommentedSwift(try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"))

        expectContent(
            navigation,
            in: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
            contains: [
                "RecipeCatalogViewModel",
                "RecipeDetailScreenViewModel",
                "RecipeCatalogRepository",
                "contentState.recipeCatalog"
            ],
            forbids: [
                "RecipesView(recipes: contentState.recipes",
                "RecipeDetailView(viewModel: RecipeDetailViewModel(recipe: recipe)",
                "comments",
                "socialFeed",
                "mealPlan",
                "RecipeComments",
                "SocialFeed",
                "MealPlan"
            ]
        )
        expectContent(
            recipesView,
            in: "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
            contains: [
                "RecipeCatalogViewModel",
                "state.rows",
                "openRoute"
            ]
        )
        expectContent(
            detailView,
            in: "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
            contains: [
                "RecipeDetailScreenViewModel",
                "spoonSummary",
                "cookbookSave",
                "ownerTools",
                "offlineIndicator"
            ],
            forbids: [
                "comments",
                "socialFeed",
                "mealPlan",
                "RecipeComments",
                "SocialFeed",
                "MealPlan"
            ]
        )
    }

    private static func recipeDetail() throws -> Recipe {
        try APIEnvelope<RecipeDetailData>.decode(recipeDetailEnvelopeData).data.recipe
    }

    private static let recipeDetailEnvelopeData = Data(
        """
        {
          "ok": true,
          "requestId": "req_recipe_detail",
          "data": {
            "recipe": {
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
                "sourceUrl": "https://example.com/original-lemon-pasta",
                "sourceHost": "example.com",
                "sourceRecipe": {
                  "id": "recipe_source_pasta",
                  "title": "Original Lemon Pasta",
                  "chef": { "id": "chef_jules", "username": "jules" },
                  "href": "/recipes/recipe_source_pasta",
                  "canonicalUrl": "https://spoonjoy.app/recipes/recipe_source_pasta",
                  "deleted": false
                }
              },
              "createdAt": "2026-06-01T00:00:00.000Z",
              "updatedAt": "2026-06-01T00:10:00.000Z",
              "steps": [
                {
                  "id": "step_boil",
                  "stepNum": 1,
                  "stepTitle": "Boil Pasta",
                  "description": "Boil the pasta until just shy of al dente.",
                  "duration": 10,
                  "ingredients": [
                    { "id": "ingredient_salt", "name": "kosher salt", "quantity": 1, "unit": "tbsp" },
                    { "id": "ingredient_spaghetti", "name": "spaghetti", "quantity": 12, "unit": "oz" }
                  ],
                  "usingSteps": []
                },
                {
                  "id": "step_sauce",
                  "stepNum": 2,
                  "stepTitle": "Build Sauce",
                  "description": "Warm the aromatics and lemon until glossy.",
                  "duration": 5,
                  "ingredients": [
                    { "id": "ingredient_garlic", "name": "garlic", "quantity": 2, "unit": "clove" },
                    { "id": "ingredient_lemon", "name": "lemon", "quantity": 1, "unit": "each" }
                  ],
                  "usingSteps": [
                    {
                      "id": "use_sauce_base",
                      "inputStepNum": 2,
                      "outputStepNum": 1,
                      "outputOfStep": { "stepNum": 1, "stepTitle": "Boil Pasta" }
                    }
                  ]
                }
              ],
              "cookbooks": [
                {
                  "id": "cookbook_weeknights",
                  "title": "Weeknights",
                  "href": "/cookbooks/cookbook_weeknights",
                  "canonicalUrl": "https://spoonjoy.app/cookbooks/cookbook_weeknights"
                }
              ],
              "recentSpoons": [
                {
                  "id": "spoon_jules_lemon",
                  "chefId": "chef_jules",
                  "recipeId": "recipe_lemon_pantry_pasta",
                  "cookedAt": "2026-06-02T18:30:00.000Z",
                  "photoUrl": "https://spoonjoy.app/photos/spoons/chef_jules/lemon.jpg",
                  "note": "More lemon next time.",
                  "nextTime": "Add parsley.",
                  "deletedAt": null,
                  "createdAt": "2026-06-02T18:30:00.000Z",
                  "updatedAt": "2026-06-02T18:31:00.000Z",
                  "chef": {
                    "id": "chef_jules",
                    "username": "jules",
                    "photoUrl": "https://spoonjoy.app/photos/users/jules.jpg"
                  }
                }
              ]
            }
          }
        }
        """.utf8
    )
}

private actor RecordingRecipeCatalogRepository: RecipeCatalogRepository {
    private let page: RecipeCatalogPage
    private let detail: RecipeCatalogDetailResult
    private var requests: [RecipeCatalogListRequest] = []
    private var detailIDs: [String] = []

    init(page: RecipeCatalogPage, detail: RecipeCatalogDetailResult) {
        self.page = page
        self.detail = detail
    }

    var listRequests: [RecipeCatalogListRequest] {
        requests
    }

    var detailRequests: [String] {
        detailIDs
    }

    func listRecipes(request: RecipeCatalogListRequest) async throws -> RecipeCatalogPage {
        requests.append(request)
        return page
    }

    func recipeDetail(id: String) async throws -> RecipeCatalogDetailResult {
        detailIDs.append(id)
        return detail
    }
}

private let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readRepoFile(_ relativePath: String) throws -> String {
    try String(contentsOf: repoURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func uncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: .regularExpression)
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    let forbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(missing.isEmpty, Comment(rawValue: "\(relativePath) missing tokens: \(missing.joined(separator: ", "))"))
    #expect(forbidden.isEmpty, Comment(rawValue: "\(relativePath) contains forbidden tokens: \(forbidden.joined(separator: ", "))"))
}
