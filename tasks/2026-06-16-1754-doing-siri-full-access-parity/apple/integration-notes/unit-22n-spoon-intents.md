# Unit 22n Spoon Cook-Log Siri Intents Integration Note

## Summary

Unit 22n implements the spoon/cook-log App Intents introduced by Unit 22m as library-only Siri/Shortcuts actions:

- `LogCookIntent`
- `EditCookLogIntent`
- `DeleteCookLogIntent`
- `CreateCoverFromSpoonIntent`

These intents expose the existing cook-log product model to Siri without adding comments, feeds, mail, messaging, or any new social surface.

## Needed Shared Paths

- `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
- `Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift`
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`

## Behavioral Contract

`SpoonEntityDescriptor` now carries `chefID`, current note, next-time text, cooked-at timestamp, and photo URL so Siri-originated cook-log edits can enforce owner-only writes while preserving selected-row state for fields the user did not mention. `NativeIntentActionResolver` maps the new actions to the existing native offline mutation queue:

- log cook -> `.spoonCreate`
- edit cook log -> `.spoonUpdate`
- delete cook log -> `.spoonDelete`
- create cover from cook-log photo -> `.coverFromSpoon`

`LogCookIntent` defaults an omitted cooked-at value to the intent timestamp, matching the native Log Cook action's timestamp behavior. `EditCookLogIntent`, `DeleteCookLogIntent`, and `CreateCoverFromSpoonIntent` call `requestConfirmation()` before queueing destructive or recipe-affecting work. The resolver verifies current-account ownership before edit/delete, recipe ownership before using a spoon photo as a recipe cover, and rejects cover generation when the selected cook log has no photo URL.

## Expected Tokens and Tests

Unit 22m requires entity-backed parameters (`SpoonjoyRecipeEntity` and `SpoonjoySpoonEntity`), library-only intent registration under `SpoonjoyIntentShortcutBudget`, capability metadata registration, scenario metadata registration, and resolver methods that queue existing `NativeQueuedMutation` families.

Unit 22n adds behavioral request-body coverage for timestamp defaulting, partial edit preservation, coverless-spoon rejection, and cover-from-spoon queueing.

## Patch Sketch

The orchestrator applied the AppIntents, resolver, descriptor, metadata, and scenario-verifier changes directly. No visible AppShortcut was added, so the user-facing shortcut budget remains unchanged while Siri and Shortcuts can still discover these write actions in the app's intent library.

## Reviewer Gate

The first harsh review blocked on three behavior risks: partial Siri edits clearing omitted cook-log fields/photo, empty log-cook mutations without a cooked-at timestamp, and cover-from-spoon accepting cook logs without photos. The implementation was tightened and revalidated; the second harsh review returned no findings and `CONVERGED`.
