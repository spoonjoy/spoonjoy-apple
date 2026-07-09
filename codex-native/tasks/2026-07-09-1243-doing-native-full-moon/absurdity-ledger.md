# Absurdity Ledger

This ledger is evidence-led. Items here are from TestFlight feedback, App Store Connect/API logs, native telemetry, route screenshots, or simulator/macOS capture artifacts.

## Open

### A-001 - Screenshot matrix can time out without terminal blocker artifacts

- Evidence: `unit-0c-baseline-capture.log`, `unit-0c-baseline-screenshots/apple/unit-0c-route-matrix.jsonl`
- Routes: `kitchen`, `shopping-list`, `capture`
- Problem: failed or interrupted routes did not produce screenshots, `design-review.json`, or `design-review-blocked.json`; `capture` did not get a route-matrix row before the outer timeout.
- Impact: an agent can stop with a partial capture and still look superficially successful if it only sees the `tee` pipeline exit.
- Routed to: Units 1a-1f.

### A-002 - Mobile dock is too visually heavy and covers content

- Evidence: `unit-0c-baseline-screenshots/screenshot-routes/recipes/screenshots/ios-mobile.png`, `recipe-detail/screenshots/ios-mobile.png`, `search/screenshots/ios-mobile.png`
- Problem: the floating dock overlaps useful lower content and the selected pill feels like an invented control rather than a native tab/navigation affordance.
- Impact: Recipes, Recipe Detail, and Search read as cramped even when their core content is stronger.
- Routed to: Units 2c-2d and route visual QA units.

### A-003 - Stale/offline status treatment is too loud for normal content reading

- Evidence: `recipe-detail/screenshots/ios-mobile.png`, `search/screenshots/ios-mobile.png`, `recipes/screenshots/ios-mobile.png`
- Problem: `Saved copy` and `Saved copy may be stale` are truthful, but they sit high in the visual hierarchy and compete with page identity and search/results.
- Impact: normal browsing feels like a warning state.
- Routed to: Units 2e-2f.

### A-004 - Search filter chips overflow at the right edge

- Evidence: `search/screenshots/ios-mobile.png`
- Problem: the horizontal filter row clips the rightmost chip at the viewport edge.
- Impact: the control looks unfinished and reduces confidence in search.
- Routed to: Units 2c-2d and Unit 3 route QA.

### A-005 - Cook mode bottom controls are still bulky

- Evidence: `cook-mode/screenshots/ios-mobile.png`
- Problem: the focused cooking layout is much improved, but the bottom command bar is large, shadowy, and could be calmer; timer secondary controls also need review across steps and Dynamic Type.
- Impact: the strongest route still feels more like a custom chrome experiment than the final kitchen-safe native mode.
- Routed to: Units 3g-3i.

### A-006 - Route evidence is missing for cookbook detail, settings, auth, and error/offline state matrix

- Evidence: Unit 0c route matrix only covers `kitchen`, `recipes`, `recipe-detail`, `cook-mode`, `cookbooks`, `shopping-list`, `search`, `capture`.
- Problem: required completion surfaces are not yet screenshot-proven.
- Impact: shipping confidence is not broad enough for the full-moon bar.
- Routed to: Unit 1g-1h and later route/state QA units.

## Closed

None yet.
