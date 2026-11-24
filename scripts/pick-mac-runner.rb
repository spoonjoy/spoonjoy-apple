# frozen_string_literal: true

# Picks where Native's App bundle, Reins journeys and Native scenario verifier jobs run on a merge-queue or main/release push run: Ari's Mac
# (the self-hosted runner labelled spoonjoy-local-mac) when it is up and idle, otherwise hosted runners. GitHub's
# runs-on can't say "whichever is free", so the "Mac runner" job decides and each of those jobs reads its output.
#
# The Mac publishes its state to the repository variable SPOONJOY_LOCAL_MAC ("v1 <unix time> <state> <free GiB>",
# written by the runner's heartbeat launch agent), because a workflow's token can't read self-hosted runners. On top of
# that, the job counts this repository's unfinished jobs on the local label, so two runs a few seconds apart don't
# both pick an idle Mac. Anything unexpected picks hosted: a wrong pick only costs time, never a check.
#
# Run: ruby scripts/pick-mac-runner.rb (in the workflow; tests in scripts/test/pick_mac_runner_test.rb)
require "json"
require "open3"
require "time"

module PickMacRunner
  LABEL = "spoonjoy-local-mac"
  # The heartbeat writes at least every 2 minutes; a sleeping or unplugged Mac stops writing.
  MAX_AGE_SECONDS = 300
  MAX_RUN_WAIT_SECONDS = 1800
  ACTIVE_JOB_STATUSES = %w[queued in_progress waiting pending requested].freeze

  module_function

  # Only trusted runs may use the Mac: the merge queue and pushes to main or release/**. Never a pull request.
  def trusted_event?(event, ref)
    return true if event == "merge_group"

    event == "push" && (ref == "refs/heads/main" || ref.to_s.start_with?("refs/heads/release/"))
  end

  # Returns [runner, reason]; runner is "local" or "hosted".
  # vars.SPOONJOY_LOCAL_MAC is read when the run attempt starts (run_started), not when this job runs, so the heartbeat's
  # age is measured from then. A heartbeat read more than MAX_RUN_WAIT_SECONDS ago says too little about the Mac now.
  def choose(event:, ref:, heartbeat:, now:, active_local_jobs:, run_started: nil)
    return ["hosted", "#{event} runs never use the local Mac"] unless trusted_event?(event, ref)

    version, at, state, free = heartbeat.to_s.split
    return ["hosted", "no heartbeat from the local Mac"] unless version == "v1" && at.to_s.match?(/\A\d+\z/)

    read_at = run_started || now
    if now - read_at > MAX_RUN_WAIT_SECONDS
      return ["hosted", "this run attempt started over #{MAX_RUN_WAIT_SECONDS / 60} min ago, so the heartbeat it read is out of date"]
    end

    age = read_at - at.to_i
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

  # When this run attempt started, which is when it read vars.SPOONJOY_LOCAL_MAC; nil (age from now) if GitHub can't say.
  def attempt_started(env, out)
    path = "repos/#{env.fetch('GITHUB_REPOSITORY')}/actions/runs/#{env.fetch('GITHUB_RUN_ID')}/attempts/#{env.fetch('GITHUB_RUN_ATTEMPT')}"
    Time.parse(gh_json(path).first.fetch("run_started_at")).to_i
  rescue StandardError => e
    out.puts "Couldn't read when this run attempt started (#{e.message}); measuring the heartbeat from now."
    nil
  end

  def main(env = ENV, out: $stdout)
    event = env.fetch("GITHUB_EVENT_NAME", "")
    ref = env.fetch("GITHUB_REF", "")
    active = nil
    run_started = nil
    if trusted_event?(event, ref)
      begin
        active = active_local_jobs(env.fetch("GITHUB_REPOSITORY"))
      rescue StandardError => e
        out.puts "Couldn't count jobs on the local Mac (#{e.message}); picking hosted."
      end
      run_started = attempt_started(env, out)
    end
    runner, reason = choose(event: event, ref: ref, heartbeat: env["SPOONJOY_LOCAL_MAC"], now: Time.now.to_i,
                            active_local_jobs: active, run_started: run_started)
    out.puts "App bundle, Reins journeys and Native scenario verifier run on #{runner == 'local' ? 'the local Mac' : 'hosted runners'}: #{reason}."
    File.open(env["GITHUB_OUTPUT"], "a") { |file| file.puts "mac=#{runner}" } if env["GITHUB_OUTPUT"]
    if env["GITHUB_STEP_SUMMARY"]
      File.open(env["GITHUB_STEP_SUMMARY"], "a") { |file| file.puts "App bundle, Reins journeys and Native scenario verifier: **#{runner}**, #{reason}." }
    end
    runner
  end
end

PickMacRunner.main if $PROGRAM_NAME == __FILE__
