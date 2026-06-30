# Spoonjoy Native Apple Design Language

Status: initial native translation brief for iOS 27 and macOS 27.

## Source Language

Spoonjoy's product language is **The Kitchen Table**: quiet bone paper, charcoal ink, restrained brass/tomato/herb accents, editorial food photography, cookbook margins, provenance, indexes, receipt-like lists, and cooking instructions that work under kitchen conditions.

The native app should not copy the web UI surface-for-surface. It should preserve the product family while letting Apple platform conventions take over where they are better.

Source pin: this brief mirrors `spoonjoy/spoonjoy-v2` `docs/design-language.md` on `main` at SHA-256 `9c2ebdb8cbfa71e202a344099e23c544899482b256353a4c828f10d0c047ab56`. A changed source hash means the native brief and contract must be intentionally reviewed together.

## Invariants To Preserve

- **Food leads.** Every primary surface needs a dominant recipe, cookbook, shopping, or cooking object.
- **No default cards.** Cards are allowed only for real recipe covers, cookbook covers, shopping receipts/lists, modal sheets, notifications, and toasts.
- **No section cards.** Page sections are spreads, shelves, bands, indexes, lists, receipts, or forms; they are not decorative cards inside pages.
- **No equal-weight grids as the primary experience.** A grid can be an index, but a lead object, spread, shelf, or receipt structure must define the page.
- **Cookbook hierarchy beats dashboard equality.** Prefer a lead object plus index, shelf, spread, or receipt over equal card grids.
- **Object-specific surfaces.** Recipes, cookbooks, shopping lists, cook logs, and settings should not all share the same container grammar.
- **Rounded corners are semantic.** Use 0 pt for page edges, rows, dividers, and dense image masks; 4 pt for cookbook covers, thumbnails, and small media; 8 pt for panels, modals, dense objects, and list containers; 999 pt only for pills, avatars, toggles, and true controls.
- **Role-bound color.** Bone is page and paper; Charcoal is text, primary controls, and structural lines; Brass is selection, provenance, warmth, and editorial emphasis; Tomato is destructive or high-intent creation; Herb is cooked, success, or origin-cook state; Photo overlay appears only on photography.
- **Typography has jobs.** Display serif is for recipe names, cookbook titles, and major page titles; Body serif is for descriptions, notes, and instructions; Condensed UI sans is for navigation, metadata, labels, and compact controls.
- **Kitchen-safe interaction.** Use large targets, high contrast, stable layouts, Dynamic Type, VoiceOver, reduced motion, and no tiny clusters in primary cooking/shopping flows.

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
- Default cards as decorative containers.
- Section cards inside page sections.
- Equal-weight recipe grids as the primary structure.
- Equal-weight recipe grids as the main experience.
- Decorative glass, fake paper, fake leather, or ornamental skeuomorphism.
- Web hover states and custom menu behavior copied into native code.
- Tiny cooking/shopping controls.
- Destructive actions competing with cooking, saving, sharing, or shopping.
- Rebuilding native sheets, share flows, search, edit mode, or swipe actions by hand without a clear product reason.

## Native Design Review Contract

`design-review.json` is the fail-closed artifact for visual and accessibility review. The schema has booleans `mobileScreenshot`, `desktopScreenshot`, `dynamicType`, `voiceOverLabels`, `keyboardNavigation`, `reduceMotion`, `contrast`, `kitchenTableHierarchy`, and `noOverlap`, a `screenshotRoute`, route-specific signed-in proof fields, and `accessibilityProofArtifacts` for iOS and macOS. Kitchen captures include `kitchenSignedInSurface` and `kitchenSeedAccountID`; search captures include `searchNativeSurface`, exact `searchScopes`, `searchSeedAccountID`, and `searchSurfaceProofArtifacts` emitted by the visible Search view during capture; settings captures include `settingsSignedInSurface`, `settingsVisualFocus`, `settingsSeedAccountID`, `settingsSections`, and `settingsSurfaceProofArtifacts` emitted by the visible Settings view during capture. Profile-focused settings captures include `settingsProfileSurface`; APNs-focused settings captures include `settingsNotificationAPNsSurface` and visible APNs sections. Runtime screenshot blockers belong in `design-review-blocked.json`, not inline `blockers[]`.

Each accessibility proof must be emitted by the running Spoonjoy app through `SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH`; the screenshot harness may wait for, validate, and copy proof files, but must not fabricate them. Proof files must include `emittedBy: SpoonjoyApp`, the expected platform `bundleIdentifier`, `minimumTargetSize`, `textFits`, `noTinyClusters`, the same `dynamicType`, `voiceOverLabels`, `keyboardNavigation`, `reduceMotion`, `contrast`, `kitchenTableHierarchy`, and `noOverlap` guarantees, observed SwiftUI environment values `observedDynamicTypeSize` and `observedReduceMotion`, route-specific `routeEvidence`, plus an `offlineIndicatorProof`. `routeEvidence` must name the actual visible route anchors for VoiceOver labels, keyboard navigation targets, dynamic type text styles, contrast pairs, hierarchy anchors, and layout guards; it must not be a route-agnostic list of true booleans. The `offlineIndicatorProof` must name `OfflineStatusView`, list the visibleStates `offline`, `stale`, `queuedWork`, `syncFailure`, `conflict`, `blocker`, and `destructiveConfirmation`, list dismissibleStates `offline` and `stale`, list severeStates `queuedWork`, `syncFailure`, `conflict`, `blocker`, and `destructiveConfirmation`, record hidden states `synced` and `dismissed`, and prove the VoiceOver label, `Hide offline status` dismiss button label, and severity-correct state mapping.

The manifest is not a substitute for screenshots or human-grade review, but it must make these native surface obligations explicit:

- Kitchen includes a lead food/cookbook/list object, `KitchenMasthead`, `RecipeLead`, `RecipeIndex`, and `CookbookShelf`.
- Recipe Detail includes hero/provenance/actions, an ingredient receipt, numbered method sections, and native share affordances.
- Shopping List uses receipt rows, large check controls, native `List`/`Section` grouping, edit/check affordances, and stable ordering.
- Cook Mode uses one focused step, persisted progress, large controls, progress/timer affordances, and no dense multi-step primary list.
- Search uses native `.searchable` scopes, typed rows, and the accepted scopes `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list`.
- Capture creates a local draft and does not claim server recipe writes before backend support exists.
- Settings shows offline/auth/environment state and validation state through quiet native rows or forms.

Later static app-surface checks should inspect SwiftUI sources directly for `KitchenView`, `RecipeDetailView`, `CookModeView`, `ShoppingListView`, `SearchView`, `CaptureDraftView`, `SettingsView`, `ReceiptListView`, `KitchenSafeControls`, and `KitchenTableTheme`. Those checks should reject placeholder shells such as `Text("Native shell ready")`, root-only generic grouped lists, default `CardView` containers, raw Spoonjoy color literals outside theme tokens, copied CSS/Tailwind class names, `WKWebView`, custom web nav docks, shared iOS `.onHover`, and fixed raw `.font(.system(size: ...))` in primary surfaces.

## Native Product Backlog Seeds

The web UI audit's product backlog becomes native product work, not porting leftovers:

- Persist cook-mode progress across reloads, screen locks, and app relaunches.
- Add step timers/rest cues where recipe data supports them.
- Add a hands-free cook-mode text setting after kitchen use.
- Group shopping-list items by recipe/source when multiple meal plans are active.
- Add smarter duplicate review for near-matches before merging quantities.

## Risk

The main design risk is over-native flattening: default SwiftUI can make Spoonjoy feel like any other list app. Use native mechanics, but keep Spoonjoy's cookbook authorship, food hierarchy, and object grammar.
