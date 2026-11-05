#!/usr/bin/env bash
# Runs the cook-mode motion checks (Apps/Spoonjoy/UITests/CookMotionUITests.swift) on a booted iPhone simulator.
# Each check plays a transition in slow motion over the screenshot fixture kitchen and reads every sampled frame.
#
#   scripts/check-motion.sh <simulator udid> <derived data path> [test name]
#
# Build first: xcodebuild build-for-testing -scheme "Spoonjoy iOS" -configuration BootstrapDebug
#   -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath <derived data path>
set -euo pipefail
udid="$1"; derived="$2"; only="${3:-}"
cd "$(dirname "$0")/.."
products="$derived/Build/Products"
xctestrun="$(ls "$products"/*.xctestrun | grep 'Spoonjoy iOS' | head -1)"
xcrun simctl terminate "$udid" app.spoonjoy 2>/dev/null || true
xcrun simctl install "$udid" "$products/BootstrapDebug-iphonesimulator/Spoonjoy.app"

# The fixture kitchen (account chef_kitchen_capture, cache only, no network), written by the screenshot capture's own
# seeding functions.
capture_account_id="chef_kitchen_capture"
shopping_capture_variant=""; capture_surface_variant=""; settings_capture_variant=""; settings_variant=""
settings_apns_registration_state=""
eval "$(awk '/^(write_app_state|write_cache_state|write_sync_store)\(\) \{/{p=1} p{print} p&&/^\}/{p=0}' scripts/capture-native-screenshots.sh)"
state="$(xcrun simctl get_app_container "$udid" app.spoonjoy data)/Library/Application Support/Spoonjoy"
mkdir -p "$state"
write_app_state "$state/native-app-state.json" kitchen
write_cache_state "$state/native-durable-cache.json" kitchen
write_sync_store "$state/native-sync-store.json" kitchen

target="SpoonjoyShoppingUITests/CookMotionUITests${only:+/$only}"
TEST_RUNNER_SPOONJOY_MOTION_CHECK=1 \
TEST_RUNNER_SPOONJOY_SCREENSHOT_AUTH=1 \
TEST_RUNNER_SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
TEST_RUNNER_SPOONJOY_SCREENSHOT_ACCOUNT_ID=chef_kitchen_capture \
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"$target" ${MOTION_RESULT_BUNDLE:+-resultBundlePath "$MOTION_RESULT_BUNDLE"}
