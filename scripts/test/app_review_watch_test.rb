# frozen_string_literal: true

# Run: ruby scripts/test/app_review_watch_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_review_watch"

class AppReviewWatchTest < Minitest::Test
  def t(previous, current)
    AppReviewWatch.transition(previous, current, platform: "IOS", version: "1.0")
  end

  def test_no_change_announces_nothing
    assert_nil t("WAITING_FOR_REVIEW", "WAITING_FOR_REVIEW")
  end

  def test_rejection_says_how_to_read_the_reason
    change = t("WAITING_FOR_REVIEW", "REJECTED")
    assert_match(/Rejected/, change["comment"])
    assert_match(/review-messages/, change["comment"])
    assert_match(%r{/iris/v1/resolutionCenterThreads}, change["comment"])
    refute change["close"]
  end

  def test_metadata_rejection_and_invalid_binary_count_as_rejections
    assert_match(/Rejected/, t(nil, "METADATA_REJECTED")["comment"])
    assert_match(/Rejected/, t(nil, "INVALID_BINARY")["comment"])
  end

  def test_approval_names_the_next_step
    assert_match(/manual release/, t("IN_REVIEW", "PENDING_DEVELOPER_RELEASE")["comment"])
    assert_match(/Apple is releasing/, t("IN_REVIEW", "PENDING_APPLE_RELEASE")["comment"])
  end

  def test_live_closes_the_issue
    change = t("PENDING_APPLE_RELEASE", "READY_FOR_SALE")
    assert_match(/Live/, change["comment"])
    assert change["close"]
  end

  def test_resubmission_after_rejection_is_called_out
    assert_match(/again after a resubmission/, t("REJECTED", "WAITING_FOR_REVIEW")["comment"])
    refute_match(/again/, t(nil, "WAITING_FOR_REVIEW")["comment"])
    assert_match(/in review/, t("WAITING_FOR_REVIEW", "IN_REVIEW")["comment"])
    assert_match(/from `IN_REVIEW` to `DEVELOPER_REJECTED`/, t("IN_REVIEW", "DEVELOPER_REJECTED")["comment"])
  end

  def test_marker_round_trips_through_the_issue_body
    body = AppReviewWatch.body("IOS", "1.0", "REJECTED")
    assert_equal "REJECTED", AppReviewWatch.last_state(body)
    assert_nil AppReviewWatch.last_state("no marker")
  end

  def test_quiet_states_are_skipped_without_an_open_issue
    refute AppReviewWatch.watch?("READY_FOR_SALE", open_issue: false)
    refute AppReviewWatch.watch?("PREPARE_FOR_SUBMISSION", open_issue: false)
    assert AppReviewWatch.watch?("READY_FOR_SALE", open_issue: true)
    assert AppReviewWatch.watch?("WAITING_FOR_REVIEW", open_issue: false)
  end

  class FakeAsc
    def initialize(versions)
      @versions = versions
    end

    def get(_path, _query = {})
      { "data" => [{ "id" => "APP" }] }
    end

    def get_all(_path, query = {})
      (@versions[query["filter[platform]"]] || []).map do |version, state|
        { "attributes" => { "versionString" => version, "appStoreState" => state } }
      end
    end
  end

  class FakeIssues
    attr_reader :issues, :comments, :label_calls

    def initialize(issues = [])
      @issues = issues
      @comments = []
      @label_calls = 0
    end

    def open_issue(title)
      @issues.find { |i| i["title"] == title && i["state"] == "open" }
    end

    def ensure_label
      @label_calls += 1
    end

    def create(title, body)
      issue = { "number" => @issues.size + 1, "title" => title, "body" => body, "state" => "open" }
      @issues << issue
      issue
    end

    def comment(number, text)
      @comments << [number, text]
    end

    def update(number, fields)
      @issues.find { |i| i["number"] == number }.merge!(fields)
    end
  end

  def watch(versions, issues)
    AppReviewWatch::Runner.new(FakeAsc.new(versions), issues, bundle_id: "app.spoonjoy", log: StringIO.new).run
  end

  def test_opens_an_issue_for_a_rejection_and_records_the_state
    issues = FakeIssues.new
    announced = watch({ "IOS" => [["1.0", "REJECTED"]], "MAC_OS" => [["1.0", "WAITING_FOR_REVIEW"]] }, issues)
    assert_equal [%w[IOS 1.0 REJECTED], %w[MAC_OS 1.0 WAITING_FOR_REVIEW]], announced
    assert_equal ["App Review: IOS 1.0", "App Review: MAC_OS 1.0"], issues.issues.map { |i| i["title"] }
    assert_equal "REJECTED", AppReviewWatch.last_state(issues.issues.first["body"])
    assert_equal 1, issues.label_calls
  end

  def test_second_run_with_no_change_is_silent_and_live_closes
    issues = FakeIssues.new
    watch({ "IOS" => [["1.0", "REJECTED"]] }, issues)
    assert_equal [], watch({ "IOS" => [["1.0", "REJECTED"]] }, issues)
    assert_equal 1, issues.comments.size
    watch({ "IOS" => [["1.0", "READY_FOR_SALE"]] }, issues)
    assert_equal "closed", issues.issues.first["state"]
    assert_equal [], watch({ "IOS" => [["1.0", "READY_FOR_SALE"]] }, issues)
  end

  def test_ignores_old_live_versions_without_an_issue
    issues = FakeIssues.new
    assert_equal [], watch({ "IOS" => [["0.9", "READY_FOR_SALE"], ["1.1", "PREPARE_FOR_SUBMISSION"]] }, issues)
    assert_equal 0, issues.label_calls
  end
end
