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
                clientMutationID: "cm_delete_lemons",
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
            localClientMutationID: "cm_delete_lemons",
            message: "Shopping item changed elsewhere.",
            actionTitle: "Review shopping conflict"
        ))
        #expect(viewModel.offlineIndicator.display == .conflict(
            recordID: "cm_delete_lemons",
            mutationID: "cm_delete_lemons"
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
        #expect(emptyOffline.sections.isEmpty)
        #expect(emptyOffline.emptyState == ShoppingSurfaceEmptyState(
            title: "Your shopping list is empty",
            message: "Add ingredients from a recipe or jot down what you need.",
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
        #expect(needsLiveLoad.emptyState == ShoppingSurfaceEmptyState(
            title: "Load your shopping list",
            message: "Connect to Spoonjoy to sync your current list.",
            systemImage: "arrow.clockwise"
        ))
        #expect(needsLiveLoad.offlineIndicator.display == .synced)
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
        try assertShoppingNoBodyRequest(
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
        try assertShoppingNoBodyRequest(
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

    private static func shoppingList() throws -> ShoppingListState {
        try ShoppingListState.decodeFromBundle()
    }

    private static func shoppingListWithCompletedItem() throws -> ShoppingListState {
        try shoppingList().settingChecked(
            true,
            itemID: "item_spaghetti",
            checkedAt: "2026-06-26T01:50:00.000Z",
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
