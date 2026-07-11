import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native shopping surface parity")
struct ShoppingSurfaceParityTests {
    private static let createdAt = "2026-06-26T02:00:00.000Z"
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("shopping surface loads live state and exposes queued, conflict, and empty affordances")
    func shoppingSurfaceLoadsLiveStateAndExposesQueueConflictAndEmptyAffordances() async throws {
        let repository = RecordingShoppingSurfaceRepository(shoppingList: try Self.shoppingList())
        let queued = [
            NativeQueuedMutation.shoppingAddItem(
                name: "limes",
                quantity: 4,
                unit: "each",
                categoryKey: "produce",
                iconKey: "lemon",
                clientMutationID: "cm_add_limes",
                createdAt: Self.createdAt
            ),
            NativeQueuedMutation.shoppingCheckItem(
                itemID: "item_lemons",
                checked: true,
                clientMutationID: "cm_check_lemons",
                createdAt: Self.createdAt
            )
        ]
        let conflicts = [
            NativeSyncConflict(
                clientMutationID: "cm_check_lemons",
                kind: .validation,
                serverRevision: .updatedAt("2026-06-26T01:55:00.000Z"),
                message: "Shopping item changed elsewhere."
            )
        ]

        let viewModel = try await ShoppingSurfaceViewModel.load(
            repository: repository,
            queuedMutations: queued,
            conflicts: conflicts,
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(await repository.fetchCount == 1)
        let expectedActiveItems = try Self.shoppingList().activeItems
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.activeCountLabel == "3 active")
        #expect(viewModel.shoppingRunSummary == "3 active")
        #expect(viewModel.sections.map(\.title) == ["Produce", "Pantry", "Dairy"])
        #expect(viewModel.sections.map { $0.items.map(\.id) } == [
            ["item_lemons"],
            ["item_spaghetti"],
            ["item_parmesan"]
        ])
        #expect(viewModel.sections.flatMap { $0.items } == expectedActiveItems)
        #expect(viewModel.emptyState == nil)
        #expect(viewModel.queuedWorkSummary == "2 shopping changes waiting to sync")
        #expect(viewModel.conflictBanner == ShoppingSurfaceConflictBanner(
            localClientMutationID: "cm_check_lemons",
            message: "Shopping item changed elsewhere.",
            actionTitle: "Review shopping conflict"
        ))
        #expect(viewModel.offlineIndicator.display == .conflict(
            recordID: "cm_check_lemons",
            mutationID: "cm_check_lemons"
        ))

        let emptyOffline = ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )
        #expect(emptyOffline.loadState == .loaded)
        #expect(emptyOffline.activeCountLabel == "0 active")
        #expect(emptyOffline.shoppingRunSummary == "0 active")
        #expect(emptyOffline.sections.isEmpty)
        #expect(emptyOffline.emptyState == ShoppingSurfaceEmptyState(
            title: "Receipt is empty",
            message: "Add an item or pull ingredients from a recipe.",
            systemImage: "cart"
        ))
        #expect(emptyOffline.offlineIndicator.display == .offline)

        let needsLiveLoad = ShoppingSurfaceViewModel(
            shoppingList: nil,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(needsLiveLoad.loadState == .needsLiveLoad)
        #expect(needsLiveLoad.shoppingRunSummary == "Ready to sync")
        #expect(needsLiveLoad.emptyState == ShoppingSurfaceEmptyState(
            title: "Sync the receipt",
            message: "Connect to Spoonjoy to load the current market run.",
            systemImage: "arrow.clockwise"
        ))
        #expect(needsLiveLoad.offlineIndicator.display == .synced)
    }

    @Test("live shopping repository fetches API read data into native state")
    func liveShoppingRepositoryFetchesAPIReadDataIntoNativeState() async throws {
        let fixture = try Self.shoppingList()
        let transport = RecordingShoppingAPITransport(envelope: APIEnvelope(
            requestID: "req_shopping_read",
            data: ShoppingListReadData(
                shoppingList: ShoppingListResponse(
                    id: fixture.id,
                    chef: fixture.chef,
                    items: fixture.items,
                    updatedAt: fixture.updatedAt
                ),
                nextCursor: ShoppingSyncCursor(rawValue: "v1.shopping.after")!
            )
        ))
        let repository = LiveShoppingSurfaceRepository(
            transport: transport,
            configuration: Self.configuration
        )

        let state = try await repository.fetchShoppingList()
        let requests = transport.requests

        #expect(state.id == fixture.id)
        #expect(state.activeItems.map(\.id) == fixture.activeItems.map(\.id))
        #expect(state.nextCursor == "v1.shopping.after")
        #expect(requests.map(\.url.path) == ["/api/v1/shopping-list"])
        #expect(requests.first?.headers["Authorization"] == "Bearer sj_private_token")
    }

    @Test("shopping conflicts and queued work are scoped to shopping mutations")
    func shoppingConflictsAndQueuedWorkAreScopedToShoppingMutations() throws {
        let recipeMutation = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_lemon",
            clientMutationID: "cm_recipe_conflict",
            title: "Changed",
            description: nil,
            servings: nil,
            createdAt: Self.createdAt
        )
        let shoppingMutation = NativeQueuedMutation.shoppingAddItem(
            name: "limes",
            quantity: 4,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_shopping_conflict",
            createdAt: Self.createdAt
        )
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [recipeMutation, shoppingMutation],
            conflicts: [
                NativeSyncConflict(
                    clientMutationID: "cm_recipe_conflict",
                    kind: .validation,
                    serverRevision: .updatedAt(Self.createdAt),
                    message: "Recipe changed elsewhere."
                ),
                NativeSyncConflict(
                    clientMutationID: "cm_shopping_conflict",
                    kind: .validation,
                    serverRevision: .updatedAt(Self.createdAt),
                    message: "Shopping item changed elsewhere."
                )
            ],
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(viewModel.queuedWorkSummary == "1 shopping change waiting to sync")
        #expect(viewModel.conflictBanner == ShoppingSurfaceConflictBanner(
            localClientMutationID: "cm_shopping_conflict",
            message: "Shopping item changed elsewhere.",
            actionTitle: "Review shopping conflict"
        ))
        #expect(viewModel.offlineIndicator.display == .conflict(recordID: "cm_shopping_conflict", mutationID: "cm_shopping_conflict"))

        let recipeOnly = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [recipeMutation],
            conflicts: [
                NativeSyncConflict(
                    clientMutationID: "cm_recipe_conflict",
                    kind: .validation,
                    serverRevision: .updatedAt(Self.createdAt),
                    message: "Recipe changed elsewhere."
                )
            ],
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(recipeOnly.queuedWorkSummary == nil)
        #expect(recipeOnly.conflictBanner == nil)
        #expect(recipeOnly.offlineIndicator.display == .synced)
    }

    @Test("online shopping actions plan exact REST mutations with offline fallbacks")
    func onlineShoppingActionsPlanExactRESTMutationsWithOfflineFallbacks() throws {
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingListWithCompletedItem(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let add = try viewModel.plan(.addItem(
            name: " Limes ",
            quantity: 4,
            unit: "each",
            categoryKey: "produce",
            iconKey: "lemon",
            clientMutationID: "cm_add_limes"
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: add),
            method: .post,
            path: "/api/v1/shopping-list/items",
            expected: [
                "clientMutationId": "cm_add_limes",
                "name": "limes",
                "quantity": 4,
                "unit": "each",
                "categoryKey": "produce",
                "iconKey": "lemon"
            ]
        )
        #expect(add.queuedMutation == nil)
        let addFallback = try requireShoppingMutation(add.offlineFallbackMutation, "add fallback")
        assertShoppingMutationMetadata(
            addFallback,
            kind: .shoppingAddItem,
            clientMutationID: "cm_add_limes",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: addFallback),
            method: .post,
            path: "/api/v1/shopping-list/items",
            expected: [
                "clientMutationId": "cm_add_limes",
                "name": "limes",
                "quantity": 4,
                "unit": "each",
                "categoryKey": "produce",
                "iconKey": "lemon"
            ]
        )
        #expect(add.updatedShoppingList?.item(id: "item_local_cm_add_limes")?.name == "limes")

        let emptyAdd = try ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        ).plan(.addItem(
            name: "starter salt",
            quantity: 1,
            unit: "pinch",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_add_first_item"
        ))
        #expect(emptyAdd.updatedShoppingList?.item(id: "item_local_cm_add_first_item")?.sortIndex == 0)

        let emptyCheckViewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(throws: KitchenStateError.itemNotFound("item_missing")) {
            try emptyCheckViewModel.plan(.setItemChecked(
                itemID: "item_missing",
                checked: true,
                clientMutationID: "cm_check_missing_empty"
            ))
        }

        let check = try viewModel.plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_check_lemons"
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: check),
            method: .patch,
            path: "/api/v1/shopping-list/items/item_lemons",
            expected: [
                "clientMutationId": "cm_check_lemons",
                "checked": true
            ]
        )
        #expect(check.updatedShoppingList?.item(id: "item_lemons")?.checked == true)
        let checkFallback = try requireShoppingMutation(check.offlineFallbackMutation, "check fallback")
        assertShoppingMutationMetadata(
            checkFallback,
            kind: .shoppingCheckItem,
            clientMutationID: "cm_check_lemons",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: checkFallback),
            method: .patch,
            path: "/api/v1/shopping-list/items/item_lemons",
            expected: [
                "clientMutationId": "cm_check_lemons",
                "checked": true
            ]
        )

        let uncheck = try viewModel.plan(.setItemChecked(
            itemID: "item_spaghetti",
            checked: false,
            clientMutationID: "cm_uncheck_spaghetti"
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: uncheck),
            method: .patch,
            path: "/api/v1/shopping-list/items/item_spaghetti",
            expected: [
                "clientMutationId": "cm_uncheck_spaghetti",
                "checked": false
            ]
        )
        #expect(uncheck.updatedShoppingList?.item(id: "item_spaghetti")?.checked == false)
        #expect(uncheck.updatedShoppingList?.item(id: "item_spaghetti")?.updatedAt == Self.createdAt)
        let uncheckFallback = try requireShoppingMutation(uncheck.offlineFallbackMutation, "uncheck fallback")
        assertShoppingMutationMetadata(
            uncheckFallback,
            kind: .shoppingCheckItem,
            clientMutationID: "cm_uncheck_spaghetti",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: uncheckFallback),
            method: .patch,
            path: "/api/v1/shopping-list/items/item_spaghetti",
            expected: [
                "clientMutationId": "cm_uncheck_spaghetti",
                "checked": false
            ]
        )

        let deletePrompt = try viewModel.plan(.deleteItem(
            itemID: "item_lemons",
            clientMutationID: "cm_delete_lemons",
            confirmation: .required
        ))
        #expect(deletePrompt.remoteRequestBuilder == nil)
        #expect(deletePrompt.queuedMutation == nil)
        #expect(deletePrompt.confirmationPrompt == ShoppingActionConfirmationPrompt(
            title: "Remove lemons?",
            message: "This removes the item from your shopping list and syncs the change across your devices.",
            confirmButtonTitle: "Remove Item",
            isDestructive: true
        ))

        let delete = try viewModel.plan(.deleteItem(
            itemID: "item_lemons",
            clientMutationID: "cm_delete_lemons",
            confirmation: .confirmed
        ))
        assertShoppingNoBodyRequest(
            try shoppingRemoteRequest(from: delete),
            method: .delete,
            path: "/api/v1/shopping-list/items/item_lemons",
            headers: [
                "Accept": "application/json",
                "Authorization": "Bearer sj_private_token",
                "X-Client-Mutation-Id": "cm_delete_lemons"
            ]
        )
        #expect(delete.updatedShoppingList?.item(id: "item_lemons")?.deletedAt == Self.createdAt)
        let deleteFallback = try requireShoppingMutation(delete.offlineFallbackMutation, "delete fallback")
        assertShoppingMutationMetadata(
            deleteFallback,
            kind: .shoppingDeleteItem,
            clientMutationID: "cm_delete_lemons",
            createdAt: Self.createdAt
        )
        assertShoppingNoBodyRequest(
            try shoppingQueuedRequest(from: deleteFallback),
            method: .delete,
            path: "/api/v1/shopping-list/items/item_lemons",
            headers: [
                "Accept": "application/json",
                "Authorization": "Bearer sj_private_token",
                "X-Client-Mutation-Id": "cm_delete_lemons"
            ]
        )

        let addRecipe = try viewModel.plan(.addRecipeIngredients(
            recipeID: "recipe_lemon_pantry_pasta",
            scaleFactor: 2.5,
            recipeIngredients: Self.recipeShoppingIngredients,
            clientMutationID: "cm_add_recipe"
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: addRecipe),
            method: .post,
            path: "/api/v1/shopping-list/add-from-recipe",
            expected: [
                "clientMutationId": "cm_add_recipe",
                "recipeId": "recipe_lemon_pantry_pasta",
                "scaleFactor": 2.5
            ]
        )
        let addRecipeFallback = try requireShoppingMutation(addRecipe.offlineFallbackMutation, "add recipe fallback")
        assertShoppingMutationMetadata(
            addRecipeFallback,
            kind: .shoppingAddFromRecipe,
            clientMutationID: "cm_add_recipe",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: addRecipeFallback),
            method: .post,
            path: "/api/v1/shopping-list/add-from-recipe",
            expected: [
                "clientMutationId": "cm_add_recipe",
                "recipeId": "recipe_lemon_pantry_pasta",
                "scaleFactor": 2.5
            ]
        )

        let clearCompletedPrompt = try viewModel.plan(.clearCompleted(
            clientMutationID: "cm_clear_completed",
            confirmation: .required
        ))
        #expect(clearCompletedPrompt.remoteRequestBuilder == nil)
        #expect(clearCompletedPrompt.confirmationPrompt == ShoppingActionConfirmationPrompt(
            title: "Clear completed items?",
            message: "This removes checked items and syncs the change across your devices.",
            confirmButtonTitle: "Clear Completed",
            isDestructive: true
        ))

        let clearCompleted = try viewModel.plan(.clearCompleted(
            clientMutationID: "cm_clear_completed",
            confirmation: .confirmed
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: clearCompleted),
            method: .post,
            path: "/api/v1/shopping-list/clear-completed",
            expected: ["clientMutationId": "cm_clear_completed"]
        )
        #expect(clearCompleted.updatedShoppingList?.activeItems.map(\.id) == ["item_lemons", "item_parmesan"])
        let clearCompletedFallback = try requireShoppingMutation(clearCompleted.offlineFallbackMutation, "clear completed fallback")
        assertShoppingMutationMetadata(
            clearCompletedFallback,
            kind: .shoppingClearCompleted,
            clientMutationID: "cm_clear_completed",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: clearCompletedFallback),
            method: .post,
            path: "/api/v1/shopping-list/clear-completed",
            expected: ["clientMutationId": "cm_clear_completed"]
        )

        let clearAll = try viewModel.plan(.clearAll(
            clientMutationID: "cm_clear_all",
            confirmation: .confirmed
        ))
        try assertShoppingJSONRequest(
            try shoppingRemoteRequest(from: clearAll),
            method: .post,
            path: "/api/v1/shopping-list/clear-all",
            expected: ["clientMutationId": "cm_clear_all"]
        )
        #expect(clearAll.updatedShoppingList?.activeItems.isEmpty == true)
        let clearAllFallback = try requireShoppingMutation(clearAll.offlineFallbackMutation, "clear all fallback")
        assertShoppingMutationMetadata(
            clearAllFallback,
            kind: .shoppingClearAll,
            clientMutationID: "cm_clear_all",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: clearAllFallback),
            method: .post,
            path: "/api/v1/shopping-list/clear-all",
            expected: ["clientMutationId": "cm_clear_all"]
        )
    }

    @Test("clear completed removes stale checked-at rows")
    func clearCompletedRemovesStaleCheckedAtRows() throws {
        let staleCompleted = ShoppingListItem(
            id: "item_stale_completed",
            name: "stale completed",
            quantity: 1,
            unit: "each",
            checked: false,
            checkedAt: "2026-06-26T01:50:00.000Z",
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: "2026-06-26T01:50:00.000Z"
        )
        let active = ShoppingListItem(
            id: "item_active",
            name: "active",
            quantity: 1,
            unit: "each",
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 1,
            updatedAt: "2026-06-26T01:51:00.000Z"
        )
        let list = ShoppingListState(
            id: "shopping_list_test",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [staleCompleted, active],
            nextCursor: "",
            updatedAt: "2026-06-26T01:51:00.000Z"
        )
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: list,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let plan = try viewModel.plan(.clearCompleted(
            clientMutationID: "cm_clear_completed_stale",
            confirmation: .confirmed
        ))

        #expect(plan.updatedShoppingList?.activeItems.map(\.id) == ["item_active"])
        #expect(plan.updatedShoppingList?.item(id: "item_stale_completed")?.deletedAt == Self.createdAt)
    }

    @Test("online shopping actions queue behind existing shopping work")
    func onlineShoppingActionsQueueBehindExistingShoppingWork() throws {
        let pendingAdd = NativeQueuedMutation.shoppingAddItem(
            name: "pepper",
            quantity: 1,
            unit: "jar",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_pending_add",
            createdAt: Self.createdAt
        )
        let localItem = ShoppingListItem(
            id: "item_local_cm_pending_add",
            name: "pepper",
            quantity: 1,
            unit: "jar",
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 3,
            updatedAt: Self.createdAt
        )
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: Self.shoppingList(items: try Self.shoppingList().activeItems + [localItem]),
            queuedMutations: [pendingAdd],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        let checkLocal = try viewModel.plan(.setItemChecked(
            itemID: "item_local_cm_pending_add",
            checked: true,
            clientMutationID: "cm_check_pending"
        ))

        #expect(checkLocal.remoteRequestBuilder == nil)
        let queuedCheck = try requireShoppingMutation(checkLocal.queuedMutation, "queued check behind pending add")
        assertShoppingMutationMetadata(
            queuedCheck,
            kind: .shoppingCheckItem,
            clientMutationID: "cm_check_pending",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: queuedCheck),
            method: .patch,
            path: "/api/v1/shopping-list/items/item_local_cm_pending_add",
            expected: [
                "clientMutationId": "cm_check_pending",
                "checked": true
            ]
        )
    }

    @Test("offline shopping actions queue safe mutations and destructive clears require confirmation")
    func offlineShoppingActionsQueueSafeMutationsAndDestructiveClearsRequireConfirmation() throws {
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        )

        let add = try viewModel.plan(.addItem(
            name: " Limes ",
            quantity: 4,
            unit: "each",
            categoryKey: "produce",
            iconKey: "lemon",
            clientMutationID: "cm_add_limes"
        ))
        #expect(add.remoteRequestBuilder == nil)
        let addMutation = try requireShoppingMutation(add.queuedMutation, "offline add")
        assertShoppingMutationMetadata(
            addMutation,
            kind: .shoppingAddItem,
            clientMutationID: "cm_add_limes",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: addMutation),
            method: .post,
            path: "/api/v1/shopping-list/items",
            expected: [
                "clientMutationId": "cm_add_limes",
                "name": "limes",
                "quantity": 4,
                "unit": "each",
                "categoryKey": "produce",
                "iconKey": "lemon"
            ]
        )

        let delete = try viewModel.plan(.deleteItem(
            itemID: "item_lemons",
            clientMutationID: "cm_delete_lemons",
            confirmation: .confirmed
        ))
        let deleteMutation = try requireShoppingMutation(delete.queuedMutation, "offline delete")
        assertShoppingMutationMetadata(
            deleteMutation,
            kind: .shoppingDeleteItem,
            clientMutationID: "cm_delete_lemons",
            createdAt: Self.createdAt
        )
        assertShoppingNoBodyRequest(
            try shoppingQueuedRequest(from: deleteMutation),
            method: .delete,
            path: "/api/v1/shopping-list/items/item_lemons",
            headers: [
                "Accept": "application/json",
                "Authorization": "Bearer sj_private_token",
                "X-Client-Mutation-Id": "cm_delete_lemons"
            ]
        )

        let clearCompleted = try ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingListWithCompletedItem(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        ).plan(.clearCompleted(
            clientMutationID: "cm_clear_completed",
            confirmation: .confirmed
        ))
        let clearCompletedMutation = try requireShoppingMutation(clearCompleted.queuedMutation, "offline clear completed")
        assertShoppingMutationMetadata(
            clearCompletedMutation,
            kind: .shoppingClearCompleted,
            clientMutationID: "cm_clear_completed",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: clearCompletedMutation),
            method: .post,
            path: "/api/v1/shopping-list/clear-completed",
            expected: ["clientMutationId": "cm_clear_completed"]
        )

        let clearAllPrompt = try viewModel.plan(.clearAll(
            clientMutationID: "cm_clear_all",
            confirmation: .required
        ))
        #expect(clearAllPrompt.remoteRequestBuilder == nil)
        #expect(clearAllPrompt.queuedMutation == nil)
        #expect(clearAllPrompt.confirmationPrompt == ShoppingActionConfirmationPrompt(
            title: "Clear your whole shopping list?",
            message: "This removes every active item and syncs the change across your devices.",
            confirmButtonTitle: "Clear All",
            isDestructive: true
        ))

        let clearAll = try viewModel.plan(.clearAll(
            clientMutationID: "cm_clear_all",
            confirmation: .confirmed
        ))
        let clearAllMutation = try requireShoppingMutation(clearAll.queuedMutation, "offline clear all")
        assertShoppingMutationMetadata(
            clearAllMutation,
            kind: .shoppingClearAll,
            clientMutationID: "cm_clear_all",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: clearAllMutation),
            method: .post,
            path: "/api/v1/shopping-list/clear-all",
            expected: ["clientMutationId": "cm_clear_all"]
        )

        let addRecipe = try viewModel.plan(.addRecipeIngredients(
            recipeID: "recipe_lemon_pantry_pasta",
            scaleFactor: 1.5,
            recipeIngredients: Self.recipeShoppingIngredients,
            clientMutationID: "cm_add_recipe_offline"
        ))
        let addRecipeMutation = try requireShoppingMutation(addRecipe.queuedMutation, "offline add recipe")
        assertShoppingMutationMetadata(
            addRecipeMutation,
            kind: .shoppingAddFromRecipe,
            clientMutationID: "cm_add_recipe_offline",
            createdAt: Self.createdAt
        )
        try assertShoppingJSONRequest(
            try shoppingQueuedRequest(from: addRecipeMutation),
            method: .post,
            path: "/api/v1/shopping-list/add-from-recipe",
            expected: [
                "clientMutationId": "cm_add_recipe_offline",
                "recipeId": "recipe_lemon_pantry_pasta",
                "scaleFactor": 1.5
            ]
        )
    }

    @Test("recipe shopping coverage requires every ingredient name and unit")
    func recipeShoppingCoverageRequiresEveryIngredientNameAndUnit() throws {
        let recipe = Self.recipeWithIngredients([
            RecipeIngredient(id: "ingredient_salt", name: " Salt ", quantity: 1, unit: "pinch"),
            RecipeIngredient(id: "ingredient_pasta", name: "Pasta", quantity: 8, unit: "oz")
        ])
        let partialOverlap = Self.shoppingList(items: [
            Self.shoppingItem(id: "item_salt", name: "salt", unit: "pinch")
        ])
        let wrongUnit = Self.shoppingList(items: [
            Self.shoppingItem(id: "item_salt", name: "salt", unit: "tbsp"),
            Self.shoppingItem(id: "item_pasta", name: "pasta", unit: "oz")
        ])
        let complete = Self.shoppingList(items: [
            Self.shoppingItem(id: "item_salt", name: "salt", unit: "pinch"),
            Self.shoppingItem(id: "item_pasta", name: "pasta", unit: "oz")
        ])
        let noUnitComplete = Self.shoppingList(items: [
            Self.shoppingItem(id: "item_cilantro", name: "cilantro", unit: nil)
        ])
        let deletedMatch = Self.shoppingList(items: [
            Self.shoppingItem(id: "item_salt_deleted", name: "salt", unit: "pinch", deletedAt: Self.createdAt),
            Self.shoppingItem(id: "item_pasta", name: "pasta", unit: "oz")
        ])

        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: nil) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(Self.recipeWithIngredients([]), in: complete) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(
            Self.recipeWithIngredients([
                RecipeIngredient(id: "ingredient_blank", name: "  ", quantity: 1, unit: "  ")
            ]),
            in: complete
        ) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: partialOverlap) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: wrongUnit) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: deletedMatch) == false)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(recipe, in: complete) == true)
        #expect(RecipeShoppingListCoverage.hasAllRecipeIngredients(
            Self.recipeWithIngredients([
                RecipeIngredient(id: "ingredient_cilantro", name: "cilantro", quantity: 1, unit: "   ")
            ]),
            in: noUnitComplete
        ) == true)
    }

    @Test("shopping receipt state distinguishes empty, all-complete, and optimistic recipe rows")
    func shoppingReceiptStateDistinguishesEmptyAllCompleteAndOptimisticRecipeRows() throws {
        let completedOnly = Self.shoppingList(items: [
            Self.shoppingItem(
                id: "item_done_salt",
                name: "salt",
                unit: "pinch",
                checked: true,
                checkedAt: Self.createdAt
            )
        ])
        let completedViewModel = ShoppingSurfaceViewModel(
            shoppingList: completedOnly,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )

        #expect(completedOnly.activeItems.isEmpty)
        #expect(completedViewModel.activeCountLabel == "0 active")
        #expect(completedViewModel.shoppingRunSummary == "0 active - 1 checked")
        #expect(completedViewModel.emptyState == ShoppingSurfaceEmptyState(
            title: "All checked off",
            message: "Nice. Clear checked items when you're ready to reset the receipt.",
            systemImage: "checkmark.circle"
        ))

        let addRecipe = try ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        ).plan(.addRecipeIngredients(
            recipeID: "recipe_lemon_pantry_pasta",
            scaleFactor: 2,
            recipeIngredients: Self.recipeShoppingIngredients,
            clientMutationID: "cm_recipe_receipt"
        ))
        let optimisticList = try #require(addRecipe.updatedShoppingList)
        #expect(optimisticList.activeItems.map(\.name) == ["pasta", "lemons"])
        #expect(optimisticList.activeItems.map(\.displayQuantity) == ["16 oz", "4 each"])
    }

    @Test("shopping surface covers queued local validation and prompt edge states")
    func shoppingSurfaceCoversQueuedLocalValidationAndPromptEdgeStates() async throws {
        let queuedClear = NativeQueuedMutation.shoppingClearAll(
            clientMutationID: "cm_clear_waiting",
            createdAt: Self.createdAt
        )
        let queuedViewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [queuedClear],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(queuedViewModel.queuedWorkSummary == "1 shopping change waiting to sync")
        #expect(queuedViewModel.offlineIndicator.display == .queuedWork(
            count: 1,
            oldestClientMutationID: "cm_clear_waiting"
        ))

        let queuedEmpty = ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [queuedClear],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(queuedEmpty.shoppingReceiptState == ShoppingReceiptState(
            title: "Saved for sync",
            message: "1 shopping change waiting to sync",
            systemImage: "arrow.triangle.2.circlepath",
            actionTitle: "Review queued work"
        ))

        let replacement = try Self.emptyShoppingList()
        #expect(queuedViewModel.replacingShoppingList(replacement).sections.isEmpty)

        let blankAdd = try queuedViewModel.plan(.addItem(
            name: "  ",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_blank_add"
        ))
        #expect(blankAdd.blockedReason == "Enter an item before adding it to your shopping list.")

        let noUnitAdd = try queuedViewModel.plan(.addItem(
            name: " Mint ",
            quantity: nil,
            unit: "   ",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_no_unit_add"
        ))
        let addedNoUnit = try #require(noUnitAdd.updatedShoppingList?.item(id: "item_local_cm_no_unit_add"))
        #expect(addedNoUnit.quantity == nil)
        #expect(addedNoUnit.unit == nil)

        let missingDeletePrompt = try queuedViewModel.plan(.deleteItem(
            itemID: "item_missing",
            clientMutationID: "cm_delete_missing",
            confirmation: .required
        ))
        #expect(missingDeletePrompt.confirmationPrompt?.title == "Remove this item?")

        let unloaded = ShoppingSurfaceViewModel(
            shoppingList: nil,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        #expect(unloaded.loadState == .needsLiveLoad)
        #expect(unloaded.sections.isEmpty)
        #expect(unloaded.activeCountLabel == "0 active")
        let unloadedClear = try unloaded.plan(.clearAll(
            clientMutationID: "cm_unloaded_clear",
            confirmation: .confirmed
        ))
        #expect(unloadedClear.updatedShoppingList == nil)

        var queuedMutations: [NativeQueuedMutation] = []
        var recordedShoppingLists: [ShoppingListState] = []
        let queuedOutcome = try await ShoppingSurfaceMutationExecutor.perform(
            unloadedClear,
            queueMutation: { queuedMutations.append($0) },
            executeRemoteRequest: { _ in },
            recordShoppingList: { recordedShoppingLists.append($0) }
        )
        #expect(queuedOutcome == .synced)
        #expect(queuedMutations.isEmpty)
        #expect(recordedShoppingLists.isEmpty)

        let localOnlyList = try Self.emptyShoppingList()
        let localOnlyOutcome = try await ShoppingSurfaceMutationExecutor.perform(
            ShoppingSurfaceMutationPlan(updatedShoppingList: localOnlyList),
            queueMutation: { queuedMutations.append($0) },
            executeRemoteRequest: { _ in throw ShoppingSurfaceParityTestFailure("remote should not run") },
            recordShoppingList: { recordedShoppingLists.append($0) }
        )
        #expect(localOnlyOutcome == .synced)
        #expect(recordedShoppingLists == [localOnlyList])

        let offlinePlan = try ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { Self.createdAt }
        ).plan(.addItem(
            name: "oranges",
            quantity: 3,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_offline_executor"
        ))
        let offlineOutcome = try await ShoppingSurfaceMutationExecutor.perform(
            offlinePlan,
            queueMutation: { queuedMutations.append($0) },
            executeRemoteRequest: { _ in throw ShoppingSurfaceParityTestFailure("remote should not run") },
            recordShoppingList: { recordedShoppingLists.append($0) }
        )
        #expect(offlineOutcome == .queuedForSync)
        #expect(queuedMutations.map(\.clientMutationID) == ["cm_offline_executor"])

        let offlineError = APITransportError(
            kind: .offline,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        let remoteOnly = ShoppingSurfaceMutationPlan(
            remoteRequestBuilder: try ShoppingListRequests.clearAll(clientMutationID: "cm_remote_only")
        )
        do {
            _ = try await ShoppingSurfaceMutationExecutor.perform(
                remoteOnly,
                queueMutation: { queuedMutations.append($0) },
                executeRemoteRequest: { _ in throw offlineError },
                recordShoppingList: { recordedShoppingLists.append($0) }
            )
            throw ShoppingSurfaceParityTestFailure("Expected remote-only offline error to be rethrown.")
        } catch let error as APITransportError {
            #expect(error.kind == .offline)
        }
    }

    @MainActor
    @Test("shopping surface executor does not clobber remote success and queues offline fallbacks")
    func shoppingSurfaceExecutorDoesNotClobberRemoteSuccessAndQueuesOfflineFallbacks() async throws {
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.shoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        let plan = try viewModel.plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_check_lemons_visible"
        ))
        var executedRequestPaths: [String] = []
        var recordedShoppingLists: [ShoppingListState] = []
        var queuedMutations: [NativeQueuedMutation] = []

        let outcome = try await ShoppingSurfaceMutationExecutor.perform(
            plan,
            queueMutation: { queuedMutations.append($0) },
            executeRemoteRequest: { request in
                executedRequestPaths.append(try request.urlRequest(configuration: Self.configuration).url.path)
            },
            recordShoppingList: { recordedShoppingLists.append($0) }
        )

        #expect(outcome == .synced)
        #expect(executedRequestPaths == ["/api/v1/shopping-list/items/item_lemons"])
        #expect(queuedMutations.isEmpty)
        #expect(recordedShoppingLists.isEmpty)

        let offlineError = APITransportError(
            kind: .offline,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        recordedShoppingLists = []
        executedRequestPaths = []
        let queuedOutcome = try await ShoppingSurfaceMutationExecutor.perform(
            plan,
            queueMutation: { queuedMutations.append($0) },
            executeRemoteRequest: { request in
                executedRequestPaths.append(try request.urlRequest(configuration: Self.configuration).url.path)
                throw offlineError
            },
            recordShoppingList: { recordedShoppingLists.append($0) }
        )

        #expect(queuedOutcome == .queuedForSync)
        #expect(executedRequestPaths == ["/api/v1/shopping-list/items/item_lemons"])
        let expectedQueuedList = try #require(plan.updatedShoppingList)
        #expect(recordedShoppingLists == [expectedQueuedList])
        #expect(queuedMutations.map(\.queueableKind) == [.shoppingCheckItem])
        #expect(queuedMutations.map(\.clientMutationID) == ["cm_check_lemons_visible"])
    }

    @MainActor
    @Test("shopping add form keeps draft on failure and clears only after accepted action")
    func shoppingAddFormKeepsDraftOnFailureAndClearsOnlyAfterAcceptedAction() async throws {
        let viewModel = ShoppingSurfaceViewModel(
            shoppingList: try Self.emptyShoppingList(),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { Self.createdAt }
        )
        var failingForm = ShoppingAddItemFormState(
            itemName: " Limes ",
            itemQuantity: "2",
            itemUnit: " each "
        )

        await failingForm.submit(
            viewModel: viewModel,
            clientMutationID: "cm_form_failure",
            actionDidPlan: { _ in throw ShoppingSurfaceParityTestFailure("queue unavailable") }
        )

        #expect(failingForm.itemName == " Limes ")
        #expect(failingForm.itemQuantity == "2")
        #expect(failingForm.itemUnit == " each ")
        #expect(failingForm.actionStatusMessage == nil)
        #expect(failingForm.actionErrorMessage == "Shopping action failed.")

        var acceptedPlans: [ShoppingSurfaceMutationPlan] = []
        var successForm = ShoppingAddItemFormState(
            itemName: " Limes ",
            itemQuantity: "2",
            itemUnit: " each "
        )

        await successForm.submit(
            viewModel: viewModel,
            clientMutationID: "cm_form_success",
            actionDidPlan: { plan in
                acceptedPlans.append(plan)
                return .synced
            }
        )

        #expect(successForm.itemName.isEmpty)
        #expect(successForm.itemQuantity.isEmpty)
        #expect(successForm.itemUnit.isEmpty)
        #expect(successForm.actionStatusMessage == "Shopping list updated")
        #expect(successForm.actionErrorMessage == nil)
        #expect(acceptedPlans.first?.updatedShoppingList?.item(id: "item_local_cm_form_success")?.name == "limes")
        #expect(acceptedPlans.first?.updatedShoppingList?.item(id: "item_local_cm_form_success")?.unit == "each")

        var blankForm = ShoppingAddItemFormState(itemName: "  ", itemQuantity: "", itemUnit: "")
        await blankForm.submit(
            viewModel: viewModel,
            clientMutationID: "cm_form_blank",
            actionDidPlan: { _ in throw ShoppingSurfaceParityTestFailure("blank form should not plan") }
        )
        #expect(blankForm.actionErrorMessage == "Enter an item before adding it to your shopping list.")
        #expect(blankForm.actionStatusMessage == nil)

        var invalidQuantityForm = ShoppingAddItemFormState(itemName: "Salt", itemQuantity: "NaN", itemUnit: "pinch")
        await invalidQuantityForm.submit(
            viewModel: viewModel,
            clientMutationID: "cm_form_invalid_quantity",
            actionDidPlan: { _ in throw ShoppingSurfaceParityTestFailure("invalid form should not plan") }
        )
        #expect(invalidQuantityForm.actionErrorMessage == "Enter a valid quantity.")
        #expect(invalidQuantityForm.actionStatusMessage == nil)

        var queuedForm = ShoppingAddItemFormState(itemName: "Salt", itemQuantity: "", itemUnit: "")
        await queuedForm.submit(
            viewModel: viewModel,
            clientMutationID: "cm_form_queued",
            actionDidPlan: { plan in
                acceptedPlans.append(plan)
                return .queuedForSync
            }
        )
        #expect(queuedForm.actionStatusMessage == "Saved for sync")
        #expect(queuedForm.actionErrorMessage == nil)
        #expect(acceptedPlans.last?.updatedShoppingList?.item(id: "item_local_cm_form_queued")?.quantity == nil)
    }

    private static func shoppingList() throws -> ShoppingListState {
        try ShoppingListState.decodeFromBundle()
    }

    private static func shoppingListWithCompletedItem() throws -> ShoppingListState {
        try shoppingList().settingChecked(
            true,
            itemID: "item_spaghetti",
            checkedAt: "2026-06-26T01:50:00.000Z",
            updatedAt: "2026-06-26T01:50:00.000Z",
            nextSortIndex: 3
        )
    }

    private static func emptyShoppingList() throws -> ShoppingListState {
        let shoppingList = try shoppingList()
        return ShoppingListState(
            id: shoppingList.id,
            chef: shoppingList.chef,
            items: [],
            nextCursor: "v1.empty.cursor",
            updatedAt: Self.createdAt
        )
    }

    private static func shoppingList(items: [ShoppingListItem]) -> ShoppingListState {
        ShoppingListState(
            id: "shopping_list_test",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: items,
            nextCursor: "v1.coverage",
            updatedAt: Self.createdAt
        )
    }

    private static func shoppingItem(
        id: String,
        name: String,
        unit: String?,
        deletedAt: String? = nil,
        checked: Bool = false,
        checkedAt: String? = nil
    ) -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: 1,
            unit: unit,
            checked: checked,
            checkedAt: checkedAt,
            deletedAt: deletedAt,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: Self.createdAt
        )
    }

    private static func recipeWithIngredients(_ ingredients: [RecipeIngredient]) -> Recipe {
        let canonicalURL = URL(string: "https://spoonjoy.app/recipes/recipe_shopping_coverage")!
        return Recipe(
            id: "recipe_shopping_coverage",
            title: "Shopping Coverage Pasta",
            description: "Coverage recipe.",
            servings: "2",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: nil,
            coverProvenanceLabel: nil,
            coverSourceType: nil,
            coverVariant: nil,
            href: "/recipes/recipe_shopping_coverage",
            canonicalURL: canonicalURL,
            attribution: RecipeAttribution(
                creditText: "By ari",
                canonicalURL: canonicalURL,
                sourceURLRaw: nil,
                sourceHost: nil,
                sourceRecipe: nil
            ),
            createdAt: Self.createdAt,
            updatedAt: Self.createdAt,
            steps: [
                RecipeStep(
                    id: "step_coverage",
                    stepNum: 1,
                    stepTitle: "Cook",
                    description: "Cook.",
                    duration: nil,
                    ingredients: ingredients
                )
            ],
            cookbooks: []
        )
    }

    private static var recipeShoppingIngredients: [RecipeIngredient] {
        [
            RecipeIngredient(id: "ingredient_pasta", name: "pasta", quantity: 8, unit: "oz"),
            RecipeIngredient(id: "ingredient_lemons", name: "lemons", quantity: 2, unit: "each")
        ]
    }
}

private actor RecordingShoppingSurfaceRepository: ShoppingSurfaceRepository {
    private let shoppingList: ShoppingListState
    private(set) var fetchCount = 0

    init(shoppingList: ShoppingListState) {
        self.shoppingList = shoppingList
    }

    func fetchShoppingList() async throws -> ShoppingListState {
        fetchCount += 1
        return shoppingList
    }
}

private final class RecordingShoppingAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let envelope: APIEnvelope<ShoppingListReadData>
    private(set) var requests: [APIRequest] = []

    init(envelope: APIEnvelope<ShoppingListReadData>) {
        self.envelope = envelope
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode valueType: Value.Type
    ) async throws -> APIEnvelope<Value> {
        requests.append(try request.urlRequest(configuration: configuration))
        guard valueType == ShoppingListReadData.self else {
            throw ShoppingSurfaceParityTestFailure("Unexpected value type \(valueType).")
        }
        return envelope as! APIEnvelope<Value>
    }
}

private func shoppingRemoteRequest(from plan: ShoppingSurfaceMutationPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw ShoppingSurfaceParityTestFailure("Expected an online shopping action to provide a remote request builder.")
    }
    return try builder.urlRequest(configuration: ShoppingSurfaceParityTests.configuration)
}

private func shoppingQueuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: ShoppingSurfaceParityTests.configuration)
}

private func requireShoppingMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    guard let mutation else {
        throw ShoppingSurfaceParityTestFailure("Expected \(label) to provide a native queued mutation.")
    }
    return mutation
}

private func assertShoppingMutationMetadata(
    _ mutation: NativeQueuedMutation,
    kind: NativeQueuedMutationKind,
    clientMutationID: String,
    createdAt: String
) {
    #expect(mutation.queueableKind == kind)
    #expect(mutation.clientMutationID == clientMutationID)
    #expect(mutation.createdAt == createdAt)
    #expect(mutation.dependencyKey == "shopping-list")
}

private func assertShoppingJSONRequest(
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
    #expect(NSDictionary(dictionary: try shoppingJSONBody(from: request)).isEqual(to: expected))
}

private func assertShoppingNoBodyRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    headers: [String: String]
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems.isEmpty)
    #expect(request.headers == headers)
    #expect(request.body == nil)
    #expect(request.responseCachePolicy == .privateNoStore)
}

private func shoppingJSONBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private struct ShoppingSurfaceParityTestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
