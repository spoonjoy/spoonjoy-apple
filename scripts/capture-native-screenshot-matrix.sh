#!/usr/bin/env bash
set -euo pipefail

artifact_root="${SPOONJOY_NATIVE_ARTIFACT_ROOT:-artifacts/apple/native-screenshot-matrix}"
unit_slug="matrix"
require_full_matrix=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    --unit-slug)
      unit_slug="$2"
      shift 2
      ;;
    --require-full-matrix)
      require_full_matrix=1
      shift
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
routes_dir="$artifact_root/screenshot-routes"
shared_build_dir="$artifact_root/shared-builds"
repo_root="$(pwd -P)"
results_path="$apple_dir/${unit_slug}-route-matrix.jsonl"
summary_path="$apple_dir/${unit_slug}-route-matrix.json"
route_timeout_seconds="${SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS:-900}"
matrix_build_timeout_seconds="${SPOONJOY_SCREENSHOT_MATRIX_BUILD_TIMEOUT_SECONDS:-900}"
reset_simulator_between_routes="${SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES:-0}"
matrix_routes="${SPOONJOY_SCREENSHOT_MATRIX_ROUTES:-}"
shared_ios_app_path="${SPOONJOY_SCREENSHOT_IOS_APP_PATH:-}"
shared_ios_ui_test_runner_path="${SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH:-}"
shared_ios_xctestrun_path="${SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH:-}"
shared_macos_app_path="${SPOONJOY_SCREENSHOT_MACOS_APP_PATH:-}"
provenance_manifest="${SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST:-}"
matrix_run_uuid="${SPOONJOY_SCREENSHOT_PROVENANCE_RUN_UUID:-$(ruby -rsecurerandom -e 'print SecureRandom.uuid')}"
provenance_log="$apple_dir/${unit_slug}-provenance.log"
transition_evidence="$apple_dir/${unit_slug}-transition-evidence.json"
transition_evidence_log="$apple_dir/${unit_slug}-transition-evidence.log"
provenance_verified_before=0
provenance_verified_after=0
shared_build_blocker="$apple_dir/${unit_slug}-shared-build-blocker.json"
shared_xcode_blocker="$apple_dir/${unit_slug}-shared-xcode-platform-blocker.json"
shared_simulator_log="$apple_dir/${unit_slug}-shared-simulator-selection.log"
ios_install_marker="$apple_dir/${unit_slug}-ios-installed.marker"
configured_ios_install_marker="${SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER:-$ios_install_marker}"
matrix_routes="${matrix_routes//[[:space:]]/}"

mkdir -p "$apple_dir" "$routes_dir"
rm -rf "$routes_dir"
mkdir -p "$routes_dir"
rm -f \
  "$results_path" \
  "$summary_path" \
  "$shared_build_blocker" \
  "$shared_xcode_blocker" \
  "$shared_simulator_log" \
  "$provenance_log" \
  "$transition_evidence" \
  "$transition_evidence_log" \
  "$apple_dir/${unit_slug}-transition-evidence-blocker.json" \
  "$ios_install_marker" \
  "$ios_install_marker-iphone" \
  "$ios_install_marker-ipad" \
  "$configured_ios_install_marker" \
  "$configured_ios_install_marker-iphone" \
  "$configured_ios_install_marker-ipad"

write_shared_build_blocker() {
  local platform="$1"
  local command="$2"
  local output_path="$3"
  local reason="$4"
  local source_blocker_path="${5:-}"
  ruby -rjson -rdigest -e '
    path, platform, command, timeout_seconds, output_path, reason, source_blocker_path = ARGV
    blocker = {
      "blocked" => true,
      "capability" => "ScreenshotMatrixSharedBuild",
      "platform" => platform,
      "command" => command,
      "timeoutSeconds" => Integer(timeout_seconds),
      "outputPath" => output_path,
      "reason" => reason,
      "ownerAction" => "Inspect the shared matrix build log or source blocker, fix the app bundle build, and rerun the screenshot route matrix."
    }
    blocker["sourceBlockerPath"] = source_blocker_path unless source_blocker_path.empty?
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$shared_build_blocker" "$platform" "$command" "$matrix_build_timeout_seconds" "$output_path" "$reason" "$source_blocker_path"
}

pin_simulator_family() {
  local family="$1"
  local label="$2"
  local configured_udid="$3"
  local selected_udid="$configured_udid"
  local destination=""

  if [[ -z "$selected_udid" ]]; then
    set +e
    destination="$(
      env \
        -u SPOONJOY_IOS_SIMULATOR_UDID \
        -u SPOONJOY_IOS_SIMULATOR_NAME \
        SPOONJOY_IOS_SIMULATOR_FAMILY="$family" \
        python3 .github/scripts/resolve-ios-simulator-destination.py \
        2>> "$shared_simulator_log"
    )"
    local resolver_status=$?
    set -e
    if [[ "$resolver_status" -ne 0 || "$destination" != platform=iOS\ Simulator,id=* ]]; then
      write_shared_build_blocker \
        "ios-$family" \
        "SPOONJOY_IOS_SIMULATOR_FAMILY=$family python3 .github/scripts/resolve-ios-simulator-destination.py" \
        "$shared_simulator_log" \
        "The screenshot matrix could not pin one $label simulator for deterministic route capture."
      return 1
    fi
    selected_udid="${destination##*,id=}"
  fi

  if [[ "$family" == "iphone" ]]; then
    export SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID="$selected_udid"
  else
    export SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID="$selected_udid"
  fi
  printf 'Pinned %s simulator for route matrix: %s\n' "$label" "$selected_udid" | tee -a "$shared_simulator_log"
}

prepare_shared_builds() {
  mkdir -p "$shared_build_dir"
  local has_ios_override=0
  local has_macos_override=0
  [[ -n "$shared_ios_app_path" ]] && has_ios_override=1
  [[ -n "$shared_macos_app_path" ]] && has_macos_override=1

  if [[ "$has_ios_override" -ne "$has_macos_override" ]]; then
    printf 'prebuilt app overrides must provide both iOS and macOS app paths\n' >&2
    write_shared_build_blocker \
      "provenance" \
      "validate prebuilt screenshot apps" \
      "$provenance_log" \
      "Exact-source provenance rejected an incomplete prebuilt app override."
    return 1
  fi

  if [[ "$has_ios_override" -eq 1 ]]; then
    if [[ -z "$provenance_manifest" ]]; then
      printf 'prebuilt app overrides require SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST\n' >&2
      write_shared_build_blocker \
        "provenance" \
        "validate prebuilt screenshot provenance" \
        "$provenance_log" \
        "Exact-source provenance rejected prebuilt app overrides without a manifest."
      return 1
    fi
  else
    rm -f "$apple_dir/${unit_slug}-screenshot-provenance.json"
    printf 'building exact-source iOS and macOS apps for route matrix\n'
    set +e
    ruby scripts/native-screenshot-provenance.rb build \
      --repo-root "$repo_root" \
      --artifact-root "$artifact_root" \
      --unit-slug "$unit_slug" \
      --matrix-run-uuid "$matrix_run_uuid" \
      --timeout-seconds "$matrix_build_timeout_seconds" \
      > "$provenance_log" 2>&1
    local provenance_build_status=$?
    set -e
    if [[ "$provenance_build_status" -ne 0 ]]; then
      cat "$provenance_log" >&2
      write_shared_build_blocker \
        "provenance" \
        "ruby scripts/native-screenshot-provenance.rb build" \
        "$provenance_log" \
        "Exact-source provenance could not create clean, immutable screenshot products."
      return 1
    fi
    provenance_manifest="$(tail -n 1 "$provenance_log")"
    shared_ios_app_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "ios", "captureAppPath")' "$provenance_manifest")"
    shared_ios_ui_test_runner_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "ios", "captureUITestRunnerPath")' "$provenance_manifest")"
    shared_ios_xctestrun_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "ios", "captureXctestrunPath")' "$provenance_manifest")"
    shared_macos_app_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "macos", "appPath")' "$provenance_manifest")"
  fi

  if [[ -z "$shared_ios_ui_test_runner_path" || -z "$shared_ios_xctestrun_path" ]]; then
    shared_ios_ui_test_runner_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "ios", "captureUITestRunnerPath")' "$provenance_manifest")"
    shared_ios_xctestrun_path="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).dig("builds", "ios", "captureXctestrunPath")' "$provenance_manifest")"
  fi

  if ! verify_provenance "before"; then
    cat "$provenance_log" >&2
    write_shared_build_blocker \
      "provenance" \
      "ruby scripts/native-screenshot-provenance.rb verify" \
      "$provenance_log" \
      "Exact-source provenance verification failed before screenshot capture."
    return 1
  fi
  provenance_verified_before=1

  pin_simulator_family "iphone" "iPhone" "${SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID:-}" || return 1
  pin_simulator_family "ipad" "iPad" "${SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID:-}" || return 1

  export SPOONJOY_SCREENSHOT_IOS_APP_PATH="$shared_ios_app_path"
  export SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH="$shared_ios_ui_test_runner_path"
  export SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH="$shared_ios_xctestrun_path"
  export SPOONJOY_SCREENSHOT_MACOS_APP_PATH="$shared_macos_app_path"
  export SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP="${SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP:-1}"
  export SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER="$configured_ios_install_marker"
  export SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST="$provenance_manifest"
  export SPOONJOY_SCREENSHOT_PROVENANCE_RUN_UUID="$matrix_run_uuid"
  printf 'route matrix using attested iOS capture app: %s\n' "$SPOONJOY_SCREENSHOT_IOS_APP_PATH"
  printf 'route matrix using attested iOS UI-test runner: %s\n' "$SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH"
  printf 'route matrix using shared macOS app: %s\n' "$SPOONJOY_SCREENSHOT_MACOS_APP_PATH"
}

verify_provenance() {
  local phase="$1"
  printf 'verifying screenshot provenance %s matrix capture\n' "$phase" >> "$provenance_log"
  ruby scripts/native-screenshot-provenance.rb verify \
    --manifest "$provenance_manifest" \
    --repo-root "$repo_root" \
    --artifact-root "$artifact_root" \
    --unit-slug "$unit_slug" \
    --matrix-run-uuid "$matrix_run_uuid" \
    --ios-app "$shared_ios_app_path" \
    --macos-app "$shared_macos_app_path" \
    >> "$provenance_log" 2>&1
}

record_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local status="$4"
  local command="$5"
  ruby -rjson -rdigest -e '
    results_path, name, route, route_root, status, command = ARGV
    def artifact(path, relative_path)
      absolute = File.join(path, relative_path)
      {
        "path" => absolute,
        "exists" => File.file?(absolute),
        "bytes" => File.file?(absolute) ? File.size(absolute) : nil,
        "sha256" => File.file?(absolute) ? Digest::SHA256.file(absolute).hexdigest : nil
      }
    end
    design_review = artifact(route_root, "design-review.json")
    design_review_blocked = artifact(route_root, "design-review-blocked.json")
    row = {
      "name" => name,
      "route" => route,
      "artifactRoot" => route_root,
      "status" => status,
      "command" => command,
      "blocked" => design_review_blocked.fetch("exists"),
      "missingDesignReview" => !design_review.fetch("exists") && !design_review_blocked.fetch("exists"),
      "designReview" => design_review,
      "designReviewBlocked" => design_review_blocked,
      "iosScreenshot" => artifact(route_root, "screenshots/ios-mobile.png"),
      "iosAccessibilityScreenshot" => artifact(route_root, "screenshots/ios-mobile-accessibility.png"),
      "iosTabletScreenshot" => artifact(route_root, "screenshots/ios-tablet.png"),
      "macosScreenshot" => artifact(route_root, "screenshots/macos-desktop.png")
    }
    File.open(results_path, "a") { |file| file.puts(JSON.generate(row)) }
  ' "$results_path" "$name" "$route" "$route_root" "$status" "$command"
}

write_route_timeout_blocker() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
  local command="$5"
  local output_path="$6"
  mkdir -p "$route_root/apple"
  ruby -rjson -rfileutils -e '
    name, route, route_root, route_slug, command, output_path, timeout_seconds = ARGV
    source_path = File.join(route_root, "apple/#{route_slug}-screenshot-route-timeout-blocker.json")
    review_path = File.join(route_root, "design-review-blocked.json")
    reason = "Screenshot route #{name} exceeded #{timeout_seconds} seconds before producing terminal screenshot artifacts."
    owner_action = "Inspect the route capture log and fix the local screenshot harness or app launch hang, then rerun the screenshot route matrix."
    source_blocker = {
      "blocked" => true,
      "capability" => "ScreenshotRouteTimeout",
      "route" => route,
      "command" => command,
      "timeoutSeconds" => Integer(timeout_seconds),
      "outputPath" => output_path,
      "reason" => reason,
      "ownerAction" => owner_action
    }
    design_review_blocked = {
      "blocked" => true,
      "capability" => "ScreenshotRouteTimeout",
      "sourceBlockerPath" => source_path,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/ios-mobile-accessibility.png",
        "screenshots/ios-tablet.png",
        "screenshots/ios-mobile-deep-scroll.png",
        "screenshots/ios-mobile-accessibility-deep-scroll.png",
        "screenshots/ios-tablet-deep-scroll.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/#{route_slug}-accessibility-proof-ios.json",
        "apple/#{route_slug}-accessibility-proof-ios-ax.json",
        "apple/#{route_slug}-accessibility-proof-ipad.json",
        "apple/#{route_slug}-accessibility-proof-macos.json",
        "apple/#{route_slug}-observed-accessibility-ios.json",
        "apple/#{route_slug}-observed-accessibility-ios-ax.json",
        "apple/#{route_slug}-observed-accessibility-ipad.json",
        "apple/#{route_slug}-observed-accessibility-macos.json"
      ],
      "reason" => reason,
      "ownerAction" => owner_action,
      "timeoutSeconds" => Integer(timeout_seconds)
    }
    FileUtils.mkdir_p(File.dirname(source_path))
    File.write(source_path, JSON.pretty_generate(source_blocker) + "\n")
    File.write(review_path, JSON.pretty_generate(design_review_blocked) + "\n")
  ' "$name" "$route" "$route_root" "$route_slug" "$command" "$output_path" "$route_timeout_seconds"
  rm -f "$route_root/screenshots/ios-mobile.png" "$route_root/screenshots/ios-mobile-accessibility.png" "$route_root/screenshots/ios-tablet.png" "$route_root/screenshots/ios-mobile-deep-scroll.png" "$route_root/screenshots/ios-mobile-accessibility-deep-scroll.png" "$route_root/screenshots/ios-tablet-deep-scroll.png" "$route_root/screenshots/macos-desktop.png"
  rm -f "$route_root/design-review.json"
  rm -f "$route_root/apple/${route_slug}-accessibility-proof-ios.json" "$route_root/apple/${route_slug}-accessibility-proof-ios-ax.json" "$route_root/apple/${route_slug}-accessibility-proof-ipad.json" "$route_root/apple/${route_slug}-accessibility-proof-macos.json"
  rm -f "$route_root/apple/${route_slug}-observed-accessibility-ios.json" "$route_root/apple/${route_slug}-observed-accessibility-ios-ax.json" "$route_root/apple/${route_slug}-observed-accessibility-ipad.json" "$route_root/apple/${route_slug}-observed-accessibility-macos.json"
}

run_route_capture_with_timeout() {
  local output_path="$1"
  shift
  python3 - "$route_timeout_seconds" "$output_path" "$@" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
output_path = sys.argv[2]
command = sys.argv[3:]

with open(output_path, "wb") as output:
    process = subprocess.Popen(
        command,
        stdout=output,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        sys.exit(process.wait(timeout=timeout_seconds))
    except subprocess.TimeoutExpired:
        output.write(f"\nCommand timed out after {timeout_seconds} seconds\n".encode())
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        time.sleep(0.2)
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        process.wait()
        sys.exit(124)
PY
}

summarize_routes() {
  local expected_route_names=()
  local entry name route route_root route_slug
  for entry in "${routes[@]}"; do
    IFS="|" read -r name route route_root route_slug <<< "$entry"
    expected_route_names+=("$name")
  done
  local expected_route_names_csv
  expected_route_names_csv="$(IFS=,; printf '%s' "${expected_route_names[*]}")"
  ruby -rjson -rdigest -rtime -e '
    results_path, summary_path, shared_build_blocker_path, provenance_manifest_path, transition_evidence_path, artifact_root, verified_before, verified_after, expected_routes_csv, selected_routes_csv, require_full = ARGV
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    expected_routes = expected_routes_csv.split(",")
    route_names = rows.map { |row| row["name"] }
    duplicate_routes = route_names.group_by(&:itself).select { |_name, values| values.length > 1 }.keys
    unexpected_routes = route_names - expected_routes
    missing_routes = expected_routes - route_names
    missing = rows.select { |row| row["missingDesignReview"] }
    blocked = rows.select { |row| row["blocked"] }
    failed = rows.select { |row| row["status"] != "pass" }
    screenshot_keys = %w[iosScreenshot iosAccessibilityScreenshot iosTabletScreenshot macosScreenshot]
    missing_screenshots = rows.select do |row|
      screenshot_keys.any? do |key|
        artifact = row[key]
        !artifact.is_a?(Hash) || artifact["exists"] != true || !artifact["bytes"].is_a?(Integer) || !artifact["bytes"].positive? ||
          !artifact["sha256"].is_a?(String) || artifact["sha256"] !~ /\A[0-9a-f]{64}\z/
      end
    end
    build_blocker = File.file?(shared_build_blocker_path) ? JSON.parse(File.read(shared_build_blocker_path)) : nil
    before_ok = verified_before == "1"
    after_ok = verified_after == "1"
    provenance = File.file?(provenance_manifest_path) ? JSON.parse(File.read(provenance_manifest_path)) : nil
    transition = File.file?(transition_evidence_path) ? JSON.parse(File.read(transition_evidence_path)) : nil
    transition_log_path = transition&.dig("log", "path")
    transition_log_absolute = transition_log_path.is_a?(String) ? File.join(artifact_root, transition_log_path) : nil
    expected_contracts = %w[search-pending-suppresses-empty-state recipe-publishes-before-cook-history]
    transition_ok = transition.is_a?(Hash) && transition["schemaVersion"] == 1 && transition["ok"] == true &&
      transition["sourceSha"] == provenance&.dig("source", "sha") &&
      transition["sourceTree"] == provenance&.dig("source", "tree") &&
      transition["contracts"].is_a?(Array) && transition["contracts"].map { |contract| contract["id"] } == expected_contracts &&
      transition_log_absolute && File.file?(transition_log_absolute) && File.size(transition_log_absolute).positive? &&
      transition.dig("log", "bytes") == File.size(transition_log_absolute) &&
      transition.dig("log", "sha256") == Digest::SHA256.file(transition_log_absolute).hexdigest
    ok = !rows.empty? && build_blocker.nil? && missing.empty? && blocked.empty? && failed.empty? && missing_screenshots.empty? &&
      duplicate_routes.empty? && unexpected_routes.empty? && before_ok && after_ok && !provenance.nil? && transition_ok
    complete_route_set = selected_routes_csv.empty? && route_names == expected_routes
    fully_validated = ok && complete_route_set
    File.write(summary_path, JSON.pretty_generate({
      "ok" => ok,
      "fullyValidated" => fully_validated,
      "generatedAt" => Time.now.utc.iso8601,
      "routeCount" => rows.length,
      "expectedRouteCount" => expected_routes.length,
      "expectedRoutes" => expected_routes,
      "selectedRoutes" => route_names,
      "completeRouteSet" => complete_route_set,
      "buildBlocked" => !build_blocker.nil?,
      "buildBlocker" => build_blocker,
      "provenanceVerifiedBefore" => before_ok,
      "provenanceVerifiedAfter" => after_ok,
      "provenanceManifestPath" => provenance_manifest_path,
      "provenanceManifestSha256" => provenance&.fetch("manifestSha256", nil),
      "transitionEvidenceValidated" => transition_ok,
      "transitionEvidencePath" => transition_evidence_path,
      "transitionEvidenceSha256" => File.file?(transition_evidence_path) ? Digest::SHA256.file(transition_evidence_path).hexdigest : nil,
      "transitionEvidenceLogPath" => transition_log_path,
      "transitionEvidenceLogSha256" => transition_log_absolute && File.file?(transition_log_absolute) ? Digest::SHA256.file(transition_log_absolute).hexdigest : nil,
      "sourceSha" => provenance&.dig("source", "sha"),
      "sourceTree" => provenance&.dig("source", "tree"),
      "routes" => rows,
      "failedRoutes" => failed.map { |row| row["name"] },
      "blockedRoutes" => blocked.map { |row| row["name"] },
      "missingDesignReviewRoutes" => missing.map { |row| row["name"] },
      "missingScreenshotRoutes" => missing_screenshots.map { |row| row["name"] },
      "missingRoutes" => missing_routes,
      "duplicateRoutes" => duplicate_routes,
      "unexpectedRoutes" => unexpected_routes
    }) + "\n")
    exit((require_full == "1" ? fully_validated : ok) ? 0 : 1)
  ' "$results_path" "$summary_path" "$shared_build_blocker" "$provenance_manifest" "$transition_evidence" "$artifact_root" "$provenance_verified_before" "$provenance_verified_after" "$expected_route_names_csv" "$matrix_routes" "$require_full_matrix"
}

capture_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
  local recorded_route
  recorded_route="$(canonical_capture_route "$route")"
  local command="SPOONJOY_SCREENSHOT_IOS_APP_PATH=$SPOONJOY_SCREENSHOT_IOS_APP_PATH SPOONJOY_SCREENSHOT_MACOS_APP_PATH=$SPOONJOY_SCREENSHOT_MACOS_APP_PATH scripts/capture-native-screenshots.sh --artifact-root $route_root --unit-slug $route_slug --route $route"
  local route_output="$route_root/apple/${route_slug}-screenshot-route.log"
  local command_status=0
  local status="pass"

  mkdir -p "$route_root/apple"
  if [[ "$reset_simulator_between_routes" == "1" ]]; then
    printf 'resetting iOS simulator before route %s\n' "$name"
    xcrun simctl shutdown all >> "$route_output" 2>&1 || true
  fi
  printf 'capturing native route %s (%s)\n' "$name" "$route"
  run_route_capture_with_timeout "$route_output" \
    scripts/capture-native-screenshots.sh --artifact-root "$route_root" --unit-slug "$route_slug" --route "$route" || command_status=$?

  if [[ "$command_status" -eq 124 ]]; then
    write_route_timeout_blocker "$name" "$route" "$route_root" "$route_slug" "$command" "$route_output"
    status="blocked"
  elif [[ -f "$route_root/design-review-blocked.json" ]]; then
    status="blocked"
  elif [[ ! -f "$route_root/design-review.json" ]]; then
    status="fail"
  elif [[ ! -s "$route_root/screenshots/ios-mobile.png" || ! -s "$route_root/screenshots/ios-mobile-accessibility.png" || ! -s "$route_root/screenshots/ios-tablet.png" || ! -s "$route_root/screenshots/macos-desktop.png" ]]; then
    status="fail"
  elif [[ "$command_status" -ne 0 ]]; then
    status="fail"
  fi

  record_route "$name" "$recorded_route" "$route_root" "$status" "$command"
  find "$route_root" -maxdepth 1 -type d -name 'DerivedData-*' -prune -exec rm -rf {} +

  [[ "$status" == "pass" ]]
}

canonical_capture_route() {
  case "$1" in
    shopping-list-empty|shopping-list-all-complete|shopping-list-duplicate|shopping-list-conflict|shopping-list-offline-queued)
      printf 'shopping-list\n'
      ;;
    search-typed-results|search-scoped-recipes|search-scoped-cookbooks|search-scoped-chefs|search-scoped-shopping|search-no-results)
      printf 'search\n'
      ;;
    capture-empty|capture-draft|capture-offline-retry|capture-provider-blocked|capture-signed-out)
      printf 'capture\n'
      ;;
    settings-notifications|settings-signed-out|settings-apns-denied|settings-apns-not-determined|settings-apns-authorized|settings-apns-unregistered)
      printf 'settings\n'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

route_is_selected() {
  local name="$1"
  local route="$2"
  if [[ -z "$matrix_routes" ]]; then
    return 0
  fi

  local selected=",$matrix_routes,"
  [[ "$selected" == *",$name,"* || "$selected" == *",$route,"* ]]
}

overall_status=0
routes=(
  "kitchen|kitchen|$artifact_root|$unit_slug"
  "recipes|recipes|$routes_dir/recipes|$unit_slug-recipes"
  "saved-recipes|saved-recipes|$routes_dir/saved-recipes|$unit_slug-saved-recipes"
  "recipe-detail|recipe-detail|$routes_dir/recipe-detail|$unit_slug-recipe-detail"
  "recipe-editor|recipe-editor|$routes_dir/recipe-editor|$unit_slug-recipe-editor"
  "recipe-covers|recipe-covers|$routes_dir/recipe-covers|$unit_slug-recipe-covers"
  "cook-mode|cook-mode|$routes_dir/cook-mode|$unit_slug-cook-mode"
  "cook-log|cook-log|$routes_dir/cook-log|$unit_slug-cook-log"
  "cookbooks|cookbooks|$routes_dir/cookbooks|$unit_slug-cookbooks"
  "cookbook-detail|cookbook-detail|$routes_dir/cookbook-detail|$unit_slug-cookbook-detail"
  "shopping-list|shopping-list|$routes_dir/shopping-list|$unit_slug-shopping-list"
  "shopping-list-empty|shopping-list-empty|$routes_dir/shopping-list-empty|$unit_slug-shopping-list-empty"
  "shopping-list-all-complete|shopping-list-all-complete|$routes_dir/shopping-list-all-complete|$unit_slug-shopping-list-all-complete"
  "shopping-list-duplicate|shopping-list-duplicate|$routes_dir/shopping-list-duplicate|$unit_slug-shopping-list-duplicate"
  "shopping-list-conflict|shopping-list-conflict|$routes_dir/shopping-list-conflict|$unit_slug-shopping-list-conflict"
  "shopping-list-offline-queued|shopping-list-offline-queued|$routes_dir/shopping-list-offline-queued|$unit_slug-shopping-list-offline-queued"
  "chefs|chefs|$routes_dir/chefs|$unit_slug-chefs"
  "profile|profile|$routes_dir/profile|$unit_slug-profile"
  "profile-graph|profile-graph|$routes_dir/profile-graph|$unit_slug-profile-graph"
  "search|search|$routes_dir/search|$unit_slug-search"
  "search-typed-results|search-typed-results|$routes_dir/search-typed-results|$unit_slug-search-typed-results"
  "search-scoped-recipes|search-scoped-recipes|$routes_dir/search-scoped-recipes|$unit_slug-search-scoped-recipes"
  "search-scoped-cookbooks|search-scoped-cookbooks|$routes_dir/search-scoped-cookbooks|$unit_slug-search-scoped-cookbooks"
  "search-scoped-chefs|search-scoped-chefs|$routes_dir/search-scoped-chefs|$unit_slug-search-scoped-chefs"
  "search-scoped-shopping|search-scoped-shopping|$routes_dir/search-scoped-shopping|$unit_slug-search-scoped-shopping"
  "search-no-results|search-no-results|$routes_dir/search-no-results|$unit_slug-search-no-results"
  "capture|capture|$routes_dir/capture|$unit_slug-capture"
  "capture-empty|capture-empty|$routes_dir/capture-empty|$unit_slug-capture-empty"
  "capture-draft|capture-draft|$routes_dir/capture-draft|$unit_slug-capture-draft"
  "capture-offline-retry|capture-offline-retry|$routes_dir/capture-offline-retry|$unit_slug-capture-offline-retry"
  "capture-provider-blocked|capture-provider-blocked|$routes_dir/capture-provider-blocked|$unit_slug-capture-provider-blocked"
  "capture-signed-out|capture-signed-out|$routes_dir/capture-signed-out|$unit_slug-capture-signed-out"
  "settings|settings|$routes_dir/settings|$unit_slug-settings"
  "settings-notifications|settings|$routes_dir/settings-notifications|$unit_slug-settings-notifications"
  "settings-signed-out|settings|$routes_dir/settings-signed-out|$unit_slug-settings-signed-out"
  "settings-apns-denied|settings|$routes_dir/settings-apns-denied|$unit_slug-settings-apns-denied"
  "settings-apns-not-determined|settings|$routes_dir/settings-apns-not-determined|$unit_slug-settings-apns-not-determined"
  "settings-apns-authorized|settings|$routes_dir/settings-apns-authorized|$unit_slug-settings-apns-authorized"
  "settings-apns-unregistered|settings|$routes_dir/settings-apns-unregistered|$unit_slug-settings-apns-unregistered"
  "unknown-link|unknown-link|$routes_dir/unknown-link|$unit_slug-unknown-link"
)

if prepare_shared_builds && scripts/capture-native-transition-evidence.sh --artifact-root "$artifact_root" --unit-slug "$unit_slug"; then
  for entry in "${routes[@]}"; do
    IFS="|" read -r name route route_root route_slug <<< "$entry"
    route_is_selected "$name" "$route" || continue
    capture_route "$name" "$route" "$route_root" "$route_slug" || overall_status=1
  done
  if verify_provenance "after"; then
    provenance_verified_after=1
  else
    cat "$provenance_log" >&2
    overall_status=1
  fi
else
  overall_status=1
fi

summarize_routes || overall_status=1
printf 'native screenshot route matrix complete: %s\n' "$summary_path"
exit "$overall_status"
