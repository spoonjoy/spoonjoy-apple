# Absurdity Ledger

This ledger is evidence-led. Items here are from TestFlight feedback, App Store Connect/API logs, native telemetry, route screenshots, or simulator/macOS capture artifacts.

## Open

### A-006 - Route evidence is missing for settings, auth, and final error/offline state matrix

- Evidence: Unit 0c route matrix only covers `kitchen`, `recipes`, `recipe-detail`, `cook-mode`, `cookbooks`, `shopping-list`, `search`, `capture`.
- Problem: settings/auth and final release-state variants are not yet fully screenshot-proven. Cookbook detail and the core route matrix are now covered by Units 1h, 3l, 4c, 4f, and 4i.
- Impact: shipping confidence is not broad enough for the full-moon bar.
- Routed to: Units 4j-4l, 7, and 8e.

## Closed

### A-001 - Screenshot matrix can time out without terminal blocker artifacts

- Evidence: `unit-0c-baseline-capture.log`, `unit-0c-baseline-screenshots/apple/unit-0c-route-matrix.jsonl`
- Problem: failed or interrupted routes did not produce screenshots, `design-review.json`, or `design-review-blocked.json`; `capture` did not get a route-matrix row before the outer timeout.
- Fixed in: Units 1a-1f.
- Verification: route-level timeout/blocker contracts, launch cleanup contracts, `unit-1e-validation`, and `unit-1f` route matrix evidence.

### A-002 - Mobile dock is too visually heavy and covers content

- Evidence: `unit-0c-baseline-screenshots/screenshot-routes/recipes/screenshots/ios-mobile.png`, `recipe-detail/screenshots/ios-mobile.png`, `search/screenshots/ios-mobile.png`
- Problem: the floating dock overlapped useful lower content and the selected pill felt like an invented control rather than a native tab/navigation affordance.
- Fixed in: Units 2d, 3c, 3f, 4f, and 4i.
- Verification: `unit-4i/after-feedback-cook-mode/screenshots/ios-mobile.png`, `unit-4f/` search visual QA, route design-review validations, and empty final warning scan.

### A-003 - Stale/offline status treatment is too loud for normal content reading

- Evidence: `recipe-detail/screenshots/ios-mobile.png`, `search/screenshots/ios-mobile.png`, `recipes/screenshots/ios-mobile.png`
- Problem: `Saved copy` and `Saved copy may be stale` were truthful but competed with page identity and normal reading.
- Fixed in: Units 2f, 3c, 3f, 4f, and 4i.
- Verification: Recipe Detail, Recipes, Search, Capture retry/provider-blocked design reviews and `NativeLiveStoreTests/restoreCacheOnlyLaunchModePreservesCaptureImportRetryAndBlockerSeverity`.

### A-004 - Search filter chips overflow at the right edge

- Evidence: `search/screenshots/ios-mobile.png`
- Problem: the horizontal filter row clipped the rightmost chip at the viewport edge.
- Fixed in: Units 4e-4f.
- Verification: native `.searchable`/`.searchScopes` conversion, compact iOS search-field proof, seven Search design-review manifests, and final Search route screenshot packet under `unit-4f/`.

### A-005 - Cook mode bottom controls are bulky and imbalanced

- Evidence: `cook-mode/screenshots/ios-mobile.png`; TestFlight feedback `ACb3UVFX_NSiCkYtg2Wnnnw`.
- Problem: the bottom cook controls were bulky, text-heavy, and visually unbalanced for kitchen-safe use.
- Fixed in: Units 3h-3i and refined in Unit 4i.
- Verification: `unit-4i/after-feedback-cook-mode/screenshots/ios-mobile.png`, `check-native-shell-contract.rb`, `NativeMobileDesignContractTests`, iOS/macOS app-target builds, and empty warning scan.

### A-008 - Recipe photo/admin chrome made real photos look broken

- Evidence: TestFlight feedback `ANvY9In1lrb9GoMUeYuBnog`; earlier recipe detail captures with visible provenance/admin labels and no-photo slabs.
- Problem: recipe detail overlaid provenance/admin copy on the photo and rendered a large fake no-photo hero when a cover was absent.
- Fixed in: Unit 4i.
- Verification: `unit-4i/after-recipe-seed-fix-recipe-detail/screenshots/ios-mobile.png`, `check-native-image-policy-contract.rb`, `NativeMobileDesignContractTests`, iOS/macOS app-target builds, and empty warning scan.

### A-009 - Capture route exposed fake future import promises

- Evidence: Unit 4i capture screenshots and source contracts.
- Problem: Capture still advertised Share Sheet, camera, photo-library, and a separate Siri coming-soon row after the app had committed to MCP agent now and native App Intents/Siri as the real native path.
- Fixed in: Unit 4i.
- Verification: `unit-4i/final-capture-offline-retry/screenshots/ios-mobile.png`, `CaptureImportSurfaceTests`, `NativeMobileDesignContractTests`, and `validate-design-review.rb`.

### A-007 - Recipe Detail macOS yield controls paint as clipped slabs

- Evidence: `unit-3f/before-yield-scale-fix/macos-desktop.png`
- Problem: macOS default button styling made the Recipe Detail yield minus/plus controls render as giant clipped grey slabs.
- Impact: the first viewport looked broken even though the route validation passed.
- Fixed in: Unit 3f.
- Verification: `unit-3f/screenshots/macos-desktop.png`, `unit-3f/visual-absurdity-ledger.md`, focused recipe-detail tests, iOS/macOS app builds, and warning scan.
