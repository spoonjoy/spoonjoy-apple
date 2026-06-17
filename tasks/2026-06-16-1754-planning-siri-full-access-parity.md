# Goal

**Status**: draft

Bring the native Spoonjoy Apple app to parity with the current Spoonjoy web product model, then expose the existing product model to Siri/App Intents as fully as Apple’s WWDC26 App Intents surface allows.

This planning draft is intentionally provisional: it captures the current hypothesis, then requires a deep web/API/native parity audit before it can be approved and converted to a doing doc.

# Scope

## In Scope

- Audit the current Spoonjoy web product surface directly from `spoonjoy-v2`: routes, loaders/actions, components, Prisma model, API v1 contract, OAuth/session behavior, design docs, feedback files, tests, and any product docs.
- Produce a product-surface inventory that distinguishes existing product concepts from speculative future concepts. Do not invent comments, social feeds, recipe threads, or other new surfaces unless the web app already contains them.
- Audit the existing `spoonjoy-apple` native app against that inventory and classify every surface/API/domain object as parity complete, partial, missing, intentionally native-only, or future-product.
- Update `spoonjoy-v2` API docs and in-product documentation to reflect the API surface that was actually dogfooded by the native app, including native constraints, supported endpoints, mutation/idempotency behavior, OAuth/app-link assumptions, and known unsupported writes.
- Update `spoonjoy-apple` docs and scenario verification to reflect the audited product model and the Siri full-access strategy.
- Implement native parity gaps required by the current web product model, using the existing REST API v1 surface where available and honest local/offline/capability blockers where the backend does not yet expose a write path.
- Implement App Intents and entity infrastructure for full Siri access to the existing Spoonjoy product model: app entities, queries, semantic indexing, view annotations, transfer/value representations, relevant entities, interaction donations, confirmation/auth policy, execution targeting, and testing contracts where supported by the installed SDK.
- Treat recipe/cookbook/shopping sharing as first-class product behavior across Siri, share sheets, Messages, Mail, and external/social destinations, without making Spoonjoy pretend to be a Messages or Mail client.
- Preserve Spoonjoy Kitchen Table design language while using native controls and WWDC26 App Intents affordances where they improve the native experience.
- Use strict TDD for implementation units, save artifacts under the task artifact directory, keep commits atomic, push after commits, open PRs, wait for protected checks, merge, sync local branches, and archive/update Desk state.

## Out of Scope

- New product surfaces not present in the current web app, including recipe comments, recipe threads, social feeds, mentions, or “spoons” reactions, unless the audit proves they already exist.
- Paid Apple Developer Program enrollment, production signing, TestFlight, App Store Connect, and production AASA publication. These remain human/account capability gates.
- Pretending local iOS simulator validation passed when the required runtime/device is unavailable. Record capability blockers honestly while requiring GitHub app-bundle checks to pass.
- Destructive production backend migrations or data changes without a safe staged path.
- Replacing the web app or changing its product direction beyond API/documentation updates needed to reflect native dogfooding reality.

# Completion Criteria

- A committed product-surface audit exists and covers all current web routes, actions, key components, API v1 endpoints, OAuth/session flows, data models, tests, and docs.
- A committed native parity matrix maps every current web product concept to the native implementation status, with evidence paths for complete items and doing-doc units for gaps.
- The planning doc is updated after the audit so it no longer relies on guessed product concepts; a harsh reviewer converges on the plan with no BLOCKER/MAJOR findings.
- A doing doc exists with all implementation units needed for full-moon completion and no deferred in-scope work.
- `spoonjoy-v2` API/docs reflect the dogfooded native API reality and pass the repo’s required checks for touched surfaces.
- `spoonjoy-apple` implements the audited parity gaps and full-Siri-access App Intents strategy for existing product concepts.
- App Intents coverage includes, where useful for current product concepts: `AppEntity`, queries, `IndexedEntity`/Spotlight, view annotations, transfer/value representations, relevant entities, interaction donations, confirmation/auth policy, execution targets, long-running intents for long work, and test/scenario coverage.
- Recipe/cookbook/shopping sharing works as a first-class native/Siri/share outcome without adopting Messages/Mail schemas as if Spoonjoy were a messaging or mail client.
- Native design and scenario verifiers cover the audited parity surface and fail closed on invented product concepts.
- Local validation passes to the fullest available extent: Swift tests, coverage, scenario verifier, app bundle builds, macOS launch/screenshot smoke, API/docs tests, warning scans, and protected GitHub checks.
- Any remaining gaps are true human/account/hardware blockers with exact evidence, not engineering deferrals.
- PRs are merged, local repos are synced to `origin/main`, temporary branches are pruned, Desk is updated, and Slugger is notified.

# Code Coverage Requirements

- New SwiftPM-measurable code in `spoonjoy-apple` must maintain 100% coverage for `Sources/SpoonjoyCore`, including valid, empty, invalid, boundary, and error paths.
- App Intent/entity/query policy logic must be testable outside the thin app target whenever possible; app-target adapters need scenario or compile/build contracts.
- Any outbound API/request builder changes must assert HTTP method, path, query, headers, body, idempotency keys, and error handling.
- `spoonjoy-v2` code changes must satisfy the repo’s 100% coverage and zero-warning policy for touched files.
- Shell/Ruby/Node validation scripts need red/green behavioral evidence when changed.
- UI parity that is not unit-testable must be covered by scenario verifier, static contracts, screenshots, and design review artifacts.

# Open Questions

- Which exact Spoonjoy product concepts exist today versus belong to later social/meal-planning work? The audit must answer this from source before implementation begins.
- Which Apple App Schema domains are semantically honest for current Spoonjoy behavior? The current hypothesis is to use schemas only where Spoonjoy truly matches the domain, and use transfer/share handoff for Messages/Mail rather than adopting those domains directly.
- Which App Intents APIs are compileable in the installed Xcode 26.5 SDK versus only targetable once Xcode 27 is available? The implementation must distinguish compileable work from SDK-capability blockers.

# Decisions Made

- Human planning/doing gates are waived under repo instructions and the user’s full-moon mandate; use harsh sub-agent reviewer gates instead.
- Use `slugger/siri-full-access-parity` as the branch name in both `spoonjoy-apple` and `spoonjoy-v2`.
- Keep task docs in `spoonjoy-apple/tasks/` because this is the native-app driving repo; include `spoonjoy-v2` as a required implementation/documentation repo in scope.
- Full Siri access means full access to the current Spoonjoy product model, not invention of future product surfaces.
- Messages, Mail, and social sharing are first-class outcomes for recipes/cookbooks/shopping lists, but Spoonjoy should not model itself as a mail or messaging client.
- Product parity comes before new social or meal-planning surfaces. Future “spoons,” comments, social feed, fitness, and meal planning are not part of this parity implementation unless the web audit proves current support.

# Context / References

- `/Users/arimendelow/Projects/spoonjoy-apple/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-15-2314-planning-native-app-skeleton.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/tasks/2026-06-15-2314-doing-native-app-skeleton.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-justification.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/api.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/components/`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1-contract.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/api-v1.server.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/prisma/schema.prisma`
- Apple WWDC26: Build intelligent Siri experiences with App Schemas, Explore advanced App Intents features, Discover new capabilities in the App Intents framework, Validate your App Intents adoption with AppIntentsTesting, and Secure your app: mitigate risks to agentic features.

# Notes

- Current native app already includes starter App Intents, Spotlight indexing, URL routing, offline snapshot state, native surfaces, macOS validation, and protected GitHub checks. This task must audit whether those match the web product surface rather than assuming parity.
- Current native App Intents use string IDs and starter intents; the likely next architecture is real app entities plus queries/indexing/annotations/share representations.
- Apple’s App Intents posture supports broad Siri access, but Apple also recommends deterministic mitigations: confirmations, authentication policy, ownership state, and testing.
- The installed Xcode is 26.5; product baseline remains iOS/macOS 27. Some WWDC26/2027 APIs may require SDK guards or blocker documentation until Xcode 27 is available.

# Progress Log

- 2026-06-16 17:54 Created initial planning draft before the required web/API/native parity audit.
