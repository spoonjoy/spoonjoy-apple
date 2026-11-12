# frozen_string_literal: true

# Run: ruby scripts/test/siri_journey_isolation_test.rb
# AppIntentsTesting loads only on a simulator runtime of its Xcode's own version, and when it fails, dyld fails the
# whole test bundle (Journeys run 43054178295). Only SpoonjoySiriJourneys, built from Journeys/Siri in a job that
# picks a matching Xcode, may import it.
require "minitest/autorun"

class SiriJourneyIsolationTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SIRI_DIR = "Apps/Spoonjoy/Journeys/Siri/"
  # Any form of import: attributes (@testable, @_implementationOnly), access levels and kind-scoped imports.
  IMPORT = /^\s*(@\w+\s+)*((public|package|internal|fileprivate|private)\s+)?import\s+((typealias|struct|class|enum|protocol|let|var|func)\s+)?AppIntentsTesting\b/

  def siri_job
    workflow = File.read(File.join(ROOT, ".github/workflows/journeys.yml"))
    job = workflow[/^  siri-journeys:\n.*?(?=^  [a-z-]+:\n|\z)/m]
    refute_nil job, "journeys.yml has no siri-journeys job"
    job
  end

  def test_the_import_pattern_catches_every_form
    ["import AppIntentsTesting", "@testable import AppIntentsTesting", "@_implementationOnly import AppIntentsTesting",
     "public import AppIntentsTesting", "import struct AppIntentsTesting.AnyAppEntity"].each do |line|
      assert_match IMPORT, line
    end
    refute_match IMPORT, "import AppIntents"
  end

  # Sources and Tests count too: the Swift tests job runs on another Xcode, where the import would break a required check.
  def test_only_the_siri_journeys_import_app_intents_testing
    importers = Dir.glob(File.join(ROOT, "{Apps,Sources,Tests}/**/*.swift")).select { |path| File.read(path).match?(IMPORT) }
    outside = importers.map { |path| path.delete_prefix("#{ROOT}/") }.reject { |path| path.start_with?(SIRI_DIR) }
    assert_empty outside, "only #{SIRI_DIR} may import AppIntentsTesting"
    refute_empty importers, "the Siri journey should import AppIntentsTesting"
  end

  # Two rules live elsewhere: scripts/check-xcode-project-contract.rb checks that only SpoonjoySiriJourneys compiles
  # Journeys/Siri, and TestFlightAutomationContractTests that the job outlasts its steps' time limits.

  # Built with CODE_SIGNING_ALLOWED=NO, the test runner stays the stock xctrunner signed by Apple, and AppIntentsServices
  # refuses every call from it (AppIntentsServicesSecurityErrorDomain 803, "Unable to run internal tests on a Customer
  # build", Journeys runs 43082111564 and 43087839715). Signed ad hoc, as ouro-ui-apple's X-ray probe is, the calls run.
  def test_the_siri_journey_job_signs_ad_hoc
    job = siri_job
    build = job[/xcodebuild build-for-testing.*?2>&1/m]
    refute_nil build, "the Siri journey job has no build-for-testing step"
    assert_includes build, "CODE_SIGN_IDENTITY=-"
    refute_includes build, "CODE_SIGNING_ALLOWED=NO"
  end

  # Installed only by xcodebuild's UI test run, the app was "not present" to AppIntentsServices
  # (AppIntentsServicesMetadataErrorDomain 400, Journeys run 43094337579). ouro-ui-apple's X-ray probe installs it with
  # simctl and launches it once first, and its calls return.
  def test_the_siri_journey_job_installs_and_first_launches_the_app_before_the_run
    job = siri_job
    install = job.index("xcrun simctl install")
    launch = job.index("xcrun simctl launch")
    run = job.index("xcodebuild test-without-building")
    refute_nil install, "the Siri journey job never installs the app with simctl"
    refute_nil launch, "the Siri journey job never launches the app before the run"
    assert_operator install, :<, launch
    assert_operator launch, :<, run
  end

  # The kitchen showed the journey's recipe, yet Siri's recipe query answered with none (Journeys run 43109137338).
  # The query reads only what the app's sync stored, so the job keeps the app's own log (subsystem app.spoonjoy,
  # where sync records each page it applies) and scans it for passwords before it can be uploaded.
  def test_the_siri_journey_job_keeps_the_apps_log_after_the_run
    job = siri_job
    run = job.index("xcodebuild test-without-building")
    capture = job.index(%(--predicate 'subsystem == "app.spoonjoy"'))
    scan = job.index("journey-qa-accounts.sh scan")
    refute_nil capture, "the Siri journey job never keeps the app's log"
    assert_operator run, :<, capture
    assert_operator capture, :<, scan
    assert_includes job[scan..], %("$RUNNER_TEMP/siri/app.log")
    assert_includes job[job.index("actions/upload-artifact")..], "/siri/app.log"
  end

  # spoonjoy has 5 macOS slots. Outside the lanes, dispatch 43113155646 took one ahead of #296's required jobs, so the
  # Siri job queues in lane c with the other optional xcode-27 jobs, and gets its own group in the merge queue.
  def test_the_siri_journey_job_queues_in_macos_lane_c
    job = siri_job
    concurrency = job[/^    concurrency:\n.*?(?=^    [a-z-]+:)/m]
    refute_nil concurrency, "the Siri journey job has no concurrency group"
    assert_includes concurrency, "|| 'spoonjoy-macos-lane-c' }}"
    assert_includes concurrency, "format('journeys-siri-journeys-{0}-{1}-{2}', github.run_id, github.run_attempt, strategy.job-index)"
    assert_includes concurrency, "queue: max"
  end

  # After install and a first launch, App Intents still sometimes answered the first call with metadata error 400,
  # "app.spoonjoy is not present" (run 43120179185, issue #301): the system registers the app's intents on its own
  # time. The journey waits for that registration, bounded, before its first Siri step, and any other error fails.
  def test_the_siri_journey_waits_for_app_intents_to_know_the_app
    intents = File.read(File.join(ROOT, "Apps/Spoonjoy/Journeys/Siri/Support/JourneyIntents.swift"))
    wait = intents[/func waitUntilRegistered\(.*?\n    }\n/m]
    refute_nil wait, "JourneyIntents has no waitUntilRegistered"
    assert_includes wait, %(error.domain == "AppIntentsServicesMetadataErrorDomain")
    assert_includes wait, "error.code == 400"
    assert_includes wait, "throw error"
    assert_includes wait, "guard waited < seconds else {"
    journey = File.read(File.join(ROOT, "Apps/Spoonjoy/Journeys/Siri/SiriJourney.swift"))
    registered = journey.index("try await siri.waitUntilRegistered()")
    refute_nil registered, "the Siri journey never waits for App Intents to know the app"
    assert_operator registered, :<, journey.index("siri.recipe(titled:")
  end

  def test_the_siri_journey_has_a_target_and_a_job_of_its_own
    generator = File.read(File.join(ROOT, "scripts/generate-xcode-project.rb"))
    assert_includes generator, %(SIRI_JOURNEYS_SWIFT = swift_sources_under("Apps/Spoonjoy/Journeys/Siri"))
    assert_includes generator, "- SIRI_JOURNEYS_SWIFT).freeze"
    workflow = File.read(File.join(ROOT, ".github/workflows/journeys.yml"))
    assert_includes workflow, "-only-testing:SpoonjoySiriJourneys"
    assert_includes workflow, "python3 -I .github/scripts/pick-matching-xcode.py"
  end
end
