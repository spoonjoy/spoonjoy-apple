# Spoonjoy Native Parity Matrix

Date: 2026-06-16

This matrix compares the current `spoonjoy-apple` implementation to the audited web/API product model.

Status legend: Complete, Partial, Missing, Native-plus, Blocked.

| Product concept | Web/API status | Native status | Required work |
| --- | --- | --- | --- |
| App shell and navigation | Web routes cover kitchen, recipes, cookbooks, shopping, search, account, profiles, API/docs. | Partial. Native SwiftUI shell has first-run setup, sidebar/detail navigation, deep links, global search, share toolbar. | Keep shell; add live data/auth/bootstrap and missing profile/account/developer routes or handoffs. |
| AASA / universal links for real web routes | `spoonjoy.app` is canonical domain; `app/routes.ts` has concrete routes for recipes, cookbooks, private shopping list UI, search, profiles, fellow chefs, kitchen visitors, account settings, auth/agent handoffs, API/docs, platform assets, and well-known files. Shopping-list routes are private deep links only, with no public share URL and no `publicShareable` classification. | Partial. Entitlements declare `applinks:spoonjoy.app`; router covers core paths. | Validate AASA when Developer Program/team id exists; generate a module-aware route manifest from `app/routes.ts`; add native handling or secure web handoff only for real web route modules such as private shopping list UI, profiles, fellow chefs, kitchen visitors, account settings, auth/agent/API/docs handoffs, and platform/well-known files; do not turn private routes into public share links. |
| Custom URL scheme native actions | No web route for native-only actions such as spoon logging sheets, cover controls, notification/API-credential subpanels, cookbook add/remove commands, shopping add-from-recipe/clear commands, capture/import drafts, or cook-mode continuation actions. | Partial. Info.plist has `spoonjoy://`; router covers some native action paths. | Keep these as `spoonjoy://` custom-scheme-only native actions with Swift route tests; do not AASA-claim or build public `spoonjoy.app` URLs for them unless real web routes and tests are added first. |
| Public recipe catalog | REST v1 supports list/detail. Web supports browse/detail. | Partial. Native has request builders and fixtures; screens are fixture-backed. | Add URLSession transport, cache, live catalog loading, offline stale/fresh state. |
| Recipe detail read | Web shows cover/provenance, chef, servings, steps, ingredients, dependencies, spoons, cookbook saves, owner tools. | Partial. Native shows fixture recipe detail and basic actions. | Add live detail cache, spoons, dependencies, cover history metadata, save/add/fork/log actions. |
| Cook mode | Web has cook hash mode, active step, scale, ingredient and step-output checkoff, local progress. | Partial. Native has focused cook mode and persisted progress, but lacks scale and step-output dependencies. | Add scale factor, dependency checkoff, duration timers for steps with duration data, offline persistence, Siri continue/start. |
| Recipe create/edit/delete | Web supports creation, editing, image upload, step/ingredient/dependency editing, soft delete. REST v1 missing. | Missing. Native has local capture draft only. | Add REST v1 endpoints and native editor flows or staged native forms for full parity. |
| Recipe fork | Web supports fork and notification. REST v1 missing. | Missing. | Add REST v1 fork endpoint, native action, Siri intent, ownership checks, and confirmation for Siri-triggered fork creation. |
| Recipe covers/images | Web supports upload, AI placeholder, spoon covers, cover set/remove/regenerate/archive. REST v1 missing. | Missing/partial. Native displays cover images from fixture/API models. | Add REST v1 image/cover endpoints and native owner cover controls for upload, cover history, set/remove/regenerate/archive, and cover-from-spoon. |
| Spoons / cook logs | Web supports create/delete/list, profile recent cooks, cover-from-spoon. REST v1 missing. | Missing. | Add REST v1 spoon endpoints and native log-cook UI/Siri intent; support photo/note/next-time/cooked-at and durable offline drafts. |
| Cookbooks read | REST v1 supports public list/detail. Web supports detail/share. | Partial. Native shelf/list exists; detail is placeholder. | Add live data/cache and real detail view with recipe contents/share. |
| Cookbook writes | Web supports create/rename/delete/add/remove. REST v1 missing. | Missing. | Add REST v1 cookbook write endpoints and native forms/actions with `clientMutationId` idempotency for create, rename, delete, add recipe, and remove recipe. |
| Shopping list read/sync | REST v1 supports read and sync. Web supports private shopping UI. | Partial. Native has request builders, fixture state, and checkoff UI. | Add live sync, offline cache, tombstone handling, sync checkpoint, conflict handling. |
| Shopping list mutations | REST v1 supports add/check/delete. Web also supports add-from-recipe, clear completed/all. | Partial. Native only exposes checkoff and local add via Siri. | Add REST v1 clear completed, clear all, and add-from-recipe endpoints; add native add/remove/clear/add-from-recipe UI backed by those endpoints and offline queued mutations. |
| Search | Web scopes all/recipes/cookbooks/chefs/shopping. | Partial. Native has local fixture search and global `.searchable`. | Add live/cache-backed search, route search links, Siri entity query support. |
| Profiles | Web profiles show recipes, cookbooks, spoons, fellow chefs, visitors. | Missing. | Add REST v1 profile/chef-graph read endpoints and native profile surfaces for recipes, cookbooks, spoons, fellow chefs, and kitchen visitors. |
| Fellow chefs / kitchen visitors | Web derives from spoons/forks/saves. | Missing. | Add REST v1 fellow-chef and kitchen-visitor read endpoints and native profile sections backed by the live cache. |
| Account settings | Web manages profile, photo, OAuth providers, passkeys, password, API credentials, OAuth app connections, notifications. | Partial/missing. Native settings only shows auth/environment/offline status. | Add native OAuth sign-in, Keychain token vault, profile/photo editing, `GET/POST /api/v1/tokens`, `DELETE /api/v1/tokens/{credentialId}`, OAuth app connection status/disconnect, notification settings, and exact secure web-auth handoff routes for passkey/password/provider-link actions that remain canonical web flows. |
| OAuth/native auth | Web supports OAuth/PKCE and delegated approval. | Partial. Native has OAuth request builders, PKCE, redirect validation, in-memory token vault, no live flow/transport. | Add ASWebAuthenticationSession universal-link callback, Keychain vault, refresh coordinator integration, logout/revoke. |
| Push notifications | Web push subscriptions/preferences exist. | Blocked for production APNs delivery without paid Developer Program. | Add native notification preference UI, REST v1 preference APIs, APNs device registration/revocation contracts, compile/static local checks, and production APNs blocker artifact until Team ID/signing exists. |
| Developer API/docs | Web has docs/playground/OpenAPI/MCP. | Missing. | Update docs/OpenAPI/playground for native dogfood and add native settings access to API credential status, revoke actions, and external docs links. |
| Capture/import | Server/tool code exists; no web route; REST v1 excludes recipe import/write. | Partial/native-plus. Native local capture draft exists. | Add offline capture drafts, share-sheet/camera/URL intake, and REST v1 import/capture submission in this task. |
| Offline usage | Web has local cook progress and PWA affordances, not full offline sync. | Partial. Native has `NativeAppSnapshot`, offline state, mutation queue, and local fixtures. | Make offline first-class: cache recipes/cookbooks/shopping/profile, dismissible status/freshness indicator, queued safe mutations, retry/reconcile, visible conflict/error state. |
| Spotlight | Web not applicable. | Native-plus partial. Recipes, cookbooks, shopping items indexed from fixtures/snapshot. | Index live cached recipes, cookbooks, shopping items, spoons/cook logs, chefs, profiles, and capture drafts; route entity IDs safely. |
| App Intents/Siri | Web not applicable; user wants full Siri access to current product model. | Partial. Four string-parameter intents exist. | Add AppEntity/query/indexed entities, App Shortcuts, entity-backed intents, confirmations/auth policy, donations, transfer/share representations, tests/guards. |
| Sharing | Web supports native share/clipboard and public URLs for routed public objects; shopping is owner-private. | Partial. Native has ShareLink toolbar for current routes. | Make recipe/cookbook public URL sharing first-class via ShareLink/App Intents/share sheet destinations; make shopping sharing private transfer/export only unless a real public route and tests are added; do not adopt messaging/mail schemas. |

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
