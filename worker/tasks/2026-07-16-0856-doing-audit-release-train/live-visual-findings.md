# Live Native Visual Findings

This ledger records fresh manual findings from real simulator/macOS pixels. A route is not visually accepted merely because screenshot generation and nonblank checks pass.

## Open

### My Recipes

- **iOS hierarchy duplication**: the navigation title and authored page heading both say `My Recipes`; the duplicated title competes with the empty-state hierarchy instead of behaving like one deliberate native surface.
- **iOS status chrome**: `Saved copy` plus a separate dismiss glyph consumes prominent top-of-page space for a passive state. Re-evaluate the single owner and placement of offline/cache status.
- **macOS sidebar truncation**: `Saved Recipes`, `Shopping List`, and `Kitchen Search` truncate despite abundant window width. The sidebar width and label layout fail the readable-navigation contract.
- **macOS empty-state weight**: the large blank canvas, duplicated title hierarchy, toolbar search field, and framed empty-state row do not yet feel proportionate as one composed native screen.

### Recipe Detail

- **iOS content occlusion**: the floating bottom dock visibly covers the next `YIELD` section and `Clear progress` content. The screenshot is nonblank but the route fails the no-overlap acceptance contract.
- **iOS status prominence**: `Saved copy may be stale` and its separate dismiss glyph occupy a full content row above the food image; cache status should not outrank the recipe itself.
- **macOS action density**: the full-width cook action plus equal-weight Save/Add/Log/More grid reads like a web action panel rather than a restrained native recipe surface.

### Cook Mode

- **macOS footer imbalance**: `Mark done` occupies a separate dominant row while Back step, Next step, and Close form an uneven second row. The hierarchy and alignment do not read as one native navigation control.
- **macOS timer explanation**: the unavailable-system-timer banner is implementation/platform narration inside the cooking flow. Prefer a quiet unavailable/omitted action or a platform-correct affordance rather than a full explanatory strip.
- **cross-route sidebar truncation**: the same Saved Recipes, Shopping List, and Kitchen Search truncation persists in Recipe Detail and Cook Mode, confirming a shell-level defect rather than one route fixture.

## Evidence

- iOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/ios-mobile.png`
- macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/macos-desktop.png`
- Recipe Detail iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipe-detail/screenshots/`
- Cook Mode iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/cook-mode/screenshots/`

## Disposition

Keep these open through the full route capture. Convert the consolidated cross-route findings into a tests-first native shell/navigation/taste unit before final Unit 11 validation. Every fix requires iPhone, iPad, and macOS screenshots plus a fresh visual reviewer.
