# Unit 21h Chef/Profile App Entities Integration Notes

## Needed Shared Paths

- `Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift`
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
- `Spoonjoy.xcodeproj/**`

## Expected Tokens/Tests

- `SpoonjoyChefProfileEntity`
- `SpoonjoyChefProfileEntityQuery`
- `ChefProfileEntityCatalog`
- `EntityStringQuery`
- `FileBackedNativeSyncStore`
- `NativeDurableCacheStore`
- `NativeIntentActionError.unresolvedChefProfileEntity`
- `scripts/check-app-intents-contract.rb --domain chef-profile`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter ChefProfileEntityTests`
- `scripts/verify-native-scenarios.sh --stage native-metadata`
- `scripts/check-xcode-project-contract.rb`
- iOS and macOS `BootstrapDebug` app-bundle builds

## Patch Sketch

The orchestrator applied the shared App Intents wrapper directly because `Apps/Spoonjoy/Shared/Native/**`, native capability metadata, scenario verifier checks, intent errors, and generated Xcode project membership are orchestrator-owned integration paths. The implementation wires chef/profile App Entities to cached sync/profile graph data, durable profile cache fallback, current account/environment scope, existing native profile routes, and public/profile-visible transfer summaries only. Tombstoned profile and recipe sync records are filtered before entity lookup, string search, and graph-derived suggestions.
