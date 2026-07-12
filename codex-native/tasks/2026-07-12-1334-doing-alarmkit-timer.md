# AlarmKit Timer Handoff

Status: done
Execution Mode: direct
Branch: `codex-native/alarmkit-timer`
Artifacts: `codex-native/tasks/2026-07-12-1334-doing-alarmkit-timer/`

## Context

Spoonjoy cook mode had an app-owned countdown timer even though the recipe schema only carries timed-step duration metadata. The product decision is to remove the fake in-app stopwatch and use native system timers on iOS via AlarmKit, while keeping macOS honest with a platform availability cue.

## Units

- [x] Unit 1a: Add failing coverage that rejects the app-owned countdown and requires a native system timer handoff.
- [x] Unit 1b: Implement the AlarmKit handoff, correct editor duration units to API minutes, and keep cook mode compiling on iOS and macOS.
- [x] Unit 1c: Final validation, reviewer gate, commit, push, and delivery cleanup.

## Acceptance Criteria

- [x] Cook mode no longer owns a ticking countdown, pause, reset, or restart UI.
- [x] Timed recipe steps expose a native system timer handoff using AlarmKit on iOS.
- [x] Duration editor copy and bounds treat recipe step duration as API minutes.
- [x] macOS does not show an enabled system-timer button that can only fail.
- [x] iOS and macOS app targets build after the shared SwiftUI changes.
- [x] Focused cook-mode tests and mobile design source contracts pass.
- [x] A cold reviewer finds no blocker or major issue.

## Evidence

- `unit-1a-cookmode-red.log`
- `unit-1a-source-contract-red.log`
- `unit-1b-cookmode-contract.log`
- `unit-1b-cookmode-suite.log`
- `unit-1b-mobile-contract-suite-rerun.log`
- `unit-1b-xcodebuild-ios.log`
- `unit-1d-cookmode-contract.log`
- `unit-1d-cookmode-tests.log`
- `unit-1d-mobile-contract-tests.log`
- `unit-1d-recipe-editor-tests.log`
- `unit-1d-native-sync-engine-tests.log`
- `unit-1d-native-live-store-tests.log`
- `unit-1d-swift-test.log`
- `unit-1d-xcodebuild-ios-bootstrap.log`
- `unit-1d-xcodebuild-macos-arm64.log`
- `unit-1d-final-diagnostic-scan.log`

## Progress Log

- 2026-07-12 13:34 Unit 1a complete: failing tests and source contracts require system timer handoff and forbid the old in-app countdown.
- 2026-07-12 13:55 Unit 1b complete: cook mode now shows a native system timer handoff on supported iOS, keeps macOS to an honest unavailable cue, and treats step duration as API minutes.
- 2026-07-12 13:57 Unit 1c complete: focused tests, full Swift tests, iOS build, macOS build, final diagnostic scan, and round-two cold review converged.
