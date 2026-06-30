CONVERGED

Unit 21m is now a valid tests-only red unit. The Swift red log fails on missing spoon entity implementation types, chiefly `SpoonEntityCatalog` and related scope/purge types, not malformed existing APIs. The AppIntents contract red log also fails on missing spoon entity files plus the newly required live-store, sync-engine, foreground, metadata, scenario, project-membership, and Spotlight delete plumbing.

Coverage is adequate for this unit: it uses `RecipeDetailRecentSpoon`, `recentSpoons`, `.spoon` cached records, recipe relationship metadata, scoped identifiers, wrong-account/environment filtering, deleted/tombstoned filtering, safe transfer values, and purge plans. The patched static contracts now force real purge consumers: `NativeLiveAppStore`, `NativeSyncEngine`, `PlatformNavigationView`, and `SpoonjoySpotlightIndexer`.

No invented comments/feed/reactions/social surfaces found. Requiring spoon purge identifier/domain helpers is acceptable here; the diff only requires delete/purge plumbing and identifier helpers, not full Spotlight document indexing, so it does not steal Unit 21j/21k scope.
