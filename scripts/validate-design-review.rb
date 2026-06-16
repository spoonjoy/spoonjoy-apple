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

blockers.each_with_index do |blocker, index|
  fail_check("#{path} blocker #{index} must be an object") unless blocker.is_a?(Hash)

  {
    "capability" => String,
    "command" => String,
    "timeoutSeconds" => Integer,
    "outputPath" => String
  }.each do |key, expected_class|
    value = blocker[key]
    fail_check("#{path} blocker #{index} missing #{key}") if value.nil?
    fail_check("#{path} blocker #{index} #{key} must be #{expected_class}") unless value.is_a?(expected_class)
    fail_check("#{path} blocker #{index} #{key} must not be empty") if value.respond_to?(:empty?) && value.empty?
  end
end

false_fields = REQUIRED_FIELDS.select { |field| manifest[field] == false }
fail_check("#{path} false fields require at least one blocker: #{false_fields.join(", ")}") if false_fields.any? && blockers.empty?

puts "design review ok"
