#if DEBUG
import SpoonjoyCore
import UIKit

/// Switches every window between light and dark when a journey posts a `NativeJourneyAppearance` notification, so a
/// parity shot's scheme does not depend on the simulator redrawing after `XCUIDevice.shared.appearance` changes.
/// DEBUG builds launched with the journeys' `-UITestDisableAnimations` argument only.
enum JourneyAppearanceOverride {
    static func install(arguments: [String]) {
        guard NativeJourneyAnimations.isRequested(arguments: arguments) else { return }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for appearance in NativeJourneyAppearance.allCases {
            CFNotificationCenterAddObserver(center, nil, { _, _, name, _, _ in
                guard let raw = name?.rawValue as String?, let appearance = NativeJourneyAppearance(notificationName: raw) else {
                    return
                }
                Task { @MainActor in
                    JourneyAppearanceOverride.apply(appearance)
                }
            }, appearance.notificationName as CFString, nil, .deliverImmediately)
        }
    }

    @MainActor
    static func apply(_ appearance: NativeJourneyAppearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .light: .light
        case .dark: .dark
        case .system: .unspecified
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
#endif
