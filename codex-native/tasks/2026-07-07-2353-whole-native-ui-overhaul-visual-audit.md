---
schema_version: 1
title: whole-native-ui-overhaul-visual-audit
status: READY_FOR_PUBLISH
created: '2026-07-08T06:53:51Z'
updated: '2026-07-08T12:27:00-07:00'
track: spoonjoy
repo: spoonjoy-apple
feedback_instance: AL3GtjesS-4gK4LAwMY7WJI
---

# Visual Absurdity Ledger

## Source Screenshots

- TestFlight feedback recipe detail: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T06-38-36-898Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-1.jpg`
- TestFlight feedback kitchen: `/Users/arimendelow/Library/Application Support/Spoonjoy/TestFlightFeedbackAutopilot/events/2026-07-08T06-38-36-898Z-AL3GtjesS-4gK4LAwMY7WJI/screenshot-2.jpg`
- Canonical mobile nav sheet: `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/mobile-navigation-contact-sheet.png`
- Canonical SpoonDock sheet: `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/spoondock-contact-sheet.png`

## Failures

| id | surface | screenshot/proof | why users perceive it as broken | disposition |
| --- | --- | --- | --- | --- |
| W1 | Compact shell | feedback screenshot 1 | System nav chrome floats over authored recipe content and steals the top of the page. | fixed: compact iOS shell now uses a bottom SpoonDock handrail and Kitchen Table page background; release screenshots show no top chrome collision. |
| W2 | Recipe detail | feedback screenshot 1 | Primary action compresses into a vertical "Start Cooking" strip; recipe actions are unusable. | fixed: recipe detail actions are full-width Kitchen Table controls with stable wrapping; latest fixed screenshot `build/visual-qa/web-recipe-parity-recipe-detail/screenshots/manual-food-cover-compact-actions-ios-mobile.png` validates no compressed or duplicate action row. |
| W3 | Recipe detail | feedback screenshot 1 | Blank gray columns and floating icons dominate the action area; food/recipe hierarchy disappears. | fixed: recipe detail now follows the web `RecipeHeader` structure with real food hero, editorial title, chef/yield language, and masthead actions. |
| W4 | Recipe detail | feedback screenshot 1 | Cookbook/ingredients sections start as generic cards and are partially below an enormous dead zone. | fixed: detail content now follows the web `StepCard`/`IngredientList` structure: header controls, modal save flow, `Steps`, per-step `Ingredients`, checkable ingredient/dependency rows, and `Cooks`; runtime accessibility proof at `build/visual-qa/web-recipe-parity-recipe-detail/runtime-accessibility-proof-ios.json` exposes that full order. |
| W5 | Kitchen | feedback screenshot 2 | Recipe index appears as a clipped nested card/island inside the scroll view. | fixed: Kitchen uses unframed receipt rows and a single page scroll; release screenshot validates. |
| W6 | Kitchen/Cookbooks | feedback screenshot 2 | Cookbook shelf repeats the same cropped image, truncates text, and reads as a broken carousel. | fixed: Cookbooks route uses object rows with covers, counts, share actions, and no clipped carousel. |
| W7 | Kitchen | feedback screenshot 2 | Hero overlay and action buttons look like default app chrome instead of a cookbook masthead. | fixed: Kitchen masthead/hero/action row now uses Kitchen Table typography and brass controls. |
| W8 | Whole app | source review | `List`/`Form` defaults erase the Kitchen Table design on recipes, search, settings, and operational screens. | fixed: Recipes, Search, Capture, Settings, Shopping, Cookbooks, Cook Mode, and Profile moved to shared Kitchen Table components. |
| W9 | Whole app | source review | Screenshot harness only covers a subset of routes, so a whole-app UI failure can pass validation. | fixed: screenshot harness and design review validator cover Kitchen, Recipes, Recipe Detail, Cookbooks, Capture, Shopping, Cook Mode, Search, and Settings. |

## Final Visual Evidence

- Full release route sweep: `codex-native/tasks/2026-07-07-2353-screenshots-release/{kitchen,recipes,recipe-detail,cookbooks,capture,shopping-list,cook-mode,search,settings}/design-review.json`
- Focused copy recapture after offline/loading wording polish: `codex-native/tasks/2026-07-07-2353-screenshots-release-copy/{kitchen,capture,recipe-detail,search,settings}/design-review.json`
- Icon balance proof: `Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/source.svg` now renders the mark at about 55% icon width, down from about 66%.

## Route Acceptance Matrix

| route | required mobile structure |
| --- | --- |
| Kitchen | Page masthead, editorial lead, receipt/index rows, vertical cookbook shelf, SpoonDock: Kitchen/Capture/Search+List |
| Recipes | Recipe index page, no grouped-list chrome, object rows with covers and stable action column |
| Recipe detail | Web-parity `RecipeHeader`: editorial food hero, title/chef/provenance/yield language, compact masthead actions, header scale and `Clear progress`; modal `Save to Cookbook`; web-parity `Steps` using per-step `Ingredients`, dependency rows, checkable ingredient rows, instructions, then `Cooks` |
| Cook mode | High-contrast task page, step progress, checklist rows, compact handrail controls |
| Shopping list | Receipt page with add form, category sections, stable amount column, embedded dock |
| Search | Native search/index page with scopes, object rows, empty/error copy that is branded and useful |
| Cookbooks/detail | Shelf/detail pages with non-clipped covers, vertical recipe rows, owner tools below content |
| Capture | Draft/import workstation with segmented capture sources, local draft preview, safe button wrapping |
| Settings | Native account form with Kitchen Table section rhythm, no raw sync/debug primary surface |
| Signed out/loading/error | Branded Spoonjoy page with clear next action and telemetry-friendly status copy |

## Closure Rule

Every `ready` row must become `fixed` or an explicit hard blocker before final response. Final screenshots must be from the fixed build or simulator run, not stale feedback screenshots.
