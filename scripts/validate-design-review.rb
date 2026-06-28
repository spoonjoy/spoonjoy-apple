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

VALID_ROUTES = ["kitchen", "settings"].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def validate_settings_proof!(manifest_path, proof_relative_path, visual_focus)
  fail_check("#{manifest_path} settingsSurfaceProofArtifacts entries must be relative paths") if proof_relative_path.start_with?("/")
  proof_path = manifest_path.dirname.join(proof_relative_path).cleanpath
  fail_check("#{manifest_path} missing settings screenshot proof artifact #{proof_relative_path}") unless proof_path.file?
  proof = JSON.parse(proof_path.read)
  fail_check("#{proof_path} must contain a JSON object") unless proof.is_a?(Hash)
  fail_check("#{proof_path} route must be settings") unless proof["route"] == "settings"
  fail_check("#{proof_path} visualFocus must be #{visual_focus}") unless proof["visualFocus"] == visual_focus
  fail_check("#{proof_path} source must be SettingsView") unless proof["source"] == "SettingsView"
  sections = proof["visibleSections"]
  fail_check("#{proof_path} visibleSections must be an array") unless sections.is_a?(Array)
  required_sections = if visual_focus == "notifications"
                        ["Notifications", "Device Notifications", "APNs Delivery", "Notification Sync"]
                      else
                        ["Profile", "Security"]
                      end
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{proof_path} visibleSections missing required #{visual_focus} sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
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

route = manifest["screenshotRoute"]
fail_check("#{path} missing screenshotRoute") if route.nil?
fail_check("#{path} screenshotRoute has invalid type") unless route.is_a?(String)
fail_check("#{path} screenshotRoute must be one of #{VALID_ROUTES.join(", ")}") unless VALID_ROUTES.include?(route)

case route
when "kitchen"
  fail_check("#{path} kitchenSignedInSurface must be true for kitchen captures") unless manifest["kitchenSignedInSurface"] == true
  seed_account_id = manifest["kitchenSeedAccountID"]
  fail_check("#{path} kitchenSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
when "settings"
  fail_check("#{path} settingsSignedInSurface must be true for settings captures") unless manifest["settingsSignedInSurface"] == true
  seed_account_id = manifest["settingsSeedAccountID"]
  fail_check("#{path} settingsSeedAccountID must be a non-empty string") unless seed_account_id.is_a?(String) && !seed_account_id.empty?
  sections = manifest["settingsSections"]
  fail_check("#{path} settingsSections must be an array") unless sections.is_a?(Array)
  visual_focus = manifest["settingsVisualFocus"]
  fail_check("#{path} settingsVisualFocus must be profile or notifications") unless ["profile", "notifications"].include?(visual_focus)
  proof_artifacts = manifest["settingsSurfaceProofArtifacts"]
  fail_check("#{path} settingsSurfaceProofArtifacts must be an array") unless proof_artifacts.is_a?(Array)
  fail_check("#{path} settingsSurfaceProofArtifacts must include iOS and macOS proof artifacts") unless proof_artifacts.length >= 2
  required_sections = if visual_focus == "notifications"
                        fail_check("#{path} settingsNotificationAPNsSurface must be true for settings/APNs captures") unless manifest["settingsNotificationAPNsSurface"] == true
                        ["Notifications", "Device Notifications", "APNs Delivery", "Notification Sync"]
                      else
                        fail_check("#{path} settingsProfileSurface must be true for profile settings captures") unless manifest["settingsProfileSurface"] == true
                        ["Profile", "Security"]
                      end
  missing_sections = required_sections.reject { |section| sections.include?(section) }
  fail_check("#{path} settingsSections missing required #{visual_focus} sections: #{missing_sections.join(", ")}") unless missing_sections.empty?
  proof_artifacts.each do |proof_relative_path|
    fail_check("#{path} settingsSurfaceProofArtifacts entries must be strings") unless proof_relative_path.is_a?(String) && !proof_relative_path.empty?
    validate_settings_proof!(path, proof_relative_path, visual_focus)
  end
end

puts "design review ok"
