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

# Xcode's App Intents metadata step says this, behind a timestamp, for a package framework that uses no App Intents
# (OuroFeelRecorderInjectable's OuroFeelCore, built for the Feel UI tests): nothing was wrong, there was nothing to extract.
BENIGN_DIAGNOSTIC_PATTERNS = [
  /\A\d{4}-\d{2}-\d{2} [\d:.]+ appintentsmetadataprocessor\[\d+:\d+\] warning: Metadata extraction skipped, no AppIntents\.framework dependency found\z/
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
    next if BENIGN_DIAGNOSTIC_PATTERNS.any? { |pattern| diagnostic.match?(pattern) }

    diagnostic_lines << "#{path}:#{number}: #{diagnostic}" if diagnostic_patterns.any? { |pattern| line.match?(pattern) }
  end
end

if diagnostic_lines.any?
  warn "FAIL: warnings or error diagnostics found"
  diagnostic_lines.each { |line| warn line }
  exit 1
end

puts "warning scan ok"
