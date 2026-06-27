# Unit 18h Capture/Import Integration Notes

## Core Contracts

- `CaptureDraft` now models text, URL, share-sheet URL, camera image, photo-library image, JSON-LD, and video URL sources.
- Import-ready drafts produce `NativeMutationSource` payloads that flow through `NativeQueuedMutation.recipeImportSubmit` and the existing authenticated `POST /api/v1/recipes/import` request builder.
- Recipe-import queue entries expose their parsed `NativeMutationSource` so restored pending imports bind only to the currently visible draft source.
- Camera/photo image drafts without recognized text remain local and return `CaptureDraftImportReadiness.needsTextRecognition`.
- `CaptureImportViewModel` plans online request submission, offline retry queueing, provider-secret blocker display, imported recipe routing, and successful draft cleanup.
- `URLSessionNativeSyncTransport` returns typed provider-secret blockers for recipe import envelopes so the sync engine retains the blocked import without treating the whole session as auth-failed.

## Durable Native State

- `NativeAppSnapshot` records capture drafts, one pending capture import retry, and provider-secret import blocker metadata for restore across launches.
- Recording a replacement draft clears stale pending import retry/provider blocker metadata unless the existing queued import source still matches the draft.
- `NativeLiveAppStore` records/discards capture drafts, records import retry metadata, persists provider-secret blockers, executes authenticated import requests, and inserts returned imported recipes into current shell content.
- `PlatformNavigationView` routes capture draft changes into live-store persistence, queues offline import retries without duplicating an already-pending matching import, never discards provider-secret-blocked imports, removes matching queued imports before explicit draft discard, discards only verified drained retry mutations after manual retry, clears completed drafts, and navigates to imported recipe detail.

## Shared Capture UI

- `CaptureDraftView` is now a usable surface even with no existing draft.
- Native controls cover text, source URL, import URL, video URL, JSON-LD, photo library, camera draft, submit import, retry status, OCR-needed state, and discard.
- Photo-library and camera controls load real image bytes and run Vision OCR before a draft becomes import-ready.
- The view reconciles its local draft state from restored/drained parent app state so a completed or discarded import cannot remain visible as a stale local draft.
- Pending retry state disables replacement capture controls until the user retries, drains, or discards the visible draft.
- Draft IDs use UUIDs rather than Swift hash values.
- `Info.plist` includes camera and selected-photo usage descriptions.

## Scenario And Project

- `NativeCapabilityMetadata` advertises capture/import share actions and offline flows.
- `ScenarioVerifier` final checks now assert capture import submission, provider-secret blocker handling, and offline retry planning.
- `scripts/check-search-capture-settings-surfaces.rb` forbids the previous no-op capture handler, local-only copy, and blocker path that discarded queued provider-secret imports.
- New core files live under SwiftPM-discovered `Sources/SpoonjoyCore`; project membership remains covered by the existing generator/contract.

## Coverage Follow-Up

- Unit 18i covers the CI coverage gap for capture/import by exercising every persisted `NativeMutationSource` variant, malformed source decode paths, incomplete capture-draft source states, provider-secret default-resource fallbacks, non-provider/empty import responses, direct live-store import execution, durable draft retry/discard persistence, no-app-state provider blockers, broken app-state cleanup paths, accepted import transport envelopes without blockers, and the capture-import scenario failure path.
- Local validation for the follow-up is recorded under `apple/unit-18i-capture-import-*`: 13 focused capture/import tests, 341 full Swift tests, `Sources/SpoonjoyCore` coverage at `100.00% (14698/14698)`, green search/capture/settings surface and surfaces-scenario checks, a canonical local screenshot/design-review blocker for the missing iOS simulator platform, and `warning scan ok`.
