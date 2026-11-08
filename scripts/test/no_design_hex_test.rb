# frozen_string_literal: true

# Run: ruby scripts/test/no_design_hex_test.rb
#
# Spoonjoy's colours have one source, ouro-ui-core's cookbook theme, which reaches the app through OuroHX. A hex
# literal in the app's design folder is a value copied by hand that drifts when web changes, so none is allowed. Nor is
# an opacity applied to a palette colour in the theme: web's translucent colours (`--sj-border`, `--sj-on-photo-muted`)
# are tokens of their own.
require "minitest/autorun"

class NoDesignHexTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  DESIGN = File.join(ROOT, "Apps/Spoonjoy/Shared/Design")
  HEX = /0x[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{6}\b/
  THEME = File.join(DESIGN, "KitchenTableTheme.swift")
  # Native-only shading web has no token for. Adding one here is a deliberate choice, not a copied web value.
  NATIVE_ONLY = {
    "foldShadow" => "the crease shade at a spread's fold",
    "selectionWash" => "the brass wash behind a selected row",
    "ruleSoft" => "a fainter rule inside a panel"
  }.freeze

  # The rule covers the theme's colour definitions (`static let`); a view fading a rule while drawing is not a colour.
  # A palette colour is one a cookbook token backs: a `Day`/`Night` member, or a theme colour built from them.
  def self.palette_names(source)
    members = source.scan(/static let (\w+) = cookbook(?:Day|Night)\(/).flatten
    themed = source.scan(/static let (\w+) = dynamic\(Day\.\w+, Night\.\w+\)/).flatten
    members.flat_map { |name| ["Day.#{name}", "Night.#{name}"] } + themed
  end

  def self.opacity_offenders(source)
    names = palette_names(source).sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }
    pattern = /(?<![\w.])(?:#{names.join("|")})\.opacity\(/
    source.lines.each_with_index.select { |line, _| line.match?(/\A\s*static let /) && line.match?(pattern) }.reject do |line, _|
      NATIVE_ONLY.keys.any? { |name| line.match?(/static let #{name} =/) }
    end.map { |line, index| "#{index + 1}: #{line.strip}" }
  end

  def test_design_folder_has_no_hex_colour_literals
    offenders = Dir.glob(File.join(DESIGN, "**/*.swift")).sort.flat_map do |path|
      File.readlines(path).each_with_index.select { |line, _| line.match?(HEX) }.map do |line, index|
        "#{path.delete_prefix("#{ROOT}/")}:#{index + 1}: #{line.strip}"
      end
    end
    assert_empty offenders, "Take these colours from OuroTokens.cookbook.extras instead:\n#{offenders.join("\n")}"
  end

  def test_theme_applies_no_opacity_to_a_palette_colour
    offenders = self.class.opacity_offenders(File.read(THEME))
    assert_empty offenders, "Use the translucent cookbook token (sjBorder, sjBorderStrong, sjOnPhotoMuted, ...) instead:\n#{offenders.join("\n")}"
  end

  def test_the_opacity_rule_catches_hand_derived_colours
    source = <<~SWIFT
      static let charcoal = cookbookDay(.sjCharcoal)
      static let brass = dynamic(Day.brass, Night.brassNight)
      static let hairline = dynamic(Day.charcoal.opacity(0.18), Night.boneNight.opacity(0.16))
      static let wash = brass.opacity(0.09)
      static let selectionWash = brass.opacity(0.09)
      static let overlay = Color.black.opacity(0.28)
    SWIFT
    assert_equal ["3: static let hairline = dynamic(Day.charcoal.opacity(0.18), Night.boneNight.opacity(0.16))",
                  "4: static let wash = brass.opacity(0.09)"], self.class.opacity_offenders(source)
  end

  def test_the_pattern_catches_both_spellings
    assert_match HEX, "webColor(0x1E1C19)"
    assert_match HEX, "// #b9854b"
    refute_match HEX, "Radius.cover = 4"
  end
end
