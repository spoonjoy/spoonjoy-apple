#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-16-1754-doing-siri-full-access-parity"
unit_slug="matrix"

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
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
routes_dir="$artifact_root/screenshot-routes"
shared_build_dir="$artifact_root/shared-builds"
results_path="$apple_dir/${unit_slug}-route-matrix.jsonl"
summary_path="$apple_dir/${unit_slug}-route-matrix.json"
route_timeout_seconds="${SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS:-180}"
matrix_build_timeout_seconds="${SPOONJOY_SCREENSHOT_MATRIX_BUILD_TIMEOUT_SECONDS:-900}"
reset_simulator_between_routes="${SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES:-1}"
matrix_routes="${SPOONJOY_SCREENSHOT_MATRIX_ROUTES:-}"
shared_ios_app_path="${SPOONJOY_SCREENSHOT_IOS_APP_PATH:-}"
shared_macos_app_path="${SPOONJOY_SCREENSHOT_MACOS_APP_PATH:-}"
shared_build_blocker="$apple_dir/${unit_slug}-shared-build-blocker.json"
shared_xcode_blocker="$apple_dir/${unit_slug}-shared-xcode-platform-blocker.json"
ios_install_marker="$apple_dir/${unit_slug}-ios-installed.marker"
matrix_routes="${matrix_routes//[[:space:]]/}"

mkdir -p "$apple_dir" "$routes_dir"
rm -rf "$routes_dir"
mkdir -p "$routes_dir"
rm -f "$results_path" "$summary_path" "$shared_build_blocker" "$shared_xcode_blocker" "$ios_install_marker"

write_shared_build_blocker() {
  local platform="$1"
  local command="$2"
  local output_path="$3"
  local reason="$4"
  local source_blocker_path="${5:-}"
  ruby -rjson -e '
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

prepare_shared_builds() {
  mkdir -p "$shared_build_dir"

  if [[ -z "$shared_ios_app_path" ]]; then
    local ios_derived="$shared_build_dir/DerivedData-iOS"
    local ios_log="$apple_dir/${unit_slug}-shared-ios-xcodebuild.log"
    local ios_command="xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy iOS -configuration BootstrapDebug -destination generic/platform=iOS Simulator -derivedDataPath $ios_derived CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
    printf 'building shared iOS simulator app for route matrix\n'
    set +e
    scripts/run-xcodebuild-with-blocker.sh \
      --output "$ios_log" \
      --blocker "$shared_xcode_blocker" \
      --timeout-seconds "$matrix_build_timeout_seconds" \
      -- \
      xcodebuild \
      -project Spoonjoy.xcodeproj \
      -scheme "Spoonjoy iOS" \
      -configuration BootstrapDebug \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "$ios_derived" \
      CODE_SIGNING_ALLOWED=NO \
      GCC_TREAT_WARNINGS_AS_ERRORS=YES \
      build
    local ios_status=$?
    set -e
    if [[ -f "$shared_xcode_blocker" ]]; then
      write_shared_build_blocker "ios" "$ios_command" "$ios_log" "Local Xcode platform state blocked the shared iOS screenshot matrix build." "$shared_xcode_blocker"
      return 1
    fi
    if [[ "$ios_status" -ne 0 ]]; then
      write_shared_build_blocker "ios" "$ios_command" "$ios_log" "The shared iOS screenshot matrix build failed."
      return 1
    fi
    shared_ios_app_path="$ios_derived/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
  fi

  if [[ ! -d "$shared_ios_app_path" ]]; then
    write_shared_build_blocker "ios" "SPOONJOY_SCREENSHOT_IOS_APP_PATH=$shared_ios_app_path" "$apple_dir/${unit_slug}-shared-ios-xcodebuild.log" "The shared iOS simulator app bundle is missing."
    return 1
  fi

  if [[ -z "$shared_macos_app_path" ]]; then
    local macos_derived="$shared_build_dir/DerivedData-macOS"
    local macos_log="$apple_dir/${unit_slug}-shared-macos-xcodebuild.log"
    local macos_command="xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy macOS -configuration BootstrapDebug -destination generic/platform=macOS -derivedDataPath $macos_derived GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
    printf 'building shared macOS app for route matrix\n'
    set +e
    scripts/run-xcodebuild-with-blocker.sh \
      --output "$macos_log" \
      --blocker "$shared_xcode_blocker" \
      --timeout-seconds "$matrix_build_timeout_seconds" \
      -- \
      xcodebuild \
      -project Spoonjoy.xcodeproj \
      -scheme "Spoonjoy macOS" \
      -configuration BootstrapDebug \
      -destination "generic/platform=macOS" \
      -derivedDataPath "$macos_derived" \
      GCC_TREAT_WARNINGS_AS_ERRORS=YES \
      build
    local macos_status=$?
    set -e
    if [[ -f "$shared_xcode_blocker" ]]; then
      write_shared_build_blocker "macos" "$macos_command" "$macos_log" "Local Xcode platform state blocked the shared macOS screenshot matrix build." "$shared_xcode_blocker"
      return 1
    fi
    if [[ "$macos_status" -ne 0 ]]; then
      write_shared_build_blocker "macos" "$macos_command" "$macos_log" "The shared macOS screenshot matrix build failed."
      return 1
    fi
    shared_macos_app_path="$macos_derived/Build/Products/BootstrapDebug/Spoonjoy.app"
  fi

  if [[ ! -d "$shared_macos_app_path" ]]; then
    write_shared_build_blocker "macos" "SPOONJOY_SCREENSHOT_MACOS_APP_PATH=$shared_macos_app_path" "$apple_dir/${unit_slug}-shared-macos-xcodebuild.log" "The shared macOS app bundle is missing."
    return 1
  fi

  export SPOONJOY_SCREENSHOT_IOS_APP_PATH="$shared_ios_app_path"
  export SPOONJOY_SCREENSHOT_MACOS_APP_PATH="$shared_macos_app_path"
  export SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP="${SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP:-1}"
  export SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER="${SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER:-$ios_install_marker}"
  printf 'route matrix using shared iOS app: %s\n' "$SPOONJOY_SCREENSHOT_IOS_APP_PATH"
  printf 'route matrix using shared macOS app: %s\n' "$SPOONJOY_SCREENSHOT_MACOS_APP_PATH"
}

record_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local status="$4"
  local command="$5"
  ruby -rjson -e '
    results_path, name, route, route_root, status, command = ARGV
    def artifact(path, relative_path)
      absolute = File.join(path, relative_path)
      {
        "path" => absolute,
        "exists" => File.file?(absolute),
        "bytes" => File.file?(absolute) ? File.size(absolute) : nil
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
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/#{route_slug}-accessibility-proof-ios.json",
        "apple/#{route_slug}-accessibility-proof-macos.json"
      ],
      "reason" => reason,
      "ownerAction" => owner_action,
      "timeoutSeconds" => Integer(timeout_seconds)
    }
    FileUtils.mkdir_p(File.dirname(source_path))
    File.write(source_path, JSON.pretty_generate(source_blocker) + "\n")
    File.write(review_path, JSON.pretty_generate(design_review_blocked) + "\n")
  ' "$name" "$route" "$route_root" "$route_slug" "$command" "$output_path" "$route_timeout_seconds"
  rm -f "$route_root/screenshots/ios-mobile.png" "$route_root/screenshots/macos-desktop.png"
  rm -f "$route_root/design-review.json"
  rm -f "$route_root/apple/${route_slug}-accessibility-proof-ios.json" "$route_root/apple/${route_slug}-accessibility-proof-macos.json"
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
  ruby -rjson -rtime -e '
    results_path, summary_path, shared_build_blocker_path = ARGV
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    missing = rows.select { |row| row["missingDesignReview"] }
    blocked = rows.select { |row| row["blocked"] }
    failed = rows.select { |row| row["status"] != "pass" }
    build_blocker = File.file?(shared_build_blocker_path) ? JSON.parse(File.read(shared_build_blocker_path)) : nil
    ok = !rows.empty? && build_blocker.nil? && missing.empty? && blocked.empty? && failed.empty?
    File.write(summary_path, JSON.pretty_generate({
      "ok" => ok,
      "fullyValidated" => ok,
      "generatedAt" => Time.now.utc.iso8601,
      "routeCount" => rows.length,
      "buildBlocked" => !build_blocker.nil?,
      "buildBlocker" => build_blocker,
      "routes" => rows,
      "failedRoutes" => failed.map { |row| row["name"] },
      "blockedRoutes" => blocked.map { |row| row["name"] },
      "missingDesignReviewRoutes" => missing.map { |row| row["name"] }
    }) + "\n")
    exit(ok ? 0 : 1)
  ' "$results_path" "$summary_path" "$shared_build_blocker"
}

capture_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
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
  elif [[ "$command_status" -ne 0 ]]; then
    status="fail"
  fi

  record_route "$name" "$route" "$route_root" "$status" "$command"
  find "$route_root" -maxdepth 1 -type d -name 'DerivedData-*' -prune -exec rm -rf {} +

  [[ "$status" == "pass" ]]
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
  "recipe-detail|recipe-detail|$routes_dir/recipe-detail|$unit_slug-recipe-detail"
  "cook-mode|cook-mode|$routes_dir/cook-mode|$unit_slug-cook-mode"
  "cookbooks|cookbooks|$routes_dir/cookbooks|$unit_slug-cookbooks"
  "cookbook-detail|cookbook-detail|$routes_dir/cookbook-detail|$unit_slug-cookbook-detail"
  "shopping-list|shopping-list|$routes_dir/shopping-list|$unit_slug-shopping-list"
  "shopping-list-empty|shopping-list-empty|$routes_dir/shopping-list-empty|$unit_slug-shopping-list-empty"
  "shopping-list-all-complete|shopping-list-all-complete|$routes_dir/shopping-list-all-complete|$unit_slug-shopping-list-all-complete"
  "shopping-list-duplicate|shopping-list-duplicate|$routes_dir/shopping-list-duplicate|$unit_slug-shopping-list-duplicate"
  "shopping-list-conflict|shopping-list-conflict|$routes_dir/shopping-list-conflict|$unit_slug-shopping-list-conflict"
  "shopping-list-offline-queued|shopping-list-offline-queued|$routes_dir/shopping-list-offline-queued|$unit_slug-shopping-list-offline-queued"
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
)

if prepare_shared_builds; then
  for entry in "${routes[@]}"; do
    IFS="|" read -r name route route_root route_slug <<< "$entry"
    route_is_selected "$name" "$route" || continue
    capture_route "$name" "$route" "$route_root" "$route_slug" || overall_status=1
  done
else
  overall_status=1
fi

summarize_routes || overall_status=1
printf 'native screenshot route matrix complete: %s\n' "$summary_path"
exit "$overall_status"
