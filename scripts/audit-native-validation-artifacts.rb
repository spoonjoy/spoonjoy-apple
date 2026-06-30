#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "English"
require "fileutils"
require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

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

FINAL_MATRIX_ARTIFACTS = [
  "apple/matrix-swift-test.log",
  "apple/matrix-coverage-test.log",
  "apple/matrix-coverage-enforce.log",
  "apple/matrix-final-scenario.log",
  "apple/matrix-project-contract.log",
  "apple/matrix-generator-contract.log",
  "apple/matrix-native-design-contract.log",
  "apple/matrix-kitchen-surfaces-contract.log",
  "apple/matrix-cook-shopping-contract.log",
  "apple/matrix-search-capture-contract.log",
  "apple/matrix-capture.log",
  "apple/matrix-design-review.log",
  "apple/matrix-xcode-version.log",
  "apple/matrix-xcodebuild-ios.log",
  "apple/matrix-xcodebuild-macos.log",
  "apple/matrix-smoke-ios.log",
  "apple/matrix-smoke-ios-inner.log",
  "apple/matrix-smoke-macos.log",
  "apple/matrix-smoke-macos-inner.log",
  "apple/matrix-stale-blocker-scan.log",
  "apple/matrix-warning-scan.log",
  "apple/validation-matrix.jsonl",
  "apple/validation-matrix.json",
  "apple/unit-26b-native-full-validation-validate-native-local.log"
].freeze

REQUIRED_RED_PATTERNS = [
  "apple/unit-11a-native-api-red.log",
  "apple/unit-12a-transport-red.log",
  "apple/unit-13a-auth-red.log",
  "apple/unit-14a-cache-red.log",
  "apple/unit-15a-sync-engine-red.log",
  "apple/unit-16a-live-store-red.log",
  "apple/unit-16d-screenshot-contract-red.log",
  "apple/unit-17d-cook-mode-red.log",
  "apple/unit-17g-recipe-editor-red.log",
  "apple/unit-17j-recipe-actions-red.log",
  "apple/unit-17m-shopping-surface-red.log",
  "apple/unit-18a-spoon-logs-red.log",
  "apple/unit-18g-capture-import-red.log",
  "apple/unit-18j-sharing-red.log",
  "apple/unit-19a-cookbooks-red.log",
  "apple/unit-19d-profiles-red.log",
  "apple/unit-19g-settings-tokens-red.log",
  "apple/unit-19j-notifications-red.log",
  "apple/unit-19m-search-surface-red.log",
  "apple/unit-21a-recipe-cookbook-entities-red.log",
  "apple/unit-21d-shopping-entities-red.log",
  "apple/unit-21j-spotlight-shortcuts-red.log",
  "apple/unit-21m-spoon-entities-red.log",
  "apple/unit-21p-capture-draft-entities-red.log",
  "apple/unit-22a-open-search-share-cook-intents-red.log",
  "apple/unit-22d-shopping-intents-red.log",
  "apple/unit-22g-recipe-action-intents-red.log",
  "apple/unit-22m-spoon-intents-red.log",
  "apple/unit-22p-capture-import-intents-red.log",
  "apple/unit-22s-profile-settings-intents-red.log",
  "apple/unit-22v-notification-intents-red.log",
  "apple/unit-23a-design-red.log"
].freeze

REQUIRED_GREEN_GROUPS = {
  "unit-11b native API implementation" => ["apple/unit-11b-native-api-green.log"],
  "unit-12b transport implementation" => ["apple/unit-12b-transport-green.log"],
  "unit-13b auth implementation" => ["apple/unit-13b-auth-green.log"],
  "unit-14b cache implementation" => ["apple/unit-14b-cache-green.log"],
  "unit-15b sync implementation" => ["apple/unit-15b-sync-engine-green.log"],
  "unit-16b live-store implementation" => ["apple/unit-16b-owner-scope-focused.log"],
  "unit-16e screenshot/smoke implementation" => ["apple/unit-16e-screenshot-contract-green.log"],
  "unit-17e cook mode implementation" => ["apple/unit-17e-cook-mode-green.log"],
  "unit-17h recipe editor implementation" => ["apple/unit-17h-recipe-editor-green.log"],
  "unit-17k recipe actions implementation" => ["apple/unit-17k-recipe-actions-green.log"],
  "unit-17n shopping implementation" => ["apple/unit-17n-shopping-surface-green.log", "apple/unit-17n-shopping-review-fix-green.log"],
  "unit-18a spoon implementation" => ["apple/unit-18a-spoon-logs-green.log"],
  "unit-18e cover implementation" => ["apple/unit-18e-photo-rejection-preserves-draft-focused.log", "apple/unit-18d-review-fixes-live-store.log"],
  "unit-18h capture/import implementation" => ["apple/unit-18h-capture-import-green.log"],
  "unit-18k sharing implementation" => ["apple/unit-18k-sharing-focused.log"],
  "unit-19b cookbooks implementation" => ["apple/unit-19b-cookbooks-green.log"],
  "unit-19e profiles implementation" => ["apple/unit-19e-profiles-green.log"],
  "unit-19h settings/tokens implementation" => ["apple/unit-19h-settings-focused-after-v2-api.log"],
  "unit-19k notifications implementation" => ["apple/unit-19k-notifications-green.log"],
  "unit-19n search implementation" => ["apple/unit-19n-search-surface-green.log"],
  "unit-20c AASA implementation" => ["apple/unit-20c-aasa-production-validation.log", "aasa-validation.json"],
  "unit-21b recipe cookbook entities" => ["apple/unit-21b-recipe-cookbook-entities-green.log"],
  "unit-21e shopping entities" => ["apple/unit-21e-shopping-entities-app-intents-contract.log"],
  "unit-21l spotlight shortcuts" => ["apple/unit-21l-spotlight-shortcuts-app-intents-contract.log"],
  "unit-21n spoon entities" => ["apple/unit-21n-spoon-entities-green.log"],
  "unit-21q capture draft entities" => ["apple/unit-21q-capture-draft-entities-green.log"],
  "unit-22b open/search/share/cook intents" => ["apple/unit-22b-open-search-share-cook-intents-green.log"],
  "unit-22e shopping intents" => ["apple/unit-22e-shopping-intents-green.log"],
  "unit-22h recipe action intents" => ["apple/unit-22h-recipe-action-intents-green.log"],
  "unit-22n spoon intents" => ["apple/unit-22n-spoon-intents-green.log"],
  "unit-22q capture/import intents" => ["apple/unit-22q-capture-import-intents-green.log"],
  "unit-22t profile/settings intents" => ["apple/unit-22t-profile-settings-intents-green.log"],
  "unit-22w notification intents" => ["apple/unit-22w-notification-intents-green.log"],
  "unit-23b design implementation" => ["apple/unit-23b-design-screenshots.log", "design-review.json"]
}.freeze

REQUIRED_MATRIX_GROUPS = {
  "unit-11c native API matrix" => ["apple/unit-11c-native-api-coverage-enforce.log", "apple/unit-11c-native-api-warning-scan.log"],
  "unit-12c transport matrix" => ["apple/unit-12c-transport-coverage-enforce.log", "apple/unit-12c-transport-warning-scan.log"],
  "unit-13c auth matrix" => ["apple/unit-13c-auth-coverage-enforce.log", "apple/unit-13c-auth-warning-scan.log"],
  "unit-14c cache matrix" => ["apple/unit-14c-cache-coverage-enforce.log", "apple/unit-14c-cache-warning-scan.log"],
  "unit-15c sync matrix" => ["apple/unit-15c-sync-engine-coverage-enforce.log", "apple/unit-15c-sync-engine-warning-scan.log"],
  "unit-16c live-store matrix" => ["apple/unit-16c-live-store-coverage-enforce.log", "apple/unit-16c-live-store-warning-scan.log"],
  "unit-16f screenshot matrix" => ["apple/unit-16f-screenshot-contract-warning-scan.log"],
  "unit-17c recipe catalog matrix" => ["apple/unit-17c-recipe-catalog-detail-coverage-enforce.log", "apple/unit-17c-recipe-catalog-detail-warning-scan.log"],
  "unit-17f cook mode matrix" => ["apple/unit-17f-cook-mode-coverage-enforce.log", "apple/unit-17f-cook-mode-warning-scan.log"],
  "unit-17i recipe editor matrix" => ["apple/unit-17i-recipe-editor-coverage-enforce.log", "apple/unit-17i-recipe-editor-warning-scan.log"],
  "unit-17l recipe actions matrix" => ["apple/unit-17l-recipe-actions-coverage-enforce.log", "apple/unit-17l-recipe-actions-warning-scan.log"],
  "unit-18c spoon matrix" => ["apple/unit-18c-spoon-logs-coverage-enforce.log", "apple/unit-18c-spoon-logs-warning-scan.log"],
  "unit-18i capture/import matrix" => ["apple/unit-18i-capture-import-coverage-enforce.log", "apple/unit-18i-capture-import-warning-scan.log"],
  "unit-18l sharing matrix" => ["apple/unit-18l-sharing-coverage-enforce.log", "apple/unit-18l-sharing-warning-scan.log"],
  "unit-19c cookbooks matrix" => ["apple/unit-19c-cookbooks-coverage-enforce.log", "apple/unit-19c-cookbooks-warning-scan.log"],
  "unit-19f profiles matrix" => ["apple/unit-19f-profiles-coverage-enforce.log", "apple/unit-19f-profiles-warning-scan.log"],
  "unit-19i settings matrix" => ["apple/unit-19i-settings-tokens-coverage-enforce.log", "apple/unit-19i-settings-tokens-warning-scan.log"],
  "unit-19l notifications matrix" => ["apple/unit-19l-notifications-coverage-enforce.log", "apple/unit-19l-notifications-warning-scan.log"],
  "unit-19o search matrix" => ["apple/unit-19o-search-surface-coverage-enforce.log", "apple/unit-19o-search-surface-warning-scan.log"],
  "unit-21c recipe cookbook entities matrix" => ["apple/unit-21c-recipe-cookbook-entities-app-intents-contract.log", "apple/unit-21c-recipe-cookbook-entities-warning-scan.log"],
  "unit-21f shopping entities matrix" => ["apple/unit-21f-shopping-entities-app-intents-contract.log", "apple/unit-21f-shopping-entities-warning-scan.log"],
  "unit-21l spotlight privacy matrix" => ["apple/unit-21l-spotlight-shortcuts-app-intents-contract.log", "apple/unit-21l-spotlight-shortcuts-warning-scan.log"],
  "unit-21o spoon entities matrix" => ["apple/unit-21o-spoon-entities-app-intents-contract.log", "apple/unit-21o-spoon-entities-warning-scan.log"],
  "unit-21r capture draft entities matrix" => ["apple/unit-21r-capture-draft-entities-app-intents-contract.log", "apple/unit-21r-capture-draft-entities-warning-scan.log"],
  "unit-22c open/search/share/cook intents matrix" => ["apple/unit-22c-open-search-share-cook-intents-app-intents-contract.log", "apple/unit-22c-open-search-share-cook-intents-warning-scan.log"],
  "unit-22f shopping intents matrix" => ["apple/unit-22f-shopping-intents-app-intents-contract.log", "apple/unit-22f-shopping-intents-warning-scan.log"],
  "unit-22i recipe action intents matrix" => ["apple/unit-22i-recipe-action-intents-app-intents-contract.log", "apple/unit-22i-recipe-action-intents-warning-scan.log"],
  "unit-22o spoon intents matrix" => ["apple/unit-22o-spoon-intents-app-intents-contract.log", "apple/unit-22o-spoon-intents-warning-scan.log"],
  "unit-22r capture/import intents matrix" => ["apple/unit-22r-capture-import-intents-app-intents-contract.log", "apple/unit-22r-capture-import-intents-warning-scan.log"],
  "unit-22u profile/settings intents matrix" => ["apple/unit-22u-profile-settings-intents-app-intents-contract.log", "apple/unit-22u-profile-settings-intents-warning-scan.log"],
  "unit-22x notification intents matrix" => ["apple/unit-22x-notification-intents-app-intents-contract.log", "apple/unit-22x-notification-intents-warning-scan.log"],
  "unit-23c design matrix" => ["apple/unit-23c-design-design-review.log", "apple/unit-23c-design-warning-scan.log"]
}.freeze

BLOCKER_REQUIRED_KEYS = %w[blocked capability command outputPath reason ownerAction].freeze
ALLOWED_FINAL_CAPABILITIES = %w[
  XcodePlatform
  CoreSimulator
  MacOSLaunch
  AASAProductionValidation
  AppIntentsSDK
  AppleDeveloperProgram
  ProviderSecret
  HumanCredential
].freeze

options = {
  artifact_root: ROOT.join("tasks/2026-06-16-1754-doing-siri-full-access-parity"),
  manifest: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: audit-native-validation-artifacts.rb --artifact-root PATH --manifest PATH"
  parser.on("--artifact-root PATH", "Task artifact root") { |value| options[:artifact_root] = Pathname.new(value) }
  parser.on("--manifest PATH", "Manifest output path") { |value| options[:manifest] = Pathname.new(value) }
end.parse!

artifact_root = options.fetch(:artifact_root).expand_path
apple_dir = artifact_root.join("apple")
manifest_path = (options[:manifest] || apple_dir.join("validation-audit-manifest.json")).expand_path

def rel(path, artifact_root)
  Pathname.new(path).expand_path.relative_path_from(artifact_root).to_s
rescue ArgumentError
  Pathname.new(path).to_s
end

def artifact_entry(artifact_root, relative_path)
  path = artifact_root.join(relative_path)
  {
    "path" => relative_path,
    "exists" => path.file?,
    "bytes" => path.file? ? path.size : nil,
    "nonEmpty" => path.file? && path.size.positive?
  }
end

def blocker_required_keys_present?(blocker)
  BLOCKER_REQUIRED_KEYS.all? { |key| !blocker[key].nil? && !blocker[key].to_s.strip.empty? }
end

def parsed_blocker(path)
  JSON.parse(path.read)
rescue JSON::ParserError
  nil
end

def blocker_entry(artifact_root, relative_path, expected_capability)
  entry = artifact_entry(artifact_root, relative_path)
  entry["expectedCapability"] = expected_capability
  entry["validBlocker"] = false
  return entry unless entry["nonEmpty"]

  blocker = parsed_blocker(artifact_root.join(relative_path))
  entry["capability"] = blocker && blocker["capability"]
  entry["validBlocker"] =
    blocker &&
    blocker["blocked"] == true &&
    blocker["capability"] == expected_capability &&
    blocker_required_keys_present?(blocker)
  entry
end

def group_entry(artifact_root, name, alternatives)
  entries = alternatives.map do |alternative|
    if alternative.is_a?(Hash)
      blocker_entry(artifact_root, alternative.fetch("path"), alternative.fetch("expectedCapability"))
    else
      artifact_entry(artifact_root, alternative)
    end
  end
  {
    "name" => name,
    "alternatives" => entries,
    "satisfied" => entries.any? { |entry| entry.key?("expectedCapability") ? entry["validBlocker"] : entry["nonEmpty"] }
  }
end

def parse_json_file(path, failures, label)
  JSON.parse(path.read)
rescue JSON::ParserError => e
  failures << "#{label} is not valid JSON: #{e.message}"
  nil
end

def expected_capability_for_path(relative_path)
  case relative_path
  when "aasa-production-blocker.json"
    "AASAProductionValidation"
  when "apple/matrix-xcode-platform-blocker.json",
       "apple/matrix-screenshots-xcode-platform-blocker.json"
    "XcodePlatform"
  when "apple/matrix-smoke-ios-simulator-blocker.json",
       "apple/matrix-screenshots-core-simulator-blocker.json"
    "CoreSimulator"
  when "apple/matrix-smoke-macos-blocker.json",
       "apple/matrix-screenshots-macos-launch-blocker.json"
    "MacOSLaunch"
  when "apple/apple-developer-program-blocker-apns.json"
    "AppleDeveloperProgram"
  when /\Aapple\/appintents-sdk-blocker-[a-z0-9-]+\.json\z/
    "AppIntentsSDK"
  when /\Aweb\/provider-secret-blocker-[a-z0-9-]+\.json\z/
    "ProviderSecret"
  when /\Ahuman-credential-blocker-[a-z0-9-]+\.json\z/
    "HumanCredential"
  end
end

def artifact_relative_from_value(value, artifact_root)
  return nil if value.nil? || value.to_s.strip.empty?

  raw = value.to_s
  path = Pathname.new(raw)
  return path.expand_path.relative_path_from(artifact_root).to_s if path.absolute? && path.expand_path.to_s.start_with?(artifact_root.to_s)
  return raw.sub(%r{\Atasks/2026-06-16-1754-doing-siri-full-access-parity/}, "") if raw.start_with?("tasks/2026-06-16-1754-doing-siri-full-access-parity/")
  return raw if raw.start_with?("apple/", "web/") || raw.start_with?("aasa-", "human-credential-")

  nil
rescue ArgumentError
  nil
end

def validate_blocker_contract(blocker, label, failures, artifact_root, expected_capability: nil)
  BLOCKER_REQUIRED_KEYS.each do |key|
    failures << "#{label} missing #{key}" if blocker[key].nil? || blocker[key].to_s.strip.empty?
  end
  failures << "#{label} blocked must be true" unless blocker["blocked"] == true

  capability = blocker["capability"]
  unless ALLOWED_FINAL_CAPABILITIES.include?(capability)
    failures << "#{label} has unsupported capability #{capability.inspect}"
  end
  failures << "#{label} uses Unit 27-only ProductionOperationApproval" if capability == "ProductionOperationApproval"
  failures << "#{label} expected capability #{expected_capability}, got #{capability.inspect}" if expected_capability && capability != expected_capability

  relative_path = artifact_relative_from_value(blocker["path"], artifact_root)
  if blocker.key?("path")
    if relative_path.nil?
      failures << "#{label} has noncanonical path #{blocker["path"].inspect}"
    else
      expected_for_path = expected_capability_for_path(relative_path)
      failures << "#{label} path is not a canonical final blocker path: #{relative_path}" if expected_for_path.nil?
      failures << "#{label} path #{relative_path} expects #{expected_for_path}, got #{capability.inspect}" if expected_for_path && capability != expected_for_path
    end
  end

  output_relative = artifact_relative_from_value(blocker["outputPath"], artifact_root)
  failures << "#{label} outputPath is outside the task artifact root: #{blocker["outputPath"].inspect}" if blocker.key?("outputPath") && output_relative.nil?
  if output_relative
    output_path = artifact_root.join(output_relative)
    if !output_path.file?
      failures << "#{label} outputPath does not exist: #{output_relative}"
    elsif output_path.size.zero?
      failures << "#{label} outputPath is empty: #{output_relative}"
    end
  end
end

required_red = REQUIRED_RED_PATTERNS.map { |relative_path| artifact_entry(artifact_root, relative_path) }
documented_historical_red = [
  {
    "path" => "apple/unit-18d-cover-controls-red.log",
    "exists" => false,
    "documentedIn" => "tasks/2026-06-16-1754-doing-siri-full-access-parity.md",
    "note" => "The doing doc records the Unit 18d red/green contract, but this specific red log was not present in git history under either artifact root."
  }
]
required_green = REQUIRED_GREEN_GROUPS.map { |name, alternatives| group_entry(artifact_root, name, alternatives) }
required_matrix = REQUIRED_MATRIX_GROUPS.map { |name, alternatives| group_entry(artifact_root, name, alternatives) }
required_final_matrix = FINAL_MATRIX_ARTIFACTS.map { |relative_path| artifact_entry(artifact_root, relative_path) }
required_app_intents = APP_INTENTS_DOMAINS.map do |domain|
  group_entry(
    artifact_root,
    "final App Intents #{domain}",
    [
      "apple/matrix-appintents-#{domain}.log",
      { "path" => "apple/appintents-sdk-blocker-#{domain}.json", "expectedCapability" => "AppIntentsSDK" }
    ]
  )
end
required_scenario = [
  "apple/matrix-final-scenario.log",
  "apple/matrix-final-report.json",
  "apple/unit-21l-spotlight-shortcuts-scenario-final.log",
  "apple/unit-23c-design-scenario-final.log"
].map { |relative_path| artifact_entry(artifact_root, relative_path) }
required_screenshots = [
  group_entry(artifact_root, "final screenshots or canonical blocker", [
    "apple/matrix-capture.log",
    "screenshots/ios-mobile.png",
    "apple/matrix-screenshots-xcode-platform-blocker.json",
    "apple/matrix-screenshots-core-simulator-blocker.json",
    "apple/matrix-screenshots-macos-launch-blocker.json"
  ]),
  group_entry(artifact_root, "final design review success or blocker", [
    "design-review.json",
    "design-review-blocked.json"
  ])
]
required_spotlight_privacy = [
  group_entry(artifact_root, "Spotlight privacy source contract", [
    "apple/unit-21l-spotlight-shortcuts-app-intents-contract.log"
  ]),
  group_entry(artifact_root, "Spotlight privacy Swift evidence", [
    "apple/unit-21l-spotlight-shortcuts-swift-test.log",
    "apple/unit-21l-spotlight-shortcuts-review-fix-focused.log"
  ]),
  group_entry(artifact_root, "Spotlight privacy current final App Intents evidence", [
    "apple/matrix-appintents-spotlight-shortcuts.log",
    { "path" => "apple/appintents-sdk-blocker-spotlight-shortcuts.json", "expectedCapability" => "AppIntentsSDK" }
  ])
]

failures = []

required_red.each { |entry| failures << "missing red artifact #{entry["path"]}" unless entry["nonEmpty"] }
required_green.each { |entry| failures << "missing implementation green artifact group #{entry["name"]}" unless entry["satisfied"] }
required_matrix.each { |entry| failures << "missing historical matrix artifact group #{entry["name"]}" unless entry["satisfied"] }
required_final_matrix.each { |entry| failures << "missing final native matrix artifact #{entry["path"]}" unless entry["nonEmpty"] }
required_app_intents.each { |entry| failures << "missing current final App Intents evidence #{entry["name"]}" unless entry["satisfied"] }
required_scenario.each { |entry| failures << "missing scenario artifact #{entry["path"]}" unless entry["nonEmpty"] }
required_screenshots.each { |entry| failures << "missing screenshot/design-review artifact group #{entry["name"]}" unless entry["satisfied"] }
required_spotlight_privacy.each { |entry| failures << "missing Spotlight privacy artifact group #{entry["name"]}" unless entry["satisfied"] }

contract_output = +""
contract_status = nil
IO.popen(["ruby", ROOT.join("scripts/check-native-final-matrix-contract.rb").to_s], err: [:child, :out]) do |io|
  contract_output = io.read
end
contract_status = $CHILD_STATUS.exitstatus
failures << "native final matrix source contract failed" unless contract_status&.zero?

final_blocker_paths = [
  artifact_root.join("aasa-production-blocker.json"),
  artifact_root.join("apple/matrix-xcode-platform-blocker.json"),
  artifact_root.join("apple/matrix-smoke-macos-blocker.json"),
  artifact_root.join("apple/matrix-smoke-ios-simulator-blocker.json"),
  artifact_root.join("apple/matrix-screenshots-xcode-platform-blocker.json"),
  artifact_root.join("apple/matrix-screenshots-core-simulator-blocker.json"),
  artifact_root.join("apple/matrix-screenshots-macos-launch-blocker.json"),
  artifact_root.join("apple/apple-developer-program-blocker-apns.json")
]
final_blocker_paths += Dir[artifact_root.join("apple/appintents-sdk-blocker-*.json").to_s].map { |path| Pathname.new(path) }
final_blocker_paths += Dir[artifact_root.join("web/provider-secret-blocker-*.json").to_s].map { |path| Pathname.new(path) }
final_blocker_paths += Dir[artifact_root.join("human-credential-blocker-*.json").to_s].map { |path| Pathname.new(path) }

blockers = []
final_blocker_paths.uniq.each do |path|
  next unless path.file?

  blocker = parse_json_file(path, failures, rel(path, artifact_root))
  next unless blocker

  blockers << blocker.merge("path" => rel(path, artifact_root))
  expected_capability = expected_capability_for_path(rel(path, artifact_root))
  validate_blocker_contract(
    blocker.merge("path" => rel(path, artifact_root)),
    rel(path, artifact_root),
    failures,
    artifact_root,
    expected_capability: expected_capability
  )
end

stale_top_level_blockers = Dir[artifact_root.join("*blocker*.json").to_s].map do |path_string|
  path = Pathname.new(path_string)
  basename = path.basename.to_s
  next if basename == "aasa-production-blocker.json"
  next if basename.start_with?("human-credential-blocker-")

  parsed = parse_json_file(path, failures, rel(path, artifact_root))
  next unless parsed
  next unless %w[XcodePlatform CoreSimulator MacOSLaunch AppIntentsSDK].include?(parsed["capability"])

  rel(path, artifact_root)
end.compact
failures << "stale noncanonical top-level native blocker(s): #{stale_top_level_blockers.join(", ")}" if stale_top_level_blockers.any?

matrix_json_path = artifact_root.join("apple/validation-matrix.json")
matrix = matrix_json_path.file? ? parse_json_file(matrix_json_path, failures, "apple/validation-matrix.json") : nil
if matrix
  unless matrix["ok"] == true
    failures << "apple/validation-matrix.json does not report ok: true"
  end
  Array(matrix["blockers"]).each_with_index do |blocker, index|
    validate_blocker_contract(blocker, "apple/validation-matrix.json blockers[#{index}]", failures, artifact_root)
  end
  stale_scan_step = Array(matrix["steps"]).find { |step| step["name"] == "stale noncanonical blocker scan" }
  if stale_scan_step.nil?
    failures << "apple/validation-matrix.json missing stale noncanonical blocker scan step"
  elsif stale_scan_step["status"] != "pass"
    failures << "apple/validation-matrix.json stale noncanonical blocker scan status is #{stale_scan_step["status"].inspect}"
  end
end

manifest = {
  "ok" => failures.empty?,
  "schemaVersion" => 1,
  "artifactRoot" => artifact_root.to_s,
  "requiredRedArtifacts" => required_red,
  "documentedHistoricalRedArtifacts" => documented_historical_red,
  "requiredGreenArtifacts" => required_green,
  "requiredMatrixArtifacts" => required_matrix,
  "requiredScenarioArtifacts" => required_scenario,
  "requiredBlockerArtifacts" => blockers,
  "requiredScreenshotArtifacts" => required_screenshots,
  "requiredSourceTestMappings" => [
    {
      "source" => "scripts/validate-native-local.sh",
      "tests" => ["scripts/check-native-final-matrix-contract.rb"],
      "status" => contract_status&.zero? ? "pass" : "fail",
      "output" => contract_output
    },
    {
      "source" => "scripts/audit-native-validation-artifacts.rb",
      "tests" => ["apple/unit-26a-validation-audit.log"],
      "status" => "self-audited"
    }
  ],
  "requiredDesignReviewBlockedArtifacts" => required_screenshots,
  "requiredSpotlightPrivacyArtifacts" => required_spotlight_privacy,
  "requiredFinalMatrixArtifacts" => required_final_matrix,
  "requiredFinalAppIntentsArtifacts" => required_app_intents,
  "staleNoncanonicalBlockers" => stale_top_level_blockers,
  "failures" => failures
}

FileUtils.mkdir_p(manifest_path.dirname)
manifest_path.write(JSON.pretty_generate(manifest) + "\n")

if failures.any?
  warn "native validation artifact audit failed"
  failures.each { |failure| warn "- #{failure}" }
  warn "manifest: #{manifest_path}"
  exit 1
end

puts "native validation artifact audit ok"
puts "manifest: #{manifest_path}"
