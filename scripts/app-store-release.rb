#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads or changes how an App Store version releases.
#   ruby scripts/app-store-release.rb --platform IOS --version 1.0 --action status|set-release-type|release|review-messages|crash-diagnostics [--apply]
# review-messages only reads: review submission states and, where Apple answers, the App Review message text.
# crash-diagnostics only reads: diagnostic signatures and TestFlight crash feedback for the version's builds.
# set-release-type uses version.releaseType from listing.json. Without --apply it only prints what it would do.
# Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_BASE64.
require "base64"
require "json"
require "optparse"
require_relative "lib/app_store_release"
require_relative "lib/app_store_crash_diagnostics"
require_relative "lib/app_store_review_messages"

root = File.expand_path("..", __dir__)
options = { apply: false, action: "status" }
OptionParser.new do |opts|
  opts.on("--platform P", %w[IOS MAC_OS]) { |value| options[:platform] = value }
  opts.on("--version V") { |value| options[:version] = value }
  opts.on("--action A", %w[status set-release-type release review-messages crash-diagnostics]) { |value| options[:action] = value }
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
  if options[:action] == "review-messages"
    runner = AppStoreRelease::Runner.new(client, bundle_id: listing.fetch("bundleId"), platform: options[:platform],
                                                 version_string: options[:version])
    runner.report(runner.version || abort("No #{options[:platform]} version #{options[:version]}"))
    AppStoreReviewMessages::Reader.new(client, app_id: runner.app_id, platform: options[:platform]).run
    exit 0
  end
  if options[:action] == "crash-diagnostics"
    runner = AppStoreRelease::Runner.new(client, bundle_id: listing.fetch("bundleId"), platform: options[:platform],
                                                 version_string: options[:version])
    AppStoreCrashDiagnostics::Reader.new(client, app_id: runner.app_id, platform: options[:platform],
                                                 version_string: options[:version]).run
    exit 0
  end
  AppStoreRelease::Runner.new(client, bundle_id: listing.fetch("bundleId"), platform: options[:platform],
                                      version_string: options[:version])
                         .run(action: options[:action], apply: options[:apply], release_type: listing.dig("version", "releaseType"))
rescue AppStoreListing::Error => e
  abort e.message
end
