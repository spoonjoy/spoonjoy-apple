#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/distribution/apple-distribution.json"
EXPORT_OPTIONS="$ROOT_DIR/distribution/ExportOptions.testflight.plist"
WRAPPER="$ROOT_DIR/scripts/apple-distribution-kit.sh"
PACKAGE_SCRIPT="$ROOT_DIR/scripts/package-testflight-ios.sh"
XCODE_PROJECT="$ROOT_DIR/Spoonjoy.xcodeproj"

fail() {
  printf 'apple distribution kit check failed: %s\n' "$1" >&2
  exit 1
}

[[ -x "$WRAPPER" ]] || fail "missing executable wrapper: scripts/apple-distribution-kit.sh"
[[ -x "$PACKAGE_SCRIPT" ]] || fail "missing executable package script: scripts/package-testflight-ios.sh"
[[ -f "$MANIFEST" ]] || fail "missing manifest: distribution/apple-distribution.json"
[[ -f "$EXPORT_OPTIONS" ]] || fail "missing TestFlight export options: distribution/ExportOptions.testflight.plist"
[[ -d "$XCODE_PROJECT" ]] || fail "missing Xcode project: Spoonjoy.xcodeproj"

secret_file="$(
  find "$ROOT_DIR" \
    -path "$ROOT_DIR/.git" -prune -o \
    -path "$ROOT_DIR/.build" -prune -o \
    -path "$ROOT_DIR/.swiftpm" -prune -o \
    -path "$ROOT_DIR/build" -prune -o \
    -path "$ROOT_DIR/artifacts" -prune -o \
    -path "$ROOT_DIR/DerivedData" -prune -o \
    -path "$ROOT_DIR/vendor/bundle" -prune -o \
    -type f \( \
      -name '*.p8' -o \
      -name '*.p12' -o \
      -name '*.mobileprovision' -o \
      -name '*.provisionprofile' -o \
      -name '*.cer' -o \
      -name 'AuthKey_*.p8' \
    \) -print -quit
)"
[[ -z "$secret_file" ]] || fail "secret-looking Apple credential file committed: ${secret_file#$ROOT_DIR/}"

ruby "$ROOT_DIR/scripts/check-xcode-project-contract.rb" >/dev/null

settings="$(
  xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "Spoonjoy iOS" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -showBuildSettings
)"
xcode_bundle_id="$(awk -F ' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }' <<<"$settings")"
xcode_marketing_version="$(awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }' <<<"$settings")"
xcode_build_number="$(awk -F ' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }' <<<"$settings")"

[[ "$xcode_bundle_id" == "app.spoonjoy" ]] || fail "Xcode PRODUCT_BUNDLE_IDENTIFIER must resolve to app.spoonjoy"
[[ -n "$xcode_marketing_version" ]] || fail "missing MARKETING_VERSION"
[[ -n "$xcode_build_number" ]] || fail "missing CURRENT_PROJECT_VERSION"

grep -q 'Spoonjoy iOS' "$PACKAGE_SCRIPT" || fail "package script must archive the Spoonjoy iOS scheme"
grep -q 'ExportOptions.testflight.plist' "$PACKAGE_SCRIPT" || fail "package script must use distribution/ExportOptions.testflight.plist"
grep -q 'build/apple/testflight' "$PACKAGE_SCRIPT" || fail "package script must export under build/apple/testflight"

node - "$MANIFEST" "$xcode_bundle_id" "$xcode_marketing_version" <<'NODE'
const fs = require("node:fs");

const [manifestPath, expectedBundleId, expectedVersion] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

function fail(message) {
  console.error(`manifest contract failed: ${message}`);
  process.exit(1);
}

if (manifest.app?.name !== "Spoonjoy") fail("app.name must be Spoonjoy");
if (manifest.app?.bundleId !== expectedBundleId) fail(`app.bundleId must be ${expectedBundleId}`);
if (manifest.app?.sku !== "app-spoonjoy-ios") fail("app.sku must be app-spoonjoy-ios");
if (manifest.team?.teamId !== "743GT2AJ24") fail("team.teamId must be 743GT2AJ24");
if (manifest.team?.providerPublicId !== "9735080289") fail("team.providerPublicId must be 9735080289");

const channels = new Map((manifest.channels ?? []).map((channel) => [channel.id, channel]));
const testflight = channels.get("ios-testflight");
if (!testflight) fail("missing ios-testflight channel");
if (testflight.platform !== "ios") fail("ios-testflight platform must be ios");
if (testflight.distribution !== "testflight") fail("ios-testflight distribution must be testflight");
if (testflight.bundleId !== expectedBundleId) fail(`ios-testflight bundleId must be ${expectedBundleId}`);
if (testflight.store?.version !== expectedVersion) fail(`testflight store.version must be ${expectedVersion}`);
if (testflight.packageCommand !== "scripts/package-testflight-ios.sh") {
  fail("ios-testflight packageCommand must run scripts/package-testflight-ios.sh");
}
if (!Array.isArray(testflight.testflight?.groups) || testflight.testflight.groups.length < 1) {
  fail("ios-testflight must declare at least one TestFlight group");
}
if (!testflight.testflight?.groups?.some((group) => group.name === "Spoonjoy Internal" && group.type === "internal")) {
  fail("ios-testflight must declare the Spoonjoy Internal group");
}
if (!testflight.testflight?.build?.whatsNew) fail("ios-testflight must declare testflight.build.whatsNew");
if (testflight.testflight?.build?.notifyTesters !== false) fail("internal TestFlight publish must not notify testers by default");
if (!testflight.testflight?.betaApp?.feedbackEmail) fail("ios-testflight must declare betaApp.feedbackEmail");

console.log("Spoonjoy native apple distribution manifest contract ok");
NODE

"$WRAPPER" manifest validate --manifest "$MANIFEST" >/dev/null
"$WRAPPER" plan --manifest "$MANIFEST" --mode dry-run --json >/dev/null
kit_help="$("$WRAPPER" --help)"
grep -q "testflight plan" <<<"$kit_help" || fail "apple-distribution-kit must support testflight plan; update/build the shared kit first"
grep -q "testflight publish" <<<"$kit_help" || fail "apple-distribution-kit must support testflight publish; update/build the shared kit first"
grep -q "asc get" <<<"$kit_help" || fail "apple-distribution-kit must support asc get; update/build the shared kit first"
"$WRAPPER" testflight plan --manifest "$MANIFEST" --channel ios-testflight --json >/dev/null

printf 'apple distribution kit check ok\n'
