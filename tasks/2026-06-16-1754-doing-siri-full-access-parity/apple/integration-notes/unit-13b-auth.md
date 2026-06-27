# Unit 13b Auth Integration Notes

## Needed shared paths

- `Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift`
- `Apps/Spoonjoy/Shared/Auth/KeychainTokenVault.swift`
- `Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift`
- `Spoonjoy.xcodeproj/**`
- `scripts/validate-native-local.sh`
- `scripts/run-xcodebuild-with-blocker.sh`

## Expected tokens/tests

- Native OAuth callback is `https://spoonjoy.app/oauth/callback`; custom-scheme OAuth redirects remain rejected.
- App target auth adapters use `ASWebAuthenticationSession.Callback.https(host:path:)` and Keychain-backed `TokenVault` storage.
- Signed-out setup launches a native web-auth session and stores auth material only through Keychain.
- `scripts/run-xcodebuild-with-blocker.sh` is the only matrix boundary that converts local Xcode platform/pre-parse failures into canonical `XcodePlatform` blocker JSON.
- Evidence: `apple/unit-13b-auth-green.log`, `apple/unit-13b-auth-coverage-test.log`, `apple/unit-13b-auth-coverage-enforce.log`, and `apple/unit-13b-auth-warning-scan.log`.

## Patch sketch

- Add SwiftPM-measurable auth lifecycle helpers under `Sources/SpoonjoyCore/Auth`.
- Add app-target Keychain and `ASWebAuthenticationSession` adapters under `Apps/Spoonjoy/Shared/Auth`.
- Wire the signed-out setup surface to start the native OAuth flow with PKCE and the HTTPS universal-link callback.
- Regenerate `Spoonjoy.xcodeproj` so the new app auth files are members of both iOS and macOS targets.
- Route app-bundle validation rows through the xcodebuild blocker wrapper.

## Local non-production signing

- Local simulator and macOS validation uses `CODE_SIGNING_ALLOWED=NO` in `scripts/validate-native-local.sh`.
- TestFlight/App Store distribution remains blocked until Apple Developer Program membership and signing identities are available.
- Free-account device testing can be attempted through Xcode later, but it is not required for the Unit 13b local validation gate.
