#!/bin/bash
# Creates a simulator of one device family on the newest iOS runtime that supports it, boots it, and writes its UDID
# to OUT, and to OUT.booted-at the time (epoch seconds) just before the successful `simctl boot`, for scripts that
# measure from the boot. Messages, including the retry warning, go to standard output so the runner sees them.
#
# Usage: create-and-boot-simulator.sh FAMILY NAME OUT
#
# Nothing of the app has run yet, so a failure here is the runner's or CoreSimulator's: a create that hangs, or a
# simctl that aborts inside CoreSimulator (#218). Such a failure gets one more try on a fresh device, after
# CoreSimulator itself is restarted, reported as an infrastructure retry; a second failure fails. A fresh device alone
# was not enough: after a hung boot the service stayed wedged and the retry's create or boot hung too (#218: run
# 42410863682, run 42445736229). Each simctl call has its own limit, so a hang is caught here rather than by the
# step's timeout, which would end the job with no retry. Worst case: 2 tries of 120 + 120 + 150 s, plus 120 s of
# cleanup and 20 s of restart between them, is 920 s, inside the step's 16 minutes.
set -uo pipefail

family="$1"
name="$2"
out="$3"
here="$(cd "$(dirname "$0")" && pwd)"

# Runs a command with a limit in seconds (macOS has no timeout(1)); exits 142 when the limit is hit.
limit() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$seconds" "$@"
}

attempt() {
  local suffix="$1" udid
  udid="$(limit 120 python3 "$here/create-newest-simulator.py" "$family" "$name$suffix")" || { echo "creating the $family failed or hung (exit $?)" >&2; return 1; }
  echo "$udid" > "$out"
  date +%s > "$out.booted-at"
  limit 120 xcrun simctl boot "$udid" || { echo "booting $udid failed or hung (exit $?)" >&2; return 1; }
  # Its own allowance: a first boot on a fresh image builds the runtime's caches and can take minutes; only a device
  # still not up after seven is hung.
  limit 420 xcrun simctl bootstatus "$udid" -b || { echo "waiting for $udid to boot failed or hung (exit $?)" >&2; return 1; }
}

: > "$out"
attempt "" && exit 0

first="$(cat "$out")"
echo "::warning title=Infrastructure retry::Creating and booting the $family simulator failed before the app ran. Restarting CoreSimulator and trying once more on a fresh device (#218)."
# Restarted first, so the failed device's shutdown and delete reach a working service; launchd starts a fresh one on
# the next simctl call.
limit 20 killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1 || true
if [ -n "$first" ]; then
  limit 60 xcrun simctl shutdown "$first" >/dev/null 2>&1 || true
  limit 60 xcrun simctl delete "$first" >/dev/null 2>&1 || true
fi
: > "$out"
attempt "-retry" && exit 0
echo "::error::Creating and booting the $family simulator failed twice; see the messages above."
exit 1
