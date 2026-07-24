#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "optparse"
require "time"
require_relative "testflight-visual-evidence"

class CandidateVerificationError < StandardError; end

class CommandRunner
  Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

  def capture(*arguments, allowed_statuses: [0])
    stdout, stderr, status = Open3.capture3(*arguments)
    unless allowed_statuses.include?(status.exitstatus)
      detail = [stdout, stderr].reject(&:empty?).join("\n").strip
      raise CandidateVerificationError,
            "command failed (#{arguments.join(" ")}): #{detail.empty? ? "exit #{status.exitstatus}" : detail}"
    end

    Result.new(stdout: stdout, stderr: stderr, status: status.exitstatus)
  end
end

class LiveCandidateEvidence
  def initialize(repository:, output_dir:, runner: CommandRunner.new)
    @repository = repository
    @output_dir = File.expand_path(output_dir)
    @runner = runner
  end

  def checked_out_sha
    @runner.capture("git", "rev-parse", "HEAD").stdout.strip
  end

  def checked_out_tree
    @runner.capture("git", "rev-parse", "HEAD^{tree}").stdout.strip
  end

  def main_ref
    gh_json("repos/#{@repository}/git/ref/heads/main")
  end

  def main_ancestor?(source_sha, main_sha)
    result = @runner.capture(
      "git", "merge-base", "--is-ancestor", source_sha, main_sha,
      allowed_statuses: [0, 1]
    )
    result.status.zero?
  end

  def legacy_release_source?(source_sha, last_legacy_main_sha)
    main_ancestor?(source_sha, last_legacy_main_sha)
  end

  def workflow_runs(source_sha)
    gh_json(
      "repos/#{@repository}/actions/workflows/native.yml/runs",
      "-f", "head_sha=#{source_sha}",
      "-f", "branch=main",
      "-f", "per_page=100"
    )
  end

  def jobs(run_id, run_attempt)
    gh_json(
      "repos/#{@repository}/actions/runs/#{run_id}/attempts/#{run_attempt}/jobs",
      "-f", "per_page=100"
    )
  end

  def artifacts(run_id)
    gh_json("repos/#{@repository}/actions/runs/#{run_id}/artifacts", "-f", "per_page=100")
  end

  def release_notes_path(run_id, artifact_name)
    destination = download_artifact(run_id, artifact_name)
    File.join(destination, "testflight-release-notes.json")
  end

  def visual_evidence_path(run_id, artifact_name)
    download_artifact(run_id, artifact_name)
  end

  private

  def download_artifact(run_id, artifact_name)
    destination = File.join(@output_dir, artifact_name)
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    @runner.capture(
      "gh", "run", "download", run_id.to_s,
      "--repo", @repository,
      "--name", artifact_name,
      "--dir", destination
    )
    destination
  end

  def gh_json(endpoint, *fields)
    result = @runner.capture("gh", "api", "--method", "GET", endpoint, *fields)
    JSON.parse(result.stdout)
  rescue JSON::ParserError => error
    raise CandidateVerificationError, "GitHub returned invalid JSON for #{endpoint}: #{error.message}"
  end
end

class FixtureCandidateEvidence
  def initialize(fixture_dir:)
    @fixture_dir = fixture_dir
  end

  def checked_out_sha
    read("checked-out-sha.txt").strip
  end

  def checked_out_tree
    read("checked-out-tree.txt").strip
  end

  def main_ref
    read_json("main-ref.json")
  end

  def main_ancestor?(_source_sha, _main_sha)
    read("is-main-ancestor.txt").strip == "true"
  end

  def legacy_release_source?(_source_sha, _last_legacy_main_sha)
    path = File.join(@fixture_dir, "is-legacy-release-source.txt")
    return false unless File.file?(path)

    File.read(path).strip == "true"
  end

  def workflow_runs(_source_sha)
    read_json("runs.json")
  end

  def jobs(_run_id, _run_attempt)
    read_json("jobs.json")
  end

  def artifacts(_run_id)
    read_json("artifacts.json")
  end

  def release_notes_path(_run_id, _artifact_name)
    File.join(@fixture_dir, "testflight-release-notes.json")
  end

  def visual_evidence_path(_run_id, _artifact_name)
    File.join(@fixture_dir, "native-visual-evidence")
  end

  private

  def read(name)
    File.read(File.join(@fixture_dir, name))
  rescue Errno::ENOENT
    raise CandidateVerificationError, "missing fixture evidence #{name}"
  end

  def read_json(name)
    JSON.parse(read(name))
  rescue JSON::ParserError => error
    raise CandidateVerificationError, "invalid fixture JSON #{name}: #{error.message}"
  end
end

class TestFlightReleaseCandidateVerifier
  SHA_PATTERN = /\A[0-9a-f]{40}\z/
  REPOSITORY_PATTERN = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}
  REQUIRED_NATIVE_JOBS = [
    "Swift tests",
    "Native scenario verifier",
    "App bundle",
    "Coverage"
  ].freeze
  VISUAL_EVIDENCE_JOB = "Native visual evidence"
  VISUAL_EVIDENCE_JOB_KEY = "native-visual-evidence"
  RELEASE_NOTE_JOB = "TestFlight release note"
  NATIVE_WORKFLOW_PATH = ".github/workflows/native.yml"
  RELEASE_NOTES_FILENAME = "testflight-release-notes.json"
  RELEASE_NOTES_SCHEMA_VERSION = 2
  PUBLISH_RELEASE_NOTES_SCHEMA_VERSION = 1
  LAST_LEGACY_RELEASE_MAIN_SHA = "bad81b49a07c006814315a56e4c98311693a7256"
  MAX_RELEASE_NOTES_LENGTH = 4_000
  TIMESTAMP_TOLERANCE_SECONDS = 300

  def initialize(
    source_sha:,
    repository:,
    allow_rollback:,
    rollback_reason:,
    rollback_notes:,
    output_dir:,
    evidence:,
    github_output: nil
  )
    @source_sha = source_sha
    @repository = repository
    @allow_rollback = allow_rollback
    @rollback_reason = rollback_reason.strip
    @rollback_notes = rollback_notes.strip
    @output_dir = File.expand_path(output_dir)
    @evidence = evidence
    @github_output = github_output
  end

  def verify
    validate_inputs
    source_tree = validate_checkout
    main_sha = validate_main_membership
    rollback = validate_release_mode(main_sha)
    run = select_native_run
    jobs = native_jobs(run.fetch("id"), run.fetch("run_attempt"))
    legacy_rollback = select_legacy_rollback_mode(rollback, jobs)
    if legacy_rollback
      validate_required_jobs(jobs, REQUIRED_NATIVE_JOBS)
      artifact = nil
      visual = nil
      release_notes_path, release_payload, release_notes = create_explicit_legacy_rollback_notes(run, source_tree)
    else
      validate_required_jobs(jobs, REQUIRED_NATIVE_JOBS + [VISUAL_EVIDENCE_JOB, RELEASE_NOTE_JOB])
      artifact, release_notes_path, release_payload, release_notes = load_native_release_notes(run, source_tree)
      visual = validate_visual_evidence(release_payload, run, source_tree)
      if rollback && !@rollback_notes.empty?
        release_notes_path, release_notes = create_explicit_rollback_notes(release_payload)
      end
    end

    attestation = {
      "schemaVersion" => 1,
      "sourceSha" => @source_sha,
      "mainSha" => main_sha,
      "rollback" => rollback,
      "rollbackReason" => rollback ? @rollback_reason : nil,
      "evidenceMode" => legacy_rollback ? "legacyRollback" : "nativeArtifacts",
      "legacyReleaseAnchorSha" => legacy_rollback ? LAST_LEGACY_RELEASE_MAIN_SHA : nil,
      "nativeRunId" => run.fetch("id"),
      "nativeRunAttempt" => run.fetch("run_attempt"),
      "releaseNotesArtifactId" => artifact&.fetch("id"),
      "releaseNotesArtifact" => artifact&.fetch("name"),
      "releaseNotesPath" => release_notes_path,
      "releaseNotes" => release_notes,
      "visualEvidenceArtifactId" => visual&.fetch("artifactId"),
      "visualEvidenceArtifact" => visual&.fetch("artifactName"),
      "visualEvidenceArtifactDigest" => visual&.fetch("artifactDigest"),
      "visualEvidenceManifestSha256" => visual&.fetch("manifestSha256"),
      "visualEvidencePath" => visual&.fetch("artifactPath")
    }

    FileUtils.mkdir_p(@output_dir)
    attestation_path = File.join(@output_dir, "testflight-release-candidate.json")
    File.write(attestation_path, JSON.pretty_generate(attestation) + "\n")
    outputs = {
      "source_sha" => @source_sha,
      "native_run_id" => run.fetch("id"),
      "native_run_attempt" => run.fetch("run_attempt"),
      "release_notes_path" => release_notes_path,
      "candidate_attestation_path" => attestation_path
    }
    if visual
      outputs["visual_evidence_path"] = visual.fetch("artifactPath")
      outputs["visual_evidence_manifest_sha256"] = visual.fetch("manifestSha256")
    end
    write_github_output(outputs)
    attestation
  end

  private

  def validate_inputs
    fail_with("source SHA must be exactly 40 lowercase hexadecimal characters") unless @source_sha.match?(SHA_PATTERN)
    fail_with("repository must be an owner/name slug") unless @repository.match?(REPOSITORY_PATTERN)
  end

  def validate_checkout
    checked_out_sha = @evidence.checked_out_sha
    fail_with("checked-out SHA does not match selected source SHA") unless checked_out_sha == @source_sha
    checked_out_tree = @evidence.checked_out_tree
    fail_with("checked-out source tree is not an exact Git tree SHA") unless checked_out_tree.match?(SHA_PATTERN)
    checked_out_tree
  end

  def validate_main_membership
    main_sha = @evidence.main_ref.dig("object", "sha")
    fail_with("GitHub main ref did not contain an exact SHA") unless main_sha.is_a?(String) && main_sha.match?(SHA_PATTERN)
    fail_with("selected SHA is not an ancestor of main") unless @evidence.main_ancestor?(@source_sha, main_sha)
    main_sha
  end

  def validate_release_mode(main_sha)
    rollback = @source_sha != main_sha
    unless rollback
      fail_with("rollback notes are only valid for an explicit rollback") unless @rollback_notes.empty?
      return false
    end

    fail_with("selected SHA is not current main; set allow_rollback for an explicit rollback") unless @allow_rollback
    fail_with("rollback reason is required for an older main commit") if @rollback_reason.empty?
    true
  end

  def select_native_run
    runs = Array(@evidence.workflow_runs(@source_sha)["workflow_runs"])
    exact_runs = runs.select do |run|
      run["head_sha"] == @source_sha &&
        run["head_branch"] == "main" &&
        run["event"] == "push" &&
        run["path"] == NATIVE_WORKFLOW_PATH
    end
    fail_with("no exact Native push run exists for selected main SHA") if exact_runs.empty?

    latest = exact_runs.max_by do |run|
      [integer_value(run, "run_number"), integer_value(run, "run_attempt"), integer_value(run, "id")]
    end
    unless latest["status"] == "completed" && latest["conclusion"] == "success"
      fail_with("latest exact Native push run #{latest.fetch("id")} was not successful")
    end
    latest
  end

  def native_jobs(run_id, run_attempt)
    Array(@evidence.jobs(run_id, run_attempt)["jobs"])
  end

  def select_legacy_rollback_mode(rollback, jobs)
    return false unless rollback
    return false unless @evidence.legacy_release_source?(@source_sha, LAST_LEGACY_RELEASE_MAIN_SHA)

    modern_names = jobs.map { |job| job["name"] }
                       .select { |name| [VISUAL_EVIDENCE_JOB, RELEASE_NOTE_JOB].include?(name) }
                       .uniq
    fail_with("legacy rollback cannot use partial modern release evidence") if modern_names.length == 1
    return false if modern_names.length == 2

    fail_with("legacy rollback requires explicit rollback notes") if @rollback_notes.empty?
    validate_notes_text(@rollback_notes)
    true
  end

  def validate_required_jobs(jobs, required_jobs)
    required_jobs.each do |required_name|
      matching = jobs.select { |job| job["name"] == required_name }
      fail_with("missing required Native job #{required_name}") if matching.empty?
      fail_with("required Native job #{required_name} is ambiguous") unless matching.length == 1

      job = matching.first
      unless job["status"] == "completed" && job["conclusion"] == "success"
        fail_with("required Native job #{required_name} was not successful")
      end
    end
  end

  def load_native_release_notes(run, source_tree)
    artifact = select_release_note_artifact(run)
    release_notes_path = @evidence.release_notes_path(run.fetch("id"), artifact.fetch("name"))
    payload, release_notes = validate_release_notes(release_notes_path, run, source_tree)
    [artifact, release_notes_path, payload, release_notes]
  end

  def create_explicit_rollback_notes(release_payload)
    validate_notes_text(@rollback_notes)
    artifact_name = "testflight-release-notes-#{@source_sha}-#{release_payload.fetch("nativeRunId")}-#{release_payload.fetch("nativeRunAttempt")}"
    directory = File.join(@output_dir, "explicit-rollback-notes", artifact_name)
    FileUtils.mkdir_p(directory)
    release_notes_path = File.join(directory, RELEASE_NOTES_FILENAME)
    payload = release_payload.merge("notes" => @rollback_notes, "origin" => "explicitRollback")
    File.write(release_notes_path, JSON.pretty_generate(payload) + "\n")
    [release_notes_path, @rollback_notes]
  end

  def create_explicit_legacy_rollback_notes(run, source_tree)
    artifact_name = "testflight-release-notes-#{@source_sha}-#{run.fetch("id")}-#{run.fetch("run_attempt")}"
    directory = File.join(@output_dir, "explicit-legacy-rollback-notes", artifact_name)
    FileUtils.mkdir_p(directory)
    release_notes_path = File.join(directory, RELEASE_NOTES_FILENAME)
    payload = {
      "schemaVersion" => PUBLISH_RELEASE_NOTES_SCHEMA_VERSION,
      "sourceSha" => @source_sha,
      "sourceTree" => source_tree,
      "nativeRunId" => run.fetch("id"),
      "nativeRunAttempt" => run.fetch("run_attempt"),
      "generatedAt" => Time.now.utc.iso8601,
      "notes" => @rollback_notes,
      "origin" => "explicitLegacyRollback",
      "legacyReleaseAnchorSha" => LAST_LEGACY_RELEASE_MAIN_SHA
    }
    File.write(release_notes_path, JSON.pretty_generate(payload) + "\n")
    [release_notes_path, payload, @rollback_notes]
  end

  def select_release_note_artifact(run)
    run_id = run.fetch("id")
    expected_name = "testflight-release-notes-#{@source_sha}-#{run_id}-#{run.fetch("run_attempt")}"
    artifacts = Array(@evidence.artifacts(run_id)["artifacts"])
    matching = artifacts.select { |artifact| artifact["name"] == expected_name }
    fail_with("missing release note artifact #{expected_name}") if matching.empty?
    fail_with("release note artifact #{expected_name} is ambiguous") unless matching.length == 1

    artifact = matching.first
    fail_with("release note artifact is expired") if artifact["expired"] == true
    integer_value(artifact, "id")
    artifact
  end

  def validate_release_notes(path, run, source_tree)
    fail_with("missing release note artifact payload #{RELEASE_NOTES_FILENAME}") unless File.file?(path)
    payload = JSON.parse(File.read(path))
    fail_with("release note schema version is unsupported") unless payload["schemaVersion"] == RELEASE_NOTES_SCHEMA_VERSION
    fail_with("release note source SHA does not match selected source SHA") unless payload["sourceSha"] == @source_sha
    fail_with("release note source tree does not match selected source tree") unless payload["sourceTree"] == source_tree
    fail_with("release note Native run ID does not match selected run") unless payload["nativeRunId"] == run["id"]
    unless payload["nativeRunAttempt"] == run["run_attempt"]
      fail_with("release note Native run attempt does not match selected run")
    end

    generated_at = parse_time(payload["generatedAt"], "release note generatedAt")
    run_created_at = parse_time(run["created_at"], "Native run created_at")
    run_updated_at = parse_time(run["updated_at"], "Native run updated_at")
    earliest = run_created_at - TIMESTAMP_TOLERANCE_SECONDS
    latest = run_updated_at + TIMESTAMP_TOLERANCE_SECONDS
    fail_with("release note timestamp is outside the selected Native run") unless generated_at.between?(earliest, latest)

    notes = payload["notes"]
    validate_notes_text(notes)
    [payload, notes.strip]
  rescue JSON::ParserError => error
    raise CandidateVerificationError, "release note artifact payload is invalid JSON: #{error.message}"
  end

  def validate_visual_evidence(release_payload, run, source_tree)
    visual = release_payload["visualEvidence"]
    fail_with("release note visualEvidence must be an object") unless visual.is_a?(Hash)
    artifact_id = integer_value(visual, "artifactId")
    expected_name = "native-visual-evidence-#{@source_sha}-#{run.fetch("id")}-#{run.fetch("run_attempt")}"
    fail_with("visual evidence artifact name does not match the exact run attempt") unless visual["artifactName"] == expected_name
    artifact_digest = visual["artifactDigest"]
    unless artifact_digest.is_a?(String) && artifact_digest.match?(/\Asha256:[0-9a-f]{64}\z/)
      fail_with("visual evidence artifact digest is not SHA-256")
    end
    manifest_digest = visual["manifestSha256"]
    unless manifest_digest.is_a?(String) && manifest_digest.match?(/\A[0-9a-f]{64}\z/)
      fail_with("visual evidence manifest digest is not SHA-256")
    end
    fail_with("visual evidence run ID does not match selected run") unless visual["workflowRunId"] == run["id"]
    unless visual["workflowRunAttempt"] == run["run_attempt"]
      fail_with("visual evidence run attempt does not match selected run")
    end
    fail_with("visual evidence workflow job key mismatch") unless visual["workflowJob"] == VISUAL_EVIDENCE_JOB_KEY
    fail_with("visual evidence job name mismatch") unless visual["jobName"] == VISUAL_EVIDENCE_JOB

    artifacts = Array(@evidence.artifacts(run.fetch("id"))["artifacts"])
    matching_names = artifacts.select { |candidate| candidate["name"] == expected_name }
    fail_with("missing visual evidence artifact #{expected_name}") if matching_names.empty?
    fail_with("visual evidence artifact name is ambiguous") unless matching_names.length == 1
    matching = artifacts.select { |candidate| candidate["id"] == artifact_id }
    fail_with("missing visual evidence artifact ID #{artifact_id}") if matching.empty?
    fail_with("visual evidence artifact ID #{artifact_id} is ambiguous") unless matching.length == 1
    artifact = matching.first
    fail_with("visual evidence artifact name mismatch") unless artifact["name"] == expected_name
    fail_with("visual evidence artifact digest mismatch") unless artifact["digest"] == artifact_digest
    fail_with("visual evidence artifact is expired") if artifact["expired"] == true

    artifact_path = @evidence.visual_evidence_path(run.fetch("id"), expected_name)
    identity = {
      "sourceSha" => @source_sha,
      "sourceTree" => source_tree,
      "workflowRunId" => run.fetch("id"),
      "workflowRunAttempt" => run.fetch("run_attempt"),
      "workflowJob" => VISUAL_EVIDENCE_JOB_KEY
    }
    verification = TestFlightVisualEvidence::Verifier.new(
      artifact_dir: artifact_path,
      expected_identity: identity,
      expected_manifest_sha256: manifest_digest
    ).verify
    {
      "artifactId" => artifact_id,
      "artifactName" => expected_name,
      "artifactDigest" => artifact_digest,
      "manifestSha256" => verification.fetch("manifestSha256"),
      "artifactPath" => artifact_path
    }
  rescue TestFlightVisualEvidence::Error => error
    raise CandidateVerificationError, "visual evidence revalidation failed: #{error.message}"
  end

  def validate_notes_text(notes)
    fail_with("release notes must be a non-empty string") unless notes.is_a?(String) && !notes.strip.empty?
    fail_with("release notes exceed #{MAX_RELEASE_NOTES_LENGTH} characters") if notes.length > MAX_RELEASE_NOTES_LENGTH
    fail_with("release notes contain a null byte") if notes.include?("\0")
  end

  def parse_time(value, label)
    fail_with("#{label} is missing") unless value.is_a?(String)
    Time.iso8601(value)
  rescue ArgumentError
    raise CandidateVerificationError, "#{label} is not ISO 8601"
  end

  def integer_value(object, key)
    value = object[key]
    fail_with("#{key} must be an integer") unless value.is_a?(Integer)
    value
  end

  def write_github_output(values)
    return if @github_output.nil? || @github_output.empty?

    File.open(@github_output, "a") do |file|
      values.each do |key, value|
        string = value.to_s
        fail_with("GitHub output #{key} contains a newline") if string.include?("\n") || string.include?("\r")
        file.puts("#{key}=#{string}")
      end
    end
  end

  def fail_with(message)
    raise CandidateVerificationError, message
  end
end

begin
  options = {
    allow_rollback: false,
    rollback_reason: "",
    rollback_notes: "",
    output_dir: "artifacts/apple/ci-testflight/release-candidate",
    github_output: ENV["GITHUB_OUTPUT"]
  }
  OptionParser.new do |parser|
    parser.banner = "Usage: verify-testflight-release-candidate.rb [options]"
    parser.on("--source-sha SHA") { |value| options[:source_sha] = value }
    parser.on("--repository OWNER/NAME") { |value| options[:repository] = value }
    parser.on("--allow-rollback BOOLEAN") do |value|
      unless %w[true false].include?(value)
        raise OptionParser::InvalidArgument, "allow-rollback must be true or false"
      end
      options[:allow_rollback] = value == "true"
    end
    parser.on("--rollback-reason REASON") { |value| options[:rollback_reason] = value }
    parser.on("--rollback-notes NOTES") { |value| options[:rollback_notes] = value }
    parser.on("--output-dir PATH") { |value| options[:output_dir] = value }
    parser.on("--github-output PATH") { |value| options[:github_output] = value }
    parser.on("--fixture-dir PATH") { |value| options[:fixture_dir] = value }
  end.parse!

  %i[source_sha repository].each do |key|
    raise CandidateVerificationError, "missing --#{key.to_s.tr("_", "-")}" if options[key].nil? || options[key].empty?
  end

  evidence = if options[:fixture_dir]
               FixtureCandidateEvidence.new(fixture_dir: options[:fixture_dir])
             else
               LiveCandidateEvidence.new(repository: options[:repository], output_dir: options[:output_dir])
             end
  verifier = TestFlightReleaseCandidateVerifier.new(
    source_sha: options[:source_sha],
    repository: options[:repository],
    allow_rollback: options[:allow_rollback],
    rollback_reason: options[:rollback_reason],
    rollback_notes: options[:rollback_notes],
    output_dir: options[:output_dir],
    evidence: evidence,
    github_output: options[:github_output]
  )
  attestation = verifier.verify
  puts "Verified TestFlight release candidate #{attestation.fetch("sourceSha")} from Native run #{attestation.fetch("nativeRunId")}."
rescue CandidateVerificationError, OptionParser::ParseError, Errno::ENOENT => error
  warn "verify-testflight-release-candidate failed: #{error.message}"
  exit 1
end
