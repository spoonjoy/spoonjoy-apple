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
  "root.descendants(matching: type).allElementsBoundByAccessibilityElement",
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
  "ObservedCaptureIdentity",
  "before.applicationProcessIdentifier",
  "captureIdentity: initialCapture.identity",
  "captureIdentity: deepCapture.identity",
  "auditTypes: auditResult.auditTypes",
  "testSettledTerminalAuditCoversVisualTypographyAndInteractionFailures",
  "testEveryDeepScrollRouteHasAnExactSourceGroundedTerminal",
  "applicationProcessIdentifier",
  "foregroundBeforeCapture",
  "foregroundAfterCapture",
  "screenshotSHA256: screenshotSHA256",
  "testScreenshotContrastAdjudicatorRejectsLowContrastTextPixels",
  "testScreenshotContrastAdjudicatorRejectsMixedHighAndLowContrastRuns",
  "testScreenshotContrastAdjudicatorRejectsMeaningfulMinorityLowContrastCluster",
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
  "selectedScrollHierarchy: primarySurface",
  "deepCapture.selectedScrollHierarchyElements",
  ".collectionView",
  "requiredVisibleIdentifiers.subtract(routeRequiredChromeIdentifiers(route: route))",
  "testRouteToolbarIdentifiersAreRequiredButNotConstrainedToTheContentViewport"
])
forbid_tokens(ios_observer, ["app.processID"])
require_tokens("Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift", [
  "applicationProcessIdentifier: ProcessInfo.processInfo.processIdentifier",
  "String(applicationProcessIdentifier)"
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
require_tokens("Apps/SpoonjoyUITests/ScreenshotPixelContrastAdjudicator.swift", [
  "minimumForegroundClusterShare = 0.2",
  "foregroundCandidates.count"
])
forbid_tokens("Apps/SpoonjoyUITests/ScreenshotPixelContrastAdjudicator.swift", [
  "dominantForegroundBucket.count) * 0.75"
])

require_tokens("scripts/run-ios-screenshot-observer.py", [
  "attest_observed_dynamic_type",
  "observedDynamicTypeSize",
  "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
  "\"extra-extra-extra-large\": \"xxxLarge\"",
  "Dynamic Type mismatch",
  "REQUIRED_AUDIT_TYPES",
  'attest_audit_types(deep_scroll, "deepScroll")',
  "parse_exact_simulator_application_processes",
  "attest_host_process_binding",
  "iosHostProcessObservationV1"
])

capture_script = "scripts/capture-native-screenshots.sh"
require_tokens(capture_script, [
  "ios_tablet_xxxl_screenshot",
  "ios_tablet_accessibility_screenshot",
  "ios_tablet_xxxl_deep_scroll_screenshot",
  "ios_tablet_accessibility_deep_scroll_screenshot",
  "accessibility_proof_ipad_xxxl",
  "accessibility_proof_ipad_ax",
  "observed_accessibility_ipad_xxxl",
  "observed_accessibility_ipad_ax",
  "macos_deep_scroll_screenshot",
  '"iosTabletXXXL" => "screenshots/ios-tablet-xxxl.png"',
  '"iosTabletAccessibility" => "screenshots/ios-tablet-accessibility.png"',
  '"macosDesktop" => "screenshots/macos-desktop-deep-scroll.png"'
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
  "kitchen.cookbook.cookbook_slow_sundays",
  "Slow Sundays and Long Simmering Suppers, 0 recipes",
  "recipe-editor.delete",
  "recipe-covers.terminal",
  "profile.graph.kitchen-visitors",
  "--deep-scroll-screenshot-path",
  "--window-id",
  "postScrollScreenshotSHA256",
  "postScrollElements",
  "postScrollAuditFindings",
  "applicationProcessIdentifier",
  "windowID",
  "capturePostScrollScreenshot",
  "publishPostScrollScreenshot",
  "failureCleanupURLs",
  "validateRunningApplication",
  "boundRootWindow",
  "CGWindowListCopyWindowInfo",
  "kCGWindowOwnerPID",
  "kCGWindowBounds",
  "stablePostScrollObservation",
  "stableInitialObservation",
  "pixelAccessibilityBinding",
  "observationDigest",
  "guard scrollEvidence.reachedTerminal, scrollEvidence.findings.isEmpty",
  'failureCleanupURLs.append(outputURL)',
  'post-scroll accessibility tree changed before evidence publication',
  'published macOS post-scroll screenshot changed before evidence publication',
  'post-scroll evidence process or window binding changed before evidence publication',
  'macOS observed screenshot evidence publication failed'
])

require_tokens(ios_observer, [
  "pixelAccessibilityBinding",
  "accessibilitySnapshotBeforeSHA256",
  "accessibilitySnapshotAfterSHA256",
  "in: primarySurface",
  "Deep-scroll proof was not bound to the exact selected scroll hierarchy."
])
forbid_tokens(ios_observer, [
  "app.collectionViews.allElementsBoundByAccessibilityElement"
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
capture_bound_start = mac_observer_source.index("func captureBoundObservation(")
capture_bound_end = mac_observer_source.index("func stableInitialObservation", capture_bound_start)
fail_check("#{mac_observer} missing point-in-time capture binding") unless capture_bound_start && capture_bound_end
capture_bound_source = mac_observer_source[capture_bound_start...capture_bound_end]
before_ax_anchor = capture_bound_source.index("let firstElements = observeTree")
temporary_capture_anchor = capture_bound_source.index("let screenshot = capturePostScrollScreenshot(")
after_ax_anchor = capture_bound_source.index("let secondElements = observeTree")
binding_anchor = capture_bound_source.index("AXObservedPixelAccessibilityBinding(")
unless before_ax_anchor && temporary_capture_anchor && after_ax_anchor && binding_anchor &&
       before_ax_anchor < temporary_capture_anchor && temporary_capture_anchor < after_ax_anchor && after_ax_anchor < binding_anchor
  fail_check("#{mac_observer} must bind each exact-window screenshot between stable before/after AX observations")
end
initial_observation_anchor = mac_observer_source.index("let initialObservation = stableInitialObservation(")
publish_initial_anchor = mac_observer_source.index("publishPostScrollScreenshot(initialObservation.screenshot")
stable_observation_anchor = mac_observer_source.index("let postScrollObservation = stablePostScrollObservation(")
publish_screenshot_anchor = mac_observer_source.index("publishPostScrollScreenshot(postScrollObservation.screenshot")
final_tree_revalidation_anchor = mac_observer_source.rindex("post-scroll accessibility tree changed before evidence publication")
publish_evidence_anchor = mac_observer_source.rindex("atomicallyPublish(temporaryOutputURL, to: outputURL")
unless initial_observation_anchor && publish_initial_anchor && stable_observation_anchor && publish_screenshot_anchor && final_tree_revalidation_anchor && publish_evidence_anchor &&
       initial_observation_anchor < publish_initial_anchor &&
       publish_initial_anchor < stable_observation_anchor &&
       stable_observation_anchor < publish_screenshot_anchor &&
       publish_screenshot_anchor < final_tree_revalidation_anchor &&
       final_tree_revalidation_anchor < publish_evidence_anchor
  fail_check("#{mac_observer} must capture to temp, stably re-observe, publish the rollback-owned PNG, revalidate, then publish evidence last")
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
  "ios-mobile-xxxl.png",
  "ios-mobile-xxxl-deep-scroll.png",
  "cookbook_slow_sundays",
  "Slow Sundays and Long Simmering Suppers",
  "extra-extra-extra-large",
  "observed-accessibility-ios-xxxl.json",
  "accessibility-proof-ios-xxxl.json",
  "refresh_ios_fixture_paths()",
  "refresh_ios_fixture_paths \"$udid\" \"$expected_platform\" || return 1",
  "--readiness-proof-output \"$readiness_proof_output\"",
  "\"$observed_accessibility_output\" \\\n    \"large\" \\\n    \"$screenshot_output\" \\\n    \"$accessibility_proof_output\" \\\n    \"$surface_proof_output\"; then\n    return 1",
  "\"$observed_accessibility_ios_ax_abs\" \\\n      \"accessibility-extra-extra-extra-large\" \\\n      \"$ios_accessibility_screenshot\" \\\n      \"$accessibility_proof_ios_ax_abs\"; then\n      return 1",
  "observed-accessibility-macos-diagnostic.json",
  "macos-desktop-diagnostic.png",
  "screenshots-macos-accessibility-blocker.json",
  "cp \"$observed_accessibility_macos_abs\" \"$observed_accessibility_macos_diagnostic\"",
  "cp \"$macos_screenshot\" \"$macos_screenshot_diagnostic\""
])
require_tokens("scripts/capture-native-screenshots.sh", [
  'rm -f "$macos_screenshot"',
  '"The external macOS observer produced no point-in-time AX/pixel-bound screenshot."',
  'evidence.fetch("windowID") == Integer(expected_window_id, 10)',
  'deep.fetch("reachedTerminal") == true',
  'deep.fetch("applicationProcessIdentifier") == Integer(expected_pid, 10)',
  'deep.fetch("postScrollScreenshotSHA256") == Digest::SHA256.file(deep_screenshot_path).hexdigest'
])
forbid_tokens("scripts/capture-native-screenshots.sh", [
  'local temporary_screenshot="${macos_screenshot}.capture-${screenshot_run_nonce}.tmp.png"',
  'mv "$temporary_screenshot" "$macos_screenshot"'
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
  "guard let terminalExpectation else",
  "consecutiveTerminalMatches >= 2",
  "terminalElementMatches(terminalElement, expectation: terminalExpectation, viewport: viewport)",
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
  "attest_capture_identity",
  "publish_attested_screenshot",
  'expected_phase="initial"',
  'expected_phase="deepScroll"',
  "readiness_proof_path",
  "deep_readiness_proof_output",
  'deep_scroll.get("readinessHandshake")',
  "observed screenshot attachment SHA-256 mismatch",
  'initial_capture_identity = attest_capture_identity(',
  'deep_capture_identity = attest_capture_identity('
])

capture_script = source("scripts/capture-native-screenshots.sh")
capture_ios_app_start = capture_script.index("capture_ios_app() {")
capture_ios_app_end = capture_script.index("\npublish_ios_capture_artifact()", capture_ios_app_start)
fail_check("scripts/capture-native-screenshots.sh missing bounded capture_ios_app implementation") unless capture_ios_app_start && capture_ios_app_end
capture_ios_app_source = capture_script[capture_ios_app_start...capture_ios_app_end]
if capture_ios_app_source.include?("capture_ios_foreground_route")
  fail_check("scripts/capture-native-screenshots.sh must not capture and validate pixels before the observer-owned screenshot")
end
observer_capture_start = capture_script.index("capture_ios_observed_accessibility() {")
observer_capture_end = capture_script.index("\nrefresh_ios_fixture_paths()", observer_capture_start)
fail_check("scripts/capture-native-screenshots.sh missing bounded capture_ios_observed_accessibility implementation") unless observer_capture_start && observer_capture_end
observer_capture_source = capture_script[observer_capture_start...observer_capture_end]
unless capture_ios_app_source.include?("capture_ios_observed_accessibility") &&
       observer_capture_source.include?("validate_ios_screenshot \"$screenshot_output\"")
  fail_check("scripts/capture-native-screenshots.sh must pixel-validate the observer-owned screenshot")
end
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
