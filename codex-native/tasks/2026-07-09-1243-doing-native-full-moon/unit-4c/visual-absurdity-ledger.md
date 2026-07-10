# Unit 4c Shopping Visual QA Ledger

## Closed

- Normal shopping receipt initially let the add-item composer dominate the first viewport; compacted the composer to one item field, one add target, and one recipe action so receipt rows lead again.
- Empty/all-complete states initially duplicated add controls above the state card; state screens now own their actions.
- Empty/all-complete/duplicate harness variants initially changed only app state while sync-store cached records restored the normal list; sync-store seeding now matches each shopping variant.
- Offline queued state duplicated the queue message through both `OfflineStatusView` and a shopping-specific label; removed the redundant label.
- Duplicate rows fit without overlap using the `2 on receipt` row metadata.
- Conflict state initially had no deterministic visual seed; screenshot auth now seeds a queued shopping mutation plus a debug-only conflict overlay, and both iOS/macOS screenshots show the review banner without crowding the receipt rows.

## Evidence

- `shopping-normal/design-review.json`
- `shopping-empty/design-review.json`
- `shopping-all-complete/design-review.json`
- `shopping-duplicate/design-review.json`
- `shopping-conflict/design-review.json`
- `shopping-offline-queued/design-review.json`
- `validate-design-reviews-final.log`
- `shopping-conflict/validate-design-review.log`
- `green-swift-test-after-conflict.log`
- `green-xcodebuild-ios-after-conflict.log`
- `green-xcodebuild-macos-after-conflict.log`
- `green-native-design-language-after-conflict.log`
- `green-native-shell-contract-after-conflict.log`
- `green-design-accessibility-contract-after-conflict.log`
- `green-native-web-palette-contract-after-conflict.log`
- `green-warning-scan-after-conflict.log`
- `green-git-diff-check-final.log`
