#!/usr/bin/env python3
"""Wait until a freshly booted iOS simulator has finished its one-time lock screen poster burst.

A few minutes after first boot, PosterBoard launches every lock screen poster extension and renders them. While
that burst runs, the simulator is so busy that XCTest misses the "app stopped" notice for an app it just
terminated, waits its fixed 60 s, and fails with "Failed to terminate app.spoonjoy" (Shopping UI tests runs
37934203995 and 37928276839: the app died within 2 s; the notice arrived after the 60 s wait had failed).

The burst is a real, observable event, so this waits for it to happen and end rather than sleeping a fixed time:
it looks for the burst in the simulator log since boot, then waits for the poster log to go quiet. This step only
improves the odds for the tests, so nothing here fails the job: if no burst shows up by the deadline, or the
simulator log cannot be read, it continues with a warning.
"""

import argparse
import subprocess
import sys
import time

PREDICATE = 'process CONTAINS "Poster" OR subsystem BEGINSWITH "com.apple.PosterBoard" OR subsystem BEGINSWITH "com.apple.PosterKit"'
# Measured on an iOS 27.0 simulator (24A434): the burst logs 5,000 to 50,000 poster lines a minute; a settled
# simulator logs a few hundred at most while an app is in front, and close to none when idle.
BURST_LINES_SINCE_BOOT = 5000
BURST_LINES_PER_WINDOW = 1000
QUIET_LINES_PER_WINDOW = 60
WINDOW_SECONDS = 20
QUIET_READINGS_NEEDED = 2
POLL_SECONDS = 10
# The longest one log read may take, so the deadline holds even when the simulator is too busy to answer.
LOG_READ_LIMIT_SECONDS = 90
# A simulator that was already booted when the job started: how far back to look, and how long to wait.
ALREADY_BOOTED_HISTORY_SECONDS = 600
ALREADY_BOOTED_WAIT_SECONDS = 120


class LogUnreadable(Exception):
    pass


def poster_lines(udid: str, seconds: int, limit: float) -> int:
    """Poster log lines the simulator wrote in the last `seconds`."""
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "spawn", udid, "log", "show", "--last", f"{seconds}s", "--style", "compact", "--predicate", PREDICATE],
            capture_output=True,
            text=True,
            check=True,
            timeout=max(5, min(LOG_READ_LIMIT_SECONDS, limit)),
        )
    except subprocess.TimeoutExpired as error:
        raise LogUnreadable(f"reading the simulator log took longer than {error.timeout:g} s") from error
    except subprocess.CalledProcessError as error:
        raise LogUnreadable(f"reading the simulator log failed with exit code {error.returncode}: {error.stderr.strip()[:500]}") from error
    # The first line is the column header.
    return max(0, len(result.stdout.splitlines()) - 1)


def wait(udid: str, booted_at: int, deadline_minutes: float) -> str:
    now = time.time()
    if booted_at > 0:
        history_seconds = int(now - booted_at) + 5
        deadline = booted_at + deadline_minutes * 60
    else:
        history_seconds = ALREADY_BOOTED_HISTORY_SECONDS
        deadline = now + ALREADY_BOOTED_WAIT_SECONDS
        print(f"The simulator was already booted; looking back {history_seconds} s and waiting at most {ALREADY_BOOTED_WAIT_SECONDS} s.")

    # A simulator booted before this job may have had its burst long ago, so for it a quiet log is enough.
    burst_seen = booted_at <= 0
    try:
        since_boot = poster_lines(udid, history_seconds, min(LOG_READ_LIMIT_SECONDS, deadline - time.time()))
        burst_seen = burst_seen or since_boot >= BURST_LINES_SINCE_BOOT
        print(f"Poster log lines in the last {history_seconds} s: {since_boot}; burst {'already seen' if burst_seen else 'not seen yet'}.")
    except LogUnreadable as error:
        # The history read is the largest; it is most likely to time out in the middle of a heavy burst, so keep
        # watching the short windows instead of giving up.
        print(f"Could not read the log since boot ({error}); watching recent windows instead.")

    quiet_readings = 0
    while True:
        recent = poster_lines(udid, WINDOW_SECONDS, deadline - time.time())
        if recent >= BURST_LINES_PER_WINDOW:
            burst_seen = True
        quiet_readings = quiet_readings + 1 if recent < QUIET_LINES_PER_WINDOW else 0
        print(f"{time.strftime('%H:%M:%S')}: {recent} poster log lines in the last {WINDOW_SECONDS} s.", flush=True)

        if burst_seen and quiet_readings >= QUIET_READINGS_NEEDED:
            return "settled"
        if time.time() >= deadline:
            return "still running" if burst_seen else "never started"
        time.sleep(POLL_SECONDS)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("udid")
    parser.add_argument("--booted-at", type=int, required=True, help="Unix time the simulator was booted, or 0 if it was already booted")
    parser.add_argument("--deadline-minutes", type=float, default=8, help="Give up this long after boot")
    args = parser.parse_args()
    print(f"Thresholds: burst at {BURST_LINES_SINCE_BOOT} lines since boot or {BURST_LINES_PER_WINDOW} per {WINDOW_SECONDS} s; "
          f"quiet below {QUIET_LINES_PER_WINDOW} per {WINDOW_SECONDS} s, {QUIET_READINGS_NEEDED} readings in a row.")

    try:
        outcome = wait(args.udid, args.booted_at, args.deadline_minutes)
    except LogUnreadable as error:
        print(f"::warning::Could not tell whether the simulator has settled ({error}); continuing.")
        return 0
    if outcome == "settled":
        print("The poster burst has finished; the simulator is settled.")
    else:
        print(f"::warning::The simulator's lock screen poster burst {outcome} by the deadline; continuing. "
              "A test that terminates the app during the burst can fail with \"Failed to terminate\".")
    return 0


if __name__ == "__main__":
    sys.exit(main())
