import Testing
@testable import SpoonjoyCore

@Suite("Screenshot visual readiness state")
struct ScreenshotVisualReadinessStateTests {
    @Test("settled empty is the zero-generation no-work readiness state")
    func settledEmptyIsTheZeroGenerationNoWorkReadinessState() {
        #expect(ScreenshotVisualReadinessSnapshot.settledEmpty == ScreenshotVisualReadinessSnapshot(
            generation: 0,
            expectedMediaCount: 0,
            loadedMediaCount: 0,
            pendingMediaCount: 0,
            failedMediaCount: 0,
            blockingIndicatorCount: 0,
            isSettled: true
        ))
    }

    @Test("media stays pending until it reaches a loaded terminal phase")
    func mediaStaysPendingUntilLoaded() {
        var state = ScreenshotVisualReadinessState()
        let token = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")

        state.beginMedia(token)
        #expect(state.snapshot == ScreenshotVisualReadinessSnapshot(
            generation: 1,
            expectedMediaCount: 1,
            loadedMediaCount: 0,
            pendingMediaCount: 1,
            failedMediaCount: 0,
            blockingIndicatorCount: 0,
            isSettled: false
        ))

        state.finishMedia(token, succeeded: true)
        #expect(state.snapshot.isSettled)
        #expect(state.snapshot.loadedMediaCount == 1)
        #expect(state.snapshot.pendingMediaCount == 0)
    }

    @Test("failed media and blocking loaders prevent settlement")
    func failuresAndBlockingLoadersPreventSettlement() {
        var state = ScreenshotVisualReadinessState()
        let token = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")
        let loader = ScreenshotVisualReadinessBlockingToken(resourceID: "catalog-loader", instanceID: "catalog")

        state.finishMedia(token, succeeded: false)
        state.beginBlockingIndicator(loader)
        #expect(state.snapshot.expectedMediaCount == 1)
        #expect(state.snapshot.failedMediaCount == 1)
        #expect(state.snapshot.blockingIndicatorCount == 1)
        #expect(!state.snapshot.isSettled)

        state.beginMedia(token)
        state.finishMedia(token, succeeded: true)
        state.endBlockingIndicator(loader)
        #expect(state.snapshot.isSettled)
        #expect(state.snapshot.failedMediaCount == 0)
        #expect(state.snapshot.loadedMediaCount == 1)
    }

    @Test("matching blocking indicators settle independently by rendered instance")
    func matchingBlockingIndicatorsSettleIndependently() {
        var state = ScreenshotVisualReadinessState()
        let lead = ScreenshotVisualReadinessBlockingToken(resourceID: "route-loading:Recipes", instanceID: "lead")
        let detail = ScreenshotVisualReadinessBlockingToken(resourceID: "route-loading:Recipes", instanceID: "detail")

        state.beginBlockingIndicator(lead)
        state.beginBlockingIndicator(detail)
        state.endBlockingIndicator(lead)

        #expect(state.snapshot.blockingIndicatorCount == 1)
        #expect(!state.snapshot.isSettled)

        state.endBlockingIndicator(detail)
        #expect(state.snapshot.isSettled)
    }

    @Test("removing offscreen media removes it from the active route contract")
    func removingOffscreenMediaRemovesItFromContract() {
        var state = ScreenshotVisualReadinessState()
        let token = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")

        state.beginMedia(token)
        state.removeMedia(token)

        #expect(state.snapshot.generation == 2)
        #expect(state.snapshot.expectedMediaCount == 0)
        #expect(state.snapshot.isSettled)
    }

    @Test("identical media resources settle independently by rendered instance")
    func identicalMediaResourcesSettleIndependently() {
        var state = ScreenshotVisualReadinessState()
        let lead = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")
        let index = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "index")

        state.beginMedia(lead)
        state.beginMedia(index)
        state.finishMedia(lead, succeeded: true)

        #expect(state.snapshot.expectedMediaCount == 2)
        #expect(state.snapshot.loadedMediaCount == 1)
        #expect(state.snapshot.pendingMediaCount == 1)
        #expect(!state.snapshot.isSettled)

        state.removeMedia(lead)
        #expect(state.snapshot.expectedMediaCount == 1)
        #expect(state.snapshot.pendingMediaCount == 1)
        #expect(!state.snapshot.isSettled)

        state.finishMedia(index, succeeded: true)
        #expect(state.snapshot.isSettled)
        #expect(state.snapshot.loadedMediaCount == 1)
    }

    @Test("late media invalidates an earlier settled readiness generation")
    func lateMediaInvalidatesEarlierSettledGeneration() {
        var state = ScreenshotVisualReadinessState()
        let initial = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")
        let late = ScreenshotVisualReadinessMediaToken(resourceID: "cover-2", instanceID: "lazy-row")

        state.beginMedia(initial)
        state.finishMedia(initial, succeeded: true)
        let publishedGeneration = state.snapshot.generation
        #expect(state.snapshot.isSettled)

        state.beginMedia(late)

        #expect(state.snapshot.generation > publishedGeneration)
        #expect(!state.snapshot.isSettled)
        #expect(state.snapshot.pendingMediaCount == 1)
    }

    @Test("idempotent readiness observations do not manufacture generations")
    func idempotentObservationsDoNotAdvanceGeneration() {
        var state = ScreenshotVisualReadinessState()
        let token = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")

        state.beginMedia(token)
        let pendingGeneration = state.snapshot.generation
        state.beginMedia(token)
        #expect(state.snapshot.generation == pendingGeneration)

        state.finishMedia(token, succeeded: true)
        let loadedGeneration = state.snapshot.generation
        state.finishMedia(token, succeeded: true)
        #expect(state.snapshot.generation == loadedGeneration)

        state.finishMedia(token, succeeded: false)
        let failedGeneration = state.snapshot.generation
        state.finishMedia(token, succeeded: false)
        #expect(state.snapshot.generation == failedGeneration)
        #expect(state.snapshot.loadedMediaCount == 0)
        #expect(state.snapshot.failedMediaCount == 1)
    }

    @Test("surface variants advance readiness without media transitions")
    func surfaceVariantsAdvanceReadinessWithoutMediaTransitions() {
        var captureState = ScreenshotVisualReadinessState()
        let captureEmpty = proofIdentity(route: "capture", source: "CaptureDraftView", variant: "empty")
        let captureDraft = proofIdentity(route: "capture", source: "CaptureDraftView", variant: "draft")

        captureState.observeProofIdentity(captureEmpty)
        let emptyGeneration = captureState.snapshot.generation
        captureState.observeProofIdentity(captureDraft)

        #expect(captureState.snapshot.generation > emptyGeneration)
        #expect(captureState.snapshot.expectedMediaCount == 0)
        #expect(captureState.snapshot.isSettled)
        #expect(captureState.snapshot.proofIdentity == captureDraft)

        var shoppingState = ScreenshotVisualReadinessState()
        let observedShoppingState = ScreenshotVisualReadinessObservedSurfaceState(
            statusOwner: "ShoppingListView",
            connectivity: "online",
            queuedMutationCount: 0,
            visibleIndicator: "synced"
        )
        let shoppingLoading = proofIdentity(
            route: "shopping-list",
            source: "ShoppingListView",
            variant: "loading",
            observedSurfaceState: observedShoppingState
        )
        let shoppingNormal = proofIdentity(
            route: "shopping-list",
            source: "ShoppingListView",
            variant: "normal",
            observedSurfaceState: observedShoppingState
        )

        shoppingState.observeProofIdentity(shoppingLoading)
        let loadingGeneration = shoppingState.snapshot.generation
        shoppingState.observeProofIdentity(shoppingLoading)
        #expect(shoppingState.snapshot.generation == loadingGeneration)

        shoppingState.observeProofIdentity(shoppingNormal)
        #expect(shoppingState.snapshot.generation > loadingGeneration)
        #expect(shoppingState.snapshot.expectedMediaCount == 0)
        #expect(shoppingState.snapshot.isSettled)
        #expect(shoppingState.snapshot.proofIdentity == shoppingNormal)
    }

    @Test("every observed proof field participates in readiness identity")
    func everyObservedProofFieldParticipatesInReadinessIdentity() {
        let observedState = ScreenshotVisualReadinessObservedSurfaceState(
            statusOwner: "ShoppingListView",
            connectivity: "online",
            queuedMutationCount: 0,
            visibleIndicator: "synced"
        )
        let baseline = proofIdentity(observedSurfaceState: observedState)
        let changedIdentities = [
            proofIdentity(captureRunNonce: "nonce-2", observedSurfaceState: observedState),
            proofIdentity(route: "capture", observedSurfaceState: observedState),
            proofIdentity(source: "CaptureDraftView", observedSurfaceState: observedState),
            proofIdentity(observedDynamicTypeSize: "accessibility5", observedSurfaceState: observedState),
            proofIdentity(observedReduceMotion: true, observedSurfaceState: observedState),
            proofIdentity(variant: "empty", observedSurfaceState: observedState),
            proofIdentity(observedSurfaceState: nil),
            proofIdentity(observedSurfaceState: ScreenshotVisualReadinessObservedSurfaceState(
                statusOwner: "Shell",
                connectivity: observedState.connectivity,
                queuedMutationCount: observedState.queuedMutationCount,
                visibleIndicator: observedState.visibleIndicator
            )),
            proofIdentity(observedSurfaceState: ScreenshotVisualReadinessObservedSurfaceState(
                statusOwner: observedState.statusOwner,
                connectivity: "offline",
                queuedMutationCount: observedState.queuedMutationCount,
                visibleIndicator: observedState.visibleIndicator
            )),
            proofIdentity(observedSurfaceState: ScreenshotVisualReadinessObservedSurfaceState(
                statusOwner: observedState.statusOwner,
                connectivity: observedState.connectivity,
                queuedMutationCount: 1,
                visibleIndicator: observedState.visibleIndicator
            )),
            proofIdentity(observedSurfaceState: ScreenshotVisualReadinessObservedSurfaceState(
                statusOwner: observedState.statusOwner,
                connectivity: observedState.connectivity,
                queuedMutationCount: observedState.queuedMutationCount,
                visibleIndicator: "queuedWork"
            ))
        ]

        for changedIdentity in changedIdentities {
            var state = ScreenshotVisualReadinessState()
            state.observeProofIdentity(baseline)
            let baselineGeneration = state.snapshot.generation
            state.observeProofIdentity(changedIdentity)

            #expect(state.snapshot.generation > baselineGeneration)
            #expect(state.snapshot.proofIdentity == changedIdentity)
        }
    }

    private func proofIdentity(
        captureRunNonce: String = "nonce-1",
        route: String = "shopping-list",
        source: String = "ShoppingListView",
        observedDynamicTypeSize: String = "large",
        observedReduceMotion: Bool = false,
        variant: String? = "normal",
        observedSurfaceState: ScreenshotVisualReadinessObservedSurfaceState? = nil
    ) -> ScreenshotVisualReadinessProofIdentity {
        ScreenshotVisualReadinessProofIdentity(
            captureRunNonce: captureRunNonce,
            route: route,
            source: source,
            observedDynamicTypeSize: observedDynamicTypeSize,
            observedReduceMotion: observedReduceMotion,
            observedSurfaceVariant: variant,
            observedSurfaceState: observedSurfaceState
        )
    }
}
