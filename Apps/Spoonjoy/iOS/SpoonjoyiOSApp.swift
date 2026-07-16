import SwiftUI
import UIKit

@main
struct SpoonjoyiOSApp: App {
    @UIApplicationDelegateAdaptor(SpoonjoyiOSAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SpoonjoyRootView()
        }
    }
}

@MainActor
final class SpoonjoyiOSAppDelegate: NSObject, UIApplicationDelegate {
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
