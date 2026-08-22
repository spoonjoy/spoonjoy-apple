# Doing: Native Shopping List Experience Repair

**Status**: drafting
**Execution Mode**: direct
**Created**: 2026-08-21 17:44
**Planning**: ./2026-08-21-1735-planning-native-shopping-list-experience-repair.md
**Artifacts**: ./2026-08-21-1735-doing-native-shopping-list-experience-repair/

## Execution Mode

- **direct**: Execute units sequentially in this dedicated worker task; use fresh sub-agent reviewer/fixer gates after substantive units.

## Objective
Make ordinary shopping-list mutations immediate and localized, and redesign the native shopping surface to preserve the web product's Need/Basket/All, category, and ruled-receipt language through native iOS, iPadOS, and macOS mechanics.

## Upstream Work Items
- `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/task.md`

## Completion Criteria
- [ ] Shopping checkoff, uncheck, add, delete, clear-checked, and clear-all never publish `.restoringCache` or replace the app shell.
- [ ] Online mutations are serialized, optimistically rebase on the latest store state, reconcile only shopping-list state after successful remote writes, and ignore stale reconciliation responses; offline/already-queued/fallback mutations retain FIFO with exactly one optimistic application.
- [ ] A definite non-offline mutation failure rolls back when no later mutation exists; otherwise a targeted read reconciles without clobbering newer state. Indeterminate reconciliation failure retains the optimistic row with a row/action retry error and never triggers root bootstrap.
- [ ] Need/Basket/All counts and category filters match the current web route's product semantics across active, completed, empty, all-complete, duplicate, queued, conflict, and failure states.
- [ ] Installed-app screenshots cover iPhone portrait at default and accessibility Dynamic Type, iPad portrait/landscape, and macOS at narrow/wide windows for populated Need/Basket/All, category-filtered, empty, all-complete, pending, row-error, queued, conflict, and duplicate states; the ledger has no clipping, overlap, tiny primary targets, unexplained blank region larger than one row, or open `ready` finding.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] `visual-qa-dogfood` evidence is captured from installed/running builds, the absurdity ledger is closed, and automated visual metrics still pass.
- [ ] Focused PR is merged; required checks are green for exact merged `main`; internal TestFlight build is attached to Spoonjoy Internal and reaches `IN_BETA_TESTING`; branch/worktree cleanup is complete.

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

### ⬜ Unit 0: Setup and source-fidelity baseline
**What**: Record fresh-main SHA, toolchain/simulator inventory, web shopping/category semantics, baseline targeted tests, native justification fit, and TestFlight capability preflight in the artifacts directory.
**Output**: Baseline log and source-fidelity matrix citing `ShoppingListState.swift`, `ShoppingSurfaceViewModel.swift`, `NativeLiveAppStore.swift`, `PlatformNavigationView.swift`, the web route, and web ingredient affordances.
**Acceptance**: Branch/worktree isolation is proven; baseline targeted suite is green; release credentials/config are checked without publishing.

### ⬜ Unit 1a: Localized mutation coordination — tests
**What**: Add failing tests in `ShoppingSurfaceParityTests.swift` and `NativeLiveStoreTests.swift` for immediate online optimistic publication, no root bootstrap, shopping-only follow-up read, exclusive optimistic ownership for queued/fallback paths, rollback/local-error semantics, and delayed/out-of-order mutation/reconciliation behavior.
**Output**: Red test commit with outbound mutation/read assertions and shell-state assertions.
**Acceptance**: New tests fail for the intended absent coordinator/reconciliation behavior while pre-existing shopping tests remain green.

### ⬜ Unit 1b: Localized mutation coordination — implementation
**What**: Implement serialized/generation-aware shopping mutation execution in `NativeLiveAppStore.swift`, wire `PlatformNavigationView.swift` to it, and adjust `ShoppingSurfaceMutationExecutor` only as required to keep one optimistic owner across online, queued, and fallback paths.
**Output**: Online writes rebase optimistically on latest store state, avoid `bootstrap()`, perform targeted shopping read reconciliation, and expose localized reconciliation/failure state.
**Acceptance**: Unit 1a passes; captured outbound requests are exact; no ordinary shopping mutation applies `.restoringCache`; builds have no warnings.

### ⬜ Unit 1c: Localized mutation coordination — coverage and refactor
**What**: Cover empty-plan, offline fallback, queue failure, non-offline failure, read-reconciliation failure, stale-generation, and concurrent-write branches; refactor without behavior change.
**Output**: Coverage and targeted/full-test logs.
**Acceptance**: 100% coverage on new mutation coordination code; all Swift tests and native scenario checks remain green.

### ⬜ Unit 2a: Market modes and category semantics — tests
**What**: Add failing pure-model tests for Need/Basket/All counts, fixed market rank, stable same-category order, explicit category validation, name fallback, completed sections, invalid-filter reset data, duplicate handling, and empty/all-complete variants.
**Output**: Red tests in `ShoppingSurfaceParityTests.swift` and/or a focused shopping presentation test file.
**Acceptance**: Tests fail on missing presentation model behavior and precisely match web helper/route semantics.

### ⬜ Unit 2b: Market modes and category semantics — implementation
**What**: Add the minimal Sendable/Equatable shopping presentation model in `ShoppingSurfaceViewModel.swift` and/or `ShoppingListState.swift`, preserving server data and stable receipt ordering.
**Output**: Tested modes, counts, category choices, filtered sections, category/icon affordances, and state-specific empty copy.
**Acceptance**: Unit 2a passes with minimal implementation; existing duplicate/offline semantics stay green.

### ⬜ Unit 2c: Market modes and category semantics — coverage and refactor
**What**: Cover invalid explicit keys, every name-fallback category/icon branch, empty modes, stable ordering ties, duplicate interaction, and category-filter boundaries; refactor with tests green.
**Output**: Coverage, full-test, and build logs.
**Acceptance**: 100% coverage on the new presentation model; all tests/builds pass without warnings.

### ⬜ Unit 3a: Native shopping surface contract — tests
**What**: Add failing source/runtime contracts for editorial title/count hierarchy, three-mode native selection, horizontal category controls, ruled rows, >=44pt targets, row pending/error indicators, compact actions, native swipe/context deletion, and absence of full-shell progress UI.
**Output**: Red design/source contract tests with exact SwiftUI anchors.
**Acceptance**: Tests fail on the current shopping view for intended missing UI behavior.

### ⬜ Unit 3b: Native shopping surface — core implementation
**What**: Redesign `ShoppingListView.swift` and `ReceiptListView.swift` around the tested presentation model with Need/Basket/All, category filters, stable ruled rows, compact composer/actions, and per-item pending/error state.
**Output**: Core shared SwiftUI receipt surface and interaction states.
**Acceptance**: Unit 3a core anchors pass; large check targets and native swipe/context deletion remain intact.

### ⬜ Unit 3c: Platform and accessibility adaptations — tests and implementation
**What**: Add failing contracts for Dynamic Type, VoiceOver, iPhone/iPad/macOS responsive layout and keyboard behavior, then implement the minimal platform adaptations.
**Output**: Tested platform-specific layout and accessibility behavior.
**Acceptance**: Adaptation tests turn red then green; no web-style custom navigation or decorative-card regression; builds have no warnings.

### ⬜ Unit 3d: Native shopping surface — coverage, build, and scenario verification
**What**: Regenerate project files if required; run full Swift tests, coverage, scenario verifier, iOS/iPadOS simulator builds, macOS build, bundle checks, and warning checks.
**Output**: Validation logs in artifacts.
**Acceptance**: Required local checks are green, modified/new logic is fully covered, and all three platform layouts compile without warnings.

### ⬜ Unit 3e: iPhone visual capture
**What**: Capture installed/running iPhone portrait screenshots at default and accessibility Dynamic Type for populated Need/Basket/All, category-filtered, empty, all-complete, pending, row-error, queued, conflict, and duplicate states.
**Output**: iPhone screenshot manifest, accessibility proofs, and initial ledger entries.
**Acceptance**: Every named state/size is captured uncropped from the installed app and recorded in the ledger.

### ⬜ Unit 3f: iPad and macOS visual capture
**What**: Capture installed/running iPad portrait/landscape and macOS narrow/wide screenshots for the same state matrix, using representative dense content.
**Output**: iPad/macOS screenshot manifests, accessibility proofs, and ledger entries.
**Acceptance**: Every named platform/state/size is captured uncropped and recorded in the ledger.

### ⬜ Unit 3g: Visual remediation, recapture, and cold review
**What**: Inspect all captures, fix every in-scope finding, rerun affected tests/metrics, recapture fixed surfaces, close the ledger, and obtain a cold visual PASS.
**Output**: Final screenshots, design-review manifests, closed `visual-qa-ledger.md`, and reviewer verdict.
**Acceptance**: No ledger item remains `ready` or `needs reviewer gate`; automated metrics pass; cold reviewer returns PASS.

### ⬜ Unit 4a: Pre-PR sync and branch validation
**What**: Fetch/merge current origin/main, resolve conflicts, rerun full validation, and obtain a cold branch review.
**Output**: Synced branch, complete validation evidence, reviewer verdict.
**Acceptance**: Branch is clean, pushed, green, and reviewer-converged against current main.

### ⬜ Unit 4b: PR, CI, review, and merge
**What**: Open the focused PR, repair review/CI findings, verify required checks, and merge under repository policy.
**Output**: Merged PR URL and merged SHA.
**Acceptance**: PR is merged with required checks green on its reviewed head.

### ⬜ Unit 4c: Exact-main and internal TestFlight verification
**What**: Check out exact merged main, rerun required verification, create release notes pinned to merged SHA, publish with `ci-publish-testflight.sh`, and verify Spoonjoy Internal attachment, non-empty tester group, and `IN_BETA_TESTING`.
**Output**: Exact-main logs and TestFlight publish summary.
**Acceptance**: Required checks are green for merged SHA and the internal build is available in beta testing.

### ⬜ Unit 4d: Cleanup and durable closure
**What**: Remove task-owned local/remote branch and worktree where policy permits, update planning/doing/task status and evidence, commit/push durable desk state, and scan for task-owned residue.
**Output**: Cleanup log and terminal durable task records.
**Acceptance**: No task-owned branch/worktree residue remains; all task docs accurately report terminal state and are pushed.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **All artifacts**: Save outputs, logs, data to `./2026-08-21-1735-doing-native-shopping-list-experience-repair/` directory
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-08-21 17:44 Created from reviewer-approved planning doc.
