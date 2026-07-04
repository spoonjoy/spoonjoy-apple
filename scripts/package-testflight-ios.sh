#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="$ROOT_DIR/build/apple/Spoonjoy.xcarchive"
EXPORT_PATH="$ROOT_DIR/build/apple/testflight"
IPA_PATH="$EXPORT_PATH/Spoonjoy.ipa"

fail() {
  printf 'package-testflight-ios failed: %s\n' "$1" >&2
  exit 1
}

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild \
  -project "$ROOT_DIR/Spoonjoy.xcodeproj" \
  -scheme "Spoonjoy iOS" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=743GT2AJ24

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ROOT_DIR/distribution/ExportOptions.testflight.plist" \
  -allowProvisioningUpdates

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
