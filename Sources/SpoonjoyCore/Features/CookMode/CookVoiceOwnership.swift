import Foundation

/// Counts the voice sessions using the audio session, so a start that was cancelled while a newer one was starting
/// can't deactivate the audio session underneath the newer one.
public struct CookAudioSessionUseCount: Equatable, Sendable {
    public private(set) var users = 0

    public init() {}

    public mutating func begin() {
        users += 1
    }

    /// Returns true when no session is left, so the audio session should be deactivated.
    public mutating func end() -> Bool {
        users = max(0, users - 1)
        return users == 0
    }
}

/// The utterance whose read-aloud currently holds the mic deaf. A late callback for an earlier utterance, such as
/// the cancel of the one a newer read replaced, must not end the newer one's mute.
public struct CookSpeechOwnership<Utterance: AnyObject> {
    public private(set) var current: Utterance?

    public init() {}

    public mutating func began(_ utterance: Utterance) {
        current = utterance
    }

    /// Returns true when `utterance` was the one holding the mute, which then ends.
    public mutating func finished(_ utterance: Utterance) -> Bool {
        guard let current, current === utterance else {
            return false
        }
        self.current = nil
        return true
    }
}
