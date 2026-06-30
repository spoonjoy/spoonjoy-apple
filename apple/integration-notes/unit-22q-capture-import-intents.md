# Unit 22q Capture Import Siri Intents

## Shared Surfaces Updated

- `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
  - Adds library-only `SubmitCaptureImportIntent`, `OpenCaptureDraftIntent`, and `DiscardCaptureDraftIntent`.
  - Keeps `CaptureRecipeIntent` as the public App Shortcut and adds a `requestValueDialog` for the source parameter.
  - Extends `SpoonjoyIntentStateWriter` so capture import submit records pending retry state without duplicate queue entries, and discard removes matching pending import mutations before clearing the local draft.
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
  - Adds entity-backed capture draft submit/open/discard resolvers with current-account ownership checks, OCR/readiness validation for submit, and local discard that does not fail when import source extraction is unavailable.
- `Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift`
  - Carries behavior-oriented `importableDraft` and `pendingImport` context on capture draft descriptors so Siri can submit/reuse/cancel the same work as the app UI.
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift` and `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
  - Register capture import Siri intents in native capability and scenario metadata.
- `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`
  - Includes capture draft entity source in the app integration typecheck that covers `SpoonjoyAppIntents.swift`.

## Validation

- `apple/unit-22q-capture-import-intents-green.log`
- `apple/unit-22q-capture-import-intents-app-intents-contract.log`
- `apple/unit-22q-capture-import-intents-native-scenario.log`
- `apple/unit-22q-capture-import-intents-native-scenario.json`
- `apple/unit-22q-capture-import-intents-affected.log`
