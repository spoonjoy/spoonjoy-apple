import Foundation
import SpoonjoyCore
#if os(iOS)
import UIKit
#endif

actor ScreenshotVisualReadiness {
    private static let shared = ScreenshotVisualReadiness()

    private var state = ScreenshotVisualReadinessState()

    static func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) async {
        await shared.beginMedia(token)
    }

    static func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) async {
        await shared.finishMedia(token, succeeded: succeeded)
    }

    static func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) async {
        await shared.removeMedia(token)
    }

    static func beginBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) async {
        await shared.beginBlockingIndicator(token)
    }

    static func endBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) async {
        await shared.endBlockingIndicator(token)
    }

    static func waitForSettled() async -> ScreenshotVisualReadinessSnapshot {
        await shared.waitForSettled()
    }

    private func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        state.beginMedia(token)
    }

    private func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) {
        state.finishMedia(token, succeeded: succeeded)
    }

    private func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) {
        state.removeMedia(token)
    }

    private func beginBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) {
        state.beginBlockingIndicator(token)
    }

    private func endBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) {
        state.endBlockingIndicator(token)
    }

    private func waitForSettled() async -> ScreenshotVisualReadinessSnapshot {
        try? await Task.sleep(nanoseconds: 700_000_000)
        let deadline = Date().addingTimeInterval(8)
        var settledSince: Date?
        var lastSnapshot: ScreenshotVisualReadinessSnapshot?

        while !Task.isCancelled {
            let snapshot = state.snapshot
            if snapshot.isSettled {
                if snapshot != lastSnapshot {
                    settledSince = Date()
                } else if let settledSince, Date().timeIntervalSince(settledSince) >= 0.35 {
                    return snapshot
                }
            } else {
                settledSince = nil
            }

            if Date() >= deadline {
                return snapshot
            }
            lastSnapshot = snapshot
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return state.snapshot
    }
}

struct ScreenshotAccessibilityRuntimeContext {
    let dynamicTypeSize: String
    let reduceMotionEnabled: Bool
}

struct ScreenshotObservedSurfaceState {
    let statusOwner: String
    let connectivity: String
    let queuedMutationCount: Int
    let visibleIndicator: String

    var dictionary: [String: Any] {
        [
            "statusOwner": statusOwner,
            "connectivity": connectivity,
            "queuedMutationCount": queuedMutationCount,
            "visibleIndicator": visibleIndicator
        ]
    }
}

enum ScreenshotAccessibilityProofWriter {
    private static let environmentKey = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"
    private static let expectedRouteEnvironmentKey = "SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"

    @MainActor static func writeIfNeeded(
        route: String,
        source: String,
        runtimeContext: ScreenshotAccessibilityRuntimeContext,
        observedSurfaceVariant: String? = nil,
        observedSurfaceState: ScreenshotObservedSurfaceState? = nil
    ) async {
#if DEBUG
        guard let rawPath = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return
        }
        let visualReadiness = await ScreenshotVisualReadiness.waitForSettled()
        guard !Task.isCancelled else {
            return
        }
        if let expectedRoute = ProcessInfo.processInfo.environment[expectedRouteEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedRoute.isEmpty,
           expectedRoute != route {
            return
        }

        let outputURL = URL(fileURLWithPath: rawPath)
        let payload = basePayload(
            route: route,
            source: source,
            runtimeContext: runtimeContext,
            visualReadiness: visualReadiness,
            observedSurfaceVariant: observedSurfaceVariant,
            observedSurfaceState: observedSurfaceState
        )
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: outputURL, options: [.atomic])
#else
        _ = route
        _ = source
        _ = runtimeContext
        _ = observedSurfaceVariant
        _ = observedSurfaceState
#endif
    }

#if DEBUG
    @MainActor private static func basePayload(
        route: String,
        source: String,
        runtimeContext: ScreenshotAccessibilityRuntimeContext,
        visualReadiness: ScreenshotVisualReadinessSnapshot,
        observedSurfaceVariant: String?,
        observedSurfaceState: ScreenshotObservedSurfaceState?
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "platform": platform,
            "route": route,
            "source": source,
            "launchEnvironmentProof": launchEnvironmentProof,
            "screenshotStateSnapshotProof": screenshotStateSnapshotProof,
            "observedDynamicTypeSize": runtimeContext.dynamicTypeSize,
            "observedReduceMotion": runtimeContext.reduceMotionEnabled,
            "visualReadiness": [
                "expectedMediaCount": visualReadiness.expectedMediaCount,
                "loadedMediaCount": visualReadiness.loadedMediaCount,
                "pendingMediaCount": visualReadiness.pendingMediaCount,
                "failedMediaCount": visualReadiness.failedMediaCount,
                "blockingIndicatorCount": visualReadiness.blockingIndicatorCount,
                "isSettled": visualReadiness.isSettled
            ],
            "emittedBy": "SpoonjoyApp",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let observedSurfaceVariant {
            payload["observedSurfaceVariant"] = observedSurfaceVariant
        }
        if let observedSurfaceState {
            payload["observedSurfaceState"] = observedSurfaceState.dictionary
        }
        return payload
    }

    private static var screenshotStateSnapshotProof: [String: Any] {
        let environment = ProcessInfo.processInfo.environment
        let rawDirectory = environment["SPOONJOY_SCREENSHOT_STATE_DIRECTORY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let usesInlineFixtures = ["1", "true", "yes"].contains(
            environment["SPOONJOY_SCREENSHOT_INLINE_FIXTURES"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
        )
        let configuredDirectory: URL? = if usesInlineFixtures {
            NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
        } else if rawDirectory.isEmpty {
            nil
        } else {
            URL(fileURLWithPath: rawDirectory, isDirectory: true).standardizedFileURL
        }
        let snapshotURL = configuredDirectory?
            .appendingPathComponent(NativeAppStateLocation.fileName) ?? NativeAppStateLocation.defaultFileURL()
        let syncSnapshotURL = snapshotURL.deletingLastPathComponent()
            .appendingPathComponent("native-sync-store.json")
        var proof: [String: Any] = [
            "stateDirectoryConfigured": !rawDirectory.isEmpty,
            "stateDirectoryResolved": true,
            "appSnapshotPresent": false,
            "appSnapshotJSONReadable": false,
            "appSnapshotCaptureDraftPresent": false,
            "appSnapshotShoppingListPresent": false,
            "appSnapshotPendingCaptureImportPresent": false,
            "appSnapshotProviderBlockerPresent": false,
            "syncSnapshotPresent": false,
            "syncSnapshotJSONReadable": false,
            "syncSnapshotQueueCount": 0,
            "syncSnapshotQueuedShoppingWorkPresent": false
        ]

        if FileManager.default.fileExists(atPath: snapshotURL.path) {
            proof["appSnapshotPresent"] = true
            if let data = try? Data(contentsOf: snapshotURL),
               let snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let providerBlocker = (snapshot["captureImportProviderBlocker"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                proof["appSnapshotJSONReadable"] = true
                proof["appSnapshotCaptureDraftPresent"] = snapshot["captureDraft"] is [String: Any]
                proof["appSnapshotShoppingListPresent"] = snapshot["shoppingList"] is [String: Any]
                proof["appSnapshotPendingCaptureImportPresent"] = snapshot["pendingCaptureImport"] is [String: Any]
                proof["appSnapshotProviderBlockerPresent"] = !providerBlocker.isEmpty
            }
        }

        if FileManager.default.fileExists(atPath: syncSnapshotURL.path) {
            proof["syncSnapshotPresent"] = true
            if let data = try? Data(contentsOf: syncSnapshotURL),
               let snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let queue = snapshot["queue"] as? [String: Any],
               let mutations = queue["mutations"] as? [[String: Any]] {
                proof["syncSnapshotJSONReadable"] = true
                proof["syncSnapshotQueueCount"] = mutations.count
                proof["syncSnapshotQueuedShoppingWorkPresent"] = mutations.contains { mutation in
                    guard let kind = mutation["kind"] as? [String: Any],
                          let type = kind["type"] as? String else {
                        return false
                    }
                    return type.hasPrefix("shopping.")
                }
            }
        }

        return proof
    }

    @MainActor private static var platform: String {
#if os(macOS)
        "macos"
#elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "ios"
#else
        "ios"
#endif
    }

    private static var launchEnvironmentProof: [String: String] {
        let environment = ProcessInfo.processInfo.environment
        return [
            "screenshotAuth": environment["SPOONJOY_SCREENSHOT_AUTH"] ?? "",
            "screenshotRestoreCacheOnly": environment["SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY"] ?? "",
            "screenshotAccountID": environment["SPOONJOY_SCREENSHOT_ACCOUNT_ID"] ?? "",
            "screenshotRecipeCoversFixture": environment["SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE"] ?? "",
            "screenshotAPNsPermissionState": environment["SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE"] ?? "",
            "screenshotAPNsRegistrationState": environment["SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE"] ?? "",
            "apiBaseURL": environment["SPOONJOY_API_BASE_URL"] ?? ""
        ]
    }
#endif
}
