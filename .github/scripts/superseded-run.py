#!/usr/bin/env python3
"""Ends a stale After TestFlight run's jobs early (#413).

After TestFlight runs one at a time, and its jobs wait one at a time in macOS lane c, so a run takes hours. Its first
job skips a commit main has already moved past, but only when the run starts: once running, a run for a commit main
then moved past kept the after-testflight-main group for hours while the newest commit's run waited. Each lane c job
now runs this right after checkout. When main's head is no longer this run's commit and a newer After TestFlight run
is waiting, it sets SPOONJOY_SUPERSEDED=true for the job's remaining steps, which all skip, so the stale run drains in
minutes and the newest commit's run takes the group. The newest commit's run never skips: its commit is main's head,
or no newer run is waiting. Any API failure leaves the job running.
"""
import json
import os
import subprocess
import sys

# A run waiting on the concurrency group reports "pending"; the others are GitHub's other not-yet-running states.
WAITING = {"pending", "queued", "waiting", "requested"}


def superseded(run_id, run_sha, main_head, runs):
    """The newer waiting run that replaces this one, or None. runs: After TestFlight runs from the runs API."""
    if run_sha == main_head:
        return None
    # A running run also reports "pending" at the run level, so only runs created after this one count.
    newer = [run for run in runs if int(run["id"]) > int(run_id) and run.get("status") in WAITING]
    return min(newer, key=lambda run: int(run["id"])) if newer else None


def gh_json(path):
    return json.loads(subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout)


def main():
    repo, run_id, run_sha = os.environ["REPO"], os.environ["RUN_ID"], os.environ["RUN_SHA"]
    try:
        main_head = gh_json(f"repos/{repo}/commits/main")["sha"]
        runs = gh_json(f"repos/{repo}/actions/workflows/after-testflight.yml/runs?branch=main&per_page=30")["workflow_runs"]
    except (subprocess.CalledProcessError, KeyError, ValueError) as error:
        print(f"::warning::Couldn't tell whether this run is superseded, so the job runs: {error}")
        return 0
    newer = superseded(run_id, run_sha, main_head, runs)
    if newer is None:
        print(f"Not superseded: {run_sha} (main is at {main_head}).")
        return 0
    message = (f"Skipped: main moved past {run_sha} to {main_head}, and After TestFlight run {newer['id']} is waiting "
               f"to run the same checks on newer code ({newer.get('html_url', '')}).")
    print(f"::notice::{message}")
    with open(os.environ["GITHUB_ENV"], "a") as env:
        env.write("SPOONJOY_SUPERSEDED=true\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(message + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
