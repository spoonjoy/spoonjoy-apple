# Unit 21b Recipe/Cookbook App Entities

## Scope

- Added `RecipeCookbookEntityCatalog` in `SpoonjoyCore` as the testable bridge from persisted native sync cache records to Siri-visible recipe and cookbook entity descriptors.
- Added guarded app-target `SpoonjoyRecipeEntity`, `SpoonjoyCookbookEntity`, `SpoonjoyRecipeEntityQuery`, and `SpoonjoyCookbookEntityQuery`.
- Entity type/default-query metadata is immutable (`static let`) so the app target passes Swift 6 concurrency checks during Xcode module emission.
- Recipe intents resolve through `SpoonjoyRecipeEntity.resolvedRecipeID()` so default placeholder entities cannot open or queue work for a fake route.
- Batched identifier queries skip stale missing/tombstoned identifiers while preserving invalid-ID and wrong-scope failures.
- Replaced recipe string parameters in `OpenRecipeIntent`, `StartCookModeIntent`, and `AddRecipeIngredientsToShoppingListIntent` with `SpoonjoyRecipeEntity`.
- Regenerated `Spoonjoy.xcodeproj` so `SpoonjoyRecipeCookbookEntities.swift` is in both iOS and macOS app targets.

## Native Capability Metadata

- `NativeCapabilityMetadata.spoonjoy.appIntents` now lists the recipe/cookbook entity and query types in addition to intent types.
- `spotlightIndexedTypes` remains limited to the implemented Spotlight document types (`recipe`, `cookbook`, `shopping-list-item`); entity-specific Spotlight/App Shortcuts indexing stays owned by Unit 21k/21l.
- `ScenarioVerifier.nativeMetadataReport` now has a dedicated `recipe App Entity source` check that requires the guarded AppIntents entity source, `EntityStringQuery`, persisted sync-store lookup, and CoreTransferable import.

## Cache And Privacy Semantics

- Entity descriptors are built from `NativeSyncSnapshot.cachedRecords` full `Recipe` and `Cookbook` payloads.
- Durable-cache title-only placeholders are not used for Siri entity resolution.
- Catalog lookup is scoped by current account and environment; wrong-scope suggestions are empty and direct ID lookup throws.
- Recipe/cookbook tombstones exclude deleted entities from suggestions, direct lookup, and string search.
- Transfer values expose only public/user-visible fields: kind, id, title, chef username, route identifier, canonical URL, image URL, and summary. Debug/private fields stay empty.

## Validation

- `swift test -Xswiftc -warnings-as-errors --filter RecipeCookbookEntityTests`
- `scripts/check-app-intents-contract.rb --domain recipe-cookbook`
- `swift test -Xswiftc -warnings-as-errors --filter NativeScenarioTests`
- `scripts/verify-native-scenarios.sh --stage native-metadata`
- `ruby scripts/check-xcode-project-contract.rb`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `swift test -Xswiftc -warnings-as-errors`
- `scripts/fail-on-warning.rb` over the Unit 21b validation logs
