# Unit 1d Evidence Summary

Command:

```bash
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1d-launch-contract.log
```

Result: `launch screenshot contract ok`.

Fix summary:

- Added bounded `run_with_timeout` execution for simulator launch and macOS launch/open-route commands.
- Added cleanup timeout wrappers for macOS quit/kill before capture, before relaunch, and after capture.
- Added explicit `proof wait timed out` diagnostics for screenshot and accessibility proof waits.
- Preserved the existing design-review blocker schema so failed launches still emit terminal artifacts instead of hanging.
