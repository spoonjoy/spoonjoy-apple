# frozen_string_literal: true

# Usage: ruby scripts/check-layout-audit.rb --artifact-root <dir> --proof <accessibility-proof.json> [--known-findings <file>] [--strict]
#
# Prints the layout audit's findings for one accessibility proof, marking those listed as known for Task 10. Exits 1
# only in strict mode (--strict or SPOONJOY_REQUIRE_LAYOUT_AUDIT=1) when the audit is missing, a measured field is
# missing, or a finding is not listed. Default CI does not run in strict mode yet.
require "optparse"
require_relative "lib/layout_audit_gate"

options = { known_findings: LayoutAuditGate::DEFAULT_KNOWN_FINDINGS, strict: LayoutAuditGate.strict? }
OptionParser.new do |parser|
  parser.on("--artifact-root DIR") { |value| options[:artifact_root] = value }
  parser.on("--proof FILE") { |value| options[:proof] = value }
  parser.on("--known-findings FILE") { |value| options[:known_findings] = value }
  parser.on("--strict") { options[:strict] = true }
end.parse!
abort("usage: check-layout-audit.rb --artifact-root <dir> --proof <file> [--known-findings <file>] [--strict]") unless options[:artifact_root] && options[:proof]

proof = JSON.parse(File.read(options[:proof]))
audit_path = proof["layoutAudit"] && Pathname.new(options[:artifact_root]).join(proof["layoutAudit"])
audit = audit_path&.file? ? JSON.parse(audit_path.read) : nil
result = LayoutAuditGate.evaluate(proof: proof, audit: audit, known: LayoutAuditGate.load_known_findings(options[:known_findings]))

label = "#{proof["platform"]} #{proof["route"]}"
result.errors.each { |error| puts "layout audit #{label}: #{error}" }
result.allowed.each { |finding| puts "layout audit #{label}: known (#{LayoutAuditGate::OWNER}) #{LayoutAuditGate.describe(finding)}" }
result.unexpected.each { |finding| puts "layout audit #{label}: NEW #{LayoutAuditGate.describe(finding)}" }
result.stale.each { |entry| puts "layout audit #{label}: known finding no longer seen: #{entry["kind"]} #{entry["elements"].join(" + ")}" }
verdict = result.passes? ? "pass" : "fail"
puts "layout audit #{label}: #{verdict}#{options[:strict] ? " (strict)" : " (not gating)"}"
exit(1) if options[:strict] && !result.passes?
