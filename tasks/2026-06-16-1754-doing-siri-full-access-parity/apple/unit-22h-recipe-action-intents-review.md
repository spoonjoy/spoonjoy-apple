CONVERGED

Unit 22h satisfies What/Output/Acceptance without expanding product scope. The diff adds the four recipe-action App Intents, keeps them library-only instead of public shortcut surfaces, and adds no comment/feed/mail/message/social product surface.

`ForkRecipeIntent`, `SaveRecipeToCookbookIntent`, `RemoveRecipeFromCookbookIntent`, and `DeleteRecipeIntent` take `SpoonjoyRecipeEntity`/`SpoonjoyCookbookEntity` parameters and route through `NativeIntentActionResolver` plus `SpoonjoyIntentStateWriter`, not string-ID parameters. The resolver emits `.nativeMutation` with `.recipeFork`, `.cookbookAddRecipe`, `.cookbookRemoveRecipe`, and `.recipeDelete`; `NativeQueuedMutation.requestBuilder()` already maps those kinds to the REST v1 recipe/cookbook paths used by the UI planners.

Destructive branches are HITL-gated: remove-from-cookbook and delete call `requestConfirmation()` before timestamp/action construction and queue writes. Delete reads `currentAccountID()` from the native writer and enforces `recipe.chefID == canonical currentChefID` before queueing `.recipeDelete`.

The shared writer appends native mutations and applies optimistic state only for shopping queueable kinds, so recipe/cookbook mutations are not pushed through shopping optimistic state. Native metadata, scenario verifier, scenario tests, and library-only registration are complete.

Validation evidence is green and warning-scan clean: focused Unit 22g test passes, app-intents contract is ok, native-metadata scenario log/json are ok, affected and full Swift suites pass, project/diff checks pass, iOS/macOS xcodebuild logs end `BUILD SUCCEEDED`, and warning scan is ok. No untested critical branch blocks Unit 22h; deeper measured coverage correctly belongs to Unit 22i.
