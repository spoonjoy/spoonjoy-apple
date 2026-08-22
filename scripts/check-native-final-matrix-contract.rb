#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "open3"
require "tmpdir"
require "digest"
require "json"
require "fileutils"

ROOT = Pathname.new(__dir__).join("..").expand_path
SCRIPT_PATH = ROOT.join("scripts/validate-native-local.sh")
MATRIX_SCRIPT_PATH = ROOT.join("scripts/capture-native-screenshot-matrix.sh")

APP_INTENTS_DOMAINS = [
  "recipe-cookbook",
  "shopping",
  "spoon",
  "capture-draft",
  "chef-profile",
  "spotlight-shortcuts",
  "open-search-share-cook",
  "recipe-action",
  "shopping-intents",
  "spoon-intents",
  "capture-import-intents",
  "cookbook-intents",
  "profile-settings-intents",
  "notification-intents"
].freeze

FINAL_MATRIX_ARTIFACT_TOKENS = [
  "matrix-swift-test.log",
  "matrix-coverage-test.log",
  "matrix-coverage-enforce.log",
  "matrix-final-scenario.log",
  "matrix-project-contract.log",
  "matrix-generator-contract.log",
  "matrix-native-design-contract.log",
  "matrix-kitchen-surfaces-contract.log",
  "matrix-cook-shopping-contract.log",
  "matrix-search-capture-contract.log",
  "matrix-native-password-dogfood.log",
  "matrix-native-password-dogfood-report.json",
  "matrix-capture.log",
  "matrix-route-matrix.json",
  "matrix-design-review.log",
  "matrix-xcode-version.log",
  "matrix-xcodebuild-ios.log",
  "matrix-xcodebuild-macos.log",
  "matrix-smoke-ios.log",
  "matrix-smoke-ios-inner.log",
  "matrix-smoke-macos.log",
  "matrix-smoke-macos-inner.log",
  "matrix-stale-blocker-scan.log",
  "matrix-warning-scan.log",
  "validation-matrix.jsonl",
  "validation-matrix.json"
].freeze

REQUIRED_SOURCE_TOKENS = [
  "fullyValidated",
  "blocked_steps",
  "blockerFailures: blocker_failures.length",
  "scripts/check-app-intents-contract.rb",
  "scripts/verify-native-password-dogfood.sh",
  "scripts/capture-native-screenshot-matrix.sh",
  "run_screenshot_matrix_batched",
  'resume_matrix=1',
  '"$status" -eq 75',
  '--batch-size "$batch_size"',
  'screenshot_batch_size="${SPOONJOY_SCREENSHOT_MATRIX_BATCH_SIZE:-5}"',
  "--screenshot-batch-size",
  "Screenshot batch size must be a positive integer",
  'run_required "native password dogfood"',
  "stale_noncanonical_blockers",
  'record_step "stale noncanonical blocker scan"',
  "validate_blocker_contract",
  "ownerAction",
  "ProductionOperationApproval",
  "apple/apple-developer-program-blocker-apns.json",
  "web/provider-secret-blocker-",
  "human-credential-blocker-",
  "aasa-production-blocker.json",
  "rm -f \"$apple_dir/matrix-warning-scan.log\"",
  "--timeout-seconds 180"
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

failures = []

Dir.mktmpdir("spoonjoy-native-route-evidence-contract") do |directory|
  artifact_root = Pathname.new(directory)
  route_root = artifact_root.join("screenshot-routes/recipes")
  route_root.join("screenshots").mkpath
  route_root.join("design-review.json").write("{}\n")
  %w[ios-mobile.png ios-tablet.png macos-desktop.png].each do |name|
    route_root.join("screenshots", name).binwrite("not-a-png")
  end
  artifact = lambda do |path|
    { "path" => path.to_s, "exists" => true, "bytes" => path.size, "sha256" => Digest::SHA256.file(path).hexdigest }
  end
  row = {
    "name" => "recipes", "route" => "recipes", "artifactRoot" => route_root.to_s,
    "status" => "pass", "blocked" => false, "missingDesignReview" => false,
    "designReview" => artifact.call(route_root.join("design-review.json")),
    "iosScreenshot" => artifact.call(route_root.join("screenshots/ios-mobile.png")),
    "iosTabletScreenshot" => artifact.call(route_root.join("screenshots/ios-tablet.png")),
    "macosScreenshot" => artifact.call(route_root.join("screenshots/macos-desktop.png"))
  }
  results = artifact_root.join("matrix.jsonl")
  results.write(JSON.generate(row) + "\n")
  checkpoint = artifact_root.join("checkpoint.json")
  checkpoint.write(JSON.generate("schemaVersion" => 2, "completedRouteDigests" => { "recipes" => Digest::SHA256.hexdigest(JSON.generate(row)) }))
  validator = ROOT.join("scripts/validate-native-route-evidence.rb")

  _stdout, stderr, status = Open3.capture3("ruby", validator.to_s, "--artifact-root", artifact_root.to_s, "--name", "recipes", "--results-jsonl", results.to_s, "--checkpoint", checkpoint.to_s)
  failures << "route evidence validator must reject a non-PNG screenshot: #{stderr.inspect}" if status.success?

  row["route"] = "settings"
  results.write(JSON.generate(row) + "\n")
  checkpoint.write(JSON.generate("schemaVersion" => 2, "completedRouteDigests" => { "recipes" => Digest::SHA256.hexdigest(JSON.generate(row)) }))
  _stdout, stderr, status = Open3.capture3("ruby", validator.to_s, "--artifact-root", artifact_root.to_s, "--name", "recipes", "--results-jsonl", results.to_s, "--checkpoint", checkpoint.to_s)
  failures << "route evidence validator must bind canonical row route independently: #{stderr.inspect}" unless !status.success? && stderr.include?("row route does not match")
  row["route"] = "recipes"

  route_root.join("design-review.json").write(JSON.generate("screenshotRoute" => "settings") + "\n")
  row["designReview"] = artifact.call(route_root.join("design-review.json"))
  results.write(JSON.generate(row) + "\n")
  checkpoint.write(JSON.generate("schemaVersion" => 2, "completedRouteDigests" => { "recipes" => Digest::SHA256.hexdigest(JSON.generate(row)) }))
  _stdout, stderr, status = Open3.capture3("ruby", validator.to_s, "--artifact-root", artifact_root.to_s, "--name", "recipes", "--results-jsonl", results.to_s, "--checkpoint", checkpoint.to_s)
  failures << "route evidence validator must bind design route independently: #{stderr.inspect}" unless !status.success? && stderr.include?("design review route does not match")

  row["iosScreenshot"]["path"] = "/etc/hosts"
  results.write(JSON.generate(row) + "\n")
  _stdout, stderr, status = Open3.capture3("ruby", validator.to_s, "--artifact-root", artifact_root.to_s, "--name", "recipes", "--results-jsonl", results.to_s, "--checkpoint", checkpoint.to_s)
  failures << "route evidence validator must reject a noncanonical JSONL path: #{stderr.inspect}" if status.success?

  results.write("{\"name\":")
  _stdout, stderr, status = Open3.capture3("ruby", validator.to_s, "--artifact-root", artifact_root.to_s, "--name", "recipes", "--results-jsonl", results.to_s, "--checkpoint", checkpoint.to_s)
  failures << "route evidence validator must reject truncated JSONL: #{stderr.inspect}" if status.success?
end

fail_check("missing #{SCRIPT_PATH}") unless SCRIPT_PATH.file?

content = SCRIPT_PATH.read
matrix_content = MATRIX_SCRIPT_PATH.read

[
  "scripts/validate-native-route-evidence.rb",
  "completedRouteDigests",
  '"schemaVersion" => 2',
  '"sha256"',
  "accessibilityProofs",
  "git ls-files --others --exclude-standard"
].each do |token|
  failures << "capture-native-screenshot-matrix.sh missing fail-closed resume token #{token.inspect}" unless matrix_content.include?(token)
end

REQUIRED_SOURCE_TOKENS.each do |token|
  failures << "validate-native-local.sh missing required final-matrix token #{token.inspect}" unless content.include?(token)
end

FINAL_MATRIX_ARTIFACT_TOKENS.each do |token|
  failures << "validate-native-local.sh missing stable matrix artifact token #{token}" unless content.include?(token)
end

APP_INTENTS_DOMAINS.each do |domain|
  [
    domain,
    "matrix-appintents-#{domain}.log",
    "appintents-sdk-blocker-#{domain}.json"
  ].each do |token|
    failures << "validate-native-local.sh missing App Intents domain token #{token.inspect}" unless content.include?(token)
  end
end

unless content.scan("scripts/run-xcodebuild-with-blocker.sh").size >= 2
  failures << "validate-native-local.sh must route both app-bundle builds through scripts/run-xcodebuild-with-blocker.sh"
end

if content.include?("--screenshot-batch-size") && content.include?("Screenshot batch size must be a positive integer")
  Dir.mktmpdir("spoonjoy-native-final-matrix-contract") do |directory|
    ["0", "not-a-number"].each do |invalid_batch_size|
      stdout, stderr, status = Open3.capture3(
        SCRIPT_PATH.to_s,
        "--artifact-root", File.join(directory, invalid_batch_size),
        "--screenshot-batch-size", invalid_batch_size,
        chdir: ROOT.to_s
      )
      unless status.exitstatus == 2 && stderr.include?("Screenshot batch size must be a positive integer")
        failures << "validate-native-local.sh must reject screenshot batch size #{invalid_batch_size.inspect} before validation; stdout=#{stdout.inspect} stderr=#{stderr.inspect} status=#{status.exitstatus.inspect}"
      end
    end
  end
end

if failures.any?
  warn "native final matrix contract failed"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "native final matrix contract ok"
