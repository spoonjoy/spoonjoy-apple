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

### ⬜ Unit 0: Native Justification And Project Generator
**What**: Add `docs/native-justification.md`, a deterministic Xcode project generator under `scripts/`, and update developer docs for 26.5 bootstrap validation vs iOS/macOS 27 product baseline.
**Output**: Native justification doc, `scripts/generate-xcode-project.rb`, generated project contract notes, and artifact log.
**Acceptance**: `ruby -c scripts/generate-xcode-project.rb` passes; native justification names accepted/rejected platform levers; docs explicitly label 26.5 as bootstrap-only and 27 as product baseline.

### ⬜ Unit 1a: Domain Models And Fixtures — Tests
**What**: Write failing Swift tests for recipe, cookbook, shopping-list, cook-mode, capture draft, settings, search, and fixture state models.
**Output**: Test files under `Tests/SpoonjoyCoreTests/` covering decoding, validation, filtering, persistence DTOs, and edge cases.
**Acceptance**: `swift test --filter SpoonjoyCoreTests` fails because implementation does not exist yet.

### ⬜ Unit 1b: Domain Models And Fixtures — Implementation
**What**: Implement `SpoonjoyCore` models, fixture loading, search/filter helpers, cook-mode progress, shopping-list operations, capture draft state, and settings state.
**Output**: Swift package sources under `Sources/SpoonjoyCore/`.
**Acceptance**: Unit 1a tests pass; no warnings; code keeps UI-independent logic out of app targets.

### ⬜ Unit 1c: Domain Models And Fixtures — Coverage & Refactor
**What**: Run SwiftPM coverage, add missing edge tests, and refactor model boundaries.
**Output**: Coverage log in artifacts directory.
**Acceptance**: 100% coverage on new package logic where measurable; `swift test` passes.

### ⬜ Unit 2a: API v1 And OAuth/PKCE Client — Tests
**What**: Write failing tests for REST API v1 request builders, response envelopes, error mapping, idempotency behavior, OAuth/PKCE request construction, redirect validation, refresh rotation, and single-flight refresh.
**Output**: Tests capturing outgoing method/path/query/headers/body for recipes, cookbooks, shopping list, tokens, OAuth register/authorize/token/refresh/revoke, and DELETE idempotency header/query/body forms.
**Acceptance**: `swift test --filter SpoonjoyCoreTests/API` fails on missing implementation with outbound-shape assertions.

### ⬜ Unit 2b: API v1 And OAuth/PKCE Client — Implementation
**What**: Implement API request builders, response/error types, OAuth/PKCE helpers, token vault protocol, in-memory token vault, refresh coordinator, and retry classification.
**Output**: Swift package sources for API and auth foundations.
**Acceptance**: Unit 2a tests pass; public recipe/cookbook requests omit stale auth by default; REST OAuth omits `resource`; shopping DELETE supports `X-Client-Mutation-Id`, query, and body forms.

### ⬜ Unit 2c: API v1 And OAuth/PKCE Client — Coverage & Refactor
**What**: Run coverage, harden edge cases, and refactor request construction into stable seams.
**Output**: Coverage and request-shape logs in artifacts directory.
**Acceptance**: 100% coverage on new API/auth logic where measurable; `swift test` passes.

### ⬜ Unit 3a: Offline Store And Scenario Engine — Tests
**What**: Write failing tests for JSON file store, offline restore, mutation queue, scenario verifier data, and native-affordance metadata.
**Output**: Tests for load/save, corrupt JSON recovery, cursor checkpointing, offline cook progress, shopping checkoff, search index metadata, App Intent descriptor metadata, and scenario report generation.
**Acceptance**: `swift test --filter SpoonjoyCoreTests/Scenario` fails before implementation.

### ⬜ Unit 3b: Offline Store And Scenario Engine — Implementation
**What**: Implement offline JSON store, mutation queue, scenario verifier library entry point, App Intent/search metadata descriptors, and deterministic fixture scenario report.
**Output**: `Sources/SpoonjoyCore` scenario/offline modules and `scripts/verify-native-scenarios.sh`.
**Acceptance**: Unit 3a tests pass; `scripts/verify-native-scenarios.sh` proves the required flows from the command line.

### ⬜ Unit 3c: Offline Store And Scenario Engine — Coverage & Refactor
**What**: Enforce coverage and clean up scenario output.
**Output**: Scenario verifier artifact JSON/log and coverage log.
**Acceptance**: 100% coverage on new offline/scenario logic where measurable; scenario verifier exits nonzero on missing native-value metadata.

### ⬜ Unit 4a: SwiftUI App Shell — Tests
**What**: Add failing compile/scenario tests or package-level view-model tests for app navigation state, tab/sidebar selection, cook-mode route state, capture draft state, and settings state.
**Output**: Tests that exercise UI-independent view model state used by SwiftUI screens.
**Acceptance**: Tests fail before app shell/view-model implementation exists.

### ⬜ Unit 4b: SwiftUI App Shell — Implementation
**What**: Create shared SwiftUI app source plus iOS and macOS app targets: signed-out setup, Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping List, Search, Capture, and Settings using native navigation/search/toolbars/share/edit/check controls.
**Output**: `Apps/Spoonjoy/` SwiftUI sources and generated `Spoonjoy.xcodeproj`.
**Acceptance**: View-model tests pass; `ruby scripts/generate-xcode-project.rb` regenerates project deterministically; `xcodebuild` builds iOS simulator and macOS app targets.

### ⬜ Unit 4c: SwiftUI App Shell — Coverage & Refactor
**What**: Run coverage/builds, refactor shared app state, and remove warning-prone code.
**Output**: Build logs and coverage logs in artifacts directory.
**Acceptance**: `swift test`, `swift test --enable-code-coverage`, iOS build, and macOS build pass with no new warnings.

### ⬜ Unit 5a: CI Coverage And Native Validation Scripts — Tests
**What**: Write failing tests or shell checks for coverage-threshold enforcement, Xcode build destination resolution, macOS launch smoke, screenshot artifact generation, and local validation reporting.
**Output**: Script tests or deterministic shell assertions under `scripts/` and artifacts.
**Acceptance**: Checks fail before scripts implement the required behavior.

### ⬜ Unit 5b: CI Coverage And Native Validation Scripts — Implementation
**What**: Implement coverage threshold script, launch/smoke scripts, screenshot/design artifact capture where tooling allows, and update `.github/workflows/native.yml` to enforce coverage.
**Output**: Updated scripts and workflow.
**Acceptance**: Coverage check fails below threshold, passes at threshold; macOS launch/smoke runs locally; iOS smoke records CoreSimulator timeout as a local blocker if the simulator service remains unavailable.

### ⬜ Unit 5c: CI Coverage And Native Validation Scripts — Coverage & Refactor
**What**: Run the full local validation matrix and clean up scripts.
**Output**: Logs for `swift test`, coverage, scenario verifier, app bundle builds, launch/smoke, and screenshot/design review in artifacts directory.
**Acceptance**: All available local validation passes, or a machine capability blocker is documented with command output; no script warnings.

### ⬜ Unit 6: Final Review, PR, And Merge
**What**: Run harsh implementation review, address findings, open PR, wait for protected checks, merge, and fast-forward local main.
**Output**: PR URL, reviewer verdicts, CI logs, merged main.
**Acceptance**: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` pass on GitHub; reviewer has no BLOCKER/MAJOR findings; PR merges to `main`.

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
