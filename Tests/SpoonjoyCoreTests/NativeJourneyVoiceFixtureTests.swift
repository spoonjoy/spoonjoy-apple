import Testing
@testable import SpoonjoyCore

@Suite("Journey voice fixture")
struct NativeJourneyVoiceFixtureTests {
    private func requested(_ value: String?) -> NativeJourneyVoiceFixture? {
        NativeJourneyVoiceFixture.requested(environment: value.map { [NativeJourneyVoiceFixture.environmentKey: $0] } ?? [:])
    }

    @Test func absentOrBlankMeansRealSpeech() {
        #expect(requested(nil) == nil)
        #expect(requested("  ") == nil)
        #expect(requested(" | |") == nil)
    }

    @Test func deniedIgnoresCase() {
        #expect(requested(" Denied ") == .denied)
    }

    @Test func transcriptsSplitOnBars() {
        #expect(requested("okay next step| go back |start the timer") == .transcripts(["okay next step", "go back", "start the timer"]))
    }
}
