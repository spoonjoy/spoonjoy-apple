# Unit 22x - Notification Siri Intents Coverage

## Changes

- Added executable coverage for notification preference reads with cache-source data and no cached preferences in both offline and online connectivity states.
- Added partial Siri update coverage proving omitted notification toggles preserve their current server/cache values instead of defaulting to enabled.
- Added APNs blocker/status accessor coverage for notification intent actions.
- Added malformed durable `.notificationPreferenceUpdate` decode coverage so missing required preference fields fail closed.
- Added capture draft pending-import mismatch coverage so unrelated pending imports do not mark the visible draft as pending.
- Removed an unreachable duplicate queue-kind guard from `NativeIntentActionResolver.updateNotificationPreferences`; `NotificationAPNsActionPlanner` owns mutation-kind selection, and executable planner tests continue to prove `.notificationPreferenceUpdate` for online fallback and offline queueing.

## Validation

- `apple/unit-22x-notification-intents-swift-test.log`
- `apple/unit-22x-notification-intents-app-intents-contract.log`
- `apple/unit-22x-notification-intents-scenario-native-metadata.log`
- `apple/unit-22x-notification-intents-scenario-native-metadata.json`
- `apple/unit-22x-notification-intents-swift-full.log`
- `apple/unit-22x-notification-intents-coverage-test.log`
- `apple/unit-22x-notification-intents-coverage-enforce.log`
- `apple/unit-22x-notification-intents-project-contract.log`
- `apple/unit-22x-notification-intents-diff-check.log`
- `apple/unit-22x-notification-intents-warning-scan.log`

Coverage enforcement reports `coverage ok: 100.00% (24323/24323)` for `Sources/SpoonjoyCore`.
