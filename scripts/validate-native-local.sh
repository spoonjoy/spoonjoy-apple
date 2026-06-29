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
rm -f \
  "$results_path" \
  "$matrix_path" \
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
  ruby -rjson -e '
    path, name, status, command, output_path, required, blocker_path = ARGV
    row = {
      name: name,
      status: status,
      command: command,
      outputPath: output_path,
      required: required == "true"
    }
    row[:blockerPath] = blocker_path unless blocker_path.empty?
    File.open(path, "a") { |file| file.puts(JSON.generate(row)) }
  ' "$results_path" "$name" "$status" "$command" "$output_path" "$required" "$blocker_path"
}

write_xcode_screenshot_blocker() {
  local source_blocker="$1"
  local screenshot_blocker="$apple_dir/matrix-screenshots-xcode-platform-blocker.json"
  local design_review_blocked="$artifact_root/design-review-blocked.json"
  ruby -rjson -e '
    source_path, screenshot_path, design_review_blocked_path = ARGV
    source = JSON.parse(File.read(source_path))
    screenshot_blocker = source.merge(
      "capability" => "XcodePlatform",
      "blocked" => true,
      "command" => "screenshots skipped after app-bundle XcodePlatform blocker",
      "outputPath" => screenshot_path.sub(/-blocker\.json\z/, ".log")
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

run_required "xcode version" "$apple_dir/matrix-xcode-version.log" bash -c 'xcode_version="$(xcodebuild -version)" && printf "%s\n" "$xcode_version" && first_line="$(printf "%s\n" "$xcode_version" | sed -n "1p")" && test "$first_line" = "Xcode 26.5"' || overall_status=1
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

run_script_with_blocker_policy \
  "iOS app bundle" \
  "$apple_dir/matrix-xcodebuild-ios.log" \
  "$apple_dir/matrix-xcode-platform-blocker.json" \
  "XcodePlatform" \
  scripts/run-xcodebuild-with-blocker.sh \
  --output "$apple_dir/matrix-xcodebuild-ios.log" \
  --blocker "$apple_dir/matrix-xcode-platform-blocker.json" \
  --timeout-seconds 30 \
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
    --timeout-seconds 30 \
    -- \
    xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build || overall_status=1
fi

if [[ -f "$apple_dir/matrix-xcode-platform-blocker.json" ]]; then
  write_xcode_screenshot_blocker "$apple_dir/matrix-xcode-platform-blocker.json"
  printf 'macOS launch smoke skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-macos.log"
  record_step "macOS launch smoke" "blocked" "skipped after XcodePlatform blocker" "$apple_dir/matrix-smoke-macos.log" "true" "$apple_dir/matrix-xcode-platform-blocker.json"
  printf 'iOS simulator smoke skipped because shared XcodePlatform blocker already exists\n' > "$apple_dir/matrix-smoke-ios.log"
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
  "$apple_dir/matrix-xcodebuild-ios.log"
  "$apple_dir/matrix-xcodebuild-macos.log"
  "$apple_dir/matrix-smoke-macos.log"
  "$apple_dir/matrix-smoke-ios.log"
  "$apple_dir/matrix-capture.log"
  "$apple_dir/matrix-design-review.log"
)
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
    File.join(artifact_root, "apple/matrix-screenshots-macos-launch-blocker.json")
  ]
  blockers = blocker_paths.uniq.map do |path|
    next unless File.file?(path)
    JSON.parse(File.read(path)).merge("path" => path)
  end.compact
  accepted_blockers = blockers.all? { |blocker| ["CoreSimulator", "XcodePlatform", "MacOSLaunch", "AASAProductionValidation"].include?(blocker["capability"]) }
  failed_steps = steps.select { |step| step["status"] == "fail" }
  ok = failed_steps.empty? && accepted_blockers
  File.write(matrix_path, JSON.pretty_generate({
    ok: ok,
    generatedAt: Time.now.utc.iso8601,
    steps: steps,
    blockers: blockers
  }) + "\n")
  exit(ok ? 0 : 1)
' "$results_path" "$matrix_path" "$artifact_root" || overall_status=1

exit "$overall_status"
