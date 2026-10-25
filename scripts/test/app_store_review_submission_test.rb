# frozen_string_literal: true

# Run: ruby scripts/test/app_store_review_submission_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_review_submission"

class AppStoreReviewSubmissionTest < Minitest::Test
  def plan(version:, submission: nil)
    AppStoreReviewSubmission.plan(version: version, submission: submission, platform: "IOS", version_string: "1.0")
  end

  def ready
    { "id" => "v1", "state" => "PREPARE_FOR_SUBMISSION", "buildId" => "b92" }
  end

  def test_fresh_version_creates_adds_and_submits
    assert_equal %w[create_submission add_version submit], plan(version: ready)["steps"].map { |s| s["action"] }
  end

  def test_reuses_an_open_submission_that_already_holds_the_version
    steps = plan(version: ready, submission: { "id" => "s1", "versionIds" => ["v1"] })["steps"]
    assert_equal %w[submit], steps.map { |s| s["action"] }
  end

  def test_refuses_without_a_build_a_version_or_a_submittable_state
    assert_match(/no build/, plan(version: ready.merge("buildId" => nil))["error"])
    assert_match(/No IOS version/, plan(version: nil)["error"])
    assert_match(/WAITING_FOR_REVIEW/, plan(version: ready.merge("state" => "WAITING_FOR_REVIEW"))["error"])
  end

  class FakeClient
    attr_reader :writes

    def initialize(responses)
      @responses = responses
      @writes = []
    end

    def get(path, _query = {})
      @responses.fetch(path)
    end

    def post(path, body)
      @writes << [:post, path, body]
      { "data" => { "id" => "s-new" } }
    end

    def patch(path, body)
      @writes << [:patch, path, body]
      { "data" => { "attributes" => { "state" => "WAITING_FOR_REVIEW" } } }
    end
  end

  def runner_client
    FakeClient.new(
      "/v1/apps" => { "data" => [{ "id" => "app1" }] },
      "/v1/apps/app1/appStoreVersions" => { "data" => [{ "id" => "v1", "attributes" => { "appStoreState" => "PREPARE_FOR_SUBMISSION" } }] },
      "/v1/appStoreVersions/v1/build" => { "data" => { "id" => "b92" } },
      "/v1/reviewSubmissions" => { "data" => [] }
    )
  end

  def test_dry_run_writes_nothing
    client = runner_client
    AppStoreReviewSubmission::Runner.new(client, bundle_id: "app.spoonjoy", platform: "IOS", version_string: "1.0", log: StringIO.new).run(apply: false)
    assert_empty client.writes
  end

  def test_apply_creates_adds_then_submits_the_new_submission
    client = runner_client
    AppStoreReviewSubmission::Runner.new(client, bundle_id: "app.spoonjoy", platform: "IOS", version_string: "1.0", log: StringIO.new).run(apply: true)
    assert_equal [[:post, "/v1/reviewSubmissions"], [:post, "/v1/reviewSubmissionItems"], [:patch, "/v1/reviewSubmissions/s-new"]],
                 client.writes.map { |w| w.first(2) }
    assert_equal true, client.writes.last[2].dig("data", "attributes", "submitted")
  end
end
