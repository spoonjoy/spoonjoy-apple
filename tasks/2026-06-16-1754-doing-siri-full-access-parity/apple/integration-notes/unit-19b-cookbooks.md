# Unit 19b Cookbooks Integration Notes

## Needed Shared Paths

- `Apps/Spoonjoy/Shared/Views/CookbooksView.swift`
- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`

## Applied Integration

- Added the native cookbook list/detail SwiftUI surface, including cookbook covers, public cookbook `ShareLink`, offline/queued/conflict banners, owner-only rename/add/remove/delete tools, and destructive confirmation dialogs.
- Replaced the app-shell cookbook placeholder with `CookbooksView`, `CookbookDetailRouteView`, `CookbookSurfaceViewModel`, live/fallback repositories, and `performCookbookAction` remote/offline execution.
- Added scenario-verifier coverage for cookbook detail, owner tools, create, rename, delete, add recipe, and remove recipe.
- Kept cookbook writes on the existing REST v1 and durable queue contracts from Units 8c, 11c, and 15c.
- Hardened the reviewer-found action bridge gap by applying `updatedCookbook` back into the visible detail route after successful direct or queued rename/add/remove plans.
- Scoped queued-work and conflict banners to the current cookbook dependency key, so unrelated cookbook mutations do not stale-lock the current detail screen or force unrelated writes into the queue.
- Split list-level creation into `CookbookCreatePlanner` and made scenario/static checks prove the native create sheet calls `planCreate` from `CookbooksView`.
- Applied queued cookbook mutations into shared `NativeShellContentState.cookbooks`, including offline create/rename/delete/add-recipe/remove-recipe optimistic state, so list/detail routes and global search stay coherent while offline.
- Added cookbook drain cache patching in `NativeSyncEngine`, so successfully replayed queued cookbook mutations update the durable cookbook cache instead of disappearing until the next full sync.
- Added cookbook create server-ID remap handling in `NativeSyncEngine`, so drained offline cookbook creates and dependent updates persist under the real backend cookbook ID rather than the temporary local ID.
- Added cookbook create dependent-key bridging, so queued local cookbook creates block live UI writes and sync replay for follow-up mutations targeting `cookbook_local_*` until the create drains.
- Extended the same dependency bridge to recipe-detail save/remove cookbook actions, so saving a recipe into a newly created local cookbook queues behind the pending cookbook create instead of calling REST with a temporary cookbook ID.

## Feature-Local Paths

- `Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceRepository.swift`
- `Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceViewModel.swift`
- `Tests/SpoonjoyCoreTests/CookbookSurfaceParityTests.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift`

## Validation Evidence

- `apple/unit-19b-cookbooks-green.log`
- `apple/unit-19b-cookbooks-live-store.log`
- `apple/unit-19b-cookbooks-recipe-actions.log`
- `apple/unit-19b-cookbooks-sync-engine.log`
- `apple/unit-19b-cookbooks-swift-full.log`
- `apple/unit-19b-cookbooks-surface.log`
- `apple/unit-19b-cookbooks-surface-kitchen-recipe.log`
- `apple/unit-19b-cookbooks-scenario-surfaces.log`
- `apple/unit-19b-cookbooks-xcodebuild-macos.log`
- `apple/unit-19b-cookbooks-xcodebuild-ios.log`
- `apple/unit-19b-cookbooks-ios-app-bundle-blocker.json`

## Blockers

- iOS app-bundle validation is locally blocked by missing iOS 26.5 platform/runtime in Xcode. The macOS app target builds with signing disabled; Xcode emits the existing project-level warning that the app deployment target is 27.0 while the installed SDK tops out at 26.5.
