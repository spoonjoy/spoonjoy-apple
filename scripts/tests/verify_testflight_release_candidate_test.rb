# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

class VerifyTestFlightReleaseCandidateTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  SCRIPT = ROOT.join("scripts/verify-testflight-release-candidate.rb")
  LEGACY_ANCHOR_SHA = "bad81b49a07c006814315a56e4c98311693a7256"
  SOURCE_SHA = LEGACY_ANCHOR_SHA
  SOURCE_TREE = "b" * 40
  MAIN_SHA = "c" * 40
  RUN_ID = 4_242
  RUN_ATTEMPT = 1
  CORE_JOBS = ["Swift tests", "Native scenario verifier", "App bundle", "Coverage"].freeze
  MODERN_JOBS = ["Native visual evidence", "TestFlight release note"].freeze

  def setup
    @temporary_directory = Pathname.new(Dir.mktmpdir("legacy-testflight-candidate"))
  end

  def teardown
    @temporary_directory.rmtree if @temporary_directory.exist?
  end

  def test_accepts_explicit_legacy_rollback_with_only_original_protected_jobs
    fixture = create_fixture(legacy_source: true)

    result = run_candidate(fixture)

    assert result.success?, result.output
    attestation = JSON.parse(fixture.join("output/testflight-release-candidate.json").read)
    assert_equal "legacyRollback", attestation.fetch("evidenceMode")
    assert_equal LEGACY_ANCHOR_SHA, attestation.fetch("legacyReleaseAnchorSha")
    assert_equal true, attestation.fetch("rollback")
    assert_nil attestation.fetch("releaseNotesArtifactId")
    assert_nil attestation.fetch("visualEvidenceArtifactId")
    assert_equal "Restores the last known-good native build.", attestation.fetch("releaseNotes")
    notes = JSON.parse(Pathname.new(attestation.fetch("releaseNotesPath")).read)
    assert_equal 1, notes.fetch("schemaVersion")
    assert_equal "explicitLegacyRollback", notes.fetch("origin")
    assert_equal attestation.fetch("legacyReleaseAnchorSha"), notes.fetch("legacyReleaseAnchorSha")
    assert_equal SOURCE_SHA, notes.fetch("sourceSha")
    assert_equal SOURCE_TREE, notes.fetch("sourceTree")
    assert_equal RUN_ID, notes.fetch("nativeRunId")
    assert_equal RUN_ATTEMPT, notes.fetch("nativeRunAttempt")
  end

  def test_rejects_legacy_source_without_explicit_notes
    fixture = create_fixture(legacy_source: true)

    result = run_candidate(fixture, rollback_notes: "")

    refute result.success?
    assert_includes result.output, "legacy rollback requires explicit rollback notes"
  end

  def test_rejects_post_boundary_source_that_is_missing_modern_evidence
    fixture = create_fixture(legacy_source: false)

    result = run_candidate(fixture)

    refute result.success?
    assert_includes result.output, "missing required Native job Native visual evidence"
  end

  def test_rejects_partial_modern_evidence_on_a_legacy_source
    fixture = create_fixture(legacy_source: true, jobs: CORE_JOBS + [MODERN_JOBS.first])

    result = run_candidate(fixture)

    refute result.success?
    assert_includes result.output, "legacy rollback cannot use partial modern release evidence"
  end

  def test_rejects_failed_original_job_on_a_legacy_source
    fixture = create_fixture(legacy_source: true)
    jobs = JSON.parse(fixture.join("jobs.json").read)
    jobs.fetch("jobs").first["conclusion"] = "failure"
    write_json(fixture.join("jobs.json"), jobs)

    result = run_candidate(fixture)

    refute result.success?
    assert_includes result.output, "required Native job Swift tests was not successful"
  end

  def test_rejects_ambiguous_original_job_on_a_legacy_source
    fixture = create_fixture(legacy_source: true, jobs: CORE_JOBS + [CORE_JOBS.first])

    result = run_candidate(fixture)

    refute result.success?
    assert_includes result.output, "required Native job Swift tests is ambiguous"
  end

  def test_full_modern_job_set_never_downgrades_to_legacy_mode
    fixture = create_fixture(legacy_source: true, jobs: CORE_JOBS + MODERN_JOBS)

    result = run_candidate(fixture)

    refute result.success?
    assert_includes result.output, "missing release note artifact"
  end

  def test_rejects_legacy_notes_for_current_main
    fixture = create_fixture(legacy_source: true, main_sha: SOURCE_SHA)

    result = run_candidate(fixture, allow_rollback: false, rollback_reason: "")

    refute result.success?
    assert_includes result.output, "rollback notes are only valid for an explicit rollback"
  end

  private

  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
    def success?
      status.success?
    end

    def output
      [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def create_fixture(legacy_source:, jobs: CORE_JOBS, main_sha: MAIN_SHA)
    fixture = @temporary_directory.join("fixture-#{Dir.children(@temporary_directory).length}")
    fixture.mkpath
    fixture.join("checked-out-sha.txt").write("#{SOURCE_SHA}\n")
    fixture.join("checked-out-tree.txt").write("#{SOURCE_TREE}\n")
    fixture.join("is-main-ancestor.txt").write("true\n")
    fixture.join("is-legacy-release-source.txt").write("#{legacy_source}\n")
    write_json(fixture.join("main-ref.json"), "object" => { "sha" => main_sha })
    write_json(
      fixture.join("runs.json"),
      "workflow_runs" => [{
        "id" => RUN_ID,
        "run_number" => 77,
        "run_attempt" => RUN_ATTEMPT,
        "event" => "push",
        "head_branch" => "main",
        "head_sha" => SOURCE_SHA,
        "path" => ".github/workflows/native.yml",
        "status" => "completed",
        "conclusion" => "success",
        "created_at" => "2026-07-15T18:00:00Z",
        "updated_at" => "2026-07-15T18:20:00Z"
      }]
    )
    write_json(
      fixture.join("jobs.json"),
      "jobs" => jobs.map { |name| { "name" => name, "status" => "completed", "conclusion" => "success" } }
    )
    write_json(fixture.join("artifacts.json"), "artifacts" => [])
    fixture
  end

  def run_candidate(
    fixture,
    allow_rollback: true,
    rollback_reason: "Restore pre-evidence known-good build",
    rollback_notes: "Restores the last known-good native build."
  )
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      SCRIPT.to_s,
      "--source-sha", SOURCE_SHA,
      "--repository", "ourostack/spoonjoy-apple",
      "--allow-rollback", allow_rollback.to_s,
      "--rollback-reason", rollback_reason,
      "--rollback-notes", rollback_notes,
      "--output-dir", fixture.join("output").to_s,
      "--fixture-dir", fixture.to_s
    )
    Result.new(stdout: stdout, stderr: stderr, status: status)
  end

  def write_json(path, object)
    path.write(JSON.pretty_generate(object) + "\n")
  end
end
