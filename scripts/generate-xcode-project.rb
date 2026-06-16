#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"
require "xcodeproj"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_NAME = "Spoonjoy"
SCHEME_NAME = "Spoonjoy"
IOS_BUNDLE_ID = "app.spoonjoy.Spoonjoy"
MAC_BUNDLE_ID = "app.spoonjoy.Spoonjoy.mac"
CONFIGURATIONS = ["Debug", "Release", "BootstrapDebug"].freeze

options = {
  output_dir: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/generate-xcode-project.rb --output-dir PATH"
  opts.on("--output-dir PATH", "Write deterministic Spoonjoy.xcodeproj output under PATH instead of the repo root.") do |value|
    options[:output_dir] = value
  end
  opts.on("--help", "Show this help for Spoonjoy.xcodeproj, BootstrapDebug, IPHONEOS_DEPLOYMENT_TARGET, and MACOSX_DEPLOYMENT_TARGET.") do
    puts opts
    exit 0
  end
end

parser.parse!

unless options[:output_dir]
  warn "FAIL: --output-dir is required until Unit 12 writes the real repo project"
  exit 1
end

output_root = Pathname.new(options[:output_dir]).expand_path
FileUtils.mkdir_p(output_root)

project_path = output_root.join("#{PROJECT_NAME}.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path.to_s)
project.build_configuration_list.build_configurations.each(&:remove_from_project)
CONFIGURATIONS.each { |name| project.add_build_configuration(name, name == "Release" ? :release : :debug) }

def apply_common_settings(target, bundle_id:, product_name:, deployment_key:, deployment_targets:)
  CONFIGURATIONS.each do |configuration|
    build_configuration = target.build_configuration_list[configuration]
    build_configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    build_configuration.build_settings["PRODUCT_NAME"] = product_name
    build_configuration.build_settings["SWIFT_VERSION"] = "6.0"
    build_configuration.build_settings["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings["GCC_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings[deployment_key] = deployment_targets.fetch(configuration)
  end
end

ios_target = project.new_target(:application, "#{PROJECT_NAME} iOS", :ios, "26.5")
mac_target = project.new_target(:application, "#{PROJECT_NAME} macOS", :osx, "26.2")

apply_common_settings(
  ios_target,
  bundle_id: IOS_BUNDLE_ID,
  product_name: PROJECT_NAME,
  deployment_key: "IPHONEOS_DEPLOYMENT_TARGET",
  deployment_targets: {
    "Debug" => "27.0",
    "Release" => "27.0",
    "BootstrapDebug" => "26.5"
  }
)

apply_common_settings(
  mac_target,
  bundle_id: MAC_BUNDLE_ID,
  product_name: PROJECT_NAME,
  deployment_key: "MACOSX_DEPLOYMENT_TARGET",
  deployment_targets: {
    "Debug" => "27.0",
    "Release" => "27.0",
    "BootstrapDebug" => "26.2"
  }
)

shared_group = project.main_group.new_group("Apps")
shared_group.new_group("Spoonjoy")

project.sort
project.predictabilize_uuids

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(ios_target)
scheme.add_build_target(mac_target)
scheme.set_launch_target(ios_target)
scheme.save_as(project_path, SCHEME_NAME, true)

project.save

puts "Generated #{project_path.relative_path_from(ROOT)}"
