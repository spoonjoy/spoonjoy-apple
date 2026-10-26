# frozen_string_literal: true

# Run: ruby scripts/test/app_store_review_messages_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_review_messages"

class AppStoreReviewMessagesTest < Minitest::Test
  def test_plain_text_keeps_paragraphs_and_decodes_entities
    html = "<p>Guideline 2.1 &amp; Performance</p><p>We found a bug:<br/>the app crashed.</p><ul><li>Step one</li></ul>"
    assert_equal "Guideline 2.1 & Performance\nWe found a bug:\nthe app crashed.\n- Step one", AppStoreReviewMessages.plain_text(html)
  end

  def test_thread_urls_try_each_submission_then_the_app_on_both_hosts
    urls = AppStoreReviewMessages.thread_urls(app_id: "A", submission_ids: ["S"])
    assert_equal 4, urls.size
    assert_match %r{\Ahttps://api\.appstoreconnect\.apple\.com/v1/resolutionCenterThreads\?filter\[reviewSubmission\]=S\z}, urls[0]
    assert_match %r{/iris/v1/apps/A/resolutionCenterThreads\z}, urls[3]
  end

  def test_answered_keeps_only_submissions_app_review_has_responded_to
    subs = %w[UNRESOLVED_ISSUES WAITING_FOR_REVIEW COMPLETE].map { |state| { "id" => state, "attributes" => { "state" => state } } }
    assert_equal %w[UNRESOLVED_ISSUES COMPLETE], AppStoreReviewMessages.answered(subs).map { |s| s["id"] }
  end

  class FakeClient
    attr_reader :calls

    def initialize(answers)
      @answers = answers
      @calls = []
    end

    def get(path, _query = {})
      @calls << path
      answer = @answers.find { |pattern, _| path.include?(pattern) }&.last
      raise AppStoreListing::Error, "GET #{path} answered HTTP 404: Not found" unless answer

      answer
    end
  end

  def test_reads_messages_from_the_first_route_that_answers
    client = FakeClient.new([
      ["/v1/reviewSubmissions", { "data" => [{ "id" => "S", "attributes" => { "state" => "UNRESOLVED_ISSUES" } }] }],
      ["iris/v1/resolutionCenterThreads?", { "data" => [{ "id" => "T", "attributes" => { "state" => "ACTIVE" } }] }],
      ["/resolutionCenterThreads/T/resolutionCenterMessages",
       { "data" => [{ "attributes" => { "messageBody" => "<p>Guideline 4.0</p>" } }],
         "included" => [{ "type" => "reviewRejections", "attributes" => { "reasons" => ["4.0"] } }] }]
    ])
    log = StringIO.new
    assert AppStoreReviewMessages::Reader.new(client, app_id: "A", platform: "IOS", log: log).run
    assert_includes log.string, "Guideline 4.0"
    assert_includes log.string, "Rejection: {\"reasons\":[\"4.0\"]}"
    assert_includes log.string, "No https://api.appstoreconnect.apple.com/v1/resolutionCenterThreads"
  end

  def test_says_where_to_look_when_no_route_answers
    client = FakeClient.new([["/v1/reviewSubmissions", { "data" => [] }]])
    log = StringIO.new
    refute AppStoreReviewMessages::Reader.new(client, app_id: "A", platform: "IOS", log: log).run
    assert_includes log.string, "Read the message in the App Store Connect web app"
  end
end
