# frozen_string_literal: true

# Picks where Native's App bundle job runs on a merge-queue or main/release push run: Ari's Mac (the self-hosted
# runner labelled spoonjoy-local-mac) when it is up and idle, otherwise a hosted xcode-27 runner. GitHub's runs-on
# can't say "whichever is free", so the "Mac runner" job decides and App bundle reads its output.
#
# The Mac publishes its state to the repository variable SPOONJOY_LOCAL_MAC ("v1 <unix time> <state> <free GiB>",
# written by the runner's heartbeat launch agent), because a workflow's token can't read self-hosted runners. On top of
# that, the job counts this repository's unfinished jobs on the local label, so two runs a few seconds apart don't
# both pick an idle Mac. Anything unexpected picks hosted: a wrong pick only costs time, never a check.
#
# Run: ruby scripts/pick-mac-runner.rb (in the workflow; tests in scripts/test/pick_mac_runner_test.rb)
require "json"
require "open3"

module PickMacRunner
  LABEL = "spoonjoy-local-mac"
  # The heartbeat writes at least every 2 minutes; a sleeping or unplugged Mac stops writing.
  MAX_AGE_SECONDS = 300
  ACTIVE_JOB_STATUSES = %w[queued in_progress waiting pending requested].freeze

  module_function

  # Only trusted runs may use the Mac: the merge queue and pushes to main or release/**. Never a pull request.
  def trusted_event?(event, ref)
    return true if event == "merge_group"

    event == "push" && (ref == "refs/heads/main" || ref.to_s.start_with?("refs/heads/release/"))
  end

  # Returns [runner, reason]; runner is "local" or "hosted".
  def choose(event:, ref:, heartbeat:, now:, active_local_jobs:)
    return ["hosted", "#{event} runs never use the local Mac"] unless trusted_event?(event, ref)

    version, at, state, free = heartbeat.to_s.split
    return ["hosted", "no heartbeat from the local Mac"] unless version == "v1" && at.to_s.match?(/\A\d+\z/)

    age = now - at.to_i
    return ["hosted", "the local Mac's heartbeat is #{age}s old"] if age > MAX_AGE_SECONDS
    return ["hosted", "the local Mac is #{state} (#{free} GiB free)"] unless state == "ready"
    return ["hosted", "the local Mac's state is unknown"] if active_local_jobs.nil?
    return ["hosted", "#{active_local_jobs} job(s) already waiting for or running on the local Mac"] if active_local_jobs.positive?

    ["local", "the local Mac is idle (#{free} GiB free)"]
  end

  def gh_json(path)
    out, status = Open3.capture2("gh", "api", "--paginate", "--slurp", path)
    raise "gh api #{path} failed" unless status.success?

    JSON.parse(out)
  end

  # Unfinished jobs of this repository's unfinished runs that asked for the local label.
  def active_local_jobs(repo)
    runs = %w[queued in_progress waiting pending requested].flat_map do |status|
      gh_json("repos/#{repo}/actions/runs?status=#{status}&per_page=100").flat_map { |page| page.fetch("workflow_runs") }
    end
    runs.uniq { |run| run.fetch("id") }.sum do |run|
      jobs = gh_json("repos/#{repo}/actions/runs/#{run.fetch('id')}/jobs?filter=latest&per_page=100")
             .flat_map { |page| page.fetch("jobs") }
      jobs.count { |job| ACTIVE_JOB_STATUSES.include?(job["status"]) && Array(job["labels"]).include?(LABEL) }
    end
  end

  def main(env = ENV, out: $stdout)
    event = env.fetch("GITHUB_EVENT_NAME", "")
    ref = env.fetch("GITHUB_REF", "")
    active = nil
    if trusted_event?(event, ref)
      begin
        active = active_local_jobs(env.fetch("GITHUB_REPOSITORY"))
      rescue StandardError => e
        out.puts "Couldn't count jobs on the local Mac (#{e.message}); picking hosted."
      end
    end
    runner, reason = choose(event: event, ref: ref, heartbeat: env["SPOONJOY_LOCAL_MAC"], now: Time.now.to_i,
                            active_local_jobs: active)
    out.puts "App bundle runs on #{runner == 'local' ? 'the local Mac' : 'a hosted xcode-27 runner'}: #{reason}."
    File.open(env["GITHUB_OUTPUT"], "a") { |file| file.puts "app-bundle=#{runner}" } if env["GITHUB_OUTPUT"]
    if env["GITHUB_STEP_SUMMARY"]
      File.open(env["GITHUB_STEP_SUMMARY"], "a") { |file| file.puts "App bundle: **#{runner}**, #{reason}." }
    end
    runner
  end
end

PickMacRunner.main if $PROGRAM_NAME == __FILE__
