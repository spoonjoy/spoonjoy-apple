# frozen_string_literal: true

# Run: ruby scripts/test/optional_checks_wait_test.rb
#
# The account has only a few macOS runners. On a pull request, optional macOS work (Journeys, Launch smoke, Feel,
# Beta SDK, the App Intents X-ray) starts only after every required check has passed, so a required job never queues
# behind it. These tests hold the workflows to that shape.
require "minitest/autorun"
require "yaml"

class OptionalChecksWaitTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKFLOWS = File.join(ROOT, ".github/workflows")
  # Native's job ids for the checks main's branch protection requires.
  REQUIRED_JOBS = {
    "contracts" => "Contracts",
    "swift-tests" => "Swift tests",
    "reins-journeys" => "Reins journeys",
    "native-scenario-verifier" => "Native scenario verifier",
    "app-bundle" => "App bundle"
  }.freeze
  OPTIONAL_WORKFLOWS = %w[journeys.yml launch-smoke.yml feel.yml beta-sdk.yml].freeze

  def workflow(name)
    YAML.safe_load(File.read(File.join(WORKFLOWS, name)))
  end

  # YAML 1.1 reads the bare key `on` as true.
  def triggers(doc)
    on = doc.fetch(true)
    on.is_a?(Hash) ? on : Array(on).to_h { |event| [event, nil] }
  end

  def native_jobs
    workflow("native.yml").fetch("jobs")
  end

  def runs_on_macos?(doc)
    doc.fetch("jobs").values.any? { |job| job["runs-on"].to_s.match?(/\A(xcode-|macos)/) }
  end

  def test_required_job_names_match_branch_protection
    REQUIRED_JOBS.each do |id, name|
      assert_equal name, native_jobs.fetch(id).fetch("name"), "Native job #{id} is a required check by its name"
    end
  end

  def test_only_native_starts_macos_work_on_a_pull_request
    Dir[File.join(WORKFLOWS, "*.yml")].sort.each do |path|
      name = File.basename(path)
      next if name == "native.yml"

      doc = YAML.safe_load(File.read(path))
      next unless runs_on_macos?(doc)

      events = triggers(doc).keys
      refute_includes events, "pull_request", "#{name} runs on macOS, so Native calls it after the required checks"
      refute_includes events, "pull_request_target", name
    end
  end

  def test_native_calls_each_optional_workflow_after_every_required_check
    OPTIONAL_WORKFLOWS.each do |name|
      callers = native_jobs.select { |_, job| job["uses"] == "./.github/workflows/#{name}" }
      assert_equal 1, callers.size, "Native calls #{name} once"
      id, job = callers.first
      assert_equal "github.event_name == 'pull_request'", job.fetch("if"), "#{id} runs from Native on pull requests only"
      assert_equal REQUIRED_JOBS.keys.sort, Array(job.fetch("needs")).sort, "#{id} waits for every required check"
      refute job.key?("secrets"), "#{id} needs no secrets; pull requests from forks must not get them"
    end
  end

  MAIN_OPTIONAL_WORKFLOWS = (OPTIONAL_WORKFLOWS + %w[app-intents-xray.yml]).freeze

  def test_optional_workflows_are_callable_and_never_start_on_their_own_for_main
    MAIN_OPTIONAL_WORKFLOWS.each do |name|
      on = triggers(workflow(name))
      assert on.key?("workflow_call"), "#{name} must be callable"
      refute on.key?("push"), "#{name} runs on main from after-testflight.yml, not beside Native and TestFlight"
      refute on.key?("schedule"), name
    end
  end

  # Native -> TestFlight -> after-testflight.yml: on main, optional work takes a runner only once TestFlight is done.
  def test_main_runs_optional_workflows_after_testflight
    doc = workflow("after-testflight.yml")
    assert_equal({ "workflows" => ["TestFlight"], "types" => ["completed"], "branches" => ["main"] }, triggers(doc).fetch("workflow_run"))
    refute doc.key?("concurrency"), "main runs are never cancelled"
    jobs = doc.fetch("jobs")
    gate = jobs.fetch("commit")
    assert_includes gate.fetch("if"), "github.event.workflow_run.event == 'workflow_run'"
    assert_includes gate.fetch("if"), "github.event.workflow_run.head_branch == 'main'"
    MAIN_OPTIONAL_WORKFLOWS.each do |name|
      callers = jobs.select { |_, job| job["uses"] == "./.github/workflows/#{name}" }
      assert_equal 1, callers.size, "after-testflight.yml calls #{name} once"
      _, job = callers.first
      assert_equal "commit", job.fetch("needs")
      assert_equal "needs.commit.outputs.run == 'true'", job.fetch("if")
    end
  end

  def test_nothing_on_main_is_cancelled_by_an_optional_workflow
    MAIN_OPTIONAL_WORKFLOWS.each do |name|
      concurrency = workflow(name).fetch("concurrency")
      assert_includes ["${{ github.event_name == 'pull_request' }}", false], concurrency.fetch("cancel-in-progress"), name
    end
  end

  def test_app_intents_xray_waits_for_every_required_check
    xray = native_jobs.fetch("app-intents-xray")
    assert_equal REQUIRED_JOBS.keys.sort, Array(xray.fetch("needs")).sort
  end

  def test_feel_runs_on_pull_requests_only_when_its_paths_change
    jobs = workflow("feel.yml").fetch("jobs")
    feel = jobs.fetch("feel")
    assert_equal "paths", feel.fetch("needs")
    assert_equal "needs.paths.outputs.run == 'true'", feel.fetch("if")
    script = jobs.fetch("paths").fetch("steps").map { |step| step["run"].to_s }.join("\n")
    %w[Apps/* Packages/* Package.swift .github/workflows/feel.yml .github/workflows/native.yml].each do |pattern|
      assert_includes script, pattern
    end
  end

  # With auto-merge, the required checks passing is also the merge, and main's push runs the optional checks again.
  def test_closing_a_pull_request_stops_only_its_own_pull_request_runs
    doc = workflow("pr-closed.yml")
    assert_equal({ "pull_request" => { "types" => ["closed"] } }, triggers(doc))
    script = doc.fetch("jobs").fetch("stop-optional-checks").fetch("steps").map { |step| step["run"].to_s }.join("\n")
    assert_includes script, "actions/workflows/native.yml/runs?event=pull_request&head_sha=$HEAD_SHA"
    assert_includes script, 'select(.status != \\"completed\\")'
    assert_includes script, "select(any(.pull_requests[]; .number == $PR_NUMBER))"
  end

  def test_testflight_still_waits_only_for_native_on_main
    on = triggers(workflow("testflight.yml"))
    assert_equal({ "workflows" => ["Native"], "types" => ["completed"], "branches" => ["main"] }, on.fetch("workflow_run"))
  end
end
