# Unit 3f Visual Absurdity Ledger

Surface: Recipe Detail (`recipe-detail`) on iOS simulator and native macOS app.

Final capture:
- iOS: `screenshots/ios-mobile.png`
- macOS: `screenshots/macos-desktop.png`
- Design review: `design-review.json`
- Accessibility proofs: `apple/unit-3f-recipe-detail-accessibility-proof-ios.json`, `apple/unit-3f-recipe-detail-accessibility-proof-macos.json`

Before capture:
- iOS: `before-yield-scale-fix/ios-mobile.png`
- macOS: `before-yield-scale-fix/macos-desktop.png`

## Items

### U3F-001 - macOS yield buttons rendered as huge clipped grey slabs

- Evidence: `before-yield-scale-fix/macos-desktop.png`
- Why broken: the minus and plus controls used platform default button styling inside a full-width selector, so macOS painted oversized grey button backgrounds that clipped at the window bottom and dominated the recipe.
- Disposition: fixed.
- Fix: `RecipeScaleSelector` now uses `.buttonStyle(.plain)` for the icon buttons and caps regular-width selector layout to `440` points.
- Verification: `screenshots/macos-desktop.png` shows balanced inline minus/plus controls with Steps visible below.

### U3F-002 - no-photo masthead had too much desktop weight

- Evidence: `before-yield-scale-fix/macos-desktop.png`
- Why broken: the honest no-photo state was visually useful, but too tall on desktop for a recipe with no cover, pushing the authored recipe identity and steps downward.
- Disposition: fixed.
- Fix: no-photo media height remains roomy on compact iOS and is reduced on regular-width layouts.
- Verification: `screenshots/macos-desktop.png` shows title, actions, yield, and the Steps header in the first viewport.

### U3F-003 - direct detail-to-detail route reuse could show stale recipe content

- Evidence: Avicenna cold review of `4e1de505..7e65dda9`.
- Why broken: a reused route view could retain a previous recipe while loading a different `recipeID`, and a new missing/failing ID could leave the old recipe visible indefinitely.
- Disposition: fixed.
- Fix: `loadRecipe()` now switches to loading whenever the visible recipe ID does not match the requested ID, and missing/failure states are allowed for that replacement load.
- Verification: focused source contract requires explicit current-recipe matching.

### U3F-004 - stale-cache warning appears on the capture fixture

- Evidence: `screenshots/ios-mobile.png`, `screenshots/macos-desktop.png`
- Why a user might notice: the warning is visible near the top of the route.
- Disposition: intentionally accepted for this fixture.
- Rationale: the Unit 3f fixture is deliberately exercising stale/offline route treatment. The banner is quiet, dismissible, does not occlude content, and validates the stale state rather than pretending the data is fresh.

## Final State

No `ready` or `needs reviewer gate` Unit 3f visual items remain.
