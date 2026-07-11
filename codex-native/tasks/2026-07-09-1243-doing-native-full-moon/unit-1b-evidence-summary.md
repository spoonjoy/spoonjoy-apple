# Unit 1b Evidence Summary

## Implementation

Updated `scripts/capture-native-screenshot-matrix.sh` to add deterministic route-level timeout handling.

New behavior:

- `SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS` controls per-route capture timeout.
- each route writes its combined capture output to `apple/<route-slug>-screenshot-route.log`.
- a route timeout writes `apple/<route-slug>-screenshot-route-timeout-blocker.json`.
- a route timeout writes `design-review-blocked.json` with capability `ScreenshotRouteTimeout`, `timeoutSeconds`, `sourceBlockerPath`, `ownerAction`, and skipped success artifacts.
- the route row is recorded as `blocked`.
- the matrix continues to later routes and summarizes terminal state instead of hanging.

## Validation

Commands:

```bash
bash -n scripts/capture-native-screenshot-matrix.sh scripts/capture-native-screenshots.sh
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1b-launch-contract-green.log
```

Artifacts:

- `unit-1b-syntax.log`
- `unit-1b-launch-contract-green.log`

Results:

- syntax ok
- launch screenshot contract ok

The Unit 1a red failure is now green: the contract fixture's hung `recipes` route no longer hangs the matrix process and must produce a terminal `ScreenshotRouteTimeout` blocker row.
