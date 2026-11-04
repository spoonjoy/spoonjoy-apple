#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks an Ouro AX X-ray report against config/xray-expected.json (see scripts/lib/xray_expectations.rb).
#
#   ruby scripts/check-xray.rb <report.json> [--expected config/xray-expected.json]
#
# Exit 0 when all is as expected, 1 when not, 2 for a usage mistake.
require "json"
require_relative "lib/xray_expectations"

args = ARGV.dup
expected_path = File.expand_path("../config/xray-expected.json", __dir__)
if (index = args.index("--expected"))
  expected_path = args.delete_at(index + 1) || abort("check-xray: --expected needs a path")
  args.delete_at(index)
end
if args.length != 1 || args.first.start_with?("-")
  warn "check-xray: give the report: ruby scripts/check-xray.rb <report.json>"
  exit 2
end

report = JSON.parse(File.read(args.first))
expected = JSON.parse(File.read(expected_path))
problems = XrayExpectations.check(report, expected)
puts XrayExpectations.summary(report)
statuses = XrayExpectations.statuses(report)
expected.fetch("failing", {}).merge(expected.fetch("open")).sort.each do |claim, reason|
  puts "  #{statuses.fetch(claim, "absent")} #{claim}: #{reason}" unless statuses[claim] == "hold"
end
problems.each { |line| warn "check-xray: #{line}" }
exit(problems.empty? ? 0 : 1)
