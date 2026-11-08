#!/usr/bin/env bash
# Runs the Ouro Feel checks (Apps/Spoonjoy/UITests/FeelUITests.swift) over the screenshot fixture kitchen on a booted
# simulator: the way back from every screen (from Chefs, and from every tab, Chefs and Account), every screen landing
# still (no jump once at rest, nothing drawn twice, and a push or a sheet travelling in), and on an iPad the sidebar
# closing once you pick a section.
# Reports land in FEEL_REPORT_DIR (default .build/feel-reports) as text and JSON.
#
#   scripts/check-feel.sh <simulator udid> <derived data path> [test name]
#
# For a cold start on a fresh simulator each run, use ouro-ui-apple's scripts/ouro-feel-cold.sh instead.
#
# Build first: xcodebuild build-for-testing -scheme "Spoonjoy iOS" -configuration BootstrapDebug
#   -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath <derived data path>
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "usage: scripts/check-feel.sh <simulator udid> <derived data path> [test name]" >&2
  exit 2
fi
udid="$1"; derived="$2"; only="${3:-}"
cd "$(dirname "$0")/.."
products="$derived/Build/Products"
xctestrun="$(ls -t "$products"/*.xctestrun 2>/dev/null | grep 'Spoonjoy iOS' | head -1 || true)"
if [[ -z "$xctestrun" ]]; then
  echo "error: no Spoonjoy iOS .xctestrun in $products; run build-for-testing first" >&2
  exit 1
fi
reports="${FEEL_REPORT_DIR:-$PWD/.build/feel-reports}"
mkdir -p "$reports"
xcrun simctl terminate "$udid" app.spoonjoy 2>/dev/null || true
xcrun simctl install "$udid" "$products/BootstrapDebug-iphonesimulator/Spoonjoy.app"

# The fixture kitchen (account chef_kitchen_capture, cache only, no network), written by the screenshot capture's own
# seeding functions, as scripts/check-motion.sh does.
capture_account_id="chef_kitchen_capture"
shopping_capture_variant=""; capture_surface_variant=""; settings_capture_variant=""; settings_variant=""
settings_apns_registration_state=""
eval "$(awk '/^(write_app_state|write_cache_state|write_sync_store)\(\) \{/{p=1} p{print} p&&/^\}/{p=0}' scripts/capture-native-screenshots.sh)"
state="$(xcrun simctl get_app_container "$udid" app.spoonjoy data)/Library/Application Support/Spoonjoy"
mkdir -p "$state"
write_app_state "$state/native-app-state.json" kitchen
write_cache_state "$state/native-durable-cache.json" kitchen
# The kitchen chef owns the fixture recipes here, so the Recipes tab has rows to open without the network.
SPOONJOY_FIXTURE_CHEF_OWNS_RECIPES=1 write_sync_store "$state/native-sync-store.json" kitchen

target="SpoonjoyShoppingUITests/FeelUITests${only:+/$only}"
TEST_RUNNER_SPOONJOY_FEEL_CHECK=1 \
TEST_RUNNER_OURO_FEEL_REPORT_DIR="$reports" \
TEST_RUNNER_SPOONJOY_SCREENSHOT_AUTH=1 \
TEST_RUNNER_SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
TEST_RUNNER_SPOONJOY_SCREENSHOT_ACCOUNT_ID=chef_kitchen_capture \
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"$target" ${FEEL_RESULT_BUNDLE:+-resultBundlePath "$FEEL_RESULT_BUNDLE"}
