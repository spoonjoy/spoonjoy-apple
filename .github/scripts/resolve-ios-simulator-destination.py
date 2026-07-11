#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys


def runtime_version(runtime: str) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", runtime))


def state_rank(state: str) -> int:
    return 1 if state == "Shutdown" else 0


try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True,
        timeout=30,
    )
except Exception as exc:
    print(f"Unable to list available iOS simulators: {exc}", file=sys.stderr)
    sys.exit(1)

data = json.loads(raw)
preferred_udid = os.environ.get("SPOONJOY_IOS_SIMULATOR_UDID", "").strip()
preferred_name = os.environ.get("SPOONJOY_IOS_SIMULATOR_NAME", "").strip()
all_available_ios_devices: list[tuple[tuple[int, ...], int, str, str, str]] = []
default_iphone_matches: list[tuple[tuple[int, ...], int, str, str, str]] = []

for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue

    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid", "")
        state = device.get("state", "")
        if device.get("isAvailable") and udid:
            match = (runtime_version(runtime), state_rank(state), name, udid, state)
            all_available_ios_devices.append(match)
            if name.startswith("iPhone"):
                default_iphone_matches.append(match)

if not all_available_ios_devices:
    print("No available iOS simulator found.", file=sys.stderr)
    sys.exit(1)

if preferred_udid:
    for _, _, name, udid, _ in all_available_ios_devices:
        if udid == preferred_udid:
            print(f"platform=iOS Simulator,id={udid}")
            sys.exit(0)
    print(f"Requested iOS simulator UDID is not available: {preferred_udid}", file=sys.stderr)
    sys.exit(1)

if preferred_name:
    named_matches = [match for match in all_available_ios_devices if match[2] == preferred_name]
    if not named_matches:
        print(f"Requested iOS simulator name is not available: {preferred_name}", file=sys.stderr)
        sys.exit(1)
    _, _, _, selected_udid, _ = sorted(named_matches, reverse=True)[0]
    print(f"platform=iOS Simulator,id={selected_udid}")
    sys.exit(0)

if not default_iphone_matches:
    print("No available iPhone simulator found.", file=sys.stderr)
    sys.exit(1)

_, _, _, selected_udid, _ = sorted(default_iphone_matches, reverse=True)[0]
print(f"platform=iOS Simulator,id={selected_udid}")
