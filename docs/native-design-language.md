# Spoonjoy Native Apple Design Language

Status: initial native translation brief for iOS 27 and macOS 27.

## Source Language

Spoonjoy's product language is **The Kitchen Table**: quiet bone paper, charcoal ink, restrained brass/tomato/herb accents, editorial food photography, cookbook margins, provenance, indexes, receipt-like lists, and cooking instructions that work under kitchen conditions.

The native app should not copy the web UI surface-for-surface. It should preserve the product family while letting Apple platform conventions take over where they are better.

## Invariants To Preserve

- **Food leads.** Every primary surface needs a dominant recipe, cookbook, shopping, or cooking object.
- **Cookbook hierarchy beats dashboard equality.** Prefer a lead object plus index, shelf, spread, or receipt over equal card grids.
- **Object-specific surfaces.** Recipes, cookbooks, shopping lists, cook logs, and settings should not all share the same container grammar.
- **Role-bound color.** Bone, charcoal, brass, tomato, herb, and photo overlays keep their semantic jobs.
- **Typography has jobs.** Recipe/cookbook names need editorial weight; labels, metadata, and controls need compact native clarity.
- **Kitchen-safe interaction.** Large targets, high contrast, stable layouts, Dynamic Type, VoiceOver, reduced motion, and no tiny clusters in primary cooking/shopping flows.

## Native Elements That Should Take Over

- `NavigationStack` and `NavigationSplitView` for structure.
- Native toolbars instead of custom web nav shells.
- `TabView` and contextual `safeAreaInset` actions instead of recreating the web mobile dock.
- `List`, `Section`, `DisclosureGroup`, `swipeActions`, and `EditMode` for dense lists.
- `sheet`, `confirmationDialog`, and `ShareLink` for modal and share behavior.
- `PhotosPicker`, camera capture, OCR, barcode scanning, and visual intelligence for recipe and grocery capture.
- `.searchable`, Spotlight indexing, and App Intents for system-level retrieval/actions.
- `Stepper`, `Toggle`, `ProgressView`, and native pickers where they improve trust and accessibility.

## SwiftUI Component Translation

- `CookbookPage` -> branded `NavigationStack`/`ScrollView` background and content margins.
- `KitchenMasthead` -> native header area with avatar, counts, and toolbar actions.
- `RecipeLead` -> editorial `AsyncImage` feature with title, provenance, and primary actions.
- `RecipeIndex` -> thumbnail `List` rows with `NavigationLink` and native search scopes.
- `CookbookShelf` -> horizontal `ScrollView` of 3:4 cookbook cover objects.
- `ReceiptList` / shopping list -> grouped `List` with large check controls, aisle/source sections, and stable ordering.
- Cook mode -> full-screen pager or focused step surface with persisted progress, timers, large text, and hands-free affordances.

## Anti-Patterns

- A generic grouped SwiftUI CRUD app.
- Equal-weight recipe grids as the main experience.
- Decorative glass, fake paper, fake leather, or ornamental skeuomorphism.
- Web hover states and custom menu behavior copied into native code.
- Tiny cooking/shopping controls.
- Destructive actions competing with cooking, saving, sharing, or shopping.
- Rebuilding native sheets, share flows, search, edit mode, or swipe actions by hand without a clear product reason.

## Native Product Backlog Seeds

The web UI audit's product backlog becomes native product work, not porting leftovers:

- Persist cook-mode progress across reloads, screen locks, and app relaunches.
- Add step timers/rest cues where recipe data supports them.
- Add a hands-free cook-mode text setting after kitchen use.
- Group shopping-list items by recipe/source when multiple meal plans are active.
- Add smarter duplicate review for near-matches before merging quantities.

## Risk

The main design risk is over-native flattening: default SwiftUI can make Spoonjoy feel like any other list app. Use native mechanics, but keep Spoonjoy's cookbook authorship, food hierarchy, and object grammar.

