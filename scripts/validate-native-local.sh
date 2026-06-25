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

mkdir -p "$artifact_root"
matrix_path="$artifact_root/validation-matrix.json"
results_path="$artifact_root/validation-matrix.jsonl"
web_design_doc="docs/source/spoonjoy-v2-design-language.md"
rm -f "$results_path" "$matrix_path"

required_hooks=(
  "scripts/fail-on-warning.rb"
  "scripts/enforce-swift-coverage.rb"
  "scripts/verify-native-scenarios.sh"
  "scripts/check-xcode-project-contract.rb"
  "scripts/check-xcode-generator-contract.rb"
  "scripts/bundle-check.sh"
  "scripts/bundle-exec.sh"
  "scripts/check-native-design-language.rb"
  "scripts/check-kitchen-recipe-surfaces.rb"
  "scripts/check-cook-shopping-surfaces.rb"
  "scripts/check-search-capture-settings-surfaces.rb"
  "scripts/check-launch-screenshot-contract.rb"
  "scripts/run-xcodebuild-with-blocker.sh"
  "scripts/smoke-macos.sh"
  "scripts/smoke-ios-simulator.sh"
  "scripts/capture-native-screenshots.sh"
  "scripts/validate-design-review.rb"
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
coverage_json_path="$artifact_root/coverage-json-path.log"

run_required "xcode version" "$artifact_root/matrix-xcode-version.log" bash -lc 'xcode_version="$(xcodebuild -version)" && printf "%s\n" "$xcode_version" && first_line="$(printf "%s\n" "$xcode_version" | sed -n "1p")" && test "$first_line" = "Xcode 26.5"' || overall_status=1
run_required "ruby bundle check" "$artifact_root/matrix-bundle-check.log" scripts/bundle-check.sh || overall_status=1
run_required "swift tests" "$artifact_root/matrix-swift-test.log" swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors || overall_status=1
run_required "swift coverage test" "$artifact_root/matrix-coverage-test.log" swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors || overall_status=1
run_required "swift coverage path" "$coverage_json_path" swift test --show-codecov-path || overall_status=1
if [[ -f "$coverage_json_path" ]]; then
  coverage_json="$(tail -n 1 "$coverage_json_path")"
  run_required "coverage enforcement" "$artifact_root/matrix-coverage-enforce.log" ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include "Sources/SpoonjoyCore" || overall_status=1
fi
run_required "native scenario final" "$artifact_root/matrix-final-scenario.log" scripts/verify-native-scenarios.sh --stage final --output "$artifact_root/matrix-final-report.json" || overall_status=1
run_required "xcode project contract" "$artifact_root/matrix-project-contract.log" scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb || overall_status=1
run_required "xcode generator contract" "$artifact_root/matrix-generator-contract.log" scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb || overall_status=1
run_required "native design contract" "$artifact_root/matrix-native-design-contract.log" ruby scripts/check-native-design-language.rb --web-design-doc "$web_design_doc" || overall_status=1
run_required "kitchen surfaces contract" "$artifact_root/matrix-kitchen-surfaces-contract.log" ruby scripts/check-kitchen-recipe-surfaces.rb || overall_status=1
run_required "cook shopping contract" "$artifact_root/matrix-cook-shopping-contract.log" ruby scripts/check-cook-shopping-surfaces.rb || overall_status=1
run_required "search capture settings contract" "$artifact_root/matrix-search-capture-contract.log" ruby scripts/check-search-capture-settings-surfaces.rb || overall_status=1
run_required "launch screenshot contract" "$artifact_root/matrix-launch-screenshot-contract.log" ruby scripts/check-launch-screenshot-contract.rb || overall_status=1
run_required "AASA validation or blocker" "$artifact_root/matrix-aasa.log" ruby scripts/validate-aasa.rb --artifact-root "$artifact_root" || overall_status=1

run_script_with_blocker_policy \
  "iOS app bundle" \
  "$artifact_root/matrix-xcodebuild-ios.log" \
  "$artifact_root/ios-app-bundle-blocker.json" \
  "XcodePlatform" \
  scripts/run-xcodebuild-with-blocker.sh \
  --output "$artifact_root/matrix-xcodebuild-ios.log" \
  --blocker "$artifact_root/ios-app-bundle-blocker.json" \
  --timeout-seconds 30 \
  -- \
  xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build || overall_status=1

run_script_with_blocker_policy \
  "macOS app bundle" \
  "$artifact_root/matrix-xcodebuild-macos.log" \
  "$artifact_root/macos-app-bundle-blocker.json" \
  "XcodePlatform" \
  scripts/run-xcodebuild-with-blocker.sh \
  --output "$artifact_root/matrix-xcodebuild-macos.log" \
  --blocker "$artifact_root/macos-app-bundle-blocker.json" \
  --timeout-seconds 30 \
  -- \
  xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build || overall_status=1
run_script_with_blocker_policy "macOS launch smoke" "$artifact_root/matrix-smoke-macos.log" "$artifact_root/smoke-macos-blocker.json" "" scripts/smoke-macos.sh --artifact-root "$artifact_root" || overall_status=1
run_script_with_blocker_policy "iOS simulator smoke" "$artifact_root/matrix-smoke-ios.log" "$artifact_root/smoke-ios-simulator-blocker.json" "CoreSimulator" scripts/smoke-ios-simulator.sh --artifact-root "$artifact_root" || overall_status=1
run_required "screenshots and design review" "$artifact_root/matrix-capture.log" scripts/capture-native-screenshots.sh --artifact-root "$artifact_root" || overall_status=1
run_required "design review validation" "$artifact_root/matrix-design-review.log" ruby scripts/validate-design-review.rb "$artifact_root/design-review.json" || overall_status=1
run_required "warning scan" "$artifact_root/matrix-warning-scan.log" scripts/fail-on-warning.rb --log "$artifact_root/matrix-swift-test.log" "$artifact_root/matrix-coverage-test.log" "$artifact_root/matrix-final-scenario.log" "$artifact_root/matrix-xcodebuild-macos.log" "$artifact_root/matrix-smoke-macos.log" || overall_status=1

ruby -rjson -rtime -e '
  results_path, matrix_path, artifact_root = ARGV
  steps = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
  blocker_paths = steps.map { |step| step["blockerPath"] }.compact
  blocker_paths += [
    File.join(artifact_root, "aasa-production-blocker.json"),
    File.join(artifact_root, "smoke-macos-blocker.json"),
    File.join(artifact_root, "smoke-ios-simulator-blocker.json")
  ]
  blockers = blocker_paths.uniq.map do |path|
    next unless File.file?(path)
    JSON.parse(File.read(path)).merge("path" => path)
  end.compact
  accepted_blockers = blockers.all? { |blocker| ["CoreSimulator", "XcodePlatform", "AASAProductionValidation"].include?(blocker["capability"]) }
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
