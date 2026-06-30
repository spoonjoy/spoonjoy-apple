# Unit 22v Notification Siri Intents Review - Raman the 3rd

Verdict: No findings after review fixes. Unit 22v red contract is ready to mark done and commit.

Reviewed fixes:

- APNs/APNS invented intent names are blocked in both Swift and Ruby contracts.
- The extra AppIntent scanner catches `Notification`, `APNs`, `APNS`, and `Push` AppIntent names and allows only `ReadNotificationPreferencesIntent`, `UpdateNotificationPreferencesIntent`, and `OpenNotificationAPNsStatusIntent`.
- Forbidden capability tokens now apply to `NativeCapabilityMetadata.swift` and `ScenarioVerifier.swift` so metadata cannot advertise invented notification/APNs Siri surfaces.
- Notification preference update no longer requires manual `requestConfirmation`; it is aligned with existing non-destructive settings update behavior while still requiring authenticated execution/status handling.
- All three notification intents are library-only and forbidden from App Shortcut promotion.

Evidence reviewed:

- `apple/unit-22v-notification-intents-red.log`
- `apple/unit-22v-notification-intents-app-intents-contract-red.log`
