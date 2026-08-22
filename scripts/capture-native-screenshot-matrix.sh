#!/usr/bin/env bash
set -euo pipefail

artifact_root="${SPOONJOY_NATIVE_ARTIFACT_ROOT:-artifacts/apple/native-screenshot-matrix}"
unit_slug="matrix"
resume_matrix=0
batch_size="${SPOONJOY_SCREENSHOT_MATRIX_BATCH_SIZE:-0}"

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
    --resume)
      resume_matrix=1
      shift
      ;;
    --batch-size)
      batch_size="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

apple_dir="$artifact_root/apple"
routes_dir="$artifact_root/screenshot-routes"
shared_build_dir="$artifact_root/shared-builds"
results_path="$apple_dir/${unit_slug}-route-matrix.jsonl"
summary_path="$apple_dir/${unit_slug}-route-matrix.json"
checkpoint_path="$apple_dir/${unit_slug}-route-matrix-checkpoint.json"
route_timeout_seconds="${SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS:-420}"
matrix_build_timeout_seconds="${SPOONJOY_SCREENSHOT_MATRIX_BUILD_TIMEOUT_SECONDS:-900}"
reset_simulator_between_routes="${SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES:-0}"
matrix_routes="${SPOONJOY_SCREENSHOT_MATRIX_ROUTES:-}"
shared_ios_app_path="${SPOONJOY_SCREENSHOT_IOS_APP_PATH:-}"
shared_macos_app_path="${SPOONJOY_SCREENSHOT_MACOS_APP_PATH:-}"
shared_build_blocker="$apple_dir/${unit_slug}-shared-build-blocker.json"
shared_xcode_blocker="$apple_dir/${unit_slug}-shared-xcode-platform-blocker.json"
ios_install_marker="$apple_dir/${unit_slug}-ios-installed.marker"
configured_ios_install_marker="${SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER:-$ios_install_marker}"
matrix_routes="${matrix_routes//[[:space:]]/}"

if ! [[ "$batch_size" =~ ^[0-9]+$ ]]; then
  printf 'Batch size must be a non-negative integer: %s\n' "$batch_size" >&2
  exit 2
fi

if [[ "$resume_matrix" == "1" ]]; then
  [[ -f "$checkpoint_path" ]] || { printf 'Cannot resume without checkpoint: %s\n' "$checkpoint_path" >&2; exit 1; }
  if [[ -z "$shared_ios_app_path" && -d "$shared_build_dir/AppBundles/iOS/Spoonjoy.app" ]]; then
    shared_ios_app_path="$shared_build_dir/AppBundles/iOS/Spoonjoy.app"
  fi
  if [[ -z "$shared_macos_app_path" && -d "$shared_build_dir/AppBundles/macOS/Spoonjoy.app" ]]; then
    shared_macos_app_path="$shared_build_dir/AppBundles/macOS/Spoonjoy.app"
  fi
fi

mkdir -p "$apple_dir" "$routes_dir"
if [[ "$resume_matrix" != "1" ]]; then
  rm -rf "$routes_dir" "$shared_build_dir"
  mkdir -p "$routes_dir"
  rm -f \
    "$results_path" \
    "$summary_path" \
    "$checkpoint_path" \
    "$shared_build_blocker" \
    "$shared_xcode_blocker" \
    "$ios_install_marker" \
    "$ios_install_marker-iphone" \
    "$ios_install_marker-ipad" \
    "$configured_ios_install_marker" \
    "$configured_ios_install_marker-iphone" \
    "$configured_ios_install_marker-ipad"
fi

write_shared_build_blocker() {
  local platform="$1"
  local command="$2"
  local output_path="$3"
  local reason="$4"
  local source_blocker_path="${5:-}"
  ruby -rjson -e '
    path, platform, command, timeout_seconds, output_path, reason, source_blocker_path = ARGV
    blocker = {
      "blocked" => true,
      "capability" => "ScreenshotMatrixSharedBuild",
      "platform" => platform,
      "command" => command,
      "timeoutSeconds" => Integer(timeout_seconds),
      "outputPath" => output_path,
      "reason" => reason,
      "ownerAction" => "Inspect the shared matrix build log or source blocker, fix the app bundle build, and rerun the screenshot route matrix."
    }
    blocker["sourceBlockerPath"] = source_blocker_path unless source_blocker_path.empty?
    File.write(path, JSON.pretty_generate(blocker) + "\n")
  ' "$shared_build_blocker" "$platform" "$command" "$matrix_build_timeout_seconds" "$output_path" "$reason" "$source_blocker_path"
}

prepare_shared_builds() {
  mkdir -p "$shared_build_dir"

  if [[ -z "$shared_ios_app_path" ]]; then
    local ios_derived="$shared_build_dir/DerivedData-iOS"
    local ios_log="$apple_dir/${unit_slug}-shared-ios-xcodebuild.log"
    local ios_command="xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy iOS -configuration BootstrapDebug -destination generic/platform=iOS Simulator -derivedDataPath $ios_derived CODE_SIGNING_ALLOWED=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
    printf 'building shared iOS simulator app for route matrix\n'
    set +e
    scripts/run-xcodebuild-with-blocker.sh \
      --output "$ios_log" \
      --blocker "$shared_xcode_blocker" \
      --timeout-seconds "$matrix_build_timeout_seconds" \
      -- \
      xcodebuild \
      -project Spoonjoy.xcodeproj \
      -scheme "Spoonjoy iOS" \
      -configuration BootstrapDebug \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "$ios_derived" \
      CODE_SIGNING_ALLOWED=NO \
      GCC_TREAT_WARNINGS_AS_ERRORS=YES \
      build
    local ios_status=$?
    set -e
    if [[ -f "$shared_xcode_blocker" ]]; then
      write_shared_build_blocker "ios" "$ios_command" "$ios_log" "Local Xcode platform state blocked the shared iOS screenshot matrix build." "$shared_xcode_blocker"
      return 1
    fi
    if [[ "$ios_status" -ne 0 ]]; then
      write_shared_build_blocker "ios" "$ios_command" "$ios_log" "The shared iOS screenshot matrix build failed."
      return 1
    fi
    shared_ios_app_path="$ios_derived/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
  fi

  if [[ ! -d "$shared_ios_app_path" ]]; then
    write_shared_build_blocker "ios" "SPOONJOY_SCREENSHOT_IOS_APP_PATH=$shared_ios_app_path" "$apple_dir/${unit_slug}-shared-ios-xcodebuild.log" "The shared iOS simulator app bundle is missing."
    return 1
  fi
  if [[ "$shared_ios_app_path" == "$shared_build_dir"/DerivedData-* || "$shared_ios_app_path" == "$artifact_root"/validation-builds/DerivedData-* ]]; then
    local compact_ios="$shared_build_dir/AppBundles/iOS/Spoonjoy.app"
    mkdir -p "$(dirname "$compact_ios")"
    rm -rf "$compact_ios"
    ditto "$shared_ios_app_path" "$compact_ios"
    shared_ios_app_path="$compact_ios"
    rm -rf "$shared_build_dir/DerivedData-iOS" "$artifact_root/validation-builds/DerivedData-iOS"
  fi

  if [[ -z "$shared_macos_app_path" ]]; then
    local macos_derived="$shared_build_dir/DerivedData-macOS"
    local macos_log="$apple_dir/${unit_slug}-shared-macos-xcodebuild.log"
    local macos_command="xcodebuild -project Spoonjoy.xcodeproj -scheme Spoonjoy macOS -configuration BootstrapDebug -destination generic/platform=macOS -derivedDataPath $macos_derived GCC_TREAT_WARNINGS_AS_ERRORS=YES build"
    printf 'building shared macOS app for route matrix\n'
    set +e
    scripts/run-xcodebuild-with-blocker.sh \
      --output "$macos_log" \
      --blocker "$shared_xcode_blocker" \
      --timeout-seconds "$matrix_build_timeout_seconds" \
      -- \
      xcodebuild \
      -project Spoonjoy.xcodeproj \
      -scheme "Spoonjoy macOS" \
      -configuration BootstrapDebug \
      -destination "generic/platform=macOS" \
      -derivedDataPath "$macos_derived" \
      GCC_TREAT_WARNINGS_AS_ERRORS=YES \
      build
    local macos_status=$?
    set -e
    if [[ -f "$shared_xcode_blocker" ]]; then
      write_shared_build_blocker "macos" "$macos_command" "$macos_log" "Local Xcode platform state blocked the shared macOS screenshot matrix build." "$shared_xcode_blocker"
      return 1
    fi
    if [[ "$macos_status" -ne 0 ]]; then
      write_shared_build_blocker "macos" "$macos_command" "$macos_log" "The shared macOS screenshot matrix build failed."
      return 1
    fi
    shared_macos_app_path="$macos_derived/Build/Products/BootstrapDebug/Spoonjoy.app"
  fi

  if [[ ! -d "$shared_macos_app_path" ]]; then
    write_shared_build_blocker "macos" "SPOONJOY_SCREENSHOT_MACOS_APP_PATH=$shared_macos_app_path" "$apple_dir/${unit_slug}-shared-macos-xcodebuild.log" "The shared macOS app bundle is missing."
    return 1
  fi
  if [[ "$shared_macos_app_path" == "$shared_build_dir"/DerivedData-* || "$shared_macos_app_path" == "$artifact_root"/validation-builds/DerivedData-* ]]; then
    local compact_macos="$shared_build_dir/AppBundles/macOS/Spoonjoy.app"
    mkdir -p "$(dirname "$compact_macos")"
    rm -rf "$compact_macos"
    ditto "$shared_macos_app_path" "$compact_macos"
    shared_macos_app_path="$compact_macos"
    rm -rf "$shared_build_dir/DerivedData-macOS" "$artifact_root/validation-builds/DerivedData-macOS"
  fi

  export SPOONJOY_SCREENSHOT_IOS_APP_PATH="$shared_ios_app_path"
  export SPOONJOY_SCREENSHOT_MACOS_APP_PATH="$shared_macos_app_path"
  export SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP="${SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP:-1}"
  export SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER="$configured_ios_install_marker"
  printf 'route matrix using shared iOS app: %s\n' "$SPOONJOY_SCREENSHOT_IOS_APP_PATH"
  printf 'route matrix using shared macOS app: %s\n' "$SPOONJOY_SCREENSHOT_MACOS_APP_PATH"
}

source_identity() {
  if [[ -n "${SPOONJOY_SCREENSHOT_MATRIX_BUILD_IDENTITY:-}" ]]; then
    printf '%s' "$SPOONJOY_SCREENSHOT_MATRIX_BUILD_IDENTITY"
    return
  fi
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --quiet && git diff --cached --quiet || {
      printf 'Screenshot matrix requires a clean tracked worktree for an exact build identity.\n' >&2
      return 1
    }
    if [[ -n "$(git ls-files --others --exclude-standard -- Sources Apps Tests scripts Package.swift Project.swift Project.yml)" ]]; then
      printf 'Screenshot matrix requires source and validation paths to contain no untracked files.\n' >&2
      return 1
    fi
    git rev-parse HEAD
    return
  fi
  shasum -a 256 scripts/capture-native-screenshot-matrix.sh | awk '{print $1}'
}

bundle_digest() {
  local bundle_path="$1"
  find "$bundle_path" -type f -print0 \
    | sort -z \
    | xargs -0 shasum -a 256 \
    | shasum -a 256 \
    | awk '{print $1}'
}

matrix_build_identity() {
  local source_id="$1"
  local ios_digest macos_digest
  ios_digest="$(bundle_digest "$shared_ios_app_path")"
  macos_digest="$(bundle_digest "$shared_macos_app_path")"
  printf '%s\n%s\n%s\n' "$source_id" "$ios_digest" "$macos_digest" | shasum -a 256 | awk '{print $1}'
}

write_or_validate_checkpoint() {
  local source_id="$1"
  local build_id="$2"
  local expected_routes="$3"
  ruby -rjson -rtime -e '
    path, resume_value, source_id, build_id, expected_csv = ARGV
    expected = expected_csv.split(",").reject(&:empty?)
    if resume_value == "1"
      checkpoint = JSON.parse(File.read(path))
      expected_keys = %w[schemaVersion sourceIdentity buildIdentity expectedRoutes completedRoutes completedRouteDigests createdAt updatedAt]
      abort("checkpoint schema changed") unless checkpoint["schemaVersion"] == 2
      abort("checkpoint fields changed") unless checkpoint.keys.sort == expected_keys.sort
      abort("checkpoint completedRouteDigests must be an object") unless checkpoint["completedRouteDigests"].is_a?(Hash)
      abort("checkpoint source identity changed") unless checkpoint["sourceIdentity"] == source_id
      abort("checkpoint build identity changed") unless checkpoint["buildIdentity"] == build_id
      abort("checkpoint route selection changed") unless checkpoint["expectedRoutes"] == expected
    else
      checkpoint = {
        "schemaVersion" => 2,
        "sourceIdentity" => source_id,
        "buildIdentity" => build_id,
        "expectedRoutes" => expected,
        "completedRoutes" => [],
        "completedRouteDigests" => {},
        "createdAt" => Time.now.utc.iso8601,
        "updatedAt" => Time.now.utc.iso8601
      }
      temporary = "#{path}.tmp-#{Process.pid}"
      File.write(temporary, JSON.pretty_generate(checkpoint) + "\n")
      File.rename(temporary, path)
    end
  ' "$checkpoint_path" "$resume_matrix" "$source_id" "$build_id" "$expected_routes"
}

route_is_complete() {
  local name="$1"
  ruby scripts/validate-native-route-evidence.rb \
    --artifact-root "$artifact_root" \
    --name "$name" \
    --results-jsonl "$results_path" \
    --checkpoint "$checkpoint_path" >/dev/null 2>&1
}

update_checkpoint_progress() {
  local name="$1"
  ruby -rdigest -rjson -rtime -e '
    checkpoint_path, results_path, name = ARGV
    checkpoint = JSON.parse(File.read(checkpoint_path))
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    matching = rows.select { |row| row["name"] == name }
    abort("results must contain exactly one row for #{name}") unless matching.length == 1
    row = matching.first
    digests = checkpoint.fetch("completedRouteDigests")
    if row["status"] == "pass"
      digests[name] = Digest::SHA256.hexdigest(JSON.generate(row))
    else
      digests.delete(name)
    end
    checkpoint["completedRoutes"] = checkpoint.fetch("expectedRoutes").select { |route_name| digests.key?(route_name) }
    checkpoint["updatedAt"] = Time.now.utc.iso8601
    temporary = "#{checkpoint_path}.tmp-#{Process.pid}"
    File.write(temporary, JSON.pretty_generate(checkpoint) + "\n")
    File.rename(temporary, checkpoint_path)
  ' "$checkpoint_path" "$results_path" "$name"
}

prune_task_transients() {
  find "$routes_dir" -type d -name 'DerivedData-*' -prune -exec rm -rf {} +
  rm -f \
    "$configured_ios_install_marker" \
    "$configured_ios_install_marker-iphone" \
    "$configured_ios_install_marker-ipad"
}

record_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local status="$4"
  local command="$5"
  ruby -rdigest -rjson -e '
    results_path, name, route, route_root, status, command = ARGV
    def artifact(path, relative_path)
      absolute = File.join(path, relative_path)
      {
        "path" => absolute,
        "exists" => File.file?(absolute),
        "bytes" => File.file?(absolute) ? File.size(absolute) : nil,
        "sha256" => File.file?(absolute) ? Digest::SHA256.file(absolute).hexdigest : nil
      }
    end
    design_review = artifact(route_root, "design-review.json")
    design_review_blocked = artifact(route_root, "design-review-blocked.json")
    accessibility_proofs = if design_review.fetch("exists")
      JSON.parse(File.read(design_review.fetch("path"))).fetch("accessibilityProofArtifacts", []).map do |relative_path|
        artifact(route_root, relative_path)
      end
    else
      []
    end
    row = {
      "name" => name,
      "route" => route,
      "artifactRoot" => route_root,
      "status" => status,
      "command" => command,
      "blocked" => design_review_blocked.fetch("exists"),
      "missingDesignReview" => !design_review.fetch("exists") && !design_review_blocked.fetch("exists"),
      "designReview" => design_review,
      "designReviewBlocked" => design_review_blocked,
      "accessibilityProofs" => accessibility_proofs,
      "iosScreenshot" => artifact(route_root, "screenshots/ios-mobile.png"),
      "iosTabletScreenshot" => artifact(route_root, "screenshots/ios-tablet.png"),
      "macosScreenshot" => artifact(route_root, "screenshots/macos-desktop.png")
    }
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    rows.reject! { |candidate| candidate["name"] == name }
    rows << row
    temporary = "#{results_path}.tmp-#{Process.pid}"
    File.write(temporary, rows.map { |candidate| JSON.generate(candidate) }.join("\n") + "\n")
    File.rename(temporary, results_path)
  ' "$results_path" "$name" "$route" "$route_root" "$status" "$command"
}

write_route_timeout_blocker() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
  local command="$5"
  local output_path="$6"
  mkdir -p "$route_root/apple"
  ruby -rjson -rfileutils -e '
    name, route, route_root, route_slug, command, output_path, timeout_seconds = ARGV
    source_path = File.join(route_root, "apple/#{route_slug}-screenshot-route-timeout-blocker.json")
    review_path = File.join(route_root, "design-review-blocked.json")
    reason = "Screenshot route #{name} exceeded #{timeout_seconds} seconds before producing terminal screenshot artifacts."
    owner_action = "Inspect the route capture log and fix the local screenshot harness or app launch hang, then rerun the screenshot route matrix."
    source_blocker = {
      "blocked" => true,
      "capability" => "ScreenshotRouteTimeout",
      "route" => route,
      "command" => command,
      "timeoutSeconds" => Integer(timeout_seconds),
      "outputPath" => output_path,
      "reason" => reason,
      "ownerAction" => owner_action
    }
    design_review_blocked = {
      "blocked" => true,
      "capability" => "ScreenshotRouteTimeout",
      "sourceBlockerPath" => source_path,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/ios-tablet.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/#{route_slug}-accessibility-proof-ios.json",
        "apple/#{route_slug}-accessibility-proof-ipad.json",
        "apple/#{route_slug}-accessibility-proof-macos.json"
      ],
      "reason" => reason,
      "ownerAction" => owner_action,
      "timeoutSeconds" => Integer(timeout_seconds)
    }
    FileUtils.mkdir_p(File.dirname(source_path))
    File.write(source_path, JSON.pretty_generate(source_blocker) + "\n")
    File.write(review_path, JSON.pretty_generate(design_review_blocked) + "\n")
  ' "$name" "$route" "$route_root" "$route_slug" "$command" "$output_path" "$route_timeout_seconds"
  rm -f "$route_root/screenshots/ios-mobile.png" "$route_root/screenshots/ios-tablet.png" "$route_root/screenshots/macos-desktop.png"
  rm -f "$route_root/design-review.json"
  rm -f "$route_root/apple/${route_slug}-accessibility-proof-ios.json" "$route_root/apple/${route_slug}-accessibility-proof-ipad.json" "$route_root/apple/${route_slug}-accessibility-proof-macos.json"
}

run_route_capture_with_timeout() {
  local output_path="$1"
  shift
  python3 - "$route_timeout_seconds" "$output_path" "$@" <<'PY'
import os
import signal
import subprocess
import sys
import time

timeout_seconds = int(sys.argv[1])
output_path = sys.argv[2]
command = sys.argv[3:]

with open(output_path, "wb") as output:
    process = subprocess.Popen(
        command,
        stdout=output,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        sys.exit(process.wait(timeout=timeout_seconds))
    except subprocess.TimeoutExpired:
        output.write(f"\nCommand timed out after {timeout_seconds} seconds\n".encode())
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

summarize_routes() {
  ruby -rjson -rtime -e '
    results_path, summary_path, shared_build_blocker_path, expected_csv, build_identity, artifact_root, checkpoint_path = ARGV
    expected = expected_csv.split(",").reject(&:empty?)
    rows = File.file?(results_path) ? File.readlines(results_path).map { |line| JSON.parse(line) } : []
    missing = rows.select { |row| row["missingDesignReview"] }
    blocked = rows.select { |row| row["blocked"] }
    failed = rows.select { |row| row["status"] != "pass" }
    invalid_evidence = rows.select do |row|
      !system(
        "ruby", "scripts/validate-native-route-evidence.rb",
        "--artifact-root", artifact_root,
        "--name", row.fetch("name", ""),
        "--results-jsonl", results_path,
        "--checkpoint", checkpoint_path,
        out: File::NULL, err: File::NULL
      )
    end
    names = rows.map { |row| row["name"] }
    name_counts = names.each_with_object(Hash.new(0)) { |name, counts| counts[name] += 1 }
    duplicate_names = name_counts.select { |_, count| count != 1 }.keys
    missing_routes = expected - names
    unexpected_routes = names - expected
    incomplete = missing_routes.any?
    build_blocker = File.file?(shared_build_blocker_path) ? JSON.parse(File.read(shared_build_blocker_path)) : nil
    exact_manifest = duplicate_names.empty? && missing_routes.empty? && unexpected_routes.empty? && rows.length == expected.length
    ok = !rows.empty? && exact_manifest && build_blocker.nil? && missing.empty? && blocked.empty? && failed.empty? && invalid_evidence.empty?
    summary = JSON.pretty_generate({
      "ok" => ok,
      "fullyValidated" => ok,
      "incomplete" => incomplete,
      "generatedAt" => Time.now.utc.iso8601,
      "buildIdentity" => build_identity,
      "routeCount" => rows.length,
      "expectedRouteCount" => expected.length,
      "expectedRoutes" => expected,
      "missingRoutes" => missing_routes,
      "duplicateRoutes" => duplicate_names,
      "unexpectedRoutes" => unexpected_routes,
      "buildBlocked" => !build_blocker.nil?,
      "buildBlocker" => build_blocker,
      "routes" => rows,
      "failedRoutes" => failed.map { |row| row["name"] },
      "invalidEvidenceRoutes" => invalid_evidence.map { |row| row["name"] },
      "blockedRoutes" => blocked.map { |row| row["name"] },
      "missingDesignReviewRoutes" => missing.map { |row| row["name"] }
    }) + "\n"
    temporary = "#{summary_path}.tmp-#{Process.pid}"
    File.write(temporary, summary)
    File.rename(temporary, summary_path)
    exit(ok ? 0 : (incomplete && build_blocker.nil? && missing.empty? && blocked.empty? && failed.empty? && invalid_evidence.empty? ? 75 : 1))
  ' "$results_path" "$summary_path" "$shared_build_blocker" "$expected_route_names" "$build_identity" "$artifact_root" "$checkpoint_path"
}

capture_route() {
  local name="$1"
  local route="$2"
  local route_root="$3"
  local route_slug="$4"
  local command="SPOONJOY_SCREENSHOT_IOS_APP_PATH=$SPOONJOY_SCREENSHOT_IOS_APP_PATH SPOONJOY_SCREENSHOT_MACOS_APP_PATH=$SPOONJOY_SCREENSHOT_MACOS_APP_PATH scripts/capture-native-screenshots.sh --artifact-root $route_root --unit-slug $route_slug --route $route"
  local route_output="$route_root/apple/${route_slug}-screenshot-route.log"
  local command_status=0
  local status="pass"

  mkdir -p "$route_root/apple"
  if [[ "$reset_simulator_between_routes" == "1" ]]; then
    printf 'resetting iOS simulator before route %s\n' "$name"
    xcrun simctl shutdown all >> "$route_output" 2>&1 || true
  fi
  printf 'capturing native route %s (%s)\n' "$name" "$route"
  run_route_capture_with_timeout "$route_output" \
    scripts/capture-native-screenshots.sh --artifact-root "$route_root" --unit-slug "$route_slug" --route "$route" || command_status=$?

  if [[ "$command_status" -eq 124 ]]; then
    write_route_timeout_blocker "$name" "$route" "$route_root" "$route_slug" "$command" "$route_output"
    status="blocked"
  elif [[ -f "$route_root/design-review-blocked.json" ]]; then
    status="blocked"
  elif [[ ! -f "$route_root/design-review.json" ]]; then
    status="fail"
  elif [[ "$command_status" -ne 0 ]]; then
    status="fail"
  fi

  record_route "$name" "$route" "$route_root" "$status" "$command"
  update_checkpoint_progress "$name"
  find "$route_root" -maxdepth 1 -type d -name 'DerivedData-*' -prune -exec rm -rf {} +

  [[ "$status" == "pass" ]]
}

route_is_selected() {
  local name="$1"
  local route="$2"
  if [[ -z "$matrix_routes" ]]; then
    return 0
  fi

  local selected=",$matrix_routes,"
  [[ "$selected" == *",$name,"* || "$selected" == *",$route,"* ]]
}

overall_status=0
routes=(
  "kitchen|kitchen|$artifact_root|$unit_slug"
  "recipes|recipes|$routes_dir/recipes|$unit_slug-recipes"
  "saved-recipes|saved-recipes|$routes_dir/saved-recipes|$unit_slug-saved-recipes"
  "recipe-detail|recipe-detail|$routes_dir/recipe-detail|$unit_slug-recipe-detail"
  "cook-mode|cook-mode|$routes_dir/cook-mode|$unit_slug-cook-mode"
  "cookbooks|cookbooks|$routes_dir/cookbooks|$unit_slug-cookbooks"
  "cookbook-detail|cookbook-detail|$routes_dir/cookbook-detail|$unit_slug-cookbook-detail"
  "shopping-list|shopping-list|$routes_dir/shopping-list|$unit_slug-shopping-list"
  "shopping-list-empty|shopping-list-empty|$routes_dir/shopping-list-empty|$unit_slug-shopping-list-empty"
  "shopping-list-all-complete|shopping-list-all-complete|$routes_dir/shopping-list-all-complete|$unit_slug-shopping-list-all-complete"
  "shopping-list-duplicate|shopping-list-duplicate|$routes_dir/shopping-list-duplicate|$unit_slug-shopping-list-duplicate"
  "shopping-list-conflict|shopping-list-conflict|$routes_dir/shopping-list-conflict|$unit_slug-shopping-list-conflict"
  "shopping-list-offline-queued|shopping-list-offline-queued|$routes_dir/shopping-list-offline-queued|$unit_slug-shopping-list-offline-queued"
  "chefs|chefs|$routes_dir/chefs|$unit_slug-chefs"
  "search|search|$routes_dir/search|$unit_slug-search"
  "search-typed-results|search-typed-results|$routes_dir/search-typed-results|$unit_slug-search-typed-results"
  "search-scoped-recipes|search-scoped-recipes|$routes_dir/search-scoped-recipes|$unit_slug-search-scoped-recipes"
  "search-scoped-cookbooks|search-scoped-cookbooks|$routes_dir/search-scoped-cookbooks|$unit_slug-search-scoped-cookbooks"
  "search-scoped-chefs|search-scoped-chefs|$routes_dir/search-scoped-chefs|$unit_slug-search-scoped-chefs"
  "search-scoped-shopping|search-scoped-shopping|$routes_dir/search-scoped-shopping|$unit_slug-search-scoped-shopping"
  "search-no-results|search-no-results|$routes_dir/search-no-results|$unit_slug-search-no-results"
  "capture|capture|$routes_dir/capture|$unit_slug-capture"
  "capture-empty|capture-empty|$routes_dir/capture-empty|$unit_slug-capture-empty"
  "capture-draft|capture-draft|$routes_dir/capture-draft|$unit_slug-capture-draft"
  "capture-offline-retry|capture-offline-retry|$routes_dir/capture-offline-retry|$unit_slug-capture-offline-retry"
  "capture-provider-blocked|capture-provider-blocked|$routes_dir/capture-provider-blocked|$unit_slug-capture-provider-blocked"
  "capture-signed-out|capture-signed-out|$routes_dir/capture-signed-out|$unit_slug-capture-signed-out"
  "settings|settings|$routes_dir/settings|$unit_slug-settings"
  "settings-notifications|settings|$routes_dir/settings-notifications|$unit_slug-settings-notifications"
  "settings-signed-out|settings|$routes_dir/settings-signed-out|$unit_slug-settings-signed-out"
  "settings-apns-denied|settings|$routes_dir/settings-apns-denied|$unit_slug-settings-apns-denied"
  "settings-apns-not-determined|settings|$routes_dir/settings-apns-not-determined|$unit_slug-settings-apns-not-determined"
  "settings-apns-authorized|settings|$routes_dir/settings-apns-authorized|$unit_slug-settings-apns-authorized"
  "settings-apns-unregistered|settings|$routes_dir/settings-apns-unregistered|$unit_slug-settings-apns-unregistered"
)

selected_routes=()
expected_route_names=""
for entry in "${routes[@]}"; do
  IFS="|" read -r name route _route_root _route_slug <<< "$entry"
  route_is_selected "$name" "$route" || continue
  selected_routes+=("$entry")
  expected_route_names="${expected_route_names:+$expected_route_names,}$name"
done

if [[ "${#selected_routes[@]}" -eq 0 ]]; then
  printf 'Screenshot route selection matched no canonical routes.\n' >&2
  exit 1
fi

source_id="$(source_identity)"
build_identity=""
if prepare_shared_builds; then
  build_identity="$(matrix_build_identity "$source_id")"
  write_or_validate_checkpoint "$source_id" "$build_identity" "$expected_route_names"
  captured_in_batch=0
  for entry in "${selected_routes[@]}"; do
    IFS="|" read -r name route route_root route_slug <<< "$entry"
    if route_is_complete "$name"; then
      printf 'reusing checkpointed route evidence %s (%s)\n' "$name" "$route"
      continue
    fi
    capture_route "$name" "$route" "$route_root" "$route_slug" || overall_status=1
    captured_in_batch=$((captured_in_batch + 1))
    if [[ "$batch_size" -gt 0 && "$captured_in_batch" -ge "$batch_size" ]]; then
      break
    fi
  done
  prune_task_transients
else
  overall_status=1
fi

summary_status=0
summarize_routes || summary_status=$?
if [[ "$summary_status" -eq 75 && "$overall_status" -eq 0 ]]; then
  printf 'native screenshot route matrix batch checkpointed: %s\n' "$checkpoint_path"
  exit 75
fi
if [[ "$summary_status" -ne 0 ]]; then
  overall_status=1
else
  rm -rf "$shared_build_dir" "$artifact_root/validation-builds"
fi
printf 'native screenshot route matrix complete: %s\n' "$summary_path"
exit "$overall_status"
