# Unit 23c - Native Design Accessibility Validation Matrix

## Changes

- Refactored `ScreenshotAccessibilityProofWriter` to accept observed SwiftUI runtime context from Kitchen, Search, and Settings.
- Added `observedDynamicTypeSize`, `observedReduceMotion`, and route-specific `routeEvidence` to app-emitted accessibility proofs.
- Tightened `scripts/validate-design-review.rb` and `scripts/capture-native-screenshots.sh` so missing or malformed observed route evidence fails validation.
- Updated design/accessibility and launch screenshot contracts, fake capture launchers, repository proof fixtures, and native local validation harness coverage.
- Documented the stronger proof contract in `docs/native-design-language.md`.

## Validation

- `apple/unit-23c-design-accessibility-contract.log`
- `apple/unit-23c-design-native-design-contract.log`
- `apple/unit-23c-design-scenario-final.log`
- `apple/unit-23c-design-project-contract.log`
- `apple/unit-23c-design-swift-full.log`
- `apple/unit-23c-design-xcodebuild-ios.log`
- `apple/unit-23c-design-xcodebuild-macos.log`
- `apple/unit-23c-design-smoke-ios.log`
- `apple/unit-23c-design-smoke-macos.log`
- `apple/unit-23c-design-screenshots.log`
- `apple/unit-23c-design-design-review.log`
- `apple/unit-23c-design-launch-screenshot-contract.log`
- `apple/unit-23c-design-warning-scan.log`

Real capture produced `design-review.json`, refreshed iOS/macOS screenshots, and emitted `apple/unit-23c-design-accessibility-proof-ios.json` plus `apple/unit-23c-design-accessibility-proof-macos.json` from the running app with observed route evidence.
