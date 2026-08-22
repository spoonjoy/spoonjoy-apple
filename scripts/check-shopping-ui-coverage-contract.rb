#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
ENFORCER = ROOT.join("scripts/enforce-xcode-changed-line-coverage.rb")
BASE_REF = "origin/main"
APP_ROOT = "Apps/Spoonjoy"
EXPLICIT_FILES = [
  "Apps/Spoonjoy/Shared/Views/ShoppingListView.swift",
  "Apps/Spoonjoy/Shared/Components/ReceiptListView.swift",
  "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift"
].freeze

def assert(condition, message)
  raise message unless condition
end

def git_lines(*args)
  stdout, stderr, status = Open3.capture3("git", *args, chdir: ROOT.to_s)
  raise "git #{args.join(" ")} failed: #{stderr}" unless status.success?

  stdout.lines.map(&:chomp).reject(&:empty?)
end

def changed_lines(path)
  output, stderr, status = Open3.capture3(
    "git", "diff", "--unified=0", "--no-ext-diff", "#{BASE_REF}...HEAD", "--", path,
    chdir: ROOT.to_s
  )
  raise "git diff failed for #{path}: #{stderr}" unless status.success?

  output.lines.map do |line|
    match = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
    next unless match

    start = match[1].to_i
    count = match[2] ? match[2].to_i : 1
    (start...(start + count)).to_a
  end.compact.flatten
end

def report(files, uncovered: nil, omit_lines_for: nil)
  {
    "targets" => [{
      "name" => "Spoonjoy iOS",
      "files" => files.map do |path|
        lines = changed_lines(path)
        lines = [] if path == omit_lines_for
        {
          "path" => ROOT.join(path).to_s,
          "lines" => lines.map do |line|
            { "lineNumber" => line, "executionCount" => (path == uncovered&.first && line == uncovered&.last ? 0 : 1) }
          end + [{ "lineNumber" => 1, "executionCount" => 0 }]
        }
      end
    }]
  }
end

def run_enforcer(coverage_path, extra_files: [])
  argv = [
    "ruby", ENFORCER.to_s,
    "--coverage-json", coverage_path.to_s,
    "--base-ref", BASE_REF,
    "--minimum", "100",
    "--app-root", APP_ROOT
  ]
  (EXPLICIT_FILES + extra_files).each { |path| argv.concat(["--file", path]) }
  Open3.capture3(*argv, chdir: ROOT.to_s)
end

assert(ENFORCER.file?, "missing scripts/enforce-xcode-changed-line-coverage.rb")
app_files = git_lines("diff", "--name-only", "#{BASE_REF}...HEAD", "--", APP_ROOT)
  .select { |path| path.end_with?(".swift") }
all_required = (EXPLICIT_FILES + app_files).uniq.sort
assert((app_files - EXPLICIT_FILES).any?, "fixture must exercise --app-root discovery beyond explicit files")

Dir.mktmpdir("shopping-ui-coverage-contract") do |directory|
  root = Pathname.new(directory)
  missing_path = root.join("missing.json")
  _stdout, stderr, status = run_enforcer(missing_path)
  assert(!status.success? && stderr.include?("missing"), "missing coverage JSON must fail clearly")

  complete = root.join("complete.json")
  complete.write(JSON.generate(report(all_required)))
  stdout, stderr, status = run_enforcer(complete)
  assert(status.success?, "complete changed-line coverage failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("100.00%"), "success must report the enforced percentage")

  discovered = (app_files - EXPLICIT_FILES).first
  omitted_file = root.join("omitted-file.json")
  omitted_file.write(JSON.generate(report(all_required - [discovered])))
  _stdout, stderr, status = run_enforcer(omitted_file)
  assert(!status.success? && stderr.include?(discovered), "missing discovered app Swift file must fail by path")

  explicit = EXPLICIT_FILES.first
  missing_lines = root.join("missing-lines.json")
  missing_lines.write(JSON.generate(report(all_required, omit_lines_for: explicit)))
  _stdout, stderr, status = run_enforcer(missing_lines)
  assert(!status.success? && stderr.include?(explicit) && stderr.include?("line"), "missing changed executable-line intersection must fail")

  uncovered_line = changed_lines(explicit).first
  uncovered = root.join("uncovered.json")
  uncovered.write(JSON.generate(report(all_required, uncovered: [explicit, uncovered_line])))
  _stdout, stderr, status = run_enforcer(uncovered)
  assert(!status.success? && stderr.include?("#{explicit}:#{uncovered_line}"), "uncovered changed executable line must fail exactly")

  malformed = root.join("malformed.json")
  malformed.write("{not-json\n")
  _stdout, stderr, status = run_enforcer(malformed)
  assert(!status.success? && stderr.include?("malformed"), "malformed xccov JSON must fail clearly")
end

puts "shopping UI changed-line coverage contract ok"
