# Unit 23b Design Accessibility Review - Huygens

## Finding

Huygens returned a P1/Major finding: the first Unit 23b implementation let `scripts/capture-native-screenshots.sh` fabricate `accessibilityProofArtifacts`, so the artifacts did not prove that the running iOS/macOS app exposed the required design/accessibility state.

## Resolution

- Added `ScreenshotAccessibilityProofWriter` and DEBUG-only calls from `KitchenView`, `SearchView`, and `SettingsView`.
- Moved `offlineIndicatorProof` derivation into `OfflineStatusView` so the proof is tied to the production component state model.
- Updated screenshot capture to pass `SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH` into the running apps, wait for the app-emitted proof, normalize it, and reject missing/malformed proofs.
- Required `emittedBy: "SpoonjoyApp"` and the expected platform bundle identifier in both the validator and contract fixtures.
- Passed an absolute macOS proof path to the app so `open --env` cannot resolve the artifact relative to an unexpected working directory.

## Closure Evidence

- `apple/unit-23b-design-accessibility-contract.log`
- `apple/unit-23b-launch-screenshot-contract.log`
- `apple/unit-23b-design-screenshots.log`
- `apple/unit-23b-design-review-validation.log`
- `apple/unit-23b-native-design-contract.log`
- `apple/unit-23b-project-contract.log`
- `apple/unit-23b-xcode-generator-contract.log`
- `apple/unit-23b-xcodebuild-macos.log`
- `apple/unit-23b-warning-scan.log`

The regenerated proof artifacts report `emittedBy: "SpoonjoyApp"` with `app.spoonjoy.Spoonjoy` on iOS and `app.spoonjoy.Spoonjoy.mac` on macOS.
