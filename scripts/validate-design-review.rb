#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

REQUIRED_FIELDS = [
  "mobileScreenshot",
  "desktopScreenshot",
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze

VALID_ROUTES = ["kitchen", "recipes", "saved-recipes", "recipe-detail", "cook-log", "cook-mode", "shopping-list", "chefs", "search", "cookbooks", "cookbook-detail", "capture", "settings"].freeze
EXPECTED_SEARCH_SCOPES = ["all", "recipes", "cookbooks", "chefs", "shopping-list"].freeze
EXPECTED_CAPTURE_VARIANTS = ["normal", "empty", "draft", "offline-retry", "provider-blocked", "signed-out"].freeze
ACCESSIBILITY_FIELDS = [
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze
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
    "keyboardNavigationTargets" => ["visible search field", "typed rows", "SearchSurfaceSectionView buttons"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "herb tint on bone"],
    "hierarchyAnchors" => ["SearchView", "SearchSurfaceContract.searchableScopes", "SearchSurfaceContract.visibleSearchField", "SearchSurfaceContract.typedRows", "SearchSurfaceSectionView", "SearchSurfaceRowView"],
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
    "voiceOverLabels" => ["Import queue", "Capture", "Submit import", "Retry when online", "Hide offline status"],
    "keyboardNavigationTargets" => ["entry point ledger", "saved capture actions", "Retry when online", "offline status dismiss"],
    "dynamicTypeTextStyles" => ["KitchenTableTheme.displayTitle", "KitchenTableTheme.bodyNote", "KitchenTableTheme.uiLabel"],
    "contrastPairs" => ["charcoal on bone", "brass on bone", "destructive action role", "status label on bone"],
    "hierarchyAnchors" => ["CaptureDraftView", "KitchenTableHeader", "CaptureImportEntryPoint", "ImportStatusPanel", "CaptureDraft", "OfflineStatusView"],
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
      "requiredSections" => ["Cookbooks"]
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
      "scope" => "recipes",
      "routeIdentifier" => "search:recipes:kumquat",
      "requiredSections" => [],
      "requiresEmptySections" => true
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
  sections = proof["visibleSections"]
  fail_check("#{proof_path} visibleSections must be an array") unless sections.is_a?(Array)
  required_sections = expected["requiredSections"]
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{proof_path} visibleSections missing required search sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
  if expected["requiresEmptySections"] && !sections.empty?
    fail_check("#{proof_path} no-results search proof must not include visible result sections: #{sections.join(", ")}")
  end
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
  when "cook-log"
    "SpoonCookLogView"
  when "cook-mode"
    "CookModeView"
  when "shopping-list"
    "ShoppingListView"
  when "chefs"
    "ChefsView"
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
  fail_check("#{proof_path} platform must be ios or macos") unless ["ios", "macos"].include?(proof["platform"])
  expected_bundle_identifier = proof["platform"] == "macos" ? "app.spoonjoy.mac" : "app.spoonjoy"
  fail_check("#{proof_path} route must be #{route}") unless proof["route"] == route
  expected_source = expected_accessibility_source(route, manifest)
  fail_check("#{proof_path} source must be #{expected_source}") unless proof["source"] == expected_source
  fail_check("#{proof_path} emittedBy must be SpoonjoyApp") unless proof["emittedBy"] == "SpoonjoyApp"
  fail_check("#{proof_path} bundleIdentifier must be #{expected_bundle_identifier}") unless proof["bundleIdentifier"] == expected_bundle_identifier

  false_fields = ACCESSIBILITY_FIELDS.reject { |field| proof[field] == true }
  fail_check("#{proof_path} accessibility fields must all be true: #{false_fields.join(", ")}") unless false_fields.empty?
  fail_check("#{proof_path} minimumTargetSize must be at least 44") unless proof["minimumTargetSize"].is_a?(Numeric) && proof["minimumTargetSize"] >= 44
  fail_check("#{proof_path} textFits must be true") unless proof["textFits"] == true
  fail_check("#{proof_path} noTinyClusters must be true") unless proof["noTinyClusters"] == true
  fail_check("#{proof_path} observedDynamicTypeSize must be a non-empty string") unless proof["observedDynamicTypeSize"].is_a?(String) && !proof["observedDynamicTypeSize"].empty?
  fail_check("#{proof_path} observedReduceMotion must be boolean") unless [true, false].include?(proof["observedReduceMotion"])

  route_evidence = proof["routeEvidence"]
  fail_check("#{proof_path} routeEvidence must be an object") unless route_evidence.is_a?(Hash)
  EXPECTED_ROUTE_EVIDENCE.fetch(accessibility_evidence_key(route, manifest)).each do |field, required_values|
    actual_values = route_evidence[field]
    fail_check("#{proof_path} routeEvidence.#{field} must be an array") unless actual_values.is_a?(Array)
    missing_values = required_values.reject { |value| actual_values.include?(value) }
    fail_check("#{proof_path} routeEvidence.#{field} missing #{missing_values.join(", ")}") unless missing_values.empty?
  end

  offline_proof = proof["offlineIndicatorProof"]
  fail_check("#{proof_path} offlineIndicatorProof must be an object") unless offline_proof.is_a?(Hash)
  fail_check("#{proof_path} offlineIndicatorProof source must be OfflineStatusView") unless offline_proof["source"] == "OfflineStatusView"
  fail_check("#{proof_path} offlineIndicatorProof visibleStates must exactly match #{EXPECTED_OFFLINE_VISIBLE_STATES.join(", ")}") unless offline_proof["visibleStates"] == EXPECTED_OFFLINE_VISIBLE_STATES
  fail_check("#{proof_path} offlineIndicatorProof dismissibleStates must exactly match #{EXPECTED_OFFLINE_DISMISSIBLE_STATES.join(", ")}") unless offline_proof["dismissibleStates"] == EXPECTED_OFFLINE_DISMISSIBLE_STATES
  fail_check("#{proof_path} offlineIndicatorProof severeStates must exactly match #{EXPECTED_OFFLINE_SEVERE_STATES.join(", ")}") unless offline_proof["severeStates"] == EXPECTED_OFFLINE_SEVERE_STATES
  fail_check("#{proof_path} offlineIndicatorProof hiddenStates must exactly match synced, dismissed") unless offline_proof["hiddenStates"] == ["synced", "dismissed"]
  fail_check("#{proof_path} offlineIndicatorProof voiceOverLabel must be true") unless offline_proof["voiceOverLabel"] == true
  fail_check("#{proof_path} offlineIndicatorProof dismissButtonLabel must be Hide offline status") unless offline_proof["dismissButtonLabel"] == "Hide offline status"
  fail_check("#{proof_path} offlineIndicatorProof severityCorrect must be true") unless offline_proof["severityCorrect"] == true
end

path = Pathname.new(ARGV.fetch(0) { fail_check("usage: validate-design-review.rb <design-review.json>") })
fail_check("missing #{path}") unless path.file?

manifest = JSON.parse(path.read)
fail_check("#{path} must contain a JSON object") unless manifest.is_a?(Hash)

missing_fields = REQUIRED_FIELDS.reject { |field| manifest.key?(field) }
fail_check("#{path} missing required fields: #{missing_fields.join(", ")}") unless missing_fields.empty?

non_boolean_fields = REQUIRED_FIELDS.reject { |field| [true, false].include?(manifest[field]) }
fail_check("#{path} fields must be booleans: #{non_boolean_fields.join(", ")}") unless non_boolean_fields.empty?

blockers = manifest.fetch("blockers", [])
fail_check("#{path} blockers must be an array") unless blockers.is_a?(Array)
fail_check("#{path} blockers must be empty; runtime blockers belong in design-review-blocked.json") unless blockers.empty?

false_fields = REQUIRED_FIELDS.select { |field| manifest[field] == false }
fail_check("#{path} false fields are not valid in design-review.json: #{false_fields.join(", ")}") unless false_fields.empty?

route = manifest["screenshotRoute"]
fail_check("#{path} missing screenshotRoute") if route.nil?
fail_check("#{path} screenshotRoute has invalid type") unless route.is_a?(String)
fail_check("#{path} screenshotRoute must be one of #{VALID_ROUTES.join(", ")}") unless VALID_ROUTES.include?(route)

accessibility_proofs = manifest["accessibilityProofArtifacts"]
fail_check("#{path} accessibilityProofArtifacts must be an array") unless accessibility_proofs.is_a?(Array)
fail_check("#{path} accessibilityProofArtifacts must include iOS and macOS proof artifacts") unless accessibility_proofs.length >= 2
platforms = []
accessibility_proofs.each do |proof_relative_path|
  fail_check("#{path} accessibilityProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
  validate_accessibility_proof!(path, proof_relative_path, route, manifest)
  proof_path = path.dirname.join(proof_relative_path).cleanpath
  platforms << JSON.parse(proof_path.read)["platform"]
end
fail_check("#{path} accessibilityProofArtifacts must include ios and macos platforms") unless platforms.sort == ["ios", "macos"]

case route
when "kitchen"
  fail_check("#{path} kitchenSignedInSurface must be true for kitchen captures") unless manifest["kitchenSignedInSurface"] == true
  seed_account_id = manifest["kitchenSeedAccountID"]
  fail_check("#{path} kitchenSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "recipes"
  fail_check("#{path} recipesNativeSurface must be true for recipes captures") unless manifest["recipesNativeSurface"] == true
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "search"
  fail_check("#{path} searchNativeSurface must be true for search captures") unless manifest["searchNativeSurface"] == true
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
  proof_artifacts.each do |proof_relative_path|
    fail_check("#{path} searchSurfaceProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
    validate_search_proof!(path, proof_relative_path, seed_account_id, expected)
  end
when "recipe-detail"
  fail_check("#{path} recipeDetailSurface must be true for recipe detail captures") unless manifest["recipeDetailSurface"] == true
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cook-log"
  fail_check("#{path} cookLogSurface must be true for cook log captures") unless manifest["cookLogSurface"] == true
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  fail_check("#{path} cookLogForm must be true") unless manifest["cookLogForm"] == true
  fail_check("#{path} cookLogPhotoSlot must be true") unless manifest["cookLogPhotoSlot"] == true
  fail_check("#{path} cookLogActionBar must be true") unless manifest["cookLogActionBar"] == true
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cook-mode"
  fail_check("#{path} cookModeSurface must be true for cook mode captures") unless manifest["cookModeSurface"] == true
  fail_check("#{path} recipeID must be recipe_lemon_pantry_pasta") unless manifest["recipeID"] == "recipe_lemon_pantry_pasta"
  seed_account_id = manifest["recipeSeedAccountID"]
  fail_check("#{path} recipeSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "shopping-list"
  fail_check("#{path} shoppingListSurface must be true for shopping list captures") unless manifest["shoppingListSurface"] == true
  seed_account_id = manifest["shoppingSeedAccountID"]
  fail_check("#{path} shoppingSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cookbooks"
  fail_check("#{path} cookbooksNativeSurface must be true for cookbooks captures") unless manifest["cookbooksNativeSurface"] == true
  fail_check("#{path} cookbookLibrarySpread must be true for cookbooks captures") unless manifest["cookbookLibrarySpread"] == true
  fail_check("#{path} cookbookShelfStrip must be true for cookbooks captures") unless manifest["cookbookShelfStrip"] == true
  seed_account_id = manifest["cookbookSeedAccountID"]
  fail_check("#{path} cookbookSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "cookbook-detail"
  fail_check("#{path} cookbookDetailSurface must be true for cookbook detail captures") unless manifest["cookbookDetailSurface"] == true
  fail_check("#{path} cookbookID must be cookbook_weeknights") unless manifest["cookbookID"] == "cookbook_weeknights"
  fail_check("#{path} cookbookContentsIndex must be true for cookbook detail captures") unless manifest["cookbookContentsIndex"] == true
  fail_check("#{path} cookbookOwnerToolsDisclosure must be true for cookbook detail captures") unless manifest["cookbookOwnerToolsDisclosure"] == true
  seed_account_id = manifest["cookbookSeedAccountID"]
  fail_check("#{path} cookbookSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "capture"
  variant = manifest["captureSurfaceVariant"]
  fail_check("#{path} captureSurfaceVariant must be one of #{EXPECTED_CAPTURE_VARIANTS.join(", ")}") unless EXPECTED_CAPTURE_VARIANTS.include?(variant)
  expected_auth = variant == "signed-out" ? "0" : "1"
  fail_check("#{path} captureScreenshotAuth must be #{expected_auth}") unless manifest["captureScreenshotAuth"] == expected_auth
  if variant == "signed-out"
    fail_check("#{path} captureSignedOutSurface must be true for signed-out capture") unless manifest["captureSignedOutSurface"] == true
    fail_check("#{path} captureNativeSurface must be false for signed-out capture") unless manifest["captureNativeSurface"] == false
  else
    fail_check("#{path} captureNativeSurface must be true for signed-in capture captures") unless manifest["captureNativeSurface"] == true
    fail_check("#{path} captureSignedOutSurface must be false for signed-in capture captures") unless manifest["captureSignedOutSurface"] == false
  end
  seed_account_id = manifest["captureSeedAccountID"]
  fail_check("#{path} captureSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "settings"
  seed_account_id = manifest["settingsSeedAccountID"]
  fail_check("#{path} settingsSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
  sections = manifest["settingsSections"]
  fail_check("#{path} settingsSections must be an array") unless sections.is_a?(Array)
  visual_focus = manifest["settingsVisualFocus"]
  fail_check("#{path} settingsVisualFocus must be profile, notifications, or signed-out") unless ["profile", "notifications", "signed-out"].include?(visual_focus)
  proof_artifacts = manifest["settingsSurfaceProofArtifacts"]
  fail_check("#{path} settingsSurfaceProofArtifacts must be an array") unless proof_artifacts.is_a?(Array)
  fail_check("#{path} settingsSurfaceProofArtifacts must include iOS and macOS proof artifacts") unless proof_artifacts.length >= 2
  required_sections = if visual_focus == "notifications"
                        fail_check("#{path} settingsSignedInSurface must be true for settings/APNs captures") unless manifest["settingsSignedInSurface"] == true
                        fail_check("#{path} settingsNotificationAPNsSurface must be true for settings/APNs captures") unless manifest["settingsNotificationAPNsSurface"] == true
                        fail_check("#{path} settingsAPNsPermissionState must be present for APNs captures") unless manifest["settingsAPNsPermissionState"].is_a?(String) && !manifest["settingsAPNsPermissionState"].empty?
                        fail_check("#{path} settingsAPNsRegistrationState must be present for APNs captures") unless manifest["settingsAPNsRegistrationState"].is_a?(String) && !manifest["settingsAPNsRegistrationState"].empty?
                        ["This Device", "Push Delivery", "Notification Sync", "Agent Access"]
                      elsif visual_focus == "signed-out"
                        fail_check("#{path} settingsSignedInSurface must be false for signed-out settings captures") unless manifest["settingsSignedInSurface"] == false
                        fail_check("#{path} settingsSignedOutSurface must be true for signed-out settings captures") unless manifest["settingsSignedOutSurface"] == true
                        fail_check("#{path} settingsSignedOutHandoffSurface must be true for signed-out settings captures") unless manifest["settingsSignedOutHandoffSurface"] == true
                        fail_check("#{path} settingsScreenshotAuth must be 0 for signed-out settings captures") unless manifest["settingsScreenshotAuth"] == "0"
                        ["Session", "Environment", "Offline"]
                      else
                        fail_check("#{path} settingsSignedInSurface must be true for profile settings captures") unless manifest["settingsSignedInSurface"] == true
                        fail_check("#{path} settingsProfileSurface must be true for profile settings captures") unless manifest["settingsProfileSurface"] == true
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
