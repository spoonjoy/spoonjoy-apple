#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

options = {}
OptionParser.new do |parser|
  parser.on("--artifact-root PATH") { |value| options[:artifact_root] = Pathname.new(value).expand_path }
  parser.on("--name NAME") { |value| options[:name] = value }
  parser.on("--results-jsonl PATH") { |value| options[:results_path] = Pathname.new(value).expand_path }
  parser.on("--checkpoint PATH") { |value| options[:checkpoint_path] = Pathname.new(value).expand_path }
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

artifact_root = options.fetch(:artifact_root) { fail_check("missing --artifact-root") }
name = options.fetch(:name) { fail_check("missing --name") }
results_path = options.fetch(:results_path) { fail_check("missing --results-jsonl") }
checkpoint_path = options.fetch(:checkpoint_path) { fail_check("missing --checkpoint") }
fail_check("missing #{results_path}") unless results_path.file?
fail_check("missing #{checkpoint_path}") unless checkpoint_path.file?

rows = results_path.readlines.map.with_index do |line, index|
  JSON.parse(line)
rescue JSON::ParserError => error
  fail_check("#{results_path} line #{index + 1} is invalid JSON: #{error.message}")
end
matching_rows = rows.select { |row| row["name"] == name }
fail_check("#{results_path} must contain exactly one row for #{name}") unless matching_rows.length == 1
row = matching_rows.first

canonical_root = name == "kitchen" ? artifact_root : artifact_root.join("screenshot-routes", name)
fail_check("#{name} artifactRoot is not canonical") unless Pathname.new(row.fetch("artifactRoot", "")).expand_path == canonical_root
fail_check("#{name} row is not a clean pass") unless row["status"] == "pass" && row["blocked"] == false && row["missingDesignReview"] == false

expected = {
  "designReview" => canonical_root.join("design-review.json"),
  "iosScreenshot" => canonical_root.join("screenshots/ios-mobile.png"),
  "iosTabletScreenshot" => canonical_root.join("screenshots/ios-tablet.png"),
  "macosScreenshot" => canonical_root.join("screenshots/macos-desktop.png")
}

validate_artifact = lambda do |field, path, artifact|
  fail_check("#{name} missing #{field} metadata") unless artifact.is_a?(Hash)
  fail_check("#{name} #{field} path is not canonical") unless Pathname.new(artifact.fetch("path", "")).expand_path == path
  fail_check("#{name} #{field} is a symlink") if path.symlink?
  fail_check("#{name} #{field} is missing") unless path.file?
  real_path = path.realpath
  root_prefix = artifact_root.realpath.to_s + File::SEPARATOR
  fail_check("#{name} #{field} resolves outside artifact root") unless real_path.to_s.start_with?(root_prefix)
  bytes = path.size
  fail_check("#{name} #{field} is empty") unless bytes.positive?
  fail_check("#{name} #{field} byte count changed") unless artifact["bytes"] == bytes
  fail_check("#{name} #{field} digest changed") unless artifact["sha256"] == Digest::SHA256.file(path).hexdigest
end
expected.each { |field, path| validate_artifact.call(field, path, row[field]) }

design_review_manifest = JSON.parse(expected.fetch("designReview").read)
proof_paths = design_review_manifest.fetch("accessibilityProofArtifacts", [])
proof_metadata = row["accessibilityProofs"]
fail_check("#{name} accessibilityProofs must match design review") unless proof_metadata.is_a?(Array) && proof_metadata.length == proof_paths.length
proof_paths.zip(proof_metadata).each_with_index do |(relative_path, metadata), index|
  fail_check("#{name} accessibility proof path must be relative") if Pathname.new(relative_path).absolute?
  canonical_path = canonical_root.join(relative_path).cleanpath
  fail_check("#{name} accessibility proof resolves outside route root") unless canonical_path.to_s.start_with?(canonical_root.to_s + File::SEPARATOR)
  validate_artifact.call("accessibilityProofs[#{index}]", canonical_path, metadata)
end

%w[iosScreenshot iosTabletScreenshot macosScreenshot].each do |field|
  path = Pathname.new(row.fetch(field).fetch("path"))
  header = path.binread(24)
  fail_check("#{name} #{field} is not a PNG") unless header.start_with?(PNG_SIGNATURE) && header.bytesize >= 24
  width, height = header.byteslice(16, 8).unpack("NN")
  fail_check("#{name} #{field} has invalid dimensions") unless width.positive? && height.positive?
end

design_review = canonical_root.join("design-review.json")
fail_check("#{name} has conflicting blocker evidence") if canonical_root.join("design-review-blocked.json").exist?
unless system("ruby", ROOT.join("scripts/validate-design-review.rb").to_s, design_review.to_s, out: File::NULL, err: File::NULL)
  fail_check("#{name} design review or accessibility proof is invalid")
end

checkpoint = JSON.parse(checkpoint_path.read)
fail_check("checkpoint schema must be 2") unless checkpoint["schemaVersion"] == 2
digests = checkpoint["completedRouteDigests"]
fail_check("checkpoint completedRouteDigests must be an object") unless digests.is_a?(Hash)
row_digest = Digest::SHA256.hexdigest(JSON.generate(row))
fail_check("#{name} row digest does not match checkpoint") unless digests[name] == row_digest

puts "native route evidence ok: #{name}"
