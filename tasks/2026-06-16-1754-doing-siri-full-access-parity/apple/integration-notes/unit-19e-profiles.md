# Unit 19e Profiles Integration Notes

## Applied Shared Paths

- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift`
- `Apps/Spoonjoy/Shared/Views/ProfileView.swift`
- `Sources/SpoonjoyCore/AppState/AppRoute.swift`
- `Sources/SpoonjoyCore/AppState/DeepLinkRouter.swift`
- `Sources/SpoonjoyCore/AppState/DeepLinkURLBuilder.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Sources/SpoonjoyCore/Features/Sharing/NativeSharePayload.swift`
- `Sources/SpoonjoyCore/Native/DeepLinkManifest.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
- `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`
- `scripts/check-search-capture-settings-surfaces.rb`
- `Spoonjoy.xcodeproj/project.pbxproj`

## Expected Tokens And Tests

- `ProfileRouteView`, `ProfileView`, `ProfileGraphRouteView`, `ProfileHero`, `ProfileRecipeShelf`, `ProfileCookbookShelf`, `RecentSpoonsSection`, `FellowChefsSection`, and `KitchenVisitorsSection` are present in the shared SwiftUI profile surface.
- Chef search rows route to `AppRoute.profile(identifier:)` instead of mutating search into a chef-scope placeholder.
- Profile detail and graph routes are registered for app state, web links, custom URL-scheme URLs, scenario metadata, and the native manifest.
- Public native sharing remains first-class for recipes and cookbooks only; profile graph routes are navigable but do not mint public share payloads.
- Scenario verification includes `profile detail`, `fellow chefs`, and `kitchen visitors` checks.
- Signed-out handoff labels cover profile and profile-graph routes so app-target switches remain exhaustive.

## Validation

- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter ProfileChefGraphSurfaceTests`
- `ruby scripts/check-search-capture-settings-surfaces.rb`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter DeepLinkRouterTests`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors`
- `scripts/verify-native-scenarios.sh --stage surfaces`
- `scripts/verify-native-scenarios.sh --stage final`
- `scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb`
- `scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb`
- `scripts/run-xcodebuild-with-blocker.sh ... "Spoonjoy macOS" ... build`

Artifacts:

- `apple/unit-19e-profiles-green.log`
- `apple/unit-19e-full-swift-test.log`
- `apple/unit-19e-scenario-static-project.log`
- `apple/unit-19e-xcodebuild-macos.log`
- `apple/unit-19e-xcodebuild-ios-blocker.json`
