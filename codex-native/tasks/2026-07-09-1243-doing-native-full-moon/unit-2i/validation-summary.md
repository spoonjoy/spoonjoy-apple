# Unit 2i Validation Summary

## Source Contracts

- `python3 -m py_compile .github/scripts/resolve-ios-simulator-destination.py`
- `swift test`
- `swift test --filter NativeMobileDesignContractTests`
- `swift test --filter NotificationAPNsSurfaceTests`
- `swift test --filter NativeLiveStoreTests`
- `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors`
- `ruby scripts/fail-on-warning.rb --log codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/apple/unit-2i-final-after-focus-coverage-test.log`
- `swift test --show-codecov-path`
- `ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include Sources/SpoonjoyCore`
- `ruby scripts/check-native-image-policy-contract.rb`
- `ruby scripts/check-notification-apns-surfaces.rb`
- `ruby scripts/check-design-accessibility-contract.rb`
- `ruby scripts/check-native-web-palette-contract.rb`
- `ruby scripts/check-native-design-language.rb`
- `ruby scripts/check-native-loading-transition-contract.rb`
- `ruby scripts/check-native-shell-contract.rb`
- `ruby scripts/check-native-sharing-surfaces.rb`
- `ruby scripts/check-native-justification.rb`
- `ruby scripts/check-launch-screenshot-contract.rb`
- `swift test --filter NativeMobileDesignContractTests`
- `ruby scripts/check-native-image-policy-contract.rb && ruby scripts/check-native-design-language.rb && ruby scripts/check-design-accessibility-contract.rb`
- `ruby scripts/check-native-final-matrix-contract.rb`
- `ruby scripts/validate-design-review.rb codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/final-clean-route-matrix/screenshot-routes/settings-notifications/design-review.json`
- `ruby scripts/fail-on-warning.rb --log .../unit-2i/*after-no-photo-callsite-fix*.log`

## App Builds

- `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/final-build-ios-after-no-photo-callsite-fix-derived CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/final-build-macos-after-no-photo-callsite-fix-derived GCC_TREAT_WARNINGS_AS_ERRORS=YES build`

## Visual Evidence

- Fresh simulator smoke: `SPOONJOY_IOS_SIMULATOR_UDID=985A934A-AA77-4548-A549-0B3892099E34 SPOONJOY_SMOKE_TIMEOUT_SECONDS=120 scripts/smoke-ios-simulator.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/fresh-ios-smoke --unit-slug unit-2i-fresh-ios-smoke`
- Fresh full matrix: `SPOONJOY_IOS_SIMULATOR_UDID=985A934A-AA77-4548-A549-0B3892099E34 SPOONJOY_SMOKE_TIMEOUT_SECONDS=120 SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS=420 SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS=120 SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS=90 SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS=0.5 scripts/capture-native-screenshot-matrix.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2i/final-clean-route-matrix --unit-slug unit-2i-final-clean-route-matrix`
- Matrix summary: `unit-2i/final-clean-route-matrix/apple/unit-2i-final-clean-route-matrix-route-matrix.json`
- iOS contact sheet: `unit-2i/final-visual-summary/ios-contact-sheet.png`
- macOS contact sheet: `unit-2i/final-visual-summary/macos-contact-sheet.png`

## Results

- Full Swift suite: 544 tests in 46 suites passed.
- Focused mobile design suite: 20 tests passed.
- Coverage: 100.00% for `Sources/SpoonjoyCore` (`25970/25970`).
- iOS app build: succeeded with warnings as errors.
- macOS app build: succeeded with warnings as errors.
- Fresh final-source full route matrix: 11/11 routes passed; `failedRoutes`, `blockedRoutes`, and `missingDesignReviewRoutes` were empty at `2026-07-10T06:53:01Z`.
- Visual review: inspected fresh iOS/macOS contact sheets and targeted Settings Notifications, Cook Mode, and Cookbook Detail screenshots.
- Simulator resolver: explicit nonstandard dedicated simulator UDID and default iPhone selection are contract-covered.
- Cold reviewer gate: Sagan returned two MINOR findings; both were fixed, stale legacy no-photo call sites were normalized, and final-source focused contracts, app builds, warning scan, and fresh matrix passed.
