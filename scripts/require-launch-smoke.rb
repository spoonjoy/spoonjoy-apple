#!/usr/bin/env ruby
# frozen_string_literal: true

# Refuses an iOS submission whose source commit has no passing Launch smoke run: the Release app, linked with the
# iPhone's 1 MB main-thread stack, launched three times on each device family (TestflightCrashGate.launch_smoke).
#
#   ruby scripts/require-launch-smoke.rb --repository spoonjoy/spoonjoy-apple --sha <40 hex> [--override "REASON"] [--github-output PATH]
#
# --override reports a refusal and goes on, recording the reason in the run summary. With --github-output it writes
# refused=true|false there (true only for a refusal without an override) and exits 0, so the job can show the rest of
# its plan before it stops. Reads with gh api, so GH_TOKEN
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
  opts.on("--github-output PATH") { |v| options[:output] = v }
end.parse!
abort "--repository and --sha are required" unless options[:repository] && options[:sha].to_s.match?(/\A[0-9a-f]{40}\z/)

def gh(endpoint, *fields)
  out, err, status = Open3.capture3("gh", "api", "--method", "GET", endpoint, *fields)
  abort "::error::gh api #{endpoint} failed: #{err.strip}" unless status.success?

  JSON.parse(out)
end

# Launch smoke runs after TestFlight on main, or on its own when dispatched (a release branch). A pull request's run
# builds the merge with main rather than this commit, so it is no proof.
WORKFLOWS = { ".github/workflows/after-testflight.yml" => "workflow_run",
              ".github/workflows/launch-smoke.yml" => "workflow_dispatch" }.freeze
runs = gh("repos/#{options[:repository]}/actions/runs", "-f", "head_sha=#{options[:sha]}", "-f", "per_page=100")["workflow_runs"]
runs = runs.select { |run| WORKFLOWS[run["path"]] == run["event"] }.map do |run|
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
refused = !result["pass"] && options[:override].nil?
File.write(options[:output], "refused=#{refused}\n", mode: "a") if options[:output]
exit 0 unless refused

warn "::error::Not submitting: #{result['refusals'].join('; ')}"
exit 1 unless options[:output]
