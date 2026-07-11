# Unit 2a Red Summary

Command:

```bash
ruby -c scripts/check-native-web-palette-contract.rb
ruby scripts/check-native-web-palette-contract.rb > codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2a/check-native-web-palette-contract-red.log 2>&1
```

Expected failure:

- `check-native-web-palette-contract.rb` now scans SwiftUI app surfaces for palette bypasses.
- Current app sources fail with 33 violations across 11 files.
- The failures cover `.foregroundStyle(.secondary)`, `.foregroundStyle(.primary)`, and `.foregroundStyle(.red)` usages that bypass `KitchenTableTheme`.

Most concentrated file:

- `Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift` with 10 violations.

