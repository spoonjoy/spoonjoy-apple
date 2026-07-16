# Live Native Visual Findings

This ledger records fresh manual findings from real simulator/macOS pixels. A route is not visually accepted merely because screenshot generation and nonblank checks pass.

## Open

### My Recipes

- **iOS hierarchy duplication**: the navigation title and authored page heading both say `My Recipes`; the duplicated title competes with the empty-state hierarchy instead of behaving like one deliberate native surface.
- **iOS status chrome**: `Saved copy` plus a separate dismiss glyph consumes prominent top-of-page space for a passive state. Re-evaluate the single owner and placement of offline/cache status.
- **macOS sidebar truncation**: `Saved Recipes`, `Shopping List`, and `Kitchen Search` truncate despite abundant window width. The sidebar width and label layout fail the readable-navigation contract.
- **macOS empty-state weight**: the large blank canvas, duplicated title hierarchy, toolbar search field, and framed empty-state row do not yet feel proportionate as one composed native screen.

## Evidence

- iOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/ios-mobile.png`
- macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/macos-desktop.png`

## Disposition

Keep these open through the full route capture. Convert the consolidated cross-route findings into a tests-first native shell/navigation/taste unit before final Unit 11 validation. Every fix requires iPhone, iPad, and macOS screenshots plus a fresh visual reviewer.
