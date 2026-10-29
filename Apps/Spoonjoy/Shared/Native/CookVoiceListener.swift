@preconcurrency import AVFoundation
import Foundation
import Speech
import SpoonjoyCore

/// The engine cook mode's mic runs on: the journeys' stand-in when a DEBUG journey asks for one, the device otherwise.
@MainActor
enum CookVoiceEngines {
    static func make() -> any CookVoiceEngine {
#if DEBUG
        if let fixture = NativeJourneyVoiceFixture.requested(environment: ProcessInfo.processInfo.environment) {
            return CookVoiceFixtureEngine(fixture: fixture)
        }
#endif
        return CookSpeechEngine()
    }
}

/// The device's microphone and on-device recognizer.
///
/// Recognition is on-device only: `SpeechAnalyzer` with `SpeechTranscriber` runs entirely on this device and sends no
/// audio anywhere, which is its on-device equivalent of `SFSpeechRecognitionRequest.requiresOnDeviceRecognition`.
@MainActor
final class CookSpeechEngine: CookVoiceEngine {
    private let reader = CookStepReader()
    private var transcriber: SpeechTranscriber?

    func prepare(downloading: @escaping @MainActor (Bool) -> Void) async -> CookVoicePreparation {
        guard await Self.microphoneAllowed() else {
            return .denied
        }
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current),
              CookVoiceCommand.supports(languageCode: locale.language.languageCode?.identifier) else {
            return .unavailable(reason: "locale")
        }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                downloading(true)
                try await request.downloadAndInstall()
                downloading(false)
            }
        } catch {
            downloading(false)
            return .unavailable(reason: "assets")
        }
        self.transcriber = transcriber
        return .ready
    }

    func start(
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> any CookVoiceRunning {
        guard let transcriber else {
            throw CookVoiceSessionError.notPrepared
        }
        return try await CookVoiceSession.start(transcriber: transcriber, gate: gate, heard: heard, failed: failed)
    }

    func speak(_ text: String, gate: CookVoiceMuteGate) {
        reader.speak(text, gate: gate)
    }

    func stopSpeaking() {
        reader.stop()
    }

    private static func microphoneAllowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        default:
            return await AVAudioApplication.requestRecordPermission()
        }
    }
}

/// One run of the microphone into the on-device transcriber, from the first buffer to `stop()`. Anything that
/// kills the mic underneath it (the recognizer stopping, an interruption such as a call, the input device going
/// away, the engine reconfiguring) reports through `failed`, so cook mode never shows a live mic that is dead.
@MainActor
private final class CookVoiceSession: CookVoiceRunning {
    private let engine: AVAudioEngine
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private var results: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var stopped = false

    private init(engine: AVAudioEngine, analyzer: SpeechAnalyzer, input: AsyncStream<AnalyzerInput>.Continuation) {
        self.engine = engine
        self.analyzer = analyzer
        self.input = input
    }

    static func start(
        transcriber: SpeechTranscriber,
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> CookVoiceSession {
        try CookAudioSessionUse.begin()
        do {
            return try await startEngine(transcriber: transcriber, gate: gate, heard: heard, failed: failed)
        } catch {
            CookAudioSessionUse.end()
            throw error
        }
    }

    private static func startEngine(
        transcriber: SpeechTranscriber,
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> CookVoiceSession {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let micFormat = inputNode.outputFormat(forBus: 0)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: micFormat),
              let converter = AVAudioConverter(from: micFormat, to: analyzerFormat) else {
            throw CookVoiceSessionError.noAudioFormat
        }
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(inputSequence: stream)

        let pipe = CookVoiceAudioPipe(converter: converter, format: analyzerFormat, gate: gate, input: input)
        CookAudioTap.install(on: inputNode, format: micFormat) { buffer, _ in
            pipe.send(buffer)
        }
        engine.prepare()
        try engine.start()

        let session = CookVoiceSession(engine: engine, analyzer: analyzer, input: input)
        session.watch(failed: failed)
        session.results = Task { @MainActor [weak session] in
            do {
                for try await result in transcriber.results where result.isFinal {
                    heard(String(result.text.characters))
                }
                guard let session, !session.stopped else { return }
                failed("stopped")
            } catch {
                guard let session, !session.stopped else { return }
                failed("stopped")
            }
        }
        return session
    }

    /// Ends listening when the system takes the mic away.
    private func watch(failed: @escaping @MainActor (String) -> Void) {
        let center = NotificationCenter.default
        let report: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.stopped else { return }
                failed("interrupted")
            }
        }
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main, using: report))
#if os(iOS)
        // A call, Siri or another app took the session. iOS 27 reports this as the session going inactive.
        if #available(iOS 27, *) {
            observers.append(center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: .main, using: report))
        } else {
            observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
                let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
                if type == .began {
                    report(note)
                }
            })
        }
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            if reason == .oldDeviceUnavailable {
                report(note)
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main, using: report))
#endif
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        input.finish()
        results?.cancel()
        let analyzer = analyzer
        Task { await analyzer.cancelAndFinishNow() }
        CookAudioSessionUse.end()
    }
}

/// Counts the sessions using the audio session, so a start that was cancelled while a newer one was starting can't
/// deactivate the audio session underneath the newer one. Only the last session to stop deactivates it.
@MainActor
private enum CookAudioSessionUse {
    private static var users = 0

    static func begin() throws {
#if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        // Play-and-record so a step read aloud and the mic share the session; speech comes out of the speaker.
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
#endif
        users += 1
    }

    static func end() {
        users = max(0, users - 1)
        guard users == 0 else { return }
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }
}

private enum CookVoiceSessionError: Error {
    case noAudioFormat, notPrepared
}

/// The tap that feeds the mic into the recognizer. iOS 27 deprecates `installTap(onBus:bufferSize:format:block:)` in
/// favour of a throwing variant that Swift imports only under a double-underscore name. Calling the original through
/// this protocol keeps it in one place and keeps its deprecation out of the warnings-as-errors build.
private protocol CookAudioTapInstalling {
    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock)
}

extension AVAudioNode: CookAudioTapInstalling {}

private enum CookAudioTap {
    static func install(on node: AVAudioNode, format: AVAudioFormat, block: @escaping AVAudioNodeTapBlock) {
        (node as any CookAudioTapInstalling).installTap(onBus: 0, bufferSize: 4096, format: format, block: block)
    }
}

/// Converts the mic's buffers to the transcriber's format on the audio thread, where the tap runs. Audio captured
/// while the app is speaking goes on as silence, judged by when it was captured rather than when it is heard.
private final class CookVoiceAudioPipe: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let gate: CookVoiceMuteGate
    private let input: AsyncStream<AnalyzerInput>.Continuation

    init(converter: AVAudioConverter, format: AVAudioFormat, gate: CookVoiceMuteGate, input: AsyncStream<AnalyzerInput>.Continuation) {
        self.converter = converter
        self.format = format
        self.gate = gate
        self.input = input
    }

    func send(_ buffer: AVAudioPCMBuffer) {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(capacity, 1)) else {
            return
        }
        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, converted.frameLength > 0 else {
            return
        }
        // The tap runs as the audio arrives, so the buffer began about its own length ago.
        let captured = Date().timeIntervalSinceReferenceDate - Double(buffer.frameLength) / buffer.format.sampleRate
        if gate.isMuted(at: captured) {
            for channel in UnsafeMutableAudioBufferListPointer(converted.mutableAudioBufferList) {
                if let data = channel.mData {
                    memset(data, 0, Int(channel.mDataByteSize))
                }
            }
        }
        input.yield(AnalyzerInput(buffer: converted))
    }
}

/// Reads a step aloud for "repeat" and "read it", holding the mic deaf while it speaks and for a moment after.
@MainActor
private final class CookStepReader: NSObject, AVSpeechSynthesizerDelegate {
    /// How long the mic stays deaf after speech ends, for the room's echo.
    static let tail: TimeInterval = 1.5

    private let synthesizer = AVSpeechSynthesizer()
    /// The utterance being read and the gate it holds deaf. A late callback for an earlier utterance, such as the
    /// cancel of the one this replaced, must not end this one's mute.
    private var current: (utterance: AVSpeechUtterance, gate: CookVoiceMuteGate)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, gate: CookVoiceMuteGate) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier(.bcp47))
        current = (utterance, gate)
        gate.speechBegan()
        synthesizer.speak(utterance)
    }

    func stop() {
        guard let current else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finished(current.utterance)
    }

    // The callback holds the utterance itself until it is compared, so a newer utterance can't reuse its address.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finished(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finished(utterance) }
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard let current, current.utterance === utterance else { return }
        current.gate.speechEnded(at: Date().timeIntervalSinceReferenceDate, tail: Self.tail)
        self.current = nil
    }
}

#if DEBUG
/// The journey stand-in: no microphone, and each transcript is "heard" five seconds after the last.
@MainActor
private final class CookVoiceFixtureEngine: CookVoiceEngine {
    private final class Session: CookVoiceRunning {
        var feed: Task<Void, Never>?
        func stop() { feed?.cancel() }
    }

    private let fixture: NativeJourneyVoiceFixture

    init(fixture: NativeJourneyVoiceFixture) {
        self.fixture = fixture
    }

    func prepare(downloading: @escaping @MainActor (Bool) -> Void) async -> CookVoicePreparation {
        fixture == .denied ? .denied : .ready
    }

    func start(
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> any CookVoiceRunning {
        let session = Session()
        guard case .transcripts(let transcripts) = fixture else {
            return session
        }
        session.feed = Task { @MainActor in
            for transcript in transcripts {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                heard(transcript)
            }
        }
        return session
    }

    func speak(_ text: String, gate: CookVoiceMuteGate) {}

    func stopSpeaking() {}
}
#endif
