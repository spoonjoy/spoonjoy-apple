# Unit 1a Evidence Summary

## Baseline

Command:

```bash
ruby scripts/check-launch-screenshot-contract.rb
```

Artifact:

- `unit-1a-baseline-launch-contract.log`

Result: existing launch screenshot contract passed before adding the new timeout contract.

## Red Test

Command:

```bash
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1a-red.log
```

Result: exit 1.

The failing contract now proves:

- `scripts/capture-native-screenshot-matrix.sh` has no route-timeout contract tokens.
- a simulated hung `recipes` route leaves the matrix stuck until the external wrapper kills it.
- no terminal route row or `design-review-blocked.json` is produced for the hung route.

Relevant failure excerpt:

```text
FAIL: scripts/capture-native-screenshot-matrix.sh missing required tokens: SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS, timeoutSeconds, ScreenshotRouteTimeout, ownerAction, sourceBlockerPath
FAIL: screenshot matrix route timeout expected terminal blocker artifact, but matrix process timed out
STDOUT:
capturing native route kitchen (kitchen)
capturing native route recipes (recipes)
```

## Next

Unit 1b must add deterministic per-route timeout handling to the matrix script so this red test goes green and a hung route produces a route-level blocker artifact.
