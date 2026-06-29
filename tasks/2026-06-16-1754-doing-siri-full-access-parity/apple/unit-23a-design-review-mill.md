# Unit 23a Design Red Contract Review - Mill

Mill found two major gaps in the first red contract:

- The expanded `design-review-blocked.json` schema was not enforced consistently because the red contract lacked a negative fixture for the old skipped-artifact set, and `scripts/validate-native-local.sh` did not yet name accessibility proof artifacts on its direct XcodePlatform screenshot-blocker path.
- The stale blocker cleanup test only created stale `design-review.json` and screenshot PNGs, not stale accessibility proof artifacts.

Both findings were addressed before commit:

- `scripts/check-design-accessibility-contract.rb` now requires `apple/matrix-accessibility-proof-ios.json` and `apple/matrix-accessibility-proof-macos.json` tokens in `scripts/validate-native-local.sh`.
- The red contract now includes an `old-skipped-artifacts-design-review-blocked.json` negative fixture proving the old skipped-artifact set must fail.
- The stale success-artifact blocker test now creates stale iOS/macOS accessibility proof files as well as stale screenshot/design-review artifacts.

Refreshed red evidence is `apple/unit-23a-design-red.log`, ending `expected red status: 1`.
