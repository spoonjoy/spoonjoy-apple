#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")
WEB_REPO = Pathname.new(ENV.fetch("SPOONJOY_WEB_REPO", ROOT.dirname.join("spoonjoy-v2").to_s)).expand_path

REQUIRED_WEB_COOKBOOK_WRITE_METHODS = {
  "/api/v1/cookbooks" => ["POST"],
  "/api/v1/cookbooks/{id}" => ["PATCH", "DELETE"],
  "/api/v1/cookbooks/{id}/recipes/{recipeId}" => ["POST", "DELETE"]
}.freeze

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/Views/KitchenView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
  "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift",
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogRepository.swift",
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift",
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift",
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceViewModel.swift",
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
  "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
  "Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/Contents.json",
  "Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png",
  "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift"
].freeze

REQUIRED_TOKENS = {
  "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift" => [
    "RecipeCoverImage",
    "AsyncImagePhase",
    "Image(\"LemonPantryPasta\")",
    ".failure",
    ".empty",
    "scaledToFill"
  ],
  "Apps/Spoonjoy/Shared/Design/KitchenTableTheme.swift" => [
    "KitchenTableTheme",
    "bone",
    "charcoal",
    "brass",
    "tomato",
    "herb",
    "photoOverlay",
    "displayTitle",
    "bodyNote",
    "uiLabel",
    "Radius"
  ],
  "Apps/Spoonjoy/Shared/Views/KitchenView.swift" => [
    "KitchenView",
    "KitchenMasthead",
    "RecipeLead",
    "RecipeIndex",
    "CookbookShelf",
    "KitchenFixtureState",
    "KitchenLeadObject",
    "ScrollView",
    "RecipeCoverImage(",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipesView.swift" => [
    "RecipesView",
    "RecipeCatalogViewModel",
    "state.rows",
    "viewModel.load",
    "List",
    "Button",
    "openRoute",
    "RecipeCoverImage(",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift" => [
    "RecipeDetailRouteView",
    "repository.recipeDetail",
    "RecipeDetailView",
    "RecipeDetailScreenViewModel",
    "ShareLink",
    "RecipeCoverImage(",
    "provenance",
    "cookbookSpread",
    "ingredientReceipt",
    "methodSections",
    "spoonSummary",
    "cookbookSave",
    "ownerTools",
    "offlineIndicator",
    "ForEach",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift" => [
    "CookModeRouteView",
    "repository.recipeDetail",
    "initialRecipe",
    "CookModeViewModel",
    "CookModeView",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift" => [
    "CookbooksView",
    "CookbookCreateSheet",
    "CookbookShelf",
    "CookbookCover",
    "CookbookSurfaceViewModel",
    "CookbookDetailRouteView",
    "NativeSharePayload.publicCookbook",
    "ShareLink",
    "ownerTools",
    "confirmationDialog",
    "planCreate",
    "performAndApplyCookbookAction",
    "ScrollView",
    "Button",
    "RecipeCoverImage(",
    "KitchenTableTheme"
  ],
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceRepository.swift" => [
    "CookbookSurfaceRepository",
    "CookbookSurfaceListRequest",
    "CookbookSurfacePage",
    "CookbookSurfaceDetailResult",
    "LiveCookbookSurfaceRepository",
    "SnapshotCookbookSurfaceRepository",
    "FallbackCookbookSurfaceRepository",
    "PublicCatalogRequests.listCookbooks",
    "PublicCatalogRequests.cookbookDetail",
    "NativeCacheDomain.cookbookList",
    "NativeCacheDomain.cookbookDetail"
  ],
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceViewModel.swift" => [
    "CookbookSurfaceViewModel",
    "CookbookSurfaceListViewModel",
    "CookbookDetailViewModel",
    "CookbookCreatePlanner",
    "CookbookSurfaceContext",
    "CookbookSurfaceAction",
    "CookbookSurfaceActionPlan",
    "CookbookActionConfirmation",
    "CookbookActionConfirmationPrompt",
    "CookbookSurfaceConflictBanner",
    "CookbookSurfaceEmptyState",
    "CookbookWriteRequests.createCookbook",
    "CookbookWriteRequests.updateCookbook",
    "CookbookWriteRequests.deleteCookbook",
    "CookbookWriteRequests.addRecipe",
    "CookbookWriteRequests.removeRecipe",
    "NativeQueuedMutation.cookbookCreate",
    "NativeQueuedMutation.cookbookUpdate",
    "NativeQueuedMutation.cookbookDelete",
    "NativeQueuedMutation.cookbookAddRecipe",
    "NativeQueuedMutation.cookbookRemoveRecipe",
    "NativeSharePayload.publicCookbook",
    "OfflineIndicatorState",
    "applying(updatedCookbook:",
    "dependencyKey"
  ],
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift" => [
    "cookbooksByApplyingQueuedCookbookMutations",
    "applyingOptimisticCookbookMutation",
    "optimisticCookbooks",
    "cookbooks: optimisticCookbooks"
  ],
  "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift" => [
    "optimisticCookbookID",
    "applyingOptimisticCookbookMutation",
    "mutatesCookbookCache",
    "drainedCookbookCachePatch",
    "cookbookCreate(clientMutationID"
  ],
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift" => [
    "cookbook detail",
    "cookbook owner tools",
    "cookbook create",
    "CookbookCreatePlanner",
    "cookbook rename",
    "cookbook delete",
    "cookbook add recipe",
    "cookbook remove recipe"
  ],
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogRepository.swift" => [
    "RecipeCatalogRepository",
    "RecipeCatalogListRequest",
    "RecipeCatalogPage",
    "RecipeCatalogDetailResult",
    "FallbackRecipeCatalogRepository",
    "PublicCatalogRequests.listRecipes",
    "PublicCatalogRequests.recipeDetail",
    "NativeCacheDomain.recipeCatalog",
    "NativeCacheDomain.recipeDetail"
  ],
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeCatalogViewModel.swift" => [
    "RecipeCatalogViewModel",
    "RecipeCatalogState",
    "RecipeCatalogRowViewModel",
    "openRecipeRoute",
    "resultCountLabel",
    "OfflineIndicatorState"
  ],
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift" => [
    "RecipeDetailScreenViewModel",
    "RecipeDetailContext",
    "RecipeCookbookSaveOption",
    "ingredientReceipt",
    "spoonSummary",
    "cookbookSave",
    "ownerTools",
    "supportedReadSurfaces"
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "CardView",
  "WKWebView",
  "className",
  "tailwind",
  "LazyVGrid",
  "Grid {",
  'Text("Recipe index is next.")',
  'Text("Cookbook shelf is next.")',
  "RecipesView(recipes: contentState.recipes",
  "RecipeDetailView(viewModel: RecipeDetailViewModel(recipe: recipe)",
  "comments",
  "socialFeed",
  "mealPlan",
  "RecipeComments",
  "SocialFeed",
  "MealPlan"
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

def web_method_declared?(content, path, method)
  resource_declared = content.lines.any? do |line|
    line.include?(%Q(path: "#{path}")) && line.match?(/methods:\s*\[[^\]]*"#{Regexp.escape(method)}"/)
  end
  scope_declared = content.lines.any? do |line|
    line.include?(%Q(path: "#{path}")) && line.include?(%Q(method: "#{method}"))
  end

  resource_declared && scope_declared
end

missing_files = REQUIRED_FILES.reject { |path| ROOT.join(path).file? }
fail_check("missing kitchen/recipe surface files: #{missing_files.join(", ")}") unless missing_files.empty?

asset_path = ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png")
stdout, stderr, status = Open3.capture3("sips", "-g", "pixelWidth", "-g", "pixelHeight", asset_path.to_s)
fail_check("unable to inspect #{asset_path}: #{stderr}") unless status.success?
width = stdout[/pixelWidth:\s+(\d+)/, 1].to_i
height = stdout[/pixelHeight:\s+(\d+)/, 1].to_i
fail_check("#{asset_path} must be at least 1200x700, got #{width}x#{height}") if width < 1200 || height < 700

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = uncommented_swift(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required surface tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

forbidden_hits = REQUIRED_FILES.select { |relative_path| relative_path.end_with?(".swift") }.flat_map do |relative_path|
  content = uncommented_swift(ROOT.join(relative_path).read)
  FORBIDDEN_TOKENS.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden kitchen/recipe surface tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

root_shell = uncommented_swift(ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read)
root_shell_forbidden = FORBIDDEN_TOKENS.select { |token| root_shell.include?(token) }
fail_check("PlatformNavigationView.swift contains forbidden recipe surface tokens: #{root_shell_forbidden.join(", ")}") unless root_shell_forbidden.empty?

[
  "KitchenView(",
  "RecipesView(",
  "RecipeDetailRouteView(",
  "CookbooksView(",
  "CookbookDetailRouteView(",
  "CookbookSurfaceViewModel",
  "LiveCookbookSurfaceRepository",
  "FallbackCookbookSurfaceRepository",
  "performCookbookAction",
  "RecipeCatalogViewModel",
  "RecipeDetailScreenViewModel",
  "RecipeCatalogRepository",
  "LiveRecipeCatalogRepository",
  "FallbackRecipeCatalogRepository",
  "RecipeDetailRouteView",
  "CookModeRouteView",
  "contentState.recipeCatalog"
].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless root_shell.include?(token)
end

web_contract = WEB_REPO.join("app/lib/api-v1-contract.server.ts")
if web_contract.file?
  contract_content = web_contract.read
  REQUIRED_WEB_COOKBOOK_WRITE_METHODS.each do |path, methods|
    methods.each do |method|
      fail_check("#{web_contract} missing #{method} #{path} for native cookbook parity") unless web_method_declared?(contract_content, path, method)
    end
  end
else
  warn "WARN: skipping web cookbook API contract; set SPOONJOY_WEB_REPO to a spoonjoy-v2 checkout to enforce it" unless ENV["CI"] == "true"
end

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "kitchen and recipe surfaces contract ok"
