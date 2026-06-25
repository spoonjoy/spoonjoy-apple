# Unit 17h Recipe Editor Integration Notes

## Orchestrator-Applied Shared View

- `Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift` presents the native editor as a SwiftUI `Form` with system text fields, steppers, editable step sections, ingredient rows, reorder controls, conflict messaging, and destructive confirmation dialogs.
- `RecipeDetailView` now routes owner edit affordances to `.recipeEditor(id:)` instead of handing off to the web edit route.
- `PlatformNavigationView` resolves `.recipeEditor(id:)` for existing recipes and `.recipeEditor(id:nil)` for local create drafts, then hands planned queued mutations back to the existing app-level queue.

## Domain And Offline Behavior

- `RecipeEditorDraft` hydrates from cached/live `Recipe` data and maps native drafts to `RecipeWriteRequests` and `RecipeStepRequests` payloads.
- `RecipeEditorViewModel` owns validation, owner-only blocking, conflict pause state, native route identity, and action planning for create/update/delete recipes, step create/update/delete/reorder, ingredient add/delete, and output-use replacement.
- Online editor actions build exact REST v1 request builders. Offline editor actions build durable `NativeQueuedMutation` entries with the same client mutation IDs and object dependency keys used by the sync engine.
- Severe states are not dismissible through the editor: non-owner writes, destructive actions without confirmation, validation errors, and conflicts all return blocked plans instead of hidden queued work.

## Route And Link Integration

- `AppRoute.recipeEditor(id:)` is now part of route state, selected recipe inference, and persisted route identifiers.
- Custom scheme routes support `spoonjoy://recipes/<id>/edit` and `spoonjoy://recipes/new/edit`.
- HTTPS `https://spoonjoy.app/recipes/<id>/edit` opens the native editor for existing recipes. The current web `/recipes/new` capture route remains capture-owned; no untested AASA route is claimed for native-only create drafts.

## Project Membership

- `ruby scripts/generate-xcode-project.rb` was rerun after adding `RecipeEditorView.swift`.
- The generated project includes `RecipeEditorView.swift` in both iOS and macOS app source phases.
- Core recipe editor files live under `Sources/SpoonjoyCore/Features/RecipeEditor/**`, so SwiftPM picks them up without explicit package manifest changes.

## Product-Scope Boundaries

- Unit 17h intentionally does not add comments, social feeds, likes/reactions, meal planning, media playback, pantry inventory, or nutrition/fitness surfaces.
- Recipe sharing remains owned by the current/future sharing units; this unit only makes current recipe editing native and offline-capable.

## Verification

- `swift test --disable-xctest --filter RecipeEditorParityTests -Xswiftc -warnings-as-errors` -> 6 tests pass (`apple/unit-17h-recipe-editor-green.log`)
- `swift test --disable-xctest -Xswiftc -warnings-as-errors` -> 235 tests pass (`apple/unit-17h-recipe-editor-full-swift.log`)
- `swift build -Xswiftc -warnings-as-errors` -> pass (`apple/unit-17h-recipe-editor-build.log`)
- `ruby scripts/check-recipe-editor-surfaces.rb` -> pass (`apple/unit-17h-recipe-editor-surface.log`)
- `ruby scripts/check-xcode-project-contract.rb` -> pass (`apple/unit-17h-recipe-editor-project-contract.log`)
- `xcodebuild ... -scheme "Spoonjoy macOS" ... GCC_TREAT_WARNINGS_AS_ERRORS=YES build` -> `BUILD SUCCEEDED` (`apple/unit-17h-recipe-editor-xcodebuild-macos.log`)
- `xcodebuild ... -scheme "Spoonjoy iOS" ... GCC_TREAT_WARNINGS_AS_ERRORS=YES build` -> canonical `XcodePlatform` blocker because the local iOS 26.5 platform/runtime is not installed (`apple/unit-17h-recipe-editor-xcodebuild-ios.log`, `apple/unit-17h-recipe-editor-xcodebuild-ios-blocker.json`)
- Unit 17h accepted-log diagnostic scan -> `warning scan ok` (`apple/unit-17h-recipe-editor-warning-scan.log`)
