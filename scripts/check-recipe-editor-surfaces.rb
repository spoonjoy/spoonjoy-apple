#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

REQUIRED_FILES = [
  "Sources/SpoonjoyCore/Features/RecipeEditor/RecipeEditorDraft.swift",
  "Sources/SpoonjoyCore/Features/RecipeEditor/RecipeEditorViewModel.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift"
].freeze

REQUIRED_TOKENS = {
  "Sources/SpoonjoyCore/Features/RecipeEditor/RecipeEditorDraft.swift" => [
    "RecipeEditorDraft",
    "RecipeEditorStepDraft",
    "RecipeEditorIngredientDraft",
    "RecipeEditorValidator",
    "RecipeEditorValidationIssue",
    "blank(currentChefID:",
    "outputStepNums"
  ],
  "Sources/SpoonjoyCore/Features/RecipeEditor/RecipeEditorViewModel.swift" => [
    "RecipeEditorViewModel",
    "RecipeEditorMode",
    "RecipeEditorAction",
    "RecipeEditorMutationPlan",
    "RecipeEditorConfirmation",
    "RecipeEditorConflict",
    "RecipeEditorConflictBanner",
    "RecipeWriteRequests.createRecipe",
    "RecipeWriteRequests.updateRecipe",
    "RecipeWriteRequests.deleteRecipe",
    "RecipeStepRequests.createStep",
    "RecipeStepRequests.updateStep",
    "RecipeStepRequests.deleteStep",
    "RecipeStepRequests.reorderStep",
    "RecipeStepRequests.createIngredient",
    "RecipeStepRequests.deleteIngredient",
    "RecipeStepRequests.replaceOutputUses",
    "NativeQueuedMutation.recipeCreate",
    "NativeQueuedMutation.recipeUpdate",
    "NativeQueuedMutation.recipeDelete",
    "NativeQueuedMutation.recipeStepCreate",
    "NativeQueuedMutation.recipeStepUpdate",
    "NativeQueuedMutation.recipeStepDelete",
    "NativeQueuedMutation.recipeStepReorder",
    "NativeQueuedMutation.recipeIngredientAdd",
    "NativeQueuedMutation.recipeIngredientDelete",
    "NativeQueuedMutation.recipeOutputUsesReplace",
    "OfflineIndicatorState"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift" => [
    "RecipeEditorView",
    "RecipeEditorViewModel",
    "TextField",
    "TextEditor",
    "Stepper",
    "ConfirmationDialog",
    "ForEach",
    "onMove",
    "KitchenSafeControls",
    "KitchenTableTheme"
  ]
}.freeze

REQUIRED_PATTERNS = {
  "Sources/SpoonjoyCore/Features/RecipeEditor/RecipeEditorViewModel.swift" => [
    /enum\s+RecipeEditorMode[\s\S]*case\s+create[\s\S]*case\s+edit/,
    /enum\s+RecipeEditorAction[\s\S]*case\s+save[\s\S]*case\s+createStep[\s\S]*case\s+updateStep[\s\S]*case\s+deleteStep[\s\S]*case\s+reorderStep[\s\S]*case\s+addIngredient[\s\S]*case\s+deleteIngredient[\s\S]*case\s+replaceOutputUses[\s\S]*case\s+deleteRecipe/,
    /func\s+plan\(_\s+action:\s+RecipeEditorAction\)\s+throws\s+->\s+RecipeEditorMutationPlan/,
    /switch\s+action[\s\S]*case\s+\.save[\s\S]*case\s+\.createStep[\s\S]*case\s+\.updateStep[\s\S]*case\s+\.deleteStep[\s\S]*case\s+\.reorderStep[\s\S]*case\s+\.addIngredient[\s\S]*case\s+\.deleteIngredient[\s\S]*case\s+\.replaceOutputUses[\s\S]*case\s+\.deleteRecipe/,
    /case\s+\.save[\s\S]*RecipeWriteRequests\.createRecipe\s*\(/,
    /case\s+\.save[\s\S]*RecipeWriteRequests\.updateRecipe\s*\(/,
    /case\s+\.save[\s\S]*NativeQueuedMutation\.recipeCreate\s*\(/,
    /case\s+\.save[\s\S]*NativeQueuedMutation\.recipeUpdate\s*\(/,
    /case\s+\.deleteRecipe[\s\S]*RecipeWriteRequests\.deleteRecipe\s*\(/,
    /case\s+\.deleteRecipe[\s\S]*NativeQueuedMutation\.recipeDelete\s*\(/,
    /case\s+\.createStep[\s\S]*RecipeStepRequests\.createStep\s*\(/,
    /case\s+\.createStep[\s\S]*NativeQueuedMutation\.recipeStepCreate\s*\(/,
    /case\s+\.updateStep[\s\S]*RecipeStepRequests\.updateStep\s*\(/,
    /case\s+\.updateStep[\s\S]*NativeQueuedMutation\.recipeStepUpdate\s*\(/,
    /case\s+\.deleteStep[\s\S]*RecipeStepRequests\.deleteStep\s*\(/,
    /case\s+\.deleteStep[\s\S]*NativeQueuedMutation\.recipeStepDelete\s*\(/,
    /case\s+\.reorderStep[\s\S]*RecipeStepRequests\.reorderStep\s*\(/,
    /case\s+\.reorderStep[\s\S]*NativeQueuedMutation\.recipeStepReorder\s*\(/,
    /case\s+\.addIngredient[\s\S]*RecipeStepRequests\.createIngredient\s*\(/,
    /case\s+\.addIngredient[\s\S]*NativeQueuedMutation\.recipeIngredientAdd\s*\(/,
    /case\s+\.deleteIngredient[\s\S]*RecipeStepRequests\.deleteIngredient\s*\(/,
    /case\s+\.deleteIngredient[\s\S]*NativeQueuedMutation\.recipeIngredientDelete\s*\(/,
    /case\s+\.replaceOutputUses[\s\S]*RecipeStepRequests\.replaceOutputUses\s*\(/,
    /case\s+\.replaceOutputUses[\s\S]*NativeQueuedMutation\.recipeOutputUsesReplace\s*\(/,
    /queuedWork\s*\(\s*count:\s*[\s\S]*?,\s*oldestClientMutationID:\s*[\s\S]*?\)/
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeEditorView.swift" => [
    /struct\s+RecipeEditorView:\s+View/,
    /RecipeEditorViewModel/,
    /ConfirmationDialog/,
    /TextField/,
    /TextEditor/,
    /Stepper/
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "WKWebView",
  "className",
  "tailwind",
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

def swift_contract_source(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
    .gsub(/"(?:\\.|[^"\\])*"/m, "\"\"")
end

missing_files = REQUIRED_FILES.reject { |path| ROOT.join(path).file? }
fail_check("missing recipe editor surface files: #{missing_files.join(", ")}") unless missing_files.empty?

REQUIRED_TOKENS.each do |relative_path, tokens|
  content = swift_contract_source(ROOT.join(relative_path).read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required recipe editor tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

REQUIRED_PATTERNS.each do |relative_path, patterns|
  content = swift_contract_source(ROOT.join(relative_path).read)
  missing_patterns = patterns.reject { |pattern| content.match?(pattern) }
  fail_check("#{relative_path} missing required recipe editor structures: #{missing_patterns.map(&:inspect).join(", ")}") unless missing_patterns.empty?
end

forbidden_hits = REQUIRED_FILES.flat_map do |relative_path|
  content = swift_contract_source(ROOT.join(relative_path).read)
  FORBIDDEN_TOKENS.select { |token| content.include?(token) }.map { |token| "#{relative_path} contains #{token}" }
end
fail_check("forbidden recipe editor tokens: #{forbidden_hits.join(", ")}") unless forbidden_hits.empty?

platform_navigation = swift_contract_source(ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read)
[
  "RecipeEditorView(",
  "RecipeEditorViewModel",
  "recipeEditor"
].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless platform_navigation.include?(token)
end

puts "recipe editor surfaces contract ok"
