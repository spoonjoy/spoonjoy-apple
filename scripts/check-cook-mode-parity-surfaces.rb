#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

REQUIRED_TOKENS = {
  "Sources/SpoonjoyCore/KitchenState/CookModeProgress.swift" => [
    "scaleFactor",
    "checkedIngredientIDs",
    "checkedStepOutputUseIDs",
    "timerStatesByStepID",
    "starting(recipe:",
    "selectingStep",
    "settingScaleFactor",
    "togglingIngredient",
    "togglingStepOutputUse",
    "settingTimer"
  ],
  "Sources/SpoonjoyCore/AppState/ScreenViewModels.swift" => [
    "CookModeChecklistRow",
    "CookModeTimerViewModel",
    "activeStep",
    "stepProgressLabel",
    "recipeProgressLabel",
    "ingredientChecklistRows",
    "stepOutputChecklistRows",
    "formattedRemainingTime",
    "progressAfterSelectingNext",
    "progressAfterSelectingPrevious"
  ],
  "Sources/SpoonjoyCore/Native/NativeIntentAction.swift" => [
    "continueCookMode"
  ],
  "Apps/Spoonjoy/Shared/Views/CookModeView.swift" => [
    "ScaleSelector",
    "CookModeTimer",
    "Toggle",
    "ingredientChecklistRows",
    "stepOutputChecklistRows",
    "progressAfterTogglingIngredient",
    "progressAfterTogglingStepOutputUse"
  ]
}.freeze

FORBIDDEN_TOKENS = [
  "WKWebView",
  "className",
  "tailwind",
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

REQUIRED_TOKENS.each do |relative_path, tokens|
  path = ROOT.join(relative_path)
  fail_check("missing cook mode surface file: #{relative_path}") unless path.file?

  content = uncommented_swift(path.read)
  missing_tokens = tokens.reject { |token| content.include?(token) }
  fail_check("#{relative_path} missing required cook mode parity tokens: #{missing_tokens.join(", ")}") unless missing_tokens.empty?
end

FORBIDDEN_TOKENS.each do |token|
  offenders = REQUIRED_TOKENS.keys.select do |relative_path|
    uncommented_swift(ROOT.join(relative_path).read).include?(token)
  end
  fail_check("forbidden cook mode token #{token.inspect} found in #{offenders.join(", ")}") unless offenders.empty?
end

puts "cook mode parity surface contract ok"
