import Foundation

public protocol ShoppingSurfaceRepository: Sendable {
    func fetchShoppingList() async throws -> ShoppingListState
}

public struct LiveShoppingSurfaceRepository: ShoppingSurfaceRepository {
    private let transport: any SpoonjoyAPITransport
    private let configuration: APIClientConfiguration

    public init(
        transport: any SpoonjoyAPITransport = URLSessionAPITransport(),
        configuration: APIClientConfiguration
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func fetchShoppingList() async throws -> ShoppingListState {
        let envelope = try await transport.send(
            ShoppingListRequests.readShoppingList(),
            configuration: configuration,
            decode: ShoppingListReadData.self
        )
        return ShoppingListState(readData: envelope.data)
    }
}

public enum ShoppingSurfaceConnectivity: Equatable, Sendable {
    case online
    case offline
}

public enum ShoppingSurfaceLoadState: Equatable, Sendable {
    case needsLiveLoad
    case loaded
}

public enum ShoppingActionConfirmation: Equatable, Sendable {
    case required
    case confirmed
}

public struct ShoppingActionConfirmationPrompt: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirmButtonTitle: String
    public let isDestructive: Bool

    public init(title: String, message: String, confirmButtonTitle: String, isDestructive: Bool) {
        self.title = title
        self.message = message
        self.confirmButtonTitle = confirmButtonTitle
        self.isDestructive = isDestructive
    }
}

public struct ShoppingSurfaceEmptyState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

public struct ShoppingReceiptState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String
    public let actionTitle: String?
    public let duplicateCountLabel: String?

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        duplicateCountLabel: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.duplicateCountLabel = duplicateCountLabel
    }

    public var emptyState: ShoppingSurfaceEmptyState {
        ShoppingSurfaceEmptyState(title: title, message: message, systemImage: systemImage)
    }
}

public struct ShoppingSurfaceConflictBanner: Equatable, Sendable {
    public let localClientMutationID: String
    public let message: String
    public let actionTitle: String

    public init(localClientMutationID: String, message: String, actionTitle: String) {
        self.localClientMutationID = localClientMutationID
        self.message = message
        self.actionTitle = actionTitle
    }
}

public enum ShoppingSurfaceAction: Equatable, Sendable {
    case addItem(name: String, quantity: Double?, unit: String?, categoryKey: String?, iconKey: String?, clientMutationID: String)
    case setItemChecked(itemID: String, checked: Bool, clientMutationID: String)
    case deleteItem(itemID: String, clientMutationID: String, confirmation: ShoppingActionConfirmation)
    case addRecipeIngredients(recipeID: String, scaleFactor: Double, recipeIngredients: [RecipeIngredient], clientMutationID: String)
    case clearCompleted(clientMutationID: String, confirmation: ShoppingActionConfirmation)
    case clearAll(clientMutationID: String, confirmation: ShoppingActionConfirmation)
}

public struct ShoppingSurfaceMutationPlan: Equatable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let updatedShoppingList: ShoppingListState?
    public let blockedReason: String?
    public let confirmationPrompt: ShoppingActionConfirmationPrompt?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        updatedShoppingList: ShoppingListState? = nil,
        blockedReason: String? = nil,
        confirmationPrompt: ShoppingActionConfirmationPrompt? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.updatedShoppingList = updatedShoppingList
        self.blockedReason = blockedReason
        self.confirmationPrompt = confirmationPrompt
    }
}

public enum ShoppingSurfaceMutationOutcome: Equatable, Sendable {
    case synced
    case queuedForSync
}

public enum RecipeShoppingListCoverage {
    public static func hasAllRecipeIngredients(_ recipe: Recipe, in shoppingList: ShoppingListState?) -> Bool {
        guard let shoppingList else {
            return false
        }

        let recipeKeys = Set(recipe.steps.flatMap(\.ingredients).compactMap { ingredient in
            IngredientKey(name: ingredient.name, unit: ingredient.unit)
        })
        guard !recipeKeys.isEmpty else {
            return false
        }

        let shoppingKeys = Set(shoppingList.activeItems.compactMap { item in
            IngredientKey(name: item.name, unit: item.unit)
        })
        return recipeKeys.isSubset(of: shoppingKeys)
    }

    private struct IngredientKey: Hashable {
        let name: String
        let unit: String?

        init?(name: String, unit: String?) {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedName.isEmpty else {
                return nil
            }

            self.name = normalizedName
            let normalizedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            self.unit = normalizedUnit?.isEmpty == false ? normalizedUnit : nil
        }
    }
}

public enum ShoppingSurfaceMutationExecutor {
    @MainActor
    public static func perform(
        _ plan: ShoppingSurfaceMutationPlan,
        queueMutation: (NativeQueuedMutation) async throws -> Void,
        executeRemoteRequest: (APIRequestBuilder) async throws -> Void,
        recordShoppingList: (ShoppingListState) -> Void
    ) async throws -> ShoppingSurfaceMutationOutcome {
        func recordOptimisticListIfNeeded() {
            if let updatedShoppingList = plan.updatedShoppingList {
                recordShoppingList(updatedShoppingList)
            }
        }

        if let queuedMutation = plan.queuedMutation {
            try await queueMutation(queuedMutation)
            recordOptimisticListIfNeeded()
            return .queuedForSync
        }

        var didSyncRemotely = false
        if let requestBuilder = plan.remoteRequestBuilder {
            do {
                try await executeRemoteRequest(requestBuilder)
                didSyncRemotely = true
            } catch let error as APITransportError where error.isOffline {
                if let offlineFallbackMutation = plan.offlineFallbackMutation {
                    try await queueMutation(offlineFallbackMutation)
                    recordOptimisticListIfNeeded()
                    return .queuedForSync
                }
                throw error
            }
        }

        if !didSyncRemotely, let updatedShoppingList = plan.updatedShoppingList {
            recordShoppingList(updatedShoppingList)
        }

        return .synced
    }
}

public struct ShoppingAddItemFormState: Equatable, Sendable {
    public var itemName: String
    public var itemQuantity: String
    public var itemUnit: String
    public var actionStatusMessage: String?
    public var actionErrorMessage: String?

    public init(
        itemName: String = "",
        itemQuantity: String = "",
        itemUnit: String = "",
        actionStatusMessage: String? = nil,
        actionErrorMessage: String? = nil
    ) {
        self.itemName = itemName
        self.itemQuantity = itemQuantity
        self.itemUnit = itemUnit
        self.actionStatusMessage = actionStatusMessage
        self.actionErrorMessage = actionErrorMessage
    }

    @MainActor
    public mutating func submit(
        viewModel: ShoppingSurfaceViewModel,
        clientMutationID: String,
        actionDidPlan: @MainActor (ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome
    ) async {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            actionErrorMessage = "Enter an item before adding it to your shopping list."
            actionStatusMessage = nil
            return
        }

        let quantity: Double?
        if trimmedQuantity.isEmpty {
            quantity = nil
        } else if let parsedQuantity = Double(trimmedQuantity), parsedQuantity.isFinite, parsedQuantity > 0 {
            quantity = parsedQuantity
        } else {
            actionErrorMessage = "Enter a valid quantity."
            actionStatusMessage = nil
            return
        }

        do {
            let plan = try viewModel.plan(.addItem(
                name: trimmedName,
                quantity: quantity,
                unit: itemUnit,
                categoryKey: nil,
                iconKey: nil,
                clientMutationID: clientMutationID
            ))

            let outcome = try await actionDidPlan(plan)
            itemName = ""
            itemQuantity = ""
            itemUnit = ""
            actionStatusMessage = outcome == .queuedForSync ? "Saved for sync" : "Shopping list updated"
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = "Shopping action failed."
            actionStatusMessage = nil
        }
    }
}

public struct ShoppingSurfaceViewModel {
    public private(set) var shoppingList: ShoppingListState?
    public let queuedMutations: [NativeQueuedMutation]
    public let conflicts: [NativeSyncConflict]
    public let connectivity: ShoppingSurfaceConnectivity

    private let now: @Sendable () -> String

    public init(
        shoppingList: ShoppingListState?,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: ShoppingSurfaceConnectivity,
        now: @escaping @Sendable () -> String
    ) {
        self.shoppingList = shoppingList
        self.queuedMutations = queuedMutations
        self.conflicts = conflicts
        self.connectivity = connectivity
        self.now = now
    }

    public static func load(
        repository: any ShoppingSurfaceRepository,
        queuedMutations: [NativeQueuedMutation],
        conflicts: [NativeSyncConflict],
        connectivity: ShoppingSurfaceConnectivity,
        now: @escaping @Sendable () -> String
    ) async throws -> ShoppingSurfaceViewModel {
        let shoppingList = try await repository.fetchShoppingList()
        return ShoppingSurfaceViewModel(
            shoppingList: shoppingList,
            queuedMutations: queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: now
        )
    }

    public var loadState: ShoppingSurfaceLoadState {
        shoppingList == nil ? .needsLiveLoad : .loaded
    }

    public var sections: [ShoppingListReceiptSection] {
        shoppingList?.receiptSections ?? []
    }

    public var activeCountLabel: String {
        "\(shoppingList?.activeItems.count ?? 0) active"
    }

    public var shoppingRunSummary: String {
        guard let shoppingList else {
            return "Ready to sync"
        }

        let activeCount = shoppingList.activeItems.count
        let completedCount = shoppingList.completedItems.count
        if completedCount > 0 {
            return "\(activeCount) active - \(completedCount) checked"
        }

        return "\(activeCount) active"
    }

    public var shoppingReceiptState: ShoppingReceiptState? {
        guard let shoppingList else {
            return emptyReceiptState
        }

        guard shoppingList.activeItems.isEmpty else {
            return nil
        }

        if let queuedReceiptState {
            return queuedReceiptState
        }

        if !shoppingList.completedItems.isEmpty {
            return allCompleteState
        }

        return emptyReceiptState
    }

    public var emptyState: ShoppingSurfaceEmptyState? {
        shoppingReceiptState?.emptyState
    }

    public var emptyReceiptState: ShoppingReceiptState {
        ShoppingReceiptState(
            title: loadState == .needsLiveLoad ? "Sync the receipt" : "Receipt is empty",
            message: loadState == .needsLiveLoad
                ? "Connect to Spoonjoy to load the current market run."
                : "Add an item or pull ingredients from a recipe.",
            systemImage: loadState == .needsLiveLoad ? "arrow.clockwise" : "cart",
            actionTitle: loadState == .needsLiveLoad ? nil : "Add item"
        )
    }

    public var allCompleteState: ShoppingReceiptState {
        ShoppingReceiptState(
            title: "All checked off",
            message: "Nice. Clear checked items when you're ready to reset the receipt.",
            systemImage: "checkmark.circle",
            actionTitle: "Clear checked"
        )
    }

    public var queuedReceiptState: ShoppingReceiptState? {
        guard let queuedWorkSummary else {
            return nil
        }

        return ShoppingReceiptState(
            title: "Saved for sync",
            message: queuedWorkSummary,
            systemImage: "arrow.triangle.2.circlepath",
            actionTitle: "Review queued work"
        )
    }

    public var queuedWorkSummary: String? {
        let count = shoppingQueuedMutations.count
        guard count > 0 else {
            return nil
        }

        return count == 1 ? "1 shopping change waiting to sync" : "\(count) shopping changes waiting to sync"
    }

    public var conflictBanner: ShoppingSurfaceConflictBanner? {
        guard let conflict = shoppingConflicts.first else {
            return nil
        }

        return ShoppingSurfaceConflictBanner(
            localClientMutationID: conflict.clientMutationID,
            message: conflict.message,
            actionTitle: "Review shopping conflict"
        )
    }

    public var offlineIndicator: OfflineIndicatorState {
        if let conflict = shoppingConflicts.first {
            return OfflineIndicatorState(
                display: .conflict(recordID: conflict.clientMutationID, mutationID: conflict.clientMutationID),
                dismissal: nil
            )
        }

        let shoppingQueue = shoppingQueuedMutations
        if !shoppingQueue.isEmpty {
            return OfflineIndicatorState(
                display: .queuedWork(count: shoppingQueue.count, oldestClientMutationID: shoppingQueue.first?.clientMutationID),
                dismissal: nil
            )
        }

        if connectivity == .offline {
            return OfflineIndicatorState(display: .offline, dismissal: nil)
        }

        return OfflineIndicatorState(display: .synced, dismissal: nil)
    }

    public func replacingShoppingList(_ shoppingList: ShoppingListState) -> ShoppingSurfaceViewModel {
        ShoppingSurfaceViewModel(
            shoppingList: shoppingList,
            queuedMutations: queuedMutations,
            conflicts: conflicts,
            connectivity: connectivity,
            now: now
        )
    }

    public func plan(_ action: ShoppingSurfaceAction) throws -> ShoppingSurfaceMutationPlan {
        switch action {
        case .addItem(let name, let quantity, let unit, let categoryKey, let iconKey, let clientMutationID):
            let normalizedName = Self.normalizedName(name)
            guard !normalizedName.isEmpty else {
                return blocked("Enter an item before adding it to your shopping list.")
            }
            let normalizedUnit = Self.normalizedOptionalName(unit)
            let updated = try shoppingList?.addingOrRestoringItem(
                name: normalizedName,
                quantity: quantity,
                unit: normalizedUnit,
                categoryKey: categoryKey,
                iconKey: iconKey,
                clientMutationID: clientMutationID
            ).shoppingList
            return try mutationPlan(
                online: ShoppingListRequests.addItem(
                    name: normalizedName,
                    quantity: quantity,
                    unit: normalizedUnit,
                    categoryKey: categoryKey,
                    iconKey: iconKey,
                    clientMutationID: clientMutationID
                ),
                offline: NativeQueuedMutation.shoppingAddItem(
                    name: normalizedName,
                    quantity: quantity,
                    unit: normalizedUnit,
                    categoryKey: categoryKey,
                    iconKey: iconKey,
                    clientMutationID: clientMutationID,
                    createdAt: now()
                ),
                updatedShoppingList: updated
            )
        case .setItemChecked(let itemID, let checked, let clientMutationID):
            let plannedAt = now()
            let updated = try shoppingList?.settingChecked(
                checked,
                itemID: itemID,
                checkedAt: checked ? plannedAt : nil,
                updatedAt: plannedAt,
                nextSortIndex: nextActiveSortIndex()
            )
            return try mutationPlan(
                online: ShoppingListRequests.setItemChecked(
                    id: itemID,
                    checked: checked,
                    clientMutationID: clientMutationID
                ),
                offline: NativeQueuedMutation.shoppingCheckItem(
                    itemID: itemID,
                    checked: checked,
                    clientMutationID: clientMutationID,
                    createdAt: plannedAt
                ),
                updatedShoppingList: updated
            )
        case .deleteItem(let itemID, let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return ShoppingSurfaceMutationPlan(confirmationPrompt: deletePrompt(itemID: itemID))
            }
            let plannedAt = now()
            return try mutationPlan(
                online: ShoppingListRequests.deleteItem(
                    id: itemID,
                    clientMutationID: clientMutationID,
                    idempotency: .header
                ),
                offline: NativeQueuedMutation.shoppingDeleteItem(
                    itemID: itemID,
                    clientMutationID: clientMutationID,
                    createdAt: plannedAt
                ),
                updatedShoppingList: try shoppingList?.removingItem(id: itemID, deletedAt: plannedAt)
            )
        case .addRecipeIngredients(let recipeID, let scaleFactor, let recipeIngredients, let clientMutationID):
            let plannedAt = now()
            return try mutationPlan(
                online: ShoppingListRequests.addIngredientsFromRecipe(
                    recipeID: recipeID,
                    scaleFactor: scaleFactor,
                    clientMutationID: clientMutationID
                ),
                offline: NativeQueuedMutation.shoppingAddFromRecipe(
                    recipeID: recipeID,
                    scaleFactor: scaleFactor,
                    recipeIngredients: recipeIngredients,
                    clientMutationID: clientMutationID,
                    createdAt: plannedAt
                ),
                updatedShoppingList: try shoppingList?.addingRecipeIngredients(
                    recipeID: recipeID,
                    scaleFactor: scaleFactor,
                    recipeIngredients: recipeIngredients,
                    clientMutationID: clientMutationID
                )
            )
        case .clearCompleted(let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return ShoppingSurfaceMutationPlan(confirmationPrompt: clearCompletedPrompt)
            }
            let plannedAt = now()
            return try mutationPlan(
                online: ShoppingListRequests.clearCompleted(clientMutationID: clientMutationID),
                offline: NativeQueuedMutation.shoppingClearCompleted(
                    clientMutationID: clientMutationID,
                    createdAt: plannedAt
                ),
                updatedShoppingList: try removingItems(matching: { $0.checked || $0.checkedAt != nil }, deletedAt: plannedAt)
            )
        case .clearAll(let clientMutationID, let confirmation):
            guard confirmation == .confirmed else {
                return ShoppingSurfaceMutationPlan(confirmationPrompt: clearAllPrompt)
            }
            let plannedAt = now()
            return try mutationPlan(
                online: ShoppingListRequests.clearAll(clientMutationID: clientMutationID),
                offline: NativeQueuedMutation.shoppingClearAll(
                    clientMutationID: clientMutationID,
                    createdAt: plannedAt
                ),
                updatedShoppingList: try removingItems(matching: { _ in true }, deletedAt: plannedAt)
            )
        }
    }

    private var shoppingQueuedMutations: [NativeQueuedMutation] {
        queuedMutations.filter { mutation in
            switch mutation.queueableKind {
            case .shoppingAddItem, .shoppingCheckItem, .shoppingDeleteItem, .shoppingAddFromRecipe, .shoppingClearCompleted, .shoppingClearAll:
                true
            default:
                false
            }
        }
    }

    private var shoppingConflicts: [NativeSyncConflict] {
        let shoppingClientMutationIDs = Set(shoppingQueuedMutations.map(\.clientMutationID))
        return conflicts.filter { shoppingClientMutationIDs.contains($0.clientMutationID) }
    }

    private func mutationPlan(
        online: APIRequestBuilder,
        offline: NativeQueuedMutation,
        updatedShoppingList: ShoppingListState?
    ) -> ShoppingSurfaceMutationPlan {
        if !shoppingQueuedMutations.isEmpty {
            return ShoppingSurfaceMutationPlan(
                queuedMutation: offline,
                updatedShoppingList: updatedShoppingList
            )
        }

        switch connectivity {
        case .online:
            return ShoppingSurfaceMutationPlan(
                remoteRequestBuilder: online,
                offlineFallbackMutation: offline,
                updatedShoppingList: updatedShoppingList
            )
        case .offline:
            return ShoppingSurfaceMutationPlan(
                queuedMutation: offline,
                updatedShoppingList: updatedShoppingList
            )
        }
    }

    private func removingItems(
        matching predicate: (ShoppingListItem) -> Bool,
        deletedAt: String
    ) throws -> ShoppingListState? {
        guard var updated = shoppingList else {
            return nil
        }

        for item in updated.receiptItems where predicate(item) {
            updated = try updated.removingItem(id: item.id, deletedAt: deletedAt)
        }

        return updated
    }

    private func deletePrompt(itemID: String) -> ShoppingActionConfirmationPrompt {
        let itemName = shoppingList?.item(id: itemID)?.name ?? "this item"
        return ShoppingActionConfirmationPrompt(
            title: "Remove \(itemName)?",
            message: "This removes the item from your shopping list and syncs the change across your devices.",
            confirmButtonTitle: "Remove Item",
            isDestructive: true
        )
    }

    private var clearCompletedPrompt: ShoppingActionConfirmationPrompt {
        ShoppingActionConfirmationPrompt(
            title: "Clear completed items?",
            message: "This removes checked items and syncs the change across your devices.",
            confirmButtonTitle: "Clear Completed",
            isDestructive: true
        )
    }

    private var clearAllPrompt: ShoppingActionConfirmationPrompt {
        ShoppingActionConfirmationPrompt(
            title: "Clear your whole shopping list?",
            message: "This removes every active item and syncs the change across your devices.",
            confirmButtonTitle: "Clear All",
            isDestructive: true
        )
    }

    private func nextActiveSortIndex() -> Int {
        ((shoppingList?.activeItems.map(\.sortIndex).max()) ?? -1) + 1
    }

    private func blocked(_ reason: String) -> ShoppingSurfaceMutationPlan {
        ShoppingSurfaceMutationPlan(blockedReason: reason)
    }

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedOptionalName(_ value: String?) -> String? {
        guard let normalized = value.map(normalizedName), !normalized.isEmpty else {
            return nil
        }

        return normalized
    }
}

private extension ShoppingListState {
    init(readData: ShoppingListReadData) {
        self.init(
            id: readData.shoppingList.id,
            chef: readData.shoppingList.chef,
            items: readData.shoppingList.items,
            nextCursor: readData.nextCursor.rawValue,
            updatedAt: readData.shoppingList.updatedAt
        )
    }
}
