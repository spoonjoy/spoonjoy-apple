#!/usr/bin/env bash
set -euo pipefail

# Uploads the Mac App Store build of the exact release commit and waits until App Store Connect marks it VALID.
# The Mac app is the macOS platform of the universal-purchase app.spoonjoy record, so builds are numbered per platform.

CONTROL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${SPOONJOY_MAC_SOURCE_ROOT:-$CONTROL_ROOT}"
BUNDLE_ID="${SPOONJOY_MAC_BUNDLE_ID:-app.spoonjoy}"
ASC_PROVIDER_PUBLIC_ID="${APP_STORE_CONNECT_PROVIDER_PUBLIC_ID:-}"
ASC_CONFIG="${APPLE_DISTRIBUTION_KIT_CONFIG:-$HOME/Library/Application Support/AppleDistributionKit/app-store-connect/config.json}"
ARTIFACT_DIR="${SPOONJOY_MAC_ARTIFACT_DIR:-$ROOT_DIR/artifacts/apple/ci-mac-app-store}"
PKG_PATH="$ROOT_DIR/build/apple/mac/app-store/Spoonjoy.pkg"
SOURCE_SHA="${SPOONJOY_MAC_SOURCE_SHA:-}"

fail() {
  printf 'ci-publish-mac-app-store failed: %s\n' "$1" >&2
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

[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "SPOONJOY_MAC_SOURCE_SHA must be an exact lowercase 40-character SHA"
CHECKED_OUT_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
[[ "$CHECKED_OUT_SHA" == "$SOURCE_SHA" ]] || fail "checked-out SHA does not match SPOONJOY_MAC_SOURCE_SHA"

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

printf 'Resolving latest Mac build number for app %s\n' "$ASC_APP_ID"
asc_get \
  --path /v1/builds \
  --query "filter[app]=$ASC_APP_ID" \
  --query 'filter[preReleaseVersion.platform]=MAC_OS' \
  --query 'sort=-uploadedDate' \
  --query 'limit=100' \
  > "$ARTIFACT_DIR/asc-builds-before.json"

if [[ -n "${SPOONJOY_MAC_BUILD_NUMBER:-}" ]]; then
  [[ "$SPOONJOY_MAC_BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "SPOONJOY_MAC_BUILD_NUMBER must be numeric"
  BUILD_NUMBER="$SPOONJOY_MAC_BUILD_NUMBER"
else
  BUILD_NUMBER="$(jq -r '[.result.data[]?.attributes.version | select(test("^[0-9]+$")) | tonumber] | max // 0 | . + 1' "$ARTIFACT_DIR/asc-builds-before.json")"
fi
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "resolved build number is not numeric"
export SPOONJOY_MAC_BUILD_NUMBER="$BUILD_NUMBER"

printf 'Packaging Spoonjoy Mac App Store build %s from this source revision\n' "$BUILD_NUMBER"
"$ROOT_DIR/scripts/check-apple-distribution-kit.sh" | tee "$ARTIFACT_DIR/check-apple-distribution-kit.log"
"$ROOT_DIR/scripts/package-mac-app-store.sh" | tee "$ARTIFACT_DIR/package-mac-app-store.log"
require_file "$PKG_PATH" "exported Mac installer package"

provider_args=()
[[ -z "$ASC_PROVIDER_PUBLIC_ID" ]] || provider_args=(--provider-public-id "$ASC_PROVIDER_PUBLIC_ID")
kit xcode run \
  --kind altool-upload \
  --mode apply \
  --package-path "$PKG_PATH" \
  --platform macos \
  --api-key "$ASC_API_KEY" \
  --api-issuer "$ASC_API_ISSUER" \
  --p8-file-path "$ASC_P8_FILE" \
  ${provider_args[@]+"${provider_args[@]}"} \
  --json \
  | tee "$ARTIFACT_DIR/altool-upload.json"

printf 'Waiting for App Store Connect to mark Mac build %s VALID\n' "$BUILD_NUMBER"
BUILD_ID=""
for attempt in $(seq 1 120); do
  asc_get \
    --path /v1/builds \
    --query "filter[app]=$ASC_APP_ID" \
    --query 'filter[preReleaseVersion.platform]=MAC_OS' \
    --query 'sort=-uploadedDate' \
    --query 'limit=100' \
    > "$ARTIFACT_DIR/asc-builds-poll.json"

  BUILD_ID="$(jq -r --arg version "$BUILD_NUMBER" '
    .result.data[]?
    | select(.attributes.version == $version and .attributes.processingState == "VALID")
    | .id
  ' "$ARTIFACT_DIR/asc-builds-poll.json" | head -n 1)"
  [[ -z "$BUILD_ID" ]] || break

  CURRENT_STATE="$(jq -r --arg version "$BUILD_NUMBER" '
    [.result.data[]? | select(.attributes.version == $version) | .attributes.processingState]
    | unique
    | join(",")
  ' "$ARTIFACT_DIR/asc-builds-poll.json")"
  case "$CURRENT_STATE" in
    *FAILED*|*INVALID*) fail "Mac build $BUILD_NUMBER processing ended in state $CURRENT_STATE" ;;
  esac
  printf 'Mac build %s not VALID yet; state=%s attempt=%s/120\n' "$BUILD_NUMBER" "${CURRENT_STATE:-not-visible}" "$attempt"
  sleep 30
done
[[ -n "$BUILD_ID" ]] || fail "Mac build $BUILD_NUMBER did not become VALID before timeout"

jq -n \
  --arg sourceSha "$SOURCE_SHA" \
  --arg appId "$ASC_APP_ID" \
  --arg buildNumber "$BUILD_NUMBER" \
  --arg buildId "$BUILD_ID" \
  '{schemaVersion: 1, platform: "MAC_OS", sourceSha: $sourceSha, appId: $appId, buildNumber: $buildNumber, buildId: $buildId, processingState: "VALID"}' \
  > "$ARTIFACT_DIR/mac-app-store-publish-summary.json"
printf 'Mac build %s (%s) is VALID in App Store Connect\n' "$BUILD_NUMBER" "$BUILD_ID"
