# Doing: Siri Full Access Parity

**Status**: drafting
**Execution Mode**: spawn
**Created**: 2026-06-16 18:23
**Planning**: ./2026-06-16-1754-planning-siri-full-access-parity.md
**Artifacts**: ./2026-06-16-1754-doing-siri-full-access-parity/

## Execution Mode

- **spawn**: Execute dependency waves with sub-agent implementors for disjoint backend, native core, app-surface, documentation, and validation write scopes. The orchestrator owns sequencing, integration, reviewer gates, commits, pushes, PRs, merges, and final validation.

## Objective

Bring Spoonjoy Apple to real native parity with the audited Spoonjoy web product model, then expose that current product model to Siri/App Intents as fully as Apple platform capabilities allow.

## Upstream Work Items

- None

## Completion Criteria

- [ ] The three audit artifacts remain committed and are referenced by planning/doing docs.
- [ ] The planning doc passes harsh sub-agent review with no BLOCKER/MAJOR findings and is marked approved.
- [ ] A doing doc exists with concrete units for backend API, native transport/auth/cache/offline, parity surfaces, App Intents/Siri, documentation, validation, review, PR/merge, and cleanup.
- [ ] `spoonjoy-v2` exposes tested REST v1 endpoints needed by native parity, including `GET/POST /api/v1/tokens` and `DELETE /api/v1/tokens/{credentialId}` in native account/API credential flows, with OpenAPI/docs/playground updates and no drift from implementation.
- [ ] Native Apple uses live Spoonjoy contracts for every read and write endpoint listed in Scope, with fixtures only as deterministic fallback/test data.
- [ ] Offline mode works as product behavior: cached read access, durable cook progress, capture drafts, shopping mutation queue, sync/retry/conflict/freshness states, and a dismissible offline indicator.
- [ ] Native surfaces cover the audited current product concepts or provide exact native secure handoff for credential/account operations where web/OAuth/passkey surfaces are canonical.
- [ ] Siri/App Intents uses entity-backed access and not just string IDs for recipes, cookbooks, shopping items/lists, spoons/cook logs, chefs, profiles, and capture drafts. It explicitly skips only schema domains that are semantically false for Spoonjoy.
- [ ] Recipe/cookbook/shopping sharing is first-class through native share and Siri/Shortcuts transfer surfaces without adding comments/social feed.
- [ ] Destructive or sensitive Siri/native actions have confirmation/auth/ownership policy.
- [ ] `spoonjoy-apple`: Swift tests, coverage, scenario verifier, warning scan, app bundle build, macOS launch/screenshot, project/generator/static contracts, or a structured Xcode/SDK/hardware blocker artifact for any command the installed toolchain cannot run.
- [ ] `spoonjoy-v2`: targeted Vitest route/lib/doc suites for every touched API surface, `pnpm run test:coverage`, `pnpm run typecheck`, `pnpm run build`, generated playground drift checks, OpenAPI route coverage tests, and zero-warning output.
- [ ] Any remaining non-green validation is backed by a structured true blocker artifact, such as Apple Developer Program, missing simulator runtime, Xcode installation fault, production secret, or unavailable hardware.
- [ ] Reviewer sub-agents converge on implementation, offline/sync, API contract, native design, and App Intents readiness.
- [ ] PRs are opened, checks pass or true blockers are recorded, branches are merged to `main`, local repos are synced, temporary branches/worktrees are cleaned up, Desk state is updated, and Slugger is notified.

## Code Coverage Requirements

**MANDATORY: 100% coverage on all new code.**
- New or modified `spoonjoy-apple` SwiftPM-measurable code in `Sources/SpoonjoyCore` must remain at 100% coverage, including valid, invalid, empty, boundary, cache, offline, conflict, replay, retry, and error paths.
- App-target SwiftUI/AppIntents adapters that cannot be measured by SwiftPM must have scenario, static, compile, screenshot, or AppIntentsTesting coverage.
- Every outbound native request builder/transport test must assert method, URL/path/query, headers, body, auth behavior, idempotency keys, and error-envelope decoding.
- `spoonjoy-v2` additions must satisfy the repo's 100% coverage and zero-warning policy for touched code, including API route coverage, OpenAPI/docs drift tests, idempotency conflicts, authorization/scope failures, validation errors, and tombstone/sync behavior.
- Documentation and generated OpenAPI/playground changes need tests that fail when the documented/native contract drifts from implemented REST v1 resources.
- UI parity that is not unit-testable must be covered by scenario verifier, static contracts, screenshots, and design-review artifacts.
- Web validation must save artifacts for `pnpm run test:coverage`, `pnpm run typecheck`, `pnpm run build`, generated API playground output, docs/OpenAPI route coverage, and every targeted Vitest command used during red/green units.

## TDD Requirements

**Strict TDD - no exceptions:**
1. **Tests first**: Write failing tests BEFORE any implementation.
2. **Verify failure**: Run tests, confirm they FAIL (red).
3. **Minimal implementation**: Write just enough code to pass.
4. **Verify pass**: Run tests, confirm they PASS (green).
5. **Refactor**: Clean up, keep tests green.
6. **No skipping**: Never write implementation without failing test first.

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ⬜ Unit 0: Artifact Root And Cross-Repo Baseline
**What**: Create baseline artifact files under `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity/` for both repos, record `git status`, remotes, current branches, protected-check names, tool versions, and branch-protection evidence for `spoonjoy/spoonjoy-v2` and `spoonjoy/spoonjoy-apple`.
**Output**: `baseline-apple.json`, `baseline-web.json`, `branch-protection-apple.json`, `branch-protection-web.json`, and `toolchain.json` in the artifact directory.
**Acceptance**: Both repos are clean except current docs/artifacts, both remotes point at `https://github.com/spoonjoy/...`, required checks are recorded, and no implementation starts until this evidence exists.

### ⬜ Unit 1a: REST V1 Contract Registry - Tests
**What**: In `spoonjoy-v2`, write failing tests for `app/lib/api-v1-contract.server.ts`, `app/lib/api-v1-openapi.server.ts`, `test/config/api-v1-route-coverage.test.ts`, and developer docs drift covering every endpoint named in the planning doc.
**Output**: Red artifacts `web/unit-1a-contract-red.log` and test changes under `test/config/`, `test/lib/`, and `test/docs/`.
**Acceptance**: Targeted tests fail because `/api/v1/me`, profile, search, recipe write, cover, spoon, cookbook write, shopping clear/add-from-recipe, sync, APNs, and token-native-account contract rows are missing or undocumented.

### ⬜ Unit 1b: REST V1 Contract Registry - Implementation
**What**: Extend `API_V1_RESOURCES`, `API_V1_SCOPE_REQUIREMENTS`, operation telemetry mapping, OpenAPI builders, generated playground metadata, and docs so every native dogfood endpoint is declared with auth mode, scopes, schemas, examples, and error envelopes.
**Output**: Updated `app/lib/api-v1-contract.server.ts`, `app/lib/api-v1-openapi.server.ts`, `docs/api.md`, `scripts/generate-api-playground.ts`, and generated playground output.
**Acceptance**: Unit 1a tests pass; `pnpm run api:playground:generate` produces no uncommitted generated drift; no implementation handler returns success for unimplemented write resources yet.

### ⬜ Unit 1c: REST V1 Contract Registry - Coverage & Refactor
**What**: Run focused docs/OpenAPI/route coverage tests, then run `pnpm run typecheck` for the touched contract surface.
**Output**: `web/unit-1c-contract-green.log`, `web/unit-1c-typecheck.log`, and drift summary.
**Acceptance**: Contract tests pass, typecheck passes, route coverage fails on any future contract/resource mismatch, and generated docs contain native OAuth/token guidance.

### ⬜ Unit 2a: Native Bootstrap And Account API - Tests
**What**: Write failing `spoonjoy-v2` route/lib tests for `GET /api/v1/me`, `PATCH /api/v1/me`, `GET /api/v1/me/kitchen`, notification preferences, APNs device registration/revocation, account connections, token list/create/revoke in native account context, auth/scope failures, and private cache headers.
**Output**: `test/routes/api-v1-me.test.ts`, token/account extensions, and `web/unit-2a-me-red.log`.
**Acceptance**: Tests fail with missing handlers or incomplete payloads; failures assert exact response envelope keys, private no-store headers, validation errors, and scope requirements.

### ⬜ Unit 2b: Native Bootstrap And Account API - Implementation
**What**: Implement native bootstrap/account handlers in `app/lib/api-v1.server.ts` using existing account, auth, notification, token, and session helpers; add a minimal APNs device registry contract using existing schema or a tested migration if storage is required.
**Output**: API handlers, helper functions, optional Prisma migration/tests for APNs device records, and docs examples.
**Acceptance**: Unit 2a tests pass; bearer and session auth both work; passkey/password/provider-link actions return exact web handoff URLs rather than fake native mutations.

### ⬜ Unit 2c: Native Bootstrap And Account API - Coverage & Refactor
**What**: Run focused account/token/APNs tests, docs drift tests, typecheck, and coverage for touched files.
**Output**: `web/unit-2c-account-coverage.log`, `web/unit-2c-typecheck.log`, and coverage summary.
**Acceptance**: New account/bootstrap/token code has 100% branch/error coverage, zero warnings, and no stale generated playground output.

### ⬜ Unit 3a: Profile, Chef Graph, And Search API - Tests
**What**: Write failing tests for `GET /api/v1/users/{identifier}`, `GET /api/v1/users/{identifier}/fellow-chefs`, `GET /api/v1/users/{identifier}/kitchen-visitors`, and `GET /api/v1/search` with `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list` scopes.
**Output**: `test/routes/api-v1-users-search.test.ts` and `web/unit-3a-users-search-red.log`.
**Acceptance**: Tests fail before handlers exist and assert payload parity with profile/search web surfaces, anonymous vs authenticated search behavior, shopping-list auth, and invalid scope errors.

### ⬜ Unit 3b: Profile, Chef Graph, And Search API - Implementation
**What**: Implement profile, chef graph, and search handlers using `app/lib/fellow-chefs.server.ts`, `app/lib/search.server.ts`, current Prisma relations, and v1 envelope helpers.
**Output**: `app/lib/api-v1.server.ts` handler additions plus extracted serializer helpers when shared serializers reduce duplication.
**Acceptance**: Unit 3a tests pass; deleted recipes/spoons stay hidden; shopping-list search requires auth; profile payload includes recipes, cookbooks, spoons, fellow chefs, and kitchen visitors.

### ⬜ Unit 3c: Profile, Chef Graph, And Search API - Coverage & Refactor
**What**: Run focused profile/search tests, typecheck, coverage, and docs/OpenAPI drift tests.
**Output**: `web/unit-3c-users-search-green.log`, `web/unit-3c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched profile/search code has 100% coverage, no warnings, and exact docs/OpenAPI examples.

### ⬜ Unit 4a: Recipe Create Update Delete Fork API - Tests
**What**: Write failing tests for `POST /api/v1/recipes`, `PATCH /api/v1/recipes/{id}`, `DELETE /api/v1/recipes/{id}`, and `POST /api/v1/recipes/{id}/fork`, including idempotency, owner checks, duplicate titles, validation, deleted source behavior, notification side effects mocked through existing helper boundaries, and response serializers.
**Output**: `test/routes/api-v1-recipe-writes.test.ts` and `web/unit-4a-recipe-writes-red.log`.
**Acceptance**: Tests fail before write handlers exist and assert exact mutation envelopes, `clientMutationId`, and scope requirements.

### ⬜ Unit 4b: Recipe Create Update Delete Fork API - Implementation
**What**: Implement recipe write handlers using `app/lib/recipe-create.server.ts`, `app/lib/recipe-fork.server.ts`, validation helpers, and v1 idempotency helpers.
**Output**: API handlers and serializer/helper extraction.
**Acceptance**: Unit 4a tests pass; writes require ownership where required; soft delete preserves tombstone data for sync; fork copies source graph consistently with web helper behavior.

### ⬜ Unit 4c: Recipe Create Update Delete Fork API - Coverage & Refactor
**What**: Run focused recipe-write tests, idempotency conflict/replay tests, typecheck, docs/OpenAPI drift tests, and coverage.
**Output**: `web/unit-4c-recipe-writes-green.log`, `web/unit-4c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched recipe write code has 100% coverage, all idempotency paths are covered, and generated docs match implemented handlers.

### ⬜ Unit 5a: Recipe Step Ingredient Dependency API - Tests
**What**: Write failing tests for step create/update/delete/reorder, ingredient add/delete, and `PUT /api/v1/recipes/{id}/step-output-uses`.
**Output**: `test/routes/api-v1-recipe-steps.test.ts` and `web/unit-5a-recipe-steps-red.log`.
**Acceptance**: Tests fail before handlers exist and cover invalid step ids, duplicate step numbers, dependency cycles/invalid refs, protected deletion, malformed quantities, and owner-only access.

### ⬜ Unit 5b: Recipe Step Ingredient Dependency API - Implementation
**What**: Implement handlers using existing step deletion/reorder/dependency helpers: `app/lib/step-deletion-validation.server.ts`, `app/lib/step-reorder-validation.server.ts`, `app/lib/step-output-use-mutations.server.ts`, and validation helpers.
**Output**: API handlers and shared mutation helpers.
**Acceptance**: Unit 5a tests pass; recipe graphs returned through v1 detail reflect changed steps, ingredients, and dependencies.

### ⬜ Unit 5c: Recipe Step Ingredient Dependency API - Coverage & Refactor
**What**: Run focused step/ingredient/dependency tests, typecheck, docs/OpenAPI drift tests, and coverage.
**Output**: `web/unit-5c-recipe-steps-green.log`, `web/unit-5c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched step/dependency code has 100% coverage and no warnings.

### ⬜ Unit 6a: Recipe Image And Cover Lifecycle API - Tests
**What**: Write failing tests for `POST /api/v1/recipes/{id}/image`, cover list/create/set/remove/archive/regenerate/from-spoon endpoints, owner checks, source variants, failure states, malformed uploads, and no-production-secret behavior for AI generation.
**Output**: `test/routes/api-v1-recipe-covers.test.ts` and `web/unit-6a-covers-red.log`.
**Acceptance**: Tests fail before v1 handlers exist and assert exact cover history response shapes, upload constraints, and structured AI/provider blocker responses for missing local secrets.

### ⬜ Unit 6b: Recipe Image And Cover Lifecycle API - Implementation
**What**: Implement image/cover handlers using `app/lib/image-storage.server.ts`, `app/lib/recipe-cover.server.ts`, `app/lib/recipe-image-assignment.server.ts`, spoon cover helpers, and background task boundaries.
**Output**: API handlers, docs/OpenAPI schemas, and tested no-secret behavior.
**Acceptance**: Unit 6a tests pass; upload, active cover, archive, regenerate, and spoon-cover flows match web behavior.

### ⬜ Unit 6c: Recipe Image And Cover Lifecycle API - Coverage & Refactor
**What**: Run focused cover/image tests, typecheck, docs/OpenAPI drift tests, coverage, and warning checks.
**Output**: `web/unit-6c-covers-green.log`, `web/unit-6c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched cover/image code has 100% coverage and every provider/blocker/error branch is tested.

### ⬜ Unit 7a: Spoon Cook Log API - Tests
**What**: Write failing tests for `GET/POST/PATCH/DELETE /api/v1/recipes/{id}/spoons/{spoonId?}` covering list pagination, create, update, delete, photo URL/upload contract, note/nextTime/cookedAt validation, owner checks, origin-cook notification flags, deleted spoons, and cover-from-spoon integration.
**Output**: `test/routes/api-v1-spoons.test.ts` and `web/unit-7a-spoons-red.log`.
**Acceptance**: Tests fail before v1 spoon handlers exist and assert exact response envelopes plus private/public cache behavior.

### ⬜ Unit 7b: Spoon Cook Log API - Implementation
**What**: Implement spoon handlers using `app/lib/recipe-spoon.server.ts`, recipe detail serializers, notification helpers, and v1 idempotency for writes.
**Output**: API handlers, serializers, docs/OpenAPI schemas, and playground examples.
**Acceptance**: Unit 7a tests pass; spoon list/detail payloads feed native cook log, profile, Spotlight, and cover-from-spoon flows.

### ⬜ Unit 7c: Spoon Cook Log API - Coverage & Refactor
**What**: Run focused spoon tests, typecheck, docs/OpenAPI drift tests, coverage, and warning checks.
**Output**: `web/unit-7c-spoons-green.log`, `web/unit-7c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched spoon API code has 100% coverage and deleted/owner/error branches are covered.

### ⬜ Unit 8a: Cookbook Write API - Tests
**What**: Write failing tests for `POST /api/v1/cookbooks`, `PATCH /api/v1/cookbooks/{id}`, `DELETE /api/v1/cookbooks/{id}`, `POST /api/v1/cookbooks/{id}/recipes/{recipeId}`, and `DELETE /api/v1/cookbooks/{id}/recipes/{recipeId}` with `clientMutationId` idempotency.
**Output**: `test/routes/api-v1-cookbook-writes.test.ts` and `web/unit-8a-cookbook-writes-red.log`.
**Acceptance**: Tests fail before write handlers exist and cover duplicate titles, missing recipes, already-added recipes, owner checks, delete semantics, replay, conflict, and in-progress idempotency.

### ⬜ Unit 8b: Cookbook Write API - Implementation
**What**: Implement cookbook write handlers using Prisma cookbook relations and v1 idempotency helpers.
**Output**: API handlers, serializers, docs/OpenAPI schemas, and playground examples.
**Acceptance**: Unit 8a tests pass; cookbook detail reads reflect mutations and native offline sync receives updated/tombstoned cookbook records.

### ⬜ Unit 8c: Cookbook Write API - Coverage & Refactor
**What**: Run focused cookbook write tests, typecheck, docs/OpenAPI drift tests, coverage, and warning checks.
**Output**: `web/unit-8c-cookbook-writes-green.log`, `web/unit-8c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched cookbook API code has 100% coverage and all idempotency branches are tested.

### ⬜ Unit 9a: Shopping Parity API - Tests
**What**: Write failing tests for `POST /api/v1/shopping-list/add-from-recipe`, `POST /api/v1/shopping-list/clear-completed`, and `POST /api/v1/shopping-list/clear-all`, preserving existing add/check/delete behavior.
**Output**: Extensions to `test/routes/api-v1-shopping-mutations.test.ts` and `web/unit-9a-shopping-parity-red.log`.
**Acceptance**: Tests fail before handlers exist and cover scale factor, checked/deleted rows, empty list, owner recipes, public recipe add, idempotency replay/conflict, and exact mutation envelopes.

### ⬜ Unit 9b: Shopping Parity API - Implementation
**What**: Implement shopping parity handlers using `app/lib/shopping-list.server.ts` behavior and v1 idempotency helpers.
**Output**: API handlers, docs/OpenAPI schemas, and playground examples.
**Acceptance**: Unit 9a tests pass; existing shopping v1 tests remain green.

### ⬜ Unit 9c: Shopping Parity API - Coverage & Refactor
**What**: Run focused shopping tests, typecheck, docs/OpenAPI drift tests, coverage, and warning checks.
**Output**: `web/unit-9c-shopping-parity-green.log`, `web/unit-9c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched shopping API code has 100% coverage and no regressions in existing idempotent item mutations.

### ⬜ Unit 10a: Private Sync Tombstone Freshness API - Tests
**What**: Write failing tests for `GET /api/v1/me/sync` covering cursor validation, page limits, updated records, tombstoned recipes/cookbooks/spoons/shopping items, profile/preference deltas, freshness metadata, and private no-store headers.
**Output**: `test/routes/api-v1-native-sync.test.ts` and `web/unit-10a-sync-red.log`.
**Acceptance**: Tests fail before sync payload exists and assert deterministic cursor ordering plus tombstone shapes for offline cache reconciliation.

### ⬜ Unit 10b: Private Sync Tombstone Freshness API - Implementation
**What**: Implement private sync handlers and serializers for current chef data, recipes, cookbooks, spoons, shopping items, profiles, notification preferences, deleted/tombstoned objects, and freshness metadata.
**Output**: `app/lib/api-v1.server.ts` sync handlers plus extracted serializers.
**Acceptance**: Unit 10a tests pass; sync output is stable across pages and can rebuild native cache from scratch.

### ⬜ Unit 10c: Private Sync Tombstone Freshness API - Coverage & Refactor
**What**: Run focused sync tests, route coverage, typecheck, docs/OpenAPI drift tests, coverage, and warning checks.
**Output**: `web/unit-10c-sync-green.log`, `web/unit-10c-typecheck.log`, and coverage artifact.
**Acceptance**: Touched sync code has 100% coverage, including invalid cursors, empty states, and tombstone-only pages.

### ⬜ Unit 11a: Native Request Builders For Expanded REST V1 - Tests
**What**: In `spoonjoy-apple`, write failing Swift tests for request builders covering every new backend endpoint, auth policy, JSON/form/multipart bodies, idempotency keys, query/cursor handling, private/public cache metadata, and error envelope decoding.
**Output**: `Tests/SpoonjoyCoreTests/NativeAPIExpansionTests.swift` and `apple/unit-11a-native-api-red.log`.
**Acceptance**: Tests fail before Swift request builders/models exist and every test captures outbound method, URL path/query, headers, and body.

### ⬜ Unit 11b: Native Request Builders For Expanded REST V1 - Implementation
**What**: Implement expanded request builders and models under `Sources/SpoonjoyCore/API/`, including account, profile, search, recipe writes, covers, spoons, cookbooks, shopping parity, sync, tokens, APNs, and docs handoff URL requests.
**Output**: Swift API files and model serializers.
**Acceptance**: Unit 11a tests pass; no request builder sends bearer tokens to anonymous public catalog reads by default.

### ⬜ Unit 11c: Native Request Builders For Expanded REST V1 - Coverage & Refactor
**What**: Run focused Swift API tests, full `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors`, Swift coverage, and coverage enforcement for `Sources/SpoonjoyCore/API`.
**Output**: `apple/unit-11c-native-api-green.log`, coverage JSON path, and coverage enforcement log.
**Acceptance**: New Swift API code has 100% measured coverage and no warnings.

### ⬜ Unit 12a: Native URLSession Transport And Error Pipeline - Tests
**What**: Write failing Swift tests for a mockable `URLSession` transport, retry policy, refresh integration hooks, request-id propagation, offline detection, cancellation, malformed JSON, server error envelopes, 401 refresh flow, 429 retry-after, and non-JSON failure handling.
**Output**: `Tests/SpoonjoyCoreTests/APITransportTests.swift` and `apple/unit-12a-transport-red.log`.
**Acceptance**: Tests fail before transport exists and assert recorded outbound `URLRequest` shape plus response decoding.

### ⬜ Unit 12b: Native URLSession Transport And Error Pipeline - Implementation
**What**: Implement `SpoonjoyAPITransport`, mock transport protocol, response decoder, retry/error mapper, request-id propagation, and offline classification under `Sources/SpoonjoyCore/API/`.
**Output**: Transport source files and tests.
**Acceptance**: Unit 12a tests pass; transport is injectable into repositories and app targets without global singletons.

### ⬜ Unit 12c: Native URLSession Transport And Error Pipeline - Coverage & Refactor
**What**: Run focused transport tests, full Swift tests, Swift build, coverage enforcement for API transport files, and warning scan.
**Output**: `apple/unit-12c-transport-green.log`, `apple/unit-12c-coverage.log`, and warning log.
**Acceptance**: Transport code has 100% measured coverage and no warnings.

### ⬜ Unit 13a: Native OAuth, Keychain, And Session Store - Tests
**What**: Write failing Swift tests and app static checks for ASWebAuthenticationSession launch/callback routing, universal-link OAuth redirect, Keychain token vault, persisted client id, refresh-token rotation, revoke/logout, auth state restoration, and exact secure web handoff URLs.
**Output**: `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift`, app static contract tests, and `apple/unit-13a-auth-red.log`.
**Acceptance**: Tests fail before Keychain/app auth integration exists; custom scheme OAuth redirects remain rejected.

### ⬜ Unit 13b: Native OAuth, Keychain, And Session Store - Implementation
**What**: Implement Keychain-backed vault in app target, session repository in `Sources/SpoonjoyCore/Auth`, ASWebAuthenticationSession adapters, universal-link callback handling, and settings sign-in/out/revoke actions.
**Output**: Auth/session Swift sources, app adapter sources, project generator updates, and docs for local non-production signing.
**Acceptance**: Unit 13a tests pass; app static checks prove associated-domain OAuth callback and custom-scheme fallback are separate.

### ⬜ Unit 13c: Native OAuth, Keychain, And Session Store - Coverage & Refactor
**What**: Run focused auth tests, full Swift tests, project generator contract, macOS/iOS app build or blocker artifact, coverage enforcement, and warning scan.
**Output**: `apple/unit-13c-auth-green.log`, coverage artifact, and app build logs.
**Acceptance**: SwiftPM auth code has 100% coverage; app adapter compile/static checks cover Keychain and ASWebAuthenticationSession boundaries.

### ⬜ Unit 14a: Native Cache Schema And Freshness Indicator - Tests
**What**: Write failing Swift tests for durable cache schema version 2, cached recipes/cookbooks/details/shopping/cook progress/capture/profile/notifications/tokens/connections/APNs status, freshness states, dismissed indicator persistence, stale thresholds, sync failure display, queued-work display, and corrupt-cache recovery.
**Output**: `Tests/SpoonjoyCoreTests/NativeCacheFreshnessTests.swift` and `apple/unit-14a-cache-red.log`.
**Acceptance**: Tests fail before expanded cache/freshness model exists and assert exact state transitions for synced, offline, stale, queued, failed, and dismissed states.

### ⬜ Unit 14b: Native Cache Schema And Freshness Indicator - Implementation
**What**: Implement expanded offline snapshot/cache models, freshness state machine, dismissible indicator state, cache migration from schema version 1, and app `OfflineStatusView` updates.
**Output**: Swift core cache files, updated `OfflineStatusView.swift`, fixtures, and scenario verifier metadata.
**Acceptance**: Unit 14a tests pass; dismissing the indicator persists only the dismissal state and never hides sync failure or conflict state.

### ⬜ Unit 14c: Native Cache Schema And Freshness Indicator - Coverage & Refactor
**What**: Run focused cache tests, full Swift tests, coverage enforcement for `Sources/SpoonjoyCore/Offline` and `AppState`, scenario verifier stage, and warning scan.
**Output**: `apple/unit-14c-cache-green.log`, coverage artifact, and scenario report.
**Acceptance**: Cache/freshness code has 100% measured coverage and UI static checks prove indicator labels/icons for every state.

### ⬜ Unit 15a: Native Sync Engine And Mutation Queue Expansion - Tests
**What**: Write failing Swift tests for sync bootstrapping, foreground/network recovery, cursor checkpoints, conflict classification, retry backoff, queue drain, replay removal, tombstone application, and queued mutation kinds for recipe, cookbook, spoon, cover, shopping, profile, notification, APNs, and capture/import writes.
**Output**: `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift` and `apple/unit-15a-sync-engine-red.log`.
**Acceptance**: Tests fail before sync engine exists and assert outgoing request order plus cache mutation results.

### ⬜ Unit 15b: Native Sync Engine And Mutation Queue Expansion - Implementation
**What**: Implement native repositories, sync engine, mutation queue expansion, conflict models, and retry scheduling under `Sources/SpoonjoyCore/Offline` and `Sources/SpoonjoyCore/AppState`.
**Output**: Sync engine sources, repository protocols, fixtures, and scenario verifier updates.
**Acceptance**: Unit 15a tests pass; offline writes survive app restart and drain once transport reports network success.

### ⬜ Unit 15c: Native Sync Engine And Mutation Queue Expansion - Coverage & Refactor
**What**: Run focused sync-engine tests, full Swift tests, coverage enforcement, scenario verifier final-stage subset, and warning scan.
**Output**: `apple/unit-15c-sync-engine-green.log`, coverage artifact, and scenario report.
**Acceptance**: Sync engine code has 100% measured coverage and no hidden untested error branches.

### ⬜ Unit 16a: Native Live Store And Shell Wiring - Tests
**What**: Write failing Swift tests/static checks for replacing fixture-primary app state with live repositories, bootstrap loading, signed-out state, signed-in cache restore, environment switching, global search scopes, and deterministic fixture fallback only in tests/demo.
**Output**: `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift`, shell static checks, and `apple/unit-16a-live-store-red.log`.
**Acceptance**: Tests fail before live store wiring exists and assert no production path silently uses fixtures after auth/cache bootstrap succeeds.

### ⬜ Unit 16b: Native Live Store And Shell Wiring - Implementation
**What**: Wire `SpoonjoyRootView`, `PlatformNavigationView`, settings model, and shared app store to auth/session/transport/cache/sync repositories.
**Output**: App shell Swift updates, project generator updates, and scenario verifier checks.
**Acceptance**: Unit 16a tests pass; shell can render signed-out, restoring cache, live synced, offline stale, and sync-failed states.

### ⬜ Unit 16c: Native Live Store And Shell Wiring - Coverage & Refactor
**What**: Run focused live-store tests, full Swift tests, scenario verifier surfaces stage, macOS typecheck/build, project contract, and warning scan.
**Output**: `apple/unit-16c-live-store-green.log`, scenario report, and build logs.
**Acceptance**: Store logic has 100% measured coverage and app target static/screenshot checks cover non-SwiftPM shell adapters.

### ⬜ Unit 17a: Native Recipe Detail Cook Mode And Editor Surfaces - Tests
**What**: Write failing Swift tests/static scenario checks for recipe catalog/detail, cover/provenance, scale factor, ingredient and step-output checkoff, duration timers, cook progress persistence, create/edit/delete, step/ingredient/dependency forms, fork, save to cookbook, add ingredients to shopping, owner tools, and share actions.
**Output**: `Tests/SpoonjoyCoreTests/RecipeSurfaceParityTests.swift`, surface contract tests, and `apple/unit-17a-recipe-surfaces-red.log`.
**Acceptance**: Tests fail before parity surfaces exist and assert exact view model states plus route actions for every web recipe concept.

### ⬜ Unit 17b: Native Recipe Detail Cook Mode And Editor Surfaces - Implementation
**What**: Implement recipe catalog/detail/cook/editor surfaces and view models using live repositories, native controls, offline queueing, and Spoonjoy design language.
**Output**: Updated `RecipesView.swift`, `RecipeDetailView.swift`, `CookModeView.swift`, new editor components, view models, and scenario metadata.
**Acceptance**: Unit 17a tests pass; native flows use live contracts or queued mutations and do not invent comments/feed/reactions.

### ⬜ Unit 17c: Native Recipe Detail Cook Mode And Editor Surfaces - Coverage & Refactor
**What**: Run focused recipe-surface tests, full Swift tests, surface contract scripts, scenario verifier surfaces/final subset, screenshots, and warning scan.
**Output**: `apple/unit-17c-recipe-surfaces-green.log`, screenshot artifacts, and scenario report.
**Acceptance**: View-model code has 100% measured coverage; UI static/screenshot checks show no text overlap and Kitchen Table hierarchy is preserved.

### ⬜ Unit 18a: Native Spoons Covers Capture And Sharing Surfaces - Tests
**What**: Write failing Swift tests/static checks for cook log list/create/edit/delete, photo/note/nextTime/cookedAt drafts, cover history/set/remove/regenerate/archive/from-spoon, capture draft URL/text/camera/share-sheet intake, import submission, and recipe/cookbook/shopping share payloads.
**Output**: `Tests/SpoonjoyCoreTests/SpoonCoverCaptureSharingTests.swift`, surface contract tests, and `apple/unit-18a-spoon-cover-red.log`.
**Acceptance**: Tests fail before surfaces exist and assert offline draft behavior plus exact native share values.

### ⬜ Unit 18b: Native Spoons Covers Capture And Sharing Surfaces - Implementation
**What**: Implement spoon/cook-log UI, cover controls, capture/import UI, and first-class `ShareLink`/transfer payloads without Messages/Mail schemas.
**Output**: App Swift views/components, view models, project generator updates, and scenario verifier updates.
**Acceptance**: Unit 18a tests pass; capture and spoon photo workflows use local drafts offline and sync through REST v1.

### ⬜ Unit 18c: Native Spoons Covers Capture And Sharing Surfaces - Coverage & Refactor
**What**: Run focused spoon/cover/capture/share tests, full Swift tests, surface scripts, scenario verifier, screenshots, and warning scan.
**Output**: `apple/unit-18c-spoon-cover-green.log`, screenshot artifacts, and coverage logs.
**Acceptance**: View-model/share logic has 100% measured coverage and UI adapters have static/screenshot coverage.

### ⬜ Unit 19a: Native Cookbooks Profiles Settings Notifications Surfaces - Tests
**What**: Write failing Swift tests/static checks for cookbook detail/create/rename/delete/add/remove recipe, profile views, fellow chefs, kitchen visitors, settings session/API token status/create/revoke, OAuth connection status/disconnect, notification preferences, APNs registration state, and secure web-auth handoff routes.
**Output**: `Tests/SpoonjoyCoreTests/CookbookProfileSettingsParityTests.swift`, surface contract tests, and `apple/unit-19a-settings-red.log`.
**Acceptance**: Tests fail before surfaces exist and assert exact view model states, destructive confirmations, and offline/cache fallbacks.

### ⬜ Unit 19b: Native Cookbooks Profiles Settings Notifications Surfaces - Implementation
**What**: Implement cookbook/profile/settings/notification/API credential surfaces using native forms, lists, toolbars, confirmations, and secure web handoff for passkey/password/provider-link actions.
**Output**: Updated `CookbooksView.swift`, `SettingsView.swift`, profile views, settings components, and scenario verifier updates.
**Acceptance**: Unit 19a tests pass; API credential list/create/revoke and notification preferences are native REST-backed flows.

### ⬜ Unit 19c: Native Cookbooks Profiles Settings Notifications Surfaces - Coverage & Refactor
**What**: Run focused cookbook/profile/settings tests, full Swift tests, surface scripts, scenario verifier, screenshots, macOS build, and warning scan.
**Output**: `apple/unit-19c-settings-green.log`, screenshot artifacts, and coverage logs.
**Acceptance**: View-model code has 100% measured coverage and native design review confirms platform-correct controls.

### ⬜ Unit 20a: Universal Links Routes And AASA Contract - Tests
**What**: Write failing Swift and web tests for every `spoonjoy.app` route and `spoonjoy://` fallback route needed by native parity, including profiles, fellow chefs, kitchen visitors, account sections, notification preferences, API credentials, cookbook actions, spoon logging, covers, shopping clear/add-from-recipe, search, capture, and OAuth redirect.
**Output**: `Tests/SpoonjoyCoreTests/DeepLinkParityTests.swift`, web AASA tests, and `apple/unit-20a-links-red.log`.
**Acceptance**: Tests fail until route parser/builders and web AASA docs cover the full route list; OAuth redirect remains HTTPS universal link only.

### ⬜ Unit 20b: Universal Links Routes And AASA Contract - Implementation
**What**: Expand `DeepLinkRouter`, `DeepLinkURLBuilder`, app route handling, Info.plist/entitlements metadata, web AASA route contract, and validation artifacts.
**Output**: Swift routing updates, web `.well-known`/devtools route updates, and AASA validation docs.
**Acceptance**: Unit 20a tests pass; unknown routes go to safe unknown-link state.

### ⬜ Unit 20c: Universal Links Routes And AASA Contract - Coverage & Refactor
**What**: Run focused link tests, project generator contract, AASA validator, scenario verifier, typecheck/builds, and warning scan.
**Output**: `apple/unit-20c-links-green.log`, `web/unit-20c-aasa-green.log`, and AASA blocker/validation artifact.
**Acceptance**: Production AASA validation is green or blocked only by missing Apple Team ID/App ID.

### ⬜ Unit 21a: App Entities Queries Spotlight And App Shortcuts - Tests
**What**: Write failing Swift tests/static AppIntents checks for `AppEntity`, `EntityQuery`, `EntityStringQuery`, display representations, Spotlight documents, indexed identifiers, App Shortcuts phrases, entity disambiguation, and transfer values for recipes, cookbooks, shopping items/lists, spoons, chefs, profiles, and capture drafts.
**Output**: `Tests/SpoonjoyCoreTests/AppIntentEntityTests.swift`, app static checks, and `apple/unit-21a-app-entities-red.log`.
**Acceptance**: Tests fail before entity-backed App Intents exist and prove string-ID-only intents are no longer sufficient.

### ⬜ Unit 21b: App Entities Queries Spotlight And App Shortcuts - Implementation
**What**: Implement entity models/queries in app target, live-cache-backed lookup, Spotlight indexing from cached data, App Shortcuts provider/phrases, transfer/value representations, and guarded WWDC26/27 APIs with blocker artifacts for symbols absent from installed SDK.
**Output**: Updated `SpoonjoyAppIntents.swift`, `SpoonjoySpotlightIndexer.swift`, core metadata, project generator updates, and scenario verifier updates.
**Acceptance**: Unit 21a tests pass; Spotlight indexes live cached entities, including spoons/cook logs, not fixture-only data.

### ⬜ Unit 21c: App Entities Queries Spotlight And App Shortcuts - Coverage & Refactor
**What**: Run AppIntents static/AppIntentsTesting coverage, Swift tests, scenario verifier native metadata/final subset, app builds, and warning scan.
**Output**: `apple/unit-21c-app-entities-green.log`, scenario report, and build logs.
**Acceptance**: Entity/query/Shortcut contracts are covered by compiled tests or structured SDK blocker artifacts.

### ⬜ Unit 22a: Entity-Backed Siri Intents And Confirmations - Tests
**What**: Write failing Swift tests/static checks for entity-backed intents: open/search/share/start cook/continue cook/add shopping/check shopping/remove shopping/clear completed/add recipe ingredients/log cook/create capture/fork/save-to-cookbook/create cookbook/rename cookbook/delete cookbook/add recipe to cookbook/remove recipe from cookbook/profile open/notification preference update.
**Output**: `Tests/SpoonjoyCoreTests/AppIntentActionTests.swift`, app static checks, and `apple/unit-22a-app-intents-red.log`.
**Acceptance**: Tests fail before intents exist and assert confirmation/auth/ownership policy for all sensitive or destructive writes.

### ⬜ Unit 22b: Entity-Backed Siri Intents And Confirmations - Implementation
**What**: Implement intent action resolvers, confirmations, authentication policy, ownership checks, request-value/disambiguation behavior, donations, relevant entities, and offline queue behavior for Siri-triggered writes.
**Output**: App Intents source updates, core resolver updates, cache/sync integration, and scenario verifier updates.
**Acceptance**: Unit 22a tests pass; Siri writes use the same mutation queue and REST contracts as the app UI.

### ⬜ Unit 22c: Entity-Backed Siri Intents And Confirmations - Coverage & Refactor
**What**: Run focused intent action tests, AppIntentsTesting/static checks, Swift tests, app builds, scenario verifier, and warning scan.
**Output**: `apple/unit-22c-app-intents-green.log`, scenario report, and build logs.
**Acceptance**: Intent contracts have no string-ID-only action paths and every destructive path has confirmation/auth evidence.

### ⬜ Unit 23a: Native Design Accessibility And Visual Validation - Tests
**What**: Add failing design/accessibility static checks for dynamic type, VoiceOver labels, keyboard navigation, reduce motion, contrast, no text overlap, Spoonjoy Kitchen Table hierarchy, mobile screenshots, and desktop screenshots.
**Output**: Design validator updates and `apple/unit-23a-design-red.log`.
**Acceptance**: Checks fail until every new surface reports the required accessibility/design manifest coverage.

### ⬜ Unit 23b: Native Design Accessibility And Visual Validation - Implementation
**What**: Update native views/components/styles to satisfy design/accessibility checks, regenerate project, capture screenshots, and produce `design-review.json`.
**Output**: UI polish changes, screenshot artifacts, design review manifest, and updated native design docs.
**Acceptance**: Unit 23a checks pass; screenshots show native controls with Spoonjoy design language and no incoherent overlap.

### ⬜ Unit 23c: Native Design Accessibility And Visual Validation - Coverage & Refactor
**What**: Run design validator, screenshot capture, macOS/iOS smoke, scenario verifier, app builds, and warning scan.
**Output**: `apple/unit-23c-design-green.log`, screenshots, and `design-review.json`.
**Acceptance**: Design/accessibility validation is green or blocked only by CoreSimulator/Xcode capability artifact.

### ⬜ Unit 24a: API Documentation And Native Dogfood Guide - Tests
**What**: Write failing docs tests for native quickstart, OAuth universal-link callback, Keychain persistence, token refresh, endpoint examples, DELETE idempotency guidance, scope defaults, REST vs MCP token rules, and SDK/OpenAPI profiles.
**Output**: Docs test changes and `web/unit-24a-docs-red.log`.
**Acceptance**: Tests fail before docs are updated and catch the documented drifts from the API audit.

### ⬜ Unit 24b: API Documentation And Native Dogfood Guide - Implementation
**What**: Update `docs/api.md`, developer routes, generated playground/profile docs, OpenAPI examples, and native repo docs to describe the exact contracts dogfooded by Spoonjoy Apple.
**Output**: Docs, generated playground output, and native dogfood guide references.
**Acceptance**: Unit 24a docs tests pass; docs state `spoonjoy.app`, HTTPS OAuth redirect, persisted `client_id`, token storage, refresh, DELETE idempotency options, and REST/MCP resource-token boundaries.

### ⬜ Unit 24c: API Documentation And Native Dogfood Guide - Coverage & Refactor
**What**: Run docs tests, route coverage, generated playground drift check, `pnpm run typecheck`, and `pnpm run build`.
**Output**: `web/unit-24c-docs-green.log`, build logs, and drift summary.
**Acceptance**: Docs/build/typecheck are green with zero warnings.

### ⬜ Unit 25a: Web Full Validation - Tests
**What**: Run targeted red/green evidence audit for all web tests created in Units 1-10 and 24, ensuring artifacts exist for red and green phases and no touched endpoint lacks a matching test file.
**Output**: `web/unit-25a-validation-audit.log`.
**Acceptance**: Audit fails until every touched route/lib/doc contract has red and green artifacts in the task artifact directory.

### ⬜ Unit 25b: Web Full Validation - Implementation
**What**: Run `pnpm run api:playground:generate`, targeted Vitest suites for every touched API surface, `pnpm run test:coverage`, `pnpm run typecheck`, and `pnpm run build`; fix any failures with tests-first sub-units.
**Output**: `web/full-test-coverage.log`, `web/typecheck.log`, `web/build.log`, `web/api-playground-generate.log`, and targeted suite logs.
**Acceptance**: All web commands pass with zero warnings; coverage meets repo policy; no generated drift remains.

### ⬜ Unit 25c: Web Full Validation - Coverage & Refactor
**What**: Run harsh API contract reviewer and docs reviewer against the final web diff and validation artifacts.
**Output**: `web/api-contract-review.md`, `web/docs-review.md`, and final web validation summary.
**Acceptance**: Reviewers converge with no BLOCKER/MAJOR findings; any MINOR/NIT disposition is recorded in the doing progress log.

### ⬜ Unit 26a: Native Full Validation - Tests
**What**: Run native validation audit proving artifacts exist for Swift red/green phases, coverage, AppIntents/static checks, scenario verifier, app bundle builds, screenshots, design review, AASA validation/blocker, macOS smoke, and iOS simulator smoke.
**Output**: `apple/unit-26a-validation-audit.log`.
**Acceptance**: Audit fails until every native unit has red/green evidence and final validation prerequisites are present.

### ⬜ Unit 26b: Native Full Validation - Implementation
**What**: Run `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors`, Swift coverage, `scripts/enforce-swift-coverage.rb`, `scripts/verify-native-scenarios.sh --stage final`, `scripts/validate-native-local.sh --artifact-root tasks/2026-06-16-1754-doing-siri-full-access-parity`, project generator contract, app bundle builds, macOS launch/smoke, iOS simulator smoke, screenshots, and design review.
**Output**: Native full validation matrix and command logs under `apple/` and the task artifact root.
**Acceptance**: All native commands pass or produce structured true blocker artifacts limited to SDK/Xcode/CoreSimulator/Apple Team ID capability.

### ⬜ Unit 26c: Native Full Validation - Coverage & Refactor
**What**: Run harsh native design, offline/sync, App Intents, and implementation reviewers against the final native diff and validation artifacts.
**Output**: `apple/native-design-review.md`, `apple/offline-sync-review.md`, `apple/app-intents-review.md`, `apple/implementation-review.md`.
**Acceptance**: Reviewers converge with no BLOCKER/MAJOR findings; every reviewer finding has a fix commit or documented no-op disposition.

### ⬜ Unit 27: PRs, CI, Merge, Cleanup, Desk, Slugger
**What**: Split or preserve atomic PRs for `spoonjoy-v2` and `spoonjoy-apple`, push branches, open PRs, wait for protected checks, run harsh merge-readiness reviewer, merge to `main`, sync local repos, clean temporary worktrees/branches, update Desk state, add lessons/friction, and notify Slugger.
**Output**: PR URLs, CI JSON, merge evidence, local final status, Desk updates, and `ouro msg --to slugger "Done: ..."` output.
**Acceptance**: PR checks pass or structured true blockers are recorded; both repos are clean on synced `main`; Slugger is notified; final user report includes validation and any true blockers.

## Execution

- **TDD strictly enforced**: tests -> red -> implement -> green -> refactor.
- Commit after each phase (`Xa`, `Xb`, `Xc`) in the repo whose files changed.
- Push after each commit.
- Save every command log under `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity/`, using `web/` for `spoonjoy-v2` logs and `apple/` for `spoonjoy-apple` logs.
- Spawn implementor sub-agents for disjoint write scopes within each dependency wave; the orchestrator reviews, integrates, and owns commits.
- Spawn harsh reviewer sub-agents after non-trivial units, plus dedicated API contract, offline/sync, native design, App Intents, docs, and merge-readiness reviews.
- Treat only credentials, paid Apple Developer Program enrollment, production secrets, unavailable local hardware/runtime, unavailable SDK symbols, and destructive production operations without a staged path as human-only blockers.
- Run web commands from `/Users/arimendelow/Projects/spoonjoy-v2`; run native commands from `/Users/arimendelow/Projects/spoonjoy-apple`.
- Use `pnpm run test:coverage`, `pnpm run typecheck`, and `pnpm run build` for final web validation.
- Use `scripts/validate-native-local.sh --artifact-root tasks/2026-06-16-1754-doing-siri-full-access-parity` for final native validation after focused Swift and app checks are green.
- Do not invent comments, recipe threads, social feeds, generic reactions/likes, meal planning, nutrition/fitness, pantry inventory, or media-library surfaces during implementation.

## Progress Log

- 2026-06-16 18:23 Created from planning doc.
