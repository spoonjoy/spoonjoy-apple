import Foundation

/// Lets a journey switch the app between light and dark from the test runner.
///
/// `XCUIDevice.shared.appearance` changes the simulator's setting. On the CI simulators it can return without the app
/// redrawing: every native `-dark` parity shot of Journeys run 42481642383 was byte-identical to its `-light` shot.
/// So the runner also posts one of these Darwin notifications, and the app, in DEBUG builds launched with the
/// journeys' `-UITestDisableAnimations` argument, overrides every window's interface style to match.
public enum NativeJourneyAppearance: String, CaseIterable, Sendable {
    case light
    case dark
    /// Back to the simulator's own setting.
    case system

    public var notificationName: String {
        "app.spoonjoy.journey.appearance.\(rawValue)"
    }

    public init?(notificationName: String) {
        guard let match = Self.allCases.first(where: { $0.notificationName == notificationName }) else { return nil }
        self = match
    }
}
