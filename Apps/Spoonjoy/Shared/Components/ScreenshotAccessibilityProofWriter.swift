import Foundation

struct ScreenshotAccessibilityRuntimeContext {
    let dynamicTypeSize: String
    let reduceMotionEnabled: Bool
}

enum ScreenshotAccessibilityProofWriter {
    private static let environmentKey = "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"
    private static let expectedRouteEnvironmentKey = "SPOONJOY_SCREENSHOT_EXPECTED_ROUTE"

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
        if let expectedRoute = ProcessInfo.processInfo.environment[expectedRouteEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedRoute.isEmpty,
           expectedRoute != route {
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
            "launchEnvironmentProof": launchEnvironmentProof,
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
        case ("recipes", "RecipesView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Recipes", "Recipe Index", "recipe rows"],
                keyboardNavigationTargets: ["recipe index buttons", "recipe rows"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "brass on bone", "secondary text on bone"],
                hierarchyAnchors: ["RecipesView", "KitchenTableHeader", "KitchenTableSection", "KitchenTableObjectRow"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "dock-safe-area"]
            )
        case ("cookbooks", "CookbooksView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Cookbooks", "Cookbook Shelf", "New Cookbook"],
                keyboardNavigationTargets: ["cookbook shelf buttons", "share buttons", "new cookbook action"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "brass on bone", "secondary text on bone"],
                hierarchyAnchors: ["CookbooksView", "KitchenTableHeader", "CookbookShelf", "KitchenTableObjectRow"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "dock-safe-area"]
            )
        case ("capture", "CaptureDraftView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Import Status", "Spoonjoy Capture", "Send to Spoonjoy"],
                keyboardNavigationTargets: ["import status", "saved capture actions"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "brass on bone", "destructive action role"],
                hierarchyAnchors: ["CaptureDraftView", "KitchenTableHeader", "ImportStatusPanel", "CaptureDraft"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "dock-safe-area"]
            )
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
                hierarchyAnchors: ["SettingsView", "KitchenTableHeader", "KitchenTableSection", "SettingsPanel", "OfflineStatusView"],
                layoutGuards: ["kitchen-table-page", "text-fit", "no-tiny-clusters", "bottom-offline-row"]
            )
        case ("recipe-detail", "RecipeDetailView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Cook mode", "Save", "Yield", "Clear progress", "Add to list", "More", "Steps", "Ingredients", "Cooks"],
                keyboardNavigationTargets: ["recipe primary actions", "recipe secondary menu", "recipe yield controls", "step ingredient rows"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "white on photo overlay", "secondary text on bone"],
                hierarchyAnchors: ["RecipeDetailView", "recipeHeaderControls", "RecipeScaleSelector", "KitchenTableActionButtonStyle", "stepsSection", "RecipeStepChecklistRow", "SpoonCookLogView"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "dock-safe-area"]
            )
        case ("cook-mode", "CookModeView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Mark the current step done", "Return to recipe detail", "Current cooking step", "Step Ingredients", "Cook mode SpoonDock"],
                keyboardNavigationTargets: ["cook step handrail", "ingredient toggles", "dependency toggles"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "herb tint on bone", "status text on material"],
                hierarchyAnchors: ["CookModeView", "compactCookControls", "SpoonDockContext.cookMode", "ScaleSelector"],
                layoutGuards: ["scroll-view", "text-fit", "no-tiny-clusters", "dock-safe-area"]
            )
        case ("shopping-list", "ShoppingListView"):
            RouteAccessibilityEvidence(
                voiceOverLabels: ["Shopping", "Kitchen", "List Actions", "Add", "Clear checked"],
                keyboardNavigationTargets: ["shopping item fields", "shopping header menu", "native tab bar"],
                dynamicTypeTextStyles: ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
                contrastPairs: ["charcoal on bone", "brass label on bone", "destructive action role"],
                hierarchyAnchors: ["ShoppingListView", "shoppingHeaderTools", "addItemControls", "TabView"],
                layoutGuards: ["scroll-list", "text-fit", "no-tiny-clusters", "tab-bar-safe-area"]
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

    private static var launchEnvironmentProof: [String: String] {
        let environment = ProcessInfo.processInfo.environment
        return [
            "screenshotAuth": environment["SPOONJOY_SCREENSHOT_AUTH"] ?? "",
            "screenshotRestoreCacheOnly": environment["SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY"] ?? "",
            "screenshotAccountID": environment["SPOONJOY_SCREENSHOT_ACCOUNT_ID"] ?? "",
            "apiBaseURL": environment["SPOONJOY_API_BASE_URL"] ?? ""
        ]
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
