#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
GENERATOR = ROOT.join("scripts/generate-xcode-project.rb")
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

def build_settings_blocks(project_content)
  project_content.scan(/buildSettings = \{(?<settings>.*?)\};/m).map(&:first)
end

def find_build_settings_block(project_content, bundle_id, configuration)
  matches = build_settings_blocks(project_content).select do |settings|
    settings.include?("PRODUCT_BUNDLE_IDENTIFIER = #{bundle_id};") &&
      settings.include?("SPOONJOY_CONFIGURATION_NAME = #{configuration};")
  end

  fail_check("missing build settings for #{bundle_id} #{configuration}") if matches.empty?
  fail_check("multiple build settings for #{bundle_id} #{configuration}") if matches.length > 1

  matches.first
end

fail_check("#{GENERATOR.relative_path_from(ROOT)} is missing") unless GENERATOR.file?

before_outputs = output_snapshot

run!("ruby", "-c", GENERATOR)

help = run!("ruby", GENERATOR, "--help")
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
  run!("ruby", GENERATOR, "--output-dir", one)
  run!("ruby", GENERATOR, "--output-dir", two)

  fail_check("temp output one did not include Spoonjoy.xcodeproj") unless one.join("Spoonjoy.xcodeproj").directory?
  fail_check("temp output two did not include Spoonjoy.xcodeproj") unless two.join("Spoonjoy.xcodeproj").directory?

  project_text = one.join("Spoonjoy.xcodeproj/project.pbxproj")
  fail_check("temp output missing project.pbxproj") unless project_text.file?

  project_content = project_text.read
  {
    "app.spoonjoy.Spoonjoy" => {
      "Debug" => { "IPHONEOS_DEPLOYMENT_TARGET" => "27.0" },
      "Release" => { "IPHONEOS_DEPLOYMENT_TARGET" => "27.0" },
      "BootstrapDebug" => { "IPHONEOS_DEPLOYMENT_TARGET" => "26.5" }
    },
    "app.spoonjoy.Spoonjoy.mac" => {
      "Debug" => { "MACOSX_DEPLOYMENT_TARGET" => "27.0" },
      "Release" => { "MACOSX_DEPLOYMENT_TARGET" => "27.0" },
      "BootstrapDebug" => { "MACOSX_DEPLOYMENT_TARGET" => "26.2" }
    }
  }.each do |bundle_id, configurations|
    configurations.each do |configuration, settings|
      block = find_build_settings_block(project_content, bundle_id, configuration)
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
