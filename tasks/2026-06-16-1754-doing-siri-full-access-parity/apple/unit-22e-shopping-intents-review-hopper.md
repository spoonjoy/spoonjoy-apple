# Unit 22e Shopping Siri Intents Review - Hopper

## Verdict

CONVERGED.

## Evidence Checked

- Reviewed the Unit 22e diff for `SpoonjoyAppIntents.swift`, `NativeIntentAction.swift`, `NativeCapabilityMetadata.swift`, `ScenarioVerifier.swift`, `NativeScenarioTests.swift`, and the integration note.
- Confirmed `RemoveShoppingListItemIntent` uses `SpoonjoyShoppingItemEntity`, resolves via `resolvedShoppingItemID()`, and does not expose a string item-ID parameter.
- Confirmed remove, clear-completed, and clear-all call `requestConfirmation()` before timestamping, resolver construction, state writer application, mutation queue append, and donation.
- Confirmed `NativeIntentActionResolver.removeShoppingListItem` canonicalizes item IDs and creates `.shoppingDeleteItem` with a stable `intent-shopping-remove-...` client mutation ID, `.shoppingList` route, and `spoonjoy://shopping-list` URL.
- Confirmed destructive Siri writes continue through `SpoonjoyIntentStateWriter`, `FileBackedNativeSyncStore`, `trustedIntentScope`, and the shared native mutation queue/auth path.
- Confirmed no new public shopping-list URL/share/product surface was introduced; shopping writes deep-link to the private native shopping-list route and share policy remains private-transfer-only.
- Confirmed `RemoveShoppingListItemIntent` is registered in native capability metadata, scenario verifier source tokens, native scenario expected intents, and library-only shortcut metadata while the App Shortcut count remains 10.
- Checked green artifacts: `unit-22e-shopping-intents-green.log`, `unit-22e-shopping-intents-app-intents-contract.log`, `unit-22e-shopping-intents-native-scenario.log`, `unit-22e-shopping-intents-native-scenario.json`, `unit-22e-shopping-intents-affected.log`, `unit-22e-shopping-intents-swift-full.log`, `unit-22e-shopping-intents-project-contract.log`, `unit-22e-shopping-intents-diff-check.log`, and `unit-22e-shopping-intents-warning-scan.log`.
- Also checked supplemental iOS/macOS xcodebuild logs; both end in `BUILD SUCCEEDED` with App Intents metadata extraction.

## Residual Risks

- The focused dynamic resolver test still proves the new remove resolver primarily through source/static contracts rather than directly instantiating `removeShoppingListItem`; Unit 22f's declared coverage/refactor gate should close that measured resolver-coverage gap.
