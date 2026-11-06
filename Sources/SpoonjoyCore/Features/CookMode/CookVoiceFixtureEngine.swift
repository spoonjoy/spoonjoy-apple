import Foundation

/// The journeys' stand-in for the microphone (`NativeJourneyVoiceFixture`): no microphone and no recognizer. A
/// `denied` fixture reports the permission as refused; otherwise, once the mic is listening, each transcript is
/// "heard" `spacing` after the last, as if the cook had said it. The parser, the listener's states and the actions run
/// unchanged. The app uses it only in DEBUG builds. Headless journeys pass `pace` instead: each transcript is heard when
/// the journey says so, so no step depends on how long anything takes.
@MainActor
public final class CookVoiceFixtureEngine: CookVoiceEngine {
    private final class Session: CookVoiceRunning {
        var feed: Task<Void, Never>?
        func stop() { feed?.cancel() }
    }

    private let fixture: NativeJourneyVoiceFixture
    private let pace: @Sendable () async -> Void

    public convenience init(fixture: NativeJourneyVoiceFixture, spacing: Duration = .seconds(5)) {
        self.init(fixture: fixture, pace: { try? await Task.sleep(for: spacing) })
    }

    /// Each transcript is heard once `pace` returns.
    public init(fixture: NativeJourneyVoiceFixture, pace: @escaping @Sendable () async -> Void) {
        self.fixture = fixture
        self.pace = pace
    }

    public func prepare(downloading: @escaping @MainActor (Bool) -> Void) async -> CookVoicePreparation {
        fixture == .denied ? .denied : .ready
    }

    public func start(
        gate: CookVoiceMuteGate,
        heard: @escaping @MainActor (String) -> Void,
        failed: @escaping @MainActor (String) -> Void
    ) async throws -> any CookVoiceRunning {
        let session = Session()
        guard case .transcripts(let transcripts) = fixture else {
            return session
        }
        let pace = pace
        session.feed = Task { @MainActor in
            for transcript in transcripts {
                await pace()
                guard !Task.isCancelled else { return }
                heard(transcript)
            }
        }
        return session
    }

    public func speak(_ text: String, gate: CookVoiceMuteGate) {}

    public func stopSpeaking() {}
}
