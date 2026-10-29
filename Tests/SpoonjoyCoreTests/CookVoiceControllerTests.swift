import Foundation
import Testing
@testable import SpoonjoyCore

@MainActor
private final class FakeVoiceSession: CookVoiceRunning {
    var stopped = 0
    func stop() { stopped += 1 }
}

private struct FakeStartError: Error {}

/// Stands in for the microphone and recognizer, so the mic's lifecycle runs without audio.
@MainActor
private final class FakeVoiceEngine: CookVoiceEngine {
    var preparation: CookVoicePreparation = .ready
    var downloads = false
    var startFails = false
    /// Runs while `start` is in flight, before it returns, to race the start against the cook.
    var duringStart: () -> Void = {}
    var sessions: [FakeVoiceSession] = []
    var heard: (String) -> Void = { _ in }
    var failed: (String) -> Void = { _ in }
    var spoken: [String] = []
    var stopSpeakingCount = 0

    func prepare(downloading: @escaping @MainActor (Bool) -> Void) async -> CookVoicePreparation {
        if downloads {
            downloading(true)
        }
        return preparation
    }

    func start(
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> any CookVoiceRunning {
        if startFails {
            throw FakeStartError()
        }
        self.heard = heard
        self.failed = failed
        let session = FakeVoiceSession()
        sessions.append(session)
        duringStart()
        return session
    }

    func speak(_ text: String, gate: CookVoiceMuteGate) {
        spoken.append(text)
    }

    func stopSpeaking() {
        stopSpeakingCount += 1
    }
}

@MainActor
@Suite("Cook voice controller")
struct CookVoiceControllerTests {
    private func listening(_ engine: FakeVoiceEngine, clock: @escaping () -> TimeInterval = { 100 }) async -> CookVoiceController {
        let controller = CookVoiceController(engine: engine, clock: clock)
        controller.toggle()
        await controller.settle()
        return controller
    }

    @Test func tapListensAndHeardCommandsRun() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }
        #expect(controller.state == .listening)
        engine.heard("okay next step")
        engine.heard("the next thing is garlic and onions")
        engine.heard("go back")
        #expect(commands == [.next, .back])
    }

    @Test func leavingTheForegroundStopsTheMic() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        controller.send(.sceneInactive)
        #expect(controller.state == .off)
        #expect(engine.sessions.map(\.stopped) == [1])
        #expect(engine.stopSpeakingCount == 1)
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }
        engine.heard("next")
        #expect(commands.isEmpty)
    }

    @Test func closingCookModeStopsTheMic() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        controller.send(.cookModeClosed)
        #expect(controller.state == .off)
        #expect(engine.sessions.first?.stopped == 1)
    }

    @Test func secondTapStopsTheMic() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        controller.toggle()
        #expect(controller.state == .off)
        #expect(engine.sessions.first?.stopped == 1)
    }

    @Test func aDeadMicLeavesListening() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        engine.failed("interrupted")
        #expect(controller.state == .unavailable(reason: "interrupted"))
        #expect(engine.sessions.first?.stopped == 1)
        // A failure reported after the mic is already off changes nothing.
        controller.toggle()
        controller.send(.userToggledOff)
        engine.failed("interrupted")
        #expect(controller.state == .off)
    }

    @Test func deniedMicrophoneParksUnavailable() async {
        let engine = FakeVoiceEngine()
        engine.preparation = .denied
        let controller = await listening(engine)
        #expect(controller.state == .unavailable(reason: "permission"))
        #expect(engine.sessions.isEmpty)
    }

    @Test func unsupportedLanguageParksUnavailable() async {
        let engine = FakeVoiceEngine()
        engine.preparation = .unavailable(reason: "locale")
        let controller = await listening(engine)
        #expect(controller.state == .unavailable(reason: "locale"))
    }

    @Test func aFailedStartParksUnavailable() async {
        let engine = FakeVoiceEngine()
        engine.startFails = true
        let controller = await listening(engine)
        #expect(controller.state == .unavailable(reason: "audio"))
    }

    @Test func downloadShowsPreparingUntilItEnds() async {
        let engine = FakeVoiceEngine()
        engine.downloads = true
        var seen: [Bool] = []
        let controller = CookVoiceController(engine: engine)
        let watch = controller.$isPreparing.sink { seen.append($0) }
        controller.toggle()
        await controller.settle()
        watch.cancel()
        #expect(seen == [false, true, false])
        #expect(controller.state == .listening)
    }

    @Test func stoppingDuringStartReleasesTheMic() async {
        let engine = FakeVoiceEngine()
        let controller = CookVoiceController(engine: engine)
        engine.duringStart = { controller.send(.sceneInactive) }
        controller.toggle()
        await controller.settle()
        #expect(controller.state == .off)
        #expect(engine.sessions.first?.stopped == 1)
    }

    @Test func stoppingDuringPermissionOpensNothing() async {
        let engine = FakeVoiceEngine()
        let controller = CookVoiceController(engine: engine)
        controller.toggle()
        controller.toggle()
        await controller.settle()
        #expect(controller.state == .off)
        #expect(engine.sessions.isEmpty)
    }

    @Test func readingAloudGoesToTheEngine() async {
        let engine = FakeVoiceEngine()
        let controller = CookVoiceController(engine: engine)
        controller.read("Toast the garlic")
        #expect(engine.spoken == ["Toast the garlic"])
    }

    @Test func mutedAudioIsNotACommand() async {
        let engine = FakeVoiceEngine()
        let controller = await listening(engine)
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }
        controller.gate.speechBegan()
        engine.heard("next")
        controller.gate.speechEnded(at: 0, tail: 0)
        engine.heard("next")
        #expect(commands == [.next])
    }

    @Test func voiceOverReadingANoticeIsNotACommand() async {
        let engine = FakeVoiceEngine()
        var time: TimeInterval = 100
        let controller = await listening(engine, clock: { time })
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }

        // A line VoiceOver doesn't speak mutes nothing.
        controller.announced("On to step 2 of 3", spokenAloud: false)
        engine.heard("next")
        #expect(commands == [.next])

        // VoiceOver says "Timer started"; while it speaks, the mic hears nothing.
        controller.announced("Timer started", spokenAloud: true)
        engine.heard("timer")
        #expect(commands == [.next])

        // After it finishes, the tail of the line heard back is an echo, but the cook's own word is a command.
        time += CookVoiceController.speakingTime(words: 2)
        engine.heard("timer started")
        engine.heard("next")
        // Longer than the line, so it can't be the line's echo.
        engine.heard("start the timer")
        #expect(commands == [.next, .next, .startTimer])

        // Long after, the same words are the cook's.
        time += CookVoiceController.echoTail
        engine.heard("timer")
        #expect(commands == [.next, .next, .startTimer, .startTimer])
        // An empty utterance is never an echo and never a command.
        engine.heard("")
        #expect(commands == [.next, .next, .startTimer, .startTimer])
    }

    @Test func oldAnnouncementsAreForgotten() async {
        let engine = FakeVoiceEngine()
        var time: TimeInterval = 100
        let controller = await listening(engine, clock: { time })
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }
        controller.announced("We can go back to step 1 of 3 and so on", spokenAloud: true)
        time += 60
        controller.announced("Timer started", spokenAloud: true)
        time += CookVoiceController.speakingTime(words: 2)
        // "go back" was in the old line only; that line has expired, so this is the cook speaking.
        engine.heard("go back")
        #expect(commands == [.back])
    }

    /// The mic says what it listens for as it turns on. A lone command word right after is the cook, not that line
    /// heard back: the mic was muted while it was spoken. Two or more of its words in a row are still its echo.
    @Test func aSingleWordRightAfterTheListeningLineIsACommand() async {
        let engine = FakeVoiceEngine()
        var time: TimeInterval = 100
        let controller = await listening(engine, clock: { time })
        var commands: [CookVoiceCommand] = []
        controller.onCommand = { commands.append($0) }
        controller.announced(CookVoiceNoticeText.listening, spokenAloud: true)
        time += CookVoiceController.speakingTime(words: CookVoiceCommand.words(in: CookVoiceNoticeText.listening).count)
        engine.heard("repeat timer")
        #expect(commands.isEmpty)
        engine.heard("next")
        engine.heard("timer")
        #expect(commands == [.next, .startTimer])
    }

    @Test func defaultClockIsTheWallClock() {
        let engine = FakeVoiceEngine()
        let controller = CookVoiceController(engine: engine)
        let before = Date().timeIntervalSinceReferenceDate
        controller.announced("Timer started", spokenAloud: true)
        #expect(controller.gate.isMuted(at: before))
    }
}
