# frozen_string_literal: true

# Run: ruby scripts/test/release_train_builds_test.rb
#
# Staging or submitting both platforms needs the iOS and Mac builds TestFlight published from one source commit.
require "minitest/autorun"
require_relative "../lib/release_train_builds"

class ReleaseTrainBuildsTest < Minitest::Test
  SHA = "1886e08545eb41769dd79a64dc3705987b0a8cc5"
  OTHER = "0ab314849ea90092f99c0c997b565676cee684d8"

  def run_row(id, created)
    { "id" => id, "created_at" => created }
  end

  def ios(sha = SHA) = { "sourceSha" => sha, "buildNumber" => "156", "buildId" => "ios-build" }
  def mac(sha = SHA) = { "platform" => "MAC_OS", "sourceSha" => sha, "buildNumber" => "61", "buildId" => "mac-build", "processingState" => "VALID" }

  # Both platforms' artifacts name the same run; it is tried once, newest run first.
  def test_candidate_runs_are_unique_and_newest_first
    runs = [run_row(1, "2026-11-10T00:00:00Z"), run_row(3, "2026-11-11T00:00:00Z"), run_row(1, "2026-11-10T00:00:01Z")]
    assert_equal [3, 1], ReleaseTrainBuilds.candidate_runs(runs).map { |run| run["id"] }
  end

  class FakeArtifacts
    attr_reader :asked

    def initialize(summaries)
      @summaries = summaries
      @asked = []
    end

    def runs(sha) = sha == SHA ? [{ "id" => 8, "created_at" => "2026-11-11T01:00:00Z" }, { "id" => 9, "created_at" => "2026-11-11T02:00:00Z" }] : []

    def summary(run_id, artifact, file)
      @asked << [run_id, artifact, file]
      @summaries.dig(run_id, file)
    end
  end

  def test_finds_both_builds_from_one_run
    artifacts = FakeArtifacts.new(9 => { "testflight-publish-summary.json" => ios, "mac-app-store-publish-summary.json" => mac })
    found = ReleaseTrainBuilds.find(SHA, artifacts)
    assert_equal({ "runId" => 9, "IOS" => { "buildNumber" => "156", "buildId" => "ios-build" },
                   "MAC_OS" => { "buildNumber" => "61", "buildId" => "mac-build" } }, found)
    assert_includes artifacts.asked, [9, "testflight-publish-artifacts-#{SHA}", "testflight-publish-summary.json"]
    assert_includes artifacts.asked, [9, "mac-app-store-publish-artifacts-#{SHA}", "mac-app-store-publish-summary.json"]
  end

  # A superseded run, or one whose Mac upload failed, publishes no summary for that platform; an older run may.
  def test_skips_a_run_missing_a_platform
    artifacts = FakeArtifacts.new(9 => { "testflight-publish-summary.json" => ios },
                                  8 => { "testflight-publish-summary.json" => ios, "mac-app-store-publish-summary.json" => mac })
    assert_equal 8, ReleaseTrainBuilds.find(SHA, artifacts)["runId"]
  end

  def test_refuses_without_both_builds_from_the_commit
    artifacts = FakeArtifacts.new(9 => { "testflight-publish-summary.json" => ios, "mac-app-store-publish-summary.json" => mac(OTHER) },
                                  8 => { "testflight-publish-summary.json" => ios })
    error = assert_raises(ReleaseTrainBuilds::Error) { ReleaseTrainBuilds.find(SHA, artifacts) }
    assert_equal "No TestFlight run published both an iOS and a Mac build from #{SHA}. Run 9: macOS summary is for " \
                 "#{OTHER}. Run 8: no macOS summary. Dispatch TestFlight for this commit, then try again.", error.message
  end

  def test_refuses_when_the_commit_has_no_testflight_run
    artifacts = FakeArtifacts.new({})
    def artifacts.runs(_sha) = []
    error = assert_raises(ReleaseTrainBuilds::Error) { ReleaseTrainBuilds.find(SHA, artifacts) }
    assert_match(/No TestFlight run published both an iOS and a Mac build from #{SHA}\. No TestFlight run uploaded a publish summary/, error.message)
  end

  def test_refuses_a_summary_that_is_not_valid
    artifacts = FakeArtifacts.new(9 => { "testflight-publish-summary.json" => ios,
                                         "mac-app-store-publish-summary.json" => mac.merge("processingState" => "PROCESSING") })
    def artifacts.runs(sha) = super.last(1)
    error = assert_raises(ReleaseTrainBuilds::Error) { ReleaseTrainBuilds.find(SHA, artifacts) }
    assert_match(/Run 9: macOS build 61 is PROCESSING, not VALID/, error.message)
  end
end
