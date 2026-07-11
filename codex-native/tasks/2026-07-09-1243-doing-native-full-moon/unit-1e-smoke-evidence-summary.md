# Unit 1e Smoke Integration Evidence

Red command:

```bash
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-smoke-red.log
```

Red result: iOS smoke launch failure and all-attempts timeout returned naked failures without a `CoreSimulator` blocker.

Green command:

```bash
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-smoke-contract.log
```

Green result: `launch screenshot contract ok`.

Fix summary:

- `smoke-ios-simulator.sh` now writes canonical `CoreSimulator` blockers for install and launch failures/timeouts.
- Stale simulator uninstall is bounded through the existing smoke timeout wrapper and logged before continuing.
- The smoke timeout wrapper now uses TERM/KILL process-group cleanup so post-timeout launch registration checks cannot hang.
