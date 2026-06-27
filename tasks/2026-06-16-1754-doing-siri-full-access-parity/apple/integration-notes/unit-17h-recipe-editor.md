# Unit 17h Recipe Editor Integration Notes

## Orchestrator-Applied Shared View

- `Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift` presents the native editor as a SwiftUI `Form` with system text fields, steppers, editable step sections, ingredient rows, reorder controls, conflict messaging, and destructive confirmation dialogs.
- `RecipeDetailView` now routes owner edit affordances to `.recipeEditor(id:)` instead of handing off to the web edit route.
- `PlatformNavigationView` resolves `.recipeEditor(id:)` for existing recipes and `.recipeEditor(id:nil)` for local create drafts, executes online editor requests through the live API transport, and awaits queued offline/fallback mutations through the app-level queue before closing the editor.
- `RecipeEditorView` computes a draft delta on save so visible step, ingredient, reorder, and delete edits become the corresponding native mutation plans instead of being dropped behind the recipe metadata save.

## Domain And Offline Behavior

- `RecipeEditorDraft` hydrates from cached/live `Recipe` data and maps native drafts to `RecipeWriteRequests` and `RecipeStepRequests` payloads.
- `RecipeEditorViewModel` owns validation, owner-only blocking, conflict pause state, native route identity, and action planning for create/update/delete recipes, step create/update/delete/reorder, ingredient add/delete, and output-use replacement.
- Online editor actions build exact REST v1 request builders plus offline fallback mutations for network-loss handoff. Offline editor actions build durable `NativeQueuedMutation` entries with the same client mutation IDs and object dependency keys used by the sync engine.
- Sync conflicts are preserved on `NativeShellContentState` and mapped back to the active recipe editor through the conflicted queued mutation, so the editor blocks local writes with the same conflict message as the global offline indicator.
- Multi-action saves are planned before execution and queued atomically when they include structural edits, so a later invalid action cannot follow an already-sent destructive mutation. Replacement ingredients delete the old row before adding the replacement so the existing duplicate-ingredient API guard is respected.
- Online structural batches report submitted, drained, remaining, and conflicted mutation IDs back to the editor. The editor closes only when the submitted batch fully drains or remains safely queued; a partial online drain/conflict stays on the editor with the conflict or queued-work indicator visible.
- Queued recipe mutations are replayed optimistically into restored cached recipes after restart, including step creates/deletes/reorders with output dependencies remapped by step identity and server ID remaps for newly created recipe, step, and nested ingredient records.
- Recipe-create and step-create ingredient ID remaps match successful API response ingredients back to the queued request ingredient shape instead of trusting response order, because the live recipe serializer returns ingredients sorted by name.
- Drained recipe editor mutations persist their resulting cache patch with the queue, so file-backed stores restore the server-confirmed recipe graph after app restart instead of only updating in-memory state.
- Immediate post-sync restores filter drained recipe-cache mutations out of the optimistic overlay after that cache patch is persisted, so successful structural online edits do not render duplicate steps or ingredients.
- Recipe-create payloads now preserve each draft step's `outputStepNums` in both direct REST builders and durable queued mutations, so new-recipe output dependencies do not disappear on save or replay.
- The web recipe-create API now accepts, validates, documents, and persists those create-time `outputStepNums`, so native create payloads are part of the live backend contract instead of a native-only optimistic shape.
- Ingredient quantity editing uses numeric text entry and validates the same `0.001...99,999` finite range as the web/API surface.
- ID remaps are field-aware: top-level resource identifier fields are rewritten after create responses, while arbitrary user-authored text in descriptions, source metadata, or nested recipe-create payload text is left untouched.
- ID remap extraction accepts both nested success-envelope objects and top-level recovery/helper response fields such as `recipeId`, `stepId`, and `ingredientId`.
- Offline-created recipe conflicts map through `NativeQueuedMutation.optimisticRecipeID`, so `recipe_local_<clientMutationID>` editor routes find the right conflicted create mutation.
- Conflict discard UI counts the queued same-recipe or locally-created-recipe mutations that will be removed, so dependent local work is not hidden behind a single-edit label.
- Severe states are not dismissible through the editor: non-owner writes, destructive actions without confirmation, validation errors, and conflicts all return blocked plans instead of hidden queued work.

## Route And Link Integration

- `AppRoute.recipeEditor(id:)` is now part of route state, selected recipe inference, and persisted route identifiers.
- Custom scheme routes support `spoonjoy://recipes/<id>/edit` and `spoonjoy://recipes/new/edit`.
- HTTPS `https://spoonjoy.app/recipes/<id>/edit` opens the native editor for existing recipes. The current web `/recipes/new` capture route remains capture-owned; no untested AASA route is claimed for native-only create drafts.
- Native capability metadata and scenario checks declare the same editor routes the deep-link router accepts: HTTPS existing-recipe edit, custom-scheme existing-recipe edit, and custom-scheme new-recipe edit.

## Project Membership

- `ruby scripts/generate-xcode-project.rb` was rerun after adding `RecipeEditorView.swift` and the core recipe-editor change planner.
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
- Final follow-up Unit 17i validation after Dalton, Euler, Kierkegaard, and Feynman review fixes:
  - targeted structural immediate-drain tests -> 3 tests pass, including successful step-create/ingredient-add duplicate replay prevention (`apple/unit-17i-recipe-editor-structural-fix.log`)
  - focused route/editor/store/sync/transport/API/metadata tests -> 23 tests pass (`apple/unit-17i-recipe-editor-focused-fix.log`)
  - remap sorted-response regression tests -> 4 tests pass (`apple/unit-17i-recipe-editor-remap-sort-fix.log`)
  - `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors` -> 260 Swift tests pass (`apple/unit-17i-recipe-editor-full-swift.log`)
  - `swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors` plus `ruby scripts/enforce-swift-coverage.rb --minimum 100 --include Sources/SpoonjoyCore` -> `coverage ok: 100.00% (10938/10938)` (`apple/unit-17i-recipe-editor-coverage-test.log`, `apple/unit-17i-recipe-editor-coverage-enforce.log`)
  - `scripts/verify-native-scenarios.sh --stage surfaces` -> `native scenario verification ok: surfaces` (`apple/unit-17i-recipe-editor-scenario-surfaces.log`, `apple/unit-17i-recipe-editor-scenario-surfaces.json`)
  - `ruby scripts/check-recipe-editor-surfaces.rb` -> pass (`apple/unit-17i-recipe-editor-surface.log`)
  - `ruby scripts/check-xcode-project-contract.rb` -> pass (`apple/unit-17i-recipe-editor-project-contract.log`)
  - `xcodebuild ... -scheme "Spoonjoy macOS" ... GCC_TREAT_WARNINGS_AS_ERRORS=YES build` -> `BUILD SUCCEEDED` (`apple/unit-17i-recipe-editor-xcodebuild-macos.log`)
  - `xcodebuild ... -scheme "Spoonjoy iOS" ... GCC_TREAT_WARNINGS_AS_ERRORS=YES build` -> canonical `XcodePlatform` blocker because the local iOS 26.5 platform/runtime is not installed (`apple/unit-17i-recipe-editor-xcodebuild-ios.log`, `apple/unit-17i-recipe-editor-xcodebuild-ios-blocker.json`)
  - accepted-log warning scan -> `warning scan ok` (`apple/unit-17i-recipe-editor-warning-scan.log`)
  - `git diff --check` -> pass (`apple/unit-17i-recipe-editor-diff-check.log`)
  - `spoonjoy-v2` focused API/create tests -> 19 tests pass (`web/unit-17i-api-create-output-vitest.log`)
  - `spoonjoy-v2` full coverage -> 322 files and 6,275 tests pass with 100% statements/branches/functions/lines (`web/unit-17i-api-create-output-full-coverage.log`)
  - `spoonjoy-v2` typecheck, warning scan, playground generation, and diff check -> pass (`web/unit-17i-api-create-output-typecheck.log`, `web/unit-17i-api-create-output-warning-scan.log`, `web/unit-17i-api-create-output-playground-generate.log`, `web/unit-17i-api-create-output-diff-check.log`)
