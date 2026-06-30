# Unit 23c Design Accessibility Review - Hegel

## First Pass

Hegel found one MAJOR issue: Search route evidence asserted invented VoiceOver labels (`Search scopes`, `Search results`) rather than labels actually present in `SearchView`.

## Resolution

- Replaced Search route evidence with source-backed tokens: `Search`, `row.accessibilityLabel`, `typed rows`, `SearchSurfaceSectionView buttons`, `SearchSurfaceContract.searchableScopes`, and `SearchSurfaceContract.typedRows`.
- Updated `ScreenshotAccessibilityProofWriter`, `scripts/validate-design-review.rb`, `scripts/capture-native-screenshots.sh`, and launch contract fakes to require the source-backed Search evidence.
- Added static contract tokens so the Search proof cannot drift back to non-source-backed labels.
- Reverted historical Unit 23b proof artifacts to their original app-emitted payloads instead of manually backfilling Unit 23c fields into old `writtenAt` evidence.

## Result

CONVERGED.
