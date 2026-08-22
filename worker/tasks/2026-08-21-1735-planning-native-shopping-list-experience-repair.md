# Planning: Native Shopping List Experience Repair

**Status**: NEEDS_REVIEW
**Created**: 2026-08-21 17:35

## Goal
Make ordinary shopping-list mutations immediate and localized, and redesign the native shopping surface to preserve the web product's Need/Basket/All, category, and ruled-receipt language through native iOS, iPadOS, and macOS mechanics.

## Upstream Work Items
- `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/task.md`

## Scope

### In Scope
- Replace shopping mutations' full-shell `bootstrap()` path with optimistic local state plus shopping-list-only server reconciliation.
- Preserve offline queue ordering and fallback behavior, with localized pending and failure feedback rather than a root loading takeover.
- Add Need, Basket, and All modes with counts; category filtering; stable market/category ordering; and correct empty states.
- Redesign the shopping list with editorial hierarchy, ruled receipt rows, large check targets, compact actions, native swipe/context behavior, and iOS/iPadOS/macOS adaptations.
- Add strict unit, source-contract, scenario, accessibility, build, coverage, and screenshot-backed visual validation.
- Merge a focused PR, verify required checks on exact merged `main`, publish an internal TestFlight build, verify availability, and clean the task worktree/branch.

### Out of Scope
- Web application changes or web Sign in with Apple repair.
- Backend shopping API changes; current read and mutation contracts remain canonical.
- Changes to PR #59 or `/Users/arimendelow/Projects/spoonjoy-apple-native-shell-taste-repair`.
- New shopping concepts such as meal planning, barcode capture, or source-grouped lists.

## Completion Criteria
- [ ] Shopping checkoff, uncheck, add, delete, clear-checked, and clear-all never publish `.restoringCache` or replace the app shell.
- [ ] Mutations update the visible shopping list optimistically, keep offline FIFO behavior, reconcile only shopping-list state after successful remote writes, and show calm local pending/failure feedback.
- [ ] Need/Basket/All counts and category filters match the current web route's product semantics across active, completed, empty, all-complete, duplicate, queued, conflict, and failure states.
- [ ] The visible surface uses stable ruled receipt rows, large accessible check targets, compact actions, and no dead space or overlap on iPhone, iPad, and macOS.
- [ ] 100% test coverage on all new code
- [ ] All tests pass
- [ ] No warnings
- [ ] `visual-qa-dogfood` evidence is captured from installed/running builds, the absurdity ledger is closed, and automated visual metrics still pass.
- [ ] Focused PR is merged; required checks are green for exact merged `main`; internal TestFlight build is attached to Spoonjoy Internal and reaches `IN_BETA_TESTING`; branch/worktree cleanup is complete.

## Code Coverage Requirements
**MANDATORY: 100% coverage on all new code.**
- No `[ExcludeFromCodeCoverage]` or equivalent on new code
- All branches covered (if/else, switch, try/catch)
- All error paths tested
- Edge cases: null, empty, boundary values

## Open Questions
- None. The operator delegated implementation and delivery; existing web semantics and native design language resolve product behavior.

## Decisions Made
- Keep canonical shopping data in `NativeLiveAppStore`; publish the plan's updated list before network waiting and reconcile through `ShoppingListRequests.readShoppingList()` without invoking root bootstrap.
- A successful mutation remains successful if follow-up read reconciliation fails; the optimistic state stays visible and later sync/bootstrap can converge it. Mutation failure remains local to the affected action and does not trigger full-shell loading.
- Need means unchecked items, Basket means checked items, and All means both; category options derive from the selected mode and reset to All when invalid.
- Preserve web information architecture and language while using SwiftUI-native picker/filter controls, List/Section, swipe actions, context menus, Dynamic Type, and platform navigation.
- Existing `docs/native-justification.md` already establishes shopping checkoff as local-first native value; this repair strengthens that invariant without adding new frameworks.

## Context / References
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Sources/SpoonjoyCore/Features/Shopping/ShoppingSurfaceViewModel.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Apps/Spoonjoy/Shared/Components/ReceiptListView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/shopping-list.tsx` (read-only product comparison)

## Notes
The existing mutation executor computes `updatedShoppingList`, but live remote execution calls `executeRecipeEditorRequest`, which awaits `bootstrap()` and publishes `.restoringCache`. Existing receipt sections expose active items only, so checked items cannot power Basket/All without a source-model extension.

## Progress Log
- 2026-08-21 17:35 Created from source audit and operator-approved scope.
