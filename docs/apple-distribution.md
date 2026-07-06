# Apple Distribution

Spoonjoy Apple uses the shared `ourostack/apple-distribution-kit` contract for
Apple distribution planning and TestFlight publishing. The native app manifest
is `distribution/apple-distribution.json`; it targets the primary iOS bundle ID
`app.spoonjoy`.

Current scope:

- iOS/TestFlight internal beta publishing through `ourostack/apple-distribution-kit`.
- No public App Store submission from this branch.
- No Apple credentials in source.

Validate the contract with:

```bash
scripts/check-apple-distribution-kit.sh
```

The check validates the native Xcode project contract, the TestFlight export
options, the manifest, the shared kit dry-run plan, and the TestFlight plan. It
also rejects committed Apple credential files.

## TestFlight Flow

The manifest declares the canonical Apple provider (`9735080289`) and the first
beta group, `Spoonjoy Internal`. The package command archives the `Spoonjoy iOS`
Release scheme and exports an IPA under `build/apple/testflight/` using
`distribution/ExportOptions.testflight.plist`.

`scripts/package-testflight-ios.sh` defaults
`SPOONJOY_TESTFLIGHT_IOS_DEPLOYMENT_TARGET` to `26.0` so the archive is accepted
by the installed Xcode 26.x iOS SDK. Override it when building with an SDK that
supports the repo's iOS 27 baseline.

```bash
scripts/check-apple-distribution-kit.sh

scripts/apple-distribution-kit.sh testflight plan \
  --manifest distribution/apple-distribution.json \
  --channel ios-testflight \
  --json

scripts/package-testflight-ios.sh

ASC_CONFIG="${APPLE_DISTRIBUTION_KIT_CONFIG:-$HOME/Library/Application Support/AppleDistributionKit/app-store-connect/config.json}"
ASC_API_KEY="$(jq -r '.keyId' "$ASC_CONFIG")"
ASC_API_ISSUER="$(jq -r '.issuerId' "$ASC_CONFIG")"
ASC_P8_FILE="$(jq -r '.privateKeyPath' "$ASC_CONFIG")"

scripts/apple-distribution-kit.sh xcode run \
  --kind altool-upload \
  --mode apply \
  --package-path build/apple/testflight/Spoonjoy.ipa \
  --platform ios \
  --api-key "$ASC_API_KEY" \
  --api-issuer "$ASC_API_ISSUER" \
  --p8-file-path "$ASC_P8_FILE" \
  --provider-public-id 9735080289 \
  --json
```

After App Store Connect shows the uploaded build as `VALID`, use the queried
App Store Connect IDs to publish it to the internal group:

```bash
scripts/apple-distribution-kit.sh asc get \
  --path /v1/apps \
  --query 'filter[bundleId]=app.spoonjoy' \
  --query 'limit=1' \
  --json

scripts/apple-distribution-kit.sh asc get \
  --path /v1/builds \
  --query "filter[app]=$ASC_APP_ID" \
  --query 'filter[preReleaseVersion.platform]=IOS' \
  --query 'filter[processingState]=VALID' \
  --query 'sort=-uploadedDate' \
  --query 'include=buildBetaDetail' \
  --json

scripts/apple-distribution-kit.sh asc get \
  --path "/v1/apps/$ASC_APP_ID/betaGroups" \
  --json

scripts/apple-distribution-kit.sh testflight publish \
  --mode dry-run \
  --manifest distribution/apple-distribution.json \
  --channel ios-testflight \
  --app-id "$ASC_APP_ID" \
  --build-id "$ASC_BUILD_ID" \
  --build-beta-detail-id "$ASC_BUILD_BETA_DETAIL_ID" \
  --group-id "Spoonjoy Internal=$ASC_INTERNAL_GROUP_ID" \
  --artifact artifacts/apple/testflight-publish-plan.json \
  --json

scripts/apple-distribution-kit.sh testflight publish \
  --mode apply \
  --manifest distribution/apple-distribution.json \
  --channel ios-testflight \
  --app-id "$ASC_APP_ID" \
  --build-id "$ASC_BUILD_ID" \
  --build-beta-detail-id "$ASC_BUILD_BETA_DETAIL_ID" \
  --group-id "Spoonjoy Internal=$ASC_INTERNAL_GROUP_ID" \
  --json
```

Verify the internal group has both the build and at least one tester before
declaring the TestFlight lane complete:

```bash
scripts/apple-distribution-kit.sh asc get \
  --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds" \
  --query 'limit=50' \
  --json

scripts/apple-distribution-kit.sh asc get \
  --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters" \
  --query 'limit=200' \
  --json

scripts/apple-distribution-kit.sh asc get \
  --path "/v1/buildBetaDetails/$ASC_BUILD_BETA_DETAIL_ID" \
  --json
```

The internal group is incomplete if the tester count is zero, even when the
build relationship exists. In that case, do not return control. Use the App
Store Connect API with the same Apple Distribution Kit credentials to create or
reuse a `betaTesters` record for an existing App Store Connect user, attach it
to `Spoonjoy Internal`, and send a `betaTesterInvitations` request for the
Spoonjoy app:

- `POST /v1/betaTesters` with the user's first name, last name, email, and a
  `betaGroups` relationship to `$ASC_INTERNAL_GROUP_ID`.
- `POST /v1/betaTesterInvitations` with `app=$ASC_APP_ID` and the resulting
  `betaTester=$ASC_BETA_TESTER_ID`.

After adding the tester, re-run the verification commands above. A successful
internal-only publish should show the build in the group, a nonzero tester
count, and `internalBuildState` as `IN_BETA_TESTING`.

Do not use `POST /v1/buildBetaNotifications` as the internal invitation path.
Apple rejects that endpoint for internal-only builds that have not been made
externally testable; use `betaTesterInvitations` instead.

External TestFlight and public App Store submission are intentionally outside
this lane.

## Reactive TestFlight Feedback

Spoonjoy uses an App Store Connect webhook for TestFlight screenshot and crash
feedback so Codex only wakes when Apple reports new tester feedback. The local
listener is `scripts/testflight-feedback-autopilot.mjs`; it verifies Apple's
HMAC signature, fetches the exact App Store Connect feedback record, downloads
submitted screenshots, de-dupes feedback IDs that were already handled, and
launches a detached `codex exec` worker with the feedback artifacts attached.

Seed existing feedback before enabling a webhook, otherwise historical TestFlight
submissions can look new:

```bash
scripts/testflight-feedback-autopilot.mjs seed-current
```

Register or update the App Store Connect webhook after the public tunnel is
reachable:

```bash
scripts/testflight-feedback-autopilot.mjs register \
  --url https://spoonjoy-testflight-feedback.ouro.bot/app-store-connect/webhook
```

The webhook must stay enabled for:

- `BETA_FEEDBACK_SCREENSHOT_SUBMISSION_CREATED`
- `BETA_FEEDBACK_CRASH_SUBMISSION_CREATED`

Validate the path after registration:

```bash
curl -fsS http://127.0.0.1:48973/health | jq .
curl -fsS https://spoonjoy-testflight-feedback.ouro.bot/health | jq .

scripts/testflight-feedback-autopilot.mjs smoke
scripts/testflight-feedback-autopilot.mjs ping
scripts/testflight-feedback-autopilot.mjs deliveries
scripts/testflight-feedback-autopilot.mjs doctor | jq \
  '{ok, health, handledInstanceIds, launchedEventIds, registeredWebhooks}'
scripts/testflight-feedback-autopilot.mjs status
scripts/testflight-feedback-autopilot.mjs status --plain

scripts/apple-distribution-kit.sh asc get \
  --path /v1/apps/6787505444/webhooks \
  --json
```

The durable local jobs are launchd user agents:

- `com.spoonjoy.testflight-feedback-listener`
- `com.spoonjoy.testflight-feedback-tunnel`
- `com.spoonjoy.testflight-feedback-reconcile`

Check them with:

```bash
uid="$(id -u)"
launchctl print "gui/$uid/com.spoonjoy.testflight-feedback-listener"
launchctl print "gui/$uid/com.spoonjoy.testflight-feedback-tunnel"
launchctl print "gui/$uid/com.spoonjoy.testflight-feedback-reconcile"
```

The listener verifies Apple's `x-apple-signature` header by comparing the raw
request body against the configured secret using the documented
`hmacsha256=<hex>` HMAC-SHA256 format. If a delivery fails, inspect Apple-side
delivery records with:

```bash
scripts/testflight-feedback-autopilot.mjs deliveries \
  --since "$(date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ')"
```

If Apple shows feedback that was not processed locally, reconcile it without a
Codex heartbeat:

```bash
scripts/testflight-feedback-autopilot.mjs reconcile --dry-run
scripts/testflight-feedback-autopilot.mjs reconcile
```

If a feedback item was processed but the downstream Codex run failed, make that
specific item retryable and launch it again:

```bash
scripts/testflight-feedback-autopilot.mjs retry --instance-id "$ASC_FEEDBACK_INSTANCE_ID"
```

Do not re-enable a Codex heartbeat poller for this lane unless both webhooks and
the local reconcile job are unavailable. Heartbeats spend agent turns even when
no feedback exists; this webhook-plus-reconcile path leaves Codex idle until
Apple emits or exposes a new feedback event.
