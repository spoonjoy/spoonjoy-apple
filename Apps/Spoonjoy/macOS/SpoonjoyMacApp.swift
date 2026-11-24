import SwiftUI
import AppKit
import Foundation
import SpoonjoyCore

@main
struct SpoonjoyMacApp: App {
    @NSApplicationDelegateAdaptor(SpoonjoyMacAppDelegate.self) private var appDelegate

    init() {
        SpoonjoyFonts.registerBundled()
        SpoonjoyMacLaunchProof.record("app-init")
        // One handler behind Siri, Shortcuts and the shopping list's button (actions/generated/OuroActions.swift).
        if #available(iOS 27.0, macOS 27.0, *) {
            SpoonjoyAddShoppingListItemBinding.bind()
        }
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
            SpoonjoyAddRecipeCommands()
            SpoonjoyGoBackCommands()
            CommandGroup(after: .newItem) {
                Button("New Window") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .spoonjoyOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// ⌘N opens Add a recipe in the focused window. Spoonjoy has no recipe form, so this is how a recipe starts.
private struct SpoonjoyAddRecipeCommands: Commands {
    @FocusedValue(\.spoonjoyAddRecipe) private var addRecipe

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add a Recipe…") {
                addRecipe?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(addRecipe == nil)
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
#if DEBUG
        switch ScreenshotAppearance.requested(in: ProcessInfo.processInfo.environment) {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case nil: break
        }
#endif
        SpoonjoyMacMainWindowCoordinator.shared.scheduleLaunchWindowCheck()
        SpoonjoyDiagnosticsReporter.shared.start()
        // Step timers count down in the app on the Mac; a timer still running from before a relaunch picks up here.
        _ = CookModeSessionCenter.shared
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
    private var screenshotResizeObserver: NSObjectProtocol?

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
                self.applyScreenshotWindowSize()
            }
        }
#if DEBUG
        // SwiftUI can restore the window's saved frame after it first shows, so the capture size is set again once
        // the window has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MainActor.assumeIsolated {
                self.applyScreenshotWindowSize()
            }
        }
#endif
    }

    /// A screenshot capture's window size (`ScreenshotCaptureOptions.windowSize`), set here rather than through System
    /// Events: AppKit holds a window moved or resized from outside to the screen it is on, and a hosted Mac's screen
    /// is smaller than the Mac App Store's 1440 by 900. `setFrame` is not held to the screen, so the window takes the
    /// size asked for, its top-left corner at the top-left of the screen, and any part past the screen's edge is still
    /// in the window's own image, which `screencapture -l` takes.
    private func applyScreenshotWindowSize() {
#if DEBUG
        guard let size = ScreenshotCaptureOptions.windowSize(in: ProcessInfo.processInfo.environment),
              let window = existingVisibleMainWindow() ?? fallbackWindow else {
            return
        }
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let frame = NSRect(x: visible.minX, y: visible.maxY - size.height, width: size.width, height: size.height)
        window.setFrame(frame, display: true)
        if screenshotResizeObserver == nil {
            // Anything that later holds the window to the screen (activation, a display change) is undone.
            screenshotResizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                MainActor.assumeIsolated {
                    guard let window, window.frame.size != frame.size else { return }
                    window.setFrame(frame, display: true)
                }
            }
        }
        SpoonjoyMacLaunchProof.record("screenshot-window-size requested=\(Int(size.width))x\(Int(size.height)) frame=\(Int(window.frame.width))x\(Int(window.frame.height)) screen=\(Int(visible.width))x\(Int(visible.height))")
#endif
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
