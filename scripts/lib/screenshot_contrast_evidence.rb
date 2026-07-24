# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

module ScreenshotContrastEvidence
  ROOT = Pathname.new(__dir__).join("../..").expand_path.freeze
  SOURCES = [
    ROOT.join("Apps/SpoonjoyUITests/ScreenshotEvidenceGeometry.swift"),
    ROOT.join("Apps/SpoonjoyUITests/ScreenshotPixelContrastAdjudicator.swift"),
    ROOT.join("scripts/screenshot-contrast-evidence-verifier/main.swift")
  ].freeze

  module_function

  def analyze(screenshot_path:, point_size:, frame:, required_contrast_ratio:)
    screenshot_path = Pathname.new(screenshot_path).expand_path
    request = {
      "screenshotPath" => screenshot_path.to_s,
      "pointSize" => point_size,
      "frame" => frame,
      "requiredContrastRatio" => required_contrast_ratio
    }
    cache_key = [Digest::SHA256.file(screenshot_path).hexdigest, point_size, frame, required_contrast_ratio]
    cached = (@analysis_cache ||= {})[cache_key]
    return Marshal.load(Marshal.dump(cached)) if cached

    binary = verifier_binary
    verify_private_binary!(binary, expected_digest: @verifier_binary_digest)
    stdout, stderr, status = Open3.capture3(binary.to_s, stdin_data: JSON.generate(request))
    raise "screenshot contrast verifier failed: #{stderr.strip}" unless status.success?

    result = JSON.parse(stdout)
    (@analysis_cache ||= {})[cache_key] = result
    Marshal.load(Marshal.dump(result))
  end

  def verifier_binary
    if @verifier_binary
      verify_private_binary!(@verifier_binary, expected_digest: @verifier_binary_digest)
      return @verifier_binary
    end

    swift_version_stdout, swift_version_stderr, swift_version_status = Open3.capture3(
      "/usr/bin/xcrun", "swiftc", "--version"
    )
    raise "screenshot contrast verifier could not query swiftc" unless swift_version_status.success?

    swift_version = swift_version_stdout + swift_version_stderr
    source_digest = Digest::SHA256.hexdigest(
      SOURCES.map { |path| Digest::SHA256.file(path).hexdigest }.join +
        swift_version +
        ENV.fetch("DEVELOPER_DIR", "")
    )
    cache_root = Pathname.new(Dir.mktmpdir("spoonjoy-contrast-verifier-"))
    FileUtils.chmod(0o700, cache_root)
    binary = cache_root.join("verifier-#{source_digest}")
    temporary = cache_root.join("compile-#{Process.pid}.tmp")
    begin
      stdout, stderr, status = Open3.capture3(
        "/usr/bin/xcrun", "swiftc", "-O", *SOURCES.map(&:to_s), "-o", temporary.to_s
      )
      unless status.success?
        FileUtils.rm_f(temporary)
        raise "screenshot contrast verifier compilation failed: #{[stdout, stderr].join.strip}"
      end
      FileUtils.chmod(0o700, temporary)
      File.rename(temporary, binary)
      binary_digest = Digest::SHA256.file(binary).hexdigest
      verify_private_binary!(binary, expected_digest: binary_digest)
      @verifier_binary = binary
      @verifier_binary_digest = binary_digest
      at_exit do
        FileUtils.rm_rf(cache_root) if cache_root.to_s.include?("spoonjoy-contrast-verifier-")
      end
    ensure
      FileUtils.rm_f(temporary)
      FileUtils.rm_rf(cache_root) unless @verifier_binary == binary
    end
    @verifier_binary
  end

  def verify_private_binary!(binary, expected_digest:)
    binary = Pathname.new(binary)
    parent = binary.dirname
    parent_stat = File.lstat(parent)
    binary_stat = File.lstat(binary)
    raise "screenshot contrast verifier parent is not a private directory" unless
      parent_stat.directory? && !parent.symlink? && parent_stat.uid == Process.uid && (parent_stat.mode & 0o777) == 0o700
    raise "screenshot contrast verifier is not a private regular executable" unless
      binary_stat.file? && !binary.symlink? && binary_stat.uid == Process.uid && (binary_stat.mode & 0o777) == 0o700
    raise "screenshot contrast verifier executable digest changed" unless
      expected_digest.is_a?(String) && Digest::SHA256.file(binary).hexdigest == expected_digest

    binary
  end
end
