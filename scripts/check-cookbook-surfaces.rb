#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
WEB_REPO = Pathname.new(ENV.fetch("SPOONJOY_WEB_REPO", ROOT.dirname.join("spoonjoy-v2").to_s)).expand_path

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceRepository.swift",
  "Sources/SpoonjoyCore/Features/Cookbooks/CookbookSurfaceViewModel.swift",
  "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
  "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
  "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
].freeze

REQUIRED_TOKENS = {
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
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift" => [
    "CookbooksView",
    "CookbookCreateSheet",
    "CookbookShelf",
    "CookbookCoverArt",
    "CookbookFallbackCover",
    "CookbookImageCover",
    "CookbookRecipeIndexRow",
    "DisclosureGroup(isExpanded",
    "CookbookSurfaceViewModel",
    "CookbookDetailRouteView",
    "NativeSharePayload.publicCookbook",
    "ShareLink",
    "ownerTools",
    "confirmationDialog",
    "planCreate",
    "performAndApplyCookbookAction",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift" => [
    "CookbookDetailRouteView(",
    "CookbookSurfaceViewModel",
    "LiveCookbookSurfaceRepository",
    "FallbackCookbookSurfaceRepository",
    "performCookbookAction",
    "queueMutation",
    "executeRecipeEditorRequest"
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
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "WKWebView",
  "className",
  "tailwind",
  "CardView",
  "Grid {",
  'Text("Cookbook shelf is next.")',
  "RecipeComments",
  "SocialFeed",
  "MealPlan"
].freeze

REQUIRED_WEB_COOKBOOK_WRITE_METHODS = {
  "/api/v1/cookbooks" => ["POST"],
  "/api/v1/cookbooks/{id}" => ["PATCH", "DELETE"],
  "/api/v1/cookbooks/{id}/recipes/{recipeId}" => ["POST", "DELETE"]
}.freeze

def uncommented_swift(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
end

def swift_contract_source(content)
  uncommented_swift(content)
    .gsub(/"(?:\\.|[^"\\\r\n])*"/, "\"\"")
end

def required_token_source(relative_path, content)
  if relative_path == "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
    uncommented_swift(content)
  else
    swift_contract_source(content)
  end
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

failures = []

REQUIRED_FILES.each do |relative_path|
  failures << "missing cookbook surface file: #{relative_path}" unless ROOT.join(relative_path).file?
end

REQUIRED_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = required_token_source(relative_path, path.read)
  missing = tokens.reject { |token| content.include?(token) }
  failures << "#{relative_path} missing required cookbook tokens: #{missing.join(", ")}" unless missing.empty?
end

REQUIRED_FILES.each do |relative_path|
  path = ROOT.join(relative_path)
  next unless path.file?

  content = uncommented_swift(path.read)
  forbidden = FORBIDDEN_TOKENS.select { |token| content.include?(token) }
  failures << "#{relative_path} contains forbidden cookbook tokens: #{forbidden.join(", ")}" unless forbidden.empty?
end

web_contract = WEB_REPO.join("app/lib/api-v1-contract.server.ts")
if web_contract.file?
  contract_content = web_contract.read
  REQUIRED_WEB_COOKBOOK_WRITE_METHODS.each do |path, methods|
    methods.each do |method|
      unless web_method_declared?(contract_content, path, method)
        failures << "#{web_contract} missing #{method} #{path} for native cookbook parity"
      end
    end
  end
else
  warn "WARN: skipping web cookbook API contract; set SPOONJOY_WEB_REPO to a spoonjoy-v2 checkout to enforce it" unless ENV["CI"] == "true"
end

if failures.empty?
  puts "cookbook surfaces contract ok"
else
  warn failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end
