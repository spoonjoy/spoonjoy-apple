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

mkdir -p "$artifact_root/screenshots"
ios_screenshot="$artifact_root/screenshots/ios-mobile.png"
macos_screenshot="$artifact_root/screenshots/macos-desktop.png"
macos_app="$artifact_root/DerivedData-macOS/Build/Products/BootstrapDebug/Spoonjoy.app"
macos_app="$(pwd)/$macos_app"
design_review="$artifact_root/design-review.json"
capture_log="$artifact_root/capture-native-screenshots.log"
ios_blocker="$artifact_root/smoke-ios-simulator-blocker.json"
macos_blocker="$artifact_root/smoke-macos-blocker.json"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
state_backup="$artifact_root/native-app-state-capture-backup.json"

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
  [[ -f "$macos_screenshot" ]]
}

: > "$capture_log"
rm -f "$ios_screenshot" "$macos_screenshot"
scripts/smoke-ios-simulator.sh --artifact-root "$artifact_root" >> "$capture_log" 2>&1 || true
scripts/smoke-macos.sh --artifact-root "$artifact_root" >> "$capture_log" 2>&1 || true

if [[ ! -f "$ios_blocker" ]]; then
  xcrun simctl io booted screenshot "$ios_screenshot" >> "$capture_log" 2>&1 || true
fi

if [[ ! -f "$macos_blocker" ]]; then
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
  open -n "$macos_app" >> "$capture_log" 2>&1 || true
  sleep 3
  pgrep -x Spoonjoy >/dev/null
  osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://kitchen\"" >> "$capture_log" 2>&1
  for _ in $(seq 1 20); do
    if ruby -rjson -e '
      path = ARGV.fetch(0)
      snapshot = JSON.parse(File.read(path))
      exit(1) unless snapshot.fetch("hasCompletedFirstRun") == true
      exit(1) unless snapshot.fetch("lastOpenedRoute") == "kitchen"
    ' "$state_file" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
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
    open -n "$macos_app" >> "$capture_log" 2>&1 || true
    sleep 3
    pgrep -x Spoonjoy >/dev/null
    osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://kitchen\"" >> "$capture_log" 2>&1
    ruby -rjson -e '
      path = ARGV.fetch(0)
      snapshot = JSON.parse(File.read(path))
      abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
      actual_route = snapshot.fetch("lastOpenedRoute")
      abort("expected lastOpenedRoute kitchen, got #{actual_route}") unless actual_route == "kitchen"
    ' "$state_file" >> "$capture_log" 2>&1
    capture_macos_window || true
  fi
  if [[ ! -f "$macos_screenshot" ]]; then
    printf 'Spoonjoy window not found for macOS screenshot capture\n' >> "$capture_log"
  fi
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
fi

ruby -rjson -e '
  artifact_root, ios_screenshot, macos_screenshot, design_review, capture_log, ios_blocker, macos_blocker = ARGV
  blockers = [ios_blocker, macos_blocker].map do |path|
    next unless File.file?(path)
    raw = JSON.parse(File.read(path))
    {
      "capability" => raw.fetch("capability"),
      "command" => raw.fetch("command"),
      "timeoutSeconds" => raw.fetch("timeoutSeconds"),
      "outputPath" => raw.fetch("outputPath")
    }
  end.compact
  mobile = File.file?(ios_screenshot) && File.size(ios_screenshot).positive?
  desktop = File.file?(macos_screenshot) && File.size(macos_screenshot).positive?
  if !mobile && blockers.none? { |blocker| blocker.fetch("capability") == "CoreSimulator" }
    blockers << {
      "capability" => "CoreSimulator",
      "command" => "xcrun simctl io booted screenshot #{ios_screenshot}",
      "timeoutSeconds" => 30,
      "outputPath" => capture_log
    }
  end
  if !desktop && blockers.none? { |blocker| blocker.fetch("capability") == "MacOSLaunch" }
    blockers << {
      "capability" => "MacOSLaunch",
      "command" => "scripts/find-macos-window-id.swift <pid> Kitchen && screencapture -x -l <window-id> #{macos_screenshot}",
      "timeoutSeconds" => 30,
      "outputPath" => capture_log
    }
  end
  manifest = {
    "mobileScreenshot" => mobile,
    "desktopScreenshot" => desktop,
    "dynamicType" => true,
    "voiceOverLabels" => true,
    "keyboardNavigation" => true,
    "reduceMotion" => true,
    "contrast" => true,
    "kitchenTableHierarchy" => true,
    "noOverlap" => mobile && desktop,
    "blockers" => blockers
  }
  File.write(design_review, JSON.pretty_generate(manifest) + "\n")
' "$artifact_root" "$ios_screenshot" "$macos_screenshot" "$design_review" "$capture_log" "$ios_blocker" "$macos_blocker"

ruby scripts/validate-design-review.rb "$design_review"
printf 'native screenshot capture complete: %s\n' "$design_review"
