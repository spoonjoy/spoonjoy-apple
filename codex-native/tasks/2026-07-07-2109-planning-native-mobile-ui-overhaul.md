# Planning: Native Mobile UI Overhaul And SpoonDock

**Status**: approved
**Created**: 2026-07-07 21:09

## Goal
Make the native iOS Spoonjoy app look and behave like a first-class mobile Spoonjoy product instead of a broken SwiftUI shell. Restore the missing SpoonDock concept as a native Liquid Glass-inspired control layer while fixing the concrete clipping, overlap, hierarchy, and mobile layout failures shown in recent TestFlight screenshots.

## Upstream Work Items
- TestFlight feedback `AL3GtjesS-4gK4LAwMY7WJI`
- Desk task `spoonjoy/mobile-first-design-recalibration`

**DO NOT include time estimates (hours/days) — planning should focus on scope and criteria, not duration.**

## Scope

### In Scope
- Audit the current native iOS shell and the latest TestFlight screenshots for mobile visual failures.
- Add a native SwiftUI SpoonDock control surface for compact iOS layouts with the three-zone contract: place/back, primary action/status, and at most two route tools.
- Use Apple-native Liquid Glass-adjacent APIs available in the current SDK, including glass button styles when supported and material-backed safe-area control layers where appropriate.
- Replace the compact iOS `NavigationSplitView`/toolbar-heavy shell with a mobile-first `NavigationStack` composition while preserving the desktop-class split view for wider layouts.
- Fix recipe detail action layout so controls prioritize primary actions, wrap secondary controls, and fall back to route-local overflow on iPhone without horizontal overflow or vertical clipped text.
- Fix kitchen, recipe detail, cook mode, and shopping-list mobile composition against the explicit visual-audit failures F1-F6.
- Update native design-language/source-contract checks so SpoonDock and compact mobile shell behavior are encoded and regressions fail locally.
- Capture screenshot-backed visual QA for at least kitchen and recipe detail on iOS, inspect the images, maintain an absurdity ledger, and close every in-scope ready item.
- Run focused Swift tests, source-contract scripts, screenshot capture, app bundle build, and protected GitHub checks before merging.
- Publish an internal TestFlight build only if the visual overhaul is merged and validated as a release candidate.

### Out of Scope
- Public App Store submission.
- Backend feature work unrelated to data needed for existing native surfaces.
- A full macOS visual redesign beyond preserving compile and not regressing desktop-class navigation.
- Replacing all recipe/cookbook imagery pipelines; image quality issues may be logged unless a native layout treatment is the cause.
- Shipping future product areas not already represented in the native app.

## Completion Criteria
- [ ] Recent TestFlight feedback and screenshots are represented in an audit artifact with explicit failure dispositions.
- [ ] Compact iOS uses a native SpoonDock with the context matrix from `2026-07-07-2109-native-mobile-ui-overhaul-visual-audit.md` instead of relying on a generic top toolbar or five-equal-tab dock.
- [ ] Kitchen and recipe detail screenshots on iPhone show no clipped controls, overlapping title/hero text, nested list cutoffs, or horizontally overflowing action rows.
- [ ] Cook mode and shopping list keep kitchen-safe primary controls reachable and readable on iPhone.
- [ ] Source-contract checks cover SpoonDock, compact iOS navigation, and no-overflow mobile action composition.
- [ ] `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] If UI/rendering/layout changed: `visual-qa-dogfood` evidence captured, absurdity ledger closed, and automated visual metrics still pass

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- [ ] None.

## Decisions Made
- The latest native UI work was bug containment around auth, sync, settings, and TestFlight feedback plumbing; it did not address product-level mobile UI composition.
- The old SpoonDock work in `spoonjoy/mobile-first-design-recalibration` remains valid source material: SpoonDock is a context-aware three-zone mobile control surface, not a five-equal-tab nav bar.
- Native does not mean default SwiftUI hierarchy everywhere. Compact iOS should use Apple navigation and control materials while preserving Spoonjoy's cookbook/table grammar.
- Liquid Glass should be used for the control layer, not as decorative glass on content cards or food imagery.
- The SpoonDock context matrix for this pass is fixed in `2026-07-07-2109-native-mobile-ui-overhaul-visual-audit.md`: kitchen/search use Capture as center action, recipe detail uses Cook, cook mode uses step status and next/previous, and shopping uses Add.
- Secondary tools do not all belong in SpoonDock. Compact iOS gets at most two right-zone route tools; less common actions remain in route-local overflow or content actions.
- The first implementation slice is not a whole-product redesign of every native screen. It is the smallest release-worthy overhaul that closes audit failures F1-F6 across kitchen, recipe detail, cook mode, and shopping list.

## Context / References
- `/Users/arimendelow/Projects/spoonjoy-apple/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-ui-overhaul/codex-native/tasks/2026-07-07-2109-native-mobile-ui-overhaul-visual-audit.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/spoondock-design-notes.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/navigation-model.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/spoondock-contact-sheet.png`
- `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T04-03-15-927Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-1.jpg`
- `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T04-03-15-927Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-2.jpg`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/KitchenView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/CookModeView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple/Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`
- Apple Developer: Applying Liquid Glass to custom views
- Apple Developer: Human Interface Guidelines, Materials
- Apple Developer WWDC25: Build a SwiftUI app with the new design

## Notes
The first screenshots show top toolbar controls floating over content, a recipe-detail action row overflowing until "Start Cooking" is clipped into vertical syllables, and nested `List` content inside a `ScrollView` cutting off recipe rows. The core fix should reshape mobile app structure before polishing individual colors.

## Progress Log
- 2026-07-07 21:09 Created
- 2026-07-07 21:11 Added visual-audit artifact and resolved SpoonDock defaults after reviewer findings.
- 2026-07-07 21:14 Approved after Slugger round-two review converged.
