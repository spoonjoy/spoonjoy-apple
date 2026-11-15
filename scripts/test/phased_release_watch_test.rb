# frozen_string_literal: true

# Run: ruby scripts/test/phased_release_watch_test.rb
#
# The fixtures are App Store Connect responses recorded on 2026-11-15 (links and relationships trimmed): iOS 1.2.1
# rolling out (ACTIVE, build 170), 1.2 rolled out (COMPLETE), 1.2.2 in review (INACTIVE), 1.0 without a phased release,
# Mac 1.1 rolling out (ACTIVE, build 44), and build 174's TestFlight crashes, used as the crashing build.
require "json"
require "minitest/autorun"
require "stringio"
require_relative "../lib/phased_release_watch"

class PhasedReleaseWatchTest < Minitest::Test
  FIXTURES = File.join(__dir__, "fixtures/phased_release_watch")
  VERSION_FIXTURES = { "89c36f06-6a67-4a24-b8b5-7076fe1d5999" => "1.2.2", "f3b68147-651a-4e98-854a-0d2835b09b31" => "1.2.1",
                       "26a676af-d6ae-4391-86e1-d6334de91a49" => "1.2", "0d3bb0d1-930f-43b3-811b-0dc2a9376b2a" => "1.0",
                       "751bdce9-e832-48b2-86f4-1f4d8cec5450" => "mac-1.1" }.freeze
  BUILD_FIXTURES = { "9ce70058-ed83-4730-85d9-85d32d9b71ac" => "170", "86c842c6-17a6-4185-a03a-66f7b303d7de" => "174",
                     "d4a601b1-2292-4b05-b6c6-5092c1fdf6b9" => "mac-44" }.freeze
  ROLLOUT_121 = "f3b68147-651a-4e98-854a-0d2835b09b31"

  def self.fixture(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json")))
  end

  # Answers from the recordings. overrides: path => body, to swap a recorded answer (for example the crashing build).
  class RecordedClient
    attr_reader :writes

    def initialize(overrides = {})
      @overrides = overrides
      @writes = []
    end

    def get(path, _query = {})
      return @overrides[path].shift if @overrides[path].is_a?(Array)
      return @overrides[path] if @overrides.key?(path)

      body = case path
             when "/v1/apps" then { "data" => [{ "id" => "6787505444" }] }
             when %r{\A/v1/appStoreVersions/([^/]+)/appStoreVersionPhasedRelease\z}
               PhasedReleaseWatchTest.fixture("phased-release-#{VERSION_FIXTURES.fetch(Regexp.last_match(1))}")
             when %r{\A/v1/appStoreVersions/([^/]+)/build\z}
               PhasedReleaseWatchTest.fixture("build-of-#{VERSION_FIXTURES.fetch(Regexp.last_match(1))}")
             when %r{\A/v1/builds/([^/]+)/metrics/betaBuildUsages\z}
               PhasedReleaseWatchTest.fixture("usage-#{BUILD_FIXTURES.fetch(Regexp.last_match(1))}")
             else raise "unrecorded GET #{path}"
             end
      raise AppStoreListing::Error, "GET #{path} answered HTTP 404: none" if body.nil?

      body
    end

    def get_all(path, query = {})
      case path
      when "/v1/apps/6787505444/appStoreVersions"
        PhasedReleaseWatchTest.fixture(query["filter[platform]"] == "IOS" ? "ios-versions" : "mac-versions")["data"]
      when "/v1/apps/6787505444/betaFeedbackCrashSubmissions"
        PhasedReleaseWatchTest.fixture("crash-feedback-#{BUILD_FIXTURES.fetch(query.fetch('filter[build]'))}")["data"]
      else raise "unrecorded GET #{path}"
      end
    end

    def patch(path, body)
      @writes << [:patch, path, body]
      {}
    end
  end

  class FakeIssues
    attr_reader :issues, :comments

    def initialize(issues = [])
      @issues = issues
      @comments = []
    end

    def open_issue(title)
      @issues.find { |i| i["title"] == title }
    end

    def ensure_label; end

    def create(title, body)
      issue = { "number" => @issues.size + 1, "title" => title, "body" => body }
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

  def run_watch(client, issues, apply: true)
    PhasedReleaseWatch::Runner.new(client, issues, bundle_id: "app.spoonjoy", apply: apply, log: StringIO.new).run
  end

  # iOS 1.2.1 on the crashing build 174's recordings, as if TestFlight saw it crash during the rollout.
  def crashing_121
    { "/v1/appStoreVersions/#{ROLLOUT_121}/build" => { "data" => { "id" => "86c842c6-17a6-4185-a03a-66f7b303d7de",
                                                                     "attributes" => { "version" => "174" } } } }
  end

  def watched(platform_version, baseline, paused = "false")
    platform, version = platform_version.split
    { "number" => 7, "title" => PhasedReleaseWatch.title(platform, version),
      "body" => PhasedReleaseWatch.body(platform, version, baseline, paused) }
  end

  def test_first_sight_of_each_active_rollout_records_a_baseline_and_writes_nothing
    client = RecordedClient.new
    issues = FakeIssues.new
    acted = run_watch(client, issues)
    assert_equal [["IOS", "1.2.1", "baseline"], ["MAC_OS", "1.1", "baseline"]], acted
    assert_empty client.writes
    assert_equal ["Phased release: IOS 1.2.1", "Phased release: MAC_OS 1.1"], issues.issues.map { |i| i["title"] }
    assert_equal [0, "false"], PhasedReleaseWatch.read_marker(issues.issues.first["body"])
  end

  def test_pauses_an_active_rollout_when_testflight_crashes_rise
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0)])
    acted = run_watch(client, issues)
    assert_includes acted, ["IOS", "1.2.1", "paused"]
    assert_equal [[:patch, "/v1/appStoreVersionPhasedReleases/#{ROLLOUT_121}",
                   { "data" => { "type" => "appStoreVersionPhasedReleases", "id" => ROLLOUT_121,
                                 "attributes" => { "phasedReleaseState" => "PAUSED" } } }]], client.writes
    text = issues.comments.map(&:last).join
    assert_includes text, "**Paused** the IOS 1.2.1 phased release"
    assert_includes text, "TestFlight crashes on the build rose from 0 to 3"
    assert_includes text, "TestFlight crash feedback since the rollout began: 2"
    assert_equal [0, "true"], PhasedReleaseWatch.read_marker(issues.issues.first["body"])
  end

  def test_a_crash_count_at_the_baseline_is_no_spike
    client = RecordedClient.new(crashing_121.merge(
                                  "/v1/apps/6787505444/betaFeedbackCrashSubmissions" => nil
                                ))
    def client.get_all(path, query = {})
      return [] if path.end_with?("betaFeedbackCrashSubmissions")

      super
    end
    issues = FakeIssues.new([watched("IOS 1.2.1", 3)])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "none"]
    assert_empty client.writes
  end

  def test_never_undoes_a_deliberate_complete_made_between_read_and_write
    complete = self.class.fixture("phased-release-1.2")
    complete["data"]["id"] = ROLLOUT_121
    path = "/v1/appStoreVersions/#{ROLLOUT_121}/appStoreVersionPhasedRelease"
    client = RecordedClient.new(crashing_121.merge(path => [self.class.fixture("phased-release-1.2.1"), complete]))
    issues = FakeIssues.new([watched("IOS 1.2.1", 0)])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "none"]
    assert_empty client.writes
  end

  def test_complete_inactive_and_missing_rollouts_are_left_alone
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new
    acted = run_watch(client, issues)
    refute(acted.any? { |_, version, _| %w[1.2 1.2.2 1.0].include?(version) })
    assert_equal({ "action" => "none", "reasons" => ["phased release is COMPLETE"] },
                 PhasedReleaseWatch.decide(phased: { "state" => "COMPLETE" }, signals: { "crashCount" => 9 }, baseline: 0))
    assert_equal "none", PhasedReleaseWatch.decide(phased: { "state" => "PAUSED" }, signals: { "crashCount" => 9 }, baseline: 0)["action"]
  end

  def test_dry_run_says_it_would_pause_once_and_writes_nothing_to_app_store_connect
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0)])
    assert_includes run_watch(client, issues, apply: false), ["IOS", "1.2.1", "would-pause"]
    assert_includes run_watch(client, issues, apply: false), ["IOS", "1.2.1", "none"]
    assert_empty client.writes
    assert_equal 1, issues.comments.count { |_, text| text.include?("**Would pause**") }
    assert_includes run_watch(client, issues, apply: true), ["IOS", "1.2.1", "paused"], "turning apply on acts on the dry run's finding"
  end

  def test_crash_feedback_on_first_sight_pauses_at_once
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "paused"]
    assert_equal 1, client.writes.size
  end

  def test_a_resumed_rollout_is_watched_again_from_its_current_count
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0, "true")])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "rebaseline"]
    assert_empty client.writes
    assert_equal [3, "false"], PhasedReleaseWatch.read_marker(issues.issues.first["body"])
  end

  def test_feedback_from_before_the_rollout_does_not_count
    found = PhasedReleaseWatch::Runner.new(RecordedClient.new(crashing_121), FakeIssues.new, bundle_id: "x", apply: false)
                                      .signals(ROLLOUT_121, "2026-11-16T00:00:00Z")
    assert_equal({ "crashCount" => 3, "feedbackSince" => 0, "build" => "174" }, found)
  end

  def test_workflow_only_writes_when_the_repository_variable_is_on
    workflow = File.read(File.expand_path("../../.github/workflows/phased-release-watch.yml", __dir__))
    assert_includes workflow, "PHASED_RELEASE_AUTO_PAUSE: ${{ vars.PHASED_RELEASE_AUTO_PAUSE }}"
    assert_match(/schedule:/, workflow)
    script = File.read(File.expand_path("../phased-release-watch.rb", __dir__))
    assert_includes script, 'apply: ENV["PHASED_RELEASE_AUTO_PAUSE"] == "on"'
  end
end
