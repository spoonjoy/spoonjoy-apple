# frozen_string_literal: true

# Run: ruby scripts/test/rerun_unplaced_mac_jobs_test.rb
#
# GitHub's hosted macOS pool sometimes never places a job and cancels it after 15 to 35 minutes with "The job was not
# acquired by Runner of type hosted even after multiple attempts" (#450). A pull request's Native run with only such
# jobs failing gets its failed jobs rerun, a bounded number of times; anything else is left alone.
require "minitest/autorun"
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

  def test_the_workflow_watches_native_and_may_only_rerun
    wf = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows/rerun-unplaced-mac-jobs.yml")))
    on = wf["on"] || wf[true]
    assert_equal ["Native"], on.dig("workflow_run", "workflows")
    assert_equal ["completed"], on.dig("workflow_run", "types")
    assert_equal({ "actions" => "write", "checks" => "read" }, wf["permissions"])
    job = wf["jobs"].values.first
    assert_match(/ubuntu/, job["runs-on"])
    assert_includes job["if"], "github.event.workflow_run.event == 'pull_request'"
  end
end
