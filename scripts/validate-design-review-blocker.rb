#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"
require "set"

ROOT = Pathname.new(__dir__).join("..").expand_path
DEFAULT_ARTIFACT_ROOT = ROOT.join("artifacts/apple/native-screenshots")
CAPABILITY_BY_BASENAME = {
  "screenshots-xcode-platform-blocker.json" => "XcodePlatform",
  "screenshots-core-simulator-blocker.json" => "CoreSimulator",
  "screenshots-macos-launch-blocker.json" => "MacOSLaunch"
}.freeze

options = {
  artifact_root: DEFAULT_ARTIFACT_ROOT,
  unit_slug: "capture-native-screenshots"
}

OptionParser.new do |parser|
  parser.banner = "Usage: ruby scripts/validate-design-review-blocker.rb <design-review-blocked.json> --artifact-root PATH --unit-slug SLUG"
  parser.on("--artifact-root PATH", "Artifact root containing design-review-blocked.json") do |path|
    options[:artifact_root] = Pathname.new(path).expand_path
  end
  parser.on("--unit-slug SLUG", "Validation matrix unit slug") do |slug|
    options[:unit_slug] = slug
  end
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def required_skipped_artifacts(unit_slug)
  Set[
    "screenshots/ios-mobile.png",
    "screenshots/macos-desktop.png",
    "design-review.json",
    "apple/#{unit_slug}-accessibility-proof-ios.json",
    "apple/#{unit_slug}-accessibility-proof-macos.json"
  ]
end

path = Pathname.new(ARGV.fetch(0) { fail_check("usage: validate-design-review-blocker.rb <design-review-blocked.json> --artifact-root PATH --unit-slug SLUG") }).expand_path
artifact_root = options.fetch(:artifact_root)
unit_slug = options.fetch(:unit_slug)

fail_check("missing #{path}") unless path.file?
manifest = JSON.parse(path.read)
fail_check("#{path} must contain a JSON object") unless manifest.is_a?(Hash)

required_fields = {
  "blocked" => [TrueClass],
  "capability" => [String],
  "sourceBlockerPath" => [String],
  "skippedArtifacts" => [Array],
  "reason" => [String],
  "ownerAction" => [String]
}
required_fields.each do |field, expected_classes|
  value = manifest[field]
  fail_check("#{path} missing #{field}") if value.nil?
  fail_check("#{path} #{field} has invalid type") unless expected_classes.any? { |klass| value.is_a?(klass) }
  fail_check("#{path} #{field} must not be empty") if value.respond_to?(:empty?) && value.empty?
end
fail_check("#{path} blocked must be true") unless manifest.fetch("blocked") == true

allowed_sources = {
  artifact_root.join("apple/#{unit_slug}-screenshots-xcode-platform-blocker.json").expand_path => "XcodePlatform",
  artifact_root.join("apple/#{unit_slug}-screenshots-core-simulator-blocker.json").expand_path => "CoreSimulator",
  artifact_root.join("apple/#{unit_slug}-screenshots-macos-launch-blocker.json").expand_path => "MacOSLaunch"
}
source_path = Pathname.new(manifest.fetch("sourceBlockerPath")).expand_path
expected_capability = allowed_sources[source_path]
fail_check("#{path} sourceBlockerPath must be a current-run screenshot blocker under #{artifact_root.join("apple")}") if expected_capability.nil?
fail_check("#{path} capability must match #{expected_capability}") unless manifest.fetch("capability") == expected_capability
fail_check("#{path} source blocker is missing: #{source_path}") unless source_path.file?

source_blocker = JSON.parse(source_path.read)
fail_check("#{source_path} must contain a JSON object") unless source_blocker.is_a?(Hash)
{
  "blocked" => [TrueClass],
  "capability" => [String],
  "command" => [String],
  "timeoutSeconds" => [Integer],
  "outputPath" => [String],
  "reason" => [String],
  "ownerAction" => [String]
}.each do |field, expected_classes|
  value = source_blocker[field]
  fail_check("#{source_path} missing #{field}") if value.nil?
  fail_check("#{source_path} #{field} has invalid type") unless expected_classes.any? { |klass| value.is_a?(klass) }
  fail_check("#{source_path} #{field} must not be empty") if value.respond_to?(:empty?) && value.empty?
end
fail_check("#{source_path} blocked must be true") unless source_blocker.fetch("blocked") == true
fail_check("#{source_path} capability must match #{expected_capability}") unless source_blocker.fetch("capability") == expected_capability

skipped_artifacts = Set.new(manifest.fetch("skippedArtifacts"))
fail_check("#{path} skippedArtifacts must exactly name skipped success artifacts") unless skipped_artifacts == required_skipped_artifacts(unit_slug)

skipped_artifacts.each do |relative_artifact|
  artifact_path = artifact_root.join(relative_artifact).cleanpath
  if artifact_path.exist?
    fail_check("#{path} stale success artifact must be absent when blocked: #{relative_artifact}")
  end
end

puts "design review blocker ok"
