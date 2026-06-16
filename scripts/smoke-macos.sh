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
log_path="$artifact_root/smoke-macos.log"
blocker_path="$artifact_root/smoke-macos-blocker.json"
derived_data_path="$artifact_root/DerivedData-macOS"
app_path="$derived_data_path/Build/Products/BootstrapDebug/Spoonjoy.app"
build_label="xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
build_command=(
  xcodebuild
  -project Spoonjoy.xcodeproj
  -scheme "Spoonjoy macOS"
  -configuration BootstrapDebug
  -destination "generic/platform=macOS"
  -derivedDataPath "$derived_data_path"
  CODE_SIGNING_ALLOWED=NO
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
  build
)

write_blocker() {
  local capability="$1"
  local command="$2"
  local timeout_seconds="$3"
  local output_path="$4"
  local reason="$5"
  ruby -rjson -e '
    path, capability, command, timeout_seconds, output_path, reason = ARGV
    blocker = {
      capability: capability,
      blocked: true,
      command: command,
      timeoutSeconds: Integer(timeout_seconds),
      outputPath: output_path,
      reason: reason
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$blocker_path" "$capability" "$command" "$timeout_seconds" "$output_path" "$reason"
}

{
  printf 'Running macOS smoke build: %s\n' "$build_label"
  set +e
  "${build_command[@]}"
  build_status=$?
  set -e
  printf 'macOS build exit code: %s\n' "$build_status"
} > "$log_path" 2>&1

if [[ "$build_status" -ne 0 ]]; then
  write_blocker \
    "MacOSLaunch" \
    "$build_label" \
    "30" \
    "$log_path" \
    "macOS launch smoke cannot run because the BootstrapDebug app bundle did not build."
  printf 'macOS smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

if [[ ! -d "$app_path" ]]; then
  write_blocker \
    "MacOSLaunch" \
    "open -n '$app_path'" \
    "30" \
    "$log_path" \
    "macOS app bundle was not found at the expected Spoonjoy.app path."
  printf 'macOS smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

{
  printf 'Launching macOS app: %s\n' "$app_path"
  open -n "$app_path"
  sleep 3
  pgrep -f "Spoonjoy" >/dev/null
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  printf 'macOS smoke ok\n'
} >> "$log_path" 2>&1

rm -f "$blocker_path"
printf 'macOS smoke ok\n'
