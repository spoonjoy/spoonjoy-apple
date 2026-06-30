# Unit 22e Shopping Siri Intents Integration

## Summary

- Added first-class `RemoveShoppingListItemIntent` using `SpoonjoyShoppingItemEntity` and the native mutation queue.
- Routed Siri remove-item through `NativeIntentActionResolver.removeShoppingListItem`, producing `.shoppingDeleteItem` with the same `spoonjoy://shopping-list` destination as app UI shopping mutations.
- Added `requestConfirmation()` before remove-item, clear-completed, and clear-all Siri actions so destructive shopping mutations require system confirmation before the native queue write.
- Registered `RemoveShoppingListItemIntent` in native capability metadata, scenario metadata checks, and the library-only App Intent inventory while preserving the 10 App Shortcut budget.

## Validation

- `apple/unit-22e-shopping-intents-green.log`
- `apple/unit-22e-shopping-intents-app-intents-contract.log`
- `apple/unit-22e-shopping-intents-native-scenario.log` plus JSON
- `apple/unit-22e-shopping-intents-affected.log`
- `apple/unit-22e-shopping-intents-swift-full.log`
- `apple/unit-22e-shopping-intents-project-contract.log`
- `apple/unit-22e-shopping-intents-xcodebuild-ios.log`
- `apple/unit-22e-shopping-intents-xcodebuild-macos.log`
- `apple/unit-22e-shopping-intents-diff-check.log`
- `apple/unit-22e-shopping-intents-warning-scan.log`
