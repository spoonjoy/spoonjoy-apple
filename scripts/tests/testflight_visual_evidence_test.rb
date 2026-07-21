# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"

class TestFlightVisualEvidenceTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  SCRIPT = ROOT.join("scripts/testflight-visual-evidence.rb")
  CANDIDATE_SCRIPT = ROOT.join("scripts/verify-testflight-release-candidate.rb")
  SOURCE_SHA = "a" * 40
  SOURCE_TREE = "b" * 40
  RUN_ID = 4_242
  RUN_ATTEMPT = 3
  JOB = "native-visual-evidence"
  ROUTES = %w[
    kitchen recipes saved-recipes recipe-detail recipe-editor recipe-covers cook-mode cook-log
    cookbooks cookbook-detail shopping-list shopping-list-empty shopping-list-all-complete
    shopping-list-duplicate shopping-list-conflict shopping-list-offline-queued chefs profile
    profile-graph search search-typed-results search-scoped-recipes search-scoped-cookbooks
    search-scoped-chefs search-scoped-shopping search-no-results capture capture-empty capture-draft
    capture-offline-retry capture-provider-blocked capture-signed-out settings settings-notifications
    settings-signed-out settings-apns-denied settings-apns-not-determined settings-apns-authorized
    settings-apns-unregistered unknown-link
  ].freeze

  def setup
    @temporary_directory = Pathname.new(Dir.mktmpdir("testflight-visual-evidence"))
    @artifact_root = @temporary_directory.join("matrix")
    @sealed_root = @temporary_directory.join("sealed")
    create_valid_matrix
  end

  def teardown
    FileUtils.rm_rf(@temporary_directory)
  end

  def test_seals_and_reverifies_a_complete_attempt_qualified_artifact
    seal = run_tool("seal", *seal_arguments)
    assert seal.success?, seal.output

    manifest_path = @sealed_root.join("visual-evidence-manifest.json")
    manifest = JSON.parse(manifest_path.read)
    assert_equal SOURCE_SHA, manifest.dig("identity", "sourceSha")
    assert_equal SOURCE_TREE, manifest.dig("identity", "sourceTree")
    assert_equal RUN_ID, manifest.dig("identity", "workflowRunId")
    assert_equal RUN_ATTEMPT, manifest.dig("identity", "workflowRunAttempt")
    assert_equal JOB, manifest.dig("identity", "workflowJob")
    assert_equal ROUTES, manifest.dig("matrix", "routes").map { |route| route.fetch("name") }
    assert manifest.fetch("files").all? { |entry| entry.fetch("sha256").match?(/\A[0-9a-f]{64}\z/) }

    verify = run_tool("verify", *verify_arguments)
    assert verify.success?, verify.output
    assert_includes verify.output, Digest::SHA256.file(manifest_path).hexdigest
  end

  def test_rejects_a_partial_route_matrix
    summary_path = matrix_summary_path
    summary = JSON.parse(summary_path.read)
    summary["routes"] = summary.fetch("routes").drop(1)
    summary["selectedRoutes"] = summary.fetch("selectedRoutes").drop(1)
    summary["routeCount"] -= 1
    summary["missingRoutes"] = [ROUTES.first]
    summary["completeRouteSet"] = false
    summary["fullyValidated"] = false
    write_json(summary_path, summary)

    result = run_tool("seal", *seal_arguments)
    refute result.success?
    assert_includes result.output, "full route matrix"
  end

  def test_rejects_blocker_residue_anywhere_in_the_matrix_root
    write_json(@artifact_root.join("apple/release-host-blocker.json"), "blocked" => true)

    result = run_tool("seal", *seal_arguments)
    refute result.success?
    assert_includes result.output, "blocker residue"
  end

  def test_rejects_traversal_from_a_design_review
    review_path = @artifact_root.join("design-review.json")
    review = JSON.parse(review_path.read)
    review.fetch("accessibilityProofArtifacts")[0] = "../outside.json"
    write_json(review_path, review)
    write_json(@temporary_directory.join("outside.json"), "route" => "kitchen")
    refresh_route_artifact_hash(ROUTES.first, "designReview", review_path)

    result = run_tool("seal", *seal_arguments)
    refute result.success?
    assert_includes result.output, "unsafe relative path"
  end

  def test_rejects_a_selected_symlink
    screenshot_path = @artifact_root.join("screenshots/ios-mobile.png")
    target = @temporary_directory.join("outside.png")
    target.binwrite(png_bytes("outside"))
    screenshot_path.delete
    File.symlink(target, screenshot_path)

    result = run_tool("seal", *seal_arguments)
    refute result.success?
    assert_includes result.output, "symlink"
  end

  def test_verify_rejects_hash_drift_and_unallowlisted_files
    seal = run_tool("seal", *seal_arguments)
    assert seal.success?, seal.output

    screenshot = @sealed_root.join("payload/screenshots/ios-mobile.png")
    screenshot.binwrite(png_bytes("tampered"))
    drift = run_tool("verify", *verify_arguments)
    refute drift.success?
    assert_includes drift.output, "SHA-256 mismatch"

    FileUtils.rm_rf(@sealed_root)
    assert run_tool("seal", *seal_arguments).success?
    @sealed_root.join("unexpected.txt").write("not allowlisted\n")
    extra = run_tool("verify", *verify_arguments)
    refute extra.success?
    assert_includes extra.output, "unallowlisted artifact path"
  end

  def test_verify_rejects_files_allowlisted_by_the_manifest_but_unreferenced_by_evidence
    assert run_tool("seal", *seal_arguments).success?
    unreferenced = @sealed_root.join("payload/unreferenced.json")
    write_json(unreferenced, "looks" => "plausible")
    add_or_refresh_sealed_file(unreferenced)

    result = run_tool("verify", *verify_arguments)
    refute result.success?
    assert_includes result.output, "unreferenced allowlisted artifact path"
  end

  def test_verify_rejects_post_upload_blocker_and_summary_forgery_even_with_refreshed_hashes
    assert run_tool("seal", *seal_arguments).success?
    review = @sealed_root.join("payload/design-review.json")
    review_json = JSON.parse(review.read)
    review_json["blocked"] = true
    write_json(review, review_json)
    add_or_refresh_sealed_file(review)

    blocked = run_tool("verify", *verify_arguments)
    refute blocked.success?
    assert_includes blocked.output, "design review contains a blocker"

    FileUtils.rm_rf(@sealed_root)
    assert run_tool("seal", *seal_arguments).success?
    summary = @sealed_root.join("payload/apple/release-route-matrix.json")
    summary_json = JSON.parse(summary.read)
    summary_json["buildBlocked"] = true
    summary_json["buildBlocker"] = { "blocked" => true }
    write_json(summary, summary_json)
    add_or_refresh_sealed_file(summary)

    forged = run_tool("verify", *verify_arguments)
    refute forged.success?
    assert_includes forged.output, "sealed route matrix summary contains a blocker"
  end

  def test_verify_rejects_identity_mismatch
    assert run_tool("seal", *seal_arguments).success?

    result = run_tool(
      "verify",
      *verify_arguments.map { |argument| argument == SOURCE_SHA ? "c" * 40 : argument }
    )
    refute result.success?
    assert_includes result.output, "source SHA mismatch"
  end

  def test_workflows_and_candidate_verifier_enforce_visual_evidence_before_release
    native = ROOT.join(".github/workflows/native.yml").read
    testflight = ROOT.join(".github/workflows/testflight.yml").read
    candidate = ROOT.join("scripts/verify-testflight-release-candidate.rb").read

    %w[
      native-visual-evidence
      Native\ visual\ evidence
      macos-26
      --require-full-matrix
      scripts/testflight-visual-evidence.rb
      artifact-id
      artifact-digest
      manifest-digest
      github.run_attempt
    ].each do |token|
      assert_includes native, token.tr("\\", " ")
    end
    assert_match(/native-visual-evidence:[\s\S]*if: github\.event_name == 'push'[\s\S]*needs:[\s\S]*swift-tests[\s\S]*coverage/, native)
    assert_match(/testflight-release-note:[\s\S]*needs:[\s\S]*native-visual-evidence/, native)
    assert_includes native, "visualEvidence"
    assert_includes testflight, "Verify exact Native release evidence"
    assert_operator testflight.index("Verify exact Native release evidence"), :<,
                    testflight.index("Prepare App Store Connect credentials")
    assert_includes candidate, "Native visual evidence"
    assert_includes candidate, "visualEvidence"
    assert_includes candidate, "testflight-visual-evidence"
    refute_match(/allow_rollback.*visual/i, candidate)
  end

  def test_candidate_reverifies_the_exact_attempt_artifact
    fixture = create_candidate_fixture

    result = run_candidate(fixture)
    assert result.success?, result.output
    attestation = JSON.parse(fixture.join("output/testflight-release-candidate.json").read)
    assert_equal 9_002, attestation.fetch("visualEvidenceArtifactId")
    assert_equal RUN_ATTEMPT, attestation.fetch("nativeRunAttempt")
    assert_equal Digest::SHA256.file(@sealed_root.join("visual-evidence-manifest.json")).hexdigest,
                 attestation.fetch("visualEvidenceManifestSha256")
  end

  def test_candidate_rejects_tampered_visual_payload
    fixture = create_candidate_fixture
    fixture.join("native-visual-evidence/payload/screenshots/ios-mobile.png").binwrite(png_bytes("tampered"))

    result = run_candidate(fixture)
    refute result.success?
    assert_includes result.output, "SHA-256 mismatch"
  end

  def test_candidate_requires_visual_evidence_even_for_a_rollback
    fixture = create_candidate_fixture(main_sha: "c" * 40)
    jobs = JSON.parse(fixture.join("jobs.json").read)
    jobs["jobs"].reject! { |job| job["name"] == "Native visual evidence" }
    write_json(fixture.join("jobs.json"), jobs)

    result = run_candidate(
      fixture,
      allow_rollback: true,
      rollback_reason: "Restore the last exact known-good native revision",
      rollback_notes: "Rollback candidate with fresh human-readable notes."
    )
    refute result.success?
    assert_includes result.output, "missing required Native job Native visual evidence"
  end

  def test_candidate_rejects_an_ambiguous_visual_artifact_name
    fixture = create_candidate_fixture
    artifacts = JSON.parse(fixture.join("artifacts.json").read)
    duplicate = artifacts.fetch("artifacts").last.dup
    duplicate["id"] = 9_999
    artifacts.fetch("artifacts") << duplicate
    write_json(fixture.join("artifacts.json"), artifacts)

    result = run_candidate(fixture)
    refute result.success?
    assert_includes result.output, "visual evidence artifact name is ambiguous"
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

  def run_tool(*arguments)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, SCRIPT.to_s, *arguments)
    Result.new(stdout: stdout, stderr: stderr, status: status)
  end

  def seal_arguments
    [
      "--artifact-root", @artifact_root.to_s,
      "--matrix-manifest", matrix_summary_path.to_s,
      "--output-dir", @sealed_root.to_s,
      "--source-sha", SOURCE_SHA,
      "--source-tree", SOURCE_TREE,
      "--workflow-run-id", RUN_ID.to_s,
      "--workflow-run-attempt", RUN_ATTEMPT.to_s,
      "--workflow-job", JOB
    ]
  end

  def verify_arguments
    [
      "--artifact-dir", @sealed_root.to_s,
      "--source-sha", SOURCE_SHA,
      "--source-tree", SOURCE_TREE,
      "--workflow-run-id", RUN_ID.to_s,
      "--workflow-run-attempt", RUN_ATTEMPT.to_s,
      "--workflow-job", JOB
    ]
  end

  def matrix_summary_path
    @artifact_root.join("apple/release-route-matrix.json")
  end

  def create_valid_matrix
    rows = ROUTES.map { |route| create_route(route) }
    provenance_path = @artifact_root.join("apple/release-screenshot-provenance.json")
    write_json(
      provenance_path,
      "schemaVersion" => 1,
      "source" => { "sha" => SOURCE_SHA, "tree" => SOURCE_TREE },
      "manifestSha256" => "d" * 64
    )
    summary = {
      "ok" => true,
      "fullyValidated" => true,
      "routeCount" => ROUTES.length,
      "expectedRouteCount" => ROUTES.length,
      "expectedRoutes" => ROUTES,
      "selectedRoutes" => ROUTES,
      "completeRouteSet" => true,
      "buildBlocked" => false,
      "buildBlocker" => nil,
      "provenanceVerifiedBefore" => true,
      "provenanceVerifiedAfter" => true,
      "provenanceManifestPath" => provenance_path.to_s,
      "provenanceManifestSha256" => "d" * 64,
      "sourceSha" => SOURCE_SHA,
      "sourceTree" => SOURCE_TREE,
      "routes" => rows,
      "failedRoutes" => [],
      "blockedRoutes" => [],
      "missingDesignReviewRoutes" => [],
      "missingScreenshotRoutes" => [],
      "missingRoutes" => [],
      "duplicateRoutes" => [],
      "unexpectedRoutes" => []
    }
    write_json(matrix_summary_path, summary)
    jsonl = rows.map { |row| JSON.generate(row) }.join("\n") + "\n"
    @artifact_root.join("apple/release-route-matrix.jsonl").write(jsonl)
  end

  def create_candidate_fixture(main_sha: SOURCE_SHA)
    seal = run_tool("seal", *seal_arguments)
    raise seal.output unless seal.success?
    fixture = @temporary_directory.join("candidate")
    fixture.mkpath
    fixture.join("checked-out-sha.txt").write("#{SOURCE_SHA}\n")
    fixture.join("checked-out-tree.txt").write("#{SOURCE_TREE}\n")
    fixture.join("is-main-ancestor.txt").write("true\n")
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
        "created_at" => "2026-07-20T18:00:00Z",
        "updated_at" => "2026-07-20T18:20:00Z"
      }]
    )
    jobs = [
      "Swift tests", "Native scenario verifier", "App bundle", "Coverage",
      "Native visual evidence", "TestFlight release note"
    ].map { |name| { "name" => name, "status" => "completed", "conclusion" => "success" } }
    write_json(fixture.join("jobs.json"), "jobs" => jobs)
    visual_name = "native-visual-evidence-#{SOURCE_SHA}-#{RUN_ID}-#{RUN_ATTEMPT}"
    visual_digest = "sha256:#{"e" * 64}"
    write_json(
      fixture.join("artifacts.json"),
      "artifacts" => [
        { "id" => 9_001, "name" => "testflight-release-notes-#{SOURCE_SHA}", "expired" => false },
        { "id" => 9_002, "name" => visual_name, "digest" => visual_digest, "expired" => false }
      ]
    )
    manifest_digest = Digest::SHA256.file(@sealed_root.join("visual-evidence-manifest.json")).hexdigest
    write_json(
      fixture.join("testflight-release-notes.json"),
      "schemaVersion" => 2,
      "sourceSha" => SOURCE_SHA,
      "sourceTree" => SOURCE_TREE,
      "nativeRunId" => RUN_ID,
      "nativeRunAttempt" => RUN_ATTEMPT,
      "generatedAt" => "2026-07-20T18:18:00Z",
      "notes" => "A precise candidate note with exact visual evidence.",
      "visualEvidence" => {
        "artifactId" => 9_002,
        "artifactName" => visual_name,
        "artifactDigest" => visual_digest,
        "manifestSha256" => manifest_digest,
        "workflowRunId" => RUN_ID,
        "workflowRunAttempt" => RUN_ATTEMPT,
        "workflowJob" => JOB,
        "jobName" => "Native visual evidence"
      }
    )
    FileUtils.cp_r(@sealed_root, fixture.join("native-visual-evidence"))
    fixture
  end

  def run_candidate(
    fixture,
    allow_rollback: false,
    rollback_reason: "",
    rollback_notes: ""
  )
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      CANDIDATE_SCRIPT.to_s,
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

  def create_route(route)
    route_root = route == ROUTES.first ? @artifact_root : @artifact_root.join("screenshot-routes", route)
    screenshot_paths = {
      "iosMobile" => "screenshots/ios-mobile.png",
      "iosAccessibility" => "screenshots/ios-mobile-accessibility.png",
      "iosTablet" => "screenshots/ios-tablet.png",
      "macosDesktop" => "screenshots/macos-desktop.png"
    }
    screenshot_paths.each_value do |relative_path|
      path = route_root.join(relative_path)
      path.dirname.mkpath
      path.binwrite(png_bytes("#{route}:#{relative_path}"))
    end

    proof_paths = %w[
      apple/accessibility-ios.json apple/accessibility-ipad.json apple/accessibility-macos.json
      apple/observed-ios.json apple/observed-ios-ax.json apple/observed-ipad.json apple/observed-macos.json
    ]
    proof_paths.each do |relative_path|
      write_json(route_root.join(relative_path), "route" => route, "proof" => relative_path)
    end

    review = {
      "screenshotRoute" => route,
      "accessibilityProofArtifacts" => proof_paths.first(3),
      "observedAccessibilityEvidenceArtifacts" => proof_paths.drop(3),
      "accessibilityContentSizeScreenshot" => screenshot_paths.fetch("iosAccessibility"),
      "blockers" => [],
      "screenshotArtifacts" => screenshot_paths.transform_values do |relative_path|
        artifact_entry(route_root.join(relative_path), relative_path)
      end
    }
    review_path = route_root.join("design-review.json")
    write_json(review_path, review)

    {
      "name" => route,
      "route" => route,
      "artifactRoot" => route_root.to_s,
      "status" => "pass",
      "blocked" => false,
      "missingDesignReview" => false,
      "designReview" => artifact_entry(review_path, review_path.to_s),
      "designReviewBlocked" => { "path" => route_root.join("design-review-blocked.json").to_s, "exists" => false },
      "iosScreenshot" => artifact_entry(route_root.join(screenshot_paths.fetch("iosMobile")), route_root.join(screenshot_paths.fetch("iosMobile")).to_s),
      "iosAccessibilityScreenshot" => artifact_entry(route_root.join(screenshot_paths.fetch("iosAccessibility")), route_root.join(screenshot_paths.fetch("iosAccessibility")).to_s),
      "iosTabletScreenshot" => artifact_entry(route_root.join(screenshot_paths.fetch("iosTablet")), route_root.join(screenshot_paths.fetch("iosTablet")).to_s),
      "macosScreenshot" => artifact_entry(route_root.join(screenshot_paths.fetch("macosDesktop")), route_root.join(screenshot_paths.fetch("macosDesktop")).to_s)
    }
  end

  def refresh_route_artifact_hash(route, key, path)
    summary = JSON.parse(matrix_summary_path.read)
    row = summary.fetch("routes").find { |candidate| candidate.fetch("name") == route }
    row[key] = artifact_entry(path, path.to_s)
    write_json(matrix_summary_path, summary)
  end

  def add_or_refresh_sealed_file(path)
    manifest_path = @sealed_root.join("visual-evidence-manifest.json")
    manifest = JSON.parse(manifest_path.read)
    relative = path.relative_path_from(@sealed_root).to_s
    entry = {
      "path" => relative,
      "bytes" => path.size,
      "sha256" => Digest::SHA256.file(path).hexdigest
    }
    existing = manifest.fetch("files").index { |candidate| candidate.fetch("path") == relative }
    if existing
      manifest.fetch("files")[existing] = entry
    else
      manifest.fetch("files") << entry
      manifest.fetch("files").sort_by! { |candidate| candidate.fetch("path") }
    end
    write_json(manifest_path, manifest)
  end

  def artifact_entry(path, displayed_path)
    {
      "path" => displayed_path,
      "exists" => path.file?,
      "bytes" => path.file? ? path.size : nil,
      "sha256" => path.file? ? Digest::SHA256.file(path).hexdigest : nil
    }
  end

  def png_bytes(label)
    "\x89PNG\r\n\x1A\n#{label}\n".b
  end

  def write_json(path, object)
    path.dirname.mkpath
    path.write(JSON.pretty_generate(object) + "\n")
  end
end
