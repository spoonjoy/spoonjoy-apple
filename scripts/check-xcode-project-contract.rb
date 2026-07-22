#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "rubygems"
require "bundler/setup"
require "xcodeproj"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_NAME = "Spoonjoy"
PROJECT_PATH = ROOT.join("#{PROJECT_NAME}.xcodeproj")
APP_ROOT = ROOT.join("Apps/Spoonjoy")
INFO_PLIST = APP_ROOT.join("Shared/Info.plist")
ENTITLEMENTS = APP_ROOT.join("Shared/Spoonjoy.entitlements")
SCHEME_DIR = PROJECT_PATH.join("xcshareddata/xcschemes")
IOS_SCHEME = SCHEME_DIR.join("Spoonjoy iOS.xcscheme")
MAC_SCHEME = SCHEME_DIR.join("Spoonjoy macOS.xcscheme")
MAC_WINDOW_DIAGNOSTIC_SCHEME = SCHEME_DIR.join("Spoonjoy macOS Window Diagnostics.xcscheme")
IOS_TARGET = "#{PROJECT_NAME} iOS"
MAC_TARGET = "#{PROJECT_NAME} macOS"
IOS_UI_TEST_TARGET = "SpoonjoyUITests"
MAC_WINDOW_DIAGNOSTIC_TARGET = "SpoonjoyMacWindowDiagnosticUITests"
IOS_BUNDLE_ID = "app.spoonjoy"
MAC_BUNDLE_ID = "app.spoonjoy.mac"
IOS_UI_TEST_BUNDLE_ID = "app.spoonjoy.uitests"
MAC_WINDOW_DIAGNOSTIC_BUNDLE_ID = "app.spoonjoy.mac.windowdiagnosticuitests"
ASSOCIATED_DOMAIN = "applinks:spoonjoy.app"
URL_SCHEME = "spoonjoy"
PACKAGE_PRODUCT = "SpoonjoyCore"

EXPECTED_FILES = [
  APP_ROOT.join("Shared/SpoonjoyApp.swift"),
  APP_ROOT.join("iOS/SpoonjoyiOSApp.swift"),
  APP_ROOT.join("macOS/SpoonjoyMacApp.swift"),
  ROOT.join("Apps/SpoonjoyUITests/NativeScreenshotEvidenceTests.swift"),
  ROOT.join("Apps/SpoonjoyUITests/ScreenshotEvidenceGeometry.swift"),
  ROOT.join("Apps/SpoonjoyMacWindowDiagnosticUITests/NativeMacWindowDiagnosticTests.swift"),
  APP_ROOT.join("Shared/Assets.xcassets"),
  INFO_PLIST,
  ENTITLEMENTS
].freeze

DEPLOYMENT_TARGETS = {
	  IOS_BUNDLE_ID => {
	    "Debug" => {
	      "IPHONEOS_DEPLOYMENT_TARGET" => "27.0",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "DEBUG SPOONJOY_SIGNED_APPLE_AUTH"
	    },
	    "Release" => {
	      "IPHONEOS_DEPLOYMENT_TARGET" => "27.0",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "SPOONJOY_SIGNED_APPLE_AUTH"
	    },
	    "BootstrapDebug" => {
	      "IPHONEOS_DEPLOYMENT_TARGET" => "26.5",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "DEBUG"
	    }
	  },
	  MAC_BUNDLE_ID => {
	    "Debug" => {
	      "MACOSX_DEPLOYMENT_TARGET" => "27.0",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "DEBUG SPOONJOY_SIGNED_APPLE_AUTH"
	    },
	    "Release" => {
	      "MACOSX_DEPLOYMENT_TARGET" => "27.0",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "SPOONJOY_SIGNED_APPLE_AUTH"
	    },
	    "BootstrapDebug" => {
	      "MACOSX_DEPLOYMENT_TARGET" => "26.2",
	      "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "DEBUG"
	    }
	  }
	}.freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def run_json!(*args)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: ROOT.to_s)
  fail_check("#{args.join(" ")} failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?
  JSON.parse(stdout)
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

def assert_setting(settings, key, expected, label)
  actual = settings[key]
  fail_check("#{label} expected #{key}=#{expected.inspect}, got #{actual.inspect}") unless actual == expected
end

def assert_absent_setting(settings, key, label)
  fail_check("#{label} must not set #{key}, got #{settings[key].inspect}") if settings.key?(key)
end

def assert_named_asset_exists(settings, key, extension, label, required: false)
  asset_name = settings[key]
  fail_check("#{label} missing #{key}") if required && (asset_name.nil? || asset_name.to_s.empty?)
  return if asset_name.nil? || asset_name.to_s.empty?

  asset_path = APP_ROOT.join("Shared/Assets.xcassets/#{asset_name}.#{extension}")
  fail_check("#{label} #{key} points at missing #{relative(asset_path)}") unless asset_path.directory?
end

def plist_json(path)
  fail_check("missing #{relative(path)}") unless path.file?

  run_json!("plutil", "-convert", "json", "-o", "-", path)
end

def host_major_minor
  stdout, stderr, status = Open3.capture3("sw_vers", "-productVersion")
  fail_check("sw_vers -productVersion failed\nSTDERR:\n#{stderr}") unless status.success?

  stdout.scan(/\d+/).first(2).map(&:to_i)
end

root_projects = ROOT.children.select { |path| path.extname == ".xcodeproj" }.map(&:basename).map(&:to_s)
unexpected_projects = root_projects - ["#{PROJECT_NAME}.xcodeproj"]
fail_check("unexpected root Xcode project(s): #{unexpected_projects.join(", ")}") unless unexpected_projects.empty?
fail_check("missing #{PROJECT_NAME}.xcodeproj") unless PROJECT_PATH.directory?
project_text = PROJECT_PATH.join("project.pbxproj").read
if project_text.match?(%r{SDKs/[A-Za-z]+[0-9]+\.[0-9]+\.sdk})
  fail_check("project contains version-pinned SDK framework paths; use current SDKROOT instead")
end

EXPECTED_FILES.each do |path|
  fail_check("missing #{relative(path)}") unless path.exist?
end
expected_schemes = [IOS_SCHEME, MAC_SCHEME, MAC_WINDOW_DIAGNOSTIC_SCHEME]
missing_schemes = expected_schemes.reject(&:file?)
fail_check("missing shared scheme(s): #{missing_schemes.map { |path| relative(path) }.join(", ")}") unless missing_schemes.empty?
scheme_files = SCHEME_DIR.children.select { |path| path.extname == ".xcscheme" }.map(&:basename).map(&:to_s).sort
expected_scheme_files = expected_schemes.map(&:basename).map(&:to_s).sort
unexpected_schemes = scheme_files - expected_scheme_files
fail_check("unexpected shared scheme(s): #{unexpected_schemes.join(", ")}") unless unexpected_schemes.empty?

info_plist = plist_json(INFO_PLIST)
url_schemes = Array(info_plist["CFBundleURLTypes"]).flat_map { |entry| Array(entry["CFBundleURLSchemes"]) }
fail_check("#{relative(INFO_PLIST)} missing URL scheme #{URL_SCHEME}") unless url_schemes.include?(URL_SCHEME)
supported_orientations = Array(info_plist["UISupportedInterfaceOrientations"])
expected_orientations = %w[
  UIInterfaceOrientationPortrait
  UIInterfaceOrientationPortraitUpsideDown
  UIInterfaceOrientationLandscapeLeft
  UIInterfaceOrientationLandscapeRight
]
missing_orientations = expected_orientations - supported_orientations
fail_check("#{relative(INFO_PLIST)} missing supported interface orientation(s): #{missing_orientations.join(", ")}") unless missing_orientations.empty?

entitlements = plist_json(ENTITLEMENTS)
associated_domains = Array(entitlements["com.apple.developer.associated-domains"])
fail_check("#{relative(ENTITLEMENTS)} missing #{ASSOCIATED_DOMAIN}") unless associated_domains.include?(ASSOCIATED_DOMAIN)

project = Xcodeproj::Project.open(PROJECT_PATH.to_s)
target_by_name = project.targets.each_with_object({}) { |target, index| index[target.name] = target }
ios_target = target_by_name[IOS_TARGET] || fail_check("missing target #{IOS_TARGET}")
mac_target = target_by_name[MAC_TARGET] || fail_check("missing target #{MAC_TARGET}")
ios_ui_test_target = target_by_name[IOS_UI_TEST_TARGET] || fail_check("missing target #{IOS_UI_TEST_TARGET}")
mac_window_diagnostic_target = target_by_name[MAC_WINDOW_DIAGNOSTIC_TARGET] || fail_check("missing target #{MAC_WINDOW_DIAGNOSTIC_TARGET}")

{
  IOS_SCHEME => { required: IOS_TARGET, required_test: IOS_UI_TEST_TARGET, forbidden: MAC_TARGET },
  MAC_SCHEME => {
    required: MAC_TARGET,
    forbidden: MAC_WINDOW_DIAGNOSTIC_TARGET,
    forbids_testable: true
  },
  MAC_WINDOW_DIAGNOSTIC_SCHEME => {
    required: MAC_TARGET,
    required_test: MAC_WINDOW_DIAGNOSTIC_TARGET,
    forbidden: IOS_TARGET
  }
}.each do |scheme, targets|
  scheme_text = scheme.read
  fail_check("#{relative(scheme)} missing #{targets.fetch(:required)}") unless scheme_text.include?(targets.fetch(:required))
  fail_check("#{relative(scheme)} must not include #{targets.fetch(:forbidden)}") if scheme_text.include?(targets.fetch(:forbidden))
  fail_check("#{relative(scheme)} missing Launch/Profile runnable") unless scheme_text.include?("<BuildableProductRunnable")
  if targets[:required_test]
    fail_check("#{relative(scheme)} missing #{targets.fetch(:required_test)}") unless scheme_text.include?(targets.fetch(:required_test))
    fail_check("#{relative(scheme)} missing TestableReference") unless scheme_text.include?("<TestableReference")
    fail_check("#{relative(scheme)} Test action must use BootstrapDebug") unless scheme_text.match?(%r{<TestAction\s+buildConfiguration = "BootstrapDebug"})
  end
  if targets[:forbids_testable]
    fail_check("#{relative(scheme)} generic app scheme must not include TestableReference") if scheme_text.include?("<TestableReference")
  end
end

{
  ios_target => IOS_BUNDLE_ID,
  mac_target => MAC_BUNDLE_ID
}.each do |target, bundle_id|
  expected_settings = DEPLOYMENT_TARGETS.fetch(bundle_id)
  expected_settings.each do |configuration, settings|
    build_configuration = target.build_configuration_list[configuration] || fail_check("missing #{target.name} #{configuration}")
    build_settings = build_configuration.build_settings
    label = "#{target.name} #{configuration}"

    assert_setting(build_settings, "PRODUCT_BUNDLE_IDENTIFIER", bundle_id, label)
    assert_setting(build_settings, "SWIFT_VERSION", "6.0", label)
    assert_setting(build_settings, "SWIFT_TREAT_WARNINGS_AS_ERRORS", "YES", label)
    assert_setting(build_settings, "GCC_TREAT_WARNINGS_AS_ERRORS", "YES", label)
    assert_setting(build_settings, "INFOPLIST_FILE", relative(INFO_PLIST), label)
    if configuration == "BootstrapDebug"
      assert_absent_setting(build_settings, "CODE_SIGN_ENTITLEMENTS", label)
    else
      assert_setting(build_settings, "CODE_SIGN_ENTITLEMENTS", relative(ENTITLEMENTS), label)
    end
    assert_named_asset_exists(build_settings, "ASSETCATALOG_COMPILER_APPICON_NAME", "appiconset", label, required: true)
    assert_named_asset_exists(build_settings, "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "colorset", label)

    settings.each do |key, expected|
      assert_setting(build_settings, key, expected, label)
    end
  end
end

def assert_package_product(target, product_name)
  dependencies = target.package_product_dependencies.select { |dependency| dependency.product_name == product_name }
  fail_check("#{target.name} missing package product dependency #{product_name}") if dependencies.empty?
  fail_check("#{target.name} has duplicate package product dependency #{product_name}") if dependencies.length > 1

  framework_entries = target.frameworks_build_phase.files.select do |build_file|
    build_file.product_ref&.product_name == product_name
  end
  fail_check("#{target.name} missing #{product_name} in Frameworks phase") if framework_entries.empty?
  fail_check("#{target.name} has duplicate #{product_name} Frameworks entries") if framework_entries.length > 1
end

[ios_target, mac_target].each { |target| assert_package_product(target, PACKAGE_PRODUCT) }

DEPLOYMENT_TARGETS.fetch(IOS_BUNDLE_ID).each do |configuration, settings|
  build_configuration = ios_ui_test_target.build_configuration_list[configuration] || fail_check("missing #{IOS_UI_TEST_TARGET} #{configuration}")
  build_settings = build_configuration.build_settings
  label = "#{IOS_UI_TEST_TARGET} #{configuration}"
  assert_setting(build_settings, "PRODUCT_BUNDLE_IDENTIFIER", IOS_UI_TEST_BUNDLE_ID, label)
  assert_setting(build_settings, "SWIFT_VERSION", "6.0", label)
  assert_setting(build_settings, "SWIFT_TREAT_WARNINGS_AS_ERRORS", "YES", label)
  assert_setting(build_settings, "GCC_TREAT_WARNINGS_AS_ERRORS", "YES", label)
  assert_setting(build_settings, "GENERATE_INFOPLIST_FILE", "YES", label)
  assert_setting(build_settings, "IPHONEOS_DEPLOYMENT_TARGET", settings.fetch("IPHONEOS_DEPLOYMENT_TARGET"), label)
  assert_setting(build_settings, "TEST_TARGET_NAME", IOS_TARGET, label)
  assert_setting(build_settings, "LM_FILTER_WARNINGS", "YES", label)
  assert_setting(build_settings, "LM_SKIP_METADATA_EXTRACTION", "YES", label)
end

DEPLOYMENT_TARGETS.fetch(MAC_BUNDLE_ID).each do |configuration, settings|
  build_configuration = mac_window_diagnostic_target.build_configuration_list[configuration] || fail_check("missing #{MAC_WINDOW_DIAGNOSTIC_TARGET} #{configuration}")
  build_settings = build_configuration.build_settings
  label = "#{MAC_WINDOW_DIAGNOSTIC_TARGET} #{configuration}"
  assert_setting(build_settings, "PRODUCT_BUNDLE_IDENTIFIER", MAC_WINDOW_DIAGNOSTIC_BUNDLE_ID, label)
  assert_setting(build_settings, "SWIFT_VERSION", "6.0", label)
  assert_setting(build_settings, "SWIFT_TREAT_WARNINGS_AS_ERRORS", "YES", label)
  assert_setting(build_settings, "GCC_TREAT_WARNINGS_AS_ERRORS", "YES", label)
  assert_setting(build_settings, "GENERATE_INFOPLIST_FILE", "YES", label)
  assert_setting(build_settings, "MACOSX_DEPLOYMENT_TARGET", settings.fetch("MACOSX_DEPLOYMENT_TARGET"), label)
  assert_setting(build_settings, "TEST_TARGET_NAME", MAC_TARGET, label)
  assert_setting(build_settings, "LM_FILTER_WARNINGS", "YES", label)
  assert_setting(build_settings, "LM_SKIP_METADATA_EXTRACTION", "YES", label)
end

mac_bootstrap = Gem::Version.new(
  mac_target.build_configuration_list["BootstrapDebug"].build_settings.fetch("MACOSX_DEPLOYMENT_TARGET")
)
host_version = Gem::Version.new(host_major_minor.join("."))
fail_check("BootstrapDebug macOS target #{mac_bootstrap} exceeds host #{host_version}") if mac_bootstrap > host_version

def target_source_paths(target)
  target.source_build_phase.files.map do |build_file|
    ref = build_file.file_ref
    next unless ref&.path&.end_with?(".swift")

    ref.real_path.to_s
  end.compact
end

ios_sources = target_source_paths(ios_target)
mac_sources = target_source_paths(mac_target)
ios_ui_test_sources = target_source_paths(ios_ui_test_target)
mac_window_diagnostic_sources = target_source_paths(mac_window_diagnostic_target)
app_swift_files = APP_ROOT.find.select { |path| path.file? && path.extname == ".swift" }.map(&:to_s)

app_swift_files.each do |source|
  rel = relative(source)
  expected_targets =
    if rel.start_with?("Apps/Spoonjoy/Shared/")
      [IOS_TARGET, MAC_TARGET]
    elsif rel.start_with?("Apps/Spoonjoy/iOS/")
      [IOS_TARGET]
    elsif rel.start_with?("Apps/Spoonjoy/macOS/")
      [MAC_TARGET]
    else
      fail_check("unexpected Apps/Spoonjoy Swift file location: #{rel}")
    end

  fail_check("#{rel} missing from #{IOS_TARGET}") if expected_targets.include?(IOS_TARGET) && !ios_sources.include?(source)
  fail_check("#{rel} missing from #{MAC_TARGET}") if expected_targets.include?(MAC_TARGET) && !mac_sources.include?(source)
  fail_check("#{rel} unexpectedly in #{IOS_TARGET}") if !expected_targets.include?(IOS_TARGET) && ios_sources.include?(source)
  fail_check("#{rel} unexpectedly in #{MAC_TARGET}") if !expected_targets.include?(MAC_TARGET) && mac_sources.include?(source)
end

ui_test_swift_files = ROOT.join("Apps/SpoonjoyUITests").find.select do |path|
  path.file? && path.extname == ".swift"
end.map(&:to_s)
ui_test_swift_files.each do |source|
  fail_check("#{relative(source)} missing from #{IOS_UI_TEST_TARGET}") unless ios_ui_test_sources.include?(source)
  fail_check("#{relative(source)} unexpectedly in #{IOS_TARGET}") if ios_sources.include?(source)
  fail_check("#{relative(source)} unexpectedly in #{MAC_TARGET}") if mac_sources.include?(source)
end


mac_window_diagnostic_swift_files = ROOT.join("Apps/SpoonjoyMacWindowDiagnosticUITests").find.select do |path|
  path.file? && path.extname == ".swift"
end.map(&:to_s)
mac_window_diagnostic_swift_files.each do |source|
  fail_check("#{relative(source)} missing from #{MAC_WINDOW_DIAGNOSTIC_TARGET}") unless mac_window_diagnostic_sources.include?(source)
  fail_check("#{relative(source)} unexpectedly in #{IOS_TARGET}") if ios_sources.include?(source)
  fail_check("#{relative(source)} unexpectedly in #{MAC_TARGET}") if mac_sources.include?(source)
end

diagnostic_source = ROOT.join("Apps/SpoonjoyMacWindowDiagnosticUITests/NativeMacWindowDiagnosticTests.swift").read
[
  "SPOONJOY_SCREENSHOT_EXPECTED_ROUTE",
  "ui-window-diagnostic",
  "releaseAccessibilityEvidence: Bool = false",
  "macos-ui-window-diagnostic",
  "macos-ui-window-diagnostic-screenshot",
  "app.descendants(matching: .any)",
  "supportedRouteMarkers[route]",
  "routeMarker.waitForExistence",
  "accessibilityElementCount",
  "XCUIIdentifierMinimizeWindow",
  "app.activate()",
  "initialWindowCount",
  "reopenedWindowCount",
  "restoredMinimizedWindow"
].each do |token|
  fail_check("macOS window diagnostic source missing #{token}") unless diagnostic_source.include?(token)
end
fail_check("macOS window diagnostic must not default to the kitchen route") if diagnostic_source.match?(/EXPECTED_ROUTE[^\n]*\?\?\s*"kitchen"/)
fail_check("macOS window diagnostic must not claim release accessibility evidence") if diagnostic_source.include?("observed-accessibility-evidence")

puts "xcode project contract ok"
