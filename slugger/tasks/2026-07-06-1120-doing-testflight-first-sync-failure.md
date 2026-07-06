# Doing: TestFlight First Sync Failure

**Status**: doing
**Planning**: `slugger/tasks/2026-07-06-1120-planning-testflight-first-sync-failure.md`

## Unit 1: Current Feedback Evidence
- [x] Inspect current App Store Connect feedback detail and screenshot.
- [x] Record current feedback comment, device, OS, support code, and Settings-button report without printing secrets or signed URLs.
- [x] Run a production native dogfood probe against the likely current account with an ephemeral credential.
- [x] Save only redacted probe evidence and revoke the temporary credential.

## Unit 2: Sync-Failed Settings Escape
- [x] Reproduce the source-level failure: `.syncFailed` with no kitchen content ignores `navigation.route == .settings`.
- [x] Patch `SpoonjoyRootView` so Settings renders from no-content sync failure.
- [x] Reuse the existing Settings view wiring to avoid divergent behavior from signed-out setup.
- [x] Add source/scenario verifier coverage for the route escape.

## Unit 3: Validation
- [x] Run focused source-contract regression checks.
- [x] Run the native scenario verifier.
- [x] Run visual QA for the changed error/settings surface.
- [x] Build and export the iOS TestFlight IPA.

## Unit 4: Internal TestFlight
- [x] Bump the internal build number if needed.
- [ ] Upload an internal-only TestFlight build.
- [ ] Verify the build is attached to `Spoonjoy Internal`.

## Evidence
- Current feedback event: `AN7XCNQQQkfp-C9BiM8TcX4`.
- Screenshot support code: `req_bcbc4434-da01-415e-b1e6-0489bf54d4e7`.
- Redacted current-account dogfood: `slugger/tasks/2026-07-06-1120-doing-testflight-first-sync-failure/ari-production-native-dogfood-redacted.json`.
- Visual QA: `slugger/tasks/2026-07-06-1120-doing-testflight-first-sync-failure/visual-qa/design-review.json`.
- Exported IPA: `build/apple/testflight/Spoonjoy.ipa`, version `1.0`, build `10`.

## Notes
- The live current-account dogfood succeeded through native sync drain and settings fetch, so no backend or sync-engine code change is justified by current evidence.
- The Settings button failure is deterministic in the native root shell and is fixed native-side.
- Focused Swift test compilation was taken over after a stuck background worker; local gates for this patch are source-contract, scenario verifier, visual QA, and TestFlight archive/export. GitHub CI still runs the full Swift test suite before merge.
