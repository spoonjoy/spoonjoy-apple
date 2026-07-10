import SwiftUI
import UIKit

@main
struct SpoonjoyiOSApp: App {
    @UIApplicationDelegateAdaptor(SpoonjoyiOSAppDelegate.self) private var appDelegate

    init() {
        SpoonjoyiOSAppDelegate.configureChromeAppearance()
    }

    var body: some Scene {
        WindowGroup {
            SpoonjoyRootView()
        }
    }
}

@MainActor
final class SpoonjoyiOSAppDelegate: NSObject, UIApplicationDelegate {
    static func configureChromeAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SpoonjoyUIColor.bone
        appearance.shadowColor = SpoonjoyUIColor.line

        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationAPNsDeviceBridge.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationAPNsDeviceBridge.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
}

private enum SpoonjoyUIColor {
    static let bone = UIColor(red: 251.0 / 255.0, green: 250.0 / 255.0, blue: 244.0 / 255.0, alpha: 1)
    static let line = UIColor(red: 40.0 / 255.0, green: 35.0 / 255.0, blue: 29.0 / 255.0, alpha: 0.18)
}
