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
  # The recorded phased release carries its version's id; a distinct one here proves the PATCH uses the phased
  # release's own id.
  PHASED_121 = "phased-release-of-1.2.1"

  def crashing_121
    phased = self.class.fixture("phased-release-1.2.1")
    phased["data"]["id"] = PHASED_121
    { "/v1/appStoreVersions/#{ROLLOUT_121}/build" => { "data" => { "id" => "86c842c6-17a6-4185-a03a-66f7b303d7de",
                                                                     "attributes" => { "version" => "174" } } },
      "/v1/appStoreVersions/#{ROLLOUT_121}/appStoreVersionPhasedRelease" => phased }
  end

  def watched(platform_version, crashes, feedback, state = "watching")
    platform, version = platform_version.split
    { "number" => 7, "title" => PhasedReleaseWatch.title(platform, version),
      "body" => PhasedReleaseWatch.body(platform, version, { "crashes" => crashes, "feedback" => feedback, "state" => state }) }
  end

  def mark(issues)
    PhasedReleaseWatch.read_marker(issues.issues.first["body"])
  end

  def test_first_sight_of_each_active_rollout_records_a_baseline_and_writes_nothing
    client = RecordedClient.new
    issues = FakeIssues.new
    acted = run_watch(client, issues)
    assert_equal [["IOS", "1.2.1", "baseline"], ["MAC_OS", "1.1", "baseline"]], acted
    assert_empty client.writes
    assert_equal ["Phased release: IOS 1.2.1", "Phased release: MAC_OS 1.1"], issues.issues.map { |i| i["title"] }
    assert_equal({ "crashes" => 0, "feedback" => 0, "state" => "watching" }, mark(issues))
  end

  def test_pauses_an_active_rollout_when_testflight_crashes_rise
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0, 0)])
    acted = run_watch(client, issues)
    assert_includes acted, ["IOS", "1.2.1", "paused"]
    assert_equal [[:patch, "/v1/appStoreVersionPhasedReleases/#{PHASED_121}",
                   { "data" => { "type" => "appStoreVersionPhasedReleases", "id" => PHASED_121,
                                 "attributes" => { "phasedReleaseState" => "PAUSED" } } }]], client.writes
    text = issues.comments.map(&:last).join
    assert_includes text, "**Paused** the IOS 1.2.1 phased release"
    assert_includes text, "TestFlight crashes on the build rose from 0 to 3"
    assert_includes text, "TestFlight crash reports on the build rose from 0 to 2"
    assert_equal({ "crashes" => 3, "feedback" => 2, "state" => "paused" }, mark(issues))
  end

  def test_counts_at_the_mark_are_no_spike
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 3, 2)])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "none"]
    assert_empty client.writes
  end

  def test_never_undoes_a_deliberate_complete_made_between_read_and_write
    complete = self.class.fixture("phased-release-1.2")
    complete["data"]["id"] = ROLLOUT_121
    path = "/v1/appStoreVersions/#{ROLLOUT_121}/appStoreVersionPhasedRelease"
    client = RecordedClient.new(crashing_121.merge(path => [self.class.fixture("phased-release-1.2.1"), complete]))
    issues = FakeIssues.new([watched("IOS 1.2.1", 0, 0)])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "none"]
    assert_empty client.writes
  end

  def test_complete_inactive_and_missing_rollouts_are_left_alone
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new
    acted = run_watch(client, issues)
    refute(acted.any? { |_, version, _| %w[1.2 1.2.2 1.0].include?(version) })
    assert_equal ["/v1/appStoreVersionPhasedReleases/#{PHASED_121}"], client.writes.map { |w| w[1] },
                 "only the crashing ACTIVE 1.2.1 is written to"
    m = { "crashes" => 0, "feedback" => 0, "state" => "watching" }
    assert_equal({ "action" => "none", "reasons" => ["phased release is COMPLETE"] },
                 PhasedReleaseWatch.decide(phased: { "state" => "COMPLETE" }, signals: { "crashCount" => 9 }, mark: m))
    assert_equal "none", PhasedReleaseWatch.decide(phased: { "state" => "PAUSED" }, signals: { "crashCount" => 9 }, mark: m)["action"]
  end

  def test_dry_run_says_it_would_pause_once_and_writes_nothing_to_app_store_connect
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0, 0)])
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

  def test_a_resumed_rollout_is_watched_again_from_its_current_counts_and_not_paused_again
    client = RecordedClient.new(crashing_121)
    issues = FakeIssues.new([watched("IOS 1.2.1", 0, 0, "paused")])
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "rebaseline"]
    assert_equal({ "crashes" => 3, "feedback" => 2, "state" => "watching" }, mark(issues))
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "none"], "the next run after a resume must not pause again"
    assert_empty client.writes
  end

  def test_an_open_issue_without_a_marker_gets_one_and_is_then_watched
    issues = FakeIssues.new([{ "number" => 7, "title" => "Phased release: IOS 1.2.1", "body" => "opened by hand" }])
    client = RecordedClient.new
    assert_includes run_watch(client, issues), ["IOS", "1.2.1", "baseline"]
    assert_equal({ "crashes" => 0, "feedback" => 0, "state" => "watching" }, mark(issues))
    assert_includes run_watch(RecordedClient.new(crashing_121), issues), ["IOS", "1.2.1", "paused"]
  end

  def test_the_issue_closes_when_the_rollout_is_complete
    issues = FakeIssues.new([watched("IOS 1.2", 0, 0)])
    assert_includes run_watch(RecordedClient.new, issues), ["IOS", "1.2", "closed"]
    assert_equal "closed", issues.issues.first["state"]
  end

  def test_one_rollouts_error_does_not_stop_the_others
    client = RecordedClient.new
    def client.get(path, query = {})
      raise AppStoreListing::Error, "GET #{path} answered HTTP 500: boom" if path == "/v1/appStoreVersions/f3b68147-651a-4e98-854a-0d2835b09b31/build"

      super
    end
    issues = FakeIssues.new
    error = assert_raises(AppStoreListing::Error) { run_watch(client, issues) }
    assert_match(/IOS 1\.2\.1: GET .* HTTP 500/, error.message)
    assert_includes issues.issues.map { |i| i["title"] }, "Phased release: MAC_OS 1.1", "the Mac rollout was still watched"
  end

  def test_feedback_from_before_the_rollout_does_not_count
    found = PhasedReleaseWatch::Runner.new(RecordedClient.new(crashing_121), FakeIssues.new, bundle_id: "x", apply: false)
                                      .signals(ROLLOUT_121, "2026-11-16T00:00:00Z")
    assert_equal({ "crashCount" => 3, "feedbackTotal" => 2, "feedbackSince" => 0, "build" => "174" }, found)
  end

  def test_workflow_only_writes_when_the_repository_variable_is_on
    workflow = File.read(File.expand_path("../../.github/workflows/phased-release-watch.yml", __dir__))
    assert_includes workflow, "PHASED_RELEASE_AUTO_PAUSE: ${{ vars.PHASED_RELEASE_AUTO_PAUSE }}"
    assert_match(/schedule:/, workflow)
    script = File.read(File.expand_path("../phased-release-watch.rb", __dir__))
    assert_includes script, 'apply: ENV["PHASED_RELEASE_AUTO_PAUSE"] == "on"'
  end
end
