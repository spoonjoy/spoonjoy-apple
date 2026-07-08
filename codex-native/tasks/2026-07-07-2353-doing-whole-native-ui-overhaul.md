---
schema_version: 1
title: doing-whole-native-ui-overhaul
status: READY_FOR_PUBLISH
created: '2026-07-08T06:53:51Z'
updated: '2026-07-08T06:53:51Z'
track: spoonjoy
repo: spoonjoy-apple
branch: codex-native/whole-ui-overhaul
---

# Doing: Whole Native UI Overhaul

## Units

1. Strengthen shared Kitchen Table theme/components and compact shell chrome.
2. Rebuild primary consumption routes: Kitchen, Recipes, Recipe Detail, Cook Mode, Shopping.
3. Rebuild supporting routes: Search, Cookbooks/detail, Capture, Settings/Profile/Signed-Out.
4. Expand design contracts and screenshot harness route coverage.
5. Capture screenshots, update ledger, run validation.
6. Bump build, archive/export/upload, publish to `Spoonjoy Internal`, and verify ASC attachment.

## Validation Commands

- `ruby scripts/check-launch-screenshot-contract.rb` - passed
- `ruby scripts/check-kitchen-recipe-surfaces.rb` - passed
- `ruby scripts/check-cook-shopping-surfaces.rb` - passed
- `ruby scripts/check-search-capture-settings-surfaces.rb` - passed
- `ruby scripts/check-design-accessibility-contract.rb` - passed
- `swift test --filter NativeMobileDesignContractTests` - passed, 12 tests
- `swift test` - passed, 534 tests
- `xcodebuild build -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug CODE_SIGNING_ALLOWED=NO` - passed
- `xcodebuild build -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination 'generic/platform=iOS Simulator' -derivedDataPath codex-native/tasks/2026-07-07-2353-deriveddata-ios-final CODE_SIGNING_ALLOWED=NO` - passed
- `scripts/capture-native-screenshots.sh --route <route> --artifact-root <path>` - passed for full release sweep and focused copy recapture
- `scripts/check-apple-distribution-kit.sh`
- command documented in `docs/apple-distribution.md` for archive/export
- `scripts/apple-distribution-kit.sh xcode run --kind altool-upload --platform ios --mode apply`
- `scripts/apple-distribution-kit.sh asc get ...`
- `scripts/apple-distribution-kit.sh testflight publish --mode dry-run`
- `scripts/apple-distribution-kit.sh testflight publish --mode apply`
