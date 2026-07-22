#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "digest"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_NATIVE_DOC = ROOT.join("docs/native-design-language.md")
DEFAULT_WEB_DOC = ROOT.join("docs/source/spoonjoy-v2-design-language.md")
EXPECTED_WEB_DESIGN_SHA256 = "764b9749a614482ac75debefa06547f21fae09d35cb8be38a09a9879d6307dae"
ENV_WEB_DOC = ENV["SPOONJOY_WEB_DESIGN_DOC"]

options = {
  native_doc: DEFAULT_NATIVE_DOC,
  web_doc: ENV_WEB_DOC && !ENV_WEB_DOC.empty? ? ENV_WEB_DOC : DEFAULT_WEB_DOC
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/check-native-design-language.rb [options]"
  parser.on("--native-doc PATH", "Native design-language doc to validate") do |path|
    options[:native_doc] = Pathname.new(path).expand_path
  end
  parser.on("--web-design-doc PATH", "Optional source Spoonjoy web design-language doc") do |path|
    options[:web_doc] = path
    options[:web_doc_explicit] = true
  end
end.parse!

options[:native_doc] = Pathname.new(options[:native_doc]).expand_path
options[:web_doc] = Pathname.new(options[:web_doc]).expand_path

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def display_path(path)
  expanded = Pathname.new(path).expand_path
  if expanded.to_s.start_with?("#{ROOT}/")
    expanded.relative_path_from(ROOT).to_s
  else
    expanded.to_s
  end
end

def assert_file(path)
  fail_check("#{display_path(path)} is missing") unless path.file?
end

def assert_includes(content, phrases, label, path)
  missing = phrases.reject { |phrase| content.include?(phrase) }
  fail_check("#{display_path(path)} missing #{label}: #{missing.join(", ")}") unless missing.empty?
end

native_doc = options.fetch(:native_doc)
assert_file(native_doc)
native_content = native_doc.read

required_headings = [
  "# Spoonjoy Native Apple Design Language",
  "## Source Language",
  "## Invariants To Preserve",
  "## Native Elements That Should Take Over",
  "## SwiftUI Component Translation",
  "## Main Kitchen Navigation",
  "## Anti-Patterns",
  "## Native Design Review Contract",
  "## Native Product Backlog Seeds",
  "## Risk"
]
assert_includes(native_content, required_headings, "required headings", native_doc)

kitchen_table_invariants = [
  "The Kitchen Table",
  "Food leads.",
  "No default cards.",
  "No section cards.",
  "No equal-weight grids",
  "Cookbook hierarchy beats dashboard equality.",
  "Object-specific surfaces.",
  "Rounded corners are semantic.",
  "0 pt",
  "4 pt",
  "8 pt",
  "999 pt",
  "Role-bound color.",
  "Bone",
  "Charcoal",
  "Brass",
  "Tomato",
  "Herb",
  "Photo overlay",
  "Typography has jobs.",
  "Display serif",
  "Body serif",
  "Condensed UI sans",
  "Kitchen-safe interaction.",
  "large targets",
  "high contrast",
  "stable layouts",
  "Dynamic Type",
  "VoiceOver",
  "reduced motion",
  "no tiny clusters"
]
assert_includes(native_content, kitchen_table_invariants, "Kitchen Table invariants", native_doc)

native_takeover_phrases = [
  "`NavigationStack`",
  "`NavigationSplitView`",
  "Native toolbars",
  "`List`",
  "`Section`",
  "`DisclosureGroup`",
  "`swipeActions`",
  "`EditMode`",
  "`sheet`",
  "`confirmationDialog`",
  "`ShareLink`",
  "`.searchable`",
  "Spotlight",
  "App Intents",
  "`Stepper`",
  "`Toggle`",
  "`ProgressView`",
  "`PhotosPicker`"
]
assert_includes(native_content, native_takeover_phrases, "native takeover primitives", native_doc)

surface_contract_phrases = [
  "Kitchen",
  "Recipe Detail",
  "Shopping List",
  "Cook Mode",
  "Search",
  "Capture",
  "Settings",
  "lead food/cookbook/list object",
  "hero/provenance",
  "header yield controls",
  "modal `Save to Cookbook` flow",
  "web-parity `Steps`",
  "per-step `Ingredients`",
  "step-output dependency rows",
  "receipt rows",
  "large check controls",
  "one focused step",
  "persisted progress",
  "native `.searchable` scopes",
  "typed rows",
  "local draft",
  "offline/auth/environment state"
]
assert_includes(native_content, surface_contract_phrases, "native surface contract", native_doc)

kitchen_navigation_phrases = [
  "Main Kitchen Navigation",
  "`Kitchen` -> `/`",
  "`My Recipes` -> `/recipes`",
  "`Saved Recipes` -> `/saved-recipes`",
  "`Cookbooks` -> `/cookbooks`",
  "`Shopping List` -> `/shopping-list`",
  "`Chefs` -> `/chefs`",
  "`Kitchen Search` -> `/search`",
  "compact iPhone tabs are exactly `Kitchen`, `Recipes`, `Saved`, `Cookbooks`, and `Shopping`",
  "Search stays in the trailing `More` menu",
  "Saved Recipes derive from cookbooks owned by the current chef",
  "route matrix covers `kitchen`, `recipes`, `saved-recipes`, `cookbooks`, `shopping-list`, `chefs`, and `search`"
]
assert_includes(native_content, kitchen_navigation_phrases, "kitchen navigation contract", native_doc)

manifest_contract_phrases = [
  "design-review.json",
  "mobileScreenshot",
  "desktopScreenshot",
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap",
  "blockers[]"
]
assert_includes(native_content, manifest_contract_phrases, "design-review manifest schema", native_doc)

anti_patterns = [
  "generic grouped SwiftUI CRUD app",
  "Default cards as decorative containers",
  "Section cards inside page sections",
  "Equal-weight recipe grids",
  "Decorative glass",
  "fake paper",
  "fake leather",
  "ornamental skeuomorphism",
  "custom menu behavior",
  "Rebuilding native sheets"
]
assert_includes(native_content, anti_patterns, "anti-pattern coverage", native_doc)

fail_check("must reference spoonjoy.app, not spoonjoy.com") if native_content.include?("spoonjoy.com")

web_doc = options[:web_doc]
assert_file(web_doc)
actual_web_sha = Digest::SHA256.file(web_doc).hexdigest
unless actual_web_sha == EXPECTED_WEB_DESIGN_SHA256
  fail_check(
    "#{display_path(web_doc)} SHA-256 #{actual_web_sha} does not match expected " \
    "#{EXPECTED_WEB_DESIGN_SHA256}; update #{display_path(native_doc)} and this contract intentionally"
  )
end

web_content = web_doc.read
web_source_markers = [
  "# Spoonjoy Design Language",
  "## Non-Negotiables",
  "Food leads.",
  "No default cards.",
  "No section cards.",
  "No equal-weight grids as the primary experience.",
  "Rounded corners are semantic.",
  "Color is role-bound.",
  "Typography has jobs.",
  "The UI must work in a kitchen."
]
assert_includes(web_content, web_source_markers, "web source design markers", web_doc)

puts "native design language contract ok"
