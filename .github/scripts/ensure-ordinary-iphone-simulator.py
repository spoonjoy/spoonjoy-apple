#!/usr/bin/env python3
"""Creates an ordinary iPhone simulator on the newest iOS runtime when that runtime has none.

Xcode 27.1 on the xcode-27 runner ships the iOS 27.1 runtime with only an iPhone Duo, which boots folded on its
outer screen. The journeys and shopping UI tests expect an ordinary iPhone, and resolve-ios-simulator-destination.py
prefers the newest runtime, so this gives it one to pick.
"""
import json
import subprocess
import sys

DEVICE_NAME = "iPhone 18 Pro"
DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"


def simctl_json(*args: str) -> dict:
    # The first simctl call on a fresh hosted runner starts CoreSimulator and can take over 30 seconds.
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *args, "--json"], text=True, timeout=120))


def version_tuple(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split(".") if part.isdigit())


runtimes = [
    runtime for runtime in simctl_json("runtimes").get("runtimes", [])
    if runtime.get("platform") == "iOS" and runtime.get("isAvailable")
]
if not runtimes:
    print("No available iOS runtime.", file=sys.stderr)
    sys.exit(1)
newest = max(runtimes, key=lambda runtime: version_tuple(runtime.get("version", "0")))
identifier = newest["identifier"]
devices = simctl_json("devices", "available").get("devices", {}).get(identifier, [])
ordinary = [device for device in devices if device.get("name", "").startswith("iPhone") and not device["name"].startswith("iPhone Duo")]
if ordinary:
    print(f"{newest['name']} already has {ordinary[0]['name']}.")
    sys.exit(0)
udid = subprocess.check_output(["xcrun", "simctl", "create", DEVICE_NAME, DEVICE_TYPE, identifier], text=True, timeout=120).strip()
print(f"Created {DEVICE_NAME} ({udid}) on {newest['name']}.")
