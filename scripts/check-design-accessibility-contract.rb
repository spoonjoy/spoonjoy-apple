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

def readiness_proof(platform)
  {
    "platform" => platform,
    "route" => "kitchen",
    "source" => "KitchenView",
    "launchEnvironmentProof" => {},
    "screenshotStateSnapshotProof" => {
      "stateDirectoryResolved" => true,
      "appSnapshotPresent" => true,
      "appSnapshotJSONReadable" => true,
      "syncSnapshotPresent" => true,
      "syncSnapshotJSONReadable" => true
    },
    "observedDynamicTypeSize" => "large",
    "observedReduceMotion" => false,
    "visualReadiness" => {
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

def observed_proof(platform)
  if platform == "macos"
    {
      "platform" => platform,
      "route" => "kitchen",
      "pid" => 123,
      "bundleIdentifier" => "app.spoonjoy.mac",
      "bundlePath" => "/Applications/Spoonjoy.app",
      "executablePath" => "/Applications/Spoonjoy.app/Contents/MacOS/Spoonjoy",
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
    {
      "platform" => platform,
      "route" => "kitchen",
      "viewport" => rect(x: 0, y: 0, width: 100, height: 80),
      "elements" => [terminal, ios_element("system.tabBar", type: "tabBar", frame: rect(x: 0, y: 80, width: 100, height: 20))],
      "auditIssues" => [],
      "geometryFindings" => [],
      "observedContentSizeCategory" => "large",
      "observedDynamicTypeSize" => "large",
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
        "toolLimitations" => []
      }
    }
  end
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
      "apple/readiness-ipad.json",
      "apple/readiness-macos.json"
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
  %w[ios ipad macos].each do |platform|
    root.join("apple/readiness-#{platform}.json").write(JSON.pretty_generate(readiness_proof(platform)) + "\n")
    root.join("apple/observed-#{platform}.json").write(JSON.pretty_generate(observed_proof(platform)) + "\n")
  end
  root.join("apple/observed-ios-ax.json").write(JSON.pretty_generate(
    observed_proof("ios").merge(
      "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
      "observedDynamicTypeSize" => "accessibility5"
    )
  ) + "\n")
  manifest_path = root.join("design-review.json")
  valid_manifest = manifest(root)
  manifest_path.write(JSON.pretty_generate(valid_manifest) + "\n")
  assert_status(true, ["ruby", VALIDATOR, manifest_path], "valid observed accessibility evidence")

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
    observed_proof("ios").merge(
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
    observed_proof("ios").merge(
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

  missing_terminal = observed_proof("ios").merge("deepScroll" => nil)
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(missing_terminal) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "missing compact deep-scroll evidence rejection")
end

puts "design accessibility contract ok"
