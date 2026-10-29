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

On compact iPhone, the compact iPhone tabs are exactly `Kitchen`, `Recipes`, `Cookbooks`, and `Shopping`, plus Search as the tab bar's search tab (`Tab(role: .search)`), which iOS draws as a separate circle beside the tab capsule. The native `.searchable` field and its scopes sit on the `TabView` itself with `.tabViewSearchActivation(.searchTabSelection)`, so selecting Search opens the field at the bottom above the keyboard. Each tab owns its own `NavigationStack`: tab roots use large titles, deeper pages push onto the tab they were opened from with the native back button and swipe-back, and switching tabs keeps every tab's stack. The tab bar minimizes on scroll. `Recipes` switches between Mine, Saved and Everyone with a segmented picker; Everyone lists the public recipes the website's Recipes page lists (`GET /api/v1/recipes`), searched on the server. The server returns only its most recent recipes, so Everyone shows "Recent recipes from every kitchen" and never a total count. Spoonjoy has no recipe form. Add a recipe is always one tap away: a `plus` button in the Kitchen and Recipes toolbars, an Add a recipe row in the regular-width sidebar, Add a recipe on Shopping, and ⌘N on the Mac (New Window moves to ⇧⌘N). Each opens the Add a recipe sheet (`AddRecipeSheet`), which teaches the ways in (Siri, Claude, copying a link from Safari) and takes a pasted link that becomes a capture draft in Imports. A `/recipes/new` route opens the same sheet over the page it came from. An empty kitchen leads with an Add a recipe and Import hero. With recipes, the Kitchen leads with the recipe on the counter edge to edge (`RecipeLead`): the photo stretches from its top edge when the page is pulled down (`KitchenHeroStretch`, off under Reduce Motion), and the label reads "On the counter · step N of M" with Keep cooking while a cook is in progress. A paper sheet with "Your recipes" (`RecipeIndexRow`, shared with the Recipes tab) overlaps the photo's foot. The sidebar's selected row is brass, and usernames are shown exactly as written. The Kitchen root's toolbar opens Add a recipe, the Import queue, Chefs, and Settings (the account button); Chefs also stays in the regular-width sidebar. Cook mode covers the tabs full screen.

Saved Recipes derive from cookbooks owned by the current chef: filter cookbooks to the authenticated chef, flatten cookbook recipes, dedupe by recipe ID, and preserve deterministic first-seen ordering. My Recipes means authored by the current chef, not every recipe they saved.

The route matrix covers `kitchen`, `recipes`, `saved-recipes`, `cookbooks`, `shopping-list`, `chefs`, and `search` for this navigation model.

## iPhone Duo Inner Screen

The iPhone Duo opens like a passport: a compact outer screen and a regular-width inner screen with a vertical fold down the middle. Open, the phone becomes the cookbook. The layout comes from size classes and the container's shape, so the same code serves the iPad, a wide iPad window and the Duo; compact iPhone is unchanged.

- **A recipe is a two-page spread.** When the container is regular width, landscape and at least 900 pt wide, `RecipeDetailView` lays the recipe open across two pages (`BookSpreadLayout`, drawn by `KitchenTableSpread`). The left page holds the title, cover, yield and scaling, the actions and every ingredient, grouped under the step that uses it as a cookbook-style subhead, with earlier-step outputs in the group. The right page holds the method: large serif step numerals, steps in body serif, duration cues, then `Cooks`. The two pages scroll on their own. Tapping a step highlights its ingredient group on the left page (brass rule and wash, the selection color) and scrolls it into view; tapping a group's subhead brings its step into view on the right. Portrait and narrow windows keep the single scrolling page.
- **Cook mode uses the spread too.** The left page gathers what the current step needs as a large-check checklist with the recipe's progress; the right page is the step itself in large serif type with its duration cue and native timer. Back step and Close sit at the outer corner of the left page and Mark done and Next step at the outer corner of the right page, like turning a page, so no control sits near the fold.
- **A gutter, not a hairline.** Pages get a 28 pt outer margin and a 40 pt inner margin so text and tap targets stay clear of the fold. A soft fold shadow (`KitchenTableTheme.foldShadow`) follows the hinge: one gradient, darkest at the fold and gone `BookSpreadLayout.gutterShadowWidth` into each page, never a flat band. There is no paper texture.
- **The page turns.** In cook mode's spread, a swipe or a drag on the right-hand page turns to the next or previous step with a page curl: the page lifts off its spine and a fold shadow sweeps across it. VoiceOver gets Next and Previous step actions. Reduce Motion turns the curl into a crossfade of the step page. At accessibility text sizes the controls under each page stack instead of shrinking, so neither page grows past the screen or into the gutter.
- **The library sidebar is a table of contents.** On regular width the `NavigationSplitView` sidebar lists the kitchen's sections, with the chef's own cookbooks listed under `Cookbooks` in a disclosure group (`LibrarySidebar`), then Chefs, Imports and Settings under More. When a recipe opens as a spread on iOS, the sidebar steps aside (`.detailOnly`) so the spread gets the whole screen and its gutter lands on the fold; the sidebar button brings the library back, and leaving the recipe restores it. We keep `NavigationSplitView` instead of `TabView` with `.sidebarAdaptable` because a `TabView` sidebar cannot be collapsed from code, and the spread needs that to put its gutter on the fold; the split view is also the path macOS already shares.
- **Shopping shows where the list came from.** On regular width at least 740 pt wide, the shopping list sits beside a "For these recipes" pane: the recipes whose ingredients are on the list, matched by name (`ShoppingRecipeSources`), each with what is left to buy. Items do not record their recipe, so the pane only claims exact name matches after folding case, accents, punctuation and simple plurals.

**Fold seam (iOS 27.1).** Built with the iOS 27.1 SDK and running on iOS 27.1 or later, the spread follows the hinge through SwiftUI. `readingFold` (in `KitchenTableSpread.swift`) reads `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed)`, asking for inactive regions too because open flat iOS marks the iPhone Duo's fold inactive and a plain query leaves it out, and reads the hinge's status and angle through `onHingeChange` (`DeviceHinge`). `FoldRegionChoice` picks a Reserved Region `.division` (a vertical fold may be inactive; the tabletop band takes only an active fold) and passes it to `BookSpreadLayout.resolve(division:)`; `KitchenTableSpread` then draws the gutter across the hinge and the pages fill each side. The shell's sidebar decision gets the same division. There is no UIKit probe any more. The code sits behind `SPOONJOY_IOS_27_1_SDK`, which the iOS target defines only for the 27.1 and newer SDKs, plus `#available(iOS 27.1, *)`. CI and TestFlight build with Xcode 27.1, so shipping builds include it; a build on an older Xcode compiles it out and keeps the width heuristic. The shopping pane has not been checked against the fold.

**Duo postures (iOS 27.1).** `TabletopLayout.posture(hingeStatus:angleDegrees:)` turns the hinge into one of four postures, and cook mode and the recipe follow it:

| Hinge | Posture | Cook mode | Recipe |
| --- | --- | --- | --- |
| Closed (outer screen) | `closedGlance` | Folded shut mid-cook, the cover becomes a kitchen timer: the step's title in display type twice the page's size, the step's timer ring when it has one, and a full-width Next step with Show step under it. Opened on the cover, cook mode is the one-page cook mode of every other iPhone. | One page |
| Partly open, 60° to 140° | `tabletop` | Held tall, split at the fold: the step above it, facing the cook, and the checklist and controls below it, flat on the counter. At accessibility text sizes the dock's three buttons give way to whole-label buttons stacked above the checklist. | The method above the fold and the selected step's ingredients below it |
| Open, 150° or more | `openFlat` | The two-page spread with the page turn | The two-page spread |
| Under 60°, or unknown | `single` | One page | One page |

Between 140° and 150° the hinge's own status decides, and with no angle `partiallyOpen` means tabletop and `fullyOpen` means open flat. Whether the screen is tall enough to split stays with `TabletopLayout.resolve`: either half shorter than `TabletopLayout.minimumHalfHeight` keeps the single page, as does a wide screen, and a half-open hinge with no division rect splits at the middle of the window. A timer keeps running through every fold, because the postures change only the layout. DEBUG builds launched with `-SpoonjoyForcePosture tabletop`, `flat` or `closed` report that hinge on any simulator, which is how the Tabletop journey checks the split and, across relaunches, that a timer keeps its end time. The Duo tour workflow (run on demand) folds a real iPhone Duo simulator through DeviceHub: it runs the tabletop journey on the real hinge and the Spread journey open flat and wide, then, in one launch with a timer running, moves the hinge through open flat, tabletop and shut, and fails if cook mode misses a posture or the timer's end date changes (the DEBUG `CookTimerProbe` log). The rest of the tour is photographs. Sources: Apple's iPhone Duo tech talks, <https://developer.apple.com/videos/play/tech-talks/111464/> and <https://developer.apple.com/videos/play/tech-talks/111466/>.

## System (1.1)

Release 1.1 turns the Kitchen Table into a full system with a night appearance. The app follows the system appearance; nothing pins it to light. Native tokens live in `KitchenTableTheme` (app) and `SpoonjoyCore/Design` (motion, haptics, contrast), and every night value is copied from the web `.dark` block in `docs/source/spoonjoy-v2-tailwind-colors.css`, which `scripts/check-native-web-palette-contract.rb` enforces.

**Type scale.** Serif roles use the system serif, New York. Every role is a Dynamic Type text style, so it scales up to AX5; primary surfaces never set a fixed point size for text.

| Role | Style | Use |
| --- | --- | --- |
| `largeTitle` | Large Title, serif, bold | Screen titles such as Kitchen |
| `recipeTitle` | Title, serif, semibold | A recipe's name |
| `cookStep` | Large Title (34 pt base), serif, regular | The step in cook mode, read from arm's length |
| `story` | Body, serif | Recipe descriptions and notes |
| `control` | Body, SF, semibold | Buttons and controls |
| `meta` | Footnote, SF | Times, counts, attributions |
| `timer` | Large Title, SF light, monospaced digits | Running timers, so digits don't jitter |

**Roles in both appearances.** Each role is one dynamic colour that resolves per appearance.

| Role | Day | Night | Job |
| --- | --- | --- | --- |
| `page` | Bone #FBFAF4 | #1E1C19 | The page behind everything |
| `raised` | #FFFEFA | #282522 | Sheets, panels and raised rows |
| `ink` | Charcoal #28231D | #F2EEE6 | Primary text and the one filled button |
| `ink2` | #635D54 | #C8C0B4 | Secondary text |
| `onInk` | Bone #FBFAF4 | #1F1D1A | Labels on ink, action and brass fills |
| `hairline` | Charcoal at 18% | Bone at 16% | Rules and borders |
| `brass` | #9B6834 | #C4945C | State and selection, never large fills |
| `action` | Charcoal #28231D | Amber #B9854B | The primary action fill |
| `tomato` | #A24A38 | #E58263 | Errors and destructive actions |
| `herb` | #596A4F | #A4B578 | Success |
| `onPhoto` | Bone | #F1E6D3 | Text over photographs |

Every text role passes WCAG AA (4.5:1) on `page` and `raised` in both appearances, as do labels on the action, brass and tomato fills; `KitchenContrastTests` measures each pair from the theme source.

**Glass.** Liquid Glass is for controls that float over content: the tab bar, toolbars, the cook dock and the timer chip. Prefer system components, which bring their own glass. Content (recipe text, lists, photos) never sits on glass. There is one filled button per screen, a solid ink capsule on interactive glass; everything else is glass or text. Group neighbouring glass controls in one `GlassEffectContainer` so they merge and split together.

The glass rules:

- Glass is only for chrome floating over content. Never stack glass on glass: a control inside a glass toolbar or dock uses the container's glass, not its own second layer.
- Controls over a photo (the cover's back, share and favourite buttons) use clear `.glass` so the photo shows through.
- A group that morphs (the cook dock, where Back splits off once there is a step to go back to) shares one `GlassEffectContainer` and one namespace of `glassEffectID`s, and animates on `KitchenSpring.glide`. Under Reduce Motion the pieces leave the morph and fade instead.
- `KitchenTableActionButtonStyle` is the button vocabulary, all capsules: `.primary` is the solid ink fill on interactive glass (a tinted glass fill reads grey over bone), `.destructive` is the same in tomato for a confirmed delete, `.secondary` is clear interactive glass, and `.quiet` is text only. No bordered outlines.
- A control that can't act right now is left out of a glass group rather than shown dimmed, unless its absence would hide where the reader is.

**Grid.** Spacing is a multiple of 4 pt (`KitchenTableTheme.Spacing`). Screen margins are 24 pt on iPhone, 32 pt on iPad and Mac, and 40 pt on the side of a page that meets the iPhone Duo fold. Touch targets stay at least 44 pt.

**Radii.** Corners keep their meaning: 0 pt for full-bleed edges, 4 pt for media, 8 pt for panels and sheets, and 999 pt (a capsule) for controls.

**Motion.** Motion uses springs in SwiftUI's response and damping terms (`KitchenSpring`): snappy 0.32/0.86 for small state changes, glide 0.42/0.82 for the tab lens and glass morphs, page turn 0.5/0.88 for cook steps, zoom 0.45/0.9 for a cover opening into its recipe, and bounce 0.35/0.6 for a checked ingredient. With Reduce Motion on, every spring becomes a 0.2 s crossfade and nothing moves: `KitchenMotion.step` makes the decision, `KitchenMotion.animation` and `kitchenAnimation` animate with it, and `kitchenTransition` swaps any slide, zoom or page turn for opacity.

**Haptics.** Haptics mark moments, not every tap (`KitchenHapticMoment`, played through `sensoryFeedback`): checking an ingredient or a list item plays selection, turning a step a light impact, starting a timer a medium impact, a timer or cook finishing success, and confirming a destructive action warning.

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
