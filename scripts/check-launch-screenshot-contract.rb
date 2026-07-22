#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require "open3"
require "pathname"
require "rbconfig"
require "shellwords"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
ARTIFACT_ROOT = ROOT.join("artifacts/apple/native-screenshots")
DESIGN_REVIEW = ARTIFACT_ROOT.join("design-review.json")
DESIGN_REVIEW_BLOCKED = ARTIFACT_ROOT.join("design-review-blocked.json")
FIXTURE_PROCESS_TIMEOUT_SECONDS = 120
ENV["SPOONJOY_SMOKE_HOST_SETTLE_SECONDS"] = "0"
ENV["SPOONJOY_SCREENSHOT_IOS_HOST_SETTLE_SECONDS"] = "0"

SCREENSHOT_ARTIFACTS = {
  "iosMobile" => "screenshots/ios-mobile.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility.png",
  "iosTablet" => "screenshots/ios-tablet.png",
  "macosDesktop" => "screenshots/macos-desktop.png"
}.freeze
DEEP_SCROLL_SCREENSHOT_ARTIFACTS = {
  "iosMobile" => "screenshots/ios-mobile-deep-scroll.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility-deep-scroll.png",
  "iosTablet" => "screenshots/ios-tablet-deep-scroll.png"
}.freeze
DEEP_SCROLL_ROUTES = %w[
  kitchen recipes saved-recipes recipe-detail recipe-editor recipe-covers cook-mode cook-log
  cookbooks cookbook-detail shopping-list chefs profile profile-graph search capture settings
].freeze

SCRIPT_CONTRACTS = {
  "scripts/smoke-macos.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--log",
      "--blocker",
      "smoke-macos.log",
      "smoke-macos-blocker.json",
      "apple/${unit_slug}-smoke-macos-inner.log",
      "apple/${unit_slug}-smoke-macos-blocker.json",
      "Spoonjoy.app",
      "SPOONJOY_SCREENSHOT_MACOS_APP_PATH",
      "Using prebuilt macOS app",
      "xcodebuild -project Spoonjoy.xcodeproj",
      "generic/platform=macOS",
      "GCC_TREAT_WARNINGS_AS_ERRORS=YES",
      "open",
      "open location",
      "pkill -x Spoonjoy",
      "spoonjoy://search?q=${route_query}&scope=recipes",
      "lastOpenedRoute",
      "hasCompletedFirstRun",
      "native-app-state.json",
      "MacOSLaunch",
      "ownerAction"
    ]
  },
  "scripts/smoke-ios-simulator.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--log",
      "--blocker",
      "smoke-ios-simulator.log",
      "smoke-ios-simulator-blocker.json",
      "apple/${unit_slug}-smoke-ios-inner.log",
      "apple/${unit_slug}-smoke-ios-simulator-blocker.json",
      "SPOONJOY_SCREENSHOT_IOS_APP_PATH",
      "Using prebuilt iOS simulator app",
      "SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP",
      "SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER",
      "bundle_sha256",
      "Installed app bundle digest matched the exact source bundle and simulator marker",
      "a running registration is not foreground proof",
      "xcrun simctl list runtimes",
      "xcrun simctl boot",
      "open -a Simulator --args -CurrentDeviceUDID",
      "SPOONJOY_SMOKE_HOST_SETTLE_SECONDS",
      "Simulator host foreground readiness",
      "SPOONJOY_SMOKE_BOOT_TIMEOUT_SECONDS",
      "xcrun simctl bootstatus $udid -b",
      "SPOONJOY_SMOKE_REGISTRATION_TIMEOUT_SECONDS",
      "Spoonjoy app registration reached two stable samples",
      "xcrun simctl uninstall",
      "xcrun simctl launch",
      "timeoutSeconds",
      "30",
      "CoreSimulator",
      "PermissionError",
      ".github/scripts/resolve-ios-simulator-destination.py",
      "ownerAction"
    ]
  },
  ".github/scripts/resolve-ios-simulator-destination.py" => {
    syntax: ["python3", "-m", "py_compile"],
    tokens: [
      "SPOONJOY_IOS_SIMULATOR_UDID",
      "SPOONJOY_IOS_SIMULATOR_NAME",
      "preferred_udid",
      "preferred_name",
      "all_available_ios_devices",
      "default_family_matches",
      "state_rank",
      "os.environ",
      "state"
    ]
  },
  "scripts/capture-native-screenshots.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--unit-slug",
      "screenshots/ios-mobile.png",
      "screenshots/ios-mobile-accessibility.png",
      "screenshots/macos-desktop.png",
      "design-review.json",
      "design-review-blocked.json",
      "rm -f \"$ios_screenshot\" \"$ios_accessibility_screenshot\" \"$ios_tablet_screenshot\" \"$macos_screenshot\"",
      "rm -f \"$design_review_blocked\"",
      "rm -f \"$design_review\"",
      "xcrun simctl io",
      "scripts/find-macos-window-id.swift",
      "pgrep -x Spoonjoy",
      "capture_macos_window",
      '--capture-run-nonce "$screenshot_run_nonce"',
      '--readiness-proof-path "$accessibility_proof_macos_abs"',
      '--screenshot-path "$macos_screenshot"',
      "screencapture -x -l",
      "open location",
      "sleep 3",
      "to activate",
      "pkill -x Spoonjoy",
      "Retrying Spoonjoy window capture after relaunch",
      "Spoonjoy window not found for macOS screenshot capture",
      'screenshot_route="kitchen"',
      'screenshot_route="search"',
      'screenshot_route="cookbook-detail"',
      'notification',
      'apns',
      "spoonjoy://$screenshot_route",
      "validate_ios_screenshot",
      "get_app_container",
      "resolve_ios_data_container",
      "simulator app data container lookup failed",
      "native-durable-cache.json",
      "SPOONJOY_SCREENSHOT_AUTH",
      "SPOONJOY_SCREENSHOT_RESTORE_CACHE_ONLY",
      "SPOONJOY_SCREENSHOT_ACCOUNT_ID",
      "SPOONJOY_SCREENSHOT_MACOS_APP_PATH",
      "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS",
      "SPOONJOY_SCREENSHOT_DISABLE_SEARCH_FOCUS",
      "SPOONJOY_SCREENSHOT_PROOF_PATH",
      "SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH",
      "SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_IOS_BOOT_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_IOS_OBSERVER_TIMEOUT_SECONDS:-300",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS:-360",
      "SPOONJOY_SCREENSHOT_MACOS_OBSERVER_PREFLIGHT_TIMEOUT_SECONDS:-5",
      "observer_deadline=$((SECONDS + macos_observer_timeout_seconds))",
      "SPOONJOY_SCREENSHOT_IOS_HOST_SETTLE_SECONDS",
      "Simulator host foreground readiness",
      "SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID",
      "SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID",
      "SPOONJOY_SCREENSHOT_IOS_FOREGROUND_PROBE_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_MACOS_LAUNCH_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_CLEANUP_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_IOS_SMOKE_ATTEMPTS",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS",
      "run_with_timeout",
      "PermissionError",
      "run_ios_smoke",
      "capture_ios_app_with_retries",
      "Reusing simulator booted by smoke preparation",
      "is_transient_screenshot_launch_key",
      "SPOONJOY_SCREENSHOT_*",
      "simulator launch timeout",
      "simulator boot readiness timeout",
      "simulator foreground event stream",
      "log stream",
      "log emit",
      "latest_front_display_event",
      "front_display_event_before_barrier",
      "ios_foreground_interval_is_spoonjoy",
      "wait_for_ios_foreground_barrier",
      "emit_ios_foreground_barrier",
      "start_ios_foreground_stream",
      "stop_ios_foreground_stream",
      "start_new_session=True",
      "signal.signal",
      "spoonjoy-foreground-stream-supervisor-v1",
      'local child_pid_file="${foreground_log}.child-pid"',
      "kill -TERM --",
      "foreground event barrier",
      "Spoonjoy stopped being the front display before screenshot capture",
      "Front display did change",
      "distinct_color_buckets",
      "edge_ratio",
      "open -n -F \"$macos_app\"",
      "macOS launch timeout",
      "proof wait timed out",
      "cleanup timeout",
      "wait_for_accessibility_proof",
      "validate_screenshot_surface_proof",
      "settingsVisualFocus",
      "settingsSurfaceProofArtifacts",
      "visibleSections",
      "settingsSeedAccountID",
      "chef_settings_capture",
      "kitchenSeedAccountID",
      "chef_kitchen_capture",
      "searchScopes",
      "searchSeedAccountID",
      "searchSurfaceProofArtifacts",
      "SearchView",
      "cookbook-detail",
      "CookbookDetailView",
      "cookbookID",
      "cookbook:cookbook_weeknights",
      "cookbooks/cookbook_weeknights",
      "routeIdentifier",
      "chef_search_capture",
      "expected_recorded_route",
      "search:all:",
      "apns-status",
      "device_apns_capture",
      "screenshot-proof-ios.json",
      "screenshot-proof-macos.json",
      "lastOpenedRoute",
      "hasCompletedFirstRun",
      "native-app-state.json",
      "screenshotArtifacts",
      "deepScrollAccessibilityProofArtifacts",
      "accessibility_proof_ios_deep_scroll",
      "apple/${unit_slug}-screenshots.log",
      "screenshots-xcode-platform-blocker.json",
      "screenshots-core-simulator-blocker.json",
      "screenshots-macos-launch-blocker.json",
      "screenshots-macos-accessibility-blocker.json",
      "apple/${unit_slug}-screenshots-xcode-platform-blocker.json",
      "apple/${unit_slug}-screenshots-core-simulator-blocker.json",
      "apple/${unit_slug}-screenshots-macos-launch-blocker.json",
      "apple/${unit_slug}-screenshots-macos-accessibility-blocker.json",
      "sourceBlockerPath",
      "skippedArtifacts",
      "conflicting design review success and blocker artifacts",
      "ownerAction"
    ]
  },
  "scripts/capture-native-screenshot-matrix.sh" => {
    syntax: ["bash", "-n"],
    tokens: [
      "set -euo pipefail",
      "--artifact-root",
      "--unit-slug",
      "record_route",
      "summarize_routes",
      "design-review.json",
      "design-review-blocked.json",
      "SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS",
      "SPOONJOY_SCREENSHOT_MATRIX_BUILD_TIMEOUT_SECONDS",
      '"$ios_install_marker-iphone"',
      '"$ios_install_marker-ipad"',
      "SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES",
      "SPOONJOY_SCREENSHOT_MATRIX_ROUTES",
      "SPOONJOY_SCREENSHOT_IOS_APP_PATH",
      "SPOONJOY_SCREENSHOT_MACOS_APP_PATH",
      "SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST",
      "SPOONJOY_SCREENSHOT_PROVENANCE_RUN_UUID",
      "native-screenshot-provenance.rb build",
      "native-screenshot-provenance.rb verify",
      "provenance_verified_before",
      "provenance_verified_after",
      "provenanceManifestSha256",
      "sourceSha",
      "sourceTree",
      "SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP",
      "SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER",
      "pin_simulator_family",
      ".github/scripts/resolve-ios-simulator-destination.py",
      "export SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID",
      "export SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID",
      'pin_simulator_family "iphone" "iPhone"',
      'pin_simulator_family "ipad" "iPad"',
      "shared-builds",
      "cookbook-detail|cookbook-detail|",
      "timeoutSeconds",
      "ScreenshotRouteTimeout",
      "PermissionError",
      "ownerAction",
      "sourceBlockerPath"
    ]
  },
  "scripts/native-screenshot-provenance.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "source worktree is not clean",
      "--untracked-files=all",
      "HEAD^{tree}",
      "git",
      "archive",
      "shared-builds",
      "matrixRunUUID",
      "buildUUID",
      "sourceSnapshotTreeSha256",
      "xcodebuildArguments",
      "xcodeVersion",
      "sdkVersions",
      "bundleIdentifier",
      "executableSha256",
      "bundleTreeSha256",
      "manifestSha256",
      "seal_tree!",
      "manifest hash mismatch",
      "source HEAD changed",
      "executable hash mismatch",
      "matrix run UUID mismatch",
      "app override does not match the manifest canonical path"
    ]
  },
  "scripts/find-macos-window-id.swift" => {
    syntax: ["swiftc", "-parse"],
    tokens: [
      "CGWindowListCopyWindowInfo",
      "kCGWindowOwnerPID",
      "kCGWindowOwnerName",
      "ownerCandidates",
      "optionOnScreenOnly",
      "excludeDesktopElements",
      "localizedCaseInsensitiveContains",
      "No on-screen layer-0 window found"
    ]
  },
  "scripts/observe-macos-screenshot-evidence.swift" => {
    syntax: ["swiftc", "-parse"],
    tokens: [
      "import CryptoKit",
      "--capture-run-nonce",
      "--readiness-proof-path",
      "--screenshot-path",
      "validateReadinessProof",
      "captureRunNonce",
      "readinessProofSHA256",
      "screenshotSHA256",
      "bundleIdentifier",
      "bundlePath",
      "executablePath",
      "executableSHA256",
      "PID executable path does not match expected executable",
      "macOS screenshot must be a PNG"
    ]
  },
  "scripts/validate-design-review.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "JSON.parse",
      "screenshotArtifacts",
      "accessibilityProofArtifacts",
      "observedAccessibilityEvidenceArtifacts",
      "deepScrollAccessibilityProofArtifacts",
      "deep-scroll readiness artifact",
      "readinessProofSHA256",
      "executableSHA256",
      "screenshotRoute",
      "searchScopes",
      "searchSurfaceProofArtifacts",
      "SearchView",
      "routeIdentifier",
      "cookbook-detail",
      "cookbookID",
      "CookbookDetailView",
      "settingsVisualFocus",
      "settingsSurfaceProofArtifacts",
      "visibleSections",
      "SettingsView",
      "Push Delivery",
      "Notification Sync"
    ]
  },
  "scripts/validate-design-review-blocker.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "JSON.parse",
      "--artifact-root",
      "--unit-slug",
      "blocked",
      "capability",
      "sourceBlockerPath",
      "skippedArtifacts",
      "reason",
      "ownerAction",
      'apple/#{unit_slug}-screenshots-xcode-platform-blocker.json',
      'apple/#{unit_slug}-screenshots-core-simulator-blocker.json',
      'apple/#{unit_slug}-screenshots-macos-launch-blocker.json',
      'apple/#{unit_slug}-screenshots-macos-accessibility-blocker.json',
      "screenshots-xcode-platform-blocker.json",
      "screenshots-core-simulator-blocker.json",
      "screenshots-macos-launch-blocker.json",
      "screenshots-macos-accessibility-blocker.json"
    ]
  },
  "scripts/fail-on-warning.rb" => {
    syntax: ["ruby", "-c"],
    tokens: [
      "warning:",
      "error:",
      "An error was encountered processing the command",
      "Underlying error",
      "failed to",
      "fatal error:",
      "uncaught exception",
      "warnings or error diagnostics found"
    ]
  }
}.freeze

$failures = []

def record_failure(message)
  $failures << message
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

def run_status(*args, env: {}, chdir: ROOT)
  stdout, stderr, status = Open3.capture3(env, *args.map(&:to_s), chdir: chdir.to_s)
  [stdout, stderr, status]
end

PROCESS_TIMEOUT_WRAPPER = <<~'RUBY'
  timeout = Integer(ARGV.shift)
  pid = Process.spawn(*ARGV, pgroup: true)
  begin
    Timeout.timeout(timeout) do
      Process.wait(pid)
      exit($?.exitstatus || 0)
    end
  rescue Timeout::Error
    begin
      Process.kill("TERM", -pid)
    rescue Errno::ESRCH
    end
    sleep 0.2
    begin
      Process.kill("KILL", -pid)
    rescue Errno::ESRCH
    rescue Errno::EPERM
    end
    begin
      Process.wait(pid)
    rescue Errno::ECHILD
    end
    exit 124
  end
RUBY

def assert_status(expected_success, args, label, env: {}, chdir: ROOT)
  stdout, stderr, status = run_status(*args, env: env, chdir: chdir)
  return if status.success? == expected_success

  expected = expected_success ? "succeed" : "fail"
  record_failure("#{label} expected to #{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
end

def write_executable(path, content)
  path.dirname.mkpath
  path.write(content.sub(/\A[ \t]+(?=#!)/, ""))
  FileUtils.chmod("+x", path.to_s)
end

def assert_file(path, label)
  record_failure("#{label} expected #{path} to exist") unless path.file?
end

def assert_missing(path, label)
  return unless path.exist?

  diagnostic = path.file? ? "\nCONTENTS:\n#{path.read}" : ""
  if path.file? && path.extname == ".json"
    begin
      payload = JSON.parse(path.read)
      source_path = payload["sourceBlockerPath"]
      if source_path && File.file?(source_path)
        source_payload = JSON.parse(File.read(source_path))
        output_path = source_payload["outputPath"]
        diagnostic += "\nSOURCE BLOCKER:\n#{JSON.pretty_generate(source_payload)}\n"
        diagnostic += "\nSOURCE OUTPUT:\n#{File.read(output_path)}\n" if output_path && File.file?(output_path)
      end
    rescue JSON::ParserError
      # The original artifact contents above are enough for malformed JSON.
    end
  end
  record_failure("#{label} expected #{path} to be absent#{diagnostic}")
end

def assert_json(path, label)
  assert_file(path, label)
  return {} unless path.file?

  JSON.parse(path.read)
rescue JSON::ParserError => error
  record_failure("#{label} expected valid JSON at #{path}: #{error.message}")
  {}
end

def screenshot_fixture_state_file(script_root, unit_slug, platform, filename)
  script_root.join(
    "ios-container/Library/Application Support/Spoonjoy/screenshot-routes",
    "#{unit_slug}-#{platform}",
    filename
  )
end

def assert_recorded_processes_gone(path, label, from_index: 0)
  pids = path.file? ? path.readlines(chomp: true).drop(from_index).map { |value| Integer(value, exception: false) }.compact : []
  if pids.empty?
    record_failure("#{label} recorded no foreground stream child processes")
    return
  end

  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
  alive = pids
  loop do
    alive = pids.select do |pid|
      output, status = Open3.capture2("ps", "-p", pid.to_s, "-o", "state=")
      status.success? && !output.strip.empty? && !output.strip.start_with?("Z")
    end
    break if alive.empty? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.05
  end
  record_failure("#{label} leaked foreground stream descendants: #{alive.join(", ")}") unless alive.empty?
end

def terminate_recorded_processes(path, from_index: 0)
  return unless path.file?

  path.readlines(chomp: true).drop(from_index).map { |value| Integer(value, exception: false) }.compact.each do |pid|
    begin
      Process.kill("KILL", -pid)
    rescue Errno::ESRCH, Errno::EPERM
    end
    begin
      Process.kill("KILL", pid)
    rescue Errno::ESRCH, Errno::EPERM
    end
  end
end

def accessibility_source(route)
  case route
  when "kitchen"
    "KitchenView"
  when "search"
    "SearchView"
  when "settings"
    "SettingsView"
  when "cookbook-detail"
    "CookbookDetailView"
  when "capture"
    "CaptureDraftView"
  when "recipe-editor"
    "RecipeEditorView"
  when "recipe-covers"
    "RecipeCoverControlsView"
  when "profile"
    "ProfileView"
  when "profile-graph"
    "ProfileGraphList"
  when "unknown-link"
    "ShellPlaceholderView"
  else
    "KitchenView"
  end
end

def add_screenshot_artifacts!(root, manifest)
  root.join("screenshots").mkpath
  manifest["screenshotArtifacts"] = SCREENSHOT_ARTIFACTS.to_h do |name, relative_path|
    path = root.join(relative_path)
    path.write("#{name}-fixture\n")
    [name, {
      "path" => relative_path,
      "bytes" => path.size,
      "sha256" => Digest::SHA256.file(path).hexdigest
    }]
  end
  if DEEP_SCROLL_ROUTES.include?(manifest["screenshotRoute"])
    manifest["deepScrollScreenshotArtifacts"] = DEEP_SCROLL_SCREENSHOT_ARTIFACTS.to_h do |name, relative_path|
      path = root.join(relative_path)
      path.write("#{name}-deep-scroll-fixture\n")
      [name, {
        "path" => relative_path,
        "bytes" => path.size,
        "sha256" => Digest::SHA256.file(path).hexdigest
      }]
    end
  end
end

def add_accessibility_proofs!(root, manifest, stem)
  route = manifest["screenshotRoute"]
  return unless route

  proof_variants = [
    ["apple/#{stem}-accessibility-proof-ios.json", "ios", "large", "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d", 10],
    ["apple/#{stem}-accessibility-proof-ios-ax.json", "ios", "accessibility5", "f62de99c-0067-4c71-9fc5-f7ba5cc27e6c", 20],
    ["apple/#{stem}-accessibility-proof-ipad.json", "ipad", "large", "817a858d-c004-4036-9c1d-d816b97f5d99", 30],
    ["apple/#{stem}-accessibility-proof-macos.json", "macos", "large", "bf3d228e-0f1f-4450-b8dc-e48db62686b6", 40]
  ]
  relative_paths = proof_variants.map(&:first)
  manifest["accessibilityProofArtifacts"] = relative_paths
  readiness_bindings = {}
  proof_variants.each do |relative_path, platform, dynamic_type, capture_run_nonce, readiness_generation|
    proof_path = root.join(relative_path)
    proof_path.dirname.mkpath
    proof_path.write(JSON.pretty_generate(
      "platform" => platform,
      "route" => route,
      "source" => accessibility_source(route),
      "captureRunNonce" => capture_run_nonce,
      "readinessGeneration" => readiness_generation,
      "launchEnvironmentProof" => route == "recipe-covers" ? {"screenshotRecipeCoversFixture" => "action-states"} : {},
      "screenshotStateSnapshotProof" => {
        "stateDirectoryResolved" => true,
        "appSnapshotPresent" => true,
        "appSnapshotJSONReadable" => true,
        "syncSnapshotPresent" => true,
        "syncSnapshotJSONReadable" => true
      },
      "emittedBy" => "SpoonjoyApp",
      "bundleIdentifier" => platform == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy",
      "observedDynamicTypeSize" => dynamic_type,
      "observedReduceMotion" => false,
      "visualReadiness" => {
        "generation" => readiness_generation,
        "expectedMediaCount" => 1,
        "loadedMediaCount" => 1,
        "pendingMediaCount" => 0,
        "failedMediaCount" => 0,
        "blockingIndicatorCount" => 0,
        "isSettled" => true
      }
    ) + "\n")
    observer_suffix = dynamic_type == "large" ? platform : "#{platform}-ax"
    runtime_proof_stem = "native-accessibility-proof.observer-#{observer_suffix}-#{capture_run_nonce}"
    readiness_bindings[[platform, dynamic_type]] = {
      "captureRunNonce" => capture_run_nonce,
      "route" => route,
      "source" => accessibility_source(route),
      "readinessGeneration" => readiness_generation,
      "proofFileName" => "#{runtime_proof_stem}.generation-#{readiness_generation}.json",
      "proofSHA256" => Digest::SHA256.file(proof_path).hexdigest
    }
  end

  deep_readiness_bindings = {}
  if DEEP_SCROLL_ROUTES.include?(route)
    manifest["deepScrollAccessibilityProofArtifacts"] = []
    proof_variants.reject { |_, platform, _, _, _| platform == "macos" }.each do |relative_path, platform, dynamic_type, capture_run_nonce, readiness_generation|
      deep_generation = readiness_generation + 1
      observer_suffix = dynamic_type == "large" ? platform : "#{platform}-ax"
      runtime_proof_stem = "native-accessibility-proof.observer-#{observer_suffix}-#{capture_run_nonce}"
      deep_relative_path = relative_path.sub(/\.json\z/, "-deep-scroll.json")
      initial_payload = JSON.parse(root.join(relative_path).read)
      initial_payload["readinessGeneration"] = deep_generation
      initial_payload.fetch("visualReadiness")["generation"] = deep_generation
      deep_path = root.join(deep_relative_path)
      deep_path.write(JSON.pretty_generate(initial_payload) + "\n")
      manifest["deepScrollAccessibilityProofArtifacts"] << deep_relative_path
      deep_readiness_bindings[[platform, dynamic_type]] = {
        "captureRunNonce" => capture_run_nonce,
        "route" => route,
        "source" => accessibility_source(route),
        "readinessGeneration" => deep_generation,
        "proofFileName" => "#{runtime_proof_stem}.generation-#{deep_generation}.json",
        "proofSHA256" => Digest::SHA256.file(deep_path).hexdigest
      }
    end
  end

  observed_paths = [
    "apple/#{stem}-observed-accessibility-ios.json",
    "apple/#{stem}-observed-accessibility-ios-ax.json",
    "apple/#{stem}-observed-accessibility-ipad.json",
    "apple/#{stem}-observed-accessibility-macos.json"
  ]
  manifest["observedAccessibilityEvidenceArtifacts"] = observed_paths
  manifest["accessibilityContentSizeScreenshot"] = "screenshots/ios-mobile-accessibility.png"
  observed_variants = [
    ["ios", "large"],
    ["ios", "accessibility-extra-extra-extra-large"],
    ["ipad", "large"],
    ["macos", nil]
  ]
  observed_paths.zip(observed_variants).each do |relative_path, (platform, content_size_category)|
    observed_path = root.join(relative_path)
    observed_path.dirname.mkpath
    apns_identifiers = if route == "settings" && manifest["settingsVisualFocus"] == "notifications"
                         [
                           "settings.apns.this-device.heading",
                           "settings.apns.push-delivery.heading",
                           "settings.apns.notification-sync.heading"
                         ]
                       else
                         []
                       end
    required_route_identifiers = {
      "recipe-editor" => ["recipe-editor.title", "recipe-editor.save"],
      "recipe-covers" => [
        "recipe-covers.photo-picker", "recipe-covers.staged-photo-status", "recipe-covers.clear-photo",
        "recipe-covers.save-photo", "recipe-covers.archive.cover_primary"
      ],
      "profile" => ["profile.header"],
      "profile-graph" => ["profile-graph.row.chef_jules"],
      "unknown-link" => ["unknown-link.message"],
      "cook-mode" => ["cook.current-step", "cook.done", "cook.tools"],
      "cook-log" => ["cook-log.note", "cook-log.next-time", "cook-log.photo", "cook-log.submit"]
    }.fetch(route, [])
    terminal_identifier = {
      "kitchen" => "kitchen.cookbook.cookbook_weeknights",
      "recipe-editor" => "recipe-editor.delete",
      "recipe-covers" => "recipe-covers.archive.cover_primary",
      "profile" => "profile.graph.kitchen-visitors"
    }.fetch(route, "fixture.terminal")
    if platform == "macos"
      macos_readiness = readiness_bindings.fetch(["macos", "large"])
      elements = ["fixture.terminal", *required_route_identifiers, *apns_identifiers].uniq.map.with_index do |identifier, index|
        {
          "identifier" => identifier,
          "role" => "AXStaticText",
          "title" => identifier,
          "frame" => { "x" => 10, "y" => 10 + (index * 45), "width" => 120, "height" => 44 },
          "enabled" => true,
          "focused" => false,
          "actions" => []
        }
      end
      observed = {
        "platform" => platform,
        "route" => route,
        "captureRunNonce" => macos_readiness.fetch("captureRunNonce"),
        "readinessProofSHA256" => macos_readiness.fetch("proofSHA256"),
        "screenshotSHA256" => manifest.dig("screenshotArtifacts", "macosDesktop", "sha256"),
        "pid" => 42,
        "bundleIdentifier" => "app.spoonjoy.mac",
        "bundlePath" => "/Applications/Spoonjoy.app",
        "executablePath" => "/Applications/Spoonjoy.app/Contents/MacOS/Spoonjoy",
        "executableSHA256" => "e" * 64,
        "elements" => elements,
        "findings" => []
      }
      if terminal_identifier != "fixture.terminal"
        terminal = {
          "identifier" => terminal_identifier,
          "role" => "AXButton",
          "title" => terminal_identifier,
          "frame" => { "x" => 10, "y" => 40, "width" => 120, "height" => 44 },
          "enabled" => true,
          "focused" => false,
          "actions" => ["AXPress"]
        }
        observed["deepScroll"] = {
          "route" => route,
          "reachedTerminal" => true,
          "scrollAreaIdentifier" => "#{route}.scroll",
          "initialScrollValue" => 0.0,
          "finalScrollValue" => 1.0,
          "contentViewport" => { "x" => 0, "y" => 0, "width" => 200, "height" => 120 },
          "terminalElement" => terminal,
          "findings" => []
        }
      end
    else
      terminal = {
        "identifier" => terminal_identifier,
        "label" => "Terminal",
        "type" => terminal_identifier == "recipe-covers.archive.cover_primary" ? "button" : "staticText",
        "frame" => { "x" => 10, "y" => 40, "width" => 44, "height" => 40 },
        "exists" => true,
        "hittable" => terminal_identifier == "recipe-covers.archive.cover_primary",
        "enabled" => true,
        "focused" => nil
      }
      observed = {
        "platform" => platform,
        "route" => route,
        "viewport" => { "x" => 0, "y" => 0, "width" => 100, "height" => 80 },
        "elements" => [terminal] + [*required_route_identifiers, *apns_identifiers].uniq.map.with_index { |identifier, index|
          {
            "identifier" => identifier,
            "label" => identifier,
            "type" => "staticText",
            "frame" => { "x" => 10, "y" => 10 + (index * 20), "width" => 80, "height" => 18 },
            "exists" => true,
            "hittable" => false,
            "enabled" => true,
            "focused" => nil
          }
        },
        "auditIssues" => [],
        "verifiedContrastFalsePositives" => [],
        "screenshotSHA256" => Digest::SHA256.file(root.join(
          content_size_category == "accessibility-extra-extra-extra-large" ? "screenshots/ios-mobile-accessibility.png" : platform == "ipad" ? "screenshots/ios-tablet.png" : "screenshots/ios-mobile.png"
        )).hexdigest,
        "geometryFindings" => [],
        "observedContentSizeCategory" => content_size_category,
        "observedDynamicTypeSize" => content_size_category == "accessibility-extra-extra-extra-large" ? "accessibility5" : "large",
        "toolLimitations" => []
      }
      observed["readinessHandshake"] = readiness_bindings.fetch([
        platform,
        observed["observedDynamicTypeSize"]
      ])
      if DEEP_SCROLL_ROUTES.include?(route)
        observed["deepScroll"] = {
          "route" => route,
          "reachedTerminal" => true,
          "swipeCount" => 2,
          "contentViewport" => { "x" => 0, "y" => 0, "width" => 100, "height" => 80 },
          "tabBarFrame" => { "x" => 0, "y" => 80, "width" => 100, "height" => 20 },
          "terminalElement" => terminal,
          "findings" => [],
          "auditIssues" => [],
          "verifiedContrastFalsePositives" => [],
          "screenshotSHA256" => Digest::SHA256.file(root.join(
            content_size_category == "accessibility-extra-extra-extra-large" ? "screenshots/ios-mobile-accessibility-deep-scroll.png" : platform == "ipad" ? "screenshots/ios-tablet-deep-scroll.png" : "screenshots/ios-mobile-deep-scroll.png"
          )).hexdigest,
          "observedContentMovement" => true,
          "contentFitsWithoutScrolling" => false,
          "toolLimitations" => []
        }
        observed["deepScroll"]["readinessHandshake"] = deep_readiness_bindings.fetch([
          platform,
          observed["observedDynamicTypeSize"]
        ])
      end
    end
    observed_path.write(JSON.pretty_generate(observed) + "\n")
  end
end

SCRIPT_CONTRACTS.each do |relative_path, contract|
  path = ROOT.join(relative_path)
  unless path.file?
    record_failure("missing #{relative_path}")
    next
  end

  content = path.read
  bad_absolute_path_lines = [
    'app_path="$(pwd)/$app_path"',
    'macos_app="$(pwd)/$macos_app"'
  ]
  if content.lines.map(&:strip).any? { |line| bad_absolute_path_lines.include?(line) }
    record_failure("#{relative_path} must not prefix pwd onto app paths; absolute artifact roots must stay absolute")
  end

  missing_tokens = contract.fetch(:tokens).reject { |token| content.include?(token) }
  record_failure("#{relative_path} missing required tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?

  if relative_path == "scripts/capture-native-screenshots.sh"
    record_failure("#{relative_path} must verify Spoonjoy foreground state before pixel capture") unless content.scan(/ios_foreground_is_spoonjoy/).length >= 2
    record_failure("#{relative_path} must bracket pixel capture and reject every intervening non-Spoonjoy event") unless content.include?("ios_foreground_interval_is_spoonjoy") && content.include?("-pre-") && content.include?("-post-") && content.include?("log emit")
    record_failure("#{relative_path} must not query historical simulator logs for foreground proof") if content.include?("log show")
  end
  if ["scripts/capture-native-screenshots.sh", "scripts/smoke-ios-simulator.sh"].include?(relative_path)
    record_failure("#{relative_path} must not use CoreSimulator's hanging terminate-and-launch composite") if content.include?("--terminate-running-process")
  end

  assert_status(true, [*contract.fetch(:syntax), path], "#{relative_path} syntax")
end

Dir.mktmpdir("spoonjoy-simulator-resolver-contract") do |directory|
  temp_root = Pathname.new(directory)
  bin_dir = temp_root.join("bin")
  bin_dir.mkpath
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$*" == "simctl list devices available --json" ]]; then
      printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{"name":"Spoonjoy Codex Fresh iPhone 17 Pro Max","udid":"DOGFOOD-UDID","state":"Shutdown","isAvailable":true},{"name":"iPhone 17","udid":"IPHONE-UDID","state":"Booted","isAvailable":true},{"name":"iPad Pro 13-inch","udid":"IPAD-UDID","state":"Shutdown","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.watchOS-26-5":[{"name":"Apple Watch","udid":"WATCH-UDID","state":"Shutdown","isAvailable":true}]}}'
      exit 0
    fi
    exit 70
  SH

  explicit_stdout, explicit_stderr, explicit_status = run_status(
    "env",
    "-i",
    "PATH=#{bin_dir}:#{ENV.fetch("PATH")}",
    "SPOONJOY_IOS_SIMULATOR_UDID=DOGFOOD-UDID",
    "python3",
    ROOT.join(".github/scripts/resolve-ios-simulator-destination.py"),
  )
  unless explicit_status.success? && explicit_stdout.strip == "platform=iOS Simulator,id=DOGFOOD-UDID"
    record_failure(
      "simulator resolver must honor explicit available UDIDs even when the simulator name is not prefixed with iPhone\n" \
      "STDOUT:\n#{explicit_stdout}\nSTDERR:\n#{explicit_stderr}"
    )
  end

  default_stdout, default_stderr, default_status = run_status(
    "env",
    "-i",
    "PATH=#{bin_dir}:#{ENV.fetch("PATH")}",
    "python3",
    ROOT.join(".github/scripts/resolve-ios-simulator-destination.py"),
  )
  unless default_status.success? && default_stdout.strip == "platform=iOS Simulator,id=IPHONE-UDID"
    record_failure(
      "simulator resolver default path must keep selecting ordinary iPhone simulator names\n" \
      "STDOUT:\n#{default_stdout}\nSTDERR:\n#{default_stderr}"
    )
  end

  ipad_stdout, ipad_stderr, ipad_status = run_status(
    "env",
    "-i",
    "PATH=#{bin_dir}:#{ENV.fetch("PATH")}",
    "SPOONJOY_IOS_SIMULATOR_FAMILY=ipad",
    "python3",
    ROOT.join(".github/scripts/resolve-ios-simulator-destination.py"),
  )
  unless ipad_status.success? && ipad_stdout.strip == "platform=iOS Simulator,id=IPAD-UDID"
    record_failure(
      "simulator resolver must select an iPad for the tablet capture family\n" \
      "STDOUT:\n#{ipad_stdout}\nSTDERR:\n#{ipad_stderr}"
    )
  end
end

Dir.mktmpdir("spoonjoy-screenshot-matrix-timeout-contract") do |directory|
  temp_root = Pathname.new(directory)
  script_root = temp_root.join("matrix-fixture")
  artifact_root = temp_root.join("artifacts")
  prebuilt_ios_app = temp_root.join("prebuilt-ios/Spoonjoy.app")
  prebuilt_macos_app = temp_root.join("prebuilt-macos/Spoonjoy.app")
  script_root.join("scripts").mkpath
  prebuilt_ios_app.mkpath
  prebuilt_macos_app.mkpath
  FileUtils.cp(ROOT.join("scripts/capture-native-screenshot-matrix.sh"), script_root.join("scripts/capture-native-screenshot-matrix.sh"))
  provenance_manifest = artifact_root.join("apple/unit-contract-screenshot-provenance.json")
  provenance_manifest.dirname.mkpath
  provenance_manifest.write(JSON.pretty_generate({
    "manifestSha256" => "a" * 64,
    "source" => { "sha" => "b" * 40, "tree" => "c" * 40 }
  }) + "\n")
  write_executable(script_root.join("scripts/native-screenshot-provenance.rb"), <<~'RUBY')
    #!/usr/bin/env ruby
    abort("expected verify") unless ARGV.first == "verify"
    puts "native screenshot provenance verified"
  RUBY

  write_executable(script_root.join("scripts/capture-native-transition-evidence.sh"), <<~'RUBY')
    #!/usr/bin/env ruby
    require "digest"
    require "fileutils"
    require "json"

    artifact_root = ARGV.fetch(ARGV.index("--artifact-root") + 1)
    unit_slug = ARGV.fetch(ARGV.index("--unit-slug") + 1)
    provenance = JSON.parse(File.read(ENV.fetch("SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST")))
    log_relative = "apple/#{unit_slug}-transition-evidence.log"
    log_path = File.join(artifact_root, log_relative)
    evidence_path = File.join(artifact_root, "apple/#{unit_slug}-transition-evidence.json")
    FileUtils.mkdir_p(File.dirname(log_path))
    File.write(log_path, "transition fixture passed\n")
    File.write(evidence_path, JSON.pretty_generate({
      "schemaVersion" => 1,
      "ok" => true,
      "sourceSha" => provenance.dig("source", "sha"),
      "sourceTree" => provenance.dig("source", "tree"),
      "contracts" => [
        { "id" => "search-pending-suppresses-empty-state" },
        { "id" => "recipe-publishes-before-cook-history" }
      ],
      "log" => {
        "path" => log_relative,
        "bytes" => File.size(log_path),
        "sha256" => Digest::SHA256.file(log_path).hexdigest
      }
    }) + "\n")
  RUBY

  write_executable(script_root.join("scripts/capture-native-screenshots.sh"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail

    artifact_root=""
    unit_slug=""
    route=""
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
          route="$2"
          shift 2
          ;;
        *)
          exit 2
          ;;
      esac
    done

    mkdir -p "$artifact_root/apple" "$artifact_root/screenshots"
    if [[ "$route" == "recipes" ]]; then
      sleep 10
    fi

    ruby -rjson -e '
      path, route = ARGV
      File.write(path, JSON.pretty_generate({"blockers" => [], "screenshotRoute" => route}) + "\n")
    ' "$artifact_root/design-review.json" "$route"
  SH

  timeout_wrapper = <<~'RUBY'
    timeout = Integer(ARGV.shift)
    pid = Process.spawn(*ARGV, pgroup: true)
    begin
      Timeout.timeout(timeout) do
        Process.wait(pid)
        exit($?.exitstatus || 0)
      end
    rescue Timeout::Error
      begin
        Process.kill("TERM", -pid)
      rescue Errno::ESRCH
      end
      sleep 0.2
      begin
        Process.kill("KILL", -pid)
      rescue Errno::ESRCH
      rescue Errno::EPERM
      end
      begin
        Process.wait(pid)
      rescue Errno::ECHILD
      end
      exit 124
    end
  RUBY

  stdout, stderr, status = run_status(
    "ruby",
    "-rtimeout",
    "-e",
    timeout_wrapper,
    "20",
    "bash",
    "scripts/capture-native-screenshot-matrix.sh",
    "--artifact-root",
    artifact_root,
    "--unit-slug",
    "unit-contract",
    env: {
      "PATH" => ENV.fetch("PATH"),
      "SPOONJOY_SCREENSHOT_ROUTE_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SCREENSHOT_RESET_SIMULATOR_BETWEEN_ROUTES" => "0",
      "SPOONJOY_SCREENSHOT_MATRIX_ROUTES" => "recipes",
      "SPOONJOY_SCREENSHOT_IOS_APP_PATH" => prebuilt_ios_app.to_s,
      "SPOONJOY_SCREENSHOT_MACOS_APP_PATH" => prebuilt_macos_app.to_s,
      "SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST" => provenance_manifest.to_s,
      "SPOONJOY_SCREENSHOT_PROVENANCE_RUN_UUID" => "unit-contract-run",
      "SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID" => "IPHONE-UNIT-UDID",
      "SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID" => "IPAD-UNIT-UDID"
    },
    chdir: script_root
  )

  if status.exitstatus == 124
    record_failure(
      "screenshot matrix route timeout expected terminal blocker artifact, but matrix process timed out\n" \
      "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  else
    summary_path = artifact_root.join("apple/unit-contract-route-matrix.json")
    summary = assert_json(summary_path, "screenshot matrix timeout summary")
    recipes_row = summary.fetch("routes", []).find { |row| row["name"] == "recipes" }
    record_failure("screenshot matrix timeout row missing for recipes route") unless recipes_row
    if recipes_row
      record_failure("screenshot matrix timeout row must be blocked") unless recipes_row["status"] == "blocked"
      record_failure("screenshot matrix timeout row must point at design-review-blocked.json") unless recipes_row.dig("designReviewBlocked", "exists") == true
    end

    blocked_review_path = artifact_root.join("screenshot-routes/recipes/design-review-blocked.json")
    blocked_review = assert_json(blocked_review_path, "screenshot matrix timeout blocked review")
    record_failure("screenshot matrix timeout blocker capability mismatch") unless blocked_review["capability"] == "ScreenshotRouteTimeout"
    record_failure("screenshot matrix timeout blocker missing timeoutSeconds") unless blocked_review["timeoutSeconds"].is_a?(Integer)
    record_failure("screenshot matrix timeout blocker missing ownerAction") unless blocked_review["ownerAction"].is_a?(String) && !blocked_review["ownerAction"].empty?
    record_failure("screenshot matrix timeout blocker missing sourceBlockerPath") unless blocked_review["sourceBlockerPath"].is_a?(String) && !blocked_review["sourceBlockerPath"].empty?
  end
end

validator = ROOT.join("scripts/validate-design-review.rb")
blocker_validator = ROOT.join("scripts/validate-design-review-blocker.rb")

Dir.mktmpdir("spoonjoy-design-review-contract") do |directory|
  temp_root = Pathname.new(directory)
  valid_manifest = {
    "blockers" => [],
    "screenshotRoute" => "kitchen",
    "kitchenSeedAccountID" => "chef_kitchen_capture"
  }
  valid_settings_manifest = {
    "blockers" => [],
    "screenshotRoute" => "settings",
    "settingsVisualFocus" => "notifications",
    "settingsAPNsPermissionState" => "authorized",
    "settingsAPNsRegistrationState" => "registered",
    "settingsSignedOutSurface" => false,
    "settingsSignedOutHandoffSurface" => false,
    "settingsSeedAccountID" => "chef_settings_capture",
    "settingsSections" => ["Profile", "Security", "Notifications", "This Device", "Push Delivery", "Notification Sync", "Agent Access"],
    "settingsSurfaceProofArtifacts" => ["apple/proof-ios.json", "apple/proof-macos.json"]
  }
  valid_profile_settings_manifest = {
    "blockers" => [],
    "screenshotRoute" => "settings",
    "settingsVisualFocus" => "profile",
    "settingsSignedOutSurface" => false,
    "settingsSignedOutHandoffSurface" => false,
    "settingsSeedAccountID" => "chef_settings_capture",
    "settingsSections" => ["Profile", "Security", "Notifications"],
    "settingsSurfaceProofArtifacts" => ["apple/profile-proof-ios.json", "apple/profile-proof-macos.json"]
  }
  valid_search_manifest = {
    "blockers" => [],
    "screenshotRoute" => "search",
    "searchScopes" => ["all", "recipes", "cookbooks", "chefs", "shopping-list"],
    "searchSeedAccountID" => "chef_search_capture",
    "searchSurfaceVariant" => "blank",
    "expectedQuery" => "",
    "expectedScope" => "all",
    "expectedRouteIdentifier" => "search:all:",
    "searchSurfaceProofArtifacts" => ["apple/search-proof-ios.json", "apple/search-proof-macos.json"]
  }
  valid_cookbook_detail_manifest = {
    "blockers" => [],
    "screenshotRoute" => "cookbook-detail",
    "cookbookSeedAccountID" => "chef_kitchen_capture",
    "cookbookID" => "cookbook_weeknights",
    "renderedSurfaceAnchors" => ["cookbookContentsIndex", "cookbookOwnerToolsDisclosure"],
    "cookbookContentsIndex" => true,
    "cookbookOwnerToolsDisclosure" => true
  }
  valid_recipe_editor_manifest = {
    "blockers" => [],
    "screenshotRoute" => "recipe-editor",
    "recipeSeedAccountID" => "chef_ari",
    "recipeID" => "recipe_lemon_pantry_pasta"
  }
  missing_macos_deep_scroll_manifest = valid_recipe_editor_manifest.dup
  missing_manifest = valid_manifest.dup
  false_without_blocker = valid_manifest.merge("mobileScreenshot" => false)
  missing_route_manifest = valid_manifest.reject { |field, _| field == "screenshotRoute" }
  signed_out_kitchen_manifest = valid_manifest.merge("kitchenSeedAccountID" => "")
  missing_search_scope_manifest = valid_search_manifest.merge("searchScopes" => ["all", "recipes"])
  missing_search_proof_manifest = valid_search_manifest.reject { |field, _| field == "searchSurfaceProofArtifacts" }
  stale_search_proof_manifest = valid_search_manifest.merge("searchSurfaceProofArtifacts" => ["apple/stale-search-proof-ios.json", "apple/search-proof-macos.json"])
  wrong_search_proof_manifest = valid_search_manifest.merge("searchSurfaceProofArtifacts" => ["apple/wrong-search-proof-ios.json", "apple/search-proof-macos.json"])
  missing_apns_settings_manifest = valid_settings_manifest.merge("settingsSections" => ["Profile", "Security", "Notifications"])
  wrong_settings_signed_out_surface_manifest = valid_settings_manifest.merge("settingsSignedOutSurface" => true)
  wrong_cookbook_surface_anchors_manifest = valid_cookbook_detail_manifest.merge("renderedSurfaceAnchors" => ["cookbookContentsIndex"])
  macos_cross_run_nonce_manifest = valid_manifest.dup
  macos_cross_run_proof_manifest = valid_manifest.dup
  macos_cross_run_screenshot_manifest = valid_manifest.dup
  macos_wrong_bundle_identity_manifest = valid_manifest.dup
  macos_wrong_executable_identity_manifest = valid_manifest.dup
  missing_deep_readiness_proof_manifest = valid_manifest.dup
  cross_run_deep_readiness_proof_manifest = valid_manifest.dup
  cross_run_deep_readiness_handshake_manifest = valid_manifest.dup
  stale_generic_readiness_filename_manifest = valid_manifest.dup
  false_with_blocker = false_without_blocker.merge(
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30,
        "outputPath" => "artifacts/apple/native-screenshots/smoke-ios-simulator.log",
        "ownerAction" => "Install an available iPhone simulator runtime."
      }
    ]
  )
  desktop_false_with_only_ios_blocker = valid_manifest.merge(
    "desktopScreenshot" => false,
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30,
        "outputPath" => "artifacts/apple/native-screenshots/smoke-ios-simulator.log"
      }
    ]
  )
  bad_blocker = false_without_blocker.merge(
    "blockers" => [
      {
        "capability" => "CoreSimulator",
        "command" => "xcrun simctl boot",
        "timeoutSeconds" => 30
      }
    ]
  )

  {
    "valid.json" => [valid_manifest, true, "valid design review"],
    "valid-search.json" => [valid_search_manifest, true, "valid search design review"],
    "valid-cookbook-detail.json" => [valid_cookbook_detail_manifest, true, "valid cookbook detail design review"],
    "valid-recipe-editor.json" => [valid_recipe_editor_manifest, true, "valid recipe editor design review"],
    "missing-macos-deep-scroll.json" => [missing_macos_deep_scroll_manifest, false, "missing macOS deep-scroll evidence"],
    "valid-settings.json" => [valid_settings_manifest, true, "valid settings design review"],
    "valid-profile-settings.json" => [valid_profile_settings_manifest, true, "valid profile settings design review"],
    "missing.json" => [missing_manifest, false, "missing design review field"],
    "missing-route.json" => [missing_route_manifest, false, "missing screenshot route"],
    "signed-out-kitchen.json" => [signed_out_kitchen_manifest, false, "signed-out kitchen route artifact"],
    "missing-search-scopes.json" => [missing_search_scope_manifest, false, "search route scope artifact"],
    "missing-search-proof.json" => [missing_search_proof_manifest, false, "search route proof artifacts"],
    "stale-search-proof.json" => [stale_search_proof_manifest, false, "stale search route proof artifact"],
    "wrong-search-proof.json" => [wrong_search_proof_manifest, false, "wrong search route proof artifact"],
    "missing-apns-settings.json" => [missing_apns_settings_manifest, false, "settings APNs route artifact"],
    "wrong-settings-signed-out-surface.json" => [wrong_settings_signed_out_surface_manifest, false, "settings signed-out surface mismatch"],
    "wrong-cookbook-surface-anchors.json" => [wrong_cookbook_surface_anchors_manifest, false, "cookbook surface anchor mismatch"],
    "macos-cross-run-nonce.json" => [macos_cross_run_nonce_manifest, false, "macOS cross-run nonce substitution"],
    "macos-cross-run-proof.json" => [macos_cross_run_proof_manifest, false, "macOS cross-run readiness proof substitution"],
    "macos-cross-run-screenshot.json" => [macos_cross_run_screenshot_manifest, false, "macOS cross-run screenshot substitution"],
    "macos-wrong-bundle-identity.json" => [macos_wrong_bundle_identity_manifest, false, "macOS wrong bundle identity"],
    "macos-wrong-executable-identity.json" => [macos_wrong_executable_identity_manifest, false, "macOS wrong executable identity"],
    "missing-deep-readiness-proof.json" => [missing_deep_readiness_proof_manifest, false, "missing deep-scroll readiness proof"],
    "cross-run-deep-readiness-proof.json" => [cross_run_deep_readiness_proof_manifest, false, "cross-run deep-scroll readiness proof substitution"],
    "cross-run-deep-readiness-handshake.json" => [cross_run_deep_readiness_handshake_manifest, false, "cross-run deep-scroll readiness handshake substitution"],
    "stale-generic-readiness-filename.json" => [stale_generic_readiness_filename_manifest, false, "stale generic readiness filename substitution"],
    "false-without-blocker.json" => [false_without_blocker, false, "false field without blocker"],
    "false-with-blocker.json" => [false_with_blocker, false, "legacy inline screenshot blocker"],
    "desktop-false-with-ios-blocker.json" => [desktop_false_with_only_ios_blocker, false, "desktop false field with unrelated iOS blocker"],
    "bad-blocker.json" => [bad_blocker, false, "invalid blocker"]
  }.each do |filename, (manifest, expected_success, label)|
    path = temp_root.join(filename)
    add_screenshot_artifacts!(temp_root, manifest)
    manifest["screenshotArtifacts"].delete("iosMobile") if filename == "missing.json"
    add_accessibility_proofs!(temp_root, manifest, filename.delete_suffix(".json"))
    macos_observed_path = temp_root.join("apple/#{filename.delete_suffix(".json")}-observed-accessibility-macos.json")
    if filename.start_with?("macos-")
      macos_observed = JSON.parse(macos_observed_path.read)
      case filename
      when "macos-cross-run-nonce.json"
        macos_observed["captureRunNonce"] = "2ce25bb7-4ac8-457a-92e7-998d8d651e2c"
      when "macos-cross-run-proof.json"
        macos_observed["readinessProofSHA256"] = "a" * 64
      when "macos-cross-run-screenshot.json"
        macos_observed["screenshotSHA256"] = "b" * 64
      when "macos-wrong-bundle-identity.json"
        macos_observed["bundleIdentifier"] = "app.spoonjoy.substitute"
      when "macos-wrong-executable-identity.json"
        macos_observed["executablePath"] = "/Applications/Substitute.app/Contents/MacOS/Spoonjoy"
      end
      macos_observed_path.write(JSON.pretty_generate(macos_observed) + "\n")
    end
    if filename == "missing-deep-readiness-proof.json"
      temp_root.join("apple/missing-deep-readiness-proof-accessibility-proof-ios-deep-scroll.json").delete
    elsif filename == "cross-run-deep-readiness-proof.json"
      FileUtils.cp(
        temp_root.join("apple/cross-run-deep-readiness-proof-accessibility-proof-ios-ax-deep-scroll.json"),
        temp_root.join("apple/cross-run-deep-readiness-proof-accessibility-proof-ios-deep-scroll.json")
      )
    elsif filename == "cross-run-deep-readiness-handshake.json"
      ios_observed_path = temp_root.join("apple/cross-run-deep-readiness-handshake-observed-accessibility-ios.json")
      ios_ax_observed_path = temp_root.join("apple/cross-run-deep-readiness-handshake-observed-accessibility-ios-ax.json")
      ios_observed = JSON.parse(ios_observed_path.read)
      ios_ax_observed = JSON.parse(ios_ax_observed_path.read)
      ios_observed.fetch("deepScroll")["readinessHandshake"] = ios_ax_observed.fetch("deepScroll").fetch("readinessHandshake")
      ios_observed_path.write(JSON.pretty_generate(ios_observed) + "\n")
    elsif filename == "stale-generic-readiness-filename.json"
      ios_observed_path = temp_root.join("apple/stale-generic-readiness-filename-observed-accessibility-ios.json")
      ios_observed = JSON.parse(ios_observed_path.read)
      generation = ios_observed.fetch("readinessHandshake").fetch("readinessGeneration")
      ios_observed.fetch("readinessHandshake")["proofFileName"] = "native-accessibility-proof.generation-#{generation}.json"
      ios_observed_path.write(JSON.pretty_generate(ios_observed) + "\n")
    end
    if filename == "missing-macos-deep-scroll.json"
      macos_observed = JSON.parse(macos_observed_path.read)
      macos_observed.delete("deepScroll")
      macos_observed_path.write(JSON.pretty_generate(macos_observed) + "\n")
    end
    path.write(JSON.pretty_generate(manifest))
    if (proof_artifacts = manifest["settingsSurfaceProofArtifacts"])
      proof_artifacts.each do |proof_relative_path|
        proof_path = temp_root.join(proof_relative_path)
        proof_path.dirname.mkpath
        proof_path.write(JSON.pretty_generate(
          "route" => "settings",
          "visualFocus" => manifest.fetch("settingsVisualFocus"),
          "visibleSections" => manifest.fetch("settingsSections", []),
          "source" => "SettingsView"
        ) + "\n")
      end
    end
    if (proof_artifacts = manifest["searchSurfaceProofArtifacts"])
      proof_artifacts.each do |proof_relative_path|
        next if proof_relative_path.include?("stale")

        proof_path = temp_root.join(proof_relative_path)
        proof_path.dirname.mkpath
        proof_payload = {
          "route" => "search",
          "routeIdentifier" => "search:all:",
          "query" => "",
          "scope" => "all",
          "searchScopes" => ["all", "recipes", "cookbooks", "chefs", "shopping-list"],
          "accountID" => manifest.fetch("searchSeedAccountID", ""),
          "visibleSections" => ["Recipes", "Chefs"],
          "source" => "SearchView",
          "renderFingerprint" => {
            "rows" => [],
            "dataSource" => { "cache" => { "serverRevision" => "cursor:search-fixture" } },
            "emptyState" => nil
          }
        }
        if proof_relative_path.include?("wrong")
          proof_payload["routeIdentifier"] = "search:recipes:tomato"
          proof_payload["searchScopes"] = ["all", "recipes"]
          proof_payload["visibleSections"] = ["Recipes"]
          proof_payload["source"] = "WrongSearchView"
        end
        proof_path.write(JSON.pretty_generate(proof_payload) + "\n")
      end
    end
    assert_status(expected_success, ["ruby", validator, path], label)
  end

  if blocker_validator.file?
    apple_dir = temp_root.join("apple")
    apple_dir.mkpath
    canonical_blocker = apple_dir.join("unit-16f-screenshot-contract-screenshots-core-simulator-blocker.json")
    canonical_blocker.write(JSON.pretty_generate(
      "blocked" => true,
      "capability" => "CoreSimulator",
      "command" => "xcrun simctl io booted screenshot",
      "timeoutSeconds" => 30,
      "outputPath" => "apple/unit-16f-screenshot-contract-screenshots.log",
      "reason" => "No booted simulator was available.",
      "ownerAction" => "Install and boot an iPhone simulator runtime."
    ) + "\n")
    macos_accessibility_blocker = apple_dir.join("unit-16f-screenshot-contract-screenshots-macos-accessibility-blocker.json")
    macos_accessibility_blocker.write(JSON.pretty_generate(
      "blocked" => true,
      "capability" => "MacOSAccessibility",
      "command" => "swift scripts/observe-macos-screenshot-evidence.swift",
      "timeoutSeconds" => 60,
      "outputPath" => "apple/unit-16f-screenshot-contract-screenshots.log",
      "reason" => "The observer reported macOS accessibility geometry findings.",
      "ownerAction" => "Repair the reported geometry findings and rerun capture."
    ) + "\n")

    valid_blocked_review = {
      "blocked" => true,
      "capability" => "CoreSimulator",
      "sourceBlockerPath" => canonical_blocker.to_s,
      "skippedArtifacts" => [
        "screenshots/ios-mobile.png",
        "screenshots/ios-mobile-accessibility.png",
        "screenshots/ios-tablet.png",
        "screenshots/ios-mobile-deep-scroll.png",
        "screenshots/ios-mobile-accessibility-deep-scroll.png",
        "screenshots/ios-tablet-deep-scroll.png",
        "screenshots/macos-desktop.png",
        "design-review.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ios.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ios-ax.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ipad.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-macos.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ios-deep-scroll.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ios-ax-deep-scroll.json",
        "apple/unit-16f-screenshot-contract-accessibility-proof-ipad-deep-scroll.json",
        "apple/unit-16f-screenshot-contract-observed-accessibility-ios.json",
        "apple/unit-16f-screenshot-contract-observed-accessibility-ios-ax.json",
        "apple/unit-16f-screenshot-contract-observed-accessibility-ipad.json",
        "apple/unit-16f-screenshot-contract-observed-accessibility-macos.json"
      ],
      "reason" => "Screenshot capture was blocked by CoreSimulator.",
      "ownerAction" => "Install and boot an iPhone simulator runtime."
    }
    valid_blocked_review.fetch("skippedArtifacts").each do |relative_path|
      artifact = temp_root.join(relative_path)
      artifact.delete if artifact.file?
    end
    valid_macos_accessibility_review = valid_blocked_review.merge(
      "capability" => "MacOSAccessibility",
      "sourceBlockerPath" => macos_accessibility_blocker.to_s,
      "reason" => "The observer reported macOS accessibility geometry findings.",
      "ownerAction" => "Repair the reported geometry findings and rerun capture."
    )
    invalid_source_review = valid_blocked_review.merge(
      "sourceBlockerPath" => apple_dir.join("old-smoke-ios-simulator-blocker.json").to_s
    )
    top_level_source_review = valid_blocked_review.merge(
      "sourceBlockerPath" => temp_root.join("smoke-ios-simulator-blocker.json").to_s
    )
    false_blocked_review = valid_blocked_review.merge("blocked" => false)
    missing_capability_review = valid_blocked_review.reject { |key, _| key == "capability" }
    mismatched_capability_review = valid_blocked_review.merge("capability" => "MacOSLaunch")
    missing_skipped_review = valid_blocked_review.reject { |key, _| key == "skippedArtifacts" }
    incomplete_skipped_review = valid_blocked_review.merge(
      "skippedArtifacts" => ["screenshots/ios-mobile.png"]
    )
    missing_reason_review = valid_blocked_review.reject { |key, _| key == "reason" }
    missing_owner_action_review = valid_blocked_review.reject { |key, _| key == "ownerAction" }

    {
      "valid-blocked-review.json" => [valid_blocked_review, true, "valid design-review blocker"],
      "valid-macos-accessibility-blocked-review.json" => [valid_macos_accessibility_review, true, "valid macOS accessibility blocker"],
      "invalid-source-blocked-review.json" => [invalid_source_review, false, "noncanonical design-review blocker source"],
      "top-level-source-blocked-review.json" => [top_level_source_review, false, "top-level design-review blocker source"],
      "false-blocked-review.json" => [false_blocked_review, false, "design-review blocker blocked=false"],
      "missing-capability-blocked-review.json" => [missing_capability_review, false, "design-review blocker missing capability"],
      "mismatched-capability-blocked-review.json" => [mismatched_capability_review, false, "design-review blocker mismatched capability"],
      "missing-skipped-blocked-review.json" => [missing_skipped_review, false, "design-review blocker missing skippedArtifacts"],
      "incomplete-skipped-blocked-review.json" => [incomplete_skipped_review, false, "design-review blocker incomplete skippedArtifacts"],
      "missing-reason-blocked-review.json" => [missing_reason_review, false, "design-review blocker missing reason"],
      "missing-owner-action-blocked-review.json" => [missing_owner_action_review, false, "design-review blocker missing ownerAction"]
    }.each do |filename, (manifest, expected_success, label)|
      path = temp_root.join(filename)
      path.write(JSON.pretty_generate(manifest) + "\n")
      assert_status(
        expected_success,
        ["ruby", blocker_validator, path, "--artifact-root", temp_root, "--unit-slug", "unit-16f-screenshot-contract"],
        label
      )
    end

    design_review = temp_root.join("design-review.json")
    blocked_review = temp_root.join("design-review-blocked.json")
    design_review.write(JSON.pretty_generate(valid_manifest) + "\n")
    blocked_review.write(JSON.pretty_generate(valid_blocked_review) + "\n")
    assert_status(
      false,
      [
        "bash",
        "-lc",
        "set -euo pipefail; if [[ -f \"$1\" && -f \"$2\" ]]; then echo \"conflicting design review success and blocker artifacts\"; exit 1; fi",
        "design-review-conflict-check",
        design_review,
        blocked_review
      ],
      "conflicting design review success and blocker artifacts"
    )
  end
end

Dir.mktmpdir("spoonjoy-smoke-script-contract") do |directory|
  temp_root = Pathname.new(directory)
  artifact_root = temp_root.join("artifacts")
  apple_dir = artifact_root.join("apple")
  bin_dir = temp_root.join("bin")
  apple_dir.mkpath
  bin_dir.mkpath

  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    exit 70
  SH

  ios_log = apple_dir.join("unit-contract-smoke-ios-inner.log")
  ios_blocker = apple_dir.join("unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    true,
    [
      "bash",
      ROOT.join("scripts/smoke-ios-simulator.sh"),
      "--artifact-root",
      artifact_root,
      "--log",
      ios_log,
      "--blocker",
      ios_blocker
    ],
    "iOS smoke writes canonical CoreSimulator blocker",
    env: { "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" }
  )
  blocker = assert_json(ios_blocker, "iOS smoke canonical blocker")
  record_failure("iOS smoke blocker capability mismatch") unless blocker["capability"] == "CoreSimulator"
  record_failure("iOS smoke blocker missing ownerAction") unless blocker["ownerAction"].is_a?(String) && !blocker["ownerAction"].empty?
  record_failure("iOS smoke blocker outputPath mismatch") unless blocker["outputPath"] == ios_log.to_s

  digest_script_root = temp_root.join("ios-install-digest")
  digest_script_root.join("scripts").mkpath
  digest_script_root.join(".github/scripts").mkpath
  FileUtils.cp(ROOT.join("scripts/smoke-ios-simulator.sh"), digest_script_root.join("scripts/smoke-ios-simulator.sh"))
  write_executable(digest_script_root.join(".github/scripts/resolve-ios-simulator-destination.py"), <<~'PY')
    #!/usr/bin/env python3
    print("platform=iOS Simulator,name=iPhone 16,id=SIM-UDID")
  PY
  digest_app = digest_script_root.join("Spoonjoy.app")
  digest_app.mkpath
  digest_app.join("Spoonjoy").write("first exact app bundle\n")
  digest_marker = digest_script_root.join("installed.marker")
  digest_installed_app = digest_script_root.join("Installed-Spoonjoy.app")
  digest_install_events = digest_script_root.join("install-events.log")
  write_executable(bin_dir.join("open"), "#!/usr/bin/env bash\nexit 0\n")
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      "simctl list runtimes"|simctl\ boot\ *|simctl\ bootstatus\ *|simctl\ uninstall\ *) exit 0 ;;
      simctl\ install\ *)
        printf 'install\n' >> "$SIMCTL_INSTALL_EVENTS"
        source_app="${@: -1}"
        rm -rf "$SIMCTL_INSTALLED_APP_PATH"
        cp -R "$source_app" "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ get_app_container\ *\ app.spoonjoy\ app)
        [[ -d "$SIMCTL_INSTALLED_APP_PATH" ]] || exit 1
        printf '%s\n' "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ get_app_container\ *\ app.spoonjoy\ data)
        printf '/tmp/Spoonjoy-data\n'
        exit 0
        ;;
      simctl\ launch\ *)
        printf 'app.spoonjoy: 12345\n'
        exit 0
        ;;
      *) exit 0 ;;
    esac
  SH
  digest_environment = {
    "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
    "SPOONJOY_SCREENSHOT_IOS_APP_PATH" => digest_app.to_s,
    "SPOONJOY_SCREENSHOT_REUSE_INSTALLED_IOS_APP" => "1",
    "SPOONJOY_SCREENSHOT_IOS_INSTALL_MARKER" => digest_marker.to_s,
    "SIMCTL_INSTALL_EVENTS" => digest_install_events.to_s,
    "SIMCTL_INSTALLED_APP_PATH" => digest_installed_app.to_s
  }
  digest_command = [
    "bash",
    "scripts/smoke-ios-simulator.sh",
    "--artifact-root",
    digest_script_root.join("artifacts"),
    "--log",
    digest_script_root.join("artifacts/apple/smoke.log"),
    "--blocker",
    digest_script_root.join("artifacts/apple/blocker.json")
  ]
  assert_status(true, digest_command, "exact digest installs the initial app bundle", env: digest_environment, chdir: digest_script_root)
  record_failure("exact digest install marker missing simulator identity") unless digest_marker.read.include?("simulator=SIM-UDID")
  record_failure("exact digest install marker missing bundle sha256") unless digest_marker.read.match?(/bundle_sha256=[0-9a-f]{64}/)
  assert_status(true, digest_command, "exact digest reuses the identical app bundle", env: digest_environment, chdir: digest_script_root)
  record_failure("identical app bundle was unexpectedly reinstalled") unless digest_install_events.readlines.length == 1
  digest_installed_app.join("Spoonjoy").write("tampered installed app bundle\n")
  assert_status(true, digest_command, "tampered installed bundle is replaced despite a matching marker", env: digest_environment, chdir: digest_script_root)
  record_failure("tampered installed app bundle did not trigger reinstall") unless digest_install_events.readlines.length == 2
  digest_app.join("Spoonjoy").write("second exact app bundle\n")
  assert_status(true, digest_command, "changed digest reinstalls the app bundle", env: digest_environment, chdir: digest_script_root)
  record_failure("changed app bundle digest did not trigger reinstall") unless digest_install_events.readlines.length == 3

  write_executable(bin_dir.join("xcodebuild"), <<~'SH')
    #!/usr/bin/env bash
    derived=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "-derivedDataPath" ]]; then
        derived="$2"
        shift 2
      else
        shift
      fi
    done
    mkdir -p "$derived/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
    exit 0
  SH
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      "simctl list runtimes") exit 0 ;;
      simctl\ boot\ *|simctl\ bootstatus\ *) exit 0 ;;
      simctl\ install\ *)
        rm -rf "$SIMCTL_INSTALLED_APP_PATH"
        cp -R "${@: -1}" "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ get_app_container\ *\ app.spoonjoy\ app)
        printf '%s\n' "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ launch\ *) exit 91 ;;
      *) exit 0 ;;
    esac
  SH
  script_root = temp_root.join("ios-launch-hard-fail")
  script_root.join("scripts").mkpath
  script_root.join(".github/scripts").mkpath
  FileUtils.cp(ROOT.join("scripts/smoke-ios-simulator.sh"), script_root.join("scripts/smoke-ios-simulator.sh"))
  write_executable(script_root.join(".github/scripts/resolve-ios-simulator-destination.py"), <<~'PY')
    #!/usr/bin/env python3
    print("platform=iOS Simulator,name=iPhone 16,id=SIM-UDID")
  PY
  hard_fail_artifacts = temp_root.join("hard-fail-artifacts")
  hard_fail_installed_app = temp_root.join("hard-fail-installed.app")
  hard_fail_log = hard_fail_artifacts.join("apple/unit-contract-smoke-ios-inner.log")
  hard_fail_blocker = hard_fail_artifacts.join("apple/unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    true,
    [
      "bash",
      "scripts/smoke-ios-simulator.sh",
      "--artifact-root",
      hard_fail_artifacts,
      "--log",
      hard_fail_log,
      "--blocker",
      hard_fail_blocker
    ],
    "iOS app launch failure writes CoreSimulator blocker",
    env: {
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SIMCTL_INSTALLED_APP_PATH" => hard_fail_installed_app.to_s
    },
    chdir: script_root
  )
  hard_fail_blocker_json = assert_json(hard_fail_blocker, "iOS launch hard failure blocker")
  record_failure("iOS launch hard failure blocker capability mismatch") unless hard_fail_blocker_json["capability"] == "CoreSimulator"
  record_failure("iOS launch hard failure blocker missing launch command") unless hard_fail_blocker_json.fetch("command", "").include?("simctl launch")

  timeout_script_root = temp_root.join("ios-launch-timeout-retry")
  timeout_script_root.join("scripts").mkpath
  timeout_script_root.join(".github/scripts").mkpath
  FileUtils.cp(ROOT.join("scripts/smoke-ios-simulator.sh"), timeout_script_root.join("scripts/smoke-ios-simulator.sh"))
  write_executable(timeout_script_root.join(".github/scripts/resolve-ios-simulator-destination.py"), <<~'PY')
    #!/usr/bin/env python3
    print("platform=iOS Simulator,name=iPhone 16,id=SIM-UDID")
  PY
  launch_state_file = temp_root.join("ios-launch-timeout-state")
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      "simctl list runtimes") exit 0 ;;
      simctl\ boot\ *|simctl\ bootstatus\ *) exit 0 ;;
      simctl\ install\ *)
        rm -rf "$SIMCTL_INSTALLED_APP_PATH"
        cp -R "${@: -1}" "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ get_app_container\ *\ app.spoonjoy\ app)
        printf '%s\n' "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ launch\ *)
        count="0"
        if [[ -f "${SIMCTL_LAUNCH_STATE_FILE:-}" ]]; then
          count="$(cat "$SIMCTL_LAUNCH_STATE_FILE")"
        fi
        if [[ "$count" == "0" ]]; then
          printf '1' > "$SIMCTL_LAUNCH_STATE_FILE"
          sleep 2
        fi
        printf 'app.spoonjoy: 12345\n'
        exit 0
        ;;
      simctl\ spawn\ *\ launchctl\ list)
        printf 'UIKitApplication:com.apple.Preferences[abcd][rb-legacy]\n'
        exit 0
        ;;
      *) exit 0 ;;
    esac
  SH
  timeout_artifacts = temp_root.join("timeout-retry-artifacts")
  timeout_installed_app = temp_root.join("timeout-retry-installed.app")
  timeout_log = timeout_artifacts.join("apple/unit-contract-smoke-ios-inner.log")
  timeout_blocker = timeout_artifacts.join("apple/unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    true,
    [
      "bash",
      "scripts/smoke-ios-simulator.sh",
      "--artifact-root",
      timeout_artifacts,
      "--log",
      timeout_log,
      "--blocker",
      timeout_blocker
    ],
    "iOS app launch timeout retries before failing smoke",
    env: {
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SIMCTL_LAUNCH_STATE_FILE" => launch_state_file.to_s,
      "SIMCTL_INSTALLED_APP_PATH" => timeout_installed_app.to_s,
      "SPOONJOY_SMOKE_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SMOKE_LAUNCH_ATTEMPTS" => "2"
    },
    chdir: timeout_script_root
  )
  timeout_log_text = timeout_log.read
  record_failure("iOS launch timeout retry did not record timeout") unless timeout_log_text.include?("command timed out after 1 seconds")
  record_failure("iOS launch timeout retry did not reach second attempt") unless timeout_log_text.include?("simulator launch attempt 2 exit code: 0")
  assert_missing(timeout_blocker, "iOS launch timeout retry")

  timeout_fail_script_root = temp_root.join("ios-launch-timeout-fail")
  timeout_fail_script_root.join("scripts").mkpath
  timeout_fail_script_root.join(".github/scripts").mkpath
  FileUtils.cp(ROOT.join("scripts/smoke-ios-simulator.sh"), timeout_fail_script_root.join("scripts/smoke-ios-simulator.sh"))
  write_executable(timeout_fail_script_root.join(".github/scripts/resolve-ios-simulator-destination.py"), <<~'PY')
    #!/usr/bin/env python3
    print("platform=iOS Simulator,name=iPhone 16,id=SIM-UDID")
  PY
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      "simctl list runtimes") exit 0 ;;
      simctl\ boot\ *|simctl\ bootstatus\ *) exit 0 ;;
      simctl\ install\ *)
        rm -rf "$SIMCTL_INSTALLED_APP_PATH"
        cp -R "${@: -1}" "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ get_app_container\ *\ app.spoonjoy\ app)
        printf '%s\n' "$SIMCTL_INSTALLED_APP_PATH"
        exit 0
        ;;
      simctl\ launch\ *)
        sleep 2
        ;;
      simctl\ spawn\ *\ launchctl\ list)
        printf 'UIKitApplication:com.apple.Preferences[abcd][rb-legacy]\n'
        exit 0
        ;;
      *) exit 0 ;;
    esac
  SH
  timeout_fail_artifacts = temp_root.join("timeout-fail-artifacts")
  timeout_fail_installed_app = temp_root.join("timeout-fail-installed.app")
  timeout_fail_log = timeout_fail_artifacts.join("apple/unit-contract-smoke-ios-inner.log")
  timeout_fail_blocker = timeout_fail_artifacts.join("apple/unit-contract-smoke-ios-simulator-blocker.json")
  assert_status(
    true,
    [
      "bash",
      "scripts/smoke-ios-simulator.sh",
      "--artifact-root",
      timeout_fail_artifacts,
      "--log",
      timeout_fail_log,
      "--blocker",
      timeout_fail_blocker
    ],
    "iOS app launch timeout writes CoreSimulator blocker",
    env: {
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SIMCTL_INSTALLED_APP_PATH" => timeout_fail_installed_app.to_s,
      "SPOONJOY_SMOKE_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SMOKE_LAUNCH_ATTEMPTS" => "2"
    },
    chdir: timeout_fail_script_root
  )
  timeout_fail_log_text = timeout_fail_log.read
  record_failure("iOS launch timeout failure did not record timeout") unless timeout_fail_log_text.include?("command timed out after 1 seconds")
  timeout_fail_blocker_json = assert_json(timeout_fail_blocker, "iOS launch timeout failure blocker")
  record_failure("iOS launch timeout failure blocker capability mismatch") unless timeout_fail_blocker_json["capability"] == "CoreSimulator"
  record_failure("iOS launch timeout failure blocker reason missing timeout") unless timeout_fail_blocker_json.fetch("reason", "").downcase.include?("timeout")

  write_executable(bin_dir.join("xcodebuild"), <<~'SH')
    #!/usr/bin/env bash
    derived=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "-derivedDataPath" ]]; then
        derived="$2"
        shift 2
      else
        shift
      fi
    done
    mkdir -p "$derived/Build/Products/BootstrapDebug/Spoonjoy.app"
    exit 0
  SH
  write_executable(bin_dir.join("osascript"), <<~'SH')
    #!/usr/bin/env bash
    exit 2
  SH
  macos_log = apple_dir.join("unit-contract-smoke-macos-inner.log")
  macos_blocker = apple_dir.join("unit-contract-smoke-macos-blocker.json")
  assert_status(
    true,
    [
      "bash",
      ROOT.join("scripts/smoke-macos.sh"),
      "--artifact-root",
      artifact_root,
      "--log",
      macos_log,
      "--blocker",
      macos_blocker
    ],
    "macOS smoke writes canonical MacOSLaunch blocker",
    env: { "HOME" => temp_root.join("home").to_s, "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}" }
  )
  macos_blocker_json = assert_json(macos_blocker, "macOS smoke canonical blocker")
  record_failure("macOS smoke blocker capability mismatch") unless macos_blocker_json["capability"] == "MacOSLaunch"
  record_failure("macOS smoke blocker missing ownerAction") unless macos_blocker_json["ownerAction"].is_a?(String) && !macos_blocker_json["ownerAction"].empty?
  record_failure("macOS smoke blocker outputPath mismatch") unless macos_blocker_json["outputPath"] == macos_log.to_s
end

Dir.mktmpdir("spoonjoy-capture-script-contract") do |directory|
  temp_root = Pathname.new(directory)
  script_root = temp_root.join("app")
  artifact_root = script_root.join("artifacts")
  scripts_dir = script_root.join("scripts")
  bin_dir = script_root.join("bin")
  scripts_dir.mkpath
  bin_dir.mkpath
  python3_path = ENV.fetch("PATH").split(File::PATH_SEPARATOR)
    .map { |entry| Pathname.new(entry).join("python3") }
    .find(&:executable?)
  raise "python3 is required for the capture contract fixture" unless python3_path
  write_executable(bin_dir.join("python3"), <<~SH)
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "${1:-}" == "-" && "${3:-}" == "spoonjoy-foreground-stream-supervisor-v1" && -n "${SPOONJOY_CONTRACT_STREAM_LEADER_DELAY_SECONDS:-}" ]]; then
      printf '%s\n' "$$" >> "${SPOONJOY_CONTRACT_STREAM_LEADER_PID_FILE:?}"
      sleep "$SPOONJOY_CONTRACT_STREAM_LEADER_DELAY_SECONDS"
    fi
    exec #{Shellwords.escape(python3_path.to_s)} "$@"
  SH
  fixture_cover_source = script_root.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png")
  fixture_cover_source.dirname.mkpath
  FileUtils.cp(
    ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png"),
    fixture_cover_source
  )
  FileUtils.cp(ROOT.join("scripts/capture-native-screenshots.sh"), scripts_dir.join("capture-native-screenshots.sh"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review.rb"), scripts_dir.join("validate-design-review.rb"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review-blocker.rb"), scripts_dir.join("validate-design-review-blocker.rb"))
  observer_products = script_root.join("observer-products")
  observer_app = observer_products.join("Spoonjoy.app")
  observer_runner = observer_products.join("SpoonjoyUITests-Runner.app")
  observer_xctestrun = observer_products.join("Spoonjoy.xctestrun")
  observer_macos_app = observer_products.join("Spoonjoy-macOS.app")
  observer_app.mkpath
  observer_runner.join("PlugIns/SpoonjoyUITests.xctest").mkpath
  observer_xctestrun.write("fixture\n")
  observer_macos_app.join("Contents/MacOS").mkpath
  observer_macos_app.join("Contents/MacOS/Spoonjoy").write("fixture\n")
  observer_macos_app.join("Contents/Info.plist").write(<<~PLIST)
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict><key>CFBundleExecutable</key><string>Spoonjoy</string></dict></plist>
  PLIST
  observer_product_env = {
    "SPOONJOY_SCREENSHOT_IOS_APP_PATH" => observer_app.to_s,
    "SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH" => observer_runner.to_s,
    "SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH" => observer_xctestrun.to_s,
    "SPOONJOY_SCREENSHOT_MACOS_APP_PATH" => observer_macos_app.to_s
  }
  write_executable(scripts_dir.join("run-ios-screenshot-observer.py"), <<~'PY')
    #!/usr/bin/env python3
    import argparse, hashlib, json, os, sys
    from pathlib import Path

    parser = argparse.ArgumentParser()
    for name in ("xctestrun", "app", "runner", "destination-udid", "platform", "route", "output", "readiness-proof-output", "work-root", "log", "timeout-seconds", "screenshot-output", "deep-scroll-screenshot-output"):
        parser.add_argument(f"--{name}")
    parser.add_argument("--environment", action="append", default=[])
    parser.add_argument("--environment-json")
    args = parser.parse_args()
    transient_failure_marker = os.environ.get("SPOONJOY_CONTRACT_FAIL_IOS_OBSERVER_ONCE_FILE")
    if transient_failure_marker and not Path(transient_failure_marker).exists():
        Path(transient_failure_marker).write_text("failed once\n")
        raise SystemExit(65)
    terminal_identifier = "kitchen.cookbook.cookbook_weeknights" if args.route == "kitchen" else "fixture.terminal"
    terminal = {"identifier":terminal_identifier,"label":"Terminal","type":"staticText","frame":{"x":10,"y":40,"width":44,"height":40},"exists":True,"hittable":False,"enabled":True,"focused":None}
    identifiers = []
    environment = dict(value.split("=", 1) for value in args.environment)
    if args.environment_json:
        environment.update(json.loads(Path(args.environment_json).read_text()))
    proof_path_log = os.environ.get("SPOONJOY_CONTRACT_OBSERVER_PROOF_PATH_FILE")
    if proof_path_log:
        with Path(proof_path_log).open("a", encoding="utf-8") as handle:
            handle.write(environment["SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"] + "\n")
    product_finding = None
    if os.environ.get("SPOONJOY_CONTRACT_FAIL_IOS_OBSERVER") == "1":
        product_finding = {"kind":"simulatedProductRegression","identifiers":[args.route],"message":"simulated product regression","intersection":None}
    if (
        os.environ.get("SPOONJOY_CONTRACT_FAIL_IOS_AX_OBSERVER") == "1"
        and environment.get("SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY", "").startswith("accessibility-")
    ):
        product_finding = {"kind":"simulatedAccessibilityProductRegression","identifiers":[args.route],"message":"simulated accessibility-size product regression","intersection":None}
    proof_path = Path(environment["SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"])
    proof = json.loads(proof_path.read_bytes())
    proof["captureRunNonce"] = environment["SPOONJOY_SCREENSHOT_RUN_NONCE"]
    proof["readinessGeneration"] = 1
    proof["visualReadiness"]["generation"] = 1
    proof_bytes = (json.dumps(proof, sort_keys=True) + "\n").encode()
    proof_path.write_bytes(proof_bytes)
    readiness_output = Path(args.readiness_proof_output)
    readiness_output.parent.mkdir(parents=True, exist_ok=True)
    readiness_output.write_bytes(proof_bytes)
    if args.route == "settings" and environment.get("SPOONJOY_SCREENSHOT_SETTINGS_FOCUS") == "notifications":
        identifiers = ["settings.apns.this-device.heading", "settings.apns.push-delivery.heading", "settings.apns.notification-sync.heading"]
    elements = [terminal] + [{"identifier":identifier,"label":identifier,"type":"staticText","frame":{"x":10,"y":10 + index * 20,"width":80,"height":18},"exists":True,"hittable":False,"enabled":True,"focused":None} for index, identifier in enumerate(identifiers)]
    content_size = environment.get("SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY", "large")
    initial_filename = f"{proof_path.stem}.generation-1{proof_path.suffix or '.json'}"
    initial_handshake = {"captureRunNonce":proof["captureRunNonce"],"route":args.route,"source":proof["source"],"readinessGeneration":1,"proofFileName":initial_filename,"proofSHA256":hashlib.sha256(proof_bytes).hexdigest()}
    evidence = {"platform":args.platform,"route":args.route,"viewport":{"x":0,"y":0,"width":100,"height":80},"elements":elements,"auditIssues":[],"verifiedContrastFalsePositives":[],"screenshotSHA256":hashlib.sha256(b"png").hexdigest(),"geometryFindings":[product_finding] if product_finding else [],"observedContentSizeCategory":content_size,"observedDynamicTypeSize":"accessibility5" if content_size == "accessibility-extra-extra-extra-large" else "large","readinessHandshake":initial_handshake,"toolLimitations":[]}
    if args.route in {"kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers", "cook-mode", "cook-log", "cookbooks", "cookbook-detail", "shopping-list", "chefs", "profile", "profile-graph", "search", "capture", "settings"}:
        deep_proof = dict(proof)
        deep_proof["visualReadiness"] = dict(proof["visualReadiness"])
        deep_proof["readinessGeneration"] = 2
        deep_proof["visualReadiness"]["generation"] = 2
        deep_proof_bytes = (json.dumps(deep_proof, sort_keys=True) + "\n").encode()
        deep_filename = f"{proof_path.stem}.generation-2{proof_path.suffix or '.json'}"
        deep_handshake = {"captureRunNonce":proof["captureRunNonce"],"route":args.route,"source":proof["source"],"readinessGeneration":2,"proofFileName":deep_filename,"proofSHA256":hashlib.sha256(deep_proof_bytes).hexdigest()}
        evidence["deepScroll"] = {"route":args.route,"reachedTerminal":True,"swipeCount":2,"contentViewport":{"x":0,"y":0,"width":100,"height":80},"tabBarFrame":{"x":0,"y":80,"width":100,"height":20},"terminalElement":terminal,"findings":[],"auditIssues":[],"verifiedContrastFalsePositives":[],"screenshotSHA256":hashlib.sha256(b"png").hexdigest(),"readinessHandshake":deep_handshake,"observedContentMovement":True,"contentFitsWithoutScrolling":False,"toolLimitations":[]}
        deep_output = readiness_output.with_name(f"{readiness_output.stem}-deep-scroll{readiness_output.suffix or '.json'}")
        deep_output.write_bytes(deep_proof_bytes)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence) + "\n")
    if args.screenshot_output:
        screenshot = Path(args.screenshot_output)
        screenshot.parent.mkdir(parents=True, exist_ok=True)
        screenshot.write_bytes(b"png")
    if args.deep_scroll_screenshot_output:
        screenshot = Path(args.deep_scroll_screenshot_output)
        screenshot.parent.mkdir(parents=True, exist_ok=True)
        screenshot.write_bytes(b"png")
  PY

  write_executable(bin_dir.join("mv"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "${SPOONJOY_CONTRACT_FAIL_IOS_PUBLISH_AFTER:-}" && "$*" == *-capture-attempt-* ]]; then
      marker="${SPOONJOY_CONTRACT_IOS_PUBLISH_COUNT_FILE:?}"
      count=0
      if [[ -f "$marker" ]]; then
        count="$(cat "$marker")"
      fi
      count=$((count + 1))
      printf '%s\n' "$count" > "$marker"
      if [[ "$count" -eq "$SPOONJOY_CONTRACT_FAIL_IOS_PUBLISH_AFTER" ]]; then
        exit 73
      fi
    fi
    exec /bin/mv "$@"
  SH

  blocker_stub = lambda do |capability|
    <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      blocker=""
      log=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --blocker) blocker="$2"; shift 2 ;;
          --log) log="$2"; shift 2 ;;
          --artifact-root) shift 2 ;;
          *) shift ;;
        esac
      done
      mkdir -p "$(dirname "$blocker")" "$(dirname "$log")"
      printf blocked > "$log"
      ruby -rjson -e 'path, capability, log_path = ARGV; File.write(path, JSON.pretty_generate({blocked: true, capability: capability, command: "simulated runtime blocker", timeoutSeconds: 30, outputPath: log_path, reason: "Simulated runtime blocker.", ownerAction: "Satisfy the simulated local runtime capability."}) + "\\n")' "$blocker" "#{capability}" "$log"
      exit 0
    SH
  end
  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), blocker_stub.call("CoreSimulator"))
  write_executable(scripts_dir.join("smoke-macos.sh"), blocker_stub.call("MacOSLaunch"))

  artifact_root.join("screenshots").mkpath
  artifact_root.join("apple").mkpath
  artifact_root.join("design-review.json").write("{}\n")
  artifact_root.join("design-review-blocked.json").write("{}\n")
  artifact_root.join("screenshots/ios-mobile.png").write("stale")
  artifact_root.join("screenshots/ios-mobile-accessibility.png").write("stale")
  artifact_root.join("screenshots/ios-tablet.png").write("stale")
  artifact_root.join("screenshots/ios-mobile-deep-scroll.png").write("stale")
  artifact_root.join("screenshots/ios-mobile-accessibility-deep-scroll.png").write("stale")
  artifact_root.join("screenshots/ios-tablet-deep-scroll.png").write("stale")
  artifact_root.join("screenshots/macos-desktop.png").write("stale")
  artifact_root.join("apple/unit-contract-accessibility-proof-ios.json").write("{}\n")
  artifact_root.join("apple/unit-contract-accessibility-proof-ios-ax.json").write("{}\n")
  artifact_root.join("apple/unit-contract-accessibility-proof-ipad.json").write("{}\n")
  artifact_root.join("apple/unit-contract-accessibility-proof-macos.json").write("{}\n")
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot blocker lane",
    env: observer_product_env.merge("HOME" => script_root.join("home").to_s),
    chdir: script_root
  )
  blocked_review = assert_json(artifact_root.join("design-review-blocked.json"), "screenshot blocked review")
  expected_source = artifact_root.join("apple/unit-contract-screenshots-core-simulator-blocker.json").expand_path.to_s
  record_failure("screenshot blocker source path mismatch") unless blocked_review["sourceBlockerPath"] == expected_source
  assert_missing(artifact_root.join("design-review.json"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-mobile.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-mobile-accessibility.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-tablet.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-mobile-deep-scroll.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-mobile-accessibility-deep-scroll.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/ios-tablet-deep-scroll.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("screenshots/macos-desktop.png"), "screenshot blocker lane")
  assert_missing(artifact_root.join("apple/unit-contract-accessibility-proof-ios.json"), "screenshot blocker lane")
  assert_missing(artifact_root.join("apple/unit-contract-accessibility-proof-ios-ax.json"), "screenshot blocker lane")
  assert_missing(artifact_root.join("apple/unit-contract-accessibility-proof-ipad.json"), "screenshot blocker lane")
  assert_missing(artifact_root.join("apple/unit-contract-accessibility-proof-macos.json"), "screenshot blocker lane")

  success_stub = <<~'SH'
    #!/usr/bin/env bash
    set -euo pipefail
    log=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --log) log="$2"; shift 2 ;;
        --blocker) shift 2 ;;
        --artifact-root) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$log")"
    udid="ABCDEF12-3456-7890-ABCD-1234567890AB"
    if [[ "${SPOONJOY_IOS_SIMULATOR_FAMILY:-iphone}" == "ipad" ]]; then
      udid="FEDCBA98-7654-3210-ABCD-0987654321FE"
    fi
    printf 'Booting simulator: xcrun simctl boot %s\nok\n' "$udid" > "$log"
  SH
  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), success_stub)
  write_executable(scripts_dir.join("smoke-macos.sh"), success_stub)
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    ios_running_file="${SPOONJOY_CONTRACT_IOS_RUNNING_FILE:-$PWD/ios-app-running}"
    write_accessibility_proof() {
      local output_path="$1"
      local route="$2"
      local platform="$3"
      local bundle="$4"
      local source="$5"
      if [[ "${SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        return 0
      fi
      if [[ "${SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        source="WrongAccessibilityView"
      fi
      observed_dynamic_type="large"
      if [[ -f "$PWD/contract-content-size" ]] && [[ "$(cat "$PWD/contract-content-size")" == "accessibility-extra-extra-extra-large" ]]; then
        observed_dynamic_type="accessibility5"
      fi
      recipe_covers_fixture="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE:-${SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE:-}}"
      capture_run_nonce="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RUN_NONCE:-${SPOONJOY_SCREENSHOT_RUN_NONCE:-}}"
      printf '{"platform":"%s","route":"%s","source":"%s","captureRunNonce":"%s","readinessGeneration":1,"launchEnvironmentProof":{"screenshotRecipeCoversFixture":"%s"},"screenshotStateSnapshotProof":{"stateDirectoryResolved":true,"appSnapshotPresent":true,"appSnapshotJSONReadable":true,"syncSnapshotPresent":true,"syncSnapshotJSONReadable":true},"observedDynamicTypeSize":"%s","observedReduceMotion":false,"visualReadiness":{"generation":1,"expectedMediaCount":1,"loadedMediaCount":1,"pendingMediaCount":0,"failedMediaCount":0,"blockingIndicatorCount":0,"isSettled":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"%s"}\n' "$platform" "$route" "$source" "$capture_run_nonce" "$recipe_covers_fixture" "$observed_dynamic_type" "$bundle" > "$output_path"
    }
    case "$*" in
      simctl\ get_app_container\ *)
        mkdir -p "$PWD/ios-container/Library/Application Support/Spoonjoy"
        printf '%s\n' "$PWD/ios-container"
        ;;
      simctl\ ui\ *\ content_size\ *)
        content_size="${@: -1}"
        printf '%s\n' "$content_size" > "$PWD/contract-content-size"
        while IFS= read -r proof_path; do
          ruby -rjson -e '
            path, content_size = ARGV
            payload = JSON.parse(File.read(path))
            payload["observedDynamicTypeSize"] = content_size == "accessibility-extra-extra-extra-large" ? "accessibility5" : "large"
            File.write(path, JSON.generate(payload) + "\n")
          ' "$proof_path" "$content_size"
        done < <(find "$PWD/ios-container" -name native-accessibility-proof.json -type f 2>/dev/null)
        ;;
      simctl\ launch\ *)
        if [[ -n "${SPOONJOY_CONTRACT_LAUNCH_PID_FILE:-}" ]]; then
          printf '%s\n' "$$" >> "$SPOONJOY_CONTRACT_LAUNCH_PID_FILE"
        fi
        if [[ "${SPOONJOY_CONTRACT_FAIL_IOS_LAUNCH:-}" == "1" ]]; then
          exit 1
        fi
        touch "$ios_running_file"
        if [[ -n "${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH:-}" ]]; then
          accessibility_route="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_EXPECTED_ROUTE:-kitchen}"
          accessibility_source="KitchenView"
          case "$accessibility_route" in
            search)
              accessibility_route="search"
              accessibility_source="SearchView"
              ;;
            settings)
              accessibility_route="settings"
              accessibility_source="SettingsView"
              ;;
            cookbook-detail)
              accessibility_route="cookbook-detail"
              accessibility_source="CookbookDetailView"
              ;;
            capture)
              accessibility_route="capture"
              accessibility_source="CaptureDraftView"
              ;;
          esac
          accessibility_platform="ios"
          if [[ "$*" == *"FEDCBA98-7654-3210-ABCD-0987654321FE"* ]]; then
            accessibility_platform="ipad"
          fi
          write_accessibility_proof "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH" "$accessibility_route" "$accessibility_platform" "app.spoonjoy" "$accessibility_source"
        fi
        if [[ -n "${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH:-}" ]]; then
          account_id="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCOUNT_ID:-}"
          if [[ "$account_id" == "chef_search_capture" ]]; then
            if [[ "${SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF:-}" != "1" ]]; then
              mkdir -p "$(dirname "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH")"
              route_identifier="search:all:"
              source="SearchView"
              scopes='["all","recipes","cookbooks","chefs","shopping-list"]'
              sections='["Recipes","Chefs"]'
              if [[ "${SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF:-}" == "1" ]]; then
                route_identifier="search:recipes:tomato"
                source="WrongSearchView"
                scopes='["all","recipes"]'
                sections='["Recipes"]'
              fi
              printf '{"route":"search","routeIdentifier":"%s","query":"","scope":"all","searchScopes":%s,"accountID":"%s","visibleSections":%s,"source":"%s","renderFingerprint":{"rows":[],"dataSource":{"cache":{"serverRevision":"cursor:search-fixture"}},"emptyState":null}}\n' "$route_identifier" "$scopes" "$account_id" "$sections" "$source" > "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH"
            fi
          else
            mkdir -p "$(dirname "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH")"
            focus="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_SETTINGS_FOCUS:-profile}"
            route="settings"
            source="SettingsView"
            sections='["Profile","Security"]'
            if [[ "${SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF:-}" == "1" ]]; then
              route="kitchen"
              focus="profile"
              source="WrongView"
              sections='["Kitchen"]'
            elif [[ "$focus" == "notifications" ]]; then
              sections='["Notifications","This Device","Push Delivery","Notification Sync","Agent Access"]'
            fi
            printf '{"route":"%s","visualFocus":"%s","visibleSections":%s,"source":"%s"}\n' "$route" "$focus" "$sections" "$source" > "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_PROOF_PATH"
          fi
        fi
        event_pipe="${SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE:-$PWD/foreground-events.fifo}"
        printf 'Front display did change: <SBApplication; app.spoonjoy>\n' > "$event_pipe"
        printf 'app.spoonjoy: 12345\n'
        if [[ "${SPOONJOY_CONTRACT_HOLD_AFTER_LAUNCH:-}" == "1" ]]; then
          touch "${SPOONJOY_CONTRACT_HOLD_STARTED_FILE:?}"
          sleep 60
        fi
        ;;
      simctl\ terminate\ *)
        rm -f "$ios_running_file"
        ;;
      simctl\ spawn\ *\ launchctl\ list*)
        if [[ -f "$ios_running_file" ]]; then
          printf '12345\t0\tUIKitApplication:app.spoonjoy[contract]\n'
        fi
        ;;
      simctl\ spawn\ *\ log\ stream*)
        event_pipe="${SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE:-$PWD/foreground-events.fifo}"
        if [[ ! -p "$event_pipe" ]]; then
          rm -f "$event_pipe"
          mkfifo "$event_pipe"
        fi
        (
          while true; do
            while IFS= read -r event; do
              printf '%s\n' "$event"
            done < "$event_pipe"
          done
        ) &
        stream_child_pid=$!
        printf '%s\n' "$stream_child_pid" >> "${SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE:-$PWD/foreground-stream-child-pids}"
        wait "$stream_child_pid"
        ;;
      simctl\ spawn\ *\ log\ emit*)
        event_pipe="${SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE:-$PWD/foreground-events.fifo}"
        barrier_token="${@: -1}"
        if [[ "${SPOONJOY_CONTRACT_FOREGROUND_INTRUDER:-}" != "" && "$barrier_token" == *"-post-"* && -f "${SPOONJOY_CONTRACT_SCREENSHOT_CAPTURED_FILE:-/dev/null}" ]]; then
          sleep 0.35
          printf 'Front display did change: <SBApplication; com.apple.Preferences>\n' > "$event_pipe"
          if [[ "$SPOONJOY_CONTRACT_FOREGROUND_INTRUDER" == "leave-and-return" ]]; then
            printf 'Front display did change: <SBApplication; app.spoonjoy>\n' > "$event_pipe"
          fi
        fi
        printf 'Spoonjoy screenshot foreground barrier: %s\n' "$barrier_token" > "$event_pipe"
        ;;
      simctl\ io\ *\ screenshot\ *)
        if [[ -n "${SPOONJOY_CONTRACT_SCREENSHOT_CAPTURED_FILE:-}" ]]; then
          touch "$SPOONJOY_CONTRACT_SCREENSHOT_CAPTURED_FILE"
        fi
        out="${@: -1}"
        mkdir -p "$(dirname "$out")"
        python3 - "$out" <<'PY'
import binascii
import struct
import sys
import zlib

path = sys.argv[1]
width, height = 400, 800
palette = [
    (38, 34, 30), (174, 112, 47), (92, 111, 74), (252, 250, 245),
    (105, 93, 82), (221, 209, 188), (129, 65, 54), (70, 96, 114),
    (189, 157, 91), (151, 143, 132)
]
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        color = (246, 239, 225)
        if y < 72:
            color = (38, 34, 30)
        elif 100 <= y < 300 and 24 <= x < 376:
            color = palette[((x - 24) // 32 + (y - 100) // 24) % len(palette)]
        elif 690 <= y < 760 and 32 <= x < 368:
            color = palette[((x - 32) // 48) % len(palette)]
        row.extend(color)
    rows.append(b"\x00" + bytes(row))

def chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xffffffff)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows)))
png += chunk(b"IEND", b"")
with open(path, "wb") as handle:
    handle.write(png)
PY
        ;;
      *)
        exit 0
        ;;
    esac
  SH
  write_executable(bin_dir.join("osascript"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    script="$*"
    macos_running_file="${SPOONJOY_CONTRACT_MACOS_RUNNING_FILE:-$PWD/macos-app-running}"
    if [[ "$script" == *"to quit"* ]]; then
      rm -f "$macos_running_file"
    elif [[ "$script" == *"open location"* ]]; then
      state="$HOME/Library/Application Support/Spoonjoy/native-app-state.json"
      mkdir -p "$(dirname "$state")"
      route="kitchen"
      if [[ "$script" == *"spoonjoy://settings"* ]]; then
        route="settings"
      elif [[ "$script" == *"spoonjoy://search"* ]]; then
        route="search:all:"
      elif [[ "$script" == *"spoonjoy://cookbooks/cookbook_weeknights"* ]]; then
        route="cookbook:cookbook_weeknights"
      elif [[ "$script" == *"spoonjoy://cookbooks"* ]]; then
        route="cookbooks"
      elif [[ "$script" == *"spoonjoy://capture"* ]]; then
        route="capture"
      fi
      printf '{"hasCompletedFirstRun":true,"lastOpenedRoute":"%s"}\n' "$route" > "$state"
    fi
  SH
  write_executable(bin_dir.join("open"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    touch "${SPOONJOY_CONTRACT_MACOS_RUNNING_FILE:-$PWD/macos-app-running}"
    write_accessibility_proof() {
      local output_path="$1"
      local route="$2"
      local platform="$3"
      local bundle="$4"
      local source="$5"
      if [[ "${SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        return 0
      fi
      if [[ "${SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF:-}" == "1" ]]; then
        source="WrongAccessibilityView"
      fi
      recipe_covers_fixture="${SPOONJOY_SCREENSHOT_RECIPE_COVERS_FIXTURE:-}"
      capture_run_nonce="${SPOONJOY_SCREENSHOT_RUN_NONCE:-}"
      printf '{"platform":"%s","route":"%s","source":"%s","captureRunNonce":"%s","readinessGeneration":1,"launchEnvironmentProof":{"screenshotRecipeCoversFixture":"%s"},"screenshotStateSnapshotProof":{"stateDirectoryResolved":true,"appSnapshotPresent":true,"appSnapshotJSONReadable":true,"syncSnapshotPresent":true,"syncSnapshotJSONReadable":true},"observedDynamicTypeSize":"large","observedReduceMotion":false,"visualReadiness":{"generation":1,"expectedMediaCount":1,"loadedMediaCount":1,"pendingMediaCount":0,"failedMediaCount":0,"blockingIndicatorCount":0,"isSettled":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"%s"}\n' "$platform" "$route" "$source" "$capture_run_nonce" "$recipe_covers_fixture" "$bundle" > "$output_path"
    }
    proof_path="${SPOONJOY_SCREENSHOT_PROOF_PATH:-}"
    accessibility_proof_path="${SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH:-}"
    expected_route="${SPOONJOY_SCREENSHOT_EXPECTED_ROUTE:-}"
    focus="${SPOONJOY_SCREENSHOT_SETTINGS_FOCUS:-profile}"
    account_id="${SPOONJOY_SCREENSHOT_ACCOUNT_ID:-}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --env)
          env_pair="$2"
          case "$env_pair" in
            SPOONJOY_SCREENSHOT_ACCOUNT_ID=*) account_id="${env_pair#SPOONJOY_SCREENSHOT_ACCOUNT_ID=}" ;;
            SPOONJOY_SCREENSHOT_EXPECTED_ROUTE=*) expected_route="${env_pair#SPOONJOY_SCREENSHOT_EXPECTED_ROUTE=}" ;;
            SPOONJOY_SCREENSHOT_PROOF_PATH=*) proof_path="${env_pair#SPOONJOY_SCREENSHOT_PROOF_PATH=}" ;;
            SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=*) accessibility_proof_path="${env_pair#SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH=}" ;;
            SPOONJOY_SCREENSHOT_SETTINGS_FOCUS=*) focus="${env_pair#SPOONJOY_SCREENSHOT_SETTINGS_FOCUS=}" ;;
          esac
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ -n "$proof_path" ]]; then
      if [[ "$account_id" == "chef_search_capture" ]]; then
        if [[ "${SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF:-}" != "1" ]]; then
          mkdir -p "$(dirname "$proof_path")"
          route_identifier="search:all:"
          source="SearchView"
          scopes='["all","recipes","cookbooks","chefs","shopping-list"]'
          sections='["Recipes","Chefs"]'
          if [[ "${SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF:-}" == "1" ]]; then
            route_identifier="search:recipes:tomato"
            source="WrongSearchView"
            scopes='["all","recipes"]'
            sections='["Recipes"]'
          fi
          printf '{"route":"search","routeIdentifier":"%s","query":"","scope":"all","searchScopes":%s,"accountID":"%s","visibleSections":%s,"source":"%s","renderFingerprint":{"rows":[],"dataSource":{"cache":{"serverRevision":"cursor:search-fixture"}},"emptyState":null}}\n' "$route_identifier" "$scopes" "$account_id" "$sections" "$source" > "$proof_path"
        fi
      else
        mkdir -p "$(dirname "$proof_path")"
        route="settings"
        source="SettingsView"
        sections='["Profile","Security"]'
        if [[ "${SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF:-}" == "1" ]]; then
          route="kitchen"
          focus="profile"
          source="WrongView"
          sections='["Kitchen"]'
        elif [[ "$focus" == "notifications" ]]; then
          sections='["Notifications","This Device","Push Delivery","Notification Sync","Agent Access"]'
        fi
        printf '{"route":"%s","visualFocus":"%s","visibleSections":%s,"source":"%s"}\n' "$route" "$focus" "$sections" "$source" > "$proof_path"
      fi
    fi
    if [[ -n "$accessibility_proof_path" ]]; then
      accessibility_route="${expected_route:-kitchen}"
      accessibility_source="KitchenView"
      case "$accessibility_route" in
        search)
          accessibility_route="search"
          accessibility_source="SearchView"
          ;;
        settings)
          accessibility_route="settings"
          accessibility_source="SettingsView"
          ;;
        cookbook-detail)
          accessibility_route="cookbook-detail"
          accessibility_source="CookbookDetailView"
          ;;
        capture)
          accessibility_route="capture"
          accessibility_source="CaptureDraftView"
          ;;
      esac
      write_accessibility_proof "$accessibility_proof_path" "$accessibility_route" "macos" "app.spoonjoy.mac" "$accessibility_source"
    fi
  SH
  write_executable(bin_dir.join("pgrep"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "${SPOONJOY_CONTRACT_MACOS_RUNNING_FILE:-$PWD/macos-app-running}" ]]; then
      if [[ -n "${SPOONJOY_CONTRACT_STALE_MACOS_PID:-}" ]]; then
        printf '%s\n' "$SPOONJOY_CONTRACT_STALE_MACOS_PID"
      fi
      printf '12345\n'
    else
      exit 1
    fi
  SH
  write_executable(bin_dir.join("pkill"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    running_file="${SPOONJOY_CONTRACT_MACOS_RUNNING_FILE:-$PWD/macos-app-running}"
    if [[ -f "$running_file" ]]; then
      rm -f "$running_file"
    else
      exit 1
    fi
  SH
  write_executable(bin_dir.join("swift"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "${1:-}" != *"observe-macos-screenshot-evidence.swift" ]]; then
      if [[ -n "${SPOONJOY_CONTRACT_STALE_MACOS_PID:-}" && "${2:-}" == "$SPOONJOY_CONTRACT_STALE_MACOS_PID" ]]; then
        exit 1
      fi
      printf '67890\n'
      exit 0
    fi
    route=""
    output=""
    pid=""
    capture_run_nonce=""
    readiness_proof_path=""
    screenshot_path=""
    bundle_id=""
    bundle_path=""
    executable_path=""
    apns=0
    preflight=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --pid) pid="$2"; shift 2 ;;
        --route) route="$2"; shift 2 ;;
        --capture-run-nonce) capture_run_nonce="$2"; shift 2 ;;
        --readiness-proof-path) readiness_proof_path="$2"; shift 2 ;;
        --screenshot-path) screenshot_path="$2"; shift 2 ;;
        --bundle-id) bundle_id="$2"; shift 2 ;;
        --bundle-path) bundle_path="$2"; shift 2 ;;
        --executable-path) executable_path="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --apns) apns=1; shift ;;
        --preflight) preflight=1; shift ;;
        *) shift ;;
      esac
    done
    if [[ -n "${SPOONJOY_CONTRACT_MACOS_OBSERVER_EVENTS:-}" ]]; then
      observer_mode="full"
      if [[ "$preflight" == "1" ]]; then
        observer_mode="preflight"
      fi
      python3 - "$pid" "$SPOONJOY_CONTRACT_MACOS_OBSERVER_EVENTS" "$observer_mode" <<'PY'
import sys
import time

with open(sys.argv[2], "a") as output:
    output.write(f"{sys.argv[3]}-{sys.argv[1]} {time.monotonic()}\n")
PY
    fi
    if [[ -n "${SPOONJOY_CONTRACT_STALE_MACOS_PID:-}" && "$pid" == "$SPOONJOY_CONTRACT_STALE_MACOS_PID" ]]; then
      sleep "${SPOONJOY_CONTRACT_STALE_MACOS_PID_DELAY_SECONDS:-0}"
      exit 1
    fi
    if [[ "$preflight" == "1" ]]; then
      exit 0
    fi
    if [[ -n "${SPOONJOY_CONTRACT_VALID_MACOS_PID_DELAY_SECONDS:-}" ]]; then
      sleep "$SPOONJOY_CONTRACT_VALID_MACOS_PID_DELAY_SECONDS"
    fi
    identifiers='["fixture.terminal"]'
    if [[ "$apns" == "1" ]]; then
      identifiers='["fixture.terminal","settings.apns.this-device.heading","settings.apns.push-delivery.heading","settings.apns.notification-sync.heading"]'
    fi
    mkdir -p "$(dirname "$output")"
    ruby -rjson -rdigest -e '
      output, route, identifiers, pid, capture_run_nonce, readiness_proof_path, screenshot_path, bundle_id, bundle_path, executable_path = ARGV
      elements = JSON.parse(identifiers).map.with_index { |identifier, index| {identifier: identifier, role: "AXStaticText", title: identifier, frame: {x: 10, y: 10 + index * 45, width: 120, height: 44}, enabled: true, focused: false, actions: []} }
      terminal_identifier = route == "kitchen" ? "kitchen.cookbook.cookbook_weeknights" : "fixture.terminal"
      evidence = {
        platform: "macos", route: route, captureRunNonce: capture_run_nonce,
        readinessProofSHA256: Digest::SHA256.file(readiness_proof_path).hexdigest,
        screenshotSHA256: Digest::SHA256.file(screenshot_path).hexdigest,
        pid: Integer(pid), bundleIdentifier: bundle_id, bundlePath: File.expand_path(bundle_path),
        executablePath: File.expand_path(executable_path),
        executableSHA256: Digest::SHA256.file(executable_path).hexdigest,
        elements: elements, findings: []
      }
      if terminal_identifier != "fixture.terminal"
        evidence[:deepScroll] = {
          route: route,
          reachedTerminal: true,
          scrollAreaIdentifier: "#{route}.scroll",
          initialScrollValue: 0.0,
          finalScrollValue: 1.0,
          contentViewport: {x: 0, y: 0, width: 200, height: 120},
          terminalElement: {
            identifier: terminal_identifier,
            role: "AXButton",
            title: terminal_identifier,
            frame: {x: 10, y: 40, width: 120, height: 44},
            enabled: true,
            focused: false,
            actions: ["AXPress"]
          },
          findings: []
        }
      end
      File.write(output, JSON.generate(evidence) + "\n")
    ' "$output" "$route" "$identifiers" "$pid" "$capture_run_nonce" "$readiness_proof_path" "$screenshot_path" "$bundle_id" "$bundle_path" "$executable_path"
  SH
  write_executable(bin_dir.join("screencapture"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    out="${@: -1}"
    mkdir -p "$(dirname "$out")"
    printf mac-image > "$out"
  SH

  fixture_runtime_env = observer_product_env.merge(
    "HOME" => script_root.join("home").to_s,
    "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
    "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
    "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
  )
  stream_child_pid_path = script_root.join("foreground-stream-child-pids")
  observer_proof_path_log = script_root.join("observer-proof-paths")
  foreground_event_pipe = script_root.join("foreground-events.fifo")
  artifact_root.join("design-review-blocked.json").write("{}\n")
  success_stream_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot success lane",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
      "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
      "SPOONJOY_CONTRACT_OBSERVER_PROOF_PATH_FILE" => observer_proof_path_log.to_s
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(stream_child_pid_path, "screenshot success lane", from_index: success_stream_pid_index)
  observer_proof_paths = observer_proof_path_log.readlines(chomp: true)
  record_failure("screenshot observers did not record all three proof namespaces") unless observer_proof_paths.length == 3
  record_failure("screenshot observers reused a proof namespace across capture phases") unless observer_proof_paths.uniq.length == 3
  assert_file(artifact_root.join("design-review.json"), "screenshot success lane")
  assert_missing(artifact_root.join("design-review-blocked.json"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-mobile.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-mobile-accessibility.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-tablet.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-mobile-deep-scroll.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-mobile-accessibility-deep-scroll.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/ios-tablet-deep-scroll.png"), "screenshot success lane")
  assert_file(artifact_root.join("screenshots/macos-desktop.png"), "screenshot success lane")
  kitchen_review = assert_json(artifact_root.join("design-review.json"), "kitchen screenshot success lane")
  record_failure("kitchen screenshot route mismatch") unless kitchen_review["screenshotRoute"] == "kitchen"
  record_failure("kitchen screenshot account seed mismatch") unless kitchen_review["kitchenSeedAccountID"] == "chef_kitchen_capture"
  record_failure("kitchen screenshot set is not hash-bound") unless kitchen_review.fetch("screenshotArtifacts", {}).keys.sort == SCREENSHOT_ARTIFACTS.keys.sort
  record_failure("kitchen deep-scroll screenshot set is not hash-bound") unless kitchen_review.fetch("deepScrollScreenshotArtifacts", {}).keys.sort == DEEP_SCROLL_SCREENSHOT_ARTIFACTS.keys.sort
  record_failure("kitchen screenshot missing four capture-bound accessibility proof artifacts") unless kitchen_review.fetch("accessibilityProofArtifacts", []).length == 4
  kitchen_review.fetch("accessibilityProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "kitchen accessibility proof artifact")
    record_failure("kitchen accessibility proof source mismatch") unless proof["source"] == "KitchenView"
    record_failure("kitchen readiness proof did not settle") unless proof.dig("visualReadiness", "isSettled") == true
  end
  record_failure("kitchen screenshot missing observed accessibility evidence") unless kitchen_review.fetch("observedAccessibilityEvidenceArtifacts", []).length == 4
  kitchen_review.fetch("observedAccessibilityEvidenceArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "kitchen observed accessibility evidence")
    findings = proof["platform"] == "macos" ? proof["findings"] : proof["geometryFindings"]
    record_failure("kitchen observed accessibility evidence has findings") unless findings == []
  end
  kitchen_cache_json = assert_json(
    screenshot_fixture_state_file(script_root, "unit-contract", "ios", "native-durable-cache.json"),
    "kitchen iOS cache seed"
  )
  record_failure("kitchen cache seed account mismatch") unless kitchen_cache_json["accountID"] == "chef_kitchen_capture"
  record_failure("kitchen cache seed missing recipe detail") unless kitchen_cache_json.fetch("records", []).any? { |record| record["id"] == "recipe-detail:recipe_lemon_pantry_pasta" }

  visual_failure_root = temp_root.join("ios-visual-evidence-failure")
  visual_failure_root.mkpath
  assert_status(
    false,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      visual_failure_root,
      "--unit-slug",
      "unit-contract-ios-visual-failure"
    ],
    "iOS visual assertion is a hard release failure",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FAIL_IOS_OBSERVER" => "1",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  assert_missing(visual_failure_root.join("design-review.json"), "iOS visual assertion failure")
  assert_missing(visual_failure_root.join("design-review-blocked.json"), "iOS visual assertion failure")
  assert_missing(
    visual_failure_root.join("apple/unit-contract-ios-visual-failure-screenshots-core-simulator-blocker.json"),
    "iOS visual assertion failure"
  )

  partial_visual_failure_root = temp_root.join("ios-partial-visual-evidence-failure")
  partial_visual_failure_root.mkpath
  assert_status(
    false,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      partial_visual_failure_root,
      "--unit-slug",
      "unit-contract-ios-partial-visual-failure"
    ],
    "accessibility-size failure cannot publish a partial iOS evidence generation",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FAIL_IOS_AX_OBSERVER" => "1",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  [
    "screenshots/ios-mobile.png",
    "screenshots/ios-mobile-deep-scroll.png",
    "apple/unit-contract-ios-partial-visual-failure-observed-accessibility-ios.json",
    "apple/unit-contract-ios-partial-visual-failure-accessibility-proof-ios.json",
    "apple/unit-contract-ios-partial-visual-failure-accessibility-proof-ios-deep-scroll.json"
  ].each do |relative_path|
    assert_missing(
      partial_visual_failure_root.join(relative_path),
      "accessibility-size partial-generation failure"
    )
  end
  assert_missing(partial_visual_failure_root.join("design-review.json"), "accessibility-size partial-generation failure")
  assert_missing(partial_visual_failure_root.join("design-review-blocked.json"), "accessibility-size partial-generation failure")

  infrastructure_retry_root = temp_root.join("ios-observer-infrastructure-retry")
  infrastructure_retry_root.mkpath
  infrastructure_retry_marker = infrastructure_retry_root.join("observer-failed-once")
  infrastructure_retry_stream_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      infrastructure_retry_root,
      "--unit-slug",
      "unit-contract-ios-observer-infrastructure-retry"
    ],
    "transient observer infrastructure failure remains retryable",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FAIL_IOS_OBSERVER_ONCE_FILE" => infrastructure_retry_marker.to_s,
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "2"
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(
    stream_child_pid_path,
    "transient observer infrastructure retry",
    from_index: infrastructure_retry_stream_index
  )
  terminate_recorded_processes(stream_child_pid_path, from_index: infrastructure_retry_stream_index)
  assert_file(infrastructure_retry_marker, "transient observer infrastructure failure marker")
  assert_json(infrastructure_retry_root.join("design-review.json"), "transient observer infrastructure retry review")
  assert_missing(
    infrastructure_retry_root.join("apple/unit-contract-ios-observer-infrastructure-retry-screenshots-core-simulator-blocker.json"),
    "transient observer infrastructure retry"
  )

  publication_failure_root = temp_root.join("ios-publication-failure")
  publication_failure_root.mkpath
  publication_count_file = publication_failure_root.join("publication-count")
  publication_failure_stream_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    false,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      publication_failure_root,
      "--unit-slug",
      "unit-contract-ios-publication-failure"
    ],
    "mid-publication failure rolls back the complete iOS generation",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FAIL_IOS_PUBLISH_AFTER" => "2",
      "SPOONJOY_CONTRACT_IOS_PUBLISH_COUNT_FILE" => publication_count_file.to_s,
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(
    stream_child_pid_path,
    "mid-publication rollback",
    from_index: publication_failure_stream_index
  )
  terminate_recorded_processes(stream_child_pid_path, from_index: publication_failure_stream_index)
  [
    "screenshots/ios-mobile.png",
    "screenshots/ios-mobile-accessibility.png",
    "screenshots/ios-tablet.png",
    "screenshots/ios-mobile-deep-scroll.png",
    "screenshots/ios-mobile-accessibility-deep-scroll.png",
    "screenshots/ios-tablet-deep-scroll.png",
    "apple/unit-contract-ios-publication-failure-observed-accessibility-ios.json",
    "apple/unit-contract-ios-publication-failure-accessibility-proof-ios.json"
  ].each do |relative_path|
    assert_missing(publication_failure_root.join(relative_path), "mid-publication rollback")
  end
  assert_missing(publication_failure_root.join("design-review.json"), "mid-publication rollback")
  assert_missing(publication_failure_root.join("design-review-blocked.json"), "mid-publication rollback")
  assert_missing(
    publication_failure_root.join("apple/unit-contract-ios-publication-failure-screenshots-core-simulator-blocker.json"),
    "mid-publication rollback"
  )

  observed_launch_timeout_root = temp_root.join("observed-launch-timeout")
  observed_launch_timeout_root.mkpath
  observed_launch_timeout_hold = observed_launch_timeout_root.join("hold-started")
  observed_launch_timeout_pid_path = observed_launch_timeout_root.join("simctl-launch-pids")
  observed_launch_timeout_pid_index = observed_launch_timeout_pid_path.file? ? observed_launch_timeout_pid_path.readlines.length : 0
  observed_launch_timeout_stream_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      observed_launch_timeout_root,
      "--unit-slug",
      "unit-contract-observed-launch-timeout"
    ],
    "observed foreground recovers a simulator launch command timeout",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
      "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
      "SPOONJOY_CONTRACT_HOLD_AFTER_LAUNCH" => "1",
      "SPOONJOY_CONTRACT_HOLD_STARTED_FILE" => observed_launch_timeout_hold.to_s,
      "SPOONJOY_CONTRACT_LAUNCH_PID_FILE" => observed_launch_timeout_pid_path.to_s,
      "SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(
    stream_child_pid_path,
    "observed simulator launch timeout lane",
    from_index: observed_launch_timeout_stream_pid_index
  )
  assert_recorded_processes_gone(
    observed_launch_timeout_pid_path,
    "observed simulator launch timeout process",
    from_index: observed_launch_timeout_pid_index
  )
  terminate_recorded_processes(observed_launch_timeout_pid_path, from_index: observed_launch_timeout_pid_index)
  assert_file(observed_launch_timeout_root.join("design-review.json"), "observed simulator launch timeout lane")
  assert_missing(observed_launch_timeout_root.join("design-review-blocked.json"), "observed simulator launch timeout lane")

  stale_macos_pid_root = temp_root.join("stale-macos-pid-success")
  stale_macos_pid_root.mkpath
  stale_macos_observer_events = stale_macos_pid_root.join("observer-events")
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      stale_macos_pid_root,
      "--unit-slug",
      "unit-contract-stale-macos-pid"
    ],
    "macOS observer uses only the exact PID whose window was captured",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_STALE_MACOS_PID" => "54321",
      "SPOONJOY_CONTRACT_STALE_MACOS_PID_DELAY_SECONDS" => "30",
      "SPOONJOY_CONTRACT_MACOS_OBSERVER_EVENTS" => stale_macos_observer_events.to_s,
      "SPOONJOY_SCREENSHOT_MACOS_OBSERVER_TIMEOUT_SECONDS" => "20",
      "SPOONJOY_SCREENSHOT_MACOS_OBSERVER_PREFLIGHT_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_CONTRACT_VALID_MACOS_PID_DELAY_SECONDS" => "6"
    ),
    chdir: script_root
  )
  stale_macos_events = stale_macos_observer_events.readlines.map { |line| line.split }.select { |parts| parts.length == 2 }
  stale_index = stale_macos_events.index { |event| event.first.end_with?("-54321") }
  record_failure("stale macOS PID must not be observed after another PID supplied the captured window") if stale_index
  live_index = stale_macos_events.index { |event| event.first == "preflight-12345" }
  record_failure("captured macOS PID never received observer preflight") unless live_index
  valid_full_index = stale_macos_events.each_index.find do |index|
    live_index && index > live_index && stale_macos_events[index].first == "full-12345"
  end
  record_failure("captured macOS PID never received the full observer pass") unless valid_full_index
  stale_macos_observed = assert_json(
    stale_macos_pid_root.join("apple/unit-contract-stale-macos-pid-observed-accessibility-macos.json"),
    "exact captured macOS PID evidence"
  )
  record_failure("macOS observed evidence PID must equal the screenshot window PID") unless stale_macos_observed["pid"] == 12_345
  assert_file(stale_macos_pid_root.join("design-review.json"), "stale macOS PID success lane")
  assert_missing(stale_macos_pid_root.join("design-review-blocked.json"), "stale macOS PID success lane")

  foreground_intruder_root = temp_root.join("foreground-intruder")
  foreground_intruder_root.mkpath
  foreground_screenshot_captured = foreground_intruder_root.join("screenshot-captured")
  intruder_stream_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      foreground_intruder_root,
      "--unit-slug",
      "unit-contract-foreground-intruder"
    ],
    "foreground intruder blocks screenshot proof",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
      "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
      "SPOONJOY_CONTRACT_FOREGROUND_INTRUDER" => "after-capture",
      "SPOONJOY_CONTRACT_SCREENSHOT_CAPTURED_FILE" => foreground_screenshot_captured.to_s,
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(stream_child_pid_path, "foreground intruder lane", from_index: intruder_stream_pid_index)
  intruder_review = assert_json(foreground_intruder_root.join("design-review-blocked.json"), "foreground intruder review")
  record_failure("foreground intruder did not block screenshot proof") unless intruder_review["blocked"] == true
  assert_missing(foreground_intruder_root.join("design-review.json"), "foreground intruder lane")

  foreground_return_root = temp_root.join("foreground-intruder-return")
  foreground_return_root.mkpath
  foreground_return_screenshot = foreground_return_root.join("screenshot-captured")
  foreground_return_stream_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      foreground_return_root,
      "--unit-slug",
      "unit-contract-foreground-intruder-return"
    ],
    "foreground intruder return blocks bracketed screenshot proof",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
      "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
      "SPOONJOY_CONTRACT_FOREGROUND_INTRUDER" => "leave-and-return",
      "SPOONJOY_CONTRACT_SCREENSHOT_CAPTURED_FILE" => foreground_return_screenshot.to_s,
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1"
    ),
    chdir: script_root
  )
  assert_recorded_processes_gone(stream_child_pid_path, "foreground intruder return lane", from_index: foreground_return_stream_pid_index)
  foreground_return_review = assert_json(foreground_return_root.join("design-review-blocked.json"), "foreground intruder return review")
  record_failure("foreground intruder return did not block screenshot proof") unless foreground_return_review["blocked"] == true
  assert_missing(foreground_return_root.join("design-review.json"), "foreground intruder return lane")

  interruption_root = temp_root.join("foreground-interruption")
  interruption_root.mkpath
  interruption_hold_started = interruption_root.join("hold-started")
  interruption_launch_pid_path = interruption_root.join("simctl-launch-pids")
  interruption_launch_pid_index = interruption_launch_pid_path.file? ? interruption_launch_pid_path.readlines.length : 0
  interruption_stream_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  interruption_env = fixture_runtime_env.merge(
    "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
    "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
    "SPOONJOY_CONTRACT_HOLD_AFTER_LAUNCH" => "1",
    "SPOONJOY_CONTRACT_HOLD_STARTED_FILE" => interruption_hold_started.to_s,
    "SPOONJOY_CONTRACT_LAUNCH_PID_FILE" => interruption_launch_pid_path.to_s
  )
  stdin, stdout, stderr, interruption_thread = Open3.popen3(
    interruption_env,
    "bash",
    "scripts/capture-native-screenshots.sh",
    "--artifact-root",
    interruption_root.to_s,
    "--unit-slug",
    "unit-contract-interruption",
    chdir: script_root.to_s,
    pgroup: true
  )
  stdin.close
  interruption_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
  until interruption_hold_started.file? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= interruption_deadline
    sleep 0.05
  end
  record_failure("foreground interruption lane did not reach active stream state") unless interruption_hold_started.file?
  begin
    Process.kill("TERM", -interruption_thread.pid)
  rescue Errno::ESRCH
  end
  unless interruption_thread.join(5)
    begin
      Process.kill("KILL", -interruption_thread.pid)
    rescue Errno::ESRCH
    end
    interruption_thread.join
    record_failure("foreground interruption lane did not terminate promptly")
  end
  interruption_stdout = stdout.read
  interruption_stderr = stderr.read
  if interruption_stdout.include?("Traceback") || interruption_stderr.include?("Traceback") ||
     interruption_stdout.include?("PermissionError") || interruption_stderr.include?("PermissionError")
    record_failure("foreground interruption lane emitted a supervisor traceback")
  end
  assert_recorded_processes_gone(stream_child_pid_path, "foreground interruption lane", from_index: interruption_stream_pid_index)
  assert_recorded_processes_gone(
    interruption_launch_pid_path,
    "foreground interruption launch process",
    from_index: interruption_launch_pid_index
  )
  terminate_recorded_processes(interruption_launch_pid_path, from_index: interruption_launch_pid_index)

  stream_startup_race_root = temp_root.join("foreground-stream-startup-race")
  stream_startup_race_root.mkpath
  stream_leader_pid_path = stream_startup_race_root.join("stream-leader-pids")
  stream_leader_pid_index = stream_leader_pid_path.file? ? stream_leader_pid_path.readlines.length : 0
  startup_race_stream_child_pid_index = stream_child_pid_path.file? ? stream_child_pid_path.readlines.length : 0
  stdout, stderr, status = run_status(
    "ruby",
    "-rtimeout",
    "-e",
    PROCESS_TIMEOUT_WRAPPER,
    "30",
    "bash",
    "scripts/capture-native-screenshots.sh",
    "--artifact-root",
    stream_startup_race_root,
    "--unit-slug",
    "unit-contract-stream-startup-race",
    env: fixture_runtime_env.merge(
      "SPOONJOY_CONTRACT_FOREGROUND_EVENT_PIPE" => foreground_event_pipe.to_s,
      "SPOONJOY_CONTRACT_STREAM_CHILD_PID_FILE" => stream_child_pid_path.to_s,
      "SPOONJOY_CONTRACT_STREAM_LEADER_PID_FILE" => stream_leader_pid_path.to_s,
      "SPOONJOY_CONTRACT_STREAM_LEADER_DELAY_SECONDS" => "2",
      "SPOONJOY_CONTRACT_FAIL_IOS_LAUNCH" => "1",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1",
      "SPOONJOY_SCREENSHOT_IOS_FOREGROUND_PROBE_TIMEOUT_SECONDS" => "1"
    ),
    chdir: script_root
  )
  if status.exitstatus == 124
    record_failure(
      "foreground stream startup-race cleanup timed out\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  elsif !status.success?
    record_failure(
      "foreground stream startup-race cleanup did not write a terminal blocker\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  end
  assert_recorded_processes_gone(
    stream_leader_pid_path,
    "foreground stream startup-race leader",
    from_index: stream_leader_pid_index
  )
  if stream_child_pid_path.file? && stream_child_pid_path.readlines.length > startup_race_stream_child_pid_index
    assert_recorded_processes_gone(
      stream_child_pid_path,
      "foreground stream startup-race descendant",
      from_index: startup_race_stream_child_pid_index
    )
  end
  terminate_recorded_processes(stream_leader_pid_path, from_index: stream_leader_pid_index)
  terminate_recorded_processes(stream_child_pid_path, from_index: startup_race_stream_child_pid_index)

  cookbook_detail_root = temp_root.join("cookbook-detail-success")
  cookbook_detail_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      cookbook_detail_root,
      "--unit-slug",
      "unit-contract-cookbook-detail",
      "--route",
      "cookbook-detail"
    ],
    "cookbook detail screenshot success lane",
    env: fixture_runtime_env,
    chdir: script_root
  )
  assert_missing(cookbook_detail_root.join("design-review-blocked.json"), "cookbook detail screenshot success lane")
  cookbook_detail_review = assert_json(cookbook_detail_root.join("design-review.json"), "cookbook detail screenshot success lane")
  record_failure("cookbook detail screenshot route mismatch") unless cookbook_detail_review["screenshotRoute"] == "cookbook-detail"
  record_failure("cookbook detail account seed mismatch") unless cookbook_detail_review["cookbookSeedAccountID"] == "chef_kitchen_capture"
  record_failure("cookbook detail ID mismatch") unless cookbook_detail_review["cookbookID"] == "cookbook_weeknights"
  cookbook_detail_review.fetch("accessibilityProofArtifacts", []).each do |relative_path|
    proof = assert_json(cookbook_detail_root.join(relative_path), "cookbook detail accessibility proof artifact")
    record_failure("cookbook detail accessibility proof source mismatch") unless proof["source"] == "CookbookDetailView"
    record_failure("cookbook detail accessibility proof route mismatch") unless proof["route"] == "cookbook-detail"
  end
  cookbook_detail_state_json = assert_json(
    screenshot_fixture_state_file(script_root, "unit-contract-cookbook-detail", "ios", "native-app-state.json"),
    "cookbook detail iOS app state"
  )
  record_failure("cookbook detail state route mismatch") unless cookbook_detail_state_json["lastOpenedRoute"] == "cookbook:cookbook_weeknights"
  cookbook_detail_cache_json = assert_json(
    screenshot_fixture_state_file(script_root, "unit-contract-cookbook-detail", "ios", "native-durable-cache.json"),
    "cookbook detail iOS cache seed"
  )
  record_failure("cookbook detail cache seed missing detail") unless cookbook_detail_cache_json.fetch("records", []).any? { |record| record["id"] == "cookbook-detail:cookbook_weeknights" }

  missing_accessibility_root = temp_root.join("missing-accessibility-proof-artifacts")
  missing_accessibility_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      missing_accessibility_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot missing accessibility proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_SKIP_ACCESSIBILITY_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(missing_accessibility_root.join("design-review.json"), "screenshot missing accessibility proof lane")
  missing_accessibility_blocked_review = assert_json(missing_accessibility_root.join("design-review-blocked.json"), "screenshot missing accessibility proof lane")
  record_failure("missing accessibility proof lane did not block screenshot success") unless missing_accessibility_blocked_review["blocked"] == true

  wrong_accessibility_root = temp_root.join("wrong-accessibility-proof-artifacts")
  wrong_accessibility_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_accessibility_root,
      "--unit-slug",
      "unit-contract"
    ],
    "screenshot wrong accessibility proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_ACCESSIBILITY_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_accessibility_root.join("design-review.json"), "screenshot wrong accessibility proof lane")
  wrong_accessibility_blocked_review = assert_json(wrong_accessibility_root.join("design-review-blocked.json"), "screenshot wrong accessibility proof lane")
  record_failure("wrong accessibility proof lane did not block screenshot success") unless wrong_accessibility_blocked_review["blocked"] == true

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot success lane",
    env: fixture_runtime_env,
    chdir: script_root
  )
  assert_missing(artifact_root.join("design-review-blocked.json"), "search screenshot success lane")
  search_review = assert_json(artifact_root.join("design-review.json"), "search screenshot success lane")
  record_failure("search screenshot route mismatch") unless search_review["screenshotRoute"] == "search"
  record_failure("search screenshot account seed mismatch") unless search_review["searchSeedAccountID"] == "chef_search_capture"
  record_failure("search screenshot scopes mismatch") unless search_review["searchScopes"] == ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
  record_failure("search screenshot missing proof artifacts") unless search_review.fetch("searchSurfaceProofArtifacts", []).length >= 2
  search_review.fetch("searchSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "search screenshot proof artifact")
    record_failure("search screenshot proof route mismatch") unless proof["route"] == "search"
    record_failure("search screenshot proof route identifier mismatch") unless proof["routeIdentifier"] == "search:all:"
    record_failure("search screenshot proof query mismatch") unless proof["query"] == ""
    record_failure("search screenshot proof scope mismatch") unless proof["scope"] == "all"
    record_failure("search screenshot proof scopes mismatch") unless proof["searchScopes"] == ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
    record_failure("search screenshot proof account mismatch") unless proof["accountID"] == "chef_search_capture"
    record_failure("search screenshot proof missing Recipes") unless proof.fetch("visibleSections", []).include?("Recipes")
    record_failure("search screenshot proof missing Chefs") unless proof.fetch("visibleSections", []).include?("Chefs")
    record_failure("search screenshot proof source mismatch") unless proof["source"] == "SearchView"
  end
  search_cache_json = assert_json(
    screenshot_fixture_state_file(script_root, "unit-contract-search", "ios", "native-durable-cache.json"),
    "search iOS cache seed"
  )
  record_failure("search cache seed account mismatch") unless search_cache_json["accountID"] == "chef_search_capture"

  wrong_search_proof_root = temp_root.join("wrong-search-proof-artifacts")
  wrong_search_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_search_proof_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot wrong proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_SEARCH_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_search_proof_root.join("design-review.json"), "search screenshot wrong proof lane")
  wrong_search_blocked_review = assert_json(wrong_search_proof_root.join("design-review-blocked.json"), "search screenshot wrong proof lane")
  record_failure("wrong search proof lane did not block screenshot success") unless wrong_search_blocked_review["blocked"] == true

  missing_search_proof_root = temp_root.join("missing-search-proof-artifacts")
  missing_search_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      missing_search_proof_root,
      "--unit-slug",
      "unit-contract-search"
    ],
    "search screenshot missing proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_SKIP_SEARCH_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(missing_search_proof_root.join("design-review.json"), "search screenshot missing proof lane")
  missing_search_blocked_review = assert_json(missing_search_proof_root.join("design-review-blocked.json"), "search screenshot missing proof lane")
  record_failure("missing search proof lane did not block screenshot success") unless missing_search_blocked_review["blocked"] == true

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-settings"
    ],
    "settings screenshot success lane",
    env: fixture_runtime_env,
    chdir: script_root
  )
  assert_missing(artifact_root.join("design-review-blocked.json"), "settings screenshot success lane")
  settings_review = assert_json(artifact_root.join("design-review.json"), "settings screenshot success lane")
  record_failure("settings screenshot route mismatch") unless settings_review["screenshotRoute"] == "settings"
  record_failure("settings screenshot focus mismatch") unless settings_review["settingsVisualFocus"] == "profile"
  record_failure("settings screenshot account seed mismatch") unless settings_review["settingsSeedAccountID"] == "chef_settings_capture"
  record_failure("settings screenshot missing proof artifacts") unless settings_review.fetch("settingsSurfaceProofArtifacts", []).length >= 2
  settings_review.fetch("settingsSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "settings screenshot proof artifact")
    record_failure("settings screenshot proof route mismatch") unless proof["route"] == "settings"
    record_failure("settings screenshot proof focus mismatch") unless proof["visualFocus"] == "profile"
    record_failure("settings screenshot proof source mismatch") unless proof["source"] == "SettingsView"
  end
  cache_json = assert_json(
    screenshot_fixture_state_file(script_root, "unit-contract-settings", "ios", "native-durable-cache.json"),
    "settings iOS cache seed"
  )
  record_failure("settings cache seed account mismatch") unless cache_json["accountID"] == "chef_settings_capture"
  record_failure("settings cache seed missing token metadata") unless cache_json.fetch("records", []).any? { |record| record["id"] == "token-metadata" }
  record_failure("settings cache seed missing APNs status") unless cache_json.fetch("records", []).any? { |record| record["id"] == "apns-status" }

  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      artifact_root,
      "--unit-slug",
      "unit-contract-notifications"
    ],
    "notification screenshot success lane",
    env: fixture_runtime_env,
    chdir: script_root
  )
  assert_missing(artifact_root.join("design-review-blocked.json"), "notification screenshot success lane")
  notification_review = assert_json(artifact_root.join("design-review.json"), "notification screenshot success lane")
  record_failure("notification screenshot route mismatch") unless notification_review["screenshotRoute"] == "settings"
  record_failure("notification screenshot focus mismatch") unless notification_review["settingsVisualFocus"] == "notifications"
  record_failure("notification screenshot missing push delivery section") unless notification_review.fetch("settingsSections", []).include?("Push Delivery")
  record_failure("notification screenshot missing proof artifacts") unless notification_review.fetch("settingsSurfaceProofArtifacts", []).length >= 2
  notification_review.fetch("settingsSurfaceProofArtifacts", []).each do |relative_path|
    proof = assert_json(artifact_root.join(relative_path), "notification screenshot proof artifact")
    record_failure("notification screenshot proof route mismatch") unless proof["route"] == "settings"
    record_failure("notification screenshot proof focus mismatch") unless proof["visualFocus"] == "notifications"
    record_failure("notification screenshot proof missing push delivery") unless proof.fetch("visibleSections", []).include?("Push Delivery")
    record_failure("notification screenshot proof source mismatch") unless proof["source"] == "SettingsView"
  end

  wrong_proof_root = temp_root.join("wrong-proof-artifacts")
  wrong_proof_root.mkpath
  assert_status(
    true,
    [
      "bash",
      "scripts/capture-native-screenshots.sh",
      "--artifact-root",
      wrong_proof_root,
      "--unit-slug",
      "unit-contract-notifications"
    ],
    "notification screenshot wrong proof lane",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_CONTRACT_WRONG_SCREENSHOT_PROOF" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.05"
    },
    chdir: script_root
  )
  assert_missing(wrong_proof_root.join("design-review.json"), "notification screenshot wrong proof lane")
  wrong_blocked_review = assert_json(wrong_proof_root.join("design-review-blocked.json"), "notification screenshot wrong proof lane")
  record_failure("wrong proof lane did not block screenshot success") unless wrong_blocked_review["blocked"] == true
end

Dir.mktmpdir("spoonjoy-capture-ios-launch-timeout-contract") do |directory|
  temp_root = Pathname.new(directory)
  script_root = temp_root.join("app")
  artifact_root = script_root.join("artifacts")
  scripts_dir = script_root.join("scripts")
  bin_dir = script_root.join("bin")
  scripts_dir.mkpath
  bin_dir.mkpath
  fixture_cover = script_root.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png")
  fixture_cover.dirname.mkpath
  FileUtils.cp(ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png"), fixture_cover)
  FileUtils.cp(ROOT.join("scripts/capture-native-screenshots.sh"), scripts_dir.join("capture-native-screenshots.sh"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review.rb"), scripts_dir.join("validate-design-review.rb"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review-blocker.rb"), scripts_dir.join("validate-design-review-blocker.rb"))
  observer_app = script_root.join("observer/Spoonjoy.app")
  observer_runner = script_root.join("observer/SpoonjoyUITests-Runner.app")
  observer_xctestrun = script_root.join("observer/Spoonjoy.xctestrun")
  observer_app.mkpath
  observer_runner.mkpath
  observer_xctestrun.write("fixture\n")

  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    log=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --log) log="$2"; shift 2 ;;
        --blocker) shift 2 ;;
        --artifact-root) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$log")"
    printf 'Booting simulator: xcrun simctl boot ABCDEF12-3456-7890-ABCD-1234567890AB\nok\n' > "$log"
  SH
  write_executable(scripts_dir.join("smoke-macos.sh"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    blocker=""
    log=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --blocker) blocker="$2"; shift 2 ;;
        --log) log="$2"; shift 2 ;;
        --artifact-root) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$blocker")" "$(dirname "$log")"
    printf 'macOS intentionally skipped for iOS launch timeout contract\n' > "$log"
    ruby -rjson -e 'path, log_path = ARGV; File.write(path, JSON.pretty_generate({blocked: true, capability: "MacOSLaunch", command: "fixture macOS blocker", timeoutSeconds: 30, outputPath: log_path, reason: "macOS intentionally skipped.", ownerAction: "Use the iOS blocker for this fixture."}) + "\n")' "$blocker" "$log"
  SH
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      simctl\ get_app_container\ *)
        mkdir -p "$PWD/ios-container/Library/Application Support/Spoonjoy"
        printf '%s\n' "$PWD/ios-container"
        ;;
      simctl\ launch\ *)
        sleep 10
        ;;
      simctl\ spawn\ *\ launchctl\ list*)
        exit 0
        ;;
      simctl\ shutdown\ *|simctl\ boot\ *|simctl\ bootstatus\ *|simctl\ terminate\ *)
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  SH
  write_executable(bin_dir.join("open"), "#!/usr/bin/env bash\nexit 0\n")

  stdout, stderr, status = run_status(
    "ruby",
    "-rtimeout",
    "-e",
    PROCESS_TIMEOUT_WRAPPER,
    FIXTURE_PROCESS_TIMEOUT_SECONDS.to_s,
    "bash",
    "scripts/capture-native-screenshots.sh",
    "--artifact-root",
    artifact_root,
    "--unit-slug",
    "unit-contract-ios-launch-timeout",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_SCREENSHOT_IOS_LAUNCH_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SCREENSHOT_IOS_CAPTURE_ATTEMPTS" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.01",
      "SPOONJOY_SCREENSHOT_IOS_APP_PATH" => observer_app.to_s,
      "SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH" => observer_runner.to_s,
      "SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH" => observer_xctestrun.to_s
    },
    chdir: script_root
  )
  if status.exitstatus == 124
    record_failure(
      "iOS simulator launch timeout expected CoreSimulator blocker, but capture process timed out\n" \
      "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  elsif !status.success?
    record_failure(
      "iOS simulator launch timeout expected successful blocker manifest\n" \
      "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  else
    blocked_review = assert_json(artifact_root.join("design-review-blocked.json"), "iOS simulator launch timeout blocked review")
    record_failure("iOS simulator launch timeout blocker capability mismatch") unless blocked_review["capability"] == "CoreSimulator"
    source_blocker = assert_json(artifact_root.join("apple/unit-contract-ios-launch-timeout-screenshots-core-simulator-blocker.json"), "iOS simulator launch timeout source blocker")
    record_failure("iOS simulator launch timeout source command missing simctl launch") unless source_blocker.fetch("command", "").include?("simctl launch")
    record_failure("iOS simulator launch timeout source reason missing timeout") unless source_blocker.fetch("reason", "").downcase.include?("timeout")
    assert_missing(artifact_root.join("design-review.json"), "iOS simulator launch timeout")
  end
end

Dir.mktmpdir("spoonjoy-capture-cleanup-timeout-contract") do |directory|
  temp_root = Pathname.new(directory)
  script_root = temp_root.join("app")
  artifact_root = script_root.join("artifacts")
  scripts_dir = script_root.join("scripts")
  bin_dir = script_root.join("bin")
  scripts_dir.mkpath
  bin_dir.mkpath
  fixture_cover = script_root.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png")
  fixture_cover.dirname.mkpath
  FileUtils.cp(ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png"), fixture_cover)
  FileUtils.cp(ROOT.join("scripts/capture-native-screenshots.sh"), scripts_dir.join("capture-native-screenshots.sh"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review.rb"), scripts_dir.join("validate-design-review.rb"))
  FileUtils.cp(ROOT.join("scripts/validate-design-review-blocker.rb"), scripts_dir.join("validate-design-review-blocker.rb"))
  observer_app = script_root.join("observer/Spoonjoy.app")
  observer_runner = script_root.join("observer/SpoonjoyUITests-Runner.app")
  observer_xctestrun = script_root.join("observer/Spoonjoy.xctestrun")
  observer_macos_app = script_root.join("observer/Spoonjoy-macOS.app")
  observer_app.mkpath
  observer_runner.mkpath
  observer_xctestrun.write("fixture\n")
  observer_macos_app.join("Contents/MacOS").mkpath
  observer_macos_app.join("Contents/MacOS/Spoonjoy").write("fixture\n")
  observer_macos_app.join("Contents/Info.plist").write("<plist version=\"1.0\"><dict><key>CFBundleExecutable</key><string>Spoonjoy</string></dict></plist>\n")
  write_executable(scripts_dir.join("run-ios-screenshot-observer.py"), <<~'PY')
    #!/usr/bin/env python3
    import argparse, hashlib, json
    from pathlib import Path
    parser = argparse.ArgumentParser()
    for name in ("xctestrun", "app", "runner", "destination-udid", "platform", "route", "output", "readiness-proof-output", "work-root", "log", "timeout-seconds", "screenshot-output", "deep-scroll-screenshot-output"):
        parser.add_argument(f"--{name}")
    parser.add_argument("--environment", action="append", default=[])
    parser.add_argument("--environment-json")
    args = parser.parse_args()
    terminal_identifier = "kitchen.cookbook.cookbook_weeknights" if args.route == "kitchen" else "fixture.terminal"
    terminal = {"identifier":terminal_identifier,"label":"Terminal","type":"staticText","frame":{"x":10,"y":40,"width":44,"height":40},"exists":True,"hittable":False,"enabled":True,"focused":None}
    environment = json.loads(Path(args.environment_json).read_text()) if args.environment_json else {}
    proof_path = Path(environment["SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH"])
    proof = json.loads(proof_path.read_bytes())
    proof["captureRunNonce"] = environment["SPOONJOY_SCREENSHOT_RUN_NONCE"]
    proof["readinessGeneration"] = 1
    proof["visualReadiness"]["generation"] = 1
    proof_bytes = (json.dumps(proof, sort_keys=True) + "\n").encode()
    proof_path.write_bytes(proof_bytes)
    readiness_output = Path(args.readiness_proof_output)
    readiness_output.parent.mkdir(parents=True, exist_ok=True)
    readiness_output.write_bytes(proof_bytes)
    content_size = environment.get("SPOONJOY_OBSERVED_CONTENT_SIZE_CATEGORY", "large")
    initial_filename = f"{proof_path.stem}.generation-1{proof_path.suffix or '.json'}"
    initial_handshake = {"captureRunNonce":proof["captureRunNonce"],"route":args.route,"source":proof["source"],"readinessGeneration":1,"proofFileName":initial_filename,"proofSHA256":hashlib.sha256(proof_bytes).hexdigest()}
    deep_proof = dict(proof)
    deep_proof["visualReadiness"] = dict(proof["visualReadiness"])
    deep_proof["readinessGeneration"] = 2
    deep_proof["visualReadiness"]["generation"] = 2
    deep_proof_bytes = (json.dumps(deep_proof, sort_keys=True) + "\n").encode()
    deep_filename = f"{proof_path.stem}.generation-2{proof_path.suffix or '.json'}"
    deep_handshake = {"captureRunNonce":proof["captureRunNonce"],"route":args.route,"source":proof["source"],"readinessGeneration":2,"proofFileName":deep_filename,"proofSHA256":hashlib.sha256(deep_proof_bytes).hexdigest()}
    evidence = {"platform":args.platform,"route":args.route,"viewport":{"x":0,"y":0,"width":100,"height":80},"elements":[terminal],"auditIssues":[],"verifiedContrastFalsePositives":[],"screenshotSHA256":hashlib.sha256(b"png").hexdigest(),"geometryFindings":[],"observedContentSizeCategory":content_size,"observedDynamicTypeSize":"accessibility5" if content_size == "accessibility-extra-extra-extra-large" else "large","readinessHandshake":initial_handshake,"toolLimitations":[],"deepScroll":{"route":args.route,"reachedTerminal":True,"swipeCount":2,"contentViewport":{"x":0,"y":0,"width":100,"height":80},"tabBarFrame":{"x":0,"y":80,"width":100,"height":20},"terminalElement":terminal,"findings":[],"auditIssues":[],"verifiedContrastFalsePositives":[],"screenshotSHA256":hashlib.sha256(b"png").hexdigest(),"readinessHandshake":deep_handshake,"observedContentMovement":True,"contentFitsWithoutScrolling":False,"toolLimitations":[]}}
    deep_output = readiness_output.with_name(f"{readiness_output.stem}-deep-scroll{readiness_output.suffix or '.json'}")
    deep_output.write_bytes(deep_proof_bytes)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence) + "\n")
    if args.screenshot_output:
        screenshot = Path(args.screenshot_output)
        screenshot.parent.mkdir(parents=True, exist_ok=True)
        screenshot.write_bytes(b"png")
    if args.deep_scroll_screenshot_output:
        screenshot = Path(args.deep_scroll_screenshot_output)
        screenshot.parent.mkdir(parents=True, exist_ok=True)
        screenshot.write_bytes(b"png")
  PY

  success_stub = <<~'SH'
    #!/usr/bin/env bash
    set -euo pipefail
    log=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --log) log="$2"; shift 2 ;;
        --blocker) shift 2 ;;
        --artifact-root) shift 2 ;;
        *) shift ;;
      esac
    done
    mkdir -p "$(dirname "$log")"
    udid="ABCDEF12-3456-7890-ABCD-1234567890AB"
    if [[ "${SPOONJOY_IOS_SIMULATOR_FAMILY:-iphone}" == "ipad" ]]; then
      udid="FEDCBA98-7654-3210-ABCD-0987654321FE"
    fi
    printf 'Booting simulator: xcrun simctl boot %s\nok\n' "$udid" > "$log"
  SH
  write_executable(scripts_dir.join("smoke-ios-simulator.sh"), success_stub)
  write_executable(scripts_dir.join("smoke-macos.sh"), success_stub)
  write_executable(bin_dir.join("launchctl"), "#!/usr/bin/env bash\nexit 0\n")
  write_executable(bin_dir.join("pkill"), <<~'SH')
    #!/usr/bin/env bash
    rm -f "$PWD/spoonjoy-running"
  SH
  write_executable(bin_dir.join("pgrep"), <<~'SH')
    #!/usr/bin/env bash
    [[ -f "$PWD/spoonjoy-running" ]] || exit 1
    printf '12345\n'
  SH
  write_executable(bin_dir.join("swift"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "${1:-}" != *"observe-macos-screenshot-evidence.swift" ]]; then printf '67890\n'; exit 0; fi
    output=""; route=""; pid=""; capture_run_nonce=""; readiness_proof_path=""; screenshot_path=""; bundle_id=""; bundle_path=""; executable_path=""; preflight=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --output) output="$2"; shift 2 ;;
        --route) route="$2"; shift 2 ;;
        --pid) pid="$2"; shift 2 ;;
        --capture-run-nonce) capture_run_nonce="$2"; shift 2 ;;
        --readiness-proof-path) readiness_proof_path="$2"; shift 2 ;;
        --screenshot-path) screenshot_path="$2"; shift 2 ;;
        --bundle-id) bundle_id="$2"; shift 2 ;;
        --bundle-path) bundle_path="$2"; shift 2 ;;
        --executable-path) executable_path="$2"; shift 2 ;;
        --preflight) preflight=1; shift ;;
        *) shift ;;
      esac
    done
    [[ "$preflight" == "0" ]] || exit 0
    mkdir -p "$(dirname "$output")"
    ruby -rjson -rdigest -e '
      output, route, pid, capture_run_nonce, readiness_proof_path, screenshot_path, bundle_id, bundle_path, executable_path = ARGV
      terminal_identifier = route == "kitchen" ? "kitchen.cookbook.cookbook_weeknights" : "fixture.terminal"
      evidence = {
        platform: "macos", route: route, captureRunNonce: capture_run_nonce,
        readinessProofSHA256: Digest::SHA256.file(readiness_proof_path).hexdigest,
        screenshotSHA256: Digest::SHA256.file(screenshot_path).hexdigest,
        pid: Integer(pid), bundleIdentifier: bundle_id, bundlePath: File.expand_path(bundle_path),
        executablePath: File.expand_path(executable_path),
        executableSHA256: Digest::SHA256.file(executable_path).hexdigest,
        elements: [{identifier: "fixture.terminal", role: "AXStaticText", title: "Terminal", frame: {x: 10, y: 10, width: 120, height: 44}, enabled: true, focused: false, actions: []}],
        findings: []
      }
      if terminal_identifier != "fixture.terminal"
        evidence[:deepScroll] = {
          route: route,
          reachedTerminal: true,
          scrollAreaIdentifier: "#{route}.scroll",
          initialScrollValue: 0.0,
          finalScrollValue: 1.0,
          contentViewport: {x: 0, y: 0, width: 200, height: 120},
          terminalElement: {
            identifier: terminal_identifier,
            role: "AXButton",
            title: terminal_identifier,
            frame: {x: 10, y: 40, width: 120, height: 44},
            enabled: true,
            focused: false,
            actions: ["AXPress"]
          },
          findings: []
        }
      end
      File.write(output, JSON.generate(evidence) + "\n")
    ' "$output" "$route" "$pid" "$capture_run_nonce" "$readiness_proof_path" "$screenshot_path" "$bundle_id" "$bundle_path" "$executable_path"
  SH
  write_executable(bin_dir.join("screencapture"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    out="${@: -1}"
    mkdir -p "$(dirname "$out")"
    printf mac-image > "$out"
  SH
  write_executable(bin_dir.join("xcrun"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    write_accessibility_proof() {
      local output_path="$1"
      local platform="$2"
      local bundle="$3"
      mkdir -p "$(dirname "$output_path")"
      observed_dynamic_type="large"
      if [[ -f "$PWD/contract-content-size" ]] && [[ "$(cat "$PWD/contract-content-size")" == "accessibility-extra-extra-extra-large" ]]; then
        observed_dynamic_type="accessibility5"
      fi
      capture_run_nonce="${SIMCTL_CHILD_SPOONJOY_SCREENSHOT_RUN_NONCE:-}"
      printf '{"platform":"%s","route":"kitchen","source":"KitchenView","captureRunNonce":"%s","readinessGeneration":1,"launchEnvironmentProof":{},"screenshotStateSnapshotProof":{"stateDirectoryResolved":true,"appSnapshotPresent":true,"appSnapshotJSONReadable":true,"syncSnapshotPresent":true,"syncSnapshotJSONReadable":true},"observedDynamicTypeSize":"%s","observedReduceMotion":false,"visualReadiness":{"generation":1,"expectedMediaCount":1,"loadedMediaCount":1,"pendingMediaCount":0,"failedMediaCount":0,"blockingIndicatorCount":0,"isSettled":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"%s"}\n' "$platform" "$capture_run_nonce" "$observed_dynamic_type" "$bundle" > "$output_path"
    }
    case "$*" in
      simctl\ get_app_container\ *)
        mkdir -p "$PWD/ios-container/Library/Application Support/Spoonjoy"
        printf '%s\n' "$PWD/ios-container"
        ;;
      simctl\ ui\ *\ content_size\ *)
        content_size="${@: -1}"
        printf '%s\n' "$content_size" > "$PWD/contract-content-size"
        while IFS= read -r proof_path; do
          ruby -rjson -e '
            path, content_size = ARGV
            payload = JSON.parse(File.read(path))
            payload["observedDynamicTypeSize"] = content_size == "accessibility-extra-extra-extra-large" ? "accessibility5" : "large"
            File.write(path, JSON.generate(payload) + "\n")
          ' "$proof_path" "$content_size"
        done < <(find "$PWD/ios-container" -name native-accessibility-proof.json -type f 2>/dev/null)
        ;;
      simctl\ launch\ *)
        platform="ios"
        if [[ "$*" == *"FEDCBA98-7654-3210-ABCD-0987654321FE"* ]]; then
          platform="ipad"
        fi
        write_accessibility_proof "$SIMCTL_CHILD_SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH" "$platform" "app.spoonjoy"
        printf 'app.spoonjoy: 12345\n'
        ;;
      simctl\ spawn\ *\ launchctl\ list*)
        exit 0
        ;;
      simctl\ spawn\ *\ log\ stream*)
        printf 'Front display did change: <SBApplication; app.spoonjoy>\n'
        trap 'exit 0' TERM INT
        while true; do
          if [[ -f "$PWD/cleanup-foreground-barrier" ]]; then
            cat "$PWD/cleanup-foreground-barrier"
            rm -f "$PWD/cleanup-foreground-barrier"
          fi
          sleep 0.05
        done
        ;;
      simctl\ spawn\ *\ log\ emit*)
        printf 'Spoonjoy screenshot foreground barrier: %s\n' "${@: -1}" > "$PWD/cleanup-foreground-barrier"
        ;;
      simctl\ io\ *\ screenshot\ *)
        out="${@: -1}"
        mkdir -p "$(dirname "$out")"
        python3 - "$out" <<'PY'
import binascii
import struct
import sys
import zlib

path = sys.argv[1]
width, height = 400, 800
palette = [
    (38, 34, 30), (174, 112, 47), (92, 111, 74), (252, 250, 245),
    (105, 93, 82), (221, 209, 188), (129, 65, 54), (70, 96, 114),
    (189, 157, 91), (151, 143, 132)
]
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        color = (246, 239, 225)
        if y < 72:
            color = (38, 34, 30)
        elif 100 <= y < 300 and 24 <= x < 376:
            color = palette[((x - 24) // 32 + (y - 100) // 24) % len(palette)]
        elif 690 <= y < 760 and 32 <= x < 368:
            color = palette[((x - 32) // 48) % len(palette)]
        row.extend(color)
    rows.append(b"\x00" + bytes(row))
raw = b"".join(rows)
def chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", binascii.crc32(kind + payload) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw))
png += chunk(b"IEND", b"")
with open(path, "wb") as handle:
    handle.write(png)
PY
        ;;
      *)
        exit 0
        ;;
    esac
  SH
  write_executable(bin_dir.join("osascript"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    script="$*"
    if [[ "$script" == *"to quit"* ]]; then
      sleep 10
    elif [[ "$script" == *"open location"* ]]; then
      state="$HOME/Library/Application Support/Spoonjoy/native-app-state.json"
      mkdir -p "$(dirname "$state")"
      printf '{"hasCompletedFirstRun":true,"lastOpenedRoute":"kitchen"}\n' > "$state"
    fi
  SH
  write_executable(bin_dir.join("open"), <<~'SH')
    #!/usr/bin/env bash
    set -euo pipefail
    : > "$PWD/spoonjoy-running"
    output_path="${SPOONJOY_SCREENSHOT_ACCESSIBILITY_PROOF_PATH:-}"
    if [[ -n "$output_path" ]]; then
      mkdir -p "$(dirname "$output_path")"
      printf '{"platform":"macos","route":"kitchen","source":"KitchenView","captureRunNonce":"%s","readinessGeneration":1,"launchEnvironmentProof":{},"screenshotStateSnapshotProof":{"stateDirectoryResolved":true,"appSnapshotPresent":true,"appSnapshotJSONReadable":true,"syncSnapshotPresent":true,"syncSnapshotJSONReadable":true},"observedDynamicTypeSize":"large","observedReduceMotion":false,"visualReadiness":{"generation":1,"expectedMediaCount":1,"loadedMediaCount":1,"pendingMediaCount":0,"failedMediaCount":0,"blockingIndicatorCount":0,"isSettled":true},"emittedBy":"SpoonjoyApp","bundleIdentifier":"app.spoonjoy.mac"}\n' "${SPOONJOY_SCREENSHOT_RUN_NONCE:-}" > "$output_path"
    fi
  SH

  stdout, stderr, status = run_status(
    "ruby",
    "-rtimeout",
    "-e",
    PROCESS_TIMEOUT_WRAPPER,
    FIXTURE_PROCESS_TIMEOUT_SECONDS.to_s,
    "bash",
    "scripts/capture-native-screenshots.sh",
    "--artifact-root",
    artifact_root,
    "--unit-slug",
    "unit-contract-cleanup-timeout",
    env: {
      "HOME" => script_root.join("home").to_s,
      "PATH" => "#{bin_dir}:#{ENV.fetch("PATH")}",
      "SPOONJOY_SCREENSHOT_CLEANUP_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SCREENSHOT_MACOS_LAUNCH_TIMEOUT_SECONDS" => "1",
      "SPOONJOY_SCREENSHOT_IOS_FOREGROUND_PROBE_TIMEOUT_SECONDS" => "2",
      "SPOONJOY_SCREENSHOT_PROOF_ATTEMPTS" => "1",
      "SPOONJOY_SCREENSHOT_PROOF_SLEEP_SECONDS" => "0.01",
      "SPOONJOY_SCREENSHOT_IOS_APP_PATH" => observer_app.to_s,
      "SPOONJOY_SCREENSHOT_IOS_UI_TEST_RUNNER_PATH" => observer_runner.to_s,
      "SPOONJOY_SCREENSHOT_IOS_XCTESTRUN_PATH" => observer_xctestrun.to_s,
      "SPOONJOY_SCREENSHOT_MACOS_APP_PATH" => observer_macos_app.to_s
    },
    chdir: script_root
  )
  if status.exitstatus == 124
    record_failure(
      "macOS cleanup timeout expected terminal screenshot artifact, but capture process timed out\n" \
      "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  elsif !status.success?
    record_failure(
      "macOS cleanup timeout expected successful terminal screenshot artifact\n" \
      "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    )
  else
    has_terminal_artifact = artifact_root.join("design-review.json").file? || artifact_root.join("design-review-blocked.json").file?
    record_failure("macOS cleanup timeout did not produce a terminal design review artifact") unless has_terminal_artifact
    cleanup_log = artifact_root.join("apple/unit-contract-cleanup-timeout-screenshots-inner.log")
    record_failure("macOS cleanup timeout log missing") unless cleanup_log.file?
    record_failure("macOS cleanup timeout was not logged") unless cleanup_log.file? && cleanup_log.read.include?("cleanup timeout")
  end
end

if DESIGN_REVIEW.file? && DESIGN_REVIEW_BLOCKED.file?
  record_failure("conflicting repository design review success and blocker artifacts")
elsif DESIGN_REVIEW.file?
  assert_status(true, ["ruby", validator, DESIGN_REVIEW], "repository design review manifest")
elsif DESIGN_REVIEW_BLOCKED.file?
  assert_status(
    true,
    ["ruby", blocker_validator, DESIGN_REVIEW_BLOCKED, "--artifact-root", ARTIFACT_ROOT, "--unit-slug", "matrix"],
    "repository design review blocker manifest"
  )
else
  # The full validation matrix deletes runtime screenshot artifacts before it
  # runs this source-contract check. The capture/design-review rows own the
  # final repository artifact validation after the runtime attempt finishes.
end

unless $failures.empty?
  warn $failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end

puts "launch screenshot contract ok"
