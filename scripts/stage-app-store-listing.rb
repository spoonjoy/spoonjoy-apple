#!/usr/bin/env ruby
# frozen_string_literal: true

# Stages distribution/app-store/listing.json and its screenshots into App Store Connect.
#
#   ruby scripts/stage-app-store-listing.rb --validate-only
#   ruby scripts/stage-app-store-listing.rb --dry-run [--build-number N]
#   ruby scripts/stage-app-store-listing.rb --apply --build-number N
#   ruby scripts/stage-app-store-listing.rb --dry-run --platform MAC_OS --build-number N
#
# --platform defaults to IOS. MAC_OS stages the Mac version from listing.json's "mac" section and leaves app-level
# data (name, categories, age rating, price, availability) alone, because the iOS listing owns it.
#
# Credentials come from the environment: ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_BASE64 (the base64 of the .p8
# key). Review details read SPOONJOY_REVIEW_DEMO_USERNAME, SPOONJOY_REVIEW_DEMO_PASSWORD and, if set,
# APP_REVIEW_CONTACT_PHONE. Secrets are never printed. Nothing here submits the app for review.

require "optparse"
require_relative "lib/app_store_listing"

root = File.expand_path("..", __dir__)
options = { mode: nil, build_number: nil, platform: "IOS", listing: File.join(root, "distribution/app-store/listing.json"),
            screenshots: File.join(root, "distribution/app-store/screenshots") }
OptionParser.new do |opts|
  opts.on("--validate-only") { options[:mode] = :validate }
  opts.on("--dry-run") { options[:mode] = :dry_run }
  opts.on("--apply") { options[:mode] = :apply }
  opts.on("--build-number N") { |value| options[:build_number] = value.strip.empty? ? nil : value.strip }
  opts.on("--platform PLATFORM") { |value| options[:platform] = value.strip.empty? ? "IOS" : value.strip }
  opts.on("--listing PATH") { |value| options[:listing] = value }
  opts.on("--screenshots DIR") { |value| options[:screenshots] = value }
end.parse!
abort "Choose --validate-only, --dry-run or --apply" unless options[:mode]

begin
  listing = AppStoreListing.for_platform(JSON.parse(File.read(options[:listing])), options[:platform])
rescue AppStoreListing::Error => e
  abort e.message
end
puts "Platform: #{options[:platform]}"
errors = AppStoreListing.validate(listing, options[:screenshots])
unless errors.empty?
  warn "The listing is not valid:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end
screenshots = AppStoreListing.local_screenshots(listing, options[:screenshots])
screenshots.each { |folder, files| puts "#{folder}: #{files.length} screenshot(s)" }
if options[:mode] == :validate
  puts "The listing is valid."
  exit 0
end

%w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64].each do |name|
  abort "Missing #{name}" if ENV[name].to_s.empty?
end
abort "--apply needs --build-number" if options[:mode] == :apply && options[:build_number].nil?

client = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
reader = AppStoreListing::Reader.new(client, listing)
secrets = {
  "demoAccountName" => ENV["SPOONJOY_REVIEW_DEMO_USERNAME"].to_s.empty? ? nil : ENV["SPOONJOY_REVIEW_DEMO_USERNAME"],
  "demoAccountPassword" => ENV["SPOONJOY_REVIEW_DEMO_PASSWORD"].to_s.empty? ? nil : ENV["SPOONJOY_REVIEW_DEMO_PASSWORD"],
  "contactPhone" => ENV["APP_REVIEW_CONTACT_PHONE"].to_s.empty? ? nil : ENV["APP_REVIEW_CONTACT_PHONE"]
}.compact
warn "No demo account secrets: review details will not include the demo account." unless secrets["demoAccountName"]

snapshot = reader.snapshot(build_number: options[:build_number])
steps = AppStoreListing.plan(listing: listing, snapshot: snapshot, screenshots: screenshots, secrets: secrets)
puts "App Store Connect app #{reader.app_id}: #{steps.length} change(s)"
puts AppStoreListing.describe(steps)
if options[:mode] == :dry_run
  puts "Dry run: nothing was written."
  exit 0
end

AppStoreListing::Executor.new(client, reader.app_id).run(steps)
puts "Staged. Review the listing in App Store Connect and submit it there; this script never submits."
