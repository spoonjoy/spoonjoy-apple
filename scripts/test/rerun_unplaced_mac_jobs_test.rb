# frozen_string_literal: true

# Run: ruby scripts/test/rerun_unplaced_mac_jobs_test.rb
#
# GitHub's hosted macOS pool sometimes never places a job and cancels it after 15 to 35 minutes with "The job was not
# acquired by Runner of type hosted even after multiple attempts" (#450). A pull request's Native run with only such
# jobs failing gets its failed jobs rerun, a bounded number of times; anything else is left alone.
require "minitest/autorun"
require "time"
require "yaml"
require_relative "../rerun-unplaced-mac-jobs"

class RerunUnplacedMacJobsTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  UNPLACED = "The job was not acquired by Runner of type hosted even after multiple attempts"

  def job(name, conclusion, runner: nil, messages: [])
    { "name" => name, "conclusion" => conclusion, "runner_name" => runner, "messages" => messages }
  end

  def decide(event: "pull_request", attempt: 1, jobs:)
    RerunUnplacedMacJobs.decide(event: event, attempt: attempt, jobs: jobs)
  end

  def test_reruns_a_pull_request_run_whose_only_failure_is_an_unplaced_job
    jobs = [job("Swift tests", "cancelled", runner: "", messages: [UNPLACED]), job("Contracts", "success", runner: "GitHub Actions 1"),
            job("Journeys", "skipped")]
    action, reason = decide(jobs: jobs)
    assert_equal :rerun, action
    assert_includes reason, "Swift tests"
  end

  def test_leaves_a_run_with_a_real_failure_alone
    jobs = [job("Swift tests", "cancelled", runner: "", messages: [UNPLACED]),
            job("Contracts", "failure", runner: "GitHub Actions 1", messages: ["Process completed with exit code 1."])]
    assert_equal :none, decide(jobs: jobs).first
  end

  def test_leaves_a_job_cancelled_for_another_reason_alone
    assert_equal :none, decide(jobs: [job("Swift tests", "cancelled", runner: "", messages: [])]).first
    assert_equal :none, decide(jobs: [job("Swift tests", "cancelled", runner: "GitHub Actions 1", messages: [UNPLACED])]).first
  end

  def test_stops_after_the_third_attempt
    jobs = [job("Swift tests", "cancelled", runner: "", messages: [UNPLACED])]
    assert_equal :rerun, decide(attempt: 2, jobs: jobs).first
    action, reason = decide(attempt: 3, jobs: jobs)
    assert_equal :none, action
    assert_includes reason, "attempt 3"
  end

  # A merge-queue entry is already out of the queue when its run fails, so a rerun can't put it back; and a run for a
  # push to main has nothing waiting on it. Only pull request runs are rerun.
  def test_reruns_only_pull_request_runs
    jobs = [job("Reins journeys", "cancelled", runner: "", messages: [UNPLACED])]
    assert_equal :none, decide(event: "merge_group", jobs: jobs).first
    assert_equal :none, decide(event: "push", jobs: jobs).first
  end

  # Sometimes GitHub neither places a job nor cancels it: on 2026-11-24 #460's Reins journeys sat queued with no runner
  # for over an hour while other macos-26 jobs were placed, and as the head of lane b's even group it held every even
  # pull request's short checks. The sweep finds such a job (queued for a runner, not pending in a lane) and restarts it.
  NOW = Time.utc(2026, 11, 24, 20, 30)

  def queued(name, minutes, labels: ["macos-26"], status: "queued", runner: "")
    { "name" => name, "status" => status, "runner_name" => runner, "labels" => labels,
      "started_at" => (NOW - (minutes * 60)).utc.iso8601 }
  end

  def stuck(jobs)
    RerunUnplacedMacJobs.stuck_jobs(jobs, now: NOW)
  end

  def test_finds_a_hosted_mac_job_queued_for_a_runner_past_the_limit
    assert_equal ["Reins journeys"], stuck([queued("Reins journeys", 56), queued("Swift tests", 5)]).map { |j| j["name"] }
    assert_equal ["App bundle"], stuck([queued("App bundle", 31, labels: ["xcode-27"])]).map { |j| j["name"] }
  end

  def test_ignores_jobs_waiting_in_a_lane_running_or_off_the_hosted_macs
    assert_empty stuck([queued("Feel", 300, status: "pending")]), "a job pending in its lane's concurrency group is waiting its turn"
    assert_empty stuck([queued("Swift tests", 60, status: "in_progress", runner: "GitHub Actions 1")])
    assert_empty stuck([queued("Contracts", 60, labels: ["ubuntu-24.04"])])
    assert_empty stuck([queued("App bundle", 60, labels: ["spoonjoy-local-mac"])]), "the local Mac is not GitHub's pool"
  end

  def sweep(event: "pull_request", attempt: 1, stuck: [queued("Reins journeys", 56)], busy: 1)
    RerunUnplacedMacJobs.decide_sweep(event: event, attempt: attempt, stuck: stuck, busy_hosted_macs: busy)
  end

  def test_restarts_a_pull_request_run_with_a_stuck_job_while_hosted_macs_are_free
    action, reason = sweep
    assert_equal :restart, action
    assert_includes reason, "Reins journeys"
  end

  def test_leaves_a_run_alone_when_the_cap_explains_the_wait_or_it_is_not_a_pull_request
    action, reason = sweep(busy: 5)
    assert_equal :none, action, "with all 5 of GitHub Free's macOS jobs busy, the wait is the cap, not a lost job"
    assert_includes reason, "5"
    assert_equal :none, sweep(event: "merge_group").first
    assert_equal :none, sweep(event: "push").first
    assert_equal :none, sweep(stuck: []).first
    assert_equal :none, sweep(attempt: 3).first
  end

  def test_the_workflow_watches_native_and_may_only_rerun
    wf = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows/rerun-unplaced-mac-jobs.yml")))
    on = wf["on"] || wf[true]
    assert_equal ["Native"], on.dig("workflow_run", "workflows")
    assert_equal ["completed"], on.dig("workflow_run", "types")
    assert_equal({ "actions" => "write", "checks" => "read" }, wf["permissions"])
    job = wf["jobs"].fetch("rerun")
    assert_match(/ubuntu/, job["runs-on"])
    assert_includes job["if"], "github.event.workflow_run.event == 'pull_request'"
  end

  def test_the_workflow_sweeps_for_stuck_jobs_on_a_schedule
    wf = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows/rerun-unplaced-mac-jobs.yml")))
    on = wf["on"] || wf[true]
    assert_equal [{ "cron" => "*/10 * * * *" }], on["schedule"]
    assert on.key?("workflow_dispatch"), "a person can run the sweep at once"
    job = wf["jobs"].fetch("sweep")
    assert_match(/ubuntu/, job["runs-on"])
    assert_equal "github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'", job["if"]
    assert_includes job["steps"].last["run"], "ruby scripts/rerun-unplaced-mac-jobs.rb --sweep"
    assert_equal "rerun-unplaced-mac-jobs-sweep", job.dig("concurrency", "group"), "one sweep at a time"
  end
end
