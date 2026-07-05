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
