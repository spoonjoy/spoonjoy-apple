# Planning: TestFlight First Sync Failure

**Status**: doing
**Created**: 2026-07-06 11:22

## Goal
Resolve the TestFlight feedback report where a signed-in Spoonjoy iOS beta user reaches "We couldn't load your kitchen" during the first sync. Use event telemetry and production/native probes to identify the failing path, add focused regression coverage and telemetry, and publish an internal TestFlight build when code changes are needed.

## Upstream Work Items
- TestFlight feedback `AAhVlDHCsZ1JQMRxuXuvn1A`
- TestFlight feedback `AN7XCNQQQkfp-C9BiM8TcX4`
- App Store Connect event type `betaFeedbackScreenshotSubmissionCreated`
- Event directory: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-06T18-12-51-927Z-AAhVlDHCsZ1JQMRxuXuvn1A`
- Event directory: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-06T22-08-05-847Z-AN7XCNQQQkfp-C9BiM8TcX4`

## Scope

### In Scope
- Inspect the feedback detail JSON, screenshot, webhook/autopilot artifacts, and local app/backend code paths without printing secrets, bearer material, signed screenshot URLs, private key contents, or API key paths.
- Reproduce or classify the production `/api/v1/me/sync` first-sync behavior with a safe authenticated smoke path or local equivalent when live credentials are unavailable.
- Patch the native bootstrap/sync path or backend sync endpoint when evidence identifies an actionable code-owned bug.
- Add focused Swift and/or backend tests for the failure mode, including request/response assertions for any adapter-path changes.
- Add missing native telemetry for the uninstrumented `NativeLiveAppStore.bootstrap()` catch path without logging sensitive token material; keep existing `NativeSyncEngine` bootstrap telemetry intact.
- Run focused and release-relevant validation, including Swift tests, native scenario verifier, app bundle build, coverage, simulator validation, and screenshot review when applicable; record any unavailable check with its concrete blocker.
- If evidence proves no code-owned bug, an account/provider-only blocker, or a deployment/environment issue outside the repo, produce a compact blocker or no-code report with the redacted evidence and required owner action.
- Build/upload/publish an internal TestFlight build only if app code changes.
- Verify the uploaded build is attached to `Spoonjoy Internal`.

### Out of Scope
- Public App Store submission or external beta release.
- Broad native app redesign, new onboarding UX, or unrelated sync architecture refactors.
- Printing, committing, or persisting secrets, JWTs, private keys, API key paths, signed screenshot URLs, or bearer tokens.
- Manual account/provider actions unless a human-only credential or account capability is the proven blocker.

## Completion Criteria
- [ ] The feedback artifacts are inspected and summarized without exposing sensitive fields.
- [ ] Production/native first-sync behavior is reproduced or classified with saved redacted evidence.
- [ ] If a code-owned failure is identified, it is covered by a failing regression test before implementation.
- [ ] If a code-owned fix is made, it passes the regression test and relevant existing native/backend tests.
- [ ] If no code-owned fix is made, the terminal report names the proven non-code cause, blocker, or residual unknown with redacted evidence.
- [ ] `NativeLiveAppStore.bootstrap()` catch-path telemetry is present for the resolved path and excludes sensitive token material.
- [ ] 100% test coverage on all new code
- [ ] Focused Swift tests pass.
- [ ] Native scenario verifier passes, or the concrete blocker is recorded.
- [ ] iOS app bundle build passes with no warnings, or the concrete blocker is recorded.
- [ ] Coverage for new code is recorded.
- [ ] Simulator validation passes for the changed behavior, or the concrete blocker is recorded.
- [ ] All tests pass, or any unrun suite has a concrete blocker.
- [ ] No warnings in the checks run.
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass
- [ ] If native app code changes, an internal-only TestFlight build is uploaded and verified in `Spoonjoy Internal`.

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [x] Does a real production native sync response currently fail because of envelope shape, pagination, auth scope, backend status, or native cache application?
- [x] Is the final fix native-only, backend-only, or both?
- [x] Does publishing require a new build number beyond the current internal build already attached to Spoonjoy Internal?

## Decisions Made
- Work on the existing agent-scoped branch `slugger/testflight-native-publish` because it is already the dedicated TestFlight publishing branch for this incident stream.
- Keep existing dirty changes in `docs/apple-distribution.md` and `scripts/testflight-feedback-autopilot.mjs` out of this incident unless they become directly required.
- Treat the screenshot state as a signed-in first-sync failure, not a signed-out/authentication onboarding issue.

## Context / References
- Native error surface: `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- Native sync engine: `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`
- Native API request builders: `Sources/SpoonjoyCore/API/NativeAPIRequests.swift`
- Native regression tests: `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift`, `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift`, `Tests/SpoonjoyCoreTests/APITransportTests.swift`
- Backend repo as needed: `/Users/arimendelow/Projects/spoonjoy-v2`
- Screenshot shows "We couldn't load your kitchen", "Try Again", and "Sync could not finish".
- Detail JSON records device `iPhone14_4`, iOS `26.5`, locale `en-US`, `connectionType` `WIFI`, app uptime `19000` ms, and feedback comment "still doesn’t work ".
- Current detail JSON records device `iPhone14_4`, iOS `26.5`, locale `en-US`, `connectionType` `WIFI`, app uptime `17000` ms, and feedback comment "still not working, and yes i made sure im on latest, and settings button doesn’t work either. cmon man "
- Redacted production/native sync probe artifact: `./2026-07-06-1120-doing-testflight-first-sync-failure/production-native-sync-probe.json`
- Redacted current-account native dogfood artifact: `./2026-07-06-1120-doing-testflight-first-sync-failure/ari-production-native-dogfood-redacted.json`
- Native sync endpoint reachability probes are recorded in the session transcript and should be re-run or replaced with a saved redacted artifact if needed for final evidence.

## Notes
Current redacted live evidence shows a disposable production account can create a native-scope token and receive a valid `/api/v1/me/sync?limit=20` envelope with entries. That rules out a globally missing native sync endpoint, but not an account-specific, transient, cache-application, or app bootstrap fallback failure. A previous settings-cache token-scope fix exists, so this incident needs a fresh discriminating fix instead of assuming the old cause.

Current-account live evidence for likely Ari account now shows the production native Swift sync engine can bootstrap and drain `/api/v1/me/sync`, cache `72` records, fetch settings, and expose token management with a revoked temporary credential. That classifies the repeated screenshot as unreproduced on the sync transport/settings path at investigation time. The current screenshot also identifies an independently code-owned native shell bug: the no-content `.syncFailed` root never renders `SettingsView` after the Settings button changes navigation route.

## Progress Log
- 2026-07-06 11:22 Created
- 2026-07-06 11:27 Addressed Round 1 planning findings: added no-code terminal path, named `NativeLiveAppStore.bootstrap()` telemetry, pinned validation, and cited redacted probe evidence.
- 2026-07-06 16:05 Added current feedback recurrence, current-account native dogfood evidence, and scoped the code-owned fix to the sync-failed Settings escape hatch.
