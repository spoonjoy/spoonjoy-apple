#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
APP_ROOT = ROOT.join("Apps/Spoonjoy")
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
  "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift",
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
  "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyToolbar.swift",
  "Apps/Spoonjoy/Shared/AppShell/ShareActions.swift",
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift"
].freeze

REQUIRED_SOURCE_TOKENS = {
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift" => [
    "NativeLiveAppStore",
    "NativeLiveAppStoreDependencies",
    "NativeAppBootstrapState",
    "NativeShellContentState",
    "signedOut",
    "restoringCache",
    "liveSynced",
    "offlineStale",
    "queuedWork",
    "conflict",
    "blocker",
    "destructiveConfirmation",
    "syncFailed",
    "NativeAuthSessionRepository",
    "NativeDurableCacheStore",
    "NativeSyncEngine",
    "NativeSyncTriggerCoordinator",
    "APIClientConfiguration",
    "SearchScope.allCases",
    "searchSurfaceViewModel",
    "searchSurfacePage(for:",
    "switchEnvironment",
    "NativeSyncTriggerEvent.environmentChanged",
    "offlineIndicatorState",
    "settingsViewModel"
  ],
  "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift" => [
    "NativeFixtureFallbackPolicy",
    "disabledInProduction",
    "testsAndDemoOnly",
    "allowsProductionFallback",
    "SPOONJOY_ALLOW_FIXTURE_FALLBACK",
    "isTestOrDemoBuild"
  ],
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift" => [
    "AppNavigationState",
    "NativeLiveAppStore",
    "NativeLiveAppStoreDependencies",
    "DeepLinkRouter",
    "SignedOutSetupView",
    "liveStore",
    "bootstrap()",
    "bootstrapState",
    "signedOut",
    "restoringCache",
    "liveSynced",
    "offlineStale",
    "queuedWork",
    "conflict",
    "blocker",
    "destructiveConfirmation",
    "syncFailed",
    "contentState:",
    "offlineIndicatorState:",
    "dismissOfflineIndicator",
    "recordingOpenedRoute(route",
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
    "NativeShellContentState",
    "contentState.recipes",
    "contentState.cookbooks",
    "contentState.kitchen",
    "contentState.shoppingList",
    "contentState.searchSurfaceViewModel",
    "contentState.captureDraft",
    "NativeQueuedMutation",
    "queueMutation",
    "syncTriggerCoordinator",
    "OfflineStatusView(display:",
    "offlineIndicatorState",
    "dismissOfflineIndicator",
    "SettingsView(",
    "settingsViewModel",
    "AppRoute",
    ".spoonjoyToolbar",
    "#if os(macOS)",
    "#if os(iOS)"
  ],
  "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift" => [
    "NativeAuthSessionRepository",
    "SignInWithAppleButton",
    "NativeAppleSignInCredential",
    "NativePasswordSignInCredential",
    "handleAppleSignInCredential",
    "handlePasswordSignInCredential",
    "restoreState",
    "revokeAndLogout",
    "isSigningIn",
    "emailOrUsername",
    "native password sign-in",
    "Button"
  ],
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift" => [
    "SettingsView",
    "SettingsViewModel",
    "OfflineStatusView(display:",
    "viewModel.offlineIndicatorDisplay",
    "viewModel.dismissOfflineIndicator",
    "viewModel.authSessionState",
    "viewModel.environmentSwitcher"
  ],
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift" => [
    "OfflineStatusView",
    "OfflineIndicatorDisplay",
    "informationalOnly",
    "queuedWork",
    "syncFailure",
    "conflict",
    "blocker",
    "destructiveConfirmation",
    "onDismiss"
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
    "NativeSharePayload.publicRoute(route)?.publicURL"
  ]
}.freeze

FORBIDDEN_SOURCE_TOKENS = {
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift" => [
    "RecipeFixtureCatalog.decodeFromBundle()",
    "CookbookFixtureCatalog.decodeFromBundle()",
    "KitchenFixtureState.decodeFromBundle()",
    "ShoppingListState.decodeFromBundle()"
  ],
  "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift" => [
    "RecipeFixtureCatalog.decodeFromBundle()"
  ],
  "Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift" => [
    "NativeAppSnapshot.bootstrap",
    "ShoppingListState.decodeFromBundle()",
    "hasCompletedFirstRun",
    "completeFirstRun(opening:",
    "openKitchen: { completeFirstRun"
  ],
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift" => [
    "RecipeFixtureCatalog.decodeFromBundle()",
    "CookbookFixtureCatalog.decodeFromBundle()",
    "KitchenFixtureState.decodeFromBundle()",
    "KitchenFixtureState.bootstrapFallback",
    "SettingsState(\n                auth: .signedOut",
    "startedAt: \"2026-06-16T11:45:00.000Z\""
  ],
  "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift" => [
    "Open Kitchen",
    "keep offline fixtures nearby"
  ],
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift" => [
    "OfflineStatusView(state:",
    "settings.offline"
  ],
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift" => [
    "legacyStatusLabel"
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

FORBIDDEN_SOURCE_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = uncommented_swift(path.read)
  present_tokens = tokens.select { |token| content.include?(token) }
  fail_check("#{relative_path} contains forbidden fixture-first shell tokens: #{present_tokens.join(", ")}") unless present_tokens.empty?
end

app_shell_sources = REQUIRED_FILES.map { |path| ROOT.join(path) }
unexpected_web_tokens = app_shell_sources.flat_map do |path|
  content = uncommented_swift(path.read)
  ["WKWebView", "className", "tailwind", ".onHover"].select { |token| content.include?(token) }.map do |token|
    "#{relative(path)} contains #{token}"
  end
end
fail_check("web-shell tokens are not allowed: #{unexpected_web_tokens.join(", ")}") unless unexpected_web_tokens.empty?

fixture_usage_allowed = [
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
  "Sources/SpoonjoyCore/AppState/NativeFixtureFallbackPolicy.swift"
].freeze
fixture_tokens = [
  "RecipeFixtureCatalog.decodeFromBundle()",
  "CookbookFixtureCatalog.decodeFromBundle()",
  "KitchenFixtureState.decodeFromBundle()",
  "ShoppingListState.decodeFromBundle()"
].freeze
fixture_violations = [ROOT.join("Apps/Spoonjoy"), ROOT.join("Sources/SpoonjoyCore")].flat_map do |scan_root|
  Dir.glob(scan_root.join("**/*.swift")).flat_map do |path_string|
    path = Pathname.new(path_string)
    relative_path = relative(path)
    next [] if fixture_usage_allowed.include?(relative_path)

    content = uncommented_swift(path.read)
    fixture_tokens.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
  end
end
fail_check("fixture fallback disabled outside tests/demo/policy: #{fixture_violations.join(", ")}") unless fixture_violations.empty?

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "native shell contract ok"
