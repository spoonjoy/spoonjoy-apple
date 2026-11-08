#if DEBUG
import SpoonjoyCore
import UIKit

/// Switches every window between light and dark when a journey posts a `NativeJourneyAppearance` notification, so a
/// parity shot's scheme does not depend on the simulator redrawing after `XCUIDevice.shared.appearance` changes.
/// Windows that appear after the notification (a new scene, the Duo's inner display, a sheet) take the same style.
/// DEBUG builds launched with the journeys' `-UITestDisableAnimations` argument only.
@MainActor
enum JourneyAppearanceOverride {
    private static let relay = JourneyAppearanceRelay<UIWindow>(
        windows: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
        },
        style: { window, appearance in
            window.overrideUserInterfaceStyle = switch appearance {
            case .light: .light
            case .dark: .dark
            case .system: .unspecified
            }
        }
    )

    static func install(arguments: [String]) {
        guard NativeJourneyAnimations.isRequested(arguments: arguments) else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for appearance in NativeJourneyAppearance.allCases {
            CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                guard let raw = name?.rawValue as String? else { return }
                Task { @MainActor in
                    JourneyAppearanceOverride.relay.receive(notificationName: raw)
                }
            }, appearance.notificationName as CFString, nil, .deliverImmediately)
        }
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? UIWindow else { return }
            MainActor.assumeIsolated {
                relay.windowAppeared(window)
            }
        }
    }
}
#endif
