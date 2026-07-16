# Native Cover Image Normalization N2 Evidence

Generated validation artifacts live under ignored local path `artifacts/apple/native-cover-normalization-n2/`.

## Red Evidence

- `artifacts/apple/native-cover-normalization-n2/unit-4a-cover-red.log`: focused `swift test --filter CoverControlSurfaceTests --disable-xctest -Xswiftc -warnings-as-errors` compiled, then failed because current staging/transport still preserves source HEIC/WebP/PNG MIME, filename, dimensions, and bytes instead of normalized JPEG.

## Green Evidence

- `artifacts/apple/native-cover-normalization-n2/unit-4b-cover-green.log`: focused `swift test --filter CoverControlSurfaceTests --disable-xctest -Xswiftc -warnings-as-errors` passed after the ImageIO normalizer routed staging, immediate upload, durable staging, and queued replay through JPEG normalization.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-cover-warning-scan.log`: warning scan over the focused cover test log passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-swift-build.log`: `swift build -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4b-build-warning-scan.log`: warning scan over the focused Swift build log passed.

## Final Validation Evidence

- `artifacts/apple/native-cover-normalization-n2/unit-4c-cover-focused.log`: `swift test --filter CoverControlSurfaceTests --disable-xctest -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-sync-focused.log`: `swift test --filter NativeSyncEngineTests --disable-xctest -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-api-focused.log`: `swift test --filter NativeAPIExpansionTests --disable-xctest -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-cache-focused.log`: `swift test --filter NativeCacheFreshnessTests --disable-xctest -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-live-store-focused.log`: `swift test --filter NativeLiveStoreTests --disable-xctest -Xswiftc -warnings-as-errors` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-cover-coverage-focused.log`: focused cover rerun for rejection-path coverage passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-swift-coverage-test.log`: `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors` passed with 602 tests in 53 suites.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-coverage-enforce.log`: `scripts/enforce-swift-coverage.rb --minimum 100 --include Sources/SpoonjoyCore` passed at `100.00% (26931/26931)`.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-final-scenario.log` and `.json`: `scripts/verify-native-scenarios.sh --stage final` passed.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-xcodebuild-ios.log`: `xcodebuild` `Spoonjoy iOS` `BootstrapDebug` generic iOS Simulator build passed with signing disabled.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-xcodebuild-macos.log`: `xcodebuild` `Spoonjoy macOS` `BootstrapDebug` generic macOS build passed with signing disabled.
- `artifacts/apple/native-cover-normalization-n2/unit-4c-*-warning-scan.log`: warning scans passed for focused tests, coverage, scenario verifier, and app builds.

## Reviewer Disposition

- PASS. Slugger performed a fresh harsh implementation/native review of `worker/native-cover-normalization-n2` against `origin/main` and found no blockers.
