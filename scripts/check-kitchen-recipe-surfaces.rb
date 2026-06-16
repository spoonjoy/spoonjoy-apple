#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_CONTRACT = ROOT.join("scripts/check-xcode-project-contract.rb")

REQUIRED_FILES = [
  "Apps/Spoonjoy/Shared/Views/KitchenView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
  "Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift",
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
    "RecipeIndex",
    "List",
    "Button",
    "RecipeSummary",
    "RecipeCoverImage(",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift" => [
    "RecipeDetailView",
    "RecipeDetailViewModel",
    "ShareLink",
    "RecipeCoverImage(",
    "provenance",
    "cookbookSpread",
    "ingredientReceipt",
    "methodSections",
    "ForEach",
    "KitchenTableTheme"
  ],
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift" => [
    "CookbooksView",
    "CookbookShelf",
    "CookbookCover",
    "ScrollView",
    "Button",
    "RecipeCoverImage(",
    "KitchenTableTheme"
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
  'Text("Cookbook shelf is next.")'
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

root_shell = ROOT.join("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift").read
[
  "KitchenView(",
  "RecipesView(",
  "RecipeDetailView(",
  "CookbooksView("
].each do |token|
  fail_check("PlatformNavigationView.swift missing #{token}") unless root_shell.include?(token)
end

stdout, stderr, status = Open3.capture3(ROOT.join("scripts/bundle-exec.sh").to_s, "ruby", PROJECT_CONTRACT.to_s, chdir: ROOT.to_s)
fail_check("xcode project contract failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?

puts "kitchen and recipe surfaces contract ok"
