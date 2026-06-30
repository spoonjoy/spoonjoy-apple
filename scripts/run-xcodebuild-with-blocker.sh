#!/usr/bin/env bash
set -euo pipefail

output_path=""
blocker_path=""
timeout_seconds="30"
platform_blocker_example="iOS 26.5 is not installed"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      output_path="$2"
      shift 2
      ;;
    --blocker)
      blocker_path="$2"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$output_path" || -z "$blocker_path" || "$#" -eq 0 ]]; then
  printf 'Usage: scripts/run-xcodebuild-with-blocker.sh --output PATH --blocker PATH --timeout-seconds SECONDS -- xcodebuild ...\n' >&2
  exit 2
fi

mkdir -p "$(dirname "$output_path")" "$(dirname "$blocker_path")"
rm -f "$blocker_path"

classify_blocker() {
  ruby -e '
    output = File.read(ARGV.fetch(0))
    allowed = [
      /xcodebuild: error: iOS \d+(?:\.\d+)? is not installed/i,
      /xcodebuild: error: Unable to find a destination matching/i,
      /CoreSimulatorService connection became invalid/i,
      /DVTPlugInManager failed to load plug-in/i,
      /IDEDistribution.*private framework/i
    ]
    exit(allowed.any? { |pattern| output.match?(pattern) } ? 0 : 1)
  ' "$output_path"
}

write_blocker() {
  local command_string="$1"
  local reason="${2:-Local Xcode platform or pre-parse state blocked app bundle validation.}"
  local owner_action="${3:-Install the required Xcode platform/runtime and rerun app bundle validation.}"
  ruby -rjson -e '
    path, command, timeout_seconds, output_path, reason, owner_action = ARGV
    blocker = {
      capability: "XcodePlatform",
      blocked: true,
      command: command,
      timeoutSeconds: Integer(timeout_seconds),
      outputPath: output_path,
      reason: reason,
      ownerAction: owner_action
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$blocker_path" "$command_string" "$timeout_seconds" "$output_path" "$reason" "$owner_action"
}

run_with_timeout() {
  python3 - "$timeout_seconds" "$output_path" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
output_path = sys.argv[2]
command = sys.argv[3:]
with open(output_path, "ab") as output:
    try:
        completed = subprocess.run(
            command,
            stdout=output,
            stderr=subprocess.STDOUT,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired:
        output.write(f"\nCommand timed out after {timeout_seconds} seconds\n".encode())
        sys.exit(124)
sys.exit(completed.returncode)
PY
}

preflight_status=0
preflight_command=""
: > "$output_path"
set +e
preflight_command="xcodebuild -version"
run_with_timeout xcodebuild -version
preflight_status=$?
if [[ "$preflight_status" -eq 0 ]]; then
  preflight_command="xcode-select -p"
  run_with_timeout xcode-select -p
  preflight_status=$?
fi
if [[ "$preflight_status" -eq 0 ]]; then
  preflight_command="xcodebuild -checkFirstLaunchStatus"
  run_with_timeout xcodebuild -checkFirstLaunchStatus
  preflight_status=$?
fi
set -e

if [[ "$preflight_status" -ne 0 ]]; then
  printf '\nXcode preflight command failed: %s (exit %s)\n' "$preflight_command" "$preflight_status" >> "$output_path"
  write_blocker \
    "$preflight_command (exit $preflight_status)" \
    "Local Xcode preflight command failed before app bundle validation." \
    "Complete Xcode first-launch setup, select a working developer directory, or repair the local Xcode platform/runtime, then rerun app bundle validation."
  exit 0
fi

command=("$@")
command_status=0
set +e
run_with_timeout "${command[@]}"
command_status=$?
set -e

if [[ "$command_status" -eq 0 ]]; then
  exit 0
fi

if classify_blocker; then
  write_blocker "${command[*]}"
  exit 0
fi

exit "$command_status"
