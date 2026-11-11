# frozen_string_literal: true

# Run: ruby scripts/test/green_commit_test.rb
#
# Publish only from green: TestFlight, "Stage App Store listing" and "Submit for App Review" act on a commit only
# after its own Native push run passed every check main requires.
require "minitest/autorun"
require "yaml"
require_relative "../lib/green_commit"

class GreenCommitTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SHA = "a" * 40

  def run_for(sha: SHA, branch: "main", event: "push", number: 1, attempt: 1, id: 10, conclusion: "success", status: "completed")
    { "id" => id, "head_sha" => sha, "head_branch" => branch, "event" => event, "path" => ".github/workflows/native.yml",
      "run_number" => number, "run_attempt" => attempt, "status" => status, "conclusion" => conclusion }
  end

  def green_jobs(names = GreenCommit::REQUIRED_CHECKS)
    names.map { |name| { "name" => name, "status" => "completed", "conclusion" => "success" } }
  end

  def test_the_latest_exact_push_run_wins
    runs = [run_for(id: 1, number: 1), run_for(id: 2, number: 2, attempt: 2), run_for(id: 3, number: 2, attempt: 1),
            run_for(id: 4, event: "pull_request", number: 9), run_for(id: 5, branch: "release/1.1", number: 9),
            run_for(id: 6, sha: "b" * 40, number: 9)]
    assert_equal 2, GreenCommit.latest_run(runs, sha: SHA, branch: "main")["id"]
    error = assert_raises(GreenCommit::NotGreen) { GreenCommit.latest_run(runs, sha: "c" * 40, branch: "main") }
    assert_match(/no Native push run on main/, error.message)
  end

  def test_a_green_run_with_every_required_check_passes
    assert GreenCommit.require_green!(run_for, green_jobs)
  end

  def test_a_red_or_unfinished_run_is_refused
    assert_match(/completed\/failure, not green/, assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for(conclusion: "failure"), green_jobs) }.message)
    assert_match(/in_progress\/pending/, assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for(status: "in_progress", conclusion: nil), green_jobs) }.message)
  end

  # A skipped job leaves the run green, so each required check is read on its own.
  def test_a_missing_skipped_or_doubled_check_is_refused
    GreenCommit::REQUIRED_CHECKS.each do |name|
      missing = green_jobs.reject { |job| job["name"] == name }
      assert_match(/no #{name} job/, assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for, missing) }.message)
      skipped = green_jobs.map { |job| job["name"] == name ? job.merge("conclusion" => "skipped") : job }
      assert_match(/#{name} did not pass/, assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for, skipped) }.message)
    end
    doubled = green_jobs + green_jobs.first(1)
    assert_match(/has 2 Swift tests jobs/, assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for, doubled) }.message)
  end

  def test_a_release_branch_cut_before_reins_journeys_may_lack_it_but_main_may_not
    old = green_jobs(GreenCommit::REQUIRED_CHECKS - ["Reins journeys"])
    assert GreenCommit.require_green!(run_for(branch: "release/1.0-resubmit"), old)
    assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for, old) }
    failed = old + [{ "name" => "Reins journeys", "status" => "completed", "conclusion" => "failure" }]
    assert_raises(GreenCommit::NotGreen) { GreenCommit.require_green!(run_for(branch: "release/1.0-resubmit"), failed) }
  end

  # An explicit TestFlight rollback may select a main commit from before Reins journeys (#212).
  def test_an_explicit_rollback_may_lack_reins_journeys_but_never_fail_it
    old = green_jobs(GreenCommit::REQUIRED_CHECKS - ["Reins journeys"])
    assert_equal GreenCommit::REQUIRED_CHECKS - ["Reins journeys"], GreenCommit.required_for("main", old, rollback: true)
    assert_equal GreenCommit::REQUIRED_CHECKS, GreenCommit.required_for("main", old)
    failed = old + [{ "name" => "Reins journeys", "status" => "completed", "conclusion" => "failure" }]
    assert_includes GreenCommit.required_for("main", failed, rollback: true), "Reins journeys"
    verifier = File.read(File.join(ROOT, "scripts/verify-testflight-release-candidate.rb"))
    assert_match(/validate_required_jobs\(run\.fetch\("id"\), require_release_note: !explicit_rollback_notes, rollback: rollback\)/, verifier)
  end

  def test_required_checks_match_natives_job_names
    native = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows/native.yml")))
    names = native.fetch("jobs").values.map { |job| job["name"] }
    GreenCommit::REQUIRED_CHECKS.each { |name| assert_includes names, name }
    agents = File.read(File.join(ROOT, "AGENTS.md"))
    GreenCommit::REQUIRED_CHECKS.each { |name| assert_includes agents, "`#{name}`" }
  end

  # Every workflow that publishes reads the green commit before it touches App Store Connect.
  def test_publishing_workflows_gate_on_a_green_commit
    %w[stage-app-store-listing.yml submit-app-store-review.yml].each do |name|
      doc = YAML.safe_load(File.read(File.join(ROOT, ".github/workflows", name)))
      assert_equal "read", doc.fetch("permissions").fetch("actions"), name
      steps = doc.fetch("jobs").values.first.fetch("steps")
      gate = steps.index { |step| step["id"] == "green" }
      refute_nil gate, "#{name} has no green gate"
      assert_match(/require-green-commit\.rb/, steps[gate].fetch("run"))
      secret_step = steps.index { |step| step.fetch("env", {}).values.any? { |v| v.to_s.include?("secrets.") } }
      assert_operator gate, :<, secret_step, "#{name} gates before any step that sees App Store Connect secrets"
      checkout = steps.index { |step| step.dig("with", "path") == "release-source" }
      assert_operator gate, :<, checkout
      assert_equal "${{ steps.green.outputs.sha }}", steps[checkout].dig("with", "ref")
    end
    testflight = File.read(File.join(ROOT, "scripts/verify-testflight-release-candidate.rb"))
    assert_includes testflight, "GreenCommit::REQUIRED_CHECKS"
  end
end
