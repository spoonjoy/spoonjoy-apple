# Unit 22t Profile/Settings Intents

Implemented Siri/App Intents coverage for the settings surface without adding new product surfaces.

## Scope

- Added library-only App Intents for opening settings, updating profile display/photo, removing profile photo, opening/managing API token metadata, opening/managing account connections, passkeys, password, provider linking, logout, and current-session revoke.
- Added `SpoonjoyAPITokenEntity` and `SpoonjoyAccountConnectionEntity` backed by cached settings metadata so Siri resolves real tokens/connections instead of string IDs.
- Added `SpoonjoySettingsAuthProviderOption` as an AppEnum for provider-link handoff.
- Extended `NativeIntentActionResolver` with settings actions that reuse `SettingsActionPlanner`, `SettingsProfilePhotoStagingPolicy.webProfileParity`, `TokenCredentialRequests`, and `PrivateAccountRequests`.
- Updated native capability metadata and scenario verifier with `Profile and settings Siri intents`.

## Behavior

- Profile display, profile photo upload, and profile photo removal execute through the same settings planner policy as native Settings: remote-first while online, with durable offline fallback only when transport classifies the request as offline.
- Profile display/photo Siri dialogs now reflect what actually happened: completed live work says updated/removed, while offline fallback says queued.
- API token create/revoke and account connection disconnect are online-only and are not queued.
- API token creation opens Spoonjoy settings instead of generating the one-time credential inside Siri; this preserves the first-party UI path that can actually show the secret.
- Settings REST execution uses a refresh-capable `URLSessionAPITransport` configuration instead of reading a raw keychain access token, so expired-but-refreshable sessions match native Settings behavior.
- Siri settings connectivity and OAuth refresh helpers share a file-level offline classifier aligned with core `URLSessionAPITransport`, including timeout and call-active conditions.
- Current-session revoke calls the OAuth revoke endpoint before local keychain/client-id cleanup.
- Settings entity display uses account/environment-safe labels and keeps raw account IDs out of visible Siri metadata.
- Passkey, password, and provider-link actions open secure handoff URLs:
  - `https://spoonjoy.app/account/settings#passkeys`
  - `https://spoonjoy.app/account/settings#password`
  - `https://spoonjoy.app/auth/{provider}?linking=true`
- Online-only settings/security actions use a bounded connectivity probe and return the explicit "not queued" offline response instead of silently persisting unsafe work.

## Validation

- `ruby scripts/check-app-intents-contract.rb --domain profile-settings-intents`
- `swift test --disable-xctest --parallel -Xswiftc -warnings-as-errors --filter ProfileSettingsIntentTests`
- `ruby scripts/check-xcode-project-contract.rb`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Secret/static scan: no profile/settings Siri token secrets or invented product-surface markers.
- `git diff --check`

The app builds succeeded and AppIntents metadata exported for both app targets. The captured Xcode logs contain the existing local SDK mismatch warnings because this repo targets iOS/macOS 27.0 while the installed SDKs are 26.5.
