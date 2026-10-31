import Testing
@testable import SpoonjoyCore

struct CookVoiceOwnershipTests {
    @Test("a cancelled start ending while a newer one is live does not deactivate the audio session")
    func cancelledStartKeepsTheLiveSession() {
        var use = CookAudioSessionUseCount()
        use.begin()
        use.begin()
        let cancelledStartEnded = use.end()
        #expect(!cancelledStartEnded)
        #expect(use.users == 1)
        let liveSessionEnded = use.end()
        #expect(liveSessionEnded)
        // An extra end never goes negative, and still reports nothing left.
        let extraEnd = use.end()
        #expect(extraEnd)
        #expect(use.users == 0)
    }

    private final class Utterance {}

    @Test("a late cancel of a replaced read does not end the newer read's mute")
    func lateCancelKeepsTheNewerMute() {
        var ownership = CookSpeechOwnership<Utterance>()
        let first = Utterance()
        let second = Utterance()
        ownership.began(first)
        // "repeat" again: the first read is stopped, which ends its own mute, and the second begins.
        let stoppedFirst = ownership.finished(first)
        #expect(stoppedFirst)
        ownership.began(second)
        // The synthesizer's didCancel for the first read arrives late.
        let lateCancel = ownership.finished(first)
        #expect(!lateCancel)
        #expect(ownership.current === second)
        let finishedSecond = ownership.finished(second)
        #expect(finishedSecond)
        #expect(ownership.current == nil)
        let repeatedFinish = ownership.finished(second)
        #expect(!repeatedFinish)
    }
}
