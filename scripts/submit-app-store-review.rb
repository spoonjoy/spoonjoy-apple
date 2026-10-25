#!/usr/bin/env ruby
# frozen_string_literal: true

# Submits a prepared App Store version for App Review.
#   ruby scripts/submit-app-store-review.rb --platform IOS --version 1.0 [--apply]
# Without --apply it only prints what it would do. Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_BASE64.
require "base64"
require "json"
require "optparse"
require_relative "lib/app_store_review_submission"

root = File.expand_path("..", __dir__)
options = { apply: false, platform: nil, version: nil }
OptionParser.new do |opts|
  opts.on("--platform P", %w[IOS MAC_OS]) { |value| options[:platform] = value }
  opts.on("--version V") { |value| options[:version] = value }
  opts.on("--apply") { options[:apply] = true }
end.parse!
abort "--platform IOS|MAC_OS and --version are required" unless options[:platform] && options[:version]
%w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64].each { |name| abort "Missing #{name}" if ENV[name].to_s.empty? }

listing = JSON.parse(File.read(File.join(root, "distribution/app-store/listing.json")))
client = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
begin
  AppStoreReviewSubmission::Runner.new(client, bundle_id: listing.fetch("bundleId"), platform: options[:platform],
                                               version_string: options[:version]).run(apply: options[:apply])
rescue AppStoreListing::Error => e
  abort e.message
end
