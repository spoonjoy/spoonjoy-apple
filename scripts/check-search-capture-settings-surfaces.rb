#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/Views/SearchView.swift",
  "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift",
  "Apps/Spoonjoy/Shared/Views/ProfileView.swift",
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift",
  "Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift",
  "Sources/SpoonjoyCore/Features/Search/SearchSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Search/SearchSurfaceViewModel.swift",
  "Sources/SpoonjoyCore/Features/Profiles/ProfileChefGraphSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Profiles/ProfileChefGraphSurfaceViewModel.swift",
  "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceViewModel.swift"
].freeze

REQUIRED_TOKENS = {
  "Apps/Spoonjoy/Shared/Views/SearchView.swift" => [
    "SearchView",
    "SearchState",
    "SearchScope",
    "SearchSurfaceViewModel",
    "SearchSurfaceSection",
    "SearchSurfaceRow",
    "List",
    "Section",
    "OfflineStatusView",
    "searchTask",
    "debounce",
    "searchable scopes",
    "typed rows",
    "KitchenTableTheme"
  ],
  "Sources/SpoonjoyCore/Features/Search/SearchSurfaceRepository.swift" => [
    "SearchSurfaceRepository",
    "LiveSearchSurfaceRepository",
    "SnapshotSearchSurfaceRepository",
    "FallbackSearchSurfaceRepository",
    "SearchSurfaceRequest",
    "SearchSurfacePage",
    "SearchSurfaceData",
    "SearchSurfaceResult",
    "SearchSurfaceResultType",
    "SearchSurfaceCacheSnapshot",
    "SearchSurfaceRecentQuery",
    "SearchSurfaceRepositoryError",
    "recentSearches",
    "SearchRequests.search",
    "NativeCacheDomain.searchResults",
    "SearchScope.shoppingList",
    "shopping_list:read"
  ],
  "Sources/SpoonjoyCore/Features/Search/SearchSurfaceViewModel.swift" => [
    "SearchSurfaceViewModel",
    "SearchSurfaceContext",
    "SearchSurfaceSection",
    "SearchSurfaceRow",
    "SearchSurfaceEmptyState",
    "SearchSurfaceErrorState",
    "SearchSurfaceDebouncePolicy",
    "SearchSurfaceDebounceDecision",
    "cancelsInFlightSearch",
    "OfflineIndicatorState",
    "SearchScope.allCases",
    "AppRoute.recipeDetail",
    "AppRoute.cookbookDetail",
    "AppRoute.profile",
    "AppRoute.shoppingList"
  ],
  "Apps/Spoonjoy/Shared/Views/CaptureDraftView.swift" => [
    "CaptureDraftView",
    "CaptureDraftViewModel",
    "CaptureImportViewModel",
    "CaptureDraft",
    "CaptureImportEntryPoint",
    "agentMCP",
    "appIntent",
    "Spoonjoy agent",
    "Shortcuts & Siri",
    "Import queue",
    "Siri",
    "Recipes sent by your Spoonjoy agent appear here for review.",
    "Use your Spoonjoy agent or Shortcuts to create a capture.",
    "onChange(of: inputDraft)",
    "reconcile(with: inputDraft)",
    "hasPendingImport",
    "ImportStatusPanel",
    "Submit import",
    "Delete capture",
    "plan.userFacingMessage",
    "canCreateServerRecipe",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/ProfileView.swift" => [
    "ProfileRouteView",
    "ProfileView",
    "ProfileGraphRouteView",
    "ProfileChefGraphSurfaceViewModel",
    "ProfileGraphViewModel",
    "ProfileHero",
    "ProfileRecipeShelf",
    "ProfileCookbookShelf",
    "RecentSpoonsSection",
    "FellowChefsSection",
    "KitchenVisitorsSection",
    "RecipeCoverImage(",
    "OfflineStatusView",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/SettingsView.swift" => [
    "SettingsView",
    "SettingsViewModel",
    "SettingsSurfaceViewModel",
    "SettingsActionPlanner",
    "SettingsState",
    "Profile",
    "Email",
    "Username",
    "Upload Photo",
    "Remove Photo",
    "Notifications",
    "Agent access",
    "Connections",
    "Passkeys",
    "Password",
    "Sign Out",
    "SettingsOnlineOnlyReason",
    "SettingsSecureHandoff",
    "PendingSettingsDestructiveAction",
    "confirmationDialog(",
    "confirmSettingsAction(",
    "onlineOnlyActionsDisabled(surface)",
    "cm_settings_remove_photo_",
    "settings.statusRows",
    "Form",
    "Section",
    "OfflineStatusView",
    "canReadShoppingList",
    "canWriteShoppingList",
    "KitchenTableTheme"
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
    "Label",
    "Button",
    "KitchenTableTheme"
  ],
  "Sources/SpoonjoyCore/Features/Profiles/ProfileChefGraphSurfaceRepository.swift" => [
    "ProfileChefGraphSurfaceRepository",
    "ProfileSurfaceRequest",
    "ProfileSurfaceResult",
    "ProfileGraphDirection",
    "ProfileGraphPage",
    "LiveProfileChefGraphSurfaceRepository",
    "SnapshotProfileChefGraphSurfaceRepository",
    "FallbackProfileChefGraphSurfaceRepository",
    "PublicProfileRequests.profile",
    "PublicProfileRequests.fellowChefs",
    "PublicProfileRequests.kitchenVisitors",
    "NativeCacheDomain.profile",
    "NativeCachePayload.profile"
  ],
  "Sources/SpoonjoyCore/Features/Profiles/ProfileChefGraphSurfaceViewModel.swift" => [
    "ProfileChefGraphSurfaceViewModel",
    "ProfileViewModel",
    "ProfileGraphViewModel",
    "ProfileSurfaceContext",
    "ProfileSurfaceOwnerActions",
    "ProfileSurfaceGraphLink",
    "ProfileSurfaceEmptyState",
    "ProfileSurfaceConflictBanner",
    "fellowChefsCount",
    "kitchenVisitorsCount",
    "recentSpoons",
    "NativeQueuedMutation.profileDisplayUpdate",
    "NativeQueuedMutation.profilePhotoUpload",
    "NativeQueuedMutation.profilePhotoRemove",
    "OfflineIndicatorState"
  ],
  "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceRepository.swift" => [
    "SettingsSurfaceRepository",
    "LiveSettingsSurfaceRepository",
    "SnapshotSettingsSurfaceRepository",
    "SettingsSurfaceData",
    "SettingsSurfaceCacheSnapshot",
    "SettingsAccountProfile",
    "SettingsNotificationPreferences",
    "SettingsAPITokenSummary",
    "SettingsOAuthConnectionSummary",
    "tokenPrefix",
    "updatedAt",
    "revokedAt",
    "PrivateAccountRequests.currentAccount",
    "PrivateAccountRequests.notificationPreferences",
    "TokenCredentialRequests.listTokens",
    "PrivateAccountRequests.connections",
    "NativeCacheDomain.settings",
    "NativeCacheDomain.notificationPreferences",
    "NativeCacheDomain.tokenMetadata",
    "NativeCacheDomain.connectionStatus",
    "NativeCachePayload.tokenMetadata",
    "NativeCachePayload.connectionStatus"
  ],
  "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceViewModel.swift" => [
    "SettingsSurfaceViewModel",
    "SettingsSurfaceSectionID",
    "SettingsProfileDraft",
    "SettingsProfilePhotoStagingPolicy",
    "SettingsActionPlanner",
    "SettingsActionPlan",
    "SettingsOnlineOnlyReason",
    "SettingsSecureHandoff",
    "SettingsSurfaceConflictBanner",
    "NativeQueuedMutation.profileDisplayUpdate",
    "NativeQueuedMutation.profilePhotoUpload",
    "NativeQueuedMutation.profilePhotoRemove",
    "NativeQueuedMutation.notificationPreferenceUpdate",
    "NativeOfflineMutationPolicy.decision",
    "TokenCredentialRequests.createToken",
    "TokenCredentialRequests.revokeToken",
    "PrivateAccountRequests.disconnectConnection",
    "SecureAuthWebHandoff.logout"
  ]
}.freeze

PLATFORM_NAVIGATION_TOKENS = [
  "queueCaptureImportRetryIfNeeded",
  "recipeImportSource == draftImportSource",
  "pendingCaptureImportMutation?.clientMutationID != mutation.clientMutationID",
  "recordCaptureImportBlocker",
  "executeCaptureImportRequest",
  "ProfileRouteView(",
  "ProfileGraphRouteView(",
  "LiveProfileChefGraphSurfaceRepository",
  "FallbackProfileChefGraphSurfaceRepository",
  "profileGraphRepository",
  "openProfileRoute",
  "contentState.settingsSurfaceViewModel",
  "performSettingsAction",
  "queueSettingsMutationIfNeeded",
  "executeSettingsActionRequest",
  "performSettingsSessionOperation"
].freeze

FORBIDDEN_TOKENS = [
  "WKWebView",
  "className",
  "tailwind",
  "CardView",
  "LazyVGrid",
  "Grid {",
  'Text("Search is next.")',
  'Text("Local draft capture is next.")',
  'Text("Offline, auth, and environment state.")',
  "draftDidChange: { _ in }",
  "Promotion requires a separate reviewed flow",
  ".constant(routeSearch)",
  "FollowButton",
  "Followers",
  "Following",
  "DirectMessage",
  "MessageComposer",
  "MailCompose",
  "RecipeComments",
  "SocialFeed",
  "ActivityFeed",
  "capture/import scope",
  "social-feed scope",
  "comments scope",
  "tokenHash",
  "rawToken",
  "tokenSecret",
	  "accessTokenSecret",
	  "refreshTokenSecret",
	  "accessTokenValue",
	  "refreshTokenValue",
	  "Ouro Draft"
	].freeze

FORBIDDEN_BY_FILE = {}.freeze

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
fail_check("missing search/capture/settings/profile surface files: #{missing_files.join(", ")}") unless missing_files.empty?

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = uncommented_swift(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required search/capture/settings tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

navigation_content = uncommented_swift(ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read)
missing_navigation_tokens = PLATFORM_NAVIGATION_TOKENS.reject { |token| navigation_content.include?(token) }
fail_check("PlatformNavigationView missing capture import retry/blocker tokens: #{missing_navigation_tokens.join(", ")}") unless missing_navigation_tokens.empty?

forbidden_hits = REQUIRED_FILES.flat_map do |relative_path|
  content = uncommented_swift(ROOT.join(relative_path).read)
  tokens = FORBIDDEN_TOKENS + FORBIDDEN_BY_FILE.fetch(relative_path, [])
  tokens.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden search/capture/settings surface tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

platform_navigation = uncommented_swift(ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read)
["SearchView(", "CaptureDraftView(", "ProfileRouteView(", "ProfileGraphRouteView(", "SettingsView("].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless platform_navigation.include?(token)
end
fail_check("PlatformNavigationView.swift must not freeze route search with .constant(routeSearch)") if platform_navigation.include?(".constant(routeSearch)")
fail_check("PlatformNavigationView.swift must not discard provider-blocked imports") if platform_navigation.include?("pendingCaptureImportMutation?.clientMutationID == clientMutationID")
[
  "defaultSettings",
  "PlatformNavigationView.defaultSettings",
  "signedOutProductionSettingsTemplate"
].each do |token|
  fail_check("PlatformNavigationView.swift must not contain #{token}") if platform_navigation.include?(token)
end
[
  ".searchable(text: searchText",
  ".searchScopes(searchScope)",
  "@FocusState private var isSearchFieldFocused",
  ".searchFocused($isSearchFieldFocused)",
  "isSearchFieldFocused = true",
  "search: $search",
  "contentState.searchSurfaceViewModel",
  "performSearch(",
  "search.apply(route: routeSearch.route)",
  "openRoute: openRoute",
  "AppRoute.profile",
  "AppRoute.profileGraph",
  "ProfileRouteView(",
  "ProfileGraphRouteView(",
  "ProfileChefGraphSurfaceViewModel",
  "recordCaptureDraft",
  "discardCaptureDraft",
  "recordCaptureImportRetry",
  "recordCaptureImportBlocker",
  "executeCaptureImportRequest",
  "performCaptureImport(draft:",
  "SettingsView(",
  "contentState.settingsViewModel"
].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless platform_navigation.include?(token)
end

live_store = uncommented_swift(ROOT.join("Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift").read)
[
  "searchSurfaceViewModel",
  "SearchSurfaceViewModel",
  "SearchSurfaceCacheSnapshot",
  "restoreSearchSurfaceSnapshot",
  "performSearch(",
  "public var settingsViewModel: SettingsViewModel",
  "profileGraphRepository",
  "profileSurfaceViewModel",
  "SettingsState(",
  "offline: offlineState"
].each do |token|
  fail_check("NativeLiveAppStore.swift missing #{token}") unless live_store.include?(token)
end

scenario_verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift").read
[
  "finalReport",
  "search",
  "capture import submission",
  "settings state",
  "offline status",
  "profile detail",
  "profile graph",
  "fellow chefs",
  "kitchen visitors",
  "settings token connection surface",
  "settings profile update",
  "settings token create online-only",
  "settings connection disconnect online-only",
  "settings secure handoff",
  "search surface view model",
  "SearchSurfaceViewModel",
  "shopping-list search auth",
  "cached search results",
  "SearchSurfaceRequest",
  "safe unknown link",
  "SearchView.swift",
  "CaptureDraftView.swift",
  "ProfileView.swift",
  "SettingsView.swift",
  "OfflineStatusView.swift"
].each do |token|
  fail_check("ScenarioVerifier.swift missing #{token}") unless scenario_verifier.include?(token)
end

verifier_script = ROOT.join("scripts/verify-native-scenarios.sh").read
fail_check("verify-native-scenarios.sh must not allow pending final checks") unless verifier_script.include?("else") && verifier_script.include?("[]")

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "search capture settings surfaces contract ok"
