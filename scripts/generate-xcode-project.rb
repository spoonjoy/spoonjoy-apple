#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"
require "bundler/setup"
require "xcodeproj"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_NAME = "Spoonjoy"
IOS_SCHEME_NAME = "Spoonjoy iOS"
MAC_SCHEME_NAME = "Spoonjoy macOS"
IOS_BUNDLE_ID = "app.spoonjoy"
MAC_BUNDLE_ID = "app.spoonjoy.mac"
CONFIGURATIONS = ["Debug", "Release", "BootstrapDebug"].freeze
INFO_PLIST = "Apps/Spoonjoy/Shared/Info.plist"
ENTITLEMENTS = "Apps/Spoonjoy/Shared/Spoonjoy.entitlements"
ASSET_CATALOG = "Apps/Spoonjoy/Shared/Assets.xcassets"

def swift_sources_under(relative_dir)
  root = ROOT.join(relative_dir)
  return [] unless root.directory?

  root.find
    .select { |path| path.file? && path.extname == ".swift" }
    .map { |path| path.relative_path_from(ROOT).to_s }
    .sort
end

SHARED_SWIFT = swift_sources_under("Apps/Spoonjoy/Shared").freeze
IOS_SWIFT = swift_sources_under("Apps/Spoonjoy/iOS").freeze
MAC_SWIFT = swift_sources_under("Apps/Spoonjoy/macOS").freeze

options = {
  output_dir: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/generate-xcode-project.rb [--output-dir PATH]"
  opts.on("--output-dir PATH", "Write deterministic Spoonjoy.xcodeproj output under PATH instead of the repo root.") do |value|
    options[:output_dir] = value
  end
  opts.on("--help", "Show this help for Spoonjoy.xcodeproj, BootstrapDebug, IPHONEOS_DEPLOYMENT_TARGET, and MACOSX_DEPLOYMENT_TARGET.") do
    puts opts
    exit 0
  end
end

parser.parse!

output_root = options[:output_dir] ? Pathname.new(options[:output_dir]).expand_path : ROOT
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
    swift_conditions = configuration == "Release" ? [] : ["DEBUG"]
    swift_conditions << "SPOONJOY_SIGNED_APPLE_AUTH" unless configuration == "BootstrapDebug"
    build_configuration.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = swift_conditions.join(" ")
    build_configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
    build_configuration.build_settings["INFOPLIST_FILE"] = INFO_PLIST
    if configuration == "BootstrapDebug"
      build_configuration.build_settings.delete("CODE_SIGN_ENTITLEMENTS")
    else
      build_configuration.build_settings["CODE_SIGN_ENTITLEMENTS"] = ENTITLEMENTS
    end
    build_configuration.build_settings["MARKETING_VERSION"] = "1.0"
    build_configuration.build_settings["CURRENT_PROJECT_VERSION"] = "31"
    build_configuration.build_settings[deployment_key] = deployment_targets.fetch(configuration)
    build_configuration.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    build_configuration.build_settings.delete("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")
  end
end

def group_for_path(project, path)
  current = project.main_group

  Pathname.new(path).each_filename do |component|
    current = current.groups.find { |group| group.display_name == component } ||
      current.new_group(component, component)
  end

  current
end

def file_reference(project, relative_path)
  group = group_for_path(project, File.dirname(relative_path))
  group.files.find { |file| file.display_name == File.basename(relative_path) } ||
    group.new_file(File.basename(relative_path))
end

def add_package_product(project, target, product_name)
  package = project.root_object.package_references.find do |reference|
    reference.isa == "XCLocalSwiftPackageReference" && reference.relative_path == "."
  end

  unless package
    package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    package.relative_path = "."
    project.root_object.package_references << package
  end

  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product_name
  dependency.package = package
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

def add_sources(project, target, paths)
  file_references = paths.map { |path| file_reference(project, path) }
  target.add_file_references(file_references)
end

def add_resources(project, target, paths)
  file_references = paths.map { |path| file_reference(project, path) }
  target.add_resources(file_references)
end

ios_target = project.new_target(:application, "#{PROJECT_NAME} iOS", :ios, "26.5")
mac_target = project.new_target(:application, "#{PROJECT_NAME} macOS", :osx, "26.2")
ios_target.frameworks_build_phase.files.clear
mac_target.frameworks_build_phase.files.clear
project.files
  .select { |file| ["Foundation.framework", "Cocoa.framework"].include?(file.display_name) }
  .each(&:remove_from_project)

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

[INFO_PLIST, ENTITLEMENTS].each { |path| file_reference(project, path) }
add_sources(project, ios_target, SHARED_SWIFT + IOS_SWIFT)
add_sources(project, mac_target, SHARED_SWIFT + MAC_SWIFT)
add_resources(project, ios_target, [ASSET_CATALOG])
add_resources(project, mac_target, [ASSET_CATALOG])
add_package_product(project, ios_target, "SpoonjoyCore")
add_package_product(project, mac_target, "SpoonjoyCore")

project.sort
project.predictabilize_uuids

def save_app_scheme(project_path, scheme_name, target)
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(project_path, scheme_name, true)
end

save_app_scheme(project_path, IOS_SCHEME_NAME, ios_target)
save_app_scheme(project_path, MAC_SCHEME_NAME, mac_target)

project.save

puts "Generated #{project_path.relative_path_from(ROOT)}"
