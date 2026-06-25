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

{
  xcodebuild -version
  xcode-select -p
  xcodebuild -checkFirstLaunchStatus
} > "$output_path" 2>&1

command=("$@")
command_status=0
set +e
"${command[@]}" >> "$output_path" 2>&1
command_status=$?
set -e

if [[ "$command_status" -eq 0 ]]; then
  exit 0
fi

if ruby -e '
  output = File.read(ARGV.fetch(0))
  allowed = [
    /iOS 26\.5 is not installed/,
    /Unable to find a destination/,
    /CoreSimulator/,
    /DVTPlugIn/,
    /IDEDistribution/
  ]
  exit(allowed.any? { |pattern| output.match?(pattern) } ? 0 : 1)
' "$output_path"; then
  ruby -rjson -e '
    path, command, timeout_seconds, output_path = ARGV
    blocker = {
      capability: "XcodePlatform",
      blocked: true,
      command: command,
      timeoutSeconds: Integer(timeout_seconds),
      outputPath: output_path,
      reason: "Local Xcode platform or pre-parse state blocked app bundle validation."
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$blocker_path" "${command[*]}" "$timeout_seconds" "$output_path"
  exit 0
fi

exit "$command_status"
