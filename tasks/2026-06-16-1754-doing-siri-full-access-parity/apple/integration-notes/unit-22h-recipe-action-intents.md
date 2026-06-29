# Unit 22h Recipe Action Siri Intents Integration Note

## Summary

Unit 22h implements the recipe-action App Intents introduced by Unit 22g as library-only Siri/Shortcuts actions:

- `ForkRecipeIntent`
- `SaveRecipeToCookbookIntent`
- `RemoveRecipeFromCookbookIntent`
- `DeleteRecipeIntent`

The existing `AddRecipeIngredientsToShoppingListIntent` remains the recipe-context shopping bridge and continues to use the shopping mutation queue path.

## Shared Paths Updated

- `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
- `Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift`
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
- `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`
- `Tests/SpoonjoyCoreTests/OpenSearchShareCookIntentTests.swift`

## Behavioral Contract

Recipe descriptors now carry `chefID` so Siri can enforce owner-only recipe deletion without inventing a new account or comment surface. `NativeIntentActionResolver` now maps recipe actions to the same native mutation queue used by in-app UI:

- fork recipe -> `.recipeFork`
- save recipe to cookbook -> `.cookbookAddRecipe`
- remove recipe from cookbook -> `.cookbookRemoveRecipe`
- delete recipe -> `.recipeDelete`

`RemoveRecipeFromCookbookIntent` and `DeleteRecipeIntent` call `requestConfirmation()` before queueing destructive work. `DeleteRecipeIntent` reads the current account through `SpoonjoyIntentStateWriter.currentAccountID()` and the resolver rejects non-owner deletion with `NativeIntentActionError.recipeOwnershipRequired`.

`SpoonjoyIntentStateWriter` now accepts `.nativeMutation` actions, appends the durable native queued mutation, and applies only shopping-specific optimistic state for shopping queueable kinds. Recipe/cookbook writes remain queued for the native sync engine instead of fabricating local product surfaces.

## Scope Guardrails

No social feed, commenting, mail, or messaging surface was added. Recipe sharing remains handled by existing share/open/read pathways; this unit only implements current product-model recipe mutations through App Intents.

## Registration

The four new recipe-action intents are registered in native capability metadata and scenario verification. They are intentionally library-only so the visible App Shortcut budget remains unchanged.

## Validation Artifacts

- `apple/unit-22h-recipe-action-intents-green.log`
- `apple/unit-22h-recipe-action-intents-app-intents-contract.log`
- `apple/unit-22h-recipe-action-intents-native-scenario.log`
- `apple/unit-22h-recipe-action-intents-native-scenario.json`
- `apple/unit-22h-recipe-action-intents-affected.log`
- `apple/unit-22h-recipe-action-intents-swift-full.log`
- `apple/unit-22h-recipe-action-intents-project-contract.log`
- `apple/unit-22h-recipe-action-intents-diff-check.log`
- `apple/unit-22h-recipe-action-intents-xcodebuild-ios.log`
- `apple/unit-22h-recipe-action-intents-xcodebuild-macos.log`

