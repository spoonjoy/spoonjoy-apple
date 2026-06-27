import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native cookbook surface parity")
struct CookbookSurfaceParityTests {
    private static let now = Date(timeIntervalSince1970: 1_780_120_000)
    private static let staleValidatedAt = Date(timeIntervalSince1970: 1_779_950_000)
    private static let createdAt = "2026-06-27T22:00:00.000Z"
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("cookbook list and detail load live state, share payloads, and owner tools")
    @MainActor
    func cookbookListAndDetailLoadLiveStateSharePayloadsAndOwnerTools() async throws {
        let cookbook = try Self.cookbook()
        let availableRecipe = try Self.availableRecipe()
        let repository = RecordingCookbookSurfaceRepository(
            page: CookbookSurfacePage(
                query: "weeknight",
                limit: 20,
                cursor: nil,
                nextCursor: PaginationCursor(rawValue: "v1.cookbook.next"),
                hasMore: true,
                rows: [CookbookSummary(cookbook: cookbook)],
                source: .live(requestID: "req_cookbook_list", validatedAt: Self.now)
            ),
            detail: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_cookbook_detail", validatedAt: Self.now),
                availableRecipes: [availableRecipe]
            )
        )
        let viewModel = CookbookSurfaceViewModel(
            repository: repository,
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )

        try await viewModel.loadList(query: "  weeknight  ", limit: 20)
        let list = viewModel.list
        #expect(list.query == "weeknight")
        #expect(list.limit == 20)
        #expect(list.nextCursor == PaginationCursor(rawValue: "v1.cookbook.next"))
        #expect(list.hasMore)
        #expect(list.resultCountLabel == "1 cookbook")
        #expect(list.emptyState == nil)
        #expect(list.rows.map(\.id) == ["cookbook_weeknights"])
        #expect(list.rows.first?.title == "Weeknight Brights")
        #expect(list.rows.first?.chefLine == "By ari")
        #expect(list.rows.first?.recipeCountLabel == "2 recipes")
        #expect(list.rows.first?.cover.primaryImageURL?.absoluteString == "https://spoonjoy.app/photos/recipes/recipe_lemon_pantry_pasta/cover.jpg")
        #expect(list.rows.first?.openRoute == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(list.rows.first?.sharePayload?.publicURL?.absoluteString == "https://spoonjoy.app/cookbooks/cookbook_weeknights")
        #expect(list.offlineIndicator.display == .synced)
        #expect(viewModel.openCookbookRoute(id: "cookbook_weeknights") == .cookbookDetail(id: "cookbook_weeknights"))
        #expect(await repository.listRequests == [
            CookbookSurfaceListRequest(query: "weeknight", limit: 20, cursor: nil)
        ])

        try await viewModel.loadDetail(id: "cookbook_weeknights")
        let detail = try #require(viewModel.detail)
        #expect(detail.id == "cookbook_weeknights")
        #expect(detail.title == "Weeknight Brights")
        #expect(detail.chefLine == "By ari")
        #expect(detail.recipeCountLabel == "2 recipes")
        #expect(detail.sharePayload.publicURL?.absoluteString == "https://spoonjoy.app/cookbooks/cookbook_weeknights")
        #expect(detail.recipes.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_soup"])
        #expect(detail.recipes.map(\.openRoute) == [
            .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail),
            .recipeDetail(id: "recipe_tomato_soup", presentation: .detail)
        ])
        #expect(detail.recipes.first?.servingsLabel == "Serves 4")
        #expect(detail.recipes.first?.coverProvenanceLabel == "Chef photo")
        #expect(detail.ownerTools.isVisible)
        #expect(detail.ownerTools.availableRecipes.map(\.id) == ["recipe_unsaved_flatbread"])
        #expect(detail.ownerTools.editTitleActionTitle == "Edit title")
        #expect(detail.ownerTools.addRecipeActionTitle == "Add recipe")
        #expect(detail.ownerTools.deleteConfirmation == CookbookActionConfirmationPrompt(
            title: "Delete Weeknight Brights?",
            message: "This permanently deletes the cookbook and removes its recipe associations. Recipes stay in your kitchen.",
            confirmButtonTitle: "Delete Cookbook",
            isDestructive: true
        ))
        #expect(detail.offlineIndicator.display == .synced)
        #expect(await repository.detailRequests == ["cookbook_weeknights"])

        let visitor = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_visitor", validatedAt: Self.now),
                availableRecipes: [availableRecipe]
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_jules"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(visitor.ownerTools.isVisible == false)
        #expect(visitor.availableActionIDs == [.share])
    }

    @Test("cookbook cache restore and queued work expose honest offline states")
    func cookbookCacheRestoreAndQueuedWorkExposeHonestOfflineStates() throws {
        let cookbook = try Self.cookbook()
        let queuedRename = NativeQueuedMutation.cookbookUpdate(
            cookbookID: cookbook.id,
            title: "Dinner Parties",
            clientMutationID: "cm_cookbook_rename",
            createdAt: Self.createdAt
        )
        let conflict = NativeSyncConflict(
            clientMutationID: "cm_cookbook_rename",
            kind: .validation,
            serverRevision: .updatedAt("2026-06-27T21:55:00.000Z"),
            message: "Cookbook changed elsewhere."
        )

        let detail = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .cache(
                    serverRevision: .updatedAt(cookbook.updatedAt),
                    lastValidatedAt: Self.staleValidatedAt
                ),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [queuedRename],
            conflicts: [conflict],
            connectivity: .offline,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )

        #expect(detail.offlineIndicator.display == .conflict(
            recordID: "cm_cookbook_rename",
            mutationID: "cm_cookbook_rename"
        ))
        #expect(detail.queuedWorkSummary == "1 cookbook change waiting to sync")
        #expect(detail.conflictBanner == CookbookSurfaceConflictBanner(
            localClientMutationID: "cm_cookbook_rename",
            message: "Cookbook changed elsewhere.",
            actionTitle: "Review cookbook conflict"
        ))

        let emptyList = CookbookSurfaceListViewModel(
            page: CookbookSurfacePage(
                query: nil,
                limit: 20,
                cursor: nil,
                nextCursor: nil,
                hasMore: false,
                rows: [],
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt)
            ),
            now: { Self.now }
        )
        #expect(emptyList.list.emptyState == CookbookSurfaceEmptyState(
            title: "No cookbooks yet",
            message: "Create a cookbook to collect recipes into a kitchen-ready set.",
            systemImage: "books.vertical"
        ))
        #expect(emptyList.list.offlineIndicator.display == .stale(domain: .cookbookList))

        let searchEmpty = CookbookSurfaceListViewModel(
            page: CookbookSurfacePage(
                query: "winter",
                limit: 20,
                cursor: nil,
                nextCursor: nil,
                hasMore: false,
                rows: [],
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt)
            ),
            now: { Self.now }
        )
        #expect(searchEmpty.list.emptyState == CookbookSurfaceEmptyState(
            title: "No matching cookbooks",
            message: "Try another title, chef, or recipe in the collection.",
            systemImage: "magnifyingglass"
        ))
    }

    @Test("cookbook actions plan exact REST mutations with offline fallbacks and confirmations")
    func cookbookActionsPlanExactRESTMutationsWithOfflineFallbacksAndConfirmations() throws {
        let cookbook = try Self.cookbook()
        let viewModel = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_cookbook_detail", validatedAt: Self.now),
                availableRecipes: [try Self.availableRecipe()]
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )

        let create = try viewModel.plan(.create(title: "  Spring Lunches  ", clientMutationID: "cm_cookbook_create"))
        try assertCookbookJSONRequest(
            try cookbookRemoteRequest(from: create),
            method: .post,
            path: "/api/v1/cookbooks",
            expected: [
                "clientMutationId": "cm_cookbook_create",
                "title": "Spring Lunches"
            ]
        )
        let createFallback = try requireCookbookMutation(create.offlineFallbackMutation, "create fallback")
        assertCookbookMutationMetadata(
            createFallback,
            kind: .cookbookCreate,
            clientMutationID: "cm_cookbook_create",
            createdAt: Self.createdAt
        )

        let rename = try viewModel.plan(.rename(title: "  Dinner Parties  ", clientMutationID: "cm_cookbook_rename"))
        try assertCookbookJSONRequest(
            try cookbookRemoteRequest(from: rename),
            method: .patch,
            path: "/api/v1/cookbooks/cookbook_weeknights",
            expected: [
                "clientMutationId": "cm_cookbook_rename",
                "title": "Dinner Parties"
            ]
        )
        #expect(rename.updatedCookbook?.title == "Dinner Parties")
        let renameFallback = try requireCookbookMutation(rename.offlineFallbackMutation, "rename fallback")
        assertCookbookMutationMetadata(
            renameFallback,
            kind: .cookbookUpdate,
            clientMutationID: "cm_cookbook_rename",
            createdAt: Self.createdAt
        )

        let deletePrompt = try viewModel.plan(.deleteCookbook(clientMutationID: "cm_cookbook_delete", confirmation: .required))
        #expect(deletePrompt.remoteRequestBuilder == nil)
        #expect(deletePrompt.queuedMutation == nil)
        #expect(deletePrompt.confirmationPrompt == CookbookActionConfirmationPrompt(
            title: "Delete Weeknight Brights?",
            message: "This permanently deletes the cookbook and removes its recipe associations. Recipes stay in your kitchen.",
            confirmButtonTitle: "Delete Cookbook",
            isDestructive: true
        ))
        let delete = try viewModel.plan(.deleteCookbook(clientMutationID: "cm_cookbook_delete", confirmation: .confirmed))
        assertCookbookNoBodyRequest(
            try cookbookRemoteRequest(from: delete),
            method: .delete,
            path: "/api/v1/cookbooks/cookbook_weeknights",
            queryItems: [URLQueryItem(name: "clientMutationId", value: "cm_cookbook_delete")]
        )
        #expect(delete.successRoute == .cookbooks)
        let deleteFallback = try requireCookbookMutation(delete.offlineFallbackMutation, "delete fallback")
        assertCookbookMutationMetadata(
            deleteFallback,
            kind: .cookbookDelete,
            clientMutationID: "cm_cookbook_delete",
            createdAt: Self.createdAt
        )

        let add = try viewModel.plan(.addRecipe(recipeID: "recipe_unsaved_flatbread", clientMutationID: "cm_cookbook_add"))
        try assertCookbookJSONRequest(
            try cookbookRemoteRequest(from: add),
            method: .post,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_unsaved_flatbread",
            expected: ["clientMutationId": "cm_cookbook_add"]
        )
        #expect(add.updatedCookbook?.recipes.map(\.id).contains("recipe_unsaved_flatbread") == true)
        let addFallback = try requireCookbookMutation(add.offlineFallbackMutation, "add fallback")
        assertCookbookMutationMetadata(
            addFallback,
            kind: .cookbookAddRecipe,
            clientMutationID: "cm_cookbook_add",
            createdAt: Self.createdAt
        )

        let removePrompt = try viewModel.plan(.removeRecipe(recipeID: "recipe_lemon_pantry_pasta", clientMutationID: "cm_cookbook_remove", confirmation: .required))
        #expect(removePrompt.confirmationPrompt == CookbookActionConfirmationPrompt(
            title: "Remove Lemon Pantry Pasta?",
            message: "This removes the recipe from this cookbook. The recipe itself stays in your kitchen.",
            confirmButtonTitle: "Remove Recipe",
            isDestructive: true
        ))
        let remove = try viewModel.plan(.removeRecipe(recipeID: "recipe_lemon_pantry_pasta", clientMutationID: "cm_cookbook_remove", confirmation: .confirmed))
        try assertCookbookJSONRequest(
            try cookbookRemoteRequest(from: remove),
            method: .delete,
            path: "/api/v1/cookbooks/cookbook_weeknights/recipes/recipe_lemon_pantry_pasta",
            expected: ["clientMutationId": "cm_cookbook_remove"]
        )
        #expect(remove.updatedCookbook?.recipes.map(\.id) == ["recipe_tomato_soup"])
        let removeFallback = try requireCookbookMutation(remove.offlineFallbackMutation, "remove fallback")
        assertCookbookMutationMetadata(
            removeFallback,
            kind: .cookbookRemoveRecipe,
            clientMutationID: "cm_cookbook_remove",
            createdAt: Self.createdAt
        )
    }

    @Test("cookbook action edges block non owners duplicates and dependent queue bypasses")
    func cookbookActionEdgesBlockNonOwnersDuplicatesAndDependentQueueBypasses() throws {
        let cookbook = try Self.cookbook()
        let visitor = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_visitor", validatedAt: Self.now),
                availableRecipes: [try Self.availableRecipe()]
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_jules"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(try visitor.plan(.rename(title: "New", clientMutationID: "cm_blocked")).blockedReason == "Only ari can edit this cookbook.")
        #expect(try visitor.plan(.deleteCookbook(clientMutationID: "cm_blocked_delete", confirmation: .confirmed)).blockedReason == "Only ari can delete this cookbook.")

        let owner = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_owner", validatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [
                NativeQueuedMutation.cookbookUpdate(
                    cookbookID: cookbook.id,
                    title: "Queued Title",
                    clientMutationID: "cm_pending_rename",
                    createdAt: Self.createdAt
                )
            ],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(try owner.plan(.addRecipe(recipeID: "recipe_lemon_pantry_pasta", clientMutationID: "cm_duplicate_add")).blockedReason == "This recipe is already in the cookbook.")
        #expect(try owner.plan(.addRecipe(recipeID: "recipe_missing", clientMutationID: "cm_missing_add")).blockedReason == "Choose one of your recipes before adding it.")

        let queuedRename = try owner.plan(.rename(title: "Queued Behind Existing Work", clientMutationID: "cm_queued_rename"))
        #expect(queuedRename.remoteRequestBuilder == nil)
        let queuedMutation = try requireCookbookMutation(queuedRename.queuedMutation, "queued rename behind pending cookbook work")
        assertCookbookMutationMetadata(
            queuedMutation,
            kind: .cookbookUpdate,
            clientMutationID: "cm_queued_rename",
            createdAt: Self.createdAt
        )
    }

    private static func cookbook() throws -> Cookbook {
        try CookbookFixtureCatalog.decodeFromBundle().cookbooks[0]
    }

    private static func availableRecipe() throws -> RecipeSummary {
        var recipe = try RecipeFixtureCatalog.decodeFromBundle().recipes[1]
        recipe = Recipe(
            id: "recipe_unsaved_flatbread",
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/recipe_unsaved_flatbread",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/recipe_unsaved_flatbread")),
            attribution: recipe.attribution,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            steps: recipe.steps,
            cookbooks: [],
            recentSpoons: []
        )
        return RecipeSummary(recipe: recipe)
    }
}

private actor RecordingCookbookSurfaceRepository: CookbookSurfaceRepository {
    private let page: CookbookSurfacePage
    private let detail: CookbookSurfaceDetailResult
    private var requests: [CookbookSurfaceListRequest] = []
    private var detailIDs: [String] = []

    init(page: CookbookSurfacePage, detail: CookbookSurfaceDetailResult) {
        self.page = page
        self.detail = detail
    }

    var listRequests: [CookbookSurfaceListRequest] {
        requests
    }

    var detailRequests: [String] {
        detailIDs
    }

    func listCookbooks(request: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage {
        requests.append(request)
        return page
    }

    func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult {
        detailIDs.append(id)
        return detail
    }
}

private func cookbookRemoteRequest(from plan: CookbookSurfaceActionPlan) throws -> APIRequest {
    try #require(plan.remoteRequestBuilder).urlRequest(configuration: CookbookSurfaceParityTests.configuration)
}

private func cookbookQueuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: CookbookSurfaceParityTests.configuration)
}

private func requireCookbookMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    try #require(mutation, Comment(rawValue: "missing \(label)"))
}

private func assertCookbookMutationMetadata(
    _ mutation: NativeQueuedMutation,
    kind: NativeQueuedMutationKind,
    clientMutationID: String,
    createdAt: String
) {
    #expect(mutation.queueableKind == kind)
    #expect(mutation.clientMutationID == clientMutationID)
    #expect(mutation.createdAt == createdAt)
}

private func assertCookbookJSONRequest(
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

private func assertCookbookNoBodyRequest(
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
    let object = try JSONSerialization.jsonObject(with: body)
    return try #require(object as? [String: Any])
}
