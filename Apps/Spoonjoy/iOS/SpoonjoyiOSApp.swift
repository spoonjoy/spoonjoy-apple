import SpoonjoyCore
import SwiftUI
import UIKit

@main
struct SpoonjoyiOSApp: App {
    @UIApplicationDelegateAdaptor(SpoonjoyiOSAppDelegate.self) private var appDelegate
    /// One store and one Cooking now list for every window, so two windows side by side show the same kitchen and
    /// sync it once.
    @StateObject private var liveStore = NativeLiveAppStore(dependencies: SpoonjoyRootView.defaultDependencies())
    @State private var cookingNow = CookingNowCenter()

    init() {
        SpoonjoyFonts.registerBundled()
        SpoonjoyFonts.styleNavigationBarLargeTitles()
        // One handler behind Siri, Shortcuts and the shopping list's button (actions/generated/OuroActions.swift).
        if #available(iOS 27.0, macOS 27.0, *) {
            SpoonjoyAddShoppingListItemBinding.bind()
        }
        #if DEBUG
        if NativeJourneyAnimations.isRequested(arguments: ProcessInfo.processInfo.arguments) {
            UIView.setAnimationsEnabled(false)
        }
        JourneyAppearanceOverride.install(arguments: ProcessInfo.processInfo.arguments)
        #endif
    }

    var body: some Scene {
        // Each window carries the page it was opened for; the system keeps that value with the window, and the root
        // view keeps where the window went from there. Opening a recipe that already has a window brings that window
        // forward, so a recipe is never open twice.
        WindowGroup(for: WindowRoute.self) { $windowRoute in
            SpoonjoyRootView(liveStore: liveStore, cookingNow: cookingNow, windowValue: windowRoute)
                .debugReduceMotion()
                .journeyQuietMode()
        }
        .commands {
            SpoonjoyGoBackCommands()
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
        cookSessionActivity = CookSessionLiveActivityController()
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
