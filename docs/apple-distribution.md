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

```bash
scripts/check-apple-distribution-kit.sh

scripts/apple-distribution-kit.sh testflight plan \
  --manifest distribution/apple-distribution.json \
  --channel ios-testflight \
  --json

scripts/package-testflight-ios.sh

scripts/apple-distribution-kit.sh xcode run \
  --kind altool-upload \
  --mode apply \
  --package-path build/apple/testflight/Spoonjoy.ipa \
  --platform ios \
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

External TestFlight and public App Store submission are intentionally outside
this lane.
