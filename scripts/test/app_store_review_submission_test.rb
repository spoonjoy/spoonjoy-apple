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
    steps = plan(version: ready, submission: { "id" => "s1", "state" => "READY_FOR_REVIEW", "versionIds" => ["v1"], "otherItems" => 0 })["steps"]
    assert_equal %w[submit], steps.map { |s| s["action"] }
  end

  def test_refuses_without_a_build_a_version_or_a_submittable_state
    assert_match(/no build/, plan(version: ready.merge("buildId" => nil))["error"])
    assert_match(/No IOS version/, plan(version: nil)["error"])
    assert_match(/WAITING_FOR_REVIEW/, plan(version: ready.merge("state" => "WAITING_FOR_REVIEW"))["error"])
  end

  def test_resubmits_a_rejected_version_through_its_unresolved_submission
    rejected = ready.merge("state" => "REJECTED")
    steps = plan(version: rejected, submission: { "id" => "s1", "state" => "UNRESOLVED_ISSUES", "versionIds" => ["v1"], "otherItems" => 0 })["steps"]
    assert_equal %w[submit], steps.map { |s| s["action"] }
  end

  def test_refuses_a_submission_that_holds_other_items
    error = plan(version: ready, submission: { "id" => "s1", "state" => "READY_FOR_REVIEW", "versionIds" => [], "otherItems" => 2 })["error"]
    assert_match(/2 other item/, error)
  end

  def test_finds_the_unresolved_submission_holding_the_version_even_without_a_platform
    client = runner_client
    client.responses["/v1/reviewSubmissions"] = { "data" => [{ "id" => "s9", "attributes" => { "state" => "UNRESOLVED_ISSUES", "platform" => nil } }] }
    client.responses["/v1/reviewSubmissions/s9/items"] = { "data" => [{ "relationships" => { "appStoreVersion" => { "data" => { "id" => "v1" } } } }] }
    client.responses["/v1/apps/app1/appStoreVersions"] = { "data" => [{ "id" => "v1", "attributes" => { "appVersionState" => "REJECTED" } }] }
    AppStoreReviewSubmission::Runner.new(client, bundle_id: "app.spoonjoy", platform: "IOS", version_string: "1.0", log: StringIO.new).run(apply: true)
    assert_equal [[:patch, "/v1/reviewSubmissions/s9"]], client.writes.map { |w| w.first(2) }
  end

  def test_marks_the_rejected_item_resolved_before_resubmitting
    rejected = ready.merge("state" => "REJECTED")
    steps = plan(version: rejected, submission: { "id" => "s1", "state" => "UNRESOLVED_ISSUES", "versionIds" => ["v1"],
                                                  "rejectedItemIds" => ["it1"], "otherItems" => 0 })["steps"]
    assert_equal %w[resolve_items submit], steps.map { |s| s["action"] }
  end

  def test_resolves_the_rejected_item_then_patches_the_same_submission
    client = runner_client
    client.responses["/v1/reviewSubmissions"] = { "data" => [{ "id" => "s9", "attributes" => { "state" => "UNRESOLVED_ISSUES", "platform" => "IOS" } }] }
    client.responses["/v1/reviewSubmissions/s9/items"] = { "data" => [
      { "id" => "it1", "attributes" => { "state" => "REJECTED" }, "relationships" => { "appStoreVersion" => { "data" => { "id" => "v1" } } } }
    ] }
    AppStoreReviewSubmission::Runner.new(client, bundle_id: "app.spoonjoy", platform: "IOS", version_string: "1.0", log: StringIO.new).run(apply: true)
    assert_equal [[:patch, "/v1/reviewSubmissionItems/it1"], [:patch, "/v1/reviewSubmissions/s9"]], client.writes.map { |w| w.first(2) }
    assert_equal({ "resolved" => true }, client.writes.first[2].dig("data", "attributes"))
  end

  class FakeClient
    attr_reader :writes, :responses

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
