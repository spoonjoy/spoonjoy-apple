#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
APP_ROOT = ROOT.join("Apps/Spoonjoy")
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
  "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift",
  "Apps/Spoonjoy/Shared/AppShell/ShareActions.swift"
].freeze

REQUIRED_SOURCE_TOKENS = {
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift" => [
    "AppNavigationState",
    "NativeAppSnapshot",
    "NativeAppStateStore",
    "DeepLinkRouter",
    "SignedOutSetupView",
    "hasCompletedFirstRun",
    "completeFirstRun",
    "persistSnapshot",
    ".onOpenURL",
    "onContinueUserActivity(NSUserActivityTypeBrowsingWeb)",
    "NSUserActivity",
    ".webpageURL",
    "PlatformNavigationView"
  ],
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift" => [
    "NavigationSplitView",
    "NavigationStack",
    "AppSection",
    ".searchable",
    "SearchState",
    "SearchScope",
    "NativeAppSnapshot",
    "persistSnapshot",
    "updatingCookProgress",
    "updatingShoppingList",
    "updatingCaptureDraft",
    "QueuedMutation",
    "AppRoute",
    ".spoonjoyToolbar",
    "#if os(macOS)",
    "#if os(iOS)"
  ],
  "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift" => [
    "spoonjoy.app",
    "offline",
    "Button",
    "Link"
  ],
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift" => [
    ".toolbar",
    "ToolbarItem",
    "Menu",
    "Button",
    "EditMode",
    "ShareActions"
  ],
  "Apps/Spoonjoy/Shared/AppShell/ShareActions.swift" => [
    "ShareLink",
    "AppRoute",
    "spoonjoy.app",
    "URLComponents"
  ]
}.freeze

ROOT_PLACEHOLDERS = [
  'Text("Native shell ready")',
  'Section("Kitchen")',
  'Label("Spoonjoy", systemImage: "fork.knife")'
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def relative(path)
  Pathname.new(path).expand_path.relative_path_from(ROOT).to_s
end

def uncommented_swift(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
end

missing_files = REQUIRED_FILES.reject { |path| ROOT.join(path).file? }
fail_check("missing native shell files: #{missing_files.join(", ")}") unless missing_files.empty?

root_source = ROOT.join("Apps/Spoonjoy/Shared/SpoonjoyApp.swift")
fail_check("#{relative(root_source)} is missing") unless root_source.file?
root_content = uncommented_swift(root_source.read)
placeholder_hits = ROOT_PLACEHOLDERS.select { |placeholder| root_content.include?(placeholder) }
fail_check("#{relative(root_source)} still contains placeholder shell tokens: #{placeholder_hits.join(", ")}") unless placeholder_hits.empty?

REQUIRED_SOURCE_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  content = uncommented_swift(path.read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required native shell tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

app_shell_sources = REQUIRED_FILES.map { |path| ROOT.join(path) }
unexpected_web_tokens = app_shell_sources.flat_map do |path|
  content = uncommented_swift(path.read)
  ["WKWebView", "className", "tailwind", ".onHover"].select { |token| content.include?(token) }.map do |token|
    "#{relative(path)} contains #{token}"
  end
end
fail_check("web-shell tokens are not allowed: #{unexpected_web_tokens.join(", ")}") unless unexpected_web_tokens.empty?

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "native shell contract ok"
