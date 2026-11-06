# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../lib/live_journey_failure"
require_relative "../live-journeys"

# The failure texts are the real ones from the failed main runs of the Journeys job in November 2026.
class LiveJourneyFailureTest < Minitest::Test
  SCREEN_DUMP = "\nAttributes: Application, 0x1086f8c80, pid: 40816, label: 'Spoonjoy'\nElement subtree:\n " \
                "→Application, label: 'Failed to launch' The request timed out"

  def summary(*failures, result: "Failed", total: 14)
    {
      "result" => result,
      "totalTestCount" => total,
      "testFailures" => failures.map { |test, text| { "testIdentifierString" => test, "failureText" => text } }
    }
  end

  def classify(summary, log: "", exit_status: 65, timed_out: false)
    LiveJourneyFailure.classify(summary: summary, log: log, exit_status: exit_status, timed_out: timed_out)
  end

  # Run 42121457441.
  def test_background_assertion_timeout_is_launch
    result = classify(summary(["CookSyncJourney/testCookModeCheckReachesTheServerJourney()",
                               "Failed to get background assertion for target app with pid 38549: Timed out while acquiring background assertion."]))
    assert_equal "launch", result.klass
    assert_equal ["background-assertion"], result.failures.map(&:rule)
    assert result.infrastructure?
  end

  # Run 41982485429: one launch failure and one assertion failure make an assertion run.
  def test_any_assertion_outranks_launch
    result = classify(summary(
                        ["ModerationJourney/testReportBlockAndUnblock()", "Application 'app.spoonjoy' does not have a process ID"],
                        ["RecipesJourney/testRecipesJourney()",
                         "XCTAssertTrue failed - The editor did not close after Save. Editor message: none shown. Screen: Sync log: " \
                         "PATCH /api/v1/recipes/cmw38nvju0005mhg5120tuog4/steps/35d4 -> ok#{SCREEN_DUMP}"]
                      ))
    assert_equal "assertion", result.klass
    assert_equal %w[launch assertion], result.failures.map(&:klass)
    refute result.infrastructure?
  end

  def test_no_process_id_alone_is_launch
    result = classify(summary(["ModerationJourney/testReportBlockAndUnblock()", "Application 'app.spoonjoy' does not have a process ID"]))
    assert_equal "launch", result.klass
    assert_equal ["no-process-id"], result.failures.map(&:rule)
  end

  # Run 42148845909: QA answered 409; that is the app's behaviour under test, not the network.
  def test_edit_conflict_status_is_assertion
    text = "XCTAssertTrue failed - The editor did not close after Save. Editor message: none shown. Screen: Sync log: " \
           "PATCH /api/v1/recipes/cmw4d82km000cuwwwuy7bunkz -> 409 edit_conflict: The recipe changed after expectedUpdatedAt"
    assert_equal "assertion", classify(summary(["EditorJourney/testRecipeEditConflictJourney()", text])).klass
  end

  # Run 42093262648: QA answered HTTP 500. A status from QA is never the network.
  def test_qa_http_500_is_assertion
    text = 'failed: caught error: "QA answered HTTP 500 for /api/v1/auth/password/native (body: {"type":"https://developers.cloudflare.com/support/"})"'
    assert_equal "assertion", classify(summary(["VoiceJourney/testVoiceCommandsDriveCookModeJourney()", text])).klass
  end

  def test_url_error_from_the_test_process_is_network
    text = 'failed: caught error: "Error Domain=NSURLErrorDomain Code=-1001 "The request timed out." UserInfo={NSErrorFailingURLKey=https://qa/api}"'
    result = classify(summary(["SignInJourney/testSignInOutJourney()", text]))
    assert_equal "network", result.klass
    assert_equal ["url-error-code"], result.failures.map(&:rule)
  end

  def test_each_unreachable_host_code_is_network
    LiveJourneyFailure::NETWORK_CODES.each do |code|
      assert_equal ["network", "url-error-code"], LiveJourneyFailure.classify_text("NSURLErrorDomain Code=#{code} \"x\""), code
    end
    assert_equal "assertion", LiveJourneyFailure.classify_text("NSURLErrorDomain Code=-1011 \"bad response\"")[0]
  end

  def test_app_sync_log_offline_is_network
    text = "XCTAssertTrue failed - Signing in did not open the kitchen. Screen: Sync log: POST /api/v1/auth/password/native -> no status (offline)"
    assert_equal ["network", "app-sync-offline"], LiveJourneyFailure.classify_text(text)
  end

  def test_other_transport_failure_in_sync_log_is_assertion
    text = "XCTAssertTrue failed - Signing in did not open the kitchen. Screen: Sync log: POST /api/v1/auth/password/native -> no status (networkFailure)"
    assert_equal "assertion", LiveJourneyFailure.classify_text(text)[0]
  end

  def test_network_and_launch_together_are_launch
    result = classify(summary(
                        ["A/testA()", "NSURLErrorDomain Code=-1005 \"The network connection was lost.\""],
                        ["B/testB()", "Failed to terminate app.spoonjoy:40816"]
                      ))
    assert_equal "launch", result.klass
  end

  def test_screen_dump_text_is_not_matched
    text = "XCTAssertTrue failed - The Kitchen has no Cooking now row.#{SCREEN_DUMP}"
    assert_equal ["assertion", "assertion"], LiveJourneyFailure.classify_text(text)
  end

  def test_journey_environment_guards_are_launch
    assert_equal "journey-environment", LiveJourneyFailure.classify_text(
      "XCTAssertTrue failed - The app launched twice without the journey environment, so it would skip the reset and use production."
    )[1]
    assert_equal "fresh-launch-signed-out", LiveJourneyFailure.classify_text(
      "XCTAssertTrue failed - The signed-out screen did not appear after a fresh launch."
    )[1]
    assert_equal "saved-state-reset", LiveJourneyFailure.classify_text(
      "XCTAssertTrue failed - The app did not clear its saved state after the journey."
    )[1]
  end

  def test_pointed_at_production_is_assertion
    assert_equal "assertion", LiveJourneyFailure.classify_text(
      "XCTAssertTrue failed - The app is not pointed at the QA mirror; stopping before any sign-in."
    )[0]
  end

  # Run 41918489161: the runner crashed before any test ran; xcodebuild printed it under "Testing failed:".
  def test_runner_bootstrap_crash_in_log_is_launch
    log = "Testing failed:\n\tSpoonjoyJourneys-Runner (14626) encountered an error (Early unexpected exit, operation never " \
          "finished bootstrapping - no restart will be attempted. (Underlying Error: The test runner crashed while preparing " \
          "to run tests: SpoonjoyJourneys-Runner at -[XCTWaiter(StallHandling) handleStalledWait:]))\n** TEST EXECUTE FAILED **\n"
    result = classify(summary(total: 0), log: log)
    assert_equal "launch", result.klass
    assert_equal ["runner-bootstrap"], result.failures.map(&:rule)
  end

  def test_missing_result_bundle_is_launch
    result = classify(nil, log: "xcodebuild: error: Unable to find a destination\n")
    assert_equal ["launch", ["no-result-bundle"]], [result.klass, result.failures.map(&:rule)]
  end

  def test_no_tests_ran_is_launch
    assert_equal ["no-tests-ran"], classify(summary(total: 0)).failures.map(&:rule)
  end

  def test_failure_without_a_test_failure_is_assertion
    assert_equal "assertion", classify(summary(total: 14)).klass
  end

  # Run 42148845909 also ran out of time and left an unreadable bundle; the log still names the assertion.
  def test_timed_out_run_reads_failures_from_the_log
    log = "/Users/runner/work/spoonjoy-apple/Apps/Spoonjoy/Journeys/EditorJourney.swift:225: error: " \
          "-[SpoonjoyJourneys.EditorJourney testRecipeEditConflictJourney] : XCTAssertTrue failed - The editor did not close after Save.\n"
    result = classify(nil, log: log, exit_status: nil, timed_out: true)
    assert_equal "assertion", result.klass
    assert_equal ["EditorJourney/testRecipeEditConflictJourney()"], result.failures.map(&:test)
  end

  def test_timed_out_run_without_failures_is_launch
    result = classify(nil, log: "Testing started\n", exit_status: nil, timed_out: true)
    assert_equal ["launch", ["runner-timeout"]], [result.klass, result.failures.map(&:rule)]
  end

  def test_exit_zero_is_passed
    assert_equal "passed", classify(nil, exit_status: 0).klass
    assert_equal "passed", classify(summary(result: "Passed"), exit_status: 0).klass
  end

  def test_exit_codes
    launch = LiveJourneyFailure::Result.new("launch", [], "")
    assertion = LiveJourneyFailure::Result.new("assertion", [], "")
    passed = LiveJourneyFailure::Result.new("passed", [], "")
    assert_equal 0, LiveJourneyFailure.exit_code(passed, attempt: 1)
    assert_equal 0, LiveJourneyFailure.exit_code(launch, attempt: 1)
    assert_equal 1, LiveJourneyFailure.exit_code(launch, attempt: 2)
    assert_equal 1, LiveJourneyFailure.exit_code(assertion, attempt: 1)
    assert_equal 1, LiveJourneyFailure.exit_code(assertion, attempt: 2)
  end

  def test_markdown_names_rules_never_failure_text
    secret_looking = "XCTAssertTrue failed - token sjt_abcdef1234 password hunter2 | `x`"
    result = classify(summary(["SignInJourney/testSignInOutJourney()", secret_looking]))
    markdown = LiveJourneyFailure.markdown(result, attempt: 1)
    assert_includes markdown, "Assertion failure, not retried."
    assert_includes markdown, "| `SignInJourney/testSignInOutJourney()` | assertion | assertion |"
    refute_includes markdown, "hunter2"
    refute_includes markdown, "sjt_"
  end

  def test_markdown_reports_infrastructure_and_retry
    result = classify(summary(["A/testA()", "Application 'app.spoonjoy' does not have a process ID"]))
    assert_includes LiveJourneyFailure.markdown(result, attempt: 1), "Infrastructure (launch) failure, retried once."
    assert_includes LiveJourneyFailure.markdown(result, attempt: 2), "Infrastructure (launch) failure, the retry failed too."
  end

  # The command-line wrapper end to end, with a stand-in for xcodebuild and for xcresulttool.
  def run_cli(script, attempt:, summary:)
    Dir.mktmpdir do |dir|
      env = { "GITHUB_OUTPUT" => File.join(dir, "output"), "GITHUB_STEP_SUMMARY" => File.join(dir, "summary") }
      out = StringIO.new
      log = File.join(dir, "test.log")
      code = LiveJourneys.main(
        ["--attempt", attempt.to_s, "--result-bundle", File.join(dir, "R.xcresult"), "--log", log, "--", "ruby", "-e", script],
        env: env,
        summary_reader: ->(_path) { summary },
        out: out
      )
      return [code, File.read(env["GITHUB_OUTPUT"]), File.read(env["GITHUB_STEP_SUMMARY"]), out.string, File.read(log)]
    end
  end

  def test_cli_passing_run
    code, output, step_summary, out, log = run_cli('puts "** TEST EXECUTE SUCCEEDED **"', attempt: 1, summary: nil)
    assert_equal 0, code
    assert_equal "class=passed\n", output
    assert_includes step_summary, "Every live journey passed."
    assert_includes out, "TEST EXECUTE SUCCEEDED"
    assert_includes log, "TEST EXECUTE SUCCEEDED"
  end

  def test_cli_launch_failure_on_attempt_one_defers_to_the_retry
    failing = summary(["A/testA()", "Application 'app.spoonjoy' does not have a process ID"])
    code, output, _, out, = run_cli('puts "** TEST EXECUTE FAILED **"; exit 65', attempt: 1, summary: failing)
    assert_equal 0, code
    assert_equal "class=launch\n", output
    assert_includes out, "::warning::Live journeys attempt 1: infrastructure failure (launch: no-process-id); retrying once."
  end

  def test_cli_launch_failure_on_attempt_two_fails
    failing = summary(["A/testA()", "Application 'app.spoonjoy' does not have a process ID"])
    code, output, = run_cli("exit 65", attempt: 2, summary: failing)
    assert_equal 1, code
    assert_equal "class=launch\n", output
  end

  def test_cli_assertion_fails_without_retry
    failing = summary(["A/testA()", "XCTAssertEqual failed: (\"a\") is not equal to (\"b\")"])
    code, output, _, out, = run_cli("exit 65", attempt: 1, summary: failing)
    assert_equal 1, code
    assert_equal "class=assertion\n", output
    assert_includes out, "::error::Live journeys attempt 1: assertion failure (assertion); not retried."
  end

  def test_run_stops_a_command_at_the_deadline
    Dir.mktmpdir do |dir|
      started = Time.now
      status, timed_out = LiveJourneys.run(
        ["ruby", "-e", "puts 'started'; $stdout.flush; sleep 60"],
        log_path: File.join(dir, "log"),
        timeout_seconds: 1,
        out: StringIO.new,
        grace_seconds: 0.2
      )
      assert_nil status
      assert timed_out
      assert_operator Time.now - started, :<, 20
    end
  end
end
