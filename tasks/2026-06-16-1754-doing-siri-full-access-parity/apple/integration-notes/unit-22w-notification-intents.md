# Unit 22w Notification Intents

Implemented Siri/App Intents coverage for current notification preferences and APNs status without adding new notification product surfaces.

## Needed shared paths

- `Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift`
- `Sources/SpoonjoyCore/Native/NativeIntentAction.swift`
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
- `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`

## Expected tokens/tests

- `ReadNotificationPreferencesIntent`, `UpdateNotificationPreferencesIntent`, and `OpenNotificationAPNsStatusIntent` are library-only App Intents and registered in native capability metadata.
- `NativeIntentActionResolver` exposes `readNotificationPreferences`, `updateNotificationPreferences`, and `openNotificationAPNsStatus`.
- `SpoonjoyIntentStateWriter` restores notification/APNs surface data, maps settings connectivity to notification connectivity, executes notification actions, and applies `.notificationPreferenceUpdate` to the durable notification preference cache.
- Notification preference update uses `PATCH /api/v1/me/notification-preferences` through `NotificationAPNsActionPlanner`, queues `.notificationPreferenceUpdate` offline, and keeps APNs permission/device-token/register/revoke actions out of Siri.
- Partial Siri updates preserve current cached/live notification preference values instead of defaulting omitted toggles to enabled; cache-backed reads fail closed when Spoonjoy has no cached notification-preference record yet.
- APNs status opens Spoonjoy settings and surfaces `AppleDeveloperProgramBlocker.artifactFileName`/blocker state instead of claiming production push delivery.
- Green validation:
  - `apple/unit-22w-notification-intents-green.log`
  - `apple/unit-22w-notification-intents-app-intents-contract.log`
  - `apple/unit-22w-notification-intents-review-fix-red.log`
  - `apple/unit-22w-notification-intents-review-fix-green.log`
  - `apple/unit-22w-notification-intents-scenario-native-metadata.log`
  - `apple/unit-22w-notification-intents-project-contract.log`
  - `apple/unit-22w-notification-intents-xcodebuild-ios.log`
  - `apple/unit-22w-notification-intents-xcodebuild-macos.log`
  - `apple/unit-22w-notification-intents-warning-scan.log`
  - `apple/unit-22w-notification-intents-diff-check.log`
  - `apple/unit-22w-notification-intents-review-dalton.md`

## Patch sketch

- Added AppIntent structs for notification preference read/update and APNs status open, with optional preference parameters for update and no manual `requestConfirmation` for the non-destructive settings update.
- Added resolver result structs for notification summaries/actions, cache-read fail-closed behavior, partial-update merging, and preference updates through `NotificationAPNsActionPlanner`.
- Added typed queued-mutation access for notification preference updates so Siri/offline execution can update `NativeCacheDomain.notificationPreferences` with `.notificationPreferenceState`.
- Added a native metadata/scenario check named `Notification Siri intents` proving the three intent names, offline queue semantics, and Apple Developer Program APNs blocker handling.
- Preserved current-product boundaries: no AppIntent or resolver surface for APNs permission prompts, device-token acquisition, APNs device register/revoke, fake production push delivery, comments, social feeds, mail, or messaging.
- Dalton's harsh review returned `CONVERGED` after checking the prior offline no-cache and partial-update clobber findings.
