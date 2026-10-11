import Foundation

/// A launch argument that journeys pass so XCUITest never waits on animation. A running animation or an
/// indeterminate spinner keeps the app from going idle, and each action then waits 60 seconds for an
/// "App animations complete notification" before it carries on.
///
/// The app reads it only in DEBUG builds, so release builds always animate.
public enum NativeJourneyAnimations {
    public static let launchArgument = "-UITestDisableAnimations"

    public static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }
}
