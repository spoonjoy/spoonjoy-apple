# Planning: PR #52 Merge Review Repairs

**Status**: NEEDS_REVIEW
**Created**: 2026-07-16 10:23

## Goal
Repair all five hostile-review findings from merged native PR #52 without changing the product contract: reject oversized source photos before decoding, normalize away from the main actor, contain corrupt legacy replay, make warning classification honest, and prove byte-level idempotency.

## Upstream Work Items
- Native PR #52 hostile merge-readiness review findings: three MAJOR and two MINOR.

## Scope

### In Scope
- Enforce the 25 MiB individual staging cap against original nonempty picker bytes before ImageIO work while preserving exact-boundary acceptance and prior staged media on rejection.
- Move cover decode, resize, and JPEG quality search to a Sendable non-main actor boundary used by the SwiftUI picker flow.
- Convert cover normalization failures during queued replay into retained validation conflicts so independent mutations drain and completed earlier mutations stay removed.
- Extend warning contract coverage for the exact `IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver` diagnostic without broad matching of benign test output.
- Make staged-upload equality and replay assertions include `byteCount` and `data`.
- Run focused red/green tests, full Swift tests, 100% coverage enforcement, warning scans, native scenario verification, and iOS/macOS app builds.
- Push atomic commits, open a ready PR, wait for required checks, and run a fresh hostile reviewer gate.

### Out of Scope
- Merging the repair PR.
- Publishing or dispatching TestFlight, creating release notes outside ordinary PR CI, notifying testers, expiring/removing builds, or changing App Store Connect state.
- Deleting or retiring any native worktree.
- Product/UI redesign, backend changes, or unrelated refactors.

## Completion Criteria
- [ ] Original nonempty picker payloads above 25 MiB are rejected before normalization; exactly 25 MiB remains eligible; prior staged media is preserved.
- [ ] Cover normalization invoked from SwiftUI executes through a Sendable worker actor rather than `MainActor`, with strict-concurrency compilation clean.
- [ ] Corrupt legacy cover media is retained with an actionable validation conflict, independent queue groups still drain, and a second drain does not resend prior successes.
- [ ] Warning contract recognizes the exact Apple M2 scaler diagnostic and keeps benign failure-language output clean.
- [ ] Byte-count and payload changes make `NativeStagedMediaUpload` unequal, and repeated normalization explicitly asserts byte/data identity.
- [ ] Ready GitHub PR has a fresh hostile-review verdict with no BLOCKER or MAJOR findings.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] UI layout is unchanged; visual QA is not required for actor-routing-only SwiftUI source changes.

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [x] No unresolved product decisions; the user supplied the complete repair contract and prohibited release/merge side effects.

## Decisions Made
- Use a dedicated `RecipeCoverPhotoStagingWorker` actor so immutable Sendable values cross an explicit executor boundary without detached-task lifetime or data-race hazards.
- Preserve corrupt queued media and classify normalization failure as a validation conflict; do not silently discard user media or retry unrelated completed mutations.
- Keep the warning match narrow and prove benign lines containing ordinary failure language still pass.
- Treat staged media as a full value for equality, including byte count and payload.

## Context / References
- `Sources/SpoonjoyCore/Features/Covers/RecipeCoverControlsViewModel.swift`
- `Sources/SpoonjoyCore/Features/Covers/RecipeCoverImageNormalizer.swift`
- `Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift`
- `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`
- `Tests/SpoonjoyCoreTests/CoverControlSurfaceTests.swift`
- `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift`
- `scripts/fail-on-warning.rb`
- `scripts/check-coverage-warning-contract.rb`
- `.github/workflows/native.yml`

## Notes
The local repo has no `subagents/work-planner.md` or `subagents/work-doer.md`; current installed Work Suite skills govern this task. The exact base and worktree are `e8eac40a90b47102d61dd61a9a5658e85e325ad2` and `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair`.

## Progress Log
- 2026-07-16 10:23 Created from the hostile PR #52 review.
