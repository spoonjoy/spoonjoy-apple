#!/usr/bin/env ruby
# frozen_string_literal: true

# Refuses an iOS submission whose source commit has no passing Launch smoke run: the Release app, linked with the
# iPhone's 1 MB main-thread stack, launched three times on each device family (TestflightCrashGate.launch_smoke).
#
#   ruby scripts/require-launch-smoke.rb --repository spoonjoy/spoonjoy-apple --sha <40 hex> [--override "REASON"]
#
# --override reports a refusal and goes on, recording the reason in the run summary. Reads with gh api, so GH_TOKEN
# needs actions: read.

require "json"
require "open3"
require "optparse"
require_relative "lib/testflight_crash_gate"

options = {}
OptionParser.new do |opts|
  opts.on("--repository OWNER/NAME") { |v| options[:repository] = v }
  opts.on("--sha SHA") { |v| options[:sha] = v.strip }
  opts.on("--override REASON") { |v| options[:override] = v.strip.empty? ? nil : v.strip }
end.parse!
abort "--repository and --sha are required" unless options[:repository] && options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)

def gh(endpoint, *fields)
  out, err, status = Open3.capture3("gh", "api", "--method", "GET", endpoint, *fields)
  abort "::error::gh api #{endpoint} failed: #{err.strip}" unless status.success?

  JSON.parse(out)
end

# Launch smoke runs inside Native (pull requests), After TestFlight (main) or on its own (a dispatch).
WORKFLOWS = %w[.github/workflows/native.yml .github/workflows/after-testflight.yml .github/workflows/launch-smoke.yml].freeze
runs = gh("repos/#{options[:repository]}/actions/runs", "-f", "head_sha=#{options[:sha]}", "-f", "per_page=100")["workflow_runs"]
runs = runs.select { |run| WORKFLOWS.include?(run["path"]) }.map do |run|
  { "id" => run["id"], "jobs" => gh("repos/#{options[:repository]}/actions/runs/#{run['id']}/jobs", "-f", "per_page=100")["jobs"] }
end
result = TestflightCrashGate.launch_smoke(runs, sha: options[:sha])
verdict = if result["pass"] then "passed"
          elsif options[:override] then "refused, overridden"
          else "refused"
          end
lines = ["### Launch smoke at the iPhone's stack size: #{verdict}", ""]
lines += result["refusals"].map { |r| "- Refused: #{r}" } + result["notes"].map { |n| "- #{n}" }
lines << "- Override reason: #{options[:override]}" if options[:override] && !result["pass"]
summary = lines.join("\n") + "\n"
puts summary
File.write(ENV["GITHUB_STEP_SUMMARY"], summary, mode: "a") if ENV["GITHUB_STEP_SUMMARY"]
exit 0 if result["pass"] || options[:override]

warn "::error::Not submitting: #{result['refusals'].join('; ')}"
exit 1
