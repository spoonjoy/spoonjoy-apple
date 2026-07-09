# Planning: Spoonjoy Native Full Moon

**Status**: approved
**Created**: 2026-07-09 12:43

## Goal
Make Spoonjoy native feel like a finished, high-taste Apple app rather than a TestFlight proof harness: beautiful, honest with data, native where it matters, and continuously verifiable through screenshots, telemetry, and TestFlight feedback.

## Upstream Work Items
- None

## Scope

### In Scope
- Consolidate the repo/worktree source of truth around `/Users/arimendelow/Projects/spoonjoy-apple` on `main`, with this branch/worktree as the only active implementation lane.
- Repair native visual validation so screenshot capture, simulator launch, macOS launch, and artifact cleanup are deterministic and cannot hang silently.
- Rebuild the shared visual substrate: Spoonjoy palette, typography roles, safe-area rules, status banners, loading transitions, image policy, no-photo states, and navigation chrome.
- Rework `SpoonDock` and platform navigation so mobile uses Apple-native affordances without overpowering content, while macOS uses desktop-native navigation instead of scaled mobile patterns.
- Audit every visible route for product honesty: Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping, Search, Capture, Settings, auth/offline/error states, and macOS equivalents.
- Pull latest TestFlight feedback, screenshots, crash data, app metadata, native telemetry, and backend signals before each wave so fixes start from observed app behavior.
- Bring recipe detail and cook mode back to the web product structure and language while translating controls into native SwiftUI patterns.
- Remove production-facing placeholder/demo language, fake-looking imagery, internal labels, transient "unavailable" flashes, and dead-end actions.
- Make shopping feel like a store-run tool: receipt/list grammar, large reliable check targets, grouped items, offline confidence, duplicate handling, and native edit affordances.
- Make capture/import coherent: current MCP/agent import reality, future Share Sheet/App Intents/Siri paths, local draft lifecycle, retryable failures, and clear blockers.
- Verify App Intents, Spotlight, Universal Links, offline cache/queue, telemetry, and TestFlight feedback automation against real app behavior rather than source claims only.
- Add or update tests, scenario checks, visual metrics, telemetry assertions, and CI guards for every new behavior and every regression found.
- Publish internal TestFlight builds after coherent waves and verify App Store Connect attachment to `Spoonjoy Internal`.
- Update relevant native-app skills/docs with durable lessons learned, especially the Native Taste Bar and TestFlight feedback loop.

### Out of Scope
- Public App Store submission.
- Paid/billing/account changes outside existing credentials and CLI-accessible Apple tooling.
- Replacing the Spoonjoy backend or web product architecture.
- New brand direction that contradicts the existing Spoonjoy web design language.
- Shipping product support below the documented iOS 27/macOS 27 baseline unless the project baseline documents change first.

## Completion Criteria
- [ ] `/Users/arimendelow/Projects/spoonjoy-apple` is the clean canonical native checkout, with stale worktrees retired or intentionally documented.
- [ ] Screenshot capture and visual QA can run across the core iOS and macOS route matrix without hanging, with artifacts saved under task docs.
- [ ] Every core route has fresh iOS and macOS screenshot evidence reviewed against the Spoonjoy native design language, with an absurdity ledger closed.
- [ ] Every visual route capture produces a valid `design-review.json` or valid `design-review-blocked.json`; success artifacts include app-emitted iOS and macOS accessibility proofs through `SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH`.
- [ ] Dynamic Type, VoiceOver labels, keyboard navigation, Reduce Motion, contrast, route-specific hierarchy evidence, target size, text fit, no-tiny-cluster checks, and `OfflineStatusView` proof pass fail-closed validation.
- [ ] Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Cookbook Detail, Shopping, Search, Capture, Settings, auth/offline/error states, and macOS shell show no overlapping text, false unavailable flashes, production-facing demo labels, or default-looking placeholder imagery.
- [ ] System blue, generic grouped-card styling, oversized dock chrome, and loud non-critical banners are removed or confined to appropriate native/system contexts.
- [ ] Recipe and cook-mode structure matches the web product language where intentional, with native controls only where they improve the workflow.
- [ ] Offline, loading, empty, stale, sync-failed, unauthenticated, and blocked-provider states are honest, graceful, telemetry-backed, and tested.
- [ ] TestFlight feedback autopilot has a transparent ledger from feedback receipt through diagnosis, fix, build number, and confirmation state.
- [ ] Latest TestFlight feedback screenshots and comments are reconciled before each TestFlight publish, with no actionable unhandled feedback left behind.
- [ ] At least one new internal TestFlight build is uploaded, processed `VALID`, attached to `Spoonjoy Internal`, verified with nonzero group tester count, and has build beta detail `internalBuildState` of `IN_BETA_TESTING`.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [ ] None currently; the user has delegated product, scope, and implementation judgment. Reopen only for true human-only credentials, unavailable hardware, irreversible account operations, or a choice that cannot be resolved from Spoonjoy source/design evidence.

## Decisions Made
- `/Users/arimendelow/Projects/spoonjoy-apple` is the canonical native repo path after retiring stale worktrees; `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` is the dedicated implementation worktree for this campaign.
- The campaign optimizes for full-product native quality, not isolated screenshot improvements.
- Visual validation infrastructure is Unit 0 because taste work is unreliable without deterministic app launch and screenshots.
- Product support follows the documented iOS 27/macOS 27 baseline; Xcode 26/iOS 26 simulator work remains a local bootstrap and validation detail, not product backport scope.
- TestFlight feedback is product input, not a passive inbox; the automation must expose state clearly and close the loop with confirmed builds.

## Context / References
- `/Users/arimendelow/Projects/spoonjoy-apple/AGENTS.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-justification.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-api-dogfood.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/apple-distribution.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/AppShell/SpoonDock.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/KitchenView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/CookModeView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/SearchView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/scripts/capture-native-screenshot-matrix.sh`
- `/Users/arimendelow/Projects/spoonjoy-apple/scripts/testflight-feedback-autopilot.mjs`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/task.md`

## Notes
Fresh roadmap evidence showed the current build has strong platform plumbing but weak product/taste closure: system blue leakage, heavy dock chrome, demo-looking imagery, loud state banners, placeholder labels, and visual validation that can hang during simulator launch. The task should move in waves, with each wave beginning from latest TestFlight/telemetry evidence and ending in screenshots, tests, and TestFlight verification rather than a PR-only stop.

## Progress Log
- 2026-07-09 12:43 Created
- 2026-07-09 12:44 Tinfoil pass added latest-feedback grounding before each wave
- 2026-07-09 12:45 Addressed reviewer findings on iOS/macOS baseline, fail-closed design evidence, TestFlight verification, and route matrix scope
- 2026-07-09 12:46 Approved after sub-agent review convergence
