# frozen_string_literal: true

# Run: ruby scripts/test/verify_testflight_release_candidate_test.rb
require "minitest/autorun"
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
