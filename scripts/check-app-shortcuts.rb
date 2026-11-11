#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: ruby scripts/check-app-shortcuts.rb <Spoonjoy.app/Metadata.appintents/extract.actionsdata> [config/app-shortcuts.json]
# Holds the App Shortcuts Xcode compiled into the app to the phrases config/app-shortcuts.json lists (scripts/lib/app_shortcuts.rb).
require "json"
require_relative "lib/app_shortcuts"

data_path = ARGV[0] or abort("usage: check-app-shortcuts.rb <extract.actionsdata> [config/app-shortcuts.json]")
config_path = ARGV[1] || File.expand_path("../config/app-shortcuts.json", __dir__)
metadata = JSON.parse(File.read(data_path))
expected = JSON.parse(File.read(config_path))
problems = AppShortcuts.check(metadata, expected)
unless problems.empty?
  problems.each { |problem| warn "FAIL: #{problem}" }
  exit 1
end
built = AppShortcuts.built(metadata)
puts "App Shortcuts ok: #{built.values.sum(&:length)} phrases across #{built.length} App Shortcuts"
