# frozen_string_literal: true

# Run: ruby scripts/test/release_train_drift_test.rb
#
# The daily drift job reads both platforms' latest App Store versions, read-only, and keeps one release-train issue.
require "minitest/autorun"
require "stringio"
require "yaml"
require_relative "../lib/release_train"

class ReleaseTrainDriftTest < Minitest::Test
  URLS = { "supportUrl" => "https://spoonjoy.app/support", "marketingUrl" => "https://spoonjoy.app",
           "privacyPolicyUrl" => nil }.freeze

  def live(platform, version, state, copy = {})
    { "platform" => platform, "versionString" => version, "state" => state, "build" => "1",
      "copy" => URLS.merge("keywords" => "a,b", "promotionalText" => "promo").merge(copy) }
  end

  def fields
    %w[supportUrl marketingUrl keywords]
  end

  def test_a_train_in_line_has_no_drift
    assert_equal [], ReleaseTrain.drift(live("IOS", "1.2", "READY_FOR_SALE"), live("MAC_OS", "1.2", "READY_FOR_SALE"), fields)
  end

  def test_version_state_and_copy_drift_are_each_named
    differences = ReleaseTrain.drift(live("IOS", "1.2", "READY_FOR_SALE", "keywords" => "x"),
                                     live("MAC_OS", "1.1", "IN_REVIEW", "supportUrl" => "https://other"), fields)
    assert_equal ["versionString: iOS 1.2, macOS 1.1",
                  "state: iOS READY_FOR_SALE, macOS IN_REVIEW",
                  "supportUrl: iOS https://spoonjoy.app/support, macOS https://other",
                  "keywords: iOS x, macOS a,b"], differences
  end

  def test_copy_the_mac_gives_its_own_is_not_compared
    assert_equal [], ReleaseTrain.drift(live("IOS", "1.2", "READY_FOR_SALE", "promotionalText" => "iOS"),
                                        live("MAC_OS", "1.2", "READY_FOR_SALE", "promotionalText" => "Mac"), fields)
  end

  def test_a_platform_with_no_version_is_drift
    assert_equal ["macOS has no App Store version"], ReleaseTrain.drift(live("IOS", "1.2", "READY_FOR_SALE"), nil, fields)
  end

  class FakeAsc
    attr_reader :calls

    def initialize(versions)
      @versions = versions
      @calls = []
    end

    def get(path, query = {})
      @calls << [:get, path, query]
      return { "data" => [{ "id" => "APP" }] } if path == "/v1/apps"
      return { "data" => { "attributes" => { "version" => "61" } } } if path.end_with?("/build")

      raise "unexpected GET #{path}"
    end

    def get_all(path, query = {})
      @calls << [:get_all, path, query]
      if path.end_with?("/appStoreVersions")
        return (@versions[query["filter[platform]"]] || []).map do |id, version, state, created|
          { "id" => id, "attributes" => { "versionString" => version, "appStoreState" => state, "createdDate" => created } }
        end
      end
      return [{ "attributes" => { "locale" => "en-US", "keywords" => "k", "supportUrl" => "https://s" } }] if path.end_with?("/appStoreVersionLocalizations")

      raise "unexpected GET_ALL #{path}"
    end

    def post(*) = raise("write")
    def patch(*) = raise("write")
    def delete(*) = raise("write")
  end

  def test_the_reader_cannot_write
    reader_client = ReleaseTrain::ReadOnly.new(FakeAsc.new({}))
    %i[post patch delete upload].each { |name| refute_respond_to reader_client, name }
  end

  def test_the_reader_takes_each_platforms_newest_version
    asc = FakeAsc.new("IOS" => [["v1", "1.0", "READY_FOR_SALE", "2026-10-01T00:00:00Z"],
                                ["v2", "1.2", "READY_FOR_SALE", "2026-11-10T00:00:00Z"]],
                      "MAC_OS" => [["m1", "1.1", "IN_REVIEW", "2026-11-01T00:00:00Z"]])
    reader = ReleaseTrain::LiveReader.new(asc, bundle_id: "app.spoonjoy")
    ios = reader.latest("IOS")
    assert_equal({ "platform" => "IOS", "versionString" => "1.2", "state" => "READY_FOR_SALE", "build" => "61",
                   "copy" => { "keywords" => "k", "supportUrl" => "https://s" } }, ios)
    assert_equal "1.1", reader.latest("MAC_OS")["versionString"]
    assert_nil ReleaseTrain::LiveReader.new(FakeAsc.new({}), bundle_id: "app.spoonjoy").latest("IOS")
    assert(asc.calls.all? { |call| %i[get get_all].include?(call.first) })
  end

  class FakeIssues
    attr_reader :issues, :comments, :label_calls

    def initialize
      @issues = []
      @comments = []
      @label_calls = 0
    end

    def open_issue(title) = @issues.find { |i| i["title"] == title && i["state"] == "open" }
    def ensure_label = @label_calls += 1

    def create(title, body)
      (@issues << { "number" => @issues.size + 1, "title" => title, "body" => body, "state" => "open" }).last
    end

    def comment(number, text) = @comments << [number, text]
    def update(number, fields) = @issues.find { |i| i["number"] == number }.merge!(fields)
  end

  def keep(issues, differences)
    ReleaseTrain::DriftIssue.new(issues, log: StringIO.new).keep(differences, ios: live("IOS", "1.2", "READY_FOR_SALE"),
                                                                              mac: live("MAC_OS", "1.1", "IN_REVIEW"))
  end

  def test_drift_opens_one_issue_and_only_a_change_comments
    issues = FakeIssues.new
    assert_equal :opened, keep(issues, ["versionString: iOS 1.2, macOS 1.1"])
    assert_equal 1, issues.issues.size
    assert_match(/versionString: iOS 1.2, macOS 1.1/, issues.issues.first["body"])
    assert_equal :unchanged, keep(issues, ["versionString: iOS 1.2, macOS 1.1"])
    assert_equal 0, issues.comments.size
    assert_equal :updated, keep(issues, ["state: iOS READY_FOR_SALE, macOS IN_REVIEW"])
    assert_equal 1, issues.issues.size
    assert_equal 1, issues.comments.size
    assert_match(/state: iOS READY_FOR_SALE/, issues.issues.first["body"])
  end

  def test_back_in_line_closes_the_issue
    issues = FakeIssues.new
    assert_equal :quiet, keep(issues, [])
    assert_equal 0, issues.label_calls
    keep(issues, ["versionString: iOS 1.2, macOS 1.1"])
    assert_equal :closed, keep(issues, [])
    assert_equal "closed", issues.issues.first["state"]
    assert_match(/back in line/, issues.comments.last.last)
  end
  def test_the_drift_workflow_runs_daily_and_only_reads
    path = File.expand_path("../../.github/workflows/release-train-drift.yml", __dir__)
    workflow = YAML.safe_load(File.read(path), aliases: true)
    triggers = workflow.fetch(true)
    assert triggers.key?("schedule")
    assert triggers.key?("workflow_dispatch")
    assert_equal({ "contents" => "read", "issues" => "write" }, workflow.fetch("permissions"))
    runs = workflow.fetch("jobs").fetch("drift").fetch("steps").filter_map { |step| step["run"] }
    assert_equal ["ruby scripts/check-release-train.rb --app-store-connect"], runs
  end
end
