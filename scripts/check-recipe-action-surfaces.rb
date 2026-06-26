#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/Features/RecipeActions/RecipeActionsViewModel.swift",
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
].freeze

REQUIRED_TOKENS = {
  "Sources/SpoonjoyCore/Features/RecipeActions/RecipeActionsViewModel.swift" => [
    "RecipeActionsViewModel",
    "RecipeAction",
    "RecipeActionPlan",
    "RecipeActionConfirmation",
    "RecipeActionConfirmationPrompt",
    "RecipeWriteRequests.forkRecipe",
    "RecipeWriteRequests.deleteRecipe",
    "CookbookWriteRequests.addRecipe",
    "CookbookWriteRequests.removeRecipe",
    "NativeQueuedMutation.recipeFork",
    "NativeQueuedMutation.recipeDelete",
    "NativeQueuedMutation.cookbookAddRecipe",
    "NativeQueuedMutation.cookbookRemoveRecipe"
  ],
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift" => [
    "RecipeDetailActionID",
    "RecipeShoppingListActionMetadata",
    "availableActionIDs",
    "cookbookOptions",
    "savedCookbookIDs",
    "shoppingListMetadata",
    "coverControlsRoute",
    "deleteConfirmation"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift" => [
    "RecipeActionsViewModel",
    "availableActionIDs",
    "ConfirmationDialog",
    "coverControlsRoute",
    "deleteConfirmation"
  ],
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift" => [
    "RecipeActionsViewModel",
    "performRecipeAction",
    "queueMutation",
    "executeRecipeEditorRequest"
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "RecipeComments",
  "SocialFeed",
  "MealPlan",
  "commentThread",
  "socialFeed",
  "mealPlan"
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def swift_contract_source(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
    .gsub(/"(?:\\.|[^"\\])*"/m, "\"\"")
end

missing_files = REQUIRED_FILES.reject { |path| ROOT.join(path).file? }
fail_check("missing recipe action surface files: #{missing_files.join(", ")}") unless missing_files.empty?

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = swift_contract_source(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required recipe action tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

forbidden_hits = REQUIRED_FILES.flat_map do |relative_path|
  content = swift_contract_source(ROOT.join(relative_path).read)
  FORBIDDEN_TOKENS.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden recipe action tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

puts "recipe action surfaces contract ok"
