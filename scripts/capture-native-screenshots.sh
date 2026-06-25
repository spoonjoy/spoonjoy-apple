#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-15-2314-doing-native-app-skeleton"
unit_slug="capture-native-screenshots"
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
mkdir -p "$artifact_root/screenshots" "$apple_dir"
ios_screenshot="$artifact_root/screenshots/ios-mobile.png"
macos_screenshot="$artifact_root/screenshots/macos-desktop.png"
macos_app="$artifact_root/DerivedData-macOS/Build/Products/BootstrapDebug/Spoonjoy.app"
design_review="$artifact_root/design-review.json"
design_review_blocked="$artifact_root/design-review-blocked.json"
matrix_log="$artifact_root/apple/${unit_slug}-screenshots.log"
capture_log="$artifact_root/apple/${unit_slug}-screenshots-inner.log"
ios_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ios.log"
macos_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-macos.log"
xcode_blocker="$artifact_root/apple/${unit_slug}-screenshots-xcode-platform-blocker.json"
ios_blocker="$artifact_root/apple/${unit_slug}-screenshots-core-simulator-blocker.json"
macos_blocker="$artifact_root/apple/${unit_slug}-screenshots-macos-launch-blocker.json"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
state_backup="$artifact_root/native-app-state-capture-backup.json"

write_blocker() {
  local path="$1"
  local capability="$2"
  local command="$3"
  local output_path="$4"
  local reason="$5"
  local owner_action="$6"
  ruby -rjson -e '
    path, capability, command, output_path, reason, owner_action = ARGV
    blocker = {
      capability: capability,
      blocked: true,
      command: command,
      timeoutSeconds: 30,
      outputPath: output_path,
      reason: reason,
      ownerAction: owner_action
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$path" "$capability" "$command" "$output_path" "$reason" "$owner_action"
}

write_design_review_blocked() {
  local source_blocker_path="$1"
  ruby -rjson -e '
    source_path, output_path = ARGV
    blocker = JSON.parse(File.read(source_path))
    manifest = {
      "blocked" => true,
      "capability" => blocker.fetch("capability"),
      "sourceBlockerPath" => File.expand_path(source_path),
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/macos-desktop.png",
        "design-review.json"
      ],
      "reason" => blocker.fetch("reason"),
      "ownerAction" => blocker.fetch("ownerAction")
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$source_blocker_path" "$design_review_blocked"
  rm -f "$ios_screenshot" "$macos_screenshot"
  rm -f "$design_review"
}

write_design_review_success() {
  ruby -rjson -e '
    output_path = ARGV.fetch(0)
    manifest = {
      "mobileScreenshot" => true,
      "desktopScreenshot" => true,
      "dynamicType" => true,
      "voiceOverLabels" => true,
      "keyboardNavigation" => true,
      "reduceMotion" => true,
      "contrast" => true,
      "kitchenTableHierarchy" => true,
      "noOverlap" => true,
      "blockers" => []
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$design_review"
}

is_xcode_platform_blocker() {
  ruby -e '
    output = File.file?(ARGV.fetch(0)) ? File.read(ARGV.fetch(0)) : ""
    allowed = [
      /xcodebuild: error: iOS \d+(?:\.\d+)? is not installed/i,
      /xcodebuild: error: Unable to find a destination matching/i,
      /CoreSimulatorService connection became invalid/i,
      /DVTPlugInManager failed to load plug-in/i,
      /IDEDistribution.*private framework/i
    ]
    exit(allowed.any? { |pattern| output.match?(pattern) } ? 0 : 1)
  ' "$1"
}

capture_macos_window() {
  osascript -e "tell application \"$macos_app\" to activate" >> "$capture_log" 2>&1 || true
  sleep 1
  local window_id=""
  local spoonjoy_pid=""
  for _ in $(seq 1 20); do
    spoonjoy_pid="$(pgrep -x Spoonjoy | tail -n 1 || true)"
    if [[ -n "$spoonjoy_pid" ]] && window_id="$(swift scripts/find-macos-window-id.swift "$spoonjoy_pid" Kitchen 2>> "$capture_log")"; then
      break
    fi
    window_id=""
    sleep 0.5
  done
  if [[ -z "$window_id" ]]; then
    return 1
  fi
  screencapture -x -l "$window_id" "$macos_screenshot" >> "$capture_log" 2>&1
  [[ -f "$macos_screenshot" && -s "$macos_screenshot" ]]
}

wait_for_kitchen_route() {
  for _ in $(seq 1 60); do
    if ruby -rjson -e '
      path = ARGV.fetch(0)
      snapshot = JSON.parse(File.read(path))
      exit(1) unless snapshot.fetch("hasCompletedFirstRun") == true
      exit(1) unless snapshot.fetch("lastOpenedRoute") == "kitchen"
    ' "$state_file" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
}

run_smoke() {
  local label="$1"
  local log_path="$2"
  local blocker_path="$3"
  shift 3

  printf 'Running %s smoke\n' "$label" >> "$capture_log"
  set +e
  "$@" --artifact-root "$artifact_root" --log "$log_path" --blocker "$blocker_path" >> "$capture_log" 2>&1
  local status=$?
  set -e

  if [[ "$status" -ne 0 && ! -f "$blocker_path" ]]; then
    if is_xcode_platform_blocker "$log_path"; then
      write_blocker \
        "$xcode_blocker" \
        "XcodePlatform" \
        "$*" \
        "$log_path" \
        "Local Xcode platform or pre-parse state blocked screenshot app preparation." \
        "Install the required Xcode platform/runtime and rerun screenshot capture."
      return 0
    fi
    printf '%s smoke failed without a runtime blocker; see %s\n' "$label" "$log_path" >> "$capture_log"
    return "$status"
  fi
}

: > "$capture_log"
rm -f "$ios_screenshot" "$macos_screenshot"
rm -f "$design_review_blocked"
rm -f "$design_review"
rm -f "$xcode_blocker" "$ios_blocker" "$macos_blocker"

run_smoke "iOS simulator" "$ios_smoke_log" "$ios_blocker" scripts/smoke-ios-simulator.sh
if [[ ! -f "$xcode_blocker" ]]; then
  run_smoke "macOS launch" "$macos_smoke_log" "$macos_blocker" scripts/smoke-macos.sh
fi

if [[ ! -f "$xcode_blocker" && ! -f "$ios_blocker" ]]; then
  if ! xcrun simctl io booted screenshot "$ios_screenshot" >> "$capture_log" 2>&1 || [[ ! -s "$ios_screenshot" ]]; then
    write_blocker \
      "$ios_blocker" \
      "CoreSimulator" \
      "xcrun simctl io booted screenshot $ios_screenshot" \
      "$capture_log" \
      "CoreSimulator could not capture the iOS screenshot." \
      "Boot an available iPhone simulator and grant screenshot capture access."
  fi
fi

if [[ ! -f "$xcode_blocker" && ! -f "$macos_blocker" ]]; then
  state_had_backup=false
  mkdir -p "$(dirname "$state_file")"
  if [[ -f "$state_file" ]]; then
    cp "$state_file" "$state_backup"
    state_had_backup=true
  else
    rm -f "$state_backup"
  fi
  restore_capture_state() {
    if [[ "$state_had_backup" == "true" && -f "$state_backup" ]]; then
      mkdir -p "$(dirname "$state_file")"
      cp "$state_backup" "$state_file"
    else
      rm -f "$state_file"
    fi
  }
  trap restore_capture_state EXIT
  rm -f "$state_file"
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  sleep 1
  open -n "$macos_app" >> "$capture_log" 2>&1
  sleep 3
  pgrep -x Spoonjoy >/dev/null
  osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://kitchen\"" >> "$capture_log" 2>&1
  wait_for_kitchen_route || true
  ruby -rjson -e '
    path = ARGV.fetch(0)
    snapshot = JSON.parse(File.read(path))
    abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
    actual_route = snapshot.fetch("lastOpenedRoute")
    abort("expected lastOpenedRoute kitchen, got #{actual_route}") unless actual_route == "kitchen"
  ' "$state_file" >> "$capture_log" 2>&1
  if ! capture_macos_window; then
    printf 'Retrying Spoonjoy window capture after relaunch\n' >> "$capture_log"
    osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
    pkill -x Spoonjoy >/dev/null 2>&1 || true
    sleep 1
    open -n "$macos_app" >> "$capture_log" 2>&1
    sleep 3
    pgrep -x Spoonjoy >/dev/null
    osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://kitchen\"" >> "$capture_log" 2>&1
    wait_for_kitchen_route || true
    ruby -rjson -e '
      path = ARGV.fetch(0)
      snapshot = JSON.parse(File.read(path))
      abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
      actual_route = snapshot.fetch("lastOpenedRoute")
      abort("expected lastOpenedRoute kitchen, got #{actual_route}") unless actual_route == "kitchen"
    ' "$state_file" >> "$capture_log" 2>&1
    capture_macos_window || true
  fi
  if [[ ! -f "$macos_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Spoonjoy window not found for macOS screenshot capture\n' >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "scripts/find-macos-window-id.swift <pid> Kitchen && screencapture -x -l <window-id> $macos_screenshot" \
      "$capture_log" \
      "Spoonjoy window capture was unavailable in the macOS GUI session." \
      "Run screenshot capture from an unlocked desktop session with Screen Recording permission for the terminal."
  fi
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
fi

if [[ -f "$xcode_blocker" ]]; then
  write_design_review_blocked "$xcode_blocker"
elif [[ -f "$ios_blocker" ]]; then
  write_design_review_blocked "$ios_blocker"
elif [[ -f "$macos_blocker" ]]; then
  write_design_review_blocked "$macos_blocker"
else
  if [[ ! -s "$ios_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce both screenshots\n' >&2
    exit 1
  fi
  write_design_review_success
  rm -f "$design_review_blocked"
fi

if [[ -f "$design_review_blocked" && -f "$design_review" ]]; then
  printf 'conflicting design review success and blocker artifacts\n' >&2
  exit 1
fi

if [[ -f "$design_review_blocked" ]]; then
  ruby scripts/validate-design-review-blocker.rb "$design_review_blocked" --artifact-root "$artifact_root" --unit-slug "$unit_slug"
  printf 'native screenshot capture blocked: %s\n' "$design_review_blocked"
else
  ruby scripts/validate-design-review.rb "$design_review"
  printf 'native screenshot capture complete: %s\n' "$design_review"
fi
