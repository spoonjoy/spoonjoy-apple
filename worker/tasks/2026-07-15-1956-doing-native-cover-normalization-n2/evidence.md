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

## Host-Rollover Remediation

- GitHub run `29469189040`, attempt 2, records `The run was canceled by @arimendelow.` for the workflow, Swift tests, and Coverage. The workflow has no `timeout-minutes` or `cancel-in-progress` rule. Attempt 1 was also manually cancelled after 32 minutes; attempt 2 was cancelled after 21 minutes. The cancellations occurred while the branch-specific test process was still running, rather than from a failed assertion.
- A compliant JPEG crossed normalization at selection, mutation planning, and queued replay. Before remediation, the focused repeated-safety-check regression failed because the bytes changed and took 10.736 seconds. The source-type/size/dimension/orientation-gated fast path now preserves those bytes and the same regression passes in 0.069 seconds.
- The fast path verifies the decoded source type is `public.jpeg`; a PNG labeled `image/jpeg` is still transcoded. Oriented JPEGs are still transformed, oversized images are still bounded, and `image/jpg` is canonicalized without recompression.
- A dedicated adaptive-quality test proves a lower JPEG quality candidate is selected only after the higher candidate exceeds the configured byte limit. Contract-equivalent fixture dimensions retain explicit 2048 px and source-over-5-MiB assertions while reducing full-suite contention.

## Rerun Validation Evidence

- `unit-4c-cover-focused-rerun.log`: 22 focused cover tests passed in 1.057 seconds under `--parallel`; warning scan passed.
- `unit-4c-swift-tests-rerun.log`: exact CI Swift test command passed 604 tests in 53 suites; the heaviest cover boundary test completed in 9.170 seconds and the warning scan passed.
- `unit-4c-swift-coverage-rerun.log` and `unit-4c-coverage-enforce-rerun.log`: 604 tests passed and SpoonjoyCore coverage is `100.00% (26961/26961)`; warning scan passed.
- `unit-4c-final-scenario-rerun.log`: final native scenario verification passed; warning scan passed.
- `unit-4c-xcodebuild-ios-rerun.log` and `unit-4c-xcodebuild-macos-rerun.log`: BootstrapDebug app-target builds passed with signing disabled; both warning scans passed.
- Final post-remediation harsh review and fresh PR CI are required before the final merge-readiness disposition.

## Post-Remediation Reviewer Disposition

- PASS. The final harsh review re-read the actual uncommitted `RecipeCoverImageNormalizer.swift` fast path plus the full PR diff, verified the decoded-type, size, dimension, orientation, adaptive-quality, immediate-upload, durable-staging, and replay contracts, and found no blockers. The reviewer corrected its initial stale bookkeeping statement before convergence.
- Fresh PR CI remains the only outstanding merge-readiness gate. Do not merge or publish TestFlight from this unit.
