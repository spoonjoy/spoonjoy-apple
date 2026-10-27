# frozen_string_literal: true

# Run: ruby scripts/test/verify_testflight_release_candidate_test.rb
require "minitest/autorun"
require "json"
require "tmpdir"
require_relative "../verify-testflight-release-candidate"

class VerifyTestFlightReleaseCandidateTest < Minitest::Test
  SOURCE = "a" * 40
  MAIN = "b" * 40

  Evidence = Struct.new(:ancestor) do
    def checked_out_sha
      VerifyTestFlightReleaseCandidateTest::SOURCE
    end

    def main_ref
      { "object" => { "sha" => VerifyTestFlightReleaseCandidateTest::MAIN } }
    end

    def main_ancestor?(_source, _main)
      ancestor
    end
  end

  def verify(dir, superseded_ok:, ancestor: true, allow_rollback: false)
    TestFlightReleaseCandidateVerifier.new(
      source_sha: SOURCE, repository: "spoonjoy/spoonjoy-apple", allow_rollback: allow_rollback,
      rollback_reason: allow_rollback ? "test" : "", rollback_notes: "", output_dir: dir,
      evidence: Evidence.new(ancestor), superseded_ok: superseded_ok, github_output: File.join(dir, "out")
    ).verify
  end

  def test_automatic_run_skips_when_main_has_moved_past_it
    Dir.mktmpdir do |dir|
      assert verify(dir, superseded_ok: true)["superseded"]
      assert_includes File.read(File.join(dir, "out")), "superseded=true"
      assert File.exist?(File.join(dir, "testflight-release-candidate-superseded.json"))
    end
  end

  def test_manual_run_still_needs_an_explicit_rollback
    Dir.mktmpdir do |dir|
      error = assert_raises(CandidateVerificationError) { verify(dir, superseded_ok: false) }
      assert_match(/not current main/, error.message)
    end
  end

  def test_a_commit_off_main_is_never_superseded
    Dir.mktmpdir do |dir|
      error = assert_raises(CandidateVerificationError) { verify(dir, superseded_ok: true, ancestor: false) }
      assert_match(/not an ancestor of main/, error.message)
    end
  end

  class ReleaseBranchEvidence
    attr_reader :queried_branch

    def initialize(head: VerifyTestFlightReleaseCandidateTest::SOURCE, run_branch: "release/1.0-resubmit", conclusion: "success")
      @head = head
      @run_branch = run_branch
      @conclusion = conclusion
    end

    def checked_out_sha
      VerifyTestFlightReleaseCandidateTest::SOURCE
    end

    def main_ref
      raise "a release-branch build must not consult main"
    end

    def branch_ref(_branch)
      { "object" => { "sha" => @head } }
    end

    def workflow_runs(source_sha, branch:)
      @queried_branch = branch
      { "workflow_runs" => [{ "id" => 7, "run_number" => 3, "run_attempt" => 1, "head_sha" => source_sha,
                              "head_branch" => @run_branch, "event" => "push", "path" => ".github/workflows/native.yml",
                              "status" => "completed", "conclusion" => @conclusion }] }
    end

    def jobs(_run_id)
      { "jobs" => TestFlightReleaseCandidateVerifier::REQUIRED_NATIVE_JOBS.map do |name|
        { "name" => name, "status" => "completed", "conclusion" => "success" }
      end }
    end
  end

  def verify_release_branch(dir, evidence, branch: "release/1.0-resubmit", notes: "Fixes a launch issue.", allow_rollback: false)
    TestFlightReleaseCandidateVerifier.new(
      source_sha: SOURCE, repository: "spoonjoy/spoonjoy-apple", allow_rollback: allow_rollback,
      rollback_reason: allow_rollback ? "test" : "", rollback_notes: notes, output_dir: dir,
      evidence: evidence, release_branch: branch, github_output: File.join(dir, "out")
    ).verify
  end

  def test_release_branch_head_with_a_green_native_run_is_a_candidate
    Dir.mktmpdir do |dir|
      evidence = ReleaseBranchEvidence.new
      attestation = verify_release_branch(dir, evidence)
      assert_equal "release/1.0-resubmit", attestation["releaseBranch"]
      assert_nil attestation["mainSha"]
      refute attestation["rollback"]
      assert_equal "Fixes a launch issue.", attestation["releaseNotes"]
      assert_equal "release/1.0-resubmit", evidence.queried_branch
      notes = JSON.parse(File.read(attestation["releaseNotesPath"]))
      assert_equal "releaseBranch", notes["origin"]
    end
  end

  def test_release_branch_must_be_named_release
    Dir.mktmpdir do |dir|
      error = assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new, branch: "feature/x") }
      assert_match(%r{release/<version>}, error.message)
    end
  end

  def test_release_branch_build_must_be_the_branch_head
    Dir.mktmpdir do |dir|
      error = assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new(head: MAIN)) }
      assert_match(/not the head of release/, error.message)
    end
  end

  def test_release_branch_build_needs_notes_and_is_never_a_rollback
    Dir.mktmpdir do |dir|
      assert_match(/needs release notes/, assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new, notes: "") }.message)
      assert_match(/cannot also be a rollback/, assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new, allow_rollback: true) }.message)
    end
  end

  def test_release_branch_build_needs_a_green_native_run_on_that_branch
    Dir.mktmpdir do |dir|
      assert_match(/no exact Native push run/, assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new(run_branch: "main")) }.message)
      assert_match(/was not successful/, assert_raises(CandidateVerificationError) { verify_release_branch(dir, ReleaseBranchEvidence.new(conclusion: "failure")) }.message)
    end
  end

  class FakeRunner
    attr_reader :calls

    def initialize(present:)
      @present = present
      @calls = []
    end

    def capture(*arguments, allowed_statuses: [0])
      @calls << arguments
      status = arguments[1] == "cat-file" && !@present ? 128 : 0
      CommandRunner::Result.new(stdout: "", stderr: "", status: status)
    end
  end

  def test_fetches_main_when_the_checkout_predates_it
    runner = FakeRunner.new(present: false)
    assert LiveCandidateEvidence.new(repository: "o/r", output_dir: Dir.tmpdir, runner: runner).main_ancestor?(SOURCE, MAIN)
    assert_includes runner.calls, ["git", "fetch", "--no-tags", "--quiet", "origin", MAIN]
  end

  def test_skips_the_fetch_when_main_is_already_present
    runner = FakeRunner.new(present: true)
    LiveCandidateEvidence.new(repository: "o/r", output_dir: Dir.tmpdir, runner: runner).main_ancestor?(SOURCE, MAIN)
    refute(runner.calls.any? { |call| call[1] == "fetch" })
  end
end
