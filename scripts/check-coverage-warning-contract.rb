#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).join("..").expand_path
COVERAGE_SCRIPT = ROOT.join("scripts/enforce-swift-coverage.rb")
WARNING_SCRIPT = ROOT.join("scripts/fail-on-warning.rb")
WORKFLOW = ROOT.join(".github/workflows/native.yml")

@failures = []

def record_failure(message)
  @failures << message
end

def run_command(*args)
  stdout, stderr, status = Open3.capture3(*args)
  [status.success?, stdout, stderr]
end

def write_coverage_json(path, percent:)
  covered = percent == 100.0 ? 10 : 9
  payload = {
    "data" => [
      {
        "files" => [
          {
            "filename" => ROOT.join("Sources/SpoonjoyCore/Foo.swift").to_s,
            "summary" => {
              "lines" => {
                "count" => 10,
                "covered" => covered,
                "percent" => percent
              }
            }
          },
          {
            "filename" => ROOT.join("Tests/SpoonjoyCoreTests/FooTests.swift").to_s,
            "summary" => {
              "lines" => {
                "count" => 10,
                "covered" => 0,
                "percent" => 0.0
              }
            }
          }
        ]
      }
    ]
  }
  path.write(JSON.pretty_generate(payload))
end

def check_coverage_script_behavior
  unless COVERAGE_SCRIPT.file?
    record_failure("#{COVERAGE_SCRIPT.relative_path_from(ROOT)} is missing")
    return
  end

  Dir.mktmpdir("spoonjoy-coverage-contract") do |dir|
    dir_path = Pathname.new(dir)
    passing_json = dir_path.join("passing.json")
    failing_json = dir_path.join("failing.json")
    missing_json = dir_path.join("missing.json")
    write_coverage_json(passing_json, percent: 100.0)
    write_coverage_json(failing_json, percent: 90.0)

    passing, = run_command(
      "ruby",
      COVERAGE_SCRIPT.to_s,
      "--coverage-json", passing_json.to_s,
      "--minimum", "100",
      "--include", "Sources/SpoonjoyCore"
    )
    record_failure("coverage script must pass when included files are at 100%") unless passing

    below_threshold, below_stdout, below_stderr = run_command(
      "ruby",
      COVERAGE_SCRIPT.to_s,
      "--coverage-json", failing_json.to_s,
      "--minimum", "100",
      "--include", "Sources/SpoonjoyCore"
    )
    if below_threshold
      record_failure("coverage script must fail below the minimum threshold")
    elsif !("#{below_stdout}\n#{below_stderr}".match?(/below|threshold|90/i))
      record_failure("coverage script below-threshold failure should explain the measured shortfall")
    end

    missing, missing_stdout, missing_stderr = run_command(
      "ruby",
      COVERAGE_SCRIPT.to_s,
      "--coverage-json", missing_json.to_s,
      "--minimum", "100",
      "--include", "Sources/SpoonjoyCore"
    )
    if missing
      record_failure("coverage script must fail when coverage JSON is missing")
    elsif !("#{missing_stdout}\n#{missing_stderr}".match?(/missing|not found|no such file/i))
      record_failure("coverage script missing-file failure should name the missing coverage JSON")
    end
  end
end

def check_warning_script_behavior
  unless WARNING_SCRIPT.file?
    record_failure("#{WARNING_SCRIPT.relative_path_from(ROOT)} is missing")
    return
  end

  Dir.mktmpdir("spoonjoy-warning-contract") do |dir|
    dir_path = Pathname.new(dir)
    clean_log = dir_path.join("clean.log")
    warning_log = dir_path.join("warning.log")
    scaler_diagnostic_log = dir_path.join("scaler-diagnostic.log")
    generic_io_service_diagnostic_log = dir_path.join("generic-io-service-diagnostic.log")
    other_driver_diagnostic_log = dir_path.join("other-driver-diagnostic.log")
    simulator_launch_metric_log = dir_path.join("simulator-launch-metric.log")
    spoofed_simulator_launch_metric_log = dir_path.join("spoofed-simulator-launch-metric.log")
    benign_failure_language_log = dir_path.join("benign-failure-language.log")
    clean_log.write("Build complete! (0.20s)\nTest run passed.\n")
    warning_log.write("Sources/SpoonjoyCore/Foo.swift:12:8: warning: variable was never mutated\n")
    scaler_diagnostic_log.write("IOServiceMatchingfailed for: AppleM2ScalerParavirtDriver\n")
    generic_io_service_diagnostic_log.write("IOServiceMatchingfailed\n")
    other_driver_diagnostic_log.write("IOServiceMatchingfailed for: UnexpectedScalerDriver\n")
    simulator_launch_metric_log.write(<<~LOG)
      2026-07-21 11:59:33.005687-0700 SpoonjoyUITests-Runner[2491:106082690] [General] Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
      2026-07-21 11:59:33.045664-0700 SpoonjoyUITests-Runner[2491:106082691] [General] Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics
      2026-07-21 20:49:19.199788+0000 SpoonjoyUITests-Runner[11946:43903] [General] Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
      2026-07-21 20:49:19.243426+0000 SpoonjoyUITests-Runner[11946:43903] [General] Failed to send CA Event for app launch measurements for ca_event_type: 1 event_name: com.apple.app_launch_measurement.ExtendedLaunchMetrics
    LOG
    spoofed_simulator_launch_metric_log.write(
      "2026-07-21 11:59:33.005687-0700 SpoonjoyUITests-Runner[2491:106082690] [General] Failed to send CA Event for app launch measurements for ca_event_type: 0 event_name: com.apple.app_launch_measurement.UnexpectedMetric\n"
    )
    benign_failure_language_log.write("Test \"failed upload remains queued\" passed\n")

    clean, = run_command("ruby", WARNING_SCRIPT.to_s, "--log", clean_log.to_s)
    record_failure("warning script must pass a warning-free log") unless clean

    warned, warned_stdout, warned_stderr = run_command("ruby", WARNING_SCRIPT.to_s, "--log", warning_log.to_s)
    if warned
      record_failure("warning script must fail on branch-source warnings")
    elsif !("#{warned_stdout}\n#{warned_stderr}".match?(/warning/i))
      record_failure("warning script failure should report the warning line")
    end

    scaler_diagnostic, = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      scaler_diagnostic_log.to_s
    )
    unless scaler_diagnostic
      record_failure("warning script must allowlist only the exact Apple M2 scaler virtualization diagnostic")
    end

    generic_diagnostic, generic_stdout, generic_stderr = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      generic_io_service_diagnostic_log.to_s
    )
    if generic_diagnostic
      record_failure("warning script must fail on a generic IOServiceMatchingfailed diagnostic")
    elsif !("#{generic_stdout}\n#{generic_stderr}".include?("IOServiceMatchingfailed"))
      record_failure("warning script failure should report a generic IOServiceMatchingfailed diagnostic")
    end

    other_driver_diagnostic, other_driver_stdout, other_driver_stderr = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      other_driver_diagnostic_log.to_s
    )
    if other_driver_diagnostic
      record_failure("warning script must fail when IOServiceMatchingfailed names another driver")
    elsif !("#{other_driver_stdout}\n#{other_driver_stderr}".include?("UnexpectedScalerDriver"))
      record_failure("warning script failure should report the unexpected IOService driver")
    end

    simulator_launch_metric, = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      simulator_launch_metric_log.to_s
    )
    unless simulator_launch_metric
      record_failure("warning script must allowlist only the exact UI-test runner launch metric diagnostics")
    end

    spoofed_launch_metric, spoofed_stdout, spoofed_stderr = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      spoofed_simulator_launch_metric_log.to_s
    )
    if spoofed_launch_metric
      record_failure("warning script must fail on an unrecognized simulator launch metric diagnostic")
    elsif !("#{spoofed_stdout}\n#{spoofed_stderr}".include?("UnexpectedMetric"))
      record_failure("warning script failure should report the unrecognized simulator launch metric")
    end

    benign_failure_language, = run_command(
      "ruby",
      WARNING_SCRIPT.to_s,
      "--log",
      benign_failure_language_log.to_s
    )
    unless benign_failure_language
      record_failure("warning script must pass expected test output containing benign failure language")
    end
  end
end

def check_workflow_wiring
  unless WORKFLOW.file?
    record_failure("#{WORKFLOW.relative_path_from(ROOT)} is missing")
    return
  end

  workflow = WORKFLOW.read

  if workflow.include?("swift test --enable-code-coverage --show-codecov-path")
    record_failure("workflow must not combine coverage generation with --show-codecov-path")
  end

  unless workflow.include?("swift test --enable-code-coverage --disable-xctest --parallel -Xswiftc -warnings-as-errors")
    record_failure("workflow must run the warning-enforced SwiftPM coverage generator")
  end

  unless workflow.include?("swift test --show-codecov-path")
    record_failure("workflow must locate coverage JSON with a separate swift test --show-codecov-path step")
  end

  unless workflow.include?("ruby scripts/enforce-swift-coverage.rb --coverage-json")
    record_failure("workflow must run scripts/enforce-swift-coverage.rb")
  end

  unless workflow.include?("ruby scripts/fail-on-warning.rb --log")
    record_failure("workflow must run scripts/fail-on-warning.rb against saved logs")
  end
end

check_coverage_script_behavior
check_warning_script_behavior
check_workflow_wiring

if @failures.any?
  warn "FAIL: coverage/warning contract is not satisfied"
  @failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "coverage/warning contract ok"
