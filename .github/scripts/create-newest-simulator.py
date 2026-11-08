#!/usr/bin/env python3
"""Creates a simulator of one device family on the newest iOS runtime that supports it, and prints its UDID.

Usage: create-newest-simulator.py FAMILY NAME

FAMILY is "iPhone Duo", "iPhone" (any iPhone but the Duo) or "iPad". The newest runtime differs per family: on the
xcode-27 runners iOS 27.1 lists only the iPhone Duo, while other iPhones and iPads stop at iOS 27.0.

Never a runtime newer than the selected Xcode's simulator SDK: an image can carry one ahead of its Xcode (iOS 27.2 beside
Xcode 27.1), and a device on it hung booting twice (#218).
"""
import json
import subprocess
import sys


def matches(family, device_type):
    if family == "iPhone Duo":
        return "Duo" in device_type["name"]
    return device_type.get("productFamily") == family and "Duo" not in device_type["name"]


def version(text):
    return [int(part) for part in text.split(".")]


def pick(family, listing, sdk=None):
    runtimes = [
        runtime for runtime in listing["runtimes"]
        if runtime["platform"] == "iOS" and runtime["isAvailable"]
        and any(matches(family, t) for t in runtime.get("supportedDeviceTypes", []))
        and (sdk is None or version(runtime["version"])[:2] <= version(sdk)[:2])
    ]
    if not runtimes:
        raise SystemExit(f"No available iOS runtime{f' up to {sdk}' if sdk else ''} supports a {family}.")
    runtime = max(runtimes, key=lambda r: version(r["version"]))
    device_type = next(t for t in runtime["supportedDeviceTypes"] if matches(family, t))
    return runtime["identifier"], device_type["identifier"]


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    family, name = sys.argv[1], sys.argv[2]
    listing = json.loads(subprocess.run(["xcrun", "simctl", "list", "--json"], check=True, capture_output=True, text=True).stdout)
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], check=True, capture_output=True,
                         text=True).stdout.strip()
    runtime, device_type = pick(family, listing, sdk=sdk)
    udid = subprocess.run(["xcrun", "simctl", "create", name, device_type, runtime], check=True, capture_output=True, text=True).stdout.strip()
    print(f"Created {device_type} on {runtime}: {udid}", file=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
