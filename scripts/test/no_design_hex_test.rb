# frozen_string_literal: true

# Run: ruby scripts/test/no_design_hex_test.rb
#
# Spoonjoy's colours have one source, ouro-ui-core's cookbook theme, which reaches the app through OuroHX. A hex
# literal in the app's design folder is a value copied by hand that drifts when web changes, so none is allowed. Nor is
# an opacity applied to a palette colour, or to black or white, in the theme: web's translucent colours (`--sj-border`,
# `--sj-on-photo-muted`) are tokens of their own. A definition that runs over several lines is read whole.
require "minitest/autorun"

class NoDesignHexTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  DESIGN = File.join(ROOT, "Apps/Spoonjoy/Shared/Design")
  HEX = /0x[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{6}\b/
  THEME = File.join(DESIGN, "KitchenTableTheme.swift")
  # Native-only shading web has no token for. Adding one here is a deliberate choice, not a copied web value.
  NATIVE_ONLY = {
    # Web's spreads have no fold, and the cookbook's only shadow colour at night (#1d1915) is nearly the night page,
    # so the crease would vanish. It stays black until ouro-ui-core has a fold token (ourostack/ouro-ui-core#71).
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

  DECLARATION = /\A\s*(?:(?:private|fileprivate|internal|public)\s+)?static (?:let|var) /

  # A line without its `//` comment and with its string literals emptied, so brackets in either can't mislead.
  def self.code(line)
    line.gsub(/"(?:[^"\\]|\\.)*"/, '""').sub(%r{//.*}, "")
  end

  # Each static colour definition with the line it starts on, joined with the lines it runs on to while its brackets
  # are open and with the chained calls (`.opacity(...)`) on the lines after it.
  def self.definitions(source)
    lines = source.lines.map { |line| code(line) }
    lines.each_index.select { |index| lines[index].match?(DECLARATION) }.map do |start|
      text = +""
      depth = 0
      index = start
      loop do
        line = lines[index]
        text << " " unless text.empty? || line.lstrip.start_with?(".")
        text << line.strip
        depth += line.count("([{") - line.count(")]}")
        index += 1
        break if index >= lines.length
        next if depth.positive?

        following = lines[index..].find { |candidate| !candidate.strip.empty? }
        break unless following&.lstrip&.start_with?(".")
      end
      [start + 1, text.sub(DECLARATION, "static let ")]
    end
  end

  def self.opacity_offenders(source)
    names = palette_names(source).sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }
    named = /(?<![\w.])(?:#{names.join("|")}|Color\.(?:black|white))\.opacity\(/
    shorthand = /(?<!\w)\.(?:black|white)\.opacity\(|Color\(white:[^)]*opacity:/
    pattern = Regexp.union(named, shorthand)
    definitions(source).select { |_, text| text.match?(pattern) }.reject do |_, text|
      NATIVE_ONLY.keys.any? { |name| text.match?(/\Astatic let #{name} =/) }
    end.map { |number, text| "#{number}: #{text}" }
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
      static let crease = dynamic(
          Day.charcoal,
          Color.black.opacity(0.32)
      )
      static let ruleSoft = hairline.opacity(0.42)
      static let fold = dynamic(liftShadow.light.color, liftShadow.dark.color)
      static let chained = Color.black
          .opacity(0.3)
      static let noted = Day.charcoal // see (web
      private static let scrim = .white.opacity(0.2)
      static var grey = Color(white: 0, opacity: 0.4)
      static let label = Text("(").opacity(1)
    SWIFT
    assert_equal ["3: static let hairline = dynamic(Day.charcoal.opacity(0.18), Night.boneNight.opacity(0.16))",
                  "4: static let wash = brass.opacity(0.09)",
                  "6: static let overlay = Color.black.opacity(0.28)",
                  "7: static let crease = dynamic( Day.charcoal, Color.black.opacity(0.32) )",
                  "13: static let chained = Color.black.opacity(0.3)",
                  "16: static let scrim = .white.opacity(0.2)",
                  "17: static let grey = Color(white: 0, opacity: 0.4)"],
                 self.class.opacity_offenders(source)
  end

  def test_the_pattern_catches_both_spellings
    assert_match HEX, "webColor(0x1E1C19)"
    assert_match HEX, "// #b9854b"
    refute_match HEX, "Radius.cover = 4"
  end
end
