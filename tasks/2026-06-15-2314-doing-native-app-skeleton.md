# Doing: Native App Skeleton

**Status**: drafting
**Execution Mode**: direct
**Created**: 2026-06-15 23:14
**Planning**: ./2026-06-15-2314-planning-native-app-skeleton.md
**Artifacts**: ./2026-06-15-2314-doing-native-app-skeleton/

## Execution Mode

- **direct**: Execute units sequentially in current session because package structure, Xcode project generation, CI, app shell, and validation scripts are tightly coupled. Use sub-agents for reviewer gates and bounded sidecar implementation only when write scopes are disjoint.

## Objective

Build the first complete, runnable native Spoonjoy Apple app slice: a protected, reproducible SwiftUI/Xcode project with iOS and macOS app bundles, testable domain/API/offline logic, and native-value surfaces that prove this is not a web clone.

## Upstream Work Items

- None

## Completion Criteria

- [ ] `Package.swift` exists and `swift test` passes with focused coverage for all new core logic and edge/error paths.
- [ ] `Spoonjoy.xcodeproj` exists and app bundles build for iOS simulator and macOS destinations without warnings introduced by this branch.
- [ ] The native scenario verifier proves first-run/session setup, fixture kitchen browsing, recipe detail, cook-mode progress persistence, shopping-list checkoff, search, capture draft creation, settings state, App Intent/search indexing metadata, offline cache restore, and native affordance flags through deterministic command-line checks.
- [ ] iOS simulator launch/smoke runs when CoreSimulator responds; if local CoreSimulator times out, the result is recorded as a local machine blocker while CI still builds the iOS bundle. macOS app launch/smoke must run locally.
- [ ] Screenshot/design review artifacts exist for mobile-width and desktop-class layouts, or the plan records a concrete simulator/runtime blocker with the last command output.
- [ ] App surfaces visibly use native navigation/search/toolbars/share/edit/check controls while preserving Kitchen Table hierarchy: a lead food/cookbook/list object, cookbook-style recipe detail, receipt-like shopping list, and focused cook-mode surface.
- [ ] `docs/native-justification.md` explains why Spoonjoy Apple earns being native and which tempting APIs are intentionally postponed or rejected.
- [ ] `docs/native-design-language.md` remains consistent with the web Kitchen Table language and the app code reflects those invariants in structure, naming, colors, typography, and object hierarchy.
- [ ] CI protected checks pass on the PR: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`.
- [ ] The `Coverage` check enforces the configured Swift package coverage threshold for new package code instead of only generating coverage output.
- [ ] Harsh sub-agent review converges with no BLOCKER/MAJOR findings before merge.

## Code Coverage Requirements

**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code.
- All branches covered where SwiftPM coverage can measure them.
- All error paths tested.
- Edge cases: null/nil, empty, boundary values, malformed URLs, malformed JSON, invalid cursors, invalid OAuth state, expired token state, and idempotency conflicts.
- Request-building tests must capture outbound method, URL path/query, headers, and JSON/form body shape.
- OAuth/PKCE tests must cover code-verifier/challenge generation, state generation/validation, register/authorize/token/refresh/revoke request construction, redirect validation, persisted client id, atomic refresh-token rotation, and single-flight refresh behavior.
- Shopping-list mutation tests must cover POST/PATCH JSON `clientMutationId`, DELETE idempotency through `X-Client-Mutation-Id`, query, and body forms, plus idempotency conflict/in-progress response handling.
- UI app target code is covered through compile/build plus scenario verifier until XCTest UI automation is added; nontrivial UI-independent logic belongs in the Swift package.

## TDD Requirements

**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE implementation.
2. **Verify failure**: Run tests and confirm they FAIL (red).
3. **Minimal implementation**: Write just enough code to pass.
4. **Verify pass**: Run tests and confirm they PASS (green).
5. **Refactor**: Clean up, keep tests green.
6. **No skipping**: Never write implementation without failing tests first.

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ⬜ Unit 0a: Native Justification And Generator Contract — Tests
**What**: Add failing checks for `docs/native-justification.md` required headings, deployment-target labeling, project generator syntax, and deterministic project regeneration contract.
**Output**: Shell/Ruby checks under `scripts/` or artifact commands proving missing docs/generator fail.
**Acceptance**: The checks fail before the doc/generator implementation exists.

### ⬜ Unit 0b: Native Justification And Generator Contract — Implementation
**What**: Add `docs/native-justification.md`, `scripts/generate-xcode-project.rb`, and bootstrap validation notes for 26.5 vs 27.
**Output**: Native justification doc and generator script.
**Acceptance**: Unit 0a checks pass; `ruby -c scripts/generate-xcode-project.rb` passes; justification names accepted/rejected native platform levers.

### ⬜ Unit 0c: Native Justification And Generator Contract — Determinism
**What**: Run generator twice, diff generated project output, and refactor generator/docs if nondeterministic.
**Output**: Determinism log in artifacts directory.
**Acceptance**: Re-running the generator produces no git diff after the first generation.

### ⬜ Unit 1a: Recipe/Cookbook Domain — Tests
**What**: Write failing Swift tests for recipe, ingredient, step, chef, cookbook, cookbook cover, fixture decoding, and public search summary models.
**Output**: `Tests/SpoonjoyCoreTests/RecipeCookbookTests.swift`.
**Acceptance**: Filtered Swift tests fail because domain models do not exist yet.

### ⬜ Unit 1b: Recipe/Cookbook Domain — Implementation
**What**: Implement recipe/cookbook domain models, fixture decoding, validation, and search-summary helpers.
**Output**: `Sources/SpoonjoyCore/RecipeCookbook/` sources and fixtures.
**Acceptance**: Unit 1a tests pass with no warnings.

### ⬜ Unit 1c: Recipe/Cookbook Domain — Coverage & Refactor
**What**: Run coverage for recipe/cookbook code, add edge tests, and refactor naming/boundaries.
**Output**: Coverage log in artifacts directory.
**Acceptance**: 100% coverage on recipe/cookbook package code where measurable; `swift test` passes.

### ⬜ Unit 2a: Shopping/Cook/Settings Domain — Tests
**What**: Write failing Swift tests for shopping-list item operations, cook-mode progress, capture drafts, settings, and kitchen fixture state.
**Output**: `Tests/SpoonjoyCoreTests/KitchenStateTests.swift`.
**Acceptance**: Filtered Swift tests fail before implementation.

### ⬜ Unit 2b: Shopping/Cook/Settings Domain — Implementation
**What**: Implement shopping-list operations, cook-mode progress persistence DTOs, capture draft state, settings state, and kitchen fixture state.
**Output**: `Sources/SpoonjoyCore/KitchenState/` sources.
**Acceptance**: Unit 2a tests pass with no warnings.

### ⬜ Unit 2c: Shopping/Cook/Settings Domain — Coverage & Refactor
**What**: Run coverage for kitchen state code, add missing edge/error tests, and refactor.
**Output**: Coverage log in artifacts directory.
**Acceptance**: 100% coverage on kitchen-state package code where measurable; `swift test` passes.

### ⬜ Unit 3a: Public API v1 Read Client — Tests
**What**: Write failing tests for recipe/cookbook list/detail request builders, optional auth behavior, response envelopes, pagination, cache headers metadata, and error mapping.
**Output**: `Tests/SpoonjoyCoreTests/APIReadClientTests.swift`.
**Acceptance**: Tests fail with outbound-shape assertions for method, path, query, headers, and auth omission by default.

### ⬜ Unit 3b: Public API v1 Read Client — Implementation
**What**: Implement API base URL, request builder, envelope/error types, recipes/cookbooks list/detail requests, pagination cursor helpers, and optional-auth policy.
**Output**: `Sources/SpoonjoyCore/API/` read-client sources.
**Acceptance**: Unit 3a tests pass; stale bearer tokens are not attached to anonymous public reads by default.

### ⬜ Unit 3c: Public API v1 Read Client — Coverage & Refactor
**What**: Run coverage, add malformed URL/cursor/error edge tests, and refactor read-client boundaries.
**Output**: Coverage and request-shape logs.
**Acceptance**: 100% coverage on read-client code where measurable; `swift test` passes.

### ⬜ Unit 4a: Shopping API Mutations — Tests
**What**: Write failing tests for shopping-list read/sync, POST/PATCH/DELETE request builders, idempotency body/header/query forms, retry classification, and conflict/in-progress handling.
**Output**: `Tests/SpoonjoyCoreTests/ShoppingAPIClientTests.swift`.
**Acceptance**: Tests fail with outbound-shape assertions and DELETE `X-Client-Mutation-Id` expectations.

### ⬜ Unit 4b: Shopping API Mutations — Implementation
**What**: Implement shopping-list API request builders, sync cursor helpers, mutation response parsing, idempotency metadata, and retry/error classification.
**Output**: `Sources/SpoonjoyCore/API/ShoppingListAPI.swift`, `Sources/SpoonjoyCore/API/ShoppingListRequests.swift`, and `Sources/SpoonjoyCore/API/APIRetryPolicy.swift`.
**Acceptance**: Unit 4a tests pass; DELETE supports header, query, and body idempotency forms.

### ⬜ Unit 4c: Shopping API Mutations — Coverage & Refactor
**What**: Run coverage, add edge/error tests for 401/403/409/429/5xx paths, and refactor.
**Output**: Coverage and retry-classification logs.
**Acceptance**: 100% coverage on shopping API code where measurable; `swift test` passes.

### ⬜ Unit 5a: OAuth/PKCE Request Construction — Tests
**What**: Write failing tests for PKCE verifier/challenge, state generation/validation, OAuth register/authorize/token/refresh/revoke request construction, redirect constraints, and REST `resource` omission.
**Output**: `Tests/SpoonjoyCoreTests/OAuthRequestTests.swift`.
**Acceptance**: Tests fail before OAuth helpers exist and assert form bodies/authorize query items.

### ⬜ Unit 5b: OAuth/PKCE Request Construction — Implementation
**What**: Implement PKCE/state helpers, OAuth request builders, redirect validation, and OAuth response types.
**Output**: `Sources/SpoonjoyCore/Auth/OAuthPKCE.swift`, `Sources/SpoonjoyCore/Auth/OAuthRequests.swift`, `Sources/SpoonjoyCore/Auth/OAuthRedirectValidator.swift`, and `Sources/SpoonjoyCore/Auth/OAuthResponses.swift`.
**Acceptance**: Unit 5a tests pass; custom schemes are rejected and REST OAuth omits `resource`.

### ⬜ Unit 5c: OAuth/PKCE Request Construction — Coverage & Refactor
**What**: Run coverage, add edge/error tests, and refactor OAuth request helpers.
**Output**: OAuth coverage log.
**Acceptance**: 100% coverage on OAuth request code where measurable; `swift test` passes.

### ⬜ Unit 6a: Token Vault And Refresh Coordination — Tests
**What**: Write failing tests for token vault protocol behavior, in-memory vault, persisted client id abstraction, atomic refresh-token rotation, invalid state handling, and single-flight refresh.
**Output**: `Tests/SpoonjoyCoreTests/TokenRefreshTests.swift`.
**Acceptance**: Tests fail before vault/coordinator implementation exists.

### ⬜ Unit 6b: Token Vault And Refresh Coordination — Implementation
**What**: Implement token vault abstractions, in-memory token vault, refresh coordinator, and disconnect/revoke state transitions.
**Output**: `Sources/SpoonjoyCore/Auth/TokenVault.swift`, `Sources/SpoonjoyCore/Auth/InMemoryTokenVault.swift`, `Sources/SpoonjoyCore/Auth/RefreshCoordinator.swift`, and `Sources/SpoonjoyCore/Auth/AuthSessionState.swift`.
**Acceptance**: Unit 6a tests pass; concurrent refresh calls share one refresh operation in tests.

### ⬜ Unit 6c: Token Vault And Refresh Coordination — Coverage & Refactor
**What**: Run coverage, add concurrency/error tests, and refactor.
**Output**: Coverage/concurrency logs.
**Acceptance**: 100% coverage on token/refresh code where measurable; `swift test` passes.

### ⬜ Unit 7a: Offline Store And Mutation Queue — Tests
**What**: Write failing tests for JSON file store, corrupt JSON recovery, durable cursor checkpointing, offline restore, and queued mutation serialization.
**Output**: `Tests/SpoonjoyCoreTests/OfflineStoreTests.swift`.
**Acceptance**: Tests fail before offline store implementation exists.

### ⬜ Unit 7b: Offline Store And Mutation Queue — Implementation
**What**: Implement file-store abstractions, JSON encoding/decoding, cursor checkpointing, offline restore, and mutation queue models.
**Output**: `Sources/SpoonjoyCore/Offline/JSONFileStore.swift`, `Sources/SpoonjoyCore/Offline/OfflineSnapshot.swift`, `Sources/SpoonjoyCore/Offline/SyncCheckpoint.swift`, and `Sources/SpoonjoyCore/Offline/MutationQueue.swift`.
**Acceptance**: Unit 7a tests pass; corrupt JSON recovers without losing valid fallback fixtures.

### ⬜ Unit 7c: Offline Store And Mutation Queue — Coverage & Refactor
**What**: Run coverage, add filesystem/error edge tests, and refactor.
**Output**: Offline coverage log.
**Acceptance**: 100% coverage on offline store code where measurable; `swift test` passes.

### ⬜ Unit 8a: Native Metadata And Scenario Engine — Tests
**What**: Write failing tests for App Intent descriptors, Spotlight/search metadata, native affordance flags, and deterministic scenario report generation.
**Output**: `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`.
**Acceptance**: Tests fail before metadata/scenario engine exists.

### ⬜ Unit 8b: Native Metadata And Scenario Engine — Implementation
**What**: Implement native-value metadata descriptors and scenario report generator for first-run, fixture kitchen, recipe detail, cook progress, shopping checkoff, search, capture draft, settings, offline restore, and native affordance flags.
**Output**: `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`, `Sources/SpoonjoyCore/Native/ScenarioReport.swift`, `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`, and `scripts/verify-native-scenarios.sh`.
**Acceptance**: Unit 8a tests pass; scenario verifier exits nonzero when required metadata is absent.

### ⬜ Unit 8c: Native Metadata And Scenario Engine — Coverage & Refactor
**What**: Run coverage, polish scenario output, and refactor descriptors.
**Output**: Scenario JSON/log and coverage log.
**Acceptance**: 100% coverage on scenario engine code where measurable; verifier produces deterministic artifacts.

### ⬜ Unit 9a: App State And Navigation View Models — Tests
**What**: Write failing tests for app route selection, sidebar/tab state, search state, recipe selection, cook-mode state, capture draft state, shopping checkoff state, and settings state used by SwiftUI.
**Output**: `Tests/SpoonjoyCoreTests/AppStateTests.swift`.
**Acceptance**: Tests fail before view-model state exists.

### ⬜ Unit 9b: App State And Navigation View Models — Implementation
**What**: Implement UI-independent app state/view models consumed by SwiftUI screens.
**Output**: `Sources/SpoonjoyCore/AppState/AppRoute.swift`, `Sources/SpoonjoyCore/AppState/AppNavigationState.swift`, `Sources/SpoonjoyCore/AppState/SearchState.swift`, and `Sources/SpoonjoyCore/AppState/ScreenViewModels.swift`.
**Acceptance**: Unit 9a tests pass; app targets do not own nontrivial business logic.

### ⬜ Unit 9c: App State And Navigation View Models — Coverage & Refactor
**What**: Run coverage, add edge tests, and refactor.
**Output**: App-state coverage log.
**Acceptance**: 100% coverage on app-state code where measurable; `swift test` passes.

### ⬜ Unit 10a: Xcode Project And App Targets — Tests
**What**: Add failing generator/project checks for iOS/macOS targets, bundle IDs, deployment target labels, shared source membership, and build settings.
**Output**: Project generation checks under `scripts/`.
**Acceptance**: Checks fail before the project/targets are generated.

### ⬜ Unit 10b: Xcode Project And App Targets — Implementation
**What**: Generate `Spoonjoy.xcodeproj` with iOS and macOS app targets, shared SwiftUI source files, asset catalogs, and build settings.
**Output**: `Spoonjoy.xcodeproj`, `Apps/Spoonjoy/Shared/SpoonjoyApp.swift`, `Apps/Spoonjoy/iOS/SpoonjoyiOSApp.swift`, `Apps/Spoonjoy/macOS/SpoonjoyMacApp.swift`, `Apps/Spoonjoy/Shared/Assets.xcassets/`, and `Apps/Spoonjoy/Shared/Info.plist`.
**Acceptance**: Project checks pass; `xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy -destination 'generic/platform=iOS Simulator' build` passes; macOS build passes.

### ⬜ Unit 10c: Xcode Project And App Targets — Determinism & Refactor
**What**: Re-run generator, diff project, and refactor generated structure/settings.
**Output**: Xcode generation determinism log.
**Acceptance**: Re-running generator produces no git diff; app bundle builds still pass.

### ⬜ Unit 11a: Native Shell Navigation — Tests
**What**: Add failing app-state or static checks for `NavigationStack`, `NavigationSplitView`, toolbars, share actions, searchable routes, edit/check affordance metadata, and platform-specific shell decisions.
**Output**: Tests/static checks for native shell affordances.
**Acceptance**: Checks fail before SwiftUI shell implementation.

### ⬜ Unit 11b: Native Shell Navigation — Implementation
**What**: Implement shared SwiftUI shell, signed-out setup, platform navigation, toolbar actions, `.searchable`, share affordances, and settings entry.
**Output**: `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`, `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`, `Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift`, `Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift`, and `Apps/Spoonjoy/Shared/AppShell/ShareActions.swift`.
**Acceptance**: Unit 11a checks pass; iOS/macOS builds pass.

### ⬜ Unit 11c: Native Shell Navigation — Coverage & Refactor
**What**: Run package tests/builds and refactor shell state.
**Output**: Build logs.
**Acceptance**: `swift test`, iOS build, and macOS build pass with no new warnings.

### ⬜ Unit 12a: Kitchen And Recipe Surfaces — Tests
**What**: Add failing tests/static checks for Kitchen lead object, recipe index rows, recipe detail cookbook spread, ingredients receipt, step list, native share, and Kitchen Table semantic tokens.
**Output**: Tests/checks for kitchen and recipe surface contracts.
**Acceptance**: Checks fail before surfaces exist.

### ⬜ Unit 12b: Kitchen And Recipe Surfaces — Implementation
**What**: Implement Kitchen, Recipes, Recipe Detail, and Cookbooks surfaces using fixture/app state and native controls.
**Output**: `Apps/Spoonjoy/Shared/Views/KitchenView.swift`, `Apps/Spoonjoy/Shared/Views/RecipesView.swift`, `Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`, `Apps/Spoonjoy/Shared/Views/CookbooksView.swift`, and `Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift`.
**Acceptance**: Unit 12a checks pass; iOS/macOS builds pass; scenario verifier covers fixture kitchen browsing and recipe detail.

### ⬜ Unit 12c: Kitchen And Recipe Surfaces — Build & Refactor
**What**: Run tests/builds/scenario verifier and refactor surface components.
**Output**: Build and scenario logs.
**Acceptance**: `swift test`, scenario verifier, iOS build, and macOS build pass with no new warnings.

### ⬜ Unit 13a: Cook Mode And Shopping Surfaces — Tests
**What**: Add failing tests/static checks for focused cook-mode state, persisted progress, large kitchen-safe controls, receipt-like shopping list, checkoff behavior, and edit/check native affordances.
**Output**: Tests/checks for cook/shopping surface contracts.
**Acceptance**: Checks fail before surfaces exist.

### ⬜ Unit 13b: Cook Mode And Shopping Surfaces — Implementation
**What**: Implement Cook Mode and Shopping List SwiftUI surfaces using package state and native controls.
**Output**: `Apps/Spoonjoy/Shared/Views/CookModeView.swift`, `Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`, `Apps/Spoonjoy/Shared/Components/ReceiptListView.swift`, and `Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift`.
**Acceptance**: Unit 13a checks pass; scenario verifier covers cook progress persistence and shopping checkoff; app builds pass.

### ⬜ Unit 13c: Cook Mode And Shopping Surfaces — Build & Refactor
**What**: Run tests/builds/scenario verifier and refactor.
**Output**: Build and scenario logs.
**Acceptance**: `swift test`, scenario verifier, iOS build, and macOS build pass with no new warnings.

### ⬜ Unit 14a: Search, Capture, Settings Surfaces — Tests
**What**: Add failing tests/static checks for native search scopes, capture draft creation, settings state, offline status, and rejected production-write claims.
**Output**: Tests/checks for search/capture/settings contracts.
**Acceptance**: Checks fail before surfaces exist.

### ⬜ Unit 14b: Search, Capture, Settings Surfaces — Implementation
**What**: Implement Search, Capture, and Settings SwiftUI surfaces using native search/toolbars/forms and local draft state.
**Output**: `Apps/Spoonjoy/Shared/Views/SearchView.swift`, `Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift`, `Apps/Spoonjoy/Shared/Views/SettingsView.swift`, and `Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift`.
**Acceptance**: Unit 14a checks pass; scenario verifier covers search, capture draft creation, settings, and offline status.

### ⬜ Unit 14c: Search, Capture, Settings Surfaces — Build & Refactor
**What**: Run tests/builds/scenario verifier and refactor.
**Output**: Build and scenario logs.
**Acceptance**: `swift test`, scenario verifier, iOS build, and macOS build pass with no new warnings.

### ⬜ Unit 15a: Coverage Enforcement Script — Tests
**What**: Add failing tests/checks for coverage JSON parsing, threshold enforcement, missing coverage file handling, and CI wiring expectations.
**Output**: Script tests/checks for coverage enforcement.
**Acceptance**: Checks fail before coverage enforcement exists.

### ⬜ Unit 15b: Coverage Enforcement Script — Implementation
**What**: Implement coverage threshold script and update `Coverage` workflow to fail below threshold.
**Output**: Coverage script and workflow changes.
**Acceptance**: Coverage check fails below threshold and passes at threshold in local script tests.

### ⬜ Unit 15c: Coverage Enforcement Script — Refactor
**What**: Run `swift test --enable-code-coverage --show-codecov-path`, threshold script, and full package tests.
**Output**: Coverage artifacts and logs.
**Acceptance**: Coverage artifacts are saved; CI coverage command is reproducible locally.

### ⬜ Unit 16a: Launch Smoke And Screenshot Scripts — Tests
**What**: Add failing checks for macOS launch smoke, iOS simulator smoke timeout reporting, exact screenshot artifact paths, and design/accessibility review manifest fields.
**Output**: Script tests/checks for `scripts/smoke-macos.sh`, `scripts/smoke-ios-simulator.sh`, `scripts/capture-native-screenshots.sh`, and `scripts/validate-design-review.rb`.
**Acceptance**: Checks fail before scripts exist.

### ⬜ Unit 16b: Launch Smoke And Screenshot Scripts — Implementation
**What**: Implement macOS launch/smoke, iOS simulator smoke with bounded CoreSimulator handling, screenshot/design artifact generation, and a fail-closed design/accessibility manifest.
**Output**: `scripts/smoke-macos.sh`, `scripts/smoke-ios-simulator.sh`, `scripts/capture-native-screenshots.sh`, `scripts/validate-design-review.rb`, and `tasks/2026-06-15-2314-doing-native-app-skeleton/design-review.json`.
**Acceptance**: macOS launch/smoke runs locally; iOS smoke records CoreSimulator timeout as a local blocker if runtime listing remains unavailable; manifest includes pass/fail entries for mobile target, desktop target, Dynamic Type, VoiceOver labels, keyboard navigation, Reduce Motion, contrast, Kitchen Table hierarchy, and no-overlap layout review.

### ⬜ Unit 16c: Launch Smoke And Screenshot Scripts — Refactor
**What**: Run launch/smoke and screenshot/design review scripts, save artifacts, and clean up output.
**Output**: `tasks/2026-06-15-2314-doing-native-app-skeleton/smoke-macos.log`, `smoke-ios-simulator.log`, `screenshots/ios-mobile.png`, `screenshots/macos-desktop.png`, and `design-review.json`.
**Acceptance**: Available launch/screenshot validation passes or records concrete local capability blocker with command output; design review manifest fails if any required pass/fail field is missing or false without a documented capability blocker.

### ⬜ Unit 17a: Full Local Matrix — Tests/Preparation
**What**: Add a single local matrix script that orchestrates Swift tests, coverage, scenario verifier, Xcode builds, launch smoke, and screenshot/design checks.
**Output**: `scripts/validate-native-local.sh` with failing pre-implementation assertions if any required script is missing.
**Acceptance**: Matrix script fails before all required validation hooks are present.

### ⬜ Unit 17b: Full Local Matrix — Implementation
**What**: Wire all validation hooks into the local matrix and align `.github/workflows/native.yml` with the same commands where feasible.
**Output**: Matrix script and workflow updates.
**Acceptance**: Matrix runs all available local validation and exits nonzero on missing mandatory checks.

### ⬜ Unit 17c: Full Local Matrix — Evidence
**What**: Run the full local matrix and save logs/artifacts.
**Output**: Full validation artifacts under `tasks/2026-06-15-2314-doing-native-app-skeleton/`.
**Acceptance**: All available validation passes; machine blockers are concrete and bounded.

### ⬜ Unit 18a: Final Implementation Review — Review
**What**: Spawn harsh implementation reviewer with full branch diff, planning/doing docs, and validation artifacts.
**Output**: Reviewer verdict.
**Acceptance**: Reviewer returns CONVERGED or FINDINGS.

### ⬜ Unit 18b: Final Implementation Review — Fixes
**What**: Address any BLOCKER/MAJOR reviewer findings with tests and implementation changes.
**Output**: Fix commits and updated artifacts.
**Acceptance**: Round 2 reviewer returns no BLOCKER/MAJOR findings.

### ⬜ Unit 19a: PR And CI — Open
**What**: Open PR for `slugger/native-app-skeleton` with summary, validation evidence, known Xcode 27 capability blocker, and reviewer gate results.
**Output**: PR URL and `tasks/2026-06-15-2314-doing-native-app-skeleton/pr-open.json`.
**Acceptance**: PR exists and protected checks start.

### ⬜ Unit 19b: PR And CI — Converge
**What**: Wait for GitHub checks, fix any CI failures, and re-run reviewer if fixes are substantive.
**Output**: Green CI, optional fix commits, and `tasks/2026-06-15-2314-doing-native-app-skeleton/github-checks.json`.
**Acceptance**: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` pass on GitHub.

### ⬜ Unit 19c: Merge And Sync
**What**: Merge PR, fast-forward local main, verify branch protection remains intact, update Desk, and continue with next app slice.
**Output**: Merged main, Desk update, and `tasks/2026-06-15-2314-doing-native-app-skeleton/branch-protection.json`.
**Acceptance**: PR is merged to `main`; local main matches `origin/main`; branch-protection JSON shows strict required checks `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`; no active implementation branch residue.

## Execution

- **TDD strictly enforced**: tests -> red -> implement -> green -> refactor.
- Commit after each phase.
- Push after each unit complete.
- Run full test suite before marking unit done.
- **All artifacts**: Save outputs, logs, screenshots, and data to `./2026-06-15-2314-doing-native-app-skeleton/`.
- **Fixes/blockers**: Spawn sub-agent immediately for ordinary implementation or review blockers.
- **Decisions made**: Update docs immediately, commit right away.

## Progress Log

- 2026-06-15 23:14 Created doing doc from approved planning doc.
- 2026-06-15 23:14 Addressed granularity review by splitting broad units into atomic test/implementation/coverage groups.
- 2026-06-15 23:14 Granularity Round 2 converged with no remaining blockers.
- 2026-06-15 23:14 Addressed validation review with explicit source paths, design/accessibility manifest criteria, screenshot targets, and branch-protection evidence artifacts.
