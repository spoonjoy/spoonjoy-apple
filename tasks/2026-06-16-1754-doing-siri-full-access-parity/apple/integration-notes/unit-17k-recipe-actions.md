# Unit 17k Recipe Actions Integration Notes

## Applied Shared UI Wiring

- Added `RecipeActionsViewModel` under `Sources/SpoonjoyCore/Features/RecipeActions/` as the core planner for recipe fork/make-variation, cookbook save, cookbook remove, and owner delete actions.
- Extended recipe-detail metadata with stable `RecipeDetailActionID` values, cookbook action options, saved cookbook IDs, shopping-list metadata, fork/make-variation labels, owner edit route, owner cover-controls route, and owner delete confirmation copy.
- Wired `RecipeDetailView` to expose native controls for start cooking, fork/make-variation, share, save/remove cookbook membership, manage covers, and owner delete with SwiftUI `.confirmationDialog`.
- Wired `PlatformNavigationView` to create `RecipeActionsViewModel`, run `performRecipeAction`, queue offline mutations, execute online actions through the existing authenticated `executeRecipeEditorRequest` transport, and queue the offline fallback if transport reports offline.
- Added `AppRoute.recipeCoverControls(id:)` with state restoration and `spoonjoy://recipes/{id}/covers` routing. The associated web routes remain limited to existing `spoonjoy.app` product URLs; no unsupported web cover-controls path was claimed.

## Scenario And Project Notes

- Existing app files were modified in place, so no Xcode source membership update was required for shared SwiftUI files.
- The new core source is part of the SwiftPM `SpoonjoyCore` target and is consumed by both SwiftPM tests and the Xcode app build through the package product.
- Scenario capability metadata consumes `DeepLinkManifest.routes`, so the new native cover-controls scheme route is included there without a bespoke verifier adapter.
- `scripts/check-kitchen-recipe-surfaces.rb`, `scripts/check-recipe-action-surfaces.rb`, and `scripts/check-xcode-project-contract.rb` all pass after the shared UI integration.

## Scope Boundaries Preserved

- Add-to-shopping remains metadata-only in this unit; the shopping mutation and recipe/cook shopping affordance behavior are owned by Units 17m-17o.
- The cover-controls route is now real and navigable, but the full cover-management workflow remains in the cover-control units rather than being invented here.
- No comments, feed, reactions, meal-planning, or new social surfaces were added.

## Review Fixes

- Rawls found the Unit 17j red contract did not pin online owner-delete REST behavior. The parity test now asserts `DELETE /api/v1/recipes/{id}?clientMutationId=...` with no JSON body for both online and queued replay paths.
- Rawls flagged implementation copy leaking sync internals. The delete prompt now says deletion syncs across devices instead of mentioning tombstones.
- The recipe-action surface checker now requires the actual SwiftUI `.confirmationDialog` modifier rather than a capitalized token.
- Ptolemy found native UI client mutation IDs could collide because the original ID used only action prefix and timestamp. The UI now appends a UUID while preserving a readable native prefix and timestamp.
- Ptolemy found cookbook actions could target duplicate saves or saved IDs outside the visible user cookbook set. The planner now requires the cookbook to be an available option, blocks duplicate saves, and blocks foreign/stale removals before planning REST or queued mutations.
- Ptolemy found save/remove buttons would remain stale after a successful action because they rendered only from immutable detail metadata. `RecipeDetailView` now keeps a local saved-cookbook overlay, feeds that overlay back into the planner, updates it on successful save/remove, and only navigates after fork/delete.

## Evidence

- `apple/unit-17k-recipe-actions-green.log`: `RecipeActionParityTests` pass with warnings-as-errors and `scripts/check-recipe-action-surfaces.rb` passes.
- `apple/unit-17k-recipe-actions-full-swift.log`: full SwiftPM suite passes with warnings-as-errors.
- `apple/unit-17k-recipe-actions-scenario-surfaces.log` and `apple/unit-17k-recipe-actions-scenario-surfaces.json`: surfaces scenario verifier passes with the updated native-only cover-controls route included in capability metadata.
- `apple/unit-17k-recipe-actions-surface-kitchen-recipe.log`: kitchen/recipe surface contract passes.
- `apple/unit-17k-recipe-actions-project-contract.log`: Xcode project contract passes.
- `apple/unit-17k-recipe-actions-xcodebuild-macos.log`: `Spoonjoy macOS` BootstrapDebug build succeeds.
- `apple/unit-17k-recipe-actions-warning-scan.log`: Unit 17k artifacts contain no warning/error/failure diagnostics.
