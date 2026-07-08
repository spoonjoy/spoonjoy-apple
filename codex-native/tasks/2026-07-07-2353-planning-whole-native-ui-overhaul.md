---
schema_version: 1
title: whole-native-ui-overhaul
status: IN_PROGRESS
created: '2026-07-08T06:53:51Z'
updated: '2026-07-08T06:53:51Z'
track: spoonjoy
repo: spoonjoy-apple
branch: codex-native/whole-ui-overhaul
bundle_id: app.spoonjoy
asc_app_id: '6787505444'
feedback_instance: AL3GtjesS-4gK4LAwMY7WJI
---

# Whole Native UI Overhaul

## Evidence

The current TestFlight feedback instance `AL3GtjesS-4gK4LAwMY7WJI` is a whole-app product blocker, not a one-off dock bug. The submitted screenshots show:

- Recipe detail content hidden under iOS chrome; title/description begin behind the toolbar.
- "Start Cooking" collapsed into a vertical text strip, proving action layout can horizontally compress instead of wrapping.
- Hero/action area dominated by blank columns, free-floating controls, and clipped side objects.
- Kitchen root has a clipped nested recipe island and a cookbook shelf that repeats/crops the same image across truncated columns.
- Typography, food media, and list rhythm do not match the Kitchen Table or the canonical mobile navigation/SpoonDock prototypes.

Canonical design references:

- `docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/docs/design-language.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/navigation-model.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/spoondock-design-notes.md`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/mobile-navigation-contact-sheet.png`
- `/Users/arimendelow/desk/spoonjoy/mobile-first-design-recalibration/spoonjoy-v2/2026-05-23-recalibration-plan/screenshots/spoondock-contact-sheet.png`

## Scope

Overhaul every currently shipped native product surface that can appear in TestFlight:

- Compact iPhone shell and SpoonDock.
- Kitchen, recipes/index, recipe detail, cook mode, shopping list, search, capture, cookbooks/detail, profile, settings, signed-out/setup and loading/error surfaces.
- Visual fixtures and screenshot/design contracts so feedback screenshots cannot regress while tests stay green.

Out of scope: public App Store submission and new product nouns not already represented in native/web design sources.

## Product Rules

- Hide generic compact navigation chrome when the authored mobile shell owns place/back/actions.
- Use the three-zone SpoonDock contract: place/back, primary/status, at most two tools.
- Food media is editorial; no repeated cropped carousels or decorative dark photo boxes.
- Lists use receipt/index grammar with stable amount/action columns; no `List` islands inside `ScrollView`.
- Primary actions must wrap vertically on compact width and maintain 44-point touch targets; never allow compressed vertical text.
- Every route gets enough bottom safe-area reserve for the dock and enough top rhythm for the authored header.
- Loading/error/signed-out states must be branded and useful, not default blank progress/error copy.

## Implementation Plan

1. Replace the thin theme with Kitchen Table page/header/section/action components.
2. Hide compact navigation bars and let authored headers plus SpoonDock carry place/back.
3. Rebuild Kitchen, Recipes, Search, Cookbooks, Recipe Detail, Cook Mode, Shopping, Capture, Settings, Profile, and Signed-Out surfaces around the shared object grammar.
4. Replace risky action flows with explicit mobile-safe vertical action rows.
5. Expand source-contract tests and screenshot route coverage to include the whole app surface set.
6. Capture screenshots, inspect them manually, close the absurdity ledger, then archive/export/upload/publish a new internal TestFlight build.

## Acceptance

- Build number is newer than TestFlight build 17.
- `swift test` and native scenario/design contract checks pass.
- iOS screenshots are captured and manually inspected for all major routes; no ledger item remains `ready`.
- The IPA uploads successfully and the newest `VALID` build is attached to `Spoonjoy Internal`.
- Feedback instance `AL3GtjesS-4gK4LAwMY7WJI` is marked fixed/unconfirmed with the uploaded build number.
