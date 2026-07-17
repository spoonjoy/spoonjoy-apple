import Testing
@testable import SpoonjoyCore

@Suite("Screenshot visual readiness state")
struct ScreenshotVisualReadinessStateTests {
    @Test("media stays pending until it reaches a loaded terminal phase")
    func mediaStaysPendingUntilLoaded() {
        var state = ScreenshotVisualReadinessState()
        let token = ScreenshotVisualReadinessMediaToken(resourceID: "cover-1", instanceID: "lead")

        state.beginMedia(token)
        #expect(state.snapshot == ScreenshotVisualReadinessSnapshot(
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

        #expect(state.snapshot == .settledEmpty)
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
}
