import Foundation

/// What a screenshot capture asks of the app beyond its appearance (`ScreenshotAppearance`). Each option is honoured
/// only in capture mode (`SPOONJOY_SCREENSHOT_AUTH`), so a stray variable cannot change the shipping app.
public enum ScreenshotCaptureOptions {
    /// Hides the "Saved copy" status. Captures run on the built-in accounts with no server, so the app rightly says it
    /// is showing a saved copy; a chef who is online never sees that line, and store art should not either.
    public static let hideOfflineStatusKey = "SPOONJOY_SCREENSHOT_HIDE_OFFLINE_STATUS"
    /// The Mac window's size in points, "1440x900". Set from inside the app, because a window sized from outside
    /// (System Events) is held to the screen it is on, and a hosted Mac's screen can be smaller than the size asked for.
    public static let windowSizeKey = "SPOONJOY_SCREENSHOT_WINDOW_SIZE"

    public static func hidesOfflineStatus(in environment: [String: String]) -> Bool {
        isCaptureMode(environment) && isTruthy(environment[hideOfflineStatusKey])
    }

    /// The shell's offline status as a capture shows it: a "Saved copy" line (offline or stale) hidden as if the chef had
    /// dismissed it, when the capture asks; anything that needs the chef's attention stays.
    public static func offlineIndicatorState(_ state: OfflineIndicatorState, in environment: [String: String]) -> OfflineIndicatorState {
        guard hidesOfflineStatus(in: environment), state.display.isVisible, state.display.informationalOnly else {
            return state
        }
        return OfflineIndicatorState(display: .dismissed(previous: state.display, reason: .informationalOnly), dismissal: state.dismissal)
    }

    /// The requested window size, or nil outside capture mode or when the value is not "<width>x<height>" with both at
    /// least 1.
    public static func windowSize(in environment: [String: String]) -> (width: Double, height: Double)? {
        guard isCaptureMode(environment) else {
            return nil
        }
        let parts = normalized(environment[windowSizeKey]).split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width >= 1, height >= 1 else {
            return nil
        }
        return (width, height)
    }

    private static func isCaptureMode(_ environment: [String: String]) -> Bool {
        isTruthy(environment[ScreenshotAppearance.captureModeKey])
    }

    private static func isTruthy(_ value: String?) -> Bool {
        ["1", "true", "yes"].contains(normalized(value))
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
