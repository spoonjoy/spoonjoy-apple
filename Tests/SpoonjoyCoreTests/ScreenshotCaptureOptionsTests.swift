import SpoonjoyCore
import Testing

struct ScreenshotCaptureOptionsTests {
    @Test func captureModeHidesTheOfflineStatusWhenAsked() {
        #expect(ScreenshotCaptureOptions.hidesOfflineStatus(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "1",
            "SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS": "1",
        ]))
        #expect(!ScreenshotCaptureOptions.hidesOfflineStatus(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "1",
            "SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS": "0",
        ]))
        #expect(!ScreenshotCaptureOptions.hidesOfflineStatus(in: ["SPOONJOY_SCREENSHOT_AUTH": "1"]))
    }

    @Test func outsideCaptureModeTheOfflineStatusStays() {
        #expect(!ScreenshotCaptureOptions.hidesOfflineStatus(in: ["SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS": "1"]))
        #expect(!ScreenshotCaptureOptions.hidesOfflineStatus(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "0",
            "SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS": "1",
        ]))
    }

    @Test func captureModeReadsTheWindowSize() throws {
        let size = try #require(ScreenshotCaptureOptions.windowSize(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "1",
            "SPOONJOY_SCREENSHOT_WINDOW_SIZE": " 1440x900 ",
        ]))
        #expect(size.width == 1440)
        #expect(size.height == 900)
    }

    @Test func aMalformedOrUngatedWindowSizeIsIgnored() {
        #expect(ScreenshotCaptureOptions.windowSize(in: ["SPOONJOY_SCREENSHOT_WINDOW_SIZE": "1440x900"]) == nil)
        for value in ["", "1440", "1440x", "x900", "0x900", "widexhigh", "1440x900x2"] {
            #expect(ScreenshotCaptureOptions.windowSize(in: [
                "SPOONJOY_SCREENSHOT_AUTH": "1",
                "SPOONJOY_SCREENSHOT_WINDOW_SIZE": value,
            ]) == nil, "\(value)")
        }
    }

    @Test func aHiddenCaptureDismissesOnlyTheSavedCopyLine() {
        let capture = ["SPOONJOY_SCREENSHOT_AUTH": "1", "SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS": "1"]
        let offline = OfflineIndicatorReducer(accountID: "chef_capture", environment: .local)
            .reduce(.synced(lastSyncedAt: .now), .networkUnavailable(at: .now))
        #expect(offline.display == .offline)
        #expect(!ScreenshotCaptureOptions.offlineIndicatorState(offline, in: capture).display.isVisible)
        #expect(ScreenshotCaptureOptions.offlineIndicatorState(offline, in: ["SPOONJOY_SCREENSHOT_AUTH": "1"]) == offline)

        let failed = OfflineIndicatorReducer(accountID: "chef_capture", environment: .local)
            .reduce(.synced(lastSyncedAt: .now), .syncFailed(errorID: "sync_capture", retryAfter: nil))
        #expect(ScreenshotCaptureOptions.offlineIndicatorState(failed, in: capture) == failed)
    }
}
