#!/usr/bin/env python3
"""Picks the newest installed Xcode whose iOS Simulator SDK has a runtime of the same version, and an iPhone Duo on it.

Usage: pick-matching-xcode.py
Prints three lines: the Xcode's path, the runtime identifier, and the device type identifier.

AppIntentsTesting (the Siri journey) ships inside Xcode but calls the simulator runtime's AppIntentsServices, so it
loads only on a runtime of the very version its Xcode's SDK has; on any other dyld fails the whole test bundle
("Symbol not found ... RunnerServiceDispatcher", Journeys run 43054178295, Xcode 27.1 beside iOS 27.2). Runner images
move Xcodes and runtimes separately, so this picks a matching pair instead of pinning one.

A matching pair must also be one AppIntentsTesting calls are known to return on in CI: ouro-ui-apple's X-ray probe got
answers from 38 calls on Xcode 27.1 and iOS 27.1 (iPhone Duo, run 42543379013), and its lanes expect a full run on 27.0.
27.2 is unproven: its one run refused every call with AppIntentsServicesSecurityErrorDomain 803, but that run's test
runner was the unsigned build's Apple-signed xctrunner, which 27.1 refused the same way (run 43087839715). Add a version
to PROVEN only after a CI run of the Siri journey on it passes.

The device is always the iPhone Duo: every passing run used it (run 43207409010), and the journey holds its hinge open.
"""
import glob
import json
import os
import subprocess
import sys


# Newest first.
PROVEN = ["27.1", "27.0"]


def version(text):
    return [int(part) for part in text.split(".")]


def is_duo(device_type):
    return device_type.get("productFamily") == "iPhone" and "Duo" in device_type.get("name", "")


def pick(xcodes, listing, proven=PROVEN):
    """xcodes: [(path, sdk version)]. Returns (path, runtime identifier, device type identifier) or raises SystemExit."""
    pairs = []
    for path, sdk in xcodes:
        for runtime in listing["runtimes"]:
            if runtime["platform"] != "iOS" or not runtime["isAvailable"]:
                continue
            if version(runtime["version"])[:2] != version(sdk)[:2]:
                continue
            if ".".join(str(part) for part in version(sdk)[:2]) not in proven:
                continue
            duos = [t for t in runtime.get("supportedDeviceTypes", []) if is_duo(t)]
            if not duos:
                continue
            pairs.append((version(sdk), path, runtime["identifier"], duos[-1]["identifier"]))
    if not pairs:
        found = ", ".join(f"{path} (SDK {sdk})" for path, sdk in xcodes) or "none"
        runtimes = ", ".join(r["version"] for r in listing["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]) or "none"
        raise SystemExit(
            f"No installed Xcode has an iOS runtime, with an iPhone Duo, of its own SDK's version that AppIntentsTesting is proven on "
            f"(proven: {', '.join(proven)}). Xcodes: {found}. iOS runtimes: {runtimes}."
        )
    _, path, runtime, device = max(pairs, key=lambda pair: pair[0])
    return path, runtime, device


def installed_xcodes():
    xcodes = []
    for path in sorted(glob.glob("/Applications/Xcode_27*.app")):
        env = dict(os.environ, DEVELOPER_DIR=f"{path}/Contents/Developer")
        result = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], env=env, capture_output=True, text=True, timeout=60)
        if result.returncode == 0 and result.stdout.strip():
            xcodes.append((path, result.stdout.strip()))
    return xcodes


if __name__ == "__main__":
    listing = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "--json"]))
    for line in pick(installed_xcodes(), listing):
        print(line)
    sys.exit(0)
