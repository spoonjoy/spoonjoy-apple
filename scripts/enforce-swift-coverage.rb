#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path

options = {
  includes: []
}

OptionParser.new do |parser|
  parser.banner = "Usage: enforce-swift-coverage.rb --coverage-json PATH --minimum PERCENT --include PATH"
  parser.on("--coverage-json PATH", "LLVM coverage JSON export path") { |value| options[:coverage_json] = value }
  parser.on("--minimum PERCENT", Float, "Required minimum line coverage percent") { |value| options[:minimum] = value }
  parser.on("--include PATH", "Source path prefix to include") { |value| options[:includes] << value }
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

coverage_path = options[:coverage_json]
minimum = options[:minimum]
includes = options[:includes]

fail_check("--coverage-json is required") if coverage_path.nil? || coverage_path.empty?
fail_check("--minimum is required") if minimum.nil?
fail_check("at least one --include is required") if includes.empty?

coverage_file = Pathname.new(coverage_path)
fail_check("coverage JSON is missing: #{coverage_file}") unless coverage_file.file?

begin
  report = JSON.parse(coverage_file.read)
rescue JSON::ParserError => error
  fail_check("coverage JSON is malformed: #{error.message}")
end

def normalized_filename(filename)
  path = Pathname.new(filename)
  return path.relative_path_from(ROOT).to_s if path.absolute? && path.to_s.start_with?(ROOT.to_s)

  filename
end

def included_file?(filename, includes)
  normalized = normalized_filename(filename)
  includes.any? do |include_path|
    normalized == include_path || normalized.start_with?("#{include_path}/")
  end
end

def uncovered_lines(file)
  regions = file.fetch("segments", []).select do |segment|
    segment.is_a?(Array) && segment.length >= 6 && segment[3] == true && segment[4] == true && segment[5] == false
  end
  regions.group_by { |segment| segment[0] }
    .select { |_, line_regions| line_regions.all? { |segment| segment[2].to_i.zero? } }
    .keys
    .sort
end

files = report.fetch("data", []).flat_map { |entry| entry.fetch("files", []) }
included = files.select { |file| included_file?(file.fetch("filename"), includes) }
fail_check("coverage JSON has no files matching include path(s): #{includes.join(", ")}") if included.empty?

covered_lines = 0
total_lines = 0

included.each do |file|
  lines = file.fetch("summary").fetch("lines")
  covered_lines += lines.fetch("covered")
  total_lines += lines.fetch("count")
end

fail_check("included coverage has no measurable lines") if total_lines.zero?

percent = (covered_lines * 100.0) / total_lines

if percent < minimum
  uncovered = included.flat_map do |file|
    filename = normalized_filename(file.fetch("filename"))
    uncovered_lines(file).map { |line| "#{filename}:#{line}" }
  end
  uncovered_details = uncovered.first(20).map { |location| "- #{location}" }
  uncovered_details << "- ... and #{uncovered.length - 20} more" if uncovered.length > 20
  diagnostics = uncovered_details.empty? ? "" : "\nUncovered included lines:\n#{uncovered_details.join("\n")}"
  fail_check(
    "coverage below threshold: #{format("%.4f", percent)}% " \
    "(#{covered_lines}/#{total_lines}) is below #{format("%.4f", minimum)}%#{diagnostics}"
  )
end

puts "coverage ok: #{format("%.4f", percent)}% (#{covered_lines}/#{total_lines})"
