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

        #expect(viewModel.canCreateCookbook)
        let listCreate = try viewModel.planCreate(title: "  Spring Lunches  ", clientMutationID: "cm_list_cookbook_create")
        #expect(listCreate.updatedCookbook?.id == "cookbook_local_cm_list_cookbook_create")
        #expect(listCreate.updatedCookbook?.title == "Spring Lunches")
        #expect(listCreate.updatedCookbook?.chef.username == "Spoonjoy")
        try assertCookbookJSONRequest(
            try cookbookRemoteRequest(from: listCreate),
            method: .post,
            path: "/api/v1/cookbooks",
            expected: [
                "clientMutationId": "cm_list_cookbook_create",
                "title": "Spring Lunches"
            ]
        )
        #expect(listCreate.offlineFallbackMutation?.queueableKind == .cookbookCreate)

        try await viewModel.loadList(query: "  weeknight  ", limit: 20)
        let list = viewModel.list
        #expect(list.query == "weeknight")
        #expect(list.limit == 20)
        #expect(list.nextCursor == PaginationCursor(rawValue: "v1.cookbook.next"))
        #expect(list.hasMore)
        #expect(list.resultCountLabel == "1 cookbook")
        #expect(list.emptyState == nil)
        #expect(list.rows.map(\.id) == ["cookbook_weeknights"])
        #expect(list.rows.first?.title == "Weeknights")
        #expect(list.rows.first?.chefLine == "By ari")
        #expect(list.rows.first?.recipeCountLabel == "2 recipes")
        #expect(list.rows.first?.cover.primaryImageURL == nil)
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
        #expect(detail.title == "Weeknights")
        #expect(detail.chefLine == "By ari")
        #expect(detail.recipeCountLabel == "2 recipes")
        #expect(detail.sharePayload.publicURL?.absoluteString == "https://spoonjoy.app/cookbooks/cookbook_weeknights")
        #expect(detail.recipes.map(\.id) == ["recipe_lemon_pantry_pasta", "recipe_tomato_toast"])
        #expect(detail.recipes.map(\.openRoute) == [
            .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail),
            .recipeDetail(id: "recipe_tomato_toast", presentation: .detail)
        ])
        #expect(detail.recipes.first?.servingsLabel == "Serves 4")
        #expect(detail.recipes.first?.coverProvenanceLabel == "Chef photo")
        #expect(detail.ownerTools.isVisible)
        #expect(detail.ownerTools.availableRecipes.map(\.id) == ["recipe_unsaved_flatbread"])
        #expect(detail.ownerTools.editTitleActionTitle == "Edit title")
        #expect(detail.ownerTools.addRecipeActionTitle == "Add recipe")
        #expect(detail.ownerTools.deleteConfirmation == CookbookActionConfirmationPrompt(
            title: "Delete Weeknights?",
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

        let freshCachedDetail = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .cache(serverRevision: .updatedAt(cookbook.updatedAt), lastValidatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(freshCachedDetail.offlineIndicator.display == .synced)

        let offlineDetail = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_cookbook_detail", validatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(offlineDetail.offlineIndicator.display == .offline)

        let invalidRecordIndicator = CookbookSurfacePage.offlineIndicator(
            domain: .cookbookList,
            payload: .recipeCatalog(recipeIDs: ["recipe_lemon_pantry_pasta"]),
            serverRevision: nil,
            lastValidatedAt: Self.now,
            now: Self.now,
            freshnessPolicy: .offlineProductContract
        )
        #expect(invalidRecordIndicator.display == .stale(domain: .cookbookList))
        let unrelatedDomainIndicator = CookbookSurfacePage.offlineIndicator(
            domain: .recipeCatalog,
            payload: .recipeCatalog(recipeIDs: ["recipe_lemon_pantry_pasta"]),
            serverRevision: nil,
            lastValidatedAt: Self.now,
            now: Self.now,
            freshnessPolicy: .offlineProductContract
        )
        #expect(unrelatedDomainIndicator.display == .synced)
    }

    @Test("cookbook repositories cover live snapshot fallback and list application edges")
    @MainActor
    func cookbookRepositoriesCoverLiveSnapshotFallbackAndListApplicationEdges() async throws {
        let cookbook = try Self.cookbook()
        let savedRecipe = cookbook.recipes[0]
        let availableRecipe = try Self.availableRecipe()
        let secondCookbook = try Self.cookbook(
            id: "cookbook_brunch",
            title: "Brunch",
            recipes: [availableRecipe]
        )
        let listEnvelope = APIEnvelope(
            requestID: "req_live_cookbooks",
            data: CookbookListData(
                query: nil,
                limit: 1,
                cursor: PaginationCursor(rawValue: "v1.before"),
                nextCursor: PaginationCursor(rawValue: "v1.after"),
                hasMore: true,
                cookbooks: [CookbookSummary(cookbook: cookbook)]
            )
        )
        let detailEnvelope = APIEnvelope(
            requestID: "req_live_cookbook_detail",
            data: CookbookDetailData(cookbook: cookbook)
        )
        let transport = RecordingCookbookAPITransport(
            listEnvelope: listEnvelope,
            detailEnvelope: detailEnvelope
        )
        let liveRepository = LiveCookbookSurfaceRepository(
            transport: transport,
            configuration: Self.configuration,
            availableRecipes: [savedRecipe, availableRecipe],
            now: { Self.now }
        )
        let defaultClockRepository = LiveCookbookSurfaceRepository(
            transport: transport,
            configuration: Self.configuration
        )

        let livePage = try await liveRepository.listCookbooks(
            request: CookbookSurfaceListRequest(
                query: "   ",
                limit: 1,
                cursor: PaginationCursor(rawValue: "v1.before")
            )
        )
        let liveDetail = try await liveRepository.cookbookDetail(id: cookbook.id)
        #expect(livePage.rows.map(\.id) == [cookbook.id])
        #expect(livePage.source == .live(requestID: "req_live_cookbooks", validatedAt: Self.now))
        #expect(liveDetail.availableRecipes.map(\.id) == [availableRecipe.id])
        let defaultClockPage = try await defaultClockRepository.listCookbooks(
            request: CookbookSurfaceListRequest(query: nil, limit: 1)
        )
        if case .live(let requestID, _) = defaultClockPage.source {
            #expect(requestID == "req_live_cookbooks")
        } else {
            Issue.record("default clock live repository should still return live source")
        }
        #expect(transport.requests.map(\.url.path) == [
            "/api/v1/cookbooks",
            "/api/v1/cookbooks/\(cookbook.id)",
            "/api/v1/cookbooks"
        ])
        #expect(transport.requests.first?.queryItems == [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "cursor", value: "v1.before")
        ])

        let snapshotRepository = SnapshotCookbookSurfaceRepository(
            page: CookbookSurfacePage(
                query: nil,
                limit: 20,
                cursor: nil,
                nextCursor: nil,
                hasMore: false,
                rows: [CookbookSummary(cookbook: secondCookbook), CookbookSummary(cookbook: cookbook)],
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt)
            ),
            details: [
                CookbookSurfaceDetailResult(cookbook: cookbook, source: .live(requestID: "req_snapshot", validatedAt: Self.now), availableRecipes: []),
                CookbookSurfaceDetailResult(cookbook: secondCookbook, source: .live(requestID: "req_snapshot_2", validatedAt: Self.now), availableRecipes: [])
            ]
        )
        let unfilteredSnapshot = try await snapshotRepository.listCookbooks(
            request: CookbookSurfaceListRequest(query: nil, limit: 1)
        )
        let chefFilteredSnapshot = try await snapshotRepository.listCookbooks(
            request: CookbookSurfaceListRequest(query: " ARI ", limit: 10)
        )
        let titleFilteredSnapshot = try await snapshotRepository.listCookbooks(
            request: CookbookSurfaceListRequest(query: "brunch", limit: 10)
        )
        #expect(unfilteredSnapshot.hasMore)
        #expect(unfilteredSnapshot.rows.map(\.id) == ["cookbook_brunch"])
        #expect(chefFilteredSnapshot.rows.map(\.id).sorted() == ["cookbook_brunch", "cookbook_weeknights"])
        #expect(titleFilteredSnapshot.rows.map(\.id) == ["cookbook_brunch"])
        #expect(try await snapshotRepository.cookbookDetail(id: "cookbook_brunch").cookbook.title == "Brunch")
        do {
            _ = try await snapshotRepository.cookbookDetail(id: "cookbook_missing")
            Issue.record("missing cookbook detail should throw")
        } catch CookbookSurfaceRepositoryError.cookbookNotFound(let id) {
            #expect(id == "cookbook_missing")
        }

        let fallbackRepository = FallbackCookbookSurfaceRepository(
            primary: FailingCookbookSurfaceRepository(),
            fallback: snapshotRepository
        )
        #expect(try await fallbackRepository.listCookbooks(request: CookbookSurfaceListRequest(query: "brunch", limit: 10)).rows.map(\.id) == ["cookbook_brunch"])
        #expect(try await fallbackRepository.cookbookDetail(id: cookbook.id).cookbook.id == cookbook.id)

        let defaultListViewModel = CookbookSurfaceListViewModel(page: unfilteredSnapshot)
        #expect(defaultListViewModel.list.resultCountLabel == "1 cookbook")
        let listViewModel = CookbookSurfaceViewModel(
            repository: snapshotRepository,
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            timestamp: { Self.createdAt }
        )
        let twoCookbookPage = CookbookSurfacePage(
            query: nil,
            limit: 20,
            cursor: nil,
            nextCursor: nil,
            hasMore: false,
            rows: [CookbookSummary(cookbook: cookbook), CookbookSummary(cookbook: secondCookbook)],
            source: .live(requestID: "req_apply", validatedAt: Self.now)
        )
        listViewModel.apply(page: twoCookbookPage)
        #expect(listViewModel.list.resultCountLabel == "2 cookbooks")
        let queuedCreate = NativeQueuedMutation.cookbookCreate(
            clientMutationID: "cm_created_list",
            title: "After School",
            createdAt: Self.createdAt
        )
        let appliedList = listViewModel.list.applyingCreatedCookbook(
            try Self.cookbook(id: "cookbook_after_school", title: "After School"),
            queuedMutation: queuedCreate
        )
        let appliedWithoutQueue = listViewModel.list.applyingCreatedCookbook(
            try Self.cookbook(id: "cookbook_breakfast", title: "Breakfast"),
            queuedMutation: nil
        )
        #expect(appliedList.rows.map(\.title) == ["After School", "Brunch", "Weeknights"])
        #expect(appliedList.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_created_list"))
        #expect(appliedWithoutQueue.offlineIndicator.display == .synced)
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
        let renamedDetail = viewModel.applying(updatedCookbook: try #require(rename.updatedCookbook))
        #expect(renamedDetail.title == "Dinner Parties")
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
            title: "Delete Weeknights?",
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
        let addedDetail = viewModel.applying(updatedCookbook: try #require(add.updatedCookbook))
        #expect(addedDetail.recipes.map(\.id).contains("recipe_unsaved_flatbread"))
        #expect(!addedDetail.ownerTools.availableRecipes.map(\.id).contains("recipe_unsaved_flatbread"))
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
        #expect(remove.updatedCookbook?.recipes.map(\.id) == ["recipe_tomato_toast"])
        let removedDetail = viewModel.applying(updatedCookbook: try #require(remove.updatedCookbook))
        #expect(removedDetail.recipes.map(\.id) == ["recipe_tomato_toast"])
        #expect(removedDetail.ownerTools.availableRecipes.map(\.id).contains("recipe_lemon_pantry_pasta"))
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
        #expect(try visitor.plan(.addRecipe(recipeID: "recipe_unsaved_flatbread", clientMutationID: "cm_blocked_add")).blockedReason == "Only ari can edit this cookbook.")
        #expect(try visitor.plan(.removeRecipe(recipeID: "recipe_lemon_pantry_pasta", clientMutationID: "cm_blocked_remove", confirmation: .confirmed)).blockedReason == "Only ari can edit this cookbook.")

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
        let queuedApplied = owner.applying(
            updatedCookbook: try #require(queuedRename.updatedCookbook),
            queuedMutation: queuedMutation
        )
        #expect(queuedApplied.title == "Queued Behind Existing Work")
        #expect(queuedApplied.queuedWorkSummary == "2 cookbook changes waiting to sync")
        #expect(queuedApplied.offlineIndicator.display == .queuedWork(count: 2, oldestClientMutationID: "cm_pending_rename"))

        let unrelatedQueued = NativeQueuedMutation.cookbookUpdate(
            cookbookID: "cookbook_other",
            title: "Other Queued Title",
            clientMutationID: "cm_other_rename",
            createdAt: Self.createdAt
        )
        let unrelatedConflict = NativeSyncConflict(
            clientMutationID: "cm_other_rename",
            kind: .validation,
            serverRevision: .updatedAt("2026-06-27T21:59:00.000Z"),
            message: "Other cookbook changed elsewhere."
        )
        let scopedOwner = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_owner_scoped", validatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [unrelatedQueued],
            conflicts: [unrelatedConflict],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(scopedOwner.queuedWorkSummary == nil)
        #expect(scopedOwner.conflictBanner == nil)
        #expect(scopedOwner.offlineIndicator.display == .synced)
        let scopedRename = try scopedOwner.plan(.rename(title: "Independent Title", clientMutationID: "cm_scoped_rename"))
        #expect(scopedRename.remoteRequestBuilder != nil)
        #expect(scopedRename.queuedMutation == nil)

        let localCreate = NativeQueuedMutation.cookbookCreate(
            clientMutationID: "cm_local_create",
            title: "Offline Binder",
            createdAt: Self.createdAt
        )
        let localCookbook = Cookbook(
            id: "cookbook_local_cm_local_create",
            title: "Offline Binder",
            chef: cookbook.chef,
            recipeCount: 0,
            cover: CookbookCover(imageURLs: []),
            href: "/cookbooks/cookbook_local_cm_local_create",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_local_cm_local_create")),
            attribution: CookbookAttribution(
                creditText: "Offline Binder by ari on Spoonjoy",
                canonicalURL: try #require(URL(string: "https://spoonjoy.app/cookbooks/cookbook_local_cm_local_create"))
            ),
            createdAt: Self.createdAt,
            updatedAt: Self.createdAt,
            recipes: []
        )
        let localOwner = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: localCookbook,
                source: .cache(serverRevision: nil, lastValidatedAt: Self.staleValidatedAt),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [localCreate],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        let localRename = try localOwner.plan(.rename(title: "Offline Binder Edited", clientMutationID: "cm_local_rename"))
        #expect(localOwner.queuedWorkSummary == "1 cookbook change waiting to sync")
        #expect(localOwner.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_local_create"))
        #expect(localRename.remoteRequestBuilder == nil)
        #expect(localRename.queuedMutation?.dependencyKey == "cookbook:cookbook_local_cm_local_create")

        let independentCreate = try CookbookCreatePlanner(
            currentChefID: "chef_ari",
            currentChef: ChefSummary(id: "chef_ari", username: "ari"),
            queuedMutations: [unrelatedQueued],
            connectivity: .online,
            timestamp: { Self.createdAt }
        ).planCreate(title: "Independent Cookbook", clientMutationID: "cm_independent_create")
        #expect(independentCreate.remoteRequestBuilder != nil)
        #expect(independentCreate.queuedMutation == nil)
        #expect(independentCreate.updatedCookbook?.chef.username == "ari")

        let signedOutCreate = try CookbookCreatePlanner(
            currentChefID: nil,
            queuedMutations: [],
            connectivity: .online,
            timestamp: { Self.createdAt }
        ).planCreate(title: "New", clientMutationID: "cm_signed_out_create")
        #expect(signedOutCreate.blockedReason == "Sign in to create a cookbook.")
        let blankCreate = try CookbookCreatePlanner(
            currentChefID: "chef_ari",
            queuedMutations: [],
            connectivity: .online,
            timestamp: { Self.createdAt }
        ).planCreate(title: "   ", clientMutationID: "cm_blank_create")
        #expect(blankCreate.blockedReason == "Enter a cookbook title.")
        let pendingCreate = NativeQueuedMutation.cookbookCreate(
            clientMutationID: "cm_pending_create",
            title: "Pending",
            createdAt: Self.createdAt
        )
        let queuedCreate = try CookbookCreatePlanner(
            currentChefID: "chef_ari",
            queuedMutations: [pendingCreate],
            connectivity: .online,
            timestamp: { Self.createdAt }
        ).planCreate(title: "Pending Again", clientMutationID: "cm_pending_create")
        #expect(queuedCreate.remoteRequestBuilder == nil)
        #expect(queuedCreate.queuedMutation?.clientMutationID == "cm_pending_create")
        let offlineCreate = try CookbookCreatePlanner(
            currentChefID: "chef_ari",
            queuedMutations: [],
            connectivity: .offline,
            timestamp: { Self.createdAt }
        ).planCreate(title: "Offline New", clientMutationID: "cm_offline_create")
        #expect(offlineCreate.remoteRequestBuilder == nil)
        #expect(offlineCreate.queuedMutation?.queueableKind == .cookbookCreate)

        let offlineOwner = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_offline_owner", validatedAt: Self.now),
                availableRecipes: [try Self.availableRecipe()]
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        let offlineRename = try offlineOwner.plan(.rename(title: "Offline Dinner", clientMutationID: "cm_offline_rename"))
        #expect(offlineRename.remoteRequestBuilder == nil)
        #expect(offlineRename.queuedMutation?.queueableKind == .cookbookUpdate)
        #expect(try offlineOwner.plan(.create(title: "New", clientMutationID: "cm_detail_create")).queuedMutation?.queueableKind == .cookbookCreate)
        #expect(try offlineOwner.plan(.create(title: "   ", clientMutationID: "cm_detail_blank")).blockedReason == "Enter a cookbook title.")
        #expect(try offlineOwner.plan(.rename(title: "   ", clientMutationID: "cm_blank_rename")).blockedReason == "Enter a cookbook title.")
        #expect(try offlineOwner.plan(.removeRecipe(recipeID: "recipe_missing", clientMutationID: "cm_missing_remove", confirmation: .confirmed)).blockedReason == "This recipe is not in the cookbook.")

        let signedOutDetail = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: cookbook,
                source: .live(requestID: "req_signed_out_detail", validatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: nil),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(try signedOutDetail.plan(.create(title: "New", clientMutationID: "cm_detail_signed_out")).blockedReason == "Sign in to create a cookbook.")

        let noServingRecipe = try Self.recipeSummary(id: "recipe_no_servings", title: "No Servings", servings: nil)
        let noServingRow = CookbookRecipeRowViewModel(summary: noServingRecipe)
        #expect(noServingRow.servingsLabel == nil)

        let offsiteCookbook = Cookbook(
            id: "cookbook_offsite",
            title: "Offsite",
            chef: cookbook.chef,
            recipeCount: 0,
            cover: cookbook.cover,
            href: "/cookbooks/cookbook_offsite",
            canonicalURL: try #require(URL(string: "https://example.com/cookbooks/cookbook_offsite")),
            attribution: CookbookAttribution(
                creditText: "Offsite by ari",
                canonicalURL: try #require(URL(string: "https://example.com/cookbooks/cookbook_offsite"))
            ),
            createdAt: cookbook.createdAt,
            updatedAt: cookbook.updatedAt,
            recipes: []
        )
        let fallbackShare = CookbookDetailViewModel(
            result: CookbookSurfaceDetailResult(
                cookbook: offsiteCookbook,
                source: .live(requestID: "req_offsite", validatedAt: Self.now),
                availableRecipes: []
            ),
            context: CookbookSurfaceContext(currentChefID: "chef_ari"),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.now },
            timestamp: { Self.createdAt }
        )
        #expect(fallbackShare.sharePayload.publicURL?.absoluteString == "https://spoonjoy.app/cookbooks/cookbook_offsite")
    }

    private static func cookbook() throws -> Cookbook {
        try CookbookFixtureCatalog.decodeFromBundle().cookbooks[0]
    }

    private static func cookbook(id: String, title: String, recipes: [RecipeSummary] = []) throws -> Cookbook {
        let base = try cookbook()
        let canonicalURL = try #require(URL(string: "https://spoonjoy.app/cookbooks/\(id)"))
        return Cookbook(
            id: id,
            title: title,
            chef: base.chef,
            recipeCount: recipes.count,
            cover: base.cover,
            href: "/cookbooks/\(id)",
            canonicalURL: canonicalURL,
            attribution: CookbookAttribution(
                creditText: "\(title) by \(base.chef.username) on Spoonjoy",
                canonicalURL: canonicalURL
            ),
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            recipes: recipes
        )
    }

    private static func availableRecipe() throws -> RecipeSummary {
        try recipeSummary(id: "recipe_unsaved_flatbread", title: nil, servings: nil)
    }

    private static func recipeSummary(id: String, title: String?, servings: String?) throws -> RecipeSummary {
        var recipe = try RecipeFixtureCatalog.decodeFromBundle().recipes[1]
        recipe = Recipe(
            id: id,
            title: title ?? recipe.title,
            description: recipe.description,
            servings: servings,
            chef: recipe.chef,
            coverImageURL: recipe.coverImageURL,
            coverProvenanceLabel: recipe.coverProvenanceLabel,
            coverSourceType: recipe.coverSourceType,
            coverVariant: recipe.coverVariant,
            href: "/recipes/\(id)",
            canonicalURL: try #require(URL(string: "https://spoonjoy.app/recipes/\(id)")),
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

private struct FailingCookbookSurfaceRepository: CookbookSurfaceRepository {
    func listCookbooks(request _: CookbookSurfaceListRequest) async throws -> CookbookSurfacePage {
        throw CookbookSurfaceRepositoryError.cookbookNotFound("list")
    }

    func cookbookDetail(id: String) async throws -> CookbookSurfaceDetailResult {
        throw CookbookSurfaceRepositoryError.cookbookNotFound(id)
    }
}

private enum RecordingCookbookAPITransportError: Error, Equatable {
    case unsupportedValueType(String)
}

private final class RecordingCookbookAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let listEnvelope: APIEnvelope<CookbookListData>
    private let detailEnvelope: APIEnvelope<CookbookDetailData>
    private var sentRequests: [APIRequest] = []

    init(
        listEnvelope: APIEnvelope<CookbookListData>,
        detailEnvelope: APIEnvelope<CookbookDetailData>
    ) {
        self.listEnvelope = listEnvelope
        self.detailEnvelope = detailEnvelope
    }

    var requests: [APIRequest] {
        sentRequests
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let builtRequest = try request.urlRequest(configuration: configuration)
        sentRequests.append(builtRequest)

        if valueType == CookbookListData.self {
            return listEnvelope as! APIEnvelope<Value>
        }
        if valueType == CookbookDetailData.self {
            return detailEnvelope as! APIEnvelope<Value>
        }
        throw RecordingCookbookAPITransportError.unsupportedValueType(String(describing: valueType))
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
