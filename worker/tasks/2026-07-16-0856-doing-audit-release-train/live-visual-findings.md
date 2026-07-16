# Live Native Visual Findings

This ledger records fresh manual findings from real simulator/macOS pixels. A route is not visually accepted merely because screenshot generation and nonblank checks pass.

## Open

### My Recipes

- **iOS hierarchy duplication**: the navigation title and authored page heading both say `My Recipes`; the duplicated title competes with the empty-state hierarchy instead of behaving like one deliberate native surface.
- **iOS status chrome**: `Saved copy` plus a separate dismiss glyph consumes prominent top-of-page space for a passive state. Re-evaluate the single owner and placement of offline/cache status.
- **macOS sidebar truncation**: `Saved Recipes`, `Shopping List`, and `Kitchen Search` truncate despite abundant window width. The sidebar width and label layout fail the readable-navigation contract.
- **macOS empty-state weight**: the large blank canvas, duplicated title hierarchy, toolbar search field, and framed empty-state row do not yet feel proportionate as one composed native screen.
- **empty-state semantics**: My Recipes and Saved Recipes currently use the same `Start your recipe box` language even though one means owned recipes and the other means saved recipes. Each state needs distinct, web-aligned language and a useful native action instead of a dead end.

### Recipe Detail

- **iOS content occlusion**: the floating bottom dock visibly covers the next `YIELD` section and `Clear progress` content. The screenshot is nonblank but the route fails the no-overlap acceptance contract.
- **iOS status prominence**: `Saved copy may be stale` and its separate dismiss glyph occupy a full content row above the food image; cache status should not outrank the recipe itself.
- **macOS action density**: the full-width cook action plus equal-weight Save/Add/Log/More grid reads like a web action panel rather than a restrained native recipe surface.
- **ambiguous duplicate controls**: iOS exposes two visually identical unlabeled ellipsis controls. Consolidate their ownership or give each a distinct native label and placement; prove the macOS action row is complete rather than clipped below the capture.

### Cook Mode

- **macOS footer imbalance**: `Mark done` occupies a separate dominant row while Back step, Next step, and Close form an uneven second row. The hierarchy and alignment do not read as one native navigation control.
- **macOS timer explanation**: the unavailable-system-timer banner is implementation/platform narration inside the cooking flow. Prefer a quiet unavailable/omitted action or a platform-correct affordance rather than a full explanatory strip.
- **cross-route sidebar truncation**: the same Saved Recipes, Shopping List, and Kitchen Search truncation persists in Recipe Detail and Cook Mode, confirming a shell-level defect rather than one route fixture.
- **focus failure on macOS**: the full library sidebar remains visible with My Recipes selected while the cook is inside a step. Collapse surrounding navigation so the step, ingredients, native timer action, and progress controls form one focused cooking surface.

### Shopping List

- **iOS content occlusion**: the floating dock covers the Dairy section and third shopping item. This is the same shell-level safe-area defect as Recipe Detail, now proved on a long list.
- **duplicated hierarchy**: the compact navigation title and authored `Shopping List` heading repeat the same label while Receipt actions, item entry, Add from recipe, and cache status stack before the actual list.
- **cache status placement**: `Saved copy` plus a dismiss glyph sits between creation controls and groceries, interrupting the primary scan path.
- **cross-platform fixture mismatch**: `shopping-list-empty` is a real empty receipt on iOS but a contradictory sign-in/sync state on macOS while also claiming `Saved copy`. The route seed and terminal language must represent the same product state on every platform.
- **duplicate-item resolution**: the duplicate route renders two indistinguishable `lemons` rows with the same quantity and no visible grouping, warning, merge, or review affordance. Resolution cannot hide behind a generic actions menu.
- **success-role drift**: `All checked off` uses brass/charcoal instead of the documented Herb success role.
- **macOS balance**: entry controls consume most of the canvas while receipt rows become visually tiny. Rebalance around scannable grocery rows and repeated action.

### Cookbooks

- **iOS content occlusion**: the floating dock covers the next `Shelf` heading and cookbook content.
- **loading captured as product state**: the featured cookbook collage contains visible activity indicators in the terminal screenshot. Route capture must wait for image settlement or render a deliberate stable no-photo treatment; a loading spinner is not acceptable final imagery.
- **action competition**: `New Cookbook`, `Open cookbook`, and `Share` occupy large adjacent blocks before the authored cookbook object, weakening food/object-first hierarchy.
- **macOS object hierarchy**: the oversized New Cookbook action dominates the actual cookbook. The primary repeated objects, covers, and titles should lead.

### Kitchen

- **iOS content occlusion**: the floating dock also covers the cookbook shelf on the Kitchen route, proving the safe-area defect is global rather than limited to detail/list screens.
- **macOS thumbnail clipping**: text-bearing cookbook thumbnails crop their own titles (`Inbox` becomes `ox`; `Weeknights` begins mid-word). Use a legible thumbnail treatment that does not crop title glyphs as imagery.

### Cookbook Detail

- **cover truth**: the large paper cover is mostly blank with skeleton-like rules and no real recipe imagery. Verify this is an authored no-photo state rather than a placeholder that escaped image loading.
- **iOS content occlusion**: the bottom dock overlaps the second recipe row and hides following contents.

## Evidence

- iOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/ios-mobile.png`
- macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipes/screenshots/macos-desktop.png`
- Recipe Detail iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/recipe-detail/screenshots/`
- Cook Mode iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/cook-mode/screenshots/`
- Shopping List iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/shopping-list/screenshots/`
- Cookbooks iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/cookbooks/screenshots/`
- Cookbook Detail iOS/macOS: `/Users/arimendelow/Projects/spoonjoy-apple-pr52-repair-validation/rebase-0309768c/screenshot-routes/cookbook-detail/screenshots/`

## Disposition

Reject the current visual set. Unit 4N owns these findings as blocking acceptance criteria before final Unit 11 validation. Every fix requires iPhone, iPad, and macOS screenshots, executable settlement/accessibility/no-overlap proofs, and a fresh visual reviewer; automated nonblank/design JSON cannot close a manual pixel finding by itself.
