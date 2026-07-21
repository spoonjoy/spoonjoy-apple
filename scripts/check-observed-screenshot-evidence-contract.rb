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
  "toolLimitations",
  "ObservedAuditToolLimitation",
  "ObservedContrastProof",
  "ObservedTabBarOcclusionProof",
  "measuredContrastProof",
  "resolvingTabBarOcclusionLimitations",
  "postScrollAnonymousContrastIssueAbsent",
  "contrastRatio",
  "relativeLuminance",
  "https://developer.apple.com/forums/thread/823968",
  "https://developer.apple.com/videos/play/wwdc2023/10035/",
  "operatingSystemVersion",
  "ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26",
  "issue.auditType == .dynamicType",
  "issue.auditType == .contrast",
  "requiredRatio = 4.5",
  "foregroundPixelCount",
  "backgroundPixelCount",
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
  "deep-scroll-evidence"
])
forbid_tokens(ios_observer, ["element.isHittable", "element.isEnabled"])

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
  "kAXPositionAttribute",
  "kAXSizeAttribute",
  "kAXEnabledAttribute",
  "kAXFocusedAttribute",
  "kAXWindowsAttribute",
  "requiredIdentifierMissing",
  "outsideViewport",
  "peerOverlap",
  "actionTargetTooSmall",
  "minimumMacControlSize = 20.0",
  "20-point macOS minimum",
  "apnsChromeIntersection"
])

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
