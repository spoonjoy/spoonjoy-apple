# Unit 1e Evidence Summary

Command:

```bash
set -o pipefail
scripts/validate-native-local.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-validation 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-validate-native-local.log
```

Result:

- `validation-matrix.json`: `result=pass`, `ok=true`, `fullyValidated=true`.
- Counts: 39 passed, 0 failed, 0 blocked, 0 blockers, 0 blocker failures.
- `matrix-route-matrix.json`: `ok=true`, `fullyValidated=true`, 10/10 routes validated.
- Route screenshot matrix produced pass rows for kitchen, recipes, recipe-detail, cook-mode, cookbooks, shopping-list, search, capture, settings, and settings-notifications.

Integration defect fixed during this unit:

- `smoke-ios-simulator.sh` now emits canonical `CoreSimulator` blockers for install/launch failures and uses hardened timeout cleanup for simulator commands.
