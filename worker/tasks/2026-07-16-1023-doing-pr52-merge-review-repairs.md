# Doing: PR #52 Merge Review Repairs

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-07-16 10:29
**Planning**: ./2026-07-16-1023-planning-pr52-merge-review-repairs.md
**Artifacts**: ./2026-07-16-1023-doing-pr52-merge-review-repairs/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts only when the user explicitly requested interactive per-unit approval; otherwise convert this to `spawn` or `direct` unless a hard exception is present
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Repair all five hostile-review findings from merged native PR #52 with strict TDD, full native validation, a ready PR, and a fresh hostile reviewer gate, without merge or release side effects.

## Upstream Work Items
- Native PR #52 hostile merge-readiness review findings: three MAJOR and two MINOR.

## Completion Criteria
- [x] Original nonempty picker payloads above 25 MiB are rejected before normalization; exactly 25 MiB remains eligible; prior staged media is preserved.
- [x] Cover normalization invoked from SwiftUI executes through a Sendable worker actor rather than `MainActor`, with strict-concurrency compilation clean.
- [x] Corrupt legacy cover media is retained with an actionable validation conflict, independent queue groups still drain, and a second drain does not resend prior successes.
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

## TDD Requirements
**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE any implementation
2. **Verify failure**: Run tests, confirm they FAIL (red)
3. **Minimal implementation**: Write just enough code to pass
4. **Verify pass**: Run tests, confirm they PASS (green)
5. **Refactor**: Clean up, keep tests green
6. **No skipping**: Never write implementation without failing test first

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ✅ Unit 0: Setup/Research
**What**: Create the pinned worktree/worker branch, inventory Apple tooling, reproduce focused baseline tests, and trace staging, normalization, queue drain, warning, and equality contracts.
**Output**: Clean worktree at exact base `e8eac40a`, source-verified repair design, and baseline focused cover suite evidence.
**Acceptance**: Branch/worktree/base verified; Xcode, Swift, and simulator runtime available; baseline cover suite passes with warnings-as-errors.

### ✅ Unit 1a: Original byte cap — Tests
**What**: Add failing tests for nonempty source bytes above 25 MiB, exact-boundary eligibility, and preservation of prior staged media.
**Output**: Red focused cover tests proving normalization currently precedes the source cap.
**Acceptance**: New assertions fail for the expected individual-file-limit mismatch.

### ✅ Unit 1b: Original byte cap — Implementation
**What**: Reject original candidate byte counts above the media policy limit before normalization.
**Output**: Minimal staging-policy fix.
**Acceptance**: Focused cover tests pass; oversized data never enters ImageIO; no warnings.

### ✅ Unit 2a: Off-main normalization — Tests
**What**: Add worker-actor behavior and SwiftUI source-contract tests requiring picker staging to await the worker boundary.
**Output**: Red tests for the absent actor and direct main-actor staging call.
**Acceptance**: Tests fail because no staging worker exists and the view calls the policy synchronously.

### ✅ Unit 2b: Off-main normalization — Implementation
**What**: Add a Sendable `RecipeCoverPhotoStagingWorker` actor and route the picker flow through it using immutable Sendable values.
**Output**: Normalization, resize, and JPEG search run on the worker actor; UI state mutation remains on `MainActor`.
**Acceptance**: Focused tests and strict-concurrency app compilation pass with no warnings or unchecked sendability.

### ✅ Unit 3a: Corrupt legacy replay — Tests
**What**: Add an end-to-end drain regression with successful mutations before and after corrupt cover media, then drain again.
**Output**: Red test proving normalization currently aborts before queue persistence.
**Acceptance**: Test fails at the normalization error and records the attempted send order.

### ✅ Unit 3b: Corrupt legacy replay — Implementation
**What**: Classify `RecipeCoverImageNormalizationError` as a retained validation conflict inside the drain loop and continue independent dependencies.
**Output**: Poison media stays queued with actionable error; successful siblings persist as drained.
**Acceptance**: First drain completes independent work; second drain attempts only corrupt media; no successful mutation is reissued.

### ⬜ Unit 4a: Warning diagnostic contract — Tests
**What**: Add script-contract fixtures for the exact Apple M2 scaler diagnostic and benign test output containing ordinary failure language.
**Output**: Red Ruby contract proving the scanner misses the exact diagnostic.
**Acceptance**: Contract fails only because the exact diagnostic is not classified.

### ⬜ Unit 4b: Warning diagnostic contract — Implementation
**What**: Add a narrowly shaped matcher for the Apple M2 scaler diagnostic without a broad plain-`failed` rule.
**Output**: Honest warning scanner behavior.
**Acceptance**: Exact diagnostic is caught, benign fixture passes, Ruby contracts and scenario contract pass.

### ⬜ Unit 5a: Payload idempotency — Tests
**What**: Add failing equality tests for changed byte count/data and explicit replay byte/data assertions.
**Output**: Red equality assertions proving metadata-only equality is insufficient.
**Acceptance**: Changed payload with identical identifiers incorrectly compares equal before implementation.

### ⬜ Unit 5b: Payload idempotency — Implementation
**What**: Include `byteCount` and `data` in staged-upload equality while retaining sidecar persistence behavior.
**Output**: Full-value equality and explicit repeated-normalization identity proof.
**Acceptance**: Focused cover/sync/persistence tests pass without weakening sidecar assertions.

### ⬜ Unit 6: Full validation, PR, and hostile gate
**What**: Run full Swift tests, coverage enforcement, warning scans, scenario verifier, iOS/macOS app builds, push all commits, open a ready PR, wait for required checks, and run a cold hostile diff review.
**Output**: Ready PR with complete validation and reviewer evidence.
**Acceptance**: 100% enforced coverage, zero unclassified warnings, all required checks green, no hostile BLOCKER/MAJOR, and no merge/TestFlight/tester/build-removal/worktree-deletion action.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **All artifacts**: Save outputs, logs, data to `./2026-07-16-1023-doing-pr52-merge-review-repairs/` directory
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-07-16 10:29 Created from the approved planning doc; Unit 0 source research is complete.
- 2026-07-16 10:32 Units 1a-1b complete: red proved nonempty oversized bytes reached normalization; green guard now rejects before ImageIO and all 23 cover tests pass.
- 2026-07-16 10:37 Units 2a-2b complete: red required an actor boundary; green routes picker normalization through a Sendable worker actor, with 24 cover tests and both app-platform builds passing.
- 2026-07-16 10:42 Units 3a-3b complete: red aborted on corrupt legacy bytes; green retains one validation conflict while independent mutations drain, and all 64 sync tests pass.
