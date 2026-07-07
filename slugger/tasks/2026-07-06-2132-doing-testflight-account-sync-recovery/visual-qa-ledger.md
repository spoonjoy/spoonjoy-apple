# Visual QA Ledger: TestFlight Account Sync Recovery

## Surfaces
- TestFlight feedback screenshot `AJ7exc318RDe20udjiB1_DI`: iPhone Account screen stuck on offline cache with "Sync could not finish".
- Fixed macOS Settings unavailable-account state: `screenshots/macos-desktop.png`.
- Existing loaded iOS Settings profile state: `screenshots/ios-mobile.png`.

## Findings
- `screenshots/macos-desktop.png`: The unavailable Account state now explains that account data has not loaded and exposes `Try Sync Again`; no overlap, clipped text, or dead-end status-only UI observed. Disposition: fixed.
- `screenshots/ios-mobile.png`: Loaded Settings profile fixture still renders without overlap or truncated controls after the SettingsView change. Disposition: accepted.

## Validation
- `design-review.json` passed with no blockers.
- Accessibility proof artifacts were emitted by the running Spoonjoy app for iOS and macOS.
