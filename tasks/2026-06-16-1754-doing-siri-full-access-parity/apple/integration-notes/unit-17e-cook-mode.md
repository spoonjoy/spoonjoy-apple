# Unit 17e Cook Mode Integration Notes

## Orchestrator-Applied Shared View

- `Apps/Spoonjoy/Shared/Views/CookModeView.swift` now consumes `CookModeViewModel` for step labels, recipe/page checkoff counts, scaled ingredient rows, step-output dependency rows, and duration-derived timers.
- `ScaleSelector` is a native `Stepper`; ingredient and dependency completion are native `Toggle` controls. Timer state is deliberately view-local and duration-derived from the active step, not persisted in `CookModeProgress`.
- `CookModeRouteView` normalizes any restored progress against the loaded recipe before presenting the view, so legacy cache payloads gain current recipe ingredient/dependency bounds before a user toggles anything.
- `CookModeView` also re-normalizes its local progress state when the loaded recipe shape changes. Placeholder recipes with no steps are not used for normalization, preserving legacy `currentStepID` until the full recipe arrives.

## Domain And Persistence

- `CookModeProgress` now persists `scaleFactor`, `checkedIngredientIDs`, and `checkedStepOutputUseIDs` with recipe-bounded restore and stale ID filtering.
- `NativeLiveAppStore.recordCookProgress(_:)` stores exact cook progress in `NativeAppSnapshot` and updates the in-memory shell state. This does not enqueue a remote sync mutation.
- `NativeShellContentState.restoredCookProgress` treats the app snapshot as authoritative when both rich app state and legacy durable cache cook-progress records exist, preventing the lossy legacy record from overwriting scale/checkoff state.
- A legacy current-step-only progress snapshot can be rehydrated against a full recipe, preserving the active step and enabling ingredient/dependency toggles after async recipe load.

## Route And Siri Handoff

- `NativeIntentActionResolver.continueCookMode(recipeID:)` maps to the same cook route and `spoonjoy://recipes/<id>/cook` URL as start cook mode after canonical recipe ID normalization.
- Existing deep-link routing already resolves `spoonjoy://recipes/<id>/cook`, `https://spoonjoy.app/recipes/<id>?mode=cook`, and `https://spoonjoy.app/recipes/<id>#cook` to `.recipeDetail(id:presentation:.cook)`; Unit 17d/17e tests prove that path.

## Scenario Verifier And Static Contracts

- No `ScenarioVerifier` source update was required in Unit 17e: the existing surfaces scenario already includes `CookModeRouteView`, and `scripts/check-cook-mode-parity-surfaces.rb` is the cook-mode-specific static gate for richer domain/view/native-view tokens.
- The static checker forbids web/social/meal-plan drift while requiring the new progress, view-model, Siri, scale, timer, and toggle surfaces.

## Project Membership

- No `.pbxproj` membership update was required because `CookModeView.swift` and the touched app shell files were already part of both app targets.
- macOS app validation compiled the shared SwiftUI files through the `Spoonjoy macOS` scheme with warnings as errors. iOS app validation is blocked by local machine platform state: Xcode 26.5 is installed, but the iOS 26.5 platform/runtime is missing.

## Verification

- `swift test --filter CookModeParityTests` -> 6 tests pass (`apple/unit-17e-cook-mode-green.log`)
- `swift test --filter NativeLiveStoreTests/signedOutLiveStoreRestoresDurableFallbackContentAndRecordsScopedRoutes` -> pass, including local cook-progress snapshot persistence and empty sync queue (`apple/unit-17e-live-store-progress.log`)
- `scripts/check-cook-mode-parity-surfaces.rb` -> pass (`apple/unit-17e-cook-mode-surface-green.log`)
- `swift build -Xswiftc -warnings-as-errors` -> pass (`apple/unit-17e-build.log`)
- `swift test` -> 228 tests pass (`apple/unit-17e-swift-test.log`)
- `xcodebuild ... -scheme "Spoonjoy macOS" ... GCC_TREAT_WARNINGS_AS_ERRORS=YES build` -> pass (`apple/unit-17e-xcodebuild-macos.log`)
- `xcodebuild ... -scheme "Spoonjoy iOS" ...` -> canonical `XcodePlatform` blocker for missing iOS 26.5 platform/runtime (`apple/unit-17e-xcodebuild-ios.log`, `apple/unit-17e-xcodebuild-ios-blocker.json`)
- `rg "warning:|Warning:"` over Unit 17e build/test/macOS artifacts -> none (`apple/unit-17e-warning-scan.log`)
