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
      "smoke-macos.log",
      "smoke-macos-blocker.json",
      "Spoonjoy.app",
      "xcodebuild -project Spoonjoy.xcodeproj",
      "generic/platform=macOS",
      "CODE_SIGNING_ALLOWED=NO",
      "open",
      "MacOSLaunch"
    ]
  },
  "scripts/smoke-ios-simulator.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "smoke-ios-simulator.log",
      "smoke-ios-simulator-blocker.json",
      "xcrun simctl list runtimes",
      "xcrun simctl boot",
      "xcrun simctl launch",
      "timeoutSeconds",
      "30",
      "CoreSimulator",
      ".github/scripts/resolve-ios-simulator-destination.py"
    ]
  },
  "scripts/capture-native-screenshots.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "screenshots/ios-mobile.png",
      "screenshots/macos-desktop.png",
      "design-review.json",
      "xcrun simctl io",
      "screencapture",
      "mobileScreenshot",
      "desktopScreenshot"
    ]
  },
  "scripts/validate-design-review.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "JSON.parse",
      "blockers",
      "capability",
      "command",
      "timeoutSeconds",
      "outputPath",
      *REQUIRED_REVIEW_FIELDS
    ]
  }
}.freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
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
  fail_check("#{label} expected to #{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
end

SCRIPT_CONTRACTS.each do |relative_path, contract|
  path = ROOT.join(relative_path)
  fail_check("missing #{relative_path}") unless path.file?

  content = path.read
  missing_tokens = contract.fetch(:tokens).reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?

  assert_status(true, [*contract.fetch(:syntax), path], "#{relative_path} syntax")
end

validator = ROOT.join("scripts/validate-design-review.rb")

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
        "outputPath" => "tasks/2026-06-15-2314-doing-native-app-skeleton/smoke-ios-simulator.log"
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
    "false-with-blocker.json" => [false_with_blocker, true, "false field with blocker"],
    "desktop-false-with-ios-blocker.json" => [desktop_false_with_only_ios_blocker, false, "desktop false field with unrelated iOS blocker"],
    "bad-blocker.json" => [bad_blocker, false, "invalid blocker"]
  }.each do |filename, (manifest, expected_success, label)|
    path = temp_root.join(filename)
    path.write(JSON.pretty_generate(manifest))
    assert_status(expected_success, ["ruby", validator, path], label)
  end
end

fail_check("missing #{relative(DESIGN_REVIEW)}") unless DESIGN_REVIEW.file?
assert_status(true, ["ruby", validator, DESIGN_REVIEW], "repository design review manifest")

puts "launch screenshot contract ok"
