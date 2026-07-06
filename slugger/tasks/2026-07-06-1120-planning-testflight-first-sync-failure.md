# Planning: TestFlight First Sync Failure

**Status**: drafting
**Created**: 2026-07-06 11:20

## Goal
Resolve the TestFlight feedback report where a signed-in Spoonjoy iOS beta user reaches "We couldn't load your kitchen" during the first sync. Use event telemetry and production/native probes to identify the failing path, add focused regression coverage and telemetry, and publish an internal TestFlight build when code changes are needed.

## Upstream Work Items
- TestFlight feedback `AAhVlDHCsZ1JQMRxuXuvn1A`
- App Store Connect event type `betaFeedbackScreenshotSubmissionCreated`
- Event directory: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-06T18-12-51-927Z-AAhVlDHCsZ1JQMRxuXuvn1A`

## Scope

### In Scope
- Inspect the feedback detail JSON, screenshot, webhook/autopilot artifacts, and local app/backend code paths without printing secrets, bearer material, signed screenshot URLs, private key contents, or API key paths.
- Reproduce or classify the production `/api/v1/me/sync` first-sync behavior with a safe authenticated smoke path or local equivalent when live credentials are unavailable.
- Patch the native bootstrap/sync path or backend sync endpoint when evidence identifies an actionable code-owned bug.
- Add focused Swift and/or backend tests for the failure mode, including request/response assertions for any adapter-path changes.
- Add missing native telemetry for the bootstrap failure path without logging sensitive token material.
- Run focused and release-relevant validation, then build/upload/publish an internal TestFlight build only if app code changes.
- Verify the uploaded build is attached to `Spoonjoy Internal`.

### Out of Scope
- Public App Store submission or external beta release.
- Broad native app redesign, new onboarding UX, or unrelated sync architecture refactors.
- Printing, committing, or persisting secrets, JWTs, private keys, API key paths, signed screenshot URLs, or bearer tokens.
- Manual account/provider actions unless a human-only credential or account capability is the proven blocker.

## Completion Criteria
- [ ] The feedback artifacts are inspected and summarized without exposing sensitive fields.
- [ ] Production/native first-sync behavior is reproduced or classified with saved redacted evidence.
- [ ] The identified code-owned failure path is covered by a failing regression test before implementation.
- [ ] The fix passes the regression test and relevant existing native/backend tests.
- [ ] Bootstrap failure telemetry is present for the resolved path and excludes sensitive token material.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass
- [ ] If native app code changes, an internal-only TestFlight build is uploaded and verified in `Spoonjoy Internal`.

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [ ] Does a real production native sync response currently fail because of envelope shape, pagination, auth scope, backend status, or native cache application?
- [ ] Is the final fix native-only, backend-only, or both?
- [ ] Does publishing require a new build number beyond the current internal build already attached to Spoonjoy Internal?

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
- Detail JSON records device `iPhone14_4`, iOS `26.5`, locale `en-US`, connection `WIFI`, app uptime `19000` ms, and feedback comment "still doesn’t work ".

## Notes
Prior evidence has already ruled out a completely missing production endpoint: unauthenticated `/api/v1/me/sync` returns authentication required, and invalid native Apple sign-in input reaches the deployed native endpoint. A previous settings-cache token-scope fix exists, so this incident needs a fresh discriminating probe instead of assuming the old cause.

## Progress Log
- 2026-07-06 11:20 Created
