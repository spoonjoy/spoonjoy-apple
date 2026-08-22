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
    @Test("reconciliation evidence covers every shopping action shape")
    func reconciliationEvidenceCoversEveryActionShape() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let cancelled = APITransportError(
            kind: .cancelled,
            requestID: nil,
            statusCode: nil,
            apiError: nil,
            retryDecision: .doNotRetry
        )

        func reconcile(
            _ plan: ShoppingSurfaceMutationPlan,
            against fetched: ShoppingListState
        ) async throws -> ShoppingSurfaceMutationOutcome {
            let coordinator = ShoppingMutationCoordinator(
                persistAlreadyApplied: { _ in },
                executeRemote: { _ in throw cancelled },
                fetchShoppingList: { fetched },
                recordShoppingList: { _ in }
            )
            return try await coordinator.submit(plan)
        }

        let add = try viewModel(baseline).plan(.addItem(
            name: "  Mint  ",
            quantity: 1,
            unit: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_evidence_add"
        ))
        #expect(try await reconcile(add, against: try #require(add.updatedShoppingList)) == .synced)
        #expect(try await reconcile(add, against: baseline) == .recovering)

        let delete = try viewModel(baseline).plan(.deleteItem(
            itemID: "item_lemons",
            clientMutationID: "cm_evidence_delete",
            confirmation: .confirmed
        ))
        #expect(try await reconcile(delete, against: try #require(delete.updatedShoppingList)) == .synced)
        let withoutLemons = ShoppingListState(
            id: baseline.id,
            chef: baseline.chef,
            items: baseline.items.filter { $0.id != "item_lemons" },
            nextCursor: baseline.nextCursor,
            updatedAt: baseline.updatedAt
        )
        #expect(try await reconcile(delete, against: withoutLemons) == .synced)
        #expect(try await reconcile(delete, against: baseline) == .recovering)

        let ingredients = [
            RecipeIngredient(id: "ingredient_mint", name: "mint", quantity: 1, unit: nil),
            RecipeIngredient(id: "ingredient_salt", name: "salt", quantity: 1, unit: "tsp")
        ]
        let recipe = try viewModel(baseline).plan(.addRecipeIngredients(
            recipeID: "recipe_evidence",
            scaleFactor: 1,
            recipeIngredients: ingredients,
            clientMutationID: "cm_evidence_recipe"
        ))
        #expect(try await reconcile(recipe, against: try #require(recipe.updatedShoppingList)) == .synced)
        #expect(try await reconcile(recipe, against: baseline) == .recovering)

        let checked = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: baseline.updatedAt,
            updatedAt: baseline.updatedAt,
            nextSortIndex: 10
        )
        let clearCompleted = try viewModel(checked).plan(.clearCompleted(
            clientMutationID: "cm_evidence_completed",
            confirmation: .confirmed
        ))
        let clearCompletedEvidence = ShoppingSurfaceMutationPlan(
            identity: clearCompleted.identity,
            action: .clearCompleted(clientMutationID: "cm_evidence_completed", confirmation: .confirmed),
            remoteRequestBuilder: clearCompleted.remoteRequestBuilder,
            originalShoppingList: checked,
            updatedShoppingList: clearCompleted.updatedShoppingList
        )
        #expect(try await reconcile(clearCompletedEvidence, against: try #require(clearCompleted.updatedShoppingList)) == .synced)
        #expect(try await reconcile(clearCompletedEvidence, against: checked) == .recovering)

        let clearAll = try viewModel(baseline).plan(.clearAll(
            clientMutationID: "cm_evidence_all",
            confirmation: .confirmed
        ))
        let clearAllEvidence = ShoppingSurfaceMutationPlan(
            identity: clearAll.identity,
            action: .clearAll(clientMutationID: "cm_evidence_all", confirmation: .confirmed),
            remoteRequestBuilder: clearAll.remoteRequestBuilder,
            originalShoppingList: baseline,
            updatedShoppingList: clearAll.updatedShoppingList
        )
        #expect(try await reconcile(clearAllEvidence, against: try #require(clearAll.updatedShoppingList)) == .synced)
        #expect(try await reconcile(clearAllEvidence, against: baseline) == .recovering)

        let clearCompletedWithoutOriginal = ShoppingSurfaceMutationPlan(
            action: .clearCompleted(clientMutationID: "cm_evidence_completed_partial", confirmation: .confirmed),
            remoteRequestBuilder: clearCompleted.remoteRequestBuilder,
            updatedShoppingList: baseline
        )
        #expect(try await reconcile(clearCompletedWithoutOriginal, against: baseline) == .synced)
        let clearAllWithoutOriginal = ShoppingSurfaceMutationPlan(
            action: .clearAll(clientMutationID: "cm_evidence_all_partial", confirmation: .confirmed),
            remoteRequestBuilder: clearAll.remoteRequestBuilder,
            updatedShoppingList: baseline
        )
        #expect(try await reconcile(clearAllWithoutOriginal, against: baseline) == .synced)

        let seedRequest = try #require(add.remoteRequestBuilder)
        let localOnlyShape = ShoppingSurfaceMutationPlan(
            remoteRequestBuilder: seedRequest,
            originalShoppingList: baseline,
            updatedShoppingList: baseline
        )
        #expect(try await reconcile(localOnlyShape, against: baseline) == .synced)
    }

    @MainActor
    @Test("recovery remains pending until a post-replay read proves the write")
    func recoveryRequiresPostReplayEvidence() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let applied = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: baseline.updatedAt,
            updatedAt: baseline.updatedAt,
            nextSortIndex: 10
        )
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes == 1 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads < 4 ? baseline : applied
            },
            recordShoppingList: { _ in }
        )
        let plan = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_post_replay_evidence"
        ))

        #expect(try await coordinator.submit(plan) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .recovering)
        #expect(writes == 2)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(writes == 2)
    }

    @MainActor
    @Test("independent indeterminate mutations retain ordered recovery obligations")
    func independentIndeterminateMutationsRetainOrderedRecoveries() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let checked = try baseline.settingChecked(
            true,
            itemID: "item_lemons",
            checkedAt: baseline.updatedAt,
            updatedAt: baseline.updatedAt,
            nextSortIndex: 10
        )
        let add = try viewModel(checked).plan(.addItem(
            name: "mint",
            quantity: 2,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_multi_recovery_b"
        ))
        let appliedBoth = try #require(add.updatedShoppingList)
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        var writes = 0
        var reads = 0
        var feedback: ShoppingMutationFeedback?
        var visible = baseline
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
                Issue.record("Reflected recovery must not replay transport")
            },
            fetchShoppingList: {
                reads += 1
                return switch reads {
                case 1, 2: baseline
                case 3: checked
                default: appliedBoth
                }
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )
        let check = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_multi_recovery_a"
        ))

        #expect(try await coordinator.submit(check) == .recovering)
        #expect(try await coordinator.submit(add) == .recovering)
        #expect(feedback?.identity == check.identity)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback?.identity == add.identity)
        #expect(visible.receiptItems.contains { $0.name == "mint" && $0.quantity == 2 })
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback == nil)
        #expect(writes == 2)
    }

    @MainActor
    @Test("pending recovery optimism survives an independent successful mutation")
    func pendingRecoveryRemainsProjectedThroughIndependentSuccess() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let check = try viewModel(baseline).plan(.setItemChecked(itemID: "item_lemons", checked: true, clientMutationID: "cm_project_a"))
        let mint = try viewModel(baseline).plan(.addItem(name: "mint", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_project_b"))
        let serverMint = try #require(mint.updatedShoppingList)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes == 1 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads == 1 ? baseline : serverMint
            },
            recordShoppingList: { visible = $0 }
        )

        #expect(try await coordinator.submit(check) == .recovering)
        #expect(try await coordinator.submit(mint) == .synced)
        #expect(visible.item(id: "item_lemons")?.isEffectivelyChecked == true)
        #expect(visible.receiptItems.contains { $0.name == "mint" })
    }

    @MainActor
    @Test("independent refresh settles reflected additive recovery without double applying")
    func reflectedAddRecoverySettlesDuringIndependentRefresh() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let addMint = try viewModel(baseline).plan(.addItem(name: "mint", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_reflected_add"))
        let serverWithMint = try #require(addMint.updatedShoppingList)
        let addParsley = try viewModel(serverWithMint).plan(.addItem(name: "parsley", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_after_reflected_add"))
        let serverWithBoth = try #require(addParsley.updatedShoppingList)
        let addBasil = try viewModel(serverWithMint).plan(.addItem(name: "basil", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_later_recovery"))
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : serverWithBoth
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(addMint) == .recovering)
        #expect(try await coordinator.submit(addBasil) == .recovering)
        #expect(try await coordinator.submit(addParsley) == .synced)
        #expect(visible.receiptItems.first { $0.name == "mint" }?.quantity == 2)
        #expect(visible.receiptItems.contains { $0.name == "basil" })
        #expect(feedback?.identity == addBasil.identity)
        #expect(writes == 3)
    }

    @MainActor
    @Test("later reflected additive recovery is not doubled behind an absent head")
    func laterReflectedRecoverySkipsProjectionWithoutReorderingFeedback() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let addMint = try viewModel(baseline).plan(.addItem(name: "mint", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_head_absent"))
        let addBasil = try viewModel(try #require(addMint.updatedShoppingList)).plan(.addItem(name: "basil", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_later_reflected"))
        let serverBasil = try #require(try viewModel(baseline).plan(.addItem(name: "basil", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_later_reflected")).updatedShoppingList)
        let addParsley = try viewModel(serverBasil).plan(.addItem(name: "parsley", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_refresh_success"))
        let serverBasilParsley = try #require(addParsley.updatedShoppingList)
        let expectedServerBasilQuantity = serverBasil.receiptItems.first { $0.name == "basil" }?.quantity
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : serverBasilParsley
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(addMint) == .recovering)
        #expect(try await coordinator.submit(addBasil) == .recovering)
        #expect(try await coordinator.submit(addParsley) == .synced)
        #expect(visible.receiptItems.first { $0.name == "mint" }?.quantity == 1)
        #expect(visible.receiptItems.first { $0.name == "basil" }?.quantity == expectedServerBasilQuantity)
        #expect(visible.receiptItems.contains { $0.name == "parsley" })
        #expect(feedback?.identity == addMint.identity)
    }

    @MainActor
    @Test("same-product additive recoveries project their latest cumulative target when neither is reflected")
    func sameProductRecoveriesProjectLatestTargetWhenNeitherReflected() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "cumulative thyme", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_neither_a"))
        let firstTarget = try #require(first.updatedShoppingList)
        let second = try viewModel(firstTarget).plan(.addItem(name: "cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_neither_b"))
        var writes = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                throw cancelled
            },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        #expect(visible.receiptItems.first { $0.name == "cumulative thyme" }?.quantity == 3)
        #expect(feedback?.identity == first.identity)
        #expect(writes == 2)
    }

    @MainActor
    @Test("same-product additive recoveries settle only the reflected FIFO prefix")
    func sameProductRecoveriesSettleOnlyReflectedPrefix() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "cumulative thyme", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_prefix_a"))
        let firstTarget = try #require(first.updatedShoppingList)
        let second = try viewModel(firstTarget).plan(.addItem(name: "cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_prefix_b"))
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : firstTarget
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback?.identity == second.identity)
        #expect(visible.receiptItems.first { $0.name == "cumulative thyme" }?.quantity == 3)
        #expect(writes == 2)
    }

    @MainActor
    @Test("same-product additive recoveries settle together when the cumulative target is reflected")
    func sameProductRecoveriesSettleCumulativePrefix() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "cumulative thyme", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_final_a"))
        let firstTarget = try #require(first.updatedShoppingList)
        let second = try viewModel(firstTarget).plan(.addItem(name: "cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_final_b"))
        let cumulativeTarget = try #require(second.updatedShoppingList)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
                Issue.record("Reflected cumulative recovery must not replay transport")
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : cumulativeTarget
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback == nil)
        #expect(visible.receiptItems.first { $0.name == "cumulative thyme" }?.quantity == 3)
        #expect(writes == 2)
    }

    @MainActor
    @Test("same-product additive recovery fails closed for an impossible partial quantity")
    func sameProductRecoveriesFailClosedForImpossiblePartialState() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "cumulative thyme", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_impossible_a"))
        let firstTarget = try #require(first.updatedShoppingList)
        let second = try viewModel(firstTarget).plan(.addItem(name: "cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_impossible_b"))
        let misleading = try #require(try viewModel(baseline).plan(.addItem(name: "cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_same_key_impossible_server")).updatedShoppingList)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : misleading
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .recovering)
        #expect(feedback?.identity == first.identity)
        #expect(visible.receiptItems.first { $0.name == "cumulative thyme" }?.quantity == 3)
        #expect(writes == 3)
    }

    @MainActor
    @Test("overlapping recipe and interleaved additive recoveries settle from union evidence")
    func overlappingInterleavedRecoveriesSettleFromUnionEvidence() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let recipe = try viewModel(baseline).plan(.addRecipeIngredients(
            recipeID: "recipe_cumulative_overlap",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "ingredient_overlap_thyme", name: "overlap thyme", quantity: 1, unit: "bunch"),
                RecipeIngredient(id: "ingredient_overlap_sage", name: "overlap sage", quantity: 1, unit: "bunch")
            ],
            clientMutationID: "cm_overlap_recipe"
        ))
        let recipeTarget = try #require(recipe.updatedShoppingList)
        let interleaved = try viewModel(recipeTarget).plan(.addItem(name: "overlap parsley", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_overlap_interleaved"))
        let interleavedTarget = try #require(interleaved.updatedShoppingList)
        let overlapping = try viewModel(interleavedTarget).plan(.addItem(name: "overlap thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_overlap_final"))
        let cumulativeTarget = try #require(overlapping.updatedShoppingList)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 3 { throw cancelled }
                Issue.record("Union-reflected recoveries must not replay transport")
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 3 ? baseline : cumulativeTarget
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(recipe) == .recovering)
        #expect(try await coordinator.submit(interleaved) == .recovering)
        #expect(try await coordinator.submit(overlapping) == .recovering)
        #expect(visible.receiptItems.first { $0.name == "overlap thyme" }?.quantity == 3)
        #expect(visible.receiptItems.first { $0.name == "overlap sage" }?.quantity == 1)
        #expect(visible.receiptItems.first { $0.name == "overlap parsley" }?.quantity == 1)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback == nil)
        #expect(writes == 3)
    }

    @MainActor
    @Test("cumulative recovery atomically rebinds dependent work to the server item")
    func cumulativeRecoveryRebindsDependentWork() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "dependent cumulative thyme", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_cumulative_dependency_a"))
        let firstTarget = try #require(first.updatedShoppingList)
        let localID = try #require(firstTarget.receiptItems.first { $0.name == "dependent cumulative thyme" }?.id)
        let second = try viewModel(firstTarget).plan(.addItem(name: "dependent cumulative thyme", quantity: 2, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_cumulative_dependency_b"))
        let localFinal = try #require(second.updatedShoppingList)
        let serverID = "item_server_cumulative_thyme"
        let serverFinal = ShoppingListState(
            id: localFinal.id,
            chef: localFinal.chef,
            items: localFinal.items.map { item in
                guard item.id == localID else { return item }
                return ShoppingListItem(id: serverID, name: item.name, quantity: item.quantity, unit: item.unit, checked: item.checked, checkedAt: item.checkedAt, deletedAt: item.deletedAt, categoryKey: item.categoryKey, iconKey: item.iconKey, sortIndex: item.sortIndex, updatedAt: item.updatedAt)
            },
            nextCursor: localFinal.nextCursor,
            updatedAt: localFinal.updatedAt
        )
        let serverChecked = try serverFinal.settingChecked(true, itemID: serverID, checkedAt: serverFinal.updatedAt, updatedAt: serverFinal.updatedAt, nextSortIndex: serverFinal.items.count)
        var paths: [String] = []
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { request in
                paths.append(request.pathComponents.joined(separator: "/"))
                if paths.count <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return switch reads {
                case 1, 2: baseline
                case 3: serverFinal
                default: serverChecked
                }
            },
            recordShoppingList: { visible = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        let dependentPlan = try viewModel(visible).plan(.setItemChecked(itemID: localID, checked: true, clientMutationID: "cm_cumulative_dependency_check"))
        let dependent = Task { try await coordinator.submit(dependentPlan) }
        await Task.yield()
        #expect(paths.count == 2)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(try await dependent.value == .synced)
        #expect(paths.count == 3)
        #expect(paths[2].contains(serverID))
        #expect(!paths[2].contains(localID))
        #expect(visible.item(id: serverID)?.isEffectivelyChecked == true)
    }

    @MainActor
    @Test("product evidence keeps delimiter-bearing name and unit pairs distinct")
    func productEvidenceKeysDoNotCollide() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        var feedback: ShoppingMutationFeedback?
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "a|b", quantity: 1, unit: "c", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_key_collision_a"))
        let secondOnly = try viewModel(baseline).plan(.addItem(name: "a", quantity: 1, unit: "b|c", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_key_collision_b_server"))
        let serverSecond = try #require(secondOnly.updatedShoppingList)
        let second = try viewModel(try #require(first.updatedShoppingList)).plan(.addItem(name: "a", quantity: 1, unit: "b|c", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_key_collision_b"))
        let refresh = try viewModel(serverSecond).plan(.addItem(name: "collision parsley", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_key_collision_refresh"))
        let serverRefresh = try #require(refresh.updatedShoppingList)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : serverRefresh
            },
            recordShoppingList: { visible = $0 },
            recordFeedback: { feedback = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(second) == .recovering)
        #expect(try await coordinator.submit(refresh) == .synced)
        #expect(feedback?.identity == first.identity)
        #expect(visible.receiptItems.first { $0.name == "a|b" && $0.unit == "c" }?.quantity == 1)
        #expect(visible.receiptItems.first { $0.name == "a" && $0.unit == "b|c" }?.quantity == 1)
    }

    @MainActor
    @Test("later reflected non-additive recovery is not projected behind an absent head")
    func laterReflectedNonAdditiveRecoverySkipsProjection() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let first = try viewModel(baseline).plan(.addItem(name: "nonadd head mint", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_nonadd_head"))
        let later = try viewModel(try #require(first.updatedShoppingList)).plan(.setItemChecked(itemID: "item_lemons", checked: true, clientMutationID: "cm_nonadd_later"))
        let serverChecked = try baseline.settingChecked(true, itemID: "item_lemons", checkedAt: baseline.updatedAt, updatedAt: baseline.updatedAt, nextSortIndex: baseline.items.count)
        var writes = 0
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes <= 2 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return reads <= 2 ? baseline : serverChecked
            },
            recordShoppingList: { visible = $0 }
        )

        #expect(try await coordinator.submit(first) == .recovering)
        #expect(try await coordinator.submit(later) == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .recovering)
        #expect(visible.receiptItems.contains { $0.name == "nonadd head mint" })
        #expect(visible.item(id: "item_lemons")?.isEffectivelyChecked == true)
        #expect(writes == 3)
    }

    @MainActor
    @Test("dependent local item mutations wait and rebind after add recovery")
    func dependentMutationWaitsForRecoveryAndRebinds() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        var visible = baseline
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let add = try viewModel(baseline).plan(.addItem(name: "mint", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_dependency_add"))
        let optimistic = try #require(add.updatedShoppingList)
        let localMint = try #require(optimistic.item(id: "item_local_cm_dependency_add"))
        let remoteMint = ShoppingListItem(
            id: "item_server_mint",
            name: localMint.name,
            quantity: localMint.quantity,
            unit: localMint.unit,
            checked: localMint.checked,
            checkedAt: localMint.checkedAt,
            deletedAt: localMint.deletedAt,
            categoryKey: localMint.categoryKey,
            iconKey: localMint.iconKey,
            sortIndex: localMint.sortIndex,
            updatedAt: localMint.updatedAt
        )
        let serverAdded = ShoppingListState(
            id: optimistic.id,
            chef: optimistic.chef,
            items: optimistic.items.map { $0.id == localMint.id ? remoteMint : $0 },
            nextCursor: optimistic.nextCursor,
            updatedAt: optimistic.updatedAt
        )
        let serverChecked = try serverAdded.settingChecked(true, itemID: remoteMint.id, checkedAt: serverAdded.updatedAt, updatedAt: serverAdded.updatedAt, nextSortIndex: 20)
        let serverDeleted = try serverChecked.removingItem(id: remoteMint.id, deletedAt: serverChecked.updatedAt)
        var paths: [String] = []
        var persisted: [NativeQueuedMutation] = []
        var reads = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { persisted.append($0) },
            executeRemote: { request in
                paths.append(request.pathComponents.joined(separator: "/"))
                if paths.count == 1 { throw cancelled }
            },
            fetchShoppingList: {
                reads += 1
                return switch reads {
                case 1: baseline
                case 2: serverAdded
                case 3: serverChecked
                default: serverDeleted
                }
            },
            recordShoppingList: { visible = $0 }
        )

        #expect(try await coordinator.submit(add) == .recovering)
        let check = try viewModel(visible).plan(.setItemChecked(itemID: localMint.id, checked: true, clientMutationID: "cm_dependency_check"))
        let dependent = Task { try await coordinator.submit(check) }
        let delete = try viewModel(visible).plan(.deleteItem(itemID: localMint.id, clientMutationID: "cm_dependency_delete", confirmation: .confirmed))
        let dependentDelete = Task { try await coordinator.submit(delete) }
        let independentPlan = try viewModel(visible).plan(.addItem(name: "parsley", quantity: 1, unit: "bunch", categoryKey: "produce", iconKey: "leaf", clientMutationID: "cm_dependency_independent"))
        let independent = Task { try await coordinator.submit(independentPlan) }
        let queuedCheck = ShoppingSurfaceMutationPlan(
            identity: ShoppingSurfaceMutationIdentity(kind: .setItemChecked, clientMutationID: "cm_dependency_queued", itemID: localMint.id),
            action: .setItemChecked(itemID: localMint.id, checked: false, clientMutationID: "cm_dependency_queued"),
            queuedMutation: NativeQueuedMutation.shoppingCheckItem(itemID: localMint.id, checked: false, clientMutationID: "cm_dependency_queued", createdAt: baseline.updatedAt),
            originalShoppingList: visible,
            updatedShoppingList: try? visible.settingChecked(false, itemID: localMint.id, checkedAt: nil, updatedAt: baseline.updatedAt, nextSortIndex: 21)
        )
        let queuedDependent = Task { try await coordinator.submit(queuedCheck) }
        await Task.yield()
        #expect(paths.count == 1)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(try await dependent.value == .synced)
        #expect(try await dependentDelete.value == .synced)
        #expect(try await independent.value == .synced)
        #expect(try await queuedDependent.value == .queuedForSync)
        #expect(paths.count == 4)
        #expect(paths[1].contains(remoteMint.id))
        #expect(!paths[1].contains(localMint.id))
        #expect(paths[2].contains(remoteMint.id))
        #expect(persisted.count == 1)
    }

    @MainActor
    @Test("ambiguous recipe recovery retains dependent local work")
    func ambiguousRecipeRecoveryRetainsDependentWork() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        let recipe = try viewModel(baseline).plan(.addRecipeIngredients(
            recipeID: "recipe_duplicate_mint",
            scaleFactor: 1,
            recipeIngredients: [
                RecipeIngredient(id: "mint_a", name: "mint", quantity: 1, unit: "bunch"),
                RecipeIngredient(id: "mint_b", name: "mint", quantity: 1, unit: "bunch")
            ],
            clientMutationID: "cm_ambiguous_recipe"
        ))
        let optimistic = try #require(recipe.updatedShoppingList)
        let localMint = try #require(optimistic.receiptItems.first { $0.name == "mint" })
        let remoteMint = ShoppingListItem(
            id: "item_server_recipe_mint",
            name: localMint.name,
            quantity: localMint.quantity,
            unit: localMint.unit,
            checked: localMint.checked,
            checkedAt: localMint.checkedAt,
            deletedAt: localMint.deletedAt,
            categoryKey: localMint.categoryKey,
            iconKey: localMint.iconKey,
            sortIndex: localMint.sortIndex,
            updatedAt: localMint.updatedAt
        )
        let serverApplied = ShoppingListState(
            id: optimistic.id,
            chef: optimistic.chef,
            items: optimistic.items.map { $0.id == localMint.id ? remoteMint : $0 },
            nextCursor: optimistic.nextCursor,
            updatedAt: optimistic.updatedAt
        )
        var fetchContinuation: CheckedContinuation<ShoppingListState, Never>?
        var shouldSuspendFetch = true
        var writes = 0
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes == 1 { throw cancelled }
            },
            fetchShoppingList: {
                if shouldSuspendFetch {
                    shouldSuspendFetch = false
                    return await withCheckedContinuation { fetchContinuation = $0 }
                }
                return serverApplied
            },
            recordShoppingList: { _ in }
        )
        let creator = Task { try await coordinator.submit(recipe) }
        while fetchContinuation == nil { await Task.yield() }
        let unresolvedLocalID = "item_local_cm_ambiguous_recipe-ingredient-2"
        let dependentPlan = ShoppingSurfaceMutationPlan(
            identity: ShoppingSurfaceMutationIdentity(kind: .setItemChecked, clientMutationID: "cm_ambiguous_check", itemID: unresolvedLocalID),
            action: .setItemChecked(itemID: unresolvedLocalID, checked: true, clientMutationID: "cm_ambiguous_check"),
            remoteRequestBuilder: try ShoppingListRequests.setItemChecked(id: unresolvedLocalID, checked: true, clientMutationID: "cm_ambiguous_check"),
            originalShoppingList: optimistic
        )
        let dependent = Task { try await coordinator.submit(dependentPlan) }
        fetchContinuation?.resume(returning: serverApplied)
        #expect(try await creator.value == .recovering)
        #expect(try await coordinator.retryCurrentRecovery() == .recovering)
        #expect(writes == 1)
        coordinator.resetScope()
        await #expect(throws: CancellationError.self) { try await dependent.value }
    }

    @MainActor
    @Test("matching add names do not prove unapplied quantities or recipe scaling")
    func addEvidenceRequiresExactPlannedProductState() async throws {
        let fixture = try ShoppingListState.decodeFromBundle()
        let baseline = try fixture.addingOrRestoringItem(
            name: "mint",
            quantity: 1,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_existing_mint"
        ).shoppingList
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)

        func reconcile(_ plan: ShoppingSurfaceMutationPlan) async throws -> ShoppingSurfaceMutationOutcome {
            let coordinator = ShoppingMutationCoordinator(
                persistAlreadyApplied: { _ in },
                executeRemote: { _ in throw cancelled },
                fetchShoppingList: { baseline },
                recordShoppingList: { _ in }
            )
            return try await coordinator.submit(plan)
        }

        let add = try viewModel(baseline).plan(.addItem(
            name: "mint",
            quantity: 3,
            unit: "bunch",
            categoryKey: "spices",
            iconKey: "pot",
            clientMutationID: "cm_add_proof"
        ))
        #expect(try await reconcile(add) == .recovering)

        let recipe = try viewModel(baseline).plan(.addRecipeIngredients(
            recipeID: "recipe_scaled_mint",
            scaleFactor: 2,
            recipeIngredients: [RecipeIngredient(id: "ingredient_mint", name: "mint", quantity: 2, unit: "bunch")],
            clientMutationID: "cm_recipe_proof"
        ))
        #expect(try await reconcile(recipe) == .recovering)

        let existingMint = try #require(baseline.receiptItems.first { $0.name == "mint" })
        let duplicateMint = ShoppingListItem(
            id: "item_duplicate_mint",
            name: " MINT ",
            quantity: nil,
            unit: " BUNCH ",
            checked: false,
            checkedAt: nil,
            deletedAt: nil,
            categoryKey: "produce",
            iconKey: "leaf",
            sortIndex: existingMint.sortIndex + 1,
            updatedAt: existingMint.updatedAt
        )
        let duplicateBaseline = ShoppingListState(
            id: baseline.id,
            chef: baseline.chef,
            items: baseline.items + [duplicateMint],
            nextCursor: baseline.nextCursor,
            updatedAt: baseline.updatedAt
        )
        let duplicatePlan = try viewModel(duplicateBaseline).plan(.addItem(
            name: "mint",
            quantity: 1,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: "leaf",
            clientMutationID: "cm_duplicate_proof"
        ))
        let duplicateCoordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in throw cancelled },
            fetchShoppingList: { duplicateBaseline },
            recordShoppingList: { _ in }
        )
        #expect(try await duplicateCoordinator.submit(duplicatePlan) == .recovering)
        #expect(try await duplicateCoordinator.submit(duplicatePlan) == .recovering)

        let incompletePlan = ShoppingSurfaceMutationPlan(
            action: .addItem(
                name: "mint",
                quantity: 1,
                unit: "bunch",
                categoryKey: "produce",
                iconKey: "leaf",
                clientMutationID: "cm_incomplete_proof"
            ),
            remoteRequestBuilder: add.remoteRequestBuilder,
            originalShoppingList: baseline
        )
        #expect(try await reconcile(incompletePlan) == .recovering)

        var fallbackReads = 0
        let appliedAdd = try #require(add.updatedShoppingList)
        let fallbackCoordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in throw cancelled },
            fetchShoppingList: {
                fallbackReads += 1
                return fallbackReads <= 2 ? baseline : appliedAdd
            },
            recordShoppingList: { _ in }
        )
        let invalidProjection = ShoppingSurfaceMutationPlan(
            action: .setItemChecked(
                itemID: "missing-item",
                checked: true,
                clientMutationID: "cm_invalid_projection"
            ),
            remoteRequestBuilder: add.remoteRequestBuilder,
            originalShoppingList: baseline
        )
        #expect(try await fallbackCoordinator.submit(add) == .recovering)
        #expect(try await fallbackCoordinator.submit(invalidProjection) == .recovering)
        #expect(try await fallbackCoordinator.retryCurrentRecovery() == .synced)
    }

    @MainActor
    @Test("a retained failure survives an unrelated recovery settling")
    func retainedFailureSurvivesUnrelatedRecoverySettlement() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let cancelled = APITransportError(kind: .cancelled, requestID: nil, statusCode: nil, apiError: nil, retryDecision: .doNotRetry)
        var writes = 0
        var reads = 0
        var feedback: ShoppingMutationFeedback?
        let add = try viewModel(baseline).plan(.addItem(
            name: "mint",
            quantity: 1,
            unit: "bunch",
            categoryKey: "produce",
            iconKey: nil,
            clientMutationID: "cm_retained_recovery"
        ))
        let applied = try #require(add.updatedShoppingList)
        let coordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in
                writes += 1
                if writes == 1 { throw ShoppingMutationCoordinatorTestError.rejected }
                throw cancelled
            },
            fetchShoppingList: {
                reads += 1
                return reads == 1 ? baseline : applied
            },
            recordShoppingList: { _ in },
            recordFeedback: { feedback = $0 }
        )
        let failed = try viewModel(baseline).plan(.setItemChecked(
            itemID: "item_lemons",
            checked: true,
            clientMutationID: "cm_retained_failure"
        ))
        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) {
            try await coordinator.submit(failed)
        }
        #expect(try await coordinator.submit(add) == .recovering)
        #expect(feedback?.identity == failed.identity)
        #expect(try await coordinator.retryCurrentRecovery() == .synced)
        #expect(feedback?.identity == failed.identity)
    }

    @MainActor
    @Test("dependency analysis covers recipe-created and actionless journal entries")
    func dependencyAnalysisCoversRecipeAndActionlessEntries() async throws {
        let baseline = try ShoppingListState.decodeFromBundle()
        let ingredients = [RecipeIngredient(id: "ingredient_mint", name: "mint", quantity: 1, unit: "bunch")]
        var visible = baseline
        let recipeGate = ShoppingMutationTestGate(firstResult: .failure(ShoppingMutationCoordinatorTestError.rejected))
        let recipeCoordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await recipeGate.wait() },
            fetchShoppingList: { baseline },
            recordShoppingList: { visible = $0 }
        )
        let recipe = try viewModel(baseline).plan(.addRecipeIngredients(
            recipeID: "recipe_dependency",
            scaleFactor: 1,
            recipeIngredients: ingredients,
            clientMutationID: "cm_recipe_dependency"
        ))
        let recipeTask = Task { try await recipeCoordinator.submit(recipe) }
        await recipeGate.waitUntilEntered(count: 1)
        let dependent = try viewModel(visible).plan(.deleteItem(
            itemID: "item_local_cm_recipe_dependency-ingredient-1",
            clientMutationID: "cm_recipe_dependency_delete",
            confirmation: .confirmed
        ))
        let dependentTask = Task { try await recipeCoordinator.submit(dependent) }
        await recipeGate.resumeNext()
        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) { try await recipeTask.value }
        await #expect(throws: ShoppingMutationCoordinatorError.dependencyRejected(dependent.identity)) { try await dependentTask.value }

        let request = try #require(recipe.remoteRequestBuilder)
        let actionlessGate = ShoppingMutationTestGate(firstResult: .failure(ShoppingMutationCoordinatorTestError.rejected))
        let actionlessCoordinator = ShoppingMutationCoordinator(
            persistAlreadyApplied: { _ in },
            executeRemote: { _ in try await actionlessGate.wait() },
            fetchShoppingList: { baseline },
            recordShoppingList: { _ in }
        )
        let actionless = ShoppingSurfaceMutationPlan(
            remoteRequestBuilder: request,
            originalShoppingList: baseline,
            updatedShoppingList: baseline
        )
        let firstTask = Task { try await actionlessCoordinator.submit(actionless) }
        await actionlessGate.waitUntilEntered(count: 1)
        let secondTask = Task { try await actionlessCoordinator.submit(actionless) }
        await actionlessGate.resumeNext()
        await #expect(throws: ShoppingMutationCoordinatorTestError.rejected) { try await firstTask.value }
        await actionlessGate.waitUntilEntered(count: 2)
        await actionlessGate.resumeNext()
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
