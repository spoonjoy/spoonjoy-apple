# Doing: Native Shopping List Experience Repair

**Status**: in-progress
**Execution Mode**: direct
**Created**: 2026-08-21 17:44
**Planning**: ./2026-08-21-1735-planning-native-shopping-list-experience-repair.md
**Artifacts**: /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/
**Product Matrix**: ./2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml

## Execution Mode

- **direct**: Execute units sequentially in this dedicated worker task; use fresh sub-agent reviewer/fixer gates after substantive units.

## Objective
Make ordinary shopping-list mutations immediate and localized, and redesign the native shopping surface to preserve the web product's Need/Basket/All, category, and ruled-receipt language through native iOS, iPadOS, and macOS mechanics.

## Upstream Work Items
- `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/task.md`

## Completion Criteria
- [x] Shopping checkoff, uncheck, add, delete, clear-checked, and clear-all never publish `.restoringCache` or replace the app shell.
- [x] Online mutations are serialized, optimistically rebase on the latest store state, reconcile only shopping-list state after successful remote writes, and ignore stale reconciliation responses; offline/already-queued/fallback mutations retain FIFO with exactly one optimistic application.
- [x] A definite non-offline mutation failure rolls back when no later mutation exists; otherwise a targeted read reconciles without clobbering newer state. Indeterminate reconciliation failure retains the optimistic row with a row/action retry error and never triggers root bootstrap.
- [x] The surface launches in All; Need/Basket/All counts, category grouping/order, filters, and mode-specific empty states match web semantics across active, completed, empty, all-complete, duplicate-data, queued, conflict, and failure states.
- [x] Installed-app screenshots cover iPhone portrait at default and accessibility Dynamic Type for every listed state; iPad portrait/landscape and macOS narrow/wide for populated Need/Basket/All, category-filtered, pending, row-error, queued, conflict, and duplicate states; and representative portrait/narrow empty and all-complete layouts on each non-phone platform. The ledger has no clipping, overlap, tiny primary targets, unexplained blank region larger than one row, or open `ready` finding.
- [x] 100% test coverage on all new code
- [x] All tests pass
- [x] No warnings
- [x] `visual-qa-dogfood` evidence is captured from installed/running builds, the absurdity ledger is closed, and automated visual metrics still pass.
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

### ✅ Unit 0: Setup and source-fidelity baseline
**What**: Record fresh-main SHA, toolchain/simulator inventory, web shopping/category semantics, baseline targeted tests, native justification fit, and TestFlight capability preflight in the artifacts directory.
**Output**: Baseline log and source-fidelity matrix citing `ShoppingListState.swift`, `ShoppingSurfaceViewModel.swift`, `NativeLiveAppStore.swift`, `PlatformNavigationView.swift`, the web route, and web ingredient affordances.
**Acceptance**: Branch/worktree isolation is proven; baseline targeted suite is green; release credentials/config are checked without publishing.

### ✅ Unit 1a: Localized mutation coordination — tests
**What**: Add failing tests for canonical action/idempotency metadata, monotonic immediate optimism, remote FIFO, and retry intents: `.resubmitWithNewID`, `.reconcileThenReplaySameID`, `.reconcileOnly`, and `.persistAlreadyAppliedBatch(entries)`. Persistence retry must retain identical IDs/order in an ordered batch journal, call only queue persistence (no remote/no optimism), and clear journal/feedback only after save succeeds. Suspend responses to prove add/add-from-recipe never duplicate. A solo definite rejection must roll back by journal reprojection and make zero targeted-read requests. For A optimistic then later B optimistic while A is suspended, make A definitely reject and require exactly one targeted shopping read; prove its generation-aware reconciliation drops A without stale-snapshot clobber, preserves B, and keeps B in remote FIFO (or marks B dependent-blocked before remote if it targets A's rejected local ID). Force A offline with suspended later add/check/delete and require one already-applied queue batch/no later remote. Cancellation remains journaled as hidden `.recovering` until reconcile/queue recovery; test no user-facing pending/error during automatic recovery.
**Output**: Red test commit with outbound mutation/read assertions and shell-state assertions.
**Acceptance**: New tests fail for the intended absent coordinator/reconciliation behavior while pre-existing shopping tests remain green.

### ✅ Unit 1b: Localized mutation coordination — implementation
**What**: Add canonical action/ID to executable plans. Implement coordinator, retry intent, and an ordered mutation journal with baseline plus per-entry generation/action/ID/optimistic reducer/dependency/status. Reproject visible state from baseline through every non-rejected journal entry; never restore a stale whole snapshot. Immediate submission appends/reprojects; remote work stays FIFO. Definite A rejection removes A and reprojects B; dependent B is blocked before remote, independent B keeps order. Indeterminate/cancelled uses same-ID recovery; confirmed-write/read-failure is read-only. Add shopping-specific `persistAlreadyAppliedShoppingBatch` that saves journal entries atomically without optimism or `.syncFailed`; persistence failure exposes `.persistAlreadyAppliedBatch` retaining same entries/IDs/order, whose retry only persists and clears on success. Offline transition moves failing+later entries into that batch and cancels their remote work. Cancelled entries remain operationally journaled as hidden `.recovering` and are removed only after reconcile/queue recovery. Sticky banners cover actionable entries; visible rows may mirror pending.
**Output**: Online writes rebase optimistically on latest store state, avoid `bootstrap()`, perform targeted shopping read reconciliation, and expose localized reconciliation/failure state.
**Acceptance**: Unit 1a passes; captured outbound requests are exact; no ordinary shopping mutation applies `.restoringCache`; builds have no warnings.

### ✅ Unit 1c: Localized mutation coordination — coverage and refactor
**What**: Cover empty/blocked plan, solo definite rejection rollback with no read, A-reject/B-independent and A-reject/B-dependent reprojection with the exact targeted-read count/order, indeterminate/cancelled hidden recovery, confirmed-write/read failure, same-ID replay, reconcile-only retry, persistence-only same-batch retry/clear-on-success, offline dependent FIFO cancellation, no-double-add/add-from-recipe, stale generation, and absent-row banner branches; refactor without behavior change.
**Output**: Coverage and targeted/full-test logs.
**Acceptance**: 100% coverage on new mutation coordination code; all Swift tests and native scenario checks remain green.

### ✅ Unit 2a: Market modes and category semantics — tests
**What**: Add failing tests for `ShoppingPresentationModel`: initial All; Need/Basket/All counts; fixed category rank/stable source order; explicit category/name fallback; checked rows in ordinary category sections; invalid-filter reset; duplicates staying in ordinary category order; and mode-specific empty/all-complete behavior. With every item checked, Need is empty while Basket/All retain checked rows and clear-checked.
**Output**: Red tests in `Tests/SpoonjoyCoreTests/ShoppingPresentationModelTests.swift`.
**Acceptance**: Tests fail on missing presentation model behavior and precisely match web helper/route semantics.

### ✅ Unit 2b: Market modes and category semantics — implementation
**What**: Add the minimal Sendable/Equatable `ShoppingPresentationModel` in `Sources/SpoonjoyCore/Features/Shopping/ShoppingPresentationModel.swift`; `ShoppingSurfaceViewModel.swift` exposes it, while `ShoppingListState.swift` remains canonical server/domain data.
**Output**: Tested modes, counts, category choices, filtered sections, category/icon affordances, and state-specific empty copy.
**Acceptance**: Unit 2a passes with minimal implementation; existing duplicate/offline semantics stay green.

### ✅ Unit 2c: Market modes and category semantics — coverage and refactor
**What**: Cover invalid keys, every fallback branch, initial All, empty/filter-empty, all-complete Need/Basket/All, stable ties, duplicate-data non-section behavior, and filter boundaries; refactor green.
**Output**: Coverage, full-test, and build logs.
**Acceptance**: 100% coverage on the new presentation model; all tests/builds pass without warnings.

### ✅ Unit 3a: Native shopping surface contract — tests
**What**: Add failing observable/accessibility tests for title/count, launch selection All with VoiceOver selected value, category reset, >=44pt targets, visible-row pending, sticky retry including absent rows, delete actions, and no shell takeover. Empty/filter-empty/all-complete require a working visible/revealable composer. When recipes exist, Add from Recipe is reachable; when none exist it is absent or disabled and an observable recipe-creation navigation/action remains reachable. Test both recipe-presence branches. All-complete Need is empty while Basket/All render rows. When check/delete hides focus, post an accessibility announcement or transfer focus to an action-specific labelled/hinted retry banner with keyboard-focusable Retry on iPadOS/macOS.
**Output**: Red behavior/accessibility contracts and minimal regression-source checks.
**Acceptance**: Tests fail on missing user-observable shopping behavior, not implementation spelling.

### ✅ Unit 3b: Native shopping surface — core implementation
**What**: Redesign around initial All, mode-specific receipt/empty states, category-only stable ruled rows (no separate completed/duplicate-review sections), and a working composer in every empty state. Expose Add from Recipe only when recipes exist; otherwise omit/disable it and expose the tested recipe-creation path. Keep visible-row pending and sticky retry with accessibility announcement/focus transfer when a row disappears.
**Output**: Core shared SwiftUI receipt surface and reachable interaction feedback.
**Acceptance**: Unit 3a core anchors pass; large check targets and native swipe/context deletion remain intact.

### ✅ Unit 3c: Platform and accessibility adaptations — tests
**What**: Add failing behavior tests for Dynamic Type, VoiceOver, iPhone/iPad/macOS responsive state, keyboard behavior, and fixture-driven UI coverage. Add/generate a `SpoonjoyShoppingUITests` target. Add failing `scripts/check-shopping-ui-coverage-contract.rb` tests for `scripts/enforce-xcode-changed-line-coverage.rb`: require xccov JSON input, base ref, 100% minimum, `ShoppingListView.swift`, `ReceiptListView.swift`, and `PlatformNavigationView.swift`, plus `--app-root Apps/Spoonjoy` discovery of every other changed app-target Swift file. Cover missing-file/line failures, changed executable-line intersection, and failure when any changed app-target Swift path is omitted from xccov input.
**Output**: Saved failing Swift/package and Xcode UI-test logs committed before adaptation code.
**Acceptance**: Tests fail on absent platform/accessibility behavior and app-target coverage path; red commit exists.

### ✅ Unit 3d: Platform and accessibility adaptations — implementation
**What**: Implement minimal platform adaptations; keep conditional presentation/selection/feedback/retry/layout policy in covered Core. Implement the tested xccov changed-line enforcer so explicit integration files and every changed Swift file under the app root are enforced, plus the generated UI-test scheme/target contract.
**Output**: Responsive/accessibility behavior with green Unit 3c tests.
**Acceptance**: Unit 3c passes unchanged; no web-style navigation/decorative-card regression; builds have no warnings.

### ✅ Unit 3e: Native shopping surface — coverage, build, and scenario verification
**What**: Set `artifacts=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/branch-validation`, run `mkdir -p "$artifacts"`, remove only the exact prior bundle with `rm -rf "$artifacts/shopping-ui.xcresult"`, then run `scripts/generate-xcode-project.rb`; `swift test`; `swift test --enable-code-coverage`; `coverage_json="$(swift test --show-codecov-path)"`; `ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include Sources/SpoonjoyCore`; `xcodebuild test -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES -resultBundlePath "$artifacts/shopping-ui.xcresult"`; `xcrun xccov view --report --json "$artifacts/shopping-ui.xcresult" > "$artifacts/shopping-ui-coverage.json"`; `ruby scripts/enforce-xcode-changed-line-coverage.rb --coverage-json "$artifacts/shopping-ui-coverage.json" --base-ref origin/main --minimum 100 --app-root Apps/Spoonjoy --file Apps/Spoonjoy/Shared/Views/ShoppingListView.swift --file Apps/Spoonjoy/Shared/Components/ReceiptListView.swift --file Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`; `scripts/verify-native-scenarios.sh --stage final --output "$artifacts/scenario-final.json"`; `scripts/bundle-check.sh`; and `scripts/validate-native-local.sh --artifact-root "$artifacts/native-local"`.
**Output**: Validation logs in artifacts.
**Acceptance**: Required local checks are green, modified/new logic is fully covered, and all three platform layouts compile without warnings.

### ✅ Unit 3f: Shopping screenshot harness — tests
**What**: Add failing launch/matrix contracts for the argument set and canonical YAML. Add `scripts/check-shopping-visual-cell-validator-contract.rb` tests for new `scripts/validate-shopping-visual-cell.rb`: a one-platform `shopping-visual-cell.json` must contain its exact matrix row ID, unit slug, artifact root, recomputed argv, selected platform, PNG path, accessibility-proof path, screenshot-log path, state, and size without absent-platform claims. The runner passes the selected canonical row contract to the validator; the validator independently recomputes argv/artifact paths and byte-compares every identity/argv/path field. Add red cases for swapped manifests between two otherwise-valid rows and every mismatched row/slug/root/argv/path field. Do not weaken/reuse `validate-design-review.rb`; its cross-platform manifest stays owned by `validate-native-local.sh`. Add a shared fail-closed matrix validator used by runner and repository audit: only exact path `worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml` may be retained, parsed with `Psych.safe_load(..., permitted_classes: [], permitted_symbols: [], aliases: false)`, and accepted only with exact top-level/row keys, schema/counts 62 and 22/20/20, allowed values, unique IDs/slugs/roots, recomputed argv byte equality, and exact artifact-kind counts. Red tests cover malformed/aliased/extra-key/count/value/argv canonical YAML. Extend `NativeRepositoryHygieneContractTests.swift` so generated JSON/log/PNG/validation formats and every other YAML/YML under any `worker/tasks/` task are rejected; Markdown remains allowed and the exact canonical YAML passes only through the safe validator. Visual artifacts themselves are external Desk evidence, not a broader repository allowance.
**Output**: Red launch, safe matrix runner, and per-cell validator contracts covering malformed/missing/extra/cross-platform-fabrication, swapped-row, and mismatched-row cases.
**Acceptance**: Contract suites fail because CLI, runner, and separate per-cell validator are absent.

### ✅ Unit 3g: Shopping screenshot harness — implementation
**What**: Implement arguments, safe matrix runner, shared fail-closed matrix validator, and separate per-cell validator. Each capture writes one row-bound `shopping-visual-cell.json`; runner validate checks four exact row artifacts and invokes only `validate-shopping-visual-cell.rb` with the selected canonical row contract. The validator recomputes and byte-compares row ID/slug/root/argv and all artifact paths before accepting the selected-platform evidence. `validate-native-local.sh` separately produces/validates the existing all-platform `design-review.json`. Add `worker/tasks/` to `audit-native-validation-artifacts.rb`'s generated-artifact roots; reject YAML/YML there by default and allow only the exact canonical path after the shared validator passes, with no other evidence exception. Enforce every Unit 3f invariant, root confinement, and dry-run/capture/validate.
**Output**: Deterministic installed-app capture controls and fail-closed safe manifest runner/validator.
**Acceptance**: All four Unit 3f suites—launch, matrix-runner/shared-matrix-validator, per-cell-validator, and Swift repository-hygiene contracts—turn green; malformed/aliased/unknown/duplicate/mismatched manifests fail before subprocess execution; existing route captures remain green.

### ✅ Unit 3h: iPhone, iPad, and macOS visual capture
**What**: Run `ruby scripts/run-shopping-visual-matrix.rb --manifest worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml --artifact-base /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/visual-qa --mode dry-run`, inspect 62 commands, then rerun with `--mode capture`. The manifest encodes 22 iPhone, 20 iPad, and 20 macOS rows with unique slug/root and one selected platform. Dense normal fixture has >=12 items, >=5 categories, and two two-line names.
**Output**: Per-cell directories with PNG, `shopping-visual-cell.json`, selected-platform accessibility proof, log, and ledger entry.
**Acceptance**: All 62 commands produce exactly 62 of each declared artifact kind at unique roots; no per-cell manifest claims another platform.

### ✅ Unit 3i: Visual remediation, recapture, and cold review
**What**: Run matrix validate against the exact Unit 3h Desk root, inspect 62 PNGs, ledger/fix/recapture, rerun launch/matrix/per-cell/hygiene contracts, and obtain cold PASS. Runner fails on missing/duplicate/extra/mismatched PNG/cell-manifest/proof/log. Commit/push the matrix and execution snapshot in the product branch; commit/push all 62 artifacts of each kind, cross-platform local-validation manifest, ledger, and cold review under the Desk task before Unit 4a.
**Output**: Desk-owned final screenshots, per-cell manifests, cross-platform design-review manifest, closed ledger, and reviewer verdict; product-owned canonical matrix.
**Acceptance**: Exactly 62 manifests and their proofs validate; no ledger item remains `ready` or `needs reviewer gate`; automated metrics pass; cold reviewer returns PASS; generated evidence is absent from product `git ls-files`, and the Desk evidence commit is pushed before PR sync/review.

### ✅ Unit 4a: Pre-PR sync and branch validation
**What**: `git fetch origin main`, merge `origin/main`, resolve conflicts, then rerun Unit 3e exact commands and run `ruby scripts/audit-native-validation-artifacts.rb --repo-hygiene-only --artifact-root /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/audit/pre-pr --manifest /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/audit/pre-pr/manifest.json` with its default full `git ls-files` input. Cold-review `git diff origin/main...HEAD` plus all validation artifacts. Before PR creation, update product planning/doing as merged execution snapshots: doing remains `in-progress`, records completed implementation/visual units/evidence, and points post-merge terminal truth to Desk.
**Output**: Synced branch, complete validation evidence, reviewer verdict.
**Acceptance**: Branch is clean, pushed, green, and reviewer-converged against current main.

### 🔄 Unit 4b: PR, CI, review, and merge
**What**: Open the focused PR, run `gh pr checks <pr> --watch`, repair review/CI findings, verify `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`, and merge under repository policy.
**Output**: Merged PR URL and merged SHA.
**Acceptance**: PR is merged with `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` green on its reviewed head.

### ⬜ Unit 4c: Exact-main and internal TestFlight verification
**What**: From persistent base checkout, require base/task clean, fetch merged `origin/main`, and create `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main` detached at the exact 40-character merged SHA; require clean status and exact `HEAD`. Set `artifacts=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/exact-main`, run `mkdir -p "$artifacts"`, then rerun every Unit 3e command in that worktree with this override so validation never writes into exact-main. Also create `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/audit/exact-main` before running `ruby scripts/audit-native-validation-artifacts.rb --repo-hygiene-only --artifact-root /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/audit/exact-main --manifest /Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/audit/exact-main/manifest.json` there with default full `git ls-files`, and require exact-main status to remain clean afterward. Use exactly `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts` as the durable Desk artifact root and write `testflight-release-notes.json` there with exactly `{ "schemaVersion": 1, "sourceSha": "<merged-sha>", "notes": "<non-empty shopping-list release notes, at most 4000 characters>" }`. From exact-main run `SPOONJOY_TESTFLIGHT_SOURCE_SHA=<merged-sha> SPOONJOY_TESTFLIGHT_RELEASE_NOTES_PATH=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/testflight-release-notes.json SPOONJOY_TESTFLIGHT_ARTIFACT_DIR=/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/ci-testflight scripts/ci-publish-testflight.sh`.
**Output**: Exact-main logs, exact-schema release notes, and `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/ci-testflight/testflight-publish-summary.json`.
**Acceptance**: Required checks are green at exact `HEAD == sourceSha == merged SHA`; publish summary has exactly the keys `sourceSha`, `releaseNotesArtifact`, `bundleId`, `appId`, `buildNumber`, `buildId`, `buildBetaDetailId`, `groupName`, `groupId`, `internalBuildState`, `testerCount`, and `testersNotifiedRequested`, with that exact `sourceSha`, exact absolute release-notes path, `buildNumber` as a non-empty decimal string, non-empty `buildId` and `buildBetaDetailId`, `groupName == "Spoonjoy Internal"`, numeric `testerCount > 0`, and `internalBuildState == "IN_BETA_TESTING"`.

### ⬜ Unit 4d: Cleanup and durable closure
**What**: Treat product planning/doing files in merged SHA as immutable execution snapshots; Desk task/card/artifacts are the sole post-merge terminal/evidence state (no second product PR). Preflight from `/Users/arimendelow/Projects/spoonjoy-apple`: base, task, and exact-main worktrees all clean; exact-main HEAD equals merged SHA; the Unit 3i product snapshot/matrix commit is ancestor of merged SHA; the separately recorded Desk visual-evidence commit plus exact-main/TestFlight artifacts exist and are committed/pushed. Then, in order from the base checkout, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main`, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair`, delete local task branch, conditionally delete remote task branch, and run `git worktree list` plus local/remote ref scans. Finally mark only the Desk task terminal and push Desk `main`.
**Output**: Cleanup log and terminal durable task records.
**Acceptance**: Three-worktree clean/evidence preflight passed; product-repo canonical matrix and execution snapshots are contained in merged SHA with no tracked generated evidence; all generated visual/validation/TestFlight evidence is pushed in Desk; exact-main and task worktrees plus local/remote task refs are absent; persistent base checkout remains clean.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **Artifacts**: Product repo stores only planning/doing Markdown plus the exact safely validated canonical matrix path named in Unit 3f; every other worker-task YAML/YML and all generated logs, JSON, screenshots, proofs, manifests, ledgers, review verdicts, and other evidence are rejected from product git. Unit 0–4d evidence lives under `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/artifacts/` and is committed/pushed in Desk; exact-main validation uses its `exact-main/` child
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-08-21 17:44 Created from reviewer-approved planning doc.
- 2026-08-21 20:02 Execution unlocked after two consecutive provenance-locked CLEAN scrutiny verdicts at `44d70752`; Unit 0 started.
- 2026-08-21 20:08 Unit 0 complete: fresh branch/toolchain/source-fidelity baseline recorded; 13 shopping parity tests and release capability preflight passed; Desk evidence pushed.
- 2026-08-21 20:59 Unit 1 coordination slice pushed at `c9b429b5`: shopping mutations now apply optimism immediately, serialize remote writes FIFO, avoid shell bootstrap, reconcile with a targeted shopping read, preserve later optimistic work across rejection, and retain confirmed writes when the reconciliation read fails. Four coordinator tests, 13 shopping parity tests, 74 live-store tests, and the iOS app-target build are green; recovery-intent/journal coverage remains in progress.
- 2026-08-21 21:42 Mutation hardening pushed through `92f14d19`: rapid plans compose from coordinator-owned latest state, an offline transition latches later work into the already-applied persistence path without additional remote writes, definite solo rejection rolls back locally, and rejection with later optimism performs one targeted read while preserving the later state. Six focused coordinator tests are green.
- 2026-08-21 21:42 Presentation and surface work pushed through `92f14d19`: the shopping route launches in All, exposes Need/Basket/All counts and fixed web-category ordering, keeps checked rows in Basket/All category sections, provides mode-specific empty states and an always-reachable composer, retains native swipe/context deletion, and uses large inline check targets without full-screen mutation loading. Five presentation-model tests and native UI contract tests are green.
- 2026-08-21 21:42 Installed-app visual captures passed automated design review for normal and all-complete states on iPhone, iPad, and macOS. Exact-head validation at `92f14d19` passed 641 tests in 58 suites, iOS and macOS app-target builds, and the final native scenario verifier. Evidence is stored under the Desk task artifact root; independent cold review and PR/release gates remain in progress.
- 2026-08-22 03:57 Units 1a–3i and 4a complete at `b4d8bf4f`: 693 Swift tests pass with exact 100.00% SpoonjoyCore coverage (28,403/28,403); the focused coordinator suite passes 49/49; the canonical shopping visual matrix passes 62/62; the source-bound native route matrix passes 34/34 with final validation 40 passed / 0 failed / 0 blocked; cold implementation review converged clean. PR #60 is open and Unit 4b is in progress.
