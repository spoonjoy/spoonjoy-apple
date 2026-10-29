import Testing
@testable import SpoonjoyCore

@Suite("Cook voice mute gate")
struct CookVoiceMuteGateTests {
    @Test func openByDefault() {
        #expect(!CookVoiceMuteGate().isMuted(at: 100))
    }

    @Test func speechMutesUntilItEndsPlusTheTail() {
        let gate = CookVoiceMuteGate()
        gate.speechBegan()
        #expect(gate.isMuted(at: 1_000))
        gate.speechEnded(at: 10, tail: 1.5)
        #expect(gate.isMuted(at: 11.4))
        #expect(!gate.isMuted(at: 11.5))
    }

    @Test func overlappingSpeechStaysMutedUntilTheLastEnds() {
        let gate = CookVoiceMuteGate()
        gate.speechBegan()
        gate.speechBegan()
        gate.speechEnded(at: 10, tail: 0)
        #expect(gate.isMuted(at: 20))
        gate.speechEnded(at: 20, tail: 0)
        #expect(!gate.isMuted(at: 20))
        gate.speechEnded(at: 20, tail: 0)
        #expect(!gate.isMuted(at: 20))
    }

    @Test func timedMuteKeepsTheLaterEnd() {
        let gate = CookVoiceMuteGate()
        gate.mute(from: 0, for: 5)
        gate.mute(from: 1, for: 1)
        #expect(gate.isMuted(at: 4.9))
        #expect(!gate.isMuted(at: 5))
    }

    @Test func resetOpensTheMic() {
        let gate = CookVoiceMuteGate()
        gate.speechBegan()
        gate.mute(from: 0, for: 100)
        gate.reset()
        #expect(!gate.isMuted(at: 1))
    }
}
