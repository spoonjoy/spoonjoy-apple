# Unit 0b Evidence Summary

- App Store Connect app id: `6787505444`
- Bundle id: `app.spoonjoy`
- Latest valid iOS build: `1.0 (27)`
- Latest valid iOS build id: `c952c059-ecd4-48e7-b68d-dec652d80d0a`
- Uploaded: `2026-07-09T02:11:40-07:00`
- Build beta detail id: `c952c059-ecd4-48e7-b68d-dec652d80d0a`
- Internal build state: `IN_BETA_TESTING`
- Auto notify enabled: `true`
- Internal beta group: `Spoonjoy Internal`
- Internal beta group id: `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`
- Tester count in internal group: `1`
- Internal tester state: `INSTALLED`
- Webhook id: `a8413a12-3003-4790-bca4-4ee03f72b2a7`
- Webhook enabled: `true`
- Feedback records: `11`
- Actionable unhandled feedback: `0`
- Awaiting tester confirmation: `9`
- Reconcile dry run: `ok=true`, `unhandled=0`
- macOS ASC app query for `app.spoonjoy.mac`: `0` apps

## Required Follow-Up

`doctor` reports the installed TestFlight feedback listener, tunnel, and reconcile launchd agents still point at retired `/Users/arimendelow/Projects/spoonjoy-apple-cookmode-ui-pass`. Unit 0e must repair those services from canonical `/Users/arimendelow/Projects/spoonjoy-apple` before Unit 1 begins.
