# Unit 2i Absurdity Ledger

## Closed

- Compact tab bar overlap: `KitchenTableTheme.compactDockReserve` now reserves 148pt, and iOS uses an opaque Spoonjoy-bone `UITabBarAppearance` instead of letting recipe rows ghost through the floating tab bar.
- Nav chrome ghosting: compact `NavigationStack` now pins the navigation bar background to `KitchenTableTheme.bone` with a visible toolbar background.
- Fake no-photo imagery: `RecipeCoverImage` no longer draws decorative stripes, fake initials, food-ish symbol art, or random-looking placeholders; no-cover surfaces are quiet and honest with `Photo not added` language.
- Recipe detail false hero: detail pages only render the large cover hero when a real cover image URL exists.
- Cookbook detail fake cover: cookbook detail no longer creates a blank cover block when there is no real primary image.
- Notification settings internal copy: APNs/device implementation fields moved behind a collapsed `Details` disclosure; the visible page now says `This Device`, `Push Delivery`, and product-level delivery state.
- Notification permission clutter: a registered device no longer shows a redundant permission request button, and the destructive action is phrased as `Stop on This Device`.
- Notification save-state slab: unchanged notification preferences no longer render a large disabled `Save Notifications` action; the button appears only when the draft has changes.
- Notification screenshot focus: settings notification captures now scroll to `This Device` with `This Device`, `Push Delivery`, and `Notification Sync` in proof instead of clipping the previous settings section.
- Section-title fit: shared `KitchenTableSection` titles now stay on one line and make the divider yield, fixing the mobile `Notification Sync` wrap.
- Screenshot harness flake: the iOS simulator resolver now supports `SPOONJOY_IOS_SIMULATOR_UDID` and `SPOONJOY_IOS_SIMULATOR_NAME`, so agents can steer around a wedged simulator without editing scripts.
- Dedicated simulator selection: explicit simulator UDIDs now work even when the device name is not prefixed with `iPhone`, so a fresh `Spoonjoy Codex Fresh iPhone 17 Pro Max` simulator can be used for deterministic visual QA.
- Default simulator selection: the resolver now prefers shutdown iPhone simulators before already-booted ones.
- Stale visual proof: the final matrix is now a fresh 11-route pass from current source, not a stitched rerun summary from before the late notification focus fixes.
- Cookbook no-cover language: `RecipeCoverImage` now respects contextual missing-media subtitles such as `Cookbook cover not added` instead of flattening every missing state into generic recipe-photo copy.
- Stale no-photo call sites: route callers no longer pass the legacy missing-photo phrase, so accessibility/failure paths also use `Photo not added` unless a more contextual missing-media label is provided.
- Notification proof/doc drift: `docs/native-design-language.md` now matches the focused settings-notification proof fields emitted by the app and validated in the fresh matrix.

## Evidence

- Fresh full matrix: `unit-2i/final-clean-route-matrix/apple/unit-2i-final-clean-route-matrix-route-matrix.json`
- iOS contact sheet: `unit-2i/final-visual-summary/ios-contact-sheet.png`
- macOS contact sheet: `unit-2i/final-visual-summary/macos-contact-sheet.png`
- Focused notification proof: `unit-2i/final-clean-route-matrix/screenshot-routes/settings-notifications/design-review.json`
- CoreSimulator diagnosis: `unit-2i/apple/unit-2i-simctl-devices-after-data-migration-failed.json`
- Resolver contract: `unit-2i/check-launch-screenshot-contract-after-resolver-fixture-printf.log`
- Final-source contracts: `unit-2i/swift-test-native-mobile-design-after-no-photo-callsite-fix.log`, `unit-2i/static-contracts-after-no-photo-callsite-fix.log`, and `unit-2i/warning-scan-after-no-photo-callsite-fix.log`
- Final-source app builds: `unit-2i/final-xcodebuild-ios-after-no-photo-callsite-fix.log` and `unit-2i/final-xcodebuild-macos-after-no-photo-callsite-fix.log`

## Routed Forward

- Settings still exposes API token management low on the signed-in settings surface. It is not part of the notification/APNs blocker, but it should be revisited with the import/MCP workflow language in the settings/import units.
- Search scope chips are functionally stable but visually cramped on narrow iPhone. Keep this for the Search workflow units instead of mixing route-specific redesign into the shared substrate pass.
