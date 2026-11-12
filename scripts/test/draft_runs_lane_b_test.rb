# frozen_string_literal: true

# Run: ruby scripts/test/draft_runs_lane_b_test.rb
#
# A draft pull request runs only the short required checks (lane b). App bundle, and every optional job that needs
# it, waits until the pull request is marked ready, which reruns Native on the same commit. So five drafts never
# fill the App bundle lane ahead of a pull request that is ready, and no ready pull request lacks an App bundle result.
require "minitest/autorun"
require "yaml"

class DraftRunsLaneBTest < Minitest::Test
  NATIVE = File.expand_path("../../.github/workflows/native.yml", __dir__)
  DRAFT_SKIP = "github.event_name != 'pull_request' || !github.event.pull_request.draft"

  def native
    @native ||= YAML.safe_load(File.read(NATIVE))
  end

  def jobs
    native.fetch("jobs")
  end

  def test_marking_a_draft_ready_reruns_native
    types = native.fetch(true).fetch("pull_request").fetch("types")
    assert_equal %w[opened synchronize reopened ready_for_review], types
  end

  def test_a_draft_skips_app_bundle_only
    assert_equal DRAFT_SKIP, jobs.fetch("app-bundle").fetch("if")
    %w[swift-tests reins-journeys native-scenario-verifier contracts].each do |id|
      refute_includes jobs.fetch(id)["if"].to_s, "draft", "#{id} is a required check and must run on a draft"
    end
  end

  # Every job that isn't a required check, the advisory scan or the release note is optional, and must wait for
  # App bundle so a draft skips it.
  NOT_OPTIONAL = %w[contracts swift-tests reins-journeys native-scenario-verifier app-bundle ruby-advisory-scan
                    testflight-release-note].freeze

  def test_every_optional_job_needs_app_bundle
    (jobs.keys - NOT_OPTIONAL).each do |id|
      assert_includes Array(jobs.fetch(id)["needs"]), "app-bundle", "#{id} must wait for App bundle, so a draft skips it"
    end
  end
end
