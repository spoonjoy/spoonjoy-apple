import SpoonjoyCore
import Testing

struct ScreenshotAppearanceTests {
    @Test func captureModeHonoursTheRequestedAppearance() {
        #expect(ScreenshotAppearance.requested(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "1",
            "SPOONJOY_SCREENSHOT_APPEARANCE": "dark",
        ]) == .dark)
        #expect(ScreenshotAppearance.requested(in: [
            "SPOONJOY_SCREENSHOT_AUTH": " True ",
            "SPOONJOY_SCREENSHOT_APPEARANCE": "Light",
        ]) == .light)
    }

    @Test func outsideCaptureModeTheAppearanceIsIgnored() {
        #expect(ScreenshotAppearance.requested(in: ["SPOONJOY_SCREENSHOT_APPEARANCE": "dark"]) == nil)
        #expect(ScreenshotAppearance.requested(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "0",
            "SPOONJOY_SCREENSHOT_APPEARANCE": "dark",
        ]) == nil)
    }

    @Test func unknownOrMissingAppearanceIsIgnored() {
        #expect(ScreenshotAppearance.requested(in: ["SPOONJOY_SCREENSHOT_AUTH": "yes"]) == nil)
        #expect(ScreenshotAppearance.requested(in: [
            "SPOONJOY_SCREENSHOT_AUTH": "1",
            "SPOONJOY_SCREENSHOT_APPEARANCE": "sepia",
        ]) == nil)
    }
}
