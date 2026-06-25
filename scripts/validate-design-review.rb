#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

REQUIRED_FIELDS = [
  "mobileScreenshot",
  "desktopScreenshot",
  "dynamicType",
  "voiceOverLabels",
  "keyboardNavigation",
  "reduceMotion",
  "contrast",
  "kitchenTableHierarchy",
  "noOverlap"
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

path = Pathname.new(ARGV.fetch(0) { fail_check("usage: validate-design-review.rb <design-review.json>") })
fail_check("missing #{path}") unless path.file?

manifest = JSON.parse(path.read)
fail_check("#{path} must contain a JSON object") unless manifest.is_a?(Hash)

missing_fields = REQUIRED_FIELDS.reject { |field| manifest.key?(field) }
fail_check("#{path} missing required fields: #{missing_fields.join(", ")}") unless missing_fields.empty?

non_boolean_fields = REQUIRED_FIELDS.reject { |field| [true, false].include?(manifest[field]) }
fail_check("#{path} fields must be booleans: #{non_boolean_fields.join(", ")}") unless non_boolean_fields.empty?

blockers = manifest.fetch("blockers", [])
fail_check("#{path} blockers must be an array") unless blockers.is_a?(Array)
fail_check("#{path} blockers must be empty; runtime blockers belong in design-review-blocked.json") unless blockers.empty?

false_fields = REQUIRED_FIELDS.select { |field| manifest[field] == false }
fail_check("#{path} false fields are not valid in design-review.json: #{false_fields.join(", ")}") unless false_fields.empty?

puts "design review ok"
