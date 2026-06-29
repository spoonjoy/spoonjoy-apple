# Unit 22k Cookbook Siri Intents

## Shared Surfaces Updated

- `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
  - Adds library-only `CreateCookbookIntent`, `RenameCookbookIntent`, `DeleteCookbookIntent`, and `AddRecipeToCookbookIntent`.
  - Upgrades `RemoveRecipeFromCookbookIntent` to fetch the current account before queueing so cookbook membership removal is owner-safe.
  - Keeps public App Shortcuts at the existing budgeted set while adding the cookbook mutation family to `SpoonjoyIntentShortcutBudget`.
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
  - Adds owner-safe cookbook create, rename, delete, add-recipe, and remove-recipe resolvers.
  - Queues the same `NativeQueuedMutation` kinds used by the cookbook UI: `.cookbookCreate`, `.cookbookUpdate`, `.cookbookDelete`, `.cookbookAddRecipe`, and `.cookbookRemoveRecipe`.
  - Adds typed `emptyCookbookTitle` and `cookbookOwnershipRequired` errors for Siri/Shortcuts feedback.
- `Sources/SpoonjoyCore/Native/RecipeCookbookEntityCatalog.swift`
  - Carries `chefID` on `CookbookEntityDescriptor` so Siri cookbook mutations can verify ownership against the signed-in account.
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift` and `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
  - Register the cookbook Siri intent family in native capability metadata and scenario proof.

## Validation

- `apple/unit-22k-cookbook-intents-swift-focused.log`
- `apple/unit-22k-cookbook-intents-app-intents-contract.log`
- `apple/unit-22k-cookbook-intents-recipe-action-focused.log`
- `apple/unit-22k-cookbook-intents-open-share-focused.log`
- `apple/unit-22k-cookbook-intents-entity-focused.log`
- `apple/unit-22k-cookbook-intents-scenario-native-metadata.log`
- `apple/unit-22k-cookbook-intents-scenario-native-metadata.json`
- `apple/unit-22k-cookbook-intents-swift-full.log`
- `apple/unit-22k-cookbook-intents-project-contract.log`
- `apple/unit-22k-cookbook-intents-xcodebuild-ios.log`
- `apple/unit-22k-cookbook-intents-xcodebuild-macos.log`
