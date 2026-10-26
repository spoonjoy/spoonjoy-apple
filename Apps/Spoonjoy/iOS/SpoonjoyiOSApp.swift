import SpoonjoyCore
import SwiftUI
import UIKit

@main
struct SpoonjoyiOSApp: App {
    @UIApplicationDelegateAdaptor(SpoonjoyiOSAppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        if NativeJourneyAnimations.isRequested(arguments: ProcessInfo.processInfo.arguments) {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SpoonjoyRootView()
                .journeyQuietMode()
        }
    }
}

@MainActor
final class SpoonjoyiOSAppDelegate: NSObject, UIApplicationDelegate {
    private var cookTimerAlarmHost: AnyObject?
    private var cookSessionActivity: CookSessionLiveActivityController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if #available(iOS 26.0, *) {
            cookTimerAlarmHost = CookTimerAlarmHost()
        }
        Task6Diag.logSavedState() // TASK6-DIAG
        cookSessionActivity = Task6Diag.timed("controller init") { CookSessionLiveActivityController() } // TASK6-DIAG
        return true
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
