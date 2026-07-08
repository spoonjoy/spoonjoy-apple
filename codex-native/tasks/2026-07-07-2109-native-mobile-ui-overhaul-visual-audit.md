# Native Mobile UI Overhaul Visual Audit

Source feedback: `AL3GtjesS-4gK4LAwMY7WJI`

## Evidence

- `screenshot-1.jpg`: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T04-03-15-927Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-1.jpg`
- `screenshot-2.jpg`: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T04-03-15-927Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-2.jpg`
- Prior SpoonDock reference: `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/spoondock-contact-sheet.png`

## Failure Inventory

### F1: Recipe action row overflows compact iPhone width
- Screenshot: `screenshot-1.jpg`
- User impact: "Start Cooking" clips into vertical syllables, the scale stepper and add-to-cart controls drift off-screen, and the primary action is unusable.
- Disposition: ready
- Fix target: replace the single horizontal recipe action `HStack` with compact-priority action composition and move route-primary actions into SpoonDock when appropriate.
- Acceptance: no button label wraps to one-character columns; all recipe primary actions fit at iPhone 14 compact width with Dynamic Type default and accessibility sizes handled by wrapping or menu fallback.

### F2: Top toolbar floats over content instead of belonging to app structure
- Screenshot: `screenshot-1.jpg`, `screenshot-2.jpg`
- User impact: the back/share/menu controls visually collide with the recipe hero/title area and make the app feel like a test harness rather than a designed native product.
- Disposition: ready
- Fix target: compact iOS uses a mobile `NavigationStack` plus bottom SpoonDock. The top toolbar keeps only true navigation/title affordances needed by the system; route tools live in the dock or route-local overflow.
- Acceptance: top chrome never obscures hero text or dominant food content; primary actions are visible in the bottom control layer.

### F3: `List` inside `ScrollView` creates a broken nested scroll/card island
- Screenshot: `screenshot-2.jpg`
- User impact: the recipe index appears as a clipped white card with partial rows, while the surrounding page scroll continues separately.
- Disposition: ready
- Fix target: replace mobile kitchen recipe index `List` with Spoonjoy object rows in a `VStack`/lazy stack inside the page scroll.
- Acceptance: the index rows render fully in the same page flow without nested scrolling or cut-off rows.

### F4: Cookbook shelf image treatment repeats/crops awkwardly
- Screenshot: `screenshot-2.jpg`
- User impact: repeated cropped aglio images make the shelf look like broken placeholder content and undermine trust in the app.
- Disposition: ready for layout treatment, media-pipeline quality deferred
- Fix target: constrain cookbook covers with stable aspect ratios, captions, and overflow behavior. Do not solve upstream image sourcing in this pass unless the native treatment is causing the breakage.
- Acceptance: shelf objects are visually deliberate, text fits, and repeated source images do not appear as accidental hard-cropped columns.

### F5: Missing SpoonDock means mobile has no contextual handrail
- Screenshot: both current screenshots, prior SpoonDock contact sheet
- User impact: users get a generic toolbar/menu instead of knowing where they are, what the primary action is, and which one or two tools matter now.
- Disposition: ready
- Fix target: add compact iOS SpoonDock with three zones: left place/back, center primary action/status, right tools.
- Acceptance: kitchen, recipe detail, cook mode, and shopping list each render a route-appropriate dock.

### F6: Typography and spacing lose the Kitchen Table hierarchy
- Screenshot: both current screenshots
- User impact: giant default titles, generic controls, and uneven spacing overpower food and recipe structure.
- Disposition: ready
- Fix target: introduce mobile-specific type/spacing helpers in `KitchenTableTheme`, apply them to kitchen and recipe detail, and keep Dynamic Type support.
- Acceptance: food/recipe object leads; metadata is secondary; controls do not dominate the content.

## SpoonDock Context Matrix

| Context | Left Zone | Center Zone | Right Tools |
| --- | --- | --- | --- |
| Kitchen | `Kitchen` place label | `Capture` primary action | Search, Shopping |
| Recipes index | `Recipes` place label | `Capture` primary action | Search, Shopping |
| Recipe detail | Back to Kitchen or Recipes | `Cook` primary action | Save/Spoon, Share |
| Cook mode | Previous step | Step status | Next step |
| Shopping list | `List` place label | `Add` primary action | Search, Clear checked |
| Search | `Search` place label | `Capture` primary action | Scope/search focus, Shopping |
| Capture | Back to Kitchen | Save/import status | Clear draft, Settings |
| Settings | Back to Kitchen | Retry/sync status | Search, none |

## Visual QA Ledger

Entries start as `ready` above. During implementation, copy each failure here with final evidence and disposition:

| ID | Disposition | Final Evidence |
| --- | --- | --- |
| F1 | ready | |
| F2 | ready | |
| F3 | ready | |
| F4 | ready | |
| F5 | ready | |
| F6 | ready | |
