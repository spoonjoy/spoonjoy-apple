#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the iOS and Mac builds TestFlight published from one source commit, or fails when either is missing.
#   ruby scripts/release-train-builds.rb --repository OWNER/REPO --sha SHA [--github-output PATH]
# With --github-output it also writes run_id, ios_build_number, ios_build_id, mac_build_number and mac_build_id.
# Needs GH_TOKEN with actions: read.
require "optparse"
require_relative "lib/release_train_builds"

options = {}
OptionParser.new do |opts|
  opts.on("--repository REPO") { |value| options[:repository] = value }
  opts.on("--sha SHA") { |value| options[:sha] = value }
  opts.on("--github-output PATH") { |value| options[:output] = value }
end.parse!
abort "--repository and --sha are required" unless options[:repository] && options[:sha]
abort "--sha must be a 40-character commit SHA" unless options[:sha].match?(/\A[0-9a-f]{40}\z/)

begin
  found = ReleaseTrainBuilds.find(options[:sha], ReleaseTrainBuilds::GitHubArtifacts.new(options[:repository]))
rescue ReleaseTrainBuilds::Error => e
  abort e.message
end
puts "TestFlight run #{found['runId']} published both builds from #{options[:sha]}:"
outputs = { "run_id" => found["runId"] }
{ "IOS" => "ios", "MAC_OS" => "mac" }.each do |platform, prefix|
  puts "- #{ReleaseTrainBuilds::NAMES.fetch(platform)} build #{found[platform]['buildNumber']} (#{found[platform]['buildId']})"
  outputs["#{prefix}_build_number"] = found[platform]["buildNumber"]
  outputs["#{prefix}_build_id"] = found[platform]["buildId"]
end
File.open(options[:output], "a") { |file| outputs.each { |key, value| file.puts "#{key}=#{value}" } } if options[:output]
