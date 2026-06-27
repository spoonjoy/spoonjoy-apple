# Unit 15b Sync Engine Integration Note

## Scope Applied

- Added the native sync bootstrap envelope, tombstone application, checkpoint model, file-backed sync snapshot store, staged-media sidecar resolver, full-domain `NativeMutationQueue`, queueable mutation factories, retry schedule/enforcement, trigger coordinator, sync transport protocol, and FIFO dependency-aware drain engine under `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`.
- Added `Sendable` conformance to immutable cursor wrappers so sync reports and checkpoints can cross actor boundaries cleanly.
- Updated `RecipeCoverVariant` with the current web/API `stylized` value; the older `illustration` value remains for compatibility with existing native model decoding.
- Updated native recipe step JSON to match the live web parser: initial recipe-create steps omit server-assigned `stepNum` and post-create `outputStepNums`, while recipe create, standalone step create, and standalone ingredient add mutations reject missing ingredient units before request construction.
- Fixed the Unit 15a red-test helper for multipart field parsing so filenames are not counted as form field names.

## AppState And Legacy Queue Boundary

- `Sources/SpoonjoyCore/AppState/**` was not changed in Unit 15b.
- The existing shopping-only `MutationQueue` remains intact for current snapshot compatibility.
- The new `NativeMutationQueue` and `FileBackedNativeSyncStore` are additive and durable for the full native/offline product contract; AppState bridging should move to them in the dedicated integration unit once UI/scenario surfaces are updated together.
- Media queue entries persist only staging metadata in the queue JSON. Upload bytes are restored after restart through `NativeStagedMediaDirectory`, which keeps raw local paths and signed URLs out of the queue snapshot.

## Scenario Verifier Boundary

- Scenario verifier commands were not changed in Unit 15b.
- The sync engine is validated at the core-contract level with focused tests for bootstrap request shape, file-backed queue/checkpoint/tombstone restore, staged-media byte rehydration, exact REST replay, local-only capture drafts, online-only refusal reasons, retry timing and `nextRetryAt` enforcement, trigger mapping, tombstone application, conflict retention, auth pause, and dependency-aware draining.

## Evidence

- `apple/unit-15b-sync-engine-green.log` records `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter NativeSyncEngineTests` with 15 focused tests passing.
- `apple/unit-15b-sync-engine-full-swift.log` records the full Swift suite with 174 tests passing.
- `apple/unit-15b-sync-engine-build.log` records a clean warnings-as-errors Swift build.
- `apple/unit-15b-sync-engine-warning-scan.log` records a clean diagnostic-pattern scan over the Unit 15b green/full/build logs.
