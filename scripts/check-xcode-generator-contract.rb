#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
GENERATOR = ROOT.join("scripts/generate-xcode-project.rb")
FORBIDDEN_REPO_OUTPUTS = [
  ROOT.join("Spoonjoy.xcodeproj"),
  ROOT.join("Apps/Spoonjoy/Shared/SpoonjoyApp.swift"),
  ROOT.join("Apps/Spoonjoy/iOS"),
  ROOT.join("Apps/Spoonjoy/macOS"),
  ROOT.join("Apps/Spoonjoy/Shared/Assets.xcassets"),
  ROOT.join("Apps/Spoonjoy/Shared/Info.plist")
].freeze

def fail_check(message)
  warn "FAIL: #{message}"
  exit 1
end

def run!(*args)
  stdout, stderr, status = Open3.capture3(*args.map(&:to_s), chdir: ROOT.to_s)
  fail_check("#{args.join(" ")} failed\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}") unless status.success?
  stdout
end

fail_check("#{GENERATOR.relative_path_from(ROOT)} is missing") unless GENERATOR.file?

run!("ruby", "-c", GENERATOR)

help = run!("ruby", GENERATOR, "--help")
[
  "--output-dir",
  "Spoonjoy.xcodeproj",
  "BootstrapDebug",
  "IPHONEOS_DEPLOYMENT_TARGET",
  "MACOSX_DEPLOYMENT_TARGET"
].each do |token|
  fail_check("--help output is missing #{token}") unless help.include?(token)
end

Dir.mktmpdir("spoonjoy-generator-contract") do |dir|
  one = Pathname.new(dir).join("one")
  two = Pathname.new(dir).join("two")
  run!("ruby", GENERATOR, "--output-dir", one)
  run!("ruby", GENERATOR, "--output-dir", two)

  fail_check("temp output one did not include Spoonjoy.xcodeproj") unless one.join("Spoonjoy.xcodeproj").directory?
  fail_check("temp output two did not include Spoonjoy.xcodeproj") unless two.join("Spoonjoy.xcodeproj").directory?

  diff_stdout, diff_stderr, diff_status = Open3.capture3("diff", "-ru", one.to_s, two.to_s)
  fail_check("generator output is not deterministic\nSTDOUT:\n#{diff_stdout}\nSTDERR:\n#{diff_stderr}") unless diff_status.success?
end

written_outputs = FORBIDDEN_REPO_OUTPUTS.select(&:exist?)
unless written_outputs.empty?
  relative = written_outputs.map { |path| path.relative_path_from(ROOT).to_s }
  fail_check("temp-output mode wrote repo outputs: #{relative.join(", ")}")
end

puts "xcode generator contract ok"
