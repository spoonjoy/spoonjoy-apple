# Spoonjoy Native Apple Design Language

Status: initial native translation brief for iOS 27 and macOS 27.

## Source Language

Spoonjoy's product language is **The Kitchen Table**: quiet bone paper, charcoal ink, restrained brass/tomato/herb accents, editorial food photography, cookbook margins, provenance, indexes, receipt-like lists, and cooking instructions that work under kitchen conditions.

The native app should not copy the web UI surface-for-surface. It should preserve the product family while letting Apple platform conventions take over where they are better.

Source pin: this brief mirrors `spoonjoy/spoonjoy-v2` `docs/design-language.md` on `main` at SHA-256 `764b9749a614482ac75debefa06547f21fae09d35cb8be38a09a9879d6307dae`. A changed source hash means the native brief and contract must be intentionally reviewed together.

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
- Cook mode -> full-screen pager or focused step surface with persisted progress, duration cues, native system timer handoff, large text, and hands-free affordances.

## Main Kitchen Navigation

The native app mirrors the web kitchen drawer model while using platform navigation:

- `Kitchen` -> `/`
- `My Recipes` -> `/recipes`
- `Saved Recipes` -> `/saved-recipes`
- `Cookbooks` -> `/cookbooks`
- `Shopping List` -> `/shopping-list`
- `Chefs` -> `/chefs`
- `Kitchen Search` -> `/search`

On compact iPhone, the compact iPhone tabs are exactly `Kitchen`, `Recipes`, `Cookbooks`, and `Shopping`, plus Search as the tab bar's search tab (`Tab(role: .search)`), which iOS draws as a separate circle beside the tab capsule. The native `.searchable` field and its scopes sit on the `TabView` itself with `.tabViewSearchActivation(.searchTabSelection)`, so selecting Search opens the field at the bottom above the keyboard. Each tab owns its own `NavigationStack`: tab roots use large titles, deeper pages push onto the tab they were opened from with the native back button and swipe-back, and switching tabs keeps every tab's stack. The tab bar minimizes on scroll. `Recipes` switches between Mine, Saved and Everyone with a segmented picker; Everyone lists the public recipes the website's Recipes page lists (`GET /api/v1/recipes`), searched on the server. New Recipe is always one tap away: a `plus` button in the Kitchen and Recipes toolbars, a New Recipe row in the regular-width sidebar and a `plus` in the regular-width toolbar on the Kitchen and recipe drawers. Every visit to New Recipe opens a fresh editor with a blank draft (`AppNavigationState.editorIdentity(for:)`), even while another recipe's editor is open, so the open recipe is never overwritten. An empty kitchen leads with a Create recipe and Import hero. The sidebar's selected row is brass, and usernames are shown exactly as written. The Kitchen root's toolbar opens New Recipe, the Import queue, Chefs, and Settings (the account button); Chefs also stays in the regular-width sidebar. Cook mode covers the tabs full screen.

Saved Recipes derive from cookbooks owned by the current chef: filter cookbooks to the authenticated chef, flatten cookbook recipes, dedupe by recipe ID, and preserve deterministic first-seen ordering. My Recipes means authored by the current chef, not every recipe they saved.

The route matrix covers `kitchen`, `recipes`, `saved-recipes`, `cookbooks`, `shopping-list`, `chefs`, and `search` for this navigation model.

## iPhone Duo Inner Screen

The iPhone Duo opens like a passport: a compact outer screen and a regular-width inner screen with a vertical fold down the middle. Open, the phone becomes the cookbook. The layout comes from size classes and the container's shape, so the same code serves the iPad, a wide iPad window and the Duo; compact iPhone is unchanged.

- **A recipe is a two-page spread.** When the container is regular width, landscape and at least 900 pt wide, `RecipeDetailView` lays the recipe open across two pages (`BookSpreadLayout`, drawn by `KitchenTableSpread`). The left page holds the title, cover, yield and scaling, the actions and every ingredient, grouped under the step that uses it as a cookbook-style subhead, with earlier-step outputs in the group. The right page holds the method: large serif step numerals, steps in body serif, duration cues, then `Cooks`. The two pages scroll on their own. Tapping a step highlights its ingredient group on the left page (brass rule and wash, the selection color) and scrolls it into view; tapping a group's subhead brings its step into view on the right. Portrait and narrow windows keep the single scrolling page.
- **Cook mode uses the spread too.** The left page gathers what the current step needs as a large-check checklist with the recipe's progress; the right page is the step itself in large serif type with its duration cue and native timer. Back step and Close sit at the outer corner of the left page and Mark done and Next step at the outer corner of the right page, like turning a page, so no control sits near the fold.
- **The gutter is a hairline, not paper.** Pages get a 28 pt outer margin and a 40 pt inner margin so text and tap targets stay clear of the fold. No page curl, shadow or texture.
- **The library sidebar is a table of contents.** On regular width the `NavigationSplitView` sidebar lists the kitchen's sections, with the chef's own cookbooks listed under `Cookbooks` in a disclosure group (`LibrarySidebar`), then Chefs, Imports and Settings under More. When a recipe opens as a spread on iOS, the sidebar steps aside (`.detailOnly`) so the spread gets the whole screen and its gutter lands on the fold; the sidebar button brings the library back, and leaving the recipe restores it. We keep `NavigationSplitView` instead of `TabView` with `.sidebarAdaptable` because a `TabView` sidebar cannot be collapsed from code, and the spread needs that to put its gutter on the fold; the split view is also the path macOS already shares.
- **Shopping shows where the list came from.** On regular width at least 740 pt wide, the shopping list sits beside a "For these recipes" pane: the recipes whose ingredients are on the list, matched by name (`ShoppingRecipeSources`), each with what is left to buy. Items do not record their recipe, so the pane only claims exact name matches after folding case, accents, punctuation and simple plurals.

**Fold seam (iOS 27.1).** Built with the iOS 27.1 SDK and running on iOS 27.1 or later, the spread follows the hinge. The SDK adds Reserved Regions to UIKit (`UIView.reservedRegions(kind:)`, with `UIHingeInteraction` for hinge changes); SwiftUI has no equivalent. `SpreadLayoutReader` wraps the old `GeometryReader`, reads the Reserved Region `.division` rect through an invisible UIKit probe, converts it with `SpreadDivision(frameMinX:...)` and passes it to `BookSpreadLayout.resolve(division:)`; `KitchenTableSpread` then draws the gutter across the hinge and the pages fill each side. The shell's sidebar decision gets the same division. The code sits behind `SPOONJOY_IOS_27_1_SDK`, which the iOS target defines only for the 27.1 and newer SDKs, plus `#available(iOS 27.1, *)`; shipping builds on Xcode 27.0 compile it out and keep the width heuristic. The Beta SDK workflow compiles it on the beta Xcodes; real hinge behavior still needs a 27.1 simulator runtime or device, and the shopping pane has not been checked against the fold. Sources: Apple's iPhone Duo tech talks, <https://developer.apple.com/videos/play/tech-talks/111464/> and <https://developer.apple.com/videos/play/tech-talks/111466/>.

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

`design-review.json` is the fail-closed artifact for visual and accessibility review. The schema has booleans `mobileScreenshot`, `desktopScreenshot`, `dynamicType`, `voiceOverLabels`, `keyboardNavigation`, `reduceMotion`, `contrast`, `kitchenTableHierarchy`, and `noOverlap`, a `screenshotRoute`, route-specific signed-in proof fields, and `accessibilityProofArtifacts` for iPhone, iPad, and macOS. Kitchen captures include `kitchenSignedInSurface` and `kitchenSeedAccountID`; search captures include `searchNativeSurface`, exact `searchScopes`, `searchSeedAccountID`, and `searchSurfaceProofArtifacts` emitted by the visible Search view during capture; settings captures include `settingsSignedInSurface`, `settingsVisualFocus`, `settingsSeedAccountID`, `settingsSections`, and `settingsSurfaceProofArtifacts` emitted by the visible Settings view during capture. Profile-focused settings captures include `settingsProfileSurface`; notification-focused settings captures scroll directly to the device notification panel and include `settingsNotificationAPNsSurface` plus the visible `This Device`, `Push Delivery`, `Notification Sync`, and `API Tokens` section proofs. Runtime screenshot blockers belong in `design-review-blocked.json`, not inline `blockers[]`.

Each accessibility proof must be emitted by the running Spoonjoy app through `SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH`; the screenshot harness may wait for, validate, and copy proof files, but must not fabricate them. Proof files must include `emittedBy: SpoonjoyApp`, the expected platform `bundleIdentifier`, `minimumTargetSize`, `textFits`, `noTinyClusters`, the same `dynamicType`, `voiceOverLabels`, `keyboardNavigation`, `reduceMotion`, `contrast`, `kitchenTableHierarchy`, and `noOverlap` guarantees, observed SwiftUI environment values `observedDynamicTypeSize` and `observedReduceMotion`, route-specific `routeEvidence`, plus an `offlineIndicatorProof`. `routeEvidence` must name the actual visible route anchors for VoiceOver labels, keyboard navigation targets, dynamic type text styles, contrast pairs, hierarchy anchors, and layout guards; it must not be a route-agnostic list of true booleans. The `offlineIndicatorProof` must name `OfflineStatusView`, list the visibleStates `offline`, `stale`, `queuedWork`, `syncFailure`, `conflict`, `blocker`, and `destructiveConfirmation`, list dismissibleStates `offline` and `stale`, list severeStates `queuedWork`, `syncFailure`, `conflict`, `blocker`, and `destructiveConfirmation`, record hidden states `synced` and `dismissed`, and prove the VoiceOver label, `Hide offline status` dismiss button label, and severity-correct state mapping.

The manifest is not a substitute for screenshots or human-grade review, but it must make these native surface obligations explicit:

- Kitchen includes a lead food/cookbook/list object, `KitchenMasthead`, `RecipeLead`, `RecipeIndex`, and `CookbookShelf`.
- Recipe Detail follows the web recipe structure: hero/provenance, header yield controls with `Clear progress`, masthead actions (`Cook mode`, `Save`, `Add to list`, share/more), a modal `Save to Cookbook` flow, web-parity `Steps` with per-step `Ingredients`, step-output dependency rows, checkable progress rows, and `Cooks`.
- Shopping List uses receipt rows, large check controls, native `List`/`Section` grouping, edit/check affordances, and stable ordering.
- Cook Mode uses one focused step, persisted progress, large controls, duration/native-timer affordances, and no dense multi-step primary list.
- Search uses native `.searchable` scopes, typed rows, and the accepted scopes `all`, `recipes`, `cookbooks`, `chefs`, and `shopping-list`.
- My Recipes and Saved Recipes are separate personal drawers; Saved Recipes come from owned cookbook membership, not authorship.
- Chefs is a first-class route and sidebar destination, not a search alias.
- Capture creates a local draft and does not claim server recipe writes before backend support exists.
- Settings shows offline/auth/environment state and validation state through quiet native rows or forms.

Later static app-surface checks should inspect SwiftUI sources directly for `KitchenView`, `RecipeDetailView`, `CookModeView`, `ShoppingListView`, `SearchView`, `CaptureDraftView`, `SettingsView`, `ReceiptListView`, `KitchenSafeControls`, and `KitchenTableTheme`. Those checks should reject placeholder shells such as `Text("Native shell ready")`, root-only generic grouped lists, default `CardView` containers, raw Spoonjoy color literals outside theme tokens, copied CSS/Tailwind class names, `WKWebView`, custom web nav docks, shared iOS `.onHover`, and fixed raw `.font(.system(size: ...))` in primary surfaces.

## Native Product Backlog Seeds

The web UI audit's product backlog becomes native product work, not porting leftovers:

- Persist cook-mode progress across reloads, screen locks, and app relaunches.
- Treat recipe step `duration` as Spoonjoy API minutes everywhere, add duration/rest cues where recipe data supports them, and hand actual countdowns to the native system timer instead of running a Spoonjoy-owned stopwatch.
- Add a hands-free cook-mode text setting after kitchen use.
- Group shopping-list items by recipe/source when multiple meal plans are active.
- Add smarter duplicate review for near-matches before merging quantities.

## Risk

The main design risk is over-native flattening: default SwiftUI can make Spoonjoy feel like any other list app. Use native mechanics, but keep Spoonjoy's cookbook authorship, food hierarchy, and object grammar.
