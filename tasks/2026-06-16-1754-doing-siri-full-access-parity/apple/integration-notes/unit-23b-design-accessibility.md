# Unit 23b - Native Design Accessibility Validation

## Changes

- Extended `design-review.json` with `accessibilityProofArtifacts` for iOS and macOS.
- Added strict validation for per-platform accessibility proof JSON:
  - Dynamic Type
  - VoiceOver labels
  - keyboard navigation
  - reduce motion
  - contrast
  - Kitchen Table hierarchy
  - no overlap
  - 44 pt minimum targets
  - text-fit and no-tiny-cluster checks
  - `offlineIndicatorProof` for visible, dismissible, severe, and hidden Offline Product Contract states
- Expanded `design-review-blocked.json` so screenshot blockers also skip and clean iOS/macOS accessibility proof artifacts.
- Added DEBUG-only native accessibility proof writing from the active route and updated screenshot capture to require app-emitted proof artifacts on successful capture.
- Huygens review found the first pass fabricated proof inside the harness; the final contract rejects harness-only proof by requiring `emittedBy: "SpoonjoyApp"` and the platform bundle identifier, and passes an absolute proof path into the macOS app.
- Updated the native local matrix direct XcodePlatform blocker path to name and clean accessibility proof artifacts.
- Updated `docs/native-design-language.md` with the stricter manifest and offline indicator proof contract.

## Validation

- `apple/unit-23b-design-accessibility-contract.log`
- `apple/unit-23b-launch-screenshot-contract.log`
- `apple/unit-23b-design-screenshots.log`
- `apple/unit-23b-design-review-validation.log`
- `apple/unit-23b-native-design-contract.log`
- `apple/unit-23b-project-contract.log`
- `apple/unit-23b-xcode-generator-contract.log`
- `apple/unit-23b-xcodebuild-macos.log`
- `apple/unit-23b-diff-check.log`
- `apple/unit-23b-warning-scan.log`

Real screenshot capture produced `design-review.json`, refreshed `screenshots/ios-mobile.png` and `screenshots/macos-desktop.png`, and emitted `apple/unit-23b-design-accessibility-proof-ios.json` plus `apple/unit-23b-design-accessibility-proof-macos.json` from the running app.
