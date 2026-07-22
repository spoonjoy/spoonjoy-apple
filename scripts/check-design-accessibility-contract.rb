#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
VALIDATOR = ROOT.join("scripts/validate-design-review.rb")
DEEP_SCROLL_SCREENSHOT_ARTIFACTS = {
  "iosMobile" => "screenshots/ios-mobile-deep-scroll.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility-deep-scroll.png",
  "iosTablet" => "screenshots/ios-tablet-deep-scroll.png"
}.freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def assert_status(expected, command, label)
  stdout, stderr, status = Open3.capture3(*command.map(&:to_s), chdir: ROOT.to_s)
  return if status.success? == expected

  fail_check("#{label} expected success=#{expected}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}")
end

CAPTURE_RUN_NONCES = {
  ["ios", "large"] => "7238f644-ff7a-4c1a-a9aa-60dd478c1c1d",
  ["ios", "accessibility5"] => "f62de99c-0067-4c71-9fc5-f7ba5cc27e6c",
  ["ipad", "large"] => "817a858d-c004-4036-9c1d-d816b97f5d99",
  ["macos", "large"] => "bf3d228e-0f1f-4450-b8dc-e48db62686b6"
}.freeze
READINESS_GENERATIONS = {
  ["ios", "large"] => 10,
  ["ios", "accessibility5"] => 20,
  ["ipad", "large"] => 30,
  ["macos", "large"] => 40
}.freeze

def readiness_generation(platform, dynamic_type:, capture_phase:)
  base = READINESS_GENERATIONS.fetch([platform, dynamic_type])
  capture_phase == "deepScroll" ? base + 1 : base
end

def readiness_proof(platform, dynamic_type: "large", capture_phase: "initial")
  generation = readiness_generation(platform, dynamic_type: dynamic_type, capture_phase: capture_phase)
  {
    "platform" => platform,
    "route" => "kitchen",
    "source" => "KitchenView",
    "captureRunNonce" => CAPTURE_RUN_NONCES.fetch([platform, dynamic_type]),
    "readinessGeneration" => generation,
    "launchEnvironmentProof" => {},
    "screenshotStateSnapshotProof" => {
      "stateDirectoryResolved" => true,
      "appSnapshotPresent" => true,
      "appSnapshotJSONReadable" => true,
      "syncSnapshotPresent" => true,
      "syncSnapshotJSONReadable" => true
    },
    "observedDynamicTypeSize" => dynamic_type,
    "observedReduceMotion" => false,
    "visualReadiness" => {
      "generation" => generation,
      "expectedMediaCount" => 1,
      "loadedMediaCount" => 1,
      "pendingMediaCount" => 0,
      "failedMediaCount" => 0,
      "blockingIndicatorCount" => 0,
      "isSettled" => true
    },
    "emittedBy" => "SpoonjoyApp",
    "bundleIdentifier" => platform == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy"
  }
end

def readiness_proof_bytes(platform, dynamic_type: "large", capture_phase: "initial")
  JSON.pretty_generate(readiness_proof(platform, dynamic_type: dynamic_type, capture_phase: capture_phase)) + "\n"
end

def readiness_handshake(platform, dynamic_type:, capture_phase:)
  generation = readiness_generation(platform, dynamic_type: dynamic_type, capture_phase: capture_phase)
  {
    "captureRunNonce" => CAPTURE_RUN_NONCES.fetch([platform, dynamic_type]),
    "route" => "kitchen",
    "source" => "KitchenView",
    "readinessGeneration" => generation,
    "proofFileName" => "native-accessibility-proof.generation-#{generation}.json",
    "proofSHA256" => Digest::SHA256.hexdigest(
      readiness_proof_bytes(platform, dynamic_type: dynamic_type, capture_phase: capture_phase)
    )
  }
end

def rect(x: 0, y: 0, width: 100, height: 100)
  { "x" => x, "y" => y, "width" => width, "height" => height }
end

def ios_element(identifier, type: "staticText", frame: rect(x: 10, y: 10, width: 44, height: 44))
  {
    "identifier" => identifier,
    "label" => identifier,
    "type" => type,
    "frame" => frame,
    "exists" => true,
    "hittable" => type == "button",
    "enabled" => true,
    "focused" => nil
  }
end

def fixture_screenshot_sha256(platform, dynamic_type:, capture_phase:)
  name = if platform == "ipad"
           "ios-tablet#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         elsif platform == "macos"
           "macos-desktop.png"
         elsif dynamic_type == "accessibility5"
           "ios-mobile-accessibility#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         else
           "ios-mobile#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         end
  Digest::SHA256.hexdigest("png:#{name}")
end

def observed_proof(platform, dynamic_type: "large")
  if platform == "macos"
    proof = {
      "platform" => platform,
      "route" => "kitchen",
      "captureRunNonce" => CAPTURE_RUN_NONCES.fetch([platform, dynamic_type]),
      "readinessProofSHA256" => Digest::SHA256.hexdigest(readiness_proof_bytes(platform, dynamic_type: dynamic_type)),
      "screenshotSHA256" => fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "initial"),
      "pid" => 123,
      "bundleIdentifier" => "app.spoonjoy.mac",
      "bundlePath" => "/Applications/Spoonjoy.app",
      "executablePath" => "/Applications/Spoonjoy.app/Contents/MacOS/Spoonjoy",
      "executableSHA256" => "e" * 64,
      "windowFrames" => [rect],
      "elements" => [{
        "identifier" => "kitchen.terminal",
        "role" => "AXStaticText",
        "title" => "Cookbook shelf",
        "frame" => rect(x: 10, y: 10, width: 44, height: 44),
        "enabled" => true,
        "focused" => false,
        "actions" => []
      }],
      "findings" => []
    }
  else
    terminal = ios_element("kitchen.terminal", frame: rect(x: 10, y: 40, width: 44, height: 40))
    proof = {
      "platform" => platform,
      "route" => "kitchen",
      "viewport" => rect(x: 0, y: 0, width: 100, height: 80),
      "elements" => [terminal, ios_element("system.tabBar", type: "tabBar", frame: rect(x: 0, y: 80, width: 100, height: 20))],
      "auditIssues" => [],
      "verifiedContrastFalsePositives" => [],
      "screenshotSHA256" => fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "initial"),
      "geometryFindings" => [],
      "observedContentSizeCategory" => "large",
      "observedDynamicTypeSize" => dynamic_type,
      "toolLimitations" => [],
      "deepScroll" => {
        "route" => "kitchen",
        "reachedTerminal" => true,
        "swipeCount" => 3,
        "contentViewport" => rect(x: 0, y: 0, width: 100, height: 80),
        "tabBarFrame" => rect(x: 0, y: 80, width: 100, height: 20),
        "terminalElement" => terminal,
        "findings" => [],
        "auditIssues" => [],
        "verifiedContrastFalsePositives" => [],
        "screenshotSHA256" => fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll"),
        "readinessHandshake" => readiness_handshake(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll"),
        "observedContentMovement" => true,
        "contentFitsWithoutScrolling" => false,
        "toolLimitations" => []
      }
    }
    proof["readinessHandshake"] = readiness_handshake(platform, dynamic_type: dynamic_type, capture_phase: "initial")
    proof
  end
end

def verified_contrast_false_positive(screenshot_sha256, capture_phase)
  {
    "capturePhase" => capture_phase,
    "issue" => {
      "category" => "contrast",
      "type" => "XCUIAccessibilityAuditType(rawValue: 1)",
      "compactDescription" => "Contrast failed",
      "detailedDescription" => "Contrast failed for SwiftUI.AccessibilityNode",
      "diagnosticDescription" => "fixture",
      "diagnosticMirror" => "",
      "elementIdentifier" => "",
      "elementLabel" => "Inbox",
      "elementType" => "staticText",
      "elementFrame" => rect(x: 10, y: 10, width: 44, height: 20)
    },
    "pixelEvidence" => {
      "method" => "screenshotPixelContrastV1",
      "screenshotSHA256" => screenshot_sha256,
      "contrastRatio" => 14.7,
      "requiredContrastRatio" => 4.5,
      "evaluatedForegroundClusterCount" => 1,
      "backgroundCoverage" => 0.73,
      "foregroundCoverage" => 0.2,
      "analyzedPixelCount" => 1_000,
      "backgroundPixelCount" => 730,
      "foregroundPixelCount" => 200,
      "background" => { "red" => 250, "green" => 249, "blue" => 243 },
      "foreground" => { "red" => 40, "green" => 35, "blue" => 29 }
    }
  }
end

def screenshot_artifact(root, relative_path)
  path = root.join(relative_path)
  {
    "path" => relative_path,
    "bytes" => path.size,
    "sha256" => Digest::SHA256.file(path).hexdigest
  }
end

def manifest(root)
  {
    "screenshotRoute" => "kitchen",
    "screenshotArtifacts" => {
      "iosMobile" => screenshot_artifact(root, "screenshots/ios-mobile.png"),
      "iosAccessibility" => screenshot_artifact(root, "screenshots/ios-mobile-accessibility.png"),
      "iosTablet" => screenshot_artifact(root, "screenshots/ios-tablet.png"),
      "macosDesktop" => screenshot_artifact(root, "screenshots/macos-desktop.png")
    },
    "deepScrollScreenshotArtifacts" => DEEP_SCROLL_SCREENSHOT_ARTIFACTS.to_h do |name, relative_path|
      [name, screenshot_artifact(root, relative_path)]
    end,
    "kitchenSignedInSurface" => true,
    "kitchenSeedAccountID" => "chef_kitchen_capture",
    "accessibilityProofArtifacts" => [
      "apple/readiness-ios.json",
      "apple/readiness-ios-ax.json",
      "apple/readiness-ipad.json",
      "apple/readiness-macos.json"
    ],
    "deepScrollAccessibilityProofArtifacts" => [
      "apple/readiness-ios-deep-scroll.json",
      "apple/readiness-ios-ax-deep-scroll.json",
      "apple/readiness-ipad-deep-scroll.json"
    ],
    "observedAccessibilityEvidenceArtifacts" => [
      "apple/observed-ios.json",
      "apple/observed-ios-ax.json",
      "apple/observed-ipad.json",
      "apple/observed-macos.json"
    ],
    "accessibilityContentSizeScreenshot" => "screenshots/ios-mobile-accessibility.png",
    "blockers" => []
  }
end

writer_source = ROOT.join("Apps/Spoonjoy/Shared/Components/ScreenshotAccessibilityProofWriter.swift").read
legacy_tokens = [
  "voiceOverLabels", "keyboardNavigation", "minimumTargetSize", "noOverlap", "textFits",
  "noTinyClusters", "routeEvidence", "RouteAccessibilityEvidence", "offlineIndicatorProof"
]
present_legacy_tokens = legacy_tokens.select { |token| writer_source.include?(token) }
fail_check("app readiness writer still self-attests #{present_legacy_tokens.join(", ")}") unless present_legacy_tokens.empty?

observer_source = ROOT.join("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift").read
[
  "performAccessibilityAudit", "geometryFindings", "deepScroll", "scrollPrimarySurfaceToTerminal",
  "testGeometryRejectsMissingRequiredIdentifier", "testGeometryRejectsClippedOrOffscreenRequiredElement",
  "testGeometryRejectsPeerOverlap", "testGeometryRejectsAPNsChromeIntersection",
  "testGeometryRejectsPartiallyVisibleSmallActionTarget",
  "testGeometryRejectsTerminalElementBehindTabBar"
].each do |token|
  fail_check("iOS observed evidence missing #{token}") unless observer_source.include?(token)
end

Dir.mktmpdir("spoonjoy-observed-accessibility") do |directory|
  root = Pathname.new(directory)
  root.join("apple").mkpath
  root.join("screenshots").mkpath
  %w[ios-mobile.png ios-mobile-accessibility.png ios-tablet.png macos-desktop.png].each do |name|
    root.join("screenshots", name).write("png:#{name}")
  end
  DEEP_SCROLL_SCREENSHOT_ARTIFACTS.each_value do |relative_path|
    root.join(relative_path).write("png:#{Pathname.new(relative_path).basename}")
  end
  [["ios", "large", "ios"], ["ios", "accessibility5", "ios-ax"], ["ipad", "large", "ipad"], ["macos", "large", "macos"]].each do |platform, dynamic_type, suffix|
    root.join("apple/readiness-#{suffix}.json").write(readiness_proof_bytes(platform, dynamic_type: dynamic_type))
    if platform != "macos"
      root.join("apple/readiness-#{suffix}-deep-scroll.json").write(
        readiness_proof_bytes(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll")
      )
    end
  end
  %w[ios ipad macos].each do |platform|
    root.join("apple/observed-#{platform}.json").write(JSON.pretty_generate(observed_proof(platform)) + "\n")
  end
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(
    observed_proof("ios", dynamic_type: "accessibility5").merge(
      "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
      "observedDynamicTypeSize" => "accessibility5"
    )
  ) + "\n")
  manifest_path = root.join("design-review.json")
  valid_manifest = manifest(root)
  manifest_path.write(JSON.pretty_generate(valid_manifest) + "\n")
  assert_status(true, ["ruby", VALIDATOR, manifest_path], "valid observed accessibility evidence")

  readiness_ios_path = root.join("apple/readiness-ios.json")
  missing_generation = readiness_proof("ios").tap { |proof| proof.delete("readinessGeneration") }
  readiness_ios_path.write(JSON.pretty_generate(missing_generation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "missing readiness generation rejection")
  readiness_ios_path.write(readiness_proof_bytes("ios"))

  mismatched_generation = readiness_proof("ios")
  mismatched_generation.fetch("visualReadiness")["generation"] += 1
  readiness_ios_path.write(JSON.pretty_generate(mismatched_generation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "mismatched visual readiness generation rejection")
  readiness_ios_path.write(readiness_proof_bytes("ios"))

  observed_ios_path = root.join("apple/observed-ios.json")
  substituted_handshake = observed_proof("ios")
  substituted_handshake["readinessHandshake"]["proofSHA256"] = "0" * 64
  observed_ios_path.write(JSON.pretty_generate(substituted_handshake) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "readiness handshake substitution")
  observed_ios_path.write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  ipad_path = root.join("apple/observed-ipad.json")
  ipad_fits = JSON.parse(ipad_path.read)
  ipad_fits["deepScroll"]["observedContentMovement"] = false
  ipad_fits["deepScroll"]["contentFitsWithoutScrolling"] = true
  ipad_fits["deepScroll"]["swipeCount"] = 1
  ipad_path.write(JSON.pretty_generate(ipad_fits) + "\n")
  assert_status(true, ["ruby", VALIDATOR, manifest_path], "iPad terminal content that already fits")
  ipad_path.write(JSON.pretty_generate(observed_proof("ipad")) + "\n")

  ipad_verified = observed_proof("ipad")
  ipad_verified["verifiedContrastFalsePositives"] = [
    verified_contrast_false_positive(
      valid_manifest.dig("screenshotArtifacts", "iosTablet", "sha256"),
      "initial"
    )
  ]
  ipad_path.write(JSON.pretty_generate(ipad_verified) + "\n")
  assert_status(true, ["ruby", VALIDATOR, manifest_path], "screenshot-bound contrast adjudication")
  ipad_verified["verifiedContrastFalsePositives"][0]["pixelEvidence"]["screenshotSHA256"] = "0" * 64
  ipad_path.write(JSON.pretty_generate(ipad_verified) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "contrast adjudication screenshot substitution")
  ipad_path.write(JSON.pretty_generate(observed_proof("ipad")) + "\n")

  root.join("screenshots/ios-mobile.png").write("tampered")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "tampered screenshot rejection")
  root.join("screenshots/ios-mobile.png").write("png:ios-mobile.png")

  stale = readiness_proof("ios").merge("routeEvidence" => { "voiceOverLabels" => ["invented"] })
  root.join("apple/readiness-ios.json").write(JSON.pretty_generate(stale) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "legacy self-attestation rejection")
  root.join("apple/readiness-ios.json").write(JSON.pretty_generate(readiness_proof("ios")) + "\n")

  failed_geometry = observed_proof("ios").merge(
    "geometryFindings" => [{ "kind" => "peerOverlap", "message" => "overlap" }]
  )
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(failed_geometry) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "observed peer overlap rejection")
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  failed_audit = observed_proof("ipad").merge(
    "auditIssues" => [{ "type" => "contrast", "compactDescription" => "low contrast" }]
  )
  root.join("apple/observed-ipad.json").write(JSON.pretty_generate(failed_audit) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "observed accessibility audit rejection")
  root.join("apple/observed-ipad.json").write(JSON.pretty_generate(observed_proof("ipad")) + "\n")

  known_ios_26_limitation = observed_proof("ios").merge(
    "operatingSystemVersion" => "26.5",
    "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
    "toolLimitations" => [{
      "issue" => {
        "category" => "dynamicType",
        "compactDescription" => "Dynamic Type font sizes are partially unsupported",
        "detailedDescription" => "User will not be able to change the font size of this SwiftUI.AccessibilityNode",
        "elementLabel" => "Start Cooking",
        "elementFrame" => rect
      },
      "reference" => "https://developer.apple.com/forums/thread/823968",
      "reason" => "Tracked iOS 26 audit limitation"
    }]
  )
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(known_ios_26_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "iOS 26 Dynamic Type finding remains blocking")

  unsupported_limitation = known_ios_26_limitation.merge(
    "toolLimitations" => [{
      "issue" => { "category" => "contrast" },
      "reference" => "https://developer.apple.com/videos/play/wwdc2023/10035/",
      "reason" => "Missing required null-element diagnostics"
    }]
  )
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(unsupported_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "unsupported audit limitation rejection")

  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(
    observed_proof("ios", dynamic_type: "accessibility5").merge(
      "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
      "observedDynamicTypeSize" => "accessibility5"
    )
  ) + "\n")

  mismatched_dynamic_type = observed_proof("ios").merge(
    "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
    "observedDynamicTypeSize" => "large"
  )
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(mismatched_dynamic_type) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "requested Dynamic Type mismatch rejection")
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(
    observed_proof("ios", dynamic_type: "accessibility5").merge(
      "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
      "observedDynamicTypeSize" => "accessibility5"
    )
  ) + "\n")

  measured_contrast_limitation = observed_proof("ios").merge(
    "operatingSystemVersion" => "26.5",
    "toolLimitations" => [{
      "issue" => {
        "category" => "contrast",
        "elementIdentifier" => "",
        "elementLabel" => "1 saved recipe",
        "elementType" => "staticText",
        "elementFrame" => { "x" => 10, "y" => 20, "width" => 100, "height" => 20 },
        "diagnosticDescription" => "Contrast failed for SwiftUI.AccessibilityNode"
      },
      "reference" => "https://developer.apple.com/videos/play/wwdc2023/10035/",
      "reason" => "Independent rendered-pixel contrast proof",
      "contrastProof" => {
        "backgroundHex" => "#FBFAF4",
        "foregroundHex" => "#28231D",
        "contrastRatio" => 14.89,
        "requiredRatio" => 4.5,
        "backgroundPixelCount" => 800,
        "foregroundPixelCount" => 180,
        "cropPixelCount" => 1_000
      }
    }]
  )
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(measured_contrast_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "measured iOS 26 contrast finding remains blocking")

  unproved_contrast_limitation = measured_contrast_limitation.merge(
    "toolLimitations" => [measured_contrast_limitation["toolLimitations"].first.merge("contrastProof" => nil)]
  )
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(unproved_contrast_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "unproved iOS 26 contrast limitation rejection")

  occluded_element = ios_element(
    "partially occluded row",
    type: "button",
    frame: rect(x: 10, y: 70, width: 44, height: 44)
  )
  tab_bar_occlusion_limitation = observed_proof("ios").merge(
    "operatingSystemVersion" => "26.5",
    "elements" => [
      occluded_element,
      ios_element("system.tabBar", type: "tabBar", frame: rect(x: 0, y: 80, width: 100, height: 20))
    ],
    "toolLimitations" => [{
      "issue" => {
        "category" => "contrast",
        "elementIdentifier" => "",
        "elementLabel" => "",
        "elementType" => "",
        "elementFrame" => nil,
        "diagnosticDescription" => "Contrast failed for SwiftUI.AccessibilityNode Element:(null)"
      },
      "reference" => "https://developer.apple.com/videos/play/wwdc2023/10035/",
      "reason" => "Independent tab-bar occlusion and clean post-scroll proof",
      "tabBarOcclusionProof" => {
        "tabBarFrame" => rect(x: 0, y: 80, width: 100, height: 20),
        "occludedElements" => [occluded_element],
        "postScrollAnonymousContrastIssueAbsent" => true
      }
    }]
  )
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(tab_bar_occlusion_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "anonymous tab-bar contrast finding remains blocking")

  unproved_tab_bar_limitation = tab_bar_occlusion_limitation.merge(
    "toolLimitations" => [tab_bar_occlusion_limitation["toolLimitations"].first.merge(
      "tabBarOcclusionProof" => tab_bar_occlusion_limitation.dig("toolLimitations", 0, "tabBarOcclusionProof").merge(
        "postScrollAnonymousContrastIssueAbsent" => false
      )
    )]
  )
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(unproved_tab_bar_limitation) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "unproved iOS 26 tab-bar occlusion rejection")
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  zero_movement_deep_scroll = observed_proof("ipad")
  zero_movement_deep_scroll["deepScroll"] = zero_movement_deep_scroll.fetch("deepScroll").merge(
    "swipeCount" => 0,
    "observedContentMovement" => false
  )
  root.join("apple/observed-ipad.json").write(JSON.pretty_generate(zero_movement_deep_scroll) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "zero-movement deep-scroll rejection")
  root.join("apple/observed-ipad.json").write(JSON.pretty_generate(observed_proof("ipad")) + "\n")

  missing_terminal = observed_proof("ios").merge("deepScroll" => nil)
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(missing_terminal) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "missing compact deep-scroll evidence rejection")
end

puts "design accessibility contract ok"
