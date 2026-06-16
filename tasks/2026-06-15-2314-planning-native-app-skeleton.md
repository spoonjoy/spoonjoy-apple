# Goal

**Status**: approved

Build the first complete, runnable native Spoonjoy Apple app slice: a protected, reproducible SwiftUI/Xcode project with iOS and macOS app bundles, testable domain/API/offline logic, and native-value surfaces that prove this is not a web clone.

This branch should leave `spoonjoy-apple` with a real app skeleton that builds locally and in CI, preserves the Spoonjoy Kitchen Table design language, and creates the foundation for the remaining full-moon implementation PRs.

# Scope

## In Scope

- Create a Swift package for Spoonjoy domain models, API request construction, offline JSON cache logic, search/filter helpers, cook-mode progress, shopping-list operations, and fixture-driven app state.
- Create a real Xcode project with separate iOS and macOS SwiftUI app targets using bundle IDs under `app.spoonjoy.*`.
- Add native app screens for signed-out setup, Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping List, Search, Capture, and Settings.
- Use Spoonjoy REST API v1 contracts at `https://spoonjoy.app/api/v1` for client request builders. Treat legacy `/api/*`, old GraphQL, and MCP routes as non-native-app contracts.
- Scaffold native OAuth/PKCE planning and request construction against `/oauth/register`, `/oauth/authorize`, `/oauth/token`, and `/oauth/revoke`; persistable token storage abstractions must be present, but production auth completion can wait for app-link/signing capability.
- Add native affordance scaffolds: `NavigationStack`/`NavigationSplitView`, `.searchable`, native toolbars, share links, edit/check controls, App Intent descriptors or compileable App Intents where the installed SDK supports them, offline status, and local persistence.
- Encode Spoonjoy native justification in repo docs before major code lands.
- Update CI/scripts so protected checks build iOS and macOS bundles, run Swift tests, run coverage, and run a native scenario verifier.
- Validate against the installed Xcode 26.5 SDK using a clearly named `BootstrapDebug` configuration on GitHub Actions `macos-26` runners. Product configs must preserve iOS 27/macOS 27 as the baseline; `IPHONEOS_DEPLOYMENT_TARGET = 26.5` may appear only in bootstrap config for iOS simulator builds, and `MACOSX_DEPLOYMENT_TARGET = 26.2` must be used for bootstrap macOS builds so mandatory local launch/smoke can run on this macOS 26.2 host. Deployment targets are actual minimum runtimes, not labels. True SDK-27 validation is a capability blocker until Xcode 27 is installed.
- Add local launch/smoke scripts and screenshot artifacts for iOS simulator when CoreSimulator is available, plus macOS app launch/smoke and desktop-class screenshot review.
- Use sub-agent reviewer gates for plan, doing doc, implementation units, and final merge readiness.

## Out of Scope

- Paid Apple Developer Program enrollment, App Store Connect, TestFlight upload, production signing, and notarization. These are account/capability blocked until the $99 developer subscription exists.
- Storing real user secrets in the repo or committing production API tokens.
- Destructive production backend changes.
- Replacing the Spoonjoy web app.
- Claiming true iOS/macOS 27 SDK validation while this machine only has Xcode 26.5.

# Completion Criteria

- `Package.swift` exists and the warning-enforced Swift test command passes with focused coverage for all new core logic and edge/error paths.
- `Spoonjoy.xcodeproj` exists and `BootstrapDebug` app bundles build for iOS simulator and macOS destinations with warnings treated as errors.
- The native scenario verifier proves first-run/session setup, fixture kitchen browsing, recipe detail, cook-mode progress persistence, shopping-list checkoff, search, capture draft creation, settings state, App Intent/search indexing metadata, offline cache restore, and native affordance flags through deterministic command-line checks.
- iOS simulator launch/smoke runs when CoreSimulator responds; if local CoreSimulator times out, the result is recorded as a local machine blocker while CI still builds the iOS bundle. macOS app launch/smoke must run locally.
- Screenshot/design review artifacts exist for mobile-width and desktop-class layouts, or the plan records a concrete simulator/runtime blocker with the last command output.
- App surfaces visibly use native navigation/search/toolbars/share/edit/check controls while preserving Kitchen Table hierarchy: a lead food/cookbook/list object, cookbook-style recipe detail, receipt-like shopping list, and focused cook-mode surface.
- `docs/native-justification.md` explains why Spoonjoy Apple earns being native and which tempting APIs are intentionally postponed or rejected.
- `docs/native-design-language.md` remains consistent with the web Kitchen Table language and the app code reflects those invariants in structure, naming, colors, typography, and object hierarchy.
- CI protected checks pass on the PR: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`.
- The `Coverage` check enforces the configured Swift package coverage threshold for new SwiftPM-measurable code instead of only generating coverage output.
- Harsh sub-agent review converges with no BLOCKER/MAJOR findings before merge.

# Code Coverage Requirements

- New Swift package code must have 100% line/branch coverage where measurable by SwiftPM coverage; shell/Ruby scripts and thin app/executable adapters need red/green behavioral checks; the CI `Coverage` job must fail below the threshold.
- Request-building code must assert outbound HTTP method, URL path/query, headers, and JSON/form body shape, not only response handling.
- Offline/cache/search/cook-mode/shopping logic must cover valid, empty, invalid, boundary, and error paths.
- OAuth/PKCE logic must cover code-verifier/challenge generation, state generation/validation, register/authorize/token/refresh/revoke request construction, redirect validation, persisted client id, atomic refresh-token rotation, and single-flight refresh behavior.
- Shopping-list mutation tests must cover POST/PATCH JSON `clientMutationId`, DELETE idempotency through `X-Client-Mutation-Id`, query, and body forms, plus idempotency conflict/in-progress response handling.
- UI app target code is covered through compile/build plus scenario verifier until XCTest UI automation is added; any nontrivial UI-independent logic belongs in the Swift package and must be tested there.

# Open Questions

- None requiring human approval under the current no-human-gates mandate.
- API/OAuth and prior mobile-code explorer findings are incorporated.
- True iOS 27/macOS 27 SDK validation is blocked by local Xcode 26.5. The branch must keep iOS/macOS 27 in product config metadata, isolate iOS simulator 26.5 and macOS local-smoke 26.2 to `BootstrapDebug`, and include a follow-up validation gate for Xcode 27 without weakening the product baseline.

# Decisions Made

- Use `slugger/native-app-skeleton` as the implementation branch.
- Use `tasks/` in the Apple repo for Work Suite planning/doing docs because the repo has no stricter task-doc path.
- Use one Xcode project with separate iOS and macOS SwiftUI app targets; share source and domain logic rather than creating two separate apps.
- Use bundle namespace `app.spoonjoy.*`, with the primary iOS bundle as `app.spoonjoy.Spoonjoy` and macOS as `app.spoonjoy.Spoonjoy.macOS` unless project generation requires a stricter suffix.
- Build the first app around local fixture/offline-capable state plus API-client contracts. Real OAuth/PKCE request construction, token persistence abstractions, and refresh/revoke logic belong in the app foundation. Production universal-link callback, paid signing, and App Store Connect remain account/capability blocked.
- REST API v1 is the native backend contract. Read endpoints are `GET /api/v1/recipes`, `GET /api/v1/recipes/{id}`, `GET /api/v1/cookbooks`, and `GET /api/v1/cookbooks/{id}`. Shopping-list endpoints are `GET /api/v1/shopping-list`, `GET /api/v1/shopping-list/sync`, `POST /api/v1/shopping-list/items`, `PATCH /api/v1/shopping-list/items/{itemId}`, and `DELETE /api/v1/shopping-list/items/{itemId}`. Mutations must include `clientMutationId`.
- Use OAuth/PKCE public-client flow for real auth, omitting `resource` for REST API v1. Register once per app/environment with `token_endpoint_auth_method: "none"`, use ASWebAuthenticationSession/AppAuth shape for authorization, rotate refresh tokens atomically, and prefer HTTPS universal/app links for production redirects. Custom schemes are rejected by the server today.
- Do not reuse `sj-mobile` implementation code or auth assumptions. It was an archived Expo/Apollo/JWT app against old GraphQL/Rails-era infrastructure. Mine it only for product ideas like photo-first recipe detail, saved collections/library, search across object types, and staged recipe creation.
- Treat App Intents, Spotlight/search metadata, capture draft creation, offline cook-mode persistence, share/search toolbars, and shopping-list checkoff as native-value proof points. Build compileable scaffolds and scenario-verifiable metadata now; deeper production server sync can follow in later PRs without redoing the app architecture.
- Preserve iOS/macOS 27 as product baseline in docs and product build settings. Use `IPHONEOS_DEPLOYMENT_TARGET = 26.5` and `MACOSX_DEPLOYMENT_TARGET = 26.2` only in a generated `BootstrapDebug` configuration while this machine has Xcode 26.5 but runs macOS 26.2, and label every such validation as bootstrap validation rather than product-baseline validation.

# Context / References

- `/Users/arimendelow/Projects/spoonjoy-apple/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/ui-systems-audit-backlog.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/api.$.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-contract.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/oauth-routes.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/oauth-server.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/spoonjoy-api.server.ts`
- `spoonjoy/sj-mobile` archived GitHub repo, product archaeology only; avoid code/auth reuse.
- `/Users/arimendelow/Projects/spoonjoy`, old Capacitor/web repo, product/domain reference only.
- `/Users/arimendelow/.codex/skills/build-native-apple-app/SKILL.md`
- `/Users/arimendelow/.codex/skills/build-native-apple-app/references/wwdc26-native-levers.md`
- `/Users/arimendelow/.codex/skills/build-native-apple-app/references/validation-matrix.md`

# Notes

- Local preflight on 2026-06-15 reported Xcode 26.5, Swift 6.3.2, iOS/macOS 26.5 SDKs, macOS host 26.2, and a bounded CoreSimulator runtime-list timeout.
- The current native repo has no project files yet, so protected checks bootstrap-pass only while neither `Package.swift` nor `Spoonjoy.xcodeproj` exists. Once Swift or Xcode sources exist, the workflow requires the verifier and coverage-enforcement hooks described in the doing doc.
- The web design language requires food/object hierarchy over dashboard grids; the native shell should default to native lists/split views/toolbars while keeping cookbook authorship visible.
- The app should be useful for dogfooding without production signing: local fixtures, offline state, token/session entry, and deterministic scenario checks all matter.
- API explorer confirmed API v1 does not expose recipe/cookbook writes for native clients yet. This branch should not fake those mutations; capture/create screens can create local drafts and request builders, with sync expansion handled by later backend/native PRs if needed.
- Prior mobile-code explorer found no reusable native implementation. The current Apple repo design brief and current v2 API docs are authoritative.
- Planning reviewer found and this revision addressed: stale open-question wording, concrete 26.5 bootstrap vs 27 product target labeling, launch/screenshot validation, native-value verification, OAuth/PKCE coverage, enforced coverage threshold, and DELETE idempotency forms.

# Progress Log

- 2026-06-15 23:14 Created initial planning doc from repo contracts, native skill workflow, design docs, local preflight, and current platform constraints.
- 2026-06-15 23:14 Incorporated explorer findings for REST API v1, OAuth/PKCE, prior mobile-code archaeology, and non-reuse decisions.
- 2026-06-15 23:14 Addressed Round 1 planning reviewer findings with concrete SDK target labeling, launch/screenshot validation, native-value criteria, OAuth and coverage enforcement, and shopping DELETE idempotency detail.
- 2026-06-15 23:14 Planning approved after Round 2 sub-agent review converged.
- 2026-06-16 00:24 Addressed doing-doc scrutiny by separating product iOS/macOS 27 baseline from Xcode 26.5 bootstrap validation and requiring warning-enforced native checks.
- 2026-06-16 00:24 Addressed Tinfoil runtime finding by setting bootstrap macOS deployment to the local macOS 26.2 smoke floor while preserving macOS 27 product config.
