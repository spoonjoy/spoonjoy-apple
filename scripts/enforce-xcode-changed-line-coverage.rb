#!/usr/bin/env ruby
# frozen_string_literal: true

require "English"
require "json"
require "open3"
require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
options = { files: [] }
OptionParser.new do |parser|
  parser.banner = "Usage: enforce-xcode-changed-line-coverage.rb --coverage-json PATH --base-ref REF --minimum PERCENT --app-root PATH --file PATH"
  parser.on("--coverage-json PATH") { |value| options[:coverage_json] = value }
  parser.on("--base-ref REF") { |value| options[:base_ref] = value }
  parser.on("--minimum PERCENT", Float) { |value| options[:minimum] = value }
  parser.on("--app-root PATH") { |value| options[:app_root] = value }
  parser.on("--file PATH") { |value| options[:files] << value }
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

%i[coverage_json base_ref minimum app_root].each do |key|
  fail_check("--#{key.to_s.tr("_", "-")} is required") if options[key].nil? || options[key].to_s.empty?
end
fail_check("at least one --file is required") if options[:files].empty?
fail_check("--minimum must be greater than 0 and at most 100") unless options[:minimum].positive? && options[:minimum] <= 100

coverage_path = Pathname.new(options[:coverage_json])
fail_check("coverage JSON is missing: #{coverage_path}") unless coverage_path.file?
begin
  report = JSON.parse(coverage_path.binread)
rescue JSON::ParserError => error
  fail_check("coverage JSON is malformed: #{error.message}")
end

def git_output(*args)
  stdout, stderr, status = Open3.capture3("git", *args, chdir: ROOT.to_s)
  fail_check("git #{args.join(" ")} failed: #{stderr.strip}") unless status.success?
  stdout
end

def normalized_repo_path(value)
  path = Pathname.new(value.to_s)
  if path.absolute?
    expanded = path.expand_path.cleanpath
    return nil unless expanded.to_s.start_with?("#{ROOT}/")
    return expanded.relative_path_from(ROOT).to_s
  end
  cleaned = ROOT.join(path).cleanpath
  return nil unless cleaned.to_s.start_with?("#{ROOT}/")
  cleaned.relative_path_from(ROOT).to_s
end

app_root = normalized_repo_path(options[:app_root])
fail_check("--app-root must resolve inside the repository") unless app_root
explicit_files = options[:files].map do |path|
  normalized = normalized_repo_path(path)
  fail_check("--file must resolve inside the repository: #{path}") unless normalized
  fail_check("--file must name a Swift source: #{path}") unless normalized.end_with?(".swift")
  normalized
end

changed_app_files = git_output(
  "diff", "--name-only", "--diff-filter=ACMR", "#{options[:base_ref]}...HEAD", "--", app_root
).lines.map(&:chomp).select { |path| path.end_with?(".swift") }
required_files = (explicit_files + changed_app_files).uniq.sort

def changed_lines(path, base_ref)
  diff = git_output("diff", "--unified=0", "--no-ext-diff", "#{base_ref}...HEAD", "--", path)
  diff.lines.flat_map do |line|
    match = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
    next [] unless match
    start = match[1].to_i
    count = match[2] ? match[2].to_i : 1
    (start...(start + count)).to_a
  end.uniq.sort
end

def integer_value(value)
  Integer(value)
rescue ArgumentError, TypeError
  nil
end

def explicit_line_counts(file)
  counts = {}
  Array(file["lines"]).each do |entry|
    next unless entry.is_a?(Hash)
    line = integer_value(entry["lineNumber"] || entry["line"])
    count = integer_value(entry["executionCount"] || entry["count"])
    counts[line] = count if line && line.positive? && count && count >= 0
  end
  if file["lineExecutionCounts"].is_a?(Hash)
    file["lineExecutionCounts"].each do |line_value, count_value|
      line = integer_value(line_value)
      count = integer_value(count_value)
      counts[line] = count if line && line.positive? && count && count >= 0
    end
  end
  counts
end

def function_line_counts(file, relevant_lines)
  functions = Array(file["functions"]).select { |entry| entry.is_a?(Hash) && integer_value(entry["lineNumber"] || entry["line"]) }
  return {} if functions.empty?
  sorted = functions.sort_by { |entry| integer_value(entry["lineNumber"] || entry["line"]) }
  source_limit = relevant_lines.max.to_i + 1
  sorted.each_with_index.each_with_object({}) do |(function, index), counts|
    start = integer_value(function["lineNumber"] || function["line"])
    finish = index + 1 < sorted.length ? integer_value(sorted[index + 1]["lineNumber"] || sorted[index + 1]["line"]) : source_limit
    execution_count = integer_value(function["executionCount"])
    covered = execution_count ? execution_count.positive? : function["lineCoverage"].to_f >= 1.0
    relevant_lines.each { |line| counts[line] = covered ? 1 : 0 if line >= start && line < finish }
  end
end

coverage_files = Array(report["targets"]).flat_map { |target| target.is_a?(Hash) ? Array(target["files"]) : [] }
coverage_by_path = coverage_files.each_with_object({}) do |file, index|
  next unless file.is_a?(Hash)
  normalized = normalized_repo_path(file["path"] || file["name"] || file["filename"])
  next unless normalized
  index[normalized] ||= file
end

missing_files = required_files.reject { |path| coverage_by_path.key?(path) }
fail_check("xccov JSON is missing required file(s): #{missing_files.join(", ")}") unless missing_files.empty?

covered = 0
executable = 0
uncovered_locations = []
required_files.each do |path|
  lines_changed = changed_lines(path, options[:base_ref])
  next if lines_changed.empty?
  file = coverage_by_path.fetch(path)
  counts = explicit_line_counts(file)
  counts = function_line_counts(file, lines_changed) if counts.empty?
  if counts.empty? && file.key?("lineCoverage")
    count = file["lineCoverage"].to_f >= 1.0 ? 1 : 0
    counts = lines_changed.to_h { |line| [line, count] }
  end
  intersection = lines_changed & counts.keys
  fail_check("xccov JSON has no changed executable line records for #{path}") if intersection.empty?
  intersection.each do |line|
    executable += 1
    if counts.fetch(line).positive?
      covered += 1
    else
      uncovered_locations << "#{path}:#{line}"
    end
  end
end

fail_check("changed app Swift files have no measurable executable lines") if executable.zero?
percent = covered * 100.0 / executable
if percent < options[:minimum]
  detail = uncovered_locations.empty? ? "" : "; uncovered: #{uncovered_locations.join(", ")}"
  fail_check(
    "changed-line coverage below threshold: #{format("%.2f", percent)}% " \
    "(#{covered}/#{executable}) is below #{format("%.2f", options[:minimum])}%#{detail}"
  )
end

puts "changed-line coverage ok: #{format("%.2f", percent)}% (#{covered}/#{executable}); files=#{required_files.length}"
