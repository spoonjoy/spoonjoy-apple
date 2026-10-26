#!/usr/bin/env ruby
# frozen_string_literal: true

# Announces App Review state changes for every App Store version on a GitHub issue per platform and version.
#   ruby scripts/app-review-watch.rb
# Needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_BASE64, GITHUB_TOKEN and GITHUB_REPOSITORY.
require "base64"
require "json"
require_relative "lib/app_review_watch"

root = File.expand_path("..", __dir__)
%w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_BASE64 GITHUB_TOKEN GITHUB_REPOSITORY].each do |name|
  abort "Missing #{name}" if ENV[name].to_s.empty?
end
listing = JSON.parse(File.read(File.join(root, "distribution/app-store/listing.json")))
asc = AppStoreListing::Client.new(
  key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"),
  private_key_pem: Base64.strict_decode64(ENV.fetch("ASC_KEY_BASE64").strip)
)
issues = AppReviewWatch::GitHubIssues.new(repo: ENV.fetch("GITHUB_REPOSITORY"), token: ENV.fetch("GITHUB_TOKEN"))
begin
  announced = AppReviewWatch::Runner.new(asc, issues, bundle_id: listing.fetch("bundleId")).run
  puts "Announced #{announced.size} change(s)."
rescue AppStoreListing::Error => e
  abort e.message
end
