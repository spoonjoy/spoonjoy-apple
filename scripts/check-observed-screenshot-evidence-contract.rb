#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def source(relative_path)
  path = ROOT.join(relative_path)
  fail_check("missing #{relative_path}") unless path.file?
  path.read
end

def require_tokens(relative_path, tokens)
  content = source(relative_path)
  tokens.each do |token|
    fail_check("#{relative_path} missing #{token.inspect}") unless content.include?(token)
  end
end

def forbid_tokens(relative_path, tokens)
  content = source(relative_path)
  tokens.each do |token|
    fail_check("#{relative_path} still self-attests #{token.inspect}") if content.include?(token)
  end
end

proof_writer = "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift"
require_tokens(proof_writer, [
  "observedDynamicTypeSize",
  "observedReduceMotion",
  "visualReadiness",
  "observedSurfaceVariant",
  "observedSurfaceState",
  "screenshotStateSnapshotProof"
])
forbid_tokens(proof_writer, [
  "voiceOverLabels",
  "keyboardNavigation",
  "minimumTargetSize",
  "noOverlap",
  "textFits",
  "noTinyClusters",
  "routeEvidence",
  "RouteAccessibilityEvidence",
  "offlineIndicatorProof"
])

require_tokens("Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift", [
  "accessibilityHeaderIdentifier: String?",
  ".accessibilityIdentifier(accessibilityHeaderIdentifier)"
])
require_tokens("Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift", [
  "settings.apns.this-device.heading",
  "settings.apns.push-delivery.heading",
  "settings.apns.notification-sync.heading"
])

geometry_support = "Apps/SpoonjoyUITests/ScreenshotEvidenceGeometry.swift"
require_tokens(geometry_support, [
  "ObservedAccessibilityElement",
  "ObservedAccessibilityFinding",
  "requiredIdentifierMissing",
  "outsideViewport",
  "peerOverlap",
  "actionTargetTooSmall",
  "apnsChromeIntersection",
  "terminalElementOccludedByTabBar",
  "persistentChromeChanged"
])

ios_observer = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
require_tokens(ios_observer, [
  "XCUIApplication()",
  "let observedTypes: [XCUIElement.ElementType]",
  "app.descendants(matching: type).allElementsBoundByAccessibilityElement",
  "elementLabel",
  "elementType",
  "elementFrame",
  "operatingSystemVersion",
  "let initialScreenshot = initialCapture.screenshot",
  "viewport: ObservedRect",
  "frame.intersects(windowFrame)",
  "performAccessibilityAudit",
  ".contrast",
  ".hitRegion",
  ".dynamicType",
  ".textClipped",
  ".trait",
  "XCUIScreen.main.screenshot()",
  "SPOONJOY_OBSERVED_ACCESSIBILITY_EVIDENCE_PATH",
  "settings.apns.this-device.heading",
  "settings.apns.push-delivery.heading",
  "testGeometryRejectsMissingRequiredIdentifier",
  "testGeometryRejectsClippedOrOffscreenRequiredElement",
  "testGeometryRejectsPeerOverlap",
  "testGeometryRejectsAPNsChromeIntersection",
  "testGeometryRejectsTerminalElementBehindTabBar",
  "verifiedContrastFalsePositives",
  "capturePhase: \"initial\"",
  "capturePhase: \"deepScroll\"",
  "screenshotSHA256: screenshotSHA256",
  "testScreenshotContrastAdjudicatorRejectsLowContrastTextPixels",
  "testScreenshotContrastAdjudicatorRejectsMixedHighAndLowContrastRuns",
  "testScreenshotContrastBufferDecodesAntialiasedSystemTextFromPNG",
  "scrollPrimarySurfaceToTerminal",
  "deepScrollRoutes",
  "kitchen",
  "recipe-detail",
  "shopping-list",
  "cookbooks",
  "cookbook-detail",
  "deep-scroll-screenshot",
  "deep-scroll-evidence",
  "case \"recipe-editor\": \"Recipe\"",
  "case \"recipe-covers\": \"Photo Studio\"",
  "case \"cook-mode\": \"Current cooking step 1, Boil pasta\"",
  "app.collectionViews.allElementsBoundByAccessibilityElement",
  ".collectionView",
  "requiredVisibleIdentifiers.subtract(routeRequiredChromeIdentifiers(route: route))",
  "testRouteToolbarIdentifiersAreRequiredButNotConstrainedToTheContentViewport"
])
forbid_tokens(ios_observer, [
  "toolLimitations",
  "ObservedAuditToolLimitation",
  "knownAuditToolLimitation",
  "measuredContrastProof",
  "resolvingTabBarOcclusionLimitations",
  "postScrollAnonymousContrastIssueAbsent",
  "shouldIgnoreVerifiedHighContrastFalsePositive("
])

require_tokens("Apps/SpoonjoyUITests/ScreenshotPixelContrastAdjudicator.swift", [
  "screenshotPixelContrastV1",
  "screenshotSHA256",
  "minimumBackgroundCoverage = 0.6",
  "requiredContrastRatio = 4.5",
  "evaluatedForegroundClusterCount",
  "substantialForegroundClusters",
  "backgroundPixelCount",
  "foregroundPixelCount"
])

require_tokens("scripts/run-ios-screenshot-observer.py", [
  "attest_observed_dynamic_type",
  "observedDynamicTypeSize",
  "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
  "Dynamic Type mismatch"
])

mac_observer = "scripts/observe-macos-screenshot-evidence.swift"
require_tokens(mac_observer, [
  "--self-test-non-finite-frame",
  "normalizedObservedRect",
  "values.allSatisfy(\\.isFinite)",
  "NSRunningApplication(processIdentifier:",
  "expectedBundleIdentifier",
  "expectedBundlePath",
  "expectedExecutablePath",
  "AXUIElementCreateApplication",
  "kAXIdentifierAttribute",
  "kAXRoleAttribute",
  "kAXTitleAttribute",
  "kAXDescriptionAttribute",
  "kAXValueAttribute",
  "kAXPositionAttribute",
  "kAXSizeAttribute",
  "kAXEnabledAttribute",
  "kAXFocusedAttribute",
  "kAXWindowsAttribute",
  "expected exactly one measurable main content window",
  "observeTree(root: rootWindowElement)",
  "isNativeSystemControl",
  "kAXDisclosureTriangleRole as String",
  "AXFullScreenButton",
  "AXIncrementArrow",
  "AXDecrementArrow",
  "AXIncrementPage",
  "AXDecrementPage",
  "requiredIdentifierMissing",
  "outsideViewport",
  "peerOverlap",
  "actionTargetTooSmall",
  "minimumMacControlSize = 20.0",
  "20-point macOS minimum",
  "apnsChromeIntersection",
  "AXObservedDeepScrollEvidence",
  "kAXVerticalScrollBarAttribute",
  "kAXMaxValueAttribute",
  "normalizedScrollMaximum = 1.0",
  "AXUIElementIsAttributeSettable",
  "AXUIElementSetAttributeValue",
  "AXScrollDownByPage",
  "scrollByPageToTerminal",
  "performNativePageScroll",
  "kAXPressAction",
  "spoonjoy.page-scroll",
  "kitchen.cookbook.cookbook_weeknights",
  "recipe-editor.delete",
  "recipe-covers.archive.cover_primary",
  "profile.graph.kitchen-visitors"
])
mac_observer_source = source(mac_observer)
deep_scroll_start = mac_observer_source.index("func observeDeepScroll")
deep_scroll_end = mac_observer_source.index("func findings", deep_scroll_start)
fail_check("#{mac_observer} missing bounded observeDeepScroll implementation") unless deep_scroll_start && deep_scroll_end
deep_scroll_source = mac_observer_source[deep_scroll_start...deep_scroll_end]
named_scroll_anchor = deep_scroll_source.index("$0.observation.identifier == expectation.scrollIdentifier")
terminal_anchor = deep_scroll_source.index("$0.observation.identifier == expectation.terminalIdentifier")
unless named_scroll_anchor && terminal_anchor && named_scroll_anchor < terminal_anchor
  fail_check("#{mac_observer} must prefer the exact named scroll area before a nested terminal scroll ancestor")
end

unless system("swift", mac_observer, "--self-test-non-finite-frame", chdir: ROOT.to_s)
  fail_check("#{mac_observer} non-finite frame self-test failed")
end

require_tokens("Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift", [
  "RecipeEditorPlatformScroller",
  "content.fixedSize(horizontal: false, vertical: true)",
  ".modifier(RecipeEditorPlatformScroller())",
  ".scrollEdgeEffectStyle(.soft, for: .top)",
  ".scrollEdgeEffectHidden(for: .bottom)",
  ".contentMargins(.top, KitchenTableTheme.pageSpacing, for: .scrollContent)",
  "ToolbarItem(placement: .confirmationAction)",
  "RecipeEditorToolbarCoordinator",
  "RecipeEditorToolbarFingerprint",
  ".padding(.vertical, 11)",
  ".onChange(of: toolbarFingerprint)",
  "session.canPerformSave(for: routeIdentifier)",
  "reset(ifMatching: editorRouteIdentifier)",
  "synchronizeToolbarCoordinator()",
  "private func durationStepper(",
  "Stepper(value: durationMinutes(value)",
  "private func toggleOutputSteps(for stepID: String)",
  ".frame(minHeight: KitchenTableTheme.minimumTouchTarget)"
])
forbid_tokens("Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift", [
  "DisclosureGroup",
  "Back to My Recipes"
])
require_tokens("scripts/capture-native-screenshots.sh", [
  "refresh_ios_fixture_paths()",
  "refresh_ios_fixture_paths \"$udid\" \"$expected_platform\" || return 1",
  "--readiness-proof-output \"$readiness_proof_output\"",
  "\"$observed_accessibility_output\" \\\n    \"large\" \\\n    \"$screenshot_output\" \\\n    \"$accessibility_proof_output\"; then\n    return 1",
  "\"$observed_accessibility_ios_ax_abs\" \\\n      \"accessibility-extra-extra-extra-large\" \\\n      \"$ios_accessibility_screenshot\" \\\n      \"$accessibility_proof_ios_ax_abs\"; then\n      return 1",
  "observed-accessibility-macos-diagnostic.json",
  "macos-desktop-diagnostic.png",
  "screenshots-macos-accessibility-blocker.json",
  "cp \"$observed_accessibility_macos_abs\" \"$observed_accessibility_macos_diagnostic\"",
  "cp \"$macos_screenshot\" \"$macos_screenshot_diagnostic\""
])
require_tokens("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift", [
  "app.buttons.matching(identifier: \"recipe-editor.save\").count",
  "Recipe editor must have exactly one toolbar Save owner",
  "terminalScrollCorrection(",
  "drag(primarySurface, contentOffset: correction)",
  "hittable: element.isHittable",
  "allElementsBoundByAccessibilityElement",
  "enabled: element.isEnabled",
  "hitRegionAuditPassed",
  "let maxScrollActions = 12",
  "routeRequiredAccessibilityScrollIdentifiers(route: route)",
  "namedTerminalIsVisible(",
  "terminalScrollSignature(",
  "observedContentMovement",
  "scrollActionCount > 0",
  "persistentChromeFindings(before: initialElements, after: elements)",
  "terminalIdentifier == nil,",
  "reachedStableTerminal = true",
  "let initialCapture = try captureAttestedScreenshot(",
  "let initialScreenshot = initialCapture.screenshot",
  "let readinessHandshake = initialCapture.handshake",
  "readinessGeneration: Int",
  "proofFileName: String",
  "readinessHandshake: deepCapture.handshake",
  "readinessHandshakeRemainsStable(",
  "Date().timeIntervalSince(stableSince) >= 0.35",
  "Screenshot readiness marker never held a stable lease.",
  "ScreenshotEvidenceGeometry.validate(\n            elements: elements",
  "screenshotSHA256: Self.sha256(deepScreenshot.pngRepresentation)",
  "data: screenshot.pngRepresentation",
  "isHorizontallyContained",
  "isVerticallyOutside",
  "captureAttestedScreenshot("
])
require_tokens("scripts/run-ios-screenshot-observer.py", [
  "attest_exported_screenshot",
  "readiness_proof_path",
  "deep_readiness_proof_output",
  'deep_scroll.get("readinessHandshake")',
  "observed screenshot attachment SHA-256 mismatch",
  'attest_exported_screenshot(evidence, screenshots[0], "screenshotSHA256")',
  'attest_exported_screenshot(deep_scroll, deep_screenshots[0], "screenshotSHA256")'
])
forbid_tokens("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift", [
  "hittable: actionable && intersectsWindow",
  "app.descendants(matching: type).allElementsBoundByIndex",
  "includesDynamicTypeChecks: false",
  "fatalError(\"Implemented after the focused regression test fails\")"
])
require_tokens("Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift", ["recipe-covers.scroll"])
require_tokens("Apps/Spoonjoy/Shared/Views/ProfileView.swift", ["profile.scroll"])

require_tokens("scripts/generate-xcode-project.rb", [
  "Apps/SpoonjoyUITests",
  "app.spoonjoy.uitests",
  ":ui_test_bundle",
  "add_dependency(ios_target)",
  "add_test_target"
])
require_tokens("Spoonjoy.xcodeproj/project.pbxproj", ["SpoonjoyUITests", "app.spoonjoy.uitests"])
require_tokens("Spoonjoy.xcodeproj/xcshareddata/xcschemes/Spoonjoy iOS.xcscheme", [
  "SpoonjoyUITests.xctest",
  "<TestableReference"
])

puts "observed screenshot evidence contract ok"
