import Foundation
import SpoonjoyCore
import UserNotifications

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class NotificationAPNsDeviceBridge {
    static let shared = NotificationAPNsDeviceBridge()

    private static let deviceTokenTimeoutNanoseconds: UInt64 = 15_000_000_000
    private let deviceIDKey = "app.spoonjoy.apns.deviceID"
    private var pendingDeviceTokenContinuation: CheckedContinuation<String, Error>?
    private var pendingDeviceTokenTimeoutTask: Task<Void, Never>?

    func requestPermission() async throws -> APNsPermissionState {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        let checkedAt = Date()
        return granted ? .authorized(lastCheckedAt: checkedAt) : .denied(lastCheckedAt: checkedAt)
    }

    func registrationAction(clientMutationID: String) async throws -> NotificationAPNsAction {
        let token = try await deviceToken()
        return .registerDevice(
            deviceID: persistentDeviceID(),
            platform: Self.platform,
            environment: NativeAPNSRuntimeDefaults.currentEnvironment,
            token: token,
            deviceName: Self.deviceName,
            appVersion: Self.appVersion,
            clientMutationID: clientMutationID
        )
    }

    func openNotificationSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
#elseif os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
#endif
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        completePendingDeviceToken(.success(Self.hexString(from: deviceToken)))
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        completePendingDeviceToken(.failure(error))
    }

    private func deviceToken() async throws -> String {
        guard pendingDeviceTokenContinuation == nil else {
            throw NotificationAPNsNativeBridgeError.deviceTokenRequestAlreadyPending
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingDeviceTokenContinuation = continuation
            pendingDeviceTokenTimeoutTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: Self.deviceTokenTimeoutNanoseconds)
                } catch {
                    return
                }
                completePendingDeviceToken(.failure(NotificationAPNsNativeBridgeError.deviceTokenRequestTimedOut))
            }
#if os(iOS)
            UIApplication.shared.registerForRemoteNotifications()
#elseif os(macOS)
            NSApplication.shared.registerForRemoteNotifications(matching: [.alert, .badge, .sound])
#else
            completePendingDeviceToken(.failure(NotificationAPNsNativeBridgeError.deviceTokenUnavailable))
#endif
        }
    }

    private func completePendingDeviceToken(_ result: Result<String, Error>) {
        guard let continuation = pendingDeviceTokenContinuation else {
            return
        }
        pendingDeviceTokenContinuation = nil
        pendingDeviceTokenTimeoutTask?.cancel()
        pendingDeviceTokenTimeoutTask = nil
        switch result {
        case .success(let token):
            continuation.resume(returning: token)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func persistentDeviceID() -> String {
        if let storedDeviceID = UserDefaults.standard.string(forKey: deviceIDKey),
           !storedDeviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storedDeviceID
        }

        let generated = "\(Self.platform.rawValue)-\(UUID().uuidString)"
        UserDefaults.standard.set(generated, forKey: deviceIDKey)
        return generated
    }

    private static var platform: NativeAPNSPlatform {
        NativeAPNSRuntimeDefaults.currentPlatform
    }

    private static var deviceName: String {
#if os(iOS)
        UIDevice.current.name
#elseif os(macOS)
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
#else
        "Spoonjoy device"
#endif
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        let joinedVersion = [version, build]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? value : nil
            }
            .joined(separator: " ")
        return joinedVersion.isEmpty ? "0.0.0" : joinedVersion
    }

    private static func hexString(from data: Data) -> String {
        data.map { String(format: "%02.2hhx", $0) }.joined()
    }
}
