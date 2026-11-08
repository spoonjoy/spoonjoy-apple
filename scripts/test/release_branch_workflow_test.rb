# frozen_string_literal: true

# Run: ruby scripts/test/release_branch_workflow_test.rb
#
# main builds the next version; a version already in App Review gets its fixes from a release/<version> branch.
# These tests hold the workflows that publish, stage and submit a release to the same release_branch contract.
require "json"
require "minitest/autorun"
require "yaml"

class ReleaseBranchWorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  MAIN_VERSION = "1.2"
  BRANCH_PATTERN = "^release/[0-9][0-9A-Za-z.-]*$"

  def workflow(name)
    YAML.safe_load(File.read(File.join(ROOT, ".github/workflows", name)), aliases: true)
  end

  def dispatch_inputs(name)
    # YAML 1.1 reads the bare key `on` as true.
    workflow(name).fetch(true).fetch("workflow_dispatch").fetch("inputs")
  end

  def source(name)
    File.read(File.join(ROOT, ".github/workflows", name))
  end

  def test_mac_job_runs_for_release_branch
    mac = workflow("testflight.yml").fetch("jobs").fetch("publish-mac-app-store")
    refute_includes mac.fetch("if"), "release_branch"
    refute_match(/iOS only/, dispatch_inputs("testflight.yml").fetch("release_branch").fetch("description"))
  end

  def test_listing_workflows_accept_release_branch
    assert_includes source("testflight.yml"), BRANCH_PATTERN
    %w[stage-app-store-listing.yml submit-app-store-review.yml].each do |name|
      input = dispatch_inputs(name).fetch("release_branch")
      assert_equal false, input.fetch("required"), name
      text = source(name)
      assert_includes text, BRANCH_PATTERN, "#{name} must validate release_branch like testflight.yml"
      assert_match(%r{ref: \$\{\{ inputs\.release_branch \|\| github\.sha \}\}}, text, "#{name} must check out the release branch head")
      assert_match(%r{--listing release-source/distribution/app-store/listing\.json}, text,
                   "#{name} must read the release branch's listing")
    end
    assert_match(%r{--screenshots release-source/distribution/app-store/screenshots}, source("stage-app-store-listing.yml"))
  end

  def test_submit_script_reads_a_given_listing
    script = File.read(File.join(ROOT, "scripts/submit-app-store-review.rb"))
    assert_match(/opts\.on\("--listing PATH"\)/, script)
  end

  def test_main_is_1_2
    listing = JSON.parse(File.read(File.join(ROOT, "distribution/app-store/listing.json")))
    assert_equal MAIN_VERSION, listing.fetch("version").fetch("versionString")
    refute listing.fetch("mac").key?("version"), "the Mac listing inherits the iOS version string"
    manifest = JSON.parse(File.read(File.join(ROOT, "distribution/apple-distribution.json")))
    testflight = manifest.fetch("channels").find { |channel| channel["id"] == "ios-testflight" }
    assert_equal MAIN_VERSION, testflight.fetch("store").fetch("version")
    generator = File.read(File.join(ROOT, "scripts/generate-xcode-project.rb"))
    assert_equal [MAIN_VERSION] * 2, generator.scan(/"MARKETING_VERSION"\] = "([^"]+)"/).flatten
    project = File.read(File.join(ROOT, "Spoonjoy.xcodeproj/project.pbxproj"))
    assert_equal [MAIN_VERSION], project.scan(/MARKETING_VERSION = ([^;]+);/).flatten.uniq
  end

  def test_distribution_check_ties_listing_to_marketing_version
    check = File.read(File.join(ROOT, "scripts/check-apple-distribution-kit.sh"))
    assert_match(/listing\.json/, check)
    assert_match(/versionString/, check)
  end
end
