# Native Advisory Pipeline Evidence

Generated validation artifacts are stored under ignored local path `artifacts/apple/native-advisory-pipeline/` to keep the PR aligned with repository hygiene policy.

## Red Evidence

- `unit-16d-native-advisory-red.log`: contract failed before implementation because `security/native-advisory-pipeline.yml` was missing.

## Green Advisory Evidence

- `unit-16e-native-advisory-green.log`: advisory contract and real scan passed after implementation.
- `unit-16e-real-ruby-advisory-report.json`: real `Gemfile.lock` scan passed with zero findings and zero allowlisted advisories.
- `unit-16f-native-advisory-contract-final.log`: final advisory contract passed.
- `unit-16f-ruby-advisory-report-final.json`: final real scan passed with zero findings, zero allowlisted advisories, `bundler-audit` 0.9.3, and Ruby Advisory Database ref `32a64d01964828d2f71ba17fb623a73142e03a3d`.

## Native Validation Evidence

- `unit-16f-swift-test-green.log`: full Swift test suite passed with warnings-as-errors.
- `unit-16f-swift-test-warning-scan.log`: Swift test log warning scan passed.
- `unit-16f-coverage-test.log`: coverage run passed.
- `unit-16f-coverage-enforce.log`: `Sources/SpoonjoyCore` coverage enforced at 100.00% (26830/26830).
- `unit-16f-final-scenario.log`: native scenario verifier passed at `--stage final`.
- `unit-16f-xcodebuild-ios.log`: iOS `BootstrapDebug` app build succeeded with warnings treated as errors.
- `unit-16f-xcodebuild-macos.log`: macOS `BootstrapDebug` app build succeeded with warnings treated as errors.
- `unit-16f-security-review.md`: harsh security review approved with no blocker or major findings.

## Repository Hygiene

- `repository-hygiene.json`: repo hygiene audit manifest showing the ignored artifact root under `artifacts/apple/native-advisory-pipeline/`.
