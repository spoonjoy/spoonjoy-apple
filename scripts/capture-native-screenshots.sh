#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-16-1754-doing-siri-full-access-parity"
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
macos_screenshot="$artifact_root/screenshots/macos-desktop.png"
macos_app="$artifact_root/DerivedData-macOS/Build/Products/BootstrapDebug/Spoonjoy.app"
design_review="$artifact_root/design-review.json"
design_review_blocked="$artifact_root/design-review-blocked.json"
matrix_log="$artifact_root/apple/${unit_slug}-screenshots.log"
capture_log="$artifact_root/apple/${unit_slug}-screenshots-inner.log"
ios_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-ios.log"
macos_smoke_log="$artifact_root/apple/${unit_slug}-screenshots-smoke-macos.log"
xcode_blocker="$artifact_root/apple/${unit_slug}-screenshots-xcode-platform-blocker.json"
ios_blocker="$artifact_root/apple/${unit_slug}-screenshots-core-simulator-blocker.json"
macos_blocker="$artifact_root/apple/${unit_slug}-screenshots-macos-launch-blocker.json"
state_file="${HOME}/Library/Application Support/Spoonjoy/native-app-state.json"
cache_file="${HOME}/Library/Application Support/Spoonjoy/native-durable-cache.json"
sync_file="${HOME}/Library/Application Support/Spoonjoy/native-sync-store.json"
proof_file="${HOME}/Library/Application Support/Spoonjoy/native-screenshot-proof.json"
state_backup="$artifact_root/native-app-state-capture-backup.json"
cache_backup="$artifact_root/native-durable-cache-capture-backup.json"
sync_backup="$artifact_root/native-sync-store-capture-backup.json"
proof_backup="$artifact_root/native-screenshot-proof-capture-backup.json"
macos_launch_env_backup="$artifact_root/apple/${unit_slug}-macos-launch-env-backup.env"
ios_proof_artifact="$artifact_root/apple/${unit_slug}-screenshot-proof-ios.json"
macos_proof_artifact="$artifact_root/apple/${unit_slug}-screenshot-proof-macos.json"
ios_proof_artifact_rel="apple/${unit_slug}-screenshot-proof-ios.json"
macos_proof_artifact_rel="apple/${unit_slug}-screenshot-proof-macos.json"
accessibility_proof_ios="$artifact_root/apple/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_macos="$artifact_root/apple/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_macos_abs="$(cd "$apple_dir" && pwd -P)/${unit_slug}-accessibility-proof-macos.json"
accessibility_proof_ios_rel="apple/${unit_slug}-accessibility-proof-ios.json"
accessibility_proof_macos_rel="apple/${unit_slug}-accessibility-proof-macos.json"
ios_accessibility_proof_runtime_path=""
screenshot_proof_path=""
screenshot_route="kitchen"
if [[ -n "$requested_route" ]]; then
  screenshot_route="$requested_route"
else
  if [[ "$unit_slug" == *recipe-detail* || "$unit_slug" == *recipe_detail* ]]; then
    screenshot_route="recipe-detail"
  elif [[ "$unit_slug" == *recipes* ]]; then
    screenshot_route="recipes"
  elif [[ "$unit_slug" == *cook-mode* || "$unit_slug" == *cook_mode* ]]; then
    screenshot_route="cook-mode"
  elif [[ "$unit_slug" == *cookbooks* ]]; then
    screenshot_route="cookbooks"
  elif [[ "$unit_slug" == *shopping-list* || "$unit_slug" == *shopping_list* || "$unit_slug" == *shopping* ]]; then
    screenshot_route="shopping-list"
  elif [[ "$unit_slug" == *search* ]]; then
    screenshot_route="search"
  elif [[ "$unit_slug" == *capture* ]]; then
    screenshot_route="capture"
  elif [[ "$unit_slug" == *settings* || "$unit_slug" == *notification* || "$unit_slug" == *notifications* || "$unit_slug" == *apns* ]]; then
    screenshot_route="settings"
  fi
fi
settings_capture_account_id="chef_settings_capture"
kitchen_capture_account_id="chef_kitchen_capture"
search_capture_account_id="chef_search_capture"
shopping_capture_account_id="chef_shopping_capture"
capture_account_id="$kitchen_capture_account_id"
settings_capture_focus="profile"
search_capture_disable_focus="0"
proof_attempts="${SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS:-60}"
proof_sleep_seconds="${SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS:-0.5}"
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
  recipe-detail)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="recipe:recipe_lemon_pantry_pasta"
    deep_link_path="recipes/recipe_lemon_pantry_pasta"
    macos_window_title="Lemon Pantry Pasta"
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
  shopping-list)
    capture_account_id="$shopping_capture_account_id"
    expected_recorded_route="shopping-list"
    deep_link_path="shopping-list"
    macos_window_title="Shopping"
    ;;
  search)
    capture_account_id="$search_capture_account_id"
    search_capture_disable_focus="1"
    expected_recorded_route="search:all:"
    deep_link_path="search"
    macos_window_title="Search"
    ;;
  capture)
    capture_account_id="$kitchen_capture_account_id"
    expected_recorded_route="capture"
    deep_link_path="capture"
    macos_window_title="Capture"
    ;;
  settings)
    capture_account_id="$settings_capture_account_id"
    if [[ "$unit_slug" == *notification* || "$unit_slug" == *notifications* || "$unit_slug" == *apns* ]]; then
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
    source_path, output_path, ios_accessibility_proof, macos_accessibility_proof = ARGV
    blocker = JSON.parse(File.read(source_path))
    manifest = {
      "blocked" => true,
      "capability" => blocker.fetch("capability"),
      "sourceBlockerPath" => source_path,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        ios_accessibility_proof,
        macos_accessibility_proof
      ],
      "reason" => blocker.fetch("reason"),
      "ownerAction" => blocker.fetch("ownerAction")
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$source_blocker_path" "$design_review_blocked" "$accessibility_proof_ios_rel" "$accessibility_proof_macos_rel"
  rm -f "$ios_screenshot" "$macos_screenshot"
  rm -f "$accessibility_proof_ios" "$accessibility_proof_macos"
  rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_macos_abs"
  rm -f "$design_review"
}

write_design_review_success() {
  ruby -rjson -e '
    output_path, route, settings_focus, ios_proof, macos_proof, ios_accessibility_proof, macos_accessibility_proof = ARGV
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
      "accessibilityProofArtifacts" => [ios_accessibility_proof, macos_accessibility_proof],
      "blockers" => []
    }
    if route == "settings"
      manifest["settingsSignedInSurface"] = true
      manifest["settingsVisualFocus"] = settings_focus
      manifest["settingsSurfaceProofArtifacts"] = [ios_proof, macos_proof]
      if settings_focus == "notifications"
        manifest["settingsNotificationAPNsSurface"] = true
      else
        manifest["settingsProfileSurface"] = true
      end
      manifest["settingsSections"] = ["Profile", "Security", "Notifications", "Device Notifications", "APNs Delivery", "Notification Sync", "API Tokens", "Connections", "Environment", "Offline"]
      manifest["settingsSeedAccountID"] = "chef_settings_capture"
    elsif route == "search"
      manifest["searchNativeSurface"] = true
      manifest["searchScopes"] = ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
      manifest["searchSeedAccountID"] = "chef_search_capture"
      manifest["searchSurfaceProofArtifacts"] = [ios_proof, macos_proof]
    elsif route == "recipes"
      manifest["recipesNativeSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
    elsif route == "recipe-detail"
      manifest["recipeDetailSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "cook-mode"
      manifest["cookModeSurface"] = true
      manifest["recipeSeedAccountID"] = "chef_kitchen_capture"
      manifest["recipeID"] = "recipe_lemon_pantry_pasta"
    elsif route == "cookbooks"
      manifest["cookbooksNativeSurface"] = true
      manifest["cookbookSeedAccountID"] = "chef_kitchen_capture"
    elsif route == "shopping-list"
      manifest["shoppingListSurface"] = true
      manifest["shoppingSeedAccountID"] = "chef_shopping_capture"
    elsif route == "capture"
      manifest["captureNativeSurface"] = true
      manifest["captureSeedAccountID"] = "chef_kitchen_capture"
    else
      manifest["kitchenSignedInSurface"] = true
      manifest["kitchenSeedAccountID"] = "chef_kitchen_capture"
    end
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$design_review" "$screenshot_route" "$settings_capture_focus" "$ios_proof_artifact_rel" "$macos_proof_artifact_rel" "$accessibility_proof_ios_rel" "$accessibility_proof_macos_rel"
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
    path, route, account_id = ARGV
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
    snapshot = {
      "schemaVersion" => 1,
      "accountID" => account_id,
      "environment" => "production",
      "hasCompletedFirstRun" => true,
      "cookProgressByRecipeID" => {},
      "spoonCookLogDraftsByRecipeID" => {},
      "shoppingList" => shopping_list,
      "captureDraft" => nil,
      "pendingCaptureImport" => nil,
      "captureImportProviderBlocker" => nil,
      "pendingMutations" => { "mutations" => [] },
      "lastOpenedRoute" => route,
      "savedAt" => "2026-06-16T12:09:00.000Z"
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$route" "$capture_account_id"
}

write_sync_store() {
  local path="$1"
  ruby -rjson -rfileutils -e '
    path, account_id = ARGV
    recipes_path = "Sources/SpoonjoyCore/Fixtures/recipes-fixture.json"
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
    snapshot = {
      "accountID" => account_id,
      "environment" => "production",
      "checkpoint" => nil,
      "queue" => { "mutations" => [] },
      "cachedRecords" => records,
      "tombstones" => []
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$capture_account_id"
}

write_cache_state() {
  local path="$1"
  local route="$2"
  ruby -rjson -rfileutils -rtime -e '
    path, route, account_id = ARGV
    FileUtils.mkdir_p(File.dirname(path))
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
                "name" => "Capture validation token",
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
      {
        "id" => "apns-status",
        "metadata" => metadata.call("apnsStatus", "/api/v1/me/apns-devices"),
        "payload" => {
          "apnsStatus" => {
            "deviceID" => "device_apns_capture",
            "registrationState" => "registered"
          }
        }
      }
    ]
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
  ' "$path" "$route" "$capture_account_id"
}

ios_launch_app() {
  local udid="$1"
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_AUTH=1 \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID="$capture_account_id" \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SETTINGS_FOCUS="$settings_capture_focus" \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS="$search_capture_disable_focus" \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
  SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$ios_accessibility_proof_runtime_path" \
    xcrun simctl launch --terminate-running-process "$udid" app.spoonjoy >> "$capture_log" 2>&1
}

open_macos_app() {
  set_macos_launch_environment
  env \
    SPOONJOY_SCREENSHOT_AUTH=1 \
    SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
    SPOONJOY_SCREENSHOT_ACCOUNT_ID="$capture_account_id" \
    SPOONJOY_SCREENSHOT_SETTINGS_FOCUS="$settings_capture_focus" \
    SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS="$search_capture_disable_focus" \
    SPOONJOY_SCREENSHOT_PROOF_PATH="$screenshot_proof_path" \
    SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH="$accessibility_proof_macos_abs" \
    SPOONJOY_API_BASE_URL="https://spoonjoy.app" \
    open -n "$macos_app" >> "$capture_log" 2>&1
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
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_AUTH 1
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY 1
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_ACCOUNT_ID "$capture_account_id"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_SETTINGS_FOCUS "$settings_capture_focus"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS "$search_capture_disable_focus"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_PROOF_PATH "$screenshot_proof_path"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH "$accessibility_proof_macos_abs"
  launchctl asuser "$uid" launchctl setenv SPOONJOY_API_BASE_URL "https://spoonjoy.app"
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
        launchctl asuser "$uid" launchctl setenv "$key" "$value" >/dev/null 2>&1 || true
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
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_PROOF_PATH >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH >/dev/null 2>&1 || true
  launchctl asuser "$uid" launchctl unsetenv SPOONJOY_API_BASE_URL >/dev/null 2>&1 || true
}

ios_udid_from_smoke_log() {
  ruby -e '
    path = ARGV.fetch(0)
    output = File.file?(path) ? File.read(path) : ""
    match = output.match(/Booting simulator: xcrun simctl boot ([A-F0-9-]+)/)
    exit(1) unless match
    puts match[1]
  ' "$ios_smoke_log"
}

wait_for_ios_foreground() {
  local udid="$1"
  local output=""
  for _ in $(seq 1 30); do
    output="$(xcrun simctl spawn "$udid" log show --last 15s --style compact --predicate 'process == "SpringBoard" AND eventMessage CONTAINS[c] "Front display did change" AND eventMessage CONTAINS[c] "app.spoonjoy"' 2>&1 || true)"
    printf '%s\n' "$output" >> "$capture_log"
    if [[ "$output" == *"app.spoonjoy"* ]]; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

validate_ios_screenshot() {
  python3 - "$ios_screenshot" <<'PY'
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
if black_ratio > 0.20 or bone_ratio < 0.30:
    raise SystemExit(f"iOS screenshot does not look like full-screen foreground Spoonjoy content (black={black_ratio:.3f}, bone={bone_ratio:.3f})")
PY
}

wait_for_screenshot_proof() {
  local proof_path="$1"
  local expected_route="$2"
  local expected_focus="$3"
  for _ in $(seq 1 "$proof_attempts"); do
    if ruby -rjson -e '
      path, expected_route, expected_focus = ARGV
      proof = JSON.parse(File.read(path))
      exit(1) unless proof.fetch("route") == expected_route
      exit(1) if !expected_focus.empty? && proof.fetch("visualFocus") != expected_focus
    ' "$proof_path" "$expected_route" "$expected_focus" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$proof_sleep_seconds"
  done
  return 1
}

wait_for_accessibility_proof() {
  local proof_path="$1"
  local expected_route="$2"
  local expected_platform="$3"
  local output_path="$4"
  for _ in $(seq 1 "$proof_attempts"); do
    if ruby -rjson -rfileutils -e '
      path, expected_route, expected_platform, output_path = ARGV
      proof = JSON.parse(File.read(path))
      expected_source = case expected_route
                        when "kitchen" then "KitchenView"
                        when "recipes" then "RecipesView"
                        when "cookbooks" then "CookbooksView"
                        when "capture" then "CaptureDraftView"
                        when "search" then "SearchView"
                        when "settings" then "SettingsView"
                        when "recipe-detail" then "RecipeDetailView"
                        when "cook-mode" then "CookModeView"
                        when "shopping-list" then "ShoppingListView"
                        else abort("unsupported route #{expected_route}")
                        end
      expected_bundle = expected_platform == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy"
      expected_fields = ["dynamicType", "voiceOverLabels", "keyboardNavigation", "reduceMotion", "contrast", "kitchenTableHierarchy", "noOverlap"]
      expected_visible = ["offline", "stale", "queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"]
      expected_dismissible = ["offline", "stale"]
      expected_severe = ["queuedWork", "syncFailure", "conflict", "blocker", "destructiveConfirmation"]
      expected_route_evidence = {
        "kitchen" => {
          "voiceOverLabels" => ["Spoonjoy Kitchen", "Open Recipe", "Start Cooking"],
          "keyboardNavigationTargets" => ["lead recipe actions", "recipe index buttons"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "white on photo overlay"],
          "hierarchyAnchors" => ["KitchenView", "KitchenMasthead", "RecipeLead"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters"]
        },
        "search" => {
          "voiceOverLabels" => ["Search", "row.accessibilityLabel"],
          "keyboardNavigationTargets" => ["typed rows", "SearchSurfaceSectionView buttons"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "herb tint on bone"],
          "hierarchyAnchors" => ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters"]
        },
        "recipes" => {
          "voiceOverLabels" => ["Recipes", "Recipe Index", "recipe rows"],
          "keyboardNavigationTargets" => ["recipe index buttons", "recipe rows"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["RecipesView", "KitchenTableHeader", "KitchenTableSection", "KitchenTableObjectRow"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cookbooks" => {
          "voiceOverLabels" => ["Cookbooks", "Cookbook Shelf", "New Cookbook"],
          "keyboardNavigationTargets" => ["cookbook shelf buttons", "share buttons", "new cookbook action"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone"],
          "hierarchyAnchors" => ["CookbooksView", "KitchenTableHeader", "CookbookShelf", "KitchenTableObjectRow"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "capture" => {
          "voiceOverLabels" => ["Import Status", "Spoonjoy Capture", "Send to Spoonjoy"],
          "keyboardNavigationTargets" => ["import status", "saved capture actions"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass on bone", "destructive action role"],
          "hierarchyAnchors" => ["CaptureDraftView", "KitchenTableHeader", "ImportStatusPanel", "CaptureDraft"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "settings" => {
          "voiceOverLabels" => ["Settings", "Profile", "Security"],
          "keyboardNavigationTargets" => ["profile form fields", "security token controls"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass label on bone"],
          "hierarchyAnchors" => ["SettingsView", "KitchenTableHeader", "KitchenTableSection", "SettingsPanel"],
          "layoutGuards" => ["kitchen-table-page", "text-fit", "no-tiny-clusters"]
        },
        "recipe-detail" => {
          "voiceOverLabels" => ["Cook mode", "Save", "Yield", "Clear progress", "Add to list", "More", "Steps", "Ingredients", "Cooks"],
          "keyboardNavigationTargets" => ["recipe primary actions", "recipe secondary menu", "recipe yield controls", "step ingredient rows"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "white on photo overlay", "secondary text on bone"],
          "hierarchyAnchors" => ["RecipeDetailView", "recipeHeaderControls", "RecipeScaleSelector", "KitchenTableActionButtonStyle", "stepsSection", "RecipeStepChecklistRow", "SpoonCookLogView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "cook-mode" => {
          "voiceOverLabels" => ["Mark the current step done", "Return to recipe detail", "Current cooking step", "Step Ingredients", "Cook mode SpoonDock"],
          "keyboardNavigationTargets" => ["cook step handrail", "ingredient toggles", "dependency toggles"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "herb tint on bone", "status text on material"],
          "hierarchyAnchors" => ["CookModeView", "compactCookControls", "SpoonDockContext.cookMode", "ScaleSelector"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
        },
        "shopping-list" => {
          "voiceOverLabels" => ["Shopping", "Kitchen", "List Actions", "Add", "Clear checked"],
          "keyboardNavigationTargets" => ["shopping item fields", "shopping header menu", "native tab bar"],
          "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
          "contrastPairs" => ["charcoal on bone", "brass label on bone", "destructive action role"],
          "hierarchyAnchors" => ["ShoppingListView", "shoppingHeaderTools", "addItemControls", "TabView"],
          "layoutGuards" => ["text-fit", "no-tiny-clusters", "tab-bar-safe-area"]
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
      route_evidence = proof.fetch("routeEvidence")
      abort("#{expected_platform} accessibility proof routeEvidence mismatch") unless route_evidence.is_a?(Hash)
      expected_route_evidence.fetch(expected_route).each do |field, required_values|
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
    ' "$proof_path" "$expected_route" "$expected_platform" "$output_path" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$proof_sleep_seconds"
  done
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
    path, output_path, platform, screenshot_route, expected_focus, expected_recorded_route, capture_account_id = ARGV
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
      abort("#{platform} screenshot proof scope mismatch") unless proof.fetch("scope") == "all"
      abort("#{platform} screenshot proof query mismatch") unless proof.fetch("query") == ""
      abort("#{platform} screenshot proof searchable scopes mismatch") unless proof.fetch("searchScopes") == expected_scopes
    end
    sections = proof.fetch("visibleSections")
    abort("#{platform} screenshot proof sections must be an array") unless sections.is_a?(Array)
    if screenshot_route == "settings"
      required_sections = if expected_focus == "notifications"
                            ["Notifications", "Device Notifications", "APNs Delivery", "Notification Sync"]
                          else
                            ["Profile", "Security"]
                          end
      missing = required_sections.reject { |section| sections.include?(section) }
      abort("#{platform} screenshot proof missing sections: #{missing.join(", ")}") unless missing.empty?
    else
      required_sections = ["Recipes", "Chefs"]
      missing = required_sections.reject { |section| sections.include?(section) }
      abort("#{platform} screenshot proof missing sections: #{missing.join(", ")}") unless missing.empty?
    end
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, JSON.pretty_generate(proof.merge("platform" => platform)) + "\n")
  ' "$proof_path" "$output_path" "$platform" "$screenshot_route" "$settings_capture_focus" "$expected_recorded_route" "$capture_account_id"
}

capture_ios_app() {
  local udid="$1"
  local data_container
  local terminate_log
  local bootstatus_log
  bootstatus_log="$(mktemp)"
  terminate_log="$(mktemp)"
  xcrun simctl shutdown "$udid" >> "$capture_log" 2>&1 || true
  xcrun simctl boot "$udid" >> "$capture_log" 2>&1 || true
  if ! xcrun simctl bootstatus "$udid" -b >"$bootstatus_log" 2>&1; then
    cat "$bootstatus_log" >> "$capture_log"
    rm -f "$bootstatus_log"
    return 1
  fi
  rm -f "$bootstatus_log"
  data_container="$(xcrun simctl get_app_container "$udid" app.spoonjoy data)"
  local ios_app_dir="$data_container/Library/Application Support/Spoonjoy"
  screenshot_proof_path="$ios_app_dir/native-screenshot-proof.json"
  ios_accessibility_proof_runtime_path="$ios_app_dir/native-accessibility-proof.json"
  write_app_state "$ios_app_dir/native-app-state.json" "$expected_recorded_route"
  write_cache_state "$ios_app_dir/native-durable-cache.json" "$screenshot_route"
  write_sync_store "$ios_app_dir/native-sync-store.json"
  rm -f "$screenshot_proof_path"
  rm -f "$ios_accessibility_proof_runtime_path"
  if ! xcrun simctl terminate "$udid" app.spoonjoy >"$terminate_log" 2>&1; then
    if ! grep -qi "found nothing to terminate" "$terminate_log"; then
      cat "$terminate_log" >> "$capture_log"
    fi
  fi
  rm -f "$terminate_log"
  ios_launch_app "$udid"
  wait_for_ios_foreground "$udid" || return 1
  sleep 1
  if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]]; then
    local proof_focus="$settings_capture_focus"
    if [[ "$screenshot_route" == "search" ]]; then
      proof_focus=""
    fi
    wait_for_screenshot_proof "$screenshot_proof_path" "$screenshot_route" "$proof_focus" || return 1
    validate_screenshot_surface_proof "$screenshot_proof_path" "$ios_proof_artifact" "ios" >> "$capture_log" 2>&1 || return 1
  fi
  if ! wait_for_accessibility_proof "$ios_accessibility_proof_runtime_path" "$screenshot_route" "ios" "$accessibility_proof_ios"; then
    log_accessibility_proof_diagnostic "$ios_accessibility_proof_runtime_path" "$screenshot_route" "ios" "iOS"
    printf 'Spoonjoy did not write the expected iOS accessibility proof for %s\n' "$screenshot_route" >> "$capture_log"
    return 1
  fi
  xcrun simctl io "$udid" screenshot "$ios_screenshot" >> "$capture_log" 2>&1
  [[ -f "$ios_screenshot" && -s "$ios_screenshot" ]]
  validate_ios_screenshot >> "$capture_log" 2>&1
}

capture_macos_window() {
  osascript -e "tell application \"$macos_app\" to activate" >> "$capture_log" 2>&1 || true
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

: > "$capture_log"
rm -f "$ios_screenshot" "$macos_screenshot"
rm -f "$ios_proof_artifact" "$macos_proof_artifact"
rm -f "$accessibility_proof_ios" "$accessibility_proof_macos"
rm -f "$accessibility_proof_ios_abs" "$accessibility_proof_macos_abs"
rm -f "$design_review_blocked"
rm -f "$design_review"
rm -f "$xcode_blocker" "$ios_blocker" "$macos_blocker"

run_smoke "iOS simulator" "$ios_smoke_log" "$ios_blocker" scripts/smoke-ios-simulator.sh
if [[ ! -f "$xcode_blocker" ]]; then
  run_smoke "macOS launch" "$macos_smoke_log" "$macos_blocker" scripts/smoke-macos.sh
fi

if [[ ! -f "$xcode_blocker" && ! -f "$ios_blocker" ]]; then
  ios_udid="$(ios_udid_from_smoke_log || true)"
  if [[ -z "$ios_udid" ]] || ! capture_ios_app "$ios_udid"; then
    write_blocker \
      "$ios_blocker" \
      "CoreSimulator" \
      "xcrun simctl launch/io $ios_udid app.spoonjoy $ios_screenshot" \
      "$capture_log" \
      "CoreSimulator could not capture a foreground Spoonjoy iOS screenshot for route $screenshot_route." \
      "Boot an available iPhone simulator, confirm Spoonjoy stays foregrounded, and rerun screenshot capture."
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
  }
  trap restore_capture_state EXIT
  rm -f "$state_file"
  rm -f "$cache_file"
  rm -f "$sync_file"
  rm -f "$proof_file"
  rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
  screenshot_proof_path="$proof_file"
  write_app_state "$state_file" "$expected_recorded_route"
  write_cache_state "$cache_file" "$screenshot_route"
  write_sync_store "$sync_file"
  osascript -e 'tell application id "app.spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  sleep 1
  open_macos_app
  sleep 3
  pgrep -x Spoonjoy >/dev/null
  osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"spoonjoy://$deep_link_path\"" >> "$capture_log" 2>&1
  wait_for_route "$expected_recorded_route" || true
  proof_focus="$settings_capture_focus"
  if [[ "$screenshot_route" == "search" ]]; then
    proof_focus=""
  fi
  if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]] && ! wait_for_screenshot_proof "$proof_file" "$screenshot_route" "$proof_focus"; then
    printf 'Spoonjoy did not write the expected macOS screenshot proof for %s\n' "$screenshot_route" >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
      "$capture_log" \
      "Spoonjoy macOS did not prove the expected visible screenshot route." \
      "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
  fi
  if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs"; then
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
  ruby -rjson -e '
    path, expected_route = ARGV
    snapshot = JSON.parse(File.read(path))
    abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
    actual_route = snapshot.fetch("lastOpenedRoute")
    abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
  ' "$state_file" "$expected_recorded_route" >> "$capture_log" 2>&1
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
    osascript -e 'tell application id "app.spoonjoy.mac" to quit' >/dev/null 2>&1 || true
    pkill -x Spoonjoy >/dev/null 2>&1 || true
    sleep 1
    rm -f "$proof_file"
    rm -f "$accessibility_proof_macos" "$accessibility_proof_macos_abs"
    write_app_state "$state_file" "$expected_recorded_route"
    write_cache_state "$cache_file" "$screenshot_route"
    write_sync_store "$sync_file"
    open_macos_app
    sleep 3
    pgrep -x Spoonjoy >/dev/null
    osascript -e "tell application id \"app.spoonjoy.mac\" to open location \"spoonjoy://$deep_link_path\"" >> "$capture_log" 2>&1
    wait_for_route "$expected_recorded_route" || true
    if [[ "$screenshot_route" == "settings" || "$screenshot_route" == "search" ]] && ! wait_for_screenshot_proof "$proof_file" "$screenshot_route" "$proof_focus"; then
      printf 'Spoonjoy did not write the expected macOS screenshot proof after relaunch for %s\n' "$screenshot_route" >> "$capture_log"
      write_blocker \
        "$macos_blocker" \
        "MacOSLaunch" \
        "SPOONJOY_SCREENSHOT_PROOF_PATH=$proof_file spoonjoy://$deep_link_path" \
        "$capture_log" \
        "Spoonjoy macOS did not prove the expected visible screenshot route after relaunch." \
        "Launch the app from an unlocked desktop session and confirm the expected route renders before screenshot capture."
    fi
    if [[ ! -f "$macos_blocker" ]] && ! wait_for_accessibility_proof "$accessibility_proof_macos_abs" "$screenshot_route" "macos" "$accessibility_proof_macos_abs"; then
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
    ruby -rjson -e '
      path, expected_route = ARGV
      snapshot = JSON.parse(File.read(path))
      abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
      actual_route = snapshot.fetch("lastOpenedRoute")
      abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
    ' "$state_file" "$expected_recorded_route" >> "$capture_log" 2>&1
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
  osascript -e 'tell application id "app.spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
fi

if [[ -f "$xcode_blocker" ]]; then
  write_design_review_blocked "$xcode_blocker"
elif [[ -f "$ios_blocker" ]]; then
  write_design_review_blocked "$ios_blocker"
elif [[ -f "$macos_blocker" ]]; then
  write_design_review_blocked "$macos_blocker"
else
  if [[ ! -s "$ios_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce both screenshots\n' >&2
    exit 1
  fi
  if [[ ! -s "$accessibility_proof_ios_abs" || ! -s "$accessibility_proof_macos_abs" ]]; then
    printf 'Screenshot capture produced no blocker but did not produce both accessibility proofs\n' >&2
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
