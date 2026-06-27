#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

def uncommented_swift(content)
  content
    .gsub(%r{/\*.*?\*/}m, "")
    .gsub(%r{//.*$}, "")
end

def read_relative(path)
  ROOT.join(path).read
end

failures = []
sharing_core = ROOT.join("Sources/SpoonjoyCore/Features/Sharing/NativeSharePayload.swift")
if sharing_core.file?
  content = uncommented_swift(sharing_core.read)
  required_tokens = [
    "NativeSharePayload",
    "NativeShareSurfaceCatalog",
    "NativePublicShareRoutePolicy",
    "publicURL(for route: AppRoute)",
    "case .recipeDetail",
    "case .cookbookDetail",
    "privateTransfer",
    "spoonjoy.app",
    "return nil"
  ]
  missing_tokens = required_tokens.reject { |token| content.include?(token) }
  failures << "#{sharing_core.relative_path_from(ROOT)} missing required sharing tokens: #{missing_tokens.join(", ")}" unless missing_tokens.empty?
else
  failures << "missing Sources/SpoonjoyCore/Features/Sharing/NativeSharePayload.swift"
end

share_actions_path = "Apps/Spoonjoy/Shared/AppShell/ShareActions.swift"
share_actions = uncommented_swift(read_relative(share_actions_path))
if share_actions.include?("private var shareURL") || share_actions.include?("components.scheme = \"https\"")
  failures << "#{share_actions_path} must delegate to NativeSharePayload/NativePublicShareRoutePolicy instead of synthesizing HTTPS URLs locally"
end

private_route_cases = [
  "case .shoppingList",
  "case .capture",
  "case .settings",
  "case .recipeEditor",
  "case .recipeCoverControls",
  "case .unknownLink"
]
private_hits = private_route_cases.select { |token| share_actions.include?(token) }
failures << "#{share_actions_path} still contains public-share cases for private/native-only routes: #{private_hits.join(", ")}" unless private_hits.empty?

recipe_detail_path = "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift"
recipe_detail = uncommented_swift(read_relative(recipe_detail_path))
if recipe_detail.include?("ShareLink(item: viewModel.actions.shareURL)")
  failures << "#{recipe_detail_path} must use a typed NativeSharePayload instead of raw RecipeDetailActions.shareURL"
end

recipe_core_path = "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
recipe_core = uncommented_swift(read_relative(recipe_core_path))
if recipe_core.include?("shareURL:")
  failures << "#{recipe_core_path} must expose typed sharing payload metadata instead of a raw shareURL-only action"
end

forbidden_surface_tokens = [
  "MFMailComposeViewController",
  "MessageCompose",
  "mailto:",
  "RecipeComments",
  "SocialFeed",
  "MessagesShare",
  "MailShare",
  "commentPayload",
  "feedPayload",
  "messagePayload"
]
scan_paths = [
  "Apps/Spoonjoy/Shared/AppShell/ShareActions.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Sources/SpoonjoyCore/Features/RecipeCatalog/RecipeDetailScreenViewModel.swift"
]
scan_paths << sharing_core.relative_path_from(ROOT).to_s if sharing_core.file?
forbidden_hits = scan_paths.flat_map do |path|
  content = uncommented_swift(read_relative(path))
  forbidden_surface_tokens.select { |token| content.include?(token) }.map { |token| "#{path} contains #{token}" }
end
failures << "forbidden invented sharing/social surface tokens: #{forbidden_hits.join(", ")}" unless forbidden_hits.empty?

if failures.empty?
  puts "native sharing surfaces contract ok"
else
  warn failures.map { |failure| "FAIL: #{failure}" }.join("\n")
  exit 1
end
