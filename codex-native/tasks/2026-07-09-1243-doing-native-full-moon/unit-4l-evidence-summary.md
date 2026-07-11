# Unit 4l Evidence Summary

Unit 4l adds screenshot-harness coverage for Settings signed-in profile, signed-in notifications, signed-out auth handoff, and APNs permission/registration states.

## Visual Evidence

- `unit-4l-settings-state-matrix/settings-profile/design-review.json`
- `unit-4l-settings-state-matrix/settings-notifications/design-review.json`
- `unit-4l-settings-state-matrix/settings-signed-out/design-review.json`
- `unit-4l-settings-state-matrix/settings-apns-denied/design-review.json`
- `unit-4l-settings-state-matrix/settings-apns-not-determined/design-review.json`
- `unit-4l-settings-state-matrix/settings-apns-authorized/design-review.json`
- `unit-4l-settings-state-matrix/settings-apns-unregistered/design-review.json`
- `unit-4l-settings-state-matrix/contact-sheet-ios-mobile.png`
- `unit-4l-settings-state-matrix/contact-sheet-macos-desktop.png`

## Validation

- `bash -n scripts/capture-native-screenshots.sh`
- `bash -n scripts/capture-native-screenshot-matrix.sh`
- `ruby -c scripts/validate-design-review.rb`
- `ruby -c scripts/check-launch-screenshot-contract.rb`
- `git diff --check`
- `swift test --filter SettingsAuthSurfaceContractTests`
- `ruby scripts/check-launch-screenshot-contract.rb`
- `ruby scripts/validate-design-review.rb <each Unit 4l design-review.json>`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-4l-builds/DerivedData-iOS CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-4l-builds/DerivedData-macOS GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `ruby scripts/fail-on-warning.rb --log unit-4l-ios-xcodebuild.log --log unit-4l-macos-xcodebuild.log`

## Visual QA Notes

- iPhone and macOS contact sheets were inspected manually.
- No overlapping controls or raw internal auth/APNs strings were visible.
- Signed-out Settings renders only Session, Environment, and Offline sections.
- APNs states render distinct permission and registration affordances.
