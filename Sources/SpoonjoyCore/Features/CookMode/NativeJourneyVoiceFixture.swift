import Foundation

/// Lets a journey hear cook-mode voice commands on a simulator with no microphone to speak into. When a journey
/// launches the app with the environment key set, the cook-mode mic skips the microphone and the recognizer: it either
/// reports the permission as denied (`denied`) or, once listening, hears each transcript in turn, as if the cook had
/// said it. The commands then run through the same parser and actions as real speech. The app reads the key only in
/// DEBUG builds, so release builds always listen to the microphone.
public enum NativeJourneyVoiceFixture: Equatable, Sendable {
    case denied
    case transcripts([String])

    public static let environmentKey = "SPOONJOY_JOURNEY_VOICE_FIXTURE"

    /// Transcripts are separated by `|`, for example `okay next step|go back`.
    public static func requested(environment: [String: String]) -> NativeJourneyVoiceFixture? {
        guard let raw = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.lowercased() == "denied" {
            return .denied
        }
        let transcripts = raw.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return transcripts.isEmpty ? nil : .transcripts(transcripts)
    }
}
