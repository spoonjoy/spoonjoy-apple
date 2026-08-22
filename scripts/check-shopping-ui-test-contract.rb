#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"
require "tmpdir"
require "bundler/setup"
require "xcodeproj"

ROOT = Pathname.new(__dir__).join("..").expand_path
GENERATOR = ROOT.join("scripts/generate-xcode-project.rb")
UI_TEST_SOURCE = ROOT.join("Apps/Spoonjoy/UITests/SpoonjoyShoppingUITests.swift")
RECEIPT_LIST_SOURCE = ROOT.join("Apps/Spoonjoy/Shared/Components/ReceiptListView.swift")
TARGET_NAME = "SpoonjoyShoppingUITests"

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

fail_check("missing #{UI_TEST_SOURCE.relative_path_from(ROOT)}") unless UI_TEST_SOURCE.file?
source = UI_TEST_SOURCE.read
[
  "import XCTest",
  "XCUIApplication()",
  "UICTContentSizeCategoryAccessibilityXXXL",
  "XCUIDevice.shared.orientation = .portrait",
  "XCUIDevice.shared.orientation = .landscapeLeft",
  "SPOONJOY_SCREENSHOT_SHOPPING_VARIANT",
  "pending",
  "row-error",
  "buttons[\"Retry\"]",
  "keyboards.firstMatch",
  "isHittable"
].each { |token| fail_check("UI test source missing #{token}") unless source.include?(token) }
fail_check("receipt list missing stable pending-item accessibility identifier") unless RECEIPT_LIST_SOURCE.read.include?("shopping.item.\\(item.id).pending")

Dir.mktmpdir("spoonjoy-shopping-ui-target") do |directory|
  stdout, stderr, status = Open3.capture3(
    ROOT.join("scripts/bundle-exec.sh").to_s,
    "ruby", GENERATOR.to_s,
    "--output-dir", directory,
    chdir: ROOT.to_s
  )
  fail_check("generator failed:\n#{stdout}\n#{stderr}") unless status.success?
  project_path = Pathname.new(directory).join("Spoonjoy.xcodeproj")
  project = Xcodeproj::Project.open(project_path.to_s)
  target = project.targets.find { |candidate| candidate.name == TARGET_NAME }
  fail_check("generated project missing #{TARGET_NAME}") unless target
  fail_check("#{TARGET_NAME} must be a UI test bundle") unless target.symbol_type == :ui_test_bundle
  source_paths = target.source_build_phase.files.map { |file| file.file_ref&.real_path&.to_s }.compact
  fail_check("#{TARGET_NAME} missing UI test source") unless source_paths.any? { |path| path.end_with?("Apps/Spoonjoy/UITests/SpoonjoyShoppingUITests.swift") }
  dependency_names = target.dependencies.map { |dependency| dependency.target&.name }.compact
  fail_check("#{TARGET_NAME} must depend on Spoonjoy iOS") unless dependency_names == ["Spoonjoy iOS"]
  target.build_configuration_list.build_configurations.each do |configuration|
    settings = configuration.build_settings
    fail_check("#{TARGET_NAME} #{configuration.name} missing TEST_TARGET_NAME") unless settings["TEST_TARGET_NAME"] == "Spoonjoy iOS"
    fail_check("#{TARGET_NAME} #{configuration.name} must treat Swift warnings as errors") unless settings["SWIFT_TREAT_WARNINGS_AS_ERRORS"] == "YES"
  end
  scheme = project_path.join("xcshareddata/xcschemes/Spoonjoy iOS.xcscheme")
  scheme_text = scheme.read
  fail_check("Spoonjoy iOS scheme does not run #{TARGET_NAME}") unless scheme_text.include?(TARGET_NAME) && scheme_text.include?("<TestAction")
  fail_check("Spoonjoy iOS UI tests must use BootstrapDebug so installed simulator runtimes remain eligible") unless scheme_text.match?(/<TestAction\s+buildConfiguration = "BootstrapDebug"/m)
end

puts "shopping UI test target contract ok"
