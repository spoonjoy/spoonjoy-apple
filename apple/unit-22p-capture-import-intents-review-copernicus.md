# Unit 22p Capture Import Siri Intents Review

- Reviewer: Copernicus the 3rd
- Scope: `Tests/SpoonjoyCoreTests/CaptureImportIntentTests.swift`, `scripts/check-app-intents-contract.rb`, and `apple/unit-22p-capture-import-intents-*.log`
- Result: CONVERGED

## Findings Addressed

1. P1: Submit red contract initially forced a fresh offline `CaptureImportViewModel` plan and could allow duplicate `.recipeImportSubmit` queue entries.
   - Resolution: red contracts now require pending retry context (`pendingRetryMutation: draft.pendingImport`), `plan.offlineRetryMutation`, and state-writer queue de-duplication by `clientMutationID`.
2. P1: Discard red contract initially missed cancellation of matching pending recipe-import mutations.
   - Resolution: red contracts now require matching by `recipeImportSource == draftImportSource` and removing queued mutation IDs before clearing local draft state.
3. P1: Discard red contract briefly required throwing `try captureDraft.importSource()`, which would block discard for image drafts that still need OCR.
   - Resolution: red contracts now require optional `let draftImportSource = try? captureDraft.importSource()` so discard remains available for non-import-ready drafts.
4. P2: Entity payload contract was too tightly named around `draft`.
   - Resolution: red contracts now name behavior-oriented entity payload fields: `importableDraft` and `pendingImport`.

Final reviewer response: `CONVERGED`.
