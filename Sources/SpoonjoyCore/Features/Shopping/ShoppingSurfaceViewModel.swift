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
        var plan: ShoppingSurfaceMutationPlan
        let generation: UInt64
        let scopeEpoch: UInt64
        let continuation: CheckedContinuation<ShoppingSurfaceMutationOutcome, Error>
    }

    private struct PendingRecovery {
        let plan: ShoppingSurfaceMutationPlan
        var requiresReplay: Bool
        var feedback: ShoppingMutationFeedback
    }

    private struct ProductEvidence: Equatable {
        let quantity: Double?
        let categoryKey: String
        let iconKey: String
        let isChecked: Bool

        var sortKey: String {
            let quantityKey = quantity.map { String($0) } ?? "nil"
            return "\(quantityKey)|\(categoryKey)|\(iconKey)|\(isChecked)"
        }
    }

    private struct ProductKey: Hashable {
        let name: String
        let unit: String
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
    private var pendingPersistenceIdentity: ShoppingSurfaceMutationIdentity?
    private var pendingRecoveries: [PendingRecovery] = []
    private var retainedFeedback: ShoppingMutationFeedback?
    private var recoveryWaiters: [CheckedContinuation<Void, Never>] = []

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
            if entries.isEmpty, pendingRecoveries.isEmpty {
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
        pendingPersistenceIdentity = nil
        pendingRecoveries = []
        signalRecoveryChange()
        retainedFeedback = nil
        isDraining = false
        recordFeedback(nil)
        cancelledEntries.forEach { $0.continuation.resume(throwing: CancellationError()) }
    }

    private func drain(scopeEpoch drainEpoch: UInt64) async {
        while drainEpoch == scopeEpoch, !entries.isEmpty, !Task.isCancelled {
            if dependsOnPendingRecovery(entries[0].plan) {
                await withCheckedContinuation { recoveryWaiters.append($0) }
                continue
            }
            await performFirstEntry()
        }
        guard drainEpoch == scopeEpoch else { return }
        if entries.isEmpty, pendingRecoveries.isEmpty {
            baselineShoppingList = nil
        }
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
            clearRetainedFailureResolved(by: plan)
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
            let reconciled = try await fetchShoppingList()
            baselineShoppingList = reconciled
            settleReflectedRecoveries(in: reconciled)
            reprojectVisibleState()
            clearRetainedFailureResolved(by: plan)
            entry.continuation.resume(returning: .synced)
        } catch {
            enqueueRecovery(plan, requiresReplay: false, feedback: ShoppingMutationFeedback(
                identity: plan.identity,
                state: .recovering,
                message: "Saved. Refresh the shopping list to confirm the latest server state.",
                retryIntent: .reconcileOnly(plan.identity)
            ))
            reprojectVisibleState()
            entry.continuation.resume(returning: .recovering)
        }
    }

    public func retryPendingPersistence() async throws -> ShoppingSurfaceMutationOutcome {
        guard !pendingPersistenceBatch.isEmpty else { return .synced }
        let batch = pendingPersistenceBatch
        try await persistAlreadyAppliedBatch(batch)
        pendingPersistenceBatch = []
        clearRetainedFeedback(matching: pendingPersistenceIdentity)
        pendingPersistenceIdentity = nil
        return .queuedForSync
    }

    public func retryCurrentRecovery() async throws -> ShoppingSurfaceMutationOutcome {
        if !pendingPersistenceBatch.isEmpty {
            return try await retryPendingPersistence()
        }
        guard let pendingRecovery = pendingRecoveries.first else { return .synced }
        let plan = pendingRecovery.plan
        if let preflight = try? await fetchShoppingList() {
            baselineShoppingList = preflight
            settleReflectedRecoveries(in: preflight)
            if !pendingRecoveries.contains(where: { $0.plan.identity == plan.identity }) {
                reprojectVisibleState()
                return .synced
            }
            if mutationIsReflected(plan, in: preflight) {
                return settleRecovery(plan, with: preflight) ? .synced : .recovering
            }
        }
        if pendingRecovery.requiresReplay, let request = plan.remoteRequestBuilder {
            try await executeRemote(request)
            pendingRecoveries[0].requiresReplay = false
            pendingRecoveries[0].feedback = ShoppingMutationFeedback(
                identity: plan.identity,
                state: .recovering,
                message: "Confirming this shopping change…",
                retryIntent: .reconcileOnly(plan.identity)
            )
        }
        let reconciled = try await fetchShoppingList()
        guard mutationIsReflected(plan, in: reconciled) else {
            baselineShoppingList = reconciled
            reprojectVisibleState()
            publishCurrentFeedback()
            return .recovering
        }
        return settleRecovery(plan, with: reconciled) ? .synced : .recovering
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
            persistedEntries.forEach { $0.continuation.resume(returning: .queuedForSync) }
        } catch {
            pendingPersistenceBatch = batch
            pendingPersistenceIdentity = persistedEntries.first?.plan.identity
            entries.removeFirst(entryCount)
            baselineShoppingList = projectedState(from: baselineShoppingList, applying: persistedEntries.map(\.plan))
            reprojectVisibleState()
            retain(ShoppingMutationFeedback(
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
        let hadLaterEntries = !entries.isEmpty
        if hadLaterEntries, let reconciled = try? await fetchShoppingList() {
            baselineShoppingList = reconciled
        }
        let rejectedLocalItemIDs = locallyCreatedItemIDs(for: entry.plan)
        let dependentEntries = entries.filter { dependsOnRejectedItem($0.plan, rejectedLocalItemIDs: rejectedLocalItemIDs) }
        entries.removeAll { candidate in
            dependentEntries.contains { $0.generation == candidate.generation }
        }
        reprojectVisibleState()
        retain(ShoppingMutationFeedback(
            identity: entry.plan.identity,
            state: .failed,
            message: "Couldn't update this shopping item. Try again.",
            retryIntent: .resubmitWithNewID(entry.plan.identity)
        ))
        entry.continuation.resume(throwing: error)
        dependentEntries.forEach {
            $0.continuation.resume(throwing: ShoppingMutationCoordinatorError.dependencyRejected($0.plan.identity))
        }
    }

    private func recoverIndeterminate(_ entry: Entry, error: Error) async {
        entries.removeFirst()
        if let reconciled = try? await fetchShoppingList() {
            baselineShoppingList = reconciled
            if mutationIsReflected(entry.plan, in: reconciled) {
                guard rebindDependentEntries(createdBy: entry.plan, in: reconciled) else {
                    enqueueRecovery(entry.plan, requiresReplay: false, feedback: ShoppingMutationFeedback(
                        identity: entry.plan.identity,
                        state: .recovering,
                        message: "Confirming this shopping change…",
                        retryIntent: .reconcileOnly(entry.plan.identity)
                    ))
                    reprojectVisibleState()
                    entry.continuation.resume(returning: .recovering)
                    return
                }
                reprojectVisibleState()
                entry.continuation.resume(returning: .synced)
                return
            }
        }
        enqueueRecovery(entry.plan, requiresReplay: true, feedback: ShoppingMutationFeedback(
            identity: entry.plan.identity,
            state: .recovering,
            message: "Confirming this shopping change…",
            retryIntent: .reconcileThenReplaySameID(entry.plan.identity)
        ))
        reprojectVisibleState()
        entry.continuation.resume(returning: .recovering)
    }

    private func settleRecovery(_ plan: ShoppingSurfaceMutationPlan, with reconciled: ShoppingListState) -> Bool {
        baselineShoppingList = reconciled
        guard rebindDependentEntries(createdBy: plan, in: reconciled) else {
            reprojectVisibleState()
            publishCurrentFeedback()
            return false
        }
        pendingRecoveries.removeAll { $0.plan.identity == plan.identity }
        signalRecoveryChange()
        reprojectVisibleState()
        clearRetainedFeedback(matching: plan.identity)
        publishCurrentFeedback()
        return true
    }

    private func settleReflectedRecoveries(in reconciled: ShoppingListState) {
        var didSettle = false
        if let endIndex = pendingRecoveries.indices.reversed().first(where: { index in
            let prefix = pendingRecoveries[...index]
            let keys = prefix.reduce(into: Set<ProductKey>()) { result, recovery in
                result.formUnion(affectedProductKeys(for: recovery.plan))
            }
            guard !keys.isEmpty,
                  let expected = pendingRecoveries[index].plan.updatedShoppingList
            else { return false }
            return cumulativeNonAdditiveEvidenceMatches(prefix.map(\.plan), expected: expected, in: reconciled) &&
                productEvidenceMatches(expected, in: reconciled, keys: keys)
        }) {
            let prefix = Array(pendingRecoveries[...endIndex])
            if rebindDependentEntries(createdBy: prefix.map(\.plan), cumulativelyIn: reconciled) {
                pendingRecoveries.removeFirst(endIndex + 1)
                prefix.forEach { clearRetainedFeedback(matching: $0.plan.identity) }
                didSettle = true
            }
        }
        while let recovery = pendingRecoveries.first,
              mutationIsReflected(recovery.plan, in: reconciled),
              rebindDependentEntries(createdBy: recovery.plan, in: reconciled) {
            pendingRecoveries.removeFirst()
            clearRetainedFeedback(matching: recovery.plan.identity)
            didSettle = true
        }
        if didSettle {
            signalRecoveryChange()
            publishCurrentFeedback()
        }
    }

    private func retain(_ feedback: ShoppingMutationFeedback) {
        if feedback.state == .failed, retainedFeedback?.state != .failed {
            retainedFeedback = feedback
        }
        publishCurrentFeedback()
    }

    private func enqueueRecovery(
        _ plan: ShoppingSurfaceMutationPlan,
        requiresReplay: Bool,
        feedback: ShoppingMutationFeedback
    ) {
        guard !pendingRecoveries.contains(where: { $0.plan.identity == plan.identity }) else { return }
        pendingRecoveries.append(PendingRecovery(plan: plan, requiresReplay: requiresReplay, feedback: feedback))
        publishCurrentFeedback()
    }

    private func publishCurrentFeedback() {
        recordFeedback(retainedFeedback ?? pendingRecoveries.first?.feedback)
    }

    private func clearRetainedFeedback(matching identity: ShoppingSurfaceMutationIdentity?) {
        guard retainedFeedback?.identity == identity else { return }
        retainedFeedback = nil
        publishCurrentFeedback()
    }

    private func clearRetainedFailureResolved(by plan: ShoppingSurfaceMutationPlan) {
        guard
            retainedFeedback?.state == .failed,
            let failedIdentity = retainedFeedback?.identity,
            let successfulIdentity = plan.identity,
            failedIdentity.kind == successfulIdentity.kind,
            failedIdentity.itemID == successfulIdentity.itemID
        else { return }
        retainedFeedback = nil
        publishCurrentFeedback()
    }

    private func locallyCreatedItemIDs(for plan: ShoppingSurfaceMutationPlan) -> Set<String> {
        guard let action = plan.action else { return [] }
        switch action {
        case .addItem(_, _, _, _, _, let clientMutationID):
            return ["item_local_\(clientMutationID)"]
        case .addRecipeIngredients(_, _, let ingredients, let clientMutationID):
            return Set(ingredients.indices.map { "item_local_\(clientMutationID)-ingredient-\($0 + 1)" })
        case .setItemChecked, .deleteItem, .clearCompleted, .clearAll:
            return []
        }
    }

    private func dependsOnRejectedItem(
        _ plan: ShoppingSurfaceMutationPlan,
        rejectedLocalItemIDs: Set<String>
    ) -> Bool {
        guard let action = plan.action else { return false }
        switch action {
        case .setItemChecked(let itemID, _, _), .deleteItem(let itemID, _, _):
            return rejectedLocalItemIDs.contains(itemID)
        case .addItem, .addRecipeIngredients, .clearCompleted, .clearAll:
            return false
        }
    }

    private func dependsOnPendingRecovery(_ plan: ShoppingSurfaceMutationPlan) -> Bool {
        pendingRecoveries.contains { recovery in
            dependsOnRejectedItem(plan, rejectedLocalItemIDs: locallyCreatedItemIDs(for: recovery.plan))
        }
    }

    private func rebindDependentEntries(createdBy creator: ShoppingSurfaceMutationPlan, in reconciled: ShoppingListState) -> Bool {
        rebindDependentEntries(createdBy: [creator], cumulativelyIn: reconciled)
    }

    private func rebindDependentEntries(
        createdBy creators: [ShoppingSurfaceMutationPlan],
        cumulativelyIn reconciled: ShoppingListState
    ) -> Bool {
        let localIDs = creators.reduce(into: Set<String>()) { result, creator in
            result.formUnion(locallyCreatedItemIDs(for: creator))
        }
        let targetedIDs = Set(entries.compactMap { entry -> String? in
            switch entry.plan.action {
            case .setItemChecked(let itemID, _, _), .deleteItem(let itemID, _, _):
                return localIDs.contains(itemID) ? itemID : nil
            case .addItem, .addRecipeIngredients, .clearCompleted, .clearAll, .none:
                return nil
            }
        })
        var mappings: [String: String] = [:]
        for creator in creators {
            guard let expected = creator.updatedShoppingList else { continue }
            for localID in locallyCreatedItemIDs(for: creator) where targetedIDs.contains(localID) {
                guard let expectedItem = expected.item(id: localID) else { continue }
                let key = productKey(name: expectedItem.name, unit: expectedItem.unit)
                let candidates = reconciled.receiptItems.filter { productKey(for: $0) == key }
                if candidates.count == 1, let resolvedID = candidates.first?.id {
                    mappings[localID] = resolvedID
                }
            }
        }
        guard targetedIDs.isSubset(of: Set(mappings.keys)) else { return false }
        for index in entries.indices {
            entries[index].plan = rebound(entries[index].plan, using: mappings, in: reconciled)
        }
        return true
    }

    private func rebound(
        _ plan: ShoppingSurfaceMutationPlan,
        using mappings: [String: String],
        in reconciled: ShoppingListState
    ) -> ShoppingSurfaceMutationPlan {
        switch plan.action {
        case .setItemChecked(let itemID, let checked, let clientMutationID):
            guard let resolvedID = mappings[itemID] else { return plan }
            let plannedAt = reconciled.updatedAt
            let updated = try? reconciled.settingChecked(
                checked,
                itemID: resolvedID,
                checkedAt: plannedAt,
                updatedAt: plannedAt,
                nextSortIndex: reconciled.items.count
            )
            let offline = NativeQueuedMutation.shoppingCheckItem(
                itemID: resolvedID,
                checked: checked,
                clientMutationID: clientMutationID,
                createdAt: plannedAt
            )
            let remote = try? ShoppingListRequests.setItemChecked(id: resolvedID, checked: checked, clientMutationID: clientMutationID)
            return ShoppingSurfaceMutationPlan(
                identity: ShoppingSurfaceMutationIdentity(kind: .setItemChecked, clientMutationID: clientMutationID, itemID: resolvedID),
                action: .setItemChecked(itemID: resolvedID, checked: checked, clientMutationID: clientMutationID),
                remoteRequestBuilder: plan.remoteRequestBuilder == nil ? nil : remote,
                queuedMutation: plan.queuedMutation == nil ? nil : offline,
                offlineFallbackMutation: plan.offlineFallbackMutation == nil ? nil : offline,
                originalShoppingList: reconciled,
                updatedShoppingList: updated
            )
        case .deleteItem(let itemID, let clientMutationID, let confirmation):
            guard let resolvedID = mappings[itemID] else { return plan }
            let plannedAt = reconciled.updatedAt
            let offline = NativeQueuedMutation.shoppingDeleteItem(itemID: resolvedID, clientMutationID: clientMutationID, createdAt: plannedAt)
            let remote = try? ShoppingListRequests.deleteItem(id: resolvedID, clientMutationID: clientMutationID, idempotency: .header)
            return ShoppingSurfaceMutationPlan(
                identity: ShoppingSurfaceMutationIdentity(kind: .deleteItem, clientMutationID: clientMutationID, itemID: resolvedID),
                action: .deleteItem(itemID: resolvedID, clientMutationID: clientMutationID, confirmation: confirmation),
                remoteRequestBuilder: plan.remoteRequestBuilder == nil ? nil : remote,
                queuedMutation: plan.queuedMutation == nil ? nil : offline,
                offlineFallbackMutation: plan.offlineFallbackMutation == nil ? nil : offline,
                originalShoppingList: reconciled,
                updatedShoppingList: try? reconciled.removingItem(id: resolvedID, deletedAt: plannedAt)
            )
        case .addItem, .addRecipeIngredients, .clearCompleted, .clearAll, .none:
            return plan
        }
    }

    private func mutationIsReflected(_ plan: ShoppingSurfaceMutationPlan, in shoppingList: ShoppingListState) -> Bool {
        guard let action = plan.action else {
            return plan.updatedShoppingList == shoppingList
        }
        switch action {
        case .addItem(let name, _, let unit, _, _, _):
            return productEvidenceMatches(plan, in: shoppingList, keys: [(normalized(name), normalized(unit))])
        case .setItemChecked(let itemID, let checked, _):
            return shoppingList.item(id: itemID)?.isEffectivelyChecked == checked
        case .deleteItem(let itemID, _, _):
            return shoppingList.item(id: itemID)?.deletedAt != nil || shoppingList.item(id: itemID) == nil
        case .addRecipeIngredients(_, _, let ingredients, _):
            let keys = ingredients.map { (normalized($0.name), normalized($0.unit)) }
            return productEvidenceMatches(plan, in: shoppingList, keys: keys)
        case .clearCompleted:
            let completedIDs = plan.originalShoppingList?.completedItems.map(\.id) ?? []
            return completedIDs.allSatisfy { shoppingList.item(id: $0)?.deletedAt != nil || shoppingList.item(id: $0) == nil }
        case .clearAll:
            let receiptIDs = plan.originalShoppingList?.receiptItems.map(\.id) ?? []
            return receiptIDs.allSatisfy { shoppingList.item(id: $0)?.deletedAt != nil || shoppingList.item(id: $0) == nil }
        }
    }

    private func cumulativeNonAdditiveEvidenceMatches(
        _ plans: [ShoppingSurfaceMutationPlan],
        expected: ShoppingListState,
        in reconciled: ShoppingListState
    ) -> Bool {
        var itemIDs = Set<String>()
        for plan in plans {
            switch plan.action {
            case .setItemChecked(let itemID, _, _), .deleteItem(let itemID, _, _):
                itemIDs.insert(itemID)
            case .clearCompleted, .clearAll:
                itemIDs.formUnion(expected.items.filter { $0.deletedAt != nil }.map(\.id))
            case .addItem, .addRecipeIngredients:
                break
            case .none:
                return false
            }
        }
        return itemIDs.allSatisfy { itemID in
            let expectedItem = expected.item(id: itemID)
            let reconciledItem = reconciled.item(id: itemID)
            let expectedIsActive = expectedItem?.deletedAt == nil && expectedItem != nil
            let reconciledIsActive = reconciledItem?.deletedAt == nil && reconciledItem != nil
            guard expectedIsActive == reconciledIsActive else { return false }
            guard expectedIsActive else { return true }
            return expectedItem?.isEffectivelyChecked == reconciledItem?.isEffectivelyChecked
        }
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private func productKey(name: String?, unit: String?) -> ProductKey {
        ProductKey(name: normalized(name), unit: normalized(unit))
    }

    private func productKey(for item: ShoppingListItem) -> ProductKey {
        productKey(name: item.name, unit: item.unit)
    }

    private func affectedProductKeys(for plan: ShoppingSurfaceMutationPlan) -> Set<ProductKey> {
        switch plan.action {
        case .addItem(let name, _, let unit, _, _, _):
            return [productKey(name: name, unit: unit)]
        case .addRecipeIngredients(_, _, let ingredients, _):
            return Set(ingredients.map { productKey(name: $0.name, unit: $0.unit) })
        case .setItemChecked, .deleteItem, .clearCompleted, .clearAll, .none:
            return []
        }
    }

    private func projectingProductTargets(
        from plan: ShoppingSurfaceMutationPlan,
        keys: Set<ProductKey>,
        onto baseline: ShoppingListState
    ) -> ShoppingListState? {
        guard !keys.isEmpty, let expected = plan.updatedShoppingList else { return nil }
        let matchingItems = baseline.items.filter { keys.contains(productKey(for: $0)) }
        let currentMatches = matchingItems.filter { $0.deletedAt == nil } + matchingItems.filter { $0.deletedAt != nil }
        let expectedMatches = expected.receiptItems.filter { keys.contains(productKey(for: $0)) }
        var currentByKey = Dictionary(grouping: currentMatches, by: productKey(for:))
        var replacedIDs = Set<String>()
        let projectedMatches = expectedMatches.map { item in
            let key = productKey(for: item)
            guard var matches = currentByKey[key], !matches.isEmpty else { return item }
            let current = matches.removeFirst()
            currentByKey[key] = matches
            replacedIDs.insert(current.id)
            return ShoppingListItem(
                id: current.id,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                checked: item.checked,
                checkedAt: item.checkedAt,
                deletedAt: item.deletedAt,
                categoryKey: item.categoryKey,
                iconKey: item.iconKey,
                sortIndex: item.sortIndex,
                updatedAt: item.updatedAt
            )
        }
        var items = baseline.items.filter { item in
            !replacedIDs.contains(item.id) && (item.deletedAt != nil || !keys.contains(productKey(for: item)))
        }
        items += projectedMatches
        return ShoppingListState(id: baseline.id, chef: baseline.chef, items: items, nextCursor: baseline.nextCursor, updatedAt: baseline.updatedAt)
    }

    private func productEvidenceMatches(
        _ plan: ShoppingSurfaceMutationPlan,
        in shoppingList: ShoppingListState,
        keys: [(String, String)]
    ) -> Bool {
        guard let expectedShoppingList = plan.updatedShoppingList else { return false }
        return productEvidenceMatches(
            expectedShoppingList,
            in: shoppingList,
            keys: Set(keys.map { ProductKey(name: $0.0, unit: $0.1) })
        )
    }

    private func productEvidenceMatches(
        _ expected: ShoppingListState,
        in shoppingList: ShoppingListState,
        keys: Set<ProductKey>
    ) -> Bool {
        keys.allSatisfy { key in
            productEvidence(in: expected, name: key.name, unit: key.unit) ==
                productEvidence(in: shoppingList, name: key.name, unit: key.unit)
        }
    }

    private func productEvidence(
        in shoppingList: ShoppingListState,
        name: String,
        unit: String
    ) -> [ProductEvidence] {
        shoppingList.receiptItems
            .filter { normalized($0.name) == name && normalized($0.unit) == unit }
            .map {
                ProductEvidence(
                    quantity: $0.quantity,
                    categoryKey: normalized($0.categoryKey),
                    iconKey: normalized($0.iconKey),
                    isChecked: $0.isEffectivelyChecked
                )
            }
            .sorted { $0.sortKey < $1.sortKey }
    }

    private func commitPlanToBaseline(_ plan: ShoppingSurfaceMutationPlan) {
        baselineShoppingList = projectedState(from: baselineShoppingList, applying: [plan])
    }

    private func reprojectVisibleState() {
        var visible = baselineShoppingList
        let fetchedBaseline = baselineShoppingList
        for (index, recovery) in pendingRecoveries.enumerated() {
            let keys = affectedProductKeys(for: recovery.plan)
            if !keys.isEmpty, let expected = recovery.plan.updatedShoppingList {
                let laterKeys = pendingRecoveries.dropFirst(index + 1).reduce(into: Set<ProductKey>()) { result, later in
                    result.formUnion(affectedProductKeys(for: later.plan))
                }
                var projectionKeys = keys.subtracting(laterKeys)
                if let fetchedBaseline {
                    projectionKeys = projectionKeys.filter { key in
                        !productEvidenceMatches(expected, in: fetchedBaseline, keys: [key])
                    }
                }
                if let current = visible,
                   let targeted = projectingProductTargets(from: recovery.plan, keys: projectionKeys, onto: current) {
                    visible = targeted
                }
                continue
            }
            visible = optimisticShoppingList(for: recovery.plan, baseline: visible) ?? visible
        }
        visible = projectedState(from: visible, applying: entries.map(\.plan))
        guard let visible else { return }
        recordShoppingList(visible)
    }

    private func signalRecoveryChange() {
        let waiters = recoveryWaiters
        recoveryWaiters.removeAll()
        waiters.forEach { $0.resume() }
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
    case dependencyRejected(ShoppingSurfaceMutationIdentity?)
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
