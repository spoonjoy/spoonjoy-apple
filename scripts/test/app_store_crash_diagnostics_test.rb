# frozen_string_literal: true

# Run: ruby scripts/test/app_store_crash_diagnostics_test.rb
require "minitest/autorun"
require "stringio"
require_relative "../lib/app_store_crash_diagnostics"

class AppStoreCrashDiagnosticsTest < Minitest::Test
  TREE = [{ "callStacks" => [{ "callStackRootFrames" => [
    { "binaryName" => "Spoonjoy", "offsetIntoBinaryTextSegment" => 1234, "subFrames" => [
      { "binaryName" => "SwiftUI", "symbol" => "ViewGraph.update", "subFrames" => [] }
    ] }
  ] }] }].freeze

  CRASH = <<~TEXT
    Incident Identifier: 11111111-2222-3333-4444-555555555555
    CrashReporter Key:   abcdef
    Hardware Model:      iPhone19,9
    OS Version:          iPhone OS 27.1 (25B5)
    Exception Type:  EXC_BREAKPOINT (SIGTRAP)
    Termination Reason: SIGNAL 5 Trace/BPT trap: 5

    Thread 0 name:   Dispatch queue: com.apple.main-thread
    Thread 0 Crashed:
    0   Spoonjoy    0x0000000100001234 HingeDivisionView.layoutSubviews() + 52
    1   UIKitCore   0x0000000180001234 -[UIView layoutSublayersOfLayer:] + 100

    Thread 1:
    0   libsystem_kernel.dylib 0x1 __workq_kernreturn + 8
  TEXT

  def test_frames_follow_the_hottest_path_and_name_unsymbolicated_offsets
    assert_equal ["Spoonjoy +1234", "SwiftUI ViewGraph.update"], AppStoreCrashDiagnostics.frames(TREE)
    assert_empty AppStoreCrashDiagnostics.frames(nil)
  end

  def test_crash_excerpt_keeps_the_exception_and_crashing_thread_but_no_device_identifiers
    excerpt = AppStoreCrashDiagnostics.crash_excerpt(CRASH)
    assert_includes excerpt, "Exception Type:  EXC_BREAKPOINT (SIGTRAP)"
    assert_includes excerpt, "Thread 0 Crashed:"
    assert(excerpt.any? { |line| line.include?("HingeDivisionView.layoutSubviews") })
    refute(excerpt.any? { |line| line.include?("Incident Identifier") || line.include?("CrashReporter Key") })
    refute(excerpt.any? { |line| line.include?("__workq_kernreturn") })
    assert_empty AppStoreCrashDiagnostics.crash_excerpt(nil)
  end

  class FakeClient
    def initialize(answers)
      @answers = answers
    end

    def get(path, _query = {})
      answer = @answers.find { |pattern, _| path.end_with?(pattern) }&.last
      raise AppStoreListing::Error, "GET #{path} answered HTTP 404: Not found" unless answer

      answer
    end

    def get_all(path, query = {})
      get(path, query)["data"]
    end
  end

  def test_reports_signatures_and_feedback_without_tester_details
    client = FakeClient.new([
      ["/v1/builds", { "data" => [{ "id" => "B", "attributes" => { "version" => "94" } }] }],
      ["/v1/builds/B/diagnosticSignatures", { "data" => [{ "id" => "D", "attributes" => { "diagnosticType" => "LAUNCHES", "weight" => 1.0, "signature" => "Spoonjoy crash" } }] }],
      ["/v1/diagnosticSignatures/D/logs", { "productData" => [{ "diagnosticLogs" => [{ "diagnosticMetaData" => { "deviceType" => "iPhone19,9", "osVersion" => "27.1", "buildVersion" => "94" }, "callStackTree" => TREE }] }] }],
      ["/betaFeedbackCrashSubmissions", { "data" => [{ "id" => "F", "attributes" => { "createdDate" => "2026-10-26", "deviceModel" => "iPhone19,9", "osVersion" => "27.1", "email" => "tester@example.com", "comment" => "it broke" }, "relationships" => { "build" => { "data" => { "id" => "B" } } } }] }],
      ["/v1/betaFeedbackCrashSubmissions/F/crashLog", { "data" => { "attributes" => { "logText" => CRASH } } }]
    ])
    log = StringIO.new
    AppStoreCrashDiagnostics::Reader.new(client, app_id: "A", platform: "IOS", version_string: "1.0", log: log).run
    out = log.string
    assert_includes out, "Build 94: 1 diagnostic signature(s)"
    assert_includes out, "LAUNCHES weight 1.0: Spoonjoy crash"
    assert_includes out, "Spoonjoy +1234"
    assert_includes out, "2026-10-26 iPhone19,9 27.1 build 94"
    assert_includes out, "HingeDivisionView.layoutSubviews"
    refute_includes out, "tester@example.com"
    refute_includes out, "it broke"
    refute_includes out, "Incident Identifier"
  end

  def test_an_endpoint_that_refuses_is_reported_and_the_rest_still_run
    client = FakeClient.new([
      ["/v1/builds", { "data" => [{ "id" => "B", "attributes" => { "version" => "94" } }] }],
      ["/betaFeedbackCrashSubmissions", { "data" => [] }]
    ])
    log = StringIO.new
    AppStoreCrashDiagnostics::Reader.new(client, app_id: "A", platform: "IOS", version_string: "1.0", log: log).run
    assert_includes log.string, "No /v1/builds/B/diagnosticSignatures: GET"
    assert_includes log.string, "TestFlight crash feedback: 0 submission(s)"
  end
end
