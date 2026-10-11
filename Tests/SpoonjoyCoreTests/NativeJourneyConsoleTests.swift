import Testing
@testable import SpoonjoyCore

@Suite("Journey console launch environment")
struct NativeJourneyConsoleTests {
    @Test("UI tests turn off the os_log stderr mirror")
    func uiTestsTurnOffTheStderrMirror() {
        #expect(NativeJourneyConsole.environmentKey == "OS_ACTIVITY_DT_MODE")
        #expect(NativeJourneyConsole.value == "NO")
    }
}
