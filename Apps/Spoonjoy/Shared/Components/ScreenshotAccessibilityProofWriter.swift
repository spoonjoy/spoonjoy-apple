import CryptoKit
import Foundation
import SpoonjoyCore
#if os(iOS)
import UIKit
#endif

actor ScreenshotVisualReadiness {
    private static let shared = ScreenshotVisualReadiness()

    private var state = ScreenshotVisualReadinessState()

    static func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) async {
        await handleTransition(await shared.beginMedia(token))
    }

    static func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) async {
        await handleTransition(await shared.finishMedia(token, succeeded: succeeded))
    }

    static func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) async {
        await handleTransition(await shared.removeMedia(token))
    }

    static func beginBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) async {
        await handleTransition(await shared.beginBlockingIndicator(token))
    }

    static func endBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) async {
        await handleTransition(await shared.endBlockingIndicator(token))
    }

    static func waitForSettled() async -> ScreenshotVisualReadinessSnapshot {
        await shared.waitForSettled()
    }

    static func currentSnapshot() async -> ScreenshotVisualReadinessSnapshot {
        await shared.state.snapshot
    }

    static func observeProofIdentity(_ identity: ScreenshotVisualReadinessProofIdentity) async -> Int? {
        await shared.observeProofIdentity(identity)
    }

    private static func handleTransition(_ generation: Int?) async {
        guard let generation else { return }
        await ScreenshotAccessibilityProofHandshake.revoke(before: generation)
        await ScreenshotAccessibilityProofWriter.visualReadinessDidTransition()
    }

    private func beginMedia(_ token: ScreenshotVisualReadinessMediaToken) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.beginMedia(token)
        return transitionedGeneration(after: previousGeneration)
    }

    private func observeProofIdentity(_ identity: ScreenshotVisualReadinessProofIdentity) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.observeProofIdentity(identity)
        return transitionedGeneration(after: previousGeneration)
    }

    private func finishMedia(_ token: ScreenshotVisualReadinessMediaToken, succeeded: Bool) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.finishMedia(token, succeeded: succeeded)
        return transitionedGeneration(after: previousGeneration)
    }

    private func removeMedia(_ token: ScreenshotVisualReadinessMediaToken) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.removeMedia(token)
        return transitionedGeneration(after: previousGeneration)
    }

    private func beginBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.beginBlockingIndicator(token)
        return transitionedGeneration(after: previousGeneration)
    }

    private func endBlockingIndicator(_ token: ScreenshotVisualReadinessBlockingToken) -> Int? {
        let previousGeneration = state.snapshot.generation
        state.endBlockingIndicator(token)
        return transitionedGeneration(after: previousGeneration)
    }

    private func transitionedGeneration(after previousGeneration: Int) -> Int? {
        let generation = state.snapshot.generation
        return generation == previousGeneration ? nil : generation
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

    var proofIdentity: ScreenshotVisualReadinessObservedSurfaceState {
        ScreenshotVisualReadinessObservedSurfaceState(
            statusOwner: statusOwner,
            connectivity: connectivity,
            queuedMutationCount: queuedMutationCount,
            visibleIndicator: visibleIndicator
        )
    }
}

struct ScreenshotAccessibilityProofReceipt: Equatable, Sendable {
    let captureRunNonce: String
    let route: String
    let source: String
    let applicationProcessIdentifier: Int32
    let readinessGeneration: Int
    let proofIdentity: ScreenshotVisualReadinessProofIdentity
    let proofFileName: String
    let proofSHA256: String

    var markerIdentifier: String {
        "screenshot.readiness.\(captureRunNonce)"
    }

    var markerLabel: String {
        [
            "Screenshot readiness",
            captureRunNonce,
            route,
            source,
            String(applicationProcessIdentifier),
            String(readinessGeneration),
            proofFileName,
            proofSHA256
        ]
            .joined(separator: "|")
    }
}

@MainActor
enum ScreenshotAccessibilityProofHandshake {
    nonisolated static let notification = Notification.Name("app.spoonjoy.screenshot-proof-ready")
    private(set) static var latestReceipt: ScreenshotAccessibilityProofReceipt?

    static func existingReceipt(
        captureRunNonce: String,
        route: String,
        source: String,
        readinessGeneration: Int,
        proofIdentity: ScreenshotVisualReadinessProofIdentity
    ) -> ScreenshotAccessibilityProofReceipt? {
        guard latestReceipt?.captureRunNonce == captureRunNonce,
              latestReceipt?.route == route,
              latestReceipt?.source == source,
              latestReceipt?.readinessGeneration == readinessGeneration,
              latestReceipt?.proofIdentity == proofIdentity else {
            return nil
        }
        return latestReceipt
    }

    static func publish(_ receipt: ScreenshotAccessibilityProofReceipt) {
        latestReceipt = receipt
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func revoke(before generation: Int) {
        guard let receipt = latestReceipt,
              receipt.readinessGeneration < generation else {
            return
        }
        latestReceipt = nil
        NotificationCenter.default.post(name: notification, object: nil)
    }
}

enum ScreenshotAccessibilityProofWriter {
    private static let environmentKey = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"
    private static let expectedRouteEnvironmentKey = "SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"
    private static let captureRunNonceEnvironmentKey = "SPOONJOY_SCREENSHOT_RUN_NONCE"

#if DEBUG
    private enum ProofArchiveError: Error {
        case invalidPayload
        case mismatchedArchive
    }

    private struct Request {
        let configuredPath: String
        let proofIdentity: ScreenshotVisualReadinessProofIdentity
    }

    @MainActor private static var activeRequest: Request?
    @MainActor private static var reattestationTask: Task<Void, Never>?
#endif

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
        guard let captureRunNonce = ProcessInfo.processInfo.environment[captureRunNonceEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              UUID(uuidString: captureRunNonce) != nil else {
            return
        }
        if let expectedRoute = ProcessInfo.processInfo.environment[expectedRouteEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedRoute.isEmpty,
           expectedRoute != route {
            return
        }
        let proofIdentity = ScreenshotVisualReadinessProofIdentity(
            captureRunNonce: captureRunNonce,
            route: route,
            source: source,
            observedDynamicTypeSize: observedDynamicTypeSize(fallback: runtimeContext.dynamicTypeSize),
            observedReduceMotion: runtimeContext.reduceMotionEnabled,
            observedSurfaceVariant: observedSurfaceVariant,
            observedSurfaceState: observedSurfaceState?.proofIdentity
        )
        let request = Request(configuredPath: rawPath, proofIdentity: proofIdentity)
        activeRequest = request
        if let generation = await ScreenshotVisualReadiness.observeProofIdentity(request.proofIdentity) {
            ScreenshotAccessibilityProofHandshake.revoke(before: generation)
        }
        await issueProof(for: request)
#else
        _ = route
        _ = source
        _ = runtimeContext
        _ = observedSurfaceVariant
        _ = observedSurfaceState
#endif
    }

    @MainActor static func visualReadinessDidTransition() {
#if DEBUG
        guard let activeRequest else { return }
        reattestationTask?.cancel()
        reattestationTask = Task { @MainActor in
            await issueProof(for: activeRequest)
        }
#endif
    }

#if DEBUG
    @MainActor private static func issueProof(for request: Request) async {
        let visualReadiness = await ScreenshotVisualReadiness.waitForSettled()
        guard !Task.isCancelled,
              visualReadiness.isSettled,
              visualReadiness.proofIdentity == request.proofIdentity else {
            return
        }
        if ScreenshotAccessibilityProofHandshake.existingReceipt(
            captureRunNonce: request.proofIdentity.captureRunNonce,
            route: request.proofIdentity.route,
            source: request.proofIdentity.source,
            readinessGeneration: visualReadiness.generation,
            proofIdentity: request.proofIdentity
        ) != nil {
            return
        }
        let outputURL = screenshotProofOutputURL(
            configuredPath: request.configuredPath,
            environment: ProcessInfo.processInfo.environment
        )
        let generationOutputURL = proofArchiveURL(
            for: outputURL,
            generation: visualReadiness.generation
        )
        let payload = basePayload(
            proofIdentity: request.proofIdentity,
            visualReadiness: visualReadiness
        )
        let data: Data
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            data = try canonicalProofData(
                payload: payload,
                generationOutputURL: generationOutputURL
            )
            try data.write(to: outputURL, options: [.atomic])
        } catch {
            return
        }
        let currentReadiness = await ScreenshotVisualReadiness.currentSnapshot()
        guard !Task.isCancelled,
              currentReadiness.isSettled,
              currentReadiness.generation == visualReadiness.generation,
              currentReadiness.proofIdentity == request.proofIdentity else {
            return
        }
        let proofSHA256 = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        ScreenshotAccessibilityProofHandshake.publish(ScreenshotAccessibilityProofReceipt(
            captureRunNonce: request.proofIdentity.captureRunNonce,
            route: request.proofIdentity.route,
            source: request.proofIdentity.source,
            applicationProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            readinessGeneration: visualReadiness.generation,
            proofIdentity: request.proofIdentity,
            proofFileName: generationOutputURL.lastPathComponent,
            proofSHA256: proofSHA256
        ))
    }

    private static func canonicalProofData(
        payload: [String: Any],
        generationOutputURL: URL
    ) throws -> Data {
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw ProofArchiveError.invalidPayload
        }
        if FileManager.default.fileExists(atPath: generationOutputURL.path) {
            let archivedData = try Data(contentsOf: generationOutputURL)
            guard proofPayloadsMatchIgnoringWrittenAt(
                archivedData: archivedData,
                expectedPayload: payload
            ) else {
                throw ProofArchiveError.mismatchedArchive
            }
            return archivedData
        }

        var timestampedPayload = payload
        timestampedPayload["writtenAt"] = ISO8601DateFormatter().string(from: Date())
        guard let data = try? JSONSerialization.data(
            withJSONObject: timestampedPayload,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            throw ProofArchiveError.invalidPayload
        }
        try data.write(to: generationOutputURL, options: [.atomic])
        return data
    }

    private static func proofPayloadsMatchIgnoringWrittenAt(
        archivedData: Data,
        expectedPayload: [String: Any]
    ) -> Bool {
        guard var archivedPayload = try? JSONSerialization.jsonObject(with: archivedData) as? [String: Any],
              let writtenAt = archivedPayload.removeValue(forKey: "writtenAt") as? String,
              ISO8601DateFormatter().date(from: writtenAt) != nil else {
            return false
        }
        return NSDictionary(dictionary: archivedPayload).isEqual(to: expectedPayload)
    }

    private static func proofArchiveURL(for outputURL: URL, generation: Int) -> URL {
        outputURL.deletingPathExtension()
            .appendingPathExtension("generation-\(generation)")
            .appendingPathExtension(outputURL.pathExtension.isEmpty ? "json" : outputURL.pathExtension)
    }

    private static func screenshotProofOutputURL(
        configuredPath: String,
        environment: [String: String]
    ) -> URL {
        let usesInlineFixtures = ["1", "true", "yes"].contains(
            environment["SPOONJOY_SCREENSHOT_INLINE_FIXTURES"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
        )
        guard usesInlineFixtures else {
            return URL(fileURLWithPath: configuredPath)
        }
        return NativeAppStateLocation.defaultFileURL()
            .deletingLastPathComponent()
            .appendingPathComponent(URL(fileURLWithPath: configuredPath).lastPathComponent)
    }

    @MainActor private static func basePayload(
        proofIdentity: ScreenshotVisualReadinessProofIdentity,
        visualReadiness: ScreenshotVisualReadinessSnapshot
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "platform": platform,
            "route": proofIdentity.route,
            "source": proofIdentity.source,
            "captureRunNonce": proofIdentity.captureRunNonce,
            "readinessGeneration": visualReadiness.generation,
            "launchEnvironmentProof": launchEnvironmentProof,
            "screenshotStateSnapshotProof": screenshotStateSnapshotProof,
            "observedDynamicTypeSize": proofIdentity.observedDynamicTypeSize,
            "observedReduceMotion": proofIdentity.observedReduceMotion,
            "visualReadiness": [
                "generation": visualReadiness.generation,
                "expectedMediaCount": visualReadiness.expectedMediaCount,
                "loadedMediaCount": visualReadiness.loadedMediaCount,
                "pendingMediaCount": visualReadiness.pendingMediaCount,
                "failedMediaCount": visualReadiness.failedMediaCount,
                "blockingIndicatorCount": visualReadiness.blockingIndicatorCount,
                "isSettled": visualReadiness.isSettled
            ],
            "emittedBy": "SpoonjoyApp",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? ""
        ]
        if let observedSurfaceVariant = proofIdentity.observedSurfaceVariant {
            payload["observedSurfaceVariant"] = observedSurfaceVariant
        }
        if let observedSurfaceState = proofIdentity.observedSurfaceState {
            payload["observedSurfaceState"] = [
                "statusOwner": observedSurfaceState.statusOwner,
                "connectivity": observedSurfaceState.connectivity,
                "queuedMutationCount": observedSurfaceState.queuedMutationCount,
                "visibleIndicator": observedSurfaceState.visibleIndicator
            ]
        }
        return payload
    }

    @MainActor private static func observedDynamicTypeSize(fallback: String) -> String {
#if os(iOS)
        switch UIApplication.shared.preferredContentSizeCategory {
        case .extraSmall:
            return "xSmall"
        case .small:
            return "small"
        case .medium:
            return "medium"
        case .large:
            return "large"
        case .extraLarge:
            return "xLarge"
        case .extraExtraLarge:
            return "xxLarge"
        case .extraExtraExtraLarge:
            return "xxxLarge"
        case .accessibilityMedium:
            return "accessibility1"
        case .accessibilityLarge:
            return "accessibility2"
        case .accessibilityExtraLarge:
            return "accessibility3"
        case .accessibilityExtraExtraLarge:
            return "accessibility4"
        case .accessibilityExtraExtraExtraLarge:
            return "accessibility5"
        default:
            return fallback
        }
#else
        return fallback
#endif
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
