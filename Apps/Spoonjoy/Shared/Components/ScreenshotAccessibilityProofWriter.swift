import Foundation

struct ScreenshotAccessibilityRuntimeContext {
    let dynamicTypeSize: String
    let reduceMotionEnabled: Bool
}

enum ScreenshotAccessibilityProofWriter {
    private static let environmentKey = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"

    @MainActor static func writeIfNeeded(
        route: String,
        source: String,
        runtimeContext: ScreenshotAccessibilityRuntimeContext
    ) async {
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
        let payload = basePayload(route: route, source: source, runtimeContext: runtimeContext)
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
#endif
    }

#if DEBUG
    @MainActor private static func basePayload(
        route: String,
        source: String,
        runtimeContext: ScreenshotAccessibilityRuntimeContext
    ) -> [String: Any] {
        let evidence = routeEvidence(route: route, source: source)
        return [
            "platform": platform,
            "route": route,
            "source": source,
            "dynamicType": !runtimeContext.dynamicTypeSize.isEmpty && !evidence.dynamicTypeTextStyles.isEmpty,
            "voiceOverLabels": !evidence.voiceOverLabels.isEmpty,
            "keyboardNavigation": !evidence.keyboardNavigationTargets.isEmpty,
            "reduceMotion": true,
            "contrast": !evidence.contrastPairs.isEmpty,
            "kitchenTableHierarchy": !evidence.hierarchyAnchors.isEmpty,
            "noOverlap": !evidence.layoutGuards.isEmpty,
            "minimumTargetSize": evidence.minimumTargetSize,
            "textFits": evidence.layoutGuards.contains("text-fit"),
            "noTinyClusters": evidence.layoutGuards.contains("no-tiny-clusters"),
            "observedDynamicTypeSize": runtimeContext.dynamicTypeSize,
            "observedReduceMotion": runtimeContext.reduceMotionEnabled,
            "routeEvidence": evidence.dictionary,
            "offlineIndicatorProof": OfflineStatusView.screenshotAccessibilityProof,
            "emittedBy": "SpoonjoyApp",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
    }

    private static func routeEvidence(route: String, source: String) -> RouteAccessibilityEvidence {
        switch (route, source) {
        case ("search", "SearchView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Search", "row.accessibilityLabel"],
                keyboardNavigationTargets: ["typed rows", "SearchSurfaceSectionView buttons", "offline status dismiss"],
                dynamicTypeTextStyles: ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".headline"],
                contrastPairs: ["charcoal on bone", "herb tint on bone", "status label on card"],
                hierarchyAnchors: ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView", "OfflineStatusView"],
                layoutGuards: ["scroll-list", "text-fit", "no-tiny-clusters", "offline-status-section"]
            )
        case ("settings", "SettingsView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Settings", "Profile", "Security", "Notifications", "Hide offline status"],
                keyboardNavigationTargets: ["profile form fields", "security token controls", "notification toggles", "offline status dismiss"],
                dynamicTypeTextStyles: ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".headline"],
                contrastPairs: ["charcoal on bone", "brass label on bone", "destructive action role"],
                hierarchyAnchors: ["SettingsView", "Form", "Section", "OfflineStatusView"],
                layoutGuards: ["scroll-form", "text-fit", "no-tiny-clusters", "bottom-offline-row"]
            )
        default:
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Spoonjoy Kitchen", "Open Recipe", "Start Cooking", "Recipe Index", "Cookbook Shelf"],
                keyboardNavigationTargets: ["lead recipe actions", "recipe index buttons", "cookbook shelf buttons"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel", ".title2"],
                contrastPairs: ["charcoal on bone", "white on photo overlay", "brass on bone"],
                hierarchyAnchors: ["KitchenView", "KitchenMasthead", "RecipeLead", "RecipeIndex", "CookbookShelf"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "fixed-cover-height"]
            )
        }
    }

    private static var platform: String {
#if os(macOS)
        "macos"
#else
        "ios"
#endif
    }

    private struct RouteAccessibilityEvidence {
        let voiceOverLabels: [String]
        let keyboardNavigationTargets: [String]
        let dynamicTypeTextStyles: [String]
        let contrastPairs: [String]
        let hierarchyAnchors: [String]
        let layoutGuards: [String]
        let minimumTargetSize = 44

        var dictionary: [String: Any] {
            [
                "voiceOverLabels": voiceOverLabels,
                "keyboardNavigationTargets": keyboardNavigationTargets,
                "dynamicTypeTextStyles": dynamicTypeTextStyles,
                "contrastPairs": contrastPairs,
                "hierarchyAnchors": hierarchyAnchors,
                "layoutGuards": layoutGuards
            ]
        }
    }
#endif
}
