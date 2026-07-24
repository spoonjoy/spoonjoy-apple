# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"
require_relative "../lib/screenshot_contrast_evidence"

class ValidateDesignReviewBypassTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  VALIDATOR = ROOT.join("scripts/validate-design-review.rb")
  MACOS_OBSERVER = ROOT.join("scripts/observe-macos-screenshot-evidence.swift")
  REQUIRED_AUDIT_TYPES = %w[contrast dynamicType textClipped hitRegion trait].freeze

  validator_library = VALIDATOR.read.split(/^path = Pathname\.new\(ARGV\.fetch/, 2).first
  class_eval(validator_library, VALIDATOR.to_s, 1)

  def test_rejects_a_missing_intermediate_scroll_waypoint
    assert_validation_failure do
      validate_ios_deep_scroll_waypoint_sequence!("proof.json", { "swipeCount" => 1, "waypoints" => [] })
    end
  end

  def test_rejects_a_failed_intermediate_scroll_viewport
    waypoint = valid_waypoint
    waypoint["findings"] = [{ "kind" => "peerOverlap" }]

    assert_validation_failure do
      validate_ios_deep_scroll_waypoint_sequence!("proof.json", { "swipeCount" => 1, "waypoints" => [waypoint] })
    end
  end

  def test_rejects_an_intermediate_waypoint_without_overlap_coverage
    waypoint = valid_waypoint
    waypoint["coverage"] = nil

    assert_validation_failure do
      validate_ios_deep_scroll_waypoint_sequence!("proof.json", { "swipeCount" => 1, "waypoints" => [waypoint] })
    end
  end

  def test_control_titles_are_text_but_untitled_affordances_remain_controls
    window = rect(0, 0, 400, 300)
    titled_button = mac_element("AXButton", "Save", rect(20, 20, 100, 44))
    untitled_button = mac_element("AXButton", "", rect(140, 20, 44, 44))

    assert_equal "text", macos_contrast_candidate_kind(titled_button, window)
    assert_equal "control", macos_contrast_candidate_kind(untitled_button, window)
  end

  def test_control_title_cannot_claim_the_three_to_one_affordance_threshold
    window = rect(0, 0, 400, 300)
    titled_button = mac_element("AXButton", "Save", rect(20, 20, 100, 44))
    digest = "a" * 64
    evidence = {
      "screenshotContrastEvidence" => {
        "schema" => "macosScreenshotContrastEvidenceV1",
        "capturePhase" => "initial",
        "screenshotSHA256" => digest,
        "windowFrame" => window,
        "entries" => [{
          "elementIndex" => 0,
          "kind" => "text",
          "element" => titled_button.slice("identifier", "role", "subrole", "title", "frame"),
          "pixelEvidence" => { "requiredContrastRatio" => 3.0, "contrastRatio" => 3.5 }
        }]
      }
    }

    assert_validation_failure do
      validate_macos_screenshot_contrast_evidence!(
        "proof.json",
        evidence,
        [titled_button],
        "initial",
        digest,
        window
      )
    end
  end

  def test_identifierless_independent_action_targets_cannot_overlap
    viewport = rect(0, 0, 320, 640)
    elements = [
      ios_button("First", rect(20, 20, 80, 44)),
      ios_button("Second", rect(80, 20, 80, 44))
    ]

    findings = host_geometry_findings!(
      "proof.json",
      elements,
      viewport,
      "ios",
      "kitchen",
      {},
      include_route_requirements: false
    )

    assert findings.any? { |finding| finding.include?("action peers") }, findings.inspect
  end

  def test_notification_sections_are_exactly_the_independently_observed_section
    validate_exact_settings_sections!("proof.json", ["This Device"], "notifications")

    assert_validation_failure do
      validate_exact_settings_sections!(
        "proof.json",
        ["This Device", "Push Delivery", "Notification Sync", "Agent Access"],
        "notifications"
      )
    end
  end

  def test_notification_heading_validation_rejects_fabricated_sections
    validate_observed_settings_notification_headings!(
      "proof.json",
      [{ "identifier" => "settings.apns.this-device.heading" }]
    )

    assert_validation_failure do
      validate_observed_settings_notification_headings!(
        "proof.json",
        [
          { "identifier" => "settings.apns.this-device.heading" },
          { "identifier" => "settings.apns.push-delivery.heading" }
        ]
      )
    end
  end

  def test_macos_observer_self_test_covers_control_title_classification
    output, status = Open3.capture2e("swift", MACOS_OBSERVER.to_s, "--self-test-screenshot-contrast")

    assert status.success?, output
    assert_includes output, "control-title classification ok"
  end

  def test_ios_contrast_failure_diagnostic_is_bound_to_screenshot_pixels
    screenshot_sha256 = "c" * 64
    issue = {
      "category" => "contrast",
      "elementType" => "staticText"
    }
    entry = {
      "schema" => "iosContrastPixelAdjudicationFailureV1",
      "capturePhase" => "initial",
      "issue" => issue,
      "matchingAttestedElementCount" => 0,
      "attestedFrame" => nil,
      "screenshotBufferAvailable" => true,
      "screenshotSHA256" => screenshot_sha256,
      "screenshotPixelWidth" => 1_206,
      "screenshotPixelHeight" => 2_622,
      "attempts" => [{
        "source" => "audit",
        "frame" => rect(20, 71, 318, 72),
        "outcome" => "analyzerRejected",
        "cropWidth" => 954,
        "cropHeight" => 216
      }]
    }

    validate_contrast_pixel_adjudication_diagnostics!(
      "proof.json",
      [entry],
      [issue],
      "initial",
      screenshot_sha256
    )

    entry["screenshotSHA256"] = "d" * 64
    assert_validation_failure do
      validate_contrast_pixel_adjudication_diagnostics!(
        "proof.json",
        [entry],
        [issue],
        "initial",
        screenshot_sha256
      )
    end
  end

  def test_contrast_verifier_requires_private_immutable_executable_bytes
    binary = ScreenshotContrastEvidence.verifier_binary
    assert_equal 0o700, File.stat(binary.dirname).mode & 0o777
    assert_equal Process.uid, File.stat(binary).uid
    assert_equal 0o700, File.stat(binary).mode & 0o777

    Dir.mktmpdir("spoonjoy-private-verifier-test-") do |directory|
      FileUtils.chmod(0o700, directory)
      copy = Pathname.new(directory).join("verifier")
      FileUtils.cp(binary, copy)
      FileUtils.chmod(0o700, copy)
      expected_digest = Digest::SHA256.file(copy).hexdigest
      ScreenshotContrastEvidence.verify_private_binary!(copy, expected_digest: expected_digest)
      copy.binwrite("tampered")
      assert_raises(RuntimeError) do
        ScreenshotContrastEvidence.verify_private_binary!(copy, expected_digest: expected_digest)
      end
    end
  end

  private

  def assert_validation_failure
    _stdout, _stderr = capture_io do
      error = assert_raises(SystemExit) { yield }
      assert_equal 1, error.status
    end
  end

  def valid_waypoint
    {
      "index" => 1,
      "capturePhase" => "deepScrollWaypoint-1",
      "coverage" => {
        "requestedContentOffset" => -200.0,
        "observedContentDisplacement" => 200.0,
        "viewportOverlap" => 400.0
      },
      "contentViewport" => rect(0, 0, 320, 600),
      "findings" => [],
      "auditIssues" => [],
      "auditScope" => "settledScrollWaypoint",
      "auditTypes" => REQUIRED_AUDIT_TYPES
    }
  end

  def rect(x, y, width, height)
    { "x" => x, "y" => y, "width" => width, "height" => height }
  end

  def ios_button(label, frame)
    {
      "identifier" => "",
      "label" => label,
      "type" => "button",
      "frame" => frame,
      "exists" => true,
      "hittable" => true,
      "enabled" => true,
      "hitRegionAuditVerified" => true
    }
  end

  def mac_element(role, title, frame)
    {
      "identifier" => "",
      "role" => role,
      "subrole" => "",
      "title" => title,
      "frame" => frame,
      "enabled" => true,
      "focused" => false,
      "actions" => ["AXPress"]
    }
  end
end
