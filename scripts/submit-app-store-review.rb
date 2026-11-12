#!/usr/bin/env ruby
# frozen_string_literal: true

# Submits a prepared App Store version for App Review.
#   ruby scripts/submit-app-store-review.rb --platform IOS --version 1.0 [--listing PATH] [--apply]
#   ruby scripts/submit-app-store-review.rb --platform BOTH --version 1.3 --build-id IOS=ID --build-id MAC_OS=ID [--apply]
# Without --apply it only prints what it would do. BOTH plans iOS and then the Mac, and submits either only once both
# plans succeed. --build-id PLATFORM=ID refuses a version whose attached build is not that one; BOTH needs one for
# each platform (scripts/release-train-builds.rb). Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_BASE64.
require "base64"
require "json"
require "optparse"
require_relative "lib/app_store_review_submission"

PLATFORMS = %w[IOS MAC_OS].freeze
root = File.expand_path("..", __dir__)
options = { apply: false, platform: nil, version: nil, build_ids: {},
            listing: File.join(root, "distribution/app-store/listing.json") }
OptionParser.new do |opts|
  opts.on("--platform P", PLATFORMS + ["BOTH"]) { |value| options[:platform] = value }
  opts.on("--version V") { |value| options[:version] = value }
  opts.on("--build-id PLATFORM=ID") do |value|
    platform, id = value.split("=", 2)
    abort "--build-id must read PLATFORM=ID with PLATFORM one of #{PLATFORMS.join(', ')}" unless PLATFORMS.include?(platform) && !id.to_s.empty?
    options[:build_ids][platform] = id
  end
  opts.on("--listing PATH") { |value| options[:listing] = value }
  opts.on("--apply") { options[:apply] = true }
end.parse!
abort "--platform IOS|MAC_OS|BOTH and --version are required" unless options[:platform] && options[:version]
platforms = options[:platform] == "BOTH" ? PLATFORMS : [options[:platform]]
missing = platforms.reject { |platform| options[:build_ids].key?(platform) }
abort "--platform BOTH needs --build-id for #{missing.join(' and ')}" if options[:platform] == "BOTH" && !missing.empty?
%w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64].each { |name| abort "Missing #{name}" if ENV[name].to_s.empty? }

listing = JSON.parse(File.read(options[:listing]))
client = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
runners = platforms.map do |platform|
  AppStoreReviewSubmission::Runner.new(client, bundle_id: listing.fetch("bundleId"), platform: platform,
                                               version_string: options[:version], build_id: options[:build_ids][platform])
end
begin
  # Every platform's plan first, so one that cannot be submitted stops the train before anything is sent.
  runners.each(&:check) if runners.length > 1
  runners.each do |runner|
    puts "#{runner.platform} #{options[:version]}:"
    runner.run(apply: options[:apply])
  end
rescue AppStoreListing::Error => e
  abort e.message
end
