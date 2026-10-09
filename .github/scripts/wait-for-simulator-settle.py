#!/usr/bin/env python3
"""Wait until a freshly booted iOS simulator has finished its one-time lock screen poster burst.

A few minutes after first boot, PosterBoard launches every lock screen poster extension and renders them. While
that burst runs, the simulator is so busy that XCTest misses the "app stopped" notice for an app it just
terminated, waits its fixed 60 s, and fails with "Failed to terminate app.spoonjoy" (Shopping UI tests runs
37934203995 and 37928276839: the app died within 2 s; the notice arrived after the 60 s wait had failed).

The burst is a real, observable event, so this waits for it to happen and end rather than sleeping a fixed time:
it looks for the burst in the simulator log since boot, then waits for the poster log to go quiet. If no burst
shows up by the deadline, it continues with a warning instead of failing the job.
"""

import argparse
import subprocess
import sys
import time

PREDICATE = 'process CONTAINS "Poster" OR subsystem BEGINSWITH "com.apple.PosterBoard" OR subsystem BEGINSWITH "com.apple.PosterKit"'
# Measured on an iOS 27 simulator: the burst logs 5,000 to 50,000 poster lines a minute; a settled simulator
# logs a few hundred at most while an app is in front, and close to none when idle.
BURST_LINES_SINCE_BOOT = 5000
BURST_LINES_PER_WINDOW = 1000
QUIET_LINES_PER_WINDOW = 60
WINDOW_SECONDS = 20
QUIET_READINGS_NEEDED = 2
POLL_SECONDS = 10


def poster_lines(udid: str, *log_range: str) -> int:
    result = subprocess.run(
        ["xcrun", "simctl", "spawn", udid, "log", "show", *log_range, "--style", "compact", "--predicate", PREDICATE],
        capture_output=True,
        text=True,
        check=True,
    )
    # The first line is the column header.
    return max(0, len(result.stdout.splitlines()) - 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("udid")
    parser.add_argument("--booted-at", type=int, required=True, help="Unix time the simulator was booted")
    parser.add_argument("--deadline-minutes", type=float, default=8, help="Give up this long after boot")
    args = parser.parse_args()

    deadline = args.booted_at + args.deadline_minutes * 60
    boot_start = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(args.booted_at))
    since_boot = poster_lines(args.udid, "--start", boot_start)
    burst_seen = since_boot >= BURST_LINES_SINCE_BOOT
    print(f"Poster log lines since boot ({boot_start}): {since_boot}; burst {'already seen' if burst_seen else 'not seen yet'}.")

    quiet_readings = 0
    while True:
        recent = poster_lines(args.udid, "--last", f"{WINDOW_SECONDS}s")
        if recent >= BURST_LINES_PER_WINDOW:
            burst_seen = True
        quiet_readings = quiet_readings + 1 if recent < QUIET_LINES_PER_WINDOW else 0
        elapsed = int(time.time() - args.booted_at)
        print(f"{elapsed}s after boot: {recent} poster log lines in the last {WINDOW_SECONDS}s.", flush=True)

        if burst_seen and quiet_readings >= QUIET_READINGS_NEEDED:
            print("The poster burst has finished; the simulator is settled.")
            return 0
        if time.time() >= deadline:
            reason = "is still running" if burst_seen else "never started"
            print(f"::warning::The simulator's lock screen poster burst {reason} {args.deadline_minutes:g} minutes after boot; "
                  "continuing. A test that terminates the app during the burst can fail with \"Failed to terminate\".")
            return 0
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    sys.exit(main())
