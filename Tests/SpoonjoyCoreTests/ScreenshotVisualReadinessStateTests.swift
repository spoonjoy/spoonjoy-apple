import Testing
@testable import SpoonjoyCore

@Suite("Screenshot visual readiness state")
struct ScreenshotVisualReadinessStateTests {
    @Test("media stays pending until it reaches a loaded terminal phase")
    func mediaStaysPendingUntilLoaded() {
        var state = ScreenshotVisualReadinessState()

        state.beginMedia("cover-1")
        #expect(state.snapshot == ScreenshotVisualReadinessSnapshot(
            expectedMediaCount: 1,
            loadedMediaCount: 0,
            pendingMediaCount: 1,
            failedMediaCount: 0,
            blockingIndicatorCount: 0,
            isSettled: false
        ))

        state.finishMedia("cover-1", succeeded: true)
        #expect(state.snapshot.isSettled)
        #expect(state.snapshot.loadedMediaCount == 1)
        #expect(state.snapshot.pendingMediaCount == 0)
    }

    @Test("failed media and blocking loaders prevent settlement")
    func failuresAndBlockingLoadersPreventSettlement() {
        var state = ScreenshotVisualReadinessState()

        state.finishMedia("cover-1", succeeded: false)
        state.beginBlockingIndicator("catalog-loader")
        #expect(state.snapshot.expectedMediaCount == 1)
        #expect(state.snapshot.failedMediaCount == 1)
        #expect(state.snapshot.blockingIndicatorCount == 1)
        #expect(!state.snapshot.isSettled)

        state.beginMedia("cover-1")
        state.finishMedia("cover-1", succeeded: true)
        state.endBlockingIndicator("catalog-loader")
        #expect(state.snapshot.isSettled)
        #expect(state.snapshot.failedMediaCount == 0)
        #expect(state.snapshot.loadedMediaCount == 1)
    }

    @Test("removing offscreen media removes it from the active route contract")
    func removingOffscreenMediaRemovesItFromContract() {
        var state = ScreenshotVisualReadinessState()

        state.beginMedia("cover-1")
        state.removeMedia("cover-1")

        #expect(state.snapshot == .settledEmpty)
    }
}
