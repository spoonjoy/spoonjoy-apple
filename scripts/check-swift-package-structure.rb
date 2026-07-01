#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
PACKAGE = ROOT.join("Package.swift")

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

fail_check("Package.swift is missing") unless PACKAGE.file?

package = PACKAGE.read
[
  'name: "SpoonjoyApple"',
  '.library(name: "SpoonjoyCore"',
  '.executable(name: "SpoonjoyNativeDogfood"',
  '.executable(name: "SpoonjoyScenarioVerifier"',
  '.target(name: "SpoonjoyCore"',
  '.executableTarget(name: "SpoonjoyNativeDogfood"',
  '.executableTarget(name: "SpoonjoyScenarioVerifier"',
  '.testTarget(name: "SpoonjoyCoreTests"',
  'resources: [.copy("Fixtures")]'
].each do |needle|
  fail_check("Package.swift is missing #{needle}") unless package.include?(needle)
end

required_paths = [
  "Sources/SpoonjoyCore/SpoonjoyCore.swift",
  "Sources/SpoonjoyCore/Fixtures/kitchen-fixture.json",
  "Sources/SpoonjoyCore/Fixtures/recipes-fixture.json",
  "Sources/SpoonjoyCore/Fixtures/cookbooks-fixture.json",
  "Sources/SpoonjoyCore/Fixtures/shopping-list-fixture.json",
  "Sources/SpoonjoyCore/Fixtures/offline-snapshot-fixture.json",
  "Sources/SpoonjoyNativeDogfood/main.swift",
  "Sources/SpoonjoyScenarioVerifier/main.swift",
  "Tests/SpoonjoyCoreTests/SpoonjoyCoreBootstrapTests.swift"
]

missing_paths = required_paths.reject { |path| ROOT.join(path).file? }
fail_check("missing required paths: #{missing_paths.join(", ")}") unless missing_paths.empty?

puts "swift package structure ok"
