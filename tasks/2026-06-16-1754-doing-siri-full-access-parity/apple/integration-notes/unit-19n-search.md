# Unit 19n Search Surface Integration Notes

## Needed Shared Paths

- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`
- `Apps/Spoonjoy/Shared/Views/SearchView.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Sources/SpoonjoyCore/AppState/SearchState.swift`
- `Sources/SpoonjoyCore/Cache/NativeDurableCache.swift`
- `Sources/SpoonjoyCore/Cache/OfflineFreshnessIndicator.swift`
- `Sources/SpoonjoyCore/Features/Search/SearchSurfaceRepository.swift`
- `Sources/SpoonjoyCore/Features/Search/SearchSurfaceViewModel.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`

Web backend contract applied in `spoonjoy-v2`:

- Branch `slugger/api-v1-search`, commit `025bf9c7` (`feat: add api v1 search endpoint`)
- `app/lib/api-v1.server.ts`
- `app/lib/api-v1-contract.server.ts`
- `app/lib/api-v1-openapi.server.ts`
- `app/lib/generated/api-v1-playground.ts`
- `docs/api.md`
- `test/routes/api-v1-search.test.ts`
- API v1 scope, OpenAPI, playground, docs, and warning-hygiene tests touched by `/api/v1/search`

Skill learning captured in `ouroboros-skills`:

- `ourostack/ouroboros-skills#140` adds native/backend contract, offline error-state, privacy-scoped mixed-cache, and cross-repo evidence rules to `build-native-apple-app`.

## Applied Integration

- Added a first-class native `SearchSurfaceRepository` and `SearchSurfaceViewModel` for `/api/v1/search`, with route-aware rows for recipes, cookbooks, chefs, and authenticated shopping-list matches.
- Replaced the placeholder `SearchView` with a native SwiftUI search surface that renders grouped results, empty/loading/error states, cached offline results, unsupported private-scope copy, and feature-owned offline status.
- Wired platform navigation to maintain an active search identity, debounce query changes, cancel stale in-flight requests, normalize unsupported shopping-list scope while signed out, and ignore stale async completions without clearing newer results.
- Persisted search snapshots through `NativeLiveAppStore` and `NativeDurableCache` using query-plus-scope cache domains, while filtering private shopping-list rows before durable fallback restore.
- Restored cached search results into `NativeShellContentState` so offline launch and route-owned search can show honest cached results instead of falling back to shell-level generic offline banners.
- Updated scenario verification and the search/capture/settings static contract so final parity checks prove the native search source rather than a placeholder.
- Added the backend `GET /api/v1/search` contract used by native search, including optional anonymous public results, authenticated owner shopping-list results, OpenAPI/playground/docs coverage, and private/no-store caching for authenticated result sets.

## Reviewer Fixes

- Scoped durable search cache keys by `SearchScope` to prevent recipe, cookbook, chef, and shopping-list collisions for the same query.
- Kept blank-query searches from preserving stale scope-specific cache identities.
- Suppressed duplicate shell offline banners on route-owned surfaces while keeping root/catalog/cook/capture fallback status visible.
- Normalized unsupported signed-out `shopping-list` scope before request/cache work rather than only hiding it in the UI.
- Cleared focused search UI after submitted rows route to their destination.
- Removed stale-completion `activeSearch = nil` assignments so an old success/error cannot wipe newer active results.
- Stopped mapping all uncached search failures to `.offline`; true offline still shows `.offline`, backend/auth/search failures show non-dismissable `.syncFailure`, and cancelled stale searches stay silent.
- Routed native search through the live-store auth-refreshing transport so expired tokens refresh before `/api/v1/search` retries, and mapped `401` search failures to authentication-required state.
- Preserved severe shell statuses on active search pages by including account and severity in the search surface identity instead of letting a cached/live search page hide queued work, conflicts, blockers, or sync failures.
- Scoped unbound authenticated search state by client ID and prevented signed-out/unbound search recording from overwriting an existing real-account durable cache file; the current shell still receives the in-memory live result.
- Triggered deep-linked/restored search routes with a live request using an identity-plus-route task, while deduping submit/debounce races at the `performSearch` boundary with an in-flight `LiveSearchRequestMarker`.
- Clamped native search request limits to the backend-supported `1...50` range before request building, page modeling, cache snapshots, and view-model policy use.

## Validation

- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter NativeSearchSurfaceTests`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter NativeLiveStoreTests/signedOutSearchRecordingDoesNotOverwriteMismatchedDurableAccountCache`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter NativeCacheFreshnessTests`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter SettingsTokenConnectionTests`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter NativeScenarioTests`
- `ruby scripts/check-search-capture-settings-surfaces.rb`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors`
- `swift run SpoonjoyScenarioVerifier --stage final`
- `xcodebuild -quiet -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration Debug -destination 'platform=macOS,arch=arm64,id=00006000-000210690A62801E' MACOSX_DEPLOYMENT_TARGET=26.5 build`
- `xcodebuild -quiet -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=26.5 build`
- `pnpm vitest run test/routes/api-v1-search.test.ts test/routes/api-v1-scopes.test.ts test/routes/api-v1-scopes-public-tokens.test.ts test/lib/api-v1-openapi.server.test.ts test/routes/developers-playground.test.tsx test/scripts/generate-api-playground.test.ts --coverage=false`
- `pnpm vitest run test/docs/developer-platform-docs.test.ts test/lib/recipe-import.test.ts test/routes/api-v1-recipe-spoons.test.ts --coverage=false`
- `pnpm vitest run test/routes/api-v1-search.test.ts test/routes/api-v1-telemetry.test.ts --coverage=false`
- `pnpm run typecheck`
- `pnpm run build`
- `pnpm run test:coverage`

Artifacts:

- `apple/unit-19n-search-surface-green.log`
- `apple/unit-19n-search-cache-ownership-green.log`
- `apple/unit-19n-cache-freshness-green.log`
- `apple/unit-19n-settings-token-green.log`
- `apple/unit-19n-native-scenario-green.log`
- `apple/unit-19n-search-capture-settings-surface.log`
- `apple/unit-19n-swift-full.log`
- `apple/unit-19n-scenario-final.log`
- `apple/unit-19n-macos-build.log`
- `apple/unit-19n-ios-simulator-build.log`
- `apple/unit-19n-web-api-search-contract.log`
- `apple/unit-19n-web-docs-noise-fix.log`
- `apple/unit-19n-web-telemetry-search.log`
- `apple/unit-19n-web-typecheck.log`
- `apple/unit-19n-web-build.log`
- `apple/unit-19n-web-coverage.log`
