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
    clean_log.write("Build complete! (0.20s)\nTest run passed.\n")
    warning_log.write("Sources/SpoonjoyCore/Foo.swift:12:8: warning: variable was never mutated\n")

    clean, = run_command("ruby", WARNING_SCRIPT.to_s, "--log", clean_log.to_s)
    record_failure("warning script must pass a warning-free log") unless clean

    warned, warned_stdout, warned_stderr = run_command("ruby", WARNING_SCRIPT.to_s, "--log", warning_log.to_s)
    if warned
      record_failure("warning script must fail on branch-source warnings")
    elsif !("#{warned_stdout}\n#{warned_stderr}".match?(/warning/i))
      record_failure("warning script failure should report the warning line")
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
