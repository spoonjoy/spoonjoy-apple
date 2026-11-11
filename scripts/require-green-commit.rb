#!/usr/bin/env ruby
# frozen_string_literal: true

# Refuses to go on unless a commit's own Native push run passed every required check (scripts/lib/green_commit.rb).
#
#   ruby scripts/require-green-commit.rb --repository spoonjoy/spoonjoy-apple --branch main --sha <40 hex>
#   ruby scripts/require-green-commit.rb --repository spoonjoy/spoonjoy-apple --branch release/1.1
#
# Without --sha it checks the branch head. It prints the commit and, under GitHub Actions, writes sha=<commit> to
# GITHUB_OUTPUT, so the job checks out exactly the commit that was proven green, even if the branch moves on.
# Reads with gh api, so GH_TOKEN needs actions: read.

require "json"
require "open3"
require "optparse"
require_relative "lib/green_commit"

options = {}
OptionParser.new do |opts|
  opts.on("--repository OWNER/NAME") { |v| options[:repository] = v }
  opts.on("--branch BRANCH") { |v| options[:branch] = v }
  opts.on("--sha SHA") { |v| options[:sha] = v.strip.empty? ? nil : v.strip }
end.parse!

def gh(endpoint, *fields)
  out, err, status = Open3.capture3("gh", "api", "--method", "GET", endpoint, *fields)
  raise GreenCommit::NotGreen, "gh api #{endpoint} failed: #{err.strip}" unless status.success?

  JSON.parse(out)
end

begin
  repository = options.fetch(:repository) { raise GreenCommit::NotGreen, "--repository is required" }
  branch = options.fetch(:branch) { raise GreenCommit::NotGreen, "--branch is required" }
  raise GreenCommit::NotGreen, "branch must be main or release/<version>, not #{branch.inspect}" unless branch.match?(GreenCommit::BRANCH)

  sha = options[:sha] || gh("repos/#{repository}/git/ref/heads/#{branch}").dig("object", "sha")
  raise GreenCommit::NotGreen, "sha must be 40 lowercase hex characters, not #{sha.inspect}" unless sha.to_s.match?(GreenCommit::SHA)

  runs = gh("repos/#{repository}/actions/workflows/native.yml/runs", "-f", "head_sha=#{sha}", "-f", "branch=#{branch}",
            "-f", "event=push", "-f", "per_page=100")
  run = GreenCommit.latest_run(runs["workflow_runs"], sha: sha, branch: branch)
  jobs = gh("repos/#{repository}/actions/runs/#{run['id']}/jobs", "-f", "per_page=100")
  GreenCommit.require_green!(run, jobs["jobs"])
  puts "#{sha} on #{branch} is green: Native run #{run['id']} passed #{GreenCommit.required_for(branch, jobs['jobs']).join(', ')}."
  File.write(ENV["GITHUB_OUTPUT"], "sha=#{sha}\n", mode: "a") if ENV["GITHUB_OUTPUT"]
rescue GreenCommit::NotGreen => e
  warn "::error::Not publishing: #{e.message}"
  exit 1
end
