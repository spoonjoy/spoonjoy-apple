# frozen_string_literal: true

# Run: ruby scripts/test/testflight_crash_gate_test.rb
#
# The fixtures are App Store Connect and GitHub Actions responses recorded on 2026-11-15 (links and relationships
# trimmed): build 174 (1.3, crashed at launch on Ari's iPhone), 156 (the 1.2 that shipped and crashed), 178 (1.2.2,
# the fix, never installed from TestFlight before it went to review), and After TestFlight runs with Launch smoke
# green (8d44b073) and still pending (081856a0).
require "json"
require "minitest/autorun"
require "open3"
require "time"
require_relative "../lib/testflight_crash_gate"

class TestflightCrashGateTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FIXTURES = File.join(__dir__, "fixtures/testflight_crash_gate")
  BUILDS = { "174" => "86c842c6-17a6-4185-a03a-66f7b303d7de", "156" => "2fcdaa4a-7d34-496d-904c-b5934fb7bd1a",
             "178" => "0b8dd1a7-e63c-41fd-aca0-aca37a6da523" }.freeze

  def fixture(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json")))
  end

  # Answers like AppStoreListing::Client from the recordings; a recorded error body raises as the client would.
  class RecordedClient
    attr_reader :paths

    def initialize(test)
      @test = test
      @paths = []
    end

    def answer(path)
      @paths << path
      number, = BUILDS.find { |_, build_id| path.include?(build_id) }
      body = case path
             when %r{\A/v1/builds/[^/]+\z} then @test.fixture("build-#{number}")
             when %r{/metrics/betaBuildUsages\z} then @test.fixture("usage-#{number}")
             when %r{/diagnosticSignatures\z} then @test.fixture("diagnostic-signatures-#{number}")
             else raise "unrecorded #{path}"
             end
      if body["errors"]
        raise AppStoreListing::Error, "GET #{path} answered HTTP #{body['errors'].first['status']}: #{body['errors'].first['detail']}"
      end

      body
    end

    def get(path, _query = {})
      answer(path)
    end

    def get_all(path, query = {})
      @paths << path
      raise "unrecorded #{path}" unless path == "/v1/apps/A/betaFeedbackCrashSubmissions"

      number = BUILDS.key(query.fetch("filter[build]"))
      @test.fixture("crash-feedback-#{number}")["data"]
    end
  end

  def facts(number)
    TestflightCrashGate::Reader.new(RecordedClient.new(self), app_id: "A").facts(BUILDS.fetch(number))
  end

  def a_day_after(number)
    Time.iso8601(facts(number)["uploadedDate"]) + (24 * 3600)
  end

  def test_reads_the_crashing_build_and_treats_apples_404_for_organizer_data_as_none
    found = facts("174")
    assert_equal({ "installCount" => 2, "crashCount" => 3, "sessionCount" => 1 }, found["usage"])
    assert_equal 2, found["crashFeedback"]
    assert_equal [], found["signatures"]
    assert_equal "174", found["buildNumber"]
  end

  def test_refuses_a_build_testflight_saw_crash
    result = TestflightCrashGate.evaluate(facts("174"), now: a_day_after("174"))
    refute result["pass"]
    assert_includes result["refusals"], "TestFlight counted 3 crash(es) on build 174"
    assert_includes result["refusals"], "Testers sent 2 TestFlight crash report(s) for build 174"
  end

  def test_refuses_a_build_nobody_installed_from_testflight
    result = TestflightCrashGate.evaluate(facts("178"), now: a_day_after("178"))
    refute result["pass"]
    assert_equal ["Nobody has installed build 178 from TestFlight yet; install it on an iPhone (or Mac) and use it first"],
                 result["refusals"]
  end

  def test_refuses_inside_the_soak_window_and_says_when_it_ends
    build = facts("156")
    uploaded = Time.iso8601(build["uploadedDate"])
    result = TestflightCrashGate.evaluate(build, now: uploaded + (3 * 3600))
    refute result["pass"]
    assert_equal ["build 156 was uploaded 3.0 hour(s) ago; the soak window is 12 hours (ready at #{(uploaded + (12 * 3600)).utc.iso8601})"],
                 result["refusals"]
  end

  def test_passes_an_installed_build_with_no_crash_after_the_soak
    result = TestflightCrashGate.evaluate(facts("156"), now: a_day_after("156"))
    assert result["pass"], result["refusals"].join("; ")
    assert_includes result["notes"], "build 156: 2 install(s), 0 session(s), 0 crash(es) in TestFlight"
  end

  def test_refuses_a_build_without_usage_metrics
    result = TestflightCrashGate.evaluate(facts("156").merge("usage" => nil), now: a_day_after("156"))
    assert_equal ["TestFlight has no usage metrics for build 156, so nothing shows it ran on a device"], result["refusals"]
  end

  def test_organizer_signatures_are_reported_never_refused
    build = facts("156").merge("signatures" => [{ "type" => "HANGS", "weight" => 0.5, "signature" => "main hang" }])
    result = TestflightCrashGate.evaluate(build, now: a_day_after("156"))
    assert result["pass"]
    assert_includes result["notes"], "Organizer diagnostic for build 156: HANGS weight 0.5: main hang"
  end

  def test_other_app_store_connect_errors_still_raise
    client = RecordedClient.new(self)
    def client.get(path, _query = {})
      raise AppStoreListing::Error, "GET #{path} answered HTTP 500: boom" if path.end_with?("/diagnosticSignatures")

      answer(path)
    end
    assert_raises(AppStoreListing::Error) { TestflightCrashGate::Reader.new(client, app_id: "A").facts(BUILDS["156"]) }
  end

  def test_summary_records_the_override_beside_what_the_gate_found
    result = TestflightCrashGate.evaluate(facts("178"), now: a_day_after("178"))
    text = TestflightCrashGate.summary("IOS", "1.2.2", result, override: "P0 launch-crash fix; phased release paused on any crash")
    assert_includes text, "### TestFlight crash gate: IOS 1.2.2 refused, overridden"
    assert_includes text, "- Refused: Nobody has installed build 178"
    assert_includes text, "- Override reason: P0 launch-crash fix; phased release paused on any crash"
    passed = TestflightCrashGate.summary("IOS", "1.2", TestflightCrashGate.evaluate(facts("156"), now: a_day_after("156")), override: "x")
    assert_includes passed, "IOS 1.2 passed"
    refute_includes passed, "Override reason"
  end

  def test_launch_smoke_passes_when_every_family_passed
    sha = "8d44b073b133d9fc6b16e87d8e91813a1d2682c1"
    result = TestflightCrashGate.launch_smoke([fixture("runs-after-testflight-green")], sha: sha)
    assert result["pass"], result["refusals"].join("; ")
    assert_match(/Launch smoke \(iPhone\)/, result["notes"].first)
    refute_match(/build the Release app/, result["notes"].first)
  end

  def test_launch_smoke_refuses_a_pending_run_and_a_commit_without_one
    sha = "081856a0e16755033ffd7c8d293f7121eaa8c432"
    result = TestflightCrashGate.launch_smoke([fixture("runs-after-testflight-pending")], sha: sha)
    refute result["pass"]
    assert_equal 3, result["refusals"].size
    assert(result["refusals"].all? { |r| r.include?("pending") })
    none = TestflightCrashGate.launch_smoke([{ "id" => 1, "jobs" => [{ "name" => "Launch smoke", "status" => "completed", "conclusion" => "skipped" }] }], sha: sha)
    refute none["pass"]
    assert_match(/no Launch smoke run; dispatch launch-smoke.yml/, none["refusals"].first)
  end

  def test_launch_smoke_reads_the_newest_run_so_a_green_rerun_counts
    pending = fixture("runs-after-testflight-pending")
    green = fixture("runs-after-testflight-green").merge("id" => pending["id"] + 1)
    assert TestflightCrashGate.launch_smoke([pending, green], sha: "x")["pass"]
  end

  def test_submit_workflow_runs_the_gate_and_records_the_override
    workflow = File.read(File.join(ROOT, ".github/workflows/submit-app-store-review.yml"))
    assert_includes workflow, "crash_gate_override:"
    assert_includes workflow, "ruby scripts/require-launch-smoke.rb"
    assert_includes workflow, '--crash-gate-override "$OVERRIDE"'
    uses = workflow.lines.grep(/inputs\.crash_gate_override/)
    assert_equal 2, uses.size
    assert(uses.all? { |line| line.strip.start_with?("OVERRIDE: ${{ inputs.crash_gate_override }}") }, "the override reaches scripts through env only")
  end

  def test_submit_script_refuses_before_it_reads_app_store_connect_without_credentials
    _out, err, status = Open3.capture3({ "ASC_KEY_ID" => "", "ASC_ISSUER_ID" => "", "ASC_KEY_BASE64" => "" }, RbConfig.ruby,
                                       File.join(ROOT, "scripts/submit-app-store-review.rb"), "--platform", "IOS", "--version", "1.0",
                                       "--crash-gate-override", "")
    refute status.success?
    assert_includes err, "Missing ASC_KEY_ID", "an empty override parses like none"
  end
end
