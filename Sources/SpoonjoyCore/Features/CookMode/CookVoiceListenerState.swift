import Foundation

public enum CookVoiceEvent: Equatable, Sendable {
    case userToggledOn, userToggledOff, permissionGranted, permissionDenied, sceneInactive, cookModeClosed
    /// The recognizer can't run: unsupported locale, missing on-device assets, or an audio failure.
    case recognizerUnavailable(reason: String)
}

/// The cook-mode mic's lifecycle. The mic is live only in `.listening`; leaving cook mode or
/// the foreground always turns it off. A denial parks in `.unavailable` and stays quiet until
/// the user taps the mic again.
public enum CookVoiceListenerState: Equatable, Sendable {
    case off, requestingPermission, listening, unavailable(reason: String)

    public var isMicLive: Bool { self == .listening }

    /// Whether the toggle reads as on: the user asked for voice and nothing has refused it.
    public var isToggledOn: Bool { self == .listening || self == .requestingPermission }

    public func next(on event: CookVoiceEvent) -> CookVoiceListenerState {
        switch (self, event) {
        case (_, .userToggledOff), (_, .cookModeClosed):
            return .off
        case (.off, .userToggledOn), (.unavailable, .userToggledOn):
            return .requestingPermission
        case (.requestingPermission, .permissionGranted):
            return .listening
        case (.requestingPermission, .permissionDenied):
            return .unavailable(reason: "permission")
        case (.requestingPermission, .recognizerUnavailable(let reason)), (.listening, .recognizerUnavailable(let reason)):
            return .unavailable(reason: reason)
        case (.requestingPermission, .sceneInactive), (.listening, .sceneInactive):
            return .off
        default:
            return self
        }
    }
}
