import SwiftUI
import AppKit
import Foundation

@main
struct SpoonjoyMacApp: App {
    @NSApplicationDelegateAdaptor(SpoonjoyMacAppDelegate.self) private var appDelegate

    init() {
        SpoonjoyMacLaunchProof.record("app-init")
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                SpoonjoyMacMainWindowCoordinator.shared.scheduleLaunchWindowCheck()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SpoonjoyRootView()
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1040, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
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
            showMainWindow()
        }
        return true
    }

    func showMainWindow() {
        SpoonjoyMacMainWindowCoordinator.shared.showMainWindow()
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
            SpoonjoyMacLaunchProof.record("schedule-launch-window-check-skip")
            return
        }
        didScheduleLaunchCheck = true

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                SpoonjoyMacLaunchProof.record("launch-window-check-immediate")
                self.showMainWindowIfNeeded()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MainActor.assumeIsolated {
                SpoonjoyMacLaunchProof.record("launch-window-check-delayed")
                self.showMainWindowIfNeeded()
            }
        }
    }

    func showMainWindow() {
        SpoonjoyMacLaunchProof.record("show-main-window-start windows=\(NSApp.windows.count)")
        if let existingWindow = existingVisibleMainWindow() {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            SpoonjoyMacLaunchProof.record("show-main-window-existing-app-window visible=\(existingWindow.isVisible) windows=\(NSApp.windows.count)")
            return
        }

        if let fallbackWindow {
            fallbackWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            SpoonjoyMacLaunchProof.record("show-main-window-existing visible=\(fallbackWindow.isVisible) windows=\(NSApp.windows.count)")
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
        SpoonjoyMacLaunchProof.record("show-main-window-created visible=\(window.isVisible) windows=\(NSApp.windows.count)")
    }

    private func showMainWindowIfNeeded() {
        let hasVisibleWindow = existingVisibleMainWindow() != nil || fallbackWindow?.isVisible == true
        SpoonjoyMacLaunchProof.record("show-main-window-if-needed visibleWindow=\(hasVisibleWindow) windows=\(NSApp.windows.count)")
        if !hasVisibleWindow {
            showMainWindow()
        }
    }

    private func existingVisibleMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            (fallbackWindow.map { window !== $0 } ?? true) &&
            window.isVisible &&
            window.canBecomeMain &&
            !window.isMiniaturized
        }
    }
}
