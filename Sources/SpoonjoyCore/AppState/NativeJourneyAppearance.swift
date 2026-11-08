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

/// Holds the appearance a journey last asked for and gives it to every window: the ones open when the notification
/// arrives and any that appear later, such as a new scene on the iPad or the Duo's inner display, or a sheet's window.
/// The app supplies how to list its windows and how to style one; this type stays free of UIKit so it can be tested.
@MainActor
public final class JourneyAppearanceRelay<Window: AnyObject> {
    public private(set) var current: NativeJourneyAppearance?
    private let windows: () -> [Window]
    private let style: (Window, NativeJourneyAppearance) -> Void

    public init(windows: @escaping () -> [Window], style: @escaping (Window, NativeJourneyAppearance) -> Void) {
        self.windows = windows
        self.style = style
    }

    /// Applies the appearance a notification names to every open window. Returns false for any other name.
    @discardableResult
    public func receive(notificationName: String) -> Bool {
        guard let appearance = NativeJourneyAppearance(notificationName: notificationName) else { return false }
        current = appearance
        for window in windows() {
            style(window, appearance)
        }
        return true
    }

    /// Gives a window that just appeared the appearance last asked for, if a journey has asked for one.
    public func windowAppeared(_ window: Window) {
        guard let current else { return }
        style(window, current)
    }
}
