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
`distribution/ExportOptions.testflight.plist`. The package script redacts App
Store Connect authentication arguments from streamed `xcodebuild` output.

`scripts/package-testflight-ios.sh` defaults
`SPOONJOY_TESTFLIGHT_IOS_DEPLOYMENT_TARGET` to `26.0` so the archive is accepted
by the installed Xcode 26.x iOS SDK. Override it when building with an SDK that
supports the repo's iOS 27 baseline.

Set `SPOONJOY_TESTFLIGHT_BUILD_NUMBER` to let automation archive a build number
that is newer than the checked-in `CURRENT_PROJECT_VERSION`. CI uses a dynamic
build number so TestFlight publishing does not require source-only build bump
commits.

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

## Exact-SHA TestFlight Release

`.github/workflows/testflight.yml` is a release-candidate dispatch, not a CI
side effect. No push, pull request, or completed workflow publishes automatically.
Dispatch the workflow from its trusted `main` definition and
provide the full lowercase 40-character `source_sha` to release.

For an ordinary release, `source_sha` must equal the current `main` head. The
verifier checks out that exact SHA and requires a successful `Native` push run
whose head is that exact SHA. All protected jobs must be present and successful: `Swift
tests`, `Native scenario verifier`, `App bundle`, and `Coverage`. A fifth job,
`TestFlight release note`, runs only after those checks and uploads
`testflight-release-notes-<source_sha>`. The note JSON embeds its source SHA,
Native run ID and attempt, generation time, and current commit subject. The
release fails closed when the run, a required job, the artifact, or any embedded
provenance is missing, unsuccessful, expired, stale, or mismatched.

The workflow pins every external action to a full commit SHA. Its checkout of
`ourostack/apple-distribution-kit` is also pinned to an audited full commit SHA,
then built with pinned Node `22.17.1` from its lockfile under
`.ci/apple-distribution-kit`. The complete generated `dist/` tree must match the
audited aggregate SHA-256
`9f64507b03a5dc76a6ebc52f88cddf71f9448a8e532e4758951d2d31309d5a45`.
Only after the
candidate verifier succeeds does the job prepare App Store Connect credentials,
compute the next dynamic build number, archive the exact source, upload the IPA,
wait for Apple to mark it `VALID`, dry-run and apply the internal publish, and
verify membership in `Spoonjoy Internal`.

Release-control scripts remain checked out at the trusted workflow's exact
`main` SHA. The selected app commit is checked out separately under
`release-source/`, so an explicit rollback changes the app source being built
without reverting the verifier or publish-control logic that authorizes it.

The GitHub-hosted runner trust boundary still includes the runner image, Xcode,
and the runner-provided `gh` client. The workflow uses `gh` only for read-only
GitHub evidence queries and exact-run artifact download; source-changing actions,
the Node setup action, toolkit source, dependency lockfile, and generated toolkit
output are independently pinned or checksum-verified.

Use GitHub's **Run workflow** form on `main`, or dispatch explicitly:

```bash
gh workflow run testflight.yml \
  --ref main \
  -f source_sha="$(git rev-parse origin/main)" \
  -f allow_rollback=false
```

The optional `build_number` input maps to
`SPOONJOY_TESTFLIGHT_BUILD_NUMBER`; leave it empty unless App Store Connect
requires a specific recovery number.

### Rollback

TestFlight builds are immutable, so rollback means republishing a last known-good main commit
as a new TestFlight build number. Select the exact older
main ancestor in `source_sha`, set `allow_rollback=true`, and provide a concrete
`rollback_reason`. The same successful Native run, required-job, and SHA-keyed
release-note checks still apply; unrelated commits and unreasoned rollbacks are
rejected.

For a last known-good commit whose Native run predates SHA-keyed note artifacts,
also provide non-empty `rollback_notes`. The trusted verifier still requires the
four successful protected Native jobs, then materializes and uploads a fresh
`testflight-release-notes-<source_sha>` artifact before Apple credentials are
prepared. `rollback_notes` is rejected for ordinary current-main releases and
cannot bypass a missing, failed, or superseded Native run.

```bash
gh workflow run testflight.yml \
  --ref main \
  -f source_sha="$LAST_KNOWN_GOOD_MAIN_SHA" \
  -f allow_rollback=true \
  -f rollback_reason="Restore the last known-good sign-in release" \
  -f rollback_notes="Restores the last known-good sign-in build."
```

Required GitHub Actions secrets for the `internal-testflight` environment:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_PROVIDER_PUBLIC_ID`

The private key secret is the base64-encoded `.p8` contents. The workflow writes
the decoded key to `$RUNNER_TEMP`, creates an Apple Distribution Kit config file,
and never commits or prints credentials.

The CI publish driver is `scripts/ci-publish-testflight.sh`. It consumes the
verified source SHA and release-note artifact, materializes an ephemeral
distribution manifest with those exact notes, and records the provenance in the
publish summary. It fails the job if any of these validations fail:

- the checkout, selected SHA, or release-note SHA does not match;
- the App Store Connect app for `app.spoonjoy` cannot be resolved;
- the uploaded build does not become `VALID`;
- the `Spoonjoy Internal` beta group cannot be resolved;
- `testflight publish --mode dry-run` reports blockers;
- `testflight publish --mode apply` fails;
- `/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds` does not contain the build;
- `/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters` reports zero testers;
- `/v1/buildBetaDetails/$ASC_BUILD_BETA_DETAIL_ID` is not `IN_BETA_TESTING`.

## Reactive TestFlight Feedback

Spoonjoy uses an App Store Connect webhook for TestFlight screenshot and crash
feedback so an agent turn only runs when Apple reports new tester feedback. The
local listener is `scripts/testflight-feedback-autopilot.mjs`; it verifies
Apple's HMAC signature, fetches the exact App Store Connect feedback record,
downloads submitted screenshots, de-dupes feedback IDs that were already
handled, and submits a generic Ouro external event to `slugger`.

Slugger owns the TestFlight-helper role. The listener passes evidence paths to
Ouro with `ouro event submit --agent slugger --source app-store-connect ...`;
Ouro records a daemon receipt, queues a structured event message, and fires an
idempotent private-runtime wake. Slugger can then route work to Codex or another
worker and notify the operator through its configured channel. If the generic
Ouro event command is unavailable during a local rollout, the listener falls
back to `ouro msg --to slugger`; direct detached `codex exec` is the final
break-glass fallback.

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

Feedback runs are not complete just because an agent exits cleanly or a build is
published. The listener records clean Codex exits as `fixed_unconfirmed`; leave
the item in that state until the affected tester confirms the newer TestFlight
build fixes the reported behavior, then mark it `confirmed`. The internal
feedback-fix lane intentionally notifies `Spoonjoy Internal` testers so the
reporter receives the fixed build promptly.

Validate the path after registration:

```bash
scripts/testflight-feedback-autopilot.mjs install-launchd

curl -fsS http://127.0.0.1:48973/health | jq .
curl -fsS https://spoonjoy-testflight-feedback.ouro.bot/health | jq .

scripts/testflight-feedback-autopilot.mjs smoke
scripts/testflight-feedback-autopilot.mjs ping
scripts/testflight-feedback-autopilot.mjs deliveries
scripts/testflight-feedback-autopilot.mjs doctor | jq \
  '{ok, health, handledInstanceIds, launchedEventIds, registeredWebhooks}'
scripts/testflight-feedback-autopilot.mjs status
scripts/testflight-feedback-autopilot.mjs status --plain

ouro event submit --agent slugger --source app-store-connect \
  --type betaFeedbackScreenshotSubmissionCreated \
  --id smoke-feedback-id \
  --summary "Spoonjoy TestFlight smoke" \
  --evidence /tmp/spoonjoy-testflight-smoke \
  --no-wake

scripts/apple-distribution-kit.sh asc get \
  --path /v1/apps/6787505444/webhooks \
  --json
```

`install-launchd` rewrites the listener, tunnel, and reconcile user agents to
the current checkout before bootstrapping them. `status` and `doctor` fail if a
plist points at a stale checkout, if the configured working directory is wrong,
or if the live listener is still running an older health contract.

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
