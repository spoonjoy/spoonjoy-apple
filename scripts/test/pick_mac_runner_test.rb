# frozen_string_literal: true

# Run: ruby scripts/test/pick_mac_runner_test.rb
#
# spoonjoy-apple is public, so a self-hosted runner must never run pull request code. Ari's Mac (label
# spoonjoy-local-mac) takes App bundle only on merge-queue and main/release push runs, and only when its Mac runner job
# picked it. These tests hold the workflows to that and check the pick itself.
require "minitest/autorun"
require "stringio"
require "tmpdir"
require "yaml"
require_relative "../pick-mac-runner"

class PickMacRunnerTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKFLOWS = File.join(ROOT, ".github/workflows")
  NOW = 1_800_000_000
  # The jobs that may run on the local Mac, with the hosted label each falls back to.
  LOCAL_JOBS = { "app-bundle" => "xcode-27", "reins-journeys" => "macos-26" }.freeze

  def native
    @native ||= YAML.safe_load(File.read(File.join(WORKFLOWS, "native.yml")))
  end

  def pick(event: "merge_group", ref: "refs/heads/gh-readonly-queue/main/pr-1", heartbeat: "v1 #{NOW - 30} ready 40",
           active: 0)
    PickMacRunner.choose(event: event, ref: ref, heartbeat: heartbeat, now: NOW, active_local_jobs: active).first
  end

  def test_only_app_bundle_can_reach_the_local_mac
    Dir[File.join(WORKFLOWS, "*.{yml,yaml}")].each do |path|
      YAML.safe_load(File.read(path), aliases: true).fetch("jobs").each do |id, job|
        runs_on = job["runs-on"].to_s
        refute_match(/self-hosted/, runs_on, "#{File.basename(path)} job #{id}: no job asks for any self-hosted runner")
        next if File.basename(path) == "native.yml" && LOCAL_JOBS.key?(id)

        refute_includes runs_on, "spoonjoy-local-mac", "#{File.basename(path)} job #{id} must not run on the local Mac"
      end
    end
  end

  def test_local_jobs_use_the_local_mac_only_on_trusted_events_it_was_picked_for
    LOCAL_JOBS.each do |id, hosted|
      job = native.fetch("jobs").fetch(id)
      assert_equal "${{ (github.event_name == 'merge_group' || github.event_name == 'push') " \
                   "&& needs.mac-runner.outputs.mac == 'local' && 'spoonjoy-local-mac' || '#{hosted}' }}",
                   job.fetch("runs-on").gsub(/\s+/, " ").strip, id
      assert_equal "mac-runner", job.fetch("needs"), id
      assert job.fetch("if").start_with?("${{ !cancelled()"), "#{id} runs even when Mac runner is skipped or fails"
    end
  end

  # A skipped job skips every job downstream whose if has no status function, so a Mac runner job skipped on pull
  # requests skipped all the optional jobs behind App bundle. It always runs, and on a pull request it answers hosted.
  def test_the_mac_runner_job_never_skips
    job = native.fetch("jobs").fetch("mac-runner")
    refute job.key?("if"), "Mac runner must not skip, or the optional jobs behind App bundle skip with it"
    assert_equal "ubuntu-24.04", job.fetch("runs-on")
    assert_equal true, job.fetch("steps").last.fetch("continue-on-error"), "a failed pick falls back to hosted"
  end

  def test_app_bundle_keeps_derived_data_in_runner_temp
    steps = native.fetch("jobs").fetch("app-bundle").fetch("steps").map { |step| step["run"].to_s }.join("\n")
    calls = steps.scan(/xcodebuild -project[^\n]*/)
    refute_empty calls
    calls.each { |call| assert_includes call, "-derivedDataPath \"$RUNNER_TEMP/DerivedData\"" }
  end

  def test_picks_the_idle_local_mac_for_the_merge_queue_and_main
    assert_equal "local", pick
    assert_equal "local", pick(event: "push", ref: "refs/heads/main")
    assert_equal "local", pick(event: "push", ref: "refs/heads/release/1.2.1")
  end

  def test_never_picks_the_local_mac_for_untrusted_events
    assert_equal "hosted", pick(event: "pull_request", ref: "refs/pull/1/merge")
    assert_equal "hosted", pick(event: "pull_request_target", ref: "refs/heads/main")
    assert_equal "hosted", pick(event: "workflow_dispatch", ref: "refs/heads/main")
    assert_equal "hosted", pick(event: "push", ref: "refs/heads/feature")
  end

  def test_picks_hosted_when_the_mac_is_busy_stale_low_on_disk_or_unknown
    assert_equal "hosted", pick(active: 1)
    assert_equal "hosted", pick(active: nil)
    assert_equal "hosted", pick(heartbeat: "v1 #{NOW - 301} ready 40")
    assert_equal "hosted", pick(heartbeat: "v1 #{NOW - 10} busy 40")
    assert_equal "hosted", pick(heartbeat: "v1 #{NOW - 10} low-disk 12")
    assert_equal "hosted", pick(heartbeat: "v1 #{NOW - 10} offline 40")
    assert_equal "hosted", pick(heartbeat: nil)
    assert_equal "hosted", pick(heartbeat: "garbage")
  end

  def test_main_writes_hosted_for_a_pull_request_without_calling_github
    Dir.mktmpdir do |dir|
      output = File.join(dir, "out")
      env = { "GITHUB_EVENT_NAME" => "pull_request", "GITHUB_REF" => "refs/pull/1/merge", "GITHUB_OUTPUT" => output }
      assert_equal "hosted", PickMacRunner.main(env, out: StringIO.new)
      assert_equal "mac=hosted\n", File.read(output)
    end
  end
end
