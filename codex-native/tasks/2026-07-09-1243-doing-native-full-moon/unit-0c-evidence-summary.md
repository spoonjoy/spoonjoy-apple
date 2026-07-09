# Unit 0c Evidence Summary

## Command

Baseline capture was attempted from `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon`:

```bash
ruby -rtimeout -e '<timeout wrapper>' 900 scripts/capture-native-screenshot-matrix.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-0c-baseline-screenshots --unit-slug unit-0c 2>&1 | tee codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-0c-baseline-capture.log
```

The pipeline masked the nonzero timeout because `tee` was the last command. The log still records the timeout and failed process-group kill:

- `unit-0c-baseline-capture.log`
- `baseline capture timed out after 900s`
- `Process.kill("KILL", -pid)` raised `Operation not permitted`

No lingering `capture-native`, `xcodebuild`, `simctl`, or Spoonjoy screenshot processes remained after inspection.

## Matrix Result

The partial route matrix is saved at:

- `unit-0c-baseline-screenshots/apple/unit-0c-route-matrix.jsonl`
- `unit-0c-failure-snippets.md`

Observed route statuses:

- `pass`: `recipes`, `recipe-detail`, `cook-mode`, `cookbooks`, `search`
- `fail`: `kitchen`, `shopping-list`
- no terminal row: `capture`, because the outer wrapper timed out while the per-route capture was still running macOS launch smoke

The five passing routes each emitted:

- `screenshots/ios-mobile.png`
- `screenshots/macos-desktop.png`
- `design-review.json`
- iOS and macOS accessibility proof JSON

The failed `kitchen` and `shopping-list` routes did not emit screenshots, `design-review.json`, or `design-review-blocked.json`. The `shopping-list` failure snippet shows the iOS build succeeded, then `simctl install` timed out after 30 seconds. This is a harness defect, not a valid external blocker.

The `capture` failure snippet shows iOS launch smoke succeeded, then macOS launch smoke was interrupted by the 900 second outer timeout. It also did not emit a terminal design review or blocker artifact.

Generated `DerivedData-*` directories, full Xcode smoke logs, and launch environment backups were removed from the committed evidence directory. Route matrix rows, concise inner logs, failure snippets, screenshots, design reviews, and accessibility proofs remain.

## Manual Pixel Inspection

I inspected the captured iOS screenshots for:

- `recipes`
- `recipe-detail`
- `cook-mode`
- `search`

Findings were added to `absurdity-ledger.md`. The automated design reviews report no basic overlap for the five passing routes, but visual inspection still found taste and shell issues that the automated checks should not paper over.

## Unit 1 Inputs

Unit 1 must fix the harness before UI work continues:

- per-route timeouts must produce terminal route rows
- launch/install/proof waits must emit valid `design-review-blocked.json` when they fail
- the matrix wrapper must preserve nonzero exit status through `tee`
- generated build cache must not live in committed screenshot evidence
- `kitchen`, `shopping-list`, and `capture` need fresh capture evidence after the harness fix
