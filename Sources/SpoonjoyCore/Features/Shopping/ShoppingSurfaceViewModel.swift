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

public enum ShoppingReceiptStateRole: Equatable, Sendable {
    case ordinary
    case success
}

public struct ShoppingReceiptState: Equatable, Sendable {
    public let title: String
    public let message: String
    public let systemImage: String
    public let actionTitle: String?
    public let duplicateCountLabel: String?
    public let role: ShoppingReceiptStateRole

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        duplicateCountLabel: String? = nil,
        role: ShoppingReceiptStateRole = .ordinary
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.duplicateCountLabel = duplicateCountLabel
        self.role = role
    }

    public var isSuccess: Bool {
        role == .success
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

public enum ShoppingSurfaceMutationKind: String, Equatable, Sendable {
    case addItem
    case setItemChecked
    case deleteItem
    case addRecipeIngredients
    case clearCompleted
    case clearAll
}

public struct ShoppingSurfaceMutationIdentity: Equatable, Sendable {
    public let kind: ShoppingSurfaceMutationKind
    public let clientMutationID: String
    public let itemID: String?

    public init(kind: ShoppingSurfaceMutationKind, clientMutationID: String, itemID: String? = nil) {
        self.kind = kind
        self.clientMutationID = clientMutationID
        self.itemID = itemID
    }
}

public struct ShoppingSurfaceMutationPlan: Equatable {
    public let identity: ShoppingSurfaceMutationIdentity?
    public let action: ShoppingSurfaceAction?
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let originalShoppingList: ShoppingListState?
    public let updatedShoppingList: ShoppingListState?
    public let blockedReason: String?
    public let confirmationPrompt: ShoppingActionConfirmationPrompt?

    public init(
        identity: ShoppingSurfaceMutationIdentity? = nil,
        action: ShoppingSurfaceAction? = nil,
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        originalShoppingList: ShoppingListState? = nil,
        updatedShoppingList: ShoppingListState? = nil,
        blockedReason: String? = nil,
        confirmationPrompt: ShoppingActionConfirmationPrompt? = nil
    ) {
        self.identity = identity
        self.action = action
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.originalShoppingList = originalShoppingList
        self.updatedShoppingList = updatedShoppingList
        self.blockedReason = blockedReason
        self.confirmationPrompt = confirmationPrompt
    }
}

public enum ShoppingSurfaceMutationOutcome: Equatable, Sendable {
    case synced
    case queuedForSync
    case recovering
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

@MainActor
public final class ShoppingMutationCoordinator {
    public typealias PersistAlreadyAppliedBatch = @MainActor ([NativeQueuedMutation]) async throws -> Void
    public typealias ExecuteRemote = @MainActor (APIRequestBuilder) async throws -> Void
    public typealias FetchShoppingList = @MainActor () async throws -> ShoppingListState
    public typealias RecordShoppingList = @MainActor (ShoppingListState) -> Void
    public typealias RecordFeedback = @MainActor (ShoppingMutationFeedback?) -> Void

    private struct Entry {
        let plan: ShoppingSurfaceMutationPlan
        let generation: UInt64
        let scopeEpoch: UInt64
        let continuation: CheckedContinuation<ShoppingSurfaceMutationOutcome, Error>
    }

    private let persistAlreadyAppliedBatch: PersistAlreadyAppliedBatch
    private let executeRemote: ExecuteRemote
    private let fetchShoppingList: FetchShoppingList
    private let recordShoppingList: RecordShoppingList
    private let recordFeedback: RecordFeedback
    private var entries: [Entry] = []
    private var isDraining = false
    private var baselineShoppingList: ShoppingListState?
    private var nextGeneration: UInt64 = 0
    private var scopeEpoch: UInt64 = 0
    private var drainTask: Task<Void, Never>?
    private var pendingPersistenceBatch: [NativeQueuedMutation] = []
    private var pendingRecoveryPlan: ShoppingSurfaceMutationPlan?
    private var pendingRecoveryRequiresReplay = false

    public init(
        persistAlreadyAppliedBatch: @escaping PersistAlreadyAppliedBatch,
        executeRemote: @escaping ExecuteRemote,
        fetchShoppingList: @escaping FetchShoppingList,
        recordShoppingList: @escaping RecordShoppingList,
        recordFeedback: @escaping RecordFeedback = { _ in }
    ) {
        self.persistAlreadyAppliedBatch = persistAlreadyAppliedBatch
        self.executeRemote = executeRemote
        self.fetchShoppingList = fetchShoppingList
        self.recordShoppingList = recordShoppingList
        self.recordFeedback = recordFeedback
    }

    public convenience init(
        persistAlreadyApplied: @escaping @MainActor (NativeQueuedMutation) async throws -> Void,
        executeRemote: @escaping ExecuteRemote,
        fetchShoppingList: @escaping FetchShoppingList,
        recordShoppingList: @escaping RecordShoppingList,
        recordFeedback: @escaping RecordFeedback = { _ in }
    ) {
        self.init(
            persistAlreadyAppliedBatch: { batch in
                for mutation in batch {
                    try await persistAlreadyApplied(mutation)
                }
            },
            executeRemote: executeRemote,
            fetchShoppingList: fetchShoppingList,
            recordShoppingList: recordShoppingList,
            recordFeedback: recordFeedback
        )
    }

    public func submit(_ plan: ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome {
        if let blockedReason = plan.blockedReason {
            throw ShoppingMutationCoordinatorError.blocked(blockedReason)
        }
        return try await withCheckedThrowingContinuation { continuation in
            if entries.isEmpty {
                baselineShoppingList = plan.originalShoppingList
            }
            nextGeneration &+= 1
            entries.append(Entry(
                plan: plan,
                generation: nextGeneration,
                scopeEpoch: scopeEpoch,
                continuation: continuation
            ))
            reprojectVisibleState()
            guard !isDraining else { return }
            isDraining = true
            let drainEpoch = scopeEpoch
            drainTask = Task { @MainActor [weak self] in
                await self?.drain(scopeEpoch: drainEpoch)
            }
        }
    }

    public func resetScope() {
        scopeEpoch &+= 1
        drainTask?.cancel()
        drainTask = nil
        let cancelledEntries = entries
        entries.removeAll()
        baselineShoppingList = nil
        pendingPersistenceBatch = []
        pendingRecoveryPlan = nil
        pendingRecoveryRequiresReplay = false
        isDraining = false
        recordFeedback(nil)
        cancelledEntries.forEach { $0.continuation.resume(throwing: CancellationError()) }
    }

    private func drain(scopeEpoch drainEpoch: UInt64) async {
        while drainEpoch == scopeEpoch, !entries.isEmpty, !Task.isCancelled {
            await performFirstEntry()
        }
        guard drainEpoch == scopeEpoch else { return }
        baselineShoppingList = nil
        drainTask = nil
        isDraining = false
    }

    private func performFirstEntry() async {
        let entry = entries[0]
        let plan = entry.plan
        if plan.queuedMutation != nil {
            await persistQueuedPrefix()
            return
        }

        guard let remoteRequest = plan.remoteRequestBuilder else {
            entries.removeFirst()
            commitPlanToBaseline(plan)
            reprojectVisibleState()
            entry.continuation.resume(returning: .synced)
            return
        }

        var remoteError: Error?
        do {
            try await executeRemote(remoteRequest)
        } catch {
            remoteError = error
        }

        guard isCurrent(entry) else { return }
        if let error = remoteError as? APITransportError, error.isOffline {
            await persistOfflineRemainder(error: error)
            return
        }
        if let error = remoteError as? APITransportError, Self.isIndeterminate(error) {
            await recoverIndeterminate(entry, error: error)
            return
        }
        if let remoteError {
            await rejectDefinite(entry, error: remoteError)
            return
        }
        entries.removeFirst()
        do {
            baselineShoppingList = try await fetchShoppingList()
            reprojectVisibleState()
            pendingRecoveryPlan = nil
            pendingRecoveryRequiresReplay = false
            recordFeedback(nil)
            entry.continuation.resume(returning: .synced)
        } catch {
            commitPlanToBaseline(plan)
            reprojectVisibleState()
            pendingRecoveryPlan = plan
            pendingRecoveryRequiresReplay = false
            recordFeedback(ShoppingMutationFeedback(
                identity: plan.identity,
                state: .recovering,
                message: "Saved. Refresh the shopping list to confirm the latest server state.",
                retryIntent: .reconcileOnly(plan.identity)
            ))
            entry.continuation.resume(returning: .recovering)
        }
    }

    public func retryPendingPersistence() async throws -> ShoppingSurfaceMutationOutcome {
        guard !pendingPersistenceBatch.isEmpty else { return .synced }
        let batch = pendingPersistenceBatch
        try await persistAlreadyAppliedBatch(batch)
        pendingPersistenceBatch = []
        recordFeedback(nil)
        return .queuedForSync
    }

    public func retryCurrentRecovery() async throws -> ShoppingSurfaceMutationOutcome {
        if !pendingPersistenceBatch.isEmpty {
            return try await retryPendingPersistence()
        }
        guard let plan = pendingRecoveryPlan else { return .synced }
        if pendingRecoveryRequiresReplay, let request = plan.remoteRequestBuilder {
            _ = try? await fetchShoppingList()
            try await executeRemote(request)
        }
        let reconciled = try await fetchShoppingList()
        baselineShoppingList = reconciled
        recordShoppingList(reconciled)
        pendingRecoveryPlan = nil
        pendingRecoveryRequiresReplay = false
        recordFeedback(nil)
        return .synced
    }

    private func persistQueuedPrefix() async {
        let queuedEntries = entries.prefix { $0.plan.queuedMutation != nil }
        let batch = queuedEntries.compactMap(\.plan.queuedMutation)
        await persist(batch: batch, entryCount: queuedEntries.count)
    }

    private func persistOfflineRemainder(error: Error) async {
        let batch = entries.compactMap { $0.plan.offlineFallbackMutation ?? $0.plan.queuedMutation }
        guard batch.count == entries.count else {
            await rejectDefinite(entries[0], error: error)
            return
        }
        await persist(batch: batch, entryCount: entries.count)
    }

    private func persist(batch: [NativeQueuedMutation], entryCount: Int) async {
        let persistedEntries = Array(entries.prefix(entryCount))
        do {
            try await persistAlreadyAppliedBatch(batch)
            entries.removeFirst(entryCount)
            baselineShoppingList = projectedState(from: baselineShoppingList, applying: persistedEntries.map(\.plan))
            reprojectVisibleState()
            recordFeedback(nil)
            persistedEntries.forEach { $0.continuation.resume(returning: .queuedForSync) }
        } catch {
            pendingPersistenceBatch = batch
            entries.removeFirst(entryCount)
            baselineShoppingList = projectedState(from: baselineShoppingList, applying: persistedEntries.map(\.plan))
            reprojectVisibleState()
            recordFeedback(ShoppingMutationFeedback(
                identity: persistedEntries.first?.plan.identity,
                state: .failed,
                message: "Couldn't save queued shopping changes. Try again.",
                retryIntent: .persistAlreadyAppliedBatch(batch.map(\.clientMutationID))
            ))
            persistedEntries.forEach { $0.continuation.resume(throwing: error) }
        }
    }

    private func rejectDefinite(_ entry: Entry, error: Error) async {
        entries.removeFirst()
        if !entries.isEmpty, let reconciled = try? await fetchShoppingList() {
            baselineShoppingList = reconciled
        }
        reprojectVisibleState()
        recordFeedback(ShoppingMutationFeedback(
            identity: entry.plan.identity,
            state: .failed,
            message: "Couldn't update this shopping item. Try again.",
            retryIntent: .resubmitWithNewID(entry.plan.identity)
        ))
        entry.continuation.resume(throwing: error)
    }

    private func recoverIndeterminate(_ entry: Entry, error: Error) async {
        entries.removeFirst()
        if let reconciled = try? await fetchShoppingList() {
            baselineShoppingList = reconciled
            reprojectVisibleState()
            recordFeedback(nil)
            entry.continuation.resume(returning: .synced)
            return
        }
        commitPlanToBaseline(entry.plan)
        reprojectVisibleState()
        pendingRecoveryPlan = entry.plan
        pendingRecoveryRequiresReplay = true
        recordFeedback(ShoppingMutationFeedback(
            identity: entry.plan.identity,
            state: .recovering,
            message: "Confirming this shopping change…",
            retryIntent: .reconcileThenReplaySameID(entry.plan.identity)
        ))
        entry.continuation.resume(returning: .recovering)
    }

    private func commitPlanToBaseline(_ plan: ShoppingSurfaceMutationPlan) {
        baselineShoppingList = projectedState(from: baselineShoppingList, applying: [plan])
    }

    private func reprojectVisibleState() {
        guard let visible = projectedState(from: baselineShoppingList, applying: entries.map(\.plan)) else { return }
        recordShoppingList(visible)
    }

    private func isCurrent(_ entry: Entry) -> Bool {
        entry.scopeEpoch == scopeEpoch && entries.first?.generation == entry.generation
    }

    private func projectedState(
        from baseline: ShoppingListState?,
        applying plans: [ShoppingSurfaceMutationPlan]
    ) -> ShoppingListState? {
        plans.reduce(baseline) { partial, plan in
            optimisticShoppingList(for: plan, baseline: partial) ?? partial
        }
    }

    private func optimisticShoppingList(
        for plan: ShoppingSurfaceMutationPlan,
        baseline: ShoppingListState?
    ) -> ShoppingListState? {
        guard let action = plan.action, let baseline else {
            return plan.updatedShoppingList
        }

        switch action {
        case .addItem(let name, let quantity, let unit, let categoryKey, let iconKey, let clientMutationID):
            return try? baseline.addingOrRestoringItem(
                name: name,
                quantity: quantity,
                unit: unit,
                categoryKey: categoryKey,
                iconKey: iconKey,
                clientMutationID: clientMutationID
            ).shoppingList
        case .setItemChecked(let itemID, let checked, _):
            let plannedItem = plan.updatedShoppingList?.item(id: itemID)
            let timestamp = plannedItem?.updatedAt ?? baseline.updatedAt
            let nextSortIndex = (baseline.activeItems.map(\.sortIndex).max() ?? -1) + 1
            return try? baseline.settingChecked(
                checked,
                itemID: itemID,
                checkedAt: checked ? timestamp : nil,
                updatedAt: timestamp,
                nextSortIndex: nextSortIndex
            )
        case .deleteItem(let itemID, _, _):
            let deletedAt = plan.updatedShoppingList?.item(id: itemID)?.deletedAt ?? baseline.updatedAt
            return try? baseline.removingItem(id: itemID, deletedAt: deletedAt)
        case .addRecipeIngredients(let recipeID, let scaleFactor, let recipeIngredients, let clientMutationID):
            return try? baseline.addingRecipeIngredients(
                recipeID: recipeID,
                scaleFactor: scaleFactor,
                recipeIngredients: recipeIngredients,
                clientMutationID: clientMutationID
            )
        case .clearCompleted:
            return clearingItems(in: baseline, where: { $0.checked || $0.checkedAt != nil }, plan: plan)
        case .clearAll:
            return clearingItems(in: baseline, where: { $0.deletedAt == nil }, plan: plan)
        }
    }

    private func clearingItems(
        in baseline: ShoppingListState,
        where shouldClear: (ShoppingListItem) -> Bool,
        plan: ShoppingSurfaceMutationPlan
    ) -> ShoppingListState {
        let deletedAt = plan.updatedShoppingList?.updatedAt ?? baseline.updatedAt
        return ShoppingListState(
            id: baseline.id,
            chef: baseline.chef,
            items: baseline.items.map { shouldClear($0) ? $0.removing(deletedAt: deletedAt) : $0 },
            nextCursor: baseline.nextCursor,
            updatedAt: deletedAt
        )
    }

    private static func isIndeterminate(_ error: APITransportError) -> Bool {
        if error.isCancelled { return true }
        if case .retrySameRequest = error.retryDecision { return true }
        return false
    }
}

public enum ShoppingMutationCoordinatorError: Error, Equatable, Sendable {
    case blocked(String)
}

public enum ShoppingMutationFeedbackState: Equatable, Sendable {
    case recovering
    case failed
}

public enum ShoppingMutationRetryIntent: Equatable, Sendable {
    case resubmitWithNewID(ShoppingSurfaceMutationIdentity?)
    case reconcileThenReplaySameID(ShoppingSurfaceMutationIdentity?)
    case reconcileOnly(ShoppingSurfaceMutationIdentity?)
    case persistAlreadyAppliedBatch([String])
}

public struct ShoppingMutationFeedback: Equatable, Sendable {
    public let identity: ShoppingSurfaceMutationIdentity?
    public let state: ShoppingMutationFeedbackState
    public let message: String
    public let retryIntent: ShoppingMutationRetryIntent

    public init(
        identity: ShoppingSurfaceMutationIdentity?,
        state: ShoppingMutationFeedbackState,
        message: String,
        retryIntent: ShoppingMutationRetryIntent
    ) {
        self.identity = identity
        self.state = state
        self.message = message
        self.retryIntent = retryIntent
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

    public var duplicateItemIDs: [String] {
        shoppingList?.duplicateItemIDs ?? []
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

    public func presentation(
        mode: ShoppingListViewMode = .all,
        activeCategory: String = "all"
    ) -> ShoppingPresentationModel? {
        shoppingList.map {
            ShoppingPresentationModel(
                shoppingList: $0,
                mode: mode,
                activeCategory: activeCategory
            )
        }
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
                ? "Connect to Spoonjoy to load your current shopping list."
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
            actionTitle: "Clear checked",
            role: .success
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
                action: action,
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
                action: action,
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
                action: action,
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
                action: action,
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
                action: action,
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
                action: action,
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
        action: ShoppingSurfaceAction,
        online: APIRequestBuilder,
        offline: NativeQueuedMutation,
        updatedShoppingList: ShoppingListState?
    ) -> ShoppingSurfaceMutationPlan {
        let identity = Self.mutationIdentity(for: action)
        if !shoppingQueuedMutations.isEmpty {
            return ShoppingSurfaceMutationPlan(
                identity: identity,
                action: action,
                queuedMutation: offline,
                originalShoppingList: shoppingList,
                updatedShoppingList: updatedShoppingList
            )
        }

        switch connectivity {
        case .online:
            return ShoppingSurfaceMutationPlan(
                identity: identity,
                action: action,
                remoteRequestBuilder: online,
                offlineFallbackMutation: offline,
                originalShoppingList: shoppingList,
                updatedShoppingList: updatedShoppingList
            )
        case .offline:
            return ShoppingSurfaceMutationPlan(
                identity: identity,
                action: action,
                queuedMutation: offline,
                originalShoppingList: shoppingList,
                updatedShoppingList: updatedShoppingList
            )
        }
    }

    private static func mutationIdentity(for action: ShoppingSurfaceAction) -> ShoppingSurfaceMutationIdentity {
        switch action {
        case .addItem(_, _, _, _, _, let clientMutationID):
            ShoppingSurfaceMutationIdentity(kind: .addItem, clientMutationID: clientMutationID)
        case .setItemChecked(let itemID, _, let clientMutationID):
            ShoppingSurfaceMutationIdentity(kind: .setItemChecked, clientMutationID: clientMutationID, itemID: itemID)
        case .deleteItem(let itemID, let clientMutationID, _):
            ShoppingSurfaceMutationIdentity(kind: .deleteItem, clientMutationID: clientMutationID, itemID: itemID)
        case .addRecipeIngredients(_, _, _, let clientMutationID):
            ShoppingSurfaceMutationIdentity(kind: .addRecipeIngredients, clientMutationID: clientMutationID)
        case .clearCompleted(let clientMutationID, _):
            ShoppingSurfaceMutationIdentity(kind: .clearCompleted, clientMutationID: clientMutationID)
        case .clearAll(let clientMutationID, _):
            ShoppingSurfaceMutationIdentity(kind: .clearAll, clientMutationID: clientMutationID)
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
