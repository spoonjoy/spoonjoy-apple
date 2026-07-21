#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "English"
require "fileutils"
require "find"
require "json"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "time"

module NativeScreenshotProvenance
  class Error < StandardError; end

  SHA_PATTERN = /\A[0-9a-f]{40}\z/
  UUID_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/
  MANIFEST_VERSION = 2

  module_function

  def execute(arguments)
    command = arguments.shift
    options = parse_options(arguments)
    case command
    when "build"
      puts build(options)
    when "verify"
      verify(options)
      puts "native screenshot provenance verified: #{canonical_existing_path(options.fetch(:manifest))}"
    else
      raise Error, "usage: native-screenshot-provenance.rb build|verify [options]"
    end
  rescue KeyError => error
    raise Error, "missing required option #{error.key.inspect}"
  end

  def parse_options(arguments)
    options = { timeout_seconds: 900 }
    OptionParser.new do |parser|
      parser.on("--repo-root PATH") { |value| options[:repo_root] = value }
      parser.on("--artifact-root PATH") { |value| options[:artifact_root] = value }
      parser.on("--unit-slug SLUG") { |value| options[:unit_slug] = value }
      parser.on("--matrix-run-uuid UUID") { |value| options[:matrix_run_uuid] = value }
      parser.on("--build-uuid UUID") { |value| options[:build_uuid] = value }
      parser.on("--timeout-seconds SECONDS", Integer) { |value| options[:timeout_seconds] = value }
      parser.on("--manifest PATH") { |value| options[:manifest] = value }
      parser.on("--ios-app PATH") { |value| options[:ios_app] = value }
      parser.on("--macos-app PATH") { |value| options[:macos_app] = value }
    end.parse!(arguments)
    raise Error, "unexpected arguments: #{arguments.join(" ")}" unless arguments.empty?

    options
  end

  def build(options)
    repo_root = canonical_existing_path(options.fetch(:repo_root))
    artifact_root = canonical_creatable_path(options.fetch(:artifact_root))
    unit_slug = validated_identifier(options.fetch(:unit_slug), "unit slug")
    matrix_run_uuid = validated_identifier(options.fetch(:matrix_run_uuid), "matrix run UUID")
    build_uuid = validated_identifier(options.fetch(:build_uuid, SecureRandom.uuid), "build UUID")
    timeout_seconds = Integer(options.fetch(:timeout_seconds))
    raise Error, "timeout must be positive" unless timeout_seconds.positive?

    assert_git_repository!(repo_root)
    assert_clean_source!(repo_root)
    source_sha = git_value(repo_root, "rev-parse", "HEAD")
    source_tree = git_value(repo_root, "rev-parse", "HEAD^{tree}")
    assert_sha!(source_sha, "source HEAD")
    assert_sha!(source_tree, "source tree")

    build_root = artifact_root.join("shared-builds", source_sha, build_uuid)
    raise Error, "exclusive build root already exists: #{build_root}" if build_root.exist?

    snapshot = build_root.join("source")
    snapshot.mkpath
    export_commit(repo_root, source_sha, build_root, snapshot)
    snapshot = snapshot.realpath
    build_root = build_root.realpath
    snapshot_hash = deterministic_tree_hash(snapshot)
    seal_tree!(snapshot)

    apple_dir = artifact_root.join("apple")
    apple_dir.mkpath
    manifest_path = apple_dir.join("#{unit_slug}-screenshot-provenance.json")
    raise Error, "provenance manifest already exists: #{manifest_path}" if manifest_path.exist?

    tools = {
      "xcodeVersion" => capture_command!(%w[xcodebuild -version]).strip,
      "sdkVersions" => {
        "iphonesimulator" => capture_command!(%w[xcrun --sdk iphonesimulator --show-sdk-version]).strip,
        "macosx" => capture_command!(%w[xcrun --sdk macosx --show-sdk-version]).strip
      }
    }
    builds = {
      "ios" => build_platform(
        platform: "ios",
        snapshot: snapshot,
        build_root: build_root,
        derived_data_name: "DerivedData-iOS",
        product_relative_path: "Build/Products/BootstrapDebug-iphonesimulator/Spoonjoy.app",
        scheme: "Spoonjoy iOS",
        destination: "generic/platform=iOS Simulator",
        log_path: apple_dir.join("#{unit_slug}-shared-ios-xcodebuild.log"),
        timeout_seconds: timeout_seconds,
        action: "build-for-testing",
        ui_test_runner_relative_path: "Build/Products/BootstrapDebug-iphonesimulator/SpoonjoyUITests-Runner.app"
      ),
      "macos" => build_platform(
        platform: "macos",
        snapshot: snapshot,
        build_root: build_root,
        derived_data_name: "DerivedData-macOS",
        product_relative_path: "Build/Products/BootstrapDebug/Spoonjoy.app",
        scheme: "Spoonjoy macOS",
        destination: "generic/platform=macOS",
        log_path: apple_dir.join("#{unit_slug}-shared-macos-xcodebuild.log"),
        timeout_seconds: timeout_seconds,
        action: "build"
      )
    }

    manifest = {
      "manifestVersion" => MANIFEST_VERSION,
      "createdAt" => Time.now.utc.iso8601,
      "source" => {
        "sha" => source_sha,
        "tree" => source_tree,
        "repositoryRoot" => repo_root.to_s,
        "clean" => true
      },
      "run" => {
        "unitSlug" => unit_slug,
        "matrixRunUUID" => matrix_run_uuid,
        "buildUUID" => build_uuid,
        "artifactRoot" => artifact_root.to_s,
        "buildRoot" => build_root.to_s,
        "sourceSnapshot" => snapshot.to_s,
        "sourceSnapshotTreeSha256" => snapshot_hash
      },
      "tools" => tools,
      "builds" => builds
    }
    manifest["manifestSha256"] = manifest_hash(manifest)
    manifest_path.write(JSON.pretty_generate(manifest) + "\n")
    manifest_path.chmod(0o444)
    manifest_path.realpath.to_s
  end

  def verify(options)
    repo_root = canonical_existing_path(options.fetch(:repo_root))
    artifact_root = canonical_existing_path(options.fetch(:artifact_root))
    unit_slug = validated_identifier(options.fetch(:unit_slug), "unit slug")
    matrix_run_uuid = validated_identifier(options.fetch(:matrix_run_uuid), "matrix run UUID")
    manifest_path = Pathname.new(options.fetch(:manifest)).expand_path
    raise Error, "provenance manifest is missing: #{manifest_path}" unless manifest_path.file?

    expected_manifest_path = artifact_root.join("apple", "#{unit_slug}-screenshot-provenance.json")
    manifest_path = manifest_path.realpath
    unless manifest_path == expected_manifest_path.expand_path
      raise Error, "provenance manifest canonical path mismatch: expected #{expected_manifest_path}, got #{manifest_path}"
    end

    manifest = parse_manifest(manifest_path)
    assert_manifest_shape!(manifest)
    expected_hash = manifest_hash(manifest)
    unless secure_equal?(manifest.fetch("manifestSha256"), expected_hash)
      raise Error, "manifest hash mismatch"
    end

    source = manifest.fetch("source")
    run = manifest.fetch("run")
    raise Error, "source repository canonical path mismatch" unless source.fetch("repositoryRoot") == repo_root.to_s
    raise Error, "artifact root canonical path mismatch" unless run.fetch("artifactRoot") == artifact_root.to_s
    raise Error, "unit slug mismatch" unless run.fetch("unitSlug") == unit_slug
    raise Error, "matrix run UUID mismatch" unless run.fetch("matrixRunUUID") == matrix_run_uuid
    raise Error, "manifest does not attest a clean source" unless source.fetch("clean") == true
    assert_sha!(source.fetch("sha"), "manifest source SHA")
    assert_sha!(source.fetch("tree"), "manifest source tree")

    assert_git_repository!(repo_root)
    assert_clean_source!(repo_root)
    current_sha = git_value(repo_root, "rev-parse", "HEAD")
    current_tree = git_value(repo_root, "rev-parse", "HEAD^{tree}")
    raise Error, "source HEAD changed: expected #{source.fetch("sha")}, got #{current_sha}" unless current_sha == source.fetch("sha")
    raise Error, "source tree changed: expected #{source.fetch("tree")}, got #{current_tree}" unless current_tree == source.fetch("tree")

    build_uuid = validated_identifier(run.fetch("buildUUID"), "manifest build UUID")
    expected_build_root = artifact_root.join("shared-builds", source.fetch("sha"), build_uuid)
    build_root = canonical_existing_path(run.fetch("buildRoot"))
    raise Error, "build root canonical path mismatch" unless build_root == expected_build_root
    snapshot = canonical_existing_path(run.fetch("sourceSnapshot"))
    raise Error, "source snapshot canonical path mismatch" unless snapshot == build_root.join("source")
    unless secure_equal?(deterministic_tree_hash(snapshot), run.fetch("sourceSnapshotTreeSha256"))
      raise Error, "source snapshot hash mismatch"
    end
    writable_snapshot_entry = tree_entries(snapshot).find do |path|
      !path.symlink? && (path.lstat.mode & 0o222).positive?
    end
    raise Error, "source snapshot is not sealed read-only: #{writable_snapshot_entry}" if writable_snapshot_entry

    verify_platform!(
      "ios",
      "iOS",
      manifest.fetch("builds").fetch("ios"),
      build_root,
      options[:ios_app]
    )
    verify_platform!(
      "macos",
      "macOS",
      manifest.fetch("builds").fetch("macos"),
      build_root,
      options[:macos_app]
    )
    true
  end

  def build_platform(
    platform:,
    snapshot:,
    build_root:,
    derived_data_name:,
    product_relative_path:,
    scheme:,
    destination:,
    log_path:,
    timeout_seconds:,
    action:,
    ui_test_runner_relative_path: nil
  )
    derived_data = build_root.join(derived_data_name)
    arguments = [
      "-project", snapshot.join("Spoonjoy.xcodeproj").to_s,
      "-scheme", scheme,
      "-configuration", "BootstrapDebug",
      "-destination", destination,
      "-derivedDataPath", derived_data.to_s,
      "CODE_SIGNING_ALLOWED=NO",
      "GCC_TREAT_WARNINGS_AS_ERRORS=YES",
      action
    ]
    run_with_timeout!(
      ["xcodebuild", *arguments],
      chdir: snapshot,
      output_path: log_path,
      timeout_seconds: timeout_seconds
    )

    app_path = derived_data.join(product_relative_path)
    raise Error, "#{platform} app bundle is missing after build: #{app_path}" unless app_path.directory?

    app_path = app_path.realpath
    bundle_contents = platform == "macos" ? app_path.join("Contents") : app_path
    info_plist = bundle_contents.join("Info.plist")
    bundle_identifier = plist_value(info_plist, "CFBundleIdentifier")
    executable_name = plist_value(info_plist, "CFBundleExecutable")
    executable_path = platform == "macos" ? bundle_contents.join("MacOS", executable_name) : app_path.join(executable_name)
    raise Error, "#{platform} executable is missing: #{executable_path}" unless executable_path.file?

    seal_tree!(app_path)
    build = {
      "bundleIdentifier" => bundle_identifier,
      "appPath" => app_path.to_s,
      "executablePath" => executable_path.realpath.to_s,
      "executableSha256" => Digest::SHA256.file(executable_path).hexdigest,
      "bundleTreeSha256" => deterministic_tree_hash(app_path),
      "workingDirectory" => snapshot.to_s,
      "derivedDataPath" => derived_data.realpath.to_s,
      "xcodebuildArguments" => arguments,
      "buildLogPath" => log_path.expand_path.to_s,
      "sealedReadOnly" => true
    }
    if ui_test_runner_relative_path
      runner_path = derived_data.join(ui_test_runner_relative_path)
      raise Error, "#{platform} UI-test runner is missing after build: #{runner_path}" unless runner_path.directory?

      xctestrun_paths = derived_data.join("Build/Products").glob("*.xctestrun")
      unless xctestrun_paths.length == 1
        raise Error, "#{platform} build produced #{xctestrun_paths.length} xctestrun files; expected exactly one"
      end
      runner_path = runner_path.realpath
      xctestrun_path = xctestrun_paths.fetch(0).realpath
      seal_tree!(runner_path)
      xctestrun_path.chmod(xctestrun_path.lstat.mode & ~0o222)
      build.merge!(
        "uiTestRunnerPath" => runner_path.to_s,
        "uiTestRunnerTreeSha256" => deterministic_tree_hash(runner_path),
        "xctestrunPath" => xctestrun_path.to_s,
        "xctestrunSha256" => Digest::SHA256.file(xctestrun_path).hexdigest
      )
      capture_root = build_root.join("CaptureProducts-iOS")
      capture_root.mkpath
      capture_app_path = capture_root.join("Spoonjoy.app")
      capture_runner_path = capture_root.join("SpoonjoyUITests-Runner.app")
      capture_xctestrun_path = capture_root.join(xctestrun_path.basename)
      FileUtils.cp_r(app_path.to_s, capture_app_path.to_s, preserve: true)
      FileUtils.cp_r(runner_path.to_s, capture_runner_path.to_s, preserve: true)
      FileUtils.cp(xctestrun_path.to_s, capture_xctestrun_path.to_s, preserve: true)
      make_tree_owner_writable!(capture_app_path)
      make_tree_owner_writable!(capture_runner_path)
      capture_xctestrun_path.chmod(capture_xctestrun_path.lstat.mode | 0o200)
      build.merge!(
        "captureAppPath" => capture_app_path.realpath.to_s,
        "captureAppTreeSha256" => deterministic_tree_hash(capture_app_path),
        "captureUITestRunnerPath" => capture_runner_path.realpath.to_s,
        "captureUITestRunnerTreeSha256" => deterministic_tree_hash(capture_runner_path),
        "captureXctestrunPath" => capture_xctestrun_path.realpath.to_s,
        "captureXctestrunSha256" => Digest::SHA256.file(capture_xctestrun_path).hexdigest,
        "captureProductsOwnerWritable" => true
      )
    end
    build
  end

  def verify_platform!(key, label, build, build_root, override_path)
    required = %w[
      bundleIdentifier appPath executablePath executableSha256 bundleTreeSha256
      workingDirectory derivedDataPath xcodebuildArguments buildLogPath sealedReadOnly
    ]
    missing = required.reject { |field| build.key?(field) }
    raise Error, "#{label} manifest is missing required keys: #{missing.join(", ")}" unless missing.empty?

    app_path = canonical_existing_path(build.fetch("appPath"))
    unless path_within?(app_path, build_root)
      raise Error, "#{label} app canonical path escapes the exclusive build root"
    end
    expected_override_path = key == "ios" ? canonical_existing_path(build.fetch("captureAppPath")) : app_path
    if override_path && canonical_existing_path(override_path) != expected_override_path
      raise Error, "#{label} app override does not match the manifest canonical path"
    end
    executable_path = canonical_existing_path(build.fetch("executablePath"))
    unless path_within?(executable_path, app_path)
      raise Error, "#{label} executable canonical path escapes the app bundle"
    end
    executable_hash = Digest::SHA256.file(executable_path).hexdigest
    unless secure_equal?(executable_hash, build.fetch("executableSha256"))
      raise Error, "#{label} executable hash mismatch"
    end
    bundle_hash = deterministic_tree_hash(app_path)
    unless secure_equal?(bundle_hash, build.fetch("bundleTreeSha256"))
      raise Error, "#{label} bundle-tree hash mismatch"
    end
    raise Error, "#{label} manifest does not attest sealed products" unless build.fetch("sealedReadOnly") == true
    writable = tree_entries(app_path).find { |path| !path.symlink? && (path.lstat.mode & 0o222).positive? }
    raise Error, "#{label} product is not sealed read-only: #{writable}" if writable
    expected_bundle_identifier = key == "ios" ? "app.spoonjoy" : "app.spoonjoy.mac"
    unless build.fetch("bundleIdentifier") == expected_bundle_identifier
      raise Error, "#{label} bundle identifier mismatch"
    end
    verify_ios_observer_products!(build, build_root) if key == "ios"
  end

  def verify_ios_observer_products!(build, build_root)
    required = %w[
      uiTestRunnerPath uiTestRunnerTreeSha256 xctestrunPath xctestrunSha256
      captureAppPath captureAppTreeSha256 captureUITestRunnerPath captureUITestRunnerTreeSha256
      captureXctestrunPath captureXctestrunSha256 captureProductsOwnerWritable
    ]
    missing = required.reject { |field| build.key?(field) }
    raise Error, "iOS manifest is missing observer products: #{missing.join(", ")}" unless missing.empty?

    runner_path = canonical_existing_path(build.fetch("uiTestRunnerPath"))
    xctestrun_path = canonical_existing_path(build.fetch("xctestrunPath"))
    unless path_within?(runner_path, build_root) && path_within?(xctestrun_path, build_root)
      raise Error, "iOS observer product canonical path escapes the exclusive build root"
    end
    unless secure_equal?(deterministic_tree_hash(runner_path), build.fetch("uiTestRunnerTreeSha256"))
      raise Error, "iOS UI-test runner tree hash mismatch"
    end
    unless secure_equal?(Digest::SHA256.file(xctestrun_path).hexdigest, build.fetch("xctestrunSha256"))
      raise Error, "iOS xctestrun hash mismatch"
    end
    writable = tree_entries(runner_path).find { |path| !path.symlink? && (path.lstat.mode & 0o222).positive? }
    raise Error, "iOS UI-test runner is not sealed read-only: #{writable}" if writable
    if (xctestrun_path.lstat.mode & 0o222).positive?
      raise Error, "iOS xctestrun is not sealed read-only"
    end

    capture_app_path = canonical_existing_path(build.fetch("captureAppPath"))
    capture_runner_path = canonical_existing_path(build.fetch("captureUITestRunnerPath"))
    capture_xctestrun_path = canonical_existing_path(build.fetch("captureXctestrunPath"))
    [capture_app_path, capture_runner_path, capture_xctestrun_path].each do |path|
      raise Error, "iOS capture product canonical path escapes the exclusive build root" unless path_within?(path, build_root)
    end
    unless secure_equal?(deterministic_tree_hash(capture_app_path), build.fetch("captureAppTreeSha256"))
      raise Error, "iOS capture app tree hash mismatch"
    end
    unless secure_equal?(deterministic_tree_hash(capture_runner_path), build.fetch("captureUITestRunnerTreeSha256"))
      raise Error, "iOS capture UI-test runner tree hash mismatch"
    end
    unless secure_equal?(Digest::SHA256.file(capture_xctestrun_path).hexdigest, build.fetch("captureXctestrunSha256"))
      raise Error, "iOS capture xctestrun hash mismatch"
    end
    unless secure_equal?(build.fetch("captureAppTreeSha256"), build.fetch("bundleTreeSha256")) &&
        secure_equal?(build.fetch("captureUITestRunnerTreeSha256"), build.fetch("uiTestRunnerTreeSha256")) &&
        secure_equal?(build.fetch("captureXctestrunSha256"), build.fetch("xctestrunSha256"))
      raise Error, "iOS capture products do not match the sealed reference products"
    end
    raise Error, "iOS manifest does not attest owner-writable capture products" unless build.fetch("captureProductsOwnerWritable") == true
    [capture_app_path, capture_runner_path].each do |root|
      nonwritable = tree_entries(root).find { |path| !path.symlink? && (path.lstat.mode & 0o200).zero? }
      raise Error, "iOS capture product is not owner-writable: #{nonwritable}" if nonwritable
    end
    if (capture_xctestrun_path.lstat.mode & 0o200).zero?
      raise Error, "iOS capture xctestrun is not owner-writable"
    end
  end

  def export_commit(repo_root, source_sha, build_root, snapshot)
    archive_path = build_root.join("source.tar")
    run_command!("git", "-C", repo_root.to_s, "archive", "--format=tar", "--output", archive_path.to_s, source_sha)
    run_command!("tar", "-xf", archive_path.to_s, "-C", snapshot.to_s)
  ensure
    archive_path&.delete if archive_path&.file?
  end

  def assert_git_repository!(repo_root)
    value = git_value(repo_root, "rev-parse", "--is-inside-work-tree")
    raise Error, "not a Git worktree: #{repo_root}" unless value == "true"
  end

  def assert_clean_source!(repo_root)
    status = capture_command!(["git", "-C", repo_root.to_s, "status", "--porcelain=v1", "--untracked-files=all"])
    return if status.empty?

    raise Error, "source worktree is not clean:\n#{status}"
  end

  def git_value(repo_root, *arguments)
    capture_command!(["git", "-C", repo_root.to_s, *arguments]).strip
  end

  def assert_sha!(value, label)
    raise Error, "#{label} must be an exact 40-character SHA" unless value.match?(SHA_PATTERN)
  end

  def validated_identifier(value, label)
    string = value.to_s
    raise Error, "#{label} is invalid" unless string.match?(UUID_PATTERN)

    string
  end

  def parse_manifest(path)
    JSON.parse(path.read)
  rescue JSON::ParserError => error
    raise Error, "provenance manifest is invalid JSON: #{error.message}"
  end

  def assert_manifest_shape!(manifest)
    required = %w[manifestVersion createdAt source run tools builds manifestSha256]
    missing = required.reject { |field| manifest.key?(field) }
    raise Error, "manifest is missing required keys: #{missing.join(", ")}" unless missing.empty?
    raise Error, "unsupported provenance manifest version" unless manifest.fetch("manifestVersion") == MANIFEST_VERSION
    raise Error, "manifest source is invalid" unless manifest.fetch("source").is_a?(Hash)
    raise Error, "manifest run is invalid" unless manifest.fetch("run").is_a?(Hash)
    raise Error, "manifest builds are invalid" unless manifest.fetch("builds").is_a?(Hash)
  end

  def plist_value(path, key)
    raise Error, "app Info.plist is missing: #{path}" unless path.file?

    capture_command!(["plutil", "-extract", key, "raw", "-o", "-", path.to_s]).strip
  end

  def canonical_existing_path(value)
    Pathname.new(value.to_s).expand_path.realpath
  rescue Errno::ENOENT
    raise Error, "path is missing: #{Pathname.new(value.to_s).expand_path}"
  end

  def canonical_creatable_path(value)
    path = Pathname.new(value.to_s).expand_path
    path.mkpath
    path.realpath
  end

  def path_within?(path, parent)
    path == parent || path.to_s.start_with?("#{parent}/")
  end

  def tree_entries(root)
    paths = []
    Find.find(root.to_s) { |path| paths << Pathname.new(path) }
    paths.sort_by { |path| path.relative_path_from(root).to_s.b }
  end

  def deterministic_tree_hash(root)
    root = canonical_existing_path(root)
    digest = Digest::SHA256.new
    tree_entries(root).each do |path|
      relative = path.relative_path_from(root).to_s
      stat = path.lstat
      if path.symlink?
        digest << "L\0#{relative}\0#{path.readlink}\0"
      elsif stat.directory?
        digest << "D\0#{relative}\0"
      elsif stat.file?
        digest << "F\0#{relative}\0#{stat.size}\0#{Digest::SHA256.file(path).hexdigest}\0"
      else
        raise Error, "unsupported bundle entry type: #{path}"
      end
    end
    digest.hexdigest
  end

  def seal_tree!(root)
    tree_entries(root).reverse_each do |path|
      next if path.symlink?

      path.chmod(path.lstat.mode & ~0o222)
    end
  end

  def make_tree_owner_writable!(root)
    tree_entries(root).each do |path|
      next if path.symlink?

      path.chmod(path.lstat.mode | 0o200)
    end
  end

  def manifest_hash(manifest)
    payload = deep_sort(manifest.reject { |key, _value| key == "manifestSha256" })
    Digest::SHA256.hexdigest(JSON.generate(payload))
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, deep_sort(value.fetch(key))] }
    when Array
      value.map { |entry| deep_sort(entry) }
    else
      value
    end
  end

  def secure_equal?(left, right)
    return false unless left.is_a?(String) && right.is_a?(String) && left.bytesize == right.bytesize

    left.bytes.zip(right.bytes).reduce(0) { |difference, (a, b)| difference | (a ^ b) }.zero?
  end

  def capture_command!(command)
    stdout, stderr, status = Open3.capture3(*command)
    return stdout if status.success?

    raise Error, "command failed (#{command.join(" ")}): #{stderr.strip}"
  end

  def run_command!(*command)
    _stdout, stderr, status = Open3.capture3(*command)
    return if status.success?

    raise Error, "command failed (#{command.join(" ")}): #{stderr.strip}"
  end

  def run_with_timeout!(command, chdir:, output_path:, timeout_seconds:)
    output_path.dirname.mkpath
    File.open(output_path, "wb") do |output|
      pid = Process.spawn(*command, chdir: chdir.to_s, out: output, err: [:child, :out], pgroup: true)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
      loop do
        waited = Process.waitpid(pid, Process::WNOHANG)
        if waited
          status = $CHILD_STATUS
          raise Error, "build failed (see #{output_path})" unless status.success?
          break
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          begin
            Process.kill("TERM", -pid)
          rescue Errno::ESRCH
          end
          sleep 0.2
          begin
            Process.kill("KILL", -pid)
          rescue Errno::ESRCH
          end
          Process.waitpid(pid) rescue Errno::ECHILD
          raise Error, "build timed out after #{timeout_seconds} seconds (see #{output_path})"
        end
        sleep 0.05
      end
    end
  end
end

begin
  NativeScreenshotProvenance.execute(ARGV.dup)
rescue NativeScreenshotProvenance::Error => error
  warn "native screenshot provenance error: #{error.message}"
  exit 1
end
