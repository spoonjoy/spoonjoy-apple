import Foundation

/// The lines cook mode shows (and VoiceOver reads) about voice. None of them parses as a command, so the mic can
/// never act on the app's own words.
public enum CookVoiceNoticeText {
    // A command word never ends the line: at a slow VoiceOver rate the mic could hear that last word alone.
    public static let listening = "Say next, back, repeat or timer when you're ready"
    public static let preparing = "Preparing voice…"
    public static let lastStep = "This is the last step."
    public static let firstStep = "This is the first step."
    public static let actionFailed = "That didn't work. Try the button."

    public static func unavailable(reason: String) -> String {
        switch reason {
        case "permission": "Voice needs the microphone. Allow it in Settings."
        case "locale": "Voice commands work in English only for now."
        case "interrupted": "Voice stopped. Tap the mic to listen again."
        default: "Voice couldn't start. Tap the mic to try again."
        }
    }

    /// Whether the unavailable line offers a way to Settings.
    public static func offersSettings(reason: String) -> Bool {
        reason == "permission"
    }

    public static func turnedForward(to step: Int, of total: Int) -> String {
        "On to step \(step) of \(total)"
    }

    public static func turnedBack(to step: Int, of total: Int) -> String {
        "Back to step \(step) of \(total)"
    }

    public static func reading(step: Int, of total: Int) -> String {
        "Reading step \(step) of \(total)"
    }

    /// The mic button's accessibility label. It carries the state, because a toolbar button drops its accessibility
    /// value, and VoiceOver reads it aloud, so it must not parse as a command either.
    public static func micLabel(for state: CookVoiceListenerState, preparing: Bool) -> String {
        switch state {
        case .off: "Listen for next, back, repeat, timer"
        case .requestingPermission: preparing ? "Preparing voice. Tap to stop" : "Starting to listen. Tap to stop"
        case .listening: "Listening. Tap to stop"
        case .unavailable: "Voice unavailable. Tap to try again"
        }
    }
}
