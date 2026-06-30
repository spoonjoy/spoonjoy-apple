# Unit 22w Dalton Review

## Findings

None. Dalton found no blocking or fix-required issues in the Unit 22w notification Siri intent changes.

## Checked

- Cache-backed notification preference reads fail closed when there is no cached notification-preference record.
- Partial Siri notification preference updates preserve omitted current values instead of defaulting them on.
- Static contracts allow only `ReadNotificationPreferencesIntent`, `UpdateNotificationPreferencesIntent`, and `OpenNotificationAPNsStatusIntent` for notification/APNs Siri surfaces.
- The new notification intents are library-only and do not consume App Shortcut budget slots.
- iOS and macOS Xcode logs compile `SpoonjoyAppIntents.swift`, run `ExtractAppIntentsMetadata`, write `Metadata.appintents`, and finish with `BUILD SUCCEEDED`.

## Residual Risks

- The generated `DerivedData/.../Metadata.appintents` files are build scratch and are not kept for direct inspection, so review relies on the Xcode logs plus static/scenario metadata checks.
- `SnapshotNotificationAPNsSurfaceRepository` still falls back to `.disabled` when there is no preference record. The Siri path now gates that correctly; future callers should not bypass the cached-preference guard.

## Verdict

CONVERGED
