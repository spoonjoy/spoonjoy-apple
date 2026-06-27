#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")
WEB_REPO = Pathname.new(ENV.fetch("SPOONJOY_WEB_REPO", ROOT.dirname.join("spoonjoy-v2").to_s)).expand_path

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/Features/Shopping/ShoppingSurfaceViewModel.swift",
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
  "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift",
  "Apps/Spoonjoy/Shared/Components/KitchenSafeControls.swift"
].freeze

REQUIRED_TOKENS = {
  "Sources/SpoonjoyCore/Features/Shopping/ShoppingSurfaceViewModel.swift" => [
    "ShoppingSurfaceRepository",
    "ShoppingSurfaceViewModel",
    "ShoppingSurfaceAction",
    "ShoppingSurfaceMutationPlan",
    "ShoppingSurfaceMutationExecutor",
    "ShoppingAddItemFormState",
    "RecipeShoppingListCoverage",
    "ShoppingActionConfirmation",
    "ShoppingActionConfirmationPrompt",
    "ShoppingListRequests.addItem",
    "ShoppingListRequests.setItemChecked",
    "ShoppingListRequests.deleteItem",
    "ShoppingListRequests.addIngredientsFromRecipe",
    "ShoppingListRequests.clearCompleted",
    "ShoppingListRequests.clearAll",
    "NativeQueuedMutation.shoppingAddItem",
    "NativeQueuedMutation.shoppingCheckItem",
    "NativeQueuedMutation.shoppingDeleteItem",
    "NativeQueuedMutation.shoppingAddFromRecipe",
    "NativeQueuedMutation.shoppingClearCompleted",
    "NativeQueuedMutation.shoppingClearAll"
  ],
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
    "deleteItem",
    "trash",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift" => [
    "CookModeView",
    "CookModeViewModel",
    "shoppingViewModel",
    "CookModeProgress",
    "KitchenSafeControls",
    "currentStep",
    "ProgressView",
    "Persisted progress",
    "addRecipeIngredients",
    "scaleFactor",
    "accessibilityLabel",
    "accessibilityValue",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift" => [
    "shoppingViewModel",
    "shoppingListMetadata",
    "addRecipeIngredients",
    "localHasIngredientsInShoppingList",
    "ShoppingSurfaceAction",
    "cart.badge.plus"
  ],
  "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift" => [
    "ShoppingListView",
    "ShoppingSurfaceViewModel",
    "ShoppingAddItemFormState",
    "ShoppingListState",
    "ReceiptListView",
    "EditMode",
    "settingChecked",
    "TextField",
    "addItem",
    "submittedForm.submit",
    "deleteItem",
    "clearCompleted",
    "clearAll",
    ".confirmationDialog",
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

REQUIRED_WEB_SHOPPING_API_PATHS = [
  "/api/v1/shopping-list/items",
  "/api/v1/shopping-list/items/{itemId}",
  "/api/v1/shopping-list/add-from-recipe",
  "/api/v1/shopping-list/clear-completed",
  "/api/v1/shopping-list/clear-all"
].freeze

REQUIRED_NATIVE_SHOPPING_ROUTE_TOKENS = [
  '"shopping-list", "items"',
  '"shopping-list", "add-from-recipe"',
  '"shopping-list", "clear-completed"',
  '"shopping-list", "clear-all"'
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
[
  "ShoppingSurfaceViewModel",
  "ShoppingSurfaceMutationExecutor.perform",
  "RecipeShoppingListCoverage.hasAllRecipeIngredients",
  "shoppingViewModel: shoppingViewModel",
  "performShoppingAction",
  "queueMutation",
  "executeRecipeEditorRequest",
  "recordShoppingList"
].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless platform_navigation.include?(token)
end

fake_planner_hits = REQUIRED_FILES.flat_map do |relative_path|
  next [] unless relative_path.end_with?("RecipeDetailView.swift", "CookModeView.swift")

  content = uncommented_swift(ROOT.join(relative_path).read)
  content.include?("queuedMutations: []") ? ["#{relative_path} builds a shopping planner without shell queued mutations"] : []
end
fail_check("shopping add-to-list entry points bypass queue state: #{fake_planner_hits.join(", ")}") unless fake_planner_hits.empty?

shopping_requests = uncommented_swift(ROOT.join("Sources/SpoonjoyCore/API/ShoppingListRequests.swift").read)
REQUIRED_NATIVE_SHOPPING_ROUTE_TOKENS.each do |token|
  fail_check("ShoppingListRequests.swift missing native shopping route components #{token}") unless shopping_requests.include?(token)
end

web_contract = WEB_REPO.join("app/lib/api-v1-contract.server.ts")
web_router = WEB_REPO.join("app/lib/api-v1.server.ts")
if web_contract.file? && web_router.file?
  contract_content = web_contract.read
  router_content = web_router.read
  REQUIRED_WEB_SHOPPING_API_PATHS.each do |path|
    fail_check("#{web_contract} missing #{path}") unless contract_content.include?(path)
  end
  {
    "shopping-list/add-from-recipe" => "handleShoppingAddFromRecipe",
    "shopping-list/clear-completed" => "handleShoppingClear",
    "shopping-list/clear-all" => "handleShoppingClear"
  }.each do |path_token, handler_token|
    fail_check("#{web_router} missing router path #{path_token}") unless router_content.include?(path_token)
    fail_check("#{web_router} missing handler #{handler_token}") unless router_content.include?(handler_token)
  end
else
  warn "WARN: skipping web API route contract; set SPOONJOY_WEB_REPO to a spoonjoy-v2 checkout to enforce it" unless ENV["CI"] == "true"
end

scenario_verifier = ROOT.join("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift").read
[
  "cook progress persistence",
  "shopping checkoff",
  "shopping add item",
  "shopping add recipe ingredients",
  "shopping recipe coverage",
  "shopping clear confirmation",
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
