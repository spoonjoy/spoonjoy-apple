import SwiftUI
import AppKit

@main
struct SpoonjoyMacApp: App {
    @NSApplicationDelegateAdaptor(SpoonjoyMacAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SpoonjoyRootView()
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 1040, height: 760)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class SpoonjoyMacAppDelegate: NSObject, NSApplicationDelegate {
    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationAPNsDeviceBridge.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationAPNsDeviceBridge.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
}
