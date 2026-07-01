#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
ARTIFACT_ROOT = ROOT.join("tasks/2026-06-16-1754-doing-siri-full-access-parity")
DESIGN_REVIEW = ARTIFACT_ROOT.join("design-review.json")
DESIGN_REVIEW_BLOCKED = ARTIFACT_ROOT.join("design-review-blocked.json")

REQUIRED_REVIEW_FIELDS = [
  "mobileScreenshot",
  "desktopScreenshot",
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze

ACCESSIBILITY_REVIEW_FIELDS = [
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze

SCRIPT_CONTRACTS = {
  "scripts/smoke-macos.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--log",
      "--blocker",
      "smoke-macos.log",
      "smoke-macos-blocker.json",
      "apple/${unit_slug}-smoke-macos-inner.log",
      "apple/${unit_slug}-smoke-macos-blocker.json",
      "Spoonjoy.app",
      "xcodebuild -project Spoonjoy.xcodeproj",
      "generic/platform=macOS",
      "GCC_TREAT_WARNINGS_AS_ERRORS=YES",
      "open",
      "open location",
      "pkill -x Spoonjoy",
      "spoonjoy://search?q=${route_query}&scope=recipes",
      "lastOpenedRoute",
      "hasCompletedFirstRun",
      "native-app-state.json",
      "MacOSLaunch",
      "ownerAction"
    ]
  },
  "scripts/smoke-ios-simulator.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--log",
      "--blocker",
      "smoke-ios-simulator.log",
      "smoke-ios-simulator-blocker.json",
      "apple/${unit_slug}-smoke-ios-inner.log",
      "apple/${unit_slug}-smoke-ios-simulator-blocker.json",
      "xcrun simctl list runtimes",
      "xcrun simctl boot",
      "xcrun simctl uninstall",
      "xcrun simctl launch",
      "timeoutSeconds",
      "30",
      "CoreSimulator",
      ".github/scripts/resolve-ios-simulator-destination.py",
      "ownerAction"
    ]
  },
  "scripts/capture-native-screenshots.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--unit-slug",
      "screenshots/ios-mobile.png",
      "screenshots/macos-desktop.png",
      "design-review.json",
      "design-review-blocked.json",
      "rm -f \"$ios_screenshot\" \"$macos_screenshot\"",
      "rm -f \"$design_review_blocked\"",
      "rm -f \"$design_review\"",
      "xcrun simctl io",
      "scripts/find-macos-window-id.swift",
      "pgrep -x Spoonjoy",
      "capture_macos_window",
      "screencapture -x -l",
      "open location",
      "sleep 3",
      "to activate",
      "pkill -x Spoonjoy",
      "Retrying Spoonjoy window capture after relaunch",
      "Spoonjoy window not found for macOS screenshot capture",
      'screenshot_route="kitchen"',
      'screenshot_route="search"',
      'notification',
      'apns',
      "spoonjoy://$screenshot_route",
      "validate_ios_screenshot",
      "get_app_container",
      "native-durable-cache.json",
      "SPOONJOY_SCREENSHOT_AUTH",
      "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY",
      "SPOONJOY_SCREENSHOT_ACCOUNT_ID",
      "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS",
      "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS",
      "SPOONJOY_SCREENSHOT_PROOF_PATH",
      "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
      "wait_for_accessibility_proof",
      "validate_screenshot_surface_proof",
      "settingsSignedInSurface",
      "settingsVisualFocus",
      "settingsProfileSurface",
      "settingsNotificationAPNsSurface",
      "settingsSurfaceProofArtifacts",
      "visibleSections",
      "settingsSeedAccountID",
      "chef_settings_capture",
      "kitchenSignedInSurface",
      "kitchenSeedAccountID",
      "chef_kitchen_capture",
      "searchNativeSurface",
      "searchScopes",
      "searchSeedAccountID",
      "searchSurfaceProofArtifacts",
      "SearchView",
      "routeIdentifier",
      "chef_search_capture",
      "expected_recorded_route",
      "search:all:",
      "apns-status",
      "device_apns_capture",
      "screenshot-proof-ios.json",
      "screenshot-proof-macos.json",
      "lastOpenedRoute",
      "hasCompletedFirstRun",
      "native-app-state.json",
      "mobileScreenshot",
      "desktopScreenshot",
      "apple/${unit_slug}-screenshots.log",
      "screenshots-xcode-platform-blocker.json",
      "screenshots-core-simulator-blocker.json",
      "screenshots-macos-launch-blocker.json",
      "apple/${unit_slug}-screenshots-xcode-platform-blocker.json",
      "apple/${unit_slug}-screenshots-core-simulator-blocker.json",
      "apple/${unit_slug}-screenshots-macos-launch-blocker.json",
      "sourceBlockerPath",
      "skippedArtifacts",
      "conflicting design review success and blocker artifacts",
      "ownerAction"
    ]
  },
  "scripts/find-macos-window-id.swift" => {
    syntax: ["swiftc", "-parse"],
    tokens: [
      "CGWindowListCopyWindowInfo",
      "kCGWindowOwnerPID",
      "kCGWindowOwnerName",
      "ownerCandidates",
      "optionOnScreenOnly",
      "excludeDesktopElements",
      "localizedCaseInsensitiveContains",
      "No on-screen layer-0 window found"
    ]
  },
  "scripts/validate-design-review.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "JSON.parse",
      *REQUIRED_REVIEW_FIELDS,
      "screenshotRoute",
      "kitchenSignedInSurface",
      "searchNativeSurface",
      "searchScopes",
      "searchSurfaceProofArtifacts",
      "SearchView",
      "routeIdentifier",
      "settingsVisualFocus",
      "settingsProfileSurface",
      "settingsNotificationAPNsSurface",
      "settingsSurfaceProofArtifacts",
      "visibleSections",
      "SettingsView",
      "APNs Delivery",
      "Notification Sync"
    ]
  },
  "scripts/validate-design-review-blocker.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "JSON.parse",
      "--artifact-root",
      "--unit-slug",
      "blocked",
      "capability",
      "sourceBlockerPath",
      "skippedArtifacts",
      "reason",
      "ownerAction",
      'apple/#{unit_slug}-screenshots-xcode-platform-blocker.json',
      'apple/#{unit_slug}-screenshots-core-simulator-blocker.json',
      'apple/#{unit_slug}-screenshots-macos-launch-blocker.json',
      "screenshots-xcode-platform-blocker.json",
      "screenshots-core-simulator-blocker.json",
      "screenshots-macos-launch-blocker.json"
    ]
  },
  "scripts/fail-on-warning.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "warning:",
      "error:",
      "An error was encountered processing the command",
      "Underlying error",
      "failed to",
      "fatal error:",
      "uncaught exception",
      "warnings or error diagnostics found"
    ]
  }
}.freeze

$failures = []

def record_failure(message)
  $failures << message
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

def run_status(*args, env: {}, chdir: ROOT)
  stdout, stderr, status = Open3.capture3(env, *args.map(&:to_s), chdir: chdir.to_s)
  [stdout, stderr, status]
end

def assert_status(expected_success, args, label, env: {}, chdir: ROOT)
  stdout, stderr, status = run_status(*args, env: env, chdir: chdir)
  return if status.success? == expected_success

  expected = expected_success ? "succeed" : "fail"
  record_failure("#{label} expected to #{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
end

def write_executable(path, content)
  path.dirname.mkpath
  path.write(content)
  FileUtils.chmod("+x", path.to_s)
end

def assert_file(path, label)
  record_failure("#{label} expected #{path} to exist") unless path.file?
end

def assert_missing(path, label)
  record_failure("#{label} expected #{path} to be absent") if path.exist?
end

def assert_json(path, label)
  assert_file(path, label)
  return {} unless path.file?

  JSON.parse(path.read)
rescue JSON::ParserError => error
  record_failure("#{label} expected valid JSON at #{path}: #{error.message}")
  {}
end

def accessibility_source(route)
  case route
  when "kitchen"
    "KitchenView"
  when "search"
    "SearchView"
  when "settings"
    "SettingsView"
  else
    "KitchenView"
  end
end

def route_accessibility_evidence(route)
  case route
  when "search"
    {
      "voiceOverLabels" => ["Search", "row.accessibilityLabel"],
      "keyboardNavigationTargets" => ["typed rows", "SearchSurfaceSectionView buttons"],
      "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
      "contrastPairs" => ["charcoal on bone", "herb tint on bone"],
      "hierarchyAnchors" => ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView"],
      "layoutGuards" => ["text-fit", "no-tiny-clusters"]
    }
  when "settings"
    {
      "voiceOverLabels" => ["Settings", "Profile", "Security"],
      "keyboardNavigationTargets" => ["profile form fields", "security token controls"],
      "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
      "contrastPairs" => ["charcoal on bone", "brass label on bone"],
      "hierarchyAnchors" => ["SettingsView", "Form", "Section"],
      "layoutGuards" => ["text-fit", "no-tiny-clusters"]
    }
  else
    {
      "voiceOverLabels" => ["Spoonjoy Kitchen", "Open Recipe", "Start Cooking"],
      "keyboardNavigationTargets" => ["lead recipe actions", "recipe index buttons"],
      "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel"],
      "contrastPairs" => ["charcoal on bone", "white on photo overlay"],
      "hierarchyAnchors" => ["KitchenView", "KitchenMasthead", "RecipeLead"],
      "layoutGuards" => ["text-fit", "no-tiny-clusters"]
    }
  end
end

def add_accessibility_proofs!(root, manifest, stem)
  route = manifest["screenshotRoute"]
  return unless route

  relative_paths = [
    "apple/#{stem}-accessibility-proof-ios.json",
    "apple/#{stem}-accessibility-proof-macos.json"
  ]
  manifest["accessibilityProofArtifacts"] = relative_paths
  relative_paths.zip(["ios", "macos"]).each do |relative_path, platform|
    proof_path = root.join(relative_path)
    proof_path.dirname.mkpath
    proof_path.write(JSON.pretty_generate(
      ACCESSIBILITY_REVIEW_FIELDS.to_h { |field| [field, true] }.merge(
        "platform" => platform,
        "route" => route,
        "source" => accessibility_source(route),
        "emittedBy" => "SpoonjoyApp",
        "bundleIdentifier" => platform == "macos" ? "app.spoonjoy.Spoonjoy.mac" : "app.spoonjoy.Spoonjoy",
        "minimumTargetSize" => 44,
        "textFits" => true,
        "noTinyClusters" => true,
        "observedDynamicTypeSize" => "large",
        "observedReduceMotion" => false,
        "routeEvidence" => route_accessibility_evidence(route),
        "offlineIndicatorProof" => {
          "source" => "OfflineStatusView",
          "visibleStates" => ["offline", "stale", "queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"],
          "dismissibleStates" => ["offline", "stale"],
          "severeStates" => ["queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"],
          "hiddenStates" => ["synced", "dismissed"],
          "voiceOverLabel" => true,
          "dismissButtonLabel" => "Hide offline status",
          "severityCorrect" => true
        }
      )
    ) + "\n")
  end
end

SCRIPT_CONTRACTS.each do |relative_path, contract|
  path = ROOT.join(relative_path)
  unless path.file?
    record_failure("missing #{relative_path}")
    next
  end

  content = path.read
  bad_absolute_path_lines = [
    'app_path="$(pwd)/$app_path"',
    'macos_app="$(pwd)/$macos_app"'
  ]
  if content.lines.map(&:strip).any? { |line| bad_absolute_path_lines.include?(line) }
    record_failure("#{relative_path} must not prefix pwd onto app paths; absolute artifact roots must stay absolute")
  end

  missing_tokens = contract.fetch(:tokens).reject { |token| content.include?(token) }
  record_failure("#{relative_path} missing required tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?

  assert_status(true, [*contract.fetch(:syntax), path], "#{relative_path} syntax")
end

validator = ROOT.join("scripts/validate-design-review.rb")
blocker_validator = ROOT.join("scripts/validate-design-review-blocker.rb")

Dir.mktmpdir("spoonjoy-design-review-contract") do |directory|
  temp_root = Pathname.new(directory)
  valid_manifest = REQUIRED_REVIEW_FIELDS.to_h { |field| [field, true] }.merge(
    "blockers" => [],
    "screenshotRoute" => "kitchen",
    "kitchenSignedInSurface" => true,
    "kitchenSeedAccountID" => "chef_kitchen_capture"
  )
  valid_settings_manifest = REQUIRED_REVIEW_FIELDS.to_h { |field| [field, true] }.merge(
    "blockers" => [],
    "screenshotRoute" => "settings",
    "settingsSignedInSurface" => true,
    "settingsVisualFocus" => "notifications",
    "settingsNotificationAPNsSurface" => true,
    "settingsSeedAccountID" => "chef_settings_capture",
    "settingsSections" => ["Profile", "Security", "Notifications", "Device Notifications", "APNs Delivery", "Notification Sync"],
    "settingsSurfaceProofArtifacts" => ["apple/proof-ios.json", "apple/proof-macos.json"]
  )
  valid_profile_settings_manifest = REQUIRED_REVIEW_FIELDS.to_h { |field| [field, true] }.merge(
    "blockers" => [],
    "screenshotRoute" => "settings",
    "settingsSignedInSurface" => true,
    "settingsVisualFocus" => "profile",
    "settingsProfileSurface" => true,
    "settingsSeedAccountID" => "chef_settings_capture",
    "settingsSections" => ["Profile", "Security", "Notifications"],
    "settingsSurfaceProofArtifacts" => ["apple/profile-proof-ios.json", "apple/profile-proof-macos.json"]
  )
  valid_search_manifest = REQUIRED_REVIEW_FIELDS.to_h { |field| [field, true] }.merge(
    "blockers" => [],
    "screenshotRoute" => "search",
    "searchNativeSurface" => true,
    "searchScopes" => ["all", "recipes", "cookbooks", "chefs", "shopping-list"],
    "searchSeedAccountID" => "chef_search_capture",
    "searchSurfaceProofArtifacts" => ["apple/search-proof-ios.json", "apple/search-proof-macos.json"]
  )
  missing_manifest = valid_manifest.reject { |field, _| field == "mobileScreenshot" }
  false_without_blocker = valid_manifest.merge("mobileScreenshot" => false)
  missing_route_manifest = valid_manifest.reject { |field, _| field == "screenshotRoute" }
  signed_out_kitchen_manifest = valid_manifest.merge("kitchenSignedInSurface" => false)
  missing_search_scope_manifest = valid_search_manifest.merge("searchScopes" => ["all", "recipes"])
  missing_search_proof_manifest = valid_search_manifest.reject { |field, _| field == "searchSurfaceProofArtifacts" }
  stale_search_proof_manifest = valid_search_manifest.merge("searchSurfaceProofArtifacts" => ["apple/stale-search-proof-ios.json", "apple/search-proof-macos.json"])
  wrong_search_proof_manifest = valid_search_manifest.merge("searchSurfaceProofArtifacts" => ["apple/wrong-search-proof-ios.json", "apple/search-proof-macos.json"])
  missing_apns_settings_manifest = valid_settings_manifest.merge(
    "settingsNotificationAPNsSurface" => false,
    "settingsSections" => ["Profile", "Security", "Notifications"]
  )
  false_with_blocker = false_without_blocker.merge(
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30,
        "outputPath" => "tasks/2026-06-16-1754-doing-siri-full-access-parity/smoke-ios-simulator.log",
        "ownerAction" => "Install an available iPhone simulator runtime."
      }
    ]
  )
  desktop_false_with_only_ios_blocker = valid_manifest.merge(
    "desktopScreenshot" => false,
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30,
        "outputPath" => "tasks/2026-06-16-1754-doing-siri-full-access-parity/smoke-ios-simulator.log"
      }
    ]
  )
  bad_blocker = false_without_blocker.merge(
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30
      }
    ]
  )

  {
    "valid.json" => [valid_manifest, true, "valid design review"],
    "valid-search.json" => [valid_search_manifest, true, "valid search design review"],
    "valid-settings.json" => [valid_settings_manifest, true, "valid settings design review"],
    "valid-profile-settings.json" => [valid_profile_settings_manifest, true, "valid profile settings design review"],
    "missing.json" => [missing_manifest, false, "missing design review field"],
    "missing-route.json" => [missing_route_manifest, false, "missing screenshot route"],
    "signed-out-kitchen.json" => [signed_out_kitchen_manifest, false, "signed-out kitchen route artifact"],
    "missing-search-scopes.json" => [missing_search_scope_manifest, false, "search route scope artifact"],
    "missing-search-proof.json" => [missing_search_proof_manifest, false, "search route proof artifacts"],
    "stale-search-proof.json" => [stale_search_proof_manifest, false, "stale search route proof artifact"],
    "wrong-search-proof.json" => [wrong_search_proof_manifest, false, "wrong search route proof artifact"],
    "missing-apns-settings.json" => [missing_apns_settings_manifest, false, "settings APNs route artifact"],
    "false-without-blocker.json" => [false_without_blocker, false, "false field without blocker"],
    "false-with-blocker.json" => [false_with_blocker, false, "legacy inline screenshot blocker"],
    "desktop-false-with-ios-blocker.json" => [desktop_false_with_only_ios_blocker, false, "desktop false field with unrelated iOS blocker"],
    "bad-blocker.json" => [bad_blocker, false, "invalid blocker"]
  }.each do |filename, (manifest, expected_success, label)|
    path = temp_root.join(filename)
    add_accessibility_proofs!(temp_root, manifest, filename.delete_suffix(".json"))
    path.write(JSON.pretty_generate(manifest))
    if (proof_artifacts = manifest["settingsSurfaceProofArtifacts"])
      proof_artifacts.each do |proof_relative_path|
        proof_path = temp_root.join(proof_relative_path)
        proof_path.dirname.mkpath
        proof_path.write(JSON.pretty_generate(
          "route" => "settings",
          "visualFocus" => manifest.fetch("settingsVisualFocus"),
          "visibleSections" => manifest.fetch("settingsSections", []),
          "source" => "SettingsView"
        ) + "\n")
      end
    end
    if (proof_artifacts = manifest["searchSurfaceProofArtifacts"])
      proof_artifacts.each do |proof_relative_path|
        next if proof_relative_path.include?("stale")

        proof_path = temp_root.join(proof_relative_path)
        proof_path.dirname.mkpath
        proof_payload = {
          "route" => "search",
          "routeIdentifier" => "search:all:",
          "query" => "",
          "scope" => "all",
          "searchScopes" => ["all", "recipes", "cookbooks", "chefs", "shopping-list"],
          "accountID" => manifest.fetch("searchSeedAccountID", ""),
          "visibleSections" => ["Recipes", "Chefs"],
          "source" => "SearchView"
        }
        if proof_relative_path.include?("wrong")
          proof_payload["routeIdentifier"] = "search:recipes:tomato"
          proof_payload["searchScopes"] = ["all", "recipes"]
          proof_payload["visibleSections"] = ["Recipes"]
          proof_payload["source"] = "WrongSearchView"
        end
        proof_path.write(JSON.pretty_generate(proof_payload) + "\n")
      end
    end
    assert_status(expected_success, ["ruby", validator, path], label)
  end

  if blocker_validator.file?
    apple_dir = temp_root.join("apple")
    apple_dir.mkpath
    canonical_blocker = apple_dir.join("unit-16f-screenshot-contract-screenshots-core-simulator-blocker.json")
    canonical_blocker.write(JSON.pretty_generate(
      "blocked" => true,
      "capability" => "CoreSimulator",
      "command" => "xcrun simctl io booted screenshot",
      "timeoutSeconds" => 30,
      "outputPath" => "apple/unit-16f-screenshot-contract-screenshots.log",
      "reason" => "No booted simulator was available.",
      "ownerAction" => "Install and boot an iPhone simulator runtime."
    ) + "\n")

    valid_blocked_review = {
      "blocked" => true,
      "capability" => "CoreSimulator",
      "sourceBlockerPath" => canonical_blocker.to_s,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ios.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-macos.json"
      ],
      "reason" => "Screenshot capture was blocked by CoreSimulator.",
      "ownerAction" => "Install and boot an iPhone simulator runtime."
    }
    invalid_source_review = valid_blocked_review.merge(
      "sourceBlockerPath" => apple_dir.join("old-smoke-ios-simulator-blocker.json").to_s
    )
    top_level_source_review = valid_blocked_review.merge(
      "sourceBlockerPath" => temp_root.join("smoke-ios-simulator-blocker.json").to_s
    )
    false_blocked_review = valid_blocked_review.merge("blocked" => false)
    missing_capability_review = valid_blocked_review.reject { |key, _| key == "capability" }
    mismatched_capability_review = valid_blocked_review.merge("capability" => "MacOSLaunch")
    missing_skipped_review = valid_blocked_review.reject { |key, _| key == "skippedArtifacts" }
    incomplete_skipped_review = valid_blocked_review.merge(
      "skippedArtifacts" => ["screenshots/ios-mobile.png"]
    )
    missing_reason_review = valid_blocked_review.reject { |key, _| key == "reason" }
    missing_owner_action_review = valid_blocked_review.reject { |key, _| key == "ownerAction" }

    {
      "valid-blocked-review.json" => [valid_blocked_review, true, "valid design-review blocker"],
      "invalid-source-blocked-review.json" => [invalid_source_review, false, "noncanonical design-review blocker source"],
      "top-level-source-blocked-review.json" => [top_level_source_review, false, "top-level design-review blocker source"],
      "false-blocked-review.json" => [false_blocked_review, false, "design-review blocker blocked=false"],
      "missing-capability-blocked-review.json" => [missing_capability_review, false, "design-review blocker missing capability"],
      "mismatched-capability-blocked-review.json" => [mismatched_capability_review, false, "design-review blocker mismatched capability"],
      "missing-skipped-blocked-review.json" => [missing_skipped_review, false, "design-review blocker missing skippedArtifacts"],
      "incomplete-skipped-blocked-review.json" => [incomplete_skipped_review, false, "design-review blocker incomplete skippedArtifacts"],
      "missing-reason-blocked-review.json" => [missing_reason_review, false, "design-review blocker missing reason"],
      "missing-owner-action-blocked-review.json" => [missing_owner_action_review, false, "design-review blocker missing ownerAction"]
    }.each do |filename, (manifest, expected_success, label)|
      path = temp_root.join(filename)
      path.write(JSON.pretty_generate(manifest) + "\n")
      assert_status(
        expected_success,
        ["ruby", blocker_validator, path, "--artifact-root", temp_root, "--unit-slug", "unit-16f-screenshot-contract"],
        label
      )
    end

    design_review = temp_root.join("design-review.json")
    blocked_review = temp_root.join("design-review-blocked.json")
    design_review.write(JSON.pretty_generate(valid_manifest) + "\n")
    blocked_review.write(JSON.pretty_generate(valid_blocked_review) + "\n")
    assert_status(
      false,
      [
        "bash",
        "-lc",
        "set -euo pipefail; if [[ -f \"$1\" && -f \"$2\" ]]; then echo \"conflicting design review success and blocker artifacts\"; exit 1; fi",
        "design-review-conflict-check",
        design_review,
        blocked_review
      ],
      "conflicting design review success and blocker artifacts"
    )
  end
end

Dir.mktmpdir("spoonjoy-smoke-script-contract") do |directory|
  temp_root = Pathname.new(directory)
  artifact_root = temp_root.join("artifacts")
  apple_dir = artifact_root.join("apple")
  bin_dir = temp_root.join("bin")
  apple_dir.mkpath
  bin_dir.mkpath

  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    exit 70
  SH

  ios_log = apple_dir.join("unit-contract-smoke-ios-inner.log")
  ios_blocker = apple_dir.join("unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    true,
    [
      "bash",
      ROOT.join("scripts/smoke-ios-simulator.sh"),
      "--artifact-root",
      artifact_root,
      "--log",
      ios_log,
      "--blocker",
      ios_blocker
    ],
    "iOS smoke writes canonical CoreSimulator blocker",
    env: { "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" }
  )
  blocker = assert_json(ios_blocker, "iOS smoke canonical blocker")
  record_failure("iOS smoke blocker capability mismatch") unless blocker["capability"] == "CoreSimulator"
  record_failure("iOS smoke blocker missing ownerAction") unless blocker["ownerAction"].is_a?(String) && !blocker["ownerAction"].empty?
  record_failure("iOS smoke blocker outputPath mismatch") unless blocker["outputPath"] == ios_log.to_s

  write_executable(bin_dir.join("xcodebuild"), <<~'SH')
    #!/usr/bin/env bash
    derived=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "-derivedDataPath" ]]; then
        derived="$2"
        shift 2
      else
        shift
      fi
    done
    mkdir -p "$derived/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
    exit 0
  SH
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    case "$*" in
      "simctl list runtimes") exit 0 ;;
      simctl\ boot\ *|simctl\ bootstatus\ *) exit 0 ;;
      simctl\ install\ *) exit 0 ;;
      simctl\ launch\ *) exit 91 ;;
      *) exit 0 ;;
    esac
  SH
  script_root = temp_root.join("ios-launch-hard-fail")
  script_root.join("scripts").mkpath
  script_root.join(".github/scripts").mkpath
  FileUtils.cp(ROOT.join("scripts/smoke-ios-simulator.sh"), script_root.join("scripts/smoke-ios-simulator.sh"))
  write_executable(script_root.join(".github/scripts/resolve-ios-simulator-destination.py"), <<~'PY')
    #!/usr/bin/env python3
    print("platform=iOS Simulator,name=iPhone 16,id=SIM-UDID")
  PY
  hard_fail_artifacts = temp_root.join("hard-fail-artifacts")
  hard_fail_log = hard_fail_artifacts.join("apple/unit-contract-smoke-ios-inner.log")
  hard_fail_blocker = hard_fail_artifacts.join("apple/unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    false,
    [
      "bash",
      "scripts/smoke-ios-simulator.sh",
      "--artifact-root",
      hard_fail_artifacts,
      "--log",
      hard_fail_log,
      "--blocker",
      hard_fail_blocker
    ],
    "iOS app launch failure is a hard failure",
    env: { "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" },
    chdir: script_root
  )
  assert_missing(hard_fail_blocker, "iOS launch hard failure")

  write_executable(bin_dir.join("xcodebuild"), <<~'SH')
    #!/usr/bin/env bash
    derived=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "-derivedDataPath" ]]; then
        derived="$2"
        shift 2
      else
        shift
      fi
    done
    mkdir -p "$derived/Build/Products/BootstrapDebug/Spoonjoy.app"
    exit 0
  SH
  write_executable(bin_dir.join("osascript"), <<~'SH')
    #!/usr/bin/env bash
    exit 2
  SH
  macos_log = apple_dir.join("unit-contract-smoke-macos-inner.log")
  macos_blocker = apple_dir.join("unit-contract-smoke-macos-blocker.json")
  assert_status(
    true,
    [
      "bash",
      ROOT.join("scripts/smoke-macos.sh"),
      "--artifact-root",
      artifact_root,
      "--log",
      macos_log,
      "--blocker",
      macos_blocker
    ],
    "macOS smoke writes canonical MacOSLaunch blocker",
    env: { "HOME" => temp_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" }
  )
  macos_blocker_json = assert_json(macos_blocker, "macOS smoke canonical blocker")
  record_failure("macOS smoke blocker capability mismatch") unless macos_blocker_json["capability"] == "MacOSLaunch"
  record_failure("macOS smoke blocker missing ownerAction") unless macos_blocker_json["ownerAction"].is_a?(String) && !macos_blocker_json["ownerAction"].empty?
  record_failure("macOS smoke blocker outputPath mismatch") unless macos_blocker_json["outputPath"] == macos_log.to_s
end

Dir.mktmpdir("spoonjoy-capture-script-contract") do |directory|
  temp_root = Pathname.new(directory)
  script_root = temp_root.join("app")
  artifact_root = script_root.join("artifacts")
  scripts_dir = script_root.join("scripts")
  bin_dir = script_root.join("bin")
  scripts_dir.mkpath
  bin_dir.mkpath
  FileUtils.cp(ROOT.join("scripts/capture-native-screenshots.sh"), scripts_dir.join("capture-native-screenshots.sh"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review.rb"), scripts_dir.join("validate-design-review.rb"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review-blocker.rb"), scripts_dir.join("validate-design-review-blocker.rb"))

  blocker_stub = lambda do |capability|
    <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      blocker=""
      log=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --blocker) blocker="$2"; shift 2 ;;
          --log) log="$2"; shift 2 ;;
          --artifact-root) shift 2 ;;
          *) shift ;;
        esac
      done
      mkdir -p "$(dirname "$blocker")" "$(dirname "$log")"
      printf blocked > "$log"
      ruby -rjson -e 'path, capability, log_path = ARGV; File.write(path, JSON.pretty_generate({blocked: true, capability: capability, command: "simulated runtime blocker", timeoutSeconds: 30, outputPath: log_path, reason: "Simulated runtime blocker.", ownerAction: "Satisfy the simulated local runtime capability."}) + "\\n")' "$blocker" "#{capability}" "$log"
      exit 0
    SH
  end
  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), blocker_stub.call("CoreSimulator"))
  write_executable(scripts_dir.join("smoke-macos.sh"), blocker_stub.call("MacOSLaunch"))

  artifact_root.join("screenshots").mkpath
  artifact_root.join("design-review.json").write("{}\n")
  artifact_root.join("design-review-blocked.json").write("{}\n")
  artifact_root.join("screenshots/ios-mobile.png").write("stale")
  artifact_root.join("screenshots/macos-desktop.png").write("stale")
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot blocker lane",
    env: { "HOME" => script_root.join("home").to_s },
    chdir: script_root
  )
  blocked_review = assert_json(artifact_root.join("design-review-blocked.json"), "screenshot blocked review")
  expected_source = artifact_root.join("apple/unit-contract-screenshots-core-simulator-blocker.json").expand_path.to_s
  record_failure("screenshot blocker source path mismatch") unless blocked_review["sourceBlockerPath"] == expected_source
  assert_missing(artifact_root.join("design-review.json"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-mobile.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/macos-desktop.png"), "screenshot blocker lane")

  success_stub = <<~'SH'
    #!/usr/bin/env bash
    set -euo pipefail
    log=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --log) log="$2"; shift 2 ;;
        --blocker) shift 2 ;;
        --artifact-root) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$log")"
    printf 'Booting simulator: xcrun simctl boot ABCDEF12-3456-7890-ABCD-1234567890AB\nok\n' > "$log"
  SH
  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), success_stub)
  write_executable(scripts_dir.join("smoke-macos.sh"), success_stub)
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    write_accessibility_proof() {
      local output_path="$1"
      local route="$2"
      local platform="$3"
      local bundle="$4"
      local source="$5"
      if [[ "${SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        return 0
      fi
      if [[ "${SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        source="WrongAccessibilityView"
      fi
      route_evidence='{"voiceOverLabels":["Spoonjoy Kitchen","Open Recipe","Start Cooking"],"keyboardNavigationTargets":["lead recipe actions","recipe index buttons"],"dynamicTypeTextStyles":["KitchenTableTheme.displayTitle","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","white on photo overlay"],"hierarchyAnchors":["KitchenView","KitchenMasthead","RecipeLead"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
      case "$route" in
        search)
          route_evidence='{"voiceOverLabels":["Search","row.accessibilityLabel"],"keyboardNavigationTargets":["typed rows","SearchSurfaceSectionView buttons"],"dynamicTypeTextStyles":["KitchenTableTheme.bodyNote","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","herb tint on bone"],"hierarchyAnchors":["SearchView","SearchSurfaceContract.searchableScopes","SearchSurfaceContract.typedRows","SearchSurfaceSectionView","SearchSurfaceRowView"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
          ;;
        settings)
          route_evidence='{"voiceOverLabels":["Settings","Profile","Security"],"keyboardNavigationTargets":["profile form fields","security token controls"],"dynamicTypeTextStyles":["KitchenTableTheme.bodyNote","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","brass label on bone"],"hierarchyAnchors":["SettingsView","Form","Section"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
          ;;
      esac
      mkdir -p "$(dirname "$output_path")"
      printf '{"platform":"%s","route":"%s","source":"%s","dynamicType":true,"voiceOverLabels":true,"keyboardNavigation":true,"reduceMotion":true,"contrast":true,"kitchenTableHierarchy":true,"noOverlap":true,"minimumTargetSize":44,"textFits":true,"noTinyClusters":true,"observedDynamicTypeSize":"large","observedReduceMotion":false,"routeEvidence":%s,"offlineIndicatorProof":{"source":"OfflineStatusView","visibleStates":["offline","stale","queuedWork","syncFailure","conflict","blocker","destructiveConfirmation"],"dismissibleStates":["offline","stale"],"severeStates":["queuedWork","syncFailure","conflict","blocker","destructiveConfirmation"],"hiddenStates":["synced","dismissed"],"voiceOverLabel":true,"dismissButtonLabel":"Hide offline status","severityCorrect":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"%s"}\n' "$platform" "$route" "$source" "$route_evidence" "$bundle" > "$output_path"
    }
    case "$*" in
      simctl\ get_app_container\ *)
        mkdir -p "$PWD/ios-container/Library/Application Support/Spoonjoy"
        printf '%s\n' "$PWD/ios-container"
        ;;
      simctl\ launch\ *)
        if [[ -n "${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH:-}" ]]; then
          accessibility_route="kitchen"
          accessibility_source="KitchenView"
          case "${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID:-}" in
            chef_search_capture)
              accessibility_route="search"
              accessibility_source="SearchView"
              ;;
            chef_settings_capture)
              accessibility_route="settings"
              accessibility_source="SettingsView"
              ;;
          esac
          write_accessibility_proof "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH" "$accessibility_route" "ios" "app.spoonjoy.Spoonjoy" "$accessibility_source"
        fi
        if [[ -n "${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH:-}" ]]; then
          account_id="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID:-}"
          if [[ "$account_id" == "chef_search_capture" ]]; then
            if [[ "${SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF:-}" != "1" ]]; then
              mkdir -p "$(dirname "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH")"
              route_identifier="search:all:"
              source="SearchView"
              scopes='["all","recipes","cookbooks","chefs","shopping-list"]'
              sections='["Recipes","Chefs"]'
              if [[ "${SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF:-}" == "1" ]]; then
                route_identifier="search:recipes:tomato"
                source="WrongSearchView"
                scopes='["all","recipes"]'
                sections='["Recipes"]'
              fi
              printf '{"route":"search","routeIdentifier":"%s","query":"","scope":"all","searchScopes":%s,"accountID":"%s","visibleSections":%s,"source":"%s"}\n' "$route_identifier" "$scopes" "$account_id" "$sections" "$source" > "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH"
            fi
          else
            mkdir -p "$(dirname "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH")"
            focus="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SETTINGS_FOCUS:-profile}"
            route="settings"
            source="SettingsView"
            sections='["Profile","Security"]'
            if [[ "${SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF:-}" == "1" ]]; then
              route="kitchen"
              focus="profile"
              source="WrongView"
              sections='["Kitchen"]'
            elif [[ "$focus" == "notifications" ]]; then
              sections='["Notifications","Device Notifications","APNs Delivery","Notification Sync"]'
            fi
            printf '{"route":"%s","visualFocus":"%s","visibleSections":%s,"source":"%s"}\n' "$route" "$focus" "$sections" "$source" > "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH"
          fi
        fi
        printf 'app.spoonjoy.Spoonjoy: 12345\n'
        ;;
      simctl\ terminate\ *)
        exit 0
        ;;
      simctl\ spawn\ *\ log\ show*)
        printf 'Front display did change: <SBApplication; app.spoonjoy.Spoonjoy>\n'
        ;;
      simctl\ io\ *\ screenshot\ *)
        out="${@: -1}"
        mkdir -p "$(dirname "$out")"
        python3 - "$out" <<'PY'
import binascii
import struct
import sys
import zlib

path = sys.argv[1]
width, height = 400, 800
rows = []
for y in range(height):
    row = bytearray()
    for _ in range(width):
        row.extend((246, 239, 225))
    rows.append(b"\x00" + bytes(row))

def chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xffffffff)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows)))
png += chunk(b"IEND", b"")
with open(path, "wb") as handle:
    handle.write(png)
PY
        ;;
      *)
        exit 0
        ;;
    esac
  SH
  write_executable(bin_dir.join("osascript"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    script="$*"
    if [[ "$script" == *"open location"* ]]; then
      state="$HOME/Library/Application Support/Spoonjoy/native-app-state.json"
      mkdir -p "$(dirname "$state")"
      route="kitchen"
      if [[ "$script" == *"spoonjoy://settings"* ]]; then
        route="settings"
      elif [[ "$script" == *"spoonjoy://search"* ]]; then
        route="search:all:"
      fi
      printf '{"hasCompletedFirstRun":true,"lastOpenedRoute":"%s"}\n' "$route" > "$state"
    fi
  SH
  write_executable(bin_dir.join("open"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    write_accessibility_proof() {
      local output_path="$1"
      local route="$2"
      local platform="$3"
      local bundle="$4"
      local source="$5"
      if [[ "${SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        return 0
      fi
      if [[ "${SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        source="WrongAccessibilityView"
      fi
      route_evidence='{"voiceOverLabels":["Spoonjoy Kitchen","Open Recipe","Start Cooking"],"keyboardNavigationTargets":["lead recipe actions","recipe index buttons"],"dynamicTypeTextStyles":["KitchenTableTheme.displayTitle","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","white on photo overlay"],"hierarchyAnchors":["KitchenView","KitchenMasthead","RecipeLead"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
      case "$route" in
        search)
          route_evidence='{"voiceOverLabels":["Search","row.accessibilityLabel"],"keyboardNavigationTargets":["typed rows","SearchSurfaceSectionView buttons"],"dynamicTypeTextStyles":["KitchenTableTheme.bodyNote","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","herb tint on bone"],"hierarchyAnchors":["SearchView","SearchSurfaceContract.searchableScopes","SearchSurfaceContract.typedRows","SearchSurfaceSectionView","SearchSurfaceRowView"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
          ;;
        settings)
          route_evidence='{"voiceOverLabels":["Settings","Profile","Security"],"keyboardNavigationTargets":["profile form fields","security token controls"],"dynamicTypeTextStyles":["KitchenTableTheme.bodyNote","KitchenTableTheme.uiLabel"],"contrastPairs":["charcoal on bone","brass label on bone"],"hierarchyAnchors":["SettingsView","Form","Section"],"layoutGuards":["text-fit","no-tiny-clusters"]}'
          ;;
      esac
      mkdir -p "$(dirname "$output_path")"
      printf '{"platform":"%s","route":"%s","source":"%s","dynamicType":true,"voiceOverLabels":true,"keyboardNavigation":true,"reduceMotion":true,"contrast":true,"kitchenTableHierarchy":true,"noOverlap":true,"minimumTargetSize":44,"textFits":true,"noTinyClusters":true,"observedDynamicTypeSize":"large","observedReduceMotion":false,"routeEvidence":%s,"offlineIndicatorProof":{"source":"OfflineStatusView","visibleStates":["offline","stale","queuedWork","syncFailure","conflict","blocker","destructiveConfirmation"],"dismissibleStates":["offline","stale"],"severeStates":["queuedWork","syncFailure","conflict","blocker","destructiveConfirmation"],"hiddenStates":["synced","dismissed"],"voiceOverLabel":true,"dismissButtonLabel":"Hide offline status","severityCorrect":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"%s"}\n' "$platform" "$route" "$source" "$route_evidence" "$bundle" > "$output_path"
    }
    proof_path=""
    accessibility_proof_path=""
    focus="profile"
    account_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --env)
          env_pair="$2"
          case "$env_pair" in
            SPOONJOY_SCREENSHOT_ACCOUNT_ID=*) account_id="${env_pair#SPOONJOY_SCREENSHOT_ACCOUNT_ID=}" ;;
            SPOONJOY_SCREENSHOT_PROOF_PATH=*) proof_path="${env_pair#SPOONJOY_SCREENSHOT_PROOF_PATH=}" ;;
            SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=*) accessibility_proof_path="${env_pair#SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=}" ;;
            SPOONJOY_SCREENSHOT_SETTINGS_FOCUS=*) focus="${env_pair#SPOONJOY_SCREENSHOT_SETTINGS_FOCUS=}" ;;
          esac
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ -n "$proof_path" ]]; then
      if [[ "$account_id" == "chef_search_capture" ]]; then
        if [[ "${SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF:-}" != "1" ]]; then
          mkdir -p "$(dirname "$proof_path")"
          route_identifier="search:all:"
          source="SearchView"
          scopes='["all","recipes","cookbooks","chefs","shopping-list"]'
          sections='["Recipes","Chefs"]'
          if [[ "${SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF:-}" == "1" ]]; then
            route_identifier="search:recipes:tomato"
            source="WrongSearchView"
            scopes='["all","recipes"]'
            sections='["Recipes"]'
          fi
          printf '{"route":"search","routeIdentifier":"%s","query":"","scope":"all","searchScopes":%s,"accountID":"%s","visibleSections":%s,"source":"%s"}\n' "$route_identifier" "$scopes" "$account_id" "$sections" "$source" > "$proof_path"
        fi
      else
        mkdir -p "$(dirname "$proof_path")"
        route="settings"
        source="SettingsView"
        sections='["Profile","Security"]'
        if [[ "${SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF:-}" == "1" ]]; then
          route="kitchen"
          focus="profile"
          source="WrongView"
          sections='["Kitchen"]'
        elif [[ "$focus" == "notifications" ]]; then
          sections='["Notifications","Device Notifications","APNs Delivery","Notification Sync"]'
        fi
        printf '{"route":"%s","visualFocus":"%s","visibleSections":%s,"source":"%s"}\n' "$route" "$focus" "$sections" "$source" > "$proof_path"
      fi
    fi
    if [[ -n "$accessibility_proof_path" ]]; then
      accessibility_route="kitchen"
      accessibility_source="KitchenView"
      case "$account_id" in
        chef_search_capture)
          accessibility_route="search"
          accessibility_source="SearchView"
          ;;
        chef_settings_capture)
          accessibility_route="settings"
          accessibility_source="SettingsView"
          ;;
      esac
      write_accessibility_proof "$accessibility_proof_path" "$accessibility_route" "macos" "app.spoonjoy.Spoonjoy.mac" "$accessibility_source"
    fi
  SH
  write_executable(bin_dir.join("pgrep"), "#!/usr/bin/env bash\nprintf '12345\\n'\n")
  write_executable(bin_dir.join("swift"), "#!/usr/bin/env bash\nprintf '67890\\n'\n")
  write_executable(bin_dir.join("screencapture"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    out="${@: -1}"
    mkdir -p "$(dirname "$out")"
    printf mac-image > "$out"
  SH

  artifact_root.join("design-review-blocked.json").write("{}\n")
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot success lane",
    env: { "HOME" => script_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" },
    chdir: script_root
  )
  assert_file(artifact_root.join("design-review.json"), "screenshot success lane")
  assert_missing(artifact_root.join("design-review-blocked.json"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-mobile.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/macos-desktop.png"), "screenshot success lane")
  kitchen_review = assert_json(artifact_root.join("design-review.json"), "kitchen screenshot success lane")
  record_failure("kitchen screenshot route mismatch") unless kitchen_review["screenshotRoute"] == "kitchen"
  record_failure("kitchen screenshot missing signed-in surface flag") unless kitchen_review["kitchenSignedInSurface"] == true
  record_failure("kitchen screenshot account seed mismatch") unless kitchen_review["kitchenSeedAccountID"] == "chef_kitchen_capture"
  record_failure("kitchen screenshot missing accessibility proof artifacts") unless kitchen_review.fetch("accessibilityProofArtifacts", []).length >= 2
  kitchen_review.fetch("accessibilityProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "kitchen accessibility proof artifact")
    record_failure("kitchen accessibility proof source mismatch") unless proof["source"] == "KitchenView"
    record_failure("kitchen accessibility proof missing offline proof") unless proof["offlineIndicatorProof"].is_a?(Hash)
  end
  kitchen_cache_json = assert_json(script_root.join("ios-container/Library/Application Support/Spoonjoy/native-durable-cache.json"), "kitchen iOS cache seed")
  record_failure("kitchen cache seed account mismatch") unless kitchen_cache_json["accountID"] == "chef_kitchen_capture"
  record_failure("kitchen cache seed missing recipe detail") unless kitchen_cache_json.fetch("records", []).any? { |record| record["id"] == "recipe-detail:recipe_lemon_pantry_pasta" }

  missing_accessibility_root = temp_root.join("missing-accessibility-proof-artifacts")
  missing_accessibility_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      missing_accessibility_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot missing accessibility proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(missing_accessibility_root.join("design-review.json"), "screenshot missing accessibility proof lane")
  missing_accessibility_blocked_review = assert_json(missing_accessibility_root.join("design-review-blocked.json"), "screenshot missing accessibility proof lane")
  record_failure("missing accessibility proof lane did not block screenshot success") unless missing_accessibility_blocked_review["blocked"] == true

  wrong_accessibility_root = temp_root.join("wrong-accessibility-proof-artifacts")
  wrong_accessibility_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_accessibility_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot wrong accessibility proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_accessibility_root.join("design-review.json"), "screenshot wrong accessibility proof lane")
  wrong_accessibility_blocked_review = assert_json(wrong_accessibility_root.join("design-review-blocked.json"), "screenshot wrong accessibility proof lane")
  record_failure("wrong accessibility proof lane did not block screenshot success") unless wrong_accessibility_blocked_review["blocked"] == true

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot success lane",
    env: { "HOME" => script_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" },
    chdir: script_root
  )
  search_review = assert_json(artifact_root.join("design-review.json"), "search screenshot success lane")
  record_failure("search screenshot route mismatch") unless search_review["screenshotRoute"] == "search"
  record_failure("search screenshot missing native surface flag") unless search_review["searchNativeSurface"] == true
  record_failure("search screenshot account seed mismatch") unless search_review["searchSeedAccountID"] == "chef_search_capture"
  record_failure("search screenshot scopes mismatch") unless search_review["searchScopes"] == ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
  record_failure("search screenshot missing proof artifacts") unless search_review.fetch("searchSurfaceProofArtifacts", []).length >= 2
  search_review.fetch("searchSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "search screenshot proof artifact")
    record_failure("search screenshot proof route mismatch") unless proof["route"] == "search"
    record_failure("search screenshot proof route identifier mismatch") unless proof["routeIdentifier"] == "search:all:"
    record_failure("search screenshot proof query mismatch") unless proof["query"] == ""
    record_failure("search screenshot proof scope mismatch") unless proof["scope"] == "all"
    record_failure("search screenshot proof scopes mismatch") unless proof["searchScopes"] == ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
    record_failure("search screenshot proof account mismatch") unless proof["accountID"] == "chef_search_capture"
    record_failure("search screenshot proof missing Recipes") unless proof.fetch("visibleSections", []).include?("Recipes")
    record_failure("search screenshot proof missing Chefs") unless proof.fetch("visibleSections", []).include?("Chefs")
    record_failure("search screenshot proof source mismatch") unless proof["source"] == "SearchView"
  end
  search_cache_json = assert_json(script_root.join("ios-container/Library/Application Support/Spoonjoy/native-durable-cache.json"), "search iOS cache seed")
  record_failure("search cache seed account mismatch") unless search_cache_json["accountID"] == "chef_search_capture"

  wrong_search_proof_root = temp_root.join("wrong-search-proof-artifacts")
  wrong_search_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_search_proof_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot wrong proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_search_proof_root.join("design-review.json"), "search screenshot wrong proof lane")
  wrong_search_blocked_review = assert_json(wrong_search_proof_root.join("design-review-blocked.json"), "search screenshot wrong proof lane")
  record_failure("wrong search proof lane did not block screenshot success") unless wrong_search_blocked_review["blocked"] == true

  missing_search_proof_root = temp_root.join("missing-search-proof-artifacts")
  missing_search_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      missing_search_proof_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot missing proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(missing_search_proof_root.join("design-review.json"), "search screenshot missing proof lane")
  missing_search_blocked_review = assert_json(missing_search_proof_root.join("design-review-blocked.json"), "search screenshot missing proof lane")
  record_failure("missing search proof lane did not block screenshot success") unless missing_search_blocked_review["blocked"] == true

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-settings"
    ],
    "settings screenshot success lane",
    env: { "HOME" => script_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" },
    chdir: script_root
  )
  settings_review = assert_json(artifact_root.join("design-review.json"), "settings screenshot success lane")
  record_failure("settings screenshot route mismatch") unless settings_review["screenshotRoute"] == "settings"
  record_failure("settings screenshot missing signed-in surface flag") unless settings_review["settingsSignedInSurface"] == true
  record_failure("settings screenshot focus mismatch") unless settings_review["settingsVisualFocus"] == "profile"
  record_failure("settings screenshot missing profile surface flag") unless settings_review["settingsProfileSurface"] == true
  record_failure("settings screenshot account seed mismatch") unless settings_review["settingsSeedAccountID"] == "chef_settings_capture"
  record_failure("settings screenshot missing proof artifacts") unless settings_review.fetch("settingsSurfaceProofArtifacts", []).length >= 2
  settings_review.fetch("settingsSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "settings screenshot proof artifact")
    record_failure("settings screenshot proof route mismatch") unless proof["route"] == "settings"
    record_failure("settings screenshot proof focus mismatch") unless proof["visualFocus"] == "profile"
    record_failure("settings screenshot proof source mismatch") unless proof["source"] == "SettingsView"
  end
  cache_json = assert_json(script_root.join("ios-container/Library/Application Support/Spoonjoy/native-durable-cache.json"), "settings iOS cache seed")
  record_failure("settings cache seed account mismatch") unless cache_json["accountID"] == "chef_settings_capture"
  record_failure("settings cache seed missing token metadata") unless cache_json.fetch("records", []).any? { |record| record["id"] == "token-metadata" }
  record_failure("settings cache seed missing APNs status") unless cache_json.fetch("records", []).any? { |record| record["id"] == "apns-status" }

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-notifications"
    ],
    "notification screenshot success lane",
    env: { "HOME" => script_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" },
    chdir: script_root
  )
  notification_review = assert_json(artifact_root.join("design-review.json"), "notification screenshot success lane")
  record_failure("notification screenshot route mismatch") unless notification_review["screenshotRoute"] == "settings"
  record_failure("notification screenshot focus mismatch") unless notification_review["settingsVisualFocus"] == "notifications"
  record_failure("notification screenshot missing APNs surface flag") unless notification_review["settingsNotificationAPNsSurface"] == true
  record_failure("notification screenshot missing APNs delivery section") unless notification_review.fetch("settingsSections", []).include?("APNs Delivery")
  record_failure("notification screenshot missing proof artifacts") unless notification_review.fetch("settingsSurfaceProofArtifacts", []).length >= 2
  notification_review.fetch("settingsSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "notification screenshot proof artifact")
    record_failure("notification screenshot proof route mismatch") unless proof["route"] == "settings"
    record_failure("notification screenshot proof focus mismatch") unless proof["visualFocus"] == "notifications"
    record_failure("notification screenshot proof missing APNs delivery") unless proof.fetch("visibleSections", []).include?("APNs Delivery")
    record_failure("notification screenshot proof source mismatch") unless proof["source"] == "SettingsView"
  end

  wrong_proof_root = temp_root.join("wrong-proof-artifacts")
  wrong_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_proof_root,
      "--unit-slug",
      "unit-contract-notifications"
    ],
    "notification screenshot wrong proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_proof_root.join("design-review.json"), "notification screenshot wrong proof lane")
  wrong_blocked_review = assert_json(wrong_proof_root.join("design-review-blocked.json"), "notification screenshot wrong proof lane")
  record_failure("wrong proof lane did not block screenshot success") unless wrong_blocked_review["blocked"] == true
end

if DESIGN_REVIEW.file? && DESIGN_REVIEW_BLOCKED.file?
  record_failure("conflicting repository design review success and blocker artifacts")
elsif DESIGN_REVIEW.file?
  assert_status(true, ["ruby", validator, DESIGN_REVIEW], "repository design review manifest")
elsif DESIGN_REVIEW_BLOCKED.file?
  assert_status(
    true,
    ["ruby", blocker_validator, DESIGN_REVIEW_BLOCKED, "--artifact-root", ARTIFACT_ROOT, "--unit-slug", "matrix"],
    "repository design review blocker manifest"
  )
else
  # The full validation matrix deletes runtime screenshot artifacts before it
  # runs this source-contract check. The capture/design-review rows own the
  # final repository artifact validation after the runtime attempt finishes.
end

unless $failures.empty?
  warn $failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end

puts "launch screenshot contract ok"
