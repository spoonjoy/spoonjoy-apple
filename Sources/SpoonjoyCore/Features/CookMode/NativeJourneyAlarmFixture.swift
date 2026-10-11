import Foundation

/// Lets a journey set and cancel a cook step timer on a simulator that refuses AlarmKit. The CI simulator answers the
/// authorization request with "denied" without showing a prompt, and `simctl privacy` has no alarm service to grant.
/// When a journey launches the app with the environment key set, starting a step timer records a stand-in alarm ID
/// instead of scheduling a system alarm, and Cancel forgets it. Cook mode's per-step registry and its Cancel control
/// run unchanged. The app reads the key only in DEBUG builds, so release builds always use AlarmKit.
public enum NativeJourneyAlarmFixture {
    public static let environmentKey = "SPOONJOY_JOURNEY_ALARM_FIXTURE"

    public static func isRequested(environment: [String: String]) -> Bool {
        switch environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }
}
