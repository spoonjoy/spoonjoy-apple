# frozen_string_literal: true

# Reruns a pull request's Native run when its only failures are jobs GitHub's hosted macOS pool never placed: they wait
# 15 to 35 minutes with no runner, then GitHub cancels them with "The job was not acquired by Runner of type hosted even
# after multiple attempts" (#450). Up to attempt 3; a run with any other failure is left for a person.
#
# Run: ruby scripts/rerun-unplaced-mac-jobs.rb (in rerun-unplaced-mac-jobs.yml; tests in
# scripts/test/rerun_unplaced_mac_jobs_test.rb)
#
# With --sweep (every 10 minutes, from the same workflow) it also catches a job GitHub neither places nor cancels: on
# 2026-11-24 #460's Reins journeys sat queued with no runner for over an hour while other macos-26 jobs were placed,
# and at the head of lane b's even group it held every even pull request's short checks. A pull request's Native run
# whose hosted macOS job has been queued for a runner over STUCK_MINUTES, while fewer than HOSTED_MAC_CAP hosted macOS
# jobs run, is cancelled and its failed jobs rerun. A job pending in its lane's concurrency group is waiting its turn,
# not stuck, and is never touched.
require "json"
require "open3"
require "time"

module RerunUnplacedMacJobs
  UNPLACED = "was not acquired by Runner"
  LAST_ATTEMPT = 3
  STUCK_MINUTES = 20
  # GitHub Free runs at most 5 macOS jobs at once across the org (xcode-27 included); at the cap, waiting is expected.
  HOSTED_MAC_CAP = 5
  HOSTED_MAC_LABEL = /\A(macos-|xcode-)/

  module_function

  def hosted_mac?(job)
    Array(job["labels"]).any? { |label| label.match?(HOSTED_MAC_LABEL) }
  end

  # Hosted macOS jobs waiting for a runner (not pending in a lane) for more than STUCK_MINUTES.
  def stuck_jobs(jobs, now: Time.now)
    jobs.select do |job|
      job["status"] == "queued" && job["runner_name"].to_s.empty? && hosted_mac?(job) &&
        now - Time.parse(job["started_at"]) > STUCK_MINUTES * 60
    end
  end

  # Returns [:restart or :none, reason].
  def decide_sweep(event:, attempt:, stuck:, busy_hosted_macs:)
    return [:none, "#{event} runs are not restarted: only a pull request's run still has a check waiting on it"] unless event == "pull_request"
    return [:none, "no job is stuck"] if stuck.empty?
    names = stuck.map { |job| job["name"] }.join(", ")
    if busy_hosted_macs >= HOSTED_MAC_CAP
      return [:none, "#{busy_hosted_macs} hosted macOS jobs are running, the cap of #{HOSTED_MAC_CAP}: #{names} is waiting its turn"]
    end
    return [:none, "attempt #{attempt} was the last: #{names} is still stuck"] if attempt >= LAST_ATTEMPT

    [:restart, "GitHub has not placed #{names} for over #{STUCK_MINUTES} minutes while #{busy_hosted_macs} hosted macOS job(s) run"]
  end

  def unplaced?(job)
    job["conclusion"] == "cancelled" && job["runner_name"].to_s.empty? &&
      job["messages"].any? { |message| message.include?(UNPLACED) }
  end

  # Returns [:rerun or :none, reason].
  def decide(event:, attempt:, jobs:)
    return [:none, "#{event} runs are not rerun: only a pull request's run still has a check waiting on it"] unless event == "pull_request"

    failed = jobs.select { |job| %w[failure cancelled timed_out].include?(job["conclusion"]) }
    unplaced, other = failed.partition { |job| unplaced?(job) }
    return [:none, "no job went unplaced"] if unplaced.empty?
    return [:none, "#{other.map { |job| job['name'] }.join(', ')} failed for another reason"] unless other.empty?
    return [:none, "attempt #{attempt} was the last: #{unplaced.map { |job| job['name'] }.join(', ')} still went unplaced"] if attempt >= LAST_ATTEMPT

    [:rerun, "GitHub never placed #{unplaced.map { |job| job['name'] }.join(', ')} on attempt #{attempt}"]
  end

  def gh(*args)
    out, status = Open3.capture2("gh", *args)
    raise "gh #{args.first(3).join(' ')} failed" unless status.success?

    out
  end

  def main(env = ENV)
    repo = env.fetch("GITHUB_REPOSITORY")
    run_id = env.fetch("RUN_ID")
    run = JSON.parse(gh("api", "repos/#{repo}/actions/runs/#{run_id}"))
    jobs = JSON.parse(gh("api", "--paginate", "--slurp", "repos/#{repo}/actions/runs/#{run_id}/attempts/#{run['run_attempt']}/jobs?per_page=100"))
               .flat_map { |page| page["jobs"] }
    jobs.each do |job|
      job["messages"] = []
      next unless job["conclusion"] == "cancelled" && job["runner_name"].to_s.empty?

      annotations = JSON.parse(gh("api", "repos/#{repo}/check-runs/#{job['id']}/annotations"))
      job["messages"] = annotations.map { |annotation| annotation["message"].to_s }
    end
    action, reason = decide(event: run["event"], attempt: run["run_attempt"], jobs: jobs)
    puts "#{action}: #{reason}"
    gh("run", "rerun", run_id.to_s, "--failed", "--repo", repo) if action == :rerun
  end
end

module RerunUnplacedMacJobs
  module_function

  def gh_jobs(repo, run_id)
    JSON.parse(gh("api", "--paginate", "--slurp", "repos/#{repo}/actions/runs/#{run_id}/jobs?filter=latest&per_page=100"))
        .flat_map { |page| page["jobs"] }
  end

  # Cancels each pull request Native run with a stuck job, waits for the cancel to finish, then reruns its failed jobs.
  def sweep(env = ENV)
    repo = env.fetch("GITHUB_REPOSITORY")
    # Every unfinished run in the repository counts toward the hosted Macs in use (After TestFlight, Mac capture and
    # others too); only Native's pull request runs are restarted. The token can't see other repositories, which run no
    # macOS jobs today.
    runs = %w[queued in_progress].flat_map do |status|
      JSON.parse(gh("api", "repos/#{repo}/actions/runs?status=#{status}&per_page=100"))["workflow_runs"]
    end.uniq { |run| run["id"] }
    jobs = runs.to_h { |run| [run["id"], gh_jobs(repo, run["id"])] }
    busy = jobs.values.flatten.count { |job| job["status"] == "in_progress" && hosted_mac?(job) }
    runs.select { |run| run["path"].to_s.start_with?(".github/workflows/native.yml") }.each do |run|
      action, reason = decide_sweep(event: run["event"], attempt: run["run_attempt"], stuck: stuck_jobs(jobs[run["id"]]),
                                    busy_hosted_macs: busy)
      puts "run #{run['id']} (#{run['event']}, #{run['head_branch']}): #{action}: #{reason}"
      next unless action == :restart

      gh("run", "cancel", run["id"].to_s, "--repo", repo)
      12.times do
        break if JSON.parse(gh("api", "repos/#{repo}/actions/runs/#{run['id']}"))["status"] == "completed"

        sleep 10
      end
      gh("run", "rerun", run["id"].to_s, "--failed", "--repo", repo)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ARGV.include?("--sweep") ? RerunUnplacedMacJobs.sweep : RerunUnplacedMacJobs.main
end
