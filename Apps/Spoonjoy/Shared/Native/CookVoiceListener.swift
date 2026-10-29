@preconcurrency import AVFoundation
import Combine
import Foundation
import Speech
import SpoonjoyCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Cook mode's hands-free mic. It hears "next", "back", "repeat", "timer" and "check all" while cook mode is open and
/// the cook has turned it on, and hands each command to cook mode, which runs the same action as the button.
///
/// Recognition is on-device only: `SpeechAnalyzer` with `SpeechTranscriber` runs entirely on this device and sends no
/// audio anywhere, which is its on-device equivalent of `SFSpeechRecognitionRequest.requiresOnDeviceRecognition`. The
/// mic runs only in `CookVoiceListenerState.listening`, and cook mode sends `.sceneInactive` and `.cookModeClosed`,
/// which always stop it. A denied microphone parks the toggle as unavailable, with no prompt until the cook taps it again.
@MainActor
final class CookVoiceListener: ObservableObject {
    @Published private(set) var state: CookVoiceListenerState = .off
    /// True while the on-device speech model downloads, before the first listen ("Preparing voice…").
    @Published private(set) var isPreparing = false

    /// Called on the main actor for each command heard at the end of a final transcript segment.
    var onCommand: (CookVoiceCommand) -> Void = { _ in }

    private let reader = CookStepReader()
    private var session: CookVoiceSession?
    private var preparation: Task<Void, Never>?

    private var lifecycle: [NSObjectProtocol] = []

    /// Cook mode also sends `.sceneInactive` from its scene phase. The app-wide notifications back it up: a scene's
    /// phase can lag when the window shares the screen, and the mic must stop the moment the app leaves the
    /// foreground or the screen locks.
    init() {
#if os(iOS)
        let names = [
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.protectedDataWillBecomeUnavailableNotification
        ]
#else
        let names = [NSApplication.didResignActiveNotification, NSApplication.didHideNotification]
#endif
        lifecycle = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.send(.sceneInactive) }
            }
        }
    }

    deinit {
        lifecycle.forEach(NotificationCenter.default.removeObserver)
    }

    func send(_ event: CookVoiceEvent) {
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
            reader.stop()
            session?.stop()
            session = nil
        }
    }

    func toggle() {
        send(state.isToggledOn ? .userToggledOff : .userToggledOn)
    }

    /// Reads the step aloud. The mic ignores what it hears meanwhile, so the step's own words are never commands.
    func read(_ text: String) {
        reader.speak(text)
    }

    private func prepare() async {
#if DEBUG
        if let fixture = NativeJourneyVoiceFixture.requested(environment: ProcessInfo.processInfo.environment) {
            startFixture(fixture)
            return
        }
#endif
        guard await Self.microphoneAllowed() else {
            send(.permissionDenied)
            return
        }
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            send(.recognizerUnavailable(reason: "locale"))
            return
        }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                isPreparing = true
                try await request.downloadAndInstall()
                isPreparing = false
            }
        } catch {
            isPreparing = false
            send(.recognizerUnavailable(reason: "assets"))
            return
        }
        guard !Task.isCancelled, state == .requestingPermission else {
            return
        }
        do {
            let session = try await CookVoiceSession.start(
                transcriber: transcriber,
                isMuted: { [reader] in reader.isSpeaking },
                heard: { [weak self] transcript in self?.heard(transcript) }
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

    private func heard(_ transcript: String) {
        guard state.isMicLive, let command = CookVoiceCommand.parse(transcript) else {
            return
        }
        onCommand(command)
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

#if DEBUG
    /// The journey stand-in: no microphone, and each transcript is "heard" five seconds after the last.
    private func startFixture(_ fixture: NativeJourneyVoiceFixture) {
        switch fixture {
        case .denied:
            send(.permissionDenied)
        case .transcripts(let transcripts):
            send(.permissionGranted)
            preparation = Task { [weak self] in
                for transcript in transcripts {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }
                    self?.heard(transcript)
                }
            }
        }
    }
#endif
}

/// One run of the microphone into the on-device transcriber, from the first buffer to `stop()`.
@MainActor
private final class CookVoiceSession {
    private let engine: AVAudioEngine
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let results: Task<Void, Never>

    private init(engine: AVAudioEngine, analyzer: SpeechAnalyzer, input: AsyncStream<AnalyzerInput>.Continuation, results: Task<Void, Never>) {
        self.engine = engine
        self.analyzer = analyzer
        self.input = input
        self.results = results
    }

    static func start(
        transcriber: SpeechTranscriber,
        isMuted: @escaping @MainActor () -> Bool,
        heard: @escaping @MainActor (String) -> Void
    ) async throws -> CookVoiceSession {
#if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        // Play-and-record so a step read aloud and the mic share the session; speech comes out of the speaker.
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
#endif
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

        let pipe = CookVoiceAudioPipe(converter: converter, format: analyzerFormat, input: input)
        let tap: AVAudioNodeTapBlock = { buffer, _ in pipe.send(buffer) }
        if #available(iOS 27, macOS 27, *) {
            // The throwing tap. Its error pointer comes before the block, so Swift imports it as an `error: ()`
            // placeholder; a failure throws.
            try inputNode.__installTap(onBus: 0, bufferSize: 4096, format: micFormat, error: (), block: tap)
        } else {
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: micFormat, block: tap)
        }
        engine.prepare()
        try engine.start()

        let results = Task { @MainActor in
            do {
                for try await result in transcriber.results where result.isFinal {
                    guard !isMuted() else { continue }
                    heard(String(result.text.characters))
                }
            } catch {}
        }
        return CookVoiceSession(engine: engine, analyzer: analyzer, input: input, results: results)
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        input.finish()
        results.cancel()
        let analyzer = analyzer
        Task { await analyzer.cancelAndFinishNow() }
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }
}

private enum CookVoiceSessionError: Error {
    case noAudioFormat
}

/// Converts the mic's buffers to the transcriber's format on the audio thread, where the tap runs.
private final class CookVoiceAudioPipe: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let input: AsyncStream<AnalyzerInput>.Continuation

    init(converter: AVAudioConverter, format: AVAudioFormat, input: AsyncStream<AnalyzerInput>.Continuation) {
        self.converter = converter
        self.format = format
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
        input.yield(AnalyzerInput(buffer: converted))
    }
}

/// Reads a step aloud for "repeat" and "read it".
@MainActor
private final class CookStepReader: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// Stays true for a moment after speech ends, so the tail of the step's own words isn't heard as a command.
    private(set) var isSpeaking = false
    private var settle: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        settle?.cancel()
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier(.bcp47))
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        settle?.cancel()
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished() }
    }

    private func finished() {
        settle?.cancel()
        settle = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            isSpeaking = false
        }
    }
}
