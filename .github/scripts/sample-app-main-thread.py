#!/usr/bin/env python3
"""Sample the Spoonjoy app's main thread during a journey run, and print the samples afterwards.

  sample-app-main-thread.py record DIR   runs in the background: every 15 seconds, while a Spoonjoy
                                         process exists, `sample` records one second of it into DIR.
                                         It stops when DIR/stop exists or after 30 minutes.
  sample-app-main-thread.py print DIR    prints each sample's UTC time and the top of its main-thread
                                         call graph, so a stall in the journey log can be matched to
                                         what the app's main thread was doing.

Samples hold only stack frames (function names), never memory contents. The script never fails a job.
"""

import glob
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

INTERVAL_SECONDS = 15
LIMIT_SECONDS = 30 * 60
MAIN_THREAD_LINES = 30


def record(directory):
    os.makedirs(directory, exist_ok=True)
    deadline = time.monotonic() + LIMIT_SECONDS
    while time.monotonic() < deadline and not os.path.exists(os.path.join(directory, "stop")):
        found = subprocess.run(["pgrep", "-x", "Spoonjoy"], capture_output=True, text=True).stdout.split()
        if found:
            stamp = datetime.now(timezone.utc).strftime("%H%M%S")
            output = os.path.join(directory, f"{stamp}-{found[0]}.txt")
            subprocess.run(["sample", found[0], "1", "-mayDie", "-file", output], capture_output=True)
        time.sleep(INTERVAL_SECONDS)


def main_thread_lines(text):
    lines = text.splitlines()
    start = next((index for index, line in enumerate(lines) if "com.apple.main-thread" in line), None)
    if start is None:
        return ["(no main thread in this sample)"]
    return lines[start:start + MAIN_THREAD_LINES]


def print_samples(directory):
    files = sorted(glob.glob(os.path.join(directory, "*.txt")))
    if not files:
        print(f"No app samples in {directory}.")
        return
    for path in files:
        name = os.path.basename(path)
        print(f"== {name[0:2]}:{name[2:4]}:{name[4:6]} UTC, pid {name[7:-4]}")
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                print("\n".join(main_thread_lines(handle.read())))
        except OSError as error:
            print(f"(could not read the sample: {error})")


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("record", "print"):
        print("usage: sample-app-main-thread.py record|print DIR")
        return
    if sys.argv[1] == "record":
        record(sys.argv[2])
    else:
        print_samples(sys.argv[2])


if __name__ == "__main__":
    main()
