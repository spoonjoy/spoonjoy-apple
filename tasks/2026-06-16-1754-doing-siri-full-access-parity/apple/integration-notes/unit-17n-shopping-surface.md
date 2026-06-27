# Unit 17n Shopping Surface Integration Notes

## Applied Shared UI Wiring

- Added `ShoppingSurfaceViewModel` under `Sources/SpoonjoyCore/Features/Shopping/` as the core planner for live shopping list loading, queued-work summaries, conflict banners, confirmation prompts, online REST requests, and offline queued mutations.
- Replaced the old local-only shopping checkoff callback with `ShoppingSurfaceMutationPlan` execution in `PlatformNavigationView`.
- Wired the shopping route to show add item controls with optional quantity/unit, active/empty/offline states, checkoff toggles, swipe removal, clear completed, and clear all confirmations.
- Wired recipe detail and cook mode to add recipe ingredients to shopping through the same planner and scale factor path instead of a hardcoded local-only action.
- Added `recordShoppingList(_:)` and queued-shopping optimistic reducers so offline shopping edits update the live shell state durably and restore from the native sync queue.

## Scenario And Project Notes

- Shared SwiftUI files were modified in place, so no app-target file membership update was required for those files.
- The new core shopping feature file is part of the SwiftPM `SpoonjoyCore` target and is consumed by the Xcode app build through the local package product.
- `ScenarioVerifier` now proves shopping checkoff, item add, recipe-ingredient add, and destructive clear behavior in the surfaces report.
- `scripts/check-cook-shopping-surfaces.rb` requires the feature layer, shared shopping UI, recipe/cook add-to-shopping controls, route wiring, and scenario verifier shopping checks.

## Scope Boundaries Preserved

- Shopping parity stays inside the current product model: no comments, feeds, meal planning, or invented messaging surfaces were added.
- Public `spoonjoy.app` URL behavior remains limited to existing web routes. Shopping mutations are native app/UI actions or private API calls, not newly claimed public universal-link routes.
- Destructive shopping actions require native confirmation before planning local queue or remote requests.

## Review Fixes

- Kant found the initial shopping view stored its view model in local `@State`, so parent live-store updates could go stale. `ShoppingListView` now receives `ShoppingSurfaceViewModel` as an immutable input each render.
- Kant found offline shopping mutations were only local view edits. `NativeLiveAppStore.queueMutations` and restore now apply queued shopping mutations to the live content snapshot, and `recordShoppingList(_:)` records non-remote local updates.
- Kant found add-item UI could not send quantity/unit values. The route now includes separate item, quantity, and unit controls with positive finite quantity validation.
- Kant found online-to-offline fallback copy was wrong. Shopping actions now return `ShoppingSurfaceMutationOutcome`, letting UI show `Saved for sync` when an offline fallback is queued.
- Kant found recipe detail used a hardcoded 1x add-to-shopping action and did not reflect an in-list state. Recipe detail now exposes a scale stepper, disables the add button when ingredients are already present, and updates local state after a successful or queued add.
- Darwin found shopping add-item drains did not record server ID remaps, so dependent check/delete mutations could replay with `item_local_*` IDs. `NativeSyncEngine` now extracts add-item IDs from mutation responses, records `serverItemId`, rewrites dependent shopping item identifiers, and keeps that internal value out of outbound request bodies.
- Darwin found drained shopping mutations disappeared after an immediate online drain because only recipe drained overlays were persisted. `bootstrapAndDrain` now creates shopping cache patches from drained shopping mutations and `NativeLiveAppStore` filters those drained shopping mutations out of the immediate overlay only after the cache patch is applied.
- Pascal found recipe detail marked ingredients as in-list when any active item name matched. `RecipeShoppingListCoverage` now requires every non-empty recipe ingredient key, including normalized unit, to be present in active shopping items.
- Pascal found online shopping actions initially had no local acceptance path. `ShoppingSurfaceMutationExecutor` now returns an explicit synced/queued outcome while leaving successful remote requests to refresh from the server-canonical bootstrap response.
- Pascal found the add-item form cleared before `actionDidPlan` accepted the plan. `ShoppingAddItemFormState` now preserves the draft on blocked/failing submissions and clears only after the action has been accepted; `ShoppingListView` submits through a local form copy to satisfy SwiftUI actor isolation.
- Pascal found validation wording was stale after the review fixes. The scenario verifier and static contracts now prove recipe coverage without claiming invented sharing/comment surfaces, and the iOS build artifact was refreshed as a current `XcodePlatform` blocker.
- Turing and Goodall found the second pass still had shopping FIFO, conflict-scope, remote-clobber, add-from-recipe remap, stale-check, empty-list, and app-snapshot drain gaps. Shopping actions now queue behind existing shopping work, conflict banners are scoped to shopping queued mutations, remote success no longer records optimistic local IDs, add-from-recipe drains record `serverItemIds`, stale checks preserve the current list, empty synced lists render as loaded empty lists only after a real sync checkpoint, and live-store queueing seeds app-snapshot shopping items into the sync cache before immediate drains.
- Harvey and Lorentz found recipe detail and cook mode were still creating fake empty shopping planners, and add-from-recipe remaps were still positional. Recipe/cook add-to-shopping now receives the shell's real `ShoppingSurfaceViewModel`, the surface contract fails on fake planners, queued add-from-recipe mutations carry internal request ingredient descriptors, remaps match response items by normalized name/unit/scaled quantity, and those internal descriptors are excluded from outbound API bodies.
- Hegel and Bacon found the native shopping surface was ahead of the web API: add-from-recipe, clear-completed, and clear-all existed only as native request plans. Spoonjoy v2 now exposes those three API v1 routes with `shopping_list:write`, idempotent replay, OpenAPI schemas, generated playground support, connector/SDK inclusion, and docs.
- Ohm, Descartes, and Bacon found add-from-recipe still failed for duplicate/coalesced ingredients and uncached recipe descriptor replay. Native transport now remaps multiple optimistic recipe ingredient IDs to the same coalesced server row when the server aggregates matching name/unit quantities, and drained cache replay prefers queued ingredient descriptors before cached recipes.
- Gauss and Dewey found the new native shopping surface still had a Siri/App Intents gap, non-atomic web bulk mutation loops, stale checked-state semantics, and missing API telemetry/scope/docs coverage. The native App Intents layer now exposes shopping item check/uncheck, add recipe ingredients, clear completed, and clear all through the same native queued-mutation writer used by the app; clear-completed treats `checkedAt` as completed even when `checked` is stale; uncheck updates `updatedAt`; and Spoonjoy v2 batches add-from-recipe/clear writes through D1-compatible `$transaction([...ops])`, aggregates duplicate requested ingredients before writing, refreshes telemetry/idempotency operation mapping, separates destructive OpenAPI playground examples, and expands scope tests.
- `scripts/check-cook-shopping-surfaces.rb` now verifies the native shopping route components and, when the sibling `spoonjoy-v2` checkout is present, verifies the matching API v1 route declarations and router handlers so native cannot silently invent unsupported shopping routes again.

## Evidence

- `apple/unit-17n-shopping-review-fix-red.log`: focused reviewer-fix tests fail before the Darwin/Pascal fixes land.
- `apple/unit-17n-shopping-review-fix-green.log`: `ShoppingSurfaceParityTests`, `APITransportTests`, `NativeSyncEngineTests`, and `NativeLiveStoreTests` pass with warnings-as-errors after the review fixes.
- `apple/unit-17n-shopping-review-fix-full-swift-rerun.log`: full SwiftPM suite passes with warnings-as-errors, 275 tests in 22 suites.
- `apple/unit-17n-shopping-review-contracts-rerun.log`: surfaces scenario verifier, Xcode project contract, native design contract, kitchen/recipe contract, cook/shopping contract, and search/capture/settings contract pass.
- `apple/unit-17n-shopping-review-xcodebuild-macos-rerun.log`: `Spoonjoy macOS` BootstrapDebug app bundle build succeeds with `GCC_TREAT_WARNINGS_AS_ERRORS=YES`.
- `apple/unit-17n-shopping-review-xcodebuild-ios-blocker.json`: iOS app bundle validation is blocked by the local Xcode iOS simulator platform/runtime state; Xcode reports iOS 26.5 is not installed.
- `apple/unit-17n-shopping-review-warning-scan.log`: current reviewer-fix validation artifacts contain no warning diagnostics.
- `apple/unit-17n-shopping-review2-red.log`: focused reviewer2 tests reproduce the FIFO, conflict scoping, server-ID remap, stale-check, empty-list, and app-snapshot drain regressions before the second fix pass.
- `apple/unit-17n-shopping-review2-green.log`: `ShoppingSurfaceParityTests`, `APITransportTests`, `NativeSyncEngineTests`, and `NativeLiveStoreTests` pass after the second fix pass, 103 tests in 4 suites.
- `apple/unit-17n-shopping-review2-full-swift.log`: full SwiftPM suite passes with warnings-as-errors, 282 tests in 22 suites.
- `apple/unit-17n-shopping-review2-contracts.log`: surfaces scenario verifier, Xcode project contract, native design contract, kitchen/recipe contract, cook/shopping contract, and search/capture/settings contract pass.
- `apple/unit-17n-shopping-review2-xcodebuild-macos.log`: `Spoonjoy macOS` BootstrapDebug app bundle build succeeds with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` and App Intents metadata extraction.
- `apple/unit-17n-shopping-review2-ios-app-bundle-blocker.json`: iOS app bundle validation remains blocked by the local Xcode iOS simulator platform/runtime state; Xcode reports iOS 26.5 is not installed.
- `apple/unit-17n-shopping-review2-warning-scan.log`: current reviewer2 validation artifacts contain no warning diagnostics.
- `apple/unit-17n-shopping-review3-red.log`: reviewer3 probes reproduce fake recipe/cook shopping planners and positional add-from-recipe remaps before the fix.
- `apple/unit-17n-shopping-review3-fix-green.log`: the tightened cook/shopping surface contract and out-of-order add-from-recipe remap transport test pass after the fix.
- `apple/unit-17n-shopping-review3-focused.log`: `ShoppingSurfaceParityTests`, `APITransportTests`, `NativeSyncEngineTests`, and `NativeLiveStoreTests` pass after reviewer3 fixes, 103 tests in 4 suites.
- `apple/unit-17n-shopping-review3-full-swift.log`: full SwiftPM suite passes with warnings-as-errors, 282 tests in 22 suites.
- `apple/unit-17n-shopping-review3-contracts.log`: surfaces scenario verifier, Xcode project contract, native design contract, kitchen/recipe contract, cook/shopping contract, and search/capture/settings contract pass.
- `apple/unit-17n-shopping-review3-xcodebuild-macos.log`: `Spoonjoy macOS` BootstrapDebug app bundle build succeeds with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` and App Intents metadata extraction.
- `apple/unit-17n-shopping-review3-ios-app-bundle-blocker.json`: iOS app bundle validation remains blocked by the local Xcode iOS simulator platform/runtime state; Xcode reports iOS 26.5 is not installed.
- `apple/unit-17n-shopping-review3-warning-scan.log`: current reviewer3 validation artifacts contain no warning diagnostics.
- `apple/unit-17n-shopping-review4-red.log`: focused native tests reproduce duplicate/coalesced add-from-recipe remap and uncached descriptor replay gaps before the fix.
- `apple/unit-17n-shopping-review4-native-fix-green.log`: focused native transport/sync tests pass after duplicate remap and descriptor replay fixes.
- `apple/unit-17n-shopping-web-api-red.log`: web API v1 tests reproduce the missing add-from-recipe, clear-completed, and clear-all routes before the web fix.
- `apple/unit-17n-shopping-web-api-green.log` and `apple/unit-17n-shopping-web-api-routes-green2.log`: web shopping route tests pass after implementing the three API v1 routes.
- `apple/unit-17n-shopping-web-api-contract-green.log`: web OpenAPI, connector/SDK profile, generated playground source, and docs drift tests pass after publishing the new shopping operations.
- `apple/unit-17n-shopping-web-typecheck.log`: `pnpm typecheck` passes in `spoonjoy-v2`.
- `apple/unit-17n-shopping-web-build.log`: `pnpm build` passes in `spoonjoy-v2`.
- `apple/unit-17n-shopping-web-route-contract.log` and `apple/unit-17n-shopping-review4-contracts-rerun.log`: the cook/shopping surface contract passes and verifies native shopping routes against the sibling web API contract/router.
- `apple/unit-17n-shopping-review4-native-focused-green.log`: focused Apple transport, sync-engine, and shopping-surface tests pass, 67 Swift Testing tests in 3 suites.
- `apple/unit-17n-shopping-review4-full-swift.log`: full SwiftPM suite passes with warnings as errors, 284 Swift Testing tests in 22 suites.
- `apple/unit-17n-shopping-review4-xcodebuild-macos.log`: `Spoonjoy macOS` BootstrapDebug app bundle build succeeds with `GCC_TREAT_WARNINGS_AS_ERRORS=YES` and App Intents metadata extraction.
- `apple/unit-17n-shopping-review4-warning-scan.log`: current review4 native and web validation artifacts contain no warning diagnostics.
- `apple/unit-17n-shopping-review4-apple-diff-check.log` and `apple/unit-17n-shopping-web-diff-check.log`: `git diff --check` is clean in both repos after the review fixes.
- `apple/unit-17n-shopping-native-review-fixes-focused.log`: focused `KitchenStateTests`, `ShoppingSurfaceParityTests`, `NativeSyncEngineTests`, and `NativeScenarioTests` pass after the Siri/App Intents and stale shopping-state fixes, 81 Swift Testing tests.
- `apple/unit-17n-shopping-native-review-fixes-full-swift.log`: full SwiftPM suite passes with warnings as errors, 286 tests in 22 suites.
- `apple/unit-17n-shopping-web-review-fixes-focused-green.log`: focused Spoonjoy v2 shopping/API/OpenAPI/scopes/telemetry/playground tests pass after the web bulk-mutation and generated-contract fixes, 74 Vitest tests.
- `apple/unit-17n-shopping-web-review-fixes-sync-branch-gap.log`: focused shopping sync tests pass with missing/deleted recipe, existing-row, empty-recipe, empty-clear, null-unit, and null-quantity edge coverage, 12 Vitest tests.
- `apple/unit-17n-shopping-web-review-fixes-image-upload-flake.log`: `RecipeImageUpload` component tests pass after reducing valid mock-file size from 1MB to 1KB, 63 Vitest tests.
- `apple/unit-17n-shopping-web-review-fixes-typecheck.log`: `pnpm typecheck` passes in `spoonjoy-v2`.
- `apple/unit-17n-shopping-web-review-fixes-build.log`: `pnpm build` passes in `spoonjoy-v2`.
- `apple/unit-17n-shopping-web-review-fixes-coverage.log`: full Spoonjoy v2 coverage passes, 317 files and 6,271 tests with 100% statements, branches, functions, and lines.
- `apple/unit-17n-shopping-review-fixes-contracts.log` and `apple/unit-17n-shopping-review-fixes-search-capture-settings-contracts.log`: native cross-surface contracts pass after the shopping review fixes.
- `apple/unit-17n-shopping-review-fixes-xcodebuild-macos-bootstrap.log`: `Spoonjoy macOS` BootstrapDebug app bundle build succeeds.
- `apple/unit-17n-shopping-review-fixes-xcodebuild-ios-bootstrap-blocker.json`: iOS app bundle validation remains blocked by local Xcode platform/runtime state; Xcode reports iOS 26.5 is not installed.
- `apple/unit-17n-shopping-review-fixes-macos-launch-smoke.log`: the BootstrapDebug macOS app launches, produces a running `Spoonjoy.app/Contents/MacOS/Spoonjoy` process, and accepts quit.
- `apple/unit-17n-shopping-review-fixes-current-warning-scan.log`: current native/web validation artifacts contain no warning diagnostics.
- `apple/unit-17n-build-native-skill-validate.log`: `ouroboros-skills` validates after adding the App Intents mutation-matrix lesson to the build-native-apple-app skill and installed Codex copy.
- `apple/unit-17n-shopping-review5-slugger.md`: Slugger harsh review returned no blockers or major findings; design notes were recorded with dispositions.
- `apple/unit-17n-shopping-review-fixes-apple-diff-check-final.log` and `apple/unit-17n-shopping-review-fixes-web-diff-check-final.log`: final `git diff --check` artifacts are clean for both repos after the documentation refresh.
