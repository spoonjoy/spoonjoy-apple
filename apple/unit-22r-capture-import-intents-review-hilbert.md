# Unit 22r Capture Import Siri Intents Review - Hilbert the 3rd

Status: CONVERGED

Initial finding:
- P2: `NativeIntentAction.swift` force-unwrapped `plan.offlineRetryMutation`, which would crash if the capture import planner ever returned a malformed offline plan instead of surfacing `captureImportQueueUnavailable`.

Resolution:
- Restored the typed guard through `captureImportSubmitAction(from:draftID:)`.
- Added direct focused coverage for the `captureImportQueueUnavailable` path with an empty `CaptureImportPlan`.
- Updated the Swift and Ruby AppIntents contracts so the helper is part of the capture-import resolver contract.

Final review:
- Original P2 is resolved.
- No new blocker or major findings.
- Refreshed evidence is green: focused `CaptureImportIntentTests`, AppIntents contract, native metadata scenario, project/diff checks, full Swift suite with 484 tests, 100% coverage, and clean warning scan.
- Residual risk is minor only: the helper is internal mainly to make the invariant directly testable, but it does not expand the public API surface.
