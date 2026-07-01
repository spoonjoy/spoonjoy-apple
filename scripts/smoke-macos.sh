#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-16-1754-doing-siri-full-access-parity"
unit_slug="${UNIT_SLUG:-smoke-macos}"
log_path=""
blocker_path=""
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
    --log)
      log_path="$2"
      shift 2
      ;;
    --blocker)
      blocker_path="$2"
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
legacy_log_path="$artifact_root/smoke-macos.log"
legacy_blocker_path="$artifact_root/smoke-macos-blocker.json"
log_path="${log_path:-$artifact_root/apple/${unit_slug}-smoke-macos-inner.log}"
blocker_path="${blocker_path:-$artifact_root/apple/${unit_slug}-smoke-macos-blocker.json}"
derived_data_path="$artifact_root/DerivedData-macOS"
app_path="$derived_data_path/Build/Products/BootstrapDebug/Spoonjoy.app"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
state_backup="$artifact_root/native-app-state-smoke-backup.json"
route_query="codex-smoke-route-$(date +%s)"
expected_route="search:recipes:${route_query}"
build_label="xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
build_command=(
  xcodebuild
  -project Spoonjoy.xcodeproj
  -scheme "Spoonjoy macOS"
  -configuration BootstrapDebug
  -destination "generic/platform=macOS"
  -derivedDataPath "$derived_data_path"
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
  build
)
mkdir -p "$(dirname "$log_path")" "$(dirname "$blocker_path")"
rm -f "$blocker_path" "$legacy_blocker_path"

write_blocker() {
  local capability="$1"
  local command="$2"
  local timeout_seconds="$3"
  local output_path="$4"
  local reason="$5"
  local owner_action="$6"
  ruby -rjson -e '
    path, capability, command, timeout_seconds, output_path, reason, owner_action = ARGV
    blocker = {
      capability: capability,
      blocked: true,
      command: command,
      timeoutSeconds: Integer(timeout_seconds),
      outputPath: output_path,
      reason: reason,
      ownerAction: owner_action
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$blocker_path" "$capability" "$command" "$timeout_seconds" "$output_path" "$reason" "$owner_action"
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
  local attempts=60
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
  printf 'macOS smoke build failed; see %s\n' "$log_path" >&2
  exit "$build_status"
fi

if [[ ! -d "$app_path" ]]; then
  printf 'macOS smoke app bundle missing at %s\n' "$app_path" >&2
  exit 1
fi

if ! osascript -e 'id of application "Finder"' >> "$log_path" 2>&1; then
  write_blocker \
    "MacOSLaunch" \
    "osascript -e 'id of application \"Finder\"'" \
    "30" \
    "$log_path" \
    "macOS GUI automation is unavailable in this session." \
    "Run the macOS smoke from an unlocked desktop session with Apple Events available."
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
  osascript -e "tell application id \"app.spoonjoy.Spoonjoy.mac\" to open location \"spoonjoy://search?q=${route_query}&scope=recipes\""
  pgrep -f "Spoonjoy" >/dev/null
  assert_route_proof "$expected_route"
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  printf 'macOS smoke ok: %s\n' "$expected_route"
} >> "$log_path" 2>&1

rm -f "$blocker_path"
printf 'macOS smoke ok\n'
