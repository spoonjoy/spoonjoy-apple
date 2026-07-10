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
            updatedAt: "2026-06-01T00:20:00.000Z",
            nextSortIndex: 4
        )
        let checkedLemons = try #require(checked.item(id: "item_lemons"))

        #expect(checkedLemons.checked)
        #expect(checkedLemons.checkedAt == "2026-06-01T00:20:00.000Z")
        #expect(checked.activeItems.map(\.id) == ["item_spaghetti", "item_parmesan"])
        #expect(checked.receiptItems.map(\.id) == ["item_spaghetti", "item_parmesan", "item_lemons"])

        let unchecked = try checked.settingChecked(
            false,
            itemID: "item_lemons",
            checkedAt: nil,
            updatedAt: "2026-06-01T00:21:00.000Z",
            nextSortIndex: 4
        )
        let uncheckedLemons = try #require(unchecked.item(id: "item_lemons"))
        #expect(!uncheckedLemons.checked)
        #expect(uncheckedLemons.checkedAt == nil)
        #expect(uncheckedLemons.updatedAt == "2026-06-01T00:21:00.000Z")

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
            name: " LEMONS ",
            quantity: 1,
            unit: " EACH ",
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
        #expect(lemons.sortIndex == 0)
    }

    @Test("shopping list operations cover local create, display, grouping, and error edges")
    func shoppingListOperationsCoverLocalCreateDisplayGroupingAndErrors() throws {
        let state = try ShoppingListState.decodeFromBundle()
        let created = try state.addingOrRestoringItem(
            name: "  Butter  ",
            quantity: nil,
            unit: " Stick ",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_add_butter"
        )
        let butter = try #require(created.shoppingList.item(id: "item_local_mutation_add_butter"))

        #expect(created.created)
        #expect(!created.updated)
        #expect(butter.name == "butter")
        #expect(butter.unit == "stick")
        #expect(butter.displayQuantity == "stick")
        #expect(created.shoppingList.receiptSections.last?.title == "Other")

        let decimalItem = ShoppingListItem(
            id: "item_decimal",
            name: "olive oil",
            quantity: 1.5,
            unit: nil,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: "pantry-dry-goods",
            iconKey: nil,
            sortIndex: 0,
            updatedAt: "2026-06-01T00:00:00.000Z"
        )
        let emptyQuantityItem = ShoppingListItem(
            id: "item_empty_quantity",
            name: "pepper",
            quantity: nil,
            unit: nil,
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: nil,
            iconKey: nil,
            sortIndex: 0,
            updatedAt: "2026-06-01T00:00:00.000Z"
        )
        let tiedSortState = ShoppingListState(
            id: "shopping_list_ties",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [emptyQuantityItem, decimalItem],
            nextCursor: "cursor",
            updatedAt: "2026-06-01T00:00:00.000Z"
        )

        #expect(decimalItem.displayQuantity == "1.5")
        #expect(emptyQuantityItem.displayQuantity == "")
        #expect(tiedSortState.activeItems.map(\.id) == ["item_decimal", "item_empty_quantity"])
        #expect(tiedSortState.receiptSections.map(\.title) == ["Pantry Dry Goods", "Other"])

        let mergedWithoutQuantity = try state.addingOrRestoringItem(
            name: "lemons",
            quantity: nil,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_merge_without_quantity"
        )
        let mergedLemons = try #require(mergedWithoutQuantity.shoppingList.item(id: "item_lemons"))
        #expect(mergedLemons.quantity == 2)
        #expect(mergedLemons.categoryKey == "produce")
        #expect(mergedLemons.iconKey == "lemon")

        let emptyState = ShoppingListState(
            id: "shopping_list_empty",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [],
            nextCursor: "cursor",
            updatedAt: "2026-06-01T00:00:00.000Z"
        )
        let createdInEmptyState = try emptyState.addingOrRestoringItem(
            name: "salt",
            quantity: 1,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_add_salt"
        )
        #expect(createdInEmptyState.shoppingList.activeItems.first?.sortIndex == 0)

        let nilQuantityState = ShoppingListState(
            id: "shopping_list_nil_quantity",
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            items: [emptyQuantityItem],
            nextCursor: "cursor",
            updatedAt: "2026-06-01T00:00:00.000Z"
        )
        let mergedNilQuantity = try nilQuantityState.addingOrRestoringItem(
            name: "pepper",
            quantity: 2,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_merge_pepper"
        )
        #expect(mergedNilQuantity.shoppingList.item(id: "item_empty_quantity")?.quantity == 2)
    }

    @Test("shopping list restore matches normalized unit and moves restored rows to active tail")
    func shoppingListRestoreMatchesNormalizedUnitAndMovesRestoredRowsToTail() throws {
        let state = try ShoppingListState.decodeFromBundle()
        let checkedState = try state.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: "2026-06-01T00:20:00.000Z",
            updatedAt: "2026-06-01T00:20:00.000Z",
            nextSortIndex: 4
        )
        let restoredChecked = try checkedState.addingOrRestoringItem(
            name: " lemons ",
            quantity: 1,
            unit: " EACH ",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_restore_checked_lemons"
        )
        let restoredLemons = try #require(restoredChecked.shoppingList.item(id: "item_lemons"))

        #expect(restoredLemons.quantity == 3)
        #expect(!restoredLemons.checked)
        #expect(restoredLemons.checkedAt == nil)
        #expect(restoredLemons.sortIndex == 3)
        #expect(restoredChecked.shoppingList.activeItems.map(\.id) == ["item_spaghetti", "item_parmesan", "item_lemons"])

        let restoredDeleted = try state.addingOrRestoringItem(
            name: " BASIL ",
            quantity: 2,
            unit: " BUNCH ",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "mutation_restore_deleted_basil"
        )
        let restoredBasil = try #require(restoredDeleted.shoppingList.item(id: "item_removed_basil"))

        #expect(restoredBasil.quantity == 3)
        #expect(restoredBasil.unit == "bunch")
        #expect(restoredBasil.deletedAt == nil)
        #expect(restoredBasil.sortIndex == 3)
        #expect(restoredDeleted.shoppingList.activeItems.map(\.id) == ["item_lemons", "item_spaghetti", "item_parmesan", "item_removed_basil"])
    }

    @Test("shopping list operations report useful errors")
    func shoppingListOperationsReportUsefulErrors() throws {
        let state = try ShoppingListState.decodeFromBundle()

        #expect(try shoppingErrorDescription { _ = try state.settingChecked(true, itemID: "missing", checkedAt: nil, updatedAt: "2026-06-01T00:00:00.000Z", nextSortIndex: 0) } == "Shopping list item missing was not found.")
        #expect(try shoppingErrorDescription { _ = try state.removingItem(id: "missing", deletedAt: "2026-06-01T00:00:00.000Z") } == "Shopping list item missing was not found.")
        #expect(try shoppingErrorDescription {
            _ = try state.addingOrRestoringItem(
                name: "   ",
                quantity: nil,
                unit: nil,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: "mutation_empty"
            )
        } == "Shopping list item name must be non-empty.")
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

    @Test("cook mode progress handles empty, duplicate, invalid, and stale state")
    func cookModeProgressHandlesEmptyDuplicateInvalidAndStaleState() throws {
        let empty = CookModeProgress(recipeID: "recipe_empty", stepIDs: [], startedAt: "2026-06-01T00:00:00.000Z")
        #expect(empty.currentStepID == nil)
        #expect(empty.completionFraction == 0)
        #expect(empty.advancing().activeStepIndex == 0)

        let started = CookModeProgress(
            recipeID: "recipe_lemon_pantry_pasta",
            stepIDs: ["step_1"],
            startedAt: "2026-06-01T00:00:00.000Z"
        )
        let completed = try started.markingStepCompleted("step_1", updatedAt: "2026-06-01T00:01:00.000Z")
        let completedAgain = try completed.markingStepCompleted("step_1", updatedAt: "2026-06-01T00:02:00.000Z")
        #expect(completedAgain.completedStepIDs == ["step_1"])
        #expect(try cookModeErrorDescription { _ = try started.markingStepCompleted("missing", updatedAt: "2026-06-01T00:01:00.000Z") } == "Cook mode step missing was not found.")

        let staleSnapshot = Data(
            """
            {
              "recipeID": "recipe_lemon_pantry_pasta",
              "stepIDs": ["step_1"],
              "activeStepIndex": 4,
              "completedStepIDs": ["step_1", "stale_step"],
              "startedAt": "2026-06-01T00:00:00.000Z",
              "updatedAt": "2026-06-01T00:02:00.000Z"
            }
            """.utf8
        )
        let restored = try CookModeProgress.restore(from: staleSnapshot)
        #expect(restored.activeStepIndex == 0)
        #expect(restored.completedStepIDs == ["step_1"])

        let restoredCurrentOnly = CookModeProgress(
            recipeID: "recipe_current_only",
            completedStepIDs: [],
            currentStepID: "step_current"
        )
        #expect(restoredCurrentOnly.stepIDs == ["step_current"])
        #expect(restoredCurrentOnly.currentStepID == "step_current")
        let restoredEmpty = CookModeProgress(
            recipeID: "recipe_empty_restore",
            completedStepIDs: [],
            currentStepID: nil
        )
        #expect(restoredEmpty.stepIDs.isEmpty)
        #expect(restoredEmpty.currentStepID == nil)
    }

    @Test("text capture drafts stay local and import ready")
    func textCaptureDraftsStayLocalAndImportReady() throws {
        let draft = try CaptureDraft.localText(
            id: "capture_text_1",
            rawText: "  2 eggs\n1 cup rice  ",
            createdAt: "2026-06-01T00:30:00.000Z"
        )

        #expect(draft.source == .text)
        #expect(draft.status == .localOnly)
        #expect(draft.rawText == "2 eggs\n1 cup rice")
        #expect(draft.previewLines == ["2 eggs", "1 cup rice"])
        #expect(draft.canCreateServerRecipe)
        let importSource = try draft.importSource().jsonValue()
        #expect(draft.importReadiness == .ready)
        #expect(importSource == .object([
            "type": .string("text"),
            "text": .string("2 eggs\n1 cup rice")
        ]))
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

    @Test("settings state handles signed-out local and kitchen-scope variants")
    func settingsStateHandlesSignedOutLocalAndKitchenScopeVariants() {
        let signedOut = SettingsState(
            auth: .signedOut,
            environment: .local(baseURL: URL(string: "http://127.0.0.1:5173")!),
            offline: .unavailable,
            preferredCookModeTextSize: .standard
        )
        let kitchenScoped = SettingsState(
            auth: .signedIn(username: "ari", scopes: ["kitchen:read", "kitchen:write"], tokenExpiresAt: nil),
            environment: .production(baseURL: URL(string: "https://spoonjoy.app")!),
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            preferredCookModeTextSize: .standard
        )

        #expect(!signedOut.canReadShoppingList)
        #expect(!signedOut.canWriteShoppingList)
        #expect(signedOut.environment.apiBaseURL == URL(string: "http://127.0.0.1:5173/api/v1"))
        #expect(signedOut.offline.statusLabel == "Offline cache unavailable")
        #expect(signedOut.statusRows.first?.value == "Signed out")
        #expect(kitchenScoped.canReadShoppingList)
        #expect(kitchenScoped.canWriteShoppingList)
        #expect(kitchenScoped.offline.statusLabel == "Offline cache ready: 1 snapshot")
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

    @Test("kitchen fixture supports explicit fallback construction")
    func kitchenFixtureSupportsExplicitFallbackConstruction() {
        let kitchen = KitchenFixtureState(
            status: .bootstrap,
            leadObject: .recipe(id: "recipe_local", title: "Local Recipe"),
            primaryAction: .startCookMode(recipeID: "recipe_local"),
            counts: KitchenCounts(recipes: 1, cookbooks: 0, shoppingItems: 0),
            offlineRestore: OfflineRestoreMetadata(snapshotID: "local", includesShoppingList: false)
        )

        #expect(kitchen.status == .bootstrap)
        #expect(kitchen.leadObject == .recipe(id: "recipe_local", title: "Local Recipe"))
        #expect(kitchen.primaryAction == .startCookMode(recipeID: "recipe_local"))
        #expect(kitchen.counts == KitchenCounts(recipes: 1, cookbooks: 0, shoppingItems: 0))
        #expect(kitchen.offlineRestore == OfflineRestoreMetadata(snapshotID: "local", includesShoppingList: false))
    }

    @Test("kitchen fixture associated values encode back to fixture shape")
    func kitchenFixtureAssociatedValuesEncodeBackToFixtureShape() throws {
        let kitchen = try KitchenFixtureState.decodeFromBundle()
        let encodedLead = try JSONEncoder().encode(kitchen.leadObject)
        let encodedAction = try JSONEncoder().encode(kitchen.primaryAction)
        let decodedLead = try JSONDecoder().decode(KitchenLeadObject.self, from: encodedLead)
        let decodedAction = try JSONDecoder().decode(KitchenPrimaryAction.self, from: encodedAction)
        let encodedKitchen = try JSONEncoder().encode(kitchen)
        let decodedKitchen = try JSONDecoder().decode(KitchenFixtureState.self, from: encodedKitchen)

        #expect(decodedLead == kitchen.leadObject)
        #expect(decodedAction == kitchen.primaryAction)
        #expect(decodedKitchen == kitchen)
    }
}

private func shoppingErrorDescription(_ operation: () throws -> Void) throws -> String? {
    do {
        try operation()
        return nil
    } catch let error as KitchenStateError {
        return error.description
    }
}

private func cookModeErrorDescription(_ operation: () throws -> Void) throws -> String? {
    do {
        try operation()
        return nil
    } catch let error as KitchenStateError {
        return error.description
    }
}
