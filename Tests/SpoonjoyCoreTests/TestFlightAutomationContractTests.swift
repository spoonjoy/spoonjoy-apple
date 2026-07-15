import Foundation
import Testing

@Suite("TestFlight release containment contract")
struct TestFlightAutomationContractTests {
    private let currentSHA = String(repeating: "a", count: 40)
    private let rollbackSHA = String(repeating: "b", count: 40)

    @Test("TestFlight is a trusted-main exact-SHA release-candidate dispatch")
    func testFlightIsAnExactSHAReleaseCandidateDispatch() throws {
        let workflow = try readTestFlightAutomationRepoFile(".github/workflows/testflight.yml")

        expectTestFlightAutomationContent(
            workflow,
            in: ".github/workflows/testflight.yml",
            contains: [
                "name: TestFlight",
                "workflow_dispatch:",
                "source_sha:",
                "required: true",
                "allow_rollback:",
                "rollback_reason:",
                "rollback_notes:",
                "github.ref == 'refs/heads/main'",
                "environment: internal-testflight",
                "actions: read",
                "group: spoonjoy-testflight-internal",
                "cancel-in-progress: false",
                "name: Check out trusted release controls",
                "ref: ${{ github.sha }}",
                "name: Check out selected source revision",
                "ref: ${{ inputs.source_sha }}",
                "path: release-source",
                "fetch-depth: 0",
                "persist-credentials: false",
                "working-directory: release-source",
                "../scripts/verify-testflight-release-candidate.rb",
                "SOURCE_SHA: ${{ inputs.source_sha }}",
                "--source-sha \"$SOURCE_SHA\"",
                "SPOONJOY_TESTFLIGHT_SOURCE_ROOT: ${{ github.workspace }}/release-source",
                "ROLLBACK_NOTES: ${{ inputs.rollback_notes }}",
                "--rollback-notes \"$ROLLBACK_NOTES\"",
                "name: Upload verified candidate note",
                "actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020",
                "node-version: 22.17.1",
                "EXPECTED_APPLE_DISTRIBUTION_KIT_DIST_SHA256: 9f64507b03a5dc76a6ebc52f88cddf71f9448a8e532e4758951d2d31309d5a45",
                "actual_dist_sha256",
                "apple-distribution-kit dist checksum mismatch",
                "SPOONJOY_TESTFLIGHT_SOURCE_SHA",
                "SPOONJOY_TESTFLIGHT_RELEASE_NOTES_PATH",
                "../scripts/ci-publish-testflight.sh"
            ],
            forbids: [
                "workflow_run:",
                "github.event.workflow_run",
                "appStoreVersionSubmissions",
                "appStoreReviewSubmissions",
                "betaAppReviewSubmissions"
            ]
        )
    }

    @Test("Native creates a SHA-keyed release note only after every required check")
    func nativeCreatesSHAKeyedReleaseNoteAfterRequiredChecks() throws {
        let workflow = try readTestFlightAutomationRepoFile(".github/workflows/native.yml")

        expectTestFlightAutomationContent(
            workflow,
            in: ".github/workflows/native.yml",
            contains: [
                "testflight-release-note:",
                "name: TestFlight release note",
                "swift-tests",
                "native-scenario-verifier",
                "app-bundle",
                "coverage",
                "github.event_name == 'push'",
                "github.ref == 'refs/heads/main'",
                "testflight-release-notes-${{ github.sha }}",
                "testflight-release-notes.json",
                "sourceSha",
                "nativeRunId",
                "nativeRunAttempt",
                "generatedAt",
                "retention-days: 90"
            ]
        )
    }

    @Test("Every external workflow action and distribution toolkit revision is immutable")
    func workflowDependenciesAreImmutable() throws {
        let workflowPaths = [
            ".github/workflows/native.yml",
            ".github/workflows/testflight.yml"
        ]
        let actionPattern = /uses:\s+[^\s@]+@([^\s#]+)/

        for path in workflowPaths {
            let workflow = try readTestFlightAutomationRepoFile(path)
            let revisions = workflow.matches(of: actionPattern).map { String($0.1) }
            #expect(!revisions.isEmpty, "\(path) must use at least one external action")
            #expect(
                revisions.allSatisfy { $0.wholeMatch(of: /[0-9a-f]{40}/) != nil },
                "\(path) contains mutable action revision(s): \(revisions)"
            )
        }

        let testFlightWorkflow = try readTestFlightAutomationRepoFile(".github/workflows/testflight.yml")
        let toolkitRefPattern = /repository:\s+ourostack\/apple-distribution-kit[\s\S]*?ref:\s+([0-9a-f]{40})/
        #expect(testFlightWorkflow.firstMatch(of: toolkitRefPattern) != nil)
    }

    @Test("Artifact uploads use the audited Node 24 action revision")
    func artifactUploadsUseAuditedNode24Revision() throws {
        let expectedRevision = "b7c566a772e6b6bfb58ed0dc250532a479d7789f"
        let uploadPattern = /actions\/upload-artifact@([0-9a-f]{40})/
        let workflowPaths = [
            ".github/workflows/native.yml",
            ".github/workflows/testflight.yml"
        ]

        for path in workflowPaths {
            let workflow = try readTestFlightAutomationRepoFile(path)
            let revisions = workflow.matches(of: uploadPattern).map { String($0.1) }
            #expect(!revisions.isEmpty, "\(path) must upload its release evidence")
            #expect(
                revisions.allSatisfy { $0 == expectedRevision },
                "\(path) must use the audited Node 24 upload-artifact revision: \(revisions)"
            )
        }
    }

    @Test("candidate verifier accepts current main only with exact successful Native evidence")
    func verifierAcceptsCurrentMainWithExactEvidence() throws {
        let fixture = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let result = try runCandidateVerifier(fixture: fixture, sourceSHA: currentSHA)
        #expect(result.status == 0, "verifier failed: \(result.output)")

        let attestationData = try Data(
            contentsOf: fixture.appendingPathComponent("output/testflight-release-candidate.json")
        )
        let attestation = try #require(
            JSONSerialization.jsonObject(with: attestationData) as? [String: Any]
        )
        #expect(attestation["sourceSha"] as? String == currentSHA)
        #expect(attestation["nativeRunId"] as? Int == 4242)
        #expect(attestation["rollback"] as? Bool == false)
    }

    @Test("live verifier queries and downloads evidence for the selected SHA and run")
    func liveVerifierUsesExactGitHubEvidenceRequests() throws {
        let fixture = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let fakeBin = fixture.appendingPathComponent("bin", isDirectory: true)
        let commandLog = fixture.appendingPathComponent("commands.log")
        try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
        try makeExecutable(
            at: fakeBin.appendingPathComponent("git"),
            content: """
            #!/usr/bin/env bash
            set -euo pipefail
            printf 'git %s\n' "$*" >> "$COMMAND_LOG"
            if [[ "$1" == "rev-parse" && "$2" == "HEAD" ]]; then
              cat "$CANDIDATE_FIXTURE/checked-out-sha.txt"
            elif [[ "$1" == "merge-base" && "$2" == "--is-ancestor" ]]; then
              [[ "$(cat "$CANDIDATE_FIXTURE/is-main-ancestor.txt")" == "true" ]]
            else
              echo "unexpected fake git arguments: $*" >&2
              exit 2
            fi
            """
        )
        try makeExecutable(
            at: fakeBin.appendingPathComponent("gh"),
            content: """
            #!/usr/bin/env bash
            set -euo pipefail
            printf 'gh %s\n' "$*" >> "$COMMAND_LOG"
            if [[ "$1" == "api" ]]; then
              endpoint="$4"
              case "$endpoint" in
                repos/*/git/ref/heads/main) cat "$CANDIDATE_FIXTURE/main-ref.json" ;;
                repos/*/actions/workflows/native.yml/runs) cat "$CANDIDATE_FIXTURE/runs.json" ;;
                repos/*/actions/runs/4242/jobs) cat "$CANDIDATE_FIXTURE/jobs.json" ;;
                repos/*/actions/runs/4242/artifacts) cat "$CANDIDATE_FIXTURE/artifacts.json" ;;
                *) echo "unexpected fake gh endpoint: $endpoint" >&2; exit 2 ;;
              esac
            elif [[ "$1" == "run" && "$2" == "download" && "$3" == "4242" ]]; then
              destination=""
              while (( $# > 0 )); do
                if [[ "$1" == "--dir" ]]; then
                  destination="$2"
                  break
                fi
                shift
              done
              [[ -n "$destination" ]]
              mkdir -p "$destination"
              cp "$CANDIDATE_FIXTURE/testflight-release-notes.json" "$destination/"
            else
              echo "unexpected fake gh arguments: $*" >&2
              exit 2
            fi
            """
        )

        let result = try runCandidateVerifierLive(
            fixture: fixture,
            fakeBin: fakeBin,
            commandLog: commandLog,
            sourceSHA: currentSHA
        )
        #expect(result.status == 0, "live verifier failed: \(result.output)")
        let commands = try String(contentsOf: commandLog, encoding: .utf8)
        #expect(commands.contains("git rev-parse HEAD"))
        #expect(commands.contains("git merge-base --is-ancestor \(currentSHA) \(currentSHA)"))
        #expect(commands.contains("gh api --method GET repos/ourostack/spoonjoy-apple/git/ref/heads/main"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/workflows/native.yml/runs -f head_sha=\(currentSHA) -f branch=main -f per_page=100"))
        #expect(!commands.contains("status=completed"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/runs/4242/jobs"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/runs/4242/artifacts"))
        #expect(commands.contains("gh run download 4242 --repo ourostack/spoonjoy-apple --name testflight-release-notes-\(currentSHA)"))
    }

    @Test("candidate verifier fails closed on unsuccessful or mismatched Native checks")
    func verifierRejectsBadNativeEvidence() throws {
        let unsuccessful = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: unsuccessful) }
        try mutateJSON(at: unsuccessful.appendingPathComponent("jobs.json")) { json in
            var jobs = json["jobs"] as! [[String: Any]]
            jobs[0]["conclusion"] = "failure"
            json["jobs"] = jobs
        }
        try expectVerifierFailure(
            fixture: unsuccessful,
            sourceSHA: currentSHA,
            contains: "required Native job Swift tests was not successful"
        )

        let mismatched = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: mismatched) }
        try mutateJSON(at: mismatched.appendingPathComponent("runs.json")) { json in
            var runs = json["workflow_runs"] as! [[String: Any]]
            runs[0]["head_sha"] = String(repeating: "c", count: 40)
            json["workflow_runs"] = runs
        }
        try expectVerifierFailure(
            fixture: mismatched,
            sourceSHA: currentSHA,
            contains: "no exact Native push run"
        )

        let missing = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: missing) }
        try mutateJSON(at: missing.appendingPathComponent("jobs.json")) { json in
            var jobs = json["jobs"] as! [[String: Any]]
            jobs.removeAll { ($0["name"] as? String) == "Coverage" }
            json["jobs"] = jobs
        }
        try expectVerifierFailure(
            fixture: missing,
            sourceSHA: currentSHA,
            contains: "missing required Native job Coverage"
        )

        let superseded = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: superseded) }
        try mutateJSON(at: superseded.appendingPathComponent("runs.json")) { json in
            var runs = json["workflow_runs"] as! [[String: Any]]
            var newerRun = runs[0]
            newerRun["id"] = 5252
            newerRun["run_number"] = 78
            newerRun["status"] = "in_progress"
            newerRun["conclusion"] = NSNull()
            runs.append(newerRun)
            json["workflow_runs"] = runs
        }
        try expectVerifierFailure(
            fixture: superseded,
            sourceSHA: currentSHA,
            contains: "latest exact Native push run 5252 was not successful"
        )
    }

    @Test("candidate verifier fails closed on missing stale or unrelated notes")
    func verifierRejectsBadReleaseNotes() throws {
        let missing = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: missing) }
        try FileManager.default.removeItem(at: missing.appendingPathComponent("testflight-release-notes.json"))
        try expectVerifierFailure(
            fixture: missing,
            sourceSHA: currentSHA,
            contains: "missing release note artifact payload"
        )

        let stale = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: stale) }
        try mutateJSON(at: stale.appendingPathComponent("testflight-release-notes.json")) { json in
            json["sourceSha"] = String(repeating: "d", count: 40)
        }
        try expectVerifierFailure(
            fixture: stale,
            sourceSHA: currentSHA,
            contains: "release note source SHA does not match"
        )

        let unrelatedRun = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: unrelatedRun) }
        try mutateJSON(at: unrelatedRun.appendingPathComponent("testflight-release-notes.json")) { json in
            json["nativeRunId"] = 9999
        }
        try expectVerifierFailure(
            fixture: unrelatedRun,
            sourceSHA: currentSHA,
            contains: "release note Native run ID does not match"
        )

        let expired = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: expired) }
        try mutateJSON(at: expired.appendingPathComponent("artifacts.json")) { json in
            var artifacts = json["artifacts"] as! [[String: Any]]
            artifacts[0]["expired"] = true
            json["artifacts"] = artifacts
        }
        try expectVerifierFailure(
            fixture: expired,
            sourceSHA: currentSHA,
            contains: "release note artifact is expired"
        )
    }

    @Test("older main commits require an explicit reasoned rollback")
    func verifierRequiresExplicitRollback() throws {
        let ordinary = try makeCandidateFixture(sourceSHA: rollbackSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: ordinary) }
        try expectVerifierFailure(
            fixture: ordinary,
            sourceSHA: rollbackSHA,
            contains: "selected SHA is not current main"
        )

        let missingReason = try makeCandidateFixture(sourceSHA: rollbackSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: missingReason) }
        try expectVerifierFailure(
            fixture: missingReason,
            sourceSHA: rollbackSHA,
            allowRollback: true,
            contains: "rollback reason is required"
        )

        let accepted = try makeCandidateFixture(sourceSHA: rollbackSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: accepted) }
        let result = try runCandidateVerifier(
            fixture: accepted,
            sourceSHA: rollbackSHA,
            allowRollback: true,
            rollbackReason: "Restore last known-good sign-in build"
        )
        #expect(result.status == 0, "verifier failed: \(result.output)")

        let nonAncestor = try makeCandidateFixture(
            sourceSHA: rollbackSHA,
            mainSHA: currentSHA,
            isMainAncestor: false
        )
        defer { try? FileManager.default.removeItem(at: nonAncestor) }
        try expectVerifierFailure(
            fixture: nonAncestor,
            sourceSHA: rollbackSHA,
            allowRollback: true,
            rollbackReason: "Attempt unrelated revision",
            contains: "selected SHA is not an ancestor of main"
        )

        let legacy = try makeCandidateFixture(sourceSHA: rollbackSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: legacy) }
        try mutateJSON(at: legacy.appendingPathComponent("jobs.json")) { json in
            var jobs = json["jobs"] as! [[String: Any]]
            jobs.removeAll { ($0["name"] as? String) == "TestFlight release note" }
            json["jobs"] = jobs
        }
        try mutateJSON(at: legacy.appendingPathComponent("artifacts.json")) { json in
            json["artifacts"] = []
        }
        try FileManager.default.removeItem(at: legacy.appendingPathComponent("testflight-release-notes.json"))
        let legacyResult = try runCandidateVerifier(
            fixture: legacy,
            sourceSHA: rollbackSHA,
            allowRollback: true,
            rollbackReason: "Restore pre-containment known-good build",
            rollbackNotes: "Restores the last known-good native build."
        )
        #expect(legacyResult.status == 0, "legacy rollback verifier failed: \(legacyResult.output)")
        let generatedNote = legacy.appendingPathComponent(
            "output/testflight-release-notes-\(rollbackSHA)/testflight-release-notes.json"
        )
        let generatedData = try Data(contentsOf: generatedNote)
        let generated = try #require(JSONSerialization.jsonObject(with: generatedData) as? [String: Any])
        #expect(generated["sourceSha"] as? String == rollbackSHA)
        #expect(generated["nativeRunId"] as? Int == 4242)
        #expect(generated["notes"] as? String == "Restores the last known-good native build.")

        let ordinaryWithRollbackNotes = try makeCandidateFixture(sourceSHA: currentSHA, mainSHA: currentSHA)
        defer { try? FileManager.default.removeItem(at: ordinaryWithRollbackNotes) }
        try expectVerifierFailure(
            fixture: ordinaryWithRollbackNotes,
            sourceSHA: currentSHA,
            rollbackNotes: "Must not override ordinary release notes",
            contains: "rollback notes are only valid for an explicit rollback"
        )
    }

    @Test("publish driver consumes exact candidate notes and records provenance")
    func publishDriverConsumesCandidateNotes() throws {
        let script = try readTestFlightAutomationRepoFile("scripts/ci-publish-testflight.sh")

        expectTestFlightAutomationContent(
            script,
            in: "scripts/ci-publish-testflight.sh",
            contains: [
                "SPOONJOY_TESTFLIGHT_SOURCE_SHA",
                "SPOONJOY_TESTFLIGHT_SOURCE_ROOT",
                "SPOONJOY_TESTFLIGHT_RELEASE_NOTES_PATH",
                "release note source SHA does not match",
                "testflight.build.whatsNew",
                "sourceSha: $sourceSha",
                "releaseNotesArtifact"
            ]
        )
    }

    @Test("distribution docs describe exact-SHA release and rollback")
    func distributionDocsDescribeContainedReleaseAndRollback() throws {
        let docs = try readTestFlightAutomationRepoFile("docs/apple-distribution.md")

        expectTestFlightAutomationContent(
            docs,
            in: "docs/apple-distribution.md",
            contains: [
                "Exact-SHA TestFlight Release",
                ".github/workflows/testflight.yml",
                "source_sha",
                "successful `Native` push run",
                "testflight-release-notes-<source_sha>",
                "allow_rollback",
                "rollback_reason",
                "rollback_notes",
                "9f64507b03a5dc76a6ebc52f88cddf71f9448a8e532e4758951d2d31309d5a45",
                "GitHub-hosted runner trust boundary",
                "runner-provided `gh`",
                "last known-good main commit",
                "new TestFlight build number",
                "No push, pull request, or completed workflow publishes automatically"
            ],
            forbids: [
                "publishes internal TestFlight builds automatically"
            ]
        )
    }
}

private struct TestFlightProcessResult {
    let status: Int32
    let output: String
}

private let testFlightAutomationRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let requiredNativeJobNames = [
    "Swift tests",
    "Native scenario verifier",
    "App bundle",
    "Coverage",
    "TestFlight release note"
]

private func readTestFlightAutomationRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: testFlightAutomationRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func expectTestFlightAutomationContent(
    _ content: String,
    in path: String,
    contains requiredTokens: [String] = [],
    forbids forbiddenTokens: [String] = []
) {
    let missing = requiredTokens.filter { !content.contains($0) }
    #expect(missing.isEmpty, "\(path) missing required token(s): \(missing)")

    let presentForbidden = forbiddenTokens.filter { content.contains($0) }
    #expect(presentForbidden.isEmpty, "\(path) contains forbidden token(s): \(presentForbidden)")
}

private func makeCandidateFixture(
    sourceSHA: String,
    mainSHA: String,
    isMainAncestor: Bool = true
) throws -> URL {
    let fixture = FileManager.default.temporaryDirectory
        .appendingPathComponent("testflight-release-candidate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)

    try "\(sourceSHA)\n".write(
        to: fixture.appendingPathComponent("checked-out-sha.txt"),
        atomically: true,
        encoding: .utf8
    )
    try "\(isMainAncestor ? "true" : "false")\n".write(
        to: fixture.appendingPathComponent("is-main-ancestor.txt"),
        atomically: true,
        encoding: .utf8
    )
    try writeJSON(
        ["ref": "refs/heads/main", "object": ["sha": mainSHA]],
        to: fixture.appendingPathComponent("main-ref.json")
    )
    try writeJSON(
        [
            "workflow_runs": [[
                "id": 4242,
                "run_number": 77,
                "run_attempt": 1,
                "event": "push",
                "head_branch": "main",
                "head_sha": sourceSHA,
                "path": ".github/workflows/native.yml",
                "status": "completed",
                "conclusion": "success",
                "created_at": "2026-07-15T18:00:00Z",
                "updated_at": "2026-07-15T18:20:00Z"
            ]]
        ],
        to: fixture.appendingPathComponent("runs.json")
    )
    try writeJSON(
        [
            "jobs": requiredNativeJobNames.map { name in
                ["name": name, "status": "completed", "conclusion": "success"]
            }
        ],
        to: fixture.appendingPathComponent("jobs.json")
    )
    try writeJSON(
        [
            "artifacts": [[
                "id": 9001,
                "name": "testflight-release-notes-\(sourceSHA)",
                "expired": false
            ]]
        ],
        to: fixture.appendingPathComponent("artifacts.json")
    )
    try writeJSON(
        [
            "schemaVersion": 1,
            "sourceSha": sourceSHA,
            "nativeRunId": 4242,
            "nativeRunAttempt": 1,
            "generatedAt": "2026-07-15T18:18:00Z",
            "notes": "A precise candidate note for this native revision."
        ],
        to: fixture.appendingPathComponent("testflight-release-notes.json")
    )

    return fixture
}

private func runCandidateVerifier(
    fixture: URL,
    sourceSHA: String,
    allowRollback: Bool = false,
    rollbackReason: String = "",
    rollbackNotes: String = ""
) throws -> TestFlightProcessResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
    process.arguments = [
        testFlightAutomationRepoURL.appendingPathComponent("scripts/verify-testflight-release-candidate.rb").path,
        "--source-sha", sourceSHA,
        "--repository", "ourostack/spoonjoy-apple",
        "--allow-rollback", allowRollback ? "true" : "false",
        "--rollback-reason", rollbackReason,
        "--rollback-notes", rollbackNotes,
        "--output-dir", fixture.appendingPathComponent("output").path,
        "--fixture-dir", fixture.path
    ]
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()

    return TestFlightProcessResult(
        status: process.terminationStatus,
        output: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func runCandidateVerifierLive(
    fixture: URL,
    fakeBin: URL,
    commandLog: URL,
    sourceSHA: String
) throws -> TestFlightProcessResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
    process.arguments = [
        testFlightAutomationRepoURL.appendingPathComponent("scripts/verify-testflight-release-candidate.rb").path,
        "--source-sha", sourceSHA,
        "--repository", "ourostack/spoonjoy-apple",
        "--allow-rollback", "false",
        "--rollback-reason", "",
        "--output-dir", fixture.appendingPathComponent("live-output").path
    ]
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = "\(fakeBin.path):/usr/bin:/bin"
    environment["CANDIDATE_FIXTURE"] = fixture.path
    environment["COMMAND_LOG"] = commandLog.path
    process.environment = environment
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()

    return TestFlightProcessResult(
        status: process.terminationStatus,
        output: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func expectVerifierFailure(
    fixture: URL,
    sourceSHA: String,
    allowRollback: Bool = false,
    rollbackReason: String = "",
    rollbackNotes: String = "",
    contains message: String
) throws {
    let result = try runCandidateVerifier(
        fixture: fixture,
        sourceSHA: sourceSHA,
        allowRollback: allowRollback,
        rollbackReason: rollbackReason,
        rollbackNotes: rollbackNotes
    )
    #expect(result.status != 0, "verifier unexpectedly accepted invalid fixture")
    #expect(result.output.contains(message), "expected \(message.debugDescription), got: \(result.output)")
}

private func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

private func makeExecutable(at url: URL, content: String) throws {
    try content.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func mutateJSON(at url: URL, mutation: (inout [String: Any]) -> Void) throws {
    let data = try Data(contentsOf: url)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    mutation(&object)
    try writeJSON(object, to: url)
}
