# Unit 19k Notifications/APNs Integration Notes

## Needed shared paths

- `Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift`
- `Apps/Spoonjoy/Shared/Native/NotificationAPNsDeviceBridge.swift`
- `Apps/Spoonjoy/Shared/Views/SettingsView.swift`
- `Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift`
- `Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift`
- `Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift`
- `Apps/Spoonjoy/iOS/SpoonjoyiOSApp.swift`
- `Apps/Spoonjoy/macOS/SpoonjoyMacApp.swift`
- `Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift`
- `Sources/SpoonjoyCore/Native/ScenarioVerifier.swift`

## Applied integration

- Added a first-class `NotificationAPNsSurfaceViewModel` settings section for notification preferences, APNs registration summary, permission-denied state, queue/offline state, and Apple Developer Program capability blockers.
- Added a shared native `NotificationAPNsDeviceBridge` around `UNUserNotificationCenter` permission prompts and platform remote-notification registration callbacks; register-device mutations are created only after a system APNs device token exists.
- Reused existing native REST contracts for `PrivateAccountRequests.notificationPreferences`, `updateNotificationPreferences`, `registerAPNSDevice`, and `revokeAPNSDevice`; no invented APNs status read endpoint was added.
- Routed notification preference updates and APNs register/revoke through the same mutation queue/preflight pattern as other account settings, while permission prompts and device-token acquisition remain online-only.
- Added `OfflineIndicatorBlocker.appleDeveloperProgram(capability:)` so production APNs capability debt is visible without conflating it with provider-secret blockers.
- Restored cached notification preferences and APNs status directly into `NativeShellContentState.notificationAPNsSurfaceData`, preserving runtime platform/APNs environment defaults instead of hardcoding iOS/development.
- Blocked production APNs registration before remote/queue work unless Apple Developer Program capability is available; development registration remains queueable/remote-backed.
- Recorded the canonical blocker at `apple/apple-developer-program-blocker-apns.json` until a paid Apple Developer Program team/signing capability is available.

## Expected tokens/tests

- `swift test --filter NotificationAPNsSurfaceTests -Xswiftc -warnings-as-errors`
- `swift test -Xswiftc -warnings-as-errors`
- `ARTIFACT_ROOT=tasks/2026-06-16-1754-doing-siri-full-access-parity ruby scripts/check-notification-apns-surfaces.rb`
- `scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb`
- `swift run SpoonjoyScenarioVerifier --stage surfaces --output tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-19k-notifications-scenario-surfaces.json`
- `swift run SpoonjoyScenarioVerifier --stage final --output tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-19k-notifications-scenario-final.json`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy macOS" -configuration BootstrapDebug -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `xcodebuild -project Spoonjoy.xcodeproj -scheme "Spoonjoy iOS" -configuration BootstrapDebug -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build`
- `scripts/fail-on-warning.rb` over the Unit 19k evidence logs
- Scenario verifier now exercises typed behavior for cached notification/APNs state, device registration planning, online-only token acquisition, and Apple Developer Program blocker enforcement rather than source-string presence.
