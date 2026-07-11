# Unit 3i Visual Absurdity Ledger

## Scope

Cook Mode and Cooks logging, captured on iOS simulator and native macOS.

## Findings

### V-001 - Cook mode duplicated progress language on compact iOS
- Evidence: `cook-mode/screenshots/ios-mobile.png`
- Problem: compact header and body both exposed progress text, making the task state feel noisy.
- Fix: compact header no longer repeats `currentPageProgressLabel`; the body keeps the progress rail.
- Verification: `cook-mode-after/screenshots/ios-mobile.png`

### V-002 - Cook tools floated in the middle of regular-width cook mode
- Evidence: `cook-mode/screenshots/macos-desktop.png`
- Problem: Tools sat as a freestanding blob in the page body, visually unrelated to the header or active step.
- Fix: regular-width header now owns the tools and shopping status row.
- Verification: `cook-mode-after/screenshots/macos-desktop.png`

### V-003 - macOS cook-mode actions were a stretched bottom slab
- Evidence: `cook-mode/screenshots/macos-desktop.png`
- Problem: `Mark done` and secondary controls filled the full width, reading like a broken mobile control deck.
- Fix: regular-width cook mode now uses a compact centered bottom action rail.
- Verification: `cook-mode-after/screenshots/macos-desktop.png`

### V-004 - Cook-log visual QA was not deterministic
- Evidence: before Unit 3i, the capture harness had no `cook-log` route and could only prove recipe detail generally.
- Problem: screenshot feedback on Cooks could be missed because the sheet was not independently routed or proven.
- Fix: added `cook-log` capture route, `SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS`, app-emitted `SpoonCookLogView` proof, manifest validation, and route contract coverage.
- Verification: `cook-log-final/design-review.json`, `cook-log-final/apple/unit-3i-cook-log-final-accessibility-proof-ios.json`, `cook-log-final/apple/unit-3i-cook-log-final-accessibility-proof-macos.json`

### V-005 - Cooks sheet duplicated its own title
- Evidence: `cook-log/screenshots/ios-mobile.png`, `cook-log/screenshots/macos-desktop.png`
- Problem: sheet navigation title and embedded `SpoonCookLogView` header both said "Cooks."
- Fix: `SpoonCookLogView` now takes `showsHeader`; recipe detail embeds the header, sheet presentation suppresses it.
- Verification: `cook-log-final/screenshots/ios-mobile.png`, `cook-log-final/screenshots/macos-desktop.png`

### V-006 - iOS medium Cooks sheet exposed weak background composition
- Evidence: `cook-log-sheet-after/screenshots/ios-mobile.png`
- Problem: medium detent exposed the underlying no-photo recipe placeholder, weakening the sheet screenshot and making the composition feel accidental.
- Fix: iOS returned to full sheet presentation; macOS kept a tighter frame and modal bottom reserve.
- Verification: `cook-log-final/screenshots/ios-mobile.png`

## Accepted Residuals

- Empty cook history naturally leaves open space below "No cooks logged yet." This is not a layout blocker because there is no overlap, no clipped text, and the empty state is quiet. Future richer empty-state content can be handled in a later product unit if desired.
- macOS Cooks modal remains somewhat roomy with an empty fixture, but it is stable, readable, and no longer duplicated or mobile-overstretched.

## Validation

- `swift test --filter 'NativeMobileDesignContractTests|CookModeParityTests|SpoonCookLogSurfaceTests'`
- `swift test`
- `swift test --filter 'NativeScenarioTests/verify native scenarios script gates native metadata behavior'`
- `ruby scripts/check-native-shell-contract.rb`
- `ruby scripts/check-design-accessibility-contract.rb`
- `ruby scripts/check-native-design-language.rb`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `rg -n "warning:|error:"` over final iOS/macOS build logs
