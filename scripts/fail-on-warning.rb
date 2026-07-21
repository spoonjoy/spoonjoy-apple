#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"

options = {
  logs: []
}

OptionParser.new do |parser|
  parser.banner = "Usage: fail-on-warning.rb --log PATH [--log PATH ...]"
  parser.on("--log PATH", "Build or test log to scan") { |value| options[:logs] << value }
end.parse!

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

fail_check("at least one --log is required") if options[:logs].empty?

# GitHub-hosted Apple Silicon emits this virtualization driver probe despite successful image tests.
BENIGN_FULL_LINE_DIAGNOSTICS = [
  "IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver"
].freeze
BENIGN_LINE_PATTERNS = [
  /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+-\d{4} SpoonjoyUITests-Runner\[\d+:\d+\] \[General\] Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com\.apple\.app_launch_measurement\.FirstFramePresentationMetric\z/,
  /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+-\d{4} SpoonjoyUITests-Runner\[\d+:\d+\] \[General\] Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com\.apple\.app_launch_measurement\.ExtendedLaunchMetrics\z/
].freeze

diagnostic_lines = []
diagnostic_patterns = [
  /\bwarning:/i,
  /\berror:/i,
  /\bFAIL:/,
  /An error was encountered processing the command/i,
  /Underlying error/i,
  /\bfailed to\b/i,
  /IOServiceMatchingfailed/,
  /\bfatal error:/i,
  /\buncaught exception\b/i
].freeze

options[:logs].each do |log_path|
  path = Pathname.new(log_path)
  fail_check("warning log is missing: #{path}") unless path.file?

  path.each_line.with_index(1) do |line, number|
    diagnostic = line.chomp
    next if BENIGN_FULL_LINE_DIAGNOSTICS.include?(diagnostic)
    next if BENIGN_LINE_PATTERNS.any? { |pattern| diagnostic.match?(pattern) }

    diagnostic_lines << "#{path}:#{number}: #{diagnostic}" if diagnostic_patterns.any? { |pattern| line.match?(pattern) }
  end
end

if diagnostic_lines.any?
  warn "FAIL: warnings or error diagnostics found"
  diagnostic_lines.each { |line| warn line }
  exit 1
end

puts "warning scan ok"
