import Foundation
import Testing
@testable import SpoonjoyCore

/// A drain writes the edits the server accepted into the cache. These states used to trap on a force unwrap; a
/// fresh install whose queue drains before an account is known is one of them.
@Suite("Native sync drain cache patch")
struct NativeSyncDrainCachePatchTests {
    private static let createdAt = "2026-06-16T09:00:00.000Z"

    private static let shoppingAdd = NativeQueuedMutation.shoppingAddItem(
        name: "lemons", quantity: 4, unit: "each", categoryKey: "produce", iconKey: "lemon",
        clientMutationID: "cm_shopping_add", createdAt: createdAt
    )

    private static func cachedShoppingItem() throws -> NativeSyncCachedRecord {
        let item = ShoppingListItem(
            id: "item_milk", name: "milk", quantity: 1, unit: nil, checked: false, checkedAt: nil, deletedAt: nil,
            categoryKey: nil, iconKey: nil, sortIndex: 0, updatedAt: createdAt
        )
        return NativeSyncCachedRecord(kind: .shoppingItem, resourceID: item.id, payload: try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(item)), serverRevision: nil)
    }

    @Test
    func drainWithNoAccountSkipsTheCachePatchInsteadOfTrapping() throws {
        let snapshot = NativeSyncSnapshot(checkpoint: nil, queue: NativeMutationQueue(), cachedRecords: [try Self.cachedShoppingItem()])
        let recipeUpdate = NativeQueuedMutation.recipeUpdate(
            recipeID: "recipe_lemon", clientMutationID: "cm_recipe_update", title: "Lemon Pasta", description: nil,
            servings: "4", createdAt: Self.createdAt
        )
        let cookbookCreate = NativeQueuedMutation.cookbookCreate(clientMutationID: "cm_cookbook_create", title: "Weeknights", createdAt: Self.createdAt)

        let patch = try NativeSyncEngine.drainedCachePatch(
            drainedMutations: [Self.shoppingAdd, recipeUpdate, cookbookCreate],
            snapshot: snapshot,
            accountID: nil
        )

        #expect(patch.upserting.isEmpty)
        #expect(patch.deletingCacheKeys.isEmpty)
    }

    @Test
    func shoppingPatchWithNoDrainedEditsAndNoCheckpointReturnsNothingInsteadOfTrapping() throws {
        let snapshot = NativeSyncSnapshot(checkpoint: nil, queue: NativeMutationQueue(), cachedRecords: [try Self.cachedShoppingItem()])

        let patch = try NativeSyncEngine.drainedShoppingCachePatch(drainedMutations: [], snapshot: snapshot, accountID: "chef_ari")

        #expect(patch.upserting.isEmpty)
        #expect(patch.deletingCacheKeys.isEmpty)
    }

    @Test
    func shoppingPatchWithAnAccountStillWritesTheAcceptedEdit() throws {
        let snapshot = NativeSyncSnapshot(checkpoint: nil, queue: NativeMutationQueue(), cachedRecords: [try Self.cachedShoppingItem()])

        let patch = try NativeSyncEngine.drainedCachePatch(drainedMutations: [Self.shoppingAdd], snapshot: snapshot, accountID: "chef_ari")

        #expect(patch.upserting.contains { $0.kind == .shoppingItem })
    }
}
