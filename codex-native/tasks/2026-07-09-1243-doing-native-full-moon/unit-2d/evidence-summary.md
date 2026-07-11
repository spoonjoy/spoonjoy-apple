# Unit 2d Evidence Summary

Implemented:

- Added centralized `SpoonDockMetrics`.
- Reduced dock max width from raw `351` to `326`.
- Replaced the whole-dock dark `photoCharcoal` capsule with light glass/paper chrome.
- Reduced dock shadow weight.
- Moved icon/text target sizing onto shared metrics.
- Kept the primary action prominent while making support/tool actions quieter.

Validation commands:

```bash
ruby scripts/check-native-shell-contract.rb
ruby scripts/check-native-web-palette-contract.rb
ruby scripts/check-native-design-language.rb
scripts/capture-native-screenshots.sh --artifact-root codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2d/cook-mode-route-retry --unit-slug unit-2d-cook-mode-retry --route cook-mode
ruby scripts/validate-design-review.rb codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2d/cook-mode-route-retry/design-review.json
```

Result:

- Native shell contract passed.
- Native/web palette contract passed.
- Native design-language contract passed.
- Focused cook-mode screenshot capture passed with `design-review.json`.
- Saved `design-review.json` validated.
- iOS and macOS accessibility proof artifacts were emitted.

Visual notes:

- iOS cook-mode dock is materially calmer: narrower, lighter, and no longer a dark heavy bar.
- macOS does not use the mobile `SpoonDock`; its desktop bottom controls still need later cook-mode/macOS adaptation work.
