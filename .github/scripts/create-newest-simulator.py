#!/usr/bin/env python3
"""Creates a simulator of one device family on the newest iOS runtime that supports it, and prints its UDID.

Usage: create-newest-simulator.py FAMILY NAME

FAMILY is "iPhone Duo", "iPhone" (any iPhone but the Duo) or "iPad", or a regular expression starting with ^ that
names device types, such as "^iPhone \\d+ Pro Max$" for the App Store's 6.9" screenshots (the newest match wins). The newest runtime differs per family: on the
xcode-27 runners iOS 27.1 lists only the iPhone Duo, while other iPhones and iPads stop at iOS 27.0.

Never a runtime newer than the selected Xcode's simulator SDK: an image can carry one ahead of its Xcode (iOS 27.2 beside
Xcode 27.1), and a device on it hung booting twice (#218).
"""
import json
import re
import subprocess
import sys


def matches(family, device_type):
    if family.startswith("^"):
        return re.search(family, device_type["name"]) is not None
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
    candidates = [t for t in runtime["supportedDeviceTypes"] if matches(family, t)]
    device_type = max(candidates, key=lambda t: t["name"]) if family.startswith("^") else candidates[0]
    return runtime["identifier"], device_type["identifier"]


LIST_LIMIT = 30  # it answers in seconds when CoreSimulator is healthy
LIST_TRIES = 2  # the caller's 120 s limit covers both tries, the restart between them and the create


def list_simulators(run=subprocess.run, kick=None, tries=LIST_TRIES):
    """`simctl list --json`, retried once after a CoreSimulator restart: the listing itself can hang (#218)."""
    kick = kick or restart_coresimulator
    why = "was not tried"
    for attempt in range(1, tries + 1):
        try:
            out = run(["xcrun", "simctl", "list", "--json"], capture_output=True, text=True, timeout=LIST_LIMIT)
            if out.returncode == 0:
                listing = json.loads(out.stdout)
                if "runtimes" in listing:
                    return listing
                why = "answered without runtimes"
            else:
                why = f"exited {out.returncode}: {out.stderr.strip()[-300:]}"
        except subprocess.TimeoutExpired:
            why = f"hung past {LIST_LIMIT} s"
        except ValueError:
            why = "answered with output that isn't JSON"
        if attempt < tries:
            print(f"::warning title=Infrastructure retry::simctl list {why}; restarting CoreSimulator (#218).", file=sys.stderr)
            kick()
    raise SystemExit(f"simctl list {why}, {tries} times, with CoreSimulator restarted between (#218).")


def restart_coresimulator():
    try:
        subprocess.run(["killall", "-9", "com.apple.CoreSimulator.CoreSimulatorService"], capture_output=True, timeout=20)
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"Restarting CoreSimulator failed ({error}); trying simctl again anyway.", file=sys.stderr)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    family, name = sys.argv[1], sys.argv[2]
    listing = list_simulators()
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], check=True, capture_output=True,
                         text=True).stdout.strip()
    runtime, device_type = pick(family, listing, sdk=sdk)
    udid = subprocess.run(["xcrun", "simctl", "create", name, device_type, runtime], check=True, capture_output=True, text=True).stdout.strip()
    print(f"Created {device_type} on {runtime}: {udid}", file=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
