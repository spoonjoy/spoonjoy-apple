# Unit 3c Kitchen/Recipes Visual QA Ledger

## Surfaces
- Kitchen: iOS compact and macOS desktop, signed-in saved-copy fixture.
- Recipes: iOS compact and macOS desktop, signed-in catalog fixture.

## Findings
- Fixed: Kitchen no-photo lead used a tall blank paper hero area.
  Evidence before fix: `unit-3c/kitchen/screenshots/ios-mobile.png` and `unit-3c/kitchen/screenshots/macos-desktop.png` from the first capture showed a large empty lead panel above the recipe title.
  Fix: `RecipeLead.coverlessLead` now renders compact "Photo not added" metadata and no reserved 210pt blank media area.
  Evidence after fix: `unit-3c/kitchen/screenshots/ios-mobile.png` and `unit-3c/kitchen/screenshots/macos-desktop.png`.

- Fixed: Recipes proof claimed a route-local offline dismiss target and ordinal guard even though Recipes used shell-owned offline chrome and unnumbered recipe rows.
  Evidence: Parfit cold review of `d13e01e3..f9c4218c`.
  Fix: removed route-local `OfflineStatusView` from `RecipesView`; Recipes route proof now names lead/index/search/loading only, while shell offline proof remains global.
  Evidence after fix: `unit-3c/recipes/apple/unit-3c-recipes-accessibility-proof-ios.json` and `unit-3c/recipes/apple/unit-3c-recipes-accessibility-proof-macos.json`.

- Ready items: none.
- Needs reviewer gate: none.

## Visual Verdict
Kitchen and Recipes now show authored hierarchy, no obvious text overlap, no fake food imagery, no giant blank lead media, no duplicate route offline bar, and no stale "Open" row labels in the inspected first viewport.
