#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds iOS and Mac to one release train (scripts/lib/release_train.rb).
#
#   ruby scripts/check-release-train.rb
#   ruby scripts/check-release-train.rb --app-store-connect [--no-issue]
#
# Without arguments it checks the repository: one version across the Xcode project, its generator, listing.json and
# apple-distribution.json; no Mac version override; a written What's New for both platforms or neither; the same
# support, marketing and privacy URLs on both.
#
# --app-store-connect reads both platforms' newest App Store versions, read-only (it never writes to App Store
# Connect), and keeps one GitHub issue labelled release-train when their version, state or shared copy differ.
# Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_BASE64, and GITHUB_TOKEN and GITHUB_REPOSITORY unless --no-issue,
# which instead exits 1 on drift.
require "base64"
require "optparse"
require_relative "lib/release_train"
require_relative "lib/app_review_watch"

root = File.expand_path("..", __dir__)
options = { asc: false, issue: true }
OptionParser.new do |opts|
  opts.on("--app-store-connect") { options[:asc] = true }
  opts.on("--no-issue") { options[:issue] = false }
end.parse!

unless options[:asc]
  errors = ReleaseTrain.static_errors(root)
  if errors.empty?
    puts "iOS and Mac are on one release train."
    exit 0
  end
  warn "iOS and Mac are not on one release train:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

required = %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64] + (options[:issue] ? %w[GITHUB_TOKEN GITHUB_REPOSITORY] : [])
required.each { |name| abort "Missing #{name}" if ENV[name].to_s.empty? }
listing = JSON.parse(File.read(File.join(root, ReleaseTrain::LISTING)))
client = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
begin
  reader = ReleaseTrain::LiveReader.new(client, bundle_id: listing.fetch("bundleId"))
  ios = reader.latest("IOS")
  mac = reader.latest("MAC_OS")
  [ios, mac].compact.each do |v|
    puts "#{ReleaseTrain::PLATFORM_NAMES.fetch(v['platform'])}: #{v['versionString']} #{v['state']} (build #{v['build'] || 'none'})"
  end
  differences = ReleaseTrain.drift(ios, mac, ReleaseTrain.matching_fields(listing))
  puts(differences.empty? ? "iOS and Mac are in line." : "iOS and Mac have drifted:")
  differences.each { |difference| puts "- #{difference}" }
  if options[:issue]
    issues = AppReviewWatch::GitHubIssues.new(repo: ENV.fetch("GITHUB_REPOSITORY"), token: ENV.fetch("GITHUB_TOKEN"),
                                              label: ReleaseTrain::LABEL,
                                              description: "iOS and Mac out of line in App Store Connect, kept by the drift job")
    ReleaseTrain::DriftIssue.new(issues).keep(differences, ios: ios, mac: mac)
  elsif !differences.empty?
    exit 1
  end
rescue AppStoreListing::Error => e
  abort e.message
end
