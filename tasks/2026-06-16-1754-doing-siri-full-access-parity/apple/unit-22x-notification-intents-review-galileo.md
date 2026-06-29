# Unit 22x Notification Intents Review - Galileo

CONVERGED. No blocker or major findings.

The guard removal is safe: `NativeIntentActionResolver.updateNotificationPreferences` delegates queue-kind ownership to `NotificationAPNsActionPlanner`, which constructs `.notificationPreferenceUpdate` for `.updatePreferences` and returns it as either online fallback or offline queued mutation. The deleted resolver check was an unreachable duplicate rather than meaningful behavior.

Executable tests still prove the contract: `NotificationIntentTests` asserts online `PATCH /api/v1/me/notification-preferences` body shape with `.notificationPreferenceUpdate` fallback and offline `.notificationPreferenceUpdate` queueing.

The new coverage is meaningful: cache read fail-closed online/offline, APNs status accessors, partial merge preservation, malformed queued mutation fail-closed behavior, and capture-draft pending-import mismatch are all covered by executable tests.

Evidence checked:

- `apple/unit-22x-notification-intents-swift-test.log`: focused `NotificationIntentTests` passed 5 tests.
- `apple/unit-22x-notification-intents-app-intents-contract.log`: `app intents contract ok: notification-intents`.
- `apple/unit-22x-notification-intents-scenario-native-metadata.log` and JSON: native metadata scenario passed.
- `apple/unit-22x-notification-intents-swift-full.log`: 495 tests passed.
- `apple/unit-22x-notification-intents-coverage-enforce.log`: `coverage ok: 100.00% (24323/24323)`.
- `apple/unit-22x-notification-intents-project-contract.log`: project contract passed.
- `apple/unit-22x-notification-intents-warning-scan.log`: warning scan passed.
- `apple/unit-22x-notification-intents-diff-check.log`: clean.
- Doing doc and Unit 22x integration note are present/current.
