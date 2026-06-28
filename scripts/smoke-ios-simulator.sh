#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-15-2314-doing-native-app-skeleton"
unit_slug="${UNIT_SLUG:-smoke-ios}"
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
legacy_log_path="$artifact_root/smoke-ios-simulator.log"
legacy_blocker_path="$artifact_root/smoke-ios-simulator-blocker.json"
log_path="${log_path:-$artifact_root/apple/${unit_slug}-smoke-ios-inner.log}"
blocker_path="${blocker_path:-$artifact_root/apple/${unit_slug}-smoke-ios-simulator-blocker.json}"
derived_data_path="$artifact_root/DerivedData-iOS"
timeout_seconds=30
list_runtimes_command="xcrun simctl list runtimes"
boot_command="xcrun simctl boot"
launch_command="xcrun simctl launch"
resolver=".github/scripts/resolve-ios-simulator-destination.py"
mkdir -p "$(dirname "$log_path")" "$(dirname "$blocker_path")"
rm -f "$blocker_path" "$legacy_blocker_path"

write_blocker() {
  local capability="$1"
  local command="$2"
  local output_path="$3"
  local reason="$4"
  local owner_action="$5"
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

run_with_timeout() {
  local command="$1"
  python3 - "$timeout_seconds" "$command" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
command = sys.argv[2]
completed = subprocess.run(
    ["bash", "-c", command],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    timeout=timeout_seconds,
)
print(completed.stdout, end="")
sys.exit(completed.returncode)
PY
}

{
  printf 'Listing iOS simulator runtimes: %s\n' "$list_runtimes_command"
  set +e
  run_with_timeout "$list_runtimes_command"
  runtime_status=$?
  set -e
  printf 'runtime list exit code: %s\n' "$runtime_status"
} > "$log_path" 2>&1

if [[ "$runtime_status" -ne 0 ]]; then
  write_blocker \
    "CoreSimulator" \
    "$list_runtimes_command" \
    "$log_path" \
    "CoreSimulator runtime listing failed or timed out." \
    "Install an available iPhone simulator runtime and confirm xcrun simctl can list runtimes."
  printf 'iOS simulator smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

set +e
destination="$(python3 "$resolver" 2>>"$log_path")"
resolver_status=$?
set -e
printf 'resolved destination: %s\nresolver exit code: %s\n' "$destination" "$resolver_status" >> "$log_path"

if [[ "$resolver_status" -ne 0 || -z "$destination" ]]; then
  write_blocker \
    "CoreSimulator" \
    "python3 $resolver" \
    "$log_path" \
    "No available iPhone simulator destination was found." \
    "Install an available iPhone simulator runtime and bootable device."
  printf 'iOS simulator smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

udid="${destination##*,id=}"
app_path="$derived_data_path/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
build_destination="generic/platform=iOS Simulator"
build_label="xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination '$build_destination' CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
build_command=(
  xcodebuild
  -project Spoonjoy.xcodeproj
  -scheme "Spoonjoy iOS"
  -configuration BootstrapDebug
  -destination "$build_destination"
  -derivedDataPath "$derived_data_path"
  CODE_SIGNING_ALLOWED=NO
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
  build
)

{
  printf 'Running iOS simulator build: %s\n' "$build_label"
  set +e
  "${build_command[@]}"
  build_status=$?
  set -e
  printf 'iOS simulator build exit code: %s\n' "$build_status"
} >> "$log_path" 2>&1

if [[ "$build_status" -ne 0 ]]; then
  printf 'iOS simulator smoke build failed; see %s\n' "$log_path" >&2
  exit "$build_status"
fi

boot_log="$(mktemp)"
printf 'Booting simulator: %s %s\n' "$boot_command" "$udid" >> "$log_path"
set +e
run_with_timeout "$boot_command $udid || xcrun simctl bootstatus $udid -b" > "$boot_log" 2>&1
boot_status=$?
set -e
if [[ "$boot_status" -ne 0 ]] || ! grep -q "Unable to boot device in current state: Booted" "$boot_log"; then
  cat "$boot_log" >> "$log_path"
else
  printf 'Simulator was already booted; suppressed benign CoreSimulator boot diagnostic.\n' >> "$log_path"
fi
printf 'simulator boot exit code: %s\n' "$boot_status" >> "$log_path"
rm -f "$boot_log"

if [[ "$boot_status" -ne 0 ]]; then
  write_blocker \
    "CoreSimulator" \
    "$boot_command $udid" \
    "$log_path" \
    "CoreSimulator boot failed or timed out." \
    "Boot the selected simulator and rerun the iOS launch smoke."
  printf 'iOS simulator smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

{
  printf 'Uninstalling stale app before fresh install: %s app.spoonjoy.Spoonjoy\n' "$udid"
  xcrun simctl uninstall "$udid" app.spoonjoy.Spoonjoy || true
  printf 'Installing app: %s\n' "$app_path"
  set +e
  run_with_timeout "xcrun simctl install $udid '$app_path'"
  install_status=$?
  set -e
  printf 'simulator install exit code: %s\n' "$install_status"
} >> "$log_path" 2>&1

if [[ "$install_status" -ne 0 ]]; then
  printf 'iOS simulator app install failed; see %s\n' "$log_path" >&2
  exit "$install_status"
fi

{
  printf 'Launching app: %s app.spoonjoy.Spoonjoy\n' "$launch_command"
  set +e
  run_with_timeout "$launch_command $udid app.spoonjoy.Spoonjoy"
  launch_status=$?
  set -e
  printf 'simulator launch exit code: %s\n' "$launch_status"
} >> "$log_path" 2>&1

if [[ "$launch_status" -ne 0 ]]; then
  printf 'iOS simulator app launch failed; see %s\n' "$log_path" >&2
  exit "$launch_status"
fi

rm -f "$blocker_path"
printf 'iOS simulator smoke ok\n'
