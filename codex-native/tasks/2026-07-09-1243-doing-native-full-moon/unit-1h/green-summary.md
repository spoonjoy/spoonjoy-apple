# Unit 1h Green Summary

Commands:

```sh
ruby scripts/check-launch-screenshot-contract.rb
scripts/capture-native-screenshots.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1h/cookbook-detail-route --unit-slug unit-1h-cookbook-detail --route cookbook-detail
```

Evidence:

- `check-launch-screenshot-contract-green.log` ends with `launch screenshot contract ok`.
- `cookbook-detail-route/design-review.json` validates and records `screenshotRoute: cookbook-detail`, `cookbookDetailSurface: true`, `cookbookID: cookbook_weeknights`, and iOS/macOS screenshot success.
- `cookbook-detail-route/apple/unit-1h-cookbook-detail-accessibility-proof-ios.json` and `...-macos.json` both prove `route: cookbook-detail` from `CookbookDetailView`.
- `cookbook-detail-route/screenshots/ios-mobile.png` and `.../macos-desktop.png` are nonblank Cookbook Detail captures.

Visual follow-up captured for later UI units:

- Cookbook Detail currently duplicates the cover/title summary before the authored `Cookbook` masthead.
- macOS Cookbook Detail leaves too much empty horizontal space and should be rebalanced in the Cookbooks/Cookbook Detail polish units.
