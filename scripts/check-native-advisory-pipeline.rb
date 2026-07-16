#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
EXPECTED_SCANNER_VERSION = "0.9.3"
EXPECTED_SCANNER_SHA256 = "81c8766c71e47d0d28a0f98c7eed028539f21a6ea3cd8f685eb6f42333c9b4e9"
EXPECTED_ADVISORY_DB_SHA = "32a64d01964828d2f71ba17fb623a73142e03a3d"

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def run!(*args)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: ROOT.to_s)
  fail_check("#{args.join(" ")} failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?
  stdout
end

def require_file(path)
  fail_check("#{path.relative_path_from(ROOT)} is missing") unless path.file?
  path.read
end

gemfile = require_file(ROOT.join("Gemfile"))
gemfile_lock = require_file(ROOT.join("Gemfile.lock"))
policy = require_file(ROOT.join("security/native-advisory-pipeline.yml"))
allowlist = require_file(ROOT.join("security/native-advisory-allowlist.yml"))
scanner = ROOT.join("scripts/scan-ruby-advisories.rb")
contract = ROOT.join("scripts/check-native-advisory-pipeline.rb")
workflow = require_file(ROOT.join(".github/workflows/native.yml"))
local_matrix = require_file(ROOT.join("scripts/validate-native-local.sh"))
docs = require_file(ROOT.join("docs/native-advisory-policy.md"))

fail_check("Gemfile must pin bundler-audit #{EXPECTED_SCANNER_VERSION}") unless gemfile.include?("gem \"bundler-audit\", \"#{EXPECTED_SCANNER_VERSION}\"")
fail_check("Gemfile.lock must lock bundler-audit #{EXPECTED_SCANNER_VERSION}") unless gemfile_lock.include?("bundler-audit (#{EXPECTED_SCANNER_VERSION})")
fail_check("Gemfile.lock must lock bundler-audit transitive thor dependency") unless gemfile_lock.match?(/^\s+thor \(/)
fail_check("policy must pin scanner version") unless policy.include?("version: #{EXPECTED_SCANNER_VERSION}")
fail_check("policy must pin scanner gem SHA256") unless policy.include?("gem_sha256: #{EXPECTED_SCANNER_SHA256}")
fail_check("policy must pin ruby-advisory-db SHA") unless policy.include?("ref: #{EXPECTED_ADVISORY_DB_SHA}")
fail_check("allowlist must use explicit advisories key") unless allowlist.match?(/^advisories:/)
fail_check("policy doc must document expiring allowlists") unless docs.include?("expires_on") && docs.include?("fail closed")
fail_check("scanner wrapper is missing") unless scanner.file?
scanner_source = scanner.read
[
  "--database",
  "--no-update",
  "--gemfile-lock",
  "git\", \"-C\", dir.to_s, \"fetch\"",
  "actionable_findings",
  "scanner_failed",
  "missing_lockfile"
].each do |token|
  fail_check("scanner wrapper missing #{token}") unless scanner_source.include?(token)
end

[
  "ruby-advisory-scan:",
  "name: Ruby advisory scan",
  "ruby/setup-ruby@8e41b362d2589a22a44c1cfa214b3c83052c195b # v1",
  "bundler-cache: true",
  "ruby scripts/check-native-advisory-pipeline.rb",
  "ruby scripts/scan-ruby-advisories.rb"
].each do |token|
  fail_check("native workflow missing #{token}") unless workflow.include?(token)
end

[
  "scripts/scan-ruby-advisories.rb",
  "scripts/check-native-advisory-pipeline.rb",
  "matrix-ruby-advisory-scan.log"
].each do |token|
  fail_check("local validation matrix missing #{token}") unless local_matrix.include?(token)
end

run!("ruby", "-c", scanner)
run!("ruby", "-c", contract)
run!("ruby", scanner, "--self-test-fixtures")

puts "native advisory pipeline contract ok"
