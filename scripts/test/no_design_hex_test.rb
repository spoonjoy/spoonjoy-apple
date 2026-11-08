# frozen_string_literal: true

# Run: ruby scripts/test/no_design_hex_test.rb
#
# Spoonjoy's colours have one source, ouro-ui-core's cookbook theme, which reaches the app through OuroHX. A hex
# literal in the app's design folder is a value copied by hand that drifts when web changes, so none is allowed.
require "minitest/autorun"

class NoDesignHexTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  DESIGN = File.join(ROOT, "Apps/Spoonjoy/Shared/Design")
  HEX = /0x[0-9A-Fa-f]{6}\b|#[0-9A-Fa-f]{6}\b/

  def test_design_folder_has_no_hex_colour_literals
    offenders = Dir.glob(File.join(DESIGN, "**/*.swift")).sort.flat_map do |path|
      File.readlines(path).each_with_index.select { |line, _| line.match?(HEX) }.map do |line, index|
        "#{path.delete_prefix("#{ROOT}/")}:#{index + 1}: #{line.strip}"
      end
    end
    assert_empty offenders, "Take these colours from OuroTokens.cookbook.extras instead:\n#{offenders.join("\n")}"
  end

  def test_the_pattern_catches_both_spellings
    assert_match HEX, "webColor(0x1E1C19)"
    assert_match HEX, "// #b9854b"
    refute_match HEX, "Radius.cover = 4"
  end
end
