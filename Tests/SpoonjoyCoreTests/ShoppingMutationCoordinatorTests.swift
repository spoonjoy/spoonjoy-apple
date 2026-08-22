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
        var feedback: ShoppingMutationFeedback?
        let gate = ShoppingMutationTestGate(firstResult: .failure(ShoppingMutationCoordinatorTestError.rejected))
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: {
                readCount += 1
                return baseline
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
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
        #expect(feedback?.identity == first.identity)
        #expect(feedback?.state == .failed)
    }

    @MainActor
    @Test("rejection blocks later work that targets its optimistic local item")
    func rejectionBlocksDependentLocalItemWorkBeforeRemote() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var readCount = 0
        var remotePaths: [String] = []
        let gate = ShoppingMutationTestGate(firstResult: .failure(ShoppingMutationCoordinatorTestError.rejected))
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { request in
                remotePaths.append(request.pathComponents.joined(separator: "/"))
                try await gate.wait()
            },
            fetchShoppingList: {
                readCount += 1
                return baseline
            },
            recordShoppingList: { visible = $0 }
        )
        let add = try viewModel(baseline).plan(.addItem(
            name: "mint",
            quantity: 1,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_dependency_a"
        ))
        let addTask = Task { try await coordinator.submit(add) }
        await gate.waitUntilEntered(count: 1)
        let check = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_local_cm_dependency_a",
            checked: true,
            clientMutationID: "cm_dependency_b"
        ))
        let checkTask = Task { try await coordinator.submit(check) }
        await gate.resumeNext()

        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) {
            try await addTask.value
        }
        await #expect(throws: ShoppingMutationCoordinatorError.dependencyRejected(check.identity)) {
            try await checkTask.value
        }
        #expect(readCount == 1)
        #expect(remotePaths == ["api/v1/shopping-list/items"])
        #expect(visible.item(id: "item_local_cm_dependency_a") == nil)
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
    @Test("a successful retry clears only the matching retained failure")
    func successfulRetryClearsMatchingRetainedFailure() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var attempts = 0
        var feedback: ShoppingMutationFeedback?
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                attempts += 1
                if attempts == 1 { throw ShoppingMutationCoordinatorTestError.rejected }
            },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )
        let failed = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_retry_target_failed"
        ))
        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) {
            try await coordinator.submit(failed)
        }
        #expect(feedback?.state == .failed)

        let retry = try viewModel(visible).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_retry_target_succeeded"
        ))
        #expect(try await coordinator.submit(retry) == .synced)
        #expect(feedback == nil)
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
    @Test("cancelled transport stays optimistic and exposes hidden same-ID recovery")
    func cancellationStaysOptimisticForSameIDRecovery() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(
            kind: .cancelled,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .doNotRetry
        )
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in throw cancelled },
            fetchShoppingList: { throw ShoppingMutationCoordinatorTestError.readFailed },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )
        let plan = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_cancelled"
        ))

        #expect(try await coordinator.submit(plan) == .recovering)
        #expect(visible.item(id: "item_lemons")?.isEffectivelyChecked == true)
        #expect(feedback?.state == .recovering)
        #expect(feedback?.retryIntent == .reconcileThenReplaySameID(plan.identity))
    }

    @MainActor
    @Test("failed atomic persistence retries only the identical batch")
    func persistenceFailureRetriesOnlyIdenticalBatch() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var attempts: [[String]] = []
        var shouldFail = true
        var remoteCount = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { batch in
                attempts.append(batch.map(\.clientMutationID))
                if shouldFail {
                    shouldFail = false
                    throw ShoppingMutationCoordinatorTestError.persistenceFailed
                }
            },
            executeRemote: { _ in remoteCount += 1 },
            fetchShoppingList: { baseline },
            recordShoppingList: { _ in }
        )
        let offlinePlan = try ShoppingSurfaceViewModel(
            shoppingList: baseline,
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            now: { "2026-08-21T20:00:00.000Z" }
        ).plan(.addItem(
            name: "sage",
            quantity: nil,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_persist_retry"
        ))

        await #expect(throws: ShoppingMutationCoordinatorTestError.persistenceFailed) {
            try await coordinator.submit(offlinePlan)
        }
        #expect(try await coordinator.retryCurrentRecovery() == .queuedForSync)
        #expect(try await coordinator.retryPendingPersistence() == .synced)
        #expect(attempts == [["cm_persist_retry"], ["cm_persist_retry"]])
        #expect(remoteCount == 0)
    }

    @MainActor
    @Test("scope reset cancels in-flight work before another environment can emit")
    func scopeResetCancelsInFlightJournal() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let gate = ShoppingMutationTestGate()
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in try await gate.wait() },
            fetchShoppingList: { baseline },
            recordShoppingList: { _ in }
        )
        let plan = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_scope_reset"
        ))
        let task = Task { try await coordinator.submit(plan) }
        await gate.waitUntilEntered(count: 1)

        coordinator.resetScope()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        await gate.resumeNext()
    }

    @MainActor
    @Test("blocked and local-only plans fail or settle without transport")
    func blockedAndLocalOnlyPlans() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in Issue.record("Local-only plan must not execute transport") },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )

        await #expect(throws: ShoppingMutationCoordinatorError.blocked("Not allowed")) {
            try await coordinator.submit(ShoppingSurfaceMutationPlan(blockedReason: "Not allowed"))
        }
        #expect(try await coordinator.retryCurrentRecovery() == .synced)

        let updated = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: "2026-08-21T20:00:00.000Z",
            updatedAt: "2026-08-21T20:00:00.000Z",
            nextSortIndex: 10
        )
        let outcome = try await coordinator.submit(ShoppingSurfaceMutationPlan(
            originalShoppingList: baseline,
            updatedShoppingList: updated
        ))
        #expect(outcome == .synced)
        #expect(visible.item(id: "item_lemons")?.isEffectivelyChecked == true)
        #expect(viewModel(ShoppingListState(id: baseline.id, chef: baseline.chef, items: [], nextCursor: baseline.nextCursor, updatedAt: baseline.updatedAt)).presentation() != nil)
        #expect(ShoppingSurfaceViewModel(shoppingList: nil, queuedMutations: [], conflicts: [], connectivity: .online, now: { "now" }).presentation() == nil)
        #expect(try await coordinator.submit(ShoppingSurfaceMutationPlan()) == .synced)
    }

    @MainActor
    @Test("recovery retry reconciles confirmed and indeterminate writes")
    func recoveryRetryReconcilesAndReplays() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var reads = 0
        var writes = 0
        var feedback: ShoppingMutationFeedback?
        let confirmedApplied = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: "2026-08-21T20:00:00.000Z",
            updatedAt: "2026-08-21T20:00:00.000Z",
            nextSortIndex: 10
        )
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in writes += 1 },
            fetchShoppingList: {
                reads += 1
                if reads == 1 { throw ShoppingMutationCoordinatorTestError.readFailed }
                return confirmedApplied
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )
        let confirmed = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_reconcile_retry"
        ))
        #expect(try await coordinator.submit(confirmed) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(reads == 2)
        #expect(writes == 1)
        #expect(visible == confirmedApplied)
        #expect(feedback == nil)

        let retrySameRequest = APITransportError(
            kind: .networkFailure,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .retrySameRequest(afterSeconds: nil)
        )
        var replayReads = 0
        var replayWrites = 0
        let replayCoordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in
                replayWrites += 1
                if replayWrites == 1 { throw retrySameRequest }
            },
            fetchShoppingList: {
                replayReads += 1
                if replayReads <= 2 { throw ShoppingMutationCoordinatorTestError.readFailed }
                return confirmedApplied
            },
            recordShoppingList: { visible = $0 }
        )
        let replay = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_replay_retry"
        ))
        #expect(try await replayCoordinator.submit(replay) == .recovering)
        #expect(try await replayCoordinator.retryCurrentRecovery() == .synced)
        #expect(replayWrites == 2)
        #expect(replayReads == 3)
    }

    @MainActor
    @Test("indeterminate reads verify the mutation before reporting sync")
    func indeterminateSuccessAndIncompleteOfflineFallback() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        var writes = 0
        var reads = 0
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let plan = try viewModel(baseline).plan(.setItemChecked(itemID: "item_lemons", checked: true, clientMutationID: "cm_cancel_reconciled"))
        let applied = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: "2026-08-21T20:00:00.000Z",
            updatedAt: "2026-08-21T20:00:00.000Z",
            nextSortIndex: 10
        )
        let recovered = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes == 1 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads < 3 ? baseline : applied
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )
        #expect(try await recovered.submit(plan) == .recovering)
        #expect(visible.item(id: "item_lemons")?.isEffectivelyChecked == true)
        #expect(feedback?.retryIntent == .reconcileThenReplaySameID(plan.identity))
        #expect(try await recovered.retryCurrentRecovery() == .synced)
        #expect(writes == 2)
        #expect(reads == 3)
        #expect(visible == applied)
        #expect(feedback == nil)

        let definiteTransportError = APITransportError(
            kind: .networkFailure,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .doNotRetry
        )
        let definite = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in throw definiteTransportError },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )
        await #expect(throws: APITransportError.self) {
            try await definite.submit(plan)
        }

        let offline = APITransportError(kind: .offline, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let incomplete = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in throw offline },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )
        let noFallback = ShoppingSurfaceMutationPlan(
            identity: plan.identity,
            action: plan.action,
            remoteRequestBuilder: plan.remoteRequestBuilder,
            originalShoppingList: baseline,
            updatedShoppingList: plan.updatedShoppingList
        )
        await #expect(throws: APITransportError.self) {
            try await incomplete.submit(noFallback)
        }
        #expect(visible == baseline)
    }

    @MainActor
    @Test("local projection covers delete recipe and clear-all action shapes")
    func localProjectionCoversStructuralActions() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in Issue.record("Local projection must not execute transport") },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 }
        )
        func local(_ plan: ShoppingSurfaceMutationPlan) -> ShoppingSurfaceMutationPlan {
            ShoppingSurfaceMutationPlan(
                identity: plan.identity,
                action: plan.action,
                originalShoppingList: plan.originalShoppingList,
                updatedShoppingList: plan.updatedShoppingList
            )
        }

        let delete = try viewModel(visible).plan(.deleteItem(itemID: "item_lemons", clientMutationID: "cm_local_delete", confirmation: .confirmed))
        #expect(try await coordinator.submit(local(delete)) == .synced)
        #expect(visible.item(id: "item_lemons")?.deletedAt != nil)

        let ingredients = [RecipeIngredient(id: "ingredient_mint", name: "mint", quantity: 1, unit: "bunch")]
        let recipe = try viewModel(visible).plan(.addRecipeIngredients(recipeID: "recipe_mint", scaleFactor: 1, recipeIngredients: ingredients, clientMutationID: "cm_local_recipe"))
        #expect(try await coordinator.submit(local(recipe)) == .synced)
        #expect(visible.activeItems.contains { $0.name == "mint" })

        let clear = try viewModel(visible).plan(.clearAll(clientMutationID: "cm_local_clear", confirmation: .confirmed))
        #expect(try await coordinator.submit(local(clear)) == .synced)
        #expect(visible.activeItems.isEmpty)
    }

    @MainActor
    @Test("local projection falls back to baseline metadata for partial plans")
    func localProjectionFallsBackForPartialPlans() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = ShoppingListState(
            id: baseline.id,
            chef: baseline.chef,
            items: [],
            nextCursor: baseline.nextCursor,
            updatedAt: baseline.updatedAt
        )
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyAppliedBatch: { _ in },
            executeRemote: { _ in Issue.record("Partial local plans must not execute transport") },
            fetchShoppingList: { visible },
            recordShoppingList: { visible = $0 }
        )
        let incompleteCheck = ShoppingSurfaceMutationPlan(
            action: .setItemChecked(
                itemID: "missing-item",
                checked: false,
                clientMutationID: "cm_partial_check"
            ),
            originalShoppingList: visible
        )
        #expect(try await coordinator.submit(incompleteCheck) == .synced)

        visible = baseline
        let incompleteDelete = ShoppingSurfaceMutationPlan(
            action: .deleteItem(
                itemID: "item_lemons",
                clientMutationID: "cm_partial_delete",
                confirmation: .confirmed
            ),
            originalShoppingList: baseline
        )
        #expect(try await coordinator.submit(incompleteDelete) == .synced)
        #expect(visible.item(id: "item_lemons")?.deletedAt == baseline.updatedAt)

        visible = baseline
        let incompleteClear = ShoppingSurfaceMutationPlan(
            action: .clearAll(
                clientMutationID: "cm_partial_clear",
                confirmation: .confirmed
            ),
            originalShoppingList: baseline
        )
        #expect(try await coordinator.submit(incompleteClear) == .synced)
        #expect(visible.activeItems.isEmpty)
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
    case persistenceFailed
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
