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
  MAIN_VERSION = "1.3"
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

  # A release branch cut before the Mac App Store target (#154) has no Mac export options. Its dispatch publishes
  # iOS and skips the Mac upload with a notice instead of failing the run (#255).
  def test_mac_job_skips_a_source_without_a_mac_app_store_target
    steps = workflow("testflight.yml").fetch("jobs").fetch("publish-mac-app-store").fetch("steps")
    names = steps.map { |step| step["name"] }
    gate_index = steps.index { |step| step["id"] == "mac_target" }
    refute_nil gate_index, "the Mac job needs a mac_target step"
    gate = steps[gate_index]
    assert_operator gate_index, :>, names.index("Verify exact Native release evidence")
    assert_includes gate.fetch("run"), "release-source/distribution/ExportOptions.mac-app-store.plist"
    assert_includes gate.fetch("run"), "::notice"
    assert_match(/-f release-source\/distribution\/ExportOptions\.mac-app-store\.plist \]\]; then\n\s+echo "build=true" >> "\$GITHUB_OUTPUT"\n\s*else\n/, gate.fetch("run"))
    assert_match(/echo "build=false" >> "\$GITHUB_OUTPUT"\n\s*fi/, gate.fetch("run"))
    assert_equal "steps.candidate.outputs.superseded != 'true'", gate.fetch("if")
    steps[(gate_index + 1)..].each do |step|
      condition = step.fetch("if", "")
      if condition.start_with?("always()")
        refute_includes condition, "mac_target", "#{step['name']} cleans up whether or not the Mac build ran"
        next
      end

      assert_equal "steps.mac_target.outputs.build == 'true'", condition, "#{step['name']} must wait for the Mac target check"
    end
    ios = workflow("testflight.yml").fetch("jobs").fetch("publish-internal").fetch("steps")
    assert_equal "steps.candidate.outputs.superseded != 'true'", ios.find { |step| step["name"] == "Install pinned source Ruby bundle" }.fetch("if"),
                 "the iOS job never waits for the Mac target check"
    refute_match(/steps\.candidate\.outputs\.superseded/, steps[(gate_index + 1)..].map { |step| step.fetch("if", "") }.join("\n"))
  end

  def test_listing_workflows_accept_release_branch
    assert_includes source("testflight.yml"), BRANCH_PATTERN
    %w[stage-app-store-listing.yml submit-app-store-review.yml].each do |name|
      input = dispatch_inputs(name).fetch("release_branch")
      assert_equal false, input.fetch("required"), name
      text = source(name)
      assert_includes text, BRANCH_PATTERN, "#{name} must validate release_branch like testflight.yml"
      assert_match(/--branch "\$\{RELEASE_BRANCH:-main\}"/, text, "#{name} must gate the release branch head, or main")
      assert_match(%r{ref: \$\{\{ steps\.green\.outputs\.sha \}\}}, text, "#{name} must check out the commit proven green")
      assert_match(%r{--listing release-source/distribution/app-store/listing\.json}, text,
                   "#{name} must read the release branch's listing")
    end
    assert_match(%r{--screenshots release-source/distribution/app-store/screenshots}, source("stage-app-store-listing.yml"))
  end

  # The release train: BOTH stages or submits iOS, then the Mac, with the builds TestFlight published from the one
  # commit proven green, found before any App Store Connect secret is in the job.
  def test_listing_workflows_offer_both_platforms_from_one_commit
    %w[stage-app-store-listing.yml submit-app-store-review.yml].each do |name|
      assert_includes dispatch_inputs(name).fetch("platform").fetch("options"), "BOTH", name
      steps = workflow(name).fetch("jobs").values.first.fetch("steps")
      train = steps.index { |step| step["id"] == "train" }
      refute_nil train, "#{name} must find both builds"
      assert_equal "inputs.platform == 'BOTH'", steps[train]["if"]
      assert_match(/scripts\/release-train-builds\.rb .*--sha "\$SOURCE_SHA"/, steps[train]["run"])
      assert_equal "${{ steps.green.outputs.sha }}", steps[train].dig("env", "SOURCE_SHA")
      first_secret = steps.index { |step| step.fetch("env", {}).values.any? { |value| value.to_s.include?("secrets.") } }
      assert_operator train, :<, first_secret, "#{name} must find the builds before any secret is in the job"
    end
    stage = source("stage-app-store-listing.yml")
    assert_match(/passes=\(--dry-run --apply\)/, stage, "BOTH must plan both platforms before it writes either")
    assert_match(/--build-id "\$BUILD_ID"/, stage)
    submit = source("submit-app-store-review.yml")
    assert_match(/"\$CONFIRM" = "submit \$PLATFORM \$VERSION"/, submit, "BOTH confirms with \"submit BOTH <version>\"")
    assert_match(/--build-id "IOS=\$IOS_BUILD_ID" --build-id "MAC_OS=\$MAC_BUILD_ID"/, submit)
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
