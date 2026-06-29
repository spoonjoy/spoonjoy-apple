# Unit 22b Open/Search/Share/Cook Siri Intents

## Implemented

- Added entity-backed App Intents for opening cookbooks, opening chef profiles, searching Spoonjoy, sharing recipes, sharing cookbooks, sharing the private shopping list transfer value, and continuing cook mode.
- Switched `OpenRecipeIntent` and `StartCookModeIntent` from string-ID resolution to `RecipeEntityDescriptor` resolver overloads.
- Added descriptor-based resolver overloads in `NativeIntentActionResolver` for open/search/share/cook flows, plus `NativeIntentShareValue` for manifest-classified public URLs and private transfer values.
- Hardened descriptor routes so recipe, cookbook, and profile App Intent actions validate safe IDs and expected route shape before opening or sharing.
- `ShareShoppingListIntent` returns the private transfer string as the App Intents result value while keeping it out of spoken dialog text.
- Added native capability metadata and scenario verifier evidence for the open/search/share/cook Siri intent family.
- Guarded route App Entity annotations behind iOS/macOS 27 availability so BootstrapDebug app targets build on the current Xcode 26.5 SDK while preserving 27+ App Entity behavior.

## Shortcut Budget Decision

Xcode App Intents metadata export failed when every intent was added as an `AppShortcut`; Apple enforces a hard limit of 10 App Shortcuts per app. The app now keeps all App Intents available, but reserves App Shortcut phrases for the 10 highest-value launch/share/cook/search/capture/add surfaces:

- `OpenRecipeIntent`
- `OpenCookbookIntent`
- `SearchSpoonjoyIntent`
- `ShareRecipeIntent`
- `ShareCookbookIntent`
- `ShareShoppingListIntent`
- `StartCookModeIntent`
- `ContinueCookModeIntent`
- `AddShoppingListItemIntent`
- `CaptureRecipeIntent`

Profile open, shopping checkoff, add-recipe-ingredients, clear-completed, and clear-all remain App Intents/Shortcuts-library actions without top-level App Shortcut phrases.

## Evidence

- `apple/unit-22b-open-search-share-cook-intents-green.log`
- `apple/unit-22b-open-search-share-cook-intents-app-intents-contract.log`
- `apple/unit-22b-open-search-share-cook-intents-spotlight-contract.log`
- `apple/unit-22b-open-search-share-cook-intents-native-scenario.log`
- `apple/unit-22b-open-search-share-cook-intents-affected.log`
- `apple/unit-22b-open-search-share-cook-intents-swift-full.log`
- `apple/unit-22b-open-search-share-cook-intents-xcodebuild-ios.log`
- `apple/unit-22b-open-search-share-cook-intents-xcodebuild-macos.log`
- `apple/unit-22b-open-search-share-cook-intents-warning-scan.log`
