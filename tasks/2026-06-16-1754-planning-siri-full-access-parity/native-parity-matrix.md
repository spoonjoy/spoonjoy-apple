# Spoonjoy Native Parity Matrix

Date: 2026-06-16

This matrix compares the current `spoonjoy-apple` implementation to the audited web/API product model.

Status legend: Complete, Partial, Missing, Native-plus, Blocked.

| Product concept | Web/API status | Native status | Required work |
| --- | --- | --- | --- |
| App shell and navigation | Web routes cover kitchen, recipes, cookbooks, shopping, search, account, profiles, API/docs. | Partial. Native SwiftUI shell has first-run setup, sidebar/detail navigation, deep links, global search, share toolbar. | Keep shell; add live data/auth/bootstrap and missing profile/account/developer routes or handoffs. |
| Universal links and URL scheme | `spoonjoy.app` is canonical domain. | Partial. Entitlements declare `applinks:spoonjoy.app`; Info.plist has `spoonjoy://`; router covers core paths. | Validate AASA when Developer Program/team id exists; expand routes for profiles/account/cookbook actions as needed. |
| Public recipe catalog | REST v1 supports list/detail. Web supports browse/detail. | Partial. Native has request builders and fixtures; screens are fixture-backed. | Add URLSession transport, cache, live catalog loading, offline stale/fresh state. |
| Recipe detail read | Web shows cover/provenance, chef, servings, steps, ingredients, dependencies, spoons, cookbook saves, owner tools. | Partial. Native shows fixture recipe detail and basic actions. | Add live detail cache, spoons, dependencies, cover history metadata, save/add/fork/log actions. |
| Cook mode | Web has cook hash mode, active step, scale, ingredient and step-output checkoff, local progress. | Partial. Native has focused cook mode and persisted progress, but lacks scale and step-output dependencies. | Add scale factor, dependency checkoff, timers where data supports it, offline persistence, Siri continue/start. |
| Recipe create/edit/delete | Web supports creation, editing, image upload, step/ingredient/dependency editing, soft delete. REST v1 missing. | Missing. Native has local capture draft only. | Add REST v1 endpoints and native editor flows or staged native forms for full parity. |
| Recipe fork | Web supports fork and notification. REST v1 missing. | Missing. | Add REST v1 fork endpoint, native action, Siri intent with confirmation where needed. |
| Recipe covers/images | Web supports upload, AI placeholder, spoon covers, cover set/remove/regenerate/archive. REST v1 missing. | Missing/partial. Native displays cover images from fixture/API models. | Add API endpoints and native owner cover controls; photo upload requires backend contract. |
| Spoons / cook logs | Web supports create/delete/list, profile recent cooks, cover-from-spoon. REST v1 missing. | Missing. | Add REST v1 spoon endpoints and native log-cook UI/Siri intent; support photo/note/next-time/cooked-at and offline drafts where possible. |
| Cookbooks read | REST v1 supports public list/detail. Web supports detail/share. | Partial. Native shelf/list exists; detail is placeholder. | Add live data/cache and real detail view with recipe contents/share. |
| Cookbook writes | Web supports create/rename/delete/add/remove. REST v1 missing. | Missing. | Add REST v1 cookbook write endpoints and native forms/actions with idempotency where applicable. |
| Shopping list read/sync | REST v1 supports read and sync. Web supports private shopping UI. | Partial. Native has request builders, fixture state, and checkoff UI. | Add live sync, offline cache, tombstone handling, sync checkpoint, conflict handling. |
| Shopping list mutations | REST v1 supports add/check/delete. Web also supports add-from-recipe, clear completed/all. | Partial. Native only exposes checkoff and local add via Siri. | Add native add/remove/clear/add-from-recipe UI; add missing REST endpoints or native client flows for clear/add-from-recipe. |
| Search | Web scopes all/recipes/cookbooks/chefs/shopping. | Partial. Native has local fixture search and global `.searchable`. | Add live/cache-backed search, route search links, Siri entity query support. |
| Profiles | Web profiles show recipes, cookbooks, spoons, fellow chefs, visitors. | Missing. | Add native profile surfaces or universal-link handoff; add API support if native rendering is desired. |
| Fellow chefs / kitchen visitors | Web derives from spoons/forks/saves. | Missing. | Add API read endpoints and native profile sections if full native rendering is in scope. |
| Account settings | Web manages profile, photo, OAuth providers, passkeys, password, API credentials, OAuth app connections, notifications. | Partial/missing. Native settings only shows auth/environment/offline status. | Add native OAuth sign-in, Keychain token vault, connection status, notification settings; destructive auth-management can hand off to web unless API exists. |
| OAuth/native auth | Web supports OAuth/PKCE and delegated approval. | Partial. Native has OAuth request builders, PKCE, redirect validation, in-memory token vault, no live flow/transport. | Add ASWebAuthenticationSession universal-link callback, Keychain vault, refresh coordinator integration, logout/revoke. |
| Push notifications | Web push subscriptions/preferences exist. | Blocked for production APNs without paid Developer Program. | Implement preference UI/API where possible; document APNs/account blocker honestly. |
| Developer API/docs | Web has docs/playground/OpenAPI/MCP. | Missing, probably not native primary UI. | Update docs for native dogfood. Native can link to docs rather than embed playground. |
| Capture/import | Server/tool code exists; no web route; REST v1 excludes recipe import/write. | Partial/native-plus. Native local capture draft exists. | Add offline capture drafts, share-sheet/camera/URL intake, and backend import endpoint only when contract exists in this task. |
| Offline usage | Web has local cook progress and PWA affordances, not full offline sync. | Partial. Native has `NativeAppSnapshot`, offline state, mutation queue, and local fixtures. | Make offline first-class: cache recipes/cookbooks/shopping/profile, dismissible status/freshness indicator, queued safe mutations, retry/reconcile, visible conflict/error state. |
| Spotlight | Web not applicable. | Native-plus partial. Recipes, cookbooks, shopping items indexed from fixtures/snapshot. | Index live cached entities, include spoons when implemented, route entity IDs safely. |
| App Intents/Siri | Web not applicable; user wants full Siri access to current product model. | Partial. Four string-parameter intents exist. | Add AppEntity/query/indexed entities, App Shortcuts, entity-backed intents, confirmations/auth policy, donations, transfer/share representations, tests/guards. |
| Sharing | Web supports native share/clipboard and public URLs. | Partial. Native has ShareLink toolbar for current routes. | Make recipe/cookbook/shopping sharing first-class via ShareLink, App Intents handoff, Messages/Mail/share sheet destinations, without adopting messaging/mail schemas. |

## Current Native Foundation To Keep

- SwiftUI iOS/macOS app targets share `SpoonjoyRootView`.
- `DeepLinkRouter` covers core `spoonjoy.app` and `spoonjoy://` paths.
- `NativeAppSnapshot`, `MutationQueue`, cook progress, capture draft, and shopping state provide a good offline base.
- Scenario verifier, project generator contracts, and coverage enforcement should be extended rather than replaced.

## Product Lines Not To Invent

- No recipe comments or threads.
- No social feed.
- No generic reactions/likes.
- No meal planning/nutrition/fitness yet.
- No pantry inventory.
- No media library.
