# Unit 18k Sharing Integration

## Shared Paths Applied

- `Sources/SpoonjoyCore/Features/Sharing/NativeSharePayload.swift`
  - Adds `NativeSharePayload`, `NativePublicShareRoutePolicy`, and `NativeShareSurfaceCatalog`.
  - Public share URLs are limited to exact `https://spoonjoy.app/recipes/{id}` and `https://spoonjoy.app/cookbooks/{id}` object routes.
  - Private native transfer values cover shopping lists, shopping items, spoon cook logs, and capture drafts without generating fake public URLs.
- `Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift`
  - Replaces raw `shareURL` action state with typed optional `NativeSharePayload`.
  - Hides the share action when the recipe canonical URL is not a validated public recipe route.
- `Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift`
  - Uses the typed recipe share payload for the detail `ShareLink`.
- `Apps/Spoonjoy/Shared/AppShell/ShareActions.swift`
  - Delegates toolbar sharing to `NativeSharePayload.publicRoute(_:)`.
  - Does not synthesize HTTPS URLs locally and does not expose private/native-only routes.
- `Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift`
  - Adds `share-cookbook` to the native action metadata.
- `Tests/SpoonjoyCoreTests/NativeScenarioTests.swift`
  - Updates scenario expectations for the new cookbook share action.

## Route And Product Boundary

- Public URL share payloads are allowed only for manifest-classified recipe detail and cookbook detail object routes.
- Cook mode, recipe editor, cover controls, shopping, search, capture/import, settings, unknown links, and unsafe object IDs return no public share URL.
- Capture draft private transfers record only sanitized host metadata for source/captured URLs and never serialize raw URL strings, query parameters, local file paths, or media asset identifiers.
- The surface catalog stays system-share-only with `share-sheet` as the system destination.
- Spoonjoy does not add Messages, Mail, comments, feeds, inboxes, or social posting as native product surfaces in this unit.

## Project Membership

SwiftPM auto-discovers the new sharing source under `Sources/SpoonjoyCore/Features/Sharing`.

The generated Xcode project contract was rerun after adding the file:

- `apple/unit-18k-sharing-generator-contract.log`
- `apple/unit-18k-sharing-project-contract.log`

## Evidence

- `apple/unit-18k-sharing-focused.log`: focused `NativeSharingTests` pass.
- `apple/unit-18k-sharing-affected.log`: affected sharing/action/scenario tests pass.
- `apple/unit-18k-sharing-swift-full.log`: full Swift suite passes with 348 tests in 26 suites.
- `apple/unit-18k-sharing-coverage-test.log`: full Swift coverage run passes.
- `apple/unit-18k-sharing-coverage-enforce.log`: `coverage ok: 100.00% (14977/14977)`.
- `apple/unit-18k-sharing-surface.log`: native sharing surface static contract passes.
- `apple/unit-18k-sharing-scenario-surfaces.log`: scenario surface verifier passes.
- `apple/unit-18k-sharing-xcodebuild-macos.log`: macOS app build succeeds.
- `apple/unit-18k-sharing-xcodebuild-ios-blocker.json`: structured local blocker for missing iOS 26.5 runtime.
- `apple/unit-18k-sharing-warning-scan.log`: warning scan passes.

## Review Fix Evidence

Kant's cold review found that capture draft private transfers leaked raw `sourceURL`/`capturedURL` values. The fix redacts capture share metadata to host-only fields and adds adversarial tests for signed URLs, token query parameters, local media paths, and photo asset identifiers.

- `apple/unit-18k-sharing-review-fix-focused.log`: focused `NativeSharingTests` pass with 9 tests.
- `apple/unit-18k-sharing-review-fix-affected.log`: affected sharing/action/scenario tests pass with 38 tests.
- `apple/unit-18k-sharing-review-fix-swift-full.log`: full Swift suite passes with 350 tests in 26 suites.
- `apple/unit-18k-sharing-review-fix-coverage-test.log`: full Swift coverage run passes.
- `apple/unit-18k-sharing-review-fix-coverage-enforce.log`: `coverage ok: 100.00% (15029/15029)`.
- `apple/unit-18k-sharing-review-fix-surface.log`: native sharing surface static contract passes and forbids raw capture URL/media identifier serialization.
- `apple/unit-18k-sharing-review-fix-xcodebuild-macos.log`: macOS app build succeeds.
- `apple/unit-18k-sharing-review-fix-ios-app-bundle-blocker.json`: structured local blocker for missing iOS 26.5 runtime.
- `apple/unit-18k-sharing-review-fix-warning-scan.log`: warning scan passes.
