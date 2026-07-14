#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="$ROOT_DIR/build/apple/Spoonjoy.xcarchive"
EXPORT_PATH="$ROOT_DIR/build/apple/testflight"
IPA_PATH="$EXPORT_PATH/Spoonjoy.ipa"
IOS_DEPLOYMENT_TARGET="${SPOONJOY_TESTFLIGHT_IOS_DEPLOYMENT_TARGET:-26.0}"
SDK_STAT_CACHE_ENABLE_VALUE="${SPOONJOY_XCODE_SDK_STAT_CACHE_ENABLE:-NO}"
BUILD_NUMBER="${SPOONJOY_TESTFLIGHT_BUILD_NUMBER:-}"

fail() {
  printf 'package-testflight-ios failed: %s\n' "$1" >&2
  exit 1
}

redact_xcodebuild_output() {
  sed -E \
    -e 's#-authenticationKeyPath "[^"]+"#-authenticationKeyPath "<REDACTED_APP_STORE_CONNECT_KEY_PATH>"#g' \
    -e 's#-authenticationKeyID [^[:space:]]+#-authenticationKeyID <REDACTED_APP_STORE_CONNECT_KEY_ID>#g' \
    -e 's#-authenticationKeyIssuerID [^[:space:]]+#-authenticationKeyIssuerID <REDACTED_APP_STORE_CONNECT_ISSUER_ID>#g'
}

run_xcodebuild() {
  set +e
  xcodebuild "$@" 2>&1 | redact_xcodebuild_output
  local status="${PIPESTATUS[0]}"
  set -e
  return "$status"
}

auth_args=()
ASC_CONFIG="${APPLE_DISTRIBUTION_KIT_CONFIG:-$HOME/Library/Application Support/AppleDistributionKit/app-store-connect/config.json}"
if [[ -f "$ASC_CONFIG" ]]; then
  key_id="$(jq -r '.keyId // empty' "$ASC_CONFIG")"
  issuer_id="$(jq -r '.issuerId // empty' "$ASC_CONFIG")"
  key_path="$(jq -r '.privateKeyPath // empty' "$ASC_CONFIG")"
  if [[ -n "$key_id" && -n "$issuer_id" && -f "$key_path" ]]; then
    auth_args=(
      -authenticationKeyPath "$key_path"
      -authenticationKeyID "$key_id"
      -authenticationKeyIssuerID "$issuer_id"
    )
  fi
fi

build_settings=()
if [[ -n "$BUILD_NUMBER" ]]; then
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "SPOONJOY_TESTFLIGHT_BUILD_NUMBER must be numeric"
  build_settings=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

run_xcodebuild \
  "${auth_args[@]}" \
  -project "$ROOT_DIR/Spoonjoy.xcodeproj" \
  -scheme "Spoonjoy iOS" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=743GT2AJ24 \
  "${build_settings[@]}" \
  IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
  SDK_STAT_CACHE_ENABLE="$SDK_STAT_CACHE_ENABLE_VALUE"

run_xcodebuild \
  "${auth_args[@]}" \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ROOT_DIR/distribution/ExportOptions.testflight.plist" \
  -allowProvisioningUpdates \
  SDK_STAT_CACHE_ENABLE="$SDK_STAT_CACHE_ENABLE_VALUE"

if [[ -f "$IPA_PATH" ]]; then
  exit 0
fi

shopt -s nullglob
ipas=("$EXPORT_PATH"/*.ipa)
if [[ "${#ipas[@]}" -eq 1 ]]; then
  mv -f "${ipas[0]}" "$IPA_PATH"
  exit 0
fi

fail "expected one exported IPA in build/apple/testflight"
