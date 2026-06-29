# Unit 21q Capture Draft App Entities Integration Notes

## Implemented

- Added `CaptureDraftEntityCatalog` in `Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift`.
- Added guarded `SpoonjoyCaptureDraftEntity` and `SpoonjoyCaptureDraftEntityQuery` in `Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift`.
- Added capture-draft Spotlight unique/domain identifier helpers for account/environment-scoped purge.
- Added `NativeCaptureDraftEntityIndexPurgeRequest` plumbing through `NativeLiveAppStore`, `PlatformNavigationView`, and `SpoonjoyRootView`.
- Updated native capability metadata and scenario verifier source checks for capture-draft App Entity registration.
- Regenerated `Spoonjoy.xcodeproj` so `SpoonjoyCaptureDraftEntities.swift` is in both iOS and macOS app targets.

## Privacy And Scope

- Capture draft entities resolve only from the current account/environment app snapshot or durable cache snapshot.
- Image-asset-only cached drafts are excluded from Siri/App Entity resolution so local media identifiers are not exposed.
- Transfer values use `NativeSharePayload.privateCaptureDraft`, preserving only user-visible summary/source-host metadata and excluding raw text, signed URLs, local media identifiers, provider blockers, account IDs, and debug fields.
- Logout, account/environment switch, draft discard, and capture-draft cache deletion all produce scoped purge requests for stale private entity indexes.
