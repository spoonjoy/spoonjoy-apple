import Combine
import Foundation

/// What the recognizer's setup found before the mic opens.
public enum CookVoicePreparation: Equatable, Sendable {
    case ready, denied
    case unavailable(reason: String)
}

/// A running microphone and recognizer. `stop()` releases both.
@MainActor
public protocol CookVoiceRunning: AnyObject {
    func stop()
}

/// The device side of cook-mode voice: permission, the speech model, the microphone and the step reader. The app
/// supplies the real one; tests and journeys supply stand-ins.
@MainActor
public protocol CookVoiceEngine: AnyObject {
    /// Asks for the microphone, checks the language and fetches the speech model. `downloading` reports a download.
    func prepare(downloading: @escaping @MainActor (Bool) -> Void) async -> CookVoicePreparation
    /// Opens the mic. `heard` gets each final utterance; `failed` reports a mic that died (an interruption, a lost
    /// route, a recognizer error). Audio captured while `gate` is muted must reach the recognizer as silence.
    func start(
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> any CookVoiceRunning
    /// Reads text aloud, holding `gate` muted while it speaks.
    func speak(_ text: String, gate: CookVoiceMuteGate)
    func stopSpeaking()
}

/// Cook mode's hands-free mic. It runs `CookVoiceListenerState`, opens and closes the engine's mic with it, and
/// hands each command it hears to cook mode. It never acts on the app's own words: the mute gate silences audio while
/// the app speaks, and an utterance that repeats a line the app just announced is dropped.
@MainActor
public final class CookVoiceController: ObservableObject {
    @Published public private(set) var state: CookVoiceListenerState = .off
    /// True while the speech model downloads, before the first listen.
    @Published public private(set) var isPreparing = false

    /// Called for each command heard while listening.
    public var onCommand: (CookVoiceCommand) -> Void = { _ in }

    public let gate: CookVoiceMuteGate

    /// How long after VoiceOver finishes a line hearing it back still counts as an echo, in seconds.
    static let echoTail: TimeInterval = 3

    private let engine: any CookVoiceEngine
    private let clock: () -> TimeInterval
    private var session: (any CookVoiceRunning)?
    private var preparation: Task<Void, Never>?
    private var announcements: [(words: [String], until: TimeInterval)] = []

    public init(
        engine: any CookVoiceEngine,
        gate: CookVoiceMuteGate = CookVoiceMuteGate(),
        clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.engine = engine
        self.gate = gate
        self.clock = clock
    }

    public func send(_ event: CookVoiceEvent) {
        let previous = state
        state = state.next(on: event)
        guard state != previous else {
            return
        }
        switch state {
        case .requestingPermission:
            preparation?.cancel()
            preparation = Task { await prepare() }
        case .listening:
            break
        case .off, .unavailable:
            preparation?.cancel()
            preparation = nil
            isPreparing = false
            engine.stopSpeaking()
            session?.stop()
            session = nil
            gate.reset()
        }
    }

    public func toggle() {
        send(state.isToggledOn ? .userToggledOff : .userToggledOn)
    }

    /// Reads the step aloud; the mic hears nothing while it does.
    public func read(_ text: String) {
        engine.speak(text, gate: gate)
    }

    /// Records a line the app showed. VoiceOver speaks it when it's running (`spokenAloud`), so the mic is muted for
    /// about as long as the line takes to say, and hearing part of it back shortly after is not a command.
    public func announced(_ text: String, spokenAloud: Bool) {
        guard spokenAloud else {
            return
        }
        let now = clock()
        let words = CookVoiceCommand.words(in: text)
        let speaking = Self.speakingTime(words: words.count)
        gate.mute(from: now, for: speaking)
        announcements = announcements.filter { now < $0.until } + [(words, now + speaking + Self.echoTail)]
    }

    /// About how long VoiceOver takes to say a line, with a second of tail.
    static func speakingTime(words: Int) -> TimeInterval {
        Double(words) * 0.4 + 1
    }

    /// Awaits the current permission and start-up work. For tests.
    func settle() async {
        await preparation?.value
    }

    private func prepare() async {
        let result = await engine.prepare { [weak self] downloading in
            self?.isPreparing = downloading
        }
        isPreparing = false
        guard !Task.isCancelled, state == .requestingPermission else {
            return
        }
        switch result {
        case .denied:
            send(.permissionDenied)
        case .unavailable(let reason):
            send(.recognizerUnavailable(reason: reason))
        case .ready:
            do {
                let session = try await engine.start(
                    gate: gate,
                    heard: { [weak self] in self?.heard($0) },
                    failed: { [weak self] in self?.failed($0) }
                )
                guard !Task.isCancelled, state == .requestingPermission else {
                    session.stop()
                    return
                }
                self.session = session
                send(.permissionGranted)
            } catch {
                send(.recognizerUnavailable(reason: "audio"))
            }
        }
    }

    private func heard(_ transcript: String) {
        let now = clock()
        guard state.isMicLive, !gate.isMuted(at: now), !isEcho(transcript, at: now),
              let command = CookVoiceCommand.parse(transcript) else {
            return
        }
        onCommand(command)
    }

    private func failed(_ reason: String) {
        send(.recognizerUnavailable(reason: reason))
    }

    /// An utterance whose words all appear, in order, in a line VoiceOver is saying or just said.
    private func isEcho(_ transcript: String, at now: TimeInterval) -> Bool {
        let words = CookVoiceCommand.words(in: transcript)
        guard !words.isEmpty else {
            return false
        }
        return announcements.contains { announcement in
            now < announcement.until && announcement.words.containsRun(words)
        }
    }
}

private extension Array where Element == String {
    func containsRun(_ run: [String]) -> Bool {
        guard run.count <= count else {
            return false
        }
        return (0...(count - run.count)).contains { start in
            self[start..<(start + run.count)].elementsEqual(run)
        }
    }
}
