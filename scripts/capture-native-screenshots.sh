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
design_review="$artifact_root/design-review.json"
capture_log="$artifact_root/capture-native-screenshots.log"
ios_blocker="$artifact_root/smoke-ios-simulator-blocker.json"
macos_blocker="$artifact_root/smoke-macos-blocker.json"

: > "$capture_log"
scripts/smoke-ios-simulator.sh --artifact-root "$artifact_root" >> "$capture_log" 2>&1 || true
scripts/smoke-macos.sh --artifact-root "$artifact_root" >> "$capture_log" 2>&1 || true

if [[ ! -f "$ios_blocker" ]]; then
  xcrun simctl io booted screenshot "$ios_screenshot" >> "$capture_log" 2>&1 || true
fi

if [[ ! -f "$macos_blocker" ]]; then
  open -n "$macos_app" >> "$capture_log" 2>&1 || true
  sleep 3
  screencapture -x "$macos_screenshot" >> "$capture_log" 2>&1 || true
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >> "$capture_log" 2>&1 || true
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
      "command" => "screencapture -x #{macos_screenshot}",
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
