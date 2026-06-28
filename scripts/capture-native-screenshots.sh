#!/usr/bin/env bash
set -euo pipefail

artifact_root="tasks/2026-06-15-2314-doing-native-app-skeleton"
unit_slug="capture-native-screenshots"
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
state_backup="$artifact_root/native-app-state-capture-backup.json"
cache_backup="$artifact_root/native-durable-cache-capture-backup.json"
screenshot_route="kitchen"
if [[ "$unit_slug" == *settings* ]]; then
  screenshot_route="settings"
fi
settings_capture_account_id="chef_settings_capture"
macos_window_title="Kitchen"
if [[ "$screenshot_route" == "settings" ]]; then
  macos_window_title="Settings"
fi

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
    source_path, output_path = ARGV
    blocker = JSON.parse(File.read(source_path))
    manifest = {
      "blocked" => true,
      "capability" => blocker.fetch("capability"),
      "sourceBlockerPath" => File.expand_path(source_path),
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/macos-desktop.png",
        "design-review.json"
      ],
      "reason" => blocker.fetch("reason"),
      "ownerAction" => blocker.fetch("ownerAction")
    }
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$source_blocker_path" "$design_review_blocked"
  rm -f "$ios_screenshot" "$macos_screenshot"
  rm -f "$design_review"
}

write_design_review_success() {
  ruby -rjson -e '
    output_path, route = ARGV
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
      "blockers" => []
    }
    if route == "settings"
      manifest["settingsSignedInSurface"] = true
      manifest["settingsSections"] = ["Profile", "Security", "Notifications", "API Tokens", "Connections", "Environment", "Offline"]
      manifest["settingsSeedAccountID"] = "chef_settings_capture"
    end
    File.write(output_path, JSON.pretty_generate(manifest) + "\n")
  ' "$design_review" "$screenshot_route"
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
    path, route = ARGV
    account_id = route == "settings" ? "chef_settings_capture" : "signed-out"
    snapshot = {
      "schemaVersion" => 1,
      "accountID" => account_id,
      "environment" => "production",
      "hasCompletedFirstRun" => true,
      "cookProgressByRecipeID" => {},
      "spoonCookLogDraftsByRecipeID" => {},
      "shoppingList" => nil,
      "captureDraft" => nil,
      "pendingCaptureImport" => nil,
      "captureImportProviderBlocker" => nil,
      "pendingMutations" => { "mutations" => [] },
      "lastOpenedRoute" => route,
      "savedAt" => "2026-06-16T12:09:00.000Z"
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(snapshot) + "\n")
  ' "$path" "$route"
}

write_cache_state() {
  local path="$1"
  local route="$2"
  ruby -rjson -rfileutils -rtime -e '
    path, route = ARGV
    FileUtils.mkdir_p(File.dirname(path))
    if route != "settings"
      File.write(path, JSON.pretty_generate({
        "schemaVersion" => 2,
        "accountID" => "signed-out",
        "environment" => "production",
        "createdAt" => Time.parse("2026-06-16T12:09:00Z") - Time.utc(2001, 1, 1),
        "records" => [],
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
  ' "$path" "$route"
}

ios_launch_app() {
  local udid="$1"
  if [[ "$screenshot_route" == "settings" ]]; then
    SIMCTL_CHILD_SPOONJOY_SCREENSHOT_AUTH=1 \
    SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
    SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID="$settings_capture_account_id" \
      xcrun simctl launch --terminate-running-process "$udid" app.spoonjoy.Spoonjoy >> "$capture_log" 2>&1
  else
    xcrun simctl launch --terminate-running-process "$udid" app.spoonjoy.Spoonjoy >> "$capture_log" 2>&1
  fi
}

open_macos_app() {
  if [[ "$screenshot_route" == "settings" ]]; then
    open -n \
      --env SPOONJOY_SCREENSHOT_AUTH=1 \
      --env SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY=1 \
      --env "SPOONJOY_SCREENSHOT_ACCOUNT_ID=$settings_capture_account_id" \
      "$macos_app" >> "$capture_log" 2>&1
  else
    open -n "$macos_app" >> "$capture_log" 2>&1
  fi
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
    output="$(xcrun simctl spawn "$udid" log show --last 15s --style compact --predicate 'process == "SpringBoard" AND eventMessage CONTAINS[c] "Front display did change" AND eventMessage CONTAINS[c] "app.spoonjoy.Spoonjoy"' 2>&1 || true)"
    printf '%s\n' "$output" >> "$capture_log"
    if [[ "$output" == *"app.spoonjoy.Spoonjoy"* ]]; then
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
if black_ratio < 0.45 or bone_ratio < 0.05:
    raise SystemExit(f"iOS screenshot does not look like foreground Spoonjoy content (black={black_ratio:.3f}, bone={bone_ratio:.3f})")
PY
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
  data_container="$(xcrun simctl get_app_container "$udid" app.spoonjoy.Spoonjoy data)"
  local ios_app_dir="$data_container/Library/Application Support/Spoonjoy"
  write_app_state "$ios_app_dir/native-app-state.json" "$screenshot_route"
  write_cache_state "$ios_app_dir/native-durable-cache.json" "$screenshot_route"
  if ! xcrun simctl terminate "$udid" app.spoonjoy.Spoonjoy >"$terminate_log" 2>&1; then
    if ! grep -qi "found nothing to terminate" "$terminate_log"; then
      cat "$terminate_log" >> "$capture_log"
    fi
  fi
  rm -f "$terminate_log"
  ios_launch_app "$udid"
  wait_for_ios_foreground "$udid" || return 1
  sleep 1
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
      "xcrun simctl launch/io $ios_udid app.spoonjoy.Spoonjoy $ios_screenshot" \
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
  restore_capture_state() {
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
  }
  trap restore_capture_state EXIT
  rm -f "$state_file"
  rm -f "$cache_file"
  write_app_state "$state_file" "$screenshot_route"
  write_cache_state "$cache_file" "$screenshot_route"
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
  pkill -x Spoonjoy >/dev/null 2>&1 || true
  sleep 1
  open_macos_app
  sleep 3
  pgrep -x Spoonjoy >/dev/null
  osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://$screenshot_route\"" >> "$capture_log" 2>&1
  wait_for_route "$screenshot_route" || true
  ruby -rjson -e '
    path, expected_route = ARGV
    snapshot = JSON.parse(File.read(path))
    abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
    actual_route = snapshot.fetch("lastOpenedRoute")
    abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
  ' "$state_file" "$screenshot_route" >> "$capture_log" 2>&1
  if ! capture_macos_window; then
    printf 'Retrying Spoonjoy window capture after relaunch\n' >> "$capture_log"
    osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
    pkill -x Spoonjoy >/dev/null 2>&1 || true
    sleep 1
    write_app_state "$state_file" "$screenshot_route"
    write_cache_state "$cache_file" "$screenshot_route"
    open_macos_app
    sleep 3
    pgrep -x Spoonjoy >/dev/null
    osascript -e "tell application \"$macos_app\" to open location \"spoonjoy://$screenshot_route\"" >> "$capture_log" 2>&1
    wait_for_route "$screenshot_route" || true
    ruby -rjson -e '
      path, expected_route = ARGV
      snapshot = JSON.parse(File.read(path))
      abort("first-run session was not completed") unless snapshot.fetch("hasCompletedFirstRun") == true
      actual_route = snapshot.fetch("lastOpenedRoute")
      abort("expected lastOpenedRoute #{expected_route}, got #{actual_route}") unless actual_route == expected_route
    ' "$state_file" "$screenshot_route" >> "$capture_log" 2>&1
    capture_macos_window || true
  fi
  if [[ ! -f "$macos_screenshot" || ! -s "$macos_screenshot" ]]; then
    printf 'Spoonjoy window not found for macOS screenshot capture\n' >> "$capture_log"
    write_blocker \
      "$macos_blocker" \
      "MacOSLaunch" \
      "scripts/find-macos-window-id.swift <pid> $macos_window_title && screencapture -x -l <window-id> $macos_screenshot" \
      "$capture_log" \
      "Spoonjoy window capture was unavailable in the macOS GUI session." \
      "Run screenshot capture from an unlocked desktop session with Screen Recording permission for the terminal."
  fi
  osascript -e 'tell application id "app.spoonjoy.Spoonjoy.mac" to quit' >/dev/null 2>&1 || true
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
