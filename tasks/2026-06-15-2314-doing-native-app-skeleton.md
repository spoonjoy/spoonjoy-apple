# Doing: Native App Skeleton

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-06-15 23:14
**Planning**: ./2026-06-15-2314-planning-native-app-skeleton.md
**Artifacts**: ./tasks/2026-06-15-2314-doing-native-app-skeleton/

## Execution Mode

- **direct**: Execute units sequentially in current session because package structure, Xcode project generation, CI, app shell, and validation scripts are tightly coupled. Use sub-agents for reviewer gates and bounded sidecar implementation only when write scopes are disjoint.

## Objective

Build the first complete, runnable native Spoonjoy Apple app slice: a protected, reproducible SwiftUI/Xcode project with iOS and macOS app bundles, testable domain/API/offline logic, and native-value surfaces that prove this is not a web clone.

## Upstream Work Items

- None

## Completion Criteria

- [ ] `Package.swift` exists and the warning-enforced Swift test command passes with focused coverage for all new core logic and edge/error paths.
- [ ] `Spoonjoy.xcodeproj` exists and `BootstrapDebug` app bundles build for iOS simulator and macOS destinations with warnings treated as errors.
- [ ] The native scenario verifier proves first-run/session setup, fixture kitchen browsing, recipe detail, cook-mode progress persistence, shopping-list checkoff, search, capture draft creation, settings state, App Intent/search indexing metadata, offline cache restore, and native affordance flags through deterministic command-line checks.
- [ ] The app registers native link entry points for `spoonjoy.app`: Associated Domains include `applinks:spoonjoy.app`, the app bundle declares a `spoonjoy` custom URL scheme fallback, and deterministic route parsing opens canonical web links in the correct native screen.
- [ ] iOS simulator launch/smoke runs when CoreSimulator responds; if local CoreSimulator times out, the result is recorded as a local machine blocker while CI still builds the iOS bundle. macOS app launch/smoke must run locally.
- [ ] Screenshot/design review artifacts exist for mobile-width and desktop-class layouts, or the plan records a concrete simulator/runtime blocker with the last command output.
- [ ] App surfaces visibly use native navigation/search/toolbars/share/edit/check controls while preserving Kitchen Table hierarchy: a lead food/cookbook/list object, cookbook-style recipe detail, receipt-like shopping list, and focused cook-mode surface.
- [ ] `docs/native-justification.md` explains why Spoonjoy Apple earns being native and which tempting APIs are intentionally postponed or rejected.
- [ ] `docs/native-design-language.md` remains consistent with the web Kitchen Table language and the app code reflects those invariants in structure, naming, colors, typography, and object hierarchy.
- [ ] CI protected checks pass on the PR: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`.
- [ ] The `Coverage` check enforces the configured Swift package coverage threshold for new SwiftPM-measurable code instead of only generating coverage output.
- [ ] Harsh sub-agent review converges with no BLOCKER/MAJOR findings before merge.

## Code Coverage Requirements

**MANDATORY: 100% coverage on all new SwiftPM-measurable code, plus behavioral checks for scripts and app-target adapters.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code.
- All branches covered where SwiftPM coverage can measure them.
- All error paths tested.
- Edge cases: null/nil, empty, boundary values, malformed URLs, malformed JSON, invalid cursors, invalid OAuth state, expired token state, and idempotency conflicts.
- Request-building tests must capture outbound method, URL path/query, headers, and JSON/form body shape.
- OAuth/PKCE tests must cover code-verifier/challenge generation, state generation/validation, register/authorize/token/refresh/revoke request construction, redirect validation, persisted client id, atomic refresh-token rotation, and single-flight refresh behavior.
- Shopping-list mutation tests must cover POST/PATCH JSON `clientMutationId`, DELETE idempotency through `X-Client-Mutation-Id`, query, and body forms, plus idempotency conflict/in-progress response handling.
- UI app target code is covered through compile/build plus scenario verifier until XCTest UI automation is added; nontrivial UI-independent logic belongs in the Swift package.
- `Sources/SpoonjoyScenarioVerifier/main.swift` must remain a thin, non-branching adapter. CLI parsing/report generation logic belongs in `Sources/SpoonjoyCore/Native/` so SwiftPM coverage measures it; the executable wrapper is covered by command-level verifier tests.
- Shell/Ruby scripts are not SwiftPM-measurable; each script must have red/green behavioral checks before it is trusted by CI.

## TDD Requirements

**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE implementation.
2. **Verify failure**: Run tests and confirm they FAIL (red).
3. **Minimal implementation**: Write just enough code to pass.
4. **Verify pass**: Run tests and confirm they PASS (green).
5. **Refactor**: Clean up, keep tests green.
6. **No skipping**: Never write implementation without failing tests first.

## Contract Constants

- **Artifact root**: `tasks/2026-06-15-2314-doing-native-app-skeleton/`. Every log, JSON report, screenshot, branch-protection export, PR export, and blocker record goes under this path.
- **CI runner**: GitHub Actions jobs use `runs-on: macos-26` and must verify `xcodebuild -version` reports `Xcode 26.5` before running native checks.
- **Swift test command**: `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors`. Filtered red/green units use `swift test --filter <ExactTestClassOrMethod> --disable-xctest --parallel -Xswiftc -warnings-as-errors` and save output to `${ARTIFACT_ROOT}/unit-<unit>-red.log` or `${ARTIFACT_ROOT}/unit-<unit>-green.log`. Any unit shorthand that says `swift test --disable-xctest --parallel` inherits this warning-enforced command.
- **Coverage command**: `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors`, followed by `swift test --show-codecov-path` to locate the generated JSON. On SwiftPM in Xcode 26.5, `--show-codecov-path` is a path locator and does not itself run tests/export coverage. The coverage threshold is exactly `100.0` percent for SwiftPM-measurable files under `Sources/SpoonjoyCore/`. Exclude only generated Xcode project files, thin executable wrappers, `Apps/` SwiftUI view files, `.build/`, `Tests/`, and scripts after behavioral tests prove those excluded adapters.
- **Coverage input**: the JSON path printed by the separate `swift test --show-codecov-path` locator. `scripts/enforce-swift-coverage.rb --coverage-json <path> --minimum 100 --include 'Sources/SpoonjoyCore'` must fail below threshold.
- **API base**: `https://spoonjoy.app`. REST paths for this slice: `/api/v1/recipes`, `/api/v1/recipes/{id}`, `/api/v1/cookbooks`, `/api/v1/cookbooks/{id}`, `/api/v1/shopping-list`, `/api/v1/shopping-list/sync`, `/api/v1/shopping-list/items`, and `/api/v1/shopping-list/items/{itemId}`. OAuth token exchange uses `/oauth/token`; API v1 token-management builders are out of this slice.
- **Deep-link contract**: app links accept `https://spoonjoy.app/`, `/recipes`, `/recipes/{id}`, `/recipes/{id}#cook`, `/recipes/{id}?mode=cook`, `/cookbooks`, `/cookbooks/{id}`, `/shopping-list`, `/search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}`, `/recipes/new`, and `/account/settings`. The `spoonjoy` custom URL scheme must support equivalent fallback routes: `spoonjoy://kitchen`, `spoonjoy://recipes`, `spoonjoy://recipes/{id}`, `spoonjoy://recipes/{id}/cook`, `spoonjoy://cookbooks`, `spoonjoy://cookbooks/{id}`, `spoonjoy://shopping-list`, `spoonjoy://search?q={query}&scope={...}`, `spoonjoy://capture`, and `spoonjoy://settings`. Unknown hosts, unknown paths, malformed IDs, and unsupported search scopes must route to a safe unknown-link state, not crash or silently open the wrong object.
- **Apple link registration**: app targets must declare Associated Domains entitlement `applinks:spoonjoy.app` and Info.plist URL type scheme `spoonjoy`. The web app must serve an Apple App Site Association document for `spoonjoy.app` before production universal-link validation can pass; the exact `TEAMID.app.spoonjoy.Spoonjoy` and macOS app ID entries remain live-validation blocked until an Apple Developer Team ID exists, but all app-side entitlements, route parsing, and fallback scheme behavior are implemented and statically validated now.
- **AASA validation artifact**: final validation must write `aasa-validation.json` when `https://spoonjoy.app/.well-known/apple-app-site-association` is live and valid, or `aasa-production-blocker.json` while Team ID/AASA publication remains blocked. The artifact must name required app IDs `TEAMID.app.spoonjoy.Spoonjoy` and `TEAMID.app.spoonjoy.Spoonjoy.mac`, expected path/component coverage for every canonical route in the deep-link contract, HTTPS no-redirect requirement, fetched status/content-type when available, and the exact blocker reason if production validation cannot pass yet.
- **API envelope**: REST v1 success `{ ok: true, requestId: String, data: ... }`; REST v1 error `{ ok: false, requestId: String, error: { code, message, status } }`. Source refs: `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md`, `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-contract.server.ts`, `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts`.
- **Shopping idempotency**: POST/PATCH send JSON `clientMutationId`; DELETE accepts JSON body `clientMutationId`, `X-Client-Mutation-Id`, or query `clientMutationId` and canonicalizes idempotency body to `{ clientMutationId }`. Source refs: `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md:670`, `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts:1431`, `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts:1435`.
- **OAuth paths**: `/oauth/register`, `/oauth/authorize`, `/oauth/token`, `/oauth/revoke`. Register body includes `client_name`, exact HTTPS or localhost/127.0.0.1 `redirect_uris`, and `token_endpoint_auth_method: "none"`. Authorize sends `response_type=code`, `scope`, `state`, `code_challenge`, `code_challenge_method=S256`, and omits `resource` for REST. Token and revoke are `application/x-www-form-urlencoded`.
- **Fixture paths**: `Sources/SpoonjoyCore/Fixtures/kitchen-fixture.json`, `recipes-fixture.json`, `cookbooks-fixture.json`, `shopping-list-fixture.json`, and `offline-snapshot-fixture.json`.
- **Swift package targets**: `SpoonjoyCore` library target, `SpoonjoyScenarioVerifier` executable target at `Sources/SpoonjoyScenarioVerifier/main.swift`, and `SpoonjoyCoreTests` test target with fixture resources copied from `Sources/SpoonjoyCore/Fixtures`.
- **Scenario verifier command/schema**: `swift run -Xswiftc -warnings-as-errors SpoonjoyScenarioVerifier --stage final --output ${ARTIFACT_ROOT}/scenario-report.json`. Output JSON has `ok: Bool`, `stage: "bootstrap" | "native-metadata" | "surfaces" | "final"`, `checks: [{ name: String, status: "pass" | "fail" | "pending", detail: String }]`, and `nativeCapabilities: { appIntents: [String], spotlightIndexedTypes: [String], searchableScopes: [String], shareActions: [String], offlineFlows: [String], associatedDomains: [String], urlSchemes: [String], deepLinkRoutes: [String] }`. `scripts/verify-native-scenarios.sh --stage final` must call `swift run -Xswiftc -warnings-as-errors` and fails if `ok` is false, any check is `fail` or `pending`, or any required native capability array is empty. Earlier units may run `--stage bootstrap`, `--stage native-metadata`, or `--stage surfaces`; those stages fail on `fail` checks but allow explicitly named `pending` checks for work that lands in later units.
- **Design invariants to encode**: lead object present on Kitchen; Recipe Detail uses hero/provenance/actions plus ingredient receipt and numbered method sections; Shopping List uses receipt rows with large check controls; Cook Mode has one focused step, large controls, persisted progress; Search uses native `.searchable` scopes and typed rows; Capture creates a local draft without claiming server recipe write; Settings includes offline/auth/environment state.
- **Native integrations that must compile**: `SpoonjoyAppIntents` app-target source with at least `OpenRecipeIntent`, `StartCookModeIntent`, and `AddShoppingListItemIntent` when `canImport(AppIntents)`; `SpoonjoySpotlightIndexer` app-target source using `CoreSpotlight` when `canImport(CoreSpotlight)`. Package metadata may describe these capabilities, but app bundle builds must compile the guarded framework-backed code.
- **Accessibility/design manifest schema**: `design-review.json` has booleans `mobileScreenshot`, `desktopScreenshot`, `dynamicType`, `voiceOverLabels`, `keyboardNavigation`, `reduceMotion`, `contrast`, `kitchenTableHierarchy`, `noOverlap`, and optional `blockers[]` entries shaped `{ "capability": String, "command": String, "timeoutSeconds": Int, "outputPath": String }`. Missing or false fields fail unless a matching blocker exists.
- **CoreSimulator timeout rule**: simulator commands use one attempt and a 30-second timeout. Timeout writes a blocker JSON with `capability: "CoreSimulator"`, the exact command, `timeoutSeconds: 30`, and captured output. Other simulator failures fail the unit unless classified by reviewer as local machine capability.
- **Build commands**: iOS bootstrap build is `xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build`. macOS bootstrap build is `xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy -configuration BootstrapDebug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build`.
- **Deployment target policy**: deployment target build settings are actual minimum runtimes, not labels. Product configs must encode the iOS 27/macOS 27 baseline. The generated `BootstrapDebug` config may set `IPHONEOS_DEPLOYMENT_TARGET = 26.5` for iOS simulator bootstrap builds, but must set `MACOSX_DEPLOYMENT_TARGET = 26.2` so the mandatory local macOS launch/smoke can run on this macOS 26.2 host. Release/TestFlight/App Store claims remain blocked until Xcode 27 validation is available.
- **Local macOS smoke floor**: `sw_vers -productVersion` currently reports `26.2`; scripts and generated project checks must fail if `BootstrapDebug` macOS deployment target exceeds the local host major.minor.
- **Protected-check cutoff**: CI bootstrap-passes only while neither `Package.swift` nor `Spoonjoy.xcodeproj` exists. Every native job fails if any root `*.xcodeproj` other than `Spoonjoy.xcodeproj` exists. After `Package.swift` lands, protected checks are expected to fail until the verifier, coverage enforcement, and exact `Spoonjoy.xcodeproj` units land; final PR readiness requires all protected checks green together.

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ✅ Unit 0a: Native Justification And Generator Contract — Tests
**What**: Add failing checks for `docs/native-justification.md` required headings, bootstrap-vs-product deployment-target policy, project generator syntax, dry-run/temp-output mode, and deterministic generator contract.
**Output**: Shell/Ruby checks under `scripts/` or artifact commands proving missing docs/generator fail.
**Acceptance**: The checks fail before the doc/generator implementation exists.

### ✅ Unit 0b: Native Justification And Generator Contract — Implementation
**What**: Add `docs/native-justification.md`, `scripts/generate-xcode-project.rb`, and bootstrap validation notes for iOS simulator 26.5, local macOS smoke floor 26.2, and product baseline 27.
**Output**: Native justification doc and generator script.
**Acceptance**: Unit 0a checks pass; `ruby -c scripts/generate-xcode-project.rb` passes; generator supports a dry-run/temp-output mode without writing `Spoonjoy.xcodeproj`; justification names accepted/rejected native platform levers.

### ✅ Unit 0c: Native Justification And Generator Contract — Determinism
**What**: Run generator dry-run/temp-output mode twice against a temporary directory, diff the temporary generated project output, and refactor generator/docs if nondeterministic.
**Output**: Determinism log and temporary-output diff summary in artifacts directory.
**Acceptance**: Dry-run/temp-output project generation is deterministic; no `Spoonjoy.xcodeproj` or generated `Apps/Spoonjoy/**` files are written to the repo before Unit 12, except Unit 10 may add native integration sources under `Apps/Spoonjoy/Shared/Native/`. Unit 0c must not block those native integration sources. A check fails on any pre-Unit-12 diff under `Spoonjoy.xcodeproj` or `Apps/Spoonjoy/**` outside `Apps/Spoonjoy/Shared/Native/**`.

### ✅ Unit 1a: Swift Package Bootstrap — Tests
**What**: Add failing checks for `Package.swift` target declarations, fixture resource processing, empty `SpoonjoyCore` build, executable scenario target, and test target discovery.
**Output**: `scripts/check-swift-package-structure.rb` and red log `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-1a-red.log`.
**Acceptance**: Structure check and `swift test list` fail before `Package.swift` and target directories exist.

### ✅ Unit 1b: Swift Package Bootstrap — Implementation
**What**: Create `Package.swift`, `Sources/SpoonjoyCore/SpoonjoyCore.swift`, `Sources/SpoonjoyCore/Fixtures/`, `Sources/SpoonjoyScenarioVerifier/main.swift`, and `Tests/SpoonjoyCoreTests/SpoonjoyCoreBootstrapTests.swift`.
**Output**: Swift package manifest, placeholder targets, fixture resource directory, executable target, and bootstrap tests.
**Acceptance**: `scripts/check-swift-package-structure.rb` passes; `swift test list` discovers `SpoonjoyCoreTests`; `swift run -Xswiftc -warnings-as-errors SpoonjoyScenarioVerifier --stage bootstrap --output ${ARTIFACT_ROOT}/scenario-bootstrap.json` runs with `pending` checks only for native metadata and app surfaces.

### ✅ Unit 1c: Swift Package Bootstrap — Coverage & Refactor
**What**: Run Swift package tests and coverage command against bootstrap targets, then refactor manifest/resources if needed.
**Output**: Bootstrap coverage/build logs.
**Acceptance**: `swift test --disable-xctest --parallel` passes; coverage command produces JSON; no implementation unit later fails because the package manifest is absent.

### ✅ Unit 2a: Coverage And Warning Enforcement Scripts — Tests
**What**: Add failing tests/checks for coverage JSON parsing, threshold enforcement, missing coverage file handling, warning-log failure behavior, and CI wiring expectations.
**Output**: Script tests/checks for coverage and warning enforcement.
**Acceptance**: Checks fail before `scripts/enforce-swift-coverage.rb` and `scripts/fail-on-warning.rb` exist.

### ✅ Unit 2b: Coverage And Warning Enforcement Scripts — Implementation
**What**: Implement coverage threshold script, warning-log enforcement script, and update workflow commands to use the Contract Constants.
**Output**: `scripts/enforce-swift-coverage.rb`, `scripts/fail-on-warning.rb`, and `.github/workflows/native.yml` coverage/warning updates.
**Acceptance**: Coverage check fails below threshold and passes at threshold in local script tests; warning enforcement fails on branch-source warnings.

### ✅ Unit 2c: Coverage And Warning Enforcement Scripts — Refactor
**What**: Run the warning-enforced coverage command, threshold script, warning parser against saved logs, and full package tests.
**Output**: Coverage artifacts and logs.
**Acceptance**: Coverage artifacts are saved; CI coverage command is reproducible locally; `scripts/enforce-swift-coverage.rb` and `scripts/fail-on-warning.rb` exist before Unit 3c.

### ✅ Unit 3a: Recipe/Cookbook Domain — Tests
**What**: Write failing Swift tests for recipe, ingredient, step, chef, cookbook, cookbook cover, fixture decoding, and public search summary models.
**Output**: `Tests/SpoonjoyCoreTests/RecipeCookbookTests.swift`.
**Acceptance**: Filtered Swift tests fail because domain models do not exist yet.

### ✅ Unit 3b: Recipe/Cookbook Domain — Implementation
**What**: Implement recipe/cookbook domain models, fixture decoding, validation, and search-summary helpers.
**Output**: `Sources/SpoonjoyCore/RecipeCookbook/` sources and fixtures.
**Acceptance**: Unit 3a tests pass using `swift test --filter RecipeCookbookTests --disable-xctest --parallel`; compiler emits no warnings.

### ✅ Unit 3c: Recipe/Cookbook Domain — Coverage & Refactor
**What**: Run coverage for recipe/cookbook code, add edge tests, and refactor naming/boundaries.
**Output**: Coverage log in artifacts directory.
**Acceptance**: `scripts/enforce-swift-coverage.rb --coverage-json <path> --minimum 100 --include 'Sources/SpoonjoyCore/RecipeCookbook'` passes; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 4a: Shopping/Cook/Settings Domain — Tests
**What**: Write failing Swift tests for shopping-list item operations, cook-mode progress, capture drafts, settings, and kitchen fixture state.
**Output**: `Tests/SpoonjoyCoreTests/KitchenStateTests.swift`.
**Acceptance**: Filtered Swift tests fail before implementation.

### ⬜ Unit 4b: Shopping/Cook/Settings Domain — Implementation
**What**: Implement shopping-list operations, cook-mode progress persistence DTOs, capture draft state, settings state, and kitchen fixture state.
**Output**: `Sources/SpoonjoyCore/KitchenState/ShoppingListState.swift`, `CookModeProgress.swift`, `CaptureDraft.swift`, `SettingsState.swift`, and `KitchenFixtureState.swift`.
**Acceptance**: Unit 4a tests pass using `swift test --filter KitchenStateTests --disable-xctest --parallel`; compiler emits no warnings.

### ⬜ Unit 4c: Shopping/Cook/Settings Domain — Coverage & Refactor
**What**: Run coverage for kitchen state code, add missing edge/error tests, and refactor.
**Output**: Coverage log in artifacts directory.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/KitchenState`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 5a: Public API v1 Read Client — Tests
**What**: Write failing tests for recipe/cookbook list/detail request builders, optional auth behavior, response envelopes, pagination, cache headers metadata, and error mapping.
**Output**: `Tests/SpoonjoyCoreTests/APIReadClientTests.swift`.
**Acceptance**: Tests fail with outbound-shape assertions for method, path, query, headers, and auth omission by default.

### ⬜ Unit 5b: Public API v1 Read Client — Implementation
**What**: Implement API base URL, request builder, envelope/error types, recipes/cookbooks list/detail requests, pagination cursor helpers, and optional-auth policy.
**Output**: `Sources/SpoonjoyCore/API/APIClient.swift`, `APIEnvelope.swift`, `APIError.swift`, `APIRequestBuilder.swift`, `PublicCatalogRequests.swift`, and `PaginationCursor.swift`.
**Acceptance**: Unit 5a tests pass; stale bearer tokens are not attached to anonymous public reads by default.

### ⬜ Unit 5c: Public API v1 Read Client — Coverage & Refactor
**What**: Run coverage, add malformed URL/cursor/error edge tests, and refactor read-client boundaries.
**Output**: Coverage and request-shape logs.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/API`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 6a: Shopping API Mutations — Tests
**What**: Write failing tests for shopping-list read/sync, POST/PATCH/DELETE request builders, idempotency body/header/query forms, retry classification, and conflict/in-progress handling.
**Output**: `Tests/SpoonjoyCoreTests/ShoppingAPIClientTests.swift`.
**Acceptance**: Tests fail with outbound-shape assertions and DELETE `X-Client-Mutation-Id` expectations.

### ⬜ Unit 6b: Shopping API Mutations — Implementation
**What**: Implement shopping-list API request builders, sync cursor helpers, mutation response parsing, idempotency metadata, and retry/error classification.
**Output**: `Sources/SpoonjoyCore/API/ShoppingListAPI.swift`, `Sources/SpoonjoyCore/API/ShoppingListRequests.swift`, and `Sources/SpoonjoyCore/API/APIRetryPolicy.swift`.
**Acceptance**: Unit 6a tests pass; DELETE supports header, query, and body idempotency forms.

### ⬜ Unit 6c: Shopping API Mutations — Coverage & Refactor
**What**: Run coverage, add edge/error tests for 401/403/409/429/5xx paths, and refactor.
**Output**: Coverage and retry-classification logs.
**Acceptance**: Coverage enforcement passes for shopping API files in `Sources/SpoonjoyCore/API`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 7a: OAuth/PKCE Request Construction — Tests
**What**: Write failing tests for PKCE verifier/challenge, state generation/validation, OAuth register/authorize/token/refresh/revoke request construction, redirect constraints, and REST `resource` omission.
**Output**: `Tests/SpoonjoyCoreTests/OAuthRequestTests.swift`.
**Acceptance**: Tests fail before OAuth helpers exist and assert form bodies/authorize query items.

### ⬜ Unit 7b: OAuth/PKCE Request Construction — Implementation
**What**: Implement PKCE/state helpers, OAuth request builders, redirect validation, and OAuth response types.
**Output**: `Sources/SpoonjoyCore/Auth/OAuthPKCE.swift`, `Sources/SpoonjoyCore/Auth/OAuthRequests.swift`, `Sources/SpoonjoyCore/Auth/OAuthRedirectValidator.swift`, and `Sources/SpoonjoyCore/Auth/OAuthResponses.swift`.
**Acceptance**: Unit 7a tests pass; custom schemes are rejected and REST OAuth omits `resource`.

### ⬜ Unit 7c: OAuth/PKCE Request Construction — Coverage & Refactor
**What**: Run coverage, add edge/error tests, and refactor OAuth request helpers.
**Output**: OAuth coverage log.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/Auth/OAuth*`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 8a: Token Vault And Refresh Coordination — Tests
**What**: Write failing tests for token vault protocol behavior, in-memory vault, persisted client id abstraction, atomic refresh-token rotation, invalid state handling, and single-flight refresh.
**Output**: `Tests/SpoonjoyCoreTests/TokenRefreshTests.swift`.
**Acceptance**: Tests fail before vault/coordinator implementation exists.

### ⬜ Unit 8b: Token Vault And Refresh Coordination — Implementation
**What**: Implement token vault abstractions, in-memory token vault, refresh coordinator, and disconnect/revoke state transitions.
**Output**: `Sources/SpoonjoyCore/Auth/TokenVault.swift`, `Sources/SpoonjoyCore/Auth/InMemoryTokenVault.swift`, `Sources/SpoonjoyCore/Auth/RefreshCoordinator.swift`, and `Sources/SpoonjoyCore/Auth/AuthSessionState.swift`.
**Acceptance**: Unit 8a tests pass; concurrent refresh calls share one refresh operation in tests.

### ⬜ Unit 8c: Token Vault And Refresh Coordination — Coverage & Refactor
**What**: Run coverage, add concurrency/error tests, and refactor.
**Output**: Coverage/concurrency logs.
**Acceptance**: Coverage enforcement passes for token/refresh files in `Sources/SpoonjoyCore/Auth`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 9a: Offline Store And Mutation Queue — Tests
**What**: Write failing tests for JSON file store, corrupt JSON recovery, durable cursor checkpointing, offline restore, and queued mutation serialization.
**Output**: `Tests/SpoonjoyCoreTests/OfflineStoreTests.swift`.
**Acceptance**: Tests fail before offline store implementation exists.

### ⬜ Unit 9b: Offline Store And Mutation Queue — Implementation
**What**: Implement file-store abstractions, JSON encoding/decoding, cursor checkpointing, offline restore, and mutation queue models.
**Output**: `Sources/SpoonjoyCore/Offline/JSONFileStore.swift`, `Sources/SpoonjoyCore/Offline/OfflineSnapshot.swift`, `Sources/SpoonjoyCore/Offline/SyncCheckpoint.swift`, and `Sources/SpoonjoyCore/Offline/MutationQueue.swift`.
**Acceptance**: Unit 9a tests pass; corrupt JSON recovers without losing valid fallback fixtures.

### ⬜ Unit 9c: Offline Store And Mutation Queue — Coverage & Refactor
**What**: Run coverage, add filesystem/error edge tests, and refactor.
**Output**: Offline coverage log.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/Offline`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 10a: Native Integrations And Scenario Engine — Tests
**What**: Write failing tests/static checks for compileable AppIntents/CoreSpotlight app sources, App Intent descriptors, Spotlight/search metadata, associated-domain/custom-scheme metadata, native affordance flags, executable scenario command, and deterministic scenario report generation.
**Output**: `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`.
**Acceptance**: Tests fail before metadata/scenario engine and app integration source files exist.

### ⬜ Unit 10b: Native Integrations And Scenario Engine — Implementation
**What**: Implement native-value metadata descriptors, guarded AppIntents/CoreSpotlight app sources, associated-domain/custom-scheme metadata, executable scenario report generator, thin CLI adapter, and verifier script for first-run, fixture kitchen, recipe detail, cook progress, shopping checkoff, search, capture draft, settings, offline restore, deep links, and native affordance flags.
**Output**: `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`, `Sources/SpoonjoyCore/Native/ScenarioReport.swift`, `Sources/SpoonjoyCore/Native/ScenarioCommand.swift`, `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`, `Sources/SpoonjoyCore/Native/DeepLinkManifest.swift`, `Sources/SpoonjoyScenarioVerifier/main.swift`, `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`, `Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift`, and `scripts/verify-native-scenarios.sh`.
**Acceptance**: Unit 10a tests pass; `swift run -Xswiftc -warnings-as-errors SpoonjoyScenarioVerifier --stage native-metadata --output ${ARTIFACT_ROOT}/scenario-native-metadata.json` emits the required schema; `scripts/verify-native-scenarios.sh --stage native-metadata` exits nonzero when AppIntents/CoreSpotlight/deep-link metadata or guarded app integration source files are absent, while allowing explicitly pending surface checks for Units 14-16.

### ⬜ Unit 10c: Native Integrations And Scenario Engine — Coverage & Refactor
**What**: Run coverage, polish scenario output, and refactor descriptors.
**Output**: Scenario JSON/log and coverage log.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/Native`; a static check proves `Sources/SpoonjoyScenarioVerifier/main.swift` is a thin adapter with no branching; `scripts/verify-native-scenarios.sh --stage native-metadata` produces deterministic artifacts and allows only surface checks to remain pending.

### ⬜ Unit 11a: App State And Navigation View Models — Tests
**What**: Write failing tests for app route selection, table-driven deep-link URL parsing, sidebar/tab state, search state, recipe selection, cook-mode state, capture draft state, shopping checkoff state, and settings state used by SwiftUI.
**Output**: `Tests/SpoonjoyCoreTests/AppStateTests.swift` and `Tests/SpoonjoyCoreTests/DeepLinkRouterTests.swift`.
**Acceptance**: Tests fail before view-model state exists. `DeepLinkRouterTests` must enumerate every URL in the deep-link contract, prove both `/recipes/{id}#cook` and `/recipes/{id}?mode=cook` map to cook mode, preserve decoded search `q`, accept only the listed scopes, map shopping/capture/settings routes, and return safe unknown-link state for unknown hosts, unknown paths, malformed/empty IDs, traversal-like IDs, and unsupported search scopes.

### ⬜ Unit 11b: App State And Navigation View Models — Implementation
**What**: Implement UI-independent app state/view models and deep-link routing consumed by SwiftUI screens.
**Output**: `Sources/SpoonjoyCore/AppState/AppRoute.swift`, `Sources/SpoonjoyCore/AppState/DeepLinkRouter.swift`, `Sources/SpoonjoyCore/AppState/AppNavigationState.swift`, `Sources/SpoonjoyCore/AppState/SearchState.swift`, and `Sources/SpoonjoyCore/AppState/ScreenViewModels.swift`.
**Acceptance**: Unit 11a tests pass; app targets do not own nontrivial business logic.

### ⬜ Unit 11c: App State And Navigation View Models — Coverage & Refactor
**What**: Run coverage, add edge tests, and refactor.
**Output**: App-state coverage log.
**Acceptance**: Coverage enforcement passes for `Sources/SpoonjoyCore/AppState`; `swift test --disable-xctest --parallel` passes.

### ⬜ Unit 12a: Xcode Project And App Targets — Tests
**What**: Add failing generator/project checks for first real repo project generation, root project set exactly empty-or-`Spoonjoy.xcodeproj`, iOS/macOS targets, bundle IDs, Associated Domains entitlement, custom URL scheme Info.plist registration, product baseline settings, `BootstrapDebug` deployment-target isolation, local macOS smoke-floor compatibility, synchronized `Apps/Spoonjoy/**` file inclusion or explicit target membership, build settings, and iOS/macOS target membership for `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift` plus `Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift`.
**Output**: Project generation checks under `scripts/`.
**Acceptance**: Checks fail before the project/targets are generated.

### ⬜ Unit 12b: Xcode Project And App Targets — Implementation
**What**: Generate `Spoonjoy.xcodeproj` with iOS and macOS app targets, shared SwiftUI source files, asset catalogs, product configs that preserve the iOS/macOS 27 baseline, a clearly named `BootstrapDebug` config compatible with Xcode 26.5 iOS simulator builds and macOS 26.2 local launch/smoke, and either file-system-synchronized groups for `Apps/Spoonjoy/**` or generator-managed target membership that can be rerun after later surface units.
**Output**: `Spoonjoy.xcodeproj`, `Apps/Spoonjoy/Shared/SpoonjoyApp.swift`, `Apps/Spoonjoy/iOS/SpoonjoyiOSApp.swift`, `Apps/Spoonjoy/macOS/SpoonjoyMacApp.swift`, `Apps/Spoonjoy/Shared/Assets.xcassets/`, `Apps/Spoonjoy/Shared/Info.plist`, and `Apps/Spoonjoy/Shared/Spoonjoy.entitlements`.
**Acceptance**: Project checks pass, including root project set exactly `Spoonjoy.xcodeproj`, Associated Domains `applinks:spoonjoy.app`, URL scheme `spoonjoy`, AppIntents/CoreSpotlight source membership in both app targets, and proof that later `Apps/Spoonjoy/**` Swift files will be auto-included by synchronized groups or caught by generator target-membership checks; product configs do not mislabel 26.5 or 26.2 as the product baseline; `BootstrapDebug` macOS target is not above the local host major.minor; the exact iOS and macOS bootstrap build commands from Contract Constants pass.

### ⬜ Unit 12c: Xcode Project And App Targets — Determinism & Refactor
**What**: Re-run generator, diff project, and refactor generated structure/settings.
**Output**: Xcode generation determinism log.
**Acceptance**: Re-running generator produces no git diff; exact iOS and macOS build commands still pass.

### ⬜ Unit 13a: Native Shell Navigation — Tests
**What**: Add failing app-state or static checks for `NavigationStack`, `NavigationSplitView`, `.onOpenURL`, continuing `NSUserActivity` universal-link handoff, toolbars, share actions, searchable routes, edit/check affordance metadata, platform-specific shell decisions, and Xcode inclusion for new shell source files.
**Output**: Tests/static checks for native shell affordances.
**Acceptance**: Checks fail before SwiftUI shell implementation and fail if new shell files would be omitted from iOS or macOS app builds. Both app targets must statically prove URL handling through `.onOpenURL` and, where applicable, `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` / `NSUserActivity.webpageURL`, with both paths using the same package `DeepLinkRouter`.

### ⬜ Unit 13b: Native Shell Navigation — Implementation
**What**: Implement shared SwiftUI shell, signed-out setup, platform navigation, universal/custom URL handoff, toolbar actions, `.searchable`, share affordances, and settings entry.
**Output**: `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`, `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`, `Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift`, `Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift`, and `Apps/Spoonjoy/Shared/AppShell/ShareActions.swift`.
**Acceptance**: Unit 13a checks pass; generator is rerun if target membership is not synchronized; exact iOS and macOS build commands pass.

### ⬜ Unit 13c: Native Shell Navigation — Coverage & Refactor
**What**: Run package tests/builds and refactor shell state.
**Output**: Build logs.
**Acceptance**: `swift test --disable-xctest --parallel` and exact iOS/macOS build commands pass with no new warnings.

### ⬜ Unit 14a: Kitchen And Recipe Surfaces — Tests
**What**: Add failing tests/static checks for Kitchen lead object, recipe index rows, recipe detail cookbook spread, ingredients receipt, step list, native share, Kitchen Table semantic tokens, and Xcode inclusion for new kitchen/recipe source files.
**Output**: Tests/checks for kitchen and recipe surface contracts.
**Acceptance**: Checks fail before surfaces exist and fail if new kitchen/recipe files would be omitted from iOS or macOS app builds.

### ⬜ Unit 14b: Kitchen And Recipe Surfaces — Implementation
**What**: Implement Kitchen, Recipes, Recipe Detail, and Cookbooks surfaces using fixture/app state and native controls.
**Output**: `Apps/Spoonjoy/Shared/Views/KitchenView.swift`, `Apps/Spoonjoy/Shared/Views/RecipesView.swift`, `Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`, `Apps/Spoonjoy/Shared/Views/CookbooksView.swift`, and `Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift`.
**Acceptance**: Unit 14a checks pass; generator is rerun if target membership is not synchronized; exact iOS and macOS build commands pass; scenario verifier `--stage surfaces` covers fixture kitchen browsing and recipe detail.

### ⬜ Unit 14c: Kitchen And Recipe Surfaces — Build & Refactor
**What**: Run tests/builds/scenario verifier and refactor surface components.
**Output**: Build and scenario logs.
**Acceptance**: `swift test --disable-xctest --parallel`, `scripts/verify-native-scenarios.sh --stage surfaces`, and exact iOS/macOS build commands pass with no new warnings.

### ⬜ Unit 15a: Cook Mode And Shopping Surfaces — Tests
**What**: Add failing tests/static checks for focused cook-mode state, persisted progress, large kitchen-safe controls, receipt-like shopping list, checkoff behavior, edit/check native affordances, and Xcode inclusion for new cook/shopping source files.
**Output**: Tests/checks for cook/shopping surface contracts.
**Acceptance**: Checks fail before surfaces exist and fail if new cook/shopping files would be omitted from iOS or macOS app builds.

### ⬜ Unit 15b: Cook Mode And Shopping Surfaces — Implementation
**What**: Implement Cook Mode and Shopping List SwiftUI surfaces using package state and native controls.
**Output**: `Apps/Spoonjoy/Shared/Views/CookModeView.swift`, `Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`, `Apps/Spoonjoy/Shared/Components/ReceiptListView.swift`, and `Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift`.
**Acceptance**: Unit 15a checks pass; generator is rerun if target membership is not synchronized; scenario verifier `--stage surfaces` covers cook progress persistence and shopping checkoff; exact iOS and macOS build commands pass.

### ⬜ Unit 15c: Cook Mode And Shopping Surfaces — Build & Refactor
**What**: Run tests/builds/scenario verifier and refactor.
**Output**: Build and scenario logs.
**Acceptance**: `swift test --disable-xctest --parallel`, `scripts/verify-native-scenarios.sh --stage surfaces`, and exact iOS/macOS build commands pass with no new warnings.

### ⬜ Unit 16a: Search, Capture, Settings Surfaces — Tests
**What**: Add failing tests/static checks for native search scopes, capture draft creation, settings state, offline status, rejected production-write claims, and Xcode inclusion for new search/capture/settings source files.
**Output**: Tests/checks for search/capture/settings contracts.
**Acceptance**: Checks fail before surfaces exist and fail if new search/capture/settings files would be omitted from iOS or macOS app builds.

### ⬜ Unit 16b: Search, Capture, Settings Surfaces — Implementation
**What**: Implement Search, Capture, and Settings SwiftUI surfaces using native search/toolbars/forms and local draft state.
**Output**: `Apps/Spoonjoy/Shared/Views/SearchView.swift`, `Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift`, `Apps/Spoonjoy/Shared/Views/SettingsView.swift`, and `Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift`.
**Acceptance**: Unit 16a checks pass; generator is rerun if target membership is not synchronized; scenario verifier `--stage final` covers search, capture draft creation, settings, offline status, and contains no pending checks.

### ⬜ Unit 16c: Search, Capture, Settings Surfaces — Build & Refactor
**What**: Run tests, builds, `scripts/verify-native-scenarios.sh --stage final`, deep-link route checks, and refactor.
**Output**: Build and scenario logs.
**Acceptance**: `swift test --disable-xctest --parallel`, `scripts/verify-native-scenarios.sh --stage final`, and exact iOS/macOS build commands pass with no new warnings. Final scenario evidence must list required `deepLinkRoutes`, include both cook-mode URL forms, and prove unsupported link inputs resolve to the safe unknown-link state.

### ⬜ Unit 17a: Launch Smoke And Screenshot Scripts — Tests
**What**: Add failing checks for macOS launch smoke, iOS simulator smoke timeout reporting, exact screenshot artifact paths, and design/accessibility review manifest fields.
**Output**: Script tests/checks for `scripts/smoke-macos.sh`, `scripts/smoke-ios-simulator.sh`, `scripts/capture-native-screenshots.sh`, and `scripts/validate-design-review.rb`.
**Acceptance**: Checks fail before scripts exist.

### ⬜ Unit 17b: Launch Smoke And Screenshot Scripts — Implementation
**What**: Implement macOS launch/smoke, iOS simulator smoke with bounded CoreSimulator handling, screenshot/design artifact generation, and a fail-closed design/accessibility manifest.
**Output**: `scripts/smoke-macos.sh`, `scripts/smoke-ios-simulator.sh`, `scripts/capture-native-screenshots.sh`, `scripts/validate-design-review.rb`, and `tasks/2026-06-15-2314-doing-native-app-skeleton/design-review.json`.
**Acceptance**: macOS launch/smoke runs locally; iOS smoke records CoreSimulator timeout as a local blocker if runtime listing remains unavailable; manifest includes pass/fail entries for mobile target, desktop target, Dynamic Type, VoiceOver labels, keyboard navigation, Reduce Motion, contrast, Kitchen Table hierarchy, and no-overlap layout review.

### ⬜ Unit 17c: Launch Smoke And Screenshot Scripts — Refactor
**What**: Run launch/smoke and screenshot/design review scripts, save artifacts, and clean up output.
**Output**: `tasks/2026-06-15-2314-doing-native-app-skeleton/smoke-macos.log`, `smoke-ios-simulator.log`, `screenshots/ios-mobile.png`, `screenshots/macos-desktop.png`, and `design-review.json`.
**Acceptance**: Available launch/screenshot validation passes or records concrete local capability blocker with command output; design review manifest fails if any required pass/fail field is missing or false without a documented capability blocker.

### ⬜ Unit 18a: Full Local Matrix — Tests/Preparation
**What**: Add a single local matrix script that orchestrates Swift tests, coverage, scenario verifier, deep-link registration checks, AASA validation/blocker artifact generation, Xcode builds, launch smoke, and screenshot/design checks.
**Output**: `scripts/validate-native-local.sh` with failing pre-implementation assertions if any required script is missing.
**Acceptance**: Matrix script fails before all required validation hooks are present, including the AASA validation/blocker artifact hook.

### ⬜ Unit 18b: Full Local Matrix — Implementation
**What**: Wire all validation hooks into the local matrix and align `.github/workflows/native.yml` with the same runner, warning-enforced Swift test, coverage, scenario, project-set, deep-link registration, AASA validation/blocker artifact generation, target-membership, and Xcode bootstrap build commands listed in Contract Constants.
**Output**: Matrix script and workflow updates.
**Acceptance**: Matrix runs each mandatory command from Contract Constants, writes `validation-matrix.json`, and exits nonzero on missing mandatory checks; GitHub workflow uses `macos-26`, verifies Xcode 26.5, rejects extra root Xcode projects, and uses the same Swift test, coverage, scenario, and Xcode build commands except launch/screenshot checks that require an interactive local session.

### ⬜ Unit 18c: Full Local Matrix — Evidence
**What**: Run the full local matrix and save logs/artifacts.
**Output**: Full validation artifacts under `tasks/2026-06-15-2314-doing-native-app-skeleton/`.
**Acceptance**: All mandatory validation passes, or a blocker JSON matching Contract Constants exists for CoreSimulator-only smoke/screenshot limits. AASA evidence must exist as either `aasa-validation.json` or `aasa-production-blocker.json` with required app IDs, route coverage, HTTPS/no-redirect expectation, and Team ID/AASA publication blocker details when applicable.

### ⬜ Unit 19a: Final Implementation Review — Review
**What**: Spawn harsh implementation reviewer with full branch diff, planning/doing docs, and validation artifacts.
**Output**: Reviewer verdict.
**Acceptance**: Reviewer returns CONVERGED or FINDINGS.

### ⬜ Unit 19b: Final Implementation Review — Fixes
**What**: Address any BLOCKER/MAJOR reviewer findings with tests and implementation changes.
**Output**: Fix commits and updated artifacts.
**Acceptance**: Round 2 reviewer returns no BLOCKER/MAJOR findings.

### ⬜ Unit 20a: PR And CI — Open
**What**: Open PR for `slugger/native-app-skeleton` with summary, validation evidence, GitHub `macos-26`/Xcode 26.5 bootstrap evidence, local macOS 26.2 launch/smoke evidence, AASA validation/blocker evidence, known Xcode 27 capability blocker, and reviewer gate results.
**Output**: PR URL and `tasks/2026-06-15-2314-doing-native-app-skeleton/pr-open.json`.
**Acceptance**: PR exists and protected checks start.

### ⬜ Unit 20b: PR And CI — Converge
**What**: Wait for GitHub checks, fix any CI failures, and re-run reviewer if fixes are substantive.
**Output**: Green CI, optional fix commits, and `tasks/2026-06-15-2314-doing-native-app-skeleton/github-checks.json`.
**Acceptance**: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage` pass on GitHub.

### ⬜ Unit 20c: Merge And Sync
**What**: Merge PR, fast-forward local main, verify branch protection remains intact, update Desk, and continue with next app slice.
**Output**: Merged main, Desk update, and `tasks/2026-06-15-2314-doing-native-app-skeleton/branch-protection.json`.
**Acceptance**: PR is merged to `main`; local main matches `origin/main`; branch-protection JSON shows strict required checks `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`; no active implementation branch residue.

## Execution

- **TDD strictly enforced**: tests -> red -> implement -> green -> refactor.
- Commit after each phase.
- Push after each unit complete.
- Run full test suite before marking unit done.
- **All artifacts**: Save outputs, logs, screenshots, and data to `./tasks/2026-06-15-2314-doing-native-app-skeleton/`.
- **Commit/push cadence**: Commit after every `a`, `b`, or `c` unit. Push after each commit. Unit review happens after each `c` unit or after standalone units 0c, 10c, 16c, 17c, 18b, and 19b.
- **Fixes/blockers**: Spawn sub-agent immediately for ordinary implementation or review blockers.
- **Decisions made**: Update docs immediately, commit right away.

## Progress Log

- 2026-06-15 23:14 Created doing doc from approved planning doc.
- 2026-06-15 23:14 Addressed granularity review by splitting broad units into atomic test/implementation/coverage groups.
- 2026-06-15 23:14 Granularity Round 2 converged with no remaining blockers.
- 2026-06-15 23:14 Addressed validation review with explicit source paths, design/accessibility manifest criteria, screenshot targets, and branch-protection evidence artifacts.
- 2026-06-15 23:14 Validation Round 2 converged with no remaining blockers.
- 2026-06-15 23:14 Addressed ambiguity review with contract constants for API/OAuth/schema sources, coverage commands, artifact root, simulator blocker schema, design invariants, exact build commands, and commit cadence.
- 2026-06-15 23:14 Ambiguity Round 2 converged with no remaining blockers.
- 2026-06-15 23:14 Quality pass converged with all units explicit and TDD-shaped.
- 2026-06-15 23:14 Addressed Tinfoil scrutiny with Swift package bootstrap, executable scenario verifier contract, and compileable AppIntents/CoreSpotlight integration requirements.
- 2026-06-15 23:14 Addressed Tinfoil Round 3 findings with stage-specific verifier commands and explicit native integration target-membership checks.
- 2026-06-15 23:14 Addressed Tinfoil Round 4 finding by pinning Unit 16c to final scenario verification.
- 2026-06-15 23:14 Tinfoil scrutiny converged after Round 5.
- 2026-06-16 00:24 Addressed Stranger With Candy findings by pinning CI to `macos-26`, enforcing warnings as errors, isolating Xcode 26.5 to `BootstrapDebug`, and tightening coverage/script accounting.
- 2026-06-16 00:24 Tightened CI script checks so present-but-nonexecutable verifier scripts cannot silently bootstrap-pass and Ruby coverage enforcement does not depend on executable mode.
- 2026-06-16 00:24 Addressed Stranger With Candy Round 2 findings by making missing scenario and coverage enforcement scripts fail once Swift/Xcode sources exist.
- 2026-06-16 00:24 Addressed Tinfoil finding by setting the bootstrap macOS deployment target to the local macOS 26.2 smoke floor while keeping product configs at macOS 27.
- 2026-06-16 00:24 Addressed Stranger With Candy Round 3 findings by marking the doing doc executable, making Unit 0 generator checks dry-run/temp-output only, and failing closed for Xcode-project-only coverage.
- 2026-06-16 00:24 Addressed Tinfoil Round 2 finding by making the App bundle check fail once `Package.swift` exists without `Spoonjoy.xcodeproj`.
- 2026-06-16 00:24 Addressed Stranger With Candy Round 4 findings by requiring exact `Spoonjoy.xcodeproj`, narrowing Unit 0c's pre-Unit-12 ban, and removing API v1 token-management paths from this slice.
- 2026-06-16 00:24 Addressed final review findings by adding extra-project guards, warning-enforced scenario runs, broader pre-Unit-12 app-output checks, and target-membership checks for later SwiftUI files.
- 2026-06-16 01:06 Final Tinfoil and Stranger With Candy doing-doc reviews converged; execution may start under Work Suite autopilot.
- 2026-06-16 01:08 Unit 0a complete: native justification and Xcode generator contract checks fail red against missing docs/generator; red log saved to `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-0a-red.log`.
- 2026-06-16 01:13 Addressed Unit 0a reviewer findings by broadening generator temp-output repo-write detection and asserting generated product/bootstrap deployment settings.
- 2026-06-16 01:18 Addressed Unit 0a Round 2 findings by snapshotting forbidden repo outputs before/after temp generation and asserting deployment targets within bundle/config-specific build settings.
- 2026-06-16 01:21 Addressed Unit 0a Round 3 finding by parsing real `XCBuildConfiguration` objects and matching their `name` fields before asserting deployment targets.
- 2026-06-16 01:29 Unit 0b complete: added `docs/native-justification.md`, deterministic temp-output Xcode generator, and green log at `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-0b-green.log`.
- 2026-06-16 01:35 Unit 0c complete: generator temp-output determinism passed twice with no `Spoonjoy.xcodeproj` or `Apps/Spoonjoy` repo output; evidence saved to `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-0c-determinism.log`.
- 2026-06-16 01:41 Unit 1a complete: Swift package structure check and `swift test list` fail red before `Package.swift` exists; red log saved to `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-1a-red.log`.
- 2026-06-16 01:43 Unit 1b complete: Swift package manifest, core target, fixtures, scenario executable, and bootstrap tests pass structure/discovery checks; green log and scenario bootstrap JSON saved under the artifact directory.
- 2026-06-16 01:49 Addressed Unit 1b reviewer finding by loading package fixtures from the generated `Fixtures` resource subdirectory; full Swift package tests pass with warnings as errors.
- 2026-06-16 01:55 Unit 1c complete: bootstrap tests and coverage generation pass; `Sources/SpoonjoyCore` is 100.0% covered in `unit-1c-codecov.json`; coverage flow corrected to run generation before the `--show-codecov-path` locator.
- 2026-06-16 02:05 Added native link contract: Spoonjoy Apple must support Associated Domains for `applinks:spoonjoy.app`, a `spoonjoy` custom URL scheme fallback, and deterministic route parsing for canonical web links into the correct native screens.
- 2026-06-16 02:10 Unit 2a complete: added coverage/warning contract checks; red log proves missing enforcement scripts and stale CI coverage/warning wiring fail before implementation.
- 2026-06-16 02:13 Addressed deep-link reviewer findings by requiring table-driven deep-link parser tests, shared app-target URL handoff proof, final scenario deep-link evidence, and AASA validation/blocker artifacts.
- 2026-06-16 02:20 Addressed Unit 1 reviewer findings by parsing `--stage` in covered core code, rejecting unsupported future stages nonzero, extending scenario capabilities with deep-link arrays, and refreshing warning-enforced Unit 1c artifacts.
- 2026-06-16 02:24 Unit 2b complete: implemented coverage threshold and warning-log scripts, corrected CI to generate coverage before locating JSON, and wired warning scans into SwiftPM, scenario, and future Xcode logs.
- 2026-06-16 02:28 Unit 2c complete: full Swift package tests, coverage generation, warning scans, and 100% `Sources/SpoonjoyCore` coverage enforcement all pass with artifacts saved.
- 2026-06-16 02:35 Unit 3a complete: added failing recipe/cookbook domain tests for fixture decoding, validation, cover modeling, and public search summaries; red log saved to `tasks/2026-06-15-2314-doing-native-app-skeleton/unit-3a-red.log`.
- 2026-06-16 02:43 Unit 3b complete: implemented recipe/cookbook domain models, fixture catalog decoders, validation errors, cover presentation, and public search summaries; focused tests, full Swift tests, and warning-enforced Swift build pass.
- 2026-06-16 02:53 Unit 3c complete: added edge tests for validation branches, missing IDs, summary fallbacks, cookbook encoding, and manual initializers; `RecipeCookbook` coverage enforcement passes at 100.00% (184/184), warning scan is clean, and warning-enforced build passes.
