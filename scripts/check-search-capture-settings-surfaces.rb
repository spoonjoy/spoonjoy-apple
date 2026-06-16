#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/Views/SearchView.swift",
  "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift"
].freeze

REQUIRED_TOKENS = {
  "Apps/Spoonjoy/Shared/Views/SearchView.swift" => [
    "SearchView",
    "SearchState",
    "SearchScope",
    "List",
    "Section",
    "searchable scopes",
    "typed rows",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift" => [
    "CaptureDraftView",
    "CaptureDraftViewModel",
    "CaptureDraft",
    "TextEditor",
    "CaptureDraft.localText",
    "local draft",
    "canCreateServerRecipe",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift" => [
    "SettingsView",
    "SettingsViewModel",
    "SettingsState",
    "Form",
    "Section",
    "OfflineStatusView",
    "canReadShoppingList",
    "canWriteShoppingList",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift" => [
    "OfflineStatusView",
    "OfflineState",
    "statusLabel",
    "Label",
    "KitchenTableTheme"
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "WKWebView",
  "className",
  "tailwind",
  "CardView",
  "LazyVGrid",
  "Grid {",
  'Text("Search is next.")',
  'Text("Local draft capture is next.")',
  'Text("Offline, auth, and environment state.")'
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def uncommented_swift(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
end

missing_files = REQUIRED_FILES.reject { |path| ROOT.join(path).file? }
fail_check("missing search/capture/settings surface files: #{missing_files.join(", ")}") unless missing_files.empty?

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = uncommented_swift(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required search/capture/settings tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

forbidden_hits = REQUIRED_FILES.flat_map do |relative_path|
  content = uncommented_swift(ROOT.join(relative_path).read)
  FORBIDDEN_TOKENS.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden search/capture/settings surface tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

platform_navigation = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read
["SearchView(", "CaptureDraftView(", "SettingsView("].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless platform_navigation.include?(token)
end

scenario_verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift").read
[
  "finalReport",
  "search",
  "capture draft creation",
  "settings state",
  "offline status",
  "safe unknown link",
  "SearchView.swift",
  "CaptureDraftView.swift",
  "SettingsView.swift",
  "OfflineStatusView.swift"
].each do |token|
  fail_check("ScenarioVerifier.swift missing #{token}") unless scenario_verifier.include?(token)
end

verifier_script = ROOT.join("scripts/verify-native-scenarios.sh").read
fail_check("verify-native-scenarios.sh must not allow pending final checks") unless verifier_script.include?("else") && verifier_script.include?("[]")

stdout, stderr, status = Open3.capture3("ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "search capture settings surfaces contract ok"
