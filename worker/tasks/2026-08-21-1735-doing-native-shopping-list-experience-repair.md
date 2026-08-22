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
**What**: Add failing tests in `ShoppingSurfaceParityTests.swift` and `NativeLiveStoreTests.swift` for a `NativeShoppingMutationCoordinator` owned by `NativeLiveAppStore` with monotonic generation, serialized `perform(plan:)`, latest-generation rollback snapshot, and `ShoppingMutationFeedback` (`pendingItemIDs`, `pendingAction`, `itemErrors`, `actionError`). Test error classes exactly: `.offline` queues; HTTP 400...499 except 408/409/425/429 and `.invalidRequestURL` are definite; cancellation is silent; network/non-HTTP/non-JSON/malformed/408/409/425/429/5xx are indeterminate. Test immediate online optimistic publication, no root bootstrap, shopping-only follow-up read, exclusive optimistic ownership for queued/fallback paths, and delayed/out-of-order behavior.
**Output**: Red test commit with outbound mutation/read assertions and shell-state assertions.
**Acceptance**: New tests fail for the intended absent coordinator/reconciliation behavior while pre-existing shopping tests remain green.

### ⬜ Unit 1b: Localized mutation coordination — implementation
**What**: Implement `NativeShoppingMutationCoordinator` and `ShoppingMutationFeedback` in `Sources/SpoonjoyCore/Features/Shopping/ShoppingMutationCoordinator.swift`; `NativeLiveAppStore` owns one coordinator and exposes feedback. Assign generation before enqueue; serialize mutation+read; derive online optimistic state by applying the plan's `offlineFallbackMutation` to current state; snapshot immediately before applying. `queueMutation` remains sole owner for queued/fallback optimism. On definite failure restore the snapshot only when generation is latest; with later generation, or on indeterminate failure, issue a targeted read and apply it only when its generation is latest. If that read fails, retain optimism and expose retryable error. `setItemChecked`/`deleteItem` use `itemErrors` plus `retryActionsByItemID`; add/add-from-recipe/clear actions use `actionError` plus `retryAction`; the coordinator retains those original `ShoppingSurfaceAction` payloads and retry replaces only `clientMutationID` with a fresh UUID. Wire `PlatformNavigationView.swift` feedback/retry closures; cancellation clears pending silently.
**Output**: Online writes rebase optimistically on latest store state, avoid `bootstrap()`, perform targeted shopping read reconciliation, and expose localized reconciliation/failure state.
**Acceptance**: Unit 1a passes; captured outbound requests are exact; no ordinary shopping mutation applies `.restoringCache`; builds have no warnings.

### ⬜ Unit 1c: Localized mutation coordination — coverage and refactor
**What**: Cover empty-plan, offline fallback, queue failure, non-offline failure, read-reconciliation failure, stale-generation, and concurrent-write branches; refactor without behavior change.
**Output**: Coverage and targeted/full-test logs.
**Acceptance**: 100% coverage on new mutation coordination code; all Swift tests and native scenario checks remain green.

### ⬜ Unit 2a: Market modes and category semantics — tests
**What**: Add failing pure-model tests in `Tests/SpoonjoyCoreTests/ShoppingPresentationModelTests.swift` for `ShoppingPresentationModel`: Need/Basket/All counts, fixed market rank, stable same-category order, explicit category validation, name fallback, completed sections, invalid-filter reset data, duplicate handling, and empty/all-complete variants.
**Output**: Red tests in `Tests/SpoonjoyCoreTests/ShoppingPresentationModelTests.swift`.
**Acceptance**: Tests fail on missing presentation model behavior and precisely match web helper/route semantics.

### ⬜ Unit 2b: Market modes and category semantics — implementation
**What**: Add the minimal Sendable/Equatable `ShoppingPresentationModel` in `Sources/SpoonjoyCore/Features/Shopping/ShoppingPresentationModel.swift`; `ShoppingSurfaceViewModel.swift` exposes it, while `ShoppingListState.swift` remains canonical server/domain data.
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
**What**: Run `scripts/generate-xcode-project.rb`, `swift test`, `swift test --enable-code-coverage`, capture `coverage_json="$(swift test --show-codecov-path)"`, then `ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include Sources/SpoonjoyCore`; run `scripts/verify-native-scenarios.sh --stage final --output <artifacts>/scenario-final.json`, `scripts/bundle-check.sh`, and `scripts/validate-native-local.sh --artifact-root <artifacts>/native-local`. The local matrix owns warning-as-error and exact iPhone/iPad/macOS BootstrapDebug builds.
**Output**: Validation logs in artifacts.
**Acceptance**: Required local checks are green, modified/new logic is fully covered, and all three platform layouts compile without warnings.

### ⬜ Unit 3e: Shopping screenshot harness — tests
**What**: Add failing cases to `scripts/check-launch-screenshot-contract.rb` for new `capture-native-screenshots.sh` arguments: `--capture-platform iphone|ipad|macos`, `--shopping-variant normal|empty|all-complete|duplicate|conflict|offline-queued|pending|row-error`, `--shopping-mode need|basket|all`, `--shopping-category all|Produce`, `--dynamic-type default|accessibility5`, `--ios-orientation portrait|landscape`, and `--macos-window 900x620|1440x900`. Add failing `scripts/check-shopping-visual-matrix-contract.rb` tests for canonical manifest `worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml` and absent runner `scripts/run-shopping-visual-matrix.rb`. Tests require `Psych.safe_load(..., permitted_classes: [], permitted_symbols: [], aliases: false)`, schemaVersion 1, expectedRows 62, four expectedArtifactsPerKind values of 62, platform counts 22/20/20, required row keys, allowed values, unique IDs/slugs/roots, and argv byte-for-byte equality with arguments recomputed from row fields.
**Output**: Red screenshot/manifest runner contract tests covering every option, invalid YAML/schema/row/count/duplicate/argv case, dry-run command emission, and capture/validate modes.
**Acceptance**: Both contract suites fail because the exact CLI/state wiring and safe manifest runner/validator are absent.

### ⬜ Unit 3f: Shopping screenshot harness — implementation
**What**: Implement the exact Unit 3e arguments in `scripts/capture-native-screenshots.sh`; `--capture-platform` launches/captures only that row's platform. Implement `scripts/run-shopping-visual-matrix.rb` as the sole matrix parser/runner: safe-load the canonical committed YAML, enforce every Unit 3e invariant before executing anything, recompute and compare each argv, resolve each unique artifactRoot beneath the doing artifacts directory, and support `--mode dry-run|capture|validate`. Capture mode invokes `capture-native-screenshots.sh` with row args plus declared slug/root; validate mode checks the exact four row artifact paths and invokes `validate-design-review.rb`. Canonical fixture data remains `Sources/SpoonjoyCore/Fixtures/shopping-list-fixture.json` with deterministic overlays.
**Output**: Deterministic installed-app capture controls and fail-closed safe manifest runner/validator.
**Acceptance**: Both Unit 3e suites turn green; malformed/aliased/unknown/duplicate/mismatched manifests fail before subprocess execution; existing route captures remain green.

### ⬜ Unit 3g: iPhone, iPad, and macOS visual capture
**What**: Run `ruby scripts/run-shopping-visual-matrix.rb --manifest worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml --artifact-base worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair --mode dry-run`, inspect 62 commands, then rerun with `--mode capture`. The manifest encodes 22 iPhone, 20 iPad, and 20 macOS rows with unique slug/root and one selected platform. Dense normal fixture has >=12 items, >=5 categories, and two two-line names.
**Output**: Per-cell screenshot directories with PNG, design-review manifest, accessibility proof, and logs; initial ledger entries.
**Acceptance**: All 62 row commands exit green and produce exactly 62 PNGs, 62 `design-review.json` manifests, 62 platform accessibility proofs, and 62 screenshot logs at the row-declared unique roots; IDs/slugs/roots are unique and every capture is recorded in the ledger.

### ⬜ Unit 3h: Visual remediation, recapture, and cold review
**What**: First run `ruby scripts/run-shopping-visual-matrix.rb --manifest worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair/shopping-visual-matrix.yaml --artifact-base worker/tasks/2026-08-21-1735-doing-native-shopping-list-experience-repair --mode validate`. Inspect all 62 runner-declared PNGs with `view_image`, record each in the ledger, fix every in-scope finding, rerun the validator plus both Unit 3e contract suites, recapture fixed rows through runner capture mode, and obtain a cold visual PASS. Runner validation fails on missing, duplicate, extra, or mismatched PNG/manifest/proof/log. Preserve and commit the canonical matrix, all 62 artifacts of each kind, and ledger before Unit 4a.
**Output**: Final screenshots, design-review manifests, closed `visual-qa-ledger.md`, and reviewer verdict.
**Acceptance**: Exactly 62 manifests and their proofs validate; no ledger item remains `ready` or `needs reviewer gate`; automated metrics pass; cold reviewer returns PASS; the branch commit containing all visual evidence is pushed before PR sync/review.

### ⬜ Unit 4a: Pre-PR sync and branch validation
**What**: `git fetch origin main`, merge `origin/main`, resolve conflicts, then rerun Unit 3d exact commands; cold-review `git diff origin/main...HEAD` plus all validation artifacts. Before PR creation, update the product planning/doing files as merged execution snapshots: doing remains `in-progress`, records completed implementation/visual units and their evidence, and explicitly points post-merge/TestFlight/cleanup terminal truth to the Desk task; do not promise a post-merge product-doc commit.
**Output**: Synced branch, complete validation evidence, reviewer verdict.
**Acceptance**: Branch is clean, pushed, green, and reviewer-converged against current main.

### ⬜ Unit 4b: PR, CI, review, and merge
**What**: Open the focused PR, run `gh pr checks <pr> --watch`, repair review/CI findings, verify `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`, and merge under repository policy.
**Output**: Merged PR URL and merged SHA.
**Acceptance**: PR is merged with `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` green on its reviewed head.

### ⬜ Unit 4c: Exact-main and internal TestFlight verification
**What**: From persistent base checkout `/Users/arimendelow/Projects/spoonjoy-apple`, preflight the base and task worktrees are clean and create detached exact-main worktree `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main` at `<merged-sha>`; preflight its HEAD equals merged SHA and status is clean. Rerun Unit 3d there. Write Desk artifact `testflight-release-notes.json` with schema `{sourceSha,notes}`. From exact-main run `SPOONJOY_TESTFLIGHT_SOURCE_SHA=<merged-sha> SPOONJOY_TESTFLIGHT_RELEASE_NOTES_PATH=<notes-json> SPOONJOY_TESTFLIGHT_ARTIFACT_DIR=<desk-artifacts>/ci-testflight scripts/ci-publish-testflight.sh`; accept only summary proving group `Spoonjoy Internal`, testerCount > 0, and `IN_BETA_TESTING`.
**Output**: Exact-main logs and TestFlight publish summary.
**Acceptance**: Required checks are green for merged SHA and the internal build is available in beta testing.

### ⬜ Unit 4d: Cleanup and durable closure
**What**: Treat product planning/doing files in merged SHA as immutable execution snapshots; Desk task/card/artifacts are the sole post-merge terminal/evidence state (no second product PR). Preflight from `/Users/arimendelow/Projects/spoonjoy-apple`: base, task, and exact-main worktrees all clean; exact-main HEAD equals merged SHA; Unit 3h evidence commit is ancestor of merged SHA; Desk exact-main/TestFlight artifacts exist and are committed/pushed. Then, in order from the base checkout, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair-exact-main`, remove `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair`, delete local task branch, conditionally delete remote task branch, and run `git worktree list` plus local/remote ref scans. Finally mark only the Desk task terminal and push Desk `main`.
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
