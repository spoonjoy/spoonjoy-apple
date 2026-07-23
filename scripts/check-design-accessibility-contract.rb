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
  "iosXXXL" => "screenshots/ios-mobile-xxxl-deep-scroll.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility-deep-scroll.png",
  "iosTablet" => "screenshots/ios-tablet-deep-scroll.png",
  "iosTabletXXXL" => "screenshots/ios-tablet-xxxl-deep-scroll.png",
  "iosTabletAccessibility" => "screenshots/ios-tablet-accessibility-deep-scroll.png",
  "macosDesktop" => "screenshots/macos-desktop-deep-scroll.png"
}.freeze
REQUIRED_AUDIT_TYPES = %w[contrast dynamicType textClipped hitRegion trait].freeze

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
  ["ios", "xxxLarge"] => "43afb485-26a1-4d2a-a205-4317fa1c4210",
  ["ios", "accessibility5"] => "f62de99c-0067-4c71-9fc5-f7ba5cc27e6c",
  ["ipad", "large"] => "817a858d-c004-4036-9c1d-d816b97f5d99",
  ["ipad", "xxxLarge"] => "f79d818b-1766-4fa8-b1db-61613faefcb8",
  ["ipad", "accessibility5"] => "35a4ef74-45d5-49d1-ac8e-f9f40fd6852d",
  ["macos", "large"] => "bf3d228e-0f1f-4450-b8dc-e48db62686b6"
}.freeze
READINESS_GENERATIONS = {
  ["ios", "large"] => 10,
  ["ios", "xxxLarge"] => 15,
  ["ios", "accessibility5"] => 20,
  ["ipad", "large"] => 30,
  ["ipad", "xxxLarge"] => 32,
  ["ipad", "accessibility5"] => 34,
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
  observer_suffix = dynamic_type == "large" ? platform : dynamic_type == "xxxLarge" ? "#{platform}-xxxl" : "#{platform}-ax"
  capture_run_nonce = CAPTURE_RUN_NONCES.fetch([platform, dynamic_type])
  {
    "captureRunNonce" => capture_run_nonce,
    "route" => "kitchen",
    "source" => "KitchenView",
    "applicationProcessIdentifier" => 42_012,
    "readinessGeneration" => generation,
    "proofFileName" => "native-accessibility-proof.observer-#{observer_suffix}-#{capture_run_nonce}.generation-#{generation}.json",
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
    "hitRegionAuditVerified" => true,
    "focused" => nil
  }
end

def ios_pixel_accessibility_binding(capture_id, screenshot_sha256, phase)
  deep = phase == "deepScroll"
  {
    "schema" => "iosPixelAccessibilityBindingV1",
    "captureID" => capture_id,
    "capturePhase" => phase,
    "pixelSource" => "mainScreen",
    "screenshotSHA256" => screenshot_sha256,
    "accessibilitySnapshotBeforeSHA256" => "a" * 64,
    "accessibilitySnapshotAfterSHA256" => "a" * 64,
    "windowFrame" => rect(x: 0, y: 0, width: 100, height: 100),
    "selectedScrollHierarchyIdentifier" => deep ? "spoonjoy.page-scroll" : nil,
    "selectedScrollHierarchySnapshotBeforeSHA256" => deep ? "b" * 64 : nil,
    "selectedScrollHierarchySnapshotAfterSHA256" => deep ? "b" * 64 : nil
  }
end

def macos_pixel_accessibility_binding(screenshot_sha256, phase)
  deep = phase == "deepScroll"
  {
    "schema" => "macosPixelAccessibilityBindingV1",
    "capturePhase" => phase,
    "pixelSource" => "exactCGWindowID",
    "screenshotSHA256" => screenshot_sha256,
    "accessibilitySnapshotBeforeSHA256" => "c" * 64,
    "accessibilitySnapshotAfterSHA256" => "c" * 64,
    "applicationProcessIdentifier" => 123,
    "windowID" => 456,
    "windowFrame" => rect,
    "selectedScrollHierarchyIdentifier" => deep ? "spoonjoy.page-scroll" : nil,
    "selectedScrollHierarchySnapshotBeforeSHA256" => deep ? "d" * 64 : nil,
    "selectedScrollHierarchySnapshotAfterSHA256" => deep ? "d" * 64 : nil
  }
end

def fixture_screenshot_sha256(platform, dynamic_type:, capture_phase:)
  name = if platform == "ipad"
           size = dynamic_type == "accessibility5" ? "-accessibility" : dynamic_type == "xxxLarge" ? "-xxxl" : ""
           "ios-tablet#{size}#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         elsif platform == "macos"
           "macos-desktop#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         elsif dynamic_type == "accessibility5"
           "ios-mobile-accessibility#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         elsif dynamic_type == "xxxLarge"
           "ios-mobile-xxxl#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         else
           "ios-mobile#{capture_phase == "deepScroll" ? "-deep-scroll" : ""}.png"
         end
  Digest::SHA256.hexdigest("png:#{name}")
end

def observed_proof(platform, dynamic_type: "large")
  if platform == "macos"
    terminal = {
      "identifier" => "kitchen.cookbook.cookbook_slow_sundays",
      "role" => "AXButton",
      "subrole" => "",
      "title" => "Slow Sundays and Long Simmering Suppers, 0 recipes",
      "frame" => rect(x: 10, y: 10, width: 44, height: 44),
      "enabled" => true,
      "focused" => false,
      "actions" => ["AXPress"]
    }
    proof = {
      "platform" => platform,
      "route" => "kitchen",
      "captureRunNonce" => CAPTURE_RUN_NONCES.fetch([platform, dynamic_type]),
      "readinessProofSHA256" => Digest::SHA256.hexdigest(readiness_proof_bytes(platform, dynamic_type: dynamic_type)),
      "screenshotSHA256" => fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "initial"),
      "pixelAccessibilityBinding" => macos_pixel_accessibility_binding(
        fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "initial"),
        "initial"
      ),
      "pid" => 123,
      "windowID" => 456,
      "bundleIdentifier" => "app.spoonjoy.mac",
      "bundlePath" => "/Applications/Spoonjoy.app",
      "executablePath" => "/Applications/Spoonjoy.app/Contents/MacOS/Spoonjoy",
      "executableSHA256" => "e" * 64,
      "windowFrames" => [rect],
      "elements" => [terminal],
      "findings" => [],
      "deepScroll" => {
        "route" => "kitchen",
        "reachedTerminal" => true,
        "contentViewport" => rect,
        "terminalElement" => terminal,
        "findings" => [],
        "scrollAreaIdentifier" => "spoonjoy.page-scroll",
        "initialScrollValue" => 0,
        "finalScrollValue" => 1,
        "postScrollScreenshotSHA256" => fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll"),
        "applicationProcessIdentifier" => 123,
        "windowID" => 456,
        "postScrollElements" => [terminal],
        "postScrollAuditFindings" => [],
        "pixelAccessibilityBinding" => macos_pixel_accessibility_binding(
          fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll"),
          "deepScroll"
        ),
        "selectedScrollHierarchyIdentifier" => "spoonjoy.page-scroll",
        "selectedScrollHierarchyElements" => [terminal]
      }
    }
  else
    terminal = ios_element(
      "kitchen.cookbook.cookbook_slow_sundays",
      type: "button",
      frame: rect(x: 10, y: 20, width: 44, height: 44)
    )
    terminal["label"] = "Slow Sundays and Long Simmering Suppers, 0 recipes"
    initial_screenshot_sha256 = fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "initial")
    deep_screenshot_sha256 = fixture_screenshot_sha256(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll")
    initial_handshake = readiness_handshake(platform, dynamic_type: dynamic_type, capture_phase: "initial")
    deep_handshake = readiness_handshake(platform, dynamic_type: dynamic_type, capture_phase: "deepScroll")
    proof = {
      "platform" => platform,
      "route" => "kitchen",
      "viewport" => rect(x: 0, y: 0, width: 100, height: 80),
      "elements" => [terminal, ios_element("system.tabBar", type: "tabBar", frame: rect(x: 0, y: 80, width: 100, height: 20))],
      "auditIssues" => [],
      "auditTypes" => REQUIRED_AUDIT_TYPES,
      "verifiedContrastFalsePositives" => [],
      "screenshotSHA256" => initial_screenshot_sha256,
      "captureIdentity" => {
        "schema" => "iosObservedCaptureV1",
        "captureID" => dynamic_type == "large" ? "7616b756-9527-4fd6-982a-8f3cb9f9c4dc" : dynamic_type == "xxxLarge" ? "aca6227f-8820-43cf-9c83-f24e7c2626b2" : "d846092a-c7c1-41dd-a460-448e9745392b",
        "captureRunNonce" => initial_handshake.fetch("captureRunNonce"),
        "capturePhase" => "initial",
        "applicationBundleIdentifier" => "app.spoonjoy",
        "applicationProcessIdentifier" => initial_handshake.fetch("applicationProcessIdentifier"),
        "foregroundBeforeCapture" => true,
        "foregroundAfterCapture" => true,
        "screenshotSHA256" => initial_screenshot_sha256
      },
      "hostProcessObservation" => {
        "schema" => "iosHostProcessObservationV1",
        "applicationBundleIdentifier" => "app.spoonjoy",
        "applicationProcessIdentifier" => initial_handshake.fetch("applicationProcessIdentifier"),
        "launchctlLabel" => "UIKitApplication:app.spoonjoy[fixture]",
        "sampleCount" => 8
      },
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
        "auditTypes" => REQUIRED_AUDIT_TYPES,
        "verifiedContrastFalsePositives" => [],
        "screenshotSHA256" => deep_screenshot_sha256,
        "readinessHandshake" => deep_handshake,
        "captureIdentity" => {
          "schema" => "iosObservedCaptureV1",
          "captureID" => dynamic_type == "large" ? "19dc51d4-5113-4268-80a5-c85cc05e8d0b" : dynamic_type == "xxxLarge" ? "811bb1f4-4edf-490a-8ce4-dd159ff5aff2" : "be455761-35eb-457d-8b26-49bf43a13ff4",
          "captureRunNonce" => deep_handshake.fetch("captureRunNonce"),
          "capturePhase" => "deepScroll",
          "applicationBundleIdentifier" => "app.spoonjoy",
          "applicationProcessIdentifier" => deep_handshake.fetch("applicationProcessIdentifier"),
          "foregroundBeforeCapture" => true,
          "foregroundAfterCapture" => true,
          "screenshotSHA256" => deep_screenshot_sha256
        },
        "selectedScrollHierarchyIdentifier" => "spoonjoy.page-scroll",
        "selectedScrollHierarchyElements" => [terminal],
        "observedContentMovement" => true,
        "contentFitsWithoutScrolling" => false,
        "toolLimitations" => []
      }
    }
    proof["pixelAccessibilityBinding"] = ios_pixel_accessibility_binding(
      proof.fetch("captureIdentity").fetch("captureID"),
      initial_screenshot_sha256,
      "initial"
    )
    proof.fetch("deepScroll")["pixelAccessibilityBinding"] = ios_pixel_accessibility_binding(
      proof.dig("deepScroll", "captureIdentity", "captureID"),
      deep_screenshot_sha256,
      "deepScroll"
    )
    proof["readinessHandshake"] = initial_handshake
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
      "iosXXXL" => screenshot_artifact(root, "screenshots/ios-mobile-xxxl.png"),
      "iosAccessibility" => screenshot_artifact(root, "screenshots/ios-mobile-accessibility.png"),
      "iosTablet" => screenshot_artifact(root, "screenshots/ios-tablet.png"),
      "iosTabletXXXL" => screenshot_artifact(root, "screenshots/ios-tablet-xxxl.png"),
      "iosTabletAccessibility" => screenshot_artifact(root, "screenshots/ios-tablet-accessibility.png"),
      "macosDesktop" => screenshot_artifact(root, "screenshots/macos-desktop.png")
    },
    "deepScrollScreenshotArtifacts" => DEEP_SCROLL_SCREENSHOT_ARTIFACTS.to_h do |name, relative_path|
      [name, screenshot_artifact(root, relative_path)]
    end,
    "kitchenSignedInSurface" => true,
    "kitchenSeedAccountID" => "chef_kitchen_capture",
    "accessibilityProofArtifacts" => [
      "apple/readiness-ios.json",
      "apple/readiness-ios-xxxl.json",
      "apple/readiness-ios-ax.json",
      "apple/readiness-ipad.json",
      "apple/readiness-ipad-xxxl.json",
      "apple/readiness-ipad-ax.json",
      "apple/readiness-macos.json"
    ],
    "deepScrollAccessibilityProofArtifacts" => [
      "apple/readiness-ios-deep-scroll.json",
      "apple/readiness-ios-xxxl-deep-scroll.json",
      "apple/readiness-ios-ax-deep-scroll.json",
      "apple/readiness-ipad-deep-scroll.json",
      "apple/readiness-ipad-xxxl-deep-scroll.json",
      "apple/readiness-ipad-ax-deep-scroll.json"
    ],
    "observedAccessibilityEvidenceArtifacts" => [
      "apple/observed-ios.json",
      "apple/observed-ios-xxxl.json",
      "apple/observed-ios-ax.json",
      "apple/observed-ipad.json",
      "apple/observed-ipad-xxxl.json",
      "apple/observed-ipad-ax.json",
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
  %w[ios-mobile.png ios-mobile-xxxl.png ios-mobile-accessibility.png ios-tablet.png ios-tablet-xxxl.png ios-tablet-accessibility.png macos-desktop.png].each do |name|
    root.join("screenshots", name).write("png:#{name}")
  end
  DEEP_SCROLL_SCREENSHOT_ARTIFACTS.each_value do |relative_path|
    root.join(relative_path).write("png:#{Pathname.new(relative_path).basename}")
  end
  [["ios", "large", "ios"], ["ios", "xxxLarge", "ios-xxxl"], ["ios", "accessibility5", "ios-ax"], ["ipad", "large", "ipad"], ["ipad", "xxxLarge", "ipad-xxxl"], ["ipad", "accessibility5", "ipad-ax"], ["macos", "large", "macos"]].each do |platform, dynamic_type, suffix|
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
  root.join("apple/observed-ios-xxxl.json").write(JSON.pretty_generate(
    observed_proof("ios", dynamic_type: "xxxLarge").merge(
      "observedContentSizeCategory" => "extra-extra-extra-large",
      "observedDynamicTypeSize" => "xxxLarge"
    )
  ) + "\n")
  root.join("apple/observed-ipad-ax.json").write(JSON.pretty_generate(
    observed_proof("ipad", dynamic_type: "accessibility5").merge(
      "observedContentSizeCategory" => "accessibility-extra-extra-extra-large",
      "observedDynamicTypeSize" => "accessibility5"
    )
  ) + "\n")
  root.join("apple/observed-ipad-xxxl.json").write(JSON.pretty_generate(
    observed_proof("ipad", dynamic_type: "xxxLarge").merge(
      "observedContentSizeCategory" => "extra-extra-extra-large",
      "observedDynamicTypeSize" => "xxxLarge"
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
  ipad_fits["deepScroll"]["swipeCount"] = 0
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

  coherently_substituted_pid = observed_proof("ios")
  coherently_substituted_pid["readinessHandshake"]["applicationProcessIdentifier"] = 43_999
  coherently_substituted_pid["captureIdentity"]["applicationProcessIdentifier"] = 43_999
  coherently_substituted_pid["deepScroll"]["readinessHandshake"]["applicationProcessIdentifier"] = 43_999
  coherently_substituted_pid["deepScroll"]["captureIdentity"]["applicationProcessIdentifier"] = 43_999
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(coherently_substituted_pid) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "coherently substituted positive iOS PID rejection")
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  missing_initial_pixel_ax_binding = observed_proof("ios")
  missing_initial_pixel_ax_binding.delete("pixelAccessibilityBinding")
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(missing_initial_pixel_ax_binding) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "missing initial iOS pixel/AX binding rejection")
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  coherent_text_overlap = observed_proof("ios")
  coherent_text_overlap["elements"] += [
    ios_element("overlap.first", frame: rect(x: 10, y: 10, width: 60, height: 30)),
    ios_element("overlap.second", frame: rect(x: 20, y: 20, width: 60, height: 30))
  ]
  coherent_text_overlap["geometryFindings"] = []
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(coherent_text_overlap) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "coherently falsified text overlap rejection")

  coherent_small_target = observed_proof("ios")
  coherent_small_target["elements"] << ios_element(
    "small.action",
    type: "button",
    frame: rect(x: 10, y: 10, width: 20, height: 20)
  )
  coherent_small_target["geometryFindings"] = []
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(coherent_small_target) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "coherently falsified target-size rejection")

  coherent_terminal_occlusion = observed_proof("ios")
  coherent_terminal_occlusion["deepScroll"]["terminalElement"]["frame"] = rect(x: 10, y: 70, width: 44, height: 20)
  coherent_terminal_occlusion["deepScroll"]["findings"] = []
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(coherent_terminal_occlusion) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "coherently falsified terminal occlusion rejection")
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
  root.join("apple/observed-ios.json").write(JSON.pretty_generate(observed_proof("ios")) + "\n")

  ipad_xxxl_path = root.join("apple/observed-ipad-xxxl.json")
  incomplete_xxxl_audit = observed_proof("ipad", dynamic_type: "xxxLarge").merge(
    "observedContentSizeCategory" => "extra-extra-extra-large",
    "observedDynamicTypeSize" => "xxxLarge",
    "auditTypes" => REQUIRED_AUDIT_TYPES - ["dynamicType"]
  )
  ipad_xxxl_path.write(JSON.pretty_generate(incomplete_xxxl_audit) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "iPad XXXL missing Dynamic Type audit rejection")
  ipad_xxxl_path.write(JSON.pretty_generate(
    observed_proof("ipad", dynamic_type: "xxxLarge").merge(
      "observedContentSizeCategory" => "extra-extra-extra-large",
      "observedDynamicTypeSize" => "xxxLarge"
    )
  ) + "\n")

  incomplete_deep_audit = observed_proof("ipad")
  incomplete_deep_audit.fetch("deepScroll")["auditTypes"] = REQUIRED_AUDIT_TYPES - ["textClipped"]
  ipad_path.write(JSON.pretty_generate(incomplete_deep_audit) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "deep-scroll missing text clipping audit rejection")
  ipad_path.write(JSON.pretty_generate(observed_proof("ipad")) + "\n")

  macos_path = root.join("apple/observed-macos.json")
  substituted_post_scroll = observed_proof("macos")
  substituted_post_scroll.fetch("deepScroll")["postScrollScreenshotSHA256"] = "0" * 64
  macos_path.write(JSON.pretty_generate(substituted_post_scroll) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "macOS post-scroll screenshot substitution rejection")

  missing_macos_initial_pixel_ax_binding = observed_proof("macos")
  missing_macos_initial_pixel_ax_binding.delete("pixelAccessibilityBinding")
  macos_path.write(JSON.pretty_generate(missing_macos_initial_pixel_ax_binding) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "missing initial macOS pixel/AX binding rejection")

  failed_post_scroll_audit = observed_proof("macos")
  failed_post_scroll_audit.fetch("deepScroll")["postScrollAuditFindings"] = [
    { "kind" => "textClipped", "message" => "terminal title clipped" }
  ]
  macos_path.write(JSON.pretty_generate(failed_post_scroll_audit) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "macOS post-scroll audit finding rejection")

  substituted_post_scroll_pid = observed_proof("macos")
  substituted_post_scroll_pid.fetch("deepScroll")["applicationProcessIdentifier"] += 1
  macos_path.write(JSON.pretty_generate(substituted_post_scroll_pid) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "macOS post-scroll PID substitution rejection")

  substituted_post_scroll_window = observed_proof("macos")
  substituted_post_scroll_window.fetch("deepScroll")["windowID"] += 1
  macos_path.write(JSON.pretty_generate(substituted_post_scroll_window) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "macOS post-scroll window substitution rejection")

  missing_post_scroll_terminal = observed_proof("macos")
  missing_post_scroll_terminal.fetch("deepScroll")["postScrollElements"] = []
  macos_path.write(JSON.pretty_generate(missing_post_scroll_terminal) + "\n")
  assert_status(false, ["ruby", VALIDATOR, manifest_path], "macOS post-scroll terminal re-observation rejection")
  macos_path.write(JSON.pretty_generate(observed_proof("macos")) + "\n")
end

puts "design accessibility contract ok"
