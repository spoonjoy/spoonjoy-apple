#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="${SPOONJOY_TESTFLIGHT_MANIFEST:-$ROOT_DIR/distribution/apple-distribution.json}"
CHANNEL_ID="${SPOONJOY_TESTFLIGHT_CHANNEL:-ios-testflight}"
BUNDLE_ID="${SPOONJOY_TESTFLIGHT_BUNDLE_ID:-app.spoonjoy}"
GROUP_NAME="${SPOONJOY_TESTFLIGHT_GROUP_NAME:-Spoonjoy Internal}"
ASC_PROVIDER_PUBLIC_ID="${APP_STORE_CONNECT_PROVIDER_PUBLIC_ID:-9735080289}"
ASC_CONFIG="${APPLE_DISTRIBUTION_KIT_CONFIG:-$HOME/Library/Application Support/AppleDistributionKit/app-store-connect/config.json}"
ARTIFACT_DIR="${SPOONJOY_TESTFLIGHT_ARTIFACT_DIR:-$ROOT_DIR/artifacts/apple/ci-testflight}"
IPA_PATH="$ROOT_DIR/build/apple/testflight/Spoonjoy.ipa"

fail() {
  printf 'ci-publish-testflight failed: %s\n' "$1" >&2
  exit 1
}

kit() {
  "$ROOT_DIR/scripts/apple-distribution-kit.sh" "$@"
}

asc_get() {
  kit asc get "$@" --config "$ASC_CONFIG" --json
}

require_file() {
  [[ -f "$1" ]] || fail "missing $2"
}

json_string() {
  jq -r "$1 // empty" "$2"
}

mkdir -p "$ARTIFACT_DIR"

require_file "$ASC_CONFIG" "App Store Connect config"
ASC_API_KEY="$(json_string '.keyId' "$ASC_CONFIG")"
ASC_API_ISSUER="$(json_string '.issuerId' "$ASC_CONFIG")"
ASC_P8_FILE="$(json_string '.privateKeyPath' "$ASC_CONFIG")"
[[ -n "$ASC_API_KEY" ]] || fail "App Store Connect key ID is missing from config"
[[ -n "$ASC_API_ISSUER" ]] || fail "App Store Connect issuer ID is missing from config"
require_file "$ASC_P8_FILE" "App Store Connect private key"

printf 'Resolving App Store Connect app for %s\n' "$BUNDLE_ID"
asc_get \
  --path /v1/apps \
  --query "filter[bundleId]=$BUNDLE_ID" \
  --query limit=1 \
  > "$ARTIFACT_DIR/asc-app.json"
ASC_APP_ID="$(jq -r '.result.data[0].id // empty' "$ARTIFACT_DIR/asc-app.json")"
[[ -n "$ASC_APP_ID" ]] || fail "could not resolve App Store Connect app id for $BUNDLE_ID"

printf 'Resolving latest TestFlight build number for app %s\n' "$ASC_APP_ID"
asc_get \
  --path /v1/builds \
  --query "filter[app]=$ASC_APP_ID" \
  --query 'filter[preReleaseVersion.platform]=IOS' \
  --query 'sort=-uploadedDate' \
  --query 'limit=100' \
  > "$ARTIFACT_DIR/asc-builds-before.json"

if [[ -n "${SPOONJOY_TESTFLIGHT_BUILD_NUMBER:-}" ]]; then
  [[ "$SPOONJOY_TESTFLIGHT_BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "SPOONJOY_TESTFLIGHT_BUILD_NUMBER must be numeric"
  BUILD_NUMBER="$SPOONJOY_TESTFLIGHT_BUILD_NUMBER"
else
  BUILD_NUMBER="$(jq -r '[.result.data[]?.attributes.version | select(test("^[0-9]+$")) | tonumber] | max // 0 | . + 1' "$ARTIFACT_DIR/asc-builds-before.json")"
fi
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "resolved build number is not numeric"
export SPOONJOY_TESTFLIGHT_BUILD_NUMBER="$BUILD_NUMBER"

printf 'Publishing Spoonjoy TestFlight build %s from this source revision\n' "$BUILD_NUMBER"
"$ROOT_DIR/scripts/check-apple-distribution-kit.sh" | tee "$ARTIFACT_DIR/check-apple-distribution-kit.log"
"$ROOT_DIR/scripts/package-testflight-ios.sh" | tee "$ARTIFACT_DIR/package-testflight-ios.log"
require_file "$IPA_PATH" "exported IPA"

kit xcode run \
  --kind altool-upload \
  --mode apply \
  --package-path "$IPA_PATH" \
  --platform ios \
  --api-key "$ASC_API_KEY" \
  --api-issuer "$ASC_API_ISSUER" \
  --p8-file-path "$ASC_P8_FILE" \
  --provider-public-id "$ASC_PROVIDER_PUBLIC_ID" \
  --json \
  | tee "$ARTIFACT_DIR/altool-upload.json"

printf 'Waiting for App Store Connect to mark build %s VALID\n' "$BUILD_NUMBER"
BUILD_ID=""
for attempt in $(seq 1 120); do
  asc_get \
    --path /v1/builds \
    --query "filter[app]=$ASC_APP_ID" \
    --query 'filter[preReleaseVersion.platform]=IOS' \
    --query 'sort=-uploadedDate' \
    --query 'include=buildBetaDetail' \
    --query 'limit=100' \
    > "$ARTIFACT_DIR/asc-builds-poll.json"

  BUILD_ID="$(jq -r --arg version "$BUILD_NUMBER" '
    .result.data[]?
    | select(.attributes.version == $version and .attributes.processingState == "VALID")
    | .id
  ' "$ARTIFACT_DIR/asc-builds-poll.json" | head -n 1)"

  if [[ -n "$BUILD_ID" ]]; then
    break
  fi

  CURRENT_STATE="$(jq -r --arg version "$BUILD_NUMBER" '
    [.result.data[]? | select(.attributes.version == $version) | .attributes.processingState]
    | unique
    | join(",")
  ' "$ARTIFACT_DIR/asc-builds-poll.json")"
  printf 'Build %s not VALID yet; state=%s attempt=%s/120\n' "$BUILD_NUMBER" "${CURRENT_STATE:-not-visible}" "$attempt"
  sleep 30
done
[[ -n "$BUILD_ID" ]] || fail "build $BUILD_NUMBER did not become VALID before timeout"

asc_get \
  --path "/v1/builds/$BUILD_ID/buildBetaDetail" \
  > "$ARTIFACT_DIR/asc-build-beta-detail-relationship.json"
BUILD_BETA_DETAIL_ID="$(jq -r '.result.data.id // empty' "$ARTIFACT_DIR/asc-build-beta-detail-relationship.json")"
[[ -n "$BUILD_BETA_DETAIL_ID" ]] || fail "could not resolve build beta detail id for build $BUILD_ID"

asc_get \
  --path "/v1/apps/$ASC_APP_ID/betaGroups" \
  --query 'limit=200' \
  > "$ARTIFACT_DIR/asc-beta-groups.json"
ASC_INTERNAL_GROUP_ID="$(jq -r --arg name "$GROUP_NAME" '
  .result.data[]?
  | select(.attributes.name == $name)
  | .id
' "$ARTIFACT_DIR/asc-beta-groups.json" | head -n 1)"
[[ -n "$ASC_INTERNAL_GROUP_ID" ]] || fail "could not resolve beta group id for $GROUP_NAME"

printf 'Dry-running TestFlight publish for build %s\n' "$BUILD_NUMBER"
kit testflight publish \
  --mode dry-run \
  --manifest "$MANIFEST_PATH" \
  --channel "$CHANNEL_ID" \
  --app-id "$ASC_APP_ID" \
  --build-id "$BUILD_ID" \
  --build-beta-detail-id "$BUILD_BETA_DETAIL_ID" \
  --group-id "$GROUP_NAME=$ASC_INTERNAL_GROUP_ID" \
  --artifact "$ARTIFACT_DIR/testflight-publish-dry-run.json" \
  --config "$ASC_CONFIG" \
  --json \
  | tee "$ARTIFACT_DIR/testflight-publish-dry-run-output.json"

printf 'Applying TestFlight publish for build %s\n' "$BUILD_NUMBER"
kit testflight publish \
  --mode apply \
  --manifest "$MANIFEST_PATH" \
  --channel "$CHANNEL_ID" \
  --app-id "$ASC_APP_ID" \
  --build-id "$BUILD_ID" \
  --build-beta-detail-id "$BUILD_BETA_DETAIL_ID" \
  --group-id "$GROUP_NAME=$ASC_INTERNAL_GROUP_ID" \
  --artifact "$ARTIFACT_DIR/testflight-publish-apply.json" \
  --config "$ASC_CONFIG" \
  --json \
  | tee "$ARTIFACT_DIR/testflight-publish-apply-output.json"

GROUP_HAS_BUILD="false"
for attempt in $(seq 1 20); do
  asc_get \
    --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/builds" \
    --query 'limit=100' \
    > "$ARTIFACT_DIR/asc-group-builds-after-publish.json"
  GROUP_HAS_BUILD="$(jq -r --arg id "$BUILD_ID" '
    any(.result.data[]?; .id == $id)
  ' "$ARTIFACT_DIR/asc-group-builds-after-publish.json")"
  if [[ "$GROUP_HAS_BUILD" == "true" ]]; then
    break
  fi
  printf 'Build %s is not visible in group %s yet; attempt=%s/20\n' "$BUILD_ID" "$ASC_INTERNAL_GROUP_ID" "$attempt"
  sleep 15
done
[[ "$GROUP_HAS_BUILD" == "true" ]] || fail "build $BUILD_ID is not attached to beta group $ASC_INTERNAL_GROUP_ID"

asc_get \
  --path "/v1/betaGroups/$ASC_INTERNAL_GROUP_ID/betaTesters" \
  --query 'limit=200' \
  > "$ARTIFACT_DIR/asc-group-testers.json"
TESTER_COUNT="$(jq -r '.result.meta.paging.total // (.result.data | length) // 0' "$ARTIFACT_DIR/asc-group-testers.json")"
[[ "$TESTER_COUNT" =~ ^[0-9]+$ ]] || fail "tester count was not numeric"
(( TESTER_COUNT > 0 )) || fail "beta group $ASC_INTERNAL_GROUP_ID has no testers"

INTERNAL_BUILD_STATE=""
for attempt in $(seq 1 20); do
  asc_get \
    --path "/v1/buildBetaDetails/$BUILD_BETA_DETAIL_ID" \
    > "$ARTIFACT_DIR/asc-build-beta-detail-after-publish.json"
  INTERNAL_BUILD_STATE="$(jq -r '.result.data.attributes.internalBuildState // empty' "$ARTIFACT_DIR/asc-build-beta-detail-after-publish.json")"
  if [[ "$INTERNAL_BUILD_STATE" == "IN_BETA_TESTING" ]]; then
    break
  fi
  printf 'Build beta detail %s state is %s; attempt=%s/20\n' "$BUILD_BETA_DETAIL_ID" "${INTERNAL_BUILD_STATE:-empty}" "$attempt"
  sleep 15
done
[[ "$INTERNAL_BUILD_STATE" == "IN_BETA_TESTING" ]] || fail "expected internalBuildState IN_BETA_TESTING, got ${INTERNAL_BUILD_STATE:-empty}"

NOTIFY_TESTERS="$(jq -r '
  .channels[]
  | select(.id == "ios-testflight")
  | .testflight.build.notifyTesters // false
' "$MANIFEST_PATH")"

jq -n \
  --arg bundleId "$BUNDLE_ID" \
  --arg appId "$ASC_APP_ID" \
  --arg buildNumber "$BUILD_NUMBER" \
  --arg buildId "$BUILD_ID" \
  --arg buildBetaDetailId "$BUILD_BETA_DETAIL_ID" \
  --arg groupName "$GROUP_NAME" \
  --arg groupId "$ASC_INTERNAL_GROUP_ID" \
  --arg internalBuildState "$INTERNAL_BUILD_STATE" \
  --argjson testerCount "$TESTER_COUNT" \
  --argjson testersNotified "$NOTIFY_TESTERS" \
  '{
    bundleId: $bundleId,
    appId: $appId,
    buildNumber: $buildNumber,
    buildId: $buildId,
    buildBetaDetailId: $buildBetaDetailId,
    groupName: $groupName,
    groupId: $groupId,
    internalBuildState: $internalBuildState,
    testerCount: $testerCount,
    testersNotifiedRequested: $testersNotified
  }' \
  | tee "$ARTIFACT_DIR/testflight-publish-summary.json"

printf 'Spoonjoy TestFlight build %s is attached to %s and in beta testing.\n' "$BUILD_NUMBER" "$GROUP_NAME"
