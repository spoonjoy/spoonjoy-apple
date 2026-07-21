#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class NativeScreenshotProvenanceTest < Minitest::Test
  SCRIPT = Pathname.new(__dir__).join("../native-screenshot-provenance.rb").expand_path
  MATRIX_SCRIPT = Pathname.new(__dir__).join("../capture-native-screenshot-matrix.sh").expand_path
  SHA_PATTERN = /\A[0-9a-f]{40}\z/
  DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

  def setup
    @temporary_directory = Dir.mktmpdir("spoonjoy-native-screenshot-provenance")
    @root = Pathname.new(@temporary_directory)
    @repository = @root.join("repository")
    @artifact_root = @root.join("artifacts")
    @bin = @root.join("bin")
    @build_log = @root.join("xcodebuild.log")
    @repository.mkpath
    @artifact_root.mkpath
    @bin.mkpath
    write_fixture_repository
    write_fake_apple_tools
  end

  def teardown
    if @temporary_directory && File.exist?(@temporary_directory)
      FileUtils.chmod_R(0o700, @temporary_directory, force: true)
      FileUtils.remove_entry(@temporary_directory)
    end
  end

  def test_build_exports_exact_commit_and_emits_verifiable_manifest
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    source_sha = git("rev-parse", "HEAD").strip
    source_tree = git("rev-parse", "HEAD^{tree}").strip
    build_root = @artifact_root.join("shared-builds", source_sha, "build-uuid")

    assert_match SHA_PATTERN, manifest.dig("source", "sha")
    assert_match SHA_PATTERN, manifest.dig("source", "tree")
    assert_equal source_sha, manifest.dig("source", "sha")
    assert_equal source_tree, manifest.dig("source", "tree")
    assert_equal @repository.realpath.to_s, manifest.dig("source", "repositoryRoot")
    assert_equal build_root.realpath.to_s, manifest.dig("run", "buildRoot")
    assert_equal build_root.join("source").realpath.to_s, manifest.dig("run", "sourceSnapshot")
    assert_equal "matrix-run-a", manifest.dig("run", "matrixRunUUID")
    assert_equal "build-uuid", manifest.dig("run", "buildUUID")
    assert_equal "Xcode 26.5\nBuild version 17Z1", manifest.dig("tools", "xcodeVersion")
    assert_equal "26.5", manifest.dig("tools", "sdkVersions", "iphonesimulator")
    assert_equal "27.0", manifest.dig("tools", "sdkVersions", "macosx")
    assert_match DIGEST_PATTERN, manifest.fetch("manifestSha256")

    %w[ios macos].each do |platform|
      build = manifest.fetch("builds").fetch(platform)
      assert build.fetch("xcodebuildArguments").is_a?(Array)
      assert_includes build.fetch("xcodebuildArguments"), "GCC_TREAT_WARNINGS_AS_ERRORS=YES"
      assert_equal build_root.join("source").realpath.to_s, build.fetch("workingDirectory")
      assert_match DIGEST_PATTERN, build.fetch("executableSha256")
      assert_match DIGEST_PATTERN, build.fetch("bundleTreeSha256")
      refute File.writable?(build.fetch("executablePath")), "#{platform} executable must be sealed read-only"
    end

    assert_equal "app.spoonjoy", manifest.dig("builds", "ios", "bundleIdentifier")
    assert_equal "app.spoonjoy.mac", manifest.dig("builds", "macos", "bundleIdentifier")
    assert manifest.dig("builds", "macos", "executablePath").end_with?("/Spoonjoy.app/Contents/MacOS/Spoonjoy")
    ios_build = manifest.dig("builds", "ios")
    assert_includes ios_build.fetch("xcodebuildArguments"), "build-for-testing"
    assert_match DIGEST_PATTERN, ios_build.fetch("uiTestRunnerTreeSha256")
    assert_match DIGEST_PATTERN, ios_build.fetch("xctestrunSha256")
    refute File.writable?(ios_build.fetch("uiTestRunnerPath"))
    refute File.writable?(ios_build.fetch("xctestrunPath"))
    assert build_root.join("source/Spoonjoy.xcodeproj/project.pbxproj").file?
    refute build_root.join("source/.git").exist?
    assert_equal 2, @build_log.readlines.length

    stdout, stderr, status = verify_manifest(manifest_path)
    assert status.success?, "verify failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    assert_includes stdout, "native screenshot provenance verified"
  end

  def test_build_rejects_dirty_tracked_source
    @repository.join("README.md").write("dirty\n")

    _stdout, stderr, status = run_tool("build", *build_arguments)

    refute status.success?
    assert_includes stderr, "source worktree is not clean"
    assert_includes stderr, "README.md"
  end

  def test_build_rejects_dirty_untracked_source
    @repository.join("untracked.txt").write("dirty\n")

    _stdout, stderr, status = run_tool("build", *build_arguments)

    refute status.success?
    assert_includes stderr, "source worktree is not clean"
    assert_includes stderr, "untracked.txt"
  end

  def test_verify_rejects_changed_head_and_tree
    manifest_path = build_manifest
    @repository.join("second.txt").write("second\n")
    git("add", "second.txt")
    git("commit", "-m", "second")

    _stdout, stderr, status = verify_manifest(manifest_path)

    refute status.success?
    assert_includes stderr, "source HEAD changed"
  end

  def test_verify_rejects_executable_mutation
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    executable = Pathname.new(manifest.dig("builds", "ios", "executablePath"))
    executable.chmod(0o755)
    executable.write("mutated\n")

    _stdout, stderr, status = verify_manifest(manifest_path)

    refute status.success?
    assert_includes stderr, "iOS executable hash mismatch"
  end

  def test_verify_rejects_ui_test_runner_mutation
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    runner = Pathname.new(manifest.dig("builds", "ios", "uiTestRunnerPath"))
    executable = runner.join("SpoonjoyUITests-Runner")
    executable.chmod(0o755)
    executable.write("mutated\n")

    _stdout, stderr, status = verify_manifest(manifest_path)

    refute status.success?
    assert_includes stderr, "iOS UI-test runner tree hash mismatch"
  end

  def test_verify_rejects_xctestrun_mutation
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    xctestrun = Pathname.new(manifest.dig("builds", "ios", "xctestrunPath"))
    xctestrun.chmod(0o644)
    xctestrun.write("mutated\n")

    _stdout, stderr, status = verify_manifest(manifest_path)

    refute status.success?
    assert_includes stderr, "iOS xctestrun hash mismatch"
  end

  def test_verify_rejects_stale_or_tampered_manifest
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    manifest["source"]["tree"] = "0" * 40
    manifest_path.chmod(0o644)
    manifest_path.write(JSON.pretty_generate(manifest) + "\n")

    _stdout, stderr, status = verify_manifest(manifest_path)

    refute status.success?
    assert_includes stderr, "manifest hash mismatch"
  end

  def test_verify_rejects_missing_and_wrong_manifest
    missing = @artifact_root.join("apple/missing.json")
    _stdout, stderr, status = verify_manifest(missing)
    refute status.success?
    assert_includes stderr, "provenance manifest is missing"

    wrong = @artifact_root.join("apple/unit-screenshot-provenance.json")
    wrong.dirname.mkpath
    wrong.write("{}\n")
    _stdout, stderr, status = verify_manifest(wrong)
    refute status.success?
    assert_includes stderr, "manifest is missing required keys"
  end

  def test_verify_rejects_prior_run_reuse
    manifest_path = build_manifest

    _stdout, stderr, status = verify_manifest(manifest_path, matrix_run_uuid: "matrix-run-b")

    refute status.success?
    assert_includes stderr, "matrix run UUID mismatch"
  end

  def test_verify_rejects_noncanonical_prebuilt_path
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)
    wrong_ios_path = @root.join("copied/Spoonjoy.app")
    wrong_ios_path.dirname.mkpath
    FileUtils.cp_r(manifest.dig("builds", "ios", "appPath"), wrong_ios_path)

    _stdout, stderr, status = verify_manifest(manifest_path, ios_app: wrong_ios_path)

    refute status.success?
    assert_includes stderr, "iOS app override does not match the manifest canonical path"
  end

  def test_matrix_fails_closed_on_dirty_source_before_capture
    @repository.join("README.md").write("dirty\n")

    stdout, stderr, status = run_matrix(matrix_run_uuid: "matrix-run-dirty")

    refute status.success?, "dirty matrix unexpectedly passed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    refute capture_marker.exist?
    blocker = JSON.parse(@artifact_root.join("apple/unit-shared-build-blocker.json").read)
    assert_includes blocker.fetch("reason"), "provenance"
    assert_includes @artifact_root.join("apple/unit-provenance.log").read, "source worktree is not clean"
  end

  def test_matrix_rejects_prebuilt_apps_without_manifest
    ios_app, macos_app = write_unattested_prebuilt_apps

    _stdout, stderr, status = run_matrix(ios_app: ios_app, macos_app: macos_app)

    refute status.success?
    assert_includes stderr, "prebuilt app overrides require"
    refute capture_marker.exist?
  end

  def test_matrix_rejects_manifest_from_a_prior_run
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)

    _stdout, stderr, status = run_matrix(
      matrix_run_uuid: "matrix-run-b",
      manifest: manifest_path,
      ios_app: manifest.dig("builds", "ios", "appPath"),
      macos_app: manifest.dig("builds", "macos", "appPath")
    )

    refute status.success?
    assert_includes stderr, "matrix run UUID mismatch"
    refute capture_marker.exist?
  end

  def test_matrix_accepts_only_matching_manifest_and_verifies_before_and_after
    manifest_path = build_manifest
    manifest = JSON.parse(manifest_path.read)

    stdout, stderr, status = run_matrix(
      matrix_run_uuid: "matrix-run-a",
      manifest: manifest_path,
      ios_app: manifest.dig("builds", "ios", "appPath"),
      macos_app: manifest.dig("builds", "macos", "appPath")
    )

    assert status.success?, "matrix failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    assert capture_marker.file?
    summary = JSON.parse(@artifact_root.join("apple/unit-route-matrix.json").read)
    assert_equal true, summary.fetch("ok")
    assert_equal false, summary.fetch("fullyValidated")
    assert_operator summary.fetch("expectedRouteCount"), :>, summary.fetch("routeCount")
    assert_equal true, summary.fetch("provenanceVerifiedBefore")
    assert_equal true, summary.fetch("provenanceVerifiedAfter")
    assert_equal manifest_path.realpath.to_s, summary.fetch("provenanceManifestPath")
    assert_equal manifest.fetch("manifestSha256"), summary.fetch("provenanceManifestSha256")
    assert_equal manifest.dig("source", "sha"), summary.fetch("sourceSha")
    assert_equal manifest.dig("source", "tree"), summary.fetch("sourceTree")
  end

  def test_matrix_marks_only_the_complete_canonical_route_set_fully_validated
    stdout, stderr, status = run_matrix(matrix_run_uuid: "matrix-run-full", selected_routes: nil)

    assert status.success?, "full matrix failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    summary = JSON.parse(@artifact_root.join("apple/unit-route-matrix.json").read)
    assert_equal true, summary.fetch("ok")
    assert_equal true, summary.fetch("fullyValidated")
    assert_equal summary.fetch("expectedRouteCount"), summary.fetch("routeCount")
    assert_operator summary.fetch("routeCount"), :>, 1
  end

  def test_matrix_fails_when_a_standard_screenshot_is_missing
    _stdout, _stderr, status = run_matrix(
      matrix_run_uuid: "matrix-run-missing-screenshot",
      skipped_screenshot: "ios-tablet.png"
    )

    refute status.success?
    summary = JSON.parse(@artifact_root.join("apple/unit-route-matrix.json").read)
    assert_equal false, summary.fetch("ok")
    assert_includes summary.fetch("missingScreenshotRoutes"), "kitchen"
  end

  private

  def write_fixture_repository
    @repository.join("Spoonjoy.xcodeproj").mkpath
    @repository.join("Spoonjoy.xcodeproj/project.pbxproj").write("// fixture\n")
    @repository.join("README.md").write("fixture\n")
    @repository.join("scripts").mkpath
    FileUtils.cp(MATRIX_SCRIPT, @repository.join("scripts/capture-native-screenshot-matrix.sh"))
    FileUtils.cp(SCRIPT, @repository.join("scripts/native-screenshot-provenance.rb")) if SCRIPT.file?
    write_executable(@repository.join("scripts/capture-native-screenshots.sh"), <<~'SH')
      #!/usr/bin/env bash
      set -euo pipefail
      artifact_root=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --artifact-root) artifact_root="$2"; shift 2 ;;
          --unit-slug|--route) shift 2 ;;
          *) exit 2 ;;
        esac
      done
      touch "${CAPTURE_MARKER:?}"
      mkdir -p "$artifact_root/screenshots" "$artifact_root/apple"
      printf '{"mobileScreenshot":true,"desktopScreenshot":true,"blockers":[]}\n' > "$artifact_root/design-review.json"
      for screenshot in ios-mobile.png ios-mobile-accessibility.png ios-tablet.png macos-desktop.png; do
        if [[ "${CAPTURE_SKIP_SCREENSHOT:-}" != "$screenshot" ]]; then
          printf 'png:%s\n' "$screenshot" > "$artifact_root/screenshots/$screenshot"
        fi
      done
    SH
    write_executable(@repository.join("scripts/run-xcodebuild-with-blocker.sh"), <<~'SH')
      #!/usr/bin/env bash
      set -euo pipefail
      output=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --output) output="$2"; shift 2 ;;
          --blocker|--timeout-seconds) shift 2 ;;
          --) shift; break ;;
          *) exit 2 ;;
        esac
      done
      "$@" > "$output" 2>&1
    SH
    git("init")
    git("config", "user.name", "Codex Test")
    git("config", "user.email", "codex@example.invalid")
    git("add", ".")
    git("commit", "-m", "fixture")
  end

  def write_fake_apple_tools
    write_executable(@bin.join("xcodebuild"), <<~'SH')
      #!/usr/bin/env bash
      set -euo pipefail
      if [[ "${1:-}" == "-version" ]]; then
        printf 'Xcode 26.5\nBuild version 17Z1\n'
        exit 0
      fi
      printf '%s|%s\n' "$PWD" "$*" >> "${FAKE_XCODEBUILD_LOG:?}"
      derived=""
      scheme=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -derivedDataPath) derived="$2"; shift 2 ;;
          -scheme) scheme="$2"; shift 2 ;;
          *) shift ;;
        esac
      done
      if [[ "$scheme" == "Spoonjoy iOS" ]]; then
        product="$derived/Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app"
        bundle_id="app.spoonjoy"
        info_dir="$product"
        executable_dir="$product"
      else
        product="$derived/Build/Products/BootstrapDebug/Spoonjoy.app"
        bundle_id="app.spoonjoy.mac"
        info_dir="$product/Contents"
        executable_dir="$product/Contents/MacOS"
      fi
      mkdir -p "$info_dir" "$executable_dir"
      printf 'binary:%s\n' "$scheme" > "$executable_dir/Spoonjoy"
      chmod +x "$executable_dir/Spoonjoy"
      cat > "$info_dir/Info.plist" <<PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>$bundle_id</string>
      <key>CFBundleExecutable</key><string>Spoonjoy</string>
      </dict></plist>
      PLIST
      if [[ "$scheme" == "Spoonjoy iOS" ]]; then
        runner="$derived/Build/Products/BootstrapDebug-iphonesimulator/SpoonjoyUITests-Runner.app"
        test_bundle="$runner/PlugIns/SpoonjoyUITests.xctest"
        mkdir -p "$test_bundle"
        printf 'runner\n' > "$runner/SpoonjoyUITests-Runner"
        chmod +x "$runner/SpoonjoyUITests-Runner"
        printf 'tests\n' > "$test_bundle/SpoonjoyUITests"
        cat > "$derived/Build/Products/Spoonjoy iOS_iphonesimulator26.5-arm64-x86_64.xctestrun" <<PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict><key>SpoonjoyUITests</key><dict>
      <key>TestBundlePath</key><string>__TESTROOT__/BootstrapDebug-iphonesimulator/SpoonjoyUITests-Runner.app/PlugIns/SpoonjoyUITests.xctest</string>
      <key>TestHostPath</key><string>__TESTROOT__/BootstrapDebug-iphonesimulator/SpoonjoyUITests-Runner.app/SpoonjoyUITests-Runner</string>
      <key>UITargetAppPath</key><string>__TESTROOT__/BootstrapDebug-iphonesimulator/Spoonjoy.app</string>
      <key>DependentProductPaths</key><array><string>__TESTROOT__/BootstrapDebug-iphonesimulator/Spoonjoy.app</string></array>
      </dict></dict></plist>
      PLIST
      fi
    SH
    write_executable(@bin.join("xcrun"), <<~'SH')
      #!/usr/bin/env bash
      set -euo pipefail
      case "$*" in
        "--sdk iphonesimulator --show-sdk-version") printf '26.5\n' ;;
        "--sdk macosx --show-sdk-version") printf '27.0\n' ;;
        *) exit 2 ;;
      esac
    SH
  end

  def write_executable(path, content)
    path.write(content)
    path.chmod(0o755)
  end

  def git(*arguments)
    stdout, stderr, status = Open3.capture3("git", "-C", @repository.to_s, *arguments)
    raise "git #{arguments.join(" ")} failed: #{stderr}" unless status.success?

    stdout
  end

  def build_arguments
    [
      "--repo-root", @repository.to_s,
      "--artifact-root", @artifact_root.to_s,
      "--unit-slug", "unit",
      "--matrix-run-uuid", "matrix-run-a",
      "--build-uuid", "build-uuid",
      "--timeout-seconds", "20"
    ]
  end

  def build_manifest
    stdout, stderr, status = run_tool("build", *build_arguments)
    assert status.success?, "build failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    manifest_path = Pathname.new(stdout.lines.last.to_s.strip)
    assert manifest_path.file?, "manifest missing at #{manifest_path}"
    manifest_path
  end

  def verify_manifest(manifest_path, matrix_run_uuid: "matrix-run-a", ios_app: nil)
    manifest = JSON.parse(manifest_path.read) if manifest_path.file? && manifest_path.basename.to_s != "missing.json"
    ios_app ||= manifest&.dig("builds", "ios", "appPath")
    macos_app = manifest&.dig("builds", "macos", "appPath")
    arguments = [
      "--manifest", manifest_path.to_s,
      "--repo-root", @repository.to_s,
      "--artifact-root", @artifact_root.to_s,
      "--unit-slug", "unit",
      "--matrix-run-uuid", matrix_run_uuid
    ]
    arguments += ["--ios-app", ios_app.to_s] if ios_app
    arguments += ["--macos-app", macos_app.to_s] if macos_app
    run_tool("verify", *arguments)
  end

  def run_tool(*arguments)
    Open3.capture3(
      {
        "PATH" => "#{@bin}:#{ENV.fetch("PATH")}",
        "FAKE_XCODEBUILD_LOG" => @build_log.to_s
      },
      "ruby",
      SCRIPT.to_s,
      *arguments
    )
  end

  def run_matrix(matrix_run_uuid: "matrix-run-a", manifest: nil, ios_app: nil, macos_app: nil, selected_routes: "kitchen", skipped_screenshot: nil)
    environment = {
      "PATH" => "#{@bin}:#{ENV.fetch("PATH")}",
      "FAKE_XCODEBUILD_LOG" => @build_log.to_s,
      "SPOONJOY_SCREENSHOT_IPHONE_SIMULATOR_UDID" => "IPHONE-UDID",
      "SPOONJOY_SCREENSHOT_IPAD_SIMULATOR_UDID" => "IPAD-UDID",
      "SPOONJOY_SCREENSHOT_PROVENANCE_RUN_UUID" => matrix_run_uuid,
      "CAPTURE_MARKER" => capture_marker.to_s
    }
    environment["SPOONJOY_SCREENSHOT_MATRIX_ROUTES"] = selected_routes unless selected_routes.nil?
    environment["CAPTURE_SKIP_SCREENSHOT"] = skipped_screenshot if skipped_screenshot
    environment["SPOONJOY_SCREENSHOT_PROVENANCE_MANIFEST"] = manifest.to_s if manifest
    environment["SPOONJOY_SCREENSHOT_IOS_APP_PATH"] = ios_app.to_s if ios_app
    environment["SPOONJOY_SCREENSHOT_MACOS_APP_PATH"] = macos_app.to_s if macos_app
    Open3.capture3(
      environment,
      "bash",
      "scripts/capture-native-screenshot-matrix.sh",
      "--artifact-root",
      @artifact_root.to_s,
      "--unit-slug",
      "unit",
      chdir: @repository.to_s
    )
  end

  def write_unattested_prebuilt_apps
    ios_app = @root.join("unattested/ios/Spoonjoy.app")
    macos_app = @root.join("unattested/macos/Spoonjoy.app")
    ios_app.mkpath
    macos_app.mkpath
    [ios_app, macos_app]
  end

  def capture_marker
    @root.join("capture-ran")
  end
end
