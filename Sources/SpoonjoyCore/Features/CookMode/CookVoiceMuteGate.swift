import Foundation
import Synchronization

/// Tells the mic when to hear nothing: while the app speaks (a step read aloud, a VoiceOver announcement) and for a
/// moment after. The audio thread asks it about each buffer by the buffer's capture time, so speech that arrives late
/// from the recognizer is still judged by when it was heard. Times are `Date.timeIntervalSinceReferenceDate` seconds.
public final class CookVoiceMuteGate: Sendable {
    private struct Window {
        var openSpeech = 0
        var mutedUntil: TimeInterval = 0
    }

    private let window = Mutex(Window())

    public init() {}

    /// The app started speaking. The mic hears nothing until a matching `speechEnded`.
    public func speechBegan() {
        window.withLock { $0.openSpeech += 1 }
    }

    /// The app stopped speaking at `time`; the mic stays deaf for `tail` more seconds, for the echo.
    public func speechEnded(at time: TimeInterval, tail: TimeInterval) {
        window.withLock {
            $0.openSpeech = max(0, $0.openSpeech - 1)
            $0.mutedUntil = max($0.mutedUntil, time + tail)
        }
    }

    /// Deaf from now until `time + duration`, for speech whose end the app can't observe.
    public func mute(from time: TimeInterval, for duration: TimeInterval) {
        window.withLock { $0.mutedUntil = max($0.mutedUntil, time + duration) }
    }

    /// Clears every mute, when the mic stops.
    public func reset() {
        window.withLock { $0 = Window() }
    }

    public func isMuted(at time: TimeInterval) -> Bool {
        window.withLock { $0.openSpeech > 0 || time < $0.mutedUntil }
    }
}
