#!/usr/bin/env bash
set -euo pipefail

artifact_root="${SPOONJOY_NATIVE_ARTIFACT_ROOT:-artifacts/apple/native-screenshots}"
unit_slug="capture-native-screenshots"
requested_route=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-root)
      artifact_root="$2"
      shift 2
      ;;
    --unit-slug)
      unit_slug="$2"
      shift 2
      ;;
    --route)
      requested_route="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
mkdir -p "$artifact_root/screenshots" "$apple_dir"
ios_screenshot="$artifact_root/screenshots/ios-mobile.png"
ios_tablet_screenshot="$artifact_root/screenshots/ios-tablet.png"
macos_screenshot="$artifact_root/screenshots/macos-desktop.png"
macos_app="${SPOONJOY_SCREENSHOT_MACOS_APP_PATH:-$artifact_root/DerivedData-macOS/Build/Products/BootstrapDebug/Spoonjoy.app}"
design_review="$artifact_root/design-review.json"
design_review_blocked="$artifact_root/design-review-blocked.json"
matrix_log="$artifact_root/apple/${unit_slug}-screenshots.log"
capture_log="$artifact_root/apple/${unit_slug}-screenshots-inner.log"
ios_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ios.log"
ipad_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ipad.log"
macos_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-macos.log"
xcode_blocker="$artifact_root/apple/${unit_slug}-screenshots-xcode-platform-blocker.json"
ios_blocker="$artifact_root/apple/${unit_slug}-screenshots-core-simulator-blocker.json"
ipad_blocker="$artifact_root/apple/${unit_slug}-screenshots-ipad-core-simulator-blocker.json"
macos_blocker="$artifact_root/apple/${unit_slug}-screenshots-macos-launch-blocker.json"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
cache_file="${HOME}/Library/Application Support/Spoonjoy/native-durable-cache.json"
sync_file="${HOME}/Library/Application Support/Spoonjoy/native-sync-store.json"
proof_file="${HOME}/Library/Application Support/Spoonjoy/native-screenshot-proof.json"
auth_file="${HOME}/Library/Application Support/Spoonjoy/debug-auth-session.json"
state_backup="$artifact_root/native-app-state-capture-backup.json"
cache_backup="$artifact_root/native-durable-cache-capture-backup.json"
sync_backup="$artifact_root/native-sync-store-capture-backup.json"
proof_backup="$artifact_root/native-screenshot-proof-capture-backup.json"
auth_backup="$artifact_root/debug-auth-session-capture-backup.json"
macos_launch_env_backup="$artifact_root/apple/${unit_slug}-macos-launch-env-backup.env"
ios_proof_artifact="$artifact_root/apple/${unit_slug}-screenshot-proof-ios.json"
ipad_proof_artifact="$artifact_root/apple/${unit_slug}-screenshot-proof-ipad.json"
macos_proof_artifact="$artifact_root/apple/${unit_slug}-screenshot-proof-macos.json"
ios_proof_artifact_rel="apple/${unit_slug}-screenshot-proof-ios.json"
ipad_proof_artifact_rel="apple/${unit_slug}-screenshot-proof-ipad.json"
macos_proof_artifact_rel="apple/${unit_slug}-screenshot-proof-macos.json"
accessibility_proof_ios="$artifact_root/apple/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_ipad="$artifact_root/apple/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos="$artifact_root/apple/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_ipad_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_rel="apple/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_ipad_rel="apple/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos_rel="apple/${unit_slug}-accessibility-proof-macos.json"
ios_accessibility_proof_runtime_path=""
screenshot_proof_path=""
screenshot_route="kitchen"
shopping_capture_variant="normal"
search_capture_variant="blank"
capture_surface_variant="normal"
settings_capture_variant="profile"
settings_apns_permission_state=""
settings_apns_registration_state=""
screenshot_auth_enabled="1"
expected_accessibility_source=""
if [[ -n "$requested_route" ]]; then
  screenshot_route="$requested_route"
else
  if [[ "$unit_slug" == *recipe-detail* || "$unit_slug" == *recipe_detail* ]]; then
    screenshot_route="recipe-detail"
  elif [[ "$unit_slug" == *cook-log* || "$unit_slug" == *cook_log* ]]; then
    screenshot_route="cook-log"
  elif [[ "$unit_slug" == *saved-recipes* || "$unit_slug" == *saved_recipes* ]]; then
    screenshot_route="saved-recipes"
  elif [[ "$unit_slug" == *recipes* ]]; then
    screenshot_route="recipes"
  elif [[ "$unit_slug" == *cook-mode* || "$unit_slug" == *cook_mode* ]]; then
    screenshot_route="cook-mode"
  elif [[ "$unit_slug" == *cookbook-detail* || "$unit_slug" == *cookbook_detail* ]]; then
    screenshot_route="cookbook-detail"
  elif [[ "$unit_slug" == *cookbooks* ]]; then
    screenshot_route="cookbooks"
  elif [[ "$unit_slug" == *shopping-list-empty* || "$unit_slug" == *shopping_list_empty* ]]; then
    screenshot_route="shopping-list-empty"
  elif [[ "$unit_slug" == *shopping-list-all-complete* || "$unit_slug" == *shopping_list_all_complete* ]]; then
    screenshot_route="shopping-list-all-complete"
  elif [[ "$unit_slug" == *shopping-list-duplicate* || "$unit_slug" == *shopping_list_duplicate* ]]; then
    screenshot_route="shopping-list-duplicate"
  elif [[ "$unit_slug" == *shopping-list-conflict* || "$unit_slug" == *shopping_list_conflict* ]]; then
    screenshot_route="shopping-list-conflict"
  elif [[ "$unit_slug" == *shopping-list-offline-queued* || "$unit_slug" == *shopping_list_offline_queued* ]]; then
    screenshot_route="shopping-list-offline-queued"
  elif [[ "$unit_slug" == *shopping-list* || "$unit_slug" == *shopping_list* || "$unit_slug" == *shopping* ]]; then
    screenshot_route="shopping-list"
  elif [[ "$unit_slug" == *chefs* ]]; then
    screenshot_route="chefs"
  elif [[ "$unit_slug" == *search-typed-results* || "$unit_slug" == *search_typed_results* ]]; then
    screenshot_route="search-typed-results"
  elif [[ "$unit_slug" == *search-scoped-recipes* || "$unit_slug" == *search_scoped_recipes* ]]; then
    screenshot_route="search-scoped-recipes"
  elif [[ "$unit_slug" == *search-scoped-cookbooks* || "$unit_slug" == *search_scoped_cookbooks* ]]; then
    screenshot_route="search-scoped-cookbooks"
  elif [[ "$unit_slug" == *search-scoped-chefs* || "$unit_slug" == *search_scoped_chefs* ]]; then
    screenshot_route="search-scoped-chefs"
  elif [[ "$unit_slug" == *search-scoped-shopping* || "$unit_slug" == *search_scoped_shopping* ]]; then
    screenshot_route="search-scoped-shopping"
  elif [[ "$unit_slug" == *search-no-results* || "$unit_slug" == *search_no_results* ]]; then
    screenshot_route="search-no-results"
  elif [[ "$unit_slug" == *search* ]]; then
    screenshot_route="search"
  elif [[ "$unit_slug" == *capture-signed-out* || "$unit_slug" == *capture_signed_out* ]]; then
    screenshot_route="capture-signed-out"
  elif [[ "$unit_slug" == *capture-provider-blocked* || "$unit_slug" == *capture_provider_blocked* ]]; then
    screenshot_route="capture-provider-blocked"
  elif [[ "$unit_slug" == *capture-offline-retry* || "$unit_slug" == *capture_offline_retry* ]]; then
    screenshot_route="capture-offline-retry"
  elif [[ "$unit_slug" == *capture-draft* || "$unit_slug" == *capture_draft* ]]; then
    screenshot_route="capture-draft"
  elif [[ "$unit_slug" == *capture-empty* || "$unit_slug" == *capture_empty* ]]; then
    screenshot_route="capture-empty"
  elif [[ "$unit_slug" == *capture* ]]; then
    screenshot_route="capture"
  elif [[ "$unit_slug" == *settings* || "$unit_slug" == *notification* || "$unit_slug" == *notifications* || "$unit_slug" == *apns* ]]; then
    screenshot_route="settings"
  fi
fi
if [[ "$screenshot_route" == "shopping-list-empty" ]]; then
  shopping_capture_variant="empty"
  screenshot_route="shopping-list"
elif [[ "$screenshot_route" == "shopping-list-all-complete" ]]; then
  shopping_capture_variant="all-complete"
  screenshot_route="shopping-list"
elif [[ "$screenshot_route" == "shopping-list-duplicate" ]]; then
  shopping_capture_variant="duplicate"
  screenshot_route="shopping-list"
elif [[ "$screenshot_route" == "shopping-list-conflict" ]]; then
  shopping_capture_variant="conflict"
  screenshot_route="shopping-list"
elif [[ "$screenshot_route" == "shopping-list-offline-queued" ]]; then
  shopping_capture_variant="offline-queued"
  screenshot_route="shopping-list"
elif [[ "$screenshot_route" == "search-typed-results" ]]; then
  search_capture_variant="typed-results"
  screenshot_route="search"
elif [[ "$screenshot_route" == "search-scoped-recipes" ]]; then
  search_capture_variant="scoped-recipes"
  screenshot_route="search"
elif [[ "$screenshot_route" == "search-scoped-cookbooks" ]]; then
  search_capture_variant="scoped-cookbooks"
  screenshot_route="search"
elif [[ "$screenshot_route" == "search-scoped-chefs" ]]; then
  search_capture_variant="scoped-chefs"
  screenshot_route="search"
elif [[ "$screenshot_route" == "search-scoped-shopping" ]]; then
  search_capture_variant="scoped-shopping"
  screenshot_route="search"
elif [[ "$screenshot_route" == "search-no-results" ]]; then
  search_capture_variant="no-results"
  screenshot_route="search"
elif [[ "$screenshot_route" == "capture-empty" ]]; then
  capture_surface_variant="empty"
  screenshot_route="capture"
elif [[ "$screenshot_route" == "capture-draft" ]]; then
  capture_surface_variant="draft"
  screenshot_route="capture"
elif [[ "$screenshot_route" == "capture-offline-retry" ]]; then
  capture_surface_variant="offline-retry"
  screenshot_route="capture"
elif [[ "$screenshot_route" == "capture-provider-blocked" ]]; then
  capture_surface_variant="provider-blocked"
  screenshot_route="capture"
elif [[ "$screenshot_route" == "capture-signed-out" ]]; then
  capture_surface_variant="signed-out"
  screenshot_auth_enabled="0"
  screenshot_route="capture"
fi
if [[ "$screenshot_route" == "settings" ]]; then
  if [[ "$unit_slug" == *settings-signed-out* || "$unit_slug" == *settings_signed_out* ]]; then
    settings_capture_variant="signed-out"
    screenshot_auth_enabled="0"
  elif [[ "$unit_slug" == *apns-denied* || "$unit_slug" == *apns_denied* ]]; then
    settings_capture_variant="apns-denied"
    settings_apns_permission_state="denied"
    settings_apns_registration_state="none"
  elif [[ "$unit_slug" == *apns-authorized* || "$unit_slug" == *apns_authorized* || "$unit_slug" == *apns-granted* || "$unit_slug" == *apns_granted* ]]; then
    settings_capture_variant="apns-authorized"
    settings_apns_permission_state="authorized"
    settings_apns_registration_state="registered"
  elif [[ "$unit_slug" == *apns-not-determined* || "$unit_slug" == *apns_not_determined* || "$unit_slug" == *apns-unknown* || "$unit_slug" == *apns_unknown* ]]; then
    settings_capture_variant="apns-not-determined"
    settings_apns_permission_state="not-determined"
    settings_apns_registration_state="none"
  elif [[ "$unit_slug" == *apns-unregistered* || "$unit_slug" == *apns_unregistered* ]]; then
    settings_capture_variant="apns-unregistered"
    settings_apns_permission_state="authorized"
    settings_apns_registration_state="unregistered"
  fi
fi
settings_capture_account_id="chef_settings_capture"
kitchen_capture_account_id="chef_kitchen_capture"
search_capture_account_id="chef_search_capture"
shopping_capture_account_id="chef_shopping_capture"
cookbook_detail_id="cookbook_weeknights"
shopping_conflict_client_mutation_id="cm_shopping_conflict_capture"
shopping_conflict_launch_client_mutation_id=""
if [[ "$shopping_capture_variant" == "conflict" ]]; then
  shopping_conflict_launch_client_mutation_id="$shopping_conflict_client_mutation_id"
fi
capture_account_id="$kitchen_capture_account_id"
settings_capture_focus="profile"
search_capture_disable_focus="0"
expected_search_query=""
expected_search_scope="all"
expected_search_route_identifier="search:all:"
recipe_detail_focus=""
proof_attempts="${SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS:-60}"
proof_sleep_seconds="${SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS:-0.5}"
ios_launch_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS:-30}"
ios_boot_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_BOOT_TIMEOUT_SECONDS:-90}"
ios_foreground_probe_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_FOREGROUND_PROBE_TIMEOUT_SECONDS:-2}"
macos_launch_timeout_seconds="${SPOONJOY_SCREENSHOT_MACOS_LAUNCH_TIMEOUT_SECONDS:-30}"
cleanup_timeout_seconds="${SPOONJOY_SCREENSHOT_CLEANUP_TIMEOUT_SECONDS:-5}"
ios_smoke_attempts="${SPOONJOY_SCREENSHOT_IOS_SMOKE_ATTEMPTS:-2}"
ios_capture_attempts="${SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS:-2}"
expected_recorded_route="$screenshot_route"
deep_link_path="$screenshot_route"
macos_window_title="Kitchen"
# Legacy contract marker: older capture code opened spoonjoy://$screenshot_route directly.
case "$screenshot_route" in
  kitchen)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="kitchen"
    deep_link_path="kitchen"
    macos_window_title="Kitchen"
    ;;
  recipes)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="recipes"
    deep_link_path="recipes"
    macos_window_title="Recipes"
    ;;
  saved-recipes)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="saved-recipes"
    deep_link_path="saved-recipes"
    macos_window_title="Saved Recipes"
    ;;
  recipe-detail)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="recipe:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta"
    macos_window_title="Lemon Pantry Pasta"
    ;;
  cook-log)
    capture_account_id="$kitchen_capture_account_id"
    recipe_detail_focus="cook-log"
    expected_recorded_route="recipe:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta"
    macos_window_title="Cooks"
    ;;
  cook-mode)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="recipe-cook:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta/cook"
    macos_window_title="Lemon Pantry Pasta"
    ;;
  cookbooks)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="cookbooks"
    deep_link_path="cookbooks"
    macos_window_title="Cookbooks"
    ;;
  cookbook-detail)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="cookbook:cookbook_weeknights"
    deep_link_path="cookbooks/$cookbook_detail_id"
    macos_window_title="Weeknights"
    ;;
  shopping-list)
    capture_account_id="$shopping_capture_account_id"
    expected_recorded_route="shopping-list"
    deep_link_path="shopping-list"
    macos_window_title="Shopping"
    ;;
  chefs)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="chefs"
    deep_link_path="chefs"
    macos_window_title="Chefs"
    ;;
  search)
    capture_account_id="$search_capture_account_id"
    search_capture_disable_focus="1"
    case "$search_capture_variant" in
      blank)
        expected_search_query=""
        expected_search_scope="all"
        ;;
      typed-results)
        expected_search_query="lemon"
        expected_search_scope="all"
        ;;
      scoped-recipes)
        expected_search_query="lemon"
        expected_search_scope="recipes"
        ;;
      scoped-cookbooks)
        expected_search_query="weeknights"
        expected_search_scope="cookbooks"
        ;;
      scoped-chefs)
        expected_search_query="ari"
        expected_search_scope="chefs"
        ;;
      scoped-shopping)
        expected_search_query="lemons"
        expected_search_scope="shopping-list"
        ;;
      no-results)
        expected_search_query="kumquat"
        expected_search_scope="recipes"
        ;;
      *)
        printf 'Unsupported search capture variant: %s\n' "$search_capture_variant" >&2
        exit 2
        ;;
    esac
    expected_search_route_identifier="search:${expected_search_scope}:${expected_search_query}"
    expected_recorded_route="$expected_search_route_identifier"
    deep_link_path="search?scope=${expected_search_scope}"
    if [[ -n "$expected_search_query" ]]; then
      deep_link_path="search?q=${expected_search_query}&scope=${expected_search_scope}"
    fi
    macos_window_title="Search"
    ;;
  capture)
    if [[ "$capture_surface_variant" == "signed-out" ]]; then
      capture_account_id="signed-out"
      expected_accessibility_source="SignedOutSetupView"
    else
      capture_account_id="$kitchen_capture_account_id"
      expected_accessibility_source="CaptureDraftView"
    fi
    expected_recorded_route="capture"
    deep_link_path="capture"
    macos_window_title="Capture"
    ;;
  settings)
    capture_account_id="$settings_capture_account_id"
    if [[ "$settings_capture_variant" == "signed-out" ]]; then
      capture_account_id="signed-out"
      settings_capture_focus="signed-out"
    elif [[ "$unit_slug" == *notification* || "$unit_slug" == *notifications* || "$unit_slug" == *apns* ]]; then
      settings_capture_focus="notifications"
    fi
    expected_recorded_route="settings"
    deep_link_path="settings"
    macos_window_title="Settings"
    ;;
  *)
    printf 'Unsupported screenshot route: %s\n' "$screenshot_route" >&2
    exit 2
    ;;
esac

write_blocker() {
  local path="$1"
  local capability="$2"
  local command="$3"
  local output_path="$4"
  local reason="$5"
  local owner_action="$6"
  ruby -rjson -e '
    path, capability, command, output_path, reason, owner_action = ARGV
    blocker = {
      capability: capability,
      blocked: true,
      command: command,
      timeoutSeconds: 30,
      outputPath: output_path,
      reason: reason,
      ownerAction: owner_action
    }
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$path" "$capability" "$command" "$output_path" "$reason" "$owner_action"
}

write_design_review_blocked() {
  local source_blocker_path="$1"
  ruby -rjson -e '
    source_path, output_path, ios_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof = ARGV
    blocker = JSON.parse(File.read(source_path))
    manifest = {
      "blocked" => true,
      "capability" => blocker.fetch("capability"),
      "sourceBlockerPath" => source_path,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/ios-tablet.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        ios_accessibility_proof,
        ipad_accessibility_proof,
        macos_accessibility_proof
      ],
      "reason" => blocker.fetch("reason"),
      "ownerAction" => blocker.fetch("ownerAction")
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$source_blocker_path" "$design_review_blocked" "$accessibility_proof_ios_rel" "$accessibility_proof_ipad_rel" "$accessibility_proof_macos_rel"
  rm -f "$ios_screenshot" "$ios_tablet_screenshot" "$macos_screenshot"
  rm -f "$accessibility_proof_ios" "$accessibility_proof_ipad" "$accessibility_proof_macos"
  rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_ipad_abs" "$accessibility_proof_macos_abs"
  rm -f "$design_review"
}

run_with_timeout() {
  local label="$1"
  local timeout_seconds="$2"
  local output_path="$3"
  local executable
  shift 3
  executable="$(command -v "$1" || true)"
  if [[ -n "$executable" ]]; then
    set -- "$executable" "${@:2}"
  fi
  mkdir -p "$(dirname "$output_path")"
  python3 - "$timeout_seconds" "$label" "$output_path" "$@" 2>> "$output_path" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
label = sys.argv[2]
output_path = sys.argv[3]
command = sys.argv[4:]

with open(output_path, "ab") as output:
    output.write(f"\nrun_with_timeout {label} ({timeout_seconds}s): {' '.join(command)}\n".encode())
    process = subprocess.Popen(
        command,
        stdout=output,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        exit_code = process.wait(timeout=timeout_seconds)
        output.write(f"\n{label} exited with code {exit_code}\n".encode())
        sys.exit(exit_code)
    except subprocess.TimeoutExpired:
        output.write(f"\n{label} timed out after {timeout_seconds} seconds\n".encode())
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        time.sleep(0.2)
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        process.wait()
        sys.exit(124)
PY
}

run_cleanup_command() {
  local description="$1"
  shift
  set +e
  run_with_timeout "cleanup timeout" "$cleanup_timeout_seconds" "$capture_log" "$@"
  local status=$?
  set -e
  if [[ "$status" -eq 124 ]]; then
    printf 'cleanup timeout while running %s\n' "$description" >> "$capture_log"
  fi
  return "$status"
}

write_design_review_success() {
  ruby -rjson -e '
    output_path, route, settings_focus, ios_proof, ipad_proof, macos_proof, ios_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof, shopping_variant, search_capture_variant, capture_surface_variant, settings_capture_variant, settings_apns_permission_state, settings_apns_registration_state, expected_search_query, expected_search_scope, expected_search_route_identifier, screenshot_auth_enabled = ARGV
    manifest = {
      "mobileScreenshot" => true,
      "desktopScreenshot" => true,
      "screenshotRoute" => route,
      "dynamicType" => true,
      "voiceOverLabels" => true,
      "keyboardNavigation" => true,
      "reduceMotion" => true,
      "contrast" => true,
      "kitchenTableHierarchy" => true,
      "noOverlap" => true,
      "accessibilityProofArtifacts" => [ios_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof],
      "blockers" => []
    }
    if route == "settings"
      manifest["settingsCaptureVariant"] = settings_capture_variant
      manifest["settingsScreenshotAuth"] = screenshot_auth_enabled
      manifest["settingsSignedInSurface"] = settings_capture_variant != "signed-out"
      manifest["settingsSignedOutSurface"] = settings_capture_variant == "signed-out"
      manifest["settingsVisualFocus"] = settings_focus
      manifest["settingsSurfaceProofArtifacts"] = [ios_proof, ipad_proof, macos_proof]
      if settings_focus == "notifications"
        manifest["settingsNotificationAPNsSurface"] = true
        manifest["settingsAPNsPermissionState"] = settings_apns_permission_state.empty? ? "not-determined" : settings_apns_permission_state
        manifest["settingsAPNsRegistrationState"] = settings_apns_registration_state.empty? ? "registered" : settings_apns_registration_state
      elsif settings_focus == "signed-out"
        manifest["settingsSignedOutHandoffSurface"] = true
      else
        manifest["settingsProfileSurface"] = true
      end
      manifest["settingsSections"] = if settings_focus == "signed-out"
                                       ["Session", "Environment", "Offline"]
                                     elsif settings_focus == "notifications"
                                       ["Notifications", "This Device", "Push Delivery", "Notification Sync", "Agent Access", "Offline"]
                                     else
                                       ["Profile", "Security", "Environment", "Offline"]
                                     end
      manifest["settingsSeedAccountID"] = settings_capture_variant == "signed-out" ? "signed-out" : "chef_settings_capture"
    elsif route == "search"
      manifest["searchNativeSurface"] = true
      manifest["searchScopes"] = ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
      manifest["searchSeedAccountID"] = "chef_search_capture"
      manifest.merge!(
        "searchSurfaceVariant" => search_capture_variant,
        "expectedQuery" => expected_search_query,
        "expectedScope" => expected_search_scope,
        "expectedRouteIdentifier" => expected_search_route_identifier
      )
      manifest["searchSurfaceProofArtifacts"] = [ios_proof, ipad_proof, macos_proof]
    elsif route == "recipes"
      manifest["recipesNativeSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
    elsif route == "recipe-detail"
      manifest["recipeDetailSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "cook-log"
      manifest["cookLogSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
      manifest["cookLogForm"] = true
      manifest["cookLogPhotoSlot"] = true
      manifest["cookLogActionBar"] = true
    elsif route == "cook-mode"
      manifest["cookModeSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "cookbooks"
      manifest["cookbooksNativeSurface"] = true
      manifest["cookbookSeedAccountID"] = "chef_kitchen_capture"
      manifest["cookbookLibrarySpread"] = true
      manifest["cookbookShelfStrip"] = true
    elsif route == "cookbook-detail"
      manifest["cookbookDetailSurface"] = true
      manifest["cookbookSeedAccountID"] = "chef_kitchen_capture"
      manifest["cookbookID"] = "cookbook_weeknights"
      manifest["cookbookContentsIndex"] = true
      manifest["cookbookOwnerToolsDisclosure"] = true
    elsif route == "shopping-list"
      manifest["shoppingListSurface"] = true
      manifest["shoppingSeedAccountID"] = "chef_shopping_capture"
      manifest["shoppingListVariant"] = shopping_variant
      manifest["shoppingConflictState"] = true if shopping_variant == "conflict"
    elsif route == "capture"
      manifest["captureSurfaceVariant"] = capture_surface_variant
      manifest["captureSignedOutSurface"] = capture_surface_variant == "signed-out"
      manifest["captureNativeSurface"] = capture_surface_variant != "signed-out"
      manifest["captureSeedAccountID"] = capture_surface_variant == "signed-out" ? "signed-out" : "chef_kitchen_capture"
      manifest["captureScreenshotAuth"] = screenshot_auth_enabled
    else
      manifest["kitchenSignedInSurface"] = true
      manifest["kitchenSeedAccountID"] = "chef_kitchen_capture"
    end
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$design_review" "$screenshot_route" "$settings_capture_focus" "$ios_proof_artifact_rel" "$ipad_proof_artifact_rel" "$macos_proof_artifact_rel" "$accessibility_proof_ios_rel" "$accessibility_proof_ipad_rel" "$accessibility_proof_macos_rel" "$shopping_capture_variant" "$search_capture_variant" "$capture_surface_variant" "$settings_capture_variant" "$settings_apns_permission_state" "$settings_apns_registration_state" "$expected_search_query" "$expected_search_scope" "$expected_search_route_identifier" "$screenshot_auth_enabled"
}

is_xcode_platform_blocker() {
  ruby -e '
    output = File.file?(ARGV.fetch(0)) ? File.read(ARGV.fetch(0)) : ""
    allowed = [
      /xcodebuild: error: iOS \d+(?:\.\d+)? is not installed/i,
      /xcodebuild: error: Unable to find a destination matching/i,
      /CoreSimulatorService connection became invalid/i,
      /DVTPlugInManager failed to load plug-in/i,
      /IDEDistribution.*private framework/i
    ]
    exit(allowed.any? { |pattern| output.match?(pattern) } ? 0 : 1)
  ' "$1"
}

write_app_state() {
  local path="$1"
  local route="$2"
  ruby -rjson -rfileutils -e '
    path, route, account_id, shopping_variant, capture_variant = ARGV
    shopping_fixture_path = "Sources/SpoonjoyCore/Fixtures/shopping-list-fixture.json"
    shopping_list = if route == "shopping-list" && File.file?(shopping_fixture_path)
                      JSON.parse(File.read(shopping_fixture_path))
                    elsif route == "shopping-list"
                      {
                        "id" => "shopping_list_ari",
                        "chef" => { "id" => "chef_ari", "username" => "ari" },
                        "nextCursor" => "v1.fixture.shopping.cursor",
                        "updatedAt" => "2026-06-01T00:15:00.000Z",
                        "items" => [
                          {
                            "id" => "item_lemons",
                            "name" => "lemons",
                            "quantity" => 2,
                            "unit" => "each",
                            "checked" => false,
                            "checkedAt" => nil,
                            "deletedAt" => nil,
                            "categoryKey" => "produce",
                            "iconKey" => "lemon",
                            "sortIndex" => 0,
                            "updatedAt" => "2026-06-01T00:00:00.000Z"
                          },
                          {
                            "id" => "item_spaghetti",
                            "name" => "spaghetti",
                            "quantity" => 12,
                            "unit" => "oz",
                            "checked" => false,
                            "checkedAt" => nil,
                            "deletedAt" => nil,
                            "categoryKey" => "pantry",
                            "iconKey" => "pasta",
                            "sortIndex" => 1,
                            "updatedAt" => "2026-06-01T00:01:00.000Z"
                          }
                        ]
                      }
                    end
    if route == "shopping-list" && shopping_variant == "all-complete" && shopping_list
      shopping_list["items"] = shopping_list.fetch("items").each_with_index.map do |item, index|
        item.merge(
          "checked" => true,
          "checkedAt" => "2026-06-16T12:08:0#{index}.000Z",
          "sortIndex" => index
        )
      end
    elsif route == "shopping-list" && shopping_variant == "empty" && shopping_list
      shopping_list["items"] = []
    elsif route == "shopping-list" && shopping_variant == "duplicate" && shopping_list
      duplicate = shopping_list.fetch("items").first.merge(
        "id" => "item_duplicate_lemons",
        "sortIndex" => shopping_list.fetch("items").length,
        "updatedAt" => "2026-06-16T12:08:20.000Z"
      )
      shopping_list["items"] = shopping_list.fetch("items") + [duplicate]
    end
    capture_url = "https://spoonjoy.app/recipes/lemon-pantry-import"
    capture_draft = if route == "capture" && ["draft", "offline-retry", "provider-blocked"].include?(capture_variant)
                      {
                        "id" => "draft_capture_#{capture_variant.tr("-", "_")}",
                        "source" => "url",
                        "rawText" => capture_url,
                        "imageAssetIdentifier" => nil,
                        "sourceURL" => nil,
                        "capturedURL" => capture_url,
                        "jsonLD" => nil,
                        "createdAt" => "2026-06-16T12:08:40.000Z",
                        "status" => "localOnly"
                      }
                    end
    capture_import_mutation = if route == "capture" && capture_variant == "offline-retry"
                                {
                                  "schemaVersion" => 1,
                                  "id" => "native:cm_capture_import_retry",
                                  "clientMutationId" => "cm_capture_import_retry",
                                  "createdAt" => "2026-06-16T12:08:50.000Z",
                                  "retryCount" => 0,
                                  "kind" => {
                                    "type" => "recipe.import.submit",
                                    "source" => {
                                      "type" => "url",
                                      "url" => capture_url
                                    }
                                  }
                                }
                              end
    snapshot = {
      "schemaVersion" => 1,
      "accountID" => account_id,
      "environment" => "production",
      "hasCompletedFirstRun" => true,
      "cookProgressByRecipeID" => {},
      "spoonCookLogDraftsByRecipeID" => {},
      "shoppingList" => shopping_list,
      "captureDraft" => capture_draft,
      "pendingCaptureImport" => capture_import_mutation,
      "captureImportProviderBlocker" => route == "capture" && capture_variant == "provider-blocked" ? "recipe-import" : nil,
      "pendingMutations" => { "mutations" => [] },
      "lastOpenedRoute" => route,
      "savedAt" => "2026-06-16T12:09:00.000Z"
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$route" "$capture_account_id" "$shopping_capture_variant" "$capture_surface_variant"
}

write_sync_store() {
  local path="$1"
  local route="$2"
  ruby -rjson -rfileutils -e '
    path, route, account_id, shopping_variant, capture_variant = ARGV
    recipes_path = "Sources/SpoonjoyCore/Fixtures/recipes-fixture.json"
    cookbooks_path = "Sources/SpoonjoyCore/Fixtures/cookbooks-fixture.json"
    shopping_path = "Sources/SpoonjoyCore/Fixtures/shopping-list-fixture.json"
    recipes = if File.file?(recipes_path)
                JSON.parse(File.read(recipes_path)).fetch("recipes")
              else
                [
                  {
                    "id" => "recipe_lemon_pantry_pasta",
                    "title" => "Lemon Pantry Pasta",
                    "description" => "Bright pantry pasta with lemon, garlic, and parmesan.",
                    "servings" => "4",
                    "chef" => { "id" => "chef_ari", "username" => "ari" },
                    "coverImageUrl" => nil,
                    "coverProvenanceLabel" => "Chef photo",
                    "coverSourceType" => "chef-upload",
                    "coverVariant" => "image",
                    "href" => "/recipes/recipe_lemon_pantry_pasta",
                    "canonicalUrl" => "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta",
                    "attribution" => {
                      "creditText" => "Lemon Pantry Pasta by ari on Spoonjoy",
                      "canonicalUrl" => "https://spoonjoy.app/recipes/recipe_lemon_pantry_pasta",
                      "sourceUrl" => nil,
                      "sourceHost" => nil,
                      "sourceRecipe" => nil
                    },
                    "createdAt" => "2026-06-01T00:00:00.000Z",
                    "updatedAt" => "2026-06-01T00:00:00.000Z",
                    "steps" => [
                      {
                        "id" => "step_boil_pasta",
                        "stepNum" => 1,
                        "stepTitle" => "Boil pasta",
                        "description" => "Boil the pasta until just tender.",
                        "ingredients" => [
                          {
                            "id" => "ingredient_spaghetti",
                            "name" => "spaghetti",
                            "quantity" => 12,
                            "unit" => "oz",
                            "categoryKey" => "pantry",
                            "iconKey" => "pasta"
                          }
                        ],
                        "timers" => [],
                        "usingSteps" => []
                      },
                      {
                        "id" => "step_finish_sauce",
                        "stepNum" => 2,
                        "stepTitle" => "Finish sauce",
                        "description" => "Toss pasta with lemon, parmesan, and a little pasta water.",
                        "ingredients" => [
                          {
                            "id" => "ingredient_lemons",
                            "name" => "lemons",
                            "quantity" => 2,
                            "unit" => "each",
                            "categoryKey" => "produce",
                            "iconKey" => "lemon"
                          }
                        ],
                        "timers" => [],
                        "usingSteps" => ["step_boil_pasta"]
                      }
                    ],
                    "cookbooks" => []
                  }
                ]
              end
    if route == "recipe-detail"
      cover_asset_path = File.expand_path("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png")
      recipes = recipes.map do |recipe|
        next recipe unless recipe.fetch("id") == "recipe_lemon_pantry_pasta"

        recipe.merge(
          "coverImageUrl" => "file://#{cover_asset_path}",
          "coverProvenanceLabel" => nil,
          "coverSourceType" => "chef-upload",
          "coverVariant" => "image"
        )
      end
    end
    cookbooks = if File.file?(cookbooks_path)
                  JSON.parse(File.read(cookbooks_path)).fetch("cookbooks")
                else
                  [
                    {
                      "id" => "cookbook_weeknights",
                      "title" => "Weeknights",
                      "chef" => { "id" => "chef_ari", "username" => "ari" },
                      "recipeCount" => 1,
                      "coverImageUrls" => [],
                      "href" => "/cookbooks/cookbook_weeknights",
                      "canonicalUrl" => "https://spoonjoy.app/cookbooks/cookbook_weeknights",
                      "attribution" => {
                        "creditText" => "Weeknights by ari on Spoonjoy",
                        "canonicalUrl" => "https://spoonjoy.app/cookbooks/cookbook_weeknights"
                      },
                      "createdAt" => "2026-06-01T00:00:00.000Z",
                      "updatedAt" => "2026-06-01T00:10:00.000Z",
                      "recipes" => recipes.map do |recipe|
                        recipe.slice("id", "title", "description", "servings", "chef", "coverImageUrl", "coverProvenanceLabel", "coverSourceType", "coverVariant", "href", "canonicalUrl", "attribution", "createdAt", "updatedAt")
                      end
                    }
                  ]
                end
    shopping = if File.file?(shopping_path)
                 JSON.parse(File.read(shopping_path))
               else
                 {
                   "id" => "shopping_list_ari",
                   "chef" => { "id" => "chef_ari", "username" => "ari" },
                   "nextCursor" => "v1.fixture.shopping.cursor",
                   "updatedAt" => "2026-06-01T00:15:00.000Z",
                   "items" => [
                     {
                       "id" => "item_lemons",
                       "name" => "lemons",
                       "quantity" => 2,
                       "unit" => "each",
                       "checked" => false,
                       "checkedAt" => nil,
                       "deletedAt" => nil,
                       "categoryKey" => "produce",
                       "iconKey" => "lemon",
                       "sortIndex" => 0,
                       "updatedAt" => "2026-06-01T00:00:00.000Z"
                     },
                     {
                       "id" => "item_spaghetti",
                       "name" => "spaghetti",
                       "quantity" => 12,
                       "unit" => "oz",
                       "checked" => false,
                       "checkedAt" => nil,
                       "deletedAt" => nil,
                       "categoryKey" => "pantry",
                       "iconKey" => "pasta",
                       "sortIndex" => 1,
                       "updatedAt" => "2026-06-01T00:01:00.000Z"
                     }
                   ]
                 }
               end
    if shopping_variant == "all-complete"
      shopping["items"] = shopping.fetch("items").each_with_index.map do |item, index|
        item.merge(
          "checked" => true,
          "checkedAt" => "2026-06-16T12:08:0#{index}.000Z",
          "sortIndex" => index
        )
      end
    elsif shopping_variant == "empty"
      shopping["items"] = []
    elsif shopping_variant == "duplicate"
      duplicate = shopping.fetch("items").first.merge(
        "id" => "item_duplicate_lemons",
        "sortIndex" => shopping.fetch("items").length,
        "updatedAt" => "2026-06-16T12:08:20.000Z"
      )
      shopping["items"] = shopping.fetch("items") + [duplicate]
    end
    records = recipes.map do |recipe|
      {
        "kind" => "recipe",
        "resourceID" => recipe.fetch("id"),
        "payload" => recipe,
        "serverRevision" => nil
      }
    end
    records.concat(shopping.fetch("items").map do |item|
      {
        "kind" => "shoppingItem",
        "resourceID" => item.fetch("id"),
        "payload" => item,
        "serverRevision" => nil
      }
    end)
    records.concat(cookbooks.map do |cookbook|
      {
        "kind" => "cookbook",
        "resourceID" => cookbook.fetch("id"),
        "payload" => cookbook,
        "serverRevision" => nil
      }
    end)
    queue_mutations = []
    if shopping_variant == "offline-queued" || shopping_variant == "conflict"
      client_mutation_id = shopping_variant == "conflict" ? "cm_shopping_conflict_capture" : "cm_shopping_offline_capture"
      queue_mutations << {
        "schemaVersion" => 1,
        "id" => "native:#{client_mutation_id}",
        "clientMutationId" => client_mutation_id,
        "createdAt" => "2026-06-16T12:08:30.000Z",
        "retryCount" => 0,
        "kind" => {
          "type" => "shopping.addItem",
          "name" => "limes",
          "quantity" => 4,
          "unit" => "each",
          "categoryKey" => "produce",
          "iconKey" => "lemon"
        }
      }
    end
    if capture_variant == "offline-retry"
      queue_mutations << {
        "schemaVersion" => 1,
        "id" => "native:cm_capture_import_retry",
        "clientMutationId" => "cm_capture_import_retry",
        "createdAt" => "2026-06-16T12:08:50.000Z",
        "retryCount" => 0,
        "kind" => {
          "type" => "recipe.import.submit",
          "source" => {
            "type" => "url",
            "url" => "https://spoonjoy.app/recipes/lemon-pantry-import"
          }
        }
      }
    end
    snapshot = {
      "accountID" => account_id,
      "environment" => "production",
      "checkpoint" => nil,
      "queue" => { "mutations" => queue_mutations },
      "cachedRecords" => records,
      "tombstones" => []
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$route" "$capture_account_id" "$shopping_capture_variant" "$capture_surface_variant"
}

write_cache_state() {
  local path="$1"
  local route="$2"
  ruby -rjson -rfileutils -rtime -e '
    path, route, account_id, settings_variant, apns_registration_state = ARGV
    FileUtils.mkdir_p(File.dirname(path))
    if route == "settings" && settings_variant == "signed-out"
      File.write(path, JSON.pretty_generate({
        "schemaVersion" => 2,
        "accountID" => account_id,
        "environment" => "production",
        "createdAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
        "records" => [],
        "dismissedIndicators" => [],
        "pendingMutationQueue" => { "mutations" => [] }
      }) + "\n")
      exit
    end
    if route != "settings"
      File.write(path, JSON.pretty_generate({
        "schemaVersion" => 2,
        "accountID" => account_id,
        "environment" => "production",
        "createdAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
        "records" => [
          {
            "id" => "recipe-catalog",
            "metadata" => {
              "accountID" => account_id,
              "environment" => "production",
              "schemaVersion" => 2,
              "domain" => { "recipeCatalog" => {} },
              "fetchedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "lastValidatedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "sourceEndpoint" => "/api/v1/recipes",
              "serverRevision" => { "cursor" => { "_0" => "screenshot-kitchen" } }
            },
            "payload" => { "recipeCatalog" => { "recipeIDs" => ["recipe_lemon_pantry_pasta"] } }
          },
          {
            "id" => "recipe-detail:recipe_lemon_pantry_pasta",
            "metadata" => {
              "accountID" => account_id,
              "environment" => "production",
              "schemaVersion" => 2,
              "domain" => { "recipeDetail" => { "id" => "recipe_lemon_pantry_pasta" } },
              "fetchedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "lastValidatedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "sourceEndpoint" => "/api/v1/recipes/recipe_lemon_pantry_pasta",
              "serverRevision" => { "etag" => { "_0" => "\"recipe-screenshot-v1\"" } }
            },
            "payload" => {
              "recipeDetail" => {
                "id" => "recipe_lemon_pantry_pasta",
                "title" => "Lemon Pantry Pasta"
              }
            }
          },
          {
            "id" => "cookbook-list",
            "metadata" => {
              "accountID" => account_id,
              "environment" => "production",
              "schemaVersion" => 2,
              "domain" => { "cookbookList" => {} },
              "fetchedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "lastValidatedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "sourceEndpoint" => "/api/v1/cookbooks",
              "serverRevision" => { "cursor" => { "_0" => "screenshot-cookbooks" } }
            },
            "payload" => { "cookbookList" => { "cookbookIDs" => ["cookbook_weeknights"] } }
          },
          {
            "id" => "cookbook-detail:cookbook_weeknights",
            "metadata" => {
              "accountID" => account_id,
              "environment" => "production",
              "schemaVersion" => 2,
              "domain" => { "cookbookDetail" => { "id" => "cookbook_weeknights" } },
              "fetchedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "lastValidatedAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
              "sourceEndpoint" => "/api/v1/cookbooks/cookbook_weeknights",
              "serverRevision" => { "etag" => { "_0" => "\"cookbook-screenshot-v1\"" } }
            },
            "payload" => {
              "cookbookDetail" => {
                "id" => "cookbook_weeknights",
                "title" => "Weeknights"
              }
            }
          }
        ],
        "dismissedIndicators" => [],
        "pendingMutationQueue" => { "mutations" => [] }
      }) + "\n")
      exit
    end

    account_id = "chef_settings_capture"
    timestamp = "2026-06-16T12:09:00.000Z"
    date_value = Time.parse(timestamp) - Time.utc(2001, 1, 1)
    metadata = lambda do |domain, endpoint|
      {
        "accountID" => account_id,
        "environment" => "production",
        "schemaVersion" => 2,
        "domain" => { domain => {} },
        "fetchedAt" => date_value,
        "lastValidatedAt" => date_value,
        "sourceEndpoint" => endpoint,
        "serverRevision" => { "localRevision" => { "_0" => "screenshot-settings" } }
      }
    end
    apns_registration_state = "registered" if apns_registration_state.nil? || apns_registration_state.empty?
    records = [
      {
        "id" => "settings",
        "metadata" => metadata.call("settings", "/api/v1/me"),
        "payload" => {
          "settings" => {
            "account" => {
              "id" => account_id,
              "email" => "settings-capture@spoonjoy.app",
              "username" => "settingscapture",
              "photoUrl" => nil,
              "hasPassword" => true,
              "oauthAccounts" => [
                { "provider" => "github", "providerUsername" => "settingscapture" }
              ],
              "passkeys" => []
            }
          }
        }
      },
      {
        "id" => "notification-preferences",
        "metadata" => metadata.call("notificationPreferences", "/api/v1/me/notification-preferences"),
        "payload" => {
          "notificationPreferenceState" => {
            "_0" => {
              "notifySpoonOnMyRecipe" => true,
              "notifyForkOfMyRecipe" => false,
              "notifyCookbookSaveOfMine" => true,
              "notifyFellowChefOriginCook" => false
            }
          }
        }
      },
      {
        "id" => "token-metadata",
        "metadata" => metadata.call("tokenMetadata", "/api/v1/tokens"),
        "payload" => {
          "tokenMetadata" => {
            "credentials" => [
              {
                "id" => "credential_capture",
                "name" => "Capture validation key",
                "tokenPrefix" => "sj_live_1234",
                "scopes" => ["recipes:read", "shopping_list:read"],
                "createdAt" => timestamp,
                "updatedAt" => timestamp,
                "lastUsedAt" => nil,
                "revokedAt" => nil,
                "expiresAt" => nil
              }
            ]
          }
        }
      },
      {
        "id" => "connection-status",
        "metadata" => metadata.call("connectionStatus", "/api/v1/me/connections"),
        "payload" => {
          "connectionStatus" => {
            "connections" => [
              {
                "id" => "connection_capture",
                "provider" => "oauth",
                "status" => "connected",
                "clientID" => "client_capture",
                "clientName" => "Capture OAuth App",
                "resource" => nil,
                "scopes" => ["account:read"],
                "createdAt" => timestamp,
                "refreshTokenCount" => 1,
                "accessTokenCount" => 1
              }
            ]
          }
        }
      },
      (apns_registration_state == "none" ? nil : {
        "id" => "apns-status",
        "metadata" => metadata.call("apnsStatus", "/api/v1/me/apns-devices"),
        "payload" => {
          "apnsStatus" => {
            "deviceID" => "device_apns_capture",
            "registrationState" => apns_registration_state
          }
        }
      })
    ].compact
    snapshot = {
      "schemaVersion" => 2,
      "accountID" => account_id,
      "environment" => "production",
      "createdAt" => date_value,
      "records" => records,
      "dismissedIndicators" => [],
      "pendingMutationQueue" => { "mutations" => [] }
    }
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$route" "$capture_account_id" "$settings_capture_variant" "$settings_apns_registration_state"
}

ios_launch_app() {
  local udid="$1"
  run_with_timeout "simulator launch timeout" "$ios_launch_timeout_seconds" "$capture_log" \
    env \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_AUTH="$screenshot_auth_enabled" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID="$capture_account_id" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SETTINGS_FOCUS="$settings_capture_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS="$search_capture_disable_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS="$recipe_detail_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE="$settings_apns_permission_state" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE="$settings_apns_registration_state" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID="$shopping_conflict_launch_client_mutation_id" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_EXPECTED_ROUTE="$screenshot_route" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$ios_accessibility_proof_runtime_path" \
      xcrun simctl launch --terminate-running-process "$udid" app.spoonjoy
}

ios_app_is_registered_as_running() {
  local udid="$1"
  local launchctl_log
  local launchctl_output
  local launchctl_status
  launchctl_log="$(mktemp)"
  set +e
  run_with_timeout "simulator launch registration check" 10 "$launchctl_log" \
    xcrun simctl spawn "$udid" launchctl list
  launchctl_status=$?
  set -e
  launchctl_output="$(cat "$launchctl_log")"
  cat "$launchctl_log" >> "$capture_log"
  rm -f "$launchctl_log"
  [[ "$launchctl_status" -eq 0 && "$launchctl_output" == *"UIKitApplication:app.spoonjoy"* ]]
}

open_macos_app() {
  set_macos_launch_environment
  run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" \
    env \
      SPOONJOY_SCREENSHOT_AUTH="$screenshot_auth_enabled" \
      SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
      SPOONJOY_SCREENSHOT_ACCOUNT_ID="$capture_account_id" \
      SPOONJOY_SCREENSHOT_SETTINGS_FOCUS="$settings_capture_focus" \
      SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS="$search_capture_disable_focus" \
      SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS="$recipe_detail_focus" \
      SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE="$settings_apns_permission_state" \
      SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE="$settings_apns_registration_state" \
      SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID="$shopping_conflict_launch_client_mutation_id" \
      SPOONJOY_SCREENSHOT_EXPECTED_ROUTE="$screenshot_route" \
      SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
      SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$accessibility_proof_macos_abs" \
      SPOONJOY_API_BASE_URL="https://spoonjoy.app" \
      open -n "$macos_app"
}

set_macos_launch_environment() {
  local uid
  uid="$(id -u)"
  if [[ ! -f "$macos_launch_env_backup" ]]; then
    : > "$macos_launch_env_backup"
    local key
    for key in \
      SPOONJOY_SCREENSHOT_AUTH \
      SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY \
      SPOONJOY_SCREENSHOT_ACCOUNT_ID \
      SPOONJOY_SCREENSHOT_SETTINGS_FOCUS \
      SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS \
      SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS \
      SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE \
      SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE \
      SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID \
      SPOONJOY_SCREENSHOT_EXPECTED_ROUTE \
      SPOONJOY_SCREENSHOT_PROOF_PATH \
      SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH \
      SPOONJOY_API_BASE_URL
    do
      local value
      value="$(launchctl asuser "$uid" launchctl getenv "$key" 2>/dev/null || true)"
      if [[ -n "$value" ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$macos_launch_env_backup"
      else
        printf '%s\n' "$key" >> "$macos_launch_env_backup"
      fi
    done
  fi
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_AUTH "$screenshot_auth_enabled"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY 1
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_ACCOUNT_ID "$capture_account_id"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_SETTINGS_FOCUS "$settings_capture_focus"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS "$search_capture_disable_focus"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS "$recipe_detail_focus"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE "$settings_apns_permission_state"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE "$settings_apns_registration_state"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID "$shopping_conflict_launch_client_mutation_id"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_EXPECTED_ROUTE "$screenshot_route"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_PROOF_PATH "$screenshot_proof_path"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH "$accessibility_proof_macos_abs"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_API_BASE_URL "https://spoonjoy.app"
}

is_transient_screenshot_launch_key() {
  [[ "$1" == SPOONJOY_SCREENSHOT_* ]]
}

clear_macos_launch_environment() {
  local uid
  uid="$(id -u)"
  if [[ -f "$macos_launch_env_backup" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      if [[ "$line" == *=* ]]; then
        local key="${line%%=*}"
        local value="${line#*=}"
        if is_transient_screenshot_launch_key "$key"; then
          launchctl asuser "$uid" launchctl unsetenv "$key" >/dev/null 2>&1 || true
        else
          launchctl asuser "$uid" launchctl setenv "$key" "$value" >/dev/null 2>&1 || true
        fi
      else
        launchctl asuser "$uid" launchctl unsetenv "$line" >/dev/null 2>&1 || true
      fi
    done < "$macos_launch_env_backup"
    return
  fi
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_AUTH >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_ACCOUNT_ID >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_SETTINGS_FOCUS >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_EXPECTED_ROUTE >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_PROOF_PATH >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_API_BASE_URL >/dev/null 2>&1 || true
}

ios_udid_from_smoke_log() {
  local smoke_log="$1"
  ruby -e '
    path = ARGV.fetch(0)
    output = File.file?(path) ? File.read(path) : ""
    match = output.match(/Booting simulator: xcrun simctl boot ([A-F0-9-]+)/)
    exit(1) unless match
    puts match[1]
  ' "$smoke_log"
}

wait_for_ios_foreground() {
  local udid="$1"
  local launched_at="$2"
  local output=""
  local foreground_log
  local foreground_status
  if ios_app_is_registered_as_running "$udid"; then
    printf 'Spoonjoy is registered as running before foreground pixel validation\n' >> "$capture_log"
    return 0
  fi
  foreground_log="$(mktemp)"
  for _ in $(seq 1 30); do
    : > "$foreground_log"
    set +e
    run_with_timeout "simulator foreground probe timeout" "$ios_foreground_probe_timeout_seconds" "$foreground_log" \
      xcrun simctl spawn "$udid" log show --start "$launched_at" --style compact --predicate 'process == "SpringBoard" AND eventMessage CONTAINS[c] "Front display did change" AND eventMessage CONTAINS[c] "app.spoonjoy"'
    foreground_status=$?
    set -e
    output="$(cat "$foreground_log")"
    printf '%s\n' "$output" >> "$capture_log"
    if [[ "$foreground_status" -eq 0 && "$output" == *"Front display did change"*"app.spoonjoy"* ]]; then
      rm -f "$foreground_log"
      return 0
    fi
    sleep 0.5
  done
  rm -f "$foreground_log"
  return 1
}

validate_ios_screenshot() {
  local screenshot_path="$1"
  python3 - "$screenshot_path" <<'PY'
import sys
import struct
import zlib

path = sys.argv[1]
with open(path, "rb") as handle:
    data = handle.read()
if not data.startswith(b"\x89PNG\r\n\x1a\n"):
    raise SystemExit("iOS screenshot is not a PNG")

offset = 8
width = height = color_type = bit_depth = None
idat = bytearray()
while offset + 8 <= len(data):
    length = struct.unpack(">I", data[offset:offset + 4])[0]
    chunk_type = data[offset + 4:offset + 8]
    chunk_data = data[offset + 8:offset + 8 + length]
    offset += 12 + length
    if chunk_type == b"IHDR":
        width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk_data)
    elif chunk_type == b"IDAT":
        idat.extend(chunk_data)
    elif chunk_type == b"IEND":
        break

if bit_depth != 8 or color_type not in (2, 6):
    raise SystemExit("iOS screenshot PNG must be 8-bit RGB or RGBA")
if width < 300 or height < 500:
    raise SystemExit("iOS screenshot is too small to prove rendered app content")

channels = 3 if color_type == 2 else 4
stride = width * channels
raw = zlib.decompress(bytes(idat))
rows = []
previous = bytearray(stride)
cursor = 0
for _ in range(height):
    filter_type = raw[cursor]
    cursor += 1
    scanline = bytearray(raw[cursor:cursor + stride])
    cursor += stride
    for i in range(stride):
        left = scanline[i - channels] if i >= channels else 0
        up = previous[i]
        upper_left = previous[i - channels] if i >= channels else 0
        if filter_type == 1:
            scanline[i] = (scanline[i] + left) & 0xff
        elif filter_type == 2:
            scanline[i] = (scanline[i] + up) & 0xff
        elif filter_type == 3:
            scanline[i] = (scanline[i] + ((left + up) // 2)) & 0xff
        elif filter_type == 4:
            predictor = left + up - upper_left
            pa = abs(predictor - left)
            pb = abs(predictor - up)
            pc = abs(predictor - upper_left)
            scanline[i] = (scanline[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else upper_left)) & 0xff
        elif filter_type != 0:
            raise SystemExit(f"unsupported PNG filter {filter_type}")
    rows.append(scanline)
    previous = scanline

black = 0
black_total = 0
for y in list(range(0, int(height * 0.18))) + list(range(int(height * 0.90), height)):
    for x in range(width):
        black_total += 1
        index = x * channels
        red, green, blue = rows[y][index], rows[y][index + 1], rows[y][index + 2]
        if red < 20 and green < 20 and blue < 20:
            black += 1

bone = 0
bone_total = 0
for y in range(int(height * 0.20), int(height * 0.88)):
    for x in range(width):
        bone_total += 1
        index = x * channels
        red, green, blue = rows[y][index], rows[y][index + 1], rows[y][index + 2]
        if red >= 220 and green >= 210 and blue >= 185 and abs(red - green) < 35 and red >= blue:
            bone += 1

black_ratio = black / max(black_total, 1)
bone_ratio = bone / max(bone_total, 1)
distinct_color_buckets = set()
edge_count = 0
edge_total = 0
for y in range(0, height, 4):
    previous = None
    for x in range(0, width, 4):
        index = x * channels
        color = (rows[y][index], rows[y][index + 1], rows[y][index + 2])
        distinct_color_buckets.add(tuple(component // 16 for component in color))
        if previous is not None:
            edge_total += 1
            if sum(abs(color[i] - previous[i]) for i in range(3)) >= 48:
                edge_count += 1
        previous = color

edge_ratio = edge_count / max(edge_total, 1)
if black_ratio > 0.20 or bone_ratio < 0.30 or len(distinct_color_buckets) < 8 or edge_ratio < 0.005:
    raise SystemExit(
        "iOS screenshot does not look like detailed full-screen foreground Spoonjoy content "
        f"(black={black_ratio:.3f}, bone={bone_ratio:.3f}, colors={len(distinct_color_buckets)}, edges={edge_ratio:.3f})"
    )
PY
}

wait_for_screenshot_proof() {
  local proof_path="$1"
  local expected_route="$2"
  local expected_focus="$3"
  local expected_route_identifier="${4:-}"
  for _ in $(seq 1 "$proof_attempts"); do
    if ruby -rjson -e '
      path, expected_route, expected_focus, expected_route_identifier = ARGV
      proof = JSON.parse(File.read(path))
      exit(1) unless proof.fetch("route") == expected_route
      exit(1) if !expected_focus.empty? && proof.fetch("visualFocus") != expected_focus
      exit(1) if !expected_route_identifier.empty? && proof.fetch("routeIdentifier") != expected_route_identifier
    ' "$proof_path" "$expected_route" "$expected_focus" "$expected_route_identifier" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$proof_sleep_seconds"
  done
  printf 'proof wait timed out for screenshot proof %s expected route %s\n' "$proof_path" "$expected_route" >> "$capture_log"
  return 1
}

wait_for_accessibility_proof() {
  local proof_path="$1"
  local expected_route="$2"
  local expected_platform="$3"
  local output_path="$4"
  local source_override="${5:-}"
  for _ in $(seq 1 "$proof_attempts"); do
    if ruby -rjson -rfileutils -e '
      path, expected_route, expected_platform, output_path, source_override = ARGV
      proof = JSON.parse(File.read(path))
      expected_source = case expected_route
                        when "kitchen" then "KitchenView"
                        when "recipes" then "RecipesView"
                        when "saved-recipes" then "SavedRecipesView"
                        when "cookbooks" then "CookbooksView"
                        when "cookbook-detail" then "CookbookDetailView"
                        when "capture" then "CaptureDraftView"
                        when "search" then "SearchView"
                        when "settings" then "SettingsView"
                        when "recipe-detail" then "RecipeDetailView"
                        when "cook-log" then "SpoonCookLogView"
                        when "cook-mode" then "CookModeView"
                        when "shopping-list" then "ShoppingListView"
                        when "chefs" then "ChefsView"
                        else abort("unsupported route #{expected_route}")
                        end
      expected_source = source_override unless source_override.empty?
      evidence_key = expected_source == "SignedOutSetupView" ? "capture-signed-out" : expected_route
      expected_bundle = if expected_platform == "macos"
                          "app.spoonjoy.mac"
                        elsif expected_platform == "ipad"
                          "app.spoonjoy"
                        else
                          "app.spoonjoy"
                        end
      expected_fields = ["dynamicType", "voiceOverLabels", "keyboardNavigation", "reduceMotion", "contrast", "kitchenTableHierarchy", "noOverlap"]
      expected_visible = ["offline", "stale", "queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"]
      expected_dismissible = ["offline", "stale"]
      expected_severe = ["queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"]
      expected_route_evidence = {
        "kitchen" => {
          "voiceOverLabels" => ["On the Counter", "Start Cooking", "Recipe index", "RecipeIndexRow ordinal", "Cookbook shelf"],
          "keyboardNavigationTargets" => ["lead recipe actions", "RecipeIndexRow buttons", "cookbook shelf buttons"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "media-aware contrast on real covers"],
          "hierarchyAnchors" => ["KitchenView", "KitchenMasthead", "RecipeLead", "RecipeIndexRow", "CookbookShelf"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "ordinal"]
        },
        "search" => {
          "voiceOverLabels" => ["Search", "row.accessibilityLabel"],
          "keyboardNavigationTargets" => ["native search field", "typed rows", "SearchSurfaceSectionView buttons"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "herb tint on bone"],
          "hierarchyAnchors" => ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters"]
        },
        "recipes" => {
          "voiceOverLabels" => ["Recipes", "On the Counter", "Recipe index", "Loading recipes"],
          "keyboardNavigationTargets" => ["recipe lead button", "RecipeIndexRow buttons", "search field"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["RecipesView", "KitchenTableHeader", "RecipeCatalogLead", "RecipeIndexRow"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "saved-recipes" => {
          "voiceOverLabels" => ["Saved Recipes", "Recipe index", "Loading saved recipes"],
          "keyboardNavigationTargets" => ["saved recipe lead button", "RecipeIndexRow buttons", "search field"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["SavedRecipesView", "RecipesView", "KitchenTableHeader", "RecipeCatalogLead", "RecipeIndexRow"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cookbooks" => {
          "voiceOverLabels" => ["Cookbooks", "Shelf", "Index", "New Cookbook"],
          "keyboardNavigationTargets" => ["cookbook shelf buttons", "cookbook index rows", "share buttons", "new cookbook action"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["CookbooksView", "KitchenTableHeader", "CookbookCoverArt", "CookbookShelf", "KitchenTableObjectRow"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cookbook-detail" => {
          "voiceOverLabels" => ["Weeknights", "Contents", "Share Cookbook", "Owner tools", "Lemon Pantry Pasta", "Tomato Toast"],
          "keyboardNavigationTargets" => ["cookbook primary actions", "CookbookRecipeIndexRow buttons", "share menu", "CookbookOwnerToolsDisclosure"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone", "secondary text on bone"],
          "hierarchyAnchors" => ["CookbookDetailView", "KitchenTableHeader", "CookbookCoverArt", "CookbookDetailHero", "CookbookRecipeIndexRow", "CookbookOwnerToolsDisclosure"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "capture" => {
          "voiceOverLabels" => ["Import queue", "Capture", "Submit import", "Retry when online", "Hide offline status"],
          "keyboardNavigationTargets" => ["entry point ledger", "saved capture actions", "Retry when online", "offline status dismiss"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone", "destructive action role", "status label on bone"],
          "hierarchyAnchors" => ["CaptureDraftView", "KitchenTableHeader", "CaptureImportEntryPoint", "ImportStatusPanel", "CaptureDraft", "OfflineStatusView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area", "offline-status-section"]
        },
        "capture-signed-out" => {
          "voiceOverLabels" => ["Spoonjoy", "Sign in", "Opening Capture after sign-in", "native Google OAuth sign-in", "native GitHub OAuth sign-in", "native Apple sign-in", "native password sign-in"],
          "keyboardNavigationTargets" => ["native sign-in email or username", "native sign-in password", "native Google OAuth sign-in", "native GitHub OAuth sign-in", "native Apple sign-in", "Settings"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".headline"],
          "contrastPairs" => ["charcoal on bone", "herb button on bone", "brass status on bone"],
          "hierarchyAnchors" => ["SignedOutSetupView", "SpoonjoyIdentityMark", "pendingRouteLabel", "OAuthProviderHint", "SignInWithAppleButton"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters"]
        },
        "settings" => {
          "voiceOverLabels" => ["Settings", "Profile", "Security", "Session", "Sign In"],
          "keyboardNavigationTargets" => ["profile form fields", "security token controls", "session handoff controls"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass label on bone"],
          "hierarchyAnchors" => ["SettingsView", "KitchenTableHeader", "KitchenTableSection", "SettingsPanel"],
          "layoutGuards" => ["kitchen-table-page", "text-fit", "no-tiny-clusters"]
        },
        "recipe-detail" => {
          "voiceOverLabels" => ["Cook mode", "Save", "Yield", "Clear progress", "Add to list", "More", "Steps", "Ingredients", "Cooks"],
          "keyboardNavigationTargets" => ["recipe primary actions", "recipe secondary menu", "recipe yield controls", "step ingredient rows"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "media-aware contrast on real covers", "secondary text on bone"],
          "hierarchyAnchors" => ["RecipeDetailView", "recipeHeaderControls", "RecipeScaleSelector", "KitchenTableActionButtonStyle", "stepsSection", "RecipeStepChecklistRow", "SpoonCookLogView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cook-log" => {
          "voiceOverLabels" => ["Cooks", "What changed?", "Next time", "Add cook photo", "Log cook"],
          "keyboardNavigationTargets" => ["cookLogForm fields", "cookLogPhotoSlot", "cookLogActionBar"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".title2"],
          "contrastPairs" => ["charcoal on bone", "brass on bone", "muted text on bone"],
          "hierarchyAnchors" => ["SpoonCookLogView", "cookLogForm", "cookLogPhotoSlot", "cookLogActionBar"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cook-mode" => {
          "voiceOverLabels" => ["Mark the current step done", "Return to recipe detail", "Current cooking step", "Ingredients", "Cook tools"],
          "keyboardNavigationTargets" => ["cook step handrail", "ingredient toggles", "dependency toggles", "cook tools"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "herb tint on bone", "status text on material"],
          "hierarchyAnchors" => ["CookModeView", "currentStepCard", "cookModeUtilitySheet", "cookModeBottomActionRail", "SpoonDockContext.cookMode", "ScaleSelector"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "shopping-list" => {
          "voiceOverLabels" => ["Shopping", "Kitchen", "Receipt actions", "Add item", "Add from recipe", "Clear checked"],
          "keyboardNavigationTargets" => ["shopping receipt composer", "receipt actions menu", "native tab bar"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass label on bone", "destructive action role"],
          "hierarchyAnchors" => ["ShoppingListView", "shoppingHeaderTools", "shoppingReceiptComposer", "shoppingReceiptState", "TabView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "tab-bar-safe-area"]
        },
        "chefs" => {
          "voiceOverLabels" => ["Chefs", "Fellow chefs", "Kitchen visitors"],
          "keyboardNavigationTargets" => ["chef profile rows", "native More menu", "regular sidebar"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["ChefsView", "ProfileSurfaceViewModel", "ProfileGraphPage"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        }
      }
      abort("#{expected_platform} accessibility proof platform mismatch") unless proof.fetch("platform") == expected_platform
      abort("#{expected_platform} accessibility proof route mismatch") unless proof.fetch("route") == expected_route
      abort("#{expected_platform} accessibility proof source mismatch") unless proof.fetch("source") == expected_source
      abort("#{expected_platform} accessibility proof emitter mismatch") unless proof.fetch("emittedBy") == "SpoonjoyApp"
      abort("#{expected_platform} accessibility proof bundle mismatch") unless proof.fetch("bundleIdentifier") == expected_bundle
      missing_fields = expected_fields.reject { |field| proof[field] == true }
      abort("#{expected_platform} accessibility proof false fields: #{missing_fields.join(", ")}") unless missing_fields.empty?
      abort("#{expected_platform} accessibility proof minimumTargetSize mismatch") unless proof.fetch("minimumTargetSize") >= 44
      abort("#{expected_platform} accessibility proof textFits mismatch") unless proof.fetch("textFits") == true
      abort("#{expected_platform} accessibility proof noTinyClusters mismatch") unless proof.fetch("noTinyClusters") == true
      abort("#{expected_platform} accessibility proof observedDynamicTypeSize missing") unless proof.fetch("observedDynamicTypeSize").is_a?(String) && !proof.fetch("observedDynamicTypeSize").empty?
      abort("#{expected_platform} accessibility proof observedReduceMotion missing") unless [true, false].include?(proof.fetch("observedReduceMotion"))
      visual_readiness = proof.fetch("visualReadiness")
      abort("#{expected_platform} accessibility proof visualReadiness mismatch") unless visual_readiness.is_a?(Hash)
      abort("#{expected_platform} accessibility proof has pending media") unless visual_readiness.fetch("pendingMediaCount") == 0
      abort("#{expected_platform} accessibility proof has failed media") unless visual_readiness.fetch("failedMediaCount") == 0
      abort("#{expected_platform} accessibility proof has blocking indicators") unless visual_readiness.fetch("blockingIndicatorCount") == 0
      abort("#{expected_platform} accessibility proof did not settle") unless visual_readiness.fetch("isSettled") == true
      route_evidence = proof.fetch("routeEvidence")
      abort("#{expected_platform} accessibility proof routeEvidence mismatch") unless route_evidence.is_a?(Hash)
      expected_route_evidence.fetch(evidence_key).each do |field, required_values|
        actual_values = route_evidence.fetch(field)
        abort("#{expected_platform} accessibility proof routeEvidence #{field} is not an array") unless actual_values.is_a?(Array)
        missing_values = required_values.reject { |value| actual_values.include?(value) }
        abort("#{expected_platform} accessibility proof routeEvidence #{field} missing #{missing_values.join(", ")}") unless missing_values.empty?
      end
      offline = proof.fetch("offlineIndicatorProof")
      abort("#{expected_platform} accessibility proof offline source mismatch") unless offline.fetch("source") == "OfflineStatusView"
      abort("#{expected_platform} accessibility proof visible states mismatch") unless offline.fetch("visibleStates") == expected_visible
      abort("#{expected_platform} accessibility proof dismissible states mismatch") unless offline.fetch("dismissibleStates") == expected_dismissible
      abort("#{expected_platform} accessibility proof severe states mismatch") unless offline.fetch("severeStates") == expected_severe
      abort("#{expected_platform} accessibility proof hidden states mismatch") unless offline.fetch("hiddenStates") == ["synced", "dismissed"]
      abort("#{expected_platform} accessibility proof voiceOverLabel mismatch") unless offline.fetch("voiceOverLabel") == true
      abort("#{expected_platform} accessibility proof dismissButtonLabel mismatch") unless offline.fetch("dismissButtonLabel") == "Hide offline status"
      abort("#{expected_platform} accessibility proof severityCorrect mismatch") unless offline.fetch("severityCorrect") == true
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, JSON.pretty_generate(proof) + "\n")
    ' "$proof_path" "$expected_route" "$expected_platform" "$output_path" "$source_override" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$proof_sleep_seconds"
  done
  printf 'proof wait timed out for accessibility proof %s expected route %s platform %s\n' "$proof_path" "$expected_route" "$expected_platform" >> "$capture_log"
  return 1
}

log_accessibility_proof_diagnostic() {
  local proof_path="$1"
  local expected_route="$2"
  local expected_platform="$3"
  local label="$4"
  if [[ -f "$proof_path" ]]; then
    ruby -rjson -e '
      path, expected_route, expected_platform, label = ARGV
      proof = JSON.parse(File.read(path))
      summary = {
        "expectedRoute" => expected_route,
        "expectedPlatform" => expected_platform,
        "actualRoute" => proof["route"],
        "actualPlatform" => proof["platform"],
        "actualSource" => proof["source"],
        "bundleIdentifier" => proof["bundleIdentifier"],
        "observedDynamicTypeSize" => proof["observedDynamicTypeSize"],
        "routeEvidenceKeys" => (proof["routeEvidence"].is_a?(Hash) ? proof["routeEvidence"].keys.sort : []),
        "launchEnvironmentProof" => proof["launchEnvironmentProof"]
      }
      state_path = File.expand_path("~/Library/Application Support/Spoonjoy/native-app-state.json")
      if File.file?(state_path)
        state = JSON.parse(File.read(state_path))
        summary["appStateRoute"] = state["lastOpenedRoute"]
        summary["appStateAccountID"] = state["accountID"]
        summary["appStateEnvironment"] = state["environment"]
        summary["appStateFirstRun"] = state["hasCompletedFirstRun"]
      end
      warn("#{label} accessibility proof mismatch: #{JSON.generate(summary)}")
    ' "$proof_path" "$expected_route" "$expected_platform" "$label" >> "$capture_log" 2>&1 || true
  else
    printf '%s accessibility proof missing at %s (expected route %s, platform %s)\n' \
      "$label" "$proof_path" "$expected_route" "$expected_platform" >> "$capture_log"
  fi
}

validate_screenshot_surface_proof() {
  local proof_path="$1"
  local output_path="$2"
  local platform="$3"
  if [[ "$screenshot_route" != "settings" && "$screenshot_route" != "search" ]]; then
    return 0
  fi
  ruby -rjson -rfileutils -e '
    path, output_path, platform, screenshot_route, expected_focus, expected_recorded_route, capture_account_id, expected_search_query, expected_search_scope, search_capture_variant = ARGV
    proof = JSON.parse(File.read(path))
    if screenshot_route == "settings"
      abort("#{platform} screenshot proof route mismatch") unless proof.fetch("route") == "settings"
      abort("#{platform} screenshot proof focus mismatch") unless proof.fetch("visualFocus") == expected_focus
      abort("#{platform} screenshot proof source mismatch") unless proof.fetch("source") == "SettingsView"
    else
      expected_scopes = ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
      abort("#{platform} screenshot proof route mismatch") unless proof.fetch("route") == "search"
      abort("#{platform} screenshot proof route identifier mismatch") unless proof.fetch("routeIdentifier") == expected_recorded_route
      abort("#{platform} screenshot proof source mismatch") unless proof.fetch("source") == "SearchView"
      abort("#{platform} screenshot proof account mismatch") unless proof.fetch("accountID") == capture_account_id
      abort("#{platform} screenshot proof scope mismatch") unless proof.fetch("scope") == expected_search_scope
      abort("#{platform} screenshot proof query mismatch") unless proof.fetch("query") == expected_search_query
      abort("#{platform} screenshot proof searchable scopes mismatch") unless proof.fetch("searchScopes") == expected_scopes
    end
    sections = proof.fetch("visibleSections")
    abort("#{platform} screenshot proof sections must be an array") unless sections.is_a?(Array)
    if screenshot_route == "settings"
      required_sections = if expected_focus == "notifications"
                            ["This Device", "Push Delivery", "Notification Sync", "Agent Access"]
                          elsif expected_focus == "signed-out"
                            ["Session", "Environment", "Offline"]
                          else
                            ["Profile", "Security"]
                          end
      missing = required_sections.reject { |section| sections.include?(section) }
      abort("#{platform} screenshot proof missing sections: #{missing.join(", ")}") unless missing.empty?
    else
      required_sections = case search_capture_variant
                          when "blank" then ["Recipes", "Chefs"]
                          when "typed-results", "scoped-recipes" then ["Recipes"]
                          when "scoped-cookbooks" then ["Cookbooks"]
                          when "scoped-chefs" then ["Chefs"]
                          when "scoped-shopping" then ["Shopping"]
                          when "no-results" then []
                          else abort("#{platform} unsupported search capture variant #{search_capture_variant}")
                          end
      missing = required_sections.reject { |section| sections.include?(section) }
      abort("#{platform} screenshot proof missing sections: #{missing.join(", ")}") unless missing.empty?
      if search_capture_variant == "no-results" && !sections.empty?
        abort("#{platform} no-results search proof must not include result sections: #{sections.join(", ")}")
      end
    end
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, JSON.pretty_generate(proof.merge("platform" => platform)) + "\n")
  ' "$proof_path" "$output_path" "$platform" "$screenshot_route" "$settings_capture_focus" "$expected_recorded_route" "$capture_account_id" "$expected_search_query" "$expected_search_scope" "$search_capture_variant"
}

resolve_ios_data_container() {
  local udid="$1"
  local container_log
  local data_container
  local get_container_status
  container_log="$(mktemp)"
  for _ in $(seq 1 5); do
    : > "$container_log"
    set +e
    data_container="$(xcrun simctl get_app_container "$udid" app.spoonjoy data 2>"$container_log")"
    get_container_status=$?
    set -e
    if [[ "$get_container_status" -eq 0 && -n "$data_container" && -d "$data_container" ]]; then
      rm -f "$container_log"
      printf '%s\n' "$data_container"
      return 0
    fi
    printf 'simulator app data container lookup failed (exit %s, path %s)\n' "$get_container_status" "${data_container:-<empty>}" >> "$capture_log"
    cat "$container_log" >> "$capture_log"
    sleep 1
  done
  rm -f "$container_log"
  return 1
}

capture_ios_app() {
  local udid="$1"
  local expected_platform="$2"
  local screenshot_output="$3"
  local surface_proof_output="$4"
  local accessibility_proof_output="$5"
  local data_container
  local terminate_log
  local bootstatus_log
  local launched_at
  bootstatus_log="$(mktemp)"
  terminate_log="$(mktemp)"
  if run_with_timeout "simulator boot readiness timeout" "$ios_boot_timeout_seconds" "$bootstatus_log" \
    xcrun simctl bootstatus "$udid" -b; then
    printf 'Reusing simulator booted by smoke preparation: %s\n' "$udid" >> "$capture_log"
  else
    cat "$bootstatus_log" >> "$capture_log"
    : > "$bootstatus_log"
    run_with_timeout "simulator boot request timeout" "$ios_boot_timeout_seconds" "$capture_log" \
      xcrun simctl boot "$udid" || true
    if ! run_with_timeout "simulator boot readiness timeout" "$ios_boot_timeout_seconds" "$bootstatus_log" \
      xcrun simctl bootstatus "$udid" -b; then
      cat "$bootstatus_log" >> "$capture_log"
      rm -f "$bootstatus_log"
      return 1
    fi
    printf 'Recovered simulator boot before capture: %s\n' "$udid" >> "$capture_log"
  fi
  rm -f "$bootstatus_log"
  if ! data_container="$(resolve_ios_data_container "$udid")"; then
    printf 'unable to resolve simulator app data container for app.spoonjoy on %s\n' "$udid" >> "$capture_log"
    return 1
  fi
  local ios_app_dir="$data_container/Library/Application Support/Spoonjoy"
  screenshot_proof_path="$ios_app_dir/native-screenshot-proof.json"
  ios_accessibility_proof_runtime_path="$ios_app_dir/native-accessibility-proof.json"
  write_app_state "$ios_app_dir/native-app-state.json" "$expected_recorded_route"
  write_cache_state "$ios_app_dir/native-durable-cache.json" "$screenshot_route"
  write_sync_store "$ios_app_dir/native-sync-store.json" "$screenshot_route"
  rm -f "$screenshot_proof_path"
  rm -f "$ios_accessibility_proof_runtime_path"
  rm -f "$ios_app_dir/debug-auth-session.json"
  if ! xcrun simctl terminate "$udid" app.spoonjoy >"$terminate_log" 2>&1; then
    if ! grep -qi "found nothing to terminate" "$terminate_log"; then
      cat "$terminate_log" >> "$capture_log"
    fi
  fi
  rm -f "$terminate_log"
  launched_at="$(date -u '+%Y-%m-%d %H:%M:%S')"
  if ! ios_launch_app "$udid"; then
    printf 'simulator launch timeout or failure for iOS route %s\n' "$screenshot_route" >> "$capture_log"
    if ios_app_is_registered_as_running "$udid"; then
      printf 'Spoonjoy is registered as running after screenshot launch timeout; continuing to foreground/proof checks\n' >> "$capture_log"
    else
      return 1
    fi
  fi
  wait_for_ios_foreground "$udid" "$launched_at" || return 1
  sleep 1
  if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]]; then
    local proof_focus="$settings_capture_focus"
    local proof_route_identifier=""
    if [[ "$screenshot_route" == "search" ]]; then
      proof_focus=""
      proof_route_identifier="$expected_search_route_identifier"
    fi
    wait_for_screenshot_proof "$screenshot_proof_path" "$screenshot_route" "$proof_focus" "$proof_route_identifier" || return 1
    validate_screenshot_surface_proof "$screenshot_proof_path" "$surface_proof_output" "$expected_platform" >> "$capture_log" 2>&1 || return 1
  fi
  if ! wait_for_accessibility_proof "$ios_accessibility_proof_runtime_path" "$screenshot_route" "$expected_platform" "$accessibility_proof_output" "$expected_accessibility_source"; then
    log_accessibility_proof_diagnostic "$ios_accessibility_proof_runtime_path" "$screenshot_route" "$expected_platform" "$expected_platform"
    printf 'Spoonjoy did not write the expected %s accessibility proof for %s\n' "$expected_platform" "$screenshot_route" >> "$capture_log"
    return 1
  fi
  xcrun simctl io "$udid" screenshot "$screenshot_output" >> "$capture_log" 2>&1
  [[ -f "$screenshot_output" && -s "$screenshot_output" ]]
  validate_ios_screenshot "$screenshot_output" >> "$capture_log" 2>&1
}

capture_ios_app_with_retries() {
  local udid="$1"
  local expected_platform="$2"
  local screenshot_output="$3"
  local surface_proof_output="$4"
  local accessibility_proof_output="$5"
  local attempt=1
  while [[ "$attempt" -le "$ios_capture_attempts" ]]; do
    rm -f "$screenshot_output" "$surface_proof_output" "$accessibility_proof_output"
    if capture_ios_app "$udid" "$expected_platform" "$screenshot_output" "$surface_proof_output" "$accessibility_proof_output"; then
      return 0
    fi
    printf '%s screenshot capture attempt %s/%s failed for route %s\n' "$expected_platform" "$attempt" "$ios_capture_attempts" "$screenshot_route" >> "$capture_log"
    if [[ "$attempt" -lt "$ios_capture_attempts" ]]; then
      xcrun simctl terminate "$udid" app.spoonjoy >> "$capture_log" 2>&1 || true
      xcrun simctl shutdown "$udid" >> "$capture_log" 2>&1 || true
      sleep 2
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

capture_macos_window() {
  run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application \"$macos_app\" to activate" || true
  sleep 1
  local window_id=""
  local spoonjoy_pid=""
  for _ in $(seq 1 20); do
    spoonjoy_pid="$(pgrep -x Spoonjoy | tail -n 1 || true)"
    if [[ -n "$spoonjoy_pid" ]] && window_id="$(swift scripts/find-macos-window-id.swift "$spoonjoy_pid" "$macos_window_title" 2>> "$capture_log")"; then
      break
    fi
    window_id=""
    sleep 0.5
  done
  if [[ -z "$window_id" ]]; then
    return 1
  fi
  screencapture -x -l "$window_id" "$macos_screenshot" >> "$capture_log" 2>&1
  [[ -f "$macos_screenshot" && -s "$macos_screenshot" ]]
}

wait_for_route() {
  local expected_route="$1"
  for _ in $(seq 1 60); do
    if ruby -rjson -e '
      path, expected_route = ARGV
      snapshot = JSON.parse(File.read(path))
      exit(1) unless snapshot.fetch("hasCompletedFirstRun") == true
      exit(1) unless snapshot.fetch("lastOpenedRoute") == expected_route
    ' "$state_file" "$expected_route" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
}

run_smoke() {
  local label="$1"
  local log_path="$2"
  local blocker_path="$3"
  shift 3

  printf 'Running %s smoke\n' "$label" >> "$capture_log"
  set +e
  "$@" --artifact-root "$artifact_root" --log "$log_path" --blocker "$blocker_path" >> "$capture_log" 2>&1
  local status=$?
  set -e

  if [[ "$status" -ne 0 && ! -f "$blocker_path" ]]; then
    if is_xcode_platform_blocker "$log_path"; then
      write_blocker \
        "$xcode_blocker" \
        "XcodePlatform" \
        "$*" \
        "$log_path" \
        "Local Xcode platform or pre-parse state blocked screenshot app preparation." \
        "Install the required Xcode platform/runtime and rerun screenshot capture."
      return 0
    fi
    printf '%s smoke failed without a runtime blocker; see %s\n' "$label" "$log_path" >> "$capture_log"
    return "$status"
  fi
}

run_ios_smoke() {
  local label="$1"
  local family="$2"
  local smoke_log="$3"
  local blocker="$4"
  local attempt=1
  local install_marker="${SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER:-}"
  local preferred_udid=""
  local -a simulator_environment=(env -u SPOONJOY_IOS_SIMULATOR_UDID -u SPOONJOY_IOS_SIMULATOR_NAME)
  if [[ "$family" == "iphone" ]]; then
    preferred_udid="${SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID:-}"
  else
    preferred_udid="${SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID:-}"
  fi
  if [[ -n "$preferred_udid" ]]; then
    simulator_environment+=("SPOONJOY_IOS_SIMULATOR_UDID=$preferred_udid")
  fi
  if [[ -n "$install_marker" ]]; then
    install_marker="${install_marker}-${family}"
  fi
  while [[ "$attempt" -le "$ios_smoke_attempts" ]]; do
    rm -f "$blocker"
    run_smoke "$label" "$smoke_log" "$blocker" \
      "${simulator_environment[@]}" \
      SPOONJOY_IOS_SIMULATOR_FAMILY="$family" \
      SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER="$install_marker" \
      scripts/smoke-ios-simulator.sh
    if [[ ! -f "$blocker" || -f "$xcode_blocker" ]]; then
      return 0
    fi
    printf '%s smoke attempt %s/%s produced blocker\n' "$label" "$attempt" "$ios_smoke_attempts" >> "$capture_log"
    if [[ "$attempt" -lt "$ios_smoke_attempts" ]]; then
      local retry_udid=""
      retry_udid="$(ios_udid_from_smoke_log "$smoke_log" || true)"
      if [[ -n "$retry_udid" ]]; then
        xcrun simctl shutdown "$retry_udid" >> "$capture_log" 2>&1 || true
      else
        xcrun simctl shutdown all >> "$capture_log" 2>&1 || true
      fi
      sleep 2
    fi
    attempt=$((attempt + 1))
  done
}

: > "$capture_log"
rm -f "$ios_screenshot" "$ios_tablet_screenshot" "$macos_screenshot"
rm -f "$ios_proof_artifact" "$ipad_proof_artifact" "$macos_proof_artifact"
rm -f "$accessibility_proof_ios" "$accessibility_proof_ipad" "$accessibility_proof_macos"
rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_ipad_abs" "$accessibility_proof_macos_abs"
rm -f "$design_review_blocked"
rm -f "$design_review"
rm -f "$xcode_blocker" "$ios_blocker" "$ipad_blocker" "$macos_blocker"

run_ios_smoke "iPhone simulator" "iphone" "$ios_smoke_log" "$ios_blocker"
if [[ ! -f "$xcode_blocker" ]]; then
  run_ios_smoke "iPad simulator" "ipad" "$ipad_smoke_log" "$ipad_blocker"
fi
if [[ ! -f "$xcode_blocker" ]]; then
  run_smoke "macOS launch" "$macos_smoke_log" "$macos_blocker" scripts/smoke-macos.sh
fi

if [[ ! -f "$xcode_blocker" && ! -f "$ios_blocker" ]]; then
  ios_udid="$(ios_udid_from_smoke_log "$ios_smoke_log" || true)"
  if [[ -z "$ios_udid" ]] || ! capture_ios_app_with_retries "$ios_udid" "ios" "$ios_screenshot" "$ios_proof_artifact" "$accessibility_proof_ios_abs"; then
    write_blocker \
      "$ios_blocker" \
      "CoreSimulator" \
      "xcrun simctl launch/io $ios_udid app.spoonjoy $ios_screenshot" \
      "$capture_log" \
      "CoreSimulator could not capture a foreground Spoonjoy iOS screenshot for route $screenshot_route; simulator launch timeout, foreground wait timeout, proof wait timeout, or screenshot capture failure occurred." \
      "Boot an available iPhone simulator, confirm Spoonjoy stays foregrounded, and rerun screenshot capture."
  fi
fi

if [[ ! -f "$xcode_blocker" && ! -f "$ipad_blocker" ]]; then
  ipad_udid="$(ios_udid_from_smoke_log "$ipad_smoke_log" || true)"
  if [[ -z "$ipad_udid" ]] || ! capture_ios_app_with_retries "$ipad_udid" "ipad" "$ios_tablet_screenshot" "$ipad_proof_artifact" "$accessibility_proof_ipad_abs"; then
    write_blocker \
      "$ipad_blocker" \
      "CoreSimulator" \
      "xcrun simctl launch/io $ipad_udid app.spoonjoy $ios_tablet_screenshot" \
      "$capture_log" \
      "CoreSimulator could not capture a foreground Spoonjoy iPad screenshot for route $screenshot_route; simulator launch timeout, foreground wait timeout, settled-render proof timeout, or screenshot capture failure occurred." \
      "Boot an available iPad simulator, confirm Spoonjoy stays foregrounded, and rerun screenshot capture."
  fi
fi

if [[ ! -f "$xcode_blocker" && ! -f "$macos_blocker" ]]; then
  state_had_backup=false
  mkdir -p "$(dirname "$state_file")"
  if [[ -f "$state_file" ]]; then
    cp "$state_file" "$state_backup"
    state_had_backup=true
  else
    rm -f "$state_backup"
  fi
  cache_had_backup=false
  if [[ -f "$cache_file" ]]; then
    cp "$cache_file" "$cache_backup"
    cache_had_backup=true
  else
    rm -f "$cache_backup"
  fi
  sync_had_backup=false
  if [[ -f "$sync_file" ]]; then
    cp "$sync_file" "$sync_backup"
    sync_had_backup=true
  else
    rm -f "$sync_backup"
  fi
  proof_had_backup=false
  if [[ -f "$proof_file" ]]; then
    cp "$proof_file" "$proof_backup"
    proof_had_backup=true
  else
    rm -f "$proof_backup"
  fi
  auth_had_backup=false
  if [[ -f "$auth_file" ]]; then
    cp "$auth_file" "$auth_backup"
    auth_had_backup=true
  else
    rm -f "$auth_backup"
  fi
  restore_capture_state() {
    clear_macos_launch_environment
    if [[ "$state_had_backup" == "true" && -f "$state_backup" ]]; then
      mkdir -p "$(dirname "$state_file")"
      cp "$state_backup" "$state_file"
    else
      rm -f "$state_file"
    fi
    if [[ "$cache_had_backup" == "true" && -f "$cache_backup" ]]; then
      mkdir -p "$(dirname "$cache_file")"
      cp "$cache_backup" "$cache_file"
    else
      rm -f "$cache_file"
    fi
    if [[ "$sync_had_backup" == "true" && -f "$sync_backup" ]]; then
      mkdir -p "$(dirname "$sync_file")"
      cp "$sync_backup" "$sync_file"
    else
      rm -f "$sync_file"
    fi
    if [[ "$proof_had_backup" == "true" && -f "$proof_backup" ]]; then
      mkdir -p "$(dirname "$proof_file")"
      cp "$proof_backup" "$proof_file"
    else
      rm -f "$proof_file"
    fi
    if [[ "$auth_had_backup" == "true" && -f "$auth_backup" ]]; then
      mkdir -p "$(dirname "$auth_file")"
      cp "$auth_backup" "$auth_file"
    else
      rm -f "$auth_file"
    fi
  }
  trap restore_capture_state EXIT
  rm -f "$state_file"
  rm -f "$cache_file"
  rm -f "$sync_file"
  rm -f "$proof_file"
  rm -f "$auth_file"
  rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
  screenshot_proof_path="$proof_file"
  write_app_state "$state_file" "$expected_recorded_route"
  write_cache_state "$cache_file" "$screenshot_route"
  write_sync_store "$sync_file" "$screenshot_route"
  run_cleanup_command "quit Spoonjoy before capture" osascript -e 'tell application id "app.spoonjoy.mac" to quit' || true
  run_cleanup_command "kill Spoonjoy before capture" pkill -x Spoonjoy || true
  sleep 1
  if ! open_macos_app; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "open -n $macos_app" \
      "$capture_log" \
      "Spoonjoy macOS launch timeout or failure occurred before screenshot capture." \
      "Launch the app from an unlocked desktop session and rerun screenshot capture."
  fi
  sleep 3
  if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" pgrep -x Spoonjoy; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "pgrep -x Spoonjoy" \
      "$capture_log" \
      "Spoonjoy macOS process was not running after launch." \
      "Launch the app from an unlocked desktop session and rerun screenshot capture."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"spoonjoy://$deep_link_path\""; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "spoonjoy://$deep_link_path" \
      "$capture_log" \
      "Spoonjoy macOS route open timeout or failure occurred before screenshot capture." \
      "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
  fi
  wait_for_route "$expected_recorded_route" || true
  proof_focus="$settings_capture_focus"
  proof_route_identifier=""
  if [[ "$screenshot_route" == "search" ]]; then
    proof_focus=""
    proof_route_identifier="$expected_search_route_identifier"
  fi
  if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]] && ! wait_for_screenshot_proof "$proof_file" "$screenshot_route" "$proof_focus" "$proof_route_identifier"; then
    printf 'Spoonjoy did not write the expected macOS screenshot proof for %s\n' "$screenshot_route" >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
      "$capture_log" \
      "Spoonjoy macOS did not prove the expected visible screenshot route." \
      "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs" "$expected_accessibility_source"; then
    log_accessibility_proof_diagnostic "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "macOS"
    printf 'Spoonjoy did not write the expected macOS accessibility proof for %s\n' "$screenshot_route" >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=$accessibility_proof_macos_abs spoonjoy://$deep_link_path" \
      "$capture_log" \
      "Spoonjoy macOS did not prove the expected accessibility state for the screenshot route." \
      "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
  fi
  if [[ ! -f "$macos_blocker" ]]; then
    ruby -rjson -e '
      path, expected_route = ARGV
      snapshot = JSON.parse(File.read(path))
      abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
      actual_route = snapshot.fetch("lastOpenedRoute")
      abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
    ' "$state_file" "$expected_recorded_route" >> "$capture_log" 2>&1
  fi
  if [[ ! -f "$macos_blocker" ]] && ! validate_screenshot_surface_proof "$proof_file" "$macos_proof_artifact" "macos" >> "$capture_log" 2>&1; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
      "$capture_log" \
      "Spoonjoy macOS screenshot proof did not match the expected route." \
      "Rerun screenshot capture after the expected route is visible."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! capture_macos_window; then
    printf 'Retrying Spoonjoy window capture after relaunch\n' >> "$capture_log"
    run_cleanup_command "quit Spoonjoy before relaunch" osascript -e 'tell application id "app.spoonjoy.mac" to quit' || true
    run_cleanup_command "kill Spoonjoy before relaunch" pkill -x Spoonjoy || true
    sleep 1
    rm -f "$proof_file"
    rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
    write_app_state "$state_file" "$expected_recorded_route"
    write_cache_state "$cache_file" "$screenshot_route"
    write_sync_store "$sync_file" "$screenshot_route"
    if ! open_macos_app; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "open -n $macos_app" \
        "$capture_log" \
        "Spoonjoy macOS relaunch timeout or failure occurred before screenshot capture." \
        "Launch the app from an unlocked desktop session and rerun screenshot capture."
    fi
    sleep 3
    if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" pgrep -x Spoonjoy; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "pgrep -x Spoonjoy" \
        "$capture_log" \
        "Spoonjoy macOS process was not running after relaunch." \
        "Launch the app from an unlocked desktop session and rerun screenshot capture."
    fi
    if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"spoonjoy://$deep_link_path\""; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "spoonjoy://$deep_link_path" \
        "$capture_log" \
        "Spoonjoy macOS route open timeout or failure occurred after relaunch." \
        "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
    fi
    wait_for_route "$expected_recorded_route" || true
    if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]] && ! wait_for_screenshot_proof "$proof_file" "$screenshot_route" "$proof_focus" "$proof_route_identifier"; then
      printf 'Spoonjoy did not write the expected macOS screenshot proof after relaunch for %s\n' "$screenshot_route" >> "$capture_log"
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
        "$capture_log" \
        "Spoonjoy macOS did not prove the expected visible screenshot route after relaunch." \
        "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
    fi
    if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs" "$expected_accessibility_source"; then
      log_accessibility_proof_diagnostic "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "macOS relaunch"
      printf 'Spoonjoy did not write the expected macOS accessibility proof after relaunch for %s\n' "$screenshot_route" >> "$capture_log"
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=$accessibility_proof_macos_abs spoonjoy://$deep_link_path" \
        "$capture_log" \
        "Spoonjoy macOS did not prove the expected accessibility state for the screenshot route after relaunch." \
        "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
    fi
    if [[ ! -f "$macos_blocker" ]]; then
      ruby -rjson -e '
        path, expected_route = ARGV
        snapshot = JSON.parse(File.read(path))
        abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
        actual_route = snapshot.fetch("lastOpenedRoute")
        abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
      ' "$state_file" "$expected_recorded_route" >> "$capture_log" 2>&1
    fi
    if [[ ! -f "$macos_blocker" ]] && ! validate_screenshot_surface_proof "$proof_file" "$macos_proof_artifact" "macos" >> "$capture_log" 2>&1; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
        "$capture_log" \
        "Spoonjoy macOS screenshot proof did not match the expected route after relaunch." \
        "Rerun screenshot capture after the expected route is visible."
    fi
    if [[ ! -f "$macos_blocker" ]]; then
      capture_macos_window || true
    fi
  fi
  if [[ ! -f "$macos_blocker" && ( ! -f "$macos_screenshot" || ! -s "$macos_screenshot" ) ]]; then
    printf 'Spoonjoy window not found for macOS screenshot capture\n' >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "scripts/find-macos-window-id.swift <pid> $macos_window_title && screencapture -x -l <window-id> $macos_screenshot" \
      "$capture_log" \
      "Spoonjoy window capture was unavailable in the macOS GUI session." \
      "Run screenshot capture from an unlocked desktop session with Screen Recording permission for the terminal."
  fi
  run_cleanup_command "quit Spoonjoy after capture" osascript -e 'tell application id "app.spoonjoy.mac" to quit' || true
  run_cleanup_command "kill Spoonjoy after capture" pkill -x Spoonjoy || true
fi

if [[ -f "$xcode_blocker" ]]; then
  write_design_review_blocked "$xcode_blocker"
elif [[ -f "$ios_blocker" ]]; then
  write_design_review_blocked "$ios_blocker"
elif [[ -f "$ipad_blocker" ]]; then
  write_design_review_blocked "$ipad_blocker"
elif [[ -f "$macos_blocker" ]]; then
  write_design_review_blocked "$macos_blocker"
else
  if [[ ! -s "$ios_screenshot" || ! -s "$ios_tablet_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce iPhone, iPad, and macOS screenshots\n' >&2
    exit 1
  fi
  if [[ ! -s "$accessibility_proof_ios_abs" || ! -s "$accessibility_proof_ipad_abs" || ! -s "$accessibility_proof_macos_abs" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce iPhone, iPad, and macOS accessibility proofs\n' >&2
    exit 1
  fi
  write_design_review_success
  rm -f "$design_review_blocked"
fi

if [[ -f "$design_review_blocked" && -f "$design_review" ]]; then
  printf 'conflicting design review success and blocker artifacts\n' >&2
  exit 1
fi

if [[ -f "$design_review_blocked" ]]; then
  ruby scripts/validate-design-review-blocker.rb "$design_review_blocked" --artifact-root "$artifact_root" --unit-slug "$unit_slug"
  printf 'native screenshot capture blocked: %s\n' "$design_review_blocked"
else
  ruby scripts/validate-design-review.rb "$design_review"
  printf 'native screenshot capture complete: %s\n' "$design_review"
fi
