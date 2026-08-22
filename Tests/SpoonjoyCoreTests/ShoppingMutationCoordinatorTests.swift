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
        var remoteIDs: [String] = []
        let gate = ShoppingMutationTestGate()
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { request in
                remoteIDs.append(request.headers["Idempotency-Key"] ?? "missing")
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
        #expect(remoteIDs == ["cm_fifo_a"])

        await gate.resumeNext()
        await gate.waitUntilEntered(count: 2)
        #expect(remoteIDs == ["cm_fifo_a", "cm_fifo_b"])
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
        #expect(visible.item(id: "item_local_cm_reject_b")?.name == "mint")

        await gate.resumeNext()
        #expect(try await secondTask.value == .synced)
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
