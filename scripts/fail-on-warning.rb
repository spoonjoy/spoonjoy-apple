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

warning_lines = []

options[:logs].each do |log_path|
  path = Pathname.new(log_path)
  fail_check("warning log is missing: #{path}") unless path.file?

  path.each_line.with_index(1) do |line, number|
    warning_lines << "#{path}:#{number}: #{line.chomp}" if line.match?(/\bwarning:/i)
  end
end

if warning_lines.any?
  warn "FAIL: warnings found"
  warning_lines.each { |line| warn line }
  exit 1
end

puts "warning scan ok"
