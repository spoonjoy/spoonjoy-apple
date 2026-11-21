# frozen_string_literal: true

# Run: ruby scripts/test/journey_time_allowance_test.rb
#
# XCTest stops a UI test at its execution time allowance and then fails to terminate the app, which reads as an
# assertion, so the run is never retried (#419). Each journey's allowance must cover what it takes on a hosted runner,
# and stay inside the wrapper's own deadline (live-journeys.rb --timeout-minutes), which then classifies a hang.
require "minitest/autorun"

class JourneyTimeAllowanceTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  JOURNEYS = File.read(File.join(ROOT, ".github/workflows/journeys.yml"))

  # The iPad parity capture took 459 to 600 s on passing main runs (Journeys 43923699696, 43931150392, 43949615139,
  # 44238504925, 44698616588) and ran past 600 s on 44838568572 and 44868027931.
  PARITY_SLOWEST_SECONDS = 600

  def steps_running(only_testing)
    JOURNEYS.split(/^      - name: /).select { |step| step.include?("test-without-building") && step.include?("-only-testing:#{only_testing}") }
  end

  def allowance(step)
    step[/-default-test-execution-time-allowance (\d+)/, 1].to_i
  end

  def maximum(step)
    step[/-maximum-test-execution-time-allowance (\d+)/, 1].to_i
  end

  def wrapper_seconds(step)
    step[/--timeout-minutes (\d+)/, 1].to_i * 60
  end

  def test_the_parity_capture_has_room_beyond_its_slowest_passing_run
    steps = steps_running("SpoonjoyParityJourneys")
    refute_empty steps
    steps.each do |step|
      assert_operator allowance(step), :>=, PARITY_SLOWEST_SECONDS * 2, "the parity capture's allowance"
    end
  end

  def test_every_journey_allowance_ends_before_the_wrapper_stops_xcodebuild
    steps = JOURNEYS.split(/^      - name: /).select { |step| step.include?("-default-test-execution-time-allowance") && step.include?("--timeout-minutes") }
    refute_empty steps
    steps.each do |step|
      assert_operator allowance(step), :<=, maximum(step), step.lines.first
      assert_operator maximum(step), :<=, wrapper_seconds(step), "#{step.lines.first.strip}: XCTest's maximum allowance must end before the wrapper's deadline"
    end
  end
end
