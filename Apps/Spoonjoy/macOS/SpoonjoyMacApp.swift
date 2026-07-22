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
