#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

ASSET_ROOT = ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets")
RECIPE_COVER_IMAGE = ROOT.join("Apps/Spoonjoy/Shared/Components/RecipeCoverImage.swift")

SURFACE_SOURCES = [
  "Apps/Spoonjoy/Shared/Views/KitchenView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipesView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
  "Apps/Spoonjoy/Shared/Views/ProfileView.swift",
  "Apps/Spoonjoy/Shared/Views/SearchView.swift",
  "Apps/Spoonjoy/Shared/Views/SpoonCookLogView.swift"
].map { |relative| ROOT.join(relative) }.freeze

PROVENANCE_SOURCES = [
  "Sources/SpoonjoyCore/Features/Covers/RecipeCoverControlsViewModel.swift",
  *SURFACE_SOURCES.map { |path| path.relative_path_from(ROOT).to_s }
].map { |relative| ROOT.join(relative) }.uniq.freeze

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

missing_files = ([RECIPE_COVER_IMAGE] + SURFACE_SOURCES + PROVENANCE_SOURCES).reject(&:file?)
fail_check("missing image policy source files: #{missing_files.map { |path| relative(path) }.join(", ")}") unless missing_files.empty?

failures = []

fallback_assets = Dir.glob(ASSET_ROOT.join("RecipeFallback*.imageset").to_s).map { |path| relative(path) }.sort
unless fallback_assets.empty?
  failures << "remove bundled fake/default recipe fallback assets: #{fallback_assets.join(", ")}"
end

cover_source = uncommented_swift(RECIPE_COVER_IMAGE.read)
required_cover_tokens = [
  "struct KitchenTableNoPhotoView",
  "missingSubtitle",
  "Photo not added",
  "accessibilityLabel"
]
missing_cover_tokens = required_cover_tokens.reject { |token| cover_source.include?(token) }
unless missing_cover_tokens.empty?
  failures << "#{relative(RECIPE_COVER_IMAGE)} must expose an authored no-photo state: #{missing_cover_tokens.join(", ")}"
end

banned_cover_tokens = {
  "fallbackFoodAssetName" => "title-hash food fallback makes missing media look real",
  "loadingFallbackAssetName" => "loading/error states must not swap in fake food",
  "bundledCover(" => "bundled food covers hide missing media",
  "assetName:" => "cover callers should not provide fallback image assets",
  "RecipeFallback" => "fallback recipe assets are not product media",
  "ForEach(0..<4" => "decorative stripe placeholders read as fake/generated food media",
  "fork.knife.circle" => "missing media should not use food-ish placeholder glyphs",
  "LinearGradient(" => "missing media should be an honest quiet panel, not a fake hero image"
}.freeze
banned_cover_tokens.each do |token, reason|
  next unless cover_source.include?(token)

  failures << "#{relative(RECIPE_COVER_IMAGE)} contains #{token.inspect}: #{reason}"
end

surface_token_failures = []
SURFACE_SOURCES.each do |path|
  content = uncommented_swift(path.read)
  relative_path = relative(path)

  {
    "RecipeCoverImage.bundledAssetName" => "real routes must not synthesize covers from local bundled assets",
    "fallbackFoodAssetName" => "real routes must not synthesize covers from recipe titles",
    "fallbackAssetName" => "search/list thumbnails need honest no-photo states, not fallback food assets",
    "assetName:" => "RecipeCoverImage call sites should pass URL/title/subtitle only",
    "RecipeFallback" => "fallback recipe assets are not product media"
  }.each do |token, reason|
    content.lines.each_with_index do |line, index|
      next unless line.include?(token)

      surface_token_failures << "#{relative_path}:#{index + 1}: #{reason}: #{line.strip}"
    end
  end

  content.lines.each_with_index do |line, index|
    stripped = line.strip
    if stripped.match?(/subtitle:\s*(?:recipe|row)\.coverProvenanceLabel/)
      surface_token_failures << "#{relative_path}:#{index + 1}: cover provenance should not be row subtitle noise: #{stripped}"
    end
    if stripped.match?(/Text\(\s*coverProvenanceLabel\s*\)/)
      surface_token_failures << "#{relative_path}:#{index + 1}: cover provenance should not be repeated as visible row text: #{stripped}"
    end
  end
end
failures << "surface image/no-photo policy failed:\n- #{surface_token_failures.join("\n- ")}" unless surface_token_failures.empty?

provenance_failures = []
PROVENANCE_SOURCES.each do |path|
  content = uncommented_swift(path.read)
  relative_path = relative(path)
  ["Chef photo", "Imported photo", "Editorialized chef photo"].each do |label|
    content.lines.each_with_index do |line, index|
      next unless line.include?(label)

      provenance_failures << "#{relative_path}:#{index + 1}: replace production-facing #{label.inspect} with quieter source language or hide it"
    end
  end
end
failures << "production-facing provenance labels failed:\n- #{provenance_failures.join("\n- ")}" unless provenance_failures.empty?

fail_check("native image policy contract failed:\n- #{failures.join("\n- ")}") unless failures.empty?

puts "native image policy contract ok"
