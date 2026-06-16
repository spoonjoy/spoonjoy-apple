#!/usr/bin/env python3
import json
import re
import subprocess
import sys


def runtime_version(runtime: str) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", runtime))


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
matches: list[tuple[tuple[int, ...], str, str]] = []

for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue

    for device in devices:
        name = device.get("name", "")
        udid = device.get("udid", "")
        if device.get("isAvailable") and name.startswith("iPhone") and udid:
            matches.append((runtime_version(runtime), name, udid))

if not matches:
    print("No available iPhone simulator found.", file=sys.stderr)
    sys.exit(1)

_, _, selected_udid = sorted(matches, reverse=True)[0]
print(f"platform=iOS Simulator,id={selected_udid}")
