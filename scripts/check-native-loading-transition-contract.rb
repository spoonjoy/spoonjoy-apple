#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

LOADING_COMPONENT = ROOT.join("Apps/Spoonjoy/Shared/Components/KitchenTableLoadingStateView.swift")
OFFLINE_STATUS = ROOT.join("Apps/Spoonjoy/Shared/Components/OfflineStatusView.swift")
SEARCH_VIEW = ROOT.join("Apps/Spoonjoy/Shared/Views/SearchView.swift")

ROUTE_SOURCES = [
  "Apps/Spoonjoy/Shared/Views/RecipeDetailView.swift",
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift",
  "Apps/Spoonjoy/Shared/Views/CookbooksView.swift",
  "Apps/Spoonjoy/Shared/Views/ProfileView.swift",
  "Apps/Spoonjoy/Shared/Views/RecipeCoverControlsView.swift"
].map { |relative| ROOT.join(relative) }.freeze

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

missing_sources = ([OFFLINE_STATUS, SEARCH_VIEW] + ROUTE_SOURCES).reject(&:file?)
fail_check("missing loading/transition source files: #{missing_sources.map { |path| relative(path) }.join(", ")}") unless missing_sources.empty?

failures = []

loading_content = LOADING_COMPONENT.file? ? uncommented_swift(LOADING_COMPONENT.read) : ""
loading_required_tokens = [
  "struct KitchenTableLoadingStateView",
  "struct KitchenTableRouteErrorView",
  "@Environment(\\.accessibilityReduceMotion)",
  "ProgressView()",
  "KitchenTableTheme.inkMuted",
  ".transition("
]
loading_missing = loading_required_tokens.reject { |token| loading_content.include?(token) }
loading_missing.unshift("file #{relative(LOADING_COMPONENT)}") unless LOADING_COMPONENT.file?
failures << "#{relative(LOADING_COMPONENT)} missing authored loading/error tokens: #{loading_missing.join(", ")}" unless loading_missing.empty?

route_failures = []
ROUTE_SOURCES.each do |path|
  content = uncommented_swift(path.read)
  relative_path = relative(path)

  route_failures << "#{relative_path} must use KitchenTableLoadingStateView" unless content.include?("KitchenTableLoadingStateView(")
  route_failures << "#{relative_path} must use KitchenTableRouteErrorView" unless content.include?("KitchenTableRouteErrorView(")

  content.lines.each_with_index do |line, index|
    stripped = line.strip
    route_failures << "#{relative_path}:#{index + 1} has raw ProgressView loading chrome" if stripped == "ProgressView()"
    route_failures << "#{relative_path}:#{index + 1} has generic unavailable route copy: #{stripped}" if stripped.match?(/=\s*"[^"]*unavailable[^"]*"/i)
  end
end
failures << "route loading/error contract failed: #{route_failures.join("; ")}" unless route_failures.empty?

search_content = uncommented_swift(SEARCH_VIEW.read)
search_required_tokens = [
  "private var imageLoadingTransaction",
  "accessibilityReduceMotion ? nil",
  "AsyncImage(url: imageURL, transaction: imageLoadingTransaction)",
  "KitchenTableImagePhaseView"
]
search_missing = search_required_tokens.reject { |token| search_content.include?(token) }
failures << "#{relative(SEARCH_VIEW)} missing reduce-motion-aware image loading tokens: #{search_missing.join(", ")}" unless search_missing.empty?

offline_content = uncommented_swift(OFFLINE_STATUS.read)
offline_required_tokens = [
  "quietInformationalForegroundStyle",
  "effectiveProminence == .quiet ? quietInformationalForegroundStyle : KitchenTableTheme.brass",
  "KitchenTableTheme.inkMuted",
  "display.informationalOnly"
]
offline_missing = offline_required_tokens.reject { |token| offline_content.include?(token) }
failures << "#{relative(OFFLINE_STATUS)} missing quiet informational status tokens: #{offline_missing.join(", ")}" unless offline_missing.empty?

fail_check("native loading transition contract failed:\n- #{failures.join("\n- ")}") unless failures.empty?

puts "native loading transition contract ok"
