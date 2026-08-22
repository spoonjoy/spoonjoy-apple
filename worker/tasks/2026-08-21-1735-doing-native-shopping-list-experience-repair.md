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
- [ ] The surface launches in All; Need/Basket/All counts, category grouping/order, filters, and mode-specific empty states match web semantics across active, completed, empty, all-complete, duplicate-data, queued, conflict, and failure states.
- [ ] Installed-app screenshots cover iPhone portrait at default and accessibility Dynamic Type, iPad portrait/landscape, and macOS at narrow/wide windows for populated Need/Basket/All, category-filtered, empty, all-complete, pending, row-error, queued, conflict, and duplicate states; the ledger has no clipping, overlap, tiny primary targets, unexplained blank region larger than one row, or open `ready` finding.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] `visual-qa-dogfood` evidence is captured from installed/running builds, the absurdity ledger is closed, and automated visual metrics still pass.
- [ ] Focused PR is merged; `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` are green for exact merged `main`; internal TestFlight build is attached to Spoonjoy Internal and reaches `IN_BETA_TESTING`; branch/worktree cleanup is complete.

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
**What**: Add failing tests for canonical action/idempotency metadata, monotonic immediate optimism, remote FIFO, and retry intents: `.resubmitWithNewID`, `.reconcileThenReplaySameID`, `.reconcileOnly`, and `.persistAlreadyAppliedBatch(entries)`. Persistence retry must retain identical IDs/order in an ordered batch journal, call only queue persistence (no remote/no optimism), and clear journal/feedback only after save succeeds. Suspend responses to prove add/add-from-recipe never duplicate. For A optimistic then B optimistic while A is suspended, make A definitely reject and prove journal reprojection from baseline drops A without stale-snapshot clobber, preserves B, and keeps B in remote FIFO (or marks B dependent-blocked before remote if it targets A's rejected local ID). Force A offline with suspended later add/check/delete and require one already-applied queue batch/no later remote. Cancellation remains journaled as hidden `.recovering` until reconcile/queue recovery; test no user-facing pending/error during automatic recovery.
**Output**: Red test commit with outbound mutation/read assertions and shell-state assertions.
**Acceptance**: New tests fail for the intended absent coordinator/reconciliation behavior while pre-existing shopping tests remain green.

### ⬜ Unit 1b: Localized mutation coordination — implementation
**What**: Add canonical action/ID to executable plans. Implement coordinator, retry intent, and an ordered mutation journal with baseline plus per-entry generation/action/ID/optimistic reducer/dependency/status. Reproject visible state from baseline through every non-rejected journal entry; never restore a stale whole snapshot. Immediate submission appends/reprojects; remote work stays FIFO. Definite A rejection removes A and reprojects B; dependent B is blocked before remote, independent B keeps order. Indeterminate/cancelled uses same-ID recovery; confirmed-write/read-failure is read-only. Add shopping-specific `persistAlreadyAppliedShoppingBatch` that saves journal entries atomically without optimism or `.syncFailed`; persistence failure exposes `.persistAlreadyAppliedBatch` retaining same entries/IDs/order, whose retry only persists and clears on success. Offline transition moves failing+later entries into that batch and cancels their remote work. Cancelled entries remain operationally journaled as hidden `.recovering` and are removed only after reconcile/queue recovery. Sticky banners cover actionable entries; visible rows may mirror pending.
**Output**: Online writes rebase optimistically on latest store state, avoid `bootstrap()`, perform targeted shopping read reconciliation, and expose localized reconciliation/failure state.
**Acceptance**: Unit 1a passes; captured outbound requests are exact; no ordinary shopping mutation applies `.restoringCache`; builds have no warnings.

### ⬜ Unit 1c: Localized mutation coordination — coverage and refactor
**What**: Cover empty/blocked plan, A-reject/B-independent and A-reject/B-dependent reprojection, indeterminate/cancelled hidden recovery, confirmed-write/read failure, same-ID replay, reconcile-only retry, persistence-only same-batch retry/clear-on-success, offline dependent FIFO cancellation, no-double-add/add-from-recipe, stale generation, and absent-row banner branches; refactor without behavior change.
**Output**: Coverage and targeted/full-test logs.
**Acceptance**: 100% coverage on new mutation coordination code; all Swift tests and native scenario checks remain green.

### ⬜ Unit 2a: Market modes and category semantics — tests
**What**: Add failing tests for `ShoppingPresentationModel`: initial All; Need/Basket/All counts; fixed category rank/stable source order; explicit category/name fallback; checked rows in ordinary category sections; invalid-filter reset; duplicates staying in ordinary category order; and mode-specific empty/all-complete behavior. With every item checked, Need is empty while Basket/All retain checked rows and clear-checked.
**Output**: Red tests in `Tests/SpoonjoyCoreTests/ShoppingPresentationModelTests.swift`.
**Acceptance**: Tests fail on missing presentation model behavior and precisely match web helper/route semantics.

### ⬜ Unit 2b: Market modes and category semantics — implementation
**What**: Add the minimal Sendable/Equatable `ShoppingPresentationModel` in `Sources/SpoonjoyCore/Features/Shopping/ShoppingPresentationModel.swift`; `ShoppingSurfaceViewModel.swift` exposes it, while `ShoppingListState.swift` remains canonical server/domain data.
**Output**: Tested modes, counts, category choices, filtered sections, category/icon affordances, and state-specific empty copy.
**Acceptance**: Unit 2a passes with minimal implementation; existing duplicate/offline semantics stay green.

### ⬜ Unit 2c: Market modes and category semantics — coverage and refactor
**What**: Cover invalid keys, every fallback branch, initial All, empty/filter-empty, all-complete Need/Basket/All, stable ties, duplicate-data non-section behavior, and filter boundaries; refactor green.
**Output**: Coverage, full-test, and build logs.
**Acceptance**: 100% coverage on the new presentation model; all tests/builds pass without warnings.

### ⬜ Unit 3a: Native shopping surface contract — tests
**What**: Add failing observable/accessibility tests for title/count, launch selection All with VoiceOver selected value, category reset, >=44pt targets, visible-row pending, sticky retry including absent rows, delete actions, and no shell takeover. Empty/filter-empty/all-complete require a working visible/revealable composer. When recipes exist, Add from Recipe is reachable; when none exist it is absent or disabled and an observable recipe-creation navigation/action remains reachable. Test both recipe-presence branches. All-complete Need is empty while Basket/All render rows. When check/delete hides focus, post an accessibility announcement or transfer focus to an action-specific labelled/hinted retry banner with keyboard-focusable Retry on iPadOS/macOS.
**Output**: Red behavior/accessibility contracts and minimal regression-source checks.
**Acceptance**: Tests fail on missing user-observable shopping behavior, not implementation spelling.

### ⬜ Unit 3b: Native shopping surface — core implementation
**What**: Redesign around initial All, mode-specific receipt/empty states, category-only stable ruled rows (no separate completed/duplicate-review sections), and a working composer in every empty state. Expose Add from Recipe only when recipes exist; otherwise omit/disable it and expose the tested recipe-creation path. Keep visible-row pending and sticky retry with accessibility announcement/focus transfer when a row disappears.
**Output**: Core shared SwiftUI receipt surface and reachable interaction feedback.
**Acceptance**: Unit 3a core anchors pass; large check targets and native swipe/context deletion remain intact.

### ⬜ Unit 3c: Platform and accessibility adaptations — tests
**What**: Add failing behavior tests for Dynamic Type, VoiceOver, iPhone/iPad/macOS responsive state, keyboard behavior, and fixture-driven UI coverage. Add/generate a `SpoonjoyShoppingUITests` target. Add failing `scripts/check-shopping-ui-coverage-contract.rb` tests for `scripts/enforce-xcode-changed-line-coverage.rb`: require xccov JSON input, base ref, 100% minimum, both view paths, missing-file/line failures, and changed executable-line intersection.
**Output**: Saved failing Swift/package and Xcode UI-test logs committed before adaptation code.
**Acceptance**: Tests fail on absent platform/accessibility behavior and app-target coverage path; red commit exists.

### ⬜ Unit 3d: Platform and accessibility adaptations — implementation
**What**: Implement minimal platform adaptations; keep conditional presentation/selection/feedback/retry/layout policy in covered Core. Implement the tested xccov changed-line enforcer and generated UI-test scheme/target contract.
**Output**: Responsive/accessibility behavior with green Unit 3c tests.
**Acceptance**: Unit 3c passes unchanged; no web-style navigation/decorative-card regression; builds have no warnings.

### ⬜ Unit 3e: Native shopping surface — coverage, build, and scenario verification
**What**: Run `scripts/generate-xcode-project.rb`; `swift test`; `swift test --enable-code-coverage`; `coverage_json="$(swift test --show-codecov-path)"`; `ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include Sources/SpoonjoyCore`; `xcodebuild test -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES -resultBundlePath <artifacts>/shopping-ui.xcresult`; `xcrun xccov view --report --json <artifacts>/shopping-ui.xcresult > <artifacts>/shopping-ui-coverage.json`; `ruby scripts/enforce-xcode-changed-line-coverage.rb --coverage-json <artifacts>/shopping-ui-coverage.json --base-ref origin/main --minimum 100 --file Apps/Spoonjoy/Shared/Views/ShoppingListView.swift --file Apps/Spoonjoy/Shared/Components/ReceiptListView.swift`; `scripts/verify-native-scenarios.sh --stage final --output <artifacts>/scenario-final.json`; `scripts/bundle-check.sh`; and `scripts/validate-native-local.sh --artifact-root <artifacts>/native-local`.
**Output**: Validation logs in artifacts.
**Acceptance**: Required local checks are green, modified/new logic is fully covered, and all three platform layouts compile without warnings.

### ⬜ Unit 3f: Shopping screenshot harness — tests
**What**: Add failing launch/matrix contracts for the argument set and canonical YAML. Add `scripts/check-shopping-visual-cell-validator-contract.rb` tests for new `scripts/validate-shopping-visual-cell.rb`: a one-platform `shopping-visual-cell.json` must contain its exact matrix row ID, unit slug, artifact root, recomputed argv, selected platform, PNG path, accessibility-proof path, screenshot-log path, state, and size without absent-platform claims. The runner passes the selected canonical row contract to the validator; the validator independently recomputes argv/artifact paths and byte-compares every identity/argv/path field. Add red cases for swapped manifests between two otherwise-valid rows and every mismatched row/slug/root/argv/path field. Do not weaken/reuse `validate-design-review.rb`; its cross-platform manifest stays owned by `validate-native-local.sh`. Matrix tests require safe YAML, schema/counts 22/20/20, keys/values/uniqueness/recomputed argv, and artifact kinds `png`, `visualCellManifest`, `accessibilityProof`, `screenshotLog` each 62.
**Output**: Red launch, safe matrix runner, and per-cell validator contracts covering malformed/missing/extra/cross-platform-fabrication, swapped-row, and mismatched-row cases.
**Acceptance**: Contract suites fail because CLI, runner, and separate per-cell validator are absent.

### ⬜ Unit 3g: Shopping screenshot harness — implementation
**What**: Implement arguments, safe matrix runner, and separate per-cell validator. Each capture writes one row-bound `shopping-visual-cell.json`; runner validate checks four exact row artifacts and invokes only `validate-shopping-visual-cell.rb` with the selected canonical row contract. The validator recomputes and byte-compares row ID/slug/root/argv and all artifact paths before accepting the selected-platform evidence. `validate-native-local.sh` separately produces/validates the existing all-platform `design-review.json`. Enforce every Unit 3f invariant, root confinement, and dry-run/capture/validate.
**Output**: Deterministic installed-app capture controls and fail-closed safe manifest runner/validator.
**Acceptance**: All three Unit 3f suites—launch, matrix-runner, and per-cell-validator—turn green; malformed/aliased/unknown/duplicate/mismatched manifests fail before subprocess execution; existing route captures remain green.

### ⬜ Unit 3h: iPhone, iPad, and macOS visual capture
**What**: Run `ruby scripts/run-shopping-visual-matrix.rb --manifest worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml --artifact-base worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair --mode dry-run`, inspect 62 commands, then rerun with `--mode capture`. The manifest encodes 22 iPhone, 20 iPad, and 20 macOS rows with unique slug/root and one selected platform. Dense normal fixture has >=12 items, >=5 categories, and two two-line names.
**Output**: Per-cell directories with PNG, `shopping-visual-cell.json`, selected-platform accessibility proof, log, and ledger entry.
**Acceptance**: All 62 commands produce exactly 62 of each declared artifact kind at unique roots; no per-cell manifest claims another platform.

### ⬜ Unit 3i: Visual remediation, recapture, and cold review
**What**: Run matrix validate, inspect 62 PNGs, ledger/fix/recapture, rerun launch/matrix/per-cell contracts, and obtain cold PASS. Runner fails on missing/duplicate/extra/mismatched PNG/cell-manifest/proof/log. Preserve matrix, 62 artifacts of each kind, cross-platform local-validation manifest, and ledger before Unit 4a.
**Output**: Final screenshots, per-cell manifests, cross-platform design-review manifest, closed ledger, and reviewer verdict.
**Acceptance**: Exactly 62 manifests and their proofs validate; no ledger item remains `ready` or `needs reviewer gate`; automated metrics pass; cold reviewer returns PASS; the branch commit containing all visual evidence is pushed before PR sync/review.

### ⬜ Unit 4a: Pre-PR sync and branch validation
**What**: `git fetch origin main`, merge `origin/main`, resolve conflicts, then rerun Unit 3e exact commands; cold-review `git diff origin/main...HEAD` plus all validation artifacts. Before PR creation, update product planning/doing as merged execution snapshots: doing remains `in-progress`, records completed implementation/visual units/evidence, and points post-merge terminal truth to Desk.
**Output**: Synced branch, complete validation evidence, reviewer verdict.
**Acceptance**: Branch is clean, pushed, green, and reviewer-converged against current main.

### ⬜ Unit 4b: PR, CI, review, and merge
**What**: Open the focused PR, run `gh pr checks <pr> --watch`, repair review/CI findings, verify `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`, and merge under repository policy.
**Output**: Merged PR URL and merged SHA.
**Acceptance**: PR is merged with `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` green on its reviewed head.

### ⬜ Unit 4c: Exact-main and internal TestFlight verification
**What**: From persistent base checkout, require base/task clean, fetch merged `origin/main`, and create `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main` detached at the exact 40-character merged SHA; require clean status and exact `HEAD`. Rerun every Unit 3e command in that worktree. Use exactly `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts` as the durable Desk artifact root and write `testflight-release-notes.json` there with exactly `{ "schemaVersion": 1, "sourceSha": "<merged-sha>", "notes": "<non-empty shopping-list release notes, at most 4000 characters>" }`. From exact-main run `SPOONJOY_TESTFLIGHT_SOURCE_SHA=<merged-sha> SPOONJOY_TESTFLIGHT_RELEASE_NOTES_PATH=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/testflight-release-notes.json SPOONJOY_TESTFLIGHT_ARTIFACT_DIR=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/ci-testflight scripts/ci-publish-testflight.sh`.
**Output**: Exact-main logs, exact-schema release notes, and `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/ci-testflight/testflight-publish-summary.json`.
**Acceptance**: Required checks are green at exact `HEAD == sourceSha == merged SHA`; publish summary has exactly the keys `sourceSha`, `releaseNotesArtifact`, `bundleId`, `appId`, `buildNumber`, `buildId`, `buildBetaDetailId`, `groupName`, `groupId`, `internalBuildState`, `testerCount`, and `testersNotifiedRequested`, with that exact `sourceSha`, exact absolute release-notes path, `buildNumber` as a non-empty decimal string, non-empty `buildId` and `buildBetaDetailId`, `groupName == "Spoonjoy Internal"`, numeric `testerCount > 0`, and `internalBuildState == "IN_BETA_TESTING"`.

### ⬜ Unit 4d: Cleanup and durable closure
**What**: Treat product planning/doing files in merged SHA as immutable execution snapshots; Desk task/card/artifacts are the sole post-merge terminal/evidence state (no second product PR). Preflight from `/Users/arimendelow/Projects/spoonjoy-apple`: base, task, and exact-main worktrees all clean; exact-main HEAD equals merged SHA; Unit 3i evidence commit is ancestor of merged SHA; Desk exact-main/TestFlight artifacts exist and are committed/pushed. Then, in order from the base checkout, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main`, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair`, delete local task branch, conditionally delete remote task branch, and run `git worktree list` plus local/remote ref scans. Finally mark only the Desk task terminal and push Desk `main`.
**Output**: Cleanup log and terminal durable task records.
**Acceptance**: Three-worktree clean/evidence preflight passed; all product-repo visual evidence and execution snapshots are contained in merged SHA; sole terminal post-merge state/evidence is pushed in Desk; exact-main and task worktrees plus local/remote task refs are absent; persistent base checkout remains clean.

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
