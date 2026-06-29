# Unit 22q Capture Import Siri Intents Review

- Reviewer: Pascal the 3rd
- Scope: capture/import Siri App Intents, resolver, entity descriptor, state writer, metadata, scenario contracts, and validation logs
- Result: CONVERGED

## Findings Addressed

1. P1: Submit could duplicate an existing queued import when `pendingCaptureImport` was stale or missing because the writer only de-duped by `clientMutationID`.
   - Resolution: `SpoonjoyIntentStateWriter.appendNativeMutationIfNeeded` now reuses an existing `.recipeImportSubmit` mutation with the same `recipeImportSource`, and records the reused mutation in local pending import state.
2. P1: Discard cleared local draft state without purging stale capture draft Spotlight/AppEntity/donation surfaces.
   - Resolution: capture draft discard now builds a scoped `CaptureDraftEntityIndexPurgePlan.draftDiscardPurge` and calls `SpoonjoySpotlightIndexer().delete(...)` for searchable item, AppEntity, and donation cleanup. The purge is best-effort so a purge failure cannot make a completed local discard report failure.

Final reviewer response: `CONVERGED`.
