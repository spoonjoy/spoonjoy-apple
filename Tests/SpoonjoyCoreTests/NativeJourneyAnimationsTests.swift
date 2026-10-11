import Testing
@testable import SpoonjoyCore

@Suite("Journey animations launch argument")
struct NativeJourneyAnimationsTests {
    @Test("only the exact launch argument turns animations off")
    func onlyTheExactArgumentTurnsAnimationsOff() {
        #expect(NativeJourneyAnimations.launchArgument == "-UITestDisableAnimations")
        #expect(NativeJourneyAnimations.isRequested(arguments: ["Spoonjoy", "-UITestDisableAnimations", "-AppleLocale"]))
        #expect(!NativeJourneyAnimations.isRequested(arguments: ["Spoonjoy", "-AppleLocale", "en_US"]))
        #expect(!NativeJourneyAnimations.isRequested(arguments: ["UITestDisableAnimations"]))
        #expect(!NativeJourneyAnimations.isRequested(arguments: []))
    }
}
