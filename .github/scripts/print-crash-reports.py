#!/usr/bin/env python3
"""Print the crash reports a journey run left for the Spoonjoy app.

XCTest reports "Lost connection to the application" when the app dies mid-journey, and the crash
report itself only reaches the result bundle. This prints each Spoonjoy crash report's exception,
termination reason, application-specific message and the crashing thread's frames into the job log.
It never fails the job: a missing directory or unreadable report is described and skipped.
"""

import glob
import json
import os
import sys

MAX_FRAMES = 40


def describe(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        header_line, _, body_text = handle.read().partition("\n")
    header = json.loads(header_line)
    body = json.loads(body_text)
    print(f"== {os.path.basename(path)}")
    print(f"process: {body.get('procName', header.get('app_name'))} {header.get('app_version', '')}")
    print(f"exception: {json.dumps(body.get('exception'))}")
    print(f"termination: {json.dumps(body.get('termination'))}")
    if body.get("asi"):
        print(f"application-specific: {json.dumps(body.get('asi'))}")
    images = body.get("usedImages", [])
    threads = body.get("threads", [])
    backtraces = []
    if body.get("lastExceptionBacktrace"):
        backtraces.append(("last exception backtrace", body["lastExceptionBacktrace"]))
    faulting = body.get("faultingThread")
    if isinstance(faulting, int) and faulting < len(threads):
        backtraces.append((f"crashing thread {faulting}", threads[faulting].get("frames", [])))
    for title, frames in backtraces:
        print(f"-- {title}")
        for index, frame in enumerate(frames[:MAX_FRAMES]):
            image_index = frame.get("imageIndex")
            image = images[image_index].get("name", "?") if isinstance(image_index, int) and image_index < len(images) else "?"
            symbol = frame.get("symbol", f"+{frame.get('imageOffset', '?')}")
            location = f" ({frame['sourceFile']}:{frame.get('sourceLine', '?')})" if frame.get("sourceFile") else ""
            print(f"{index:3d} {image} {symbol}{location}")


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Library/Logs/DiagnosticReports")
    reports = sorted(glob.glob(os.path.join(directory, "**", "Spoonjoy*.ips"), recursive=True))
    if not reports:
        print(f"No Spoonjoy crash reports under {directory}.")
        return
    for path in reports:
        try:
            describe(path)
        except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
            print(f"== {os.path.basename(path)}: could not read the report ({error})")


if __name__ == "__main__":
    main()
