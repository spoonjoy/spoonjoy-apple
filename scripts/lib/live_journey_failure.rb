# frozen_string_literal: true

require "json"

# Sorts a failed live-journeys run into one class, so the workflow knows whether a second attempt is allowed:
#
# - network: the device or the test process could not reach the QA mirror (a URLError such as a timeout or a lost
#   connection, or the app's sync log saying a request got no status because it was offline);
# - launch: the simulator or the test runner failed to start, launch, background or terminate the app, or never ran
#   the tests;
# - assertion: anything else, including every XCTAssert failure and every HTTP status QA answered with.
#
# Network and launch are infrastructure: the workflow retries them once. An assertion is never retried. One assertion
# anywhere in the run makes the whole run an assertion; otherwise launch outranks network.
#
# Only the failure message itself is matched: the accessibility dump XCUITest appends ("Attributes:", "Element
# subtree:") shows whatever text was on screen, so it is cut off first. The report names rules, never failure text.
module LiveJourneyFailure
  PASSED = "passed"
  NETWORK = "network"
  LAUNCH = "launch"
  ASSERTION = "assertion"
  INFRASTRUCTURE = [NETWORK, LAUNCH].freeze

  # URLError codes for an unreachable host: timedOut, cannotFindHost, cannotConnectToHost, networkConnectionLost,
  # dnsLookupFailed, notConnectedToInternet.
  NETWORK_CODES = %w[-1001 -1003 -1004 -1005 -1006 -1009].freeze

  NETWORK_RULES = [
    ["url-error-code", /(?:NSURLErrorDomain\s+Code=|NSURLErrorDomain error |URLError\b.*?)(#{NETWORK_CODES.join("|")})\b/],
    ["url-error-phrase", /The request timed out|The Internet connection appears to be offline|The network connection was lost|A server with the specified hostname could not be found|Could not connect to the server/],
    ["app-sync-offline", /-> no status \(offline\)/]
  ].freeze

  LAUNCH_RULES = [
    ["no-process-id", /does not have a process ID/],
    ["background-assertion", /Failed to get background assertion/],
    ["app-launch", /Failed to launch app|Simulator device failed to launch|Application failed to launch|Failed to launch|Failed to terminate/],
    ["journey-environment", /launched twice without the journey environment/],
    ["fresh-launch-signed-out", /The signed-out screen did not appear after a fresh launch/],
    ["saved-state-reset", /The app did not clear its saved state after the journey/],
    ["runner-bootstrap", /never finished bootstrapping|test runner crashed while preparing to run tests/],
    ["runner-never-started", /Test runner never began executing tests|failed to initialize for UI testing|Failed to install or launch the test runner|The test runner exited with code .* before (?:finishing|starting)/]
  ].freeze

  # Runner-level errors xcodebuild prints under "Testing failed:" without a test to pin them on.
  RUNNER_LOG_RULES = LAUNCH_RULES.select { |name, _| name.start_with?("runner-") }.freeze

  # "<file>:<line>: error: -[Target.Class testName] : message" in xcodebuild's output.
  LOG_FAILURE = /error: -\[(?:\w+\.)?(\w+) (\w+)\] : (.*)$/

  Failure = Struct.new(:test, :klass, :rule)
  Result = Struct.new(:klass, :failures, :reason) do
    def infrastructure?
      INFRASTRUCTURE.include?(klass)
    end
  end

  # The message a failure was raised with, without the screen dump that follows it.
  def self.message(text)
    text.to_s.split(/\n\s*(?:Attributes:|Element subtree:)/, 2).first.to_s
  end

  # One failure message's class and the rule that decided it.
  def self.classify_text(text)
    body = message(text)
    LAUNCH_RULES.each { |name, pattern| return [LAUNCH, name] if body.match?(pattern) }
    NETWORK_RULES.each { |name, pattern| return [NETWORK, name] if body.match?(pattern) }
    [ASSERTION, "assertion"]
  end

  # Failures from `xcresulttool get test-results summary` JSON.
  def self.failures_from_summary(summary)
    Array(summary["testFailures"]).map do |failure|
      klass, rule = classify_text(failure["failureText"])
      Failure.new(failure["testIdentifierString"] || failure["testName"] || "unknown test", klass, rule)
    end
  end

  # Failures from xcodebuild's output, for a run whose result bundle could not be read.
  def self.failures_from_log(log)
    log.to_s.each_line.map { |line| line.match(LOG_FAILURE) }.compact.map do |match|
      klass, rule = classify_text(match[3])
      Failure.new("#{match[1]}/#{match[2]}()", klass, rule)
    end.uniq(&:test)
  end

  # summary: the parsed summary JSON, or nil when the result bundle is missing or unreadable.
  # log: xcodebuild's output. exit_status: xcodebuild's exit status (nil when it was killed).
  # timed_out: true when the wrapper stopped xcodebuild at its own deadline.
  def self.classify(summary:, log:, exit_status:, timed_out: false)
    return Result.new(PASSED, [], "passed") if exit_status&.zero? && !timed_out && summary_passed?(summary)

    failures = summary ? failures_from_summary(summary) : failures_from_log(log)
    return Result.new(ASSERTION, failures, "assertion failure") if failures.any? { |f| f.klass == ASSERTION }
    return Result.new(LAUNCH, failures, "launch failure") if failures.any? { |f| f.klass == LAUNCH }
    return Result.new(NETWORK, failures, "network failure") if failures.any?

    runner_rule = RUNNER_LOG_RULES.find { |_, pattern| log.to_s.match?(pattern) }
    return Result.new(LAUNCH, [Failure.new("test runner", LAUNCH, runner_rule[0])], "launch failure") if runner_rule
    return Result.new(LAUNCH, [Failure.new("test runner", LAUNCH, "runner-timeout")], "launch failure") if timed_out
    return Result.new(LAUNCH, [Failure.new("test runner", LAUNCH, "no-result-bundle")], "launch failure") if summary.nil?
    if summary["totalTestCount"].to_i.zero?
      return Result.new(LAUNCH, [Failure.new("test runner", LAUNCH, "no-tests-ran")], "launch failure")
    end

    Result.new(ASSERTION, [Failure.new("xcodebuild", ASSERTION, "failed-without-test-failure")], "assertion failure")
  end

  def self.summary_passed?(summary)
    summary.nil? || summary["result"].to_s != "Failed"
  end

  # The job summary section for one attempt: the class and, per failed test, its class and rule. No failure text.
  def self.markdown(result, attempt:)
    lines = ["### Live journeys, attempt #{attempt}: #{result.klass}", ""]
    if result.klass == PASSED
      lines << "Every live journey passed."
    else
      kind = result.infrastructure? ? "Infrastructure (#{result.klass})" : "Assertion"
      verdict = if !result.infrastructure?
                  "not retried"
                elsif attempt == 1
                  "retried once"
                else
                  "the retry failed too"
                end
      lines << "#{kind} failure, #{verdict}."
      lines << ""
      lines << "| Test | Class | Rule |"
      lines << "| --- | --- | --- |"
      result.failures.each { |f| lines << "| `#{f.test.to_s.delete('|`')}` | #{f.klass} | #{f.rule} |" }
    end
    lines.join("\n") + "\n"
  end

  # Whether the step should fail: always on an assertion, and on infrastructure only once the retry is spent.
  def self.exit_code(result, attempt:)
    return 0 if result.klass == PASSED
    return 0 if result.infrastructure? && attempt == 1

    1
  end
end
