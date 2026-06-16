# Goal

Build the first complete, runnable native Spoonjoy Apple app slice: a protected, reproducible SwiftUI/Xcode project with iOS and macOS app bundles, testable domain/API/offline logic, and native-value surfaces that prove this is not a web clone.

This branch should leave `spoonjoy-apple` with a real app skeleton that builds locally and in CI, preserves the Spoonjoy Kitchen Table design language, and creates the foundation for the remaining full-moon implementation PRs.

# Scope

## In Scope

- Create a Swift package for Spoonjoy domain models, API request construction, offline JSON cache logic, search/filter helpers, cook-mode progress, shopping-list operations, and fixture-driven app state.
- Create a real Xcode project with separate iOS and macOS SwiftUI app targets using bundle IDs under `app.spoonjoy.*`.
- Add native app screens for signed-out setup, Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping List, Search, Capture, and Settings.
- Add native affordance scaffolds: `NavigationStack`/`NavigationSplitView`, `.searchable`, native toolbars, share links, edit/check controls, App Intent descriptors or compileable App Intents where the installed SDK supports them, offline status, and local persistence.
- Encode Spoonjoy native justification in repo docs before major code lands.
- Update CI/scripts so protected checks build iOS and macOS bundles, run Swift tests, run coverage, and run a native scenario verifier.
- Validate against the installed Xcode 26.5 SDK while preserving the product baseline of iOS 27/macOS 27 forward in docs. True SDK-27 validation is a capability blocker until Xcode 27 is installed.
- Use sub-agent reviewer gates for plan, doing doc, implementation units, and final merge readiness.

## Out of Scope

- Paid Apple Developer Program enrollment, App Store Connect, TestFlight upload, production signing, and notarization. These are account/capability blocked until the $99 developer subscription exists.
- Storing real user secrets in the repo or committing production API tokens.
- Destructive production backend changes.
- Replacing the Spoonjoy web app.
- Claiming true iOS/macOS 27 SDK validation while this machine only has Xcode 26.5.

# Completion Criteria

- `Package.swift` exists and `swift test` passes with focused coverage for all new core logic and edge/error paths.
- `Spoonjoy.xcodeproj` exists and app bundles build for iOS simulator and macOS destinations without warnings introduced by this branch.
- The native scenario verifier proves first-run/session setup, fixture kitchen browsing, recipe detail, cook-mode progress persistence, shopping-list checkoff, search, capture draft creation, and settings state through deterministic command-line checks.
- `docs/native-justification.md` explains why Spoonjoy Apple earns being native and which tempting APIs are intentionally postponed or rejected.
- `docs/native-design-language.md` remains consistent with the web Kitchen Table language and the app code reflects those invariants in structure, naming, colors, typography, and object hierarchy.
- CI protected checks pass on the PR: `Swift tests`, `Native scenario verifier`, `App bundle`, and `Coverage`.
- Harsh sub-agent review converges with no BLOCKER/MAJOR findings before merge.

# Code Coverage Requirements

- New Swift package code must have 100% line/branch coverage where measurable by SwiftPM coverage.
- Request-building code must assert outbound HTTP method, URL path/query, headers, and JSON body shape, not only response handling.
- Offline/cache/search/cook-mode/shopping logic must cover valid, empty, invalid, boundary, and error paths.
- UI app target code is covered through compile/build plus scenario verifier until XCTest UI automation is added; any nontrivial UI-independent logic belongs in the Swift package and must be tested there.

# Open Questions

- None requiring human approval under the current no-human-gates mandate.
- Explorer results for existing API/OAuth details and prior mobile code are pending; incorporate as source-fidelity updates before converting to doing.
- True iOS 27/macOS 27 SDK validation is blocked by local Xcode 26.5. This branch will document the blocker and make the validation target switch explicit rather than silently weakening the product baseline.

# Decisions Made

- Use `slugger/native-app-skeleton` as the implementation branch.
- Use `tasks/` in the Apple repo for Work Suite planning/doing docs because the repo has no stricter task-doc path.
- Use one Xcode project with separate iOS and macOS SwiftUI app targets; share source and domain logic rather than creating two separate apps.
- Use bundle namespace `app.spoonjoy.*`, with the primary iOS bundle as `app.spoonjoy.Spoonjoy` and macOS as `app.spoonjoy.Spoonjoy.macOS` unless project generation requires a stricter suffix.
- Build the first app around local fixture/offline-capable state plus API-client contracts. Real OAuth/token entry belongs in the app foundation, but production secrets and paid signing do not.
- Treat App Intents, Spotlight, capture, offline cook-mode, and shopping-list checkoff as native-value proof points. Build compileable scaffolds now; deeper production server sync can follow in later PRs without redoing the app architecture.
- Preserve iOS/macOS 27 as product baseline in docs; set build settings to the highest installed SDK-supported minimum only when necessary for local CI, with an explicit validation note.

# Context / References

- `/Users/arimendelow/Projects/spoonjoy-apple/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/ui-systems-audit-backlog.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/api.$.ts`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/spoonjoy-api.server.ts`
- `/Users/arimendelow/.codex/skills/build-native-apple-app/SKILL.md`
- `/Users/arimendelow/.codex/skills/build-native-apple-app/references/wwdc26-native-levers.md`
- `/Users/arimendelow/.codex/skills/build-native-apple-app/references/validation-matrix.md`

# Notes

- Local preflight on 2026-06-15 reported Xcode 26.5, Swift 6.3.2, iOS/macOS 26.5 SDKs, and a bounded CoreSimulator runtime-list timeout.
- The current native repo has no project files yet; protected checks bootstrap-pass until this branch adds `Package.swift` and `Spoonjoy.xcodeproj`.
- The web design language requires food/object hierarchy over dashboard grids; the native shell should default to native lists/split views/toolbars while keeping cookbook authorship visible.
- The app should be useful for dogfooding without production signing: local fixtures, offline state, token/session entry, and deterministic scenario checks all matter.

# Progress Log

- 2026-06-15 23:14 Created initial planning doc from repo contracts, native skill workflow, design docs, local preflight, and current platform constraints.
