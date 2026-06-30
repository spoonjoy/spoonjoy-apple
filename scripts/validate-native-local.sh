#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-15-2314-doing-native-app-skeleton"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
mkdir -p "$artifact_root" "$apple_dir"
matrix_path="$apple_dir/validation-matrix.json"
results_path="$apple_dir/validation-matrix.jsonl"
web_design_doc="docs/source/spoonjoy-v2-design-language.md"
unit_26b_validate_log_name="unit-26b-native-full-validation-validate-native-local.log"
app_intents_domains=(
  "recipe-cookbook:matrix-appintents-recipe-cookbook.log:appintents-sdk-blocker-recipe-cookbook.json"
  "shopping:matrix-appintents-shopping.log:appintents-sdk-blocker-shopping.json"
  "spoon:matrix-appintents-spoon.log:appintents-sdk-blocker-spoon.json"
  "capture-draft:matrix-appintents-capture-draft.log:appintents-sdk-blocker-capture-draft.json"
  "chef-profile:matrix-appintents-chef-profile.log:appintents-sdk-blocker-chef-profile.json"
  "spotlight-shortcuts:matrix-appintents-spotlight-shortcuts.log:appintents-sdk-blocker-spotlight-shortcuts.json"
  "open-search-share-cook:matrix-appintents-open-search-share-cook.log:appintents-sdk-blocker-open-search-share-cook.json"
  "recipe-action:matrix-appintents-recipe-action.log:appintents-sdk-blocker-recipe-action.json"
  "shopping-intents:matrix-appintents-shopping-intents.log:appintents-sdk-blocker-shopping-intents.json"
  "spoon-intents:matrix-appintents-spoon-intents.log:appintents-sdk-blocker-spoon-intents.json"
  "capture-import-intents:matrix-appintents-capture-import-intents.log:appintents-sdk-blocker-capture-import-intents.json"
  "cookbook-intents:matrix-appintents-cookbook-intents.log:appintents-sdk-blocker-cookbook-intents.json"
  "profile-settings-intents:matrix-appintents-profile-settings-intents.log:appintents-sdk-blocker-profile-settings-intents.json"
  "notification-intents:matrix-appintents-notification-intents.log:appintents-sdk-blocker-notification-intents.json"
)
rm -f "$apple_dir/matrix-warning-scan.log"
rm -f \
  "$results_path" \
  "$matrix_path" \
  "$apple_dir/matrix-warning-scan.log" \
  "$apple_dir/matrix-stale-blocker-scan.log" \
  "$apple_dir/matrix-xcode-platform-blocker.json" \
  "$apple_dir/matrix-smoke-macos-blocker.json" \
  "$apple_dir/matrix-smoke-ios-simulator-blocker.json" \
  "$apple_dir/matrix-screenshots-xcode-platform-blocker.json" \
  "$apple_dir/matrix-screenshots-core-simulator-blocker.json" \
  "$apple_dir/matrix-screenshots-macos-launch-blocker.json" \
  "$artifact_root/design-review-blocked.json" \
  "$artifact_root/design-review.json" \
  "$artifact_root/screenshots/ios-mobile.png" \
  "$artifact_root/screenshots/macos-desktop.png"

for app_intents_entry in "${app_intents_domains[@]}"; do
  IFS=":" read -r _app_intents_domain app_intents_log app_intents_blocker <<< "$app_intents_entry"
  rm -f "$apple_dir/$app_intents_log" "$apple_dir/$app_intents_blocker"
done

required_hooks=(
  "scripts/fail-on-warning.rb"
  "scripts/enforce-swift-coverage.rb"
  "scripts/verify-native-scenarios.sh"
  "scripts/check-xcode-project-contract.rb"
  "scripts/check-xcode-generator-contract.rb"
  "scripts/bundle-check.sh"
  "scripts/bundle-exec.sh"
  "scripts/check-native-design-language.rb"
  "scripts/check-design-accessibility-contract.rb"
  "scripts/check-kitchen-recipe-surfaces.rb"
  "scripts/check-cook-shopping-surfaces.rb"
  "scripts/check-search-capture-settings-surfaces.rb"
  "scripts/check-launch-screenshot-contract.rb"
  "scripts/check-app-intents-contract.rb"
  "scripts/run-xcodebuild-with-blocker.sh"
  "scripts/smoke-macos.sh"
  "scripts/smoke-ios-simulator.sh"
  "scripts/capture-native-screenshots.sh"
  "scripts/validate-design-review.rb"
  "scripts/validate-design-review-blocker.rb"
  "scripts/validate-aasa.rb"
)

missing_hooks=()
for hook in "${required_hooks[@]}"; do
  if [[ ! -f "$hook" ]]; then
    missing_hooks+=("$hook")
  fi
done
for bundle_file in Gemfile Gemfile.lock; do
  if [[ ! -f "$bundle_file" ]]; then
    missing_hooks+=("$bundle_file")
  fi
done
if [[ ! -f "$web_design_doc" ]]; then
  missing_hooks+=("$web_design_doc")
fi

if [[ "${#missing_hooks[@]}" -gt 0 ]]; then
  printf 'Native local matrix is missing required hook(s):\n' >&2
  printf ' - %s\n' "${missing_hooks[@]}" >&2
  exit 1
fi

record_step() {
  local name="$1"
  local status="$2"
  local command="$3"
  local output_path="$4"
  local required="$5"
  local blocker_path="${6:-}"
  local details="${7:-}"
  ruby -rjson -e '
    path, name, status, command, output_path, required, blocker_path, details = ARGV
    row = {
      name: name,
      status: status,
      command: command,
      outputPath: output_path,
      required: required == "true"
    }
    row[:blockerPath] = blocker_path unless blocker_path.empty?
    row[:details] = details unless details.empty?
    File.open(path, "a") { |file| file.puts(JSON.generate(row)) }
  ' "$results_path" "$name" "$status" "$command" "$output_path" "$required" "$blocker_path" "$details"
}

validate_blocker_contract() {
  local blocker_path="$1"
  local expected_capabilities="$2"
  ruby -rjson -e '
    path, expected_capabilities = ARGV
    allowed = %w[
      XcodePlatform
      CoreSimulator
      MacOSLaunch
      AASAProductionValidation
      AppIntentsSDK
      AppleDeveloperProgram
      ProviderSecret
      HumanCredential
    ]
    expected = expected_capabilities.split(",").reject(&:empty?)
    blocker = JSON.parse(File.read(path))
    required = %w[blocked capability command outputPath reason ownerAction]
    missing = required.select { |key| blocker[key].nil? || blocker[key].to_s.strip.empty? }
    abort("#{path} missing #{missing.join(", ")}") unless missing.empty?
    abort("#{path} blocked must be true") unless blocker["blocked"] == true
    capability = blocker["capability"]
    abort("#{path} unsupported capability #{capability.inspect}") unless allowed.include?(capability)
    abort("#{path} ProductionOperationApproval is Unit 27-only") if capability == "ProductionOperationApproval"
    abort("#{path} expected #{expected.join(" or ")}, got #{capability}") unless expected.empty? || expected.include?(capability)
  ' "$blocker_path" "$expected_capabilities"
}

stale_noncanonical_blockers() {
  ruby -rjson -e '
    artifact_root = ARGV.fetch(0)
    allowed_top_level = [
      "aasa-production-blocker.json"
    ]
    stale = Dir[File.join(artifact_root, "*blocker*.json")].map do |path|
      basename = File.basename(path)
      next if allowed_top_level.include?(basename)
      next if basename.start_with?("human-credential-blocker-")
      begin
        blocker = JSON.parse(File.read(path))
      rescue JSON::ParserError
        next basename
      end
      %w[XcodePlatform CoreSimulator MacOSLaunch AppIntentsSDK].include?(blocker["capability"]) ? basename : nil
    end.compact
    if stale.any?
      warn "stale noncanonical native blocker(s): #{stale.join(", ")}"
      exit 1
    end
  ' "$artifact_root"
}

write_xcode_screenshot_blocker() {
  local source_blocker="$1"
  local screenshot_blocker="$apple_dir/matrix-screenshots-xcode-platform-blocker.json"
  local design_review_blocked="$artifact_root/design-review-blocked.json"
  ruby -rjson -e '
    source_path, screenshot_path, design_review_blocked_path = ARGV
    source = JSON.parse(File.read(source_path))
    capture_log_path = File.join(File.dirname(screenshot_path), "matrix-capture.log")
    screenshot_blocker = source.merge(
      "capability" => "XcodePlatform",
      "blocked" => true,
      "command" => "screenshots skipped after app-bundle XcodePlatform blocker",
      "outputPath" => capture_log_path
    )
    File.write(screenshot_path, JSON.pretty_generate(screenshot_blocker) + "\n")
    design_review_blocked = {
      "blocked" => true,
      "capability" => "XcodePlatform",
      "sourceBlockerPath" => File.expand_path(screenshot_path),
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/matrix-accessibility-proof-ios.json",
        "apple/matrix-accessibility-proof-macos.json"
      ],
      "reason" => screenshot_blocker.fetch("reason"),
      "ownerAction" => screenshot_blocker.fetch("ownerAction")
    }
    File.write(design_review_blocked_path, JSON.pretty_generate(design_review_blocked) + "\n")
  ' "$source_blocker" "$screenshot_blocker" "$design_review_blocked"
  rm -f "$artifact_root/design-review.json"
  rm -f "$artifact_root/screenshots/ios-mobile.png" "$artifact_root/screenshots/macos-desktop.png"
  rm -f "$artifact_root/apple/matrix-accessibility-proof-ios.json" "$artifact_root/apple/matrix-accessibility-proof-macos.json"
}

run_required() {
  local name="$1"
  local output_path="$2"
  shift 2
  local command="$*"
  if "$@" > "$output_path" 2>&1; then
    record_step "$name" "pass" "$command" "$output_path" "true"
  else
    record_step "$name" "fail" "$command" "$output_path" "true"
    return 1
  fi
}

run_script_with_blocker_policy() {
  local name="$1"
  local output_path="$2"
  local blocker_path="$3"
  local allowed_capabilities="$4"
  shift 4
  local command="$*"
  local command_status=0
  "$@" > "$output_path" 2>&1 || command_status=$?

  if [[ -f "$blocker_path" ]]; then
    local capability
    capability="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("capability")' "$blocker_path")"
    if [[ ",$allowed_capabilities," == *",$capability,"* ]]; then
      validate_blocker_contract "$blocker_path" "$allowed_capabilities"
      record_step "$name" "blocked" "$command" "$output_path" "true" "$blocker_path"
      return 0
    fi
    record_step "$name" "fail" "$command" "$output_path" "true" "$blocker_path"
    return 1
  fi

  if [[ "$command_status" -eq 0 ]]; then
    record_step "$name" "pass" "$command" "$output_path" "true"
  else
    record_step "$name" "fail" "$command" "$output_path" "true"
    return 1
  fi
}

overall_status=0
coverage_json_path="$apple_dir/coverage-json-path.log"
stale_blocker_scan_path="$apple_dir/matrix-stale-blocker-scan.log"

if stale_noncanonical_blockers > "$stale_blocker_scan_path" 2>&1; then
  printf 'stale blocker scan ok\n' >> "$stale_blocker_scan_path"
  record_step "stale noncanonical blocker scan" "pass" "stale_noncanonical_blockers" "$stale_blocker_scan_path" "true"
else
  stale_blocker_details="$(cat "$stale_blocker_scan_path")"
  record_step "stale noncanonical blocker scan" "fail" "stale_noncanonical_blockers" "$stale_blocker_scan_path" "true" "" "$stale_blocker_details"
  overall_status=1
fi
run_required "xcode version" "$apple_dir/matrix-xcode-version.log" bash -c 'xcode_version="$(xcodebuild -version)" && printf "%s\n" "$xcode_version" && first_line="$(printf "%s\n" "$xcode_version" | sed -n "1p")" && minimum_xcode_version="26.5" && version="${first_line#Xcode }" && awk -v version="$version" -v minimum="$minimum_xcode_version" "BEGIN { split(version, actual, \".\"); split(minimum, required, \".\"); exit !((actual[1] + 0) > (required[1] + 0) || ((actual[1] + 0) == (required[1] + 0) && (actual[2] + 0) >= (required[2] + 0))) }"' || overall_status=1
run_required "ruby bundle check" "$apple_dir/matrix-bundle-check.log" scripts/bundle-check.sh || overall_status=1
run_required "swift tests" "$apple_dir/matrix-swift-test.log" swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors || overall_status=1
run_required "swift coverage test" "$apple_dir/matrix-coverage-test.log" swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors || overall_status=1
run_required "swift coverage path" "$coverage_json_path" swift test --show-codecov-path || overall_status=1
if [[ -f "$coverage_json_path" ]]; then
  coverage_json="$(tail -n 1 "$coverage_json_path")"
  run_required "coverage enforcement" "$apple_dir/matrix-coverage-enforce.log" ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include "Sources/SpoonjoyCore" || overall_status=1
fi
run_required "native scenario final" "$apple_dir/matrix-final-scenario.log" scripts/verify-native-scenarios.sh --stage final --output "$apple_dir/matrix-final-report.json" || overall_status=1
run_required "xcode project contract" "$apple_dir/matrix-project-contract.log" scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb || overall_status=1
run_required "xcode generator contract" "$apple_dir/matrix-generator-contract.log" scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb || overall_status=1
run_required "native design contract" "$apple_dir/matrix-native-design-contract.log" ruby scripts/check-native-design-language.rb --web-design-doc "$web_design_doc" || overall_status=1
run_required "native design accessibility contract" "$apple_dir/matrix-design-accessibility-contract.log" ruby scripts/check-design-accessibility-contract.rb || overall_status=1
run_required "kitchen surfaces contract" "$apple_dir/matrix-kitchen-surfaces-contract.log" ruby scripts/check-kitchen-recipe-surfaces.rb || overall_status=1
run_required "cook shopping contract" "$apple_dir/matrix-cook-shopping-contract.log" ruby scripts/check-cook-shopping-surfaces.rb || overall_status=1
run_required "search capture settings contract" "$apple_dir/matrix-search-capture-contract.log" ruby scripts/check-search-capture-settings-surfaces.rb || overall_status=1
run_required "launch screenshot contract" "$apple_dir/matrix-launch-screenshot-contract.log" ruby scripts/check-launch-screenshot-contract.rb || overall_status=1
run_required "AASA validation or blocker" "$apple_dir/matrix-aasa.log" ruby scripts/validate-aasa.rb --artifact-root "$artifact_root" || overall_status=1

for app_intents_entry in "${app_intents_domains[@]}"; do
  IFS=":" read -r app_intents_domain app_intents_log app_intents_blocker <<< "$app_intents_entry"
  app_intents_output="$apple_dir/$app_intents_log"
  app_intents_blocker_path="$apple_dir/$app_intents_blocker"
  if ruby scripts/check-app-intents-contract.rb --domain "$app_intents_domain" > "$app_intents_output" 2>&1; then
    record_step "App Intents ${app_intents_domain}" "pass" "ruby scripts/check-app-intents-contract.rb --domain ${app_intents_domain}" "$app_intents_output" "true"
  elif [[ -f "$app_intents_blocker_path" ]]; then
    validate_blocker_contract "$app_intents_blocker_path" "AppIntentsSDK" || overall_status=1
    record_step "App Intents ${app_intents_domain}" "blocked" "ruby scripts/check-app-intents-contract.rb --domain ${app_intents_domain}" "$app_intents_output" "true" "$app_intents_blocker_path"
  else
    record_step "App Intents ${app_intents_domain}" "fail" "ruby scripts/check-app-intents-contract.rb --domain ${app_intents_domain}" "$app_intents_output" "true"
    overall_status=1
  fi
done

run_script_with_blocker_policy \
  "iOS app bundle" \
  "$apple_dir/matrix-xcodebuild-ios.log" \
  "$apple_dir/matrix-xcode-platform-blocker.json" \
  "XcodePlatform" \
  scripts/run-xcodebuild-with-blocker.sh \
  --output "$apple_dir/matrix-xcodebuild-ios.log" \
  --blocker "$apple_dir/matrix-xcode-platform-blocker.json" \
  --timeout-seconds 180 \
  -- \
  xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build || overall_status=1

if [[ -f "$apple_dir/matrix-xcode-platform-blocker.json" ]]; then
  printf 'macOS app bundle skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-xcodebuild-macos.log"
  record_step "macOS app bundle" "blocked" "skipped after iOS XcodePlatform blocker" "$apple_dir/matrix-xcodebuild-macos.log" "true" "$apple_dir/matrix-xcode-platform-blocker.json"
else
  run_script_with_blocker_policy \
    "macOS app bundle" \
    "$apple_dir/matrix-xcodebuild-macos.log" \
    "$apple_dir/matrix-xcode-platform-blocker.json" \
    "XcodePlatform" \
    scripts/run-xcodebuild-with-blocker.sh \
    --output "$apple_dir/matrix-xcodebuild-macos.log" \
    --blocker "$apple_dir/matrix-xcode-platform-blocker.json" \
    --timeout-seconds 180 \
    -- \
    xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build || overall_status=1
fi

if [[ -f "$apple_dir/matrix-xcode-platform-blocker.json" ]]; then
  write_xcode_screenshot_blocker "$apple_dir/matrix-xcode-platform-blocker.json"
  printf 'macOS launch smoke skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-macos.log"
  printf 'macOS launch smoke inner skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-macos-inner.log"
  record_step "macOS launch smoke" "blocked" "skipped after XcodePlatform blocker" "$apple_dir/matrix-smoke-macos.log" "true" "$apple_dir/matrix-xcode-platform-blocker.json"
  printf 'iOS simulator smoke skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-ios.log"
  printf 'iOS simulator smoke inner skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-ios-inner.log"
  record_step "iOS simulator smoke" "blocked" "skipped after XcodePlatform blocker" "$apple_dir/matrix-smoke-ios.log" "true" "$apple_dir/matrix-xcode-platform-blocker.json"
  printf 'screenshots skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-capture.log"
  record_step "screenshots and design review" "blocked" "skipped after XcodePlatform blocker" "$apple_dir/matrix-capture.log" "true" "$apple_dir/matrix-screenshots-xcode-platform-blocker.json"
  run_required "design review validation" "$apple_dir/matrix-design-review.log" ruby scripts/validate-design-review-blocker.rb "$artifact_root/design-review-blocked.json" --artifact-root "$artifact_root" --unit-slug "matrix" || overall_status=1
else
  run_script_with_blocker_policy "macOS launch smoke" "$apple_dir/matrix-smoke-macos.log" "$apple_dir/matrix-smoke-macos-blocker.json" "MacOSLaunch" scripts/smoke-macos.sh --artifact-root "$artifact_root" --log "$apple_dir/matrix-smoke-macos-inner.log" --blocker "$apple_dir/matrix-smoke-macos-blocker.json" || overall_status=1
  run_script_with_blocker_policy "iOS simulator smoke" "$apple_dir/matrix-smoke-ios.log" "$apple_dir/matrix-smoke-ios-simulator-blocker.json" "CoreSimulator" scripts/smoke-ios-simulator.sh --artifact-root "$artifact_root" --log "$apple_dir/matrix-smoke-ios-inner.log" --blocker "$apple_dir/matrix-smoke-ios-simulator-blocker.json" || overall_status=1
  run_required "screenshots and design review" "$apple_dir/matrix-capture.log" scripts/capture-native-screenshots.sh --artifact-root "$artifact_root" --unit-slug "matrix" || overall_status=1
  if [[ -f "$artifact_root/design-review-blocked.json" && -f "$artifact_root/design-review.json" ]]; then
    printf 'conflicting design review success and blocker artifacts\n' > "$apple_dir/matrix-design-review.log"
    overall_status=1
  elif [[ -f "$artifact_root/design-review-blocked.json" ]]; then
    run_required "design review validation" "$apple_dir/matrix-design-review.log" ruby scripts/validate-design-review-blocker.rb "$artifact_root/design-review-blocked.json" --artifact-root "$artifact_root" --unit-slug "matrix" || overall_status=1
  else
    run_required "design review validation" "$apple_dir/matrix-design-review.log" ruby scripts/validate-design-review.rb "$artifact_root/design-review.json" || overall_status=1
  fi
fi
matrix_warning_logs=(
  "$stale_blocker_scan_path"
  "$apple_dir/matrix-xcode-version.log"
  "$apple_dir/matrix-bundle-check.log"
  "$apple_dir/matrix-swift-test.log"
  "$apple_dir/matrix-coverage-test.log"
  "$coverage_json_path"
  "$apple_dir/matrix-coverage-enforce.log"
  "$apple_dir/matrix-final-scenario.log"
  "$apple_dir/matrix-project-contract.log"
  "$apple_dir/matrix-generator-contract.log"
  "$apple_dir/matrix-native-design-contract.log"
  "$apple_dir/matrix-design-accessibility-contract.log"
  "$apple_dir/matrix-kitchen-surfaces-contract.log"
  "$apple_dir/matrix-cook-shopping-contract.log"
  "$apple_dir/matrix-search-capture-contract.log"
  "$apple_dir/matrix-launch-screenshot-contract.log"
  "$apple_dir/matrix-aasa.log"
  "$apple_dir/matrix-smoke-ios-inner.log"
  "$apple_dir/matrix-smoke-macos-inner.log"
  "$apple_dir/matrix-xcodebuild-ios.log"
  "$apple_dir/matrix-xcodebuild-macos.log"
  "$apple_dir/matrix-smoke-macos.log"
  "$apple_dir/matrix-smoke-ios.log"
  "$apple_dir/matrix-capture.log"
  "$apple_dir/matrix-design-review.log"
)
for app_intents_entry in "${app_intents_domains[@]}"; do
  IFS=":" read -r _app_intents_domain app_intents_log _app_intents_blocker <<< "$app_intents_entry"
  matrix_warning_logs+=("$apple_dir/$app_intents_log")
done
matrix_warning_args=()
for matrix_warning_log in "${matrix_warning_logs[@]}"; do
  matrix_warning_args+=(--log "$matrix_warning_log")
done
run_required "warning scan" "$apple_dir/matrix-warning-scan.log" scripts/fail-on-warning.rb "${matrix_warning_args[@]}" || overall_status=1

ruby -rjson -rtime -e '
  results_path, matrix_path, artifact_root = ARGV
  steps = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
  blocker_paths = steps.map { |step| step["blockerPath"] }.compact
  blocker_paths += [
    File.join(artifact_root, "aasa-production-blocker.json"),
    File.join(artifact_root, "apple/matrix-xcode-platform-blocker.json"),
    File.join(artifact_root, "apple/matrix-smoke-macos-blocker.json"),
    File.join(artifact_root, "apple/matrix-smoke-ios-simulator-blocker.json"),
    File.join(artifact_root, "apple/matrix-screenshots-xcode-platform-blocker.json"),
    File.join(artifact_root, "apple/matrix-screenshots-core-simulator-blocker.json"),
    File.join(artifact_root, "apple/matrix-screenshots-macos-launch-blocker.json"),
    File.join(artifact_root, "apple/apple-developer-program-blocker-apns.json")
  ]
  blocker_paths.concat(Dir[File.join(artifact_root, "apple/appintents-sdk-blocker-*.json")])
  blocker_paths.concat(Dir[File.join(artifact_root, "web/provider-secret-blocker-*.json")])
  blocker_paths.concat(Dir[File.join(artifact_root, "human-credential-blocker-*.json")])
  allowed_capabilities = %w[
    CoreSimulator
    XcodePlatform
    MacOSLaunch
    AASAProductionValidation
    AppIntentsSDK
    AppleDeveloperProgram
    ProviderSecret
    HumanCredential
  ]
  def canonical_capability(path, artifact_root)
    expanded_root = File.expand_path(artifact_root)
    expanded_path = File.expand_path(path)
    relative = expanded_path.sub(/\A#{Regexp.escape(expanded_root)}\/?/, "")
    case relative
    when "aasa-production-blocker.json" then "AASAProductionValidation"
    when "apple/matrix-xcode-platform-blocker.json", "apple/matrix-screenshots-xcode-platform-blocker.json" then "XcodePlatform"
    when "apple/matrix-smoke-ios-simulator-blocker.json", "apple/matrix-screenshots-core-simulator-blocker.json" then "CoreSimulator"
    when "apple/matrix-smoke-macos-blocker.json", "apple/matrix-screenshots-macos-launch-blocker.json" then "MacOSLaunch"
    when "apple/apple-developer-program-blocker-apns.json" then "AppleDeveloperProgram"
    when %r{\Aapple/appintents-sdk-blocker-[a-z0-9-]+\.json\z} then "AppIntentsSDK"
    when %r{\Aweb/provider-secret-blocker-[a-z0-9-]+\.json\z} then "ProviderSecret"
    when %r{\Ahuman-credential-blocker-[a-z0-9-]+\.json\z} then "HumanCredential"
    end
  end
  def validate_blocker_contract(blocker, path, allowed_capabilities, artifact_root)
    failures = []
    %w[blocked capability command outputPath reason ownerAction].each do |key|
      failures << "#{path} missing #{key}" if blocker[key].nil? || blocker[key].to_s.strip.empty?
    end
    failures << "#{path} blocked must be true" unless blocker["blocked"] == true
    capability = blocker["capability"]
    failures << "#{path} unsupported capability #{capability.inspect}" unless allowed_capabilities.include?(capability)
    failures << "#{path} ProductionOperationApproval is Unit 27-only" if capability == "ProductionOperationApproval"
    expected = canonical_capability(path, artifact_root)
    failures << "#{path} is not a canonical final blocker path" if expected.nil?
    failures << "#{path} expected #{expected}, got #{capability}" if expected && capability != expected
    failures
  end
  blockers = blocker_paths.uniq.map do |path|
    next unless File.file?(path)
    JSON.parse(File.read(path)).merge("path" => path)
  end.compact
  blocker_failures = blockers.flat_map { |blocker| validate_blocker_contract(blocker, blocker.fetch("path"), allowed_capabilities, artifact_root) }
  passed_steps = steps.select { |step| step["status"] == "pass" }
  failed_steps = steps.select { |step| step["status"] == "fail" }
  blocked_steps = steps.select { |step| step["status"] == "blocked" }
  ok = failed_steps.empty? && blocker_failures.empty?
  fully_validated = ok && blocked_steps.empty?
  result = if fully_validated
    "pass"
  elsif ok
    "blocked"
  else
    "fail"
  end
  File.write(matrix_path, JSON.pretty_generate({
    ok: ok,
    fullyValidated: fully_validated,
    result: result,
    generatedAt: Time.now.utc.iso8601,
    counts: {
      passed: passed_steps.length,
      failed: failed_steps.length,
      blocked: blocked_steps.length,
      blockerFailures: blocker_failures.length
    },
    steps: steps,
    blockers: blockers,
    blockerFailures: blocker_failures,
    externalValidationLog: File.join(artifact_root, "apple/unit-26b-native-full-validation-validate-native-local.log")
  }) + "\n")
  exit(ok ? 0 : 1)
' "$results_path" "$matrix_path" "$artifact_root" || overall_status=1

printf 'external validation log expected: %s\n' "$apple_dir/$unit_26b_validate_log_name"
exit "$overall_status"
