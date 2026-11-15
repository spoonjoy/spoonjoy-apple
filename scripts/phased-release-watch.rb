#!/usr/bin/env ruby
# frozen_string_literal: true

# Pauses an App Store phased release when its build starts crashing (scripts/lib/phased_release_watch.rb).
#   ruby scripts/phased-release-watch.rb
# Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_BASE64, GITHUB_TOKEN and GITHUB_REPOSITORY. It pauses only when
# PHASED_RELEASE_AUTO_PAUSE is "on" (the repository variable of the same name); otherwise it comments what it would do.
require "base64"
require "json"
require_relative "lib/phased_release_watch"

root = File.expand_path("..", __dir__)
%w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64 GITHUB_TOKEN GITHUB_REPOSITORY].each do |name|
  abort "Missing #{name}" if ENV[name].to_s.empty?
end
listing = JSON.parse(File.read(File.join(root, "distribution/app-store/listing.json")))
asc = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
issues = AppReviewWatch::GitHubIssues.new(repo: ENV.fetch("GITHUB_REPOSITORY"), token: ENV.fetch("GITHUB_TOKEN"),
                                          label: PhasedReleaseWatch::LABEL,
                                          description: "An App Store phased release, watched for crashes")
begin
  acted = PhasedReleaseWatch::Runner.new(asc, issues, bundle_id: listing.fetch("bundleId"),
                                                      apply: ENV["PHASED_RELEASE_AUTO_PAUSE"] == "on").run
  acted.each { |platform, version, action| puts "#{platform} #{version}: #{action}" }
  puts "No phased release is rolling out." if acted.empty?
rescue AppStoreListing::Error => e
  abort e.message
end
