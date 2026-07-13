#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "set"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path

REQUIRED_ACCESSIBILITY_FIELDS = [
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze

EXPECTED_OFFLINE_VISIBLE_STATES = [
  "offline",
  "stale",
  "queuedWork",
  "syncFailure",
  "conflict",
  "blocker",
  "destructiveConfirmation"
].freeze
EXPECTED_OFFLINE_DISMISSIBLE_STATES = ["offline", "stale"].freeze
EXPECTED_OFFLINE_SEVERE_STATES = [
  "queuedWork",
  "syncFailure",
  "conflict",
  "blocker",
  "destructiveConfirmation"
].freeze

CONTRACTS = {
  "docs/native-design-language.md" => [
    "accessibilityProofArtifacts",
    "offlineIndicatorProof",
    "minimumTargetSize",
    "visibleStates",
    "dismissibleStates",
    "severeStates",
    "dynamicType",
    "voiceOverLabels",
    "keyboardNavigation",
    "reduceMotion",
    "contrast",
    "kitchenTableHierarchy",
    "noOverlap"
  ],
  "scripts/validate-design-review.rb" => [
    "accessibilityProofArtifacts",
    "validate_accessibility_proof!",
    "offlineIndicatorProof",
    "minimumTargetSize",
    "visibleStates",
    "dismissibleStates",
    "severeStates",
    "OfflineStatusView",
    "Hide offline status",
    "textFits",
    "noTinyClusters",
    "emittedBy",
    "bundleIdentifier",
    "observedDynamicTypeSize",
    "observedReduceMotion",
    "routeEvidence"
  ],
  "scripts/validate-design-review-blocker.rb" => [
    'apple/#{unit_slug}-accessibility-proof-ios.json',
    'apple/#{unit_slug}-accessibility-proof-macos.json',
    "screenshots/ios-mobile.png",
    "screenshots/macos-desktop.png",
    "design-review.json",
    "stale success artifact",
    "sourceBlockerPath"
  ],
  "scripts/capture-native-screenshots.sh" => [
    "accessibility_proof_ios",
    "accessibility_proof_macos",
    "wait_for_accessibility_proof",
    "accessibilityProofArtifacts",
    "offlineIndicatorProof",
    "minimumTargetSize",
    "observedDynamicTypeSize",
    "routeEvidence",
    "visibleStates",
    "dismissibleStates",
    "severeStates",
    "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
    "apple/${unit_slug}-accessibility-proof-ios.json",
    "apple/${unit_slug}-accessibility-proof-macos.json",
    "rm -f \"$accessibility_proof_ios\" \"$accessibility_proof_macos\""
  ],
  "Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift" => [
    "ScreenshotAccessibilityProofWriter",
    "ScreenshotAccessibilityRuntimeContext",
    "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
    "writeIfNeeded(",
    "runtimeContext: ScreenshotAccessibilityRuntimeContext",
    "routeEvidence(route: route, source: source)",
    "row.accessibilityLabel",
    "SearchSurfaceContract.searchableScopes",
    "SearchSurfaceContract.visibleSearchField",
    "SearchSurfaceContract.typedRows",
    "OfflineStatusView.screenshotAccessibilityProof",
    "observedDynamicTypeSize",
    "observedReduceMotion",
    "\"emittedBy\": \"SpoonjoyApp\"",
    "\"bundleIdentifier\": Bundle.main.bundleIdentifier",
    "JSONSerialization.data",
    "FileManager.default.createDirectory"
  ],
  "scripts/validate-native-local.sh" => [
    "scripts/check-design-accessibility-contract.rb",
    "matrix-design-accessibility-contract.log",
    "conflicting design review success and blocker artifacts",
    "apple/matrix-accessibility-proof-ios.json",
    "apple/matrix-accessibility-proof-macos.json",
    "design-review-blocked.json"
  ],
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift" => [
    "OfflineStatusView",
    "OfflineIndicatorDisplay",
    "display.informationalOnly",
    ".accessibilityLabel(label)",
    ".accessibilityLabel(\"Hide offline status\")",
    "Button",
    "KitchenTableTheme.bodyNote",
    "screenshotAccessibilityProof",
    "visibleProbeDisplays",
    "hiddenProbeDisplays",
    "severityCorrect"
  ],
  "Apps/Spoonjoy/Shared/Views/KitchenView.swift" => [
    "@Environment(\\.dynamicTypeSize)",
    "@Environment(\\.accessibilityReduceMotion)",
    "ScreenshotAccessibilityProofWriter.writeIfNeeded(",
    "runtimeContext: screenshotAccessibilityRuntimeContext"
  ],
  "Apps/Spoonjoy/Shared/Views/SearchView.swift" => [
    "@Environment(\\.dynamicTypeSize)",
    "@Environment(\\.accessibilityReduceMotion)",
    "ScreenshotAccessibilityProofWriter.writeIfNeeded(",
    "runtimeContext: screenshotAccessibilityRuntimeContext"
  ],
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift" => [
    "@Environment(\\.dynamicTypeSize)",
    "@Environment(\\.accessibilityReduceMotion)",
    "ScreenshotAccessibilityProofWriter.writeIfNeeded(",
    "runtimeContext: screenshotAccessibilityRuntimeContext"
  ]
}.freeze

$failures = []

def record_failure(message)
  $failures << message
end

def run_status(*args, chdir: ROOT)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: chdir.to_s)
  [stdout, stderr, status]
end

def assert_status(expected_success, args, label, chdir: ROOT)
  stdout, stderr, status = run_status(*args, chdir: chdir)
  return if status.success? == expected_success

  expected = expected_success ? "succeed" : "fail"
  record_failure("#{label} expected to #{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
end

def assert_tokens(relative_path, tokens)
  path = ROOT.join(relative_path)
  unless path.file?
    record_failure("missing #{relative_path}")
    return
  end

  content = path.read
  missing = tokens.reject { |token| content.include?(token) }
  record_failure("#{relative_path} missing required tokens: #{missing.join(", ")}") unless missing.empty?
end

def base_design_review
  REQUIRED_ACCESSIBILITY_FIELDS.to_h { |field| [field, true] }.merge(
    "mobileScreenshot" => true,
    "desktopScreenshot" => true,
    "blockers" => [],
    "screenshotRoute" => "kitchen",
    "kitchenSignedInSurface" => true,
    "kitchenSeedAccountID" => "chef_kitchen_capture",
    "accessibilityProofArtifacts" => [
      "apple/unit-contract-accessibility-proof-ios.json",
      "apple/unit-contract-accessibility-proof-macos.json"
    ]
  )
end

def accessibility_proof(platform)
  REQUIRED_ACCESSIBILITY_FIELDS.to_h { |field| [field, true] }.merge(
    "platform" => platform,
    "route" => "kitchen",
    "source" => "KitchenView",
    "emittedBy" => "SpoonjoyApp",
    "bundleIdentifier" => platform == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy",
    "minimumTargetSize" => 44,
    "textFits" => true,
    "noTinyClusters" => true,
    "observedDynamicTypeSize" => "large",
    "observedReduceMotion" => false,
    "routeEvidence" => {
      "voiceOverLabels" => ["On the Counter", "Start Cooking", "Recipe index", "RecipeIndexRow ordinal", "Cookbook shelf"],
      "keyboardNavigationTargets" => ["lead recipe actions", "RecipeIndexRow buttons", "cookbook shelf buttons"],
      "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel"],
      "contrastPairs" => ["charcoal on bone", "media-aware contrast on real covers"],
      "hierarchyAnchors" => ["KitchenView", "KitchenMasthead", "RecipeLead", "RecipeIndexRow", "CookbookShelf"],
      "layoutGuards" => ["text-fit", "no-tiny-clusters", "ordinal"]
    },
    "offlineIndicatorProof" => {
      "source" => "OfflineStatusView",
      "visibleStates" => EXPECTED_OFFLINE_VISIBLE_STATES,
      "dismissibleStates" => EXPECTED_OFFLINE_DISMISSIBLE_STATES,
      "severeStates" => EXPECTED_OFFLINE_SEVERE_STATES,
      "hiddenStates" => ["synced", "dismissed"],
      "voiceOverLabel" => true,
      "dismissButtonLabel" => "Hide offline status",
      "severityCorrect" => true
    }
  )
end

CONTRACTS.each { |relative_path, tokens| assert_tokens(relative_path, tokens) }

capture_script = ROOT.join("scripts/capture-native-screenshots.sh").read
if capture_script.include?("write_accessibility_proof()")
  record_failure("scripts/capture-native-screenshots.sh must not fabricate accessibility proof artifacts in the harness")
end

[
  "scripts/check-design-accessibility-contract.rb",
  "scripts/validate-design-review.rb",
  "scripts/validate-design-review-blocker.rb"
].each do |relative_path|
  assert_status(true, ["ruby", "-c", ROOT.join(relative_path)], "#{relative_path} syntax")
end

Dir.mktmpdir("spoonjoy-design-accessibility-contract") do |directory|
  temp_root = Pathname.new(directory)
  apple_dir = temp_root.join("apple")
  apple_dir.mkpath

  validator = ROOT.join("scripts/validate-design-review.rb")
  blocker_validator = ROOT.join("scripts/validate-design-review-blocker.rb")

  base_design_review.fetch("accessibilityProofArtifacts").zip(["ios", "macos"]).each do |relative_path, platform|
    path = temp_root.join(relative_path)
    path.dirname.mkpath
    path.write(JSON.pretty_generate(accessibility_proof(platform)) + "\n")
  end

  valid_review_path = temp_root.join("valid-design-review.json")
  valid_review_path.write(JSON.pretty_generate(base_design_review) + "\n")
  assert_status(true, ["ruby", validator, valid_review_path], "valid accessibility design review")

  missing_route_evidence = accessibility_proof("ios")
  missing_route_evidence.delete("routeEvidence")
  temp_root.join("apple/unit-contract-accessibility-proof-ios.json").write(JSON.pretty_generate(missing_route_evidence) + "\n")
  missing_route_evidence_path = temp_root.join("missing-route-evidence-design-review.json")
  missing_route_evidence_path.write(JSON.pretty_generate(base_design_review) + "\n")
  assert_status(false, ["ruby", validator, missing_route_evidence_path], "missing routeEvidence design review")
  temp_root.join("apple/unit-contract-accessibility-proof-ios.json").write(JSON.pretty_generate(accessibility_proof("ios")) + "\n")

  missing_accessibility_path = temp_root.join("missing-accessibility-proof.json")
  missing_accessibility_path.write(JSON.pretty_generate(base_design_review.reject { |key, _| key == "accessibilityProofArtifacts" }) + "\n")
  assert_status(false, ["ruby", validator, missing_accessibility_path], "missing accessibilityProofArtifacts design review")

  missing_offline_proof = accessibility_proof("ios")
  missing_offline_proof.delete("offlineIndicatorProof")
  temp_root.join("apple/unit-contract-accessibility-proof-ios.json").write(JSON.pretty_generate(missing_offline_proof) + "\n")
  missing_offline_path = temp_root.join("missing-offline-proof-design-review.json")
  missing_offline_path.write(JSON.pretty_generate(base_design_review) + "\n")
  assert_status(false, ["ruby", validator, missing_offline_path], "missing offlineIndicatorProof design review")

  canonical_blocker = apple_dir.join("unit-contract-screenshots-core-simulator-blocker.json")
  canonical_blocker.write(JSON.pretty_generate(
    "blocked" => true,
    "capability" => "CoreSimulator",
    "command" => "xcrun simctl io booted screenshot",
    "timeoutSeconds" => 30,
    "outputPath" => apple_dir.join("unit-contract-screenshots.log").to_s,
    "reason" => "No booted simulator was available.",
    "ownerAction" => "Install and boot an iPhone simulator runtime."
  ) + "\n")
  expanded_blocked_review = {
    "blocked" => true,
    "capability" => "CoreSimulator",
    "sourceBlockerPath" => canonical_blocker.to_s,
    "skippedArtifacts" => [
      "screenshots/ios-mobile.png",
      "screenshots/macos-desktop.png",
      "design-review.json",
      "apple/unit-contract-accessibility-proof-ios.json",
      "apple/unit-contract-accessibility-proof-macos.json"
    ],
    "reason" => "Screenshot capture was blocked by CoreSimulator.",
    "ownerAction" => "Install and boot an iPhone simulator runtime."
  }
  blocked_review_path = temp_root.join("design-review-blocked.json")
  blocked_review_path.write(JSON.pretty_generate(expanded_blocked_review) + "\n")
  base_design_review.fetch("accessibilityProofArtifacts").each do |relative_path|
    temp_root.join(relative_path).delete if temp_root.join(relative_path).exist?
  end
  assert_status(
    true,
    ["ruby", blocker_validator, blocked_review_path, "--artifact-root", temp_root, "--unit-slug", "unit-contract"],
    "valid expanded design-review blocker"
  )

  old_skipped_artifacts_review = expanded_blocked_review.merge(
    "skippedArtifacts" => [
      "screenshots/ios-mobile.png",
      "screenshots/macos-desktop.png",
      "design-review.json"
    ]
  )
  old_skipped_artifacts_path = temp_root.join("old-skipped-artifacts-design-review-blocked.json")
  old_skipped_artifacts_path.write(JSON.pretty_generate(old_skipped_artifacts_review) + "\n")
  assert_status(
    false,
    ["ruby", blocker_validator, old_skipped_artifacts_path, "--artifact-root", temp_root, "--unit-slug", "unit-contract"],
    "old skippedArtifacts design-review blocker"
  )

  temp_root.join("design-review.json").write(JSON.pretty_generate(base_design_review) + "\n")
  temp_root.join("screenshots").mkpath
  temp_root.join("screenshots/ios-mobile.png").write("stale")
  temp_root.join("screenshots/macos-desktop.png").write("stale")
  temp_root.join("apple/unit-contract-accessibility-proof-ios.json").write("{}\n")
  temp_root.join("apple/unit-contract-accessibility-proof-macos.json").write("{}\n")
  assert_status(
    false,
    ["ruby", blocker_validator, blocked_review_path, "--artifact-root", temp_root, "--unit-slug", "unit-contract"],
    "stale success artifacts with design-review blocker"
  )
end

unless $failures.empty?
  warn $failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end

puts "design accessibility contract ok"
