#!/usr/bin/env ruby
# frozen_string_literal: true

# Holds iOS and Mac to one release train (scripts/lib/release_train.rb).
#
#   ruby scripts/check-release-train.rb
#
# Checks the repository: one version across the Xcode project, its generator, listing.json and
# apple-distribution.json; no Mac version override; a written What's New for both platforms or neither; the same
# support, marketing and privacy URLs on both.
require_relative "lib/release_train"

root = File.expand_path("..", __dir__)
errors = ReleaseTrain.static_errors(root)
if errors.empty?
  puts "iOS and Mac are on one release train."
  exit 0
end
warn "iOS and Mac are not on one release train:"
errors.each { |error| warn "- #{error}" }
exit 1
