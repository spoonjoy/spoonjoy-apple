#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"

ROOT = Pathname.new(ENV.fetch("SPOONJOY_CONTRACT_ROOT", Pathname.new(__dir__).join("..").to_s)).expand_path

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def source(relative_path)
  path = ROOT.join(relative_path)
  fail_check("missing #{relative_path}") unless path.file?
  content = path.read
  case path.extname
  when ".py"
    content.each_line.map { |line| line.lstrip.start_with?("#") ? "\n" : line }.join
  when ".swift"
    strip_swift_nonexecuting_source(content)
  else
    content
  end
end

def strip_swift_nonexecuting_source(content)
  active_lines = []
  disabled_depth = 0
  content.each_line do |line|
    stripped = line.strip
    if disabled_depth.positive?
      disabled_depth += 1 if stripped.start_with?("#if ")
      disabled_depth -= 1 if stripped == "#endif"
      active_lines << "\n"
      next
    end
    if stripped.match?(/\A#if\s+(?:false|0)\z/)
      disabled_depth = 1
      active_lines << "\n"
      next
    end
    active_lines << line
  end
  fail_check("unterminated disabled Swift conditional") unless disabled_depth.zero?

  result = +""
  block_depth = 0
  in_string = false
  escaped = false
  index = 0
  swift_source = active_lines.join
  while index < swift_source.length
    pair = swift_source[index, 2]
    character = swift_source[index]
    if block_depth.positive?
      if pair == "/*"
        block_depth += 1
        result << "  "
        index += 2
      elsif pair == "*/"
        block_depth -= 1
        result << "  "
        index += 2
      else
        result << (character == "\n" ? "\n" : " ")
        index += 1
      end
    elsif in_string
      result << character
      if escaped
        escaped = false
      elsif character == "\\"
        escaped = true
      elsif character == '"'
        in_string = false
      end
      index += 1
    elsif pair == "//"
      newline = swift_source.index("\n", index) || swift_source.length
      result << " " * (newline - index)
      index = newline
    elsif pair == "/*"
      block_depth = 1
      result << "  "
      index += 2
    else
      in_string = true if character == '"'
      result << character
      index += 1
    end
  end
  fail_check("unterminated Swift block comment") unless block_depth.zero?
  result
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

def validate_python_observer_ast!(relative_path)
  path = ROOT.join(relative_path)
  inspector = <<~'PYTHON'
    import ast
    import json
    import sys

    tree = ast.parse(open(sys.argv[1], encoding="utf-8").read(), filename=sys.argv[1])

    class ActiveCalls(ast.NodeVisitor):
        def __init__(self):
            self.calls = []

        def visit_If(self, node):
            if isinstance(node.test, ast.Constant) and not bool(node.test.value):
                for statement in node.orelse:
                    self.visit(statement)
                return
            self.generic_visit(node)

        def visit_Call(self, node):
            if isinstance(node.func, ast.Name):
                name = node.func.id
            elif isinstance(node.func, ast.Attribute):
                name = node.func.attr
            else:
                name = ""
            self.calls.append({
                "name": name,
                "line": node.lineno,
                "keywords": sorted(keyword.arg for keyword in node.keywords if keyword.arg),
            })
            self.generic_visit(node)

    result = {}
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            visitor = ActiveCalls()
            for statement in node.body:
                visitor.visit(statement)
            result[node.name] = visitor.calls
    print(json.dumps(result, sort_keys=True))
  PYTHON
  stdout, stderr, status = Open3.capture3("python3", "-c", inspector, path.to_s)
  fail_check("#{relative_path} AST inspection failed: #{stderr.strip}") unless status.success?
  functions = JSON.parse(stdout)

  waypoint_calls = functions.fetch("publish_waypoint_screenshots", [])
  required_waypoint_calls = %w[
    attest_audit_types readiness_proof_path attest_screenshot_readiness attest_capture_identity
  ]
  missing_waypoint_calls = required_waypoint_calls.reject do |name|
    waypoint_calls.any? { |call| call["name"] == name }
  end
  fail_check("#{relative_path} publish_waypoint_screenshots missing active #{missing_waypoint_calls.join(", ")}") unless missing_waypoint_calls.empty?
  fail_check("#{relative_path} publish_waypoint_screenshots must attest capture identity before and after publication") unless
    waypoint_calls.count { |call| call["name"] == "attest_capture_identity" } >= 2

  main_publish = functions.fetch("main", []).find { |call| call["name"] == "publish_waypoint_screenshots" }
  required_keywords = %w[
    canonical_app_proof_path expected_platform expected_route expected_run_nonce host_process_observation
  ]
  fail_check("#{relative_path} main missing active publish_waypoint_screenshots") unless main_publish
  fail_check("#{relative_path} main waypoint publication lacks authoritative inputs") unless
    required_keywords.all? { |keyword| main_publish.fetch("keywords").include?(keyword) }
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
  "ObservedContrastPixelAdjudicationDiagnostic",
  "iosContrastPixelAdjudicationFailureV1",
  "matchingAttestedElementCount",
  "screenshotBufferUnavailable",
  "cropUnavailable",
  "analyzerRejected",
  "contrastPixelAdjudicationDiagnostics",
  "testBlockingContrastPixelDiagnosticEncodesTheExactFailedStage",
  "ObservedVerifiedStaleOffscreenContrastFalsePositive",
  "iosStaleOffscreenContrastFalsePositiveV1",
  "priorHighContrastPixelsBoundToNowOffscreenAttestedElement",
  "verifiedStaleOffscreenContrastFalsePositives",
  "testStaleOffscreenContrastRequiresPriorPixelsAndExactScrollDisplacement",
  "ObservedVerifiedSystemChromeContrastFalsePositive",
  "verifiedSystemChromeContrastFalsePositives",
  "iosNativeCompactTabChromeContrastFalsePositiveV2",
  "elementContrastBoundToAttestedNativeCompactTabChrome",
  "testChromeContrastWaiverRequiresExactIssueBoundLargeTypeNativeCompactTabEvidence",
  "iosNativeBottomTabChromeContrastFalsePositiveV3",
  "elementContrastBoundToAttestedNativeBottomTabChrome",
  "iosNativeLargeTypeBottomTabChromeContrastFalsePositiveV4",
  "elementContrastBoundToAttestedNativeLargeTypeBottomTabChrome",
  "iosNativeLabelOnlyBottomTabChromeContrastFalsePositiveV5",
  "elementContrastBoundToAttestedNativeLabelOnlyBottomTabChrome",
  "testChromeContrastWaiverRequiresExactIssueBoundPhoneBottomTabEvidence",
  "ObservedVerifiedNativeSidebarSelectionContrastFalsePositive",
  "ObservedVisibleTextContrastEvidence",
  "verifiedNativeSidebarSelectionContrastFalsePositives",
  "iosNativeSidebarSelectionContrastFalsePositiveV3",
  "elementContrastBoundToAttestedNativeSidebarSelection",
  "issueElement",
  "issuePixelEvidence",
  "selectedCellInteriorFrame",
  "selectedCellPixelEvidence",
  "selectedSymbolPixelEvidence",
  "visibleTextPixelEvidence",
  "testSidebarContrastWaiverRequiresExactIssueBoundSelectionPixelAttestation",
  "ObservedVerifiedTextClippedFalsePositive",
  "verifiedTextClippedFalsePositives",
  "iosNativeSidebarTextClippedFalsePositiveV1",
  "nativeSidebarRowExpandedWithinAttestedContainer",
  "testNativeIPadSidebarClippingWarningRequiresExactFrameBoundAttestation",
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
  "testScreenshotContrastAdjudicatorIgnoresOnlyWideEdgeAlignedDividerPixels",
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
  "elements: elements",
  ".collectionView",
  "requiredVisibleIdentifiers.subtract(routeRequiredChromeIdentifiers(route: route))",
  "testRouteToolbarIdentifiersAreRequiredButNotConstrainedToTheContentViewport"
])
require_tokens("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift", [
  "@Environment(\\.dynamicTypeSize) private var dynamicTypeSize",
  "horizontalSizeClass == .compact || dynamicTypeSize >= .xxxLarge"
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
  "screenshotPixelContrastV2",
  "screenshotSHA256",
  "minimumBackgroundCoverage = 0.6",
  "defaultRequiredContrastRatio = 4.5",
  "requiredContrastRatio: Double = defaultRequiredContrastRatio",
  "evaluatedForegroundClusterCount",
  "substantialForegroundClusters",
  "backgroundPixelCount",
  "foregroundPixelCount",
  "ignoredEdgeRulePixelCount",
  "ignoredEdgeRuleRowCount",
  "ignoredEdgeRuleRows"
])
require_tokens("Apps/SpoonjoyUITests/ScreenshotPixelContrastAdjudicator.swift", [
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
require_tokens("scripts/validate-design-review.rb", [
  "validate_macos_screenshot_contrast_evidence!",
  "macosScreenshotContrastEvidenceV1",
  "macOS screenshot contrast evidence fields must be exact",
  "macOS screenshot contrast coverage mismatch",
  "macOS screenshot contrast ratio does not meet its threshold",
  "ios_actionable_composite_pair?",
  "validate_verified_text_clipped_false_positives!",
  "iosNativeSidebarTextClippedFalsePositiveV1",
  "nativeSidebarRowExpandedWithinAttestedContainer",
  "ordinary-size native iPad sidebar rows",
  'deep_scroll["elements"]'
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
  "--self-test-screenshot-contrast",
  "--self-test-screenshot-temporary-name",
  "screenshotTemporaryURL",
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
  "Weeknights",
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
  "process.arguments = [\"-x\", \"-o\", \"-l\"",
  "publishPostScrollScreenshot",
  "publishFailureDiagnostic",
  "macOS diagnostic evidence",
  "findingSummary",
  'macOS initial accessibility audit found \(findingSummary(observedFindings))',
  "failureCleanupURLs",
  "validateRunningApplication",
  "boundRootWindow",
  "CGWindowListCopyWindowInfo",
  "kCGWindowOwnerPID",
  "kCGWindowBounds",
  "stablePostScrollObservation",
  "stableInitialObservation",
  "AXObservedScreenshotContrastEvidence",
  "macosScreenshotContrastEvidenceV1",
  "screenshotContrastEvidence",
  "contrastEvidenceCandidates",
  "ScreenshotPixelContrastAnalyzer",
  "let requiredContrastRatio = candidate.kind == \"text\" ? 4.5 : 3.0",
  "capturePhase: capturePhase",
  "screenshotSHA256: sha256Hex(screenshot.data)",
  "windowFrame: secondWindow.frame",
  "postScrollElements: postScrollObservation.elements",
  "screenshotContrastEvidence: initialObservation.screenshotContrastEvidence",
  "screenshotContrastEvidence: postScrollObservation.screenshotContrastEvidence",
  "pixelAccessibilityBinding",
  "observationDigest",
  "observationDifferenceSummary",
  "let maximumCaptureBindingAttempts = 4",
  "for attempt in 1...maximumCaptureBindingAttempts",
  "Thread.sleep(forTimeInterval: 0.25)",
  "accessibility tree was not stable across the exact-window screenshot after",
  "waitForRequiredRouteTitles",
  "route content did not become accessibility-ready after",
  "waitForRequiredRouteTitles(options: options)",
  "guard scrollEvidence.reachedTerminal, scrollEvidence.findings.isEmpty",
  'failureCleanupURLs.append(outputURL)',
  'post-scroll accessibility tree changed before evidence publication',
  'published macOS post-scroll screenshot changed before evidence publication',
  'post-scroll evidence process or window binding changed before evidence publication',
  'macOS observed screenshot evidence publication failed'
])
forbid_tokens(mac_observer, [
  '".\(outputURL.lastPathComponent).\(UUID().uuidString).capture.png"'
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
contrast_anchor = capture_bound_source.index("let contrastEvidence = screenshotContrastEvidence(")
binding_anchor = capture_bound_source.index("AXObservedPixelAccessibilityBinding(")
unless before_ax_anchor && temporary_capture_anchor && after_ax_anchor && contrast_anchor && binding_anchor &&
       before_ax_anchor < temporary_capture_anchor && temporary_capture_anchor < after_ax_anchor &&
       after_ax_anchor < contrast_anchor && contrast_anchor < binding_anchor
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

unless system("swift", mac_observer, "--self-test-screenshot-temporary-name", chdir: ROOT.to_s)
  fail_check("#{mac_observer} screenshot temporary-name self-test failed")
end

unless system("swift", mac_observer, "--self-test-screenshot-contrast", chdir: ROOT.to_s)
  fail_check("#{mac_observer} screenshot contrast self-test failed")
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
  "drag(primarySurface, contentOffset: requestedContentOffset)",
  "hittable: element.isHittable",
  "allElementsBoundByAccessibilityElement",
  "enabled: element.isEnabled",
  "hitRegionAuditPassed",
  "let maxScrollActions = 12",
  "routeRequiredAccessibilityScrollIdentifiers(route: route)",
  "testInitialPixelAccessibilityBindingEncodesExactSchemaWithExplicitNullHierarchyFields",
  "testDeepPixelAccessibilityBindingEncodesSelectedHierarchyValues",
  "encodeNil(forKey: .selectedScrollHierarchyIdentifier)",
  "encodeNil(forKey: .selectedScrollHierarchySnapshotBeforeSHA256)",
  "encodeNil(forKey: .selectedScrollHierarchySnapshotAfterSHA256)",
  "isStructurallyObservedScrollContent",
  "stableChromeIdentity",
  "testPersistentChromeUsesStableLabelsWhenXCTestAddsSymbolIdentifiersAfterScroll",
  "testPersistentChromeRejectsChangedStructurallyNestedTabControl",
  "namedTerminalIsVisible(",
  "terminalScrollSignature(",
  "observedContentMovement",
  "scrollActionCount > 0",
  "findings.append(contentsOf: persistentChromeFindings(",
  "beforeScrollContent: initialPrimaryElements",
  "afterScrollContent: selectedHierarchyElements",
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
validate_python_observer_ast!("scripts/run-ios-screenshot-observer.py")

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
