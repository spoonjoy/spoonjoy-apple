import Foundation
import Testing
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Darwin)
import Darwin
#endif

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

    @Test("Protected pull-request CI runs non-launch native UI geometry regressions")
    func protectedNativeCIRunsNonLaunchGeometryTests() throws {
        let workflow = try readTestFlightAutomationRepoFile(".github/workflows/native.yml")

        expectTestFlightAutomationContent(
            workflow,
            in: ".github/workflows/native.yml",
            contains: [
                "Run non-launch native UI geometry regressions",
                "xcodebuild test",
                "simulator_arch=\"$(uname -m)\"",
                "-destination \"$ios_destination,arch=$simulator_arch\"",
                "-only-testing:SpoonjoyUITests/NativeScreenshotEvidenceTests",
                "-skip-testing:SpoonjoyUITests/NativeScreenshotEvidenceTests/testObservedAccessibilityAndGeometry",
                "GCC_TREAT_WARNINGS_AS_ERRORS=YES",
                "ruby scripts/fail-on-warning.rb --log \"$ui_geometry_log\""
            ]
        )
    }

    @Test("visual release evidence binds exact-source pending-to-content tests")
    func visualReleaseEvidenceBindsTransitionTests() throws {
        let capture = try readTestFlightAutomationRepoFile("scripts/capture-native-transition-evidence.sh")
        let matrix = try readTestFlightAutomationRepoFile("scripts/capture-native-screenshot-matrix.sh")
        let sealer = try readTestFlightAutomationRepoFile("scripts/testflight-visual-evidence.rb")

        expectTestFlightAutomationContent(
            capture,
            in: "scripts/capture-native-transition-evidence.sh",
            contains: [
                "git diff --quiet",
                "NativeSearchSurfaceTests.pendingSearchSuppressesEmptyState",
                "RecipeCatalogDetailTests.recipeDetailPublishesBeforeCookHistoryEnrichment",
                "-Xswiftc -warnings-as-errors",
                "search-pending-suppresses-empty-state",
                "recipe-publishes-before-cook-history",
                "sourceSha",
                "sourceTree"
            ]
        )
        expectTestFlightAutomationContent(
            matrix,
            in: "scripts/capture-native-screenshot-matrix.sh",
            contains: [
                "scripts/capture-native-transition-evidence.sh",
                "transitionEvidenceValidated",
                "transitionEvidenceSha256",
                "transitionEvidenceLogSha256"
            ]
        )
        expectTestFlightAutomationContent(
            sealer,
            in: "scripts/testflight-visual-evidence.rb",
            contains: [
                "TRANSITION_CONTRACT_IDS",
                "validate_transition_evidence!",
                "transitionEvidenceLog",
                "sealed native transition evidence mismatch"
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

    @Test("TestFlight feedback tunnel validates the installed and loaded HTTP/2 command")
    func feedbackTunnelValidatesInstalledAndLoadedHTTP2Command() throws {
        let result = try runTestFlightFeedbackAutopilot(command: "self-test-launchd-validation")
        #expect(result.status == 0, "launchd validation self-test failed: \(result.output)")

        let data = try #require(result.output.data(using: .utf8))
        let report = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expectedTunnelArguments = try #require(report["expectedTunnelProgramArguments"] as? [String])
        let exact = try #require(report["exactHTTP2"] as? [String: Any])
        let legacy = try #require(report["legacyQUIC"] as? [String: Any])
        let misordered = try #require(report["misorderedHTTP2"] as? [String: Any])
        let staleLoaded = try #require(report["staleLoadedJob"] as? [String: Any])
        let staleWorkingDirectory = try #require(report["staleLoadedWorkingDirectory"] as? [String: Any])
        let staleEnvironment = try #require(report["staleLoadedEnvironment"] as? [String: Any])
        let unexpectedEnvironment = try #require(report["unexpectedManagedEnvironment"] as? [String: Any])
        let deadKeepAlive = try #require(report["deadKeepAliveService"] as? [String: Any])
        let failedScheduledJob = try #require(report["failedScheduledJob"] as? [String: Any])
        let transientConvergence = try #require(report["transientLaunchdConvergence"] as? [String: Any])
        let timedOutConvergence = try #require(report["timedOutLaunchdConvergence"] as? [String: Any])
        let deadlineConvergence = try #require(report["deadlineLaunchdConvergence"] as? [String: Any])
        let definitionReuse = try #require(report["definitionReuse"] as? [String: Any])
        let hungSubprocess = try #require(report["hungSubprocess"] as? [String: Any])
        let healthWaitPolicy = try #require(report["healthWaitPolicy"] as? [String: Any])
        let htmlHealthFailure = try #require(report["htmlHealthFailure"] as? [String: Any])
        let transientPublicHealth = try #require(report["transientPublicHealth"] as? [String: Any])
        let exhaustedPublicHealth = try #require(report["exhaustedPublicHealth"] as? [String: Any])
        let hungLocalHealth = try #require(report["hungLocalHealth"] as? [String: Any])
        let deadlinePublicHealth = try #require(report["deadlinePublicHealth"] as? [String: Any])
        let rejectedHealthContracts = try #require(report["rejectedHealthContracts"] as? [String: Any])
        let healthContract = try #require(report["healthContract"] as? [String: Any])

        #expect(exact["ok"] as? Bool == true)
        #expect(expectedTunnelArguments == [
            "/opt/homebrew/bin/cloudflared", "tunnel", "--config",
            "/Users/tester/.cloudflared/spoonjoy-testflight-feedback.yml",
            "--protocol", "http2", "run", "spoonjoy-testflight-feedback"
        ])
        #expect(legacy["ok"] as? Bool == false)
        #expect(misordered["ok"] as? Bool == false)
        #expect(staleLoaded["ok"] as? Bool == false)
        #expect(staleWorkingDirectory["ok"] as? Bool == false)
        #expect(staleEnvironment["ok"] as? Bool == false)
        #expect(unexpectedEnvironment["ok"] as? Bool == false)
        #expect(deadKeepAlive["ok"] as? Bool == false)
        #expect(failedScheduledJob["ok"] as? Bool == false)
        #expect(transientConvergence["ok"] as? Bool == true)
        #expect(transientConvergence["attemptsUsed"] as? Int == 3)
        #expect(timedOutConvergence["ok"] as? Bool == false)
        #expect(timedOutConvergence["attemptsUsed"] as? Int == 3)
        #expect(
            (timedOutConvergence["issues"] as? [String])?.contains(where: { $0.contains("xpcproxy") }) == true
        )
        #expect(deadlineConvergence["ok"] as? Bool == false)
        #expect(deadlineConvergence["attemptsUsed"] as? Int == 2)
        #expect(deadlineConvergence["timedOut"] as? Bool == true)
        #expect(definitionReuse["ok"] as? Bool == true)
        #expect(definitionReuse["attemptsUsed"] as? Int == 1)
        #expect(hungSubprocess["timedOut"] as? Bool == true)
        #expect(hungSubprocess["signal"] as? String == "SIGKILL")
        #expect(hungSubprocess["elapsedMilliseconds"] as? Int ?? .max < 1_000)
        #expect(healthWaitPolicy["installAttempts"] as? Int == 40)
        #expect(healthWaitPolicy["installDelayMilliseconds"] as? Int == 250)
        #expect(healthWaitPolicy["installTimeoutMilliseconds"] as? Int == 15_000)
        #expect(healthWaitPolicy["subprocessTimeoutMilliseconds"] as? Int == 10_000)
        #expect(healthWaitPolicy["localRequestTimeoutMilliseconds"] as? Int == 2_000)
        #expect(healthWaitPolicy["publicAttempts"] as? Int == 180)
        #expect(healthWaitPolicy["publicDelayMilliseconds"] as? Int == 1_000)
        #expect(healthWaitPolicy["publicTimeoutMilliseconds"] as? Int == 180_000)
        #expect(healthWaitPolicy["publicRequestTimeoutMilliseconds"] as? Int == 10_000)
        #expect(htmlHealthFailure["ok"] as? Bool == false)
        #expect(htmlHealthFailure["status"] as? Int == 530)
        #expect(htmlHealthFailure["error"] as? String == "HTTP 530 (non-JSON response)")
        #expect(htmlHealthFailure["body"] == nil)
        #expect(!result.output.contains("TEST_SECRET_RESPONSE_BODY_MARKER"))
        #expect(transientPublicHealth["ok"] as? Bool == true)
        #expect(transientPublicHealth["attemptsUsed"] as? Int == 3)
        #expect(exhaustedPublicHealth["ok"] as? Bool == false)
        #expect(exhaustedPublicHealth["attemptsUsed"] as? Int == 2)
        #expect(hungLocalHealth["ok"] as? Bool == false)
        #expect(hungLocalHealth["requestSeen"] as? Bool == true)
        #expect(hungLocalHealth["connectionHeader"] as? String == "close")
        #expect(hungLocalHealth["error"] as? String == "request timed out after 100ms")
        #expect(hungLocalHealth["openConnections"] as? Int == 0)
        #expect(hungLocalHealth["forcedCleanup"] as? Bool == false)
        #expect(hungLocalHealth["serverClosed"] as? Bool == true)
        #expect(deadlinePublicHealth["ok"] as? Bool == false)
        #expect(deadlinePublicHealth["attemptsUsed"] as? Int == 2)
        #expect(deadlinePublicHealth["timedOut"] as? Bool == true)
        for key in ["bodyNotOk", "wrongApp", "wrongBundle", "wrongProcess"] {
            let issues = try #require(rejectedHealthContracts[key] as? [String])
            #expect(!issues.isEmpty, "health contract case \(key) must be rejected")
        }
        #expect(healthContract["deploymentIdentity"] as? String == "spoonjoy-testflight-feedback-autopilot")
        let scriptDigest = try #require(healthContract["scriptDigest"] as? String)
        #expect(scriptDigest.wholeMatch(of: /[0-9a-f]{64}/) != nil)
        #expect(healthContract["repo"] == nil)
        #expect(healthContract["scriptPath"] == nil)
        #expect(
            (legacy["issues"] as? [String])?.contains(where: { $0.contains("plist program arguments") }) == true
        )
        #expect(
            (staleLoaded["issues"] as? [String])?.contains(where: { $0.contains("loaded launchd arguments") }) == true
        )
        #expect(
            (staleWorkingDirectory["issues"] as? [String])?.contains(where: { $0.contains("loaded working directory") }) == true
        )
        #expect(
            (staleEnvironment["issues"] as? [String])?.contains(where: { $0.contains("loaded managed environment") }) == true
        )
        #expect(
            (unexpectedEnvironment["issues"] as? [String])?.contains(where: { $0.contains("loaded managed environment") }) == true
        )
        #expect(
            (deadKeepAlive["issues"] as? [String])?.contains(where: { $0.contains("loaded launchd state") }) == true
        )
        #expect(
            (failedScheduledJob["issues"] as? [String])?.contains(where: { $0.contains("last exit code") }) == true
        )

        let script = try readTestFlightAutomationRepoFile("scripts/testflight-feedback-autopilot.mjs")
        #expect(!script.contains("spawnSync(\"launchctl\""))
        #expect(!script.contains("spawnSync(\"/usr/bin/plutil\""))
        #expect(!script.contains("requester: async () => new Promise(() => {})"))
    }

    @Test("TestFlight feedback help uses the live public tunnel hostname")
    func feedbackAutomationHelpUsesLivePublicTunnelHostname() throws {
        let result = try runTestFlightFeedbackAutopilot(command: "help")
        #expect(result.status == 0)
        #expect(result.output.contains("https://spoonjoy-testflight-feedback.ouro.bot/app-store-connect/webhook"))
        #expect(!result.output.contains("https://testflight-feedback.spoonjoy.app/app-store-connect/webhook"))
        #expect(result.output.contains("SPOONJOY_TESTFLIGHT_WEBHOOK_SECRET_PATH  (configured path; value redacted)"))
        #expect(!result.output.contains("webhook-secret"))
    }

    @Test("TestFlight feedback diagnostics redact configured credential paths")
    func feedbackAutomationDiagnosticsRedactCredentialPaths() throws {
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("testflight-feedback-redaction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let privateKeyPath = "/sensitive/private/AuthKey_test.p8"
        let configPath = fixture.appendingPathComponent("app-store-connect.json")
        try writeJSON(
            ["keyId": "test-key", "issuerId": "test-issuer", "privateKeyPath": privateKeyPath],
            to: configPath
        )
        let statusResult = try runTestFlightFeedbackAutopilot(
            command: "status",
            environmentOverrides: ["APPLE_DISTRIBUTION_KIT_CONFIG": configPath.path]
        )
        #expect(!statusResult.output.contains(privateKeyPath))
        #expect(statusResult.output.contains("configured path (redacted)"))

        let secretPath = "/sensitive/private/webhook-secret"
        let listenerResult = try runTestFlightFeedbackAutopilot(
            command: "listen",
            environmentOverrides: ["SPOONJOY_TESTFLIGHT_WEBHOOK_SECRET_PATH": secretPath]
        )
        #expect(listenerResult.status != 0)
        #expect(!listenerResult.output.contains(secretPath))
        #expect(listenerResult.output.contains("configured path (redacted)"))

        let unreadableSecretPath = fixture.appendingPathComponent("unreadable-webhook-secret")
        try "test-secret".write(to: unreadableSecretPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: unreadableSecretPath.path)
        let unreadableResult = try runTestFlightFeedbackAutopilot(
            command: "listen",
            environmentOverrides: ["SPOONJOY_TESTFLIGHT_WEBHOOK_SECRET_PATH": unreadableSecretPath.path]
        )
        #expect(unreadableResult.status != 0)
        #expect(!unreadableResult.output.contains(unreadableSecretPath.path))
        #expect(unreadableResult.output.contains("configured path (redacted)"))
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
            elif [[ "$1" == "rev-parse" && "$2" == "HEAD^{tree}" ]]; then
              cat "$CANDIDATE_FIXTURE/checked-out-tree.txt"
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
                repos/*/actions/runs/4242/attempts/1/jobs) cat "$CANDIDATE_FIXTURE/jobs.json" ;;
                repos/*/actions/runs/4242/artifacts) cat "$CANDIDATE_FIXTURE/artifacts.json" ;;
                *) echo "unexpected fake gh endpoint: $endpoint" >&2; exit 2 ;;
              esac
            elif [[ "$1" == "run" && "$2" == "download" && "$3" == "4242" ]]; then
              destination=""
              artifact_name=""
              index=1
              while (( index <= $# )); do
                argument="${!index}"
                if [[ "$argument" == "--name" ]]; then
                  next=$((index + 1))
                  artifact_name="${!next}"
                elif [[ "$argument" == "--dir" ]]; then
                  next=$((index + 1))
                  destination="${!next}"
                fi
                index=$((index + 1))
              done
              [[ -n "$destination" && -n "$artifact_name" ]]
              mkdir -p "$destination"
              if [[ "$artifact_name" == testflight-release-notes-* ]]; then
                cp "$CANDIDATE_FIXTURE/testflight-release-notes.json" "$destination/"
              elif [[ "$artifact_name" == native-visual-evidence-* ]]; then
                cp -R "$CANDIDATE_FIXTURE/native-visual-evidence/." "$destination/"
              else
                echo "unexpected fake artifact: $artifact_name" >&2
                exit 2
              fi
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
        #expect(commands.contains("git rev-parse HEAD^{tree}"))
        #expect(commands.contains("git merge-base --is-ancestor \(currentSHA) \(currentSHA)"))
        #expect(commands.contains("gh api --method GET repos/ourostack/spoonjoy-apple/git/ref/heads/main"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/workflows/native.yml/runs -f head_sha=\(currentSHA) -f branch=main -f per_page=100"))
        #expect(!commands.contains("status=completed"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/runs/4242/attempts/1/jobs"))
        #expect(commands.contains("repos/ourostack/spoonjoy-apple/actions/runs/4242/artifacts"))
        #expect(commands.contains("gh run download 4242 --repo ourostack/spoonjoy-apple --name testflight-release-notes-\(currentSHA)-4242-1"))
        #expect(commands.contains("gh run download 4242 --repo ourostack/spoonjoy-apple --name native-visual-evidence-\(currentSHA)-4242-1"))
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

    @Test("candidate verifier rejects incomplete deep-scroll visual evidence")
    func verifierRejectsMissingDeepScrollEvidence() throws {
        let fixture = try makeCandidateFixture(
            sourceSHA: currentSHA,
            mainSHA: currentSHA,
            omitDeepScrollForRoute: "kitchen"
        )
        defer { try? FileManager.default.removeItem(at: fixture) }

        try expectVerifierFailure(
            fixture: fixture,
            sourceSHA: currentSHA,
            contains: "route kitchen deep-scroll screenshot set is incomplete"
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
        try expectVerifierFailure(
            fixture: legacy,
            sourceSHA: rollbackSHA,
            allowRollback: true,
            rollbackReason: "Restore pre-containment known-good build",
            rollbackNotes: "Restores the last known-good native build.",
            contains: "missing required Native job TestFlight release note"
        )

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
private let testFlightVisualSourceTree = String(repeating: "f", count: 40)
private let testFlightVisualRoutes = [
    "kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers",
    "cook-mode", "cook-log", "cookbooks", "cookbook-detail", "shopping-list",
    "shopping-list-empty", "shopping-list-all-complete", "shopping-list-duplicate",
    "shopping-list-conflict", "shopping-list-offline-queued", "chefs", "profile", "profile-graph",
    "search", "search-typed-results", "search-scoped-recipes", "search-scoped-cookbooks",
    "search-scoped-chefs", "search-scoped-shopping", "search-no-results", "capture", "capture-empty",
    "capture-draft", "capture-offline-retry", "capture-provider-blocked", "capture-signed-out",
    "settings", "settings-notifications", "settings-signed-out", "settings-apns-denied",
    "settings-apns-not-determined", "settings-apns-authorized", "settings-apns-unregistered",
    "unknown-link"
]
private let testFlightRouteVariants: [String: Set<String>] = [
    "shopping-list": [
        "shopping-list-empty", "shopping-list-all-complete", "shopping-list-duplicate",
        "shopping-list-conflict", "shopping-list-offline-queued"
    ],
    "search": [
        "search-typed-results", "search-scoped-recipes", "search-scoped-cookbooks",
        "search-scoped-chefs", "search-scoped-shopping", "search-no-results"
    ],
    "capture": [
        "capture-empty", "capture-draft", "capture-offline-retry", "capture-provider-blocked",
        "capture-signed-out"
    ],
    "settings": [
        "settings-notifications", "settings-signed-out", "settings-apns-denied",
        "settings-apns-not-determined", "settings-apns-authorized", "settings-apns-unregistered"
    ]
]
private let testFlightDeepScrollRoutes: Set<String> = [
    "kitchen", "recipes", "saved-recipes", "recipe-detail", "recipe-editor", "recipe-covers",
    "cook-mode", "cook-log", "cookbooks", "cookbook-detail", "shopping-list", "chefs",
    "profile", "profile-graph", "search", "capture", "settings"
]

private func testFlightCaptureRoute(for route: String) -> String {
    testFlightRouteVariants.first { $0.value.contains(route) }?.key ?? route
}
private let requiredNativeJobNames = [
    "Swift tests",
    "Native scenario verifier",
    "App bundle",
    "Coverage",
    "Native visual evidence",
    "TestFlight release note"
]

private func readTestFlightAutomationRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: testFlightAutomationRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func runTestFlightFeedbackAutopilot(
    command: String,
    environmentOverrides: [String: String] = [:],
    timeout: TimeInterval = 20
) throws -> TestFlightProcessResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "node",
        testFlightAutomationRepoURL.appendingPathComponent("scripts/testflight-feedback-autopilot.mjs").path,
        command
    ]
    process.environment = ProcessInfo.processInfo.environment.merging(environmentOverrides) { _, override in override }
    process.standardOutput = output
    process.standardError = output
    let exited = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in exited.signal() }
    try process.run()
    if exited.wait(timeout: .now() + timeout) == .timedOut {
        process.terminate()
        if exited.wait(timeout: .now() + 1) == .timedOut {
            #if canImport(Darwin)
            Darwin.kill(process.processIdentifier, SIGKILL)
            #endif
            _ = exited.wait(timeout: .now() + 1)
        }
        throw TestFlightAutomationProcessTimeout(command: command, seconds: timeout)
    }

    return TestFlightProcessResult(
        status: process.terminationStatus,
        output: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private struct TestFlightAutomationProcessTimeout: Error, CustomStringConvertible {
    let command: String
    let seconds: TimeInterval

    var description: String {
        "TestFlight feedback command \(command) exceeded \(seconds) seconds"
    }
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
    isMainAncestor: Bool = true,
    omitDeepScrollForRoute: String? = nil
) throws -> URL {
    let fixture = FileManager.default.temporaryDirectory
        .appendingPathComponent("testflight-release-candidate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)

    try "\(sourceSHA)\n".write(
        to: fixture.appendingPathComponent("checked-out-sha.txt"),
        atomically: true,
        encoding: .utf8
    )
    try "\(testFlightVisualSourceTree)\n".write(
        to: fixture.appendingPathComponent("checked-out-tree.txt"),
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
    let visualArtifact = try makeVisualEvidenceFixture(
        fixture: fixture,
        sourceSHA: sourceSHA,
        runID: 4242,
        runAttempt: 1,
        omitDeepScrollForRoute: omitDeepScrollForRoute
    )
    try writeJSON(
        [
            "artifacts": [
                [
                    "id": 9001,
                    "name": "testflight-release-notes-\(sourceSHA)-4242-1",
                    "expired": false
                ],
                [
                    "id": 9002,
                    "name": visualArtifact.name,
                    "digest": visualArtifact.artifactDigest,
                    "expired": false
                ]
            ]
        ],
        to: fixture.appendingPathComponent("artifacts.json")
    )
    try writeJSON(
        [
            "schemaVersion": 2,
            "sourceSha": sourceSHA,
            "sourceTree": testFlightVisualSourceTree,
            "nativeRunId": 4242,
            "nativeRunAttempt": 1,
            "generatedAt": "2026-07-15T18:18:00Z",
            "notes": "A precise candidate note for this native revision.",
            "visualEvidence": [
                "artifactId": 9002,
                "artifactName": visualArtifact.name,
                "artifactDigest": visualArtifact.artifactDigest,
                "manifestSha256": visualArtifact.manifestDigest,
                "workflowRunId": 4242,
                "workflowRunAttempt": 1,
                "workflowJob": "native-visual-evidence",
                "jobName": "Native visual evidence"
            ]
        ],
        to: fixture.appendingPathComponent("testflight-release-notes.json")
    )

    return fixture
}

private struct TestFlightVisualArtifactFixture {
    let name: String
    let artifactDigest: String
    let manifestDigest: String
}

private func makeVisualEvidenceFixture(
    fixture: URL,
    sourceSHA: String,
    runID: Int,
    runAttempt: Int,
    omitDeepScrollForRoute: String?
) throws -> TestFlightVisualArtifactFixture {
    let artifact = fixture.appendingPathComponent("native-visual-evidence", isDirectory: true)
    let payload = artifact.appendingPathComponent("payload", isDirectory: true)
    try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
    var fileURLs: [URL] = []
    var matrixRows: [[String: Any]] = []
    var manifestRoutes: [[String: Any]] = []
    let screenshotNames = [
        "iosMobile": "ios-mobile.png",
        "iosAccessibility": "ios-mobile-accessibility.png",
        "iosTablet": "ios-tablet.png",
        "macosDesktop": "macos-desktop.png"
    ]
    let deepScrollScreenshotNames = [
        "iosMobile": "ios-mobile-deep-scroll.png",
        "iosAccessibility": "ios-mobile-accessibility-deep-scroll.png",
        "iosTablet": "ios-tablet-deep-scroll.png"
    ]
    let accessibilityProofs = ["accessibility-ios.json", "accessibility-ipad.json", "accessibility-macos.json"]
    let observedProofs = ["observed-ios.json", "observed-ios-ax.json", "observed-ipad.json", "observed-macos.json"]

    for route in testFlightVisualRoutes {
        let captureRoute = testFlightCaptureRoute(for: route)
        let routeDirectory = payload.appendingPathComponent("routes/\(route)", isDirectory: true)
        let screenshotsDirectory = routeDirectory.appendingPathComponent("screenshots", isDirectory: true)
        let proofsDirectory = routeDirectory.appendingPathComponent("proofs", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: proofsDirectory, withIntermediateDirectories: true)

        var screenshotReferences: [String: String] = [:]
        var screenshotRecords: [String: [String: Any]] = [:]
        for (key, name) in screenshotNames {
            let url = screenshotsDirectory.appendingPathComponent(name)
            var bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            bytes.append(Data("\(route):\(key)".utf8))
            try bytes.write(to: url)
            let relative = "screenshots/\(name)"
            screenshotReferences[key] = "payload/routes/\(route)/\(relative)"
            screenshotRecords[key] = [
                "path": relative,
                "bytes": bytes.count,
                "sha256": try sha256OfFile(at: url)
            ]
            fileURLs.append(url)
        }

        var deepScrollScreenshotReferences: [String: String] = [:]
        var deepScrollScreenshotRecords: [String: [String: Any]] = [:]
        let requiresDeepScroll = testFlightDeepScrollRoutes.contains(captureRoute)
        if requiresDeepScroll && omitDeepScrollForRoute != route {
            for (key, name) in deepScrollScreenshotNames {
                let url = screenshotsDirectory.appendingPathComponent(name)
                var bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
                bytes.append(Data("\(route):\(key):deep-scroll".utf8))
                try bytes.write(to: url)
                let relative = "screenshots/\(name)"
                deepScrollScreenshotReferences[key] = "payload/routes/\(route)/\(relative)"
                deepScrollScreenshotRecords[key] = [
                    "path": relative,
                    "bytes": bytes.count,
                    "sha256": try sha256OfFile(at: url)
                ]
                fileURLs.append(url)
            }
        }

        let proofNames = accessibilityProofs + observedProofs
        for name in proofNames {
            let url = proofsDirectory.appendingPathComponent(name)
            try writeJSON(["route": route, "blocked": false, "proof": name], to: url)
            fileURLs.append(url)
        }
        var designReviewPayload: [String: Any] = [
            "screenshotRoute": captureRoute,
            "blockers": [],
            "screenshotArtifacts": screenshotRecords,
            "accessibilityProofArtifacts": accessibilityProofs.map { "proofs/\($0)" },
            "observedAccessibilityEvidenceArtifacts": observedProofs.map { "proofs/\($0)" }
        ]
        if requiresDeepScroll && omitDeepScrollForRoute != route {
            designReviewPayload["deepScrollScreenshotArtifacts"] = deepScrollScreenshotRecords
        }
        if captureRoute == "recipe-covers" {
            designReviewPayload["recipeCoverControlsFixture"] = "action-states"
            designReviewPayload["renderedSurfaceAnchors"] = ["stagedPhotoActions", "coverMutationActions"]
        }
        let designReview = routeDirectory.appendingPathComponent("design-review.json")
        try writeJSON(designReviewPayload, to: designReview)
        fileURLs.append(designReview)

        matrixRows.append([
            "name": route,
            "route": captureRoute,
            "status": "pass",
            "blocked": false,
            "missingDesignReview": false
        ])
        manifestRoutes.append([
            "name": route,
            "route": captureRoute,
            "designReview": "payload/routes/\(route)/design-review.json",
            "screenshots": screenshotReferences,
            "deepScrollScreenshots": deepScrollScreenshotReferences,
            "proofs": proofNames.map { "payload/routes/\(route)/proofs/\($0)" }
        ])
    }

    let provenance = payload.appendingPathComponent("provenance.json")
    let provenanceDigest = String(repeating: "d", count: 64)
    try writeJSON(
        [
            "source": ["sha": sourceSHA, "tree": testFlightVisualSourceTree],
            "manifestSha256": provenanceDigest
        ],
        to: provenance
    )
    fileURLs.append(provenance)

    let transitionLog = payload.appendingPathComponent("transition-evidence.log")
    try "2 transition tests passed\n".write(to: transitionLog, atomically: true, encoding: .utf8)
    let transitionLogDigest = try sha256OfFile(at: transitionLog)
    fileURLs.append(transitionLog)
    let transitionEvidence = payload.appendingPathComponent("transition-evidence.json")
    try writeJSON(
        [
            "schemaVersion": 1,
            "ok": true,
            "sourceSha": sourceSHA,
            "sourceTree": testFlightVisualSourceTree,
            "command": "swift test --filter native-transitions",
            "log": [
                "path": "transition-evidence.log",
                "bytes": try Data(contentsOf: transitionLog).count,
                "sha256": transitionLogDigest
            ],
            "contracts": [
                ["id": "search-pending-suppresses-empty-state", "test": "NativeSearchSurfaceTests.pendingSearchSuppressesEmptyState", "assertion": "pending"],
                ["id": "recipe-publishes-before-cook-history", "test": "RecipeCatalogDetailTests.recipeDetailPublishesBeforeCookHistoryEnrichment", "assertion": "progressive"]
            ],
            "generatedAt": "2026-07-15T18:17:00Z"
        ],
        to: transitionEvidence
    )
    let transitionEvidenceDigest = try sha256OfFile(at: transitionEvidence)
    fileURLs.append(transitionEvidence)

    let matrix = payload.appendingPathComponent("matrix.json")
    try writeJSON(
        [
            "ok": true,
            "fullyValidated": true,
            "completeRouteSet": true,
            "routeCount": testFlightVisualRoutes.count,
            "expectedRouteCount": testFlightVisualRoutes.count,
            "expectedRoutes": testFlightVisualRoutes,
            "selectedRoutes": testFlightVisualRoutes,
            "buildBlocked": false,
            "buildBlocker": NSNull(),
            "provenanceVerifiedBefore": true,
            "provenanceVerifiedAfter": true,
            "provenanceManifestSha256": provenanceDigest,
            "transitionEvidenceValidated": true,
            "transitionEvidencePath": "transition-evidence.json",
            "transitionEvidenceSha256": transitionEvidenceDigest,
            "transitionEvidenceLogPath": "transition-evidence.log",
            "transitionEvidenceLogSha256": transitionLogDigest,
            "sourceSha": sourceSHA,
            "sourceTree": testFlightVisualSourceTree,
            "routes": matrixRows,
            "failedRoutes": [],
            "blockedRoutes": [],
            "missingDesignReviewRoutes": [],
            "missingScreenshotRoutes": [],
            "missingRoutes": [],
            "duplicateRoutes": [],
            "unexpectedRoutes": []
        ],
        to: matrix
    )
    fileURLs.append(matrix)

    let results = payload.appendingPathComponent("matrix.jsonl")
    let resultLines = try matrixRows.map { row in
        let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }.joined(separator: "\n") + "\n"
    try resultLines.write(to: results, atomically: true, encoding: .utf8)
    fileURLs.append(results)

    let files: [[String: Any]] = try fileURLs.map { url in
        let data = try Data(contentsOf: url)
        let relative = url.path.replacingOccurrences(of: artifact.path + "/", with: "")
        return [
            "path": relative,
            "bytes": data.count,
            "sha256": try sha256OfFile(at: url)
        ]
    }.sorted { ($0["path"] as! String) < ($1["path"] as! String) }
    let manifest = artifact.appendingPathComponent("visual-evidence-manifest.json")
    try writeJSON(
        [
            "schemaVersion": 1,
            "identity": [
                "sourceSha": sourceSHA,
                "sourceTree": testFlightVisualSourceTree,
                "workflowRunId": runID,
                "workflowRunAttempt": runAttempt,
                "workflowJob": "native-visual-evidence"
            ],
            "matrix": [
                "summary": "payload/matrix.json",
                "results": "payload/matrix.jsonl",
                "provenance": "payload/provenance.json",
                "transitionEvidence": "payload/transition-evidence.json",
                "transitionEvidenceLog": "payload/transition-evidence.log",
                "expectedRouteCount": testFlightVisualRoutes.count,
                "routes": manifestRoutes
            ],
            "files": files
        ],
        to: manifest
    )
    return TestFlightVisualArtifactFixture(
        name: "native-visual-evidence-\(sourceSHA)-\(runID)-\(runAttempt)",
        artifactDigest: "sha256:\(String(repeating: "e", count: 64))",
        manifestDigest: try sha256OfFile(at: manifest)
    )
}

private func sha256OfFile(at url: URL) throws -> String {
    #if canImport(CryptoKit)
    let digest = SHA256.hash(data: try Data(contentsOf: url))
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
    process.arguments = ["-a", "256", url.path]
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let result = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    guard process.terminationStatus == 0, let digest = result.split(separator: " ").first else {
        throw TestFlightVisualFixtureError.hashFailure(result)
    }
    return String(digest)
    #endif
}

private enum TestFlightVisualFixtureError: Error {
    case hashFailure(String)
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
