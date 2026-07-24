# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class ObservedScreenshotContractBypassTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  CHECKER = ROOT.join("scripts/check-observed-screenshot-evidence-contract.rb")

  def test_python_comment_cannot_replace_waypoint_attestation
    with_contract_copy do |copy|
      observer = copy.join("scripts/run-ios-screenshot-observer.py")
      content = observer.read
      required = 'attest_audit_types(deep_scroll, "deepScroll")'
      observer.write(content.sub(required, "# #{required}"))

      output, status = Open3.capture2e(
        { "SPOONJOY_CONTRACT_ROOT" => copy.to_s },
        "ruby",
        CHECKER.to_s
      )

      refute status.success?, output
      assert_includes output, "attest_audit_types"
    end
  end

  def test_disabled_swift_region_cannot_replace_capture_behavior
    with_contract_copy do |copy|
      observer = copy.join("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift")
      content = observer.read
      required = "let initialScreenshot = initialCapture.screenshot"
      observer.write(content.sub(required, "#if false\n#{required}\n#endif"))

      output, status = Open3.capture2e(
        { "SPOONJOY_CONTRACT_ROOT" => copy.to_s },
        "ruby",
        CHECKER.to_s
      )

      refute status.success?, output
      assert_includes output, "initialScreenshot"
    end
  end

  def test_python_string_cannot_replace_waypoint_attestation_call
    with_contract_copy do |copy|
      observer = copy.join("scripts/run-ios-screenshot-observer.py")
      content = observer.read
      required = "attest_audit_types(waypoint, phase)"
      observer.write(content.sub(required, %('#{required}')))

      output, status = Open3.capture2e(
        { "SPOONJOY_CONTRACT_ROOT" => copy.to_s },
        "ruby",
        CHECKER.to_s
      )

      refute status.success?, output
      assert_includes output, "publish_waypoint_screenshots"
    end
  end

  private

  def with_contract_copy
    Dir.mktmpdir("spoonjoy-observed-contract-") do |directory|
      copy = Pathname.new(directory)
      %w[Apps scripts Spoonjoy.xcodeproj].each do |entry|
        FileUtils.cp_r(ROOT.join(entry), copy.join(entry))
      end
      yield copy
    end
  end
end
