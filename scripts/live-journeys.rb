#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs one attempt of the live journeys and classifies a failure (see scripts/lib/live_journey_failure.rb).
#
#   ruby scripts/live-journeys.rb --attempt 1 --result-bundle PATH --log PATH --timeout-minutes 38 -- xcodebuild ...
#
# The command's output goes to stdout and to --log. The attempt is stopped at --timeout-minutes, before the step's own
# timeout, so the result bundle and the log are still there to classify and scan. On a failure it reads the result
# bundle with xcresulttool, writes `class=<passed|network|launch|assertion>` to $GITHUB_OUTPUT and a table of failed
# tests, classes and rules (never failure text) to $GITHUB_STEP_SUMMARY.
#
# Exit status: 0 when the journeys passed, or when attempt 1 failed on infrastructure (network or launch) and the
# workflow's retry step will run; 1 for any assertion failure and for an infrastructure failure on attempt 2.

require "json"
require "open3"
require "optparse"
require_relative "lib/live_journey_failure"

module LiveJourneys
  SUMMARY_READER = lambda do |path|
    next nil unless File.directory?(path)

    output, status = Open3.capture2e("xcrun", "xcresulttool", "get", "test-results", "summary", "--path", path)
    next nil unless status.success?

    begin
      JSON.parse(output)
    rescue JSON::ParserError
      nil
    end
  end

  # Runs command, copying its output to out and to log_path. Returns [exit status or nil, timed out].
  def self.run(command, log_path:, timeout_seconds:, out: $stdout, grace_seconds: 10)
    File.open(log_path, "w") do |log|
      Open3.popen2e(*command, pgroup: true) do |stdin, output, wait|
        stdin.close
        reader = Thread.new do
          output.each_line do |line|
            out.write(line)
            log.write(line)
          end
        end
        finished = wait.join(timeout_seconds)
        unless finished
          stop(wait.pid, grace_seconds)
          wait.join
          reader.join(5)
          return [nil, true]
        end
        reader.join
        return [wait.value.exitstatus, false]
      end
    end
  end

  # TERM to the whole process group (xcodebuild and the simulator tools it started), then KILL after the grace period.
  def self.stop(pid, grace_seconds)
    Process.kill("TERM", -pid)
    sleep grace_seconds
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  end

  def self.main(argv, env: ENV, summary_reader: SUMMARY_READER, out: $stdout)
    options = { attempt: 1, timeout_minutes: 38 }
    command = argv.include?("--") ? argv[(argv.index("--") + 1)..-1] : []
    flags = argv.include?("--") ? argv[0...argv.index("--")] : argv
    OptionParser.new do |opts|
      opts.on("--attempt N", Integer) { |v| options[:attempt] = v }
      opts.on("--result-bundle PATH") { |v| options[:result_bundle] = v }
      opts.on("--log PATH") { |v| options[:log] = v }
      opts.on("--timeout-minutes M", Float) { |v| options[:timeout_minutes] = v }
    end.parse!(flags)
    raise ArgumentError, "a command after -- is required" if command.empty?
    raise ArgumentError, "--result-bundle and --log are required" unless options[:result_bundle] && options[:log]

    status, timed_out = run(command, log_path: options[:log], timeout_seconds: options[:timeout_minutes] * 60, out: out)
    summary = status&.zero? && !timed_out ? nil : summary_reader.call(options[:result_bundle])
    result = LiveJourneyFailure.classify(
      summary: summary,
      log: File.read(options[:log]),
      exit_status: status,
      timed_out: timed_out
    )
    report(result, attempt: options[:attempt], env: env, out: out, timed_out: timed_out)
    LiveJourneyFailure.exit_code(result, attempt: options[:attempt])
  end

  def self.report(result, attempt:, env:, out:, timed_out:)
    append(env["GITHUB_OUTPUT"], "class=#{result.klass}\n")
    append(env["GITHUB_STEP_SUMMARY"], LiveJourneyFailure.markdown(result, attempt: attempt))
    out.puts("::warning::The live journeys stopped at the attempt's time limit.") if timed_out
    return if result.klass == LiveJourneyFailure::PASSED

    rules = result.failures.map(&:rule).uniq.join(", ")
    if result.infrastructure?
      next_step = attempt == 1 ? "retrying once" : "the retry failed too"
      out.puts("::warning::Live journeys attempt #{attempt}: infrastructure failure (#{result.klass}: #{rules}); #{next_step}.")
    else
      out.puts("::error::Live journeys attempt #{attempt}: assertion failure (#{rules}); not retried.")
    end
  end

  def self.append(path, text)
    return if path.nil? || path.empty?

    File.open(path, "a") { |file| file.write(text) }
  end
end

exit(LiveJourneys.main(ARGV)) if $PROGRAM_NAME == __FILE__
