# frozen_string_literal: true

# Run: ruby scripts/test/app_store_release_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_release"

class AppStoreReleaseTest < Minitest::Test
  def plan(action, version, release_type: nil)
    AppStoreRelease.plan(action: action, version: version, platform: "IOS", version_string: "1.0", release_type: release_type)
  end

  def waiting
    { "id" => "v1", "state" => "WAITING_FOR_REVIEW", "releaseType" => "MANUAL" }
  end

  def test_status_never_changes_anything
    assert_equal [], plan("status", waiting)["steps"]
  end

  def test_sets_the_release_type_of_a_version_in_review
    steps = plan("set-release-type", waiting, release_type: "AFTER_APPROVAL")["steps"]
    assert_equal [["patch_release_type", "AFTER_APPROVAL"]], steps.map { |s| [s["action"], s["releaseType"]] }
  end

  def test_skips_a_release_type_that_already_matches_and_refuses_unknown_ones
    assert_equal [], plan("set-release-type", waiting.merge("releaseType" => "AFTER_APPROVAL"), release_type: "AFTER_APPROVAL")["steps"]
    assert_match(/Unknown release type/, plan("set-release-type", waiting, release_type: "SOON")["error"])
  end

  def test_releases_only_a_version_pending_developer_release
    assert_match(/only PENDING_DEVELOPER_RELEASE/, plan("release", waiting)["error"])
    assert_equal %w[release], plan("release", waiting.merge("state" => "PENDING_DEVELOPER_RELEASE"))["steps"].map { |s| s["action"] }
  end

  def test_refuses_a_missing_version_or_unknown_action
    assert_match(/No IOS version/, plan("status", nil)["error"])
    assert_match(/Unknown action/, plan("ship", waiting)["error"])
  end

  class FakeClient
    attr_reader :writes

    def initialize(release_type)
      @release_type = release_type
      @writes = []
    end

    def get(path, _query = {})
      case path
      when "/v1/apps" then { "data" => [{ "id" => "app1" }] }
      when "/v1/apps/app1/appStoreVersions"
        { "data" => [{ "id" => "v1", "attributes" => { "appStoreState" => "WAITING_FOR_REVIEW", "releaseType" => @release_type } }] }
      when "/v1/apps/app1/appInfos" then { "data" => [{ "attributes" => { "state" => "WAITING_FOR_REVIEW", "appStoreAgeRating" => "FOUR_PLUS" } }] }
      end
    end

    def patch(path, body)
      @writes << [path, body]
      @release_type = body.dig("data", "attributes", "releaseType")
      {}
    end
  end

  def test_runner_dry_run_writes_nothing_and_apply_patches_then_reads_back
    client = FakeClient.new("MANUAL")
    log = StringIO.new
    runner = AppStoreRelease::Runner.new(client, bundle_id: "app.spoonjoy", platform: "IOS", version_string: "1.0", log: log)
    runner.run(action: "set-release-type", apply: false, release_type: "AFTER_APPROVAL")
    assert_empty client.writes
    assert_match(/FOUR_PLUS/, log.string)

    runner.run(action: "set-release-type", apply: true, release_type: "AFTER_APPROVAL")
    assert_equal ["/v1/appStoreVersions/v1"], client.writes.map(&:first)
    assert_match(/After:\nIOS 1.0: state WAITING_FOR_REVIEW, release AFTER_APPROVAL/, log.string)
  end
end
