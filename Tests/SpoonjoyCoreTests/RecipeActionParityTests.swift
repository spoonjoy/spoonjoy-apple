import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native recipe action parity")
struct RecipeActionParityTests {
    private static let now = Date(timeIntervalSince1970: 1_780_020_000)
    private static let createdAt = "2026-06-26T00:00:00.000Z"
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("recipe detail exposes native action metadata without inventing new social surfaces")
    func recipeDetailExposesNativeActionMetadata() throws {
        let recipe = try Self.recipeDetail()
        let context = Self.detailContext(currentChefID: "chef_ari")
        let viewModel = RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(
                recipe: recipe,
                source: .live(requestID: "req_recipe_detail", validatedAt: Self.now)
            ),
            context: context
        )

        #expect(viewModel.actions.availableActionIDs == [
            .startCooking,
            .saveToCookbook,
            .addToShoppingList,
            .share,
            .makeVariation,
            .edit,
            .manageCovers,
            .deleteRecipe
        ])
        #expect(viewModel.actions.startCookingRoute == .recipeDetail(id: recipe.id, presentation: .cook))
        #expect(viewModel.actions.sharePayload?.publicURL?.absoluteString == "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta")
        #expect(viewModel.actions.chefProfilePath == "/users/ari")
        #expect(viewModel.actions.cookbookOptions.map(\.id) == ["cookbook_weeknights", "cookbook_pantry"])
        #expect(viewModel.actions.savedCookbookIDs == ["cookbook_weeknights"])
        #expect(viewModel.actions.shoppingListMetadata == RecipeShoppingListActionMetadata(
            recipeID: recipe.id,
            hasIngredientsInShoppingList: true
        ))
        #expect(viewModel.actions.fork.titleOverride == "Lemon Pantry Pasta, my version")
        #expect(viewModel.actions.fork.label == "Make a variation")
        #expect(viewModel.ownerTools.editRoute == .recipeEditor(id: recipe.id))
        #expect(viewModel.ownerTools.coverControlsRoute == .recipeCoverControls(id: recipe.id))
        #expect(viewModel.ownerTools.deleteConfirmation == RecipeActionConfirmationPrompt(
            title: "Delete Lemon Pantry Pasta?",
            message: "This removes the recipe from your kitchen and syncs the deletion across your devices.",
            confirmButtonTitle: "Delete Recipe",
            isDestructive: true
        ))
    }

    @Test("visitor recipe detail exposes fork but hides owner-only actions")
    func visitorRecipeDetailExposesForkButHidesOwnerActions() throws {
        let recipe = try Self.recipeDetail()
        let viewModel = RecipeDetailScreenViewModel(
            result: RecipeCatalogDetailResult(
                recipe: recipe,
                source: .cache(serverRevision: .updatedAt(recipe.updatedAt), lastValidatedAt: Self.now)
            ),
            context: Self.detailContext(currentChefID: "chef_jules")
        )

        #expect(viewModel.actions.availableActionIDs == [
            .startCooking,
            .saveToCookbook,
            .addToShoppingList,
            .share,
            .fork
        ])
        #expect(viewModel.actions.fork.label == "Fork")
        #expect(viewModel.actions.fork.titleOverride == "Lemon Pantry Pasta")
        #expect(!viewModel.ownerTools.isVisible)
        #expect(viewModel.ownerTools.editRoute == nil)
        #expect(viewModel.ownerTools.coverControlsRoute == nil)
        #expect(viewModel.ownerTools.deleteConfirmation == nil)
    }

    @Test("platform navigation renders native cover controls instead of a placeholder")
    func platformNavigationRendersNativeCoverControls() throws {
        let navigationSource = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
        #expect(navigationSource.contains("RecipeCoverControlsRouteView("))
        #expect(navigationSource.contains("connectivity: recipeCoverControlsConnectivity"))
        #expect(navigationSource.contains("performCoverAction: performCoverAction"))
        #expect(navigationSource.contains("private func performCoverAction(_ plan: RecipeCoverControlsMutationPlan) async throws"))
        #expect(navigationSource.contains("hasQueuedMutation(withDependencyKey: offlineFallbackMutation.dependencyKey)"))
        #expect(navigationSource.contains("queueMutations([offlineFallbackMutation], true)"))
        #expect(!navigationSource.contains("case .recipeCoverControls(let id):\n            ShellPlaceholderView"))

        let coverControlsSource = try readRepoFile("Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift")
        let coverControlsCoreSource = try readRepoFile("Sources/SpoonjoyCore/Features/Covers/RecipeCoverControlsViewModel.swift")
        #expect(coverControlsCoreSource.contains("RecipeCoverRequests.listCovers"))
        #expect(coverControlsCoreSource.contains("includeArchived: true"))
        #expect(coverControlsCoreSource.contains("spoonImages: envelope.data.spoonImages"))
        #expect(coverControlsSource.contains("RecipeCoverControlsData.live"))
        #expect(coverControlsSource.contains("Archive And Replace"))
        #expect(coverControlsSource.contains("replacementOptions(for: cover)"))
        #expect(coverControlsSource.contains("replacementCoverID: option.coverID"))
        #expect(coverControlsSource.contains("confirmNoCover: false"))
        #expect(coverControlsSource.contains("activateWhenReady: false"))
        #expect(coverControlsSource.contains("activate: false"))
        #expect(!coverControlsSource.contains("activateWhenReady: cover.isActive"))
        #expect(!coverControlsCoreSource.contains("activateWhenReady: cover.isActive"))
        #expect(!coverControlsSource.contains("RecipeSpoonRequests.listSpoons"))
    }

    @Test("online recipe actions plan exact REST mutations with offline fallbacks")
    func onlineRecipeActionsPlanExactRESTMutationsWithOfflineFallbacks() throws {
        let recipe = try Self.recipeDetail()
        let viewModel = RecipeActionsViewModel(
            recipe: recipe,
            context: Self.detailContext(currentChefID: "chef_ari"),
            connectivity: .online,
            now: { Self.createdAt }
        )

        let fork = try viewModel.plan(.fork(
            clientMutationID: "cm_fork",
            titleOverride: "Lemon Pantry Pasta, my version"
        ))
        try assertJSONRequest(try remoteRequest(from: fork), method: .post, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/fork", expected: [
            "clientMutationId": "cm_fork",
            "title": "Lemon Pantry Pasta, my version"
        ])
        #expect(fork.queuedMutation == nil)
        let forkFallback = try requireMutation(fork.offlineFallbackMutation, "fork offline fallback")
        #expect(forkFallback.queueableKind == NativeQueuedMutationKind.recipeFork)
        try assertJSONRequest(try queuedRequest(from: forkFallback), method: .post, path: "/api/v1/recipes/recipe_lemon_pantry_pasta/fork", expected: [
            "clientMutationId": "cm_fork",
            "title": "Lemon Pantry Pasta, my version"
        ])

        let save = try viewModel.plan(.saveToCookbook(
            cookbookID: "cookbook_pantry",
            clientMutationID: "cm_save"
        ))
        try assertJSONRequest(try remoteRequest(from: save), method: .post, path: "/api/v1/cookbooks/cookbook_pantry/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_save"
        ])
        #expect(save.queuedMutation == nil)
        let saveFallback = try requireMutation(save.offlineFallbackMutation, "save offline fallback")
        #expect(saveFallback.queueableKind == NativeQueuedMutationKind.cookbookAddRecipe)
        try assertJSONRequest(try queuedRequest(from: saveFallback), method: .post, path: "/api/v1/cookbooks/cookbook_pantry/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_save"
        ])

        let remove = try viewModel.plan(.removeFromCookbook(
            cookbookID: "cookbook_weeknights",
            clientMutationID: "cm_remove"
        ))
        try assertJSONRequest(try remoteRequest(from: remove), method: .delete, path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_remove"
        ])
        #expect(remove.queuedMutation == nil)
        let removeFallback = try requireMutation(remove.offlineFallbackMutation, "remove offline fallback")
        #expect(removeFallback.queueableKind == NativeQueuedMutationKind.cookbookRemoveRecipe)
        try assertJSONRequest(try queuedRequest(from: removeFallback), method: .delete, path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_remove"
        ])

        let delete = try viewModel.plan(.deleteRecipe(
            clientMutationID: "cm_delete_online",
            confirmation: .confirmed
        ))
        let deleteRequest = try remoteRequest(from: delete)
        assertNoBodyRequest(
            deleteRequest,
            method: .delete,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_delete_online")]
        )
        #expect(delete.queuedMutation == nil)
        let deleteFallback = try requireMutation(delete.offlineFallbackMutation, "delete offline fallback")
        #expect(deleteFallback.queueableKind == NativeQueuedMutationKind.recipeDelete)
        let deleteFallbackRequest = try queuedRequest(from: deleteFallback)
        assertNoBodyRequest(
            deleteFallbackRequest,
            method: .delete,
            path: "/api/v1/recipes/recipe_lemon_pantry_pasta",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_delete_online")]
        )

        let duplicateSave = try viewModel.plan(.saveToCookbook(
            cookbookID: "cookbook_weeknights",
            clientMutationID: "cm_duplicate_save"
        ))
        #expect(duplicateSave.blockedReason == "This recipe is already saved in that cookbook.")
        #expect(duplicateSave.remoteRequestBuilder == nil)
        #expect(duplicateSave.queuedMutation == nil)

        let unavailableSave = try viewModel.plan(.saveToCookbook(
            cookbookID: "cookbook_foreign",
            clientMutationID: "cm_foreign_save"
        ))
        #expect(unavailableSave.blockedReason == "Choose one of your cookbooks before saving this recipe.")
        #expect(unavailableSave.remoteRequestBuilder == nil)
        #expect(unavailableSave.queuedMutation == nil)

        let availableButUnsavedRemove = try viewModel.plan(.removeFromCookbook(
            cookbookID: "cookbook_pantry",
            clientMutationID: "cm_unsaved_remove"
        ))
        #expect(availableButUnsavedRemove.blockedReason == "This recipe is not saved in that cookbook.")
        #expect(availableButUnsavedRemove.remoteRequestBuilder == nil)
        #expect(availableButUnsavedRemove.queuedMutation == nil)

        let unavailableRemove = try viewModel.plan(.removeFromCookbook(
            cookbookID: "cookbook_foreign",
            clientMutationID: "cm_foreign_remove"
        ))
        #expect(unavailableRemove.blockedReason == "Choose one of your cookbooks before removing this recipe.")
        #expect(unavailableRemove.remoteRequestBuilder == nil)
        #expect(unavailableRemove.queuedMutation == nil)

        let staleSavedCookbookPlanner = RecipeActionsViewModel(
            recipe: recipe,
            context: Self.detailContext(currentChefID: "chef_ari", savedInCookbookIDs: ["cookbook_foreign"]),
            connectivity: .online,
            now: { Self.createdAt }
        )
        let staleSavedCookbookRemove = try staleSavedCookbookPlanner.plan(.removeFromCookbook(
            cookbookID: "cookbook_foreign",
            clientMutationID: "cm_stale_foreign_remove"
        ))
        #expect(staleSavedCookbookRemove.blockedReason == "Choose one of your cookbooks before removing this recipe.")
        #expect(staleSavedCookbookRemove.remoteRequestBuilder == nil)
        #expect(staleSavedCookbookRemove.queuedMutation == nil)
    }

    @Test("offline actions queue safe mutations and owner delete requires confirmation")
    func offlineActionsQueueSafeMutationsAndOwnerDeleteRequiresConfirmation() throws {
        let recipe = try Self.recipeDetail()
        let owner = RecipeActionsViewModel(
            recipe: recipe,
            context: Self.detailContext(currentChefID: "chef_ari"),
            connectivity: .offline,
            now: { Self.createdAt }
        )

        let queuedSave = try owner.plan(.saveToCookbook(
            cookbookID: "cookbook_pantry",
            clientMutationID: "cm_offline_save"
        ))
        #expect(queuedSave.remoteRequestBuilder == nil)
        let queuedSaveMutation = try requireMutation(queuedSave.queuedMutation, "offline save queued mutation")
        #expect(queuedSaveMutation.queueableKind == NativeQueuedMutationKind.cookbookAddRecipe)
        #expect(queuedSaveMutation.createdAt == Self.createdAt)
        try assertJSONRequest(try queuedRequest(from: queuedSaveMutation), method: .post, path: "/api/v1/cookbooks/cookbook_pantry/recipes/recipe_lemon_pantry_pasta", expected: [
            "clientMutationId": "cm_offline_save"
        ])
        #expect(queuedSave.blockedReason == nil)

        let unconfirmedDelete = try owner.plan(.deleteRecipe(
            clientMutationID: "cm_delete",
            confirmation: .required
        ))
        #expect(unconfirmedDelete.remoteRequestBuilder == nil)
        #expect(unconfirmedDelete.queuedMutation == nil)
        #expect(unconfirmedDelete.confirmationPrompt?.isDestructive == true)

        let confirmedDelete = try owner.plan(.deleteRecipe(
            clientMutationID: "cm_delete",
            confirmation: .confirmed
        ))
        #expect(confirmedDelete.remoteRequestBuilder == nil)
        let confirmedDeleteMutation = try requireMutation(confirmedDelete.queuedMutation, "confirmed delete queued mutation")
        #expect(confirmedDeleteMutation.queueableKind == NativeQueuedMutationKind.recipeDelete)
        #expect(confirmedDeleteMutation.dependencyKey == "recipe:recipe_lemon_pantry_pasta")

        let visitor = RecipeActionsViewModel(
            recipe: recipe,
            context: Self.detailContext(currentChefID: "chef_jules"),
            connectivity: .online,
            now: { Self.createdAt }
        )
        let visitorDelete = try visitor.plan(.deleteRecipe(
            clientMutationID: "cm_visitor_delete",
            confirmation: .confirmed
        ))
        #expect(visitorDelete.blockedReason == "Only ari can delete this recipe.")
        #expect(visitorDelete.remoteRequestBuilder == nil)
        #expect(visitorDelete.queuedMutation == nil)
    }

    private static func detailContext(
        currentChefID: String?,
        savedInCookbookIDs: Set<String> = ["cookbook_weeknights"]
    ) -> RecipeDetailContext {
        RecipeDetailContext(
            currentChefID: currentChefID,
            availableCookbooks: [
                RecipeCookbookSaveOption(id: "cookbook_weeknights", title: "Weeknights"),
                RecipeCookbookSaveOption(id: "cookbook_pantry", title: "Pantry")
            ],
            savedInCookbookIDs: savedInCookbookIDs,
            hasIngredientsInShoppingList: true,
            now: Self.now
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
                "sourceUrl": null,
                "sourceHost": null,
                "sourceRecipe": null
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
                    { "id": "ingredient_spaghetti", "name": "spaghetti", "quantity": 12, "unit": "oz" }
                  ],
                  "usingSteps": []
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
              "recentSpoons": []
            }
          }
        }
        """.utf8
    )
}

private func remoteRequest(from plan: RecipeActionPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw RecipeActionParityTestFailure("Expected an online recipe action to provide a remote request builder.")
    }
    return try builder.urlRequest(configuration: RecipeActionParityTests.configuration)
}

private func queuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: RecipeActionParityTests.configuration)
}

private func requireMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    guard let mutation else {
        throw RecipeActionParityTestFailure("Expected \(label) to provide a native queued mutation.")
    }
    return mutation
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) throws {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems.isEmpty)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token",
        "Content-Type": "application/json"
    ])
    #expect(request.responseCachePolicy == .privateNoStore)
    #expect(NSDictionary(dictionary: try jsonBody(from: request)).isEqual(to: expected))
}

private func assertNoBodyRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    queryItems: [URLQueryItem]
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    #expect(request.headers == [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token"
    ])
    #expect(request.body == nil)
    #expect(request.responseCachePolicy == .privateNoStore)
}

private func jsonBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRootURL().appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func repoRootURL() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private struct RecipeActionParityTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
