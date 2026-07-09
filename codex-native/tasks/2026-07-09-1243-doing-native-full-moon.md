# Doing: Spoonjoy Native Full Moon

**Status**: drafting
**Execution Mode**: direct
**Created**: 2026-07-09 12:49
**Planning**: ./2026-07-09-1243-planning-native-full-moon.md
**Artifacts**: ./2026-07-09-1243-doing-native-full-moon/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts only when the user explicitly requested interactive per-unit approval; otherwise convert this to `spawn` or `direct` unless a hard exception is present
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Make Spoonjoy native feel like a finished, high-taste Apple app rather than a TestFlight proof harness: beautiful, honest with data, native where it matters, and continuously verifiable through screenshots, telemetry, and TestFlight feedback.

## Upstream Work Items
- None

## Completion Criteria
- [ ] `/Users/arimendelow/Projects/spoonjoy-apple` is the clean canonical native checkout, with stale worktrees retired or intentionally documented.
- [ ] Screenshot capture and visual QA can run across the core iOS and macOS route matrix without hanging, with artifacts saved under task docs.
- [ ] Every core route has fresh iOS and macOS screenshot evidence reviewed against the Spoonjoy native design language, with an absurdity ledger closed.
- [ ] Every visual route capture produces a valid `design-review.json` or valid `design-review-blocked.json`; success artifacts include app-emitted iOS and macOS accessibility proofs through `SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH`.
- [ ] Dynamic Type, VoiceOver labels, keyboard navigation, Reduce Motion, contrast, route-specific hierarchy evidence, target size, text fit, no-tiny-cluster checks, and `OfflineStatusView` proof pass fail-closed validation.
- [ ] Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Cookbook Detail, Shopping, Search, Capture, Settings, auth/offline/error states, and macOS shell show no overlapping text, false unavailable flashes, production-facing demo labels, or default-looking placeholder imagery.
- [ ] System blue, generic grouped-card styling, oversized dock chrome, and loud non-critical banners are removed or confined to appropriate native/system contexts.
- [ ] Recipe and cook-mode structure matches the web product language where intentional, with native controls only where they improve the workflow.
- [ ] Offline, loading, empty, stale, sync-failed, unauthenticated, and blocked-provider states are honest, graceful, telemetry-backed, and tested.
- [ ] TestFlight feedback autopilot has a transparent ledger from feedback receipt through diagnosis, fix, build number, and confirmation state.
- [ ] Latest TestFlight feedback screenshots and comments are reconciled before each TestFlight publish, with no actionable unhandled feedback left behind.
- [ ] At least one new internal TestFlight build is uploaded, processed `VALID`, attached to `Spoonjoy Internal`, verified with nonzero group tester count, and has build beta detail `internalBuildState` of `IN_BETA_TESTING`.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass

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

### ⬜ Unit 0: Setup/Research
**What**: Confirm repo/worktree cleanup, pull latest TestFlight feedback status, capture current app evidence, and refresh `AUTOPILOT-STATE.md` with exact branch, validation, and next-action state.
**Output**: Setup log, feedback status JSON/text, current state update, and initial absurdity ledger in `codex-native/tasks/2026-07-09-1243-doing-native-full-moon/`.
**Acceptance**: `git worktree list --porcelain` shows only canonical `main` plus this worktree; `scripts/testflight-feedback-autopilot.mjs status --plain`, `doctor`, and `reconcile --dry-run` outputs are saved; no actionable unhandled TestFlight feedback is ignored.

### ⬜ Unit 1a: Visual Validation Harness — Tests
**What**: Add or extend tests/contracts for `scripts/capture-native-screenshot-matrix.sh`, `scripts/capture-native-screenshots.sh`, `scripts/check-launch-screenshot-contract.rb`, and `scripts/validate-native-local.sh` so route capture has deterministic timeouts, records timeout/blocker artifacts, cleans per-route DerivedData, and never hangs silently after `simctl launch` or macOS launch.
**Output**: Failing tests or contract assertions that reproduce the current hang class and missing timeout behavior.
**Acceptance**: The new/updated tests fail before implementation with an assertion tied to missing timeout/blocker behavior, not an incidental shell error.

### ⬜ Unit 1b: Visual Validation Harness — Implementation
**What**: Implement fail-closed timeout and cleanup behavior for iOS/macOS launch, route capture, screenshot matrix aggregation, and native local validation using the existing `design-review-blocked.json`/blocker schema.
**Output**: Updated scripts and validation contracts.
**Acceptance**: Unit 1a tests pass; `scripts/capture-native-screenshot-matrix.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1b-screenshots --unit-slug unit-1b` completes or produces valid blocker artifacts without hanging.

### ⬜ Unit 1c: Visual Validation Harness — Coverage & Refactor
**What**: Refactor harness changes for readability, edge cases, and coverage; ensure timeout, success, blocker, missing-design-review, and cleanup paths are covered.
**Output**: Refactored scripts/tests and coverage logs.
**Acceptance**: Relevant Swift/Ruby/shell contract tests pass; `scripts/validate-native-local.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1c-validation` reaches a terminal matrix result or canonical blocker.

### ⬜ Unit 1d: Visual Validation Harness — Visual QA Dogfood
**What**: Run the full screenshot route matrix and inspect produced iOS/macOS screenshots and `design-review.json` artifacts for Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping, Search, Capture, and Settings.
**Output**: Screenshot route matrix JSON, screenshots, design-review artifacts, and absurdity ledger entries.
**Acceptance**: No route hangs; every route has success or canonical blocker; any visual issue discovered is entered into the absurdity ledger for Units 2-5.

### ⬜ Unit 2a: Shared Taste Substrate — Tests
**What**: Add failing tests/static checks for Spoonjoy theme token use, banned system blue leakage, SpoonDock visual weight, status-banner severity roles, loading transition policy, placeholder/no-photo policy, text-fit requirements, and rounded-corner semantics in primary surfaces.
**Output**: Failing contract tests covering `KitchenTableTheme`, `SpoonDock`, `SpoonjoyToolbar`, `OfflineStatusView`, shared loading/media components, and primary view sources.
**Acceptance**: Tests fail on at least one current violation such as system blue, oversized dock chrome, loud non-critical banner treatment, or production-facing placeholder language.

### ⬜ Unit 2b: Shared Taste Substrate — Implementation
**What**: Replace leaking system colors/chrome with Spoonjoy theme tokens, quiet non-critical banners, rebalance or replace mobile dock affordances with native-safe controls, add eager image/loading transitions, and implement appetizing no-photo states that never pretend default images are real food.
**Output**: Updated shared theme, shell, dock, toolbar, banner, loading, and media/no-photo components.
**Acceptance**: Unit 2a tests pass; primary controls and banners use role-bound Spoonjoy colors; dock/navigation no longer overpowers route content; no production-facing default image label remains.

### ⬜ Unit 2c: Shared Taste Substrate — Coverage & Refactor
**What**: Cover all new state branches and refactor shared UI helpers into existing Spoonjoy native patterns without adding decorative card wrappers.
**Output**: Coverage report and refactored shared components.
**Acceptance**: 100% coverage on new code; no warnings; `scripts/check-native-design-language.rb`, `scripts/check-native-web-palette-contract.rb`, `scripts/check-native-shell-contract.rb`, and `scripts/check-design-accessibility-contract.rb` pass.

### ⬜ Unit 2d: Shared Taste Substrate — Visual QA Dogfood
**What**: Re-run route screenshots and visual review focused on palette, dock/chrome, banners, image transitions, no-photo states, text fit, and overlap.
**Output**: Fresh screenshots, design-review artifacts, and closed or routed absurdity ledger items for shared UI.
**Acceptance**: All shared-substrate absurdities are fixed or become explicit downstream route tasks; automated visual metrics still pass.

### ⬜ Unit 3a: Recipe, Kitchen, and Cook Mode Fidelity — Tests
**What**: Add failing tests for web-structure fidelity and native behavior in `KitchenView`, `RecipesView`, `RecipeDetailView`, `CookModeView`, `SpoonCookLogView`, and related view models/contracts.
**Output**: Failing tests for kitchen lead/index/shelf structure, recipe detail hero/provenance/yield/actions/steps/ingredients/cooks, cook-mode focused-step grammar, progress persistence, timer/control layout, and absence of false "recipe unavailable" loading flashes.
**Acceptance**: Tests fail against current gaps or previously reported issues, including one assertion that navigation-to-detail shows loading/progress instead of transient unavailable copy.

### ⬜ Unit 3b: Recipe, Kitchen, and Cook Mode Fidelity — Implementation
**What**: Rework Kitchen, Recipes, Recipe Detail, Cook Mode, and cook logging to match Spoonjoy web language while using native navigation, toolbars, steppers, toggles, progress, lists, sheets, and safe-area actions where they improve use.
**Output**: Updated recipe/kitchen/cook-mode views and models.
**Acceptance**: Unit 3a tests pass; overlapping title/hero issues, unnecessary "Open"/"Used" style labels, false unavailable flashes, and dense kitchen controls are removed.

### ⬜ Unit 3c: Recipe, Kitchen, and Cook Mode Fidelity — Coverage & Refactor
**What**: Refactor route-specific helpers, cover edge cases for empty recipe lists, missing covers, stale/offline recipe detail, persisted progress, scale changes, and timer states.
**Output**: Coverage logs and route helpers aligned with existing patterns.
**Acceptance**: 100% coverage on new code; `scripts/check-kitchen-recipe-surfaces.rb`, `scripts/check-cook-mode-parity-surfaces.rb`, `scripts/check-recipe-action-surfaces.rb`, and relevant Swift tests pass.

### ⬜ Unit 3d: Recipe, Kitchen, and Cook Mode Fidelity — Visual QA Dogfood
**What**: Manually inspect and capture iOS/macOS Kitchen, Recipes, Recipe Detail, Cook Mode, and cook logging, including narrow phone, large Dynamic Type, reduced motion, stale/offline states, and navigation transitions.
**Output**: Screenshots, design-review artifacts, and closed absurdity ledger for these routes.
**Acceptance**: No overlap, snapping, false unavailable flash, ugly fallback image, or control crowding remains in these routes.

### ⬜ Unit 4a: Shopping, Search, Capture, and Settings Reality — Tests
**What**: Add failing tests for shopping receipt grammar, grouped/source-aware rows, duplicate handling, offline queue honesty, native search scopes/results, capture/import truthfulness, and quiet settings/auth/environment/APNs state.
**Output**: Failing tests over `ShoppingListView`, `ReceiptListView`, `SearchView`, `CaptureDraftView`, `SettingsView`, `NotificationAPNsSettingsView`, and relevant core models.
**Acceptance**: Tests fail against at least one current gap such as capture dead-end copy, generic row/chrome language, search scope proof, or weak offline queue state.

### ⬜ Unit 4b: Shopping, Search, Capture, and Settings Reality — Implementation
**What**: Rework shopping, search, capture, and settings to be native, honest, and Spoonjoy-specific: receipt/list affordances, native search scopes, capture draft lifecycle, MCP/agent import reality, retryable blockers, and quiet settings forms.
**Output**: Updated views, models, and contracts for shopping/search/capture/settings.
**Acceptance**: Unit 4a tests pass; no "Ouro draft" product-facing capture nonsense remains; no dead-end import path claims server writes before backend support exists.

### ⬜ Unit 4c: Shopping, Search, Capture, and Settings Reality — Coverage & Refactor
**What**: Cover edge cases for empty shopping, checked/all-complete shopping, duplicate candidates, typed search, no results, offline capture retry, blocked-provider capture, signed-out settings, APNs denied/unknown/granted states.
**Output**: Coverage logs and refactored route helpers.
**Acceptance**: 100% coverage on new code; `scripts/check-cook-shopping-surfaces.rb`, `scripts/check-search-capture-settings-surfaces.rb`, `scripts/check-notification-apns-surfaces.rb`, and related Swift tests pass.

### ⬜ Unit 4d: Shopping, Search, Capture, and Settings Reality — Visual QA Dogfood
**What**: Capture and inspect iOS/macOS Shopping, Search, Capture, Settings, and notification settings across normal, empty, offline, and blocked states.
**Output**: Screenshots, design-review artifacts, and closed absurdity ledger for these routes.
**Acceptance**: No generic placeholder copy, crowding, overlap, or unverified blocker state remains in these routes.

### ⬜ Unit 5a: Native Integrations and Telemetry — Tests
**What**: Add failing tests for App Intents, Spotlight, Universal Links, auth/OAuth callback handling, offline queue telemetry, Sign in with Apple telemetry, feedback-led diagnostics, and app-emitted screenshot accessibility proofs.
**Output**: Failing tests over `SpoonjoyAppIntents.swift`, `SpoonjoySpotlightIndexer.swift`, `DeepLinkRouter`, auth/session code, native telemetry surfaces, and feedback tooling.
**Acceptance**: Tests fail on missing or insufficiently proved telemetry/integration behavior rather than merely checking symbols exist.

### ⬜ Unit 5b: Native Integrations and Telemetry — Implementation
**What**: Fill telemetry/proof gaps, ensure integration state is observable, harden auth/link/offline telemetry, and keep iOS 27/macOS 27 availability gates aligned with product baseline.
**Output**: Updated native integration code, telemetry payloads, and proof emitters.
**Acceptance**: Unit 5a tests pass; Sign in with Apple/OAuth/offline/provider failures produce actionable telemetry without printing secrets.

### ⬜ Unit 5c: Native Integrations and Telemetry — Coverage & Refactor
**What**: Cover all integration branches, adapter request shapes, error paths, purge paths, and no-secret logging paths.
**Output**: Coverage report and refactored native integration helpers.
**Acceptance**: 100% coverage on new code; `scripts/check-app-intents-contract.rb`, `scripts/validate-aasa.rb`, `scripts/verify-native-scenarios.sh`, and relevant Swift tests pass.

### ⬜ Unit 5d: Native Integrations and Telemetry — Visual QA Dogfood
**What**: Verify visible auth/offline/integration states in simulator/macOS and ensure route screenshots include app-emitted proof artifacts.
**Output**: Screenshots, proof JSON, telemetry sample logs with secrets redacted, and closed ledger items.
**Acceptance**: Failure states are observable and human-readable, and no generated artifact leaks secrets, API keys, JWTs, passwords, or private key paths.

### ⬜ Unit 6a: TestFlight Feedback Transparency — Tests
**What**: Add failing tests/contracts for `scripts/testflight-feedback-autopilot.mjs` status/doctor/reconcile output, fixed-unconfirmed state, event ledger, slugger/Ouro handoff, screenshot download records, and build-confirmation lifecycle.
**Output**: Failing tests or fixture-based script assertions for transparent feedback state.
**Acceptance**: Tests fail on opaque or incomplete status, especially when feedback is `fixed_unconfirmed` without build/confirmation guidance.

### ⬜ Unit 6b: TestFlight Feedback Transparency — Implementation
**What**: Improve the feedback autopilot ledger/status UX and machine-readable state so agents and slugger can explain what happened, what build fixed it, whether tester confirmation is pending, and what evidence exists.
**Output**: Updated feedback autopilot script/docs and, if needed, slugger/Ouro event payload fields.
**Acceptance**: Unit 6a tests pass; `status --plain`, `doctor`, and `reconcile --dry-run` give a clear, evidence-backed picture without secrets.

### ⬜ Unit 6c: TestFlight Feedback Transparency — Coverage & Refactor
**What**: Cover duplicate feedback, screenshot-only feedback, crash feedback, stale build feedback, fixed-unconfirmed feedback, webhook delivery, tunnel/listener health, and fallback handoff paths.
**Output**: Coverage logs and refactored feedback automation code.
**Acceptance**: 100% coverage on new code; feedback automation tests pass; no secrets printed.

### ⬜ Unit 6d: TestFlight Feedback Transparency — Live Dogfood
**What**: Run live feedback status/doctor/reconcile, inspect latest event directories, and send a controlled slugger/Ouro test event if the tooling supports a safe dry-run/test path.
**Output**: Live logs and ledger proof saved to artifacts.
**Acceptance**: The feedback loop is either live and transparent or has a canonical blocker with owner action; no actionable TestFlight feedback remains unhandled before publishing.

### ⬜ Unit 7a: macOS Native Companion — Tests
**What**: Add failing tests/static checks for macOS-specific navigation, split-view/toolbar/menu behavior, keyboard affordances, desktop recipe/cookbook editing, and absence of mobile-only dock patterns on macOS.
**Output**: Failing tests for macOS shell and route adaptations.
**Acceptance**: Tests fail on at least one macOS surface that still behaves like a stretched phone app or lacks desktop-native affordances.

### ⬜ Unit 7b: macOS Native Companion — Implementation
**What**: Rework macOS shell and route affordances toward a desktop companion: split navigation, keyboard commands, toolbar/menu actions, recipe/cookbook management, search/import workflows, and quiet desktop forms.
**Output**: Updated macOS-specific SwiftUI shell/routes.
**Acceptance**: Unit 7a tests pass; macOS no longer relies on mobile dock grammar for primary navigation.

### ⬜ Unit 7c: macOS Native Companion — Coverage & Refactor
**What**: Cover macOS branches, command handling, selected-route behavior, window sizing, keyboard commands, and route state restoration.
**Output**: Coverage logs and refactored platform-specific helpers.
**Acceptance**: 100% coverage on new code; macOS build/smoke checks pass without warnings.

### ⬜ Unit 7d: macOS Native Companion — Visual QA Dogfood
**What**: Capture and inspect macOS Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping, Search, Capture, and Settings at desktop sizes.
**Output**: macOS screenshot set, design-review artifacts, and closed absurdity ledger.
**Acceptance**: macOS surfaces feel desktop-native, not mobile-stretched, and pass visual/accessibility contracts.

### ⬜ Unit 8a: Full Validation and Release Prep — Tests
**What**: Run the full local validation stack and add missing release-prep tests/contracts for build number bumping, distribution kit checks, TestFlight publish preflight, and no-secret output.
**Output**: Failing tests/contracts for any release-prep gap found.
**Acceptance**: Any missing release guard fails before implementation; existing validation output is saved to artifacts.

### ⬜ Unit 8b: Full Validation and Release Prep — Implementation
**What**: Fix release-prep gaps, bump the next TestFlight build number, update release notes/internal build metadata if needed, and ensure docs reflect exact commands.
**Output**: Updated project/distribution files and docs.
**Acceptance**: Unit 8a tests pass; `scripts/check-apple-distribution-kit.sh` passes.

### ⬜ Unit 8c: Full Validation and Release Prep — Coverage & Refactor
**What**: Run full tests, coverage, design/accessibility contract, scenario verifier, app bundle, iOS simulator smoke, macOS smoke, screenshot matrix, and warning scan.
**Output**: Complete validation logs under artifacts.
**Acceptance**: All required local validations pass or produce canonical blockers; no warnings; 100% coverage on new code.

### ⬜ Unit 8d: Full Validation and Release Prep — Visual QA Dogfood
**What**: Final route-by-route visual pass on iOS and macOS with screenshot matrix artifacts and absurdity ledger closure.
**Output**: Final screenshot packet and closed ledger.
**Acceptance**: No visual, loading, overlap, placeholder, or app-language blocker remains.

### ⬜ Unit 9: Merge, Publish, and Verify TestFlight
**What**: Push the branch, open PR, run cold self-review, resolve findings, merge to `main`, package/upload/publish the next internal iOS TestFlight build, and verify App Store Connect state.
**Output**: PR/merge evidence, build/version numbers, upload logs, App Store Connect IDs, beta group tester count, beta detail state, and final verification commands saved to artifacts.
**Acceptance**: `main` contains the work; new build is `VALID`, attached to `Spoonjoy Internal`, group has nonzero tester count, `internalBuildState=IN_BETA_TESTING`, testers notification state is recorded, and no public App Store submission occurs.

### ⬜ Unit 10: Durable Continuation Scan and Cleanup
**What**: Retire this worktree/branch if merged, update skills/docs with durable lessons, reconcile feedback automation state, clean generated artifacts that should not persist, update `AUTOPILOT-STATE.md`, and run the final continuation scan.
**Output**: Cleanup commits if needed, updated docs/skills if lessons generalized, final state file, and no stale worktree/branch from this run.
**Acceptance**: No ready work remains under the mandate, or remaining work is classified as hard exception or out of scope with evidence.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **All artifacts**: Save outputs, logs, data to `./2026-07-09-1243-doing-native-full-moon/` directory
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away

## Progress Log
- 2026-07-09 12:49 Created from planning doc
