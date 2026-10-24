import SpoonjoyCore
import SwiftUI
import UIKit

@main
struct SpoonjoyiOSApp: App {
    @UIApplicationDelegateAdaptor(SpoonjoyiOSAppDelegate.self) private var appDelegate
    /// One store for every window, so two windows side by side show the same kitchen and sync it once.
    @StateObject private var liveStore = NativeLiveAppStore(dependencies: SpoonjoyRootView.defaultDependencies())

    init() {
        #if DEBUG
        if NativeJourneyAnimations.isRequested(arguments: ProcessInfo.processInfo.arguments) {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        // Each window carries the page it was opened for; the system keeps that value with the window, and the root
        // view keeps where the window went from there.
        WindowGroup(for: WindowRoute.self) { $windowRoute in
            SpoonjoyRootView(liveStore: liveStore, windowValue: windowRoute)
                .journeyQuietMode()
        }
    }
}

@MainActor
final class SpoonjoyiOSAppDelegate: NSObject, UIApplicationDelegate {
    private var cookTimerAlarmHost: AnyObject?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if #available(iOS 26.0, *) {
            cookTimerAlarmHost = CookTimerAlarmHost()
        }
        return true
    }

    /// A window the chef closed will not come back, so its page leaves the book.
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        let identifiers = sceneSessions.map(\.persistentIdentifier)
        SceneRouteBookLocation.store.update { book in
            book.forget(scenes: identifiers)
        }
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
