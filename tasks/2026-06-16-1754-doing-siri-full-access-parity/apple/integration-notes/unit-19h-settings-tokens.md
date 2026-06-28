# Unit 19h Settings Tokens Integration Notes

## Needed Shared Paths

- `Apps/Spoonjoy/Shared/Views/SettingsView.swift`
- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Sources/SpoonjoyCore/Cache/NativeDurableCache.swift`
- `Sources/SpoonjoyCore/KitchenState/SettingsState.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`
- `Tests/SpoonjoyCoreTests/NativeAuthSessionTests.swift`
- `scripts/smoke-ios-simulator.sh`

## Applied Integration

- Added `SettingsSurfaceRepository` and `SettingsSurfaceViewModel` as the native account settings feature layer for account profile, profile photo, notification preferences, API token metadata, OAuth connections, passkeys, password/provider handoffs, and sign-out state.
- Wired the shared settings view to render native profile edits, PhotosPicker profile-photo staging/removal, notification toggles, token creation/revocation controls, OAuth connection disconnect controls, passkey/password/provider secure handoff links, and online-only disabled/retry state.
- Routed settings action plans through `PlatformNavigationView`, `NativeLiveAppStore.executeSettingsActionRequest`, native mutation queue fallback for profile/photo/notification updates, and secure web handoff/openURL for credential flows.
- Restored settings cache snapshots from durable cache domains and refreshed settings cache data after live bootstrap/drain so offline settings can display account, notification, token, and connection metadata without persisting token secrets.
- Updated the default OAuth scopes to request `account:read` and `account:write`, matching the live `/api/v1/me`, profile-photo, notification-preferences, and connection REST contracts.
- Extended scenario verification and static surface checks so settings parity fails closed if account sections, online-only credential policy, secure handoff, or no-secret rendering disappears.
- Hardened iOS simulator smoke cleanup so generated wrapper test files are removed after the smoke run.

## Expected Tokens And Tests

- `SettingsView` contains native sections for `Profile`, `Notifications`, `API Tokens`, `Connections`, `Passkeys`, `Password`, and `Sign Out`.
- `PlatformNavigationView` passes `contentState.settingsSurfaceViewModel`, `performSettingsAction`, `executeSettingsActionRequest`, and `performSettingsSessionOperation` through the app shell.
- `NativeLiveAppStore` fetches and restores `SettingsSurfaceData` with cache records for settings, notification preferences, token metadata, and connection status.
- `SettingsTokenConnectionTests` prove REST request shape, offline queue policy, credential online-only policy, no secret-bearing token fields, legacy nullable passkey timestamps, and static shared-surface wiring.
- `NativeAuthSessionTests` prove the native OAuth default scope string includes `account:read account:write`.

## Validation Evidence

- `apple/unit-19h-settings-focused-after-v2-api.log`
- `apple/unit-19h-settings-auth-focused-after-v2-api.log`
- `apple/unit-19h-swift-full-after-v2-api.log`
- `apple/unit-19h-scenario-final-after-v2-api.log`
- `apple/unit-19h-search-capture-settings-contract-after-v2-api.log`
- `apple/unit-19h-project-contract-after-v2-api.log`
- `apple/unit-19h-project-generator-contract-after-v2-api.log`
- `apple/unit-19h-native-design-contract-after-v2-api.log`
- `apple/unit-19h-xcodebuild-ios-after-v2-api.log`
- `apple/unit-19h-xcodebuild-macos-after-v2-api.log`
- `apple/unit-19h-smoke-ios-after-v2-api.log`
- `apple/unit-19h-smoke-macos-after-v2-api.log`
- `apple/unit-19h-warning-scan-after-v2-api.log`

## Scope Boundaries

- Profile display/photo and notification preference edits may queue offline; token create/revoke, OAuth disconnect, logout/session revoke, passkey/password/provider-link actions, and credential handoffs remain online-only.
- Token secrets, access-token values, refresh-token values, token hashes, and provider secrets are not rendered, cached, or exposed in native settings.
- Unit 19i remains responsible for the canonical coverage/refactor matrix and screenshot/static coverage refresh for this surface.
