#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates or repairs the App Review demo kitchen on spoonjoy.app. Safe to run again at any time.
#
#   ruby scripts/seed-review-demo-account.rb --validate-only
#   ruby scripts/seed-review-demo-account.rb
#   ruby scripts/seed-review-demo-account.rb --store-scenes FILE
#
# Reads SPOONJOY_REVIEW_DEMO_USERNAME / _PASSWORD and SPOONJOY_REVIEW_FRIEND_USERNAME / _PASSWORD, and
# SPOONJOY_BASE_URL (default https://spoonjoy.app). Passwords are never printed. --store-scenes also writes, 0600,
# a signed-in session for a DEBUG app and the links the Duo tour photographs (Seeder#store_scenes).

require "optparse"
require_relative "lib/review_demo_kitchen"

root = File.expand_path("..", __dir__)
options = { validate_only: false, kitchen: File.join(root, "distribution/app-store/review-demo-kitchen.json") }
OptionParser.new do |opts|
  opts.on("--validate-only") { options[:validate_only] = true }
  opts.on("--kitchen PATH") { |value| options[:kitchen] = value }
  opts.on("--store-scenes PATH") { |value| options[:store_scenes] = value }
end.parse!

kitchen = JSON.parse(File.read(options[:kitchen]))
errors = ReviewDemoKitchen.validate(kitchen)
unless errors.empty?
  warn "The demo kitchen is not valid:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end
if options[:validate_only]
  puts "The demo kitchen is valid."
  exit 0
end

begin
  http = ReviewDemoKitchen::Http.new(ENV.fetch("SPOONJOY_BASE_URL", "https://spoonjoy.app"))
  seeder = ReviewDemoKitchen::Seeder.new(kitchen: kitchen, http: http, env: ENV)
  seeder.run
  if options[:store_scenes]
    File.open(options[:store_scenes], "w", 0o600) { |file| file.write(JSON.generate(seeder.store_scenes)) }
  end
rescue ReviewDemoKitchen::Error => e
  warn e.message
  exit 1
end
