#!/usr/bin/env python3
"""Scratch probe: watch a booted simulator and record when poster bursts happen and what spawns with them."""

import argparse
import collections
import datetime
import json
import os
import subprocess
import sys
import time

PREDICATE = ('process CONTAINS "Poster" OR subsystem BEGINSWITH "com.apple.PosterBoard" OR subsystem BEGINSWITH "com.apple.PosterKit"'
             ' OR process == "dasd" OR subsystem == "com.apple.duetactivityscheduler"')
WINDOW = 20


def sim_processes(udid: str) -> dict:
    out = subprocess.run(["ps", "-axo", "pid=,args="], capture_output=True, text=True).stdout
    procs = {}
    for line in out.splitlines():
        line = line.strip()
        pid, _, args = line.partition(" ")
        if "CoreSimulator" not in args and "RuntimeRoot" not in args and udid not in args:
            continue
        exe = args.split(" ")[0]
        procs[int(pid)] = os.path.basename(exe)
    return procs


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("udid")
    p.add_argument("--booted-at", type=int, required=True)
    p.add_argument("--until", type=int, default=1100, help="seconds after boot to stop")
    p.add_argument("--out", required=True)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stream_path = os.path.join(a.out, "poster-dasd-stream.ndjson")
    stream = subprocess.Popen(["xcrun", "simctl", "spawn", a.udid, "log", "stream", "--style", "ndjson", "--level", "info", "--predicate", PREDICATE],
                              stdout=open(stream_path, "w"), stderr=subprocess.DEVNULL)
    seen = sim_processes(a.udid)
    print(f"{len(seen)} simulator processes at start ({int(time.time() - a.booted_at)} s after boot); "
          f"{sum('Poster' in n for n in seen.values())} poster processes.", flush=True)
    spawn_log = open(os.path.join(a.out, "spawns.tsv"), "w")
    while time.time() - a.booted_at < a.until:
        time.sleep(WINDOW)
        now = sim_processes(a.udid)
        new = {pid: n for pid, n in now.items() if pid not in seen}
        seen.update(new)
        t = int(time.time() - a.booted_at)
        for pid, n in sorted(new.items()):
            spawn_log.write(f"{t}\t{pid}\t{n}\n")
        spawn_log.flush()
        posters_alive = sum("Poster" in n for n in now.values())
        new_posters = sum("Poster" in n for n in new.values())
        names = ", ".join(sorted(collections.Counter(new.values())))[:600]
        print(f"t={t:5d}s alive={len(now):4d} posters_alive={posters_alive:3d} new={len(new):3d} new_posters={new_posters:3d} :: {names}", flush=True)
    stream.terminate()
    time.sleep(2)

    # Per-window line counts of poster lines (excluding dasd) from the stream.
    buckets = collections.Counter()
    dasd = []
    for line in open(stream_path, errors="replace"):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = e.get("timestamp", "")
        try:
            when = datetime.datetime.strptime(ts, "%Y-%m-%d %H:%M:%S.%f%z").timestamp()
        except ValueError:
            continue
        t = int(when - a.booted_at)
        proc = os.path.basename(e.get("processImagePath", ""))
        if proc == "dasd" or e.get("subsystem") == "com.apple.duetactivityscheduler":
            dasd.append((t, e.get("eventMessage", "")[:300]))
        else:
            buckets[t // WINDOW * WINDOW] += 1
    print("\nPoster log lines per 20 s window (seconds after boot):")
    for k in sorted(buckets):
        print(f"  {k:5d}-{k + WINDOW:5d}s {buckets[k]:7d} {'#' * min(80, buckets[k] // 250)}")
    late = [k for k in sorted(buckets) if k >= 600 and buckets[k] >= 1000]
    total_late = sum(v for k, v in buckets.items() if k >= 600)
    print(f"\nRESULT late_burst={'yes' if late else 'no'} first_late_burst_window={late[0] if late else '-'} "
          f"late_poster_lines={total_late} total_poster_lines={sum(buckets.values())}")
    if late:
        start = late[0]
        print(f"\ndasd lines from {start - 90} s to {start + 30} s:")
        for t, m in dasd:
            if start - 90 <= t <= start + 30:
                print(f"  {t:5d}s {m}")
        boot = a.booted_at
        fmt = lambda s: time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(boot + s))
        with open(os.path.join(a.out, "full-log-around-burst.ndjson"), "w") as fh:
            subprocess.run(["xcrun", "simctl", "spawn", a.udid, "log", "show", "--style", "ndjson", "--info", "--debug",
                            "--start", fmt(start - 120), "--end", fmt(start + 40)], stdout=fh, stderr=subprocess.DEVNULL, timeout=600)
    with open(os.path.join(a.out, "dasd.txt"), "w") as fh:
        for t, m in dasd:
            fh.write(f"{t}\t{m}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
