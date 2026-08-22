# Planning: Native Shopping List Experience Repair

**Status**: NEEDS_REVIEW
**Created**: 2026-08-21 17:35

## Goal
Make ordinary shopping-list mutations immediate and localized, and redesign the native shopping surface to preserve the web product's Need/Basket/All, category, and ruled-receipt language through native iOS, iPadOS, and macOS mechanics.

## Upstream Work Items
- `/Users/arimendelow/desk/spoonjoy/native-shopping-list-experience-repair/task.md`

## Scope

### In Scope
- Replace shopping mutations' full-shell `bootstrap()` path with serialized optimistic local state plus shopping-list-only server reconciliation.
- Preserve offline queue ordering and fallback behavior, with localized pending and failure feedback rather than a root loading takeover.
- Add Need, Basket, and All modes with counts; category filtering; the web affordance helper's explicit-category/name-fallback semantics; fixed Produce/Protein/Dairy/Bakery/Pantry/Spices/Frozen/Other market order; completed-item sectioning; and state-specific empty copy.
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
- [ ] Online mutations are serialized, optimistically rebase on the latest store state, reconcile only shopping-list state after successful remote writes, and ignore stale reconciliation responses; offline/already-queued/fallback mutations retain FIFO with exactly one optimistic application.
- [ ] A definite non-offline mutation failure rolls back when no later mutation exists; otherwise a targeted read reconciles without clobbering newer state. Indeterminate reconciliation failure retains the optimistic row with a row/action retry error and never triggers root bootstrap.
- [ ] Need/Basket/All counts and category filters match the current web route's product semantics across active, completed, empty, all-complete, duplicate, queued, conflict, and failure states.
- [ ] Installed-app screenshots cover iPhone portrait at default and accessibility Dynamic Type, iPad portrait/landscape, and macOS at narrow/wide windows for populated Need/Basket/All, category-filtered, empty, all-complete, pending, row-error, queued, conflict, and duplicate states; the ledger has no clipping, overlap, tiny primary targets, unexplained blank region larger than one row, or open `ready` finding.
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
- Keep canonical shopping data in `NativeLiveAppStore`. A dedicated shopping mutation coordinator serializes online writes, rebases the plan's queue-compatible mutation onto the latest store state, and reconciles through `ShoppingListRequests.readShoppingList()` without invoking root bootstrap. Monotonic mutation generations prevent stale reads from applying.
- Optimistic ownership is exclusive: the coordinator applies online mutations; existing `queueMutation` applies already-queued and online-to-offline fallback mutations. The executor must not apply the same shopping mutation a second time.
- A successful mutation remains successful if follow-up read reconciliation fails; the optimistic state stays visible with a localized retry/reconciliation message and later sync can converge it. A definite non-offline mutation failure rolls back the coordinator-owned optimistic state if its generation is still latest; when later work exists, a targeted read rebases instead of restoring a stale snapshot.
- Need means unchecked items, Basket means checked items, and All means both; category options derive from the selected mode and reset to All when invalid. Category/icon resolution ports the current web helper's explicit safe-key behavior and name-based fallback, then sorts by the web's fixed market rank with stable source order inside a category.
- Preserve web information architecture and language while using SwiftUI-native picker/filter controls, List/Section, swipe actions, context menus, Dynamic Type, and platform navigation.
- Existing `docs/native-justification.md` already establishes shopping checkoff as local-first native value; this repair strengthens that invariant without adding new frameworks.

## Context / References
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Sources/SpoonjoyCore/Features/Shopping/ShoppingSurfaceViewModel.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Sources/SpoonjoyCore/KitchenState/ShoppingListState.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Apps/Spoonjoy/Shared/Views/ShoppingListView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Apps/Spoonjoy/Shared/Components/ReceiptListView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `/Users/arimendelow/Projects/spoonjoy-apple-native-shopping-list-experience-repair/docs/native-design-language.md`
- `/Users/arimendelow/Projects/spoonjoy-v2/app/routes/shopping-list.tsx` (read-only product comparison)
- `/Users/arimendelow/Projects/spoonjoy-v2/app/lib/ingredient-affordances.ts` (read-only category/icon semantics)

## Notes
The existing mutation executor computes `updatedShoppingList`, but live remote execution calls `executeRecipeEditorRequest`, which awaits `bootstrap()` and publishes `.restoringCache`. Existing receipt sections expose active items only, so checked items cannot power Basket/All without a source-model extension.

## Progress Log
- 2026-08-21 17:35 Created from source audit and operator-approved scope.
- 2026-08-21 17:40 Addressed cold-review findings on category fidelity, optimistic ownership, failures, concurrency, and measurable visual coverage.
