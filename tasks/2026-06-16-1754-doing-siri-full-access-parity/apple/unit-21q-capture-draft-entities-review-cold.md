CONVERGED

Cold review verdict: Unit 21q satisfies the Unit 21p contracts without obvious test weakening.

Reviewed the supplied review diff, integration note, current worktree, Unit 21p test file, implementation files, AppIntents contract log, focused green log, full Swift test log, project contract, scenario native metadata log, iOS/macOS xcodebuild logs, warning scan, and diff-check artifact. The artifacts are current on 2026-06-29 and the meaningful logs report green: focused capture-draft App Entity suite, `scripts/check-app-intents-contract.rb --domain capture-draft`, native metadata scenario verification, full `swift test`, xcode project contract, and iOS/macOS AppIntents metadata builds.

Implementation review found the expected behavior:

- `CaptureDraftEntityCatalog` resolves from scoped app snapshots and durable cache snapshots only, rejects wrong account/environment entity identifiers, filters malformed identifiers, and excludes `.imageAsset` cache records from entity reconstruction.
- Transfer data is built through `NativeSharePayload.privateCaptureDraft`, exposes only visible title/host/source metadata, and the tests cover non-leakage of raw text secrets, URL tokens, provider blocker resource IDs, account IDs, media identifiers, and debug fields.
- App Entity identifiers are account/environment-scoped, and Spotlight purge identifiers/domain identifiers are scoped and filtered before deletion.
- Logout, account/environment restore switch, draft discard, and record/cache-replacement purge paths are wired through `NativeLiveAppStore` to the app CoreSpotlight deletion surface in `SpoonjoyRootView`.
- The guarded `SpoonjoyCaptureDraftEntity`/query compiles in both iOS and macOS app targets and uses the shared app-state, sync-scope, and durable-cache stores rather than fixture data.
- The changes did not introduce a new product surface; they expose the existing capture draft model through App Entities.

No blocking findings.
