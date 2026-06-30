CONVERGED

Reviewer: Cicero the 2nd

Scope: Unit 21r capture-draft App Entity coverage/refactor diff and artifacts.

Initial finding:

- P2 in `Tests/SpoonjoyCoreTests/NativeLiveStoreTests.swift`: the logout purge test only checked that the expected logout purge request was present, which would allow extra wrong-scope capture-draft purge requests.

Resolution verified:

- `liveStorePurgesCaptureDraftEntityIndexesOnLogout` now asserts exactly two allowed capture-draft purge requests by count plus membership: the cache-delete identifier-only purge from `recordCaptureDraft`, and the logout account-scope purge with the capture-draft domain.
- The regenerated review patch matches the current code diff.

Evidence checked:

- `unit-21r-capture-draft-entities-live-store-purge.log`
- `unit-21r-capture-draft-entities-swift-test.log`
- `unit-21r-capture-draft-entities-coverage-test.log`
- `unit-21r-capture-draft-entities-coverage-enforce.log`
- `unit-21r-capture-draft-entities-swift-full.log`
- `unit-21r-capture-draft-entities-warning-scan.log`
- `unit-21r-capture-draft-entities-diff-check.log`
- `unit-21r-capture-draft-entities-review-diff.patch`

Final result: no findings. Full Swift reports 448/448 tests passing and coverage enforcement reports 100.00%.
