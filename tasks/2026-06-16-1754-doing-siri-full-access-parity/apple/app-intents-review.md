# App Intents Review

Verdict: CONVERGED after reviewer-fix re-review

## Final Resolution
- Spotlight and private App Entity identifiers now include schema, account, and environment scope.
- Recipe/cookbook App Entity direct lookup now requires scoped identifiers and rejects raw resource IDs.
- `SpotlightIndexPlan.route(uniqueIdentifier:scope:)` requires the active schema/account/environment prefix, and `SpoonjoyRootView.applySpotlightIdentifier` fails closed when the live store has no active Spotlight scope.
- Recipe/cookbook Spotlight purge plans are wired for logout, account switch, cache delete, and tombstone paths.
- Evidence refreshed in `unit-26c-reviewer-major-fixes-focused.log`, `unit-26c-spotlight-optional-scope-focused.log`, `unit-26c-reviewer-major-fixes-affected.log`, `unit-26c-reviewer-major-fixes-full-swift-2.log`, `unit-26c-reviewer-major-fixes-coverage-enforce.log`, and `unit-26c-reviewer-major-fixes-validate-native-local.log`.
- Chandrasekhar's findings were fixed, Herschel's optional-scope blocker was fixed, and Mencius returned `CONVERGED` on the fresh App Intents/privacy re-review.

## Original Findings
- BLOCKER, Apps/Spoonjoy/Shared/Native/SpoonjoyRecipeCookbookEntities.swift:18: Recipe and cookbook AppEntity IDs expose raw resource IDs, and Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift:2058 has no logout/account-switch purge for recipe or cookbook Spotlight domains. `replaceAll(.empty)` can only delete the signed-out scope, so prior-account recipe/cookbook CSSearchable rows and related donations can survive logout/account switch, cache deletion, or tombstones. Fix: make recipe/cookbook AppEntity identifiers account/environment/schema scoped, resolve them through scoped query parsing, add a recipe/cookbook purge plan for account-scope, cache-delete, and tombstone cases, wire it through NativeSyncEngine, NativeLiveAppStore, SpoonjoyRootView, and SpoonjoySpotlightIndexer, and add logout/account-switch/cache-delete/tombstone regression tests.
- MAJOR, Sources/SpoonjoyCore/Native/SpotlightIndexPlan.swift:54: SpotlightIndexScope is account/environment scoped but not schema scoped; private AppEntity ID builders follow the same pattern in Sources/SpoonjoyCore/Native/ShoppingEntityCatalog.swift:398, Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift:352, Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift:430, and Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift:262. A cache/entity schema change can leave incompatible private Spotlight and App Entity rows addressable under stable old identifiers/domains. Fix: carry an entity/cache schema version through SpotlightIndexScope and each private AppEntity identifier, purge old-schema domains/IDs on migration or cache recovery, and add schema-bump stale-index tests.

## Domain Coverage
- Recipes/cookbooks: Broad entity-backed open/share/cook/fork/save/create/rename/delete/add/remove coverage, blocked by raw IDs and missing stale-index purge.
- Shopping: Entity-backed list/item actions cover add/check/remove/bulk/clear/share with destructive confirmations and purge coverage, but schema is missing from private IDs.
- Spoons/cook logs: Spoon entity and cook-log create/edit/delete/cover actions are present with owner checks and confirmations, but schema is missing from private IDs.
- Capture/import: Capture, submit/open/discard draft, and import-review flows are entity-backed with discard confirmation and account purge coverage, but schema is missing from private IDs.
- Profiles/settings: Profile, settings, notification preferences, tokens, connections, passkeys, password, provider, logout, and session actions are represented without invented social/comment/mail surfaces, but schema is missing from private IDs.
- Notifications/APNs status: Preference read/update and APNs status opening are exposed; delivery blocker remains an external owner-action artifact, not an invented intent surface.
- Search/share/open/cook and routing: Search, share, open, and cook shortcuts are entity-backed; Universal Links for spoonjoy.app and custom scheme routing stay distinct.

## Evidence Read
- Inspected `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`, `Spoonjoy*Entities.swift`, and `SpoonjoySpotlightIndexer.swift`.
- Inspected `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`, `*EntityCatalog.swift`, `SpotlightIndexPlan.swift`, and `NativeCapabilityMetadata.swift`.
- Inspected relevant `Tests/SpoonjoyCoreTests/*IntentTests.swift`, `*EntityTests.swift`, `SpotlightShortcutTransferTests.swift`, deep-link tests, and purge/Spotlight transfer tests.
- Inspected `scripts/check-app-intents-contract.rb`, `tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/matrix-appintents-*.log`, and `validation-matrix.json`.
- Reran `ruby scripts/check-app-intents-contract.rb --domain ...` for all 14 App Intents domains; all current contract checks passed.
