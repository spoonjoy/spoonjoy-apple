# Unit 1c Evidence Summary

Command:

```bash
set -o pipefail
ruby scripts/check-launch-screenshot-contract.rb 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1c-red.log
```

Result: expected red.

Intentional failures:

- `scripts/capture-native-screenshots.sh` is missing launch/cleanup timeout controls: `SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS`, `SPOONJOY_SCREENSHOT_MACOS_LAUNCH_TIMEOUT_SECONDS`, and `SPOONJOY_SCREENSHOT_CLEANUP_TIMEOUT_SECONDS`.
- A stubbed hung `xcrun simctl launch` times out the capture process instead of producing a `CoreSimulator` blocker.
- A stubbed hung macOS cleanup command times out the capture process instead of producing a terminal design-review artifact and logging `cleanup timeout`.

The paired implementation unit is Unit 1d.
