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
  "terminalElementOccludedByTabBar"
])

ios_observer = "Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"
require_tokens(ios_observer, [
  "XCUIApplication()",
  "let observedTypes: [XCUIElement.ElementType]",
  "app.descendants(matching: type).allElementsBoundByIndex",
  "elementLabel",
  "elementType",
  "elementFrame",
  "operatingSystemVersion",
  "let initialScreenshot = XCUIScreen.main.screenshot()",
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
  "app.collectionViews.allElementsBoundByIndex",
  ".collectionView",
  "requiredVisibleIdentifiers.subtract(routeRequiredChromeIdentifiers(route: route))",
  "testRouteToolbarIdentifiersAreRequiredButNotConstrainedToTheContentViewport"
])
forbid_tokens(ios_observer, [
  "element.isHittable",
  "element.isEnabled",
  "toolLimitations",
  "ObservedAuditToolLimitation",
  "knownAuditToolLimitation",
  "measuredContrastProof",
  "resolvingTabBarOcclusionLimitations",
  "postScrollAnonymousContrastIssueAbsent"
])

require_tokens("scripts/run-ios-screenshot-observer.py", [
  "attest_observed_dynamic_type",
  "observedDynamicTypeSize",
  "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
  "Dynamic Type mismatch"
])

mac_observer = "scripts/observe-macos-screenshot-evidence.swift"
require_tokens(mac_observer, [
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
  "recipe-editor.delete",
  "recipe-covers.saved-covers",
  "profile.graph.kitchen-visitors"
])

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
  "private func adjustDuration(",
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
  "capture_ios_observed_accessibility \"$udid\" \"$expected_platform\" \"$observed_accessibility_output\" \"large\" || return 1\n  if [[ \"$expected_platform\" == \"ios\" ]]; then\n    terminate_ios_app_and_confirm_stopped \"$udid\" || return 1\n    refresh_ios_fixture_paths",
  "observed-accessibility-macos-diagnostic.json",
  "macos-desktop-diagnostic.png",
  "screenshots-macos-accessibility-blocker.json",
  "cp \"$observed_accessibility_macos_abs\" \"$observed_accessibility_macos_diagnostic\"",
  "cp \"$macos_screenshot\" \"$macos_screenshot_diagnostic\""
])
require_tokens("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift", [
  "app.buttons.matching(identifier: \"recipe-editor.save\").count",
  "Recipe editor must have exactly one toolbar Save owner",
  "primarySurface.swipeUp(velocity: .fast)",
  "scrollGestureAnchor(in: app, windowFrame: windowFrame)",
  "if stablePasses >= 2 && terminalReached",
  "!viewport.contains(elementFrame)",
  "includesDynamicTypeChecks: false"
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
