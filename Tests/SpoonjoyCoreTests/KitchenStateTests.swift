import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Kitchen state domain")
struct KitchenStateTests {
    @Test("shopping list fixture decodes receipt rows and active ordering")
    func shoppingListFixtureDecodesReceiptRowsAndActiveOrdering() throws {
        let state = try ShoppingListState.decodeFromBundle()

        #expect(state.id == "shopping_list_ari")
        #expect(state.chef == ChefSummary(id: "chef_ari", username: "ari"))
        #expect(state.nextCursor == "v1.fixture.shopping.cursor")
        #expect(state.activeItems.map(\.id) == ["item_lemons", "item_spaghetti", "item_parmesan"])

        let lemons = try #require(state.item(id: "item_lemons"))
        #expect(lemons.name == "lemons")
        #expect(lemons.displayQuantity == "2 each")
        #expect(lemons.categoryKey == "produce")
        #expect(lemons.iconKey == "lemon")
        #expect(!lemons.checked)
        #expect(lemons.deletedAt == nil)

        #expect(state.receiptSections.map(\.title) == ["Produce", "Pantry", "Dairy"])
        #expect(state.receiptSections.first?.items.map(\.id) == ["item_lemons"])
    }

    @Test("shopping list checkoff and removal keep receipt ordering stable")
    func shoppingListCheckoffAndRemovalKeepOrderingStable() throws {
        let state = try ShoppingListState.decodeFromBundle()
        let checked = try state.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: "2026-06-01T00:20:00.000Z",
            nextSortIndex: 4
        )
        let checkedLemons = try #require(checked.item(id: "item_lemons"))

        #expect(checkedLemons.checked)
        #expect(checkedLemons.checkedAt == "2026-06-01T00:20:00.000Z")
        #expect(checked.activeItems.map(\.id) == ["item_spaghetti", "item_parmesan", "item_lemons"])

        let unchecked = try checked.settingChecked(false, itemID: "item_lemons", checkedAt: nil, nextSortIndex: 4)
        let uncheckedLemons = try #require(unchecked.item(id: "item_lemons"))
        #expect(!uncheckedLemons.checked)
        #expect(uncheckedLemons.checkedAt == nil)

        let removed = try unchecked.removingItem(
            id: "item_spaghetti",
            deletedAt: "2026-06-01T00:21:00.000Z"
        )
        #expect(removed.item(id: "item_spaghetti")?.deletedAt == "2026-06-01T00:21:00.000Z")
        #expect(removed.activeItems.map(\.id) == ["item_parmesan", "item_lemons"])
    }

    @Test("shopping list add or restore merges matching display items")
    func shoppingListAddOrRestoreMergesMatchingDisplayItems() throws {
        let state = try ShoppingListState.decodeFromBundle()
        let result = try state.addingOrRestoringItem(
            name: "lemons",
            quantity: 1,
            unit: "each",
            categoryKey: "produce",
            iconKey: "lemon",
            clientMutationID: "mutation_add_lemons"
        )
        let lemons = try #require(result.shoppingList.item(id: "item_lemons"))

        #expect(!result.created)
        #expect(result.updated)
        #expect(result.mutation == ShoppingListMutationMetadata(clientMutationID: "mutation_add_lemons", replayed: false))
        #expect(lemons.quantity == 3)
        #expect(lemons.displayQuantity == "3 each")
        #expect(!lemons.checked)
        #expect(lemons.deletedAt == nil)
    }

    @Test("cook mode progress persists current step and completion")
    func cookModeProgressPersistsCurrentStepAndCompletion() throws {
        let started = CookModeProgress(
            recipeID: "recipe_lemon_pantry_pasta",
            stepIDs: ["step_lemon_pasta_1", "step_lemon_pasta_2", "step_lemon_pasta_3"],
            startedAt: "2026-06-01T00:00:00.000Z"
        )

        #expect(started.currentStepID == "step_lemon_pasta_1")
        #expect(started.completionFraction == 0)

        let progressed = try started
            .markingStepCompleted("step_lemon_pasta_1", updatedAt: "2026-06-01T00:05:00.000Z")
            .advancing()
        #expect(progressed.currentStepID == "step_lemon_pasta_2")
        #expect(progressed.completedStepIDs == ["step_lemon_pasta_1"])
        #expect(progressed.completionFraction == 1.0 / 3.0)

        let snapshot = try progressed.snapshot()
        let restored = try CookModeProgress.restore(from: snapshot)
        #expect(restored == progressed)
    }

    @Test("capture drafts stay local until explicitly promoted")
    func captureDraftsStayLocalUntilPromoted() throws {
        let draft = try CaptureDraft.localText(
            id: "capture_text_1",
            rawText: "  2 eggs\n1 cup rice  ",
            createdAt: "2026-06-01T00:30:00.000Z"
        )

        #expect(draft.source == .text)
        #expect(draft.status == .localOnly)
        #expect(draft.rawText == "2 eggs\n1 cup rice")
        #expect(draft.previewLines == ["2 eggs", "1 cup rice"])
        #expect(!draft.canCreateServerRecipe)
        #expect(draft.imageAssetIdentifier == nil)
    }

    @Test("capture drafts reject empty local text")
    func captureDraftsRejectEmptyLocalText() {
        var validationMessage: String?

        do {
            _ = try CaptureDraft.localText(
                id: "capture_empty",
                rawText: "   ",
                createdAt: "2026-06-01T00:30:00.000Z"
            )
        } catch let error as CaptureDraftValidationError {
            validationMessage = error.description
        } catch {
            validationMessage = String(describing: error)
        }

        #expect(validationMessage == "Capture draft capture_empty must include text or an image reference.")
    }

    @Test("settings state describes auth environment and offline readiness")
    func settingsStateDescribesAuthEnvironmentAndOfflineReadiness() {
        let settings = SettingsState(
            auth: .signedIn(username: "ari", scopes: ["shopping_list:read"], tokenExpiresAt: "2026-06-02T00:00:00.000Z"),
            environment: .production(baseURL: URL(string: "https://spoonjoy.app")!),
            offline: .available(snapshotCount: 2, lastRestoredAt: "2026-06-01T00:40:00.000Z"),
            preferredCookModeTextSize: .large
        )

        #expect(settings.canReadShoppingList)
        #expect(!settings.canWriteShoppingList)
        #expect(settings.environment.apiBaseURL == URL(string: "https://spoonjoy.app/api/v1"))
        #expect(settings.offline.statusLabel == "Offline cache ready: 2 snapshots")
        #expect(settings.statusRows.map(\.id) == ["auth", "environment", "offline", "cook-mode-text"])
    }

    @Test("kitchen fixture exposes the lead food object and restore metadata")
    func kitchenFixtureExposesLeadFoodObjectAndRestoreMetadata() throws {
        let kitchen = try KitchenFixtureState.decodeFromBundle()

        #expect(kitchen.status == .ready)
        #expect(kitchen.leadObject == .recipe(id: "recipe_lemon_pantry_pasta", title: "Lemon Pantry Pasta"))
        #expect(kitchen.primaryAction == .startCookMode(recipeID: "recipe_lemon_pantry_pasta"))
        #expect(kitchen.counts == KitchenCounts(recipes: 2, cookbooks: 2, shoppingItems: 3))
        #expect(kitchen.offlineRestore.snapshotID == "snapshot_weeknight")
        #expect(kitchen.offlineRestore.includesShoppingList)
    }
}
