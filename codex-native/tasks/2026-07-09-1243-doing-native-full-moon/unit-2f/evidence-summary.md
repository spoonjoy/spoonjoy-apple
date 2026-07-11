# Unit 2f Evidence Summary

Implemented:

- Added shared `KitchenTableLoadingStateView` and `KitchenTableRouteErrorView`.
- Replaced route-level raw `ProgressView()` loading chrome in guarded route wrappers.
- Removed generic user-facing `unavailable` route copy from guarded loading/error paths.
- Made search thumbnail image transitions respect Reduce Motion.
- Quieted informational offline/stale foreground color to `KitchenTableTheme.inkMuted` when `OfflineStatusView` is quiet.
- Regenerated `Spoonjoy.xcodeproj` so the new shared component is included in iOS and macOS targets.

Validation commands:

```bash
ruby scripts/check-native-loading-transition-contract.rb
ruby scripts/generate-xcode-project.rb
ruby scripts/check-native-web-palette-contract.rb
ruby scripts/check-native-design-language.rb
ruby scripts/check-native-shell-contract.rb
ruby scripts/check-xcode-project-contract.rb
ruby scripts/check-xcode-generator-contract.rb
scripts/run-xcodebuild-with-blocker.sh --output codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/apple/unit-2f-xcodebuild-ios-nosign.log --blocker codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/apple/unit-2f-xcodebuild-ios-nosign-blocker.json --timeout-seconds 240 -- xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy iOS' -configuration BootstrapDebug -destination 'generic/platform=iOS' -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/DerivedData-iOS-NoSign CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build
scripts/run-xcodebuild-with-blocker.sh --output codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/apple/unit-2f-xcodebuild-macos.log --blocker codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/apple/unit-2f-xcodebuild-macos-blocker.json --timeout-seconds 240 -- xcodebuild -project Spoonjoy.xcodeproj -scheme 'Spoonjoy macOS' -configuration BootstrapDebug -destination 'generic/platform=macOS' -derivedDataPath codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-2f/DerivedData-macOS GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

Result:

- Loading/transition contract passed.
- Palette, design-language, shell, Xcode project, and generator contracts passed.
- iOS no-sign target build passed.
- macOS target build passed.

