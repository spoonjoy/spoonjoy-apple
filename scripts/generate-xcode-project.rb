#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "digest"
require "optparse"
require "pathname"
require "bundler/setup"
require "xcodeproj"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_NAME = "Spoonjoy"
IOS_SCHEME_NAME = "Spoonjoy iOS"
MAC_SCHEME_NAME = "Spoonjoy macOS"
UI_TEST_TARGET_NAME = "SpoonjoyShoppingUITests"
JOURNEYS_TARGET_NAME = "SpoonjoyJourneys"
IOS_BUNDLE_ID = "app.spoonjoy"
MAC_BUNDLE_ID = "app.spoonjoy.mac"
UI_TEST_BUNDLE_ID = "app.spoonjoy.shopping-uitests"
JOURNEYS_BUNDLE_ID = "app.spoonjoy.journeys"
WIDGET_TARGET_NAME = "SpoonjoyCookTimerWidget"
WIDGET_BUNDLE_ID = "app.spoonjoy.cook-timer-widget"
WIDGET_INFO_PLIST = "Apps/Spoonjoy/LiveActivity/Widget/Info.plist"
THEME_SOURCE = "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
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
UI_TEST_SWIFT = swift_sources_under("Apps/Spoonjoy/UITests").freeze
JOURNEYS_SWIFT = swift_sources_under("Apps/Spoonjoy/Journeys").freeze
# The Live Activity code the app and the widget extension both compile (attributes and button intents).
LIVE_ACTIVITY_SHARED_SWIFT = swift_sources_under("Apps/Spoonjoy/LiveActivity/Shared").freeze
LIVE_ACTIVITY_WIDGET_SWIFT = swift_sources_under("Apps/Spoonjoy/LiveActivity/Widget").freeze

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
    build_configuration.build_settings["CURRENT_PROJECT_VERSION"] = "32"
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
ui_test_target = project.new_target(:ui_test_bundle, UI_TEST_TARGET_NAME, :ios, "26.5")
journeys_target = project.new_target(:ui_test_bundle, JOURNEYS_TARGET_NAME, :ios, "26.5")
widget_target = project.new_target(:app_extension, WIDGET_TARGET_NAME, :ios, "26.5")
ios_target.frameworks_build_phase.files.clear
widget_target.frameworks_build_phase.files.clear
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

def apply_ui_test_settings(target, bundle_id:)
  CONFIGURATIONS.each do |configuration|
    build_configuration = target.build_configuration_list[configuration]
    build_configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    build_configuration.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
    build_configuration.build_settings["SWIFT_VERSION"] = "6.0"
    build_configuration.build_settings["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings["GCC_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
    build_configuration.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "26.5"
    build_configuration.build_settings["TEST_TARGET_NAME"] = "#{PROJECT_NAME} iOS"
    # UI-test bundles declare no App Intents. Skipping extraction avoids the extractor's
    # "no AppIntents.framework dependency found" warning, which the warnings-as-errors log gate rejects.
    build_configuration.build_settings["LM_SKIP_METADATA_EXTRACTION"] = "YES"
  end
end

# The widget extension draws the cook-timer Live Activity. It links no package product, takes no entitlements,
# and signs with the same automatic team signing as the app because its bundle ID sits under app.spoonjoy.
def apply_widget_settings(target)
  CONFIGURATIONS.each do |configuration|
    build_configuration = target.build_configuration_list[configuration]
    build_configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = WIDGET_BUNDLE_ID
    build_configuration.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
    build_configuration.build_settings["SWIFT_VERSION"] = "6.0"
    build_configuration.build_settings["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings["GCC_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    build_configuration.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = configuration == "Release" ? "" : "DEBUG"
    build_configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "NO"
    build_configuration.build_settings["INFOPLIST_FILE"] = WIDGET_INFO_PLIST
    build_configuration.build_settings["MARKETING_VERSION"] = "1.0"
    build_configuration.build_settings["CURRENT_PROJECT_VERSION"] = "32"
    build_configuration.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = configuration == "BootstrapDebug" ? "26.5" : "27.0"
    build_configuration.build_settings["SKIP_INSTALL"] = "YES"
    build_configuration.build_settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
    build_configuration.build_settings["TARGETED_DEVICE_FAMILY"] = "1,2"
    build_configuration.build_settings["SDKROOT"] = "iphoneos"
    build_configuration.build_settings["SUPPORTED_PLATFORMS"] = "iphoneos iphonesimulator"
    build_configuration.build_settings.delete("CODE_SIGN_ENTITLEMENTS")
  end
end

apply_widget_settings(widget_target)

apply_ui_test_settings(ui_test_target, bundle_id: UI_TEST_BUNDLE_ID)
apply_ui_test_settings(journeys_target, bundle_id: JOURNEYS_BUNDLE_ID)

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
add_sources(project, ios_target, SHARED_SWIFT + IOS_SWIFT + LIVE_ACTIVITY_SHARED_SWIFT)
add_sources(project, mac_target, SHARED_SWIFT + MAC_SWIFT)
add_resources(project, ios_target, [ASSET_CATALOG])
add_resources(project, mac_target, [ASSET_CATALOG])
add_package_product(project, ios_target, "SpoonjoyCore")
add_package_product(project, mac_target, "SpoonjoyCore")
file_reference(project, WIDGET_INFO_PLIST)
add_sources(project, widget_target, LIVE_ACTIVITY_SHARED_SWIFT + LIVE_ACTIVITY_WIDGET_SWIFT + [THEME_SOURCE])
add_sources(project, ui_test_target, UI_TEST_SWIFT)
ui_test_target.add_dependency(ios_target)
ui_test_dependency = ui_test_target.dependencies[0]
ui_test_dependency_proxy = ui_test_dependency.target_proxy
add_sources(project, journeys_target, JOURNEYS_SWIFT)
add_package_product(project, journeys_target, "SpoonjoyCore")
journeys_target.add_dependency(ios_target)
journeys_dependency = journeys_target.dependencies[0]
journeys_dependency_proxy = journeys_dependency.target_proxy

project.sort
project.predictabilize_uuids

# Wire the widget into the iOS app after the UUID pass above, so the extra edge does not reorder the walk.
ios_target.add_dependency(widget_target)
widget_dependency = ios_target.dependencies[0]
widget_dependency_proxy = widget_dependency.target_proxy
embed_extensions = ios_target.new_copy_files_build_phase("Embed Foundation Extensions")
embed_extensions.symbol_dst_subfolder_spec = :plug_ins
embedded_widget = embed_extensions.add_file_reference(widget_target.product_reference, true)
embedded_widget.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

def assign_stable_uuid(project, object, key)
  previous_uuid = object.uuid
  stable_uuid = Digest::MD5.hexdigest("Spoonjoy/#{key}").upcase
  project.objects_by_uuid.delete(previous_uuid)
  object.instance_variable_set(:@uuid, stable_uuid)
  project.objects_by_uuid[stable_uuid] = object
end

# xcodeproj's UUID walker cannot traverse the proxy UUID attributes created by
# PBXTargetDependency, so stabilize these two generated objects explicitly.
# Files compiled by more than one target make xcodeproj's UUID walker order-dependent, so pin those build files by target and path.
[ios_target, mac_target, widget_target].each do |target|
  target.source_build_phase.files.each do |build_file|
    path = build_file.file_ref&.hierarchy_path&.delete_prefix("/")
    next unless path && (path.start_with?("Apps/Spoonjoy/LiveActivity/") || path == THEME_SOURCE)

    assign_stable_uuid(project, build_file, "#{target.name}/sources/#{path}")
  end
end
assign_stable_uuid(project, embedded_widget, "Spoonjoy iOS/embed/#{WIDGET_TARGET_NAME}.appex")
assign_stable_uuid(project, embed_extensions, "Spoonjoy iOS/embed-phase")
assign_stable_uuid(project, widget_dependency_proxy, "SpoonjoyCookTimerWidget/app-proxy")
assign_stable_uuid(project, widget_dependency, "SpoonjoyCookTimerWidget/app-dependency")
widget_dependency.target_proxy = widget_dependency_proxy
widget_dependency_proxy.remote_global_id_string = widget_target.uuid
assign_stable_uuid(project, ui_test_dependency_proxy, "SpoonjoyShoppingUITests/app-proxy")
assign_stable_uuid(project, ui_test_dependency, "SpoonjoyShoppingUITests/app-dependency")
ui_test_dependency.target_proxy = ui_test_dependency_proxy
assign_stable_uuid(project, journeys_dependency_proxy, "SpoonjoyJourneys/app-proxy")
assign_stable_uuid(project, journeys_dependency, "SpoonjoyJourneys/app-dependency")
journeys_dependency.target_proxy = journeys_dependency_proxy

def save_app_scheme(project_path, scheme_name, target, test_targets: [])
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  test_targets.each { |test_target| scheme.add_test_target(test_target) }
  scheme.test_action.build_configuration = "BootstrapDebug" unless test_targets.empty?
  scheme.save_as(project_path, scheme_name, true)
end

save_app_scheme(project_path, IOS_SCHEME_NAME, ios_target, test_targets: [ui_test_target, journeys_target])
save_app_scheme(project_path, MAC_SCHEME_NAME, mac_target)

project.save

puts "Generated #{project_path.relative_path_from(ROOT)}"
