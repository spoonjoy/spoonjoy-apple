import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Shopping mutation coordinator")
struct ShoppingMutationCoordinatorTests {
    @MainActor
    @Test("optimism is immediate and remote writes stay FIFO")
    func optimismIsImmediateAndRemoteWritesStayFIFO() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var remotePaths: [String] = []
        let gate = ShoppingMutationTestGate()
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { request in
                remotePaths.append(request.pathComponents.joined(separator: "/"))
                try await gate.wait()
            },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )

        let first = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_fifo_a"
        ))
        let firstTask = Task { try await coordinator.submit(first) }
        await gate.waitUntilEntered(count: 1)
        #expect(visible.item(id: "item_lemons")?.checked == true)

        let second = try viewModel(visible).plan(.addItem(
            name: "mint",
            quantity: 1,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: nil,
            clientMutationID: "cm_fifo_b"
        ))
        let secondTask = Task { try await coordinator.submit(second) }
        await Task.yield()
        #expect(visible.item(id: "item_local_cm_fifo_b")?.name == "mint")
        #expect(remotePaths == ["api/v1/shopping-list/items/item_lemons"])

        await gate.resumeNext()
        await gate.waitUntilEntered(count: 2)
        #expect(remotePaths == [
            "api/v1/shopping-list/items/item_lemons",
            "api/v1/shopping-list/items"
        ])
        await gate.resumeNext()

        #expect(try await firstTask.value == .synced)
        #expect(try await secondTask.value == .synced)
    }

    @MainActor
    @Test("solo definite rejection rolls back without a targeted read")
    func soloDefiniteRejectionRollsBackWithoutTargetedRead() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var readCount = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in throw ShoppingMutationCoordinatorTestError.rejected },
            fetchShoppingList: {
                readCount += 1
                return baseline
            },
            recordShoppingList: { visible = $0 }
        )
        let plan = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_solo_reject"
        ))

        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) {
            try await coordinator.submit(plan)
        }
        #expect(readCount == 0)
        #expect(visible == baseline)
    }

    @MainActor
    @Test("rejection with later work performs one targeted read without clobbering later optimism")
    func rejectionWithLaterWorkReadsOnceAndPreservesLaterOptimism() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var readCount = 0
        let gate = ShoppingMutationTestGate(firstResult: .failure(ShoppingMutationCoordinatorTestError.rejected))
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: {
                readCount += 1
                return baseline
            },
            recordShoppingList: { visible = $0 }
        )
        let first = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_reject_a"
        ))
        let firstTask = Task { try await coordinator.submit(first) }
        await gate.waitUntilEntered(count: 1)

        let second = try viewModel(visible).plan(.addItem(
            name: "mint",
            quantity: nil,
            unit: nil,
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_reject_b"
        ))
        let secondTask = Task { try await coordinator.submit(second) }
        await Task.yield()
        await gate.resumeNext()
        await gate.waitUntilEntered(count: 2)

        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) {
            try await firstTask.value
        }
        #expect(readCount == 1)
        #expect(visible.item(id: "item_lemons")?.checked == false)
        #expect(visible.item(id: "item_local_cm_reject_b")?.name == "mint")

        await gate.resumeNext()
        #expect(try await secondTask.value == .synced)
    }

    @MainActor
    @Test("confirmed write with failed reconciliation keeps optimistic state")
    func confirmedWriteWithFailedReconciliationKeepsOptimisticState() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in },
            fetchShoppingList: { throw ShoppingMutationCoordinatorTestError.readFailed },
            recordShoppingList: { visible = $0 }
        )
        let plan = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_confirmed_read_failed"
        ))

        #expect(try await coordinator.submit(plan) == .recovering)
        #expect(visible.item(id: "item_lemons")?.checked == true)
    }

    @MainActor
    @Test("rapid plans from the same rendered snapshot compose optimism monotonically")
    func rapidPlansFromSameSnapshotComposeMonotonically() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let gate = ShoppingMutationTestGate()
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 }
        )
        let staleViewModel = viewModel(baseline)
        let first = try staleViewModel.plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_rapid_a"
        ))
        let second = try staleViewModel.plan(.addItem(
            name: "mint",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_rapid_b"
        ))

        let firstTask = Task { try await coordinator.submit(first) }
        await gate.waitUntilEntered(count: 1)
        let secondTask = Task { try await coordinator.submit(second) }
        await Task.yield()

        #expect(visible.item(id: "item_lemons")?.checked == true)
        #expect(visible.item(id: "item_local_cm_rapid_b")?.name == "mint")

        await gate.resumeNext()
        await gate.waitUntilEntered(count: 2)
        await gate.resumeNext()
        _ = try await firstTask.value
        _ = try await secondTask.value
    }

    @MainActor
    @Test("offline transition queues later optimistic work without another remote write")
    func offlineTransitionQueuesLaterWorkWithoutRemoteWrite() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var remoteCount = 0
        var persistedIDs: [String] = []
        let offline = APITransportError(
            kind: .offline,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        let gate = ShoppingMutationTestGate(firstResult: .failure(offline))
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { mutation in persistedIDs.append(mutation.clientMutationID) },
            executeRemote: { _ in
                remoteCount += 1
                try await gate.wait()
            },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )
        let first = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_offline_a"
        ))
        let firstTask = Task { try await coordinator.submit(first) }
        await gate.waitUntilEntered(count: 1)
        let second = try viewModel(visible).plan(.addItem(
            name: "mint",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_offline_b"
        ))
        let secondTask = Task { try await coordinator.submit(second) }
        await gate.resumeNext()

        #expect(try await firstTask.value == .queuedForSync)
        #expect(try await secondTask.value == .queuedForSync)
        #expect(remoteCount == 1)
        #expect(persistedIDs == ["cm_offline_a", "cm_offline_b"])
    }

    @MainActor
    @Test("an idle coordinator never carries one account baseline into the next account")
    func idleCoordinatorDoesNotCrossAccountBoundary() async throws {
        let firstAccount = try ShoppingListState.decodeFromBundle()
        let secondAccount = ShoppingListState(
            id: "shopping_second_account",
            chef: firstAccount.chef,
            items: [],
            nextCursor: "second-cursor",
            updatedAt: "2026-08-21T21:00:00.000Z"
        )
        var visible = firstAccount
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 }
        )

        let firstPlan = try viewModel(firstAccount).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_first_account"
        ))
        _ = try await coordinator.submit(firstPlan)
        visible = secondAccount

        let secondPlan = try viewModel(secondAccount).plan(.addItem(
            name: "sage",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_second_account"
        ))
        _ = try await coordinator.submit(secondPlan)

        #expect(visible.id == secondAccount.id)
        #expect(visible.item(id: "item_lemons") == nil)
        #expect(visible.item(id: "item_local_cm_second_account")?.name == "sage")
    }

    @MainActor
    @Test("rapid clear completed reduces the latest journal state instead of a stale plan snapshot")
    func rapidClearCompletedPreservesLaterActiveOptimism() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let gate = ShoppingMutationTestGate()
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 }
        )
        let staleViewModel = viewModel(baseline)
        let add = try staleViewModel.plan(.addItem(
            name: "sage",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_before_clear"
        ))
        let clear = try staleViewModel.plan(.clearCompleted(
            clientMutationID: "cm_clear_completed",
            confirmation: .confirmed
        ))

        let addTask = Task { try await coordinator.submit(add) }
        await gate.waitUntilEntered(count: 1)
        let clearTask = Task { try await coordinator.submit(clear) }
        await Task.yield()

        #expect(visible.item(id: "item_local_cm_before_clear")?.name == "sage")
        #expect(visible.completedItems.isEmpty)

        await gate.resumeNext()
        await gate.waitUntilEntered(count: 2)
        await gate.resumeNext()
        _ = try await addTask.value
        _ = try await clearTask.value
    }

    @MainActor
    @Test("offline transition persists the failing and later work as one ordered atomic batch")
    func offlineTransitionPersistsOneAtomicBatch() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var batches: [[String]] = []
        let offline = APITransportError(
            kind: .offline,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        let gate = ShoppingMutationTestGate(firstResult: .failure(offline))
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { batch in
                batches.append(batch.map(\.clientMutationID))
            },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: { baseline },
            recordShoppingList: { _ in }
        )
        let first = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_atomic_a"
        ))
        let second = try viewModel(baseline).plan(.addItem(
            name: "sage",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_atomic_b"
        ))

        let firstTask = Task { try await coordinator.submit(first) }
        await gate.waitUntilEntered(count: 1)
        let secondTask = Task { try await coordinator.submit(second) }
        await gate.resumeNext()

        #expect(try await firstTask.value == .queuedForSync)
        #expect(try await secondTask.value == .queuedForSync)
        #expect(batches == [["cm_atomic_a", "cm_atomic_b"]])
    }

    @MainActor
    private func viewModel(_ shoppingList: ShoppingListState) -> ShoppingSurfaceViewModel {
        ShoppingSurfaceViewModel(
            shoppingList: shoppingList,
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            now: { "2026-08-21T20:00:00.000Z" }
        )
    }
}

private enum ShoppingMutationCoordinatorTestError: Error {
    case rejected
    case readFailed
}

private actor ShoppingMutationTestGate {
    private var entered = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var operationContinuations: [CheckedContinuation<Void, Error>] = []
    private var results: [Result<Void, Error>]

    init(firstResult: Result<Void, Error> = .success(())) {
        results = [firstResult]
    }

    func wait() async throws {
        entered += 1
        let currentWaiters = waiters
        waiters.removeAll()
        currentWaiters.forEach { $0.resume() }
        try await withCheckedThrowingContinuation { continuation in
            operationContinuations.append(continuation)
        }
    }

    func waitUntilEntered(count: Int) async {
        while entered < count {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func resumeNext() {
        guard !operationContinuations.isEmpty else { return }
        let continuation = operationContinuations.removeFirst()
        let result = results.isEmpty ? .success(()) : results.removeFirst()
        continuation.resume(with: result)
    }
}
