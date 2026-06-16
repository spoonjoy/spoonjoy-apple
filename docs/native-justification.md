# Native Justification

Spoonjoy Apple earns being native by making cooking, grocery, and capture flows faster, more available, and more integrated than a web surface can be. The app must still feel like Spoonjoy: food first, cookbook-like detail, receipt-like shopping, calm controls, and the Kitchen Table hierarchy from the web product.

## Native Workflows

- Cook mode stays usable offline, preserves progress locally, and gives large kitchen-safe controls for the current step.
- Shopping checkoff is fast and local-first, with receipt rows, native edit/check controls, and queued sync back to `spoonjoy.app`.
- Recipe and cookbook browsing use native navigation, search, share, and platform layouts instead of a web clone.
- Capture creates local drafts from native entry points without pretending the REST API already supports production recipe writes.
- Settings exposes auth, offline, environment, and validation state in native forms.

## Accepted Native Platform Levers

- SwiftUI navigation with `NavigationStack` on compact layouts and `NavigationSplitView` on macOS and desktop-class layouts.
- App Intents for `OpenRecipeIntent`, `StartCookModeIntent`, and `AddShoppingListItemIntent`.
- Spotlight metadata for recipes, cookbooks, shopping items, and searchable scopes.
- Share actions, toolbars, `.searchable`, edit mode, check controls, forms, and platform keyboard behavior.
- Offline local state for recipes, cook progress, shopping checkoff, capture drafts, and sync checkpoints.
- Keychain-ready token storage and OAuth/PKCE through the Spoonjoy OAuth paths.

## Rejected Or Later Platform Levers

- TestFlight and App Store distribution wait for Apple Developer Program membership.
- Widgets, Watch, Live Activities, lock-screen surfaces, barcode flows, OCR, Photos, Camera, and Foundation Models are later only if they make a specific cooking or shopping workflow better.
- Custom web-styled controls are rejected when native controls carry the premium interaction.
- API v1 token-management builders are out of this slice; OAuth token exchange uses `/oauth/token`.
- The alternate commercial domain is not used; the product domain is `spoonjoy.app`.

## Shared With Web And Backend

- Canonical recipe, cookbook, shopping, OAuth, and idempotency contracts stay with the Spoonjoy v2 backend.
- The native app consumes `/api/v1/recipes`, `/api/v1/cookbooks`, shopping-list endpoints, and OAuth paths instead of duplicating server policy.
- Design language comes from the web Kitchen Table system, translated into native navigation and controls.
- Production recipe creation remains a backend/API responsibility; this slice supports local capture drafts.

## Design Language Invariants

- Food or a real cooking object leads every primary screen.
- Recipe detail keeps cookbook authorship: hero/provenance/actions, ingredient receipt, and numbered method sections.
- Shopping lists feel like receipts with large check targets.
- Cook mode is focused on one step, with persistent progress and few distractions.
- Search uses typed scopes and native result rows.
- Colors, typography, spacing, and hierarchy should preserve Kitchen Table warmth without turning into generic grouped SwiftUI screens.

## Platform Differences

- iOS uses compact navigation, thumb-friendly actions, and focused cook/shopping flows.
- macOS uses split navigation, toolbar placement, keyboard navigation, and desktop-class screenshot review.
- Shared domain, API, offline, App Intents metadata, and scenario verification live outside app-target view code.

## Bootstrap Validation And Product Baseline

- Product baseline remains iOS 27 and macOS 27 forward.
- This machine and GitHub `macos-26` runners validate with Xcode 26.5 before Xcode 27 is available.
- `BootstrapDebug` may use `IPHONEOS_DEPLOYMENT_TARGET = 26.5` for iOS simulator bootstrap builds.
- `BootstrapDebug` must use `MACOSX_DEPLOYMENT_TARGET = 26.2` because this local macOS 26.2 host must run mandatory macOS launch/smoke.
- Product Debug and Release configs keep iOS 27/macOS 27 deployment targets.
- Local simulator and macOS validation come before paid signing; TestFlight waits for Apple Developer Program membership.
