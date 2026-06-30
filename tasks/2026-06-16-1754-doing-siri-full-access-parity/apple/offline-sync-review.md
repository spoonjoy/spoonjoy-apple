# Offline Sync Review

Verdict: CONVERGED after reviewer-fix re-review

## Final Resolution
- Queued cover regenerate/from-spoon sync now classifies ProviderSecret blocker envelopes/errors before queue deletion, preserving the blocked action instead of treating it as success.
- Drained cache patches now carry optimistic/local revision semantics so remote success cannot be mistaken for server-canonical normalized cache state.
- Evidence refreshed in `unit-26c-review-fixes-green-focused.log`, `unit-26c-review-fixes-green-affected.log`, `unit-26c-coverage-repair-coverage-test.log`, `unit-26c-coverage-repair-enforce.log`, `unit-26c-reviewer-major-fixes-affected.log`, and `unit-26c-reviewer-major-fixes-full-swift-2.log`.
- Feynman re-reviewed the offline sync/cache changes and returned `CONVERGED`.

## Original Findings
- BLOCKER Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift:3782 - Provider-generated cover mutations are not blocker-aware in queued sync. `URLSessionNativeSyncTransport.send` only special-cases `.recipeImportSubmit`; `.coverRegenerate` and `.coverFromSpoon` fall through to generic `JSONValue` success at line 3790, while ProviderSecret API errors fall through generic retry/conflict/throw handling at lines 3811-3832. The cover planner always creates offline fallback/queued mutations for regenerate/from-spoon (`Sources/SpoonjoyCore/Features/Covers/RecipeCoverControlsViewModel.swift:112`, `:147`) even though the contract says provider-secret-blocked cover generation is online-only and blockers must not drain as success. Fix: make cover regenerate/from-spoon responses and API errors classify ProviderSecret before queue deletion, return `.blocked(.providerSecret(resourceID: "recipe-covers"))`, keep the queued mutation visible, persist/display the blocker like import blockers, use `NativeOfflineAction.providerSecretBlockedCoverRegeneration` when a known blocker exists, and add sync tests for 2xx blocker envelopes plus 400/409 ProviderSecret errors.
- MAJOR Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift:4054 - Remote-success cache state is persisted from optimistic local patches instead of a server-canonical refresh. After draining remote mutations, the engine builds recipe/shopping/cookbook cache patches from `drainedMutations` and saves them at lines 4091-4097; the patch helpers derive records via `applyingOptimistic*` from the pre-drain snapshot and mutation timestamps (`:4325`, `:4357`, `:4404`). That violates the contract requirement to refresh/bootstrap from server-canonical state after remote success and risks stale normalized fields, revisions, and derived shopping/cookbook membership surviving as confirmed cache. Fix: after any drained remote mutation, refresh the touched domains or run a post-drain sync bootstrap before persisting visible cache, or require typed mutation responses with canonical records/revisions and prove server-returned data wins over local optimistic data in tests.

## Offline Contract Coverage
- Auth/profile/settings/account: satisfied; profile/photo/notification prefs are queueable, while token create/revoke, OAuth disconnect, logout/session revoke, passkey/password/provider link, APNs permission, and device-token acquisition are online-only.
- Recipe/cookbook/chef graph/search: finding; queueing, owner checks, App Entity scoping, tombstones, and remaps are present, but post-drain cache canonicalization is not.
- Cook mode/shopping: finding; durable shopping mutations and dependency FIFO are present, but successful shopping/cookbook drains persist optimistic cache patches instead of refreshed server state.
- Spoons/covers/capture/import: finding; capture import blockers/drafts are retained, but queued cover regenerate/from-spoon does not canonicalize ProviderSecret blockers before success/deletion.
- App Intents/Spotlight/sharing: satisfied with inherited cover finding; catalogs scope private identifiers by account/environment and mutable intents use owner checks and the native queue.
- Cache/privacy/freshness/dismissal: satisfied; durable cache records carry account/environment/schema/fetched/source/revision metadata, secret material is rejected, stale/offline dismissal is informational-only, and severe states stay visible.
- Validation/blocker artifacts: satisfied for artifact canon; matrix records XcodePlatform, AppleDeveloperProgram, and ProviderSecret blockers as canonical blockers rather than success.

## Evidence Read
- `nl -ba tasks/2026-06-16-1754-doing-siri-full-access-parity.md` for Offline Product Contract, Units 11-26, and validation/blocker artifact rules.
- `nl -ba`/`rg` over `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`, `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`, `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`, cover/settings/notification/cache view models, and `Sources/SpoonjoyCore/Native/*EntityCatalog.swift`.
- `nl -ba`/`rg` over `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift`, `NativeSyncEngineTests.swift`, `CoverControlSurfaceTests.swift`, and shopping/recipe/spoon/capture/cookbook/profile/notification intent/entity tests.
- `jq`/`find` over `tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/validation-matrix.json`, `validation-audit-manifest.json`, `matrix-final-report.json`, and canonical blocker artifacts.
