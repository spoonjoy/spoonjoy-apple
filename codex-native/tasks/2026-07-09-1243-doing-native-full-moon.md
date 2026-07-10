# Doing: Spoonjoy Native Full Moon

**Status**: READY_FOR_EXECUTION
**Execution Mode**: direct
**Created**: 2026-07-09 12:49
**Host context**: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` / OS: `Darwin` / probed: 2026-07-10T00:45:29Z
**Planning**: ./2026-07-09-1243-planning-native-full-moon.md
**Artifacts**: ./2026-07-09-1243-doing-native-full-moon/

## Execution Mode

- **pending**: Awaiting user approval before each unit starts only when the user explicitly requested interactive per-unit approval; otherwise convert this to `spawn` or `direct` unless a hard exception is present
- **spawn**: Spawn sub-agent for each unit (parallel/autonomous)
- **direct**: Execute units sequentially in current session (default)

## Objective
Make Spoonjoy native feel like a finished, high-taste Apple app rather than a TestFlight proof harness: beautiful, honest with data, native where it matters, and continuously verifiable through screenshots, telemetry, and TestFlight feedback.

## Upstream Work Items
- None

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
- [ ] The distributed TestFlight build is install/launch smoked on an available eligible device, or a valid human-only/unavailable-hardware blocker records the exact device/account action needed.
- [ ] macOS distribution for `app.spoonjoy.mac` is either published and verified through the configured Apple lane or explicitly dispositioned with source/App Store Connect evidence for why it is not currently publishable.
- [ ] Widgets, Watch, Live Activities/lock-screen-adjacent surfaces, Siri, camera/OCR/barcode, and Foundation Models have implement-now/no-op/future dispositions grounded in product materiality and platform support.
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

## TDD Requirements
**Strict TDD — no exceptions:**
1. **Tests first**: Write failing tests BEFORE any implementation
2. **Verify failure**: Run tests, confirm they FAIL (red)
3. **Minimal implementation**: Write just enough code to pass
4. **Verify pass**: Run tests, confirm they PASS (green)
5. **Refactor**: Clean up, keep tests green
6. **No skipping**: Never write implementation without failing test first
7. **Evidence-first for non-code/live units**: Units whose output is evidence, live verification, release operations, docs lessons, cleanup, or continuation state do not create artificial red tests. They must instead save command output, API responses, screenshots, design-review artifacts, or state-file diffs that prove acceptance. If a non-code/live unit discovers a code or script defect, create or update the paired red-test unit before implementing the fix.

## Work Units

### Legend
⬜ Not started · 🔄 In progress · ✅ Done · ❌ Blocked

**CRITICAL: Every unit header MUST start with status emoji (⬜ for new units).**

### ✅ Unit 0a: Repo and Worktree Hygiene Evidence
**What**: Verify canonical checkout and active worktree state after retiring stale worktrees.
**Output**: `unit-0a-worktrees.log`, `unit-0a-main-status.log`, and stash list for preserved stale-worktree changes.
**Acceptance**: `git worktree list --porcelain` shows `/Users/arimendelow/Projects/spoonjoy-apple` on `main` plus this worktree only; both worktrees are clean except intentional task-doc edits.

### ✅ Unit 0b: TestFlight Feedback and Telemetry Intake
**What**: Pull latest feedback, feedback automation status, doctor output, reconcile dry-run, newest build metadata, beta detail, internal group build relationship, and tester count.
**Output**: Redacted JSON/text logs under `unit-0b-*`.
**Acceptance**: No actionable unhandled TestFlight feedback is ignored; any actionable item becomes an absurdity ledger entry or a concrete unit update. If `doctor` reports launchd listener/tunnel/reconcile paths that point at a retired worktree, Unit 0e must repair that before Unit 1 begins.

### ✅ Unit 0c: Baseline App Evidence Capture
**What**: Capture or attempt current route screenshots before fixes using the current harness, then record exact failures, blockers, and visible absurdities.
**Output**: Baseline screenshot artifacts or canonical blocker artifacts plus `absurdity-ledger.md`.
**Acceptance**: Every attempted route has a screenshot, a valid `design-review-blocked.json`, or a logged harness failure that feeds Unit 1; no visual claim is made without artifact evidence.

### ✅ Unit 0d: Autopilot State Refresh
**What**: Update `AUTOPILOT-STATE.md` with Unit 0 evidence, current branch state, latest feedback status, and next executable unit.
**Output**: Committed state-file update.
**Acceptance**: A resumed agent can continue at Unit 1a without rereading the chat.

### ✅ Unit 0e: Feedback Listener Path Repair
**What**: Repair installed launchd listener, tunnel, and reconcile service paths so they point at canonical `/Users/arimendelow/Projects/spoonjoy-apple` instead of any retired or temporary worktree, then restart/reload the services through `scripts/testflight-feedback-autopilot.mjs`.
**Output**: Before/after `doctor`, launchd, and health logs under `unit-0e-*`.
**Acceptance**: Running `scripts/testflight-feedback-autopilot.mjs doctor` from `/Users/arimendelow/Projects/spoonjoy-apple` reports healthy service paths, local health, and public health, or a valid external/human-only blocker records schema, owner action, retry command, output path, and evidence. This unit must complete before Unit 1.

### ✅ Unit 0f: Latest Feedback Gate After Repair
**What**: Re-run `status --plain`, `doctor`, and `reconcile --dry-run` after Unit 0e so the UI work starts from the repaired feedback loop.
**Output**: Redacted post-repair feedback logs under `unit-0f-*`.
**Acceptance**: No actionable feedback remains unhandled before Unit 1 begins.

### ✅ Unit 1a: Screenshot Matrix Timeout Contract — Tests
**What**: Add failing contract coverage for route-level timeouts in `scripts/capture-native-screenshot-matrix.sh` and timeout/blocker handling in `scripts/check-launch-screenshot-contract.rb`.
**Output**: Failing test/contract log proving a simulated hung route does not currently produce the required terminal blocker artifact.
**Acceptance**: The red failure names missing timeout/blocker behavior.

### ✅ Unit 1b: Screenshot Matrix Timeout Contract — Implementation
**What**: Add deterministic per-route timeout handling and route-level blocker recording to `scripts/capture-native-screenshot-matrix.sh`.
**Output**: Updated matrix script and contract fixtures.
**Acceptance**: Unit 1a tests pass; a simulated hung route records status `blocked` or `fail` with artifact paths instead of hanging the matrix.

### ✅ Unit 1c: Native Screenshot Launch Cleanup — Tests
**What**: Add failing tests for `scripts/capture-native-screenshots.sh` covering `simctl launch`, macOS launch/relaunch, proof wait, and cleanup timeout behavior.
**Output**: Failing test/contract log for missing launch cleanup or timeout behavior.
**Acceptance**: The red failure is tied to iOS/macOS launch or proof-wait behavior, not incidental missing tools.

### ✅ Unit 1d: Native Screenshot Launch Cleanup — Implementation
**What**: Implement fail-closed timeout and cleanup behavior in `scripts/capture-native-screenshots.sh` using existing `design-review-blocked.json` and blocker schema rules.
**Output**: Updated screenshot script and launch contract tests.
**Acceptance**: Unit 1c tests pass; a failed launch writes a valid blocker with capability, command, output path, reason, owner action, and skipped artifacts.

### ✅ Unit 1e: Local Validation Harness Integration
**What**: Integrate the new timeout/blocker behavior with `scripts/validate-native-local.sh` and artifact auditing.
**Output**: Validation matrix logs under `unit-1e-validation`.
**Acceptance**: `scripts/validate-native-local.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-validation` reaches a terminal pass or valid external/human-only blocker without silent hang.

### ✅ Unit 1f: Harness Visual QA Dogfood
**What**: Run `scripts/capture-native-screenshot-matrix.sh` after harness fixes and inspect route matrix artifacts.
**Output**: Screenshot matrix JSON, route artifacts, and harness-specific absurdity ledger updates.
**Acceptance**: Every route has screenshot evidence or a valid blocker; no local-code timeout/hang is accepted as a blocker.

### ✅ Unit 1g: Cookbook Detail Capture Contract — Tests
**What**: Add failing tests/contracts showing `scripts/capture-native-screenshot-matrix.sh` and `scripts/capture-native-screenshots.sh` must support a `cookbook-detail` route with a seeded cookbook id/state, matching `AppRoute.cookbookDetail`.
**Output**: Red contract log for unsupported `cookbook-detail` route capture.
**Acceptance**: Tests fail because `cookbook-detail` is unsupported or lacks route evidence before implementation.

### ✅ Unit 1h: Cookbook Detail Capture Contract — Implementation
**What**: Teach the screenshot harness and route matrix to capture Cookbook Detail on iOS/macOS with valid route state, app-emitted accessibility proof source, and design-review artifacts.
**Output**: Updated harness scripts/contracts and cookbook-detail route artifacts.
**Acceptance**: Unit 1g tests pass; `scripts/capture-native-screenshot-matrix.sh` includes `cookbook-detail` and produces screenshot evidence or a valid external/human-only blocker for that route.

### ✅ Unit 2a: Palette and Theme Token Contract — Tests
**What**: Add failing tests/static checks for banned system blue, raw color literals, and web-palette drift in primary SwiftUI surfaces.
**Output**: Red contract log covering `KitchenTableTheme`, `SpoonjoyToolbar`, `SpoonDock`, and primary route files.
**Acceptance**: Tests fail on current palette/token leakage.

### ✅ Unit 2b: Palette and Theme Token Contract — Implementation
**What**: Replace inappropriate system blue/raw colors with role-bound Spoonjoy theme tokens without changing route layout.
**Output**: Theme/token and small call-site updates.
**Acceptance**: Unit 2a tests pass; `scripts/check-native-web-palette-contract.rb` and `scripts/check-native-design-language.rb` pass.

### ✅ Unit 2c: Mobile Dock and Toolbar Contract — Tests
**What**: Add failing tests/static checks for mobile dock visual weight, safe-area behavior, macOS exclusion, icon/button sizing, and native toolbar expectations.
**Output**: Red contract log covering `SpoonDock.swift`, `PlatformNavigationView.swift`, and `SpoonjoyToolbar.swift`.
**Acceptance**: Tests fail on at least one current dock/toolbar weight or platform behavior issue.

### ✅ Unit 2d: Mobile Dock and Toolbar Contract — Implementation
**What**: Rebalance or replace mobile dock affordances with native-safe controls, reduce chrome dominance, preserve large targets, and keep macOS desktop-native.
**Output**: Updated shell/dock/toolbar code.
**Acceptance**: Unit 2c tests pass; no macOS primary route depends on mobile dock grammar.

### ✅ Unit 2e: Loading, Banner, and Transition Contract — Tests
**What**: Add failing tests for loading state honesty, no transient unavailable flashes, reduced-motion-aware transitions, and non-critical banner quietness.
**Output**: Red tests/contracts covering loading helpers, `OfflineStatusView`, route view models, and screenshot proof emitters.
**Acceptance**: Tests fail on a current false unavailable flash, loud non-critical status, or missing transition policy.

### ✅ Unit 2f: Loading, Banner, and Transition Contract — Implementation
**What**: Implement calm loading states, eager image/content transitions, reduced-motion-safe animations, and quiet severity-bound banners.
**Output**: Updated shared state/banner/loading components and route call sites.
**Acceptance**: Unit 2e tests pass; stale/offline/sync states are visible but do not visually dominate normal content.

### ✅ Unit 2g: Image and No-Photo Policy — Tests
**What**: Add failing tests/static checks for production-facing default images, "Chef photo"/"Imported photo" labels, fake food fallbacks, and missing appetizing no-photo states.
**Output**: Red tests/contracts over media models and route views.
**Acceptance**: Tests fail on current placeholder/default image language or behavior.

### ✅ Unit 2h: Image and No-Photo Policy — Implementation
**What**: Replace default/fake-looking image behavior with appetizing, honest no-photo states and clear capture/import affordances.
**Output**: Updated media/no-photo components and route usage.
**Acceptance**: Unit 2g tests pass; no production route presents a fake default image as real food.

### ✅ Unit 2i: Shared Substrate Coverage and Visual QA
**What**: Run shared substrate checks, coverage for new code, and full screenshot matrix focused on palette, dock/toolbar, loading, banners, images, text fit, and overlap.
**Output**: Coverage logs, route screenshots, design-review artifacts, and closed shared-substrate ledger items.
**Acceptance**: 100% coverage on new code; no warnings; automated design/accessibility contracts pass.

### ✅ Unit 3a: Kitchen and Recipes Structure — Tests
**What**: Add failing tests for `KitchenView` and `RecipesView` covering masthead, lead object, recipe index, cookbook shelf, list row language, empty/loading/offline states, and no unnecessary "Open" row labels.
**Output**: Red Swift/static tests for kitchen and recipes.
**Acceptance**: Tests fail on current route structure, language, or state gap.

### ✅ Unit 3b: Kitchen and Recipes Structure — Implementation
**What**: Rework Kitchen and Recipes surfaces to follow Spoonjoy cookbook hierarchy while preserving native navigation and search.
**Output**: Updated `KitchenView.swift`, `RecipesView.swift`, and supporting models/helpers.
**Acceptance**: Unit 3a tests pass; Kitchen/Recipes no longer show overlap, fake placeholders, or redundant index-line commands.

### ✅ Unit 3c: Kitchen and Recipes Visual QA
**What**: Capture and inspect Kitchen and Recipes on iOS/macOS, including narrow phone, large Dynamic Type, reduced motion, empty/loading/offline states.
**Output**: Screenshots, design-review artifacts, and closed ledger entries for Kitchen/Recipes.
**Acceptance**: No Kitchen/Recipes visual absurdity remains.

### ✅ Unit 3d: Recipe Detail Structure — Tests
**What**: Add failing tests for `RecipeDetailView` covering hero/provenance, yield controls, masthead actions, save/add/share/more, steps with per-step ingredients, cooks, loading, stale/offline, and missing recipe states.
**Output**: Red Swift/static tests for recipe detail.
**Acceptance**: Tests fail on a current recipe detail parity or loading-state issue.

### ✅ Unit 3e: Recipe Detail Structure — Implementation
**What**: Rework Recipe Detail to match web recipe structure and native action patterns without false unavailable flashes or crowded labels.
**Output**: Updated `RecipeDetailView.swift` and supporting models/helpers.
**Acceptance**: Unit 3d tests pass; navigation from search/list shows loading progress rather than transient unavailable copy.

### ✅ Unit 3f: Recipe Detail Visual QA
**What**: Capture and inspect Recipe Detail on iOS/macOS across normal, loading, stale/offline, missing-cover, and scaled-yield states.
**Output**: Screenshots, design-review artifacts, and closed ledger entries for Recipe Detail.
**Acceptance**: No recipe detail overlap, snap-in, false unavailable, or placeholder-image issue remains.

### ✅ Unit 3g: Cook Mode and Cook Log — Tests
**What**: Add failing tests for `CookModeView`, `KitchenSafeControls`, and `SpoonCookLogView` covering focused-step grammar, progress persistence, timers, ingredient use labels, controls, completion, and cook-log form layout.
**Output**: Red Swift/static tests for cook mode and cook logging.
**Acceptance**: Tests fail on current control crowding, unnecessary labels, persistence gap, or broken cook-log layout.

### ✅ Unit 3h: Cook Mode and Cook Log — Implementation
**What**: Rework cook mode and cook logging for kitchen-safe use: one focused step, large controls, calm timers, clear progress, and balanced log form.
**Output**: Updated cook-mode/log views and supporting models/helpers.
**Acceptance**: Unit 3g tests pass; the reported cook-mode breakages are absent: add-photo button text wrapping/hyphenation, center toggle floating without meaning, `Log Cook` button crowding, oversized empty media area, explanatory text card competing with the form, bottom dock overlap, dense top controls, and unstable layout across narrow phone and large Dynamic Type.

### ✅ Unit 3i: Cook Mode and Cook Log Visual QA
**What**: Manually exercise and capture cook mode and cook log in simulator and macOS, including progress changes, timers, reduced motion, and large Dynamic Type.
**Output**: Screenshots, design-review artifacts, and closed cook-mode ledger entries.
**Acceptance**: Cook mode is usable without dense clusters, overlap, or visually unstable controls.

### ⬜ Unit 3j: Cookbooks and Cookbook Detail — Tests
**What**: Add failing tests for `CookbooksView`, cookbook detail route behavior, cookbook shelf/index grammar, cookbook cover/no-photo policy, recipe membership rows, empty/loading/offline states, and native navigation from Kitchen/Search.
**Output**: Red Swift/static tests for cookbooks and cookbook detail.
**Acceptance**: Tests fail on a current cookbook route structure, language, navigation, image, or state gap.

### ⬜ Unit 3k: Cookbooks and Cookbook Detail — Implementation
**What**: Rework Cookbooks and Cookbook Detail as native cookbook objects with Spoonjoy shelf/spread language, balanced cover treatment, honest empty/offline states, and stable recipe membership navigation.
**Output**: Updated cookbook views/models/helpers.
**Acceptance**: Unit 3j tests pass; Cookbooks/Cookbook Detail no longer look like generic grids or omit the native cookbook hierarchy.

### ⬜ Unit 3l: Cookbooks and Cookbook Detail Visual QA
**What**: Capture and inspect Cookbooks and Cookbook Detail on iOS/macOS across normal, empty, loading, missing-cover, and offline states.
**Output**: Screenshots, design-review artifacts, and closed cookbook ledger entries.
**Acceptance**: No cookbook route overlap, fake cover, generic-card dominance, or navigation dead end remains.

### ⬜ Unit 4a: Shopping Workflow — Tests
**What**: Add failing tests for shopping receipt grammar, grouped/source-aware rows, duplicate handling, check targets, edit mode, offline queue state, and all-complete/empty states.
**Output**: Red tests over `ShoppingListView`, `ReceiptListView`, shopping models, and surface contracts.
**Acceptance**: Tests fail on at least one current shopping workflow gap.

### ⬜ Unit 4b: Shopping Workflow — Implementation
**What**: Rework shopping into a store-run receipt/list tool with native list/edit affordances and honest offline queue visibility.
**Output**: Updated shopping views/models/helpers.
**Acceptance**: Unit 4a tests pass; shopping rows are balanced, tappable, and source-aware without generic card clutter.

### ⬜ Unit 4c: Shopping Workflow Visual QA
**What**: Capture and inspect Shopping normal, empty, checked/all-complete, duplicate, offline queued, and conflict states on iOS/macOS.
**Output**: Screenshots, design-review artifacts, and closed shopping ledger entries.
**Acceptance**: No shopping crowding, placeholder, or state-honesty issue remains.

### ⬜ Unit 4d: Search Workflow — Tests
**What**: Add failing tests for native `.searchable` scopes, typed rows, result grouping, no-results copy, deep-link/result navigation, and search screenshot proof artifacts.
**Output**: Red tests over `SearchView`, search models, and screenshot proof contracts.
**Acceptance**: Tests fail on a current search scope/proof/navigation gap.

### ⬜ Unit 4e: Search Workflow — Implementation
**What**: Rework search as a cookbook index with native scopes and stable result navigation.
**Output**: Updated search view/models/helpers.
**Acceptance**: Unit 4d tests pass; search does not navigate through false unavailable states.

### ⬜ Unit 4f: Search Workflow Visual QA
**What**: Capture and inspect Search across empty query, typed query, no results, recipe results, cookbook results, chef results, and shopping-list scope.
**Output**: Screenshots, design-review artifacts, and closed search ledger entries.
**Acceptance**: Search uses native scopes, typed rows, compact object rows, stable result grouping, no-results copy that names the active scope, and direct navigation to recipe/cookbook/profile/shopping results without false unavailable flashes.

### ⬜ Unit 4g: Capture and Import Workflow — Tests
**What**: Add failing tests for capture draft lifecycle, MCP/agent import language, Share Sheet/App Intents/Siri future affordance truthfulness, offline retry, blocked-provider states, and no server-write claims before support exists.
**Output**: Red tests over `CaptureDraftView`, capture models, and import intent contracts.
**Acceptance**: Tests fail on current capture/import truthfulness or dead-end behavior.

### ⬜ Unit 4h: Capture and Import Workflow — Implementation
**What**: Rework capture/import so only real current paths are presented, future native import paths are framed truthfully, drafts are retryable, and blockers are actionable.
**Output**: Updated capture/import views/models/helpers.
**Acceptance**: Unit 4g tests pass; no product-facing "Ouro draft" or fake import path remains.

### ⬜ Unit 4i: Capture and Import Visual QA
**What**: Capture and inspect Capture normal, empty, draft, offline retry, blocked-provider, and signed-out states on iOS/macOS.
**Output**: Screenshots, design-review artifacts, and closed capture ledger entries.
**Acceptance**: Capture has no dead ends or fake promise states.

### ⬜ Unit 4j: Settings and APNs Workflow — Tests
**What**: Add failing tests for quiet native settings rows/forms, auth/environment/offline status, notification/APNs states, profile settings, and Sign in with Apple failure visibility.
**Output**: Red tests over `SettingsView`, `NotificationAPNsSettingsView`, auth/session state, and settings proof contracts.
**Acceptance**: Tests fail on a current settings/APNs/auth visibility gap.

### ⬜ Unit 4k: Settings and APNs Workflow — Implementation
**What**: Rework settings/APNs/auth state as quiet native forms with clear validation, failure, and environment status.
**Output**: Updated settings/APNs/auth-facing views/models/helpers.
**Acceptance**: Unit 4j tests pass; settings communicates real state without debug-looking product copy.

### ⬜ Unit 4l: Settings and APNs Visual QA
**What**: Capture and inspect Settings, profile settings, notification settings, signed-out, denied/unknown/granted APNs, and offline/auth failure states.
**Output**: Screenshots, design-review artifacts, and closed settings ledger entries.
**Acceptance**: Settings/APNs has no generic grouped-card feel, overlap, or unverified state.

### ⬜ Unit 5a: App Intents Contract — Tests
**What**: Add failing tests for App Intents entity/action availability, iOS 27/macOS 27 baseline gates, no unsupported iOS 26 product scope, and intent output telemetry.
**Output**: Red tests over `SpoonjoyAppIntents.swift` and intent test files.
**Acceptance**: Tests fail on a concrete intent availability, telemetry, or contract gap.

### ⬜ Unit 5b: App Intents Contract — Implementation
**What**: Harden App Intents contracts, availability gates, and telemetry without changing user-facing route layouts.
**Output**: Updated App Intents code/tests.
**Acceptance**: Unit 5a tests pass; `scripts/check-app-intents-contract.rb` passes.

### ⬜ Unit 5c: Spotlight and Universal Links — Tests
**What**: Add failing tests for Spotlight indexing/purge, Universal Link routing, custom-scheme routing, and account/environment isolation.
**Output**: Red tests over `SpoonjoySpotlightIndexer.swift`, `DeepLinkRouter`, and spotlight/link tests.
**Acceptance**: Tests fail on a concrete indexing, purge, routing, or isolation gap.

### ⬜ Unit 5d: Spotlight and Universal Links — Implementation
**What**: Harden Spotlight and link behavior with observable route outcomes and clean purge semantics.
**Output**: Updated Spotlight/link code/tests.
**Acceptance**: Unit 5c tests pass; `scripts/validate-aasa.rb` and relevant scenario tests pass.

### ⬜ Unit 5e: Auth, OAuth, and Sign in with Apple Telemetry — Tests
**What**: Add failing tests for OAuth callback handling, Keychain/session restore, Sign in with Apple failure telemetry, token refresh, logout, no-secret logging, and user-visible auth state.
**Output**: Red tests over auth/session/telemetry code.
**Acceptance**: Tests fail on a concrete auth telemetry or state-honesty gap.

### ⬜ Unit 5f: Auth, OAuth, and Sign in with Apple Telemetry — Implementation
**What**: Implement missing auth telemetry and state handling while redacting secrets, private key paths, JWTs, passwords, and API key paths.
**Output**: Updated auth/session/telemetry code/tests.
**Acceptance**: Unit 5e tests pass; Sign in with Apple/OAuth failures are diagnosable from telemetry.

### ⬜ Unit 5g: Offline Queue and Accessibility Proof Telemetry — Tests
**What**: Add failing tests for offline queue telemetry, sync failure/conflict/blocker/destructive-confirmation state proof, and app-emitted screenshot accessibility proof fields.
**Output**: Red tests over offline/sync state and proof emitters.
**Acceptance**: Tests fail on a concrete offline proof or telemetry gap.

### ⬜ Unit 5h: Offline Queue and Accessibility Proof Telemetry — Implementation
**What**: Implement missing offline telemetry/proof fields and ensure screenshot proofs are emitted by the app, not fabricated by harnesses.
**Output**: Updated offline/proof code/tests.
**Acceptance**: Unit 5g tests pass; `scripts/check-design-accessibility-contract.rb` and `scripts/validate-design-review.rb` pass on generated artifacts.

### ⬜ Unit 5i: Native Integrations Coverage and Visual QA
**What**: Run integration coverage, scenario verifier, and visual capture of visible auth/offline/integration states.
**Output**: Coverage logs, scenario logs, screenshots, proof JSON, and redacted telemetry samples.
**Acceptance**: 100% coverage on new integration code; no secrets leak; failure states are visible and actionable.

### ⬜ Unit 5j: Native-Adjacent Surface Disposition
**What**: Evaluate Widgets, Watch, Live Activities/lock-screen-adjacent surfaces, Siri/App Intents, camera, Photos, OCR, barcode, and Foundation Models against Spoonjoy product materiality, platform availability, existing source support, and release risk.
**Output**: `unit-5j-native-adjacent-surface-disposition.md` with implement-now/no-op/future disposition, evidence, and tests/units created for any implement-now item.
**Acceptance**: Every native-adjacent surface named in Unit 5j has a disposition; no no-op is accepted without source/product rationale; any implement-now item is completed or routed to a concrete new red-test/implementation unit before release.

### ⬜ Unit 6a: Feedback Autopilot Status Contract — Tests
**What**: Add failing tests/fixtures for `scripts/testflight-feedback-autopilot.mjs status --plain`, `doctor`, `reconcile --dry-run`, and fixed-unconfirmed lifecycle clarity.
**Output**: Red script test logs.
**Acceptance**: Tests fail when fixed-unconfirmed feedback lacks build, confirmation, or next-action explanation.

### ⬜ Unit 6b: Feedback Autopilot Status Contract — Implementation
**What**: Improve feedback status and machine-readable output so agents and slugger can see feedback ID, build, diagnosis state, fix build, confirmation state, evidence paths, and next action.
**Output**: Updated feedback autopilot script/docs.
**Acceptance**: Unit 6a tests pass; no secrets printed.

### ⬜ Unit 6c: Feedback Event Handoff Contract — Tests
**What**: Add failing tests/fixtures for webhook event payloads, screenshot download records, slugger/Ouro handoff, tunnel/listener health, launchd stale-repo-path detection/repair, crash feedback, screenshot-only feedback, and duplicate feedback.
**Output**: Red script test logs.
**Acceptance**: Tests fail on a concrete handoff or ledger evidence gap.

### ⬜ Unit 6d: Feedback Event Handoff Contract — Implementation
**What**: Harden feedback event ledger, handoff payloads, and launchd install/repair behavior so slugger can notify the operator with useful state and route work to Codex without opacity, even after canonical repo paths change.
**Output**: Updated feedback autopilot script/docs and event payload fixtures.
**Acceptance**: Unit 6c tests pass; handoff records include evidence paths and deterministic event IDs; `doctor` no longer reports listener/tunnel/reconcile paths pointing at retired worktrees after repair.

### ⬜ Unit 6e: Feedback Autopilot Live Dogfood
**What**: From canonical `/Users/arimendelow/Projects/spoonjoy-apple`, run live `status --plain`, `doctor`, `reconcile --dry-run`, inspect event directories, and run a safe test/dry-run handoff if supported.
**Output**: Live logs and ledger proof saved under `unit-6e-*`.
**Acceptance**: The feedback loop is live and transparent, or a valid external/human-only blocker records schema, owner action, retry command, and evidence.

### ⬜ Unit 7a: macOS Shell Contract — Tests
**What**: Add failing tests/static checks for macOS split navigation, toolbar/menu behavior, keyboard commands, selected route restoration, and mobile dock exclusion.
**Output**: Red macOS shell contract logs.
**Acceptance**: Tests fail on at least one current desktop-native shell gap.

### ⬜ Unit 7b: macOS Shell Contract — Implementation
**What**: Rework macOS shell/navigation/toolbars/menus/keyboard affordances without changing route content.
**Output**: Updated macOS shell code/tests.
**Acceptance**: Unit 7a tests pass; macOS shell does not present as a stretched mobile app.

### ⬜ Unit 7c: macOS Route Adaptation — Tests
**What**: Add failing tests/static checks for desktop recipe/cookbook/search/import/settings route adaptations and window sizing.
**Output**: Red macOS route adaptation logs.
**Acceptance**: Tests fail on a concrete macOS route adaptation gap.

### ⬜ Unit 7d: macOS Route Adaptation — Implementation
**What**: Apply desktop-native route adaptations for Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Cookbook Detail, Shopping, Search, Capture, Settings, notification settings, and profile/settings-adjacent flows.
**Output**: Updated macOS route code/tests.
**Acceptance**: Unit 7c tests pass; each route named in Unit 7d has desktop navigation/layout evidence or a concrete follow-on ledger entry before Unit 7e visual QA begins.

### ⬜ Unit 7e: macOS Visual QA
**What**: Capture and inspect macOS Kitchen, Recipes, Recipe Detail, Cook Mode, Cookbooks, Shopping, Search, Capture, Settings, and notification settings.
**Output**: macOS screenshot set, design-review artifacts, and closed macOS ledger.
**Acceptance**: No macOS route remains mobile-stretched, overlapped, or generic-card dominant.

### ⬜ Unit 8a: Validation Inventory
**What**: Run current validation stack without adding new release guards, save logs, and identify exact missing or failing release-prep checks.
**Output**: `unit-8a-validation-inventory.md` plus raw logs.
**Acceptance**: Each failure/gap is classified as ready fix, valid external/human-only blocker, or out of scope with evidence.

### ⬜ Unit 8b: Release Guard Contract — Tests
**What**: Add failing tests/contracts only for concrete release-prep gaps found in Unit 8a: build number bumping, distribution kit checks, TestFlight dry-run preflight, no-secret output, or docs command drift.
**Output**: Red release-guard test logs.
**Acceptance**: Tests fail on named release-prep gaps from Unit 8a, not open-ended speculation.

### ⬜ Unit 8c: Release Guard Contract — Implementation
**What**: Fix release-prep gaps, bump the next TestFlight build number, and update release docs/metadata as required.
**Output**: Updated project/distribution/docs files.
**Acceptance**: Unit 8b tests pass; `scripts/check-apple-distribution-kit.sh` passes.

### ⬜ Unit 8d: Full Local Validation
**What**: Run full tests, coverage, scenario verifier, app bundle, iOS simulator smoke, macOS smoke, design/accessibility contract, screenshot route matrix, warning scan, and artifact audit.
**Output**: Complete validation logs under `unit-8d-*`.
**Acceptance**: All required validations pass; valid blockers are allowed only for external/human-only capabilities with schema, owner action, retry command, and evidence.

### ⬜ Unit 8e: Final Visual QA Dogfood
**What**: Final route-by-route iOS/macOS visual pass with screenshots, app-emitted proofs, and absurdity ledger closure.
**Output**: Final screenshot packet, design-review artifacts, and closed ledger.
**Acceptance**: No visual, loading, overlap, placeholder, copy, or app-language blocker remains.

### ⬜ Unit 8f: macOS Distribution Inventory
**What**: Inspect `distribution/apple-distribution.json`, `docs/apple-distribution.md`, Xcode schemes, Apple Distribution Kit capabilities, and App Store Connect API state for `app.spoonjoy.mac`.
**Output**: `unit-8f-macos-distribution-inventory.md` plus redacted ASC query logs.
**Acceptance**: The doc states whether macOS is publishable now, what channel/script/app IDs exist or are missing, and whether Unit 9i should publish macOS or record a valid source-backed blocker/no-op.

### ⬜ Unit 9a: PR and Cold Self-Review
**What**: Push branch, open PR, run independent cold self-review, address findings, and wait for required checks.
**Output**: PR URL, review verdict, CI/check evidence, and any fix commits.
**Acceptance**: PR is approved by sub-agent review, mergeable, and checks are green or proven unrelated/non-applicable.

### ⬜ Unit 9b: Merge and Main Verification
**What**: Merge PR to `main`, fetch/pull canonical checkout, and verify remote `main` contains the merge commit.
**Output**: Merge commit SHA and remote verification logs.
**Acceptance**: `origin/main` confirms the merged SHA; no open PR from this run remains.

### ⬜ Unit 9c: Archive and Export IPA
**What**: Run distribution kit check and package the iOS TestFlight IPA from `main`.
**Output**: `Spoonjoy.ipa`, archive/export logs, version/build number, and redacted distribution logs.
**Acceptance**: `build/apple/testflight/Spoonjoy.ipa` exists; packaging logs contain no secrets.

### ⬜ Unit 9d: Upload and Poll Build Processing
**What**: Upload IPA with the full documented Apple Distribution Kit altool command, including `--package-path build/apple/testflight/Spoonjoy.ipa`, App Store Connect API key id, issuer id, private key path read from local kit config without printing secrets, `--provider-public-id 9735080289`, `--platform ios`, and `--mode apply`; then poll newest build for `VALID`.
**Output**: Upload log, ASC app/build/buildBetaDetail IDs, and processing poll logs.
**Acceptance**: Newest uploaded iOS build for `app.spoonjoy` is `VALID`; build number/version match Unit 9c.

### ⬜ Unit 9e: Immediate Pre-Publish Feedback Reconciliation
**What**: Immediately before attaching the build to `Spoonjoy Internal`, re-run feedback `status --plain`, `doctor`, and `reconcile --dry-run` from canonical `/Users/arimendelow/Projects/spoonjoy-apple` and inspect newly arrived feedback/screenshots/crashes.
**Output**: Redacted pre-publish feedback logs under `unit-9e-*`.
**Acceptance**: No actionable unhandled feedback exists at the moment of publish; any new actionable feedback pauses publish and is routed to a concrete fix unit unless it is a valid external/human-only blocker.

### ⬜ Unit 9f: Internal TestFlight Publish
**What**: Run TestFlight publish dry-run, inspect blockers, fix fixable blockers, then run publish apply for `Spoonjoy Internal`.
**Output**: Dry-run/apply logs and publish plan artifact.
**Acceptance**: Build is attached to `Spoonjoy Internal`; no public App Store submission occurs.

### ⬜ Unit 9g: App Store Connect Final Verification
**What**: Verify internal group build relationship, beta tester count, build beta detail state, tester notification state, and feedback autopilot latest state through App Store Connect/API scripts.
**Output**: Final ASC verification JSON/logs and feedback status logs.
**Acceptance**: Group has the build, tester count is nonzero, `internalBuildState=IN_BETA_TESTING`, tester notification state is recorded, and no actionable unhandled feedback remains.

### ⬜ Unit 9h: Distributed TestFlight Install/Launch Smoke
**What**: Attempt to install and launch the distributed TestFlight build on an available eligible physical device through CLI/device tooling or another non-browser automated path; if unavailable, prove the missing device/account capability with a valid human-only/unavailable-hardware blocker.
**Output**: Device listing, install/launch/smoke logs, or blocker artifact under `unit-9h-*`.
**Acceptance**: The exact distributed build is install/launch smoked, or the blocker names the required human/device action, retry command, output path, and evidence. Simulator/local IPA smoke is not a substitute for this distributed-build check.

### ⬜ Unit 9i: macOS Distribution Disposition and Execution
**What**: Follow Unit 8f: if macOS is publishable with existing tooling and credentials, package/upload/publish/verify `app.spoonjoy.mac`; if not, record the source/App Store Connect evidence-backed blocker/no-op and keep macOS local smoke evidence from Unit 7/8.
**Output**: macOS publish logs and ASC IDs, or `unit-9i-macos-distribution-blocker.json` plus disposition note.
**Acceptance**: macOS distribution is either verified live through the configured Apple lane or explicitly dispositioned with exact missing script/channel/App Store Connect/capability evidence.

### ⬜ Unit 10a: Skill and Documentation Lessons
**What**: Update native app skill/docs with durable lessons from this run when they generalize beyond Spoonjoy.
**Output**: Skill/doc changes or an explicit no-op note in artifacts.
**Acceptance**: Any generalized lesson is encoded; single-case lessons are recorded in artifacts only.

### ⬜ Unit 10b: Cleanup and Worktree Retirement
**What**: Clean generated artifacts that should not persist, retire this worktree/branch if merged, verify canonical checkout is clean, and preserve recoverable stashes.
**Output**: Cleanup logs and final `git worktree list --porcelain`.
**Acceptance**: No stale worktree/branch from this run remains unless branch protection or external review is a valid hard blocker.

### ⬜ Unit 10c: Durable Continuation Scan
**What**: Update `AUTOPILOT-STATE.md`, scan task docs, feedback state, PRs, branches, worktrees, and validation logs for remaining ready work.
**Output**: Final continuation scan table.
**Acceptance**: No ready work remains under the mandate, or remaining work is classified as hard exception or out of scope with evidence.

## Execution
- **TDD strictly enforced**: tests → red → implement → green → refactor
- Commit after each phase (1a, 1b, 1c)
- Push after each unit complete
- Run full test suite before marking unit done
- Red-test units (`1a`, `1c`, `1g`, `2a`, `2c`, `2e`, `2g`, `3a`, `3d`, `3g`, `3j`, `4a`, `4d`, `4g`, `4j`, `5a`, `5c`, `5e`, `5g`, `6a`, `6c`, `7a`, `7c`, `8b`) are complete when the intended new tests fail for the expected reason and are committed. Do not require the full suite to pass until the paired implementation/coverage unit. Push red-test commits only when the repo convention permits; otherwise defer push until the paired green unit.
- Evidence/live/process units (`0a`, `0b`, `0c`, `0d`, `0e`, `0f`, visual QA units, live dogfood units, native-adjacent disposition, validation inventory, macOS distribution inventory, full local validation, PR/merge/upload/publish/verification units, distributed TestFlight smoke, macOS distribution disposition, docs lessons, cleanup, and continuation scan) are complete when their acceptance evidence is saved to artifacts and any discovered code defect is routed to a concrete red-test/implementation unit.
- For UI/rendering/layout units, run `visual-qa-dogfood` before declaring the unit or task complete
- **All artifacts**: Save outputs, logs, and data under `codex-native/tasks/2026-07-09-1243-doing-native-full-moon/` from the repo root, or the same absolute path in the canonical checkout when a unit explicitly runs there.
- **Fixes/blockers**: Spawn sub-agent immediately — don't ask, just do it
- **Decisions made**: Update docs immediately, commit right away
- **Canonical blockers**: Treat a blocker as acceptance only for external/human-only capabilities or genuinely unrecoverable shared-state operations. Local-code failures, script hangs, test failures, layout regressions, and missing telemetry are not acceptable blockers; fix them. Every accepted blocker must include schema, owner action, retry command, output path, and evidence.

## Progress Log
- 2026-07-09 12:49 Created from planning doc
- 2026-07-09 12:53 Granularity pass split broad buckets into route/workflow/release phases and tightened blocker eligibility
- 2026-07-09 12:55 Granularity Round 2 added cookbook route units and clarified red-test unit completion rules
- 2026-07-09 12:56 Granularity review converged
- 2026-07-09 12:59 Validation review converged
- 2026-07-09 13:00 Ambiguity pass made cook-mode, search, and macOS route acceptance concrete
- 2026-07-09 13:01 Ambiguity review converged
- 2026-07-09 13:02 Quality pass added evidence-first rule for non-code/live verification units
- 2026-07-09 13:03 Quality review converged
- 2026-07-09 13:04 Live feedback check found launchd services still pointing at retired `spoonjoy-apple-cookmode-ui-pass`; routed stale-service repair to Unit 6
- 2026-07-09 13:05 Scrutiny pass added front-loaded feedback-service repair, pre-publish feedback reconciliation, distributed TestFlight smoke, macOS distribution disposition, and native-adjacent surface disposition
- 2026-07-09 13:08 Scrutiny omission pass converged
- 2026-07-09 13:10 Scrutiny deception pass added cookbook-detail capture support units, full upload command requirements, canonical feedback command checkout, and explicit artifact root
- 2026-07-09 15:55 Unit 1g complete: added red screenshot harness contracts for `cookbook-detail`; red log proves missing matrix route, capture support, validator route support, `cookbook:cookbook_weeknights` state, durable cache seed, and `CookbookDetailView` accessibility proof.
- 2026-07-09 16:14 Unit 1h complete: implemented `cookbook-detail` route capture through the matrix, deep link/state/cache seed, design-review validation, and app-emitted `CookbookDetailView` accessibility proof; focused iOS/macOS capture passed with `design-review.json`, screenshots, and proof artifacts. Logged follow-up visual issues for duplicate cookbook summary/cover treatment and macOS horizontal balance.
- 2026-07-09 16:21 Unit 2a complete: expanded the native/web palette contract to scan SwiftUI app surfaces; red log proves 33 current `KitchenTableTheme` bypasses across 11 files, including `.secondary`, `.primary`, and `.red` foreground styles.
- 2026-07-09 16:27 Unit 2b complete: replaced the 33 app-surface palette bypasses with `KitchenTableTheme` role tokens. Palette and native design-language contracts passed; iOS no-sign target build and macOS target build passed with warnings-as-errors.
- 2026-07-09 16:33 Unit 2c complete: added native shell contract coverage for mobile dock chrome weight, centralized dock metrics, max width, target sizing, dark capsule avoidance, shadow weight, compact iOS-only dock use, safe-area placement, and toolbar primary action menu structure; red log fails on current overweight SpoonDock.
- 2026-07-09 16:45 Unit 2d complete: replaced overweight mobile `SpoonDock` chrome with centralized metrics, a narrower light glass/paper shell, quieter shadow, and metric-driven target sizing. Shell, palette, and design-language contracts passed; focused cook-mode screenshot capture passed on clean simulator retry with iOS/macOS screenshots, design-review, and accessibility proofs.
- 2026-07-09 16:53 Unit 2e complete: added a loading/transition contract for authored loading/error surfaces, no generic `unavailable` route copy, reduce-motion-aware search image loading, and quiet informational offline/stale status; red log names the current raw spinners, unavailable copy, fixed image animation, and brass quiet-status treatment.
- 2026-07-09 16:56 Unit 2f complete: added shared authored loading/error states, replaced guarded raw route spinners and generic unavailable copy, made search image transitions Reduce Motion aware, quieted informational offline/stale status, regenerated the Xcode project, and passed loading, palette, design-language, shell, Xcode project/generator, iOS no-sign, and macOS build checks.
- 2026-07-09 16:59 Unit 2g complete: added native image policy contract; red log proves bundled `RecipeFallback*` assets, title-hash fake food fallbacks, route-level bundled fallback image calls, search fallback thumbnails, visible row provenance noise, and production-facing `Chef photo` / `Imported photo` / `Editorialized chef photo` labels.
- 2026-07-09 17:10 Unit 2h complete: removed bundled recipe fallback image assets, replaced fake food fallback behavior with an authored `KitchenTableNoPhotoView`, removed route-level fallback asset calls and provenance row noise, renamed cover-source labels, and passed image policy, palette, design-language, loading, shell, Xcode project/generator, focused Swift tests, iOS no-sign, and macOS build checks.
- 2026-07-09 23:53 Unit 2i complete: closed shared substrate visual issues for tab/nav chrome, honest no-photo states, notification settings focus/copy, simulator resolver determinism, and stale screenshot evidence; Sagan cold review found two MINOR issues, both fixed; stale legacy no-photo call sites normalized; focused contracts, app-target builds, warning scan, and fresh 11-route iOS/macOS matrix passed.
- 2026-07-10 00:06 Unit 3a complete: added red Kitchen/Recipes structure contracts for web-aligned masthead/lead/index/shelf hierarchy, lead/index separation, index-row ordinal/metadata language, structured recipes loading/offline/empty states, and richer screenshot proof expectations; focused Swift contract and kitchen surface script both fail red with artifacts under `unit-3a/`.
- 2026-07-10 00:24 Unit 3b complete: implemented Kitchen/Recipes lead-plus-index hierarchy, removed redundant lead/index duplication and empty filler copy, added structured recipe empty/loading/offline states, refreshed screenshot accessibility proof expectations, and passed focused Kitchen/Recipes contracts, native mobile design contracts, static design contracts, full `swift test`, iOS/macOS app-target builds, warning scan, stale-source scan, and `git diff --check` with green evidence under `unit-3a/`.
- 2026-07-10 00:58 Unit 3c complete: captured Kitchen and Recipes on iOS/macOS, fixed the coverless Kitchen lead blank slab, removed duplicated Recipes route offline chrome/proof claims, tightened no-photo Recipes lead behavior, passed focused/static/full Swift/app-target/warning/stale-source checks, and received Confucius cold-review PASS with screenshot evidence under `unit-3c/`.
- 2026-07-10 01:06 Unit 3d complete: added red recipe-detail structure contracts for real-cover/no-photo metadata, log-cook action/read-surface parity, web-faithful masthead/source-proof anchors, stable route-state enum coverage, and `Save to Cookbook` sheet title; focused Swift runs fail red with compile evidence under `unit-3d/`.
- 2026-07-10 01:18 Unit 3e complete: implemented recipe-detail route-state loading/missing/failure handling, web-faithful masthead/media/no-photo/log-cook action, `Save to Cookbook` sheet title, and refreshed accessibility proof anchors; focused contracts, full Swift tests, static design contracts, iOS/macOS app-target builds, warning scan, and diff check passed with evidence under `unit-3d/`.
- 2026-07-10 01:34 Unit 3f complete: captured Recipe Detail on iOS and macOS, fixed macOS yield controls rendering as clipped slabs, reduced regular-width no-photo masthead weight, fixed Avicenna's direct detail-to-detail stale-route finding, cleaned generated build-log whitespace, and passed focused/full Swift tests, static design/palette contracts, iOS/macOS app-target builds, warning scan, design review, and screenshot inspection with evidence under `unit-3f/`.
- 2026-07-10 01:40 Unit 3g complete: added red source contracts covering cook-mode compact task structure, kitchen-safe control deck language, cook-mode SpoonDock center action clarity, and cook-log media/action-bar layout; focused run fails red with eight current blockers under `unit-3g/red-cook-mode-cook-log-source-contract.log`.
- 2026-07-10 01:55 Unit 3h complete: implemented kitchen-safe cook-mode and cook-log layout fixes: `Mark done` dock/control language, compact task header with separate cook-tools sheet, focused step card, quieter input/ingredient sections, balanced cook-log photo slot/action bar, and no decorative form panel. Focused source contract, affected Swift tests, design/accessibility contracts, iOS/macOS app-target builds, and warning scan passed with evidence under `unit-3g/`.
- 2026-07-10 02:43 Unit 3i complete: captured Cook Mode and Cooks on iOS/macOS, fixed duplicate cook-mode progress, regular-width floating tools, macOS stretched cook-mode controls, missing deterministic `cook-log` route proof, duplicate Cooks sheet heading, and the iOS medium-sheet regression that exposed the no-photo background. Final evidence: `unit-3i/cook-mode-after/`, `unit-3i/cook-log-final/`, `unit-3i/visual-absurdity-ledger.md`, focused contracts, full `swift test`, native scenario metadata, iOS/macOS app-target builds, and warning scans.
- 2026-07-09 13:11 Scrutiny deception review converged; doing doc ready for execution
- 2026-07-09 13:14 Unit 0a complete: saved worktree, main status, branch status, and preserved-stash evidence
- 2026-07-09 13:20 Unit 0b complete: saved feedback, webhook, latest build, beta detail, group, tester, and macOS ASC evidence; stale launchd repair required before Unit 1
