#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_NATIVE_DOC = ROOT.join("docs/native-design-language.md")
DEFAULT_WEB_DOC = ROOT.parent.join("spoonjoy-v2/docs/design-language.md")

options = {
  native_doc: DEFAULT_NATIVE_DOC,
  web_doc: ENV["SPOONJOY_WEB_DESIGN_DOC"]
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
if options[:web_doc]
  options[:web_doc] = Pathname.new(options[:web_doc]).expand_path
elsif DEFAULT_WEB_DOC.file?
  options[:web_doc] = DEFAULT_WEB_DOC
end

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
  "hero/provenance/actions",
  "ingredient receipt",
  "numbered method sections",
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
if web_doc
  fail_check("#{display_path(web_doc)} is missing") if options[:web_doc_explicit] && !web_doc.file?

  if web_doc.file?
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
  end
end

puts "native design language contract ok"
