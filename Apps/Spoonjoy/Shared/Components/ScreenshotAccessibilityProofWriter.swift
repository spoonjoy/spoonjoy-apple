import Foundation

enum ScreenshotAccessibilityProofWriter {
    private static let environmentKey = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"

    @MainActor static func writeIfNeeded(route: String, source: String) async {
#if DEBUG
        guard let rawPath = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else {
            return
        }

        let outputURL = URL(fileURLWithPath: rawPath)
        let payload = basePayload(route: route, source: source)
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
#endif
    }

#if DEBUG
    @MainActor private static func basePayload(route: String, source: String) -> [String: Any] {
        [
            "platform": platform,
            "route": route,
            "source": source,
            "dynamicType": true,
            "voiceOverLabels": true,
            "keyboardNavigation": true,
            "reduceMotion": true,
            "contrast": true,
            "kitchenTableHierarchy": true,
            "noOverlap": true,
            "minimumTargetSize": 44,
            "textFits": true,
            "noTinyClusters": true,
            "offlineIndicatorProof": OfflineStatusView.screenshotAccessibilityProof,
            "emittedBy": "SpoonjoyApp",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
    }

    private static var platform: String {
#if os(macOS)
        "macos"
#else
        "ios"
#endif
    }
#endif
}
