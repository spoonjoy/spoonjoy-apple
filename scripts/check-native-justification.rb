#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
DOC = ROOT.join("docs/native-justification.md")

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

fail_check("#{DOC.relative_path_from(ROOT)} is missing") unless DOC.file?

content = DOC.read

required_headings = [
  "# Native Justification",
  "## Native Workflows",
  "## Accepted Native Platform Levers",
  "## Rejected Or Later Platform Levers",
  "## Shared With Web And Backend",
  "## Design Language Invariants",
  "## Platform Differences",
  "## Bootstrap Validation And Product Baseline"
]

missing_headings = required_headings.reject { |heading| content.include?(heading) }
fail_check("missing required headings: #{missing_headings.join(", ")}") unless missing_headings.empty?

required_phrases = [
  "Spoonjoy Apple earns being native",
  "iOS 27",
  "macOS 27",
  "BootstrapDebug",
  "IPHONEOS_DEPLOYMENT_TARGET = 26.5",
  "MACOSX_DEPLOYMENT_TARGET = 26.2",
  "Xcode 26.5",
  "macOS 26.2",
  "App Intents",
  "Spotlight",
  "offline",
  "Kitchen Table",
  "TestFlight",
  "Apple Developer Program"
]

missing_phrases = required_phrases.reject { |phrase| content.include?(phrase) }
fail_check("missing required phrases: #{missing_phrases.join(", ")}") unless missing_phrases.empty?

if content.include?("spoonjoy.com")
  fail_check("must reference spoonjoy.app, not spoonjoy.com")
end

unless content.include?("spoonjoy.app")
  fail_check("must reference spoonjoy.app")
end

puts "native justification contract ok"
