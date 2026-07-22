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
artifact_root_abs="$(cd "$artifact_root" && pwd -P)"
ios_screenshot="$artifact_root/screenshots/ios-mobile.png"
ios_accessibility_screenshot="$artifact_root/screenshots/ios-mobile-accessibility.png"
ios_tablet_screenshot="$artifact_root/screenshots/ios-tablet.png"
ios_deep_scroll_screenshot="$artifact_root/screenshots/ios-mobile-deep-scroll.png"
ios_accessibility_deep_scroll_screenshot="$artifact_root/screenshots/ios-mobile-accessibility-deep-scroll.png"
ios_tablet_deep_scroll_screenshot="$artifact_root/screenshots/ios-tablet-deep-scroll.png"
macos_screenshot="$artifact_root/screenshots/macos-desktop.png"
macos_screenshot_diagnostic="$artifact_root/screenshots/macos-desktop-diagnostic.png"
ios_app="${SPOONJOY_SCREENSHOT_IOS_APP_PATH:-}"
ios_ui_test_runner="${SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH:-}"
ios_xctestrun="${SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH:-}"
macos_app="${SPOONJOY_SCREENSHOT_MACOS_APP_PATH:-$artifact_root/DerivedData-macOS/Build/Products/BootstrapDebug/Spoonjoy.app}"
design_review="$artifact_root/design-review.json"
design_review_blocked="$artifact_root/design-review-blocked.json"
matrix_log="$artifact_root/apple/${unit_slug}-screenshots.log"
capture_log="$artifact_root/apple/${unit_slug}-screenshots-inner.log"
ios_app_stdout_log="$artifact_root/apple/${unit_slug}-ios-app-stdout.log"
ios_app_stderr_log="$artifact_root/apple/${unit_slug}-ios-app-stderr.log"
ios_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ios.log"
ipad_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ipad.log"
macos_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-macos.log"
xcode_blocker="$artifact_root/apple/${unit_slug}-screenshots-xcode-platform-blocker.json"
ios_blocker="$artifact_root/apple/${unit_slug}-screenshots-core-simulator-blocker.json"
ipad_blocker="$artifact_root/apple/${unit_slug}-screenshots-ipad-core-simulator-blocker.json"
macos_blocker="$artifact_root/apple/${unit_slug}-screenshots-macos-launch-blocker.json"
macos_accessibility_blocker="$artifact_root/apple/${unit_slug}-screenshots-macos-accessibility-blocker.json"
macos_state_directory="$artifact_root_abs/macos-state/Spoonjoy"
state_file="$macos_state_directory/native-app-state.json"
cache_file="$macos_state_directory/native-durable-cache.json"
sync_file="$macos_state_directory/native-sync-store.json"
fixture_cover_source="Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png"
proof_file="$macos_state_directory/native-screenshot-proof.json"
auth_file="$macos_state_directory/debug-auth-session.json"
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
accessibility_proof_ios_ax="$artifact_root/apple/${unit_slug}-accessibility-proof-ios-ax.json"
accessibility_proof_ipad="$artifact_root/apple/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos="$artifact_root/apple/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_ios_ax_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ios-ax.json"
accessibility_proof_ipad_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_rel="apple/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_ios_ax_rel="apple/${unit_slug}-accessibility-proof-ios-ax.json"
accessibility_proof_ipad_rel="apple/${unit_slug}-accessibility-proof-ipad.json"
accessibility_proof_macos_rel="apple/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_deep_scroll="${accessibility_proof_ios%.json}-deep-scroll.json"
accessibility_proof_ios_ax_deep_scroll="${accessibility_proof_ios_ax%.json}-deep-scroll.json"
accessibility_proof_ipad_deep_scroll="${accessibility_proof_ipad%.json}-deep-scroll.json"
accessibility_proof_ios_deep_scroll_abs="${accessibility_proof_ios_abs%.json}-deep-scroll.json"
accessibility_proof_ios_ax_deep_scroll_abs="${accessibility_proof_ios_ax_abs%.json}-deep-scroll.json"
accessibility_proof_ipad_deep_scroll_abs="${accessibility_proof_ipad_abs%.json}-deep-scroll.json"
accessibility_proof_ios_deep_scroll_rel="${accessibility_proof_ios_rel%.json}-deep-scroll.json"
accessibility_proof_ios_ax_deep_scroll_rel="${accessibility_proof_ios_ax_rel%.json}-deep-scroll.json"
accessibility_proof_ipad_deep_scroll_rel="${accessibility_proof_ipad_rel%.json}-deep-scroll.json"
observed_accessibility_ios="$artifact_root/apple/${unit_slug}-observed-accessibility-ios.json"
observed_accessibility_ios_ax="$artifact_root/apple/${unit_slug}-observed-accessibility-ios-ax.json"
observed_accessibility_ipad="$artifact_root/apple/${unit_slug}-observed-accessibility-ipad.json"
observed_accessibility_macos="$artifact_root/apple/${unit_slug}-observed-accessibility-macos.json"
observed_accessibility_macos_diagnostic="$artifact_root/apple/${unit_slug}-observed-accessibility-macos-diagnostic.json"
observed_accessibility_ios_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-observed-accessibility-ios.json"
observed_accessibility_ios_ax_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-observed-accessibility-ios-ax.json"
observed_accessibility_ipad_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-observed-accessibility-ipad.json"
observed_accessibility_macos_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-observed-accessibility-macos.json"
observed_accessibility_ios_rel="apple/${unit_slug}-observed-accessibility-ios.json"
observed_accessibility_ios_ax_rel="apple/${unit_slug}-observed-accessibility-ios-ax.json"
observed_accessibility_ipad_rel="apple/${unit_slug}-observed-accessibility-ipad.json"
observed_accessibility_macos_rel="apple/${unit_slug}-observed-accessibility-macos.json"
ios_observer_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_OBSERVER_TIMEOUT_SECONDS:-300}"
macos_observer_timeout_seconds="${SPOONJOY_SCREENSHOT_MACOS_OBSERVER_TIMEOUT_SECONDS:-60}"
macos_observer_preflight_timeout_seconds="${SPOONJOY_SCREENSHOT_MACOS_OBSERVER_PREFLIGHT_TIMEOUT_SECONDS:-5}"
ios_accessibility_proof_runtime_path=""
screenshot_proof_path=""
screenshot_run_nonce=""
macos_screenshot_pid=""
ios_state_directory=""
screenshot_route="kitchen"
shopping_capture_variant="normal"
search_capture_variant="blank"
capture_surface_variant="empty"
settings_capture_variant="profile"
settings_apns_permission_state=""
settings_apns_registration_state=""
screenshot_auth_enabled="1"
recipe_covers_capture_fixture=""
expected_accessibility_source=""
if [[ -n "$requested_route" ]]; then
  screenshot_route="$requested_route"
else
  if [[ "$unit_slug" == *recipe-editor* || "$unit_slug" == *recipe_editor* ]]; then
    screenshot_route="recipe-editor"
  elif [[ "$unit_slug" == *recipe-covers* || "$unit_slug" == *recipe_covers* ]]; then
    screenshot_route="recipe-covers"
  elif [[ "$unit_slug" == *recipe-detail* || "$unit_slug" == *recipe_detail* ]]; then
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
  elif [[ "$unit_slug" == *profile-graph* || "$unit_slug" == *profile_graph* ]]; then
    screenshot_route="profile-graph"
  elif [[ "$unit_slug" == *profile* ]]; then
    screenshot_route="profile"
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
  elif [[ "$unit_slug" == *unknown-link* || "$unit_slug" == *unknown_link* ]]; then
    screenshot_route="unknown-link"
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
expected_surface_variant=""
if [[ "$screenshot_route" == "shopping-list" ]]; then
  expected_surface_variant="$shopping_capture_variant"
elif [[ "$screenshot_route" == "capture" ]]; then
  expected_surface_variant="$capture_surface_variant"
fi
settings_capture_account_id="chef_settings_capture"
kitchen_capture_account_id="chef_kitchen_capture"
search_capture_account_id="chef_search_capture"
shopping_capture_account_id="chef_shopping_capture"
owner_capture_account_id="chef_ari"
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
proof_attempts="${SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS:-360}"
proof_sleep_seconds="${SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS:-0.5}"
ios_launch_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS:-30}"
ios_boot_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_BOOT_TIMEOUT_SECONDS:-90}"
ios_host_settle_seconds="${SPOONJOY_SCREENSHOT_IOS_HOST_SETTLE_SECONDS:-5}"
ios_foreground_probe_timeout_seconds="${SPOONJOY_SCREENSHOT_IOS_FOREGROUND_PROBE_TIMEOUT_SECONDS:-15}"
macos_launch_timeout_seconds="${SPOONJOY_SCREENSHOT_MACOS_LAUNCH_TIMEOUT_SECONDS:-30}"
cleanup_timeout_seconds="${SPOONJOY_SCREENSHOT_CLEANUP_TIMEOUT_SECONDS:-5}"
ios_smoke_attempts="${SPOONJOY_SCREENSHOT_IOS_SMOKE_ATTEMPTS:-2}"
ios_capture_attempts="${SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS:-2}"
ios_visual_evidence_failure_seen=false
ios_evidence_publication_failure_seen=false
ios_capture_generation_committed=false
expected_recorded_route="$screenshot_route"
deep_link_path="$screenshot_route"
deep_link_url=""
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
  recipe-editor)
    capture_account_id="$owner_capture_account_id"
    expected_recorded_route="recipe-editor:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta/edit"
    macos_window_title="Recipes"
    ;;
  recipe-covers)
    capture_account_id="$owner_capture_account_id"
    recipe_covers_capture_fixture="action-states"
    expected_recorded_route="recipe-covers:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta/covers"
    macos_window_title="Recipes"
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
  profile)
    capture_account_id="$owner_capture_account_id"
    expected_recorded_route="profile:ari"
    deep_link_path="users/ari"
    macos_window_title="Profile"
    ;;
  profile-graph)
    capture_account_id="$owner_capture_account_id"
    expected_recorded_route="profile-graph:ari:kitchen-visitors:1"
    deep_link_path="users/ari/kitchen-visitors?page=1"
    macos_window_title="Kitchen Visitors"
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
        expected_search_scope="all"
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
  unknown-link)
    capture_account_id="$owner_capture_account_id"
    expected_recorded_route="unknown-link"
    deep_link_path="unknown"
    deep_link_url="spoonjoy://unknown"
    macos_window_title="Unknown Link"
    ;;
  *)
    printf 'Unsupported screenshot route: %s\n' "$screenshot_route" >&2
    exit 2
    ;;
esac
deep_link_url="${deep_link_url:-spoonjoy://$deep_link_path}"

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
    source_path, output_path, ios_accessibility_proof, ios_ax_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof, ios_observed, ios_ax_observed, ipad_observed, macos_observed = ARGV
    blocker = JSON.parse(File.read(source_path))
    manifest = {
      "blocked" => true,
      "capability" => blocker.fetch("capability"),
      "sourceBlockerPath" => source_path,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/ios-mobile-accessibility.png",
        "screenshots/ios-tablet.png",
        "screenshots/ios-mobile-deep-scroll.png",
        "screenshots/ios-mobile-accessibility-deep-scroll.png",
        "screenshots/ios-tablet-deep-scroll.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        ios_accessibility_proof,
        ios_ax_accessibility_proof,
        ipad_accessibility_proof,
        macos_accessibility_proof,
        ios_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json"),
        ios_ax_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json"),
        ipad_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json"),
        ios_observed,
        ios_ax_observed,
        ipad_observed,
        macos_observed
      ],
      "reason" => blocker.fetch("reason"),
      "ownerAction" => blocker.fetch("ownerAction")
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$source_blocker_path" "$design_review_blocked" "$accessibility_proof_ios_rel" "$accessibility_proof_ios_ax_rel" "$accessibility_proof_ipad_rel" "$accessibility_proof_macos_rel" "$observed_accessibility_ios_rel" "$observed_accessibility_ios_ax_rel" "$observed_accessibility_ipad_rel" "$observed_accessibility_macos_rel"
  rm -f "$ios_screenshot" "$ios_accessibility_screenshot" "$ios_tablet_screenshot" "$macos_screenshot"
  rm -f "$ios_deep_scroll_screenshot" "$ios_accessibility_deep_scroll_screenshot" "$ios_tablet_deep_scroll_screenshot"
  rm -f "$accessibility_proof_ios" "$accessibility_proof_ios_ax" "$accessibility_proof_ipad" "$accessibility_proof_macos"
  rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_ios_ax_abs" "$accessibility_proof_ipad_abs" "$accessibility_proof_macos_abs"
  rm -f "$accessibility_proof_ios_deep_scroll" "$accessibility_proof_ios_ax_deep_scroll" "$accessibility_proof_ipad_deep_scroll"
  rm -f "$accessibility_proof_ios_deep_scroll_abs" "$accessibility_proof_ios_ax_deep_scroll_abs" "$accessibility_proof_ipad_deep_scroll_abs"
  rm -f "$observed_accessibility_ios" "$observed_accessibility_ios_ax" "$observed_accessibility_ipad" "$observed_accessibility_macos"
  rm -f "$observed_accessibility_ios_abs" "$observed_accessibility_ios_ax_abs" "$observed_accessibility_ipad_abs" "$observed_accessibility_macos_abs"
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

    def terminate_process_group():
        if process.poll() is not None:
            return
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        deadline = time.monotonic() + 0.2
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.01)
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        if process.poll() is None:
            process.wait()

    def forward_parent_signal(signum, _frame):
        terminate_process_group()
        sys.exit(128 + signum)

    for forwarded_signal in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(forwarded_signal, forward_parent_signal)

    try:
        exit_code = process.wait(timeout=timeout_seconds)
        output.write(f"\n{label} exited with code {exit_code}\n".encode())
        sys.exit(exit_code)
    except subprocess.TimeoutExpired:
        output.write(f"\n{label} timed out after {timeout_seconds} seconds\n".encode())
        terminate_process_group()
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
  ruby -rjson -rdigest -e '
    output_path, route, settings_focus, ios_proof, ipad_proof, macos_proof, ios_accessibility_proof, ios_ax_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof, ios_observed, ios_ax_observed, ipad_observed, macos_observed, shopping_variant, search_capture_variant, capture_surface_variant, settings_capture_variant, settings_apns_permission_state, settings_apns_registration_state, expected_search_query, expected_search_scope, expected_search_route_identifier, screenshot_auth_enabled = ARGV
    manifest = {
      "screenshotRoute" => route,
      "accessibilityProofArtifacts" => [ios_accessibility_proof, ios_ax_accessibility_proof, ipad_accessibility_proof, macos_accessibility_proof],
      "observedAccessibilityEvidenceArtifacts" => [ios_observed, ios_ax_observed, ipad_observed, macos_observed],
      "accessibilityContentSizeScreenshot" => "screenshots/ios-mobile-accessibility.png",
      "blockers" => []
    }
    artifact_root = File.dirname(output_path)
    manifest["screenshotArtifacts"] = {
      "iosMobile" => "screenshots/ios-mobile.png",
      "iosAccessibility" => "screenshots/ios-mobile-accessibility.png",
      "iosTablet" => "screenshots/ios-tablet.png",
      "macosDesktop" => "screenshots/macos-desktop.png"
    }.transform_values do |relative_path|
      absolute_path = File.join(artifact_root, relative_path)
      abort("missing screenshot artifact #{relative_path}") unless File.file?(absolute_path) && File.size(absolute_path).positive?
      {
        "path" => relative_path,
        "bytes" => File.size(absolute_path),
        "sha256" => Digest::SHA256.file(absolute_path).hexdigest
      }
    end
    if [
      "kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers",
      "cook-mode", "cook-log", "cookbooks", "cookbook-detail", "shopping-list", "chefs",
      "profile", "profile-graph", "search", "capture", "settings"
    ].include?(route)
      manifest["deepScrollAccessibilityProofArtifacts"] = [
        ios_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json"),
        ios_ax_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json"),
        ipad_accessibility_proof.sub(/\.json\z/, "-deep-scroll.json")
      ]
      manifest["deepScrollScreenshotArtifacts"] = {
        "iosMobile" => "screenshots/ios-mobile-deep-scroll.png",
        "iosAccessibility" => "screenshots/ios-mobile-accessibility-deep-scroll.png",
        "iosTablet" => "screenshots/ios-tablet-deep-scroll.png"
      }.transform_values do |relative_path|
        absolute_path = File.join(artifact_root, relative_path)
        abort("missing deep-scroll screenshot artifact #{relative_path}") unless File.file?(absolute_path) && File.size(absolute_path).positive?
        {
          "path" => relative_path,
          "bytes" => File.size(absolute_path),
          "sha256" => Digest::SHA256.file(absolute_path).hexdigest
        }
      end
    end
    if route == "settings"
      manifest["settingsCaptureVariant"] = settings_capture_variant
      manifest["settingsScreenshotAuth"] = screenshot_auth_enabled
      manifest["settingsVisualFocus"] = settings_focus
      manifest["settingsSignedOutSurface"] = settings_focus == "signed-out"
      manifest["settingsSignedOutHandoffSurface"] = settings_focus == "signed-out"
      manifest["settingsSurfaceProofArtifacts"] = [ios_proof, ipad_proof, macos_proof]
      if settings_focus == "notifications"
        manifest["settingsAPNsPermissionState"] = settings_apns_permission_state.empty? ? "not-determined" : settings_apns_permission_state
        manifest["settingsAPNsRegistrationState"] = settings_apns_registration_state.empty? ? "registered" : settings_apns_registration_state
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
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
    elsif route == "recipe-detail"
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "recipe-editor"
      manifest["recipeSeedAccountID"] = "chef_ari"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "recipe-covers"
      manifest["recipeSeedAccountID"] = "chef_ari"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
      manifest["recipeCoverControlsFixture"] = "action-states"
      manifest["renderedSurfaceAnchors"] = ["stagedPhotoActions", "coverMutationActions"]
    elsif route == "cook-log"
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
      manifest["renderedSurfaceAnchors"] = ["cookLogForm", "cookLogPhotoSlot", "cookLogActionBar"]
    elsif route == "cook-mode"
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "cookbooks"
      manifest["cookbookSeedAccountID"] = "chef_kitchen_capture"
      manifest["renderedSurfaceAnchors"] = ["cookbookShelfStrip", "cookbookLibrarySpread"]
    elsif route == "cookbook-detail"
      manifest["cookbookSeedAccountID"] = "chef_kitchen_capture"
      manifest["cookbookID"] = "cookbook_weeknights"
      manifest["renderedSurfaceAnchors"] = ["cookbookContentsIndex", "cookbookOwnerToolsDisclosure"]
    elsif route == "profile"
      manifest["profileSeedAccountID"] = "chef_ari"
      manifest["profileIdentifier"] = "ari"
    elsif route == "profile-graph"
      manifest["profileSeedAccountID"] = "chef_ari"
      manifest["profileIdentifier"] = "ari"
      manifest["profileGraphDirection"] = "kitchen-visitors"
      manifest["profileGraphPage"] = 1
    elsif route == "shopping-list"
      manifest["shoppingSeedAccountID"] = "chef_shopping_capture"
      manifest["shoppingListVariant"] = shopping_variant
    elsif route == "capture"
      manifest["captureSurfaceVariant"] = capture_surface_variant
      manifest["captureSeedAccountID"] = capture_surface_variant == "signed-out" ? "signed-out" : "chef_kitchen_capture"
      manifest["captureScreenshotAuth"] = screenshot_auth_enabled
      manifest["captureSignedOutSurface"] = capture_surface_variant == "signed-out"
    elsif route == "kitchen"
      manifest["kitchenSeedAccountID"] = "chef_kitchen_capture"
    end
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$design_review" "$screenshot_route" "$settings_capture_focus" "$ios_proof_artifact_rel" "$ipad_proof_artifact_rel" "$macos_proof_artifact_rel" "$accessibility_proof_ios_rel" "$accessibility_proof_ios_ax_rel" "$accessibility_proof_ipad_rel" "$accessibility_proof_macos_rel" "$observed_accessibility_ios_rel" "$observed_accessibility_ios_ax_rel" "$observed_accessibility_ipad_rel" "$observed_accessibility_macos_rel" "$shopping_capture_variant" "$search_capture_variant" "$capture_surface_variant" "$settings_capture_variant" "$settings_apns_permission_state" "$settings_apns_registration_state" "$expected_search_query" "$expected_search_scope" "$expected_search_route_identifier" "$screenshot_auth_enabled"
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

atomic_fixture_write() {
  local target_path="$1"
  local writer="$2"
  shift 2
  local temporary_path="${target_path}.tmp.$$.$RANDOM"
  mkdir -p "$(dirname "$target_path")"
  if "$writer" "$temporary_path" "$@"; then
    mv -f "$temporary_path" "$target_path"
  else
    rm -f "$temporary_path"
    return 1
  fi
}

install_fixture_cover() {
  local destination_directory="$1"
  local destination_path="$destination_directory/lemon-pantry-pasta.png"
  mkdir -p "$destination_directory"
  cp "$fixture_cover_source" "$destination_path"
  printf '%s\n' "$destination_path"
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
  local fixture_cover_path="$3"
  ruby -rjson -rfileutils -e '
    path, route, account_id, shopping_variant, capture_variant, fixture_cover_path = ARGV
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
    if ["kitchen", "recipe-detail", "recipe-editor", "recipe-covers", "profile", "profile-graph"].include?(route)
      recipes = recipes.map do |recipe|
        next recipe unless recipe.fetch("id") == "recipe_lemon_pantry_pasta"

        recipe.merge(
          "coverImageUrl" => "file://#{fixture_cover_path}",
          "coverProvenanceLabel" => nil,
          "coverSourceType" => "chef-upload",
          "coverVariant" => "image"
        )
      end
    end
    if ["profile", "profile-graph"].include?(route)
      recipes = recipes.map do |recipe|
        next recipe unless recipe.fetch("id") == "recipe_lemon_pantry_pasta"

        recipe.merge("recentSpoons" => [{
          "id" => "spoon_jules_lemon",
          "chefId" => "chef_jules",
          "recipeId" => "recipe_lemon_pantry_pasta",
          "cookedAt" => "2026-06-02T18:30:00.000Z",
          "photoUrl" => nil,
          "note" => "More lemon next time.",
          "nextTime" => "Add parsley.",
          "deletedAt" => nil,
          "createdAt" => "2026-06-02T18:30:00.000Z",
          "updatedAt" => "2026-06-02T18:31:00.000Z",
          "chef" => { "id" => "chef_jules", "username" => "jules" }
        }])
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
    records << {
      "kind" => "profile",
      "resourceID" => account_id,
      "payload" => {
        "id" => account_id,
        "username" => "ari",
        "photoUrl" => nil,
        "joinedLabel" => "Joined Spoonjoy",
        "href" => "/users/ari",
        "canonicalUrl" => "https://spoonjoy.app/users/ari"
      },
      "serverRevision" => nil
    }
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
  ' "$path" "$route" "$capture_account_id" "$shopping_capture_variant" "$capture_surface_variant" "$fixture_cover_path"
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
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_STATE_DIRECTORY="$ios_state_directory" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID="$capture_account_id" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SETTINGS_FOCUS="$settings_capture_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS="$search_capture_disable_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS="$recipe_detail_focus" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE="$settings_apns_permission_state" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE="$settings_apns_registration_state" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID="$shopping_conflict_launch_client_mutation_id" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_EXPECTED_ROUTE="$screenshot_route" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT="$expected_surface_variant" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RUN_NONCE="$screenshot_run_nonce" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE="$recipe_covers_capture_fixture" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
      SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$ios_accessibility_proof_runtime_path" \
      xcrun simctl launch --stdout="$ios_app_stdout_log" --stderr="$ios_app_stderr_log" "$udid" app.spoonjoy
}

open_macos_app() {
  screenshot_run_nonce="$(uuidgen | tr '[:upper:]' '[:lower:]')"
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
      SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT="$expected_surface_variant" \
      SPOONJOY_SCREENSHOT_RUN_NONCE="$screenshot_run_nonce" \
      SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE="$recipe_covers_capture_fixture" \
      SPOONJOY_SCREENSHOT_STATE_DIRECTORY="$macos_state_directory" \
      SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
      SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$accessibility_proof_macos_abs" \
      SPOONJOY_API_BASE_URL="https://spoonjoy.app" \
      open -n -F "$macos_app"
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
      SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT \
      SPOONJOY_SCREENSHOT_RUN_NONCE \
      SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE \
      SPOONJOY_SCREENSHOT_STATE_DIRECTORY \
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
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT "$expected_surface_variant"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_RUN_NONCE "$screenshot_run_nonce"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE "$recipe_covers_capture_fixture"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_STATE_DIRECTORY "$macos_state_directory"
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
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_STATE_DIRECTORY >/dev/null 2>&1 || true
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

latest_front_display_event() {
  ruby -e '
    path = ARGV.fetch(0)
    events = File.readlines(path, chomp: true).select { |line| line.include?("Front display did change:") }
    exit(1) if events.empty?
    puts events.last
  ' "$1"
}

front_display_event_before_barrier() {
  ruby -e '
    path, barrier = ARGV
    lines = File.readlines(path, chomp: true)
    barrier_index = lines.index { |line| line.include?(barrier) }
    exit(1) unless barrier_index
    events = lines.take(barrier_index).select { |line| line.include?("Front display did change:") }
    exit(1) if events.empty?
    puts events.last
  ' "$1" "$2"
}

ios_foreground_interval_is_spoonjoy() {
  ruby -e '
    path, start_barrier, end_barrier = ARGV
    lines = File.readlines(path, chomp: true)
    start_index = lines.index { |line| line.include?(start_barrier) }
    exit(1) unless start_index
    end_index = lines.each_index.find { |index| index > start_index && lines[index].include?(end_barrier) }
    exit(1) unless end_index
    before_start = lines.take(start_index).reverse.find { |line| line.include?("Front display did change:") }
    exit(1) unless before_start&.include?("app.spoonjoy")
    interval_events = lines[(start_index + 1)...end_index].select { |line| line.include?("Front display did change:") }
    exit(1) if interval_events.any? { |line| !line.include?("app.spoonjoy") }
  ' "$1" "$2" "$3"
}

wait_for_ios_foreground() {
  local foreground_log="$1"
  local foreground_stream_pid="$2"
  local deadline=$((SECONDS + ios_foreground_probe_timeout_seconds))
  local latest_event

  while [[ "$SECONDS" -lt "$deadline" ]]; do
    kill -0 "$foreground_stream_pid" >/dev/null 2>&1 || return 1
    latest_event="$(latest_front_display_event "$foreground_log" || true)"
    if [[ "$latest_event" == *"app.spoonjoy"* ]]; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

ios_foreground_is_spoonjoy() {
  local foreground_log="$1"
  local foreground_stream_pid="$2"
  local latest_event
  kill -0 "$foreground_stream_pid" >/dev/null 2>&1 || return 1
  latest_event="$(latest_front_display_event "$foreground_log" || true)"
  printf 'Latest simulator front display event: %s\n' "${latest_event:-<none>}" >> "$capture_log"
  [[ "$latest_event" == *"app.spoonjoy"* ]]
}

wait_for_ios_foreground_barrier() {
  local foreground_log="$1"
  local foreground_stream_pid="$2"
  local barrier_token="$3"
  local deadline=$((SECONDS + ios_foreground_probe_timeout_seconds))

  while [[ "$SECONDS" -lt "$deadline" ]]; do
    kill -0 "$foreground_stream_pid" >/dev/null 2>&1 || return 1
    grep -Fq "$barrier_token" "$foreground_log" && return 0
    sleep 0.1
  done
  return 1
}

emit_ios_foreground_barrier() {
  local udid="$1"
  local foreground_log="$2"
  local foreground_stream_pid="$3"
  local barrier_token="$4"
  local barrier_emit_log="$5"
  : > "$barrier_emit_log"
  if ! run_with_timeout "simulator foreground barrier timeout" "$ios_foreground_probe_timeout_seconds" "$barrier_emit_log" \
    xcrun simctl spawn "$udid" log emit \
      --subsystem app.spoonjoy.screenshot-proof \
      --category foreground-barrier \
      --public "$barrier_token"; then
    cat "$barrier_emit_log" >> "$capture_log"
    return 1
  fi
  cat "$barrier_emit_log" >> "$capture_log"
  wait_for_ios_foreground_barrier "$foreground_log" "$foreground_stream_pid" "$barrier_token"
}

start_ios_foreground_stream() {
  local udid="$1"
  local foreground_log="$2"
  local child_pid_file="${foreground_log}.child-pid"
  : > "$foreground_log"
  rm -f "$child_pid_file"
  printf 'Starting simulator foreground event stream for %s\n' "$udid" >> "$capture_log"
  python3 - "$child_pid_file" spoonjoy-foreground-stream-supervisor-v1 xcrun simctl spawn "$udid" log stream --style compact \
    --predicate '(process == "SpringBoard" AND eventMessage CONTAINS[c] "Front display did change") OR (subsystem == "app.spoonjoy.screenshot-proof" AND category == "foreground-barrier")' \
    > "$foreground_log" 2>&1 <<'PY' &
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

child = None
forwarded_exit_signal = None
termination_started_at = None
kill_escalated = False


def signal_child(signum):
    if child is None or child.poll() is not None:
        return
    try:
        os.killpg(child.pid, signum)
    except (ProcessLookupError, PermissionError):
        pass


def forward_signal(signum, _frame):
    global forwarded_exit_signal, termination_started_at
    if forwarded_exit_signal is None:
        forwarded_exit_signal = signum
        termination_started_at = time.monotonic()
    signal_child(signal.SIGTERM)


for forwarded_signal in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(forwarded_signal, forward_signal)

child_pid_file = Path(sys.argv[1])
if sys.argv[2] != "spoonjoy-foreground-stream-supervisor-v1":
    raise SystemExit("missing foreground stream supervisor marker")
try:
    child = subprocess.Popen(sys.argv[3:], start_new_session=True)
    child_pid_file.write_text(f"{child.pid}\n", encoding="utf-8")
    while child.poll() is None:
        if (
            forwarded_exit_signal is not None
            and termination_started_at is not None
            and not kill_escalated
            and time.monotonic() - termination_started_at >= 1.5
        ):
            signal_child(signal.SIGKILL)
            kill_escalated = True
        time.sleep(0.05)
    if forwarded_exit_signal is not None:
        raise SystemExit(128 + forwarded_exit_signal)
    raise SystemExit(child.returncode)
finally:
    signal_child(signal.SIGKILL)
PY
  ios_foreground_stream_pid=$!
}

stop_ios_foreground_stream() {
  local foreground_stream_pid="$1"
  local foreground_log="$2"
  local child_pid_file="${foreground_log}.child-pid"
  local foreground_stream_child_pid=""
  if [[ -s "$child_pid_file" ]]; then
    foreground_stream_child_pid="$(<"$child_pid_file")"
  fi
  if [[ -n "$foreground_stream_pid" ]]; then
    kill -TERM "$foreground_stream_pid" >/dev/null 2>&1 || true
    [[ -z "$foreground_stream_child_pid" ]] || kill -TERM -- "-$foreground_stream_child_pid" >/dev/null 2>&1 || true
    for _ in $(seq 1 40); do
      if ! kill -0 "$foreground_stream_pid" >/dev/null 2>&1 \
        && { [[ -z "$foreground_stream_child_pid" ]] || ! kill -0 -- "-$foreground_stream_child_pid" >/dev/null 2>&1; }; then
        break
      fi
      sleep 0.05
    done
    kill -KILL "$foreground_stream_pid" >/dev/null 2>&1 || true
    [[ -z "$foreground_stream_child_pid" ]] || kill -KILL -- "-$foreground_stream_child_pid" >/dev/null 2>&1 || true
  fi
  [[ -z "$foreground_stream_pid" ]] || wait "$foreground_stream_pid" >/dev/null 2>&1 || true
  cat "$foreground_log" >> "$capture_log" 2>/dev/null || true
  rm -f "$foreground_log" "$child_pid_file"
}

terminate_ios_app_and_confirm_stopped() {
  local udid="$1"
  local terminate_log
  local terminate_status
  local probe_log
  local probe_status
  terminate_log="$(mktemp)"
  set +e
  run_with_timeout "simulator app termination timeout" "$ios_launch_timeout_seconds" "$terminate_log" \
    xcrun simctl terminate "$udid" app.spoonjoy
  terminate_status=$?
  set -e
  if [[ "$terminate_status" -ne 0 ]]; then
    if ! grep -qi "found nothing to terminate" "$terminate_log"; then
      cat "$terminate_log" >> "$capture_log"
      rm -f "$terminate_log"
      return 1
    fi
  fi
  rm -f "$terminate_log"

  probe_log="$(mktemp)"
  for _ in $(seq 1 30); do
    : > "$probe_log"
    set +e
    run_with_timeout "simulator stopped-process probe timeout" "$cleanup_timeout_seconds" "$probe_log" \
      xcrun simctl spawn "$udid" /bin/sh -c \
      '/usr/bin/pgrep -x Spoonjoy >/dev/null; status=$?; printf "spoonjoy-stop-probe-status=%s\n" "$status"; exit "$status"'
    probe_status=$?
    set -e
    if [[ "$probe_status" -eq 1 ]] && grep -q '^spoonjoy-stop-probe-status=1$' "$probe_log"; then
      rm -f "$probe_log"
      return 0
    fi
    if [[ "$probe_status" -ne 0 ]]; then
      cat "$probe_log" >> "$capture_log"
      rm -f "$probe_log"
      return 1
    fi
    sleep 0.1
  done
  rm -f "$probe_log"
  printf 'Spoonjoy remained running after simulator termination on %s\n' "$udid" >> "$capture_log"
  return 1
}

terminate_macos_app_and_confirm_stopped() {
  run_cleanup_command "quit Spoonjoy before fixture write" osascript -e 'tell application id "app.spoonjoy.mac" to quit' || true
  run_cleanup_command "kill Spoonjoy before fixture write" pkill -x Spoonjoy || true
  for _ in $(seq 1 30); do
    if ! pgrep -x Spoonjoy >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  printf 'Spoonjoy remained running after macOS termination\n' >> "$capture_log"
  return 1
}

capture_ios_foreground_route() (
  local udid="$1"
  local expected_platform="$2"
  local screenshot_output="$3"
  local surface_proof_output="$4"
  local accessibility_proof_output="$5"
  local foreground_stream_log
  local ios_foreground_stream_pid=""
  local barrier_emit_log
  local pre_barrier_token
  local post_barrier_token
  local barrier_front_event
  foreground_stream_log="$(mktemp)"
  barrier_emit_log="$(mktemp)"
  trap 'rm -f "$barrier_emit_log"; stop_ios_foreground_stream "$ios_foreground_stream_pid" "$foreground_stream_log"' EXIT
  start_ios_foreground_stream "$udid" "$foreground_stream_log"
  sleep 0.2
  if ! ios_launch_app "$udid"; then
    printf 'simulator launch command timed out or failed for iOS route %s; requiring observed foreground proof\n' "$screenshot_route" >> "$capture_log"
  fi
  wait_for_ios_foreground "$foreground_stream_log" "$ios_foreground_stream_pid" || return 1
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
  if ! wait_for_accessibility_proof "$ios_accessibility_proof_runtime_path" "$screenshot_route" "$expected_platform" "$accessibility_proof_output" "$expected_accessibility_source" "$expected_surface_variant"; then
    log_accessibility_proof_diagnostic "$ios_accessibility_proof_runtime_path" "$screenshot_route" "$expected_platform" "$expected_platform" "$expected_surface_variant"
    printf 'Spoonjoy did not write the expected %s accessibility proof for %s\n' "$expected_platform" "$screenshot_route" >> "$capture_log"
    return 1
  fi
  if ! ios_foreground_is_spoonjoy "$foreground_stream_log" "$ios_foreground_stream_pid"; then
    printf 'Spoonjoy stopped being the front display before screenshot capture\n' >> "$capture_log"
    return 1
  fi
  pre_barrier_token="spoonjoy-foreground-barrier-${unit_slug}-${expected_platform}-pre-$$-${RANDOM}"
  if ! emit_ios_foreground_barrier "$udid" "$foreground_stream_log" "$ios_foreground_stream_pid" "$pre_barrier_token" "$barrier_emit_log"; then
    printf 'Spoonjoy foreground event barrier could not be established before screenshot capture\n' >> "$capture_log"
    return 1
  fi
  barrier_front_event="$(front_display_event_before_barrier "$foreground_stream_log" "$pre_barrier_token" || true)"
  if [[ "$barrier_front_event" != *"app.spoonjoy"* ]]; then
    printf 'Spoonjoy stopped being the front display before screenshot capture barrier\n' >> "$capture_log"
    return 1
  fi
  xcrun simctl io "$udid" screenshot "$screenshot_output" >> "$capture_log" 2>&1
  post_barrier_token="spoonjoy-foreground-barrier-${unit_slug}-${expected_platform}-post-$$-${RANDOM}"
  if ! emit_ios_foreground_barrier "$udid" "$foreground_stream_log" "$ios_foreground_stream_pid" "$post_barrier_token" "$barrier_emit_log"; then
    printf 'Spoonjoy foreground event barrier could not be emitted after screenshot capture\n' >> "$capture_log"
    rm -f "$screenshot_output"
    return 1
  fi
  barrier_front_event="$(front_display_event_before_barrier "$foreground_stream_log" "$post_barrier_token" || true)"
  printf 'Latest simulator front display event before capture barrier: %s\n' "${barrier_front_event:-<none>}" >> "$capture_log"
  if ! ios_foreground_interval_is_spoonjoy "$foreground_stream_log" "$pre_barrier_token" "$post_barrier_token"; then
    printf 'Spoonjoy stopped being the front display during screenshot capture\n' >> "$capture_log"
    rm -f "$screenshot_output"
    return 1
  fi
  [[ -f "$screenshot_output" && -s "$screenshot_output" ]]
  validate_ios_screenshot "$screenshot_output" >> "$capture_log" 2>&1
)

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
  local expected_surface_variant="${6:-}"
  for _ in $(seq 1 "$proof_attempts"); do
    if ruby -rjson -rfileutils -e '
      path, expected_route, expected_platform, output_path, source_override, expected_surface_variant = ARGV
      proof = JSON.parse(File.read(path))
      expected_source = {
        "kitchen" => "KitchenView",
        "recipes" => "RecipesView",
        "saved-recipes" => "SavedRecipesView",
        "cookbooks" => "CookbooksView",
        "cookbook-detail" => "CookbookDetailView",
        "capture" => "CaptureDraftView",
        "search" => "SearchView",
        "settings" => "SettingsView",
        "recipe-detail" => "RecipeDetailView",
        "recipe-editor" => "RecipeEditorView",
        "recipe-covers" => "RecipeCoverControlsView",
        "cook-log" => "SpoonCookLogView",
        "cook-mode" => "CookModeView",
        "shopping-list" => "ShoppingListView",
        "chefs" => "ChefsView",
        "profile" => "ProfileView",
        "profile-graph" => "ProfileGraphList",
        "unknown-link" => "ShellPlaceholderView"
      }.fetch(expected_route)
      expected_source = source_override unless source_override.empty?
      expected_bundle = expected_platform == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy"
      abort("platform mismatch") unless proof.fetch("platform") == expected_platform
      abort("route mismatch") unless proof.fetch("route") == expected_route
      abort("source mismatch") unless proof.fetch("source") == expected_source
      abort("emitter mismatch") unless proof.fetch("emittedBy") == "SpoonjoyApp"
      abort("bundle mismatch") unless proof.fetch("bundleIdentifier") == expected_bundle
      unless expected_surface_variant.empty?
        abort("surface variant mismatch") unless proof["observedSurfaceVariant"] == expected_surface_variant
      end
      if expected_route == "recipe-covers"
        abort("Photo Studio action fixture mismatch") unless proof.dig("launchEnvironmentProof", "screenshotRecipeCoversFixture") == "action-states"
      end
      if expected_route == "shopping-list" && expected_surface_variant == "offline-queued"
        surface_state = proof["observedSurfaceState"]
        abort("queued shopping state mismatch") unless surface_state.is_a?(Hash) &&
          surface_state["statusOwner"] == "ShoppingListView" &&
          surface_state["connectivity"] == "offline" &&
          surface_state["visibleIndicator"] == "queuedWork" &&
          surface_state["queuedMutationCount"].is_a?(Integer) &&
          surface_state["queuedMutationCount"].positive?
      end
      legacy_fields = %w[
        dynamicType voiceOverLabels keyboardNavigation reduceMotion contrast
        kitchenTableHierarchy noOverlap minimumTargetSize textFits noTinyClusters
        routeEvidence offlineIndicatorProof
      ].select { |field| proof.key?(field) }
      abort("legacy self-attestation: #{legacy_fields.join(", ")}") unless legacy_fields.empty?
      observed_size = proof["observedDynamicTypeSize"]
      abort("dynamic type observation missing") unless observed_size.is_a?(String) && !observed_size.empty?
      abort("reduce motion observation missing") unless [true, false].include?(proof["observedReduceMotion"])
      state_proof = proof["screenshotStateSnapshotProof"]
      abort("screenshot state proof missing") unless state_proof.is_a?(Hash)
      abort("screenshot app state is unreadable") unless state_proof["stateDirectoryResolved"] == true &&
        state_proof["appSnapshotPresent"] == true &&
        state_proof["appSnapshotJSONReadable"] == true &&
        state_proof["syncSnapshotPresent"] == true &&
        state_proof["syncSnapshotJSONReadable"] == true
      readiness = proof["visualReadiness"]
      abort("visual readiness missing") unless readiness.is_a?(Hash)
      abort("visual route not settled") unless readiness["pendingMediaCount"] == 0 &&
        readiness["failedMediaCount"] == 0 &&
        readiness["blockingIndicatorCount"] == 0 &&
        readiness["isSettled"] == true
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, JSON.pretty_generate(proof) + "\n")
    ' "$proof_path" "$expected_route" "$expected_platform" "$output_path" "$source_override" "$expected_surface_variant" >/dev/null 2>&1; then
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
  local expected_surface_variant="${5:-}"
  if [[ -f "$proof_path" ]]; then
    ruby -rjson -e '
      path, expected_route, expected_platform, label, expected_surface_variant = ARGV
      proof = JSON.parse(File.read(path))
      summary = {
        "expectedRoute" => expected_route,
        "expectedPlatform" => expected_platform,
        "expectedSurfaceVariant" => expected_surface_variant,
        "actualRoute" => proof["route"],
        "actualPlatform" => proof["platform"],
        "actualObservedSurfaceVariant" => proof["observedSurfaceVariant"],
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
    ' "$proof_path" "$expected_route" "$expected_platform" "$label" "$expected_surface_variant" >> "$capture_log" 2>&1 || true
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
      fingerprint = proof.fetch("renderFingerprint")
      abort("#{platform} search render fingerprint must be an object") unless fingerprint.is_a?(Hash)
      rows = fingerprint.fetch("rows")
      abort("#{platform} search render fingerprint rows must be an array") unless rows.is_a?(Array)
      rows.each do |row|
        abort("#{platform} search render fingerprint row must be exact") unless row.is_a?(Hash) && row.keys.sort == ["id", "title", "type"]
      end
      data_source = fingerprint.fetch("dataSource")
      abort("#{platform} search render fingerprint data source must be exact") unless data_source.is_a?(Hash) && data_source.length == 1
      if search_capture_variant == "scoped-cookbooks"
        expected_rows = [{"type" => "cookbook", "id" => "cookbook-cookbook_weeknights", "title" => "Weeknights"}]
        abort("#{platform} scoped cookbook render fingerprint mismatch") unless rows == expected_rows
        abort("#{platform} scoped cookbook render must not include an empty state") unless fingerprint["emptyState"].nil?
      elsif search_capture_variant == "no-results"
        abort("#{platform} no-results render fingerprint must have no rows") unless rows.empty?
        expected_empty = {
          "scope" => "all",
          "title" => "No matches for \"kumquat\"",
          "message" => "No Spoonjoy results match \"kumquat\"."
        }
        abort("#{platform} no-results render fingerprint empty state mismatch") unless fingerprint.fetch("emptyState") == expected_empty
      end
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

prepare_ios_observer_products() {
  local configured_count=0
  [[ -n "$ios_app" ]] && configured_count=$((configured_count + 1))
  [[ -n "$ios_ui_test_runner" ]] && configured_count=$((configured_count + 1))
  [[ -n "$ios_xctestrun" ]] && configured_count=$((configured_count + 1))
  if [[ "$configured_count" -ne 0 && "$configured_count" -ne 3 ]]; then
    printf 'iOS screenshot observer requires app, UI-test runner, and xctestrun paths together\n' >> "$capture_log"
    return 1
  fi
  if [[ "$configured_count" -eq 0 ]]; then
    local observer_derived_data="$artifact_root/DerivedData-iOS-Observer"
    if ! run_with_timeout "iOS screenshot observer build timeout" "$ios_observer_timeout_seconds" "$capture_log" \
      xcodebuild \
        -project Spoonjoy.xcodeproj \
        -scheme "Spoonjoy iOS" \
        -configuration BootstrapDebug \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$observer_derived_data" \
        CODE_SIGNING_ALLOWED=NO \
        GCC_TREAT_WARNINGS_AS_ERRORS=YES \
        build-for-testing; then
      return 1
    fi
    ios_app="$observer_derived_data/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
    ios_ui_test_runner="$observer_derived_data/Build/Products/BootstrapDebug-iphonesimulator/SpoonjoyUITests-Runner.app"
    ios_xctestrun="$(find "$observer_derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -type f -print -quit)"
    export SPOONJOY_SCREENSHOT_IOS_APP_PATH="$ios_app"
  fi
  [[ -d "$ios_app" && -d "$ios_ui_test_runner" && -f "$ios_xctestrun" ]]
}

capture_ios_observed_accessibility() {
  local udid="$1"
  local expected_platform="$2"
  local output_path="$3"
  local content_size_category="${4:-large}"
  local screenshot_output="${5:-}"
  local readiness_proof_output="$6"
  local deep_scroll_screenshot_output=""
  local observer_suffix="$expected_platform"
  [[ "$content_size_category" == "large" ]] || observer_suffix="${expected_platform}-ax"
  case "$screenshot_route" in
    kitchen|recipes|saved-recipes|recipe-detail|recipe-editor|recipe-covers|cook-mode|cook-log|cookbooks|cookbook-detail|shopping-list|chefs|profile|profile-graph|search|capture|settings)
      if [[ "$expected_platform" == "ipad" ]]; then
        deep_scroll_screenshot_output="$ios_tablet_deep_scroll_screenshot"
      elif [[ "$content_size_category" == "large" ]]; then
        deep_scroll_screenshot_output="$ios_deep_scroll_screenshot"
      else
        deep_scroll_screenshot_output="$ios_accessibility_deep_scroll_screenshot"
      fi
      rm -f "$deep_scroll_screenshot_output"
      ;;
  esac
  local observer_work_root="$artifact_root/apple/${unit_slug}-${observer_suffix}-observer"
  local observer_environment_json="${observer_work_root}-environment.json"
  local capture_run_nonce
  capture_run_nonce="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  local observer_accessibility_proof_runtime_path="$ios_state_directory/native-accessibility-proof.observer-${observer_suffix}-${capture_run_nonce}.json"
  if [[ -s "$ios_accessibility_proof_runtime_path" ]]; then
    cp "$ios_accessibility_proof_runtime_path" "$observer_accessibility_proof_runtime_path"
  else
    rm -f "$observer_accessibility_proof_runtime_path"
  fi
  local inline_fixture_cover="${observer_work_root}-media-fixture.jpg"
  local inline_fixture_cover_url="file:///spoonjoy-screenshot-media/lemon-pantry-pasta.jpg"
  local inline_fixture_cover_base64
  local inline_sync_store="${observer_work_root}-sync-store.json"
  if ! sips \
    -s format jpeg \
    -s formatOptions 65 \
    --resampleWidth 800 \
    "$fixture_cover_source" \
    --out "$inline_fixture_cover" >> "$capture_log" 2>&1; then
    printf 'unable to prepare portable screenshot media fixture\n' >> "$capture_log"
    return 1
  fi
  inline_fixture_cover_base64="$(base64 < "$inline_fixture_cover" | tr -d '\r\n')"
  write_sync_store \
    "$inline_sync_store" \
    "$screenshot_route" \
    "/spoonjoy-screenshot-media/lemon-pantry-pasta.jpg"
  rm -f "$output_path"
  jq -n \
    --arg auth "$screenshot_auth_enabled" \
    --arg stateDirectory "$ios_state_directory" \
    --arg accountID "$capture_account_id" \
    --arg settingsFocus "$settings_capture_focus" \
    --arg disableSearchFocus "$search_capture_disable_focus" \
    --arg recipeDetailFocus "$recipe_detail_focus" \
    --arg apnsPermission "$settings_apns_permission_state" \
    --arg apnsRegistration "$settings_apns_registration_state" \
    --arg shoppingConflictID "$shopping_conflict_launch_client_mutation_id" \
    --arg route "$screenshot_route" \
    --arg surfaceVariant "$expected_surface_variant" \
    --arg captureRunNonce "$capture_run_nonce" \
    --arg recipeCoversFixture "$recipe_covers_capture_fixture" \
    --arg contentSizeCategory "$content_size_category" \
    --arg proofPath "$screenshot_proof_path" \
    --arg accessibilityProofPath "$observer_accessibility_proof_runtime_path" \
    --arg mediaFixtureURL "$inline_fixture_cover_url" \
    --arg mediaFixtureBase64 "$inline_fixture_cover_base64" \
    --rawfile appState "$ios_state_directory/native-app-state.json" \
    --rawfile durableCache "$ios_state_directory/native-durable-cache.json" \
    --rawfile syncStore "$inline_sync_store" \
    '{
      SPOONJOY_SCREENSHOT_AUTH: $auth,
      SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY: "1",
      SPOONJOY_SCREENSHOT_STATE_DIRECTORY: $stateDirectory,
      SPOONJOY_SCREENSHOT_ACCOUNT_ID: $accountID,
      SPOONJOY_SCREENSHOT_SETTINGS_FOCUS: $settingsFocus,
      SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS: $disableSearchFocus,
      SPOONJOY_SCREENSHOT_RECIPE_DETAIL_FOCUS: $recipeDetailFocus,
      SPOONJOY_SCREENSHOT_APNS_PERMISSION_STATE: $apnsPermission,
      SPOONJOY_SCREENSHOT_APNS_REGISTRATION_STATE: $apnsRegistration,
      SPOONJOY_SCREENSHOT_SHOPPING_CONFLICT_CLIENT_MUTATION_ID: $shoppingConflictID,
      SPOONJOY_SCREENSHOT_EXPECTED_ROUTE: $route,
      SPOONJOY_SCREENSHOT_EXPECTED_SURFACE_VARIANT: $surfaceVariant,
      SPOONJOY_SCREENSHOT_RUN_NONCE: $captureRunNonce,
      SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE: $recipeCoversFixture,
      SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY: $contentSizeCategory,
      SPOONJOY_SCREENSHOT_PROOF_PATH: $proofPath,
      SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH: $accessibilityProofPath,
      SPOONJOY_SCREENSHOT_INLINE_FIXTURES: "1",
      SPOONJOY_SCREENSHOT_APP_STATE_JSON: $appState,
      SPOONJOY_SCREENSHOT_DURABLE_CACHE_JSON: $durableCache,
      SPOONJOY_SCREENSHOT_SYNC_STORE_JSON: $syncStore,
      SPOONJOY_SCREENSHOT_MEDIA_FIXTURE_URL: $mediaFixtureURL,
      SPOONJOY_SCREENSHOT_MEDIA_FIXTURE_BASE64: $mediaFixtureBase64,
      SPOONJOY_API_BASE_URL: "https://spoonjoy.app"
    }' > "$observer_environment_json"
  local observer_status=0
  local -a observer_command=(python3 scripts/run-ios-screenshot-observer.py \
    --xctestrun "$ios_xctestrun" \
    --app "$ios_app" \
    --runner "$ios_ui_test_runner" \
    --destination-udid "$udid" \
    --platform "$expected_platform" \
    --route "$screenshot_route" \
    --output "$output_path" \
    --readiness-proof-output "$readiness_proof_output" \
    --work-root "$observer_work_root" \
    --log "$capture_log" \
    --timeout-seconds "$ios_observer_timeout_seconds" \
    --environment-json "$observer_environment_json")
  if [[ -n "$screenshot_output" ]]; then
    observer_command+=(--screenshot-output "$screenshot_output")
  fi
  if [[ -n "$deep_scroll_screenshot_output" ]]; then
    observer_command+=(--deep-scroll-screenshot-output "$deep_scroll_screenshot_output")
  fi
  "${observer_command[@]}" >> "$capture_log" 2>&1 || observer_status=$?
  rm -f "$observer_environment_json"
  if [[ "$observer_status" -ne 0 ]]; then
    return "$observer_status"
  fi
  if jq -e '
    ((.auditIssues // []) | length)
      + ((.geometryFindings // []) | length)
      + ((.deepScroll.findings // []) | length)
      + ((.deepScroll.auditIssues // []) | length)
      > 0
  ' "$output_path" >/dev/null 2>&1; then
    ios_visual_evidence_failure_seen=true
    return 65
  fi
  return "$observer_status"
}

refresh_ios_fixture_paths() {
  local udid="$1"
  local expected_platform="$2"
  local data_container
  local fixture_cover_path
  if ! data_container="$(resolve_ios_data_container "$udid")"; then
    printf 'unable to refresh simulator app data container for app.spoonjoy on %s\n' "$udid" >> "$capture_log"
    return 1
  fi
  local ios_app_dir="$data_container/Library/Application Support/Spoonjoy"
  ios_state_directory="$ios_app_dir/screenshot-routes/${unit_slug}-${expected_platform}"
  rm -f "$ios_state_directory"/native-accessibility-proof.observer-*.json
  fixture_cover_path="$(install_fixture_cover "$ios_state_directory")"
  screenshot_proof_path="$ios_state_directory/native-screenshot-proof.json"
  ios_accessibility_proof_runtime_path="$ios_state_directory/native-accessibility-proof.json"
  atomic_fixture_write "$ios_state_directory/native-app-state.json" write_app_state "$expected_recorded_route"
  atomic_fixture_write "$ios_state_directory/native-durable-cache.json" write_cache_state "$screenshot_route"
  atomic_fixture_write "$ios_state_directory/native-sync-store.json" write_sync_store "$screenshot_route" "$fixture_cover_path"
}

capture_ios_app() {
  local udid="$1"
  local expected_platform="$2"
  local screenshot_output="$3"
  local surface_proof_output="$4"
  local accessibility_proof_output="$5"
  local observed_accessibility_output="$6"
  local data_container
  local bootstatus_log
  bootstatus_log="$(mktemp)"
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
  if ! terminate_ios_app_and_confirm_stopped "$udid"; then
    return 1
  fi
  screenshot_run_nonce="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  refresh_ios_fixture_paths "$udid" "$expected_platform" || return 1
  rm -f "$screenshot_proof_path"
  rm -f "$ios_accessibility_proof_runtime_path"
  rm -f "$ios_state_directory/debug-auth-session.json"
  xcrun simctl ui "$udid" content_size large >> "$capture_log" 2>&1 || return 1
  capture_ios_foreground_route "$udid" "$expected_platform" "$screenshot_output" "$surface_proof_output" "$accessibility_proof_output" || return 1
  if ! capture_ios_observed_accessibility \
    "$udid" \
    "$expected_platform" \
    "$observed_accessibility_output" \
    "large" \
    "$screenshot_output" \
    "$accessibility_proof_output"; then
    return 1
  fi
  if [[ "$expected_platform" == "ios" ]]; then
    terminate_ios_app_and_confirm_stopped "$udid" || return 1
    refresh_ios_fixture_paths "$udid" "$expected_platform" || return 1
    xcrun simctl ui "$udid" content_size accessibility-extra-extra-extra-large >> "$capture_log" 2>&1 || return 1
    if ! capture_ios_observed_accessibility \
      "$udid" \
      "$expected_platform" \
      "$observed_accessibility_ios_ax_abs" \
      "accessibility-extra-extra-extra-large" \
      "$ios_accessibility_screenshot" \
      "$accessibility_proof_ios_ax_abs"; then
      return 1
    fi
    xcrun simctl ui "$udid" content_size large >> "$capture_log" 2>&1 || return 1
  fi
}

publish_ios_capture_artifact() {
  local staged_path="$1"
  local final_path="$2"
  if [[ ! -s "$staged_path" ]]; then
    printf 'staged iOS capture artifact is missing or empty: %s\n' "$staged_path" >> "$capture_log"
    ios_evidence_publication_failure_seen=true
    return 1
  fi
  mkdir -p "$(dirname "$final_path")"
  if ! mv -f "$staged_path" "$final_path"; then
    ios_evidence_publication_failure_seen=true
    return 1
  fi
}

require_ios_capture_artifact() {
  local staged_path="$1"
  if [[ ! -s "$staged_path" ]]; then
    printf 'staged iOS capture artifact is missing or empty: %s\n' "$staged_path" >> "$capture_log"
    ios_evidence_publication_failure_seen=true
    return 1
  fi
}

cleanup_uncommitted_ios_generation() {
  if [[ "$ios_capture_generation_committed" == true ]]; then
    return 0
  fi
  rm -f "$ios_screenshot" "$ios_accessibility_screenshot" "$ios_tablet_screenshot"
  rm -f "$ios_deep_scroll_screenshot" "$ios_accessibility_deep_scroll_screenshot" "$ios_tablet_deep_scroll_screenshot"
  rm -f "$ios_proof_artifact" "$ipad_proof_artifact"
  rm -f "$accessibility_proof_ios" "$accessibility_proof_ios_ax" "$accessibility_proof_ipad"
  rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_ios_ax_abs" "$accessibility_proof_ipad_abs"
  rm -f "$accessibility_proof_ios_deep_scroll" "$accessibility_proof_ios_ax_deep_scroll" "$accessibility_proof_ipad_deep_scroll"
  rm -f "$accessibility_proof_ios_deep_scroll_abs" "$accessibility_proof_ios_ax_deep_scroll_abs" "$accessibility_proof_ipad_deep_scroll_abs"
  rm -f "$observed_accessibility_ios" "$observed_accessibility_ios_ax" "$observed_accessibility_ipad"
  rm -f "$observed_accessibility_ios_abs" "$observed_accessibility_ios_ax_abs" "$observed_accessibility_ipad_abs"
}

capture_ios_app_with_retries() {
  local udid="$1"
  local expected_platform="$2"
  local screenshot_output="$3"
  local surface_proof_output="$4"
  local accessibility_proof_output="$5"
  local observed_accessibility_output="$6"
  local final_observed_accessibility_ios_ax_abs="$observed_accessibility_ios_ax_abs"
  local final_ios_accessibility_screenshot="$ios_accessibility_screenshot"
  local final_accessibility_proof_ios_ax_abs="$accessibility_proof_ios_ax_abs"
  local final_accessibility_proof_ios_deep_scroll_abs="$accessibility_proof_ios_deep_scroll_abs"
  local final_accessibility_proof_ios_ax_deep_scroll_abs="$accessibility_proof_ios_ax_deep_scroll_abs"
  local final_accessibility_proof_ipad_deep_scroll_abs="$accessibility_proof_ipad_deep_scroll_abs"
  local final_ios_deep_scroll_screenshot="$ios_deep_scroll_screenshot"
  local final_ios_accessibility_deep_scroll_screenshot="$ios_accessibility_deep_scroll_screenshot"
  local final_ios_tablet_deep_scroll_screenshot="$ios_tablet_deep_scroll_screenshot"
  local attempt=1
  rm -f "$screenshot_output" "$surface_proof_output" "$accessibility_proof_output" "$observed_accessibility_output"
  if [[ "$expected_platform" == "ios" ]]; then
    rm -f "$final_observed_accessibility_ios_ax_abs" "$final_ios_accessibility_screenshot" "$final_accessibility_proof_ios_ax_abs"
    rm -f "$final_accessibility_proof_ios_deep_scroll_abs" "$final_accessibility_proof_ios_ax_deep_scroll_abs"
    rm -f "$final_ios_deep_scroll_screenshot" "$final_ios_accessibility_deep_scroll_screenshot"
  else
    rm -f "$final_accessibility_proof_ipad_deep_scroll_abs" "$final_ios_tablet_deep_scroll_screenshot"
  fi
  while [[ "$attempt" -le "$ios_capture_attempts" ]]; do
    local attempt_directory="$artifact_root/apple/${unit_slug}-${expected_platform}-capture-attempt-${attempt}"
    rm -rf "$attempt_directory"
    mkdir -p "$attempt_directory"
    local staged_screenshot="$attempt_directory/$(basename "$screenshot_output")"
    local staged_surface_proof="$attempt_directory/$(basename "$surface_proof_output")"
    local staged_accessibility_proof="$attempt_directory/$(basename "$accessibility_proof_output")"
    local staged_observed_accessibility="$attempt_directory/$(basename "$observed_accessibility_output")"
    observed_accessibility_ios_ax_abs="$attempt_directory/$(basename "$final_observed_accessibility_ios_ax_abs")"
    ios_accessibility_screenshot="$attempt_directory/$(basename "$final_ios_accessibility_screenshot")"
    accessibility_proof_ios_ax_abs="$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_abs")"
    accessibility_proof_ios_deep_scroll_abs="$attempt_directory/$(basename "$final_accessibility_proof_ios_deep_scroll_abs")"
    accessibility_proof_ios_ax_deep_scroll_abs="$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_deep_scroll_abs")"
    accessibility_proof_ipad_deep_scroll_abs="$attempt_directory/$(basename "$final_accessibility_proof_ipad_deep_scroll_abs")"
    ios_deep_scroll_screenshot="$attempt_directory/$(basename "$final_ios_deep_scroll_screenshot")"
    ios_accessibility_deep_scroll_screenshot="$attempt_directory/$(basename "$final_ios_accessibility_deep_scroll_screenshot")"
    ios_tablet_deep_scroll_screenshot="$attempt_directory/$(basename "$final_ios_tablet_deep_scroll_screenshot")"
    if capture_ios_app "$udid" "$expected_platform" "$staged_screenshot" "$staged_surface_proof" "$staged_accessibility_proof" "$staged_observed_accessibility"; then
      observed_accessibility_ios_ax_abs="$final_observed_accessibility_ios_ax_abs"
      ios_accessibility_screenshot="$final_ios_accessibility_screenshot"
      accessibility_proof_ios_ax_abs="$final_accessibility_proof_ios_ax_abs"
      accessibility_proof_ios_deep_scroll_abs="$final_accessibility_proof_ios_deep_scroll_abs"
      accessibility_proof_ios_ax_deep_scroll_abs="$final_accessibility_proof_ios_ax_deep_scroll_abs"
      accessibility_proof_ipad_deep_scroll_abs="$final_accessibility_proof_ipad_deep_scroll_abs"
      ios_deep_scroll_screenshot="$final_ios_deep_scroll_screenshot"
      ios_accessibility_deep_scroll_screenshot="$final_ios_accessibility_deep_scroll_screenshot"
      ios_tablet_deep_scroll_screenshot="$final_ios_tablet_deep_scroll_screenshot"
      require_ios_capture_artifact "$staged_screenshot" || return 1
      require_ios_capture_artifact "$staged_accessibility_proof" || return 1
      require_ios_capture_artifact "$staged_observed_accessibility" || return 1
      if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]]; then
        require_ios_capture_artifact "$staged_surface_proof" || return 1
      fi
      if [[ "$expected_platform" == "ios" ]]; then
        require_ios_capture_artifact "$attempt_directory/$(basename "$final_observed_accessibility_ios_ax_abs")" || return 1
        require_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_accessibility_screenshot")" || return 1
        require_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_abs")" || return 1
      fi
      case "$screenshot_route" in
        kitchen|recipes|saved-recipes|recipe-detail|recipe-editor|recipe-covers|cook-mode|cook-log|cookbooks|cookbook-detail|shopping-list|chefs|profile|profile-graph|search|capture|settings)
          if [[ "$expected_platform" == "ios" ]]; then
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_deep_scroll_abs")" || return 1
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_deep_scroll_abs")" || return 1
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_deep_scroll_screenshot")" || return 1
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_accessibility_deep_scroll_screenshot")" || return 1
          else
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ipad_deep_scroll_abs")" || return 1
            require_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_tablet_deep_scroll_screenshot")" || return 1
          fi
          ;;
      esac
      publish_ios_capture_artifact "$staged_screenshot" "$screenshot_output" || return 1
      if [[ -s "$staged_surface_proof" ]]; then
        publish_ios_capture_artifact "$staged_surface_proof" "$surface_proof_output" || return 1
      elif [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]]; then
        printf 'staged iOS surface proof is required for route %s\n' "$screenshot_route" >> "$capture_log"
        return 1
      fi
      publish_ios_capture_artifact "$staged_accessibility_proof" "$accessibility_proof_output" || return 1
      publish_ios_capture_artifact "$staged_observed_accessibility" "$observed_accessibility_output" || return 1
      if [[ "$expected_platform" == "ios" ]]; then
        publish_ios_capture_artifact "$attempt_directory/$(basename "$final_observed_accessibility_ios_ax_abs")" "$final_observed_accessibility_ios_ax_abs" || return 1
        publish_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_accessibility_screenshot")" "$final_ios_accessibility_screenshot" || return 1
        publish_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_abs")" "$final_accessibility_proof_ios_ax_abs" || return 1
        if [[ -s "$attempt_directory/$(basename "$final_accessibility_proof_ios_deep_scroll_abs")" ]]; then
          publish_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_deep_scroll_abs")" "$final_accessibility_proof_ios_deep_scroll_abs" || return 1
          publish_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ios_ax_deep_scroll_abs")" "$final_accessibility_proof_ios_ax_deep_scroll_abs" || return 1
          publish_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_deep_scroll_screenshot")" "$final_ios_deep_scroll_screenshot" || return 1
          publish_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_accessibility_deep_scroll_screenshot")" "$final_ios_accessibility_deep_scroll_screenshot" || return 1
        fi
      elif [[ -s "$attempt_directory/$(basename "$final_accessibility_proof_ipad_deep_scroll_abs")" ]]; then
        publish_ios_capture_artifact "$attempt_directory/$(basename "$final_accessibility_proof_ipad_deep_scroll_abs")" "$final_accessibility_proof_ipad_deep_scroll_abs" || return 1
        publish_ios_capture_artifact "$attempt_directory/$(basename "$final_ios_tablet_deep_scroll_screenshot")" "$final_ios_tablet_deep_scroll_screenshot" || return 1
      fi
      rm -rf "$attempt_directory"
      return 0
    fi
    observed_accessibility_ios_ax_abs="$final_observed_accessibility_ios_ax_abs"
    ios_accessibility_screenshot="$final_ios_accessibility_screenshot"
    accessibility_proof_ios_ax_abs="$final_accessibility_proof_ios_ax_abs"
    accessibility_proof_ios_deep_scroll_abs="$final_accessibility_proof_ios_deep_scroll_abs"
    accessibility_proof_ios_ax_deep_scroll_abs="$final_accessibility_proof_ios_ax_deep_scroll_abs"
    accessibility_proof_ipad_deep_scroll_abs="$final_accessibility_proof_ipad_deep_scroll_abs"
    ios_deep_scroll_screenshot="$final_ios_deep_scroll_screenshot"
    ios_accessibility_deep_scroll_screenshot="$final_ios_accessibility_deep_scroll_screenshot"
    ios_tablet_deep_scroll_screenshot="$final_ios_tablet_deep_scroll_screenshot"
    rm -rf "$attempt_directory"
    printf '%s screenshot capture attempt %s/%s failed for route %s\n' "$expected_platform" "$attempt" "$ios_capture_attempts" "$screenshot_route" >> "$capture_log"
    if [[ "$ios_visual_evidence_failure_seen" == true ]]; then
      return 1
    fi
    if [[ "$attempt" -lt "$ios_capture_attempts" ]]; then
      run_with_timeout "simulator retry termination timeout" "$ios_launch_timeout_seconds" "$capture_log" \
        xcrun simctl terminate "$udid" app.spoonjoy || true
      run_with_timeout "simulator retry shutdown timeout" "$ios_boot_timeout_seconds" "$capture_log" \
        xcrun simctl shutdown "$udid" || true
      sleep 2
    fi
    attempt=$((attempt + 1))
  done
  return 1
}

transition_ios_capture_device() {
  local previous_udid="$1"
  local next_udid="$2"
  if [[ -z "$next_udid" ]]; then
    printf 'simulator device transition is missing the destination UDID\n' >> "$capture_log"
    return 1
  fi

  printf 'Transitioning simulator capture device: %s -> %s\n' "${previous_udid:-none}" "$next_udid" >> "$capture_log"
  if [[ -n "$previous_udid" && "$previous_udid" != "$next_udid" ]]; then
    run_with_timeout "simulator device transition termination timeout" "$ios_launch_timeout_seconds" "$capture_log" \
      xcrun simctl terminate "$previous_udid" app.spoonjoy || true
    run_with_timeout "simulator device transition shutdown timeout" "$ios_boot_timeout_seconds" "$capture_log" \
      xcrun simctl shutdown "$previous_udid" || true
  fi

  run_with_timeout "simulator device transition boot request timeout" "$ios_boot_timeout_seconds" "$capture_log" \
    xcrun simctl boot "$next_udid" || true
  if ! run_with_timeout "simulator device transition boot readiness timeout" "$ios_boot_timeout_seconds" "$capture_log" \
    xcrun simctl bootstatus "$next_udid" -b; then
    return 1
  fi
  if ! run_with_timeout "Simulator host transition timeout" "$ios_launch_timeout_seconds" "$capture_log" \
    open -a Simulator --args -CurrentDeviceUDID "$next_udid"; then
    return 1
  fi
  if [[ "$ios_host_settle_seconds" != "0" ]]; then
    printf 'Waiting %s seconds for Simulator host foreground readiness\n' "$ios_host_settle_seconds" >> "$capture_log"
    sleep "$ios_host_settle_seconds"
  fi
}

capture_macos_window() {
  run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application \"$macos_app\" to activate" || true
  sleep 1
  local window_id=""
  local spoonjoy_pid=""
  macos_screenshot_pid=""
  for _ in $(seq 1 20); do
    while IFS= read -r spoonjoy_pid; do
      [[ -n "$spoonjoy_pid" ]] || continue
      if window_id="$(swift scripts/find-macos-window-id.swift "$spoonjoy_pid" "$macos_window_title" 2>> "$capture_log")"; then
        macos_screenshot_pid="$spoonjoy_pid"
        break
      fi
      window_id=""
    done < <(pgrep -x Spoonjoy | sort -nr || true)
    [[ -n "$window_id" ]] && break
    sleep 0.5
  done
  if [[ -z "$window_id" || -z "$macos_screenshot_pid" ]]; then
    return 1
  fi
  if ! screencapture -x -l "$window_id" "$macos_screenshot" >> "$capture_log" 2>&1 || [[ ! -f "$macos_screenshot" || ! -s "$macos_screenshot" ]]; then
    macos_screenshot_pid=""
    return 1
  fi
  return 0
}

capture_macos_observed_accessibility() {
  local output_path="$1"
  local spoonjoy_pid="$macos_screenshot_pid"
  local executable_name
  local executable_path
  local observer_deadline
  local observer_remaining_seconds
  local observer_preflight_timeout_seconds
  local -a observer_command
  local -a observer_preflight_command
  [[ -n "$spoonjoy_pid" ]] || return 1
  executable_name="$(plutil -extract CFBundleExecutable raw -o - "$macos_app/Contents/Info.plist")"
  executable_path="$macos_app/Contents/MacOS/$executable_name"
  observer_deadline=$((SECONDS + macos_observer_timeout_seconds))
  while IFS= read -r spoonjoy_pid; do
    observer_remaining_seconds=$((observer_deadline - SECONDS))
    (( observer_remaining_seconds > 0 )) || return 1
    observer_preflight_timeout_seconds="$macos_observer_preflight_timeout_seconds"
    if (( observer_preflight_timeout_seconds > observer_remaining_seconds )); then
      observer_preflight_timeout_seconds="$observer_remaining_seconds"
    fi
    observer_command=(
      swift scripts/observe-macos-screenshot-evidence.swift
      --pid "$spoonjoy_pid"
      --route "$screenshot_route"
      --capture-run-nonce "$screenshot_run_nonce"
      --readiness-proof-path "$accessibility_proof_macos_abs"
      --screenshot-path "$macos_screenshot"
      --bundle-id app.spoonjoy.mac
      --bundle-path "$macos_app"
      --executable-path "$executable_path"
      --output "$output_path"
    )
    if [[ "$screenshot_route" == "settings" && "$settings_capture_focus" == "notifications" ]]; then
      observer_command+=(--apns)
    fi
    if [[ "$screenshot_auth_enabled" == "0" ]]; then
      observer_command+=(--signed-out)
    fi
    observer_preflight_command=("${observer_command[@]}" --preflight)
    if ! run_with_timeout "macOS accessibility observer preflight timeout" "$observer_preflight_timeout_seconds" "$capture_log" "${observer_preflight_command[@]}"; then
      continue
    fi
    observer_remaining_seconds=$((observer_deadline - SECONDS))
    (( observer_remaining_seconds > 0 )) || return 1
    rm -f "$output_path"
    if run_with_timeout "macOS accessibility observation timeout" "$observer_remaining_seconds" "$capture_log" "${observer_command[@]}" && [[ -s "$output_path" ]]; then
      return 0
    fi
  done < <(printf '%s\n' "$macos_screenshot_pid")
  return 1
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
rm -f "$ios_screenshot" "$ios_accessibility_screenshot" "$ios_tablet_screenshot" "$macos_screenshot"
rm -f "$ios_deep_scroll_screenshot" "$ios_accessibility_deep_scroll_screenshot" "$ios_tablet_deep_scroll_screenshot"
rm -f "$macos_screenshot_diagnostic"
rm -f "$ios_proof_artifact" "$ipad_proof_artifact" "$macos_proof_artifact"
rm -f "$accessibility_proof_ios" "$accessibility_proof_ios_ax" "$accessibility_proof_ipad" "$accessibility_proof_macos"
rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_ios_ax_abs" "$accessibility_proof_ipad_abs" "$accessibility_proof_macos_abs"
rm -f "$accessibility_proof_ios_deep_scroll" "$accessibility_proof_ios_ax_deep_scroll" "$accessibility_proof_ipad_deep_scroll"
rm -f "$accessibility_proof_ios_deep_scroll_abs" "$accessibility_proof_ios_ax_deep_scroll_abs" "$accessibility_proof_ipad_deep_scroll_abs"
rm -f "$observed_accessibility_ios" "$observed_accessibility_ios_ax" "$observed_accessibility_ipad" "$observed_accessibility_macos"
rm -f "$observed_accessibility_ios_abs" "$observed_accessibility_ios_ax_abs" "$observed_accessibility_ipad_abs" "$observed_accessibility_macos_abs"
rm -f "$design_review_blocked"
rm -f "$design_review"
rm -f "$xcode_blocker" "$ios_blocker" "$ipad_blocker" "$macos_blocker" "$macos_accessibility_blocker"
rm -f "$observed_accessibility_macos_diagnostic"
trap cleanup_uncommitted_ios_generation EXIT

ios_udid=""
ipad_udid=""

if ! prepare_ios_observer_products; then
  write_blocker \
    "$xcode_blocker" \
    "XcodePlatform" \
    "xcodebuild build-for-testing for Spoonjoy iOS observer" \
    "$capture_log" \
    "The iOS screenshot app and external UI observer products could not be prepared from one build." \
    "Repair the iOS app/UI-test build and rerun screenshot capture."
fi

if [[ ! -f "$xcode_blocker" ]]; then
  run_ios_smoke "iPhone simulator" "iphone" "$ios_smoke_log" "$ios_blocker"
fi
if [[ ! -f "$xcode_blocker" ]]; then
  run_ios_smoke "iPad simulator" "ipad" "$ipad_smoke_log" "$ipad_blocker"
fi
if [[ ! -f "$xcode_blocker" ]]; then
  run_smoke "macOS launch" "$macos_smoke_log" "$macos_blocker" scripts/smoke-macos.sh
fi

if [[ ! -f "$xcode_blocker" && ! -f "$ios_blocker" ]]; then
  ios_udid="$(ios_udid_from_smoke_log "$ios_smoke_log" || true)"
  ipad_udid="$(ios_udid_from_smoke_log "$ipad_smoke_log" || true)"
  if [[ -z "$ios_udid" ]] || ! transition_ios_capture_device "$ipad_udid" "$ios_udid" || ! capture_ios_app_with_retries "$ios_udid" "ios" "$ios_screenshot" "$ios_proof_artifact" "$accessibility_proof_ios_abs" "$observed_accessibility_ios_abs"; then
    if [[ "$ios_visual_evidence_failure_seen" == true || "$ios_evidence_publication_failure_seen" == true ]]; then
      printf 'iOS visual evidence or transactional publication failed for route %s; release evidence failures are not CoreSimulator blockers.\n' "$screenshot_route" >&2
      exit 1
    fi
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
  if [[ -z "$ipad_udid" ]]; then
    ipad_udid="$(ios_udid_from_smoke_log "$ipad_smoke_log" || true)"
  fi
  if [[ -z "$ipad_udid" ]] || ! transition_ios_capture_device "$ios_udid" "$ipad_udid" || ! capture_ios_app_with_retries "$ipad_udid" "ipad" "$ios_tablet_screenshot" "$ipad_proof_artifact" "$accessibility_proof_ipad_abs" "$observed_accessibility_ipad_abs"; then
    if [[ "$ios_visual_evidence_failure_seen" == true || "$ios_evidence_publication_failure_seen" == true ]]; then
      printf 'iPad visual evidence or transactional publication failed for route %s; release evidence failures are not CoreSimulator blockers.\n' "$screenshot_route" >&2
      exit 1
    fi
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
  trap 'restore_capture_state || true; cleanup_uncommitted_ios_generation' EXIT
  if ! terminate_macos_app_and_confirm_stopped; then
    write_blocker \
      "$macos_blocker" \
      "MacOSTermination" \
      "terminate_macos_app_and_confirm_stopped" \
      "$capture_log" \
      "Spoonjoy macOS did not stop before screenshot fixture state was written." \
      "Rerun screenshot capture after the existing Spoonjoy process exits."
  fi
  rm -f "$state_file"
  rm -f "$cache_file"
  rm -f "$sync_file"
  rm -f "$proof_file"
  rm -f "$auth_file"
  rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
  screenshot_proof_path="$proof_file"
  macos_fixture_cover_path="$(install_fixture_cover "$macos_state_directory")"
  atomic_fixture_write "$state_file" write_app_state "$expected_recorded_route"
  atomic_fixture_write "$cache_file" write_cache_state "$screenshot_route"
  atomic_fixture_write "$sync_file" write_sync_store "$screenshot_route" "$macos_fixture_cover_path"
  if ! open_macos_app; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "open -n -F $macos_app" \
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
  if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"$deep_link_url\""; then
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "$deep_link_url" \
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
      "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file $deep_link_url" \
      "$capture_log" \
      "Spoonjoy macOS did not prove the expected visible screenshot route." \
      "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs" "$expected_accessibility_source" "$expected_surface_variant"; then
    log_accessibility_proof_diagnostic "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "macOS" "$expected_surface_variant"
    printf 'Spoonjoy did not write the expected macOS accessibility proof for %s\n' "$screenshot_route" >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=$accessibility_proof_macos_abs $deep_link_url" \
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
      "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file $deep_link_url" \
      "$capture_log" \
      "Spoonjoy macOS screenshot proof did not match the expected route." \
      "Rerun screenshot capture after the expected route is visible."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! capture_macos_window; then
    printf 'Retrying Spoonjoy window capture after relaunch\n' >> "$capture_log"
    if ! terminate_macos_app_and_confirm_stopped; then
      write_blocker \
        "$macos_blocker" \
        "MacOSTermination" \
        "terminate_macos_app_and_confirm_stopped" \
        "$capture_log" \
        "Spoonjoy macOS did not stop before retry fixture state was written." \
        "Rerun screenshot capture after the existing Spoonjoy process exits."
    fi
    rm -f "$proof_file"
    rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
    atomic_fixture_write "$state_file" write_app_state "$expected_recorded_route"
    atomic_fixture_write "$cache_file" write_cache_state "$screenshot_route"
    atomic_fixture_write "$sync_file" write_sync_store "$screenshot_route" "$macos_fixture_cover_path"
    if ! open_macos_app; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "open -n -F $macos_app" \
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
    if [[ ! -f "$macos_blocker" ]] && ! run_with_timeout "macOS launch timeout" "$macos_launch_timeout_seconds" "$capture_log" osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"$deep_link_url\""; then
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "$deep_link_url" \
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
        "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file $deep_link_url" \
        "$capture_log" \
        "Spoonjoy macOS did not prove the expected visible screenshot route after relaunch." \
        "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
    fi
    if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs" "$expected_accessibility_source" "$expected_surface_variant"; then
      log_accessibility_proof_diagnostic "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "macOS relaunch" "$expected_surface_variant"
      printf 'Spoonjoy did not write the expected macOS accessibility proof after relaunch for %s\n' "$screenshot_route" >> "$capture_log"
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=$accessibility_proof_macos_abs $deep_link_url" \
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
        "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file $deep_link_url" \
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
  if [[ ! -f "$macos_blocker" ]] && ! capture_macos_observed_accessibility "$observed_accessibility_macos_abs"; then
    if [[ -s "$observed_accessibility_macos_abs" ]]; then
      cp "$observed_accessibility_macos_abs" "$observed_accessibility_macos_diagnostic"
    fi
    if [[ -s "$macos_screenshot" ]]; then
      cp "$macos_screenshot" "$macos_screenshot_diagnostic"
    fi
    write_blocker \
      "$macos_accessibility_blocker" \
      "MacOSAccessibility" \
      "swift scripts/observe-macos-screenshot-evidence.swift --pid <exact Spoonjoy pid> --route $screenshot_route --capture-run-nonce <uuid> --readiness-proof-path <path> --screenshot-path <path> --bundle-id app.spoonjoy.mac --bundle-path <path> --executable-path <path>" \
      "$capture_log" \
      "The external macOS accessibility observer could not prove the exact foreground Spoonjoy process and visible route." \
      "Grant Accessibility access to the capture host if prompted, repair any reported geometry findings, and rerun screenshot capture."
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
elif [[ -f "$macos_accessibility_blocker" ]]; then
  write_design_review_blocked "$macos_accessibility_blocker"
else
  if [[ ! -s "$ios_screenshot" || ! -s "$ios_accessibility_screenshot" || ! -s "$ios_tablet_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce standard iPhone, accessibility iPhone, iPad, and macOS screenshots\n' >&2
    exit 1
  fi
  if [[ ! -s "$accessibility_proof_ios_abs" || ! -s "$accessibility_proof_ios_ax_abs" || ! -s "$accessibility_proof_ipad_abs" || ! -s "$accessibility_proof_macos_abs" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce standard iPhone, accessibility iPhone, iPad, and macOS accessibility proofs\n' >&2
    exit 1
  fi
  case "$screenshot_route" in
    kitchen|recipes|saved-recipes|recipe-detail|recipe-editor|recipe-covers|cook-mode|cook-log|cookbooks|cookbook-detail|shopping-list|chefs|profile|profile-graph|search|capture|settings)
      if [[ ! -s "$accessibility_proof_ios_deep_scroll_abs" || ! -s "$accessibility_proof_ios_ax_deep_scroll_abs" || ! -s "$accessibility_proof_ipad_deep_scroll_abs" ]]; then
        printf 'Screenshot capture produced no blocker but did not produce all deep-scroll readiness proofs\n' >&2
        exit 1
      fi
      ;;
  esac
  if [[ ! -s "$observed_accessibility_ios_abs" || ! -s "$observed_accessibility_ios_ax_abs" || ! -s "$observed_accessibility_ipad_abs" || ! -s "$observed_accessibility_macos_abs" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce standard iPhone, accessibility iPhone, iPad, and macOS observed accessibility evidence\n' >&2
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
  ios_capture_generation_committed=true
  printf 'native screenshot capture complete: %s\n' "$design_review"
fi
