# Local Non-Production Signing

Spoonjoy Apple validates locally before paid Apple Developer Program signing is available.

- SwiftPM tests and native static contracts do not require signing.
- Local iOS simulator bundle validation should pass `CODE_SIGNING_ALLOWED=NO`.
- Local macOS structural builds may pass with signing disabled, but launch/dogfood smoke needs Xcode's ad-hoc "Sign to Run Locally" identity. `BootstrapDebug` strips restricted Apple Developer Program entitlements so the app can launch before paid signing is configured; signed Debug/Release builds keep the production entitlement file.
- The validation matrix records local Xcode platform/pre-parse failures as `XcodePlatform` blockers only through `scripts/run-xcodebuild-with-blocker.sh`.
- TestFlight, App Store Connect upload, APNs production capabilities, and App Store distribution require Apple Developer Program membership and are account/capability blockers until available.
