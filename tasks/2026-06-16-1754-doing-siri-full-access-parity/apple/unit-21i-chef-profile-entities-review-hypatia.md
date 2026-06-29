# Unit 21i Chef/Profile Entities Review - Hypatia the 2nd

## Round 1

FINDINGS:

- BLOCKER: `Sources/SpoonjoyCore/Native/ChefProfileEntityCatalog.swift` reintroduced `ProfileGraphPage` rows without filtering tombstoned profile IDs, so stale cached graph pages could re-suggest deleted chefs.
- BLOCKER: `ownerProfileID` fell back to the first profile record when no record was explicitly `isOwner`, allowing recipe-derived graph suggestions to be invented under the wrong owner.

## Fix

- Added red regression artifact `unit-21i-review-fix-chef-profile-entities-red.log`.
- Filtered `ProfileGraphPage` rows through `tombstonedProfileIDs`.
- Changed recipe-derived graph ownership to require an explicit owner profile.
- Added compiled regressions for tombstoned graph-page rows and non-owner profile snapshots.
- Refreshed focused, full Swift, coverage, AppIntents, scenario, project, iOS/macOS build, diff-check, and warning-scan artifacts.

## Round 2

CONVERGED: Prior blockers are fixed: ProfileGraphPage rows filter tombstoned chef IDs, and recipe-derived graph suggestions require explicit `isOwner`. Red/green artifacts prove both regressions. Final matrix is current and green: focused 9 tests, full/coverage 457 tests, 100.00% coverage, AppIntents chef-profile, native-metadata, project contract, iOS/macOS builds, warning scan, and diff check all pass.
