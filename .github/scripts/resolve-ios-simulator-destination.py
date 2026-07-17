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


def family_device_rank(name: str, family: str) -> int:
    if family != "ipad":
        return 0
    if name.startswith("iPad Pro 13-inch"):
        return 5
    if name.startswith("iPad Air 13-inch"):
        return 4
    if name.startswith("iPad Pro 11-inch"):
        return 3
    if name.startswith("iPad Air 11-inch"):
        return 2
    if name.startswith("iPad mini"):
        return 0
    return 1


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
preferred_family = os.environ.get("SPOONJOY_IOS_SIMULATOR_FAMILY", "iphone").strip().lower()
if preferred_family not in {"iphone", "ipad"}:
    print(f"Unsupported iOS simulator family: {preferred_family}", file=sys.stderr)
    sys.exit(1)
all_available_ios_devices: list[tuple[tuple[int, ...], int, str, str, str]] = []
default_family_matches: list[tuple[tuple[int, ...], int, str, str, str]] = []

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
            family_prefix = "iPad" if preferred_family == "ipad" else "iPhone"
            if name.startswith(family_prefix):
                default_family_matches.append(match)

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

if not default_family_matches:
    print(f"No available {preferred_family} simulator found.", file=sys.stderr)
    sys.exit(1)

_, _, _, selected_udid, _ = sorted(
    default_family_matches,
    key=lambda match: (match[0], match[1], family_device_rank(match[2], preferred_family), match[2]),
    reverse=True,
)[0]
print(f"platform=iOS Simulator,id={selected_udid}")
