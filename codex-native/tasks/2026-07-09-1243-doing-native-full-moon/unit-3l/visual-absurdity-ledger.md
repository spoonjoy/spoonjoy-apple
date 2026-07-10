# Unit 3l Visual Absurdity Ledger

Host: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` / OS: `Darwin` / probed: 2026-07-10 03:49 PDT

## Surfaces

- Cookbooks index: iOS compact and macOS regular
- Cookbook detail: iOS compact and macOS regular

## Ledger

| surface | evidence | issue | disposition |
| --- | --- | --- | --- |
| Cookbooks index iOS | `cookbooks/screenshots/ios-mobile.png` | Lead selection chose an empty Inbox-style cookbook, producing a huge fallback cover and pushing actions under the bottom tab chrome. | fixed - lead cookbook now prefers real cover media, then higher recipe count; compact layout places story/actions before the cover and reserves enough bottom space. Final proof: `cookbooks-after/screenshots/ios-mobile.png`. |
| Cookbooks index macOS | `cookbooks/screenshots/macos-desktop.png` | The shelf spread was acceptable but did not use the best food-led cookbook when better media existed. | fixed - same media/count lead ranking gives the desktop shelf a real food object. Final proof: `cookbooks-after/screenshots/macos-desktop.png`. |
| Cookbook detail iOS | `cookbook-detail/screenshots/ios-mobile.png` | No-photo cookbook cover rendered duplicate title treatment: the fallback paper cover plus the dark photo overlay fought each other. | fixed - photo overlay now renders only for image-backed covers. Final proof: `cookbook-detail-title-fit-final/screenshots/ios-mobile.png`. |
| Cookbook detail macOS | `cookbook-detail/screenshots/macos-desktop.png` | Detail header was bottom-aligned to the cover, leaving a large dead upper field and weaker desktop balance. | fixed - detail spread now top-aligns the story and cover with platform-specific cover widths. Final proof: `cookbook-detail-title-fit-final/screenshots/macos-desktop.png`. |
| Cookbook detail macOS | `cookbook-detail-title-fit-final/screenshots/macos-desktop.png` | Independent review passed but noted the Share action still floated too loosely between the title and cover. | fixed - Share is grouped under the detail heading and the desktop story column is constrained so the spread reads as one object. Final proof: `cookbook-detail-share-grouping-final/screenshots/macos-desktop.png`. |
| Cookbook detail contents | `cookbook-detail/screenshots/ios-mobile.png` | Recipe rows without real media showed thumbnail placeholders that looked like default/fake imagery. | fixed - contents rows render thumbnails only when a real `coverImageURL` exists; no-photo rows become clean numbered contents entries. Final proof: `cookbook-detail-title-fit-final/screenshots/ios-mobile.png`. |
| Cookbook fallback typography | `cookbook-detail-final/screenshots/ios-mobile.png` | The fallback cover split "Weeknights" awkwardly, making the no-photo state feel broken. | fixed - fallback title uses a smaller serif style with tightening and scale factor so ordinary cookbook names stay intact. Final proof: `cookbook-detail-title-fit-final/screenshots/ios-mobile.png`. |
| Cookbook detail capture retry | `cookbook-detail-after/design-review-blocked.json` | One iOS/macOS recapture was blocked by a CoreSimulator launch timeout. | fixed - reset simulator state with `xcrun simctl shutdown all` and reran capture successfully. Final proof: `cookbook-detail-title-fit-final/design-review.json`. |

## Final Checks

- `swift test --filter 'NativeMobileDesignContractTests/cookbookSurfacesUseAuthoredShelfSpreadAndNativeContentsGrammar|CookbookSurfaceParityTests/cookbookListAndDetailLoadLiveStateSharePayloadsAndOwnerTools'`
- `ruby scripts/validate-design-review.rb codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-3l/cookbooks-after/design-review.json`
- `ruby scripts/validate-design-review.rb codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-3l/cookbook-detail-share-grouping-final/design-review.json`

## Remaining Notes

- The cookbook detail no-photo cover is intentionally honest paper, not a fake food image. It remains visually quiet and should be revisited only if the product chooses a stronger no-photo editorial asset policy.
- Independent reviewer Curie returned PASS, then the lone non-blocking Share-grouping nit was fixed and recaptured.
- No `ready` or `needs reviewer gate` cookbook ledger items remain.
