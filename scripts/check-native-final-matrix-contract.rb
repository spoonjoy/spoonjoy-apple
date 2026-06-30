#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
SCRIPT_PATH = ROOT.join("scripts/validate-native-local.sh")

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
  "matrix-capture.log",
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
  "scripts/check-app-intents-contract.rb",
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

fail_check("missing #{SCRIPT_PATH}") unless SCRIPT_PATH.file?

content = SCRIPT_PATH.read
failures = []

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

if failures.any?
  warn "native final matrix contract failed"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "native final matrix contract ok"
