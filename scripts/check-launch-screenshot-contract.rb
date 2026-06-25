#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
ARTIFACT_ROOT = ROOT.join("tasks/2026-06-15-2314-doing-native-app-skeleton")
DESIGN_REVIEW = ARTIFACT_ROOT.join("design-review.json")

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
      "CODE_SIGNING_ALLOWED=NO",
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
      "spoonjoy://kitchen",
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
      *REQUIRED_REVIEW_FIELDS
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
  }
}.freeze

$failures = []

def record_failure(message)
  $failures << message
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

def run_status(*args)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: ROOT.to_s)
  [stdout, stderr, status]
end

def assert_status(expected_success, args, label)
  stdout, stderr, status = run_status(*args)
  return if status.success? == expected_success

  expected = expected_success ? "succeed" : "fail"
  record_failure("#{label} expected to #{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
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
  valid_manifest = REQUIRED_REVIEW_FIELDS.to_h { |field| [field, true] }.merge("blockers" => [])
  missing_manifest = valid_manifest.reject { |field, _| field == "mobileScreenshot" }
  false_without_blocker = valid_manifest.merge("mobileScreenshot" => false)
  false_with_blocker = false_without_blocker.merge(
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30,
        "outputPath" => "tasks/2026-06-15-2314-doing-native-app-skeleton/smoke-ios-simulator.log",
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
        "outputPath" => "tasks/2026-06-15-2314-doing-native-app-skeleton/smoke-ios-simulator.log"
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
    "missing.json" => [missing_manifest, false, "missing design review field"],
    "false-without-blocker.json" => [false_without_blocker, false, "false field without blocker"],
    "false-with-blocker.json" => [false_with_blocker, false, "legacy inline screenshot blocker"],
    "desktop-false-with-ios-blocker.json" => [desktop_false_with_only_ios_blocker, false, "desktop false field with unrelated iOS blocker"],
    "bad-blocker.json" => [bad_blocker, false, "invalid blocker"]
  }.each do |filename, (manifest, expected_success, label)|
    path = temp_root.join(filename)
    path.write(JSON.pretty_generate(manifest))
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
        "design-review.json"
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

if DESIGN_REVIEW.file?
  assert_status(true, ["ruby", validator, DESIGN_REVIEW], "repository design review manifest")
else
  record_failure("missing #{relative(DESIGN_REVIEW)}")
end

unless $failures.empty?
  warn $failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end

puts "launch screenshot contract ok"
