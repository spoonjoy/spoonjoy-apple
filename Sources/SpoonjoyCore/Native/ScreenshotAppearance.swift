import Foundation

/// The appearance a Mac screenshot capture asks for. The capture script cannot switch the Mac app the way
/// `simctl ui appearance` switches a simulator, so it passes `SPOONJOY_SCREENSHOT_APPEARANCE` instead.
public enum ScreenshotAppearance: String, Equatable, Sendable {
    case light
    case dark

    public static let environmentKey = "SPOONJOY_SCREENSHOT_APPEARANCE"
    public static let captureModeKey = "SPOONJOY_SCREENSHOT_AUTH"

    /// The requested appearance, honoured only in capture mode so a stray variable cannot restyle the shipping app.
    public static func requested(in environment: [String: String]) -> ScreenshotAppearance? {
        guard isCaptureMode(environment) else {
            return nil
        }
        return ScreenshotAppearance(rawValue: normalized(environment[environmentKey]))
    }

    private static func isCaptureMode(_ environment: [String: String]) -> Bool {
        ["1", "true", "yes"].contains(normalized(environment[captureModeKey]))
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
