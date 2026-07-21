import Foundation
import Testing

@Suite("Native settings auth and APNs surface contract")
struct SettingsAuthSurfaceContractTests {
    @Test("settings and APNs surface use product language and user-safe failure copy")
    func settingsAndAPNsUseProductLanguageAndSafeFailures() throws {
        let failures = sourceContractFailures(
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Views/SettingsView.swift": [
                    "settingsActionFailureBanner",
                    "settingsActionErrorMessage(for:",
                    "settingsActionDiagnosticCode(for:",
                    "Agent access",
                    "Create access key",
                    "Revoke access key",
                    "Access key name",
                    "settingsCreatedCredentialDisclosure"
                ],
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift": [
                    "notificationActionFailureBanner",
                    "notificationActionErrorMessage(for:",
                    "notificationActionDiagnosticCode(for:",
                    "Notification permission could not be checked.",
                    "Device notifications could not be updated."
                ],
                "Apps/Spoonjoy/Shared/Native/NotificationAPNsDeviceBridge.swift": [
                    "deviceTokenTimeoutNanoseconds",
                    "pendingDeviceTokenTimeoutTask",
                    "completePendingDeviceToken(",
                    "NotificationAPNsNativeBridgeError.deviceTokenRequestTimedOut"
                ],
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift": [
                    "case deviceTokenRequestTimedOut"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Views/SettingsView.swift": [
                    "settingsActionError = String(describing: error)",
                    "New token",
                    "API Tokens",
                    "Create Token",
                    "Revoke Token",
                    "Token name"
                ],
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift": [
                    "notificationActionError = String(describing: error)"
                ],
                "scripts/capture-native-screenshots.sh": [
                    "\"API Tokens\""
                ]
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("settings screenshot proof distinguishes profile from APNs notification state")
    func settingsScreenshotProofDistinguishesProfileFromAPNsState() throws {
        let failures = sourceContractFailures(
            requiredTokens: [
                "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift": [
                    "performAccessibilityAudit",
                    "settings.apns.this-device.heading",
                    "settings.apns.push-delivery.heading",
                    "settings.apns.notification-sync.heading",
                    "apnsChromeIntersection",
                    "geometryFindings",
                    "return [\"Spoonjoy\", \"Sign in\"]"
                ],
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift": [
                    "This Device",
                    "Push Delivery",
                    "Notification Sync",
                    "Turn On for This Device",
                    "Open System Settings",
                    "AppleDeveloperProgramBlockerView",
                    "NotificationDiagnosticsDisclosure"
                ],
                "scripts/validate-design-review.rb": [
                    "\"Session\"",
                    "\"Sign In\"",
                    "\"This Device\"",
                    "\"Push Delivery\"",
                    "\"Notification Sync\"",
                    "\"session handoff controls\"",
                    "\"APNs device controls\"",
                    "\"NotificationAPNsSettingsView\"",
                    "settingsSignedOutSurface",
                    "settingsSignedOutHandoffSurface",
                    "settingsAPNsPermissionState",
                    "settingsAPNsRegistrationState"
                ],
                "scripts/capture-native-screenshots.sh": [
                    "settings_capture_variant",
                    "settings-signed-out",
                    "apns-denied",
                    "apns-not-determined",
                    "apns-authorized",
                    "apns-unregistered",
                    "SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE",
                    "SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE",
                    "\"Session\"",
                    "\"Agent Access\"",
                    "\"This Device\"",
                    "\"Push Delivery\"",
                    "\"Notification Sync\""
                ],
                "scripts/capture-native-screenshot-matrix.sh": [
                    "settings-signed-out",
                    "settings-apns-denied",
                    "settings-apns-not-determined",
                    "settings-apns-authorized",
                    "settings-apns-unregistered"
                ],
                "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift": [
                    "SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE",
                    "SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE",
                    "screenshotNotificationAPNsSurfaceData"
                ],
                "Apps/Spoonjoy/Shared/Views/SettingsView.swift": [
                    "case signedOut = \"signed-out\"",
                    "\"Session\", \"Environment\", \"Offline\""
                ]
            ],
            forbiddenTokens: [:]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }
}

private func sourceContractFailures(
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    let root = repoRoot()
    var failures: [String] = []
    let files = Set(requiredTokens.keys).union(forbiddenTokens.keys).sorted()

    for relativePath in files {
        let fileURL = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            failures.append("missing settings/auth surface file: \(relativePath)")
            continue
        }

        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let missingTokens = requiredTokens[relativePath, default: []].filter { !content.contains($0) }
        if !missingTokens.isEmpty {
            failures.append("\(relativePath) missing settings/auth tokens: \(missingTokens.joined(separator: ", "))")
        }

        let forbiddenHits = forbiddenTokens[relativePath, default: []].filter { content.contains($0) }
        if !forbiddenHits.isEmpty {
            failures.append("\(relativePath) contains forbidden settings/auth tokens: \(forbiddenHits.joined(separator: ", "))")
        }
    }

    return failures
}

private func repoRoot() -> URL {
    var current = URL(fileURLWithPath: #filePath)
    while current.path != "/" {
        let package = current.appendingPathComponent("Package.swift")
        let xcodeProject = current.appendingPathComponent("Spoonjoy.xcodeproj")
        if FileManager.default.fileExists(atPath: package.path),
           FileManager.default.fileExists(atPath: xcodeProject.path) {
            return current
        }
        current.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}
