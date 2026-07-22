#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
GENERATOR = ROOT.join("scripts/generate-xcode-project.rb")
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")
GEMFILE = ROOT.join("Gemfile")
GEMFILE_LOCK = ROOT.join("Gemfile.lock")
WORKFLOW = ROOT.join(".github/workflows/native.yml")
LOCAL_MATRIX = ROOT.join("scripts/validate-native-local.sh")
BUNDLE_EXEC = [ROOT.join("scripts/bundle-exec.sh").to_s].freeze
REPO_OUTPUT_ROOTS = [
  ROOT.join("Spoonjoy.xcodeproj"),
  ROOT.join("Apps/Spoonjoy")
].freeze
NATIVE_SOURCE_EXEMPTION = ROOT.join("Apps/Spoonjoy/Shared/Native")

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def run!(*args)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: ROOT.to_s)
  fail_check("#{args.join(" ")} failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?
  stdout
end

def generated_repo_outputs
  REPO_OUTPUT_ROOTS.flat_map do |root|
    next [] unless root.exist?

    if root.file?
      [root]
    else
      root.find.to_a
    end
  end.reject do |path|
    path == NATIVE_SOURCE_EXEMPTION || path.to_s.start_with?("#{NATIVE_SOURCE_EXEMPTION}/")
  end
end

def output_snapshot
  generated_repo_outputs.each_with_object({}) do |path, snapshot|
    snapshot[path.relative_path_from(ROOT).to_s] = path.file? ? path.mtime.to_f : :directory
  end
end

def assert_setting(block, setting, expected)
  match = block.match(/#{Regexp.escape(setting)} = ([^;]+);/)
  fail_check("missing #{setting} in build settings:\n#{block}") unless match
  actual = match[1].strip
  fail_check("expected #{setting} = #{expected}, got #{actual}") unless actual == expected
end

def assert_absent_setting(block, setting)
  fail_check("unexpected #{setting} in build settings:\n#{block}") if block.match?(/#{Regexp.escape(setting)} = [^;]+;/)
end

def build_configuration_objects(project_content)
  project_content.scan(%r{/\* (?<object_name>[^*]+) \*/ = \{
\s+isa = XCBuildConfiguration;
\s+buildSettings = \{(?<settings>.*?)\};
\s+name = (?<configuration>[^;]+);
\s+\};}m).map do |object_name, settings, configuration|
    {
      object_name: object_name.strip,
      settings: settings,
      configuration: configuration.strip.delete('"')
    }
  end
end

def find_build_settings_block(project_content, bundle_id, configuration)
  matches = build_configuration_objects(project_content).select do |object|
    object[:configuration] == configuration &&
      object[:settings].include?("PRODUCT_BUNDLE_IDENTIFIER = #{bundle_id};")
  end

  fail_check("missing build settings for #{bundle_id} #{configuration}") if matches.empty?
  fail_check("multiple build settings for #{bundle_id} #{configuration}") if matches.length > 1

  matches.first[:settings]
end

fail_check("#{GENERATOR.relative_path_from(ROOT)} is missing") unless GENERATOR.file?
fail_check("#{PROJECT_CONTRACT.relative_path_from(ROOT)} is missing") unless PROJECT_CONTRACT.file?
fail_check("Gemfile is missing") unless GEMFILE.file?
fail_check("Gemfile.lock is missing") unless GEMFILE_LOCK.file?

gemfile = GEMFILE.read
gemfile_lock = GEMFILE_LOCK.read
fail_check("Gemfile must pin xcodeproj 1.27.0") unless gemfile.include?('gem "xcodeproj", "1.27.0"')
fail_check("Gemfile must pin CFPropertyList 3.0.8 for Ruby 3.3 CI compatibility") unless gemfile.include?('gem "CFPropertyList", "3.0.8"')
fail_check("Gemfile.lock must lock xcodeproj 1.27.0") unless gemfile_lock.include?("xcodeproj (1.27.0)")
fail_check("Gemfile.lock must lock CFPropertyList 3.0.8") unless gemfile_lock.include?("CFPropertyList (3.0.8)")
fail_check("Gemfile.lock must not lock CFPropertyList 3.0.9") if gemfile_lock.include?("CFPropertyList (3.0.9)")
fail_check("Gemfile.lock must record Bundler 2.4.22") unless gemfile_lock.include?("BUNDLED WITH\n   2.4.22")

{
  GENERATOR => "generate-xcode-project.rb",
  PROJECT_CONTRACT => "check-xcode-project-contract.rb"
}.each do |path, label|
  source = path.read
  fail_check("#{label} must load bundler/setup before xcodeproj") unless source.include?('require "bundler/setup"') &&
    source.index('require "bundler/setup"') < source.index('require "xcodeproj"')
end

workflow = WORKFLOW.read
matrix = ROOT.join("scripts/validate-native-local.sh").read
[
  "ruby/setup-ruby@8e41b362d2589a22a44c1cfa214b3c83052c195b # v1",
  "bundler-cache: true",
  'xcode_version="$(xcodebuild -version)"',
  'minimum_xcode_version="26.5"',
  'version="${first_line#Xcode }"',
  "bundle exec ruby scripts/check-xcode-project-contract.rb",
  "bundle exec ruby scripts/check-xcode-generator-contract.rb"
].each do |token|
  fail_check("native workflow missing #{token}") unless workflow.include?(token)
end
fail_check("native workflow must not pipe xcodebuild -version into grep -q") if workflow.include?("xcodebuild -version | grep")
generic_mac_test = /xcodebuild\s+test[^\n]*-scheme\s+"Spoonjoy macOS"[^\n]*-destination\s+'generic\/platform=macOS'/
fail_check("native workflow must build, not test, the app-only macOS scheme at a generic destination") if workflow.match?(generic_mac_test)
generic_mac_build = /xcodebuild\s+build[^\n]*-scheme\s+"Spoonjoy macOS"[^\n]*-destination\s+'generic\/platform=macOS'/
fail_check("native workflow missing generic macOS app build") unless workflow.match?(generic_mac_build)
fail_check("local matrix must not pipe xcodebuild -version into grep -q") if matrix.include?("xcodebuild -version | grep")
fail_check("local matrix missing captured xcodebuild version check") unless matrix.include?('xcode_version="$(xcodebuild -version)"') &&
  matrix.include?('minimum_xcode_version="26.5"') &&
  matrix.include?('version="${first_line#Xcode }"')

local_matrix = LOCAL_MATRIX.read
[
  "scripts/bundle-check.sh",
  "scripts/bundle-exec.sh ruby scripts/check-xcode-project-contract.rb",
  "scripts/bundle-exec.sh ruby scripts/check-xcode-generator-contract.rb"
].each do |token|
  fail_check("local matrix missing #{token}") unless local_matrix.include?(token)
end

before_outputs = output_snapshot

run!("ruby", "-c", GENERATOR)

help = run!(*BUNDLE_EXEC, "ruby", GENERATOR, "--help")
[
  "--output-dir",
  "Spoonjoy.xcodeproj",
  "BootstrapDebug",
  "IPHONEOS_DEPLOYMENT_TARGET",
  "MACOSX_DEPLOYMENT_TARGET"
].each do |token|
  fail_check("--help output is missing #{token}") unless help.include?(token)
end

Dir.mktmpdir("spoonjoy-generator-contract") do |dir|
  one = Pathname.new(dir).join("one")
  two = Pathname.new(dir).join("two")
  run!(*BUNDLE_EXEC, "ruby", GENERATOR, "--output-dir", one)
  run!(*BUNDLE_EXEC, "ruby", GENERATOR, "--output-dir", two)

  fail_check("temp output one did not include Spoonjoy.xcodeproj") unless one.join("Spoonjoy.xcodeproj").directory?
  fail_check("temp output two did not include Spoonjoy.xcodeproj") unless two.join("Spoonjoy.xcodeproj").directory?

  project_text = one.join("Spoonjoy.xcodeproj/project.pbxproj")
  fail_check("temp output missing project.pbxproj") unless project_text.file?

  project_content = project_text.read
  fail_check("generated project missing AppIcon compiler setting") unless project_content.include?("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
  scheme_dir = one.join("Spoonjoy.xcodeproj/xcshareddata/xcschemes")
  scheme_files = scheme_dir.children.select { |path| path.extname == ".xcscheme" }.map(&:basename).map(&:to_s).sort
  expected_scheme_files = [
    "Spoonjoy iOS.xcscheme",
    "Spoonjoy macOS Window Diagnostics.xcscheme",
    "Spoonjoy macOS.xcscheme"
  ]
  fail_check("generated schemes were #{scheme_files.inspect}, expected #{expected_scheme_files.inspect}") unless scheme_files == expected_scheme_files

  {
    "Spoonjoy iOS.xcscheme" => { required: "Spoonjoy iOS", required_test: "SpoonjoyUITests", forbidden: "Spoonjoy macOS" },
    "Spoonjoy macOS.xcscheme" => {
      required: "Spoonjoy macOS",
      forbidden: "SpoonjoyMacWindowDiagnosticUITests",
      forbids_testable: true
    },
    "Spoonjoy macOS Window Diagnostics.xcscheme" => {
      required: "Spoonjoy macOS",
      required_test: "SpoonjoyMacWindowDiagnosticUITests",
      forbidden: "Spoonjoy iOS"
    }
  }.each do |scheme_name, targets|
    scheme_text = scheme_dir.join(scheme_name).read
    fail_check("#{scheme_name} missing #{targets.fetch(:required)}") unless scheme_text.include?(targets.fetch(:required))
    fail_check("#{scheme_name} must not include #{targets.fetch(:forbidden)}") if scheme_text.include?(targets.fetch(:forbidden))
    fail_check("#{scheme_name} missing Launch/Profile runnable") unless scheme_text.include?("<BuildableProductRunnable")
    if targets[:required_test]
      fail_check("#{scheme_name} missing #{targets.fetch(:required_test)}") unless scheme_text.include?(targets.fetch(:required_test))
      fail_check("#{scheme_name} missing TestableReference") unless scheme_text.include?("<TestableReference")
      fail_check("#{scheme_name} Test action must use BootstrapDebug") unless scheme_text.match?(%r{<TestAction\s+buildConfiguration = "BootstrapDebug"})
    end
    if targets[:forbids_testable]
      fail_check("#{scheme_name} generic app scheme must not include TestableReference") if scheme_text.include?("<TestableReference")
    end
  end

  fail_check("generated project missing SpoonjoyUITests target") unless project_content.include?("SpoonjoyUITests")
  fail_check("generated project missing UI test bundle identifier") unless project_content.include?("PRODUCT_BUNDLE_IDENTIFIER = app.spoonjoy.uitests;")
  fail_check("generated project missing observed UI test source") unless project_content.include?("NativeScreenshotEvidenceTests.swift")
  fail_check("generated project missing SpoonjoyMacWindowDiagnosticUITests target") unless project_content.include?("SpoonjoyMacWindowDiagnosticUITests")
  fail_check("generated project missing macOS window diagnostic bundle identifier") unless project_content.include?("PRODUCT_BUNDLE_IDENTIFIER = app.spoonjoy.mac.windowdiagnosticuitests;")
  fail_check("generated project missing macOS window diagnostic source") unless project_content.include?("NativeMacWindowDiagnosticTests.swift")
  fail_check("generated project must quiet irrelevant App Intents metadata warnings for the UI test bundle") unless project_content.include?("LM_FILTER_WARNINGS = YES;")
  fail_check("generated project must skip App Intents metadata extraction for the UI test bundle") unless project_content.include?("LM_SKIP_METADATA_EXTRACTION = YES;")

  {
	    "app.spoonjoy" => {
	      "Debug" => {
	        "IPHONEOS_DEPLOYMENT_TARGET" => "27.0",
	        "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "\"DEBUG SPOONJOY_SIGNED_APPLE_AUTH\""
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
	    "app.spoonjoy.mac" => {
	      "Debug" => {
	        "MACOSX_DEPLOYMENT_TARGET" => "27.0",
	        "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "\"DEBUG SPOONJOY_SIGNED_APPLE_AUTH\""
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
	  }.each do |bundle_id, configurations|
    configurations.each do |configuration, settings|
      block = find_build_settings_block(project_content, bundle_id, configuration)
      if configuration == "BootstrapDebug"
        assert_absent_setting(block, "CODE_SIGN_ENTITLEMENTS")
      else
        assert_setting(block, "CODE_SIGN_ENTITLEMENTS", "Apps/Spoonjoy/Shared/Spoonjoy.entitlements")
      end
      settings.each do |setting, expected|
        assert_setting(block, setting, expected)
      end
    end
  end

  diff_stdout, diff_stderr, diff_status = Open3.capture3("diff", "-ru", one.to_s, two.to_s)
  fail_check("generator output is not deterministic\nSTDOUT:\n#{diff_stdout}\nSTDERR:\n#{diff_stderr}") unless diff_status.success?
end

after_outputs = output_snapshot
changed_outputs = after_outputs.reject do |path, signature|
  before_outputs.key?(path) && before_outputs[path] == signature
end

unless changed_outputs.empty?
  fail_check("temp-output mode wrote or modified repo outputs: #{changed_outputs.keys.join(", ")}")
end

puts "xcode generator contract ok"
