import SwiftUI
import AppKit
import Foundation

@main
struct SpoonjoyMacApp: App {
    @NSApplicationDelegateAdaptor(SpoonjoyMacAppDelegate.self) private var appDelegate

    init() {
        SpoonjoyMacLaunchProof.record("app-init")
    }

    var body: some Scene {
        let _ = SpoonjoyMacLaunchProof.record("scene-body-evaluated")
        Window("Spoonjoy", id: "main") {
            SpoonjoyRootView()
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1040, height: 760)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private enum SpoonjoyMacLaunchProof {
    static func record(_ event: String) {
        guard let rawPath = ProcessInfo.processInfo.environment["SPOONJOY_MAC_LAUNCH_PROOF_PATH"],
              !rawPath.isEmpty else {
            return
        }

        let url = URL(fileURLWithPath: rawPath)
        let line = "\(Date().timeIntervalSince1970) \(event)\n"
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer {
                try? handle.close()
            }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

@MainActor
final class SpoonjoyMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SpoonjoyMacLaunchProof.record("delegate-did-finish-launching")
        SpoonjoyMacMainWindowCoordinator.shared.scheduleLaunchWindowCheck()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            SpoonjoyMacMainWindowCoordinator.shared.showMainWindow()
        }
        return true
    }

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

@MainActor
final class SpoonjoyMacMainWindowCoordinator {
    static let shared = SpoonjoyMacMainWindowCoordinator()

    private var fallbackWindow: NSWindow?
    private var didScheduleLaunchCheck = false

    private init() {}

    func scheduleLaunchWindowCheck() {
        SpoonjoyMacLaunchProof.record("schedule-launch-window-check")
        guard !didScheduleLaunchCheck else {
            return
        }
        didScheduleLaunchCheck = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MainActor.assumeIsolated {
                self.showMainWindowIfNeeded()
            }
        }
    }

    func showMainWindow() {
        if let existingWindow = existingMainWindow() {
            present(existingWindow, event: "show-main-window-existing")
            return
        }

        if let fallbackWindow {
            present(fallbackWindow, event: "show-main-window-fallback")
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Spoonjoy"
        window.minSize = NSSize(width: 900, height: 620)
        window.contentViewController = NSHostingController(rootView: SpoonjoyRootView())
        window.isReleasedWhenClosed = false
        window.center()
        fallbackWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        SpoonjoyMacLaunchProof.record("show-main-window-created")
    }

    private func showMainWindowIfNeeded() {
        guard existingMainWindow()?.isVisible != true,
              fallbackWindow?.isVisible != true else {
            return
        }
        showMainWindow()
    }

    private func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            (fallbackWindow.map { window !== $0 } ?? true) &&
            window.canBecomeMain
        }
    }

    private func present(_ window: NSWindow, event: String) {
        let windowCountBeforePresentation = restorableMainWindowCount()
        let wasMiniaturized = window.isMiniaturized
        if wasMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let outcome = wasMiniaturized ? "\(event)-deminiaturized" : event
        SpoonjoyMacLaunchProof.record(
            "\(outcome) cardinality-before=\(windowCountBeforePresentation) " +
            "cardinality-after=\(restorableMainWindowCount())"
        )
    }

    private func restorableMainWindowCount() -> Int {
        NSApp.windows.filter(\.canBecomeMain).count
    }
}
