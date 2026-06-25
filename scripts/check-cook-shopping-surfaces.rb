#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
  "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
  "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift",
  "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift"
].freeze

REQUIRED_TOKENS = {
  "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift" => [
    "KitchenSafeControls",
    "Button",
    "controlSize",
    "accessibilityLabel",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift" => [
    "ReceiptListView",
    "ShoppingListReceiptSection",
    "ShoppingListItem",
    "List",
    "Section",
    "Toggle",
    ".toggleStyle(.largeCheck)",
    "LargeCheckToggleStyle",
    "ToggleStyle",
    "minimumCheckTarget",
    "checkmark.circle.fill",
    "configuration.isOn.toggle()",
    "swipeActions",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift" => [
    "CookModeView",
    "CookModeViewModel",
    "CookModeProgress",
    "KitchenSafeControls",
    "currentStep",
    "ProgressView",
    "Persisted progress",
    "accessibilityLabel",
    "accessibilityValue",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift" => [
    "ShoppingListView",
    "ShoppingListViewModel",
    "ShoppingListState",
    "ReceiptListView",
    "EditMode",
    "settingChecked",
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
  'Text("Receipt rows are next.")',
  'Text("Cook Mode")'
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
fail_check("missing cook/shopping surface files: #{missing_files.join(", ")}") unless missing_files.empty?

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = uncommented_swift(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required cook/shopping tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

forbidden_hits = REQUIRED_FILES.flat_map do |relative_path|
  content = uncommented_swift(ROOT.join(relative_path).read)
  FORBIDDEN_TOKENS.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden cook/shopping surface tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

platform_navigation = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read
unless platform_navigation.include?("CookModeView(") || platform_navigation.include?("CookModeRouteView(")
  fail_check("PlatformNavigationView.swift missing cook mode route/view")
end
fail_check("PlatformNavigationView.swift missing ShoppingListView(") unless platform_navigation.include?("ShoppingListView(")

scenario_verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift").read
[
  "cook progress persistence",
  "shopping checkoff",
  "CookModeView.swift",
  "ShoppingListView.swift",
  "ReceiptListView.swift",
  "KitchenSafeControls.swift"
].each do |token|
  fail_check("ScenarioVerifier.swift missing #{token}") unless scenario_verifier.include?(token)
end

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "cook and shopping surfaces contract ok"
