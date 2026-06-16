#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
MAIN = ROOT.join("Sources/SpoonjoyScenarioVerifier/main.swift")

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

fail_check("#{MAIN.relative_path_from(ROOT)} is missing") unless MAIN.file?

content = MAIN.read
significant_lines = content.lines.map(&:strip).reject(&:empty?)
forbidden_patterns = [
  /\bif\b/,
  /\bswitch\b/,
  /\bdo\b/,
  /\bcatch\b/,
  /\bfor\b/,
  /\bwhile\b/,
  /\bguard\b/,
  /\btry\b/,
  /\bFileHandle\b/,
  /\bJSONEncoder\b/,
  /\bScenarioReporter\b/,
  /\bScenarioCommand\.parse\b/
]

fail_check("main.swift should be a single adapter call") unless significant_lines == [
  "ScenarioProcessMain.main(arguments: Array(CommandLine.arguments.dropFirst()))"
]

forbidden_patterns.each do |pattern|
  fail_check("main.swift contains forbidden branching or command logic: #{pattern}") if content.match?(pattern)
end

puts "scenario verifier main adapter is thin"
