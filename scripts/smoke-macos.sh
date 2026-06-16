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
app_path="$(pwd)/$app_path"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
state_backup="$artifact_root/native-app-state-smoke-backup.json"
route_query="codex-smoke-route-$(date +%s)"
expected_route="search:recipes:${route_query}"
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

state_had_backup=false
mkdir -p "$(dirname "$state_file")"
if [[ -f "$state_file" ]]; then
  cp "$state_file" "$state_backup"
  state_had_backup=true
else
  rm -f "$state_backup"
fi

restore_state() {
  if [[ "$state_had_backup" == "true" && -f "$state_backup" ]]; then
    mkdir -p "$(dirname "$state_file")"
    cp "$state_backup" "$state_file"
  else
    rm -f "$state_file"
  fi
}
trap restore_state EXIT

assert_route_proof() {
  local expected_route="$1"
  local attempts=20
  local delay="0.5"
  for _ in $(seq 1 "$attempts"); do
    if ruby -rjson -e '
      path, expected_route = ARGV
      snapshot = JSON.parse(File.read(path))
      exit(1) unless snapshot.fetch("hasCompletedFirstRun") == true
      exit(1) unless snapshot.fetch("lastOpenedRoute") == expected_route
    ' "$state_file" "$expected_route" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done

  ruby -rjson -e '
    path, expected_route = ARGV
    snapshot = JSON.parse(File.read(path))
    abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
    actual_route = snapshot.fetch("lastOpenedRoute")
    abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
  ' "$state_file" "$expected_route"
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
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  sleep 1
  rm -f "$state_file"
  open -n "$app_path"
  sleep 3
  osascript -e "tell application \"$app_path\" to open location \"spoonjoy://search?q=${route_query}&scope=recipes\""
  pgrep -f "Spoonjoy" >/dev/null
  assert_route_proof "$expected_route"
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  printf 'macOS smoke ok: %s\n' "$expected_route"
} >> "$log_path" 2>&1

rm -f "$blocker_path"
printf 'macOS smoke ok\n'
