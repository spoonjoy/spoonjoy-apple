#!/usr/bin/env bash
set -euo pipefail

artifact_root="${SPOONJOY_NATIVE_ARTIFACT_ROOT:-artifacts/apple/native-smoke}"
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
prebuilt_app_path="${SPOONJOY_SCREENSHOT_IOS_APP_PATH:-}"
reuse_installed_app="${SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP:-0}"
install_marker="${SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER:-}"
timeout_seconds="${SPOONJOY_SMOKE_TIMEOUT_SECONDS:-30}"
boot_timeout_seconds="${SPOONJOY_SMOKE_BOOT_TIMEOUT_SECONDS:-120}"
launch_attempts="${SPOONJOY_SMOKE_LAUNCH_ATTEMPTS:-3}"
registration_timeout_seconds="${SPOONJOY_SMOKE_REGISTRATION_TIMEOUT_SECONDS:-120}"
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
  local command_timeout_seconds="${2:-$timeout_seconds}"
  python3 - "$command_timeout_seconds" "$command" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
command = sys.argv[2]
process = subprocess.Popen(
    ["bash", "-c", command],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    stdout, _ = process.communicate(timeout=timeout_seconds)
except subprocess.TimeoutExpired:
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
    try:
        stdout, _ = process.communicate(timeout=1)
    except subprocess.TimeoutExpired:
        stdout = ""
    print(stdout, end="")
    print(f"command timed out after {timeout_seconds} seconds")
    sys.exit(124)
print(stdout, end="")
sys.exit(process.returncode)
PY
}

app_is_registered_as_running() {
  local launchctl_output=""
  local launchctl_status=0
  set +e
  launchctl_output="$(run_with_timeout "xcrun simctl spawn $udid launchctl list" 2>&1)"
  launchctl_status=$?
  set -e
  printf 'launchctl app registration exit code: %s\n' "$launchctl_status"
  if [[ -n "$launchctl_output" ]]; then
    printf '%s\n' "$launchctl_output"
  fi
  [[ "$launchctl_status" -eq 0 && "$launchctl_output" == *"UIKitApplication:app.spoonjoy"* ]]
}

wait_for_app_registration() {
  local deadline=$((SECONDS + registration_timeout_seconds))
  local stable_samples=0
  local container_output=""
  local container_status=1

  while [[ "$SECONDS" -lt "$deadline" ]]; do
    set +e
    container_output="$(run_with_timeout "xcrun simctl get_app_container $udid app.spoonjoy app" 5)"
    container_status=$?
    set -e
    printf 'simulator app registration probe exit code: %s\n' "$container_status"
    if [[ -n "$container_output" ]]; then
      printf '%s\n' "$container_output"
    fi
    if [[ "$container_status" -eq 0 && -n "$container_output" ]]; then
      stable_samples=$((stable_samples + 1))
      if [[ "$stable_samples" -ge 2 ]]; then
        printf 'Spoonjoy app registration reached two stable samples\n'
        return 0
      fi
    else
      stable_samples=0
    fi
    sleep 1
  done

  printf 'Spoonjoy app registration did not converge within %s seconds\n' "$registration_timeout_seconds"
  return 1
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
app_path="${prebuilt_app_path:-$derived_data_path/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app}"
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

if [[ -n "$prebuilt_app_path" ]]; then
  {
    printf 'Using prebuilt iOS simulator app from SPOONJOY_SCREENSHOT_IOS_APP_PATH: %s\n' "$app_path"
    if [[ -d "$app_path" ]]; then
      build_status=0
    else
      printf 'prebuilt iOS simulator app bundle missing at %s\n' "$app_path"
      build_status=1
    fi
    printf 'iOS simulator build exit code: %s\n' "$build_status"
  } >> "$log_path" 2>&1
else
  {
    printf 'Running iOS simulator build: %s\n' "$build_label"
    set +e
    "${build_command[@]}"
    build_status=$?
    set -e
    printf 'iOS simulator build exit code: %s\n' "$build_status"
  } >> "$log_path" 2>&1
fi

if [[ "$build_status" -ne 0 ]]; then
  printf 'iOS simulator smoke build failed; see %s\n' "$log_path" >&2
  exit "$build_status"
fi

boot_log="$(mktemp)"
printf 'Booting simulator: %s %s; waiting for readiness with xcrun simctl bootstatus %s -b\n' "$boot_command" "$udid" "$udid" >> "$log_path"
set +e
run_with_timeout "$boot_command $udid || true; xcrun simctl bootstatus $udid -b" "$boot_timeout_seconds" > "$boot_log" 2>&1
boot_status=$?
set -e
cat "$boot_log" >> "$log_path"
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
  install_needed=1
  install_status=0
  if [[ "$reuse_installed_app" == "1" && -n "$install_marker" && -f "$install_marker" ]]; then
    printf 'Checking reusable iOS simulator app install marker: %s\n' "$install_marker"
    set +e
    existing_container="$(run_with_timeout "xcrun simctl get_app_container $udid app.spoonjoy data" 10)"
    existing_status=$?
    set -e
    printf 'simulator reusable app container lookup exit code: %s\n' "$existing_status"
    if [[ -n "$existing_container" ]]; then
      printf '%s\n' "$existing_container"
    fi
    if [[ "$existing_status" -eq 0 && -n "$existing_container" ]]; then
      install_needed=0
      printf 'Reusing installed iOS simulator app for this screenshot route\n'
    fi
  fi

  if [[ "$install_needed" -eq 1 ]]; then
    printf 'Uninstalling stale app before fresh install: %s app.spoonjoy\n' "$udid"
    set +e
    run_with_timeout "xcrun simctl uninstall $udid app.spoonjoy"
    uninstall_status=$?
    set -e
    printf 'simulator uninstall exit code: %s\n' "$uninstall_status"
    if [[ "$uninstall_status" -eq 124 ]]; then
      printf 'simulator uninstall timed out; continuing with fresh install attempt\n'
    fi
    printf 'Installing app: %s\n' "$app_path"
    set +e
    run_with_timeout "xcrun simctl install $udid '$app_path'"
    install_status=$?
    set -e
    printf 'simulator install exit code: %s\n' "$install_status"
    if [[ "$install_status" -eq 0 && "$reuse_installed_app" == "1" && -n "$install_marker" ]]; then
      mkdir -p "$(dirname "$install_marker")"
      printf '%s\n' "$app_path" > "$install_marker"
      printf 'Wrote reusable iOS simulator app install marker: %s\n' "$install_marker"
    fi
  fi
  if [[ "$install_status" -eq 0 ]] && ! wait_for_app_registration; then
    install_status=1
  fi
} >> "$log_path" 2>&1

if [[ "$install_status" -ne 0 ]]; then
  write_blocker \
    "CoreSimulator" \
    "xcrun simctl install $udid $app_path" \
    "$log_path" \
    "CoreSimulator app install or LaunchServices registration failed or hit a timeout." \
    "Confirm the selected simulator is responsive, reset it if needed, and rerun the iOS launch smoke."
  printf 'iOS simulator smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

{
  printf 'Launching app: %s --terminate-running-process app.spoonjoy\n' "$launch_command"
  launch_status=1
  attempt=1
  while [[ "$attempt" -le "$launch_attempts" ]]; do
    printf 'simulator launch attempt %s/%s\n' "$attempt" "$launch_attempts"
    set +e
    run_with_timeout "$launch_command --terminate-running-process $udid app.spoonjoy"
    launch_status=$?
    set -e
    printf 'simulator launch attempt %s exit code: %s\n' "$attempt" "$launch_status"
    if [[ "$launch_status" -eq 0 ]]; then
      break
    fi
    if [[ "$launch_status" -eq 124 ]]; then
      printf 'simulator launch attempt %s timed out; checking whether Spoonjoy is already registered as running\n' "$attempt"
      if app_is_registered_as_running; then
        printf 'Spoonjoy is registered as running after a simctl launch timeout; accepting launch smoke\n'
        launch_status=0
        break
      fi
      if [[ "$attempt" -lt "$launch_attempts" ]]; then
        printf 'Retrying simulator launch after timeout\n'
        sleep 2
        attempt=$((attempt + 1))
        continue
      fi
    fi
    break
  done
  printf 'simulator launch exit code: %s\n' "$launch_status"
} >> "$log_path" 2>&1

if [[ "$launch_status" -ne 0 ]]; then
  write_blocker \
    "CoreSimulator" \
    "$launch_command --terminate-running-process $udid app.spoonjoy" \
    "$log_path" \
    "CoreSimulator app launch failed or hit a timeout after $launch_attempts attempt(s)." \
    "Confirm the selected simulator can foreground Spoonjoy, reset the simulator if needed, and rerun the iOS launch smoke."
  printf 'iOS simulator smoke blocked; see %s\n' "$blocker_path"
  exit 0
fi

rm -f "$blocker_path"
printf 'iOS simulator smoke ok\n'
