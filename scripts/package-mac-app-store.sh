#!/usr/bin/env bash
set -euo pipefail

# Archives the Mac app and exports the signed installer package that the Mac App Store takes.
# CI signs manually: SPOONJOY_MAC_SIGNING_XCCONFIG and SPOONJOY_MAC_EXPORT_OPTIONS_PLIST come from
# apple-distribution-kit "signing profiles --profile-type MAC_APP_STORE", and the export options name the
# Mac Installer Distribution identity that the workflow imported. Local runs fall back to automatic signing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="$ROOT_DIR/build/apple/mac/Spoonjoy.xcarchive"
EXPORT_PATH="$ROOT_DIR/build/apple/mac/app-store"
PKG_PATH="$EXPORT_PATH/Spoonjoy.pkg"
BUILD_NUMBER="${SPOONJOY_MAC_BUILD_NUMBER:-}"
SIGNING_XCCONFIG="${SPOONJOY_MAC_SIGNING_XCCONFIG:-}"
EXPORT_OPTIONS_PLIST="${SPOONJOY_MAC_EXPORT_OPTIONS_PLIST:-$ROOT_DIR/distribution/ExportOptions.mac-app-store.plist}"

fail() {
  printf 'package-mac-app-store failed: %s\n' "$1" >&2
  exit 1
}

signing_args=()
if [[ -n "$SIGNING_XCCONFIG" ]]; then
  [[ -f "$SIGNING_XCCONFIG" ]] || fail "SPOONJOY_MAC_SIGNING_XCCONFIG does not exist: $SIGNING_XCCONFIG"
  [[ -f "$EXPORT_OPTIONS_PLIST" ]] || fail "SPOONJOY_MAC_EXPORT_OPTIONS_PLIST does not exist: $EXPORT_OPTIONS_PLIST"
  signing_args=(-xcconfig "$SIGNING_XCCONFIG")
else
  [[ "${CI:-}" != "true" ]] || fail "CI must sign manually: set SPOONJOY_MAC_SIGNING_XCCONFIG and SPOONJOY_MAC_EXPORT_OPTIONS_PLIST"
  signing_args=(-allowProvisioningUpdates)
fi

build_settings=()
if [[ -n "$BUILD_NUMBER" ]]; then
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "SPOONJOY_MAC_BUILD_NUMBER must be numeric"
  build_settings=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild \
  "${signing_args[@]}" \
  -project "$ROOT_DIR/Spoonjoy.xcodeproj" \
  -scheme "Spoonjoy macOS" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  DEVELOPMENT_TEAM=743GT2AJ24 \
  ${build_settings[@]+"${build_settings[@]}"}

# The App Store rejects a Mac app without App Sandbox, so check the signed archive before exporting it.
app_path="$ARCHIVE_PATH/Products/Applications/Spoonjoy.app"
[[ -d "$app_path" ]] || fail "archive has no Spoonjoy.app"
entitlements="$(codesign -d --entitlements - --xml "$app_path" 2>/dev/null || true)"
grep -q 'com.apple.security.app-sandbox' <<<"$entitlements" || fail "the archived app is not sandboxed"
# The app registers for remote notifications, which needs production push under an App Store profile.
# PlistBuddy reads /dev/stdin as empty, so give it the entitlements as a file.
entitlements_plist="$(mktemp -t spoonjoy-entitlements)"
printf '%s' "$entitlements" >"$entitlements_plist"
aps="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.aps-environment' "$entitlements_plist" 2>/dev/null || true)"
rm -f "$entitlements_plist"
[[ "$aps" == "production" ]] || fail "the archived app has com.apple.developer.aps-environment '$aps', expected production"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$bundle_id" == "app.spoonjoy" ]] || fail "the archived app has bundle ID $bundle_id, expected app.spoonjoy"

export_args=()
[[ -n "$SIGNING_XCCONFIG" ]] || export_args=(-allowProvisioningUpdates)
xcodebuild \
  ${export_args[@]+"${export_args[@]}"} \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [[ ! -f "$PKG_PATH" ]]; then
  shopt -s nullglob
  pkgs=("$EXPORT_PATH"/*.pkg)
  [[ "${#pkgs[@]}" -eq 1 ]] || fail "expected one exported .pkg in $EXPORT_PATH"
  mv -f "${pkgs[0]}" "$PKG_PATH"
fi
pkgutil --check-signature "$PKG_PATH" >/dev/null || fail "the exported package is not signed"
printf 'Exported %s\n' "$PKG_PATH"
