# Native Design Review

Verdict: CONVERGED after reviewer-fix re-review

## Final Resolution
- Route-owned `OfflineStatusView` surfaces now receive the shell dismissal callback where they own the visible offline/status surface.
- `RecipeEditorView` now receives `shellOfflineIndicatorState` while keeping its route-owned safe-area inset, so severe shell-level offline states remain visible and dismissible without duplicating the shell indicator.
- Evidence refreshed in `unit-26c-reviewer-major-fixes-focused.log`, `unit-26c-spotlight-optional-scope-focused.log`, `unit-26c-reviewer-major-fixes-affected.log`, and `unit-26c-reviewer-major-fixes-full-swift-2.log`.
- Noether re-reviewed the design/offline-status changes and returned `CONVERGED`.

## Original Findings
- MAJOR, `Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift:21`, `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift:190`, `Apps/Spoonjoy/Shared/Views/SearchView.swift:36`, `Apps/Spoonjoy/Shared/Views/CookbooksView.swift:86`, `Apps/Spoonjoy/Shared/Views/ProfileView.swift:70`, `Apps/Spoonjoy/Shared/Views/ShoppingListView.swift:160`, `Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift:490`: feature-owned offline/status surfaces suppress the shell status bar, then call `OfflineStatusView(display:)` without a dismiss handler. `OfflineStatusView` still renders the "Hide offline status" button for informational `offline`/`stale` states, so the user sees a native dismiss affordance that does nothing on Search, Cookbooks, Profile, Shopping, Recipe Detail, and similar route-owned surfaces. This violates the Offline Product Contract's dismissible informational-state behavior and makes the status indicator misleading even though the non-overlap predicate is correct. Fix by threading a real dismiss callback into every route-owned `OfflineStatusView` that can show informational states, or by changing `OfflineStatusView` to hide the dismiss button when no handler exists and updating the design/accessibility contract accordingly; the stronger product fix is to preserve dismissal by passing the route/shell dismiss handler through these surfaces.

## Evidence Read
- Read Units 23-26 in `tasks/2026-06-16-1754-doing-siri-full-access-parity.md`, especially the design/accessibility and final native validation acceptance/evidence.
- Read `docs/native-design-language.md`, `docs/native-justification.md`, `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`, `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`, `Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift`, and the diff-touched `KitchenView.swift`, `SearchView.swift`, and `SettingsView.swift`.
- Inspected route-owned offline call sites in `RecipeDetailView.swift`, `CookbooksView.swift`, `ProfileView.swift`, `ShoppingListView.swift`, and `RecipeEditorView.swift`.
- Ran `ruby scripts/check-design-accessibility-contract.rb`, `ruby scripts/check-kitchen-recipe-surfaces.rb`, `ruby scripts/check-cook-shopping-surfaces.rb`, and `ruby scripts/check-search-capture-settings-surfaces.rb`; all passed.
- Read `scripts/check-design-accessibility-contract.rb`, `scripts/validate-design-review-blocker.rb`, `apple/validation-matrix.json`, `apple/matrix-final-report.json`, `design-review-blocked.json`, and `apple/matrix-screenshots-xcode-platform-blocker.json`.
- Ran `ruby scripts/validate-design-review-blocker.rb tasks/2026-06-16-1754-doing-siri-full-access-parity/design-review-blocked.json --artifact-root tasks/2026-06-16-1754-doing-siri-full-access-parity --unit-slug matrix`; it passed. Verified `design-review.json` and screenshot PNG success artifacts are absent while the blocker artifacts are present and mutually exclusive.
