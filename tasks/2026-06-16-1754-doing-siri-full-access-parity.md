# Doing: Siri Full Access Parity

**Status**: executable; reviewer-gated, no human approval gate
**Execution Mode**: spawn
**Execution Authorization**: Human approval gates are waived. After doing-doc reviewer passes converge with no BLOCKER/MAJOR findings, the orchestrator starts Unit 0 immediately and continues through Unit 27 without asking for human approval unless a true human-only blocker listed in Execution is hit.
**Created**: 2026-06-16 18:23
**Planning**: ./2026-06-16-1754-planning-siri-full-access-parity.md
**Artifacts**: ./2026-06-16-1754-doing-siri-full-access-parity/

## Execution Mode

- **spawn**: Execute dependency waves with sub-agent implementors for disjoint backend, native core, app-surface, documentation, and validation write scopes. The orchestrator owns sequencing, integration, reviewer gates, commits, pushes, PRs, merges, and final validation.
- Dependency Wave 0 is orchestrator-only: Unit 0 baseline plus any docs/review fixes.
- Dependency Wave 1 is backend REST contract and handlers: Units 1-10f. Unit 1b is orchestrator-only because it changes the shared REST contract registry. Spawn only disjoint backend workers by endpoint family after Unit 1b; the orchestrator owns shared `app/lib/api-v1.server.ts`, `app/lib/api-v1-contract.server.ts`, `app/lib/api-v1-openapi.server.ts`, generated docs/playground integration, and final merge of backend changes.
- Dependency Wave 2 is native API/auth/offline core: Units 11-16. Spawn only disjoint SwiftPM workers for API builders, transport, auth, cache, sync, and shell wiring; serialize any change touching `NativeAppSnapshot`, `MutationQueue`, `ScenarioVerifier`, `scripts/generate-xcode-project.rb`, or project files through the orchestrator.
- Dependency Wave 3 is native product surfaces: Units 17a-20c. Spawn one surface worker per feature family only after the needed backend and native core units are green; route, scenario verifier, design-token, and project-generator edits are orchestrator-owned integration files.
- Dependency Wave 4 is App Intents and Spotlight: Units 21a-22x. Spawn entity-domain and action-family workers only after cached repositories and routes are green; `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`, `SpoonjoySpotlightIndexer.swift`, and shared App Intents metadata are orchestrator-owned integration files. Execute Wave 4 in this exact order, ignoring lexical/unit-label sort: 21a-21c, 21d-21f, 21m-21o, 21p-21r, 21g-21i, 21j-21l, 22a-22c, 22d-22f, 22g-22i, 22m-22o, 22p-22r, 22j-22l, 22s-22u, 22v-22x. Units 21j-21l are orchestrator-only because they integrate Spotlight/App Shortcuts/transfer metadata across all entity domains and must run after every entity-domain group.
- Dependency Wave 5 is design/docs/full validation/merge: Units 23-27. Units 23a-23c and 26a-27 are orchestrator-only. No implementation spawn may bypass reviewer convergence, final validation artifacts, PR checks, or merge-readiness review.
- Spawned native workers must not edit orchestrator-owned shared paths directly: `Sources/SpoonjoyCore/AppState/**`, `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`, `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`, `Apps/Spoonjoy/Shared/AppShell/**`, `Apps/Spoonjoy/Shared/Components/**`, `Apps/Spoonjoy/Shared/Design/**`, all `Apps/Spoonjoy/Shared/Views/**`, `Apps/Spoonjoy/Shared/Native/**`, `scripts/generate-xcode-project.rb`, `Spoonjoy.xcodeproj/**`, and `.github/workflows/**`. Workers produce feature-local files, tests, and patch notes; the orchestrator serializes shared-path integration commits.
- Spawned-unit Output lines that mention scenario verifier updates, scenario metadata, project generator updates, project membership, route updates, core metadata updates, native capability metadata, shared App Intents files, shared Spotlight files, AppShell, shared Design, shared Views, or shared Components mean feature-local patch notes only. The worker must write `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/integration-notes/<unit-slug>.md` with `Needed shared paths`, `Expected tokens/tests`, and `Patch sketch`; the orchestrator applies those shared edits in a serialized integration commit before the unit's coverage/refactor step.
- Spawned backend workers must not edit orchestrator-owned shared REST files directly: `app/lib/api-v1.server.ts`, `app/lib/api-v1-contract.server.ts`, `app/lib/api-v1-openapi.server.ts`, `app/lib/generated/api-v1-playground.ts`, `docs/api.md`, `scripts/generate-api-playground.ts`, and shared OpenAPI/docs route files. Backend workers may edit endpoint-family tests, migrations, and feature-local helper modules named `app/lib/api-v1-<domain>.server.ts`; any Output line that mentions shared handlers, contracts, OpenAPI schemas, generated playground, or docs means feature-local patch notes only. The worker must write `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity/web/integration-notes/<unit-slug>.md` with `Needed shared paths`, `Route/handler wiring`, `Schemas/docs/playground changes`, and `Patch sketch`; the orchestrator applies those shared edits in a serialized integration commit before the unit's coverage/refactor step.

## Worker Write Scope Contracts

Native workers may edit only the files in the unit's Output plus the worker-owned source roots below. App target shared views/components, project files, scenario verifiers, design manifests, App Intents registrars, Spotlight registrars, and metadata files are always orchestrator-owned integration work even when a unit's Output names the resulting product behavior.

| Units | Worker-owned Swift source roots | Worker-owned tests/checks | Orchestrator-only integration |
| --- | --- | --- | --- |
| 11a-11c | `Sources/SpoonjoyCore/API/**` | `Tests/SpoonjoyCoreTests/NativeAPIExpansionTests.swift` | Project membership, scenario metadata |
| 12a-12c | `Sources/SpoonjoyCore/API/**` | `Tests/SpoonjoyCoreTests/APITransportTests.swift` | Shared app state wiring |
| 13a-13c | `Sources/SpoonjoyCore/Auth/**` | `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift` | App auth adapters, URL callback wiring, project membership |
| 14a-14c | `Sources/SpoonjoyCore/Offline/**`, `Sources/SpoonjoyCore/Cache/**` | `Tests/SpoonjoyCoreTests/NativeCacheFreshnessTests.swift` | `NativeAppSnapshot`, shell indicator integration |
| 15a-15c | `Sources/SpoonjoyCore/Sync/**`, `Sources/SpoonjoyCore/Offline/**` | `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift` | `MutationQueue`, global sync shell integration |
| 16a-16c | `Sources/SpoonjoyCore/Stores/**` | `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift` | `Sources/SpoonjoyCore/AppState/**`, AppShell wiring |
| 17a-20c | `Sources/SpoonjoyCore/Features/<feature>/**` | Unit-named `Tests/SpoonjoyCoreTests/*Tests.swift` and feature-local static checks | All `Apps/Spoonjoy/Shared/Views/**`, `Apps/Spoonjoy/Shared/Components/**`, route maps, design manifests, project membership |
| 21a-22x | `Sources/SpoonjoyCore/AppIntents/<domain>/**` | Unit-named App Intents tests and `scripts/check-app-intents-contract.rb` domain cases | `Apps/Spoonjoy/Shared/Native/**`, `SpoonjoyAppIntents.swift`, `SpoonjoySpotlightIndexer.swift`, native capability metadata |
| 23a-27 | None unless the unit explicitly says otherwise | Review, validation, docs, and merge artifacts | Orchestrator-owned |

Backend workers may edit only the test files named in the unit Output, migrations required by that endpoint family, and the helper file listed below. Shared route dispatch, contract registration, OpenAPI schemas, generated playground output, and docs are always orchestrator-owned integration work from the required `web/integration-notes/<unit-slug>.md`.

| Units | Domain | Worker-owned helper file |
| --- | --- | --- |
| 1a-1c | contract registry | orchestrator-only, no spawned backend helper |
| 2a-2c | account-tokens | `app/lib/api-v1-account.server.ts` |
| 3a-3c | users-search | `app/lib/api-v1-users-search.server.ts` |
| 4a-4c | recipe-writes | `app/lib/api-v1-recipe-writes.server.ts` |
| 5a-5c | recipe-steps | `app/lib/api-v1-recipe-steps.server.ts` |
| 6a-6c | recipe-covers | `app/lib/api-v1-recipe-covers.server.ts` |
| 7a-7c | spoons | `app/lib/api-v1-spoons.server.ts` |
| 8a-8c | cookbook-writes | `app/lib/api-v1-cookbook-writes.server.ts` |
| 9a-9c | shopping | `app/lib/api-v1-shopping.server.ts` |
| 10a-10c | native-sync | `app/lib/api-v1-native-sync.server.ts` |
| 10d-10f | recipe-import | `app/lib/api-v1-recipe-import.server.ts` |
| 20a-20c | aasa-links | `app/lib/api-v1-aasa.server.ts` only if helper extraction is needed |
| 24a-25c | docs-validation | orchestrator-only, no spawned backend helper |

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

## Validation Command Matrix

All native validation shorthand resolves through this matrix. Run `export ARTIFACT_ROOT=/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity` before any matrix command; commands run from `/Users/arimendelow/Projects/spoonjoy-apple`; `<unit-slug>` is deterministic. If a unit Output says `Validation Command Matrix artifacts for <slug>`, use that `<slug>`. If a unit Output names explicit logs instead, use the common prefix before `-red`, `-green`, `-coverage-test`, `-coverage-enforce`, `-warning-scan`, `-xcodebuild-ios`, `-xcodebuild-macos`, or another matrix suffix; for example `apple/unit-11c-native-api-green.log` and `apple/unit-11c-native-api-coverage-test.log` both resolve to `unit-11c-native-api`. No worker may invent alternate slugs.

- `swift-focused`: `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter <TestSuiteName> | tee "$ARTIFACT_ROOT/apple/<unit-slug>-swift-test.log"`.
- `swift-full`: `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors | tee "$ARTIFACT_ROOT/apple/<unit-slug>-swift-full.log"`.
- `coverage`: `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors | tee "$ARTIFACT_ROOT/apple/<unit-slug>-coverage-test.log"`, then `coverage_json="$(swift test --show-codecov-path | tail -n 1)"`, then `ruby scripts/enforce-swift-coverage.rb --coverage-json "$coverage_json" --minimum 100 --include "Sources/SpoonjoyCore" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-coverage-enforce.log"`.
- `warning-scan`: `bash -lc 'set -o pipefail; shopt -s nullglob; args=(); for path in "$ARTIFACT_ROOT/apple/<unit-slug>"*.log; do [[ "$path" == *-warning-scan.log ]] && continue; args+=(--log "$path"); done; [[ ${#args[@]} -gt 0 ]] || { echo "no logs found for <unit-slug>"; exit 1; }; ruby scripts/fail-on-warning.rb "${args[@]}"' | tee "$ARTIFACT_ROOT/apple/<unit-slug>-warning-scan.log"`.
- `project-contract`: `scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb | tee "$ARTIFACT_ROOT/apple/<unit-slug>-project-contract.log"`.
- `project-generator-contract`: `scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb | tee "$ARTIFACT_ROOT/apple/<unit-slug>-project-generator-contract.log"`.
- `surface:recipe`: `ruby scripts/check-kitchen-recipe-surfaces.rb | tee "$ARTIFACT_ROOT/apple/<unit-slug>-surface-kitchen-recipe.log"`.
- `surface:cook-shopping`: `ruby scripts/check-cook-shopping-surfaces.rb | tee "$ARTIFACT_ROOT/apple/<unit-slug>-surface-cook-shopping.log"`.
- `surface:search-capture-settings`: `ruby scripts/check-search-capture-settings-surfaces.rb | tee "$ARTIFACT_ROOT/apple/<unit-slug>-surface-search-capture-settings.log"`.
- `design-contract`: `ruby scripts/check-native-design-language.rb --web-design-doc docs/source/spoonjoy-v2-design-language.md | tee "$ARTIFACT_ROOT/apple/<unit-slug>-native-design-contract.log"`.
- `appintents-contract`: create `scripts/check-app-intents-contract.rb` in the first App Entity red-test unit, then run `ruby scripts/check-app-intents-contract.rb --domain <domain> | tee "$ARTIFACT_ROOT/apple/<unit-slug>-app-intents-contract.log"`. The script must fail on unknown domains and must cover `recipe-cookbook`, `shopping`, `spoon`, `capture-draft`, `chef-profile`, `spotlight-shortcuts`, `open-search-share-cook`, `recipe-action`, `shopping-intents`, `spoon-intents`, `capture-import-intents`, `cookbook-intents`, `profile-settings-intents`, and `notification-intents`.
- `scenario:bootstrap`: `scripts/verify-native-scenarios.sh --stage bootstrap --output "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-bootstrap.json" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-bootstrap.log"`.
- `scenario:native-metadata`: `scripts/verify-native-scenarios.sh --stage native-metadata --output "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-native-metadata.json" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-native-metadata.log"`.
- `scenario:surfaces`: `scripts/verify-native-scenarios.sh --stage surfaces --output "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-surfaces.json" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-surfaces.log"`.
- `scenario:final`: `scripts/verify-native-scenarios.sh --stage final --output "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-final.json" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-scenario-final.log"`.
- `screenshots`: `scripts/capture-native-screenshots.sh --artifact-root "$ARTIFACT_ROOT" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-screenshots.log"`; required artifacts are `$ARTIFACT_ROOT/screenshots/ios-mobile.png`, `$ARTIFACT_ROOT/screenshots/macos-desktop.png`, and `$ARTIFACT_ROOT/design-review.json` or structured blocker JSON produced by the script.
- `design-review`: `ruby scripts/validate-design-review.rb "$ARTIFACT_ROOT/design-review.json" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-design-review.log"`.
- `aasa`: `ruby scripts/validate-aasa.rb --artifact-root "$ARTIFACT_ROOT" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-aasa.log"`; missing Team ID/App ID is accepted only as `$ARTIFACT_ROOT/aasa-production-blocker.json` with `capability: "AASAProductionValidation"` matching the Blocker Artifact Contract.
- `xcodebuild-ios`: `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build | tee "$ARTIFACT_ROOT/apple/<unit-slug>-xcodebuild-ios.log"`; if the command fails only because the required simulator platform/runtime is unavailable, write `$ARTIFACT_ROOT/apple/<unit-slug>-ios-app-bundle-blocker.json` with `capability: "XcodePlatform"` matching the Blocker Artifact Contract.
- `xcodebuild-macos`: `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build | tee "$ARTIFACT_ROOT/apple/<unit-slug>-xcodebuild-macos.log"`; any build/test failure after project parsing is a hard failure to fix. Only a local Xcode installation/SDK fault that prevents project parsing may produce `$ARTIFACT_ROOT/apple/<unit-slug>-macos-app-bundle-blocker.json` with `capability: "XcodePlatform"` matching the Blocker Artifact Contract.
- `smoke-ios`: `scripts/smoke-ios-simulator.sh --artifact-root "$ARTIFACT_ROOT" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-smoke-ios.log"`; if CoreSimulator is unavailable, accept only `$ARTIFACT_ROOT/smoke-ios-simulator-blocker.json` with `capability: "CoreSimulator"` matching the Blocker Artifact Contract.
- `smoke-macos`: `scripts/smoke-macos.sh --artifact-root "$ARTIFACT_ROOT" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-smoke-macos.log"`; app crash, route failure, or screenshot failure is a hard failure to fix. Only local macOS GUI/session capability failure may produce `$ARTIFACT_ROOT/apple/<unit-slug>-smoke-macos-blocker.json` with `capability: "MacOSLaunch"` matching the Blocker Artifact Contract.
- `native-final-matrix`: `scripts/validate-native-local.sh --artifact-root "$ARTIFACT_ROOT" | tee "$ARTIFACT_ROOT/apple/<unit-slug>-validate-native-local.log"`; stable matrix artifacts are `matrix-swift-test.log`, `matrix-coverage-test.log`, `matrix-coverage-enforce.log`, `matrix-final-scenario.log`, `matrix-project-contract.log`, `matrix-generator-contract.log`, `matrix-native-design-contract.log`, `matrix-kitchen-surfaces-contract.log`, `matrix-cook-shopping-contract.log`, `matrix-search-capture-contract.log`, `matrix-capture.log`, `matrix-design-review.log`, `matrix-warning-scan.log`, `validation-matrix.jsonl`, and `validation-matrix.json`. If `validate-native-local.sh` rejects a blocker capability allowed by the Blocker Artifact Contract, Unit 26b must update the script and its tests before rerunning the matrix.

## Blocker Artifact Contract

Only these native blocker artifact capabilities are acceptable during execution: `XcodePlatform`, `CoreSimulator`, `MacOSLaunch`, `AASAProductionValidation`, `AppIntentsSDK`, `AppleDeveloperProgram`, and `ProviderSecret`. Every blocker artifact must be JSON with `blocked: true`, `capability`, `command`, `outputPath`, `reason`, and `ownerAction`; app-build/smoke blockers also include `timeoutSeconds`; SDK blockers also include `sdkSymbol`, `requiredAvailability`, and `fallbackBehavior`.

- AASA production blockers are produced only by `ruby scripts/validate-aasa.rb --artifact-root "$ARTIFACT_ROOT"` at `$ARTIFACT_ROOT/aasa-production-blocker.json`; consumers are Unit 20c and Unit 26b.
- App Intents or Spotlight SDK blockers are produced only by orchestrator-owned App Intents integration units at `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-<domain>.json` with `capability: "AppIntentsSDK"` and `<domain>` equal to the `appintents-contract --domain` value; consumers are `appintents-contract`, `scenario:native-metadata`, Unit 21l/22 coverage units, and Unit 26b.
- Xcode platform blockers are produced only by `xcodebuild-ios` at `$ARTIFACT_ROOT/apple/<unit-slug>-ios-app-bundle-blocker.json`, `xcodebuild-macos` at `$ARTIFACT_ROOT/apple/<unit-slug>-macos-app-bundle-blocker.json`, or `scripts/validate-native-local.sh` at `$ARTIFACT_ROOT/xcode-platform-blocker.json` with `capability: "XcodePlatform"`; consumers are Unit 13c, Unit 23c, and Unit 26b.
- CoreSimulator blockers are produced only by `smoke-ios` or `scripts/validate-native-local.sh` at `$ARTIFACT_ROOT/smoke-ios-simulator-blocker.json` with `capability: "CoreSimulator"`; consumers are Unit 23c and Unit 26b.
- macOS launch blockers are produced only by `smoke-macos` at `$ARTIFACT_ROOT/apple/<unit-slug>-smoke-macos-blocker.json` or by `scripts/validate-native-local.sh` at `$ARTIFACT_ROOT/smoke-macos-blocker.json`; consumers are Unit 23c and Unit 26b.
- Apple Developer Program blockers are produced only by APNs/capability units at `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json` with `capability: "AppleDeveloperProgram"`; consumers are Unit 19l, Unit 22x, and Unit 26b.
- Provider secret blockers are produced only by provider-bound backend units at `$ARTIFACT_ROOT/web/provider-secret-blocker-<domain>.json` with `capability: "ProviderSecret"` and `<domain>` equal to `recipe-covers` or `recipe-import`; consumers are Unit 6c, Unit 10f, Unit 18f, Unit 18i, and Unit 26b.

## Web Command Matrix

All web validation shorthand resolves through this matrix. Run `export ARTIFACT_ROOT=/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity` before any matrix command; commands run from `/Users/arimendelow/Projects/spoonjoy-v2`; `<unit-slug>` follows the same deterministic slug rule as the native matrix. If a unit Output says `Web Command Matrix artifacts for <slug>`, use that `<slug>`; if explicit logs are named, use the common prefix before `-red`, `-green`, or a matrix suffix, such as `unit-20c-aasa` from `web/unit-20c-aasa-green.log`.

- `web-focused`: `pnpm exec vitest run <test-files> --fileParallelism=false | tee "$ARTIFACT_ROOT/web/<unit-slug>-vitest.log"`.
- `web-route-coverage`: `pnpm exec vitest run test/config/api-v1-route-coverage.test.ts --fileParallelism=false | tee "$ARTIFACT_ROOT/web/<unit-slug>-route-coverage.log"`.
- `web-docs-drift`: `pnpm exec vitest run test/docs/developer-platform-docs.test.ts test/docs/developer-platform-guide.test.ts test/routes/api-v1-openapi.test.ts test/lib/api-v1-openapi.server.test.ts test/scripts/generate-api-playground.test.ts --fileParallelism=false | tee "$ARTIFACT_ROOT/web/<unit-slug>-docs-drift.log"`.
- `web-playground-generate`: `bash -lc 'set -o pipefail; pnpm run api:playground:generate | tee "$ARTIFACT_ROOT/web/<unit-slug>-api-playground-generate.log"; git diff --exit-code -- app/lib/generated/api-v1-playground.ts | tee "$ARTIFACT_ROOT/web/<unit-slug>-api-playground-drift.log"'`.
- `web-typecheck`: `pnpm run typecheck | tee "$ARTIFACT_ROOT/web/<unit-slug>-typecheck.log"`.
- `web-build`: `pnpm run build | tee "$ARTIFACT_ROOT/web/<unit-slug>-build.log"`.
- `web-coverage-full`: `pnpm run test:coverage | tee "$ARTIFACT_ROOT/web/<unit-slug>-coverage.log"`.
- `web-warning-scan`: `bash -lc 'set -o pipefail; shopt -s nullglob; logs=("$ARTIFACT_ROOT/web/<unit-slug>"*.log); [[ ${#logs[@]} -gt 0 ]] || { echo "no logs found for <unit-slug>"; exit 1; }; if rg -n "\\b(warning|WARN)\\b" "${logs[@]}"; then exit 1; fi' | tee "$ARTIFACT_ROOT/web/<unit-slug>-warning-scan.log"`.

Matrix-generated log and JSON names are authoritative for validation artifacts. Unit `Output` lines may also name summary files, changed source files, or human-readable review documents, but artifact audits must verify the matrix-generated paths above when a unit lists a matrix entry in `What`.

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
**What**: Run Web Command Matrix entries `web-focused` with `test/config/api-v1-route-coverage.test.ts test/routes/api-v1-openapi.test.ts test/lib/api-v1-openapi.server.test.ts test/scripts/generate-api-playground.test.ts test/docs/developer-platform-docs.test.ts test/docs/developer-platform-guide.test.ts`, `web-route-coverage`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-1c-contract`.
**Acceptance**: Contract tests pass, typecheck passes, route coverage fails on any future contract/resource mismatch, and generated docs contain native OAuth/token guidance.

### ⬜ Unit 2a: Native Bootstrap And Account API - Tests
**What**: Write failing `spoonjoy-v2` route/lib tests for `GET /api/v1/me`, `PATCH /api/v1/me`, `GET /api/v1/me/kitchen`, notification preferences, APNs device registration/revocation, account connections, token list/create/revoke in native account context, auth/scope failures, and private cache headers.
**Output**: `test/routes/api-v1-me.test.ts`, token/account extensions, and `web/unit-2a-me-red.log`.
**Acceptance**: Tests fail with missing handlers or incomplete payloads; failures assert exact response envelope keys, private no-store headers, validation errors, and scope requirements.

### ⬜ Unit 2b: Native Bootstrap And Account API - Implementation
**What**: Implement native bootstrap/account handlers in `app/lib/api-v1.server.ts` using existing account, auth, notification, token, and session helpers; add a tested Prisma migration for a dedicated `NativePushDevice` table instead of reusing `PushSubscription`, because APNs needs platform/environment/device-token metadata that web-push endpoint keys do not model.
**Output**: API handlers, helper functions, Prisma schema/migration/tests for `NativePushDevice`, and docs examples.
**Acceptance**: Unit 2a tests pass; bearer and session auth both work; passkey/password/provider-link actions return exact web handoff URLs rather than fake native mutations; APNs registration stores user id, platform, environment, device identifier, hashed APNs token, token prefix, enabled/revoked timestamps, and last registration timestamp without writing a `PushSubscription` row.

### ⬜ Unit 2c: Native Bootstrap And Account API - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-me.test.ts test/routes/api-v1-tokens.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-2c-account`.
**Acceptance**: New account/bootstrap/token code has 100% branch/error coverage, zero warnings, and no stale generated playground output.

### ⬜ Unit 3a: Profile, Chef Graph, And Search API - Tests
**What**: Write failing tests for `GET /api/v1/users/{identifier}`, `GET /api/v1/users/{identifier}/fellow-chefs`, `GET /api/v1/users/{identifier}/kitchen-visitors`, and `GET /api/v1/search` with `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list` scopes.
**Output**: `test/routes/api-v1-users-search.test.ts` and `web/unit-3a-users-search-red.log`.
**Acceptance**: Tests fail before handlers exist and assert payload parity with profile/search web surfaces, anonymous vs authenticated search behavior, shopping-list auth, and invalid scope errors.

### ⬜ Unit 3b: Profile, Chef Graph, And Search API - Implementation
**What**: Implement profile, chef graph, and search handlers using `app/lib/fellow-chefs.server.ts`, `app/lib/search.server.ts`, current Prisma relations, and v1 envelope helpers.
**Output**: `app/lib/api-v1.server.ts` handler additions plus extracted serializer helpers for profile and search payloads.
**Acceptance**: Unit 3a tests pass; deleted recipes/spoons stay hidden; shopping-list search requires auth; profile payload includes recipes, cookbooks, spoons, fellow chefs, and kitchen visitors.

### ⬜ Unit 3c: Profile, Chef Graph, And Search API - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-users-search.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-3c-users-search`.
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
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-recipe-writes.test.ts test/lib/api-idempotency.server.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-4c-recipe-writes`.
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
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-recipe-steps.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-5c-recipe-steps`.
**Acceptance**: Touched step/dependency code has 100% coverage and no warnings.

### ⬜ Unit 6a: Recipe Image And Cover Lifecycle API - Tests
**What**: Write failing tests for `POST /api/v1/recipes/{id}/image`, cover list/create/set/remove/archive/regenerate/from-spoon endpoints, owner checks, source variants, failure states, malformed uploads, and no-production-secret behavior for AI generation, including `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-covers.json`.
**Output**: `test/routes/api-v1-recipe-covers.test.ts` and `web/unit-6a-covers-red.log`.
**Acceptance**: Tests fail before v1 handlers exist and assert exact cover history response shapes, upload constraints, and structured AI/provider blocker responses for missing local secrets.

### ⬜ Unit 6b: Recipe Image And Cover Lifecycle API - Implementation
**What**: Implement image/cover handlers using `app/lib/image-storage.server.ts`, `app/lib/recipe-cover.server.ts`, `app/lib/recipe-image-assignment.server.ts`, spoon cover helpers, and background task boundaries.
**Output**: API handlers, docs/OpenAPI schemas, tested no-secret behavior, and `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-covers.json` when local provider secrets are unavailable.
**Acceptance**: Unit 6a tests pass; upload, active cover, archive, regenerate, and spoon-cover flows match web behavior; missing provider secrets emit only the canonical `ProviderSecret` blocker for `recipe-covers`.

### ⬜ Unit 6c: Recipe Image And Cover Lifecycle API - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-recipe-covers.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-6c-covers`.
**Acceptance**: Touched cover/image code has 100% coverage and every provider/blocker/error branch is tested, including `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-covers.json` matching the Blocker Artifact Contract.

### ⬜ Unit 7a: Spoon Cook Log API - Tests
**What**: Write failing tests for `GET/POST/PATCH/DELETE /api/v1/recipes/{id}/spoons/{spoonId?}` covering list pagination, create, update, delete, photo URL/upload contract, note/nextTime/cookedAt validation, owner checks, origin-cook notification flags, deleted spoons, and cover-from-spoon integration.
**Output**: `test/routes/api-v1-spoons.test.ts` and `web/unit-7a-spoons-red.log`.
**Acceptance**: Tests fail before v1 spoon handlers exist and assert exact response envelopes plus private/public cache behavior.

### ⬜ Unit 7b: Spoon Cook Log API - Implementation
**What**: Implement spoon handlers using `app/lib/recipe-spoon.server.ts`, recipe detail serializers, notification helpers, and v1 idempotency for writes.
**Output**: API handlers, serializers, docs/OpenAPI schemas, and playground examples.
**Acceptance**: Unit 7a tests pass; spoon list/detail payloads feed native cook log, profile, Spotlight, and cover-from-spoon flows.

### ⬜ Unit 7c: Spoon Cook Log API - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-spoons.test.ts test/lib/spoonjoy-api-spoons.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-7c-spoons`.
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
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-cookbook-writes.test.ts test/lib/spoonjoy-api-cookbook-notification.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-8c-cookbook-writes`.
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
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-shopping-mutations.test.ts test/routes/api-v1-shopping-conflicts.test.ts`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-9c-shopping-parity`.
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
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-native-sync.test.ts`, `web-route-coverage`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-10c-sync`.
**Acceptance**: Touched sync code has 100% coverage, including invalid cursors, empty states, and tombstone-only pages.

### ⬜ Unit 10d: Recipe Import API - Tests
**What**: Write failing tests for `POST /api/v1/recipes/import` covering URL import, text import, JSON-LD import, video URL import, local no-provider-secret behavior through `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-import.json`, duplicate title behavior, validation errors, auth/scope failures, idempotency replay/conflict, and exact capture/import response envelopes.
**Output**: `test/routes/api-v1-recipe-import.test.ts` and `web/unit-10d-recipe-import-red.log`.
**Acceptance**: Tests fail before the REST v1 import handler exists and assert the outbound/native contract that capture drafts will call.

### ⬜ Unit 10e: Recipe Import API - Implementation
**What**: Implement `POST /api/v1/recipes/import` using existing import helpers in `app/lib/recipe-import*.server.ts`, recipe creation helpers, v1 idempotency helpers, request body limits, and structured provider-secret blocker responses.
**Output**: Import API handler, serializers, docs/OpenAPI schemas, generated playground examples, and `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-import.json` when local provider secrets are unavailable.
**Acceptance**: Unit 10d tests pass; missing AI/provider secrets return only the canonical `ProviderSecret` blocker for `recipe-import` rather than silently pretending import completed.

### ⬜ Unit 10f: Recipe Import API - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-focused` with `test/routes/api-v1-recipe-import.test.ts`, `web-route-coverage`, `web-docs-drift`, `web-playground-generate`, `web-typecheck`, `web-coverage-full`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-10f-recipe-import`.
**Acceptance**: Touched import API code has 100% coverage, including invalid URL/text, provider failure, `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-import.json`, replay, conflict, auth, scope, and duplicate-title branches.

### ⬜ Unit 11a: Native Request Builders For Expanded REST V1 - Tests
**What**: In `spoonjoy-apple`, write failing Swift tests for request builders covering every new backend endpoint, auth policy, JSON/form/multipart bodies, idempotency keys, query/cursor handling, private/public cache metadata, and error envelope decoding.
**Output**: `Tests/SpoonjoyCoreTests/NativeAPIExpansionTests.swift` and `apple/unit-11a-native-api-red.log`.
**Acceptance**: Tests fail before Swift request builders/models exist and every test captures outbound method, URL path/query, headers, and body.

### ⬜ Unit 11b: Native Request Builders For Expanded REST V1 - Implementation
**What**: Implement expanded request builders and models under `Sources/SpoonjoyCore/API/`, including account, profile, search, recipe writes, covers, spoons, cookbooks, shopping parity, sync, tokens, APNs, and docs handoff URL requests.
**Output**: Swift API files and model serializers.
**Acceptance**: Unit 11a tests pass; no request builder sends bearer tokens to anonymous public catalog reads by default.

### ⬜ Unit 11c: Native Request Builders For Expanded REST V1 - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeAPIExpansionTests`, `swift-full`, `coverage`, and `warning-scan`.
**Output**: `apple/unit-11c-native-api-green.log`, `apple/unit-11c-native-api-coverage-test.log`, `apple/unit-11c-native-api-coverage-enforce.log`, and `apple/unit-11c-native-api-warning-scan.log`.
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
**What**: Run Validation Command Matrix entries `swift-focused` with `APITransportTests`, `swift-full`, `coverage`, and `warning-scan`.
**Output**: `apple/unit-12c-transport-green.log`, `apple/unit-12c-transport-coverage-test.log`, `apple/unit-12c-transport-coverage-enforce.log`, and `apple/unit-12c-transport-warning-scan.log`.
**Acceptance**: Transport code has 100% measured coverage and no warnings.

### ⬜ Unit 13a: Native OAuth, Keychain, And Session Store - Tests
**What**: Write failing Swift tests and app static checks for ASWebAuthenticationSession launch/callback routing, universal-link OAuth redirect, Keychain token vault, persisted client id, refresh-token rotation, revoke/logout, auth state restoration, and exact secure web handoff URLs.
**Output**: `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift`, app static contract tests, and `apple/unit-13a-auth-red.log`.
**Acceptance**: Tests fail before Keychain/app auth integration exists; custom scheme OAuth redirects remain rejected.

### ⬜ Unit 13b: Native OAuth, Keychain, And Session Store - Implementation
**What**: Implement Keychain-backed vault in app target, session repository in `Sources/SpoonjoyCore/Auth`, ASWebAuthenticationSession adapters, universal-link callback handling, and settings sign-in/out/revoke actions.
**Output**: Auth/session Swift sources, `apple/integration-notes/unit-13b-auth.md` covering orchestrator-applied app adapter/project updates, and docs for local non-production signing.
**Acceptance**: Unit 13a tests pass; app static checks prove associated-domain OAuth callback and custom-scheme fallback are separate.

### ⬜ Unit 13c: Native OAuth, Keychain, And Session Store - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeAuthSessionTests`, `swift-full`, `project-generator-contract`, `project-contract`, `coverage`, `xcodebuild-ios`, `xcodebuild-macos`, and `warning-scan`.
**Output**: `apple/unit-13c-auth-green.log`, `apple/unit-13c-auth-coverage-test.log`, `apple/unit-13c-auth-coverage-enforce.log`, `apple/unit-13c-auth-xcodebuild-ios.log`, and `apple/unit-13c-auth-xcodebuild-macos.log`.
**Acceptance**: SwiftPM auth code has 100% coverage; app adapter compile/static checks cover Keychain and ASWebAuthenticationSession boundaries.

### ⬜ Unit 14a: Native Cache Schema And Freshness Indicator - Tests
**What**: Write failing Swift tests for durable cache schema version 2, cached recipes/cookbooks/details/shopping/cook progress/capture/profile/notifications/tokens/connections/APNs status, freshness states, dismissed indicator persistence, stale thresholds, sync failure display, queued-work display, and corrupt-cache recovery.
**Output**: `Tests/SpoonjoyCoreTests/NativeCacheFreshnessTests.swift` and `apple/unit-14a-cache-red.log`.
**Acceptance**: Tests fail before expanded cache/freshness model exists and assert exact state transitions for synced, offline, stale, queued, failed, and dismissed states.

### ⬜ Unit 14b: Native Cache Schema And Freshness Indicator - Implementation
**What**: Implement expanded offline snapshot/cache models, freshness state machine, dismissible indicator state, cache migration from schema version 1, and app `OfflineStatusView` updates.
**Output**: Swift core cache files, fixtures, and `apple/integration-notes/unit-14b-cache.md` covering orchestrator-applied `OfflineStatusView.swift` and scenario metadata updates.
**Acceptance**: Unit 14a tests pass; dismissing the indicator persists only the dismissal state and never hides sync failure or conflict state.

### ⬜ Unit 14c: Native Cache Schema And Freshness Indicator - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeCacheFreshnessTests`, `swift-full`, `coverage`, `scenario:bootstrap`, and `warning-scan`.
**Output**: `apple/unit-14c-cache-green.log`, `apple/unit-14c-cache-coverage-test.log`, `apple/unit-14c-cache-coverage-enforce.log`, and `apple/unit-14c-cache-scenario-bootstrap.json`.
**Acceptance**: Cache/freshness code has 100% measured coverage and UI static checks prove indicator labels/icons for every state.

### ⬜ Unit 15a: Native Sync Engine And Mutation Queue Expansion - Tests
**What**: Write failing Swift tests for sync bootstrapping, foreground/network recovery, cursor checkpoints, conflict classification, retry backoff, queue drain, replay removal, tombstone application, and queued mutation kinds for recipe, cookbook, spoon, cover, shopping, profile, notification, APNs, and capture/import writes.
**Output**: `Tests/SpoonjoyCoreTests/NativeSyncEngineTests.swift` and `apple/unit-15a-sync-engine-red.log`.
**Acceptance**: Tests fail before sync engine exists and assert outgoing request order plus cache mutation results.

### ⬜ Unit 15b: Native Sync Engine And Mutation Queue Expansion - Implementation
**What**: Implement native repositories, sync engine, mutation queue expansion, conflict models, and retry scheduling under `Sources/SpoonjoyCore/Offline` and `Sources/SpoonjoyCore/AppState`.
**Output**: Sync engine sources, repository protocols, fixtures, and feature-local scenario verifier integration notes for the orchestrator.
**Acceptance**: Unit 15a tests pass; offline writes survive app restart and drain once transport reports network success.

### ⬜ Unit 15c: Native Sync Engine And Mutation Queue Expansion - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeSyncEngineTests`, `swift-full`, `coverage`, `scenario:native-metadata`, and `warning-scan`.
**Output**: `apple/unit-15c-sync-engine-green.log`, `apple/unit-15c-sync-engine-coverage-test.log`, `apple/unit-15c-sync-engine-coverage-enforce.log`, and `apple/unit-15c-sync-engine-scenario-native-metadata.json`.
**Acceptance**: Sync engine code has 100% measured coverage and no hidden untested error branches.

### ⬜ Unit 16a: Native Live Store And Shell Wiring - Tests
**What**: Write failing Swift tests/static checks for replacing fixture-primary app state with live repositories, bootstrap loading, signed-out state, signed-in cache restore, environment switching, global search scopes, and deterministic fixture fallback only in tests/demo.
**Output**: `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift`, shell static checks, and `apple/unit-16a-live-store-red.log`.
**Acceptance**: Tests fail before live store wiring exists and assert no production path silently uses fixtures after auth/cache bootstrap succeeds.

### ⬜ Unit 16b: Native Live Store And Shell Wiring - Implementation
**What**: Wire `SpoonjoyRootView`, `PlatformNavigationView`, settings model, and shared app store to auth/session/transport/cache/sync repositories.
**Output**: App shell Swift updates plus orchestrator-applied project generator and scenario verifier checks.
**Acceptance**: Unit 16a tests pass; shell can render signed-out, restoring cache, live synced, offline stale, and sync-failed states.

### ⬜ Unit 16c: Native Live Store And Shell Wiring - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeLiveStoreTests`, `swift-full`, `scenario:surfaces`, `project-contract`, `xcodebuild-macos`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-16c-live-store`.
**Acceptance**: Store logic has 100% measured coverage and app target static/screenshot checks cover non-SwiftPM shell adapters.

### ⬜ Unit 17a: Native Recipe Catalog And Detail - Tests
**What**: Write failing Swift tests/static scenario checks for live recipe catalog loading, search/filter state, recipe detail cache restore, cover/provenance display, chef attribution, servings, steps, ingredients, dependencies, spoon summary, cookbook-save state, owner-tool visibility, and offline stale state.
**Output**: `Tests/SpoonjoyCoreTests/RecipeCatalogDetailTests.swift`, surface contract tests, and `apple/unit-17a-recipe-catalog-detail-red.log`.
**Acceptance**: Tests fail before catalog/detail parity exists and assert exact view model states plus route actions for read-only recipe browsing.

### ⬜ Unit 17b: Native Recipe Catalog And Detail - Implementation
**What**: Implement catalog/detail view models and SwiftUI wiring for `RecipesView.swift` and `RecipeDetailView.swift` using live repositories, cache state, native search, native share affordance placeholders, and Spoonjoy design hierarchy.
**Output**: Updated recipe catalog/detail Swift files, view models, and `apple/integration-notes/unit-17b-recipe-catalog-detail.md` for orchestrator-applied project/scenario metadata.
**Acceptance**: Unit 17a tests pass; catalog/detail reads come from live/cache repositories and fixtures remain test/demo fallback only.

### ⬜ Unit 17c: Native Recipe Catalog And Detail - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `RecipeCatalogDetailTests`, `swift-full`, `surface:recipe`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-17c-recipe-catalog-detail`.
**Acceptance**: Catalog/detail view-model code has 100% measured coverage and static/screenshot checks preserve Kitchen Table hierarchy.

### ⬜ Unit 17d: Native Cook Mode - Tests
**What**: Write failing Swift tests/static checks for start/continue cook mode, active step navigation, scale factor, ingredient checkoff, step-output dependency checkoff, duration timers for duration-bearing steps, durable progress, offline progress restore, and Siri/deep-link routes into cook mode.
**Output**: `Tests/SpoonjoyCoreTests/CookModeParityTests.swift`, cook-mode surface checks, and `apple/unit-17d-cook-mode-red.log`.
**Acceptance**: Tests fail before cook-mode parity exists and assert exact progress persistence and route behavior.

### ⬜ Unit 17e: Native Cook Mode - Implementation
**What**: Implement `CookModeView.swift`, cook-mode view models, progress persistence, timer state, scale/dependency/checkoff controls, and route/Siri handoff integration.
**Output**: Cook mode Swift files, view models, and `apple/integration-notes/unit-17e-cook-mode.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 17d tests pass; cook mode works from cached data while offline and syncs progress-related queued writes only through declared contracts.

### ⬜ Unit 17f: Native Cook Mode - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CookModeParityTests`, `swift-full`, `surface:cook-shopping`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-17f-cook-mode`.
**Acceptance**: Cook-mode logic has 100% measured coverage and no timer/checkoff branch lacks tests.

### ⬜ Unit 17g: Native Recipe Editor - Tests
**What**: Write failing Swift tests/static checks for create, edit, delete, step create/update/delete/reorder, ingredient add/delete, dependency editing, validation, owner-only tools, offline queued drafts, and conflict display.
**Output**: `Tests/SpoonjoyCoreTests/RecipeEditorParityTests.swift`, editor surface checks, and `apple/unit-17g-recipe-editor-red.log`.
**Acceptance**: Tests fail before editor parity exists and assert exact request/mutation kinds and validation messages.

### ⬜ Unit 17h: Native Recipe Editor - Implementation
**What**: Implement native recipe editor view models and SwiftUI forms using native controls, REST v1 recipe/step/ingredient/dependency endpoints, offline queued drafts, and owner confirmations.
**Output**: Recipe editor Swift files, view models, and `apple/integration-notes/unit-17h-recipe-editor.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 17g tests pass; editor mutations use live REST contracts or durable offline queue entries.

### ⬜ Unit 17i: Native Recipe Editor - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `RecipeEditorParityTests`, `swift-full`, `surface:recipe`, `scenario:surfaces`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-17i-recipe-editor`.
**Acceptance**: Editor view-model code has 100% measured coverage and all validation/conflict/error states are tested.

### ⬜ Unit 17j: Native Recipe Actions - Tests
**What**: Write failing Swift tests/static checks for fork, save to cookbook, remove from cookbook, add recipe ingredients to shopping, owner delete confirmation, owner cover-entry routing, and route/action state from recipe detail.
**Output**: `Tests/SpoonjoyCoreTests/RecipeActionParityTests.swift`, action surface checks, and `apple/unit-17j-recipe-actions-red.log`.
**Acceptance**: Tests fail before recipe action parity exists and assert exact queued or live mutation behavior for each action.

### ⬜ Unit 17k: Native Recipe Actions - Implementation
**What**: Implement recipe action view models and UI affordances in recipe detail/cook surfaces using native menus/buttons/confirmation dialogs and live REST contracts.
**Output**: Recipe action Swift files, view model updates, and `apple/integration-notes/unit-17k-recipe-actions.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 17j tests pass; destructive actions require confirmation and ownership checks.

### ⬜ Unit 17l: Native Recipe Actions - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `RecipeActionParityTests`, `swift-full`, `surface:recipe`, `surface:cook-shopping`, `scenario:surfaces`, `coverage`, `screenshots`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-17l-recipe-actions`.
**Acceptance**: Recipe action logic has 100% measured coverage and does not introduce comments/feed/reactions.

### ⬜ Unit 18a: Native Spoon Cook Logs - Tests
**What**: Write failing Swift tests/static checks for cook log list, create, edit, delete, photo URL/upload draft, note, nextTime, cookedAt, owner checks, offline draft persistence, and profile/detail reuse.
**Output**: `Tests/SpoonjoyCoreTests/SpoonCookLogSurfaceTests.swift`, spoon surface checks, and `apple/unit-18a-spoon-logs-red.log`.
**Acceptance**: Tests fail before spoon surfaces exist and assert exact view model states plus REST/offline mutation behavior.

### ⬜ Unit 18b: Native Spoon Cook Logs - Implementation
**What**: Implement spoon/cook-log view models and SwiftUI sheets/rows using live spoon endpoints, local offline drafts, and confirmation on delete.
**Output**: Spoon Swift views/components, view models, and `apple/integration-notes/unit-18b-spoon-logs.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 18a tests pass; spoon photo/note/nextTime/cookedAt workflows sync through REST v1.

### ⬜ Unit 18c: Native Spoon Cook Logs - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `SpoonCookLogSurfaceTests`, `swift-full`, `surface:recipe`, `surface:search-capture-settings`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-18c-spoon-logs`.
**Acceptance**: Spoon view-model logic has 100% measured coverage and deleted/owner/conflict states are tested.

### ⬜ Unit 18d: Native Cover Controls - Tests
**What**: Write failing Swift tests/static checks for cover history, active variant display, upload entry, set active, remove/archive, regenerate, cover-from-spoon, provider-secret blocker display, owner-only controls, and offline state.
**Output**: `Tests/SpoonjoyCoreTests/CoverControlSurfaceTests.swift`, cover surface checks, and `apple/unit-18d-cover-controls-red.log`.
**Acceptance**: Tests fail before cover controls exist and assert exact request/mutation behavior plus confirmation state.

### ⬜ Unit 18e: Native Cover Controls - Implementation
**What**: Implement cover controls in recipe owner surfaces using REST v1 image/cover endpoints, spoon-cover integration, native photo/file affordances, and tested blocker display.
**Output**: Cover Swift views/components, view models, and `apple/integration-notes/unit-18e-cover-controls.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 18d tests pass; cover lifecycle behavior matches web and does not require production secrets for local validation.

### ⬜ Unit 18f: Native Cover Controls - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CoverControlSurfaceTests`, `swift-full`, `surface:recipe`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-18f-cover-controls`.
**Acceptance**: Cover-control view-model logic has 100% measured coverage and every provider/blocker state is visible, including the canonical `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-covers.json` state when present.

### ⬜ Unit 18g: Native Capture And Import - Tests
**What**: Write failing Swift tests/static checks for capture draft URL/text/camera/share-sheet intake, local draft persistence, import submission to `POST /api/v1/recipes/import`, provider-secret blocker handling, imported recipe routing, and offline retry.
**Output**: `Tests/SpoonjoyCoreTests/CaptureImportSurfaceTests.swift`, capture surface checks, and `apple/unit-18g-capture-import-red.log`.
**Acceptance**: Tests fail before capture/import parity exists and assert exact capture draft to backend import transition.

### ⬜ Unit 18h: Native Capture And Import - Implementation
**What**: Implement capture/import UI and view models using native share/camera/photo affordances, local drafts, import endpoint requests, and sync retry.
**Output**: Capture/import Swift views/components, view models, and `apple/integration-notes/unit-18h-capture-import.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 18g tests pass; local capture works offline and import submits through the REST v1 import contract.

### ⬜ Unit 18i: Native Capture And Import - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CaptureImportSurfaceTests`, `swift-full`, `surface:search-capture-settings`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-18i-capture-import`.
**Acceptance**: Capture/import view-model logic has 100% measured coverage and no import path bypasses the backend contract, including the canonical `$ARTIFACT_ROOT/web/provider-secret-blocker-recipe-import.json` state when present.

### ⬜ Unit 18j: Native Sharing Payloads - Tests
**What**: Write failing Swift tests/static checks for recipe, cookbook, shopping-list, spoon, and capture-draft share payloads, public URL generation, `ShareLink` presentation state, transfer values for Shortcuts/Siri, and share-sheet destination neutrality.
**Output**: `Tests/SpoonjoyCoreTests/NativeSharingTests.swift`, sharing surface checks, and `apple/unit-18j-sharing-red.log`.
**Acceptance**: Tests fail before first-class sharing exists and assert that Spoonjoy does not adopt Messages/Mail schemas.

### ⬜ Unit 18k: Native Sharing Payloads - Implementation
**What**: Implement native share payload builders, `ShareLink` usage, Shortcuts/Siri transfer values, and public URL builders for recipe/cookbook/shopping/spoon/capture objects.
**Output**: Sharing Swift files/components, view model updates, and `apple/integration-notes/unit-18k-sharing.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 18j tests pass; sharing opens system share sheet destinations without adding Spoonjoy messaging or mail product surfaces.

### ⬜ Unit 18l: Native Sharing Payloads - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NativeSharingTests`, `swift-full`, `surface:recipe`, `surface:cook-shopping`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-18l-sharing`.
**Acceptance**: Sharing logic has 100% measured coverage and all generated public URLs route through `spoonjoy.app`.

### ⬜ Unit 19a: Native Cookbook Surfaces - Tests
**What**: Write failing Swift tests/static checks for cookbook list/detail, recipe contents, create, rename, delete, add recipe, remove recipe, share, owner checks, destructive confirmations, offline cache restore, and queued mutations.
**Output**: `Tests/SpoonjoyCoreTests/CookbookSurfaceParityTests.swift`, cookbook surface checks, and `apple/unit-19a-cookbooks-red.log`.
**Acceptance**: Tests fail before cookbook parity exists and assert exact REST/offline mutation behavior.

### ⬜ Unit 19b: Native Cookbook Surfaces - Implementation
**What**: Implement cookbook views and view models in `CookbooksView.swift` and supporting components using native forms, lists, toolbars, and live REST contracts.
**Output**: Cookbook Swift views/components, view models, and `apple/integration-notes/unit-19b-cookbooks.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 19a tests pass; cookbook create/rename/delete/add/remove actions use declared REST v1 endpoints with confirmation where destructive.

### ⬜ Unit 19c: Native Cookbook Surfaces - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CookbookSurfaceParityTests`, `swift-full`, `surface:recipe`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-19c-cookbooks`.
**Acceptance**: Cookbook view-model logic has 100% measured coverage and UI uses platform-correct native controls.

### ⬜ Unit 19d: Native Profile And Chef Graph Surfaces - Tests
**What**: Write failing Swift tests/static checks for profile views, profile recipes, cookbooks, spoons, fellow chefs, kitchen visitors, route handling by username/id, public cache restore, and signed-in personalization.
**Output**: `Tests/SpoonjoyCoreTests/ProfileChefGraphSurfaceTests.swift`, profile surface checks, and `apple/unit-19d-profiles-red.log`.
**Acceptance**: Tests fail before profile parity exists and assert exact cached/live profile payload states.

### ⬜ Unit 19e: Native Profile And Chef Graph Surfaces - Implementation
**What**: Implement profile and chef graph SwiftUI surfaces/view models using profile/search/sync endpoints and Spoonjoy social-derived product model.
**Output**: Profile Swift views/components, view models, and `apple/integration-notes/unit-19e-profiles.md` for orchestrator-applied scenario verifier and route updates.
**Acceptance**: Unit 19d tests pass; profiles show only existing product concepts and do not add follows, comments, or feeds.

### ⬜ Unit 19f: Native Profile And Chef Graph Surfaces - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `ProfileChefGraphSurfaceTests`, `swift-full`, `surface:recipe`, `surface:search-capture-settings`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-19f-profiles`.
**Acceptance**: Profile view-model logic has 100% measured coverage and deleted/private object states are tested.

### ⬜ Unit 19g: Native Settings Tokens And Connections - Tests
**What**: Write failing Swift tests/static checks for signed-in/out settings, environment status, API token list/create/revoke, OAuth app connection status/disconnect, logout/revoke, secure web-auth handoff routes for passkey/password/provider-link actions, and offline account cache.
**Output**: `Tests/SpoonjoyCoreTests/SettingsTokenConnectionTests.swift`, settings surface checks, and `apple/unit-19g-settings-tokens-red.log`.
**Acceptance**: Tests fail before settings/token parity exists and assert exact native vs web-handoff boundaries.

### ⬜ Unit 19h: Native Settings Tokens And Connections - Implementation
**What**: Implement settings, API credential, OAuth connection, logout/revoke, and secure handoff UI using native forms/lists/confirmation dialogs and live REST contracts.
**Output**: `SettingsView.swift`, settings components/view models, and `apple/integration-notes/unit-19h-settings-tokens.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 19g tests pass; API credential list/create/revoke and connection disconnect are native REST-backed flows.

### ⬜ Unit 19i: Native Settings Tokens And Connections - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `SettingsTokenConnectionTests`, `swift-full`, `surface:search-capture-settings`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-19i-settings-tokens`.
**Acceptance**: Settings/token/connection view-model logic has 100% measured coverage and all destructive actions have confirmation evidence.

### ⬜ Unit 19j: Native Notification Preferences And APNs State - Tests
**What**: Write failing Swift tests/static checks for notification preference reads/writes, APNs registration status, APNs device register/revoke request flow, missing Developer Program blocker display from `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json`, permission denial display, and offline cached preferences.
**Output**: `Tests/SpoonjoyCoreTests/NotificationAPNsSurfaceTests.swift`, notification surface checks, and `apple/unit-19j-notifications-red.log`.
**Acceptance**: Tests fail before notification/APNs parity exists and assert production APNs delivery is represented only as a structured account/team blocker.

### ⬜ Unit 19k: Native Notification Preferences And APNs State - Implementation
**What**: Implement notification preference UI, APNs registration-state UI, device registration/revocation request plumbing, and blocker artifact display for missing Apple Developer Program/team capability.
**Output**: Notification settings Swift files/view models, `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json` when Apple account/team capability is unavailable, and `apple/integration-notes/unit-19k-notifications.md` for orchestrator-applied scenario verifier and project membership updates.
**Acceptance**: Unit 19j tests pass; preference APIs are native REST-backed and production APNs delivery remains blocked only by the canonical `AppleDeveloperProgram` blocker.

### ⬜ Unit 19l: Native Notification Preferences And APNs State - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NotificationAPNsSurfaceTests`, `swift-full`, `surface:search-capture-settings`, `scenario:surfaces`, `screenshots`, `coverage`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-19l-notifications`.
**Acceptance**: Notification/APNs view-model logic has 100% measured coverage, `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json` matches the Blocker Artifact Contract when produced, and no test pretends TestFlight/APNs production delivery is available.

### ⬜ Unit 20a: Universal Links Routes And AASA Contract - Tests
**What**: Write failing Swift and web tests for every `spoonjoy.app` route and `spoonjoy://` fallback route needed by native parity, including profiles, fellow chefs, kitchen visitors, account sections, notification preferences, API credentials, cookbook actions, spoon logging, covers, shopping clear/add-from-recipe, search, capture, and OAuth redirect.
**Output**: `Tests/SpoonjoyCoreTests/DeepLinkParityTests.swift`, `spoonjoy-v2/test/routes/aasa-contract.test.ts`, `apple/unit-20a-links-red.log`, and `web/unit-20a-aasa-red.log`.
**Acceptance**: Tests fail until route parser/builders and web AASA docs cover the full route list; OAuth redirect remains HTTPS universal link only.

### ⬜ Unit 20b: Universal Links Routes And AASA Contract - Implementation
**What**: Expand `DeepLinkRouter`, `DeepLinkURLBuilder`, app route handling, Info.plist/entitlements metadata, web AASA route contract, and validation artifacts.
**Output**: Swift routing updates, web `.well-known`/devtools route updates, and AASA validation docs.
**Acceptance**: Unit 20a tests pass; unknown routes go to safe unknown-link state.

### ⬜ Unit 20c: Universal Links Routes And AASA Contract - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `DeepLinkParityTests`, `project-generator-contract`, `project-contract`, `aasa`, `scenario:surfaces`, `swift-full`, and `warning-scan`; run Web Command Matrix entry `web-focused` with `test/routes/aasa-contract.test.ts`.
**Output**: `apple/unit-20c-links-green.log`, `web/unit-20c-aasa-green.log`, and either `$ARTIFACT_ROOT/aasa-validation.json` or `$ARTIFACT_ROOT/aasa-production-blocker.json`.
**Acceptance**: Production AASA validation is green or blocked only by `$ARTIFACT_ROOT/aasa-production-blocker.json` with `capability: "AASAProductionValidation"` matching the Blocker Artifact Contract.

### ⬜ Unit 21a: Recipe And Cookbook App Entities - Tests
**What**: Write failing Swift tests/static AppIntents checks for recipe and cookbook `AppEntity`, `EntityQuery`, `EntityStringQuery`, display representations, identifiers, disambiguation, transfer values, and cache-backed lookup.
**Output**: `Tests/SpoonjoyCoreTests/RecipeCookbookEntityTests.swift`, initial `scripts/check-app-intents-contract.rb`, AppIntents contract red log `apple/unit-21a-recipe-cookbook-entities-app-intents-contract-red.log`, and `apple/unit-21a-recipe-cookbook-entities-red.log`.
**Acceptance**: Tests fail before recipe/cookbook entities exist and prove string-ID-only recipe/cookbook intents are insufficient.

### ⬜ Unit 21b: Recipe And Cookbook App Entities - Implementation
**What**: Implement recipe and cookbook entity/query/display/transfer types using live cache repositories and guarded AppIntents symbols.
**Output**: Recipe/cookbook entity Swift files and `apple/integration-notes/unit-21b-recipe-cookbook-entities.md` for orchestrator-applied native capability metadata, scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 21a tests pass; recipe/cookbook entities resolve by identifier and search string from live cached data.

### ⬜ Unit 21c: Recipe And Cookbook App Entities - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `RecipeCookbookEntityTests`, `appintents-contract` with `--domain recipe-cookbook`, `scenario:native-metadata`, `swift-full`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21c-recipe-cookbook-entities`.
**Acceptance**: Recipe/cookbook entity contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-recipe-cookbook.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 21d: Shopping App Entities - Tests
**What**: Write failing Swift tests/static AppIntents checks for shopping list and shopping item entities, queries, display representations, transfer values, and cache-backed lookup.
**Output**: `Tests/SpoonjoyCoreTests/ShoppingEntityTests.swift`, AppIntents contract red log `apple/unit-21d-shopping-entities-app-intents-contract-red.log`, and `apple/unit-21d-shopping-entities-red.log`.
**Acceptance**: Tests fail before shopping entities exist and assert offline cached shopping lookup.

### ⬜ Unit 21e: Shopping App Entities - Implementation
**What**: Implement shopping list/item entity/query/display/transfer types using live cache repositories and guarded AppIntents symbols.
**Output**: Shopping entity Swift files and `apple/integration-notes/unit-21e-shopping-entities.md` for orchestrator-applied native capability metadata, scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 21d tests pass; shopping entities resolve from live cached data and expose safe transfer values.

### ⬜ Unit 21f: Shopping App Entities - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `ShoppingEntityTests`, `appintents-contract` with `--domain shopping`, `scenario:native-metadata`, `swift-full`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21f-shopping-entities`.
**Acceptance**: Shopping entity contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-shopping.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 21m: Spoon Cook Log App Entities - Tests
**What**: Write failing Swift tests/static AppIntents checks for spoon/cook-log entities, queries, display representations, transfer values, recipe relationship metadata, and cache-backed lookup.
**Output**: `Tests/SpoonjoyCoreTests/SpoonEntityTests.swift`, AppIntents contract red log `apple/unit-21m-spoon-entities-app-intents-contract-red.log`, and `apple/unit-21m-spoon-entities-red.log`.
**Acceptance**: Tests fail before spoon entities exist and assert cached spoon lookup plus deleted-spoon exclusion.

### ⬜ Unit 21n: Spoon Cook Log App Entities - Implementation
**What**: Implement spoon/cook-log entity/query/display/transfer types using live cache repositories and guarded AppIntents symbols.
**Output**: Spoon entity Swift files and `apple/integration-notes/unit-21n-spoon-entities.md` for orchestrator-applied native capability metadata, scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 21m tests pass; spoon entities resolve from live cached data and expose safe transfer values.

### ⬜ Unit 21o: Spoon Cook Log App Entities - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `SpoonEntityTests`, `appintents-contract` with `--domain spoon`, `scenario:native-metadata`, `swift-full`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21o-spoon-entities`.
**Acceptance**: Spoon entity contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-spoon.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 21p: Capture Draft App Entities - Tests
**What**: Write failing Swift tests/static AppIntents checks for capture draft entities, queries, display representations, transfer values, import-submission relationship metadata, and local-cache lookup.
**Output**: `Tests/SpoonjoyCoreTests/CaptureDraftEntityTests.swift`, AppIntents contract red log `apple/unit-21p-capture-draft-entities-app-intents-contract-red.log`, and `apple/unit-21p-capture-draft-entities-red.log`.
**Acceptance**: Tests fail before capture draft entities exist and assert local/offline capture draft lookup.

### ⬜ Unit 21q: Capture Draft App Entities - Implementation
**What**: Implement capture draft entity/query/display/transfer types using local cache repositories and guarded AppIntents symbols.
**Output**: Capture draft entity Swift files and `apple/integration-notes/unit-21q-capture-draft-entities.md` for orchestrator-applied native capability metadata, scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 21p tests pass; capture draft entities resolve from local/offline data and expose safe transfer values.

### ⬜ Unit 21r: Capture Draft App Entities - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CaptureDraftEntityTests`, `appintents-contract` with `--domain capture-draft`, `scenario:native-metadata`, `swift-full`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21r-capture-draft-entities`.
**Acceptance**: Capture draft entity contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-capture-draft.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 21g: Chef And Profile App Entities - Tests
**What**: Write failing Swift tests/static AppIntents checks for chef/profile entities, profile lookup by username/id, display representation, disambiguation, transfer values, and profile route opening.
**Output**: `Tests/SpoonjoyCoreTests/ChefProfileEntityTests.swift`, AppIntents contract red log `apple/unit-21g-chef-profile-entities-app-intents-contract-red.log`, and `apple/unit-21g-chef-profile-entities-red.log`.
**Acceptance**: Tests fail before chef/profile entities exist and assert no follow/comment/feed semantics are exposed.

### ⬜ Unit 21h: Chef And Profile App Entities - Implementation
**What**: Implement chef/profile entity/query/display/transfer types using cached profile and chef graph data.
**Output**: Chef/profile entity Swift files and `apple/integration-notes/unit-21h-chef-profile-entities.md` for orchestrator-applied native capability metadata, scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 21g tests pass; chef/profile entities open existing profile surfaces only.

### ⬜ Unit 21i: Chef And Profile App Entities - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `ChefProfileEntityTests`, `appintents-contract` with `--domain chef-profile`, `scenario:native-metadata`, `swift-full`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21i-chef-profile-entities`.
**Acceptance**: Chef/profile entity contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-chef-profile.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 21j: Spotlight App Shortcuts And Transfer Integration - Tests
**What**: Write failing Swift tests/static checks for Spotlight documents, indexed identifiers, App Shortcuts provider phrases, entity donations, relevant entities, view annotations, and transfer/value representations across every shipped entity domain.
**Output**: `Tests/SpoonjoyCoreTests/SpotlightShortcutTransferTests.swift`, AppIntents/CoreSpotlight contract red log `apple/unit-21j-spotlight-shortcuts-app-intents-contract-red.log`, and `apple/unit-21j-spotlight-shortcuts-red.log`.
**Acceptance**: Tests fail before Spotlight/App Shortcuts integration uses live cached entities across all domains.

### ⬜ Unit 21k: Spotlight App Shortcuts And Transfer Integration - Implementation
**What**: Implement Spotlight indexing from live cached recipes, cookbooks, shopping items, spoons, chefs, profiles, and capture drafts; add App Shortcuts phrases, donations, relevant entities, and transfer/view annotations with SDK guards.
**Output**: Orchestrator-applied updates to `SpoonjoySpotlightIndexer.swift`, `SpoonjoyAppIntents.swift`, native capability metadata, scenario verifier, and `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-spotlight-shortcuts.json` if SDK symbols are unavailable.
**Acceptance**: Unit 21j tests pass; Spotlight indexes live cached entities, including spoons/cook logs, not fixture-only data.

### ⬜ Unit 21l: Spotlight App Shortcuts And Transfer Integration - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `SpotlightShortcutTransferTests`, `appintents-contract` with `--domain spotlight-shortcuts`, `scenario:native-metadata`, `scenario:final`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-21l-spotlight-shortcuts`.
**Acceptance**: Spotlight/Shortcut/transfer contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-spotlight-shortcuts.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22a: Open Search Share And Cook Siri Intents - Tests
**What**: Write failing Swift tests/static checks for entity-backed open recipe, open cookbook, open profile, search Spoonjoy, share recipe, share cookbook, share shopping list, start cook mode, and continue cook mode intents.
**Output**: `Tests/SpoonjoyCoreTests/OpenSearchShareCookIntentTests.swift`, AppIntents contract red log `apple/unit-22a-open-search-share-cook-intents-app-intents-contract-red.log`, and `apple/unit-22a-open-search-share-cook-intents-red.log`.
**Acceptance**: Tests fail before these intents exist and assert entity-backed parameters, disambiguation, transfer values, and no string-ID-only action paths.

### ⬜ Unit 22b: Open Search Share And Cook Siri Intents - Implementation
**What**: Implement open/search/share/cook intent resolvers, App Intent types, donations, relevant entities, and route/open URL behavior using entity queries and live cache.
**Output**: Intent-family source/resolver updates and `apple/integration-notes/unit-22b-open-search-share-cook-intents.md` for orchestrator-applied scenario verifier, shared App Intents registrar, and project membership updates.
**Acceptance**: Unit 22a tests pass; read/open/share/cook intents do not require destructive confirmations but still honor auth/cache state.

### ⬜ Unit 22c: Open Search Share And Cook Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `OpenSearchShareCookIntentTests`, `appintents-contract` with `--domain open-search-share-cook`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22c-open-search-share-cook-intents`.
**Acceptance**: Open/search/share/cook intent contracts are covered by compiled tests or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-open-search-share-cook.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22d: Shopping Siri Intents - Tests
**What**: Write failing Swift tests/static checks for add shopping item, check shopping item, remove shopping item, clear completed shopping items, and add recipe ingredients to shopping intents.
**Output**: `Tests/SpoonjoyCoreTests/ShoppingIntentTests.swift`, AppIntents contract red log `apple/unit-22d-shopping-intents-app-intents-contract-red.log`, and `apple/unit-22d-shopping-intents-red.log`.
**Acceptance**: Tests fail before shopping intents exist and assert confirmation/auth policy for remove/clear/add-from-recipe actions plus offline queue behavior.

### ⬜ Unit 22e: Shopping Siri Intents - Implementation
**What**: Implement shopping intent resolvers and App Intent types using shopping entities, mutation queue, REST v1 request builders, confirmations, and ownership/auth checks.
**Output**: Shopping intent source/resolver updates, cache/sync integration, and `apple/integration-notes/unit-22e-shopping-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22d tests pass; Siri shopping writes use the same mutation queue and REST contracts as app UI.

### ⬜ Unit 22f: Shopping Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `ShoppingIntentTests`, `appintents-contract` with `--domain shopping-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22f-shopping-intents`.
**Acceptance**: Shopping intent contracts have confirmation/auth evidence for destructive paths and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-shopping-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22g: Recipe Action Siri Intents - Tests
**What**: Write failing Swift tests/static checks for fork recipe, save recipe to cookbook, remove recipe from cookbook, add recipe ingredients to shopping from recipe context, and owner recipe delete intent paths.
**Output**: `Tests/SpoonjoyCoreTests/RecipeActionIntentTests.swift`, AppIntents contract red log `apple/unit-22g-recipe-action-intents-app-intents-contract-red.log`, and `apple/unit-22g-recipe-action-intents-red.log`.
**Acceptance**: Tests fail before recipe action intents exist and assert confirmation/auth/ownership for fork, save/remove, add-to-shopping, and delete actions.

### ⬜ Unit 22h: Recipe Action Siri Intents - Implementation
**What**: Implement recipe action intent resolvers and App Intent types using recipe/cookbook/shopping entities with offline queue and REST v1 contracts.
**Output**: Recipe action intent source/resolver updates, feature-local cache/sync patch notes, and `apple/integration-notes/unit-22h-recipe-action-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22g tests pass; Siri recipe action writes use the same queue and backend contracts as the app UI.

### ⬜ Unit 22i: Recipe Action Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `RecipeActionIntentTests`, `appintents-contract` with `--domain recipe-action`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22i-recipe-action-intents`.
**Acceptance**: Recipe action intent contracts have confirmation/auth evidence and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-recipe-action.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22m: Spoon Cook Log Siri Intents - Tests
**What**: Write failing Swift tests/static checks for log cook, edit cook log, delete cook log, and create cover from spoon intent paths.
**Output**: `Tests/SpoonjoyCoreTests/SpoonIntentTests.swift`, AppIntents contract red log `apple/unit-22m-spoon-intents-app-intents-contract-red.log`, and `apple/unit-22m-spoon-intents-red.log`.
**Acceptance**: Tests fail before spoon intents exist and assert confirmation/auth/ownership for cook-log writes and cover-from-spoon action.

### ⬜ Unit 22n: Spoon Cook Log Siri Intents - Implementation
**What**: Implement spoon/cook-log intent resolvers and App Intent types using spoon and recipe entities with offline queue and REST v1 contracts.
**Output**: Spoon intent source/resolver updates, feature-local cache/sync patch notes, and `apple/integration-notes/unit-22n-spoon-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22m tests pass; Siri spoon writes use the same queue and backend contracts as the app UI.

### ⬜ Unit 22o: Spoon Cook Log Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `SpoonIntentTests`, `appintents-contract` with `--domain spoon-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22o-spoon-intents`.
**Acceptance**: Spoon intent contracts have confirmation/auth evidence and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-spoon-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22p: Capture Import Siri Intents - Tests
**What**: Write failing Swift tests/static checks for create capture draft, submit capture import, open capture draft, and discard capture draft intent paths.
**Output**: `Tests/SpoonjoyCoreTests/CaptureImportIntentTests.swift`, AppIntents contract red log `apple/unit-22p-capture-import-intents-app-intents-contract-red.log`, and `apple/unit-22p-capture-import-intents-red.log`.
**Acceptance**: Tests fail before capture/import intents exist and assert confirmation/auth/offline behavior for import submit and discard actions.

### ⬜ Unit 22q: Capture Import Siri Intents - Implementation
**What**: Implement capture/import intent resolvers and App Intent types using capture draft entities, local/offline storage, and `POST /api/v1/recipes/import`.
**Output**: Capture/import intent source/resolver updates, feature-local cache/sync patch notes, and `apple/integration-notes/unit-22q-capture-import-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22p tests pass; Siri capture import submits through the same backend import contract as app UI.

### ⬜ Unit 22r: Capture Import Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CaptureImportIntentTests`, `appintents-contract` with `--domain capture-import-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22r-capture-import-intents`.
**Acceptance**: Capture/import intent contracts have confirmation/auth evidence and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-capture-import-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22j: Cookbook Siri Intents - Tests
**What**: Write failing Swift tests/static checks for create cookbook, rename cookbook, delete cookbook, add recipe to cookbook, and remove recipe from cookbook intent paths.
**Output**: `Tests/SpoonjoyCoreTests/CookbookIntentTests.swift`, AppIntents contract red log `apple/unit-22j-cookbook-intents-app-intents-contract-red.log`, and `apple/unit-22j-cookbook-intents-red.log`.
**Acceptance**: Tests fail before cookbook intents exist and assert confirmations/auth for cookbook mutations.

### ⬜ Unit 22k: Cookbook Siri Intents - Implementation
**What**: Implement cookbook intent resolvers and App Intent types using cookbook and recipe entities, live cache, REST v1 contracts, and confirmation/auth policy.
**Output**: Cookbook intent source/resolver updates, feature-local cache/sync patch notes, and `apple/integration-notes/unit-22k-cookbook-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22j tests pass; cookbook Siri writes use the same queue/backend contracts as app UI.

### ⬜ Unit 22l: Cookbook Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `CookbookIntentTests`, `appintents-contract` with `--domain cookbook-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22l-cookbook-intents`.
**Acceptance**: Cookbook intent contracts have confirmation/auth evidence and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-cookbook-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22s: Profile And Settings Siri Intents - Tests
**What**: Write failing Swift tests/static checks for profile open, API-token status open, settings open, account connection open, and passkey/password/provider-link secure web handoff intents.
**Output**: `Tests/SpoonjoyCoreTests/ProfileSettingsIntentTests.swift`, AppIntents contract red log `apple/unit-22s-profile-settings-intents-app-intents-contract-red.log`, and `apple/unit-22s-profile-settings-intents-red.log`.
**Acceptance**: Tests fail before profile/settings intents exist and assert exact secure web-auth handoff routes for canonical web auth flows.

### ⬜ Unit 22t: Profile And Settings Siri Intents - Implementation
**What**: Implement profile/settings intent resolvers and App Intent types using profile entities, settings routes, live cache, and secure web handoff URLs.
**Output**: Profile/settings intent source/resolver updates and `apple/integration-notes/unit-22t-profile-settings-intents.md` for orchestrator-applied route, scenario verifier, and shared App Intents registrar updates.
**Acceptance**: Unit 22s tests pass; passkey/password/provider-link actions open exact secure web-auth handoff routes instead of fake native mutations.

### ⬜ Unit 22u: Profile And Settings Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `ProfileSettingsIntentTests`, `appintents-contract` with `--domain profile-settings-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22u-profile-settings-intents`.
**Acceptance**: Profile/settings intent contracts have route/handoff evidence and 100% measured resolver coverage, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-profile-settings-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 22v: Notification Preference Siri Intents - Tests
**What**: Write failing Swift tests/static checks for notification preference read/update intents and APNs status open intent.
**Output**: `Tests/SpoonjoyCoreTests/NotificationIntentTests.swift`, AppIntents contract red log `apple/unit-22v-notification-intents-app-intents-contract-red.log`, and `apple/unit-22v-notification-intents-red.log`.
**Acceptance**: Tests fail before notification intents exist and assert auth/confirmation for preference updates plus APNs blocker display behavior.

### ⬜ Unit 22w: Notification Preference Siri Intents - Implementation
**What**: Implement notification preference intent resolvers and App Intent types using REST v1 preference contracts and APNs capability blocker state.
**Output**: Notification intent source/resolver updates, feature-local cache/sync patch notes, and `apple/integration-notes/unit-22w-notification-intents.md` for orchestrator-applied scenario verifier and shared App Intents registrar updates.
**Acceptance**: Unit 22v tests pass; notification preference writes use the same backend contracts as settings UI and consume the same canonical `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json` capability state.

### ⬜ Unit 22x: Notification Preference Siri Intents - Coverage & Refactor
**What**: Run Validation Command Matrix entries `swift-focused` with `NotificationIntentTests`, `appintents-contract` with `--domain notification-intents`, `scenario:native-metadata`, `swift-full`, `coverage`, `project-contract`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-22x-notification-intents`.
**Acceptance**: Notification intent contracts have confirmation/auth evidence and 100% measured resolver coverage, including `$ARTIFACT_ROOT/apple/apple-developer-program-blocker-apns.json` handling when APNs account/team capability is unavailable, or `$ARTIFACT_ROOT/apple/appintents-sdk-blocker-notification-intents.json` with `capability: "AppIntentsSDK"` matching the Blocker Artifact Contract.

### ⬜ Unit 23a: Native Design Accessibility And Visual Validation - Tests
**What**: Add failing design/accessibility static checks for dynamic type, VoiceOver labels, keyboard navigation, reduce motion, contrast, no text overlap, Spoonjoy Kitchen Table hierarchy, mobile screenshots, and desktop screenshots; checks must use or extend Validation Command Matrix entries `design-contract`, `screenshots`, and `design-review`.
**Output**: Design validator updates and `apple/unit-23a-design-red.log`.
**Acceptance**: Checks fail until every new surface reports the required accessibility/design manifest coverage.

### ⬜ Unit 23b: Native Design Accessibility And Visual Validation - Implementation
**What**: Orchestrator-only: update native views/components/styles to satisfy design/accessibility checks, regenerate project, run `screenshots`, and produce `design-review.json`.
**Output**: UI polish changes, screenshot artifacts, design review manifest, and updated native design docs.
**Acceptance**: Unit 23a checks pass; screenshots show native controls with Spoonjoy design language and no incoherent overlap.

### ⬜ Unit 23c: Native Design Accessibility And Visual Validation - Coverage & Refactor
**What**: Orchestrator-only: run Validation Command Matrix entries `design-contract`, `screenshots`, `design-review`, `scenario:final`, `project-contract`, `swift-full`, `xcodebuild-ios`, `xcodebuild-macos`, `smoke-ios`, `smoke-macos`, and `warning-scan`.
**Output**: Validation Command Matrix artifacts for `unit-23c-design`.
**Acceptance**: Design/accessibility validation is green or blocked only by `CoreSimulator`, `XcodePlatform`, or `MacOSLaunch` JSON matching the Blocker Artifact Contract.

### ⬜ Unit 24a: API Documentation And Native Dogfood Guide - Tests
**What**: Write failing docs tests for native quickstart, OAuth universal-link callback, Keychain persistence, token refresh, endpoint examples, DELETE idempotency guidance, scope defaults, REST vs MCP token rules, and SDK/OpenAPI profiles.
**Output**: Docs test changes and `web/unit-24a-docs-red.log`.
**Acceptance**: Tests fail before docs are updated and catch the documented drifts from the API audit.

### ⬜ Unit 24b: API Documentation And Native Dogfood Guide - Implementation
**What**: Update `docs/api.md`, developer routes, generated playground/profile docs, OpenAPI examples, and native repo docs to describe the exact contracts dogfooded by Spoonjoy Apple.
**Output**: Docs, generated playground output, and native dogfood guide references.
**Acceptance**: Unit 24a docs tests pass; docs state `spoonjoy.app`, HTTPS OAuth redirect, persisted `client_id`, token storage, refresh, DELETE idempotency options, and REST/MCP resource-token boundaries.

### ⬜ Unit 24c: API Documentation And Native Dogfood Guide - Coverage & Refactor
**What**: Run Web Command Matrix entries `web-docs-drift`, `web-route-coverage`, `web-playground-generate`, `web-typecheck`, `web-build`, and `web-warning-scan`.
**Output**: Web Command Matrix artifacts for `unit-24c-docs`.
**Acceptance**: Docs/build/typecheck are green with zero warnings.

### ⬜ Unit 25a: Web Full Validation - Tests
**What**: Run targeted red/green evidence audit for all web tests created in Units 1-10f and 24, ensuring artifacts exist for red and green phases and no touched endpoint lacks a matching test file.
**Output**: `web/unit-25a-validation-audit.log`.
**Acceptance**: Audit fails until every touched route/lib/doc contract has red and green artifacts in the task artifact directory.

### ⬜ Unit 25b: Web Full Validation - Implementation
**What**: Run Web Command Matrix entries `web-playground-generate`, `web-focused` with every touched API/docs test file from Units 1-10f and 24, `web-coverage-full`, `web-typecheck`, `web-build`, and `web-warning-scan`; fix any failures with tests-first sub-units.
**Output**: Web Command Matrix artifacts for `unit-25b-web-full-validation`.
**Acceptance**: All web commands pass with zero warnings; coverage meets repo policy; no generated drift remains.

### ⬜ Unit 25c: Web Full Validation - Coverage & Refactor
**What**: Run harsh API contract reviewer and docs reviewer against the final web diff and validation artifacts.
**Output**: `web/api-contract-review.md`, `web/docs-review.md`, and final web validation summary.
**Acceptance**: Reviewers converge with no BLOCKER/MAJOR findings; any MINOR/NIT disposition is recorded in the doing progress log.

### ⬜ Unit 26a: Native Full Validation - Tests
**What**: Run native validation audit proving artifacts exist for Swift red/green phases, `coverage`, `appintents-contract`, `scenario:*`, app bundle builds, `screenshots`, design review, AASA validation/blocker, macOS smoke, and iOS simulator smoke.
**Output**: `apple/unit-26a-validation-audit.log`.
**Acceptance**: Audit fails until every native unit has red/green evidence and final validation prerequisites are present.

### ⬜ Unit 26b: Native Full Validation - Implementation
**What**: Run Validation Command Matrix entry `native-final-matrix`; if any matrix step fails, fix it with tests-first sub-units. If the only failure is that `validate-native-local.sh` rejects a JSON blocker capability allowed by the Blocker Artifact Contract, first add tests for that blocker-capability acceptance, update `validate-native-local.sh`, then rerun `native-final-matrix`.
**Output**: Native full validation matrix and command logs under `apple/` and the task artifact root.
**Acceptance**: All native commands pass or produce JSON matching the Blocker Artifact Contract with capability limited to `XcodePlatform`, `CoreSimulator`, `MacOSLaunch`, `AASAProductionValidation`, `AppIntentsSDK`, `AppleDeveloperProgram`, or `ProviderSecret`; `AppleDeveloperProgram` and `ProviderSecret` blockers use only the canonical paths named in the Blocker Artifact Contract.

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
- Task artifact logs, blocker JSON, review markdown, and integration notes under `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-doing-siri-full-access-parity/` are committed only in `spoonjoy-apple`. For a web unit that changes `spoonjoy-v2`, commit and push the `spoonjoy-v2` source/test/docs/generated changes first, then commit and push the corresponding artifact-root logs or integration notes in `spoonjoy-apple`. For validation-only web units with no `spoonjoy-v2` source changes, commit only the `spoonjoy-apple` artifacts. Generated files physically located in `spoonjoy-v2`, such as `app/lib/generated/api-v1-playground.ts`, are committed in `spoonjoy-v2` before their `spoonjoy-apple` logs.
- Spawn implementor sub-agents for disjoint write scopes within each dependency wave; the orchestrator reviews, integrates, and owns commits.
- Spawn harsh reviewer sub-agents after every unit before marking it done. Tests-only red units may use a focused test-quality reviewer; implementation, coverage/refactor, validation, design, docs, App Intents, offline/sync, API contract, and merge units require harsh domain reviewers with no BLOCKER/MAJOR findings before completion.
- Treat only credentials, paid Apple Developer Program enrollment, production secrets, unavailable local hardware/runtime, unavailable SDK symbols, and destructive production operations without a staged path as human-only blockers.
- Run web commands from `/Users/arimendelow/Projects/spoonjoy-v2`; run native commands from `/Users/arimendelow/Projects/spoonjoy-apple`.
- Use `pnpm run test:coverage`, `pnpm run typecheck`, and `pnpm run build` for final web validation.
- Use `scripts/validate-native-local.sh --artifact-root tasks/2026-06-16-1754-doing-siri-full-access-parity` for final native validation after focused Swift and app checks are green.
- Do not invent comments, recipe threads, social feeds, generic reactions/likes, meal planning, nutrition/fitness, pantry inventory, or media-library surfaces during implementation.

## Progress Log

- 2026-06-16 18:23 Created from planning doc.
- 2026-06-16 18:33 Addressed granularity review findings by adding recipe import API units, splitting native surface/App Intents units, and adding dependency wave ownership.
- 2026-06-16 18:38 Granularity pass converged after Round 3.
- 2026-06-16 18:49 Addressed source-validation finding by replacing the bare native coverage script command with the required argument form.
- 2026-06-16 18:57 Addressed ambiguity review findings by adding a native validation command matrix, making spawned-worker shared-path patch-note ownership explicit, and choosing a dedicated `NativePushDevice` APNs storage migration.
- 2026-06-16 19:04 Addressed ambiguity review findings by making warning scans log-discovery based, adding native app build/smoke matrix commands, adding a web command matrix, and defining backend shared-file integration notes.
- 2026-06-16 19:08 Addressed ambiguity review findings by adding macOS build/smoke blocker policy, routing AASA web validation through `web-focused`, and adding a `design-review` matrix entry.
- 2026-06-16 19:13 Addressed ambiguity review findings by adding a Blocker Artifact Contract, defining AASA/AppIntents/macOS blocker producers and consumers, and aligning Unit 23c/26b acceptance with that contract.
- 2026-06-16 19:20 Addressed ambiguity review findings by canonicalizing App Intents SDK blocker filenames and making matrix artifact names authoritative for validation outputs.
- 2026-06-16 19:27 Addressed ambiguity review findings by forcing Wave 4 execution order, requiring exported `ARTIFACT_ROOT`, and canonicalizing Apple Developer Program/provider-secret blocker paths across producers and consumers.
- 2026-06-16 19:34 Addressed ambiguity review findings by marking the doing doc executable with reviewer gates, adding exact worker write-scope contracts, defining matrix slug rules, completing Xcode/CoreSimulator blocker contracts, and fixing cross-repo artifact commit ownership.
