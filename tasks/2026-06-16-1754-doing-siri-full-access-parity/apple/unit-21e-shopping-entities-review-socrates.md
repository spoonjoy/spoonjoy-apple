# Unit 21e Shopping Entities Review - Socrates the 2nd

CONVERGED

- `SpotlightIndexPlan.swift` defines the indexed CoreSpotlight keys, and `ShoppingEntityCatalog.swift` now purges those same unique/domain identifiers, not colon-delimited AppEntity IDs.
- `SpoonjoySpotlightIndexer.swift` calls both `deleteSearchableItems(withIdentifiers:)` and `deleteSearchableItems(withDomainIdentifiers:)`.
- Purge paths cover logout/revoke, account switch, tombstones, cache deletes, and app-shell foreground forwarding.
- Tests assert the exact Spotlight identifier/domain contract in `ShoppingEntityTests`, `NativeSyncEngineTests`, and `NativeLiveStoreTests`.
- Final evidence is green: focused purge logs, App Intents contracts, project contract, full `swift test` with 431 tests, iOS/macOS `xcodebuild` success, clean `git diff --check`, and `unit-21e-shopping-entities-warning-scan-3.log` reports `matches: 0`.
