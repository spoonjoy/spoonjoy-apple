# frozen_string_literal: true

# Run: ruby scripts/test/macos_lanes_test.rb
#
# spoonjoy runs at most 5 macOS jobs at once (GitHub Free), xcode-27 included. Pull request, after-TestFlight and
# dispatch work waits in three lanes (see the note at the top of native.yml), so the merge queue and main
# always keep runners. A macOS job with no lane escapes that cap and takes a slot the merge queue is waiting for,
# as a new Siri journey job did on 2026-11-11. These tests fail any such job, including in every reusable workflow
# that a workflow_run workflow calls.
require "minitest/autorun"
require "yaml"

class MacosLanesTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKFLOWS = File.join(ROOT, ".github/workflows")
  LANE = /spoonjoy-macos-lane-([abc])\b/
  # Tied to shipping, so never laned: they share the slots outside the lanes with the merge queue and main.
  UNLANED = %w[testflight.yml testflight-signing-dry-run.yml review-demo-launch.yml].freeze
  # Native's required checks take lanes a and b; everything else waits in lane c, so no required check queues
  # behind optional work.
  REQUIRED_LANES = {
    "app-bundle" => "a",
    "swift-tests" => "b",
    "reins-journeys" => "b",
    "native-scenario-verifier" => "b"
  }.freeze

  def workflow(name)
    YAML.safe_load(File.read(File.join(WORKFLOWS, name)), aliases: true)
  end

  # YAML 1.1 reads the bare key `on` as true.
  def triggers(doc)
    on = doc.key?(true) ? doc[true] : doc.fetch("on")
    on.is_a?(Hash) ? on.keys : Array(on)
  end

  # Broad on purpose: runs-on as a label, an array, a group hash, an expression or a matrix value. A false
  # positive only asks for a lane.
  def macos?(job)
    [job["runs-on"], job.dig("strategy", "matrix")].to_s.match?(/macos|xcode-/i)
  end

  def macos_jobs(name)
    workflow(name).fetch("jobs").select { |_, job| macos?(job) }
  end

  def lane_of(job)
    concurrency = job["concurrency"]
    return nil unless concurrency.is_a?(Hash) && concurrency["queue"] == "max"

    concurrency["group"].to_s[LANE, 1]
  end

  def called_workflows(name)
    workflow(name).fetch("jobs").values.map do |job|
      job["uses"].to_s[%r{\A\./\.github/workflows/(.+\.ya?ml)\z}, 1]
    end.compact
  end

  def all_workflows
    Dir[File.join(WORKFLOWS, "*.{yml,yaml}")].map { |path| File.basename(path) }.sort
  end

  def test_every_macos_job_waits_in_a_lane
    all_workflows.each do |name|
      next if UNLANED.include?(name)

      macos_jobs(name).each do |id, job|
        refute_nil lane_of(job), "#{name} job #{id} runs on macOS with no lane: give it concurrency " \
                                 "group 'spoonjoy-macos-lane-c' (or a/b for a required check) and queue: max"
        refute job["concurrency"].key?("cancel-in-progress"), "#{name} job #{id}: a lane never cancels"
      end
    end
  end

  def test_no_laned_workflow_calls_an_unlaned_one
    (all_workflows - UNLANED).each do |caller|
      called_workflows(caller).each do |name|
        refute_includes UNLANED, name, "#{caller} calls #{name}, so its jobs would run with no lane"
      end
    end
  end

  def test_reusable_workflows_called_by_workflow_run_are_laned
    callers = (all_workflows - UNLANED).select { |name| triggers(workflow(name)).include?("workflow_run") }
    refute_empty callers, "after-testflight.yml runs on workflow_run"
    callers.each do |caller|
      called_workflows(caller).each do |name|
        macos_jobs(name).each do |id, job|
          assert_equal "c", lane_of(job), "#{caller} calls #{name}; its job #{id} is optional work for lane c"
        end
      end
    end
  end

  def test_required_checks_take_lanes_a_and_b_and_optional_work_takes_lane_c
    macos_jobs("native.yml").each do |id, job|
      assert_equal REQUIRED_LANES.fetch(id, "c"), lane_of(job), "native.yml job #{id}"
    end
  end

  # One shared lane a and b held about 10 PRs pending for hours on 2026-11-12 while Macs sat free; a lane per PR (#321)
  # then let about 15 open PRs take every macos-26 runner, and the merge queue's head waited 3 hours. So PRs share a
  # pool of two lanes a and two lanes b, by the parity of their number (Actions expressions have no %): PR work holds at
  # most 4 runners, and merge-queue and push runs keep the rest. Optional work stays in the one shared lane c.
  PR_POOL = "(endsWith(format('{0}', github.event.pull_request.number), '0') || " \
            "endsWith(format('{0}', github.event.pull_request.number), '2') || " \
            "endsWith(format('{0}', github.event.pull_request.number), '4') || " \
            "endsWith(format('{0}', github.event.pull_request.number), '6') || " \
            "endsWith(format('{0}', github.event.pull_request.number), '8')) && '0' || '1'"

  def test_pull_request_required_jobs_share_a_pool_of_two_lanes
    macos_jobs("native.yml").each do |id, job|
      group = job.fetch("concurrency").fetch("group").to_s.gsub(/\s+/, " ")
      lane = REQUIRED_LANES[id]
      if lane
        assert_includes group,
                        "github.event_name == 'pull_request' && format('spoonjoy-macos-lane-#{lane}-pr-{0}', #{PR_POOL})",
                        "native.yml job #{id}: a pull request's required job waits in lane #{lane}-pr-0 or -1, by its number's parity"
        refute_includes group, "format('spoonjoy-macos-lane-#{lane}-pr-{0}', github.event.pull_request.number)",
                        "native.yml job #{id}: a lane per PR lets open PRs take every runner"
      else
        refute_includes group, "pull_request.number", "native.yml job #{id}: optional work shares lane c"
      end
    end
  end

  def test_merge_queue_and_push_jobs_skip_the_lanes
    macos_jobs("native.yml").each do |id, job|
      group = job.fetch("concurrency").fetch("group").to_s
      assert_includes group, "github.event_name == 'merge_group' || github.event_name == 'push'",
                      "native.yml job #{id}: merge-queue and push jobs take a group of their own"
      assert_includes group, "github.run_id", "native.yml job #{id}: that group is unique to its run"
    end
  end
end
