# Unit 21h Chef/Profile App Entities Review - Nash the 2nd

## Round 1

Nash returned `FINDINGS`.

- `MAJOR`: `ChefProfileEntityCatalog` read profile and recipe sync records without filtering `syncSnapshot.tombstones`, allowing stale tombstoned profile records to resolve and tombstoned recipe records to keep producing fellow-chef/kitchen-visitor suggestions.
- `MINOR`: Unit 21h required `apple/integration-notes/unit-21h-chef-profile-entities.md`, but the note artifact was absent.

## Fix Evidence

- Added tombstone regressions in `ChefProfileEntityTests`.
- `apple/unit-21h-review-fix-chef-profile-entities-red.log` proves the new regression failed before the catalog fix.
- `ChefProfileEntityCatalog` now filters profile records, durable profile cache records, recipe graph sources, and graph-derived chef rows against sync tombstones.
- Added `apple/integration-notes/unit-21h-chef-profile-entities.md`.
- Refreshed focused, full Swift, App Intents contract, project contract, scenario native metadata, iOS app build, macOS app build, and warning-scan artifacts.

## Round 2

Nash returned `CONVERGED`.
