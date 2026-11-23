# frozen_string_literal: true

# Reruns a pull request's Native run when its only failures are jobs GitHub's hosted macOS pool never placed: they wait
# 15 to 35 minutes with no runner, then GitHub cancels them with "The job was not acquired by Runner of type hosted even
# after multiple attempts" (#450). Up to attempt 3; a run with any other failure is left for a person.
#
# Run: ruby scripts/rerun-unplaced-mac-jobs.rb (in rerun-unplaced-mac-jobs.yml; tests in
# scripts/test/rerun_unplaced_mac_jobs_test.rb)
require "json"
require "open3"

module RerunUnplacedMacJobs
  UNPLACED = "was not acquired by Runner"
  LAST_ATTEMPT = 3

  module_function

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

RerunUnplacedMacJobs.main if $PROGRAM_NAME == __FILE__
