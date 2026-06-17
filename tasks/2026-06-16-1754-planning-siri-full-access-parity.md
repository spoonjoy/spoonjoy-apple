# Goal

**Status**: approved

Bring Spoonjoy Apple to real native parity with the audited Spoonjoy web product model, then expose that current product model to Siri/App Intents as fully as Apple platform capabilities allow.

This is not a thin web clone and not a new social/product expansion. The native app must use live Spoonjoy contracts, work intelligently offline, open `spoonjoy.app` links in the correct native place, and make Siri/Spotlight/share-sheet access a first-class way to use existing Spoonjoy recipes, cookbooks, shopping, cook mode, cook logs, capture drafts, and account/session state.

# Scope

## In Scope

- Treat the committed audits as source-of-truth for implementation:
  - `tasks/2026-06-16-1754-planning-siri-full-access-parity/web-product-surface-audit.md`
  - `tasks/2026-06-16-1754-planning-siri-full-access-parity/api-native-dogfood-audit.md`
  - `tasks/2026-06-16-1754-planning-siri-full-access-parity/native-parity-matrix.md`
- Implement a live native API client, transport, auth/session, token refresh, Keychain-backed storage, cache bootstrap, and sync pipeline. Current request builders and fixture-backed screens are not enough.
- Add the REST v1 backend endpoints needed for native parity rather than relying on app-only legacy `/api/*` routes:
  - Native bootstrap/session/account/API credentials: `GET /api/v1/me`, `PATCH /api/v1/me`, `GET /api/v1/me/kitchen`, `GET /api/v1/me/sync`, `GET /api/v1/me/notification-preferences`, `PATCH /api/v1/me/notification-preferences`, `POST /api/v1/me/apns-devices`, `DELETE /api/v1/me/apns-devices/{deviceId}`, `GET /api/v1/me/connections`, `DELETE /api/v1/me/connections/{connectionId}`, `GET /api/v1/tokens`, `POST /api/v1/tokens`, and `DELETE /api/v1/tokens/{credentialId}`.
  - Profile and chef graph reads: `GET /api/v1/users/{identifier}`, `GET /api/v1/users/{identifier}/fellow-chefs`, and `GET /api/v1/users/{identifier}/kitchen-visitors`.
  - Search: `GET /api/v1/search` with `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list` scopes.
  - Recipe writes: `POST /api/v1/recipes`, `PATCH /api/v1/recipes/{id}`, `DELETE /api/v1/recipes/{id}`, `POST /api/v1/recipes/{id}/fork`, `POST /api/v1/recipes/import`, `POST /api/v1/recipes/{id}/steps`, `PATCH /api/v1/recipes/{id}/steps/{stepId}`, `DELETE /api/v1/recipes/{id}/steps/{stepId}`, `POST /api/v1/recipes/{id}/steps/reorder`, `POST /api/v1/recipes/{id}/steps/{stepId}/ingredients`, `DELETE /api/v1/recipes/{id}/steps/{stepId}/ingredients/{ingredientId}`, and `PUT /api/v1/recipes/{id}/step-output-uses`.
  - Recipe image and cover lifecycle: `POST /api/v1/recipes/{id}/image`, `GET /api/v1/recipes/{id}/covers`, `POST /api/v1/recipes/{id}/covers`, `PATCH /api/v1/recipes/{id}/covers/{coverId}`, `DELETE /api/v1/recipes/{id}/covers/{coverId}`, `POST /api/v1/recipes/{id}/covers/regenerate`, and `POST /api/v1/recipes/{id}/covers/from-spoon/{spoonId}`.
  - Spoon/cook-log reads and writes: `GET /api/v1/recipes/{id}/spoons`, `POST /api/v1/recipes/{id}/spoons`, `PATCH /api/v1/recipes/{id}/spoons/{spoonId}`, and `DELETE /api/v1/recipes/{id}/spoons/{spoonId}`, covering photo/note/next-time/cooked-at behavior.
  - Cookbook writes: `POST /api/v1/cookbooks`, `PATCH /api/v1/cookbooks/{id}`, `DELETE /api/v1/cookbooks/{id}`, `POST /api/v1/cookbooks/{id}/recipes/{recipeId}`, and `DELETE /api/v1/cookbooks/{id}/recipes/{recipeId}`.
  - Shopping parity gaps: `POST /api/v1/shopping-list/add-from-recipe`, `POST /api/v1/shopping-list/clear-completed`, and `POST /api/v1/shopping-list/clear-all`, preserving the existing idempotent add/check/delete resources.
  - Sync/tombstone/freshness contracts: cursor-based private sync payloads for recipes, cookbooks, spoons, shopping items, profiles, notification preferences, and deleted/tombstoned objects so offline cache reconciliation is deterministic.
- Update `spoonjoy-v2` API docs, OpenAPI, generated playground/profile docs, and in-product developer documentation to reflect what native dogfooding uses and what remains human/account gated.
- Replace native fixture-primary state with live data plus durable offline cache. Fixtures may remain only as test/demo fallback.
- Make offline usage first-class:
  - Cache recipes, cookbooks, recipe details, shopping list, cook progress, capture drafts, current chef profile, chef graph/profile reads, notification preferences, API token metadata, connection status, and APNs registration status.
  - Queue safe mutations with stable client mutation IDs and visible retry/conflict states.
  - Sync on launch/foreground/network recovery.
  - Show a dismissible offline/freshness indicator that distinguishes offline, stale cache, queued work, sync failure, and synced state.
- Bring native surfaces to current web parity where product concepts exist today:
  - Kitchen, recipe catalog/detail/edit/create/fork, cook mode, spoons/cook logs, cover controls, cookbooks/detail/editor, shopping list, search, profiles/activity-derived chef graph, settings/session/API access/notification preferences, and capture drafts/import handoff.
  - Use native web-auth handoff only for passkey enrollment/removal, password set/change/remove, and provider link/unlink flows that remain canonical web/OAuth/passkey surfaces; the native app must route users to the exact action and return cleanly.
- Preserve Spoonjoy Kitchen Table design language while using SwiftUI/AppKit/UIKit platform primitives where they feel premium.
- Implement first-class recipe/cookbook/shopping sharing through `ShareLink`, share sheet destinations, public URLs, and Siri/Shortcuts transfer/value representations. Messages, Mail, and social destinations are outcomes, not Spoonjoy-owned messaging/mail schemas.
- Implement App Intents/Siri full access for the current model:
  - App entities and queries for recipes, cookbooks, shopping items, shopping lists, spoons/cook logs, chefs, profiles, and capture drafts.
  - Spotlight/semantic indexing from live cached entities.
  - App Shortcuts and phrase catalogs for open recipe, search Spoonjoy, start cook mode, continue cook mode, add shopping item, check shopping item, remove shopping item, clear completed shopping items, add recipe ingredients to shopping, log cook, create capture draft, fork recipe, save recipe to cookbook, create cookbook, rename cookbook, add recipe to cookbook, remove recipe from cookbook, and share recipe/cookbook/shopping list.
  - Entity-backed intents for open/search/share/start cook mode/continue cook mode/add shopping/check shopping/remove shopping/clear shopping/add recipe ingredients/log cook/create capture/fork/save-to-cookbook/create cookbook/rename cookbook/delete cookbook/add recipe to cookbook/remove recipe from cookbook/profile open/notification preference update.
  - Confirmation, authentication policy, and ownership checks for writes/destructive actions; assume Apple HITL helps but do not rely on it as the only guard.
  - Donations, relevant entities, transfer/value representations, and view annotations for every shipped entity/action whose symbols compile in the installed SDK; unsupported WWDC26/27 symbols require structured SDK blocker artifacts and guarded fallbacks.
  - AppIntentsTesting coverage for compiled intent contracts; if the installed SDK lacks AppIntentsTesting, compile/static contracts must cover entities, queries, shortcut phrases, confirmations, auth policy, and transfer representations.
- Run local and CI validation commands for Swift tests, coverage, scenario verifier, warning scans, app bundle checks, macOS launch/screenshot, API/docs tests, and protected GitHub checks; record structured blocker artifacts only for Xcode/SDK/account/hardware/secret capabilities outside local control.
- Use harsh sub-agent reviewers for planning, doing, unit reviews, design review, API contract review, App Intents review, offline/sync review, and merge readiness. Human gates are waived except for true credentials/hardware/account/destructive-production blockers.

## Out of Scope

- New product surfaces not present today: recipe comments, recipe threads, social feeds, mentions, generic likes/reactions, meal planning, nutrition/fitness, pantry stock inventory, or a general media library.
- Pretending Spoonjoy is a messaging, mail, fitness, or media app to adopt an Apple schema that does not honestly match current product behavior.
- Paid Apple Developer Program enrollment, production signing, TestFlight upload, App Store Connect, production APNs, or production AASA finalization before account/team capability exists.
- Destructive production data changes or irreversible shared-state operations without a safe staged path.
- Replacing the web app or changing the product direction beyond REST/API/docs work required for native dogfooding and parity.

# Completion Criteria

- The three audit artifacts remain committed and are referenced by planning/doing docs.
- The planning doc passes harsh sub-agent review with no BLOCKER/MAJOR findings and is marked approved.
- A doing doc exists with concrete units for backend API, native transport/auth/cache/offline, parity surfaces, App Intents/Siri, documentation, validation, review, PR/merge, and cleanup.
- `spoonjoy-v2` exposes tested REST v1 endpoints needed by native parity, including `GET/POST /api/v1/tokens` and `DELETE /api/v1/tokens/{credentialId}` in native account/API credential flows, with OpenAPI/docs/playground updates and no drift from implementation.
- Native Apple uses live Spoonjoy contracts for every read and write endpoint listed in Scope, with fixtures only as deterministic fallback/test data.
- Offline mode works as product behavior: cached read access, durable cook progress, capture drafts, shopping mutation queue, sync/retry/conflict/freshness states, and a dismissible offline indicator.
- Native surfaces cover the audited current product concepts or provide exact native secure handoff for credential/account operations where web/OAuth/passkey surfaces are canonical.
- Siri/App Intents uses entity-backed access and not just string IDs for recipes, cookbooks, shopping items/lists, spoons/cook logs, chefs, profiles, and capture drafts. It explicitly skips only schema domains that are semantically false for Spoonjoy.
- Recipe/cookbook/shopping sharing is first-class through native share and Siri/Shortcuts transfer surfaces without adding comments/social feed.
- Destructive or sensitive Siri/native actions have confirmation/auth/ownership policy.
- Local validation is green to the available capability floor:
  - `spoonjoy-apple`: Swift tests, coverage, scenario verifier, warning scan, app bundle build, macOS launch/screenshot, project/generator/static contracts, or a structured Xcode/SDK/hardware blocker artifact for any command the installed toolchain cannot run.
  - `spoonjoy-v2`: targeted Vitest route/lib/doc suites for every touched API surface, `pnpm run test:coverage`, `pnpm run typecheck`, `pnpm run build`, generated playground drift checks, OpenAPI route coverage tests, and zero-warning output.
- Any remaining non-green validation is backed by a structured true blocker artifact, such as Apple Developer Program, missing simulator runtime, Xcode installation fault, production secret, or unavailable hardware.
- Reviewer sub-agents converge on implementation, offline/sync, API contract, native design, and App Intents readiness.
- PRs are opened, checks pass or true blockers are recorded, branches are merged to `main`, local repos are synced, temporary branches/worktrees are cleaned up, Desk state is updated, and Slugger is notified.

# Code Coverage Requirements

- New or modified `spoonjoy-apple` SwiftPM-measurable code in `Sources/SpoonjoyCore` must remain at 100% coverage, including valid, invalid, empty, boundary, cache, offline, conflict, replay, retry, and error paths.
- App-target SwiftUI/AppIntents adapters that cannot be measured by SwiftPM must have scenario, static, compile, screenshot, or AppIntentsTesting coverage.
- Every outbound native request builder/transport test must assert method, URL/path/query, headers, body, auth behavior, idempotency keys, and error-envelope decoding.
- `spoonjoy-v2` additions must satisfy the repo's 100% coverage and zero-warning policy for touched code, including API route coverage, OpenAPI/docs drift tests, idempotency conflicts, authorization/scope failures, validation errors, and tombstone/sync behavior.
- Documentation and generated OpenAPI/playground changes need tests that fail when the documented/native contract drifts from implemented REST v1 resources.
- UI parity that is not unit-testable must be covered by scenario verifier, static contracts, screenshots, and design-review artifacts.
- Web validation must save artifacts for `pnpm run test:coverage`, `pnpm run typecheck`, `pnpm run build`, generated API playground output, docs/OpenAPI route coverage, and every targeted Vitest command used during red/green units.

# Open Questions

- Which WWDC26/27 App Intents symbols compile in the installed Xcode 26.5 SDK versus requiring SDK guards or structured Xcode 27 blocker artifacts? This is a capability question, not a product-scope question.
- Which Apple Team ID/App ID values will be used for production AASA/APNs/TestFlight once Apple Developer Program enrollment exists? Until then, local/CI validation proceeds without pretending production signing is complete.

# Decisions Made

- Spoons are current Spoonjoy cook logs, not future comments or reactions. They are in scope for native parity and Siri.
- Product parity comes before new social or meal-planning surfaces. Do not invent comments, feeds, pantry inventory, nutrition, or media surfaces.
- Native parity requires REST v1 parity endpoints. Do not lean on app-only legacy `/api/*` routes for the native product.
- Native offline is a core product requirement and a major reason for the native app to exist.
- Use `spoonjoy.app` as the canonical domain. Do not assume `spoonjoy.com`.
- Use HTTPS universal-link OAuth redirect for the native app. Custom URL schemes remain deep-link fallback, not OAuth redirect URIs.
- Use `app.spoonjoy.Spoonjoy`-style bundle IDs because the canonical domain is `spoonjoy.app`.
- Keep the product baseline iOS 27/macOS 27 forward while using bootstrap/local validation floors only where the repo already documents them.
- Use full Siri access for the current Spoonjoy actions listed in Scope, including sensitive/destructive ones, with confirmation/auth/ownership policy and tests.
- Use Apple schema domains only when semantically honest. Messaging/Mail are share destinations, not Spoonjoy-owned domains. Fitness/media/meal-planning schemas are skipped until those product surfaces exist.
- Human gates are waived under repo instructions and the user's full-moon mandate. Approval means harsh sub-agent reviewer convergence unless a true human-only credential/account/hardware/destructive-production blocker appears.

# Context / References

- `/Users/arimendelow/Projects/spoonjoy-apple/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-planning-siri-full-access-parity/web-product-surface-audit.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-planning-siri-full-access-parity/api-native-dogfood-audit.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-16-1754-planning-siri-full-access-parity/native-parity-matrix.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-15-2314-planning-native-app-skeleton.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-15-2314-doing-native-app-skeleton.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-justification.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/prisma/schema.prisma`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-contract.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts`
- Apple: https://developer.apple.com/videos/play/wwdc2026/240/
- Apple: https://developer.apple.com/videos/play/wwdc2026/343/
- Apple: https://developer.apple.com/videos/play/wwdc2026/345/
- Apple: https://developer.apple.com/videos/play/wwdc2026/295/
- Apple: https://developer.apple.com/videos/play/wwdc2026/347/

# Notes

- Current native app foundation is strong: SwiftUI iOS/macOS targets, shared shell, deep-link router, scenario verifier, project generator, offline snapshot primitives, mutation queue, local cook progress, local capture draft, Spotlight planning, and starter App Intents.
- Current native app is not yet product-parity because it is fixture/local-first, has no live `URLSession` transport, has no Keychain-backed OAuth flow, and lacks many web mutations/surfaces.
- Current REST v1 is enough for public catalog reads and basic shopping sync/mutations, but not enough for native parity.
- The implementation sequence should keep both repos runnable after each atomic unit. Backend API endpoints and docs should land before native client units that rely on them.
- The offline implementation should prefer a small explicit local store and sync state over magical hidden caching. The user must be able to tell when data is offline, stale, queued, failed, or synced.
- Recipe sharing should remain URL/public-object based. There is no current product concept of sending messages or mail inside Spoonjoy.
- Production APNs delivery and TestFlight remain blocked by Apple Developer Program/team capability, but native notification preference UI, backend preference APIs, APNs device-registration contract, local compile/static checks, and structured blocker artifacts are in scope now.

# Progress Log

- 2026-06-16 17:56 Created initial planning draft before the required web/API/native parity audit.
- 2026-06-16 18:06 Added committed web product, API dogfood, and native parity audit artifacts.
- 2026-06-16 18:08 Replaced provisional plan with audited full-moon scope, including REST v1 parity, native offline, and entity-backed Siri access.
- 2026-06-16 18:16 Addressed reviewer findings by replacing optional language with explicit API, offline, App Intents, notification, and sync scope.
- 2026-06-16 18:20 Addressed Round 2 reviewer findings by making API credential endpoints and web validation commands explicit.
- 2026-06-16 18:21 Planning review converged and status moved to approved.
