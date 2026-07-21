#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"
require "pathname"

SCREENSHOT_ARTIFACTS = {
  "iosMobile" => "screenshots/ios-mobile.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility.png",
  "iosTablet" => "screenshots/ios-tablet.png",
  "macosDesktop" => "screenshots/macos-desktop.png"
}.freeze
DEEP_SCROLL_SCREENSHOT_ARTIFACTS = {
  "iosMobile" => "screenshots/ios-mobile-deep-scroll.png",
  "iosAccessibility" => "screenshots/ios-mobile-accessibility-deep-scroll.png",
  "iosTablet" => "screenshots/ios-tablet-deep-scroll.png"
}.freeze
COMPACT_DEEP_SCROLL_ROUTES = %w[
  kitchen recipe-detail recipe-editor recipe-covers profile shopping-list cookbooks cookbook-detail
].freeze

VALID_ROUTES = [
  "kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers",
  "cook-log", "cook-mode", "shopping-list", "chefs", "profile", "profile-graph", "search",
  "cookbooks", "cookbook-detail", "capture", "settings", "unknown-link"
].freeze
REQUIRED_OBSERVED_IDENTIFIERS = {
  "recipe-editor" => ["recipe-editor.title", "recipe-editor.save"],
  "recipe-covers" => [
    "recipe-covers.photo-picker", "recipe-covers.staged-photo-status", "recipe-covers.clear-photo",
    "recipe-covers.save-photo", "recipe-covers.generate-placeholder", "recipe-covers.archive.cover_primary"
  ],
  "profile" => ["profile.header"],
  "profile-graph" => ["profile-graph.row.chef_jules"],
  "unknown-link" => ["unknown-link.message"],
  "cook-mode" => ["cook.current-step", "cook.done", "cook.tools"],
  "cook-log" => ["cook-log.note", "cook-log.next-time", "cook-log.photo", "cook-log.submit"]
}.freeze
REQUIRED_DEEP_SCROLL_TERMINALS = {
  "recipe-editor" => "recipe-editor.delete",
  "recipe-covers" => "recipe-covers.archive.cover_primary",
  "profile" => "profile.graph.kitchen-visitors"
}.freeze
EXPECTED_SEARCH_SCOPES = ["all", "recipes", "cookbooks", "chefs", "shopping-list"].freeze
EXPECTED_CAPTURE_VARIANTS = ["empty", "draft", "offline-retry", "provider-blocked", "signed-out"].freeze
EXPECTED_SHOPPING_VARIANTS = ["normal", "empty", "all-complete", "duplicate", "conflict", "offline-queued"].freeze
EXPECTED_ROUTE_SURFACE_ANCHORS = {
  "cook-log" => ["cookLogForm", "cookLogPhotoSlot", "cookLogActionBar"],
  "recipe-covers" => ["stagedPhotoActions", "coverMutationActions"],
  "cookbooks" => ["cookbookShelfStrip", "cookbookLibrarySpread"],
  "cookbook-detail" => ["cookbookContentsIndex", "cookbookOwnerToolsDisclosure"]
}.freeze
EXPECTED_OFFLINE_VISIBLE_STATES = [
  "offline",
  "stale",
  "queuedWork",
  "syncFailure",
  "conflict",
  "blocker",
  "destructiveConfirmation"
].freeze
EXPECTED_OFFLINE_DISMISSIBLE_STATES = ["offline", "stale"].freeze
EXPECTED_OFFLINE_SEVERE_STATES = [
  "queuedWork",
  "syncFailure",
  "conflict",
  "blocker",
  "destructiveConfirmation"
].freeze
EXPECTED_ROUTE_EVIDENCE = {
  "kitchen" => {
    "voiceOverLabels" => ["On the Counter", "Start Cooking", "Recipe index", "RecipeIndexRow ordinal", "Cookbook shelf"],
    "keyboardNavigationTargets" => ["lead recipe actions", "RecipeIndexRow buttons", "cookbook shelf buttons"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "media-aware contrast on real covers"],
    "hierarchyAnchors" => ["KitchenView", "KitchenMasthead", "RecipeLead", "RecipeIndexRow", "CookbookShelf"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "ordinal"]
  },
  "search" => {
    "voiceOverLabels" => ["Search", "row.accessibilityLabel"],
    "keyboardNavigationTargets" => ["native search field", "typed rows", "SearchSurfaceSectionView buttons"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "herb tint on bone"],
    "hierarchyAnchors" => ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters"]
  },
  "recipes" => {
    "voiceOverLabels" => ["Recipes", "On the Counter", "Recipe index", "Loading recipes"],
    "keyboardNavigationTargets" => ["recipe lead button", "RecipeIndexRow buttons", "search field"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone"],
    "hierarchyAnchors" => ["RecipesView", "KitchenTableHeader", "RecipeCatalogLead", "RecipeIndexRow"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "saved-recipes" => {
    "voiceOverLabels" => ["Saved Recipes", "Recipe index", "Loading saved recipes"],
    "keyboardNavigationTargets" => ["saved recipe lead button", "RecipeIndexRow buttons", "search field"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone"],
    "hierarchyAnchors" => ["SavedRecipesView", "RecipesView", "KitchenTableHeader", "RecipeCatalogLead", "RecipeIndexRow"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "cookbooks" => {
    "voiceOverLabels" => ["Cookbooks", "Shelf", "Index", "New Cookbook"],
    "keyboardNavigationTargets" => ["cookbook shelf buttons", "cookbook index rows", "share buttons", "new cookbook action"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone"],
    "hierarchyAnchors" => ["CookbooksView", "KitchenTableHeader", "CookbookCoverArt", "CookbookShelf", "KitchenTableObjectRow"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "cookbook-detail" => {
    "voiceOverLabels" => ["Weeknights", "Contents", "Share Cookbook", "Owner tools", "Lemon Pantry Pasta", "Tomato Toast"],
    "keyboardNavigationTargets" => ["cookbook primary actions", "CookbookRecipeIndexRow buttons", "share menu", "CookbookOwnerToolsDisclosure"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone", "secondary text on bone"],
    "hierarchyAnchors" => ["CookbookDetailView", "KitchenTableHeader", "CookbookCoverArt", "CookbookDetailHero", "CookbookRecipeIndexRow", "CookbookOwnerToolsDisclosure"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "capture" => {
    "voiceOverLabels" => ["Imports", "Import", "Import actions", "Delete import", "Hide offline status"],
    "keyboardNavigationTargets" => ["saved import primary action", "import actions menu", "offline status dismiss"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone", "destructive action role", "status label on bone"],
    "hierarchyAnchors" => ["CaptureDraftView", "KitchenTableHeader", "ImportStatusPanel", "CaptureDraft", "OfflineStatusView"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area", "offline-status-section"]
  },
  "capture-signed-out" => {
    "voiceOverLabels" => ["Spoonjoy", "Sign in", "Opening Capture after sign-in", "native Apple sign-in", "native password sign-in"],
    "keyboardNavigationTargets" => ["native sign-in email or username", "native sign-in password", "native Apple sign-in", "Settings"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".headline"],
    "contrastPairs" => ["charcoal on bone", "herb button on bone", "brass status on bone"],
    "hierarchyAnchors" => ["SignedOutSetupView", "SpoonjoyIdentityMark", "pendingRouteLabel", "SignInWithAppleButton"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters"]
  },
  "settings" => {
    "voiceOverLabels" => ["Settings", "Profile", "Security", "This Device", "Push Delivery", "Notification Sync", "Turn On for This Device", "Open System Settings", "Session", "Sign In"],
    "keyboardNavigationTargets" => ["profile form fields", "security token controls", "APNs device controls", "notification sync status", "session handoff controls"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass label on bone"],
    "hierarchyAnchors" => ["SettingsView", "KitchenTableHeader", "KitchenTableSection", "SettingsPanel", "NotificationAPNsSettingsView"],
    "layoutGuards" => ["kitchen-table-page", "text-fit", "no-tiny-clusters"]
  },
  "recipe-detail" => {
    "voiceOverLabels" => ["Cook mode", "Save", "Yield", "Clear progress", "Add to list", "More", "Steps", "Ingredients", "Cooks"],
    "keyboardNavigationTargets" => ["recipe primary actions", "recipe secondary menu", "recipe yield controls", "step ingredient rows"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "media-aware contrast on real covers", "secondary text on bone"],
    "hierarchyAnchors" => ["RecipeDetailView", "recipeHeaderControls", "RecipeScaleSelector", "KitchenTableActionButtonStyle", "stepsSection", "RecipeStepChecklistRow", "SpoonCookLogView"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "cook-log" => {
    "voiceOverLabels" => ["Cooks", "What changed?", "Next time", "Add cook photo", "Log cook"],
    "keyboardNavigationTargets" => ["cookLogForm fields", "cookLogPhotoSlot", "cookLogActionBar"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel", ".title2"],
    "contrastPairs" => ["charcoal on bone", "brass on bone", "muted text on bone"],
    "hierarchyAnchors" => ["SpoonCookLogView", "cookLogForm", "cookLogPhotoSlot", "cookLogActionBar"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "cook-mode" => {
    "voiceOverLabels" => ["Mark the current step done", "Return to recipe detail", "Current cooking step", "Ingredients", "Cook tools"],
    "keyboardNavigationTargets" => ["cook step handrail", "ingredient toggles", "dependency toggles", "cook tools"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "herb tint on bone", "status text on material"],
    "hierarchyAnchors" => ["CookModeView", "currentStepCard", "cookModeUtilitySheet", "cookModeBottomActionRail", "SpoonDockContext.cookMode", "ScaleSelector"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  },
  "shopping-list" => {
    "voiceOverLabels" => ["Shopping", "Kitchen", "Receipt actions", "Add item", "Add from recipe", "Clear checked"],
    "keyboardNavigationTargets" => ["shopping receipt composer", "receipt actions menu", "native tab bar"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass label on bone", "destructive action role"],
    "hierarchyAnchors" => ["ShoppingListView", "shoppingHeaderTools", "shoppingReceiptComposer", "shoppingReceiptState", "TabView"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "tab-bar-safe-area"]
  },
  "chefs" => {
    "voiceOverLabels" => ["Chefs", "Fellow chefs", "Kitchen visitors"],
    "keyboardNavigationTargets" => ["chef profile rows", "native More menu", "regular sidebar"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone"],
    "hierarchyAnchors" => ["ChefsView", "ProfileSurfaceViewModel", "ProfileGraphPage"],
    "layoutGuards" => ["text-fit", "no-tiny-clusters", "dock-safe-area"]
  }
}.freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def validate_screenshot_artifacts!(manifest_path, manifest)
  artifacts = manifest["screenshotArtifacts"]
  fail_check("#{manifest_path} screenshotArtifacts must be an object") unless artifacts.is_a?(Hash)
  fail_check("#{manifest_path} screenshotArtifacts keys must exactly match the release set") unless artifacts.keys.sort == SCREENSHOT_ARTIFACTS.keys.sort

  artifact_root = manifest_path.dirname.expand_path
  SCREENSHOT_ARTIFACTS.each do |name, expected_relative_path|
    artifact = artifacts[name]
    fail_check("#{manifest_path} screenshot artifact #{name} must be an object") unless artifact.is_a?(Hash)
    fail_check("#{manifest_path} screenshot artifact #{name} path mismatch") unless artifact["path"] == expected_relative_path
    fail_check("#{manifest_path} screenshot artifact #{name} path must be relative") if expected_relative_path.start_with?("/")
    absolute_path = artifact_root.join(expected_relative_path).cleanpath.expand_path
    unless absolute_path.to_s.start_with?(artifact_root.to_s + File::SEPARATOR)
      fail_check("#{manifest_path} screenshot artifact #{name} escapes the artifact root")
    end
    fail_check("#{manifest_path} screenshot artifact #{name} is missing") unless absolute_path.file?
    bytes = absolute_path.size
    fail_check("#{manifest_path} screenshot artifact #{name} must be non-empty") unless bytes.positive?
    fail_check("#{manifest_path} screenshot artifact #{name} byte count mismatch") unless artifact["bytes"] == bytes
    digest = Digest::SHA256.file(absolute_path).hexdigest
    fail_check("#{manifest_path} screenshot artifact #{name} SHA-256 mismatch") unless artifact["sha256"] == digest
  end

  deep_scroll_artifacts = manifest["deepScrollScreenshotArtifacts"]
  if COMPACT_DEEP_SCROLL_ROUTES.include?(manifest["screenshotRoute"])
    unless deep_scroll_artifacts.is_a?(Hash) && deep_scroll_artifacts.keys.sort == DEEP_SCROLL_SCREENSHOT_ARTIFACTS.keys.sort
      fail_check("#{manifest_path} deepScrollScreenshotArtifacts keys must exactly match the compact deep-scroll release set")
    end
    DEEP_SCROLL_SCREENSHOT_ARTIFACTS.each do |name, expected_relative_path|
      artifact = deep_scroll_artifacts[name]
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} must be an object") unless artifact.is_a?(Hash)
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} path mismatch") unless artifact["path"] == expected_relative_path
      absolute_path = artifact_root.join(expected_relative_path).cleanpath.expand_path
      unless absolute_path.to_s.start_with?(artifact_root.to_s + File::SEPARATOR)
        fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} escapes the artifact root")
      end
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} is missing") unless absolute_path.file?
      bytes = absolute_path.size
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} must be non-empty") unless bytes.positive?
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} byte count mismatch") unless artifact["bytes"] == bytes
      digest = Digest::SHA256.file(absolute_path).hexdigest
      fail_check("#{manifest_path} deep-scroll screenshot artifact #{name} SHA-256 mismatch") unless artifact["sha256"] == digest
    end
  elsif !deep_scroll_artifacts.nil?
    fail_check("#{manifest_path} non-scrolling route must not claim deepScrollScreenshotArtifacts")
  end
end

def validate_settings_proof!(manifest_path, proof_relative_path, visual_focus)
  fail_check("#{manifest_path} settingsSurfaceProofArtifacts entries must be relative paths") if proof_relative_path.start_with?("/")
  proof_path = manifest_path.dirname.join(proof_relative_path).cleanpath
  fail_check("#{manifest_path} missing settings screenshot proof artifact #{proof_relative_path}") unless proof_path.file?
  proof = JSON.parse(proof_path.read)
  fail_check("#{proof_path} must contain a JSON object") unless proof.is_a?(Hash)
  fail_check("#{proof_path} route must be settings") unless proof["route"] == "settings"
  fail_check("#{proof_path} visualFocus must be #{visual_focus}") unless proof["visualFocus"] == visual_focus
  fail_check("#{proof_path} source must be SettingsView") unless proof["source"] == "SettingsView"
  sections = proof["visibleSections"]
  fail_check("#{proof_path} visibleSections must be an array") unless sections.is_a?(Array)
  required_sections = if visual_focus == "notifications"
                        ["This Device", "Push Delivery", "Notification Sync", "Agent Access"]
                      elsif visual_focus == "signed-out"
                        ["Session", "Environment", "Offline"]
                      else
                        ["Profile", "Security"]
                      end
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{proof_path} visibleSections missing required #{visual_focus} sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
end

def expected_search_proof(variant)
  case variant
  when "blank"
    {
      "query" => "",
      "scope" => "all",
      "routeIdentifier" => "search:all:",
      "requiredSections" => ["Recipes", "Chefs"]
    }
  when "typed-results"
    {
      "query" => "lemon",
      "scope" => "all",
      "routeIdentifier" => "search:all:lemon",
      "requiredSections" => ["Recipes"]
    }
  when "scoped-recipes"
    {
      "query" => "lemon",
      "scope" => "recipes",
      "routeIdentifier" => "search:recipes:lemon",
      "requiredSections" => ["Recipes"]
    }
  when "scoped-cookbooks"
    {
      "query" => "weeknights",
      "scope" => "cookbooks",
      "routeIdentifier" => "search:cookbooks:weeknights",
      "requiredSections" => ["Cookbooks"],
      "expectedRows" => [
        {"type" => "cookbook", "id" => "cookbook-cookbook_weeknights", "title" => "Weeknights"}
      ]
    }
  when "scoped-chefs"
    {
      "query" => "ari",
      "scope" => "chefs",
      "routeIdentifier" => "search:chefs:ari",
      "requiredSections" => ["Chefs"]
    }
  when "scoped-shopping"
    {
      "query" => "lemons",
      "scope" => "shopping-list",
      "routeIdentifier" => "search:shopping-list:lemons",
      "requiredSections" => ["Shopping"]
    }
  when "no-results"
    {
      "query" => "kumquat",
      "scope" => "all",
      "routeIdentifier" => "search:all:kumquat",
      "requiredSections" => [],
      "requiresEmptySections" => true,
      "expectedRows" => [],
      "expectedEmptyState" => {
        "scope" => "all",
        "title" => "No matches for \"kumquat\"",
        "message" => "No Spoonjoy results match \"kumquat\"."
      }
    }
  else
    fail_check("unsupported searchSurfaceVariant #{variant.inspect}")
  end
end

def validate_search_proof!(manifest_path, proof_relative_path, seed_account_id, expected)
  fail_check("#{manifest_path} searchSurfaceProofArtifacts entries must be relative paths") if proof_relative_path.start_with?("/")
  proof_path = manifest_path.dirname.join(proof_relative_path).cleanpath
  fail_check("#{manifest_path} missing search screenshot proof artifact #{proof_relative_path}") unless proof_path.file?
  proof = JSON.parse(proof_path.read)
  fail_check("#{proof_path} must contain a JSON object") unless proof.is_a?(Hash)
  fail_check("#{proof_path} route must be search") unless proof["route"] == "search"
  fail_check("#{proof_path} routeIdentifier must be #{expected["routeIdentifier"]}") unless proof["routeIdentifier"] == expected["routeIdentifier"]
  fail_check("#{proof_path} query must be #{expected["query"].inspect}") unless proof["query"] == expected["query"]
  fail_check("#{proof_path} scope must be #{expected["scope"]}") unless proof["scope"] == expected["scope"]
  fail_check("#{proof_path} searchScopes must exactly match #{EXPECTED_SEARCH_SCOPES.join(", ")}") unless proof["searchScopes"] == EXPECTED_SEARCH_SCOPES
  fail_check("#{proof_path} accountID must be #{seed_account_id}") unless proof["accountID"] == seed_account_id
  fail_check("#{proof_path} source must be SearchView") unless proof["source"] == "SearchView"
  fingerprint = proof["renderFingerprint"]
  fail_check("#{proof_path} renderFingerprint must be an object") unless fingerprint.is_a?(Hash)
  rows = fingerprint["rows"]
  fail_check("#{proof_path} renderFingerprint rows must be an array") unless rows.is_a?(Array)
  rows.each do |row|
    fail_check("#{proof_path} renderFingerprint rows must contain exact type/id/title fields") unless row.is_a?(Hash) && row.keys.sort == ["id", "title", "type"]
  end
  data_source = fingerprint["dataSource"]
  fail_check("#{proof_path} renderFingerprint dataSource must contain exactly one source") unless data_source.is_a?(Hash) && data_source.length == 1
  if expected.key?("expectedRows")
    fail_check("#{proof_path} renderFingerprint rows do not match the exact expected render") unless rows == expected["expectedRows"]
  end
  if expected.key?("expectedEmptyState")
    fail_check("#{proof_path} renderFingerprint emptyState does not match the exact expected render") unless fingerprint["emptyState"] == expected["expectedEmptyState"]
  end
  sections = proof["visibleSections"]
  fail_check("#{proof_path} visibleSections must be an array") unless sections.is_a?(Array)
  required_sections = expected["requiredSections"]
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{proof_path} visibleSections missing required search sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
  if expected["requiresEmptySections"] && !sections.empty?
    fail_check("#{proof_path} no-results search proof must not include visible result sections: #{sections.join(", ")}")
  end
  fingerprint
end

def expected_accessibility_source(route, manifest)
  case route
  when "kitchen"
    "KitchenView"
  when "search"
    "SearchView"
  when "recipes"
    "RecipesView"
  when "saved-recipes"
    "SavedRecipesView"
  when "cookbooks"
    "CookbooksView"
  when "cookbook-detail"
    "CookbookDetailView"
  when "capture"
    manifest["captureSurfaceVariant"] == "signed-out" ? "SignedOutSetupView" : "CaptureDraftView"
  when "settings"
    "SettingsView"
  when "recipe-detail"
    "RecipeDetailView"
  when "recipe-editor"
    "RecipeEditorView"
  when "recipe-covers"
    "RecipeCoverControlsView"
  when "cook-log"
    "SpoonCookLogView"
  when "cook-mode"
    "CookModeView"
  when "shopping-list"
    "ShoppingListView"
  when "chefs"
    "ChefsView"
  when "profile"
    "ProfileView"
  when "profile-graph"
    "ProfileGraphList"
  when "unknown-link"
    "ShellPlaceholderView"
  else
    fail_check("unsupported accessibility route #{route}")
  end
end

def accessibility_evidence_key(route, manifest)
  route == "capture" && manifest["captureSurfaceVariant"] == "signed-out" ? "capture-signed-out" : route
end

def validate_accessibility_proof!(manifest_path, proof_relative_path, route, manifest)
  fail_check("#{manifest_path} accessibilityProofArtifacts entries must be relative paths") if proof_relative_path.start_with?("/")
  proof_path = manifest_path.dirname.join(proof_relative_path).cleanpath
  fail_check("#{manifest_path} missing accessibility proof artifact #{proof_relative_path}") unless proof_path.file?
  proof = JSON.parse(proof_path.read)
  fail_check("#{proof_path} must contain a JSON object") unless proof.is_a?(Hash)
  fail_check("#{proof_path} platform must be ios, ipad, or macos") unless ["ios", "ipad", "macos"].include?(proof["platform"])
  expected_bundle_identifier = proof["platform"] == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy"
  fail_check("#{proof_path} route must be #{route}") unless proof["route"] == route
  expected_source = expected_accessibility_source(route, manifest)
  fail_check("#{proof_path} source must be #{expected_source}") unless proof["source"] == expected_source
  expected_surface_variant = case route
                             when "capture" then manifest["captureSurfaceVariant"]
                             when "shopping-list" then manifest["shoppingListVariant"]
                             end
  if expected_surface_variant
    fail_check("#{proof_path} observedSurfaceVariant must be #{expected_surface_variant}") unless proof["observedSurfaceVariant"] == expected_surface_variant
  end
  if route == "recipe-covers"
    launch_proof = proof["launchEnvironmentProof"]
    fail_check("#{proof_path} must bind the Photo Studio action-state fixture") unless launch_proof.is_a?(Hash) &&
      launch_proof["screenshotRecipeCoversFixture"] == "action-states"
  end
  if route == "shopping-list" && expected_surface_variant == "offline-queued"
    surface_state = proof["observedSurfaceState"]
    fail_check("#{proof_path} observedSurfaceState must describe queued shopping state") unless surface_state.is_a?(Hash)
    fail_check("#{proof_path} queued shopping status owner must be ShoppingListView") unless surface_state["statusOwner"] == "ShoppingListView"
    fail_check("#{proof_path} queued shopping connectivity must be offline") unless surface_state["connectivity"] == "offline"
    fail_check("#{proof_path} queued shopping indicator must be queuedWork") unless surface_state["visibleIndicator"] == "queuedWork"
    queued_count = surface_state["queuedMutationCount"]
    fail_check("#{proof_path} queued shopping mutation count must be positive") unless queued_count.is_a?(Integer) && queued_count.positive?

    launch_proof = proof["launchEnvironmentProof"]
    fail_check("#{proof_path} offline queued state must launch cache-only") unless launch_proof.is_a?(Hash) && launch_proof["screenshotRestoreCacheOnly"] == "1"
    snapshot_proof = proof["screenshotStateSnapshotProof"]
    fail_check("#{proof_path} offline queued state must prove a readable shopping queue") unless snapshot_proof.is_a?(Hash) &&
      snapshot_proof["syncSnapshotQueuedShoppingWorkPresent"] == true &&
      snapshot_proof["syncSnapshotQueueCount"] == queued_count
  end
  fail_check("#{proof_path} emittedBy must be SpoonjoyApp") unless proof["emittedBy"] == "SpoonjoyApp"
  fail_check("#{proof_path} bundleIdentifier must be #{expected_bundle_identifier}") unless proof["bundleIdentifier"] == expected_bundle_identifier
  legacy_fields = [
    "dynamicType", "voiceOverLabels", "keyboardNavigation", "reduceMotion", "contrast",
    "kitchenTableHierarchy", "noOverlap", "minimumTargetSize", "textFits", "noTinyClusters",
    "routeEvidence", "offlineIndicatorProof"
  ].select { |field| proof.key?(field) }
  fail_check("#{proof_path} contains legacy self-attested fields: #{legacy_fields.join(", ")}") unless legacy_fields.empty?

  fail_check("#{proof_path} observedDynamicTypeSize must be a non-empty string") unless proof["observedDynamicTypeSize"].is_a?(String) && !proof["observedDynamicTypeSize"].empty?
  fail_check("#{proof_path} observedReduceMotion must be boolean") unless [true, false].include?(proof["observedReduceMotion"])

  state_proof = proof["screenshotStateSnapshotProof"]
  fail_check("#{proof_path} screenshotStateSnapshotProof must be an object") unless state_proof.is_a?(Hash)
  fail_check("#{proof_path} screenshot state directory must resolve") unless state_proof["stateDirectoryResolved"] == true
  fail_check("#{proof_path} app snapshot must be present and readable") unless state_proof["appSnapshotPresent"] == true && state_proof["appSnapshotJSONReadable"] == true
  fail_check("#{proof_path} sync snapshot must be present and readable") unless state_proof["syncSnapshotPresent"] == true && state_proof["syncSnapshotJSONReadable"] == true

  visual_readiness = proof["visualReadiness"]
  fail_check("#{proof_path} visualReadiness must be an object") unless visual_readiness.is_a?(Hash)
  fail_check("#{proof_path} pendingMediaCount must be zero") unless visual_readiness["pendingMediaCount"] == 0
  fail_check("#{proof_path} failedMediaCount must be zero") unless visual_readiness["failedMediaCount"] == 0
  fail_check("#{proof_path} blockingIndicatorCount must be zero") unless visual_readiness["blockingIndicatorCount"] == 0
  fail_check("#{proof_path} visualReadiness must be settled") unless visual_readiness["isSettled"] == true
end

def validate_observed_accessibility_evidence!(manifest_path, proof_relative_path, route, manifest)
  fail_check("#{manifest_path} observedAccessibilityEvidenceArtifacts entries must be relative paths") if proof_relative_path.start_with?("/")
  proof_path = manifest_path.dirname.join(proof_relative_path).cleanpath
  fail_check("#{manifest_path} missing observed accessibility evidence #{proof_relative_path}") unless proof_path.file?
  proof = JSON.parse(proof_path.read)
  fail_check("#{proof_path} must contain a JSON object") unless proof.is_a?(Hash)
  platform = proof["platform"]
  fail_check("#{proof_path} platform must be ios, ipad, or macos") unless ["ios", "ipad", "macos"].include?(platform)
  fail_check("#{proof_path} route must be #{route}") unless proof["route"] == route
  elements = proof["elements"]
  fail_check("#{proof_path} elements must be a non-empty observed accessibility array") unless elements.is_a?(Array) && !elements.empty?
  required_element_fields = platform == "macos" ? ["identifier", "role", "title", "frame", "enabled", "focused"] : ["identifier", "label", "type", "frame", "exists", "hittable"]
  elements.each do |element|
    fail_check("#{proof_path} observed element must be an object") unless element.is_a?(Hash)
    missing = required_element_fields.reject { |field| element.key?(field) }
    fail_check("#{proof_path} observed element missing #{missing.join(", ")}") unless missing.empty?
  end
  identifiers = elements.map { |element| element["identifier"] }
  missing_identifiers = REQUIRED_OBSERVED_IDENTIFIERS.fetch(route, []) - identifiers
  fail_check("#{proof_path} missing route controls: #{missing_identifiers.join(", ")}") unless missing_identifiers.empty?

  findings = platform == "macos" ? proof["findings"] : proof["geometryFindings"]
  fail_check("#{proof_path} observed geometry findings must be an empty array") unless findings == []
  if platform != "macos"
    fail_check("#{proof_path} accessibility audit issues must be empty") unless proof["auditIssues"] == []
    content_size_category = proof["observedContentSizeCategory"]
    fail_check("#{proof_path} observedContentSizeCategory must be present") unless content_size_category.is_a?(String) && !content_size_category.empty?
    observed_dynamic_type = proof["observedDynamicTypeSize"]
    expected_dynamic_type = {
      "large" => "large",
      "accessibility-extra-extra-extra-large" => "accessibility5"
    }[content_size_category]
    fail_check("#{proof_path} observedContentSizeCategory is unsupported") if expected_dynamic_type.nil?
    fail_check("#{proof_path} requested and observed Dynamic Type do not match") unless observed_dynamic_type == expected_dynamic_type
    fail_check("#{proof_path} accessibility audit tool limitations are not release evidence") unless proof.fetch("toolLimitations", []) == []
  end

  compact_deep_scroll_route = COMPACT_DEEP_SCROLL_ROUTES.include?(route)
  deep_scroll_required = platform == "macos" ? REQUIRED_DEEP_SCROLL_TERMINALS.key?(route) : compact_deep_scroll_route
  if deep_scroll_required
    deep_scroll = proof["deepScroll"]
    fail_check("#{proof_path} missing deep-scroll evidence") unless deep_scroll.is_a?(Hash)
    fail_check("#{proof_path} deep-scroll route mismatch") unless deep_scroll["route"] == route
    fail_check("#{proof_path} deep scroll did not reach terminal content") unless deep_scroll["reachedTerminal"] == true
    fail_check("#{proof_path} deep-scroll findings must be empty") unless deep_scroll["findings"] == []
    fail_check("#{proof_path} deep scroll missing content viewport") unless deep_scroll["contentViewport"].is_a?(Hash)
    fail_check("#{proof_path} deep scroll missing terminal element") unless deep_scroll["terminalElement"].is_a?(Hash)
    expected_terminal = REQUIRED_DEEP_SCROLL_TERMINALS[route]
    if expected_terminal
      fail_check("#{proof_path} deep scroll did not prove #{expected_terminal}") unless deep_scroll.dig("terminalElement", "identifier") == expected_terminal
    end
    if platform == "macos"
      fail_check("#{proof_path} macOS deep scroll missing route-specific scroll identifier") unless deep_scroll["scrollAreaIdentifier"].is_a?(String) && !deep_scroll["scrollAreaIdentifier"].empty?
      fail_check("#{proof_path} macOS deep scroll missing initial value") unless deep_scroll["initialScrollValue"].is_a?(Numeric)
      fail_check("#{proof_path} macOS deep scroll missing final value") unless deep_scroll["finalScrollValue"].is_a?(Numeric)
      fail_check("#{proof_path} macOS deep scroll moved backwards") if deep_scroll["finalScrollValue"] < deep_scroll["initialScrollValue"]
    else
      fail_check("#{proof_path} compact deep-scroll accessibility audit issues must be empty") unless deep_scroll["auditIssues"] == []
      fail_check("#{proof_path} compact deep-scroll tool limitations are not release evidence") unless deep_scroll.fetch("toolLimitations", []) == []
    end
    if platform == "ios"
      fail_check("#{proof_path} compact deep scroll missing tab bar frame") unless deep_scroll["tabBarFrame"].is_a?(Hash)
    end
  end

  if route == "settings" && manifest["settingsVisualFocus"] == "notifications"
    identifiers = elements.map { |element| element["identifier"] }
    required = ["settings.apns.this-device.heading", "settings.apns.push-delivery.heading", "settings.apns.notification-sync.heading"]
    missing = required - identifiers
    fail_check("#{proof_path} missing observed APNs headings: #{missing.join(", ")}") unless missing.empty?
  end

  platform
end

path = Pathname.new(ARGV.fetch(0) { fail_check("usage: validate-design-review.rb <design-review.json>") })
fail_check("missing #{path}") unless path.file?

manifest = JSON.parse(path.read)
fail_check("#{path} must contain a JSON object") unless manifest.is_a?(Hash)

legacy_self_attestations = %w[
  mobileScreenshot desktopScreenshot dynamicType voiceOverLabels keyboardNavigation
  reduceMotion contrast kitchenTableHierarchy noOverlap
].select { |field| manifest.key?(field) }
fail_check("#{path} contains legacy self-attested fields: #{legacy_self_attestations.join(", ")}") unless legacy_self_attestations.empty?

blockers = manifest.fetch("blockers", [])
fail_check("#{path} blockers must be an array") unless blockers.is_a?(Array)
fail_check("#{path} blockers must be empty; runtime blockers belong in design-review-blocked.json") unless blockers.empty?

validate_screenshot_artifacts!(path, manifest)

route = manifest["screenshotRoute"]
fail_check("#{path} missing screenshotRoute") if route.nil?
fail_check("#{path} screenshotRoute has invalid type") unless route.is_a?(String)
fail_check("#{path} screenshotRoute must be one of #{VALID_ROUTES.join(", ")}") unless VALID_ROUTES.include?(route)

accessibility_proofs = manifest["accessibilityProofArtifacts"]
fail_check("#{path} accessibilityProofArtifacts must be an array") unless accessibility_proofs.is_a?(Array)
fail_check("#{path} accessibilityProofArtifacts must include iPhone, iPad, and macOS proof artifacts") unless accessibility_proofs.length == 3
platforms = []
accessibility_proofs.each do |proof_relative_path|
  fail_check("#{path} accessibilityProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
  validate_accessibility_proof!(path, proof_relative_path, route, manifest)
  proof_path = path.dirname.join(proof_relative_path).cleanpath
  platforms << JSON.parse(proof_path.read)["platform"]
end
fail_check("#{path} accessibilityProofArtifacts must include ios, ipad, and macos platforms") unless platforms.sort == ["ios", "ipad", "macos"]

observed_accessibility_proofs = manifest["observedAccessibilityEvidenceArtifacts"]
fail_check("#{path} observedAccessibilityEvidenceArtifacts must be an array") unless observed_accessibility_proofs.is_a?(Array)
fail_check("#{path} observedAccessibilityEvidenceArtifacts must include standard and accessibility iPhone, iPad, and macOS evidence") unless observed_accessibility_proofs.length == 4
observed_content_sizes = []
observed_platforms = observed_accessibility_proofs.map do |proof_relative_path|
  fail_check("#{path} observedAccessibilityEvidenceArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
  platform = validate_observed_accessibility_evidence!(path, proof_relative_path, route, manifest)
  proof_path = path.dirname.join(proof_relative_path).cleanpath
  observed_content_sizes << JSON.parse(proof_path.read)["observedContentSizeCategory"] if platform == "ios"
  platform
end
fail_check("#{path} observedAccessibilityEvidenceArtifacts must include two ios, one ipad, and one macos platform") unless observed_platforms.sort == ["ios", "ios", "ipad", "macos"]
fail_check("#{path} iPhone evidence must include large and accessibility-extra-extra-extra-large content sizes") unless observed_content_sizes.sort == ["accessibility-extra-extra-extra-large", "large"]

accessibility_screenshot = manifest["accessibilityContentSizeScreenshot"]
fail_check("#{path} accessibilityContentSizeScreenshot must be a relative path") unless accessibility_screenshot.is_a?(String) && !accessibility_screenshot.empty? && !accessibility_screenshot.start_with?("/")
fail_check("#{path} missing accessibility content-size screenshot") unless path.dirname.join(accessibility_screenshot).cleanpath.file?

if (expected_surface_anchors = EXPECTED_ROUTE_SURFACE_ANCHORS[route])
  fail_check("#{path} renderedSurfaceAnchors must exactly match #{expected_surface_anchors.join(", ")}") unless manifest["renderedSurfaceAnchors"] == expected_surface_anchors
end

case route
when "kitchen"
  seed_account_id = manifest["kitchenSeedAccountID"]
  fail_check("#{path} kitchenSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "recipes"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "search"
  seed_account_id = manifest["searchSeedAccountID"]
  fail_check("#{path} searchSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
  variant = manifest["searchSurfaceVariant"]
  expected = expected_search_proof(variant)
  fail_check("#{path} expectedQuery must be #{expected["query"].inspect}") unless manifest["expectedQuery"] == expected["query"]
  fail_check("#{path} expectedScope must be #{expected["scope"]}") unless manifest["expectedScope"] == expected["scope"]
  fail_check("#{path} expectedRouteIdentifier must be #{expected["routeIdentifier"]}") unless manifest["expectedRouteIdentifier"] == expected["routeIdentifier"]
  search_scopes = manifest["searchScopes"]
  fail_check("#{path} searchScopes must be an array") unless search_scopes.is_a?(Array)
  fail_check("#{path} searchScopes must exactly match #{EXPECTED_SEARCH_SCOPES.join(", ")}") unless search_scopes == EXPECTED_SEARCH_SCOPES
  proof_artifacts = manifest["searchSurfaceProofArtifacts"]
  fail_check("#{path} searchSurfaceProofArtifacts must be an array") unless proof_artifacts.is_a?(Array)
  fail_check("#{path} searchSurfaceProofArtifacts must include iOS and macOS proof artifacts") unless proof_artifacts.length >= 2
  render_fingerprints = proof_artifacts.map do |proof_relative_path|
    fail_check("#{path} searchSurfaceProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
    validate_search_proof!(path, proof_relative_path, seed_account_id, expected)
  end
  fail_check("#{path} search proof render fingerprints must match across platforms") unless render_fingerprints.uniq.length == 1
when "recipe-detail"
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "recipe-editor"
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  fail_check("#{path} recipeSeedAccountID must be chef_ari") unless manifest["recipeSeedAccountID"] == "chef_ari"
when "recipe-covers"
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  fail_check("#{path} recipeSeedAccountID must be chef_ari") unless manifest["recipeSeedAccountID"] == "chef_ari"
  fail_check("#{path} recipeCoverControlsFixture must be action-states") unless manifest["recipeCoverControlsFixture"] == "action-states"
when "cook-log"
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cook-mode"
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "shopping-list"
  variant = manifest["shoppingListVariant"]
  fail_check("#{path} shoppingListVariant must be one of #{EXPECTED_SHOPPING_VARIANTS.join(", ")}") unless EXPECTED_SHOPPING_VARIANTS.include?(variant)
  seed_account_id = manifest["shoppingSeedAccountID"]
  fail_check("#{path} shoppingSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cookbooks"
  seed_account_id = manifest["cookbookSeedAccountID"]
  fail_check("#{path} cookbookSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cookbook-detail"
  fail_check("#{path} cookbookID must be cookbook_weeknights") unless manifest["cookbookID"] == "cookbook_weeknights"
  seed_account_id = manifest["cookbookSeedAccountID"]
  fail_check("#{path} cookbookSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "profile"
  fail_check("#{path} profileSeedAccountID must be chef_ari") unless manifest["profileSeedAccountID"] == "chef_ari"
  fail_check("#{path} profileIdentifier must be ari") unless manifest["profileIdentifier"] == "ari"
when "profile-graph"
  fail_check("#{path} profileSeedAccountID must be chef_ari") unless manifest["profileSeedAccountID"] == "chef_ari"
  fail_check("#{path} profileIdentifier must be ari") unless manifest["profileIdentifier"] == "ari"
  fail_check("#{path} profileGraphDirection must be kitchen-visitors") unless manifest["profileGraphDirection"] == "kitchen-visitors"
  fail_check("#{path} profileGraphPage must be 1") unless manifest["profileGraphPage"] == 1
when "capture"
  variant = manifest["captureSurfaceVariant"]
  fail_check("#{path} captureSurfaceVariant must be one of #{EXPECTED_CAPTURE_VARIANTS.join(", ")}") unless EXPECTED_CAPTURE_VARIANTS.include?(variant)
  expected_auth = variant == "signed-out" ? "0" : "1"
  fail_check("#{path} captureScreenshotAuth must be #{expected_auth}") unless manifest["captureScreenshotAuth"] == expected_auth
  seed_account_id = manifest["captureSeedAccountID"]
  fail_check("#{path} captureSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
  captureSignedOutSurface = manifest["captureSignedOutSurface"]
  fail_check("#{path} captureSignedOutSurface must match the signed-out variant") unless captureSignedOutSurface == (variant == "signed-out")
when "settings"
  seed_account_id = manifest["settingsSeedAccountID"]
  fail_check("#{path} settingsSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
  sections = manifest["settingsSections"]
  fail_check("#{path} settingsSections must be an array") unless sections.is_a?(Array)
  visual_focus = manifest["settingsVisualFocus"]
  fail_check("#{path} settingsVisualFocus must be profile, notifications, or signed-out") unless ["profile", "notifications", "signed-out"].include?(visual_focus)
  settingsSignedOutSurface = manifest["settingsSignedOutSurface"]
  settingsSignedOutHandoffSurface = manifest["settingsSignedOutHandoffSurface"]
  fail_check("#{path} settingsSignedOutSurface must match signed-out focus") unless settingsSignedOutSurface == (visual_focus == "signed-out")
  fail_check("#{path} settingsSignedOutHandoffSurface must match signed-out focus") unless settingsSignedOutHandoffSurface == (visual_focus == "signed-out")
  proof_artifacts = manifest["settingsSurfaceProofArtifacts"]
  fail_check("#{path} settingsSurfaceProofArtifacts must be an array") unless proof_artifacts.is_a?(Array)
  fail_check("#{path} settingsSurfaceProofArtifacts must include iOS and macOS proof artifacts") unless proof_artifacts.length >= 2
  required_sections = if visual_focus == "notifications"
                        fail_check("#{path} settingsAPNsPermissionState must be present for APNs captures") unless manifest["settingsAPNsPermissionState"].is_a?(String) && !manifest["settingsAPNsPermissionState"].empty?
                        fail_check("#{path} settingsAPNsRegistrationState must be present for APNs captures") unless manifest["settingsAPNsRegistrationState"].is_a?(String) && !manifest["settingsAPNsRegistrationState"].empty?
                        ["This Device", "Push Delivery", "Notification Sync", "Agent Access"]
                      elsif visual_focus == "signed-out"
                        fail_check("#{path} settingsScreenshotAuth must be 0 for signed-out settings captures") unless manifest["settingsScreenshotAuth"] == "0"
                        ["Session", "Environment", "Offline"]
                      else
                        ["Profile", "Security"]
                      end
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{path} settingsSections missing required #{visual_focus} sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
  proof_artifacts.each do |proof_relative_path|
    fail_check("#{path} settingsSurfaceProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
    validate_settings_proof!(path, proof_relative_path, visual_focus)
  end
end

puts "design review ok"
