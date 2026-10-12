import Foundation
import Testing

@Suite("Release ownership handoff gate contract")
struct ReleaseOwnershipHandoffContractTests {
    private let webSHA = String(repeating: "a", count: 40)
    private let nativeSHA = String(repeating: "b", count: 40)
    private let receiverThreadID = "019f2e25-2fc3-75b2-8ba3-335f3777115a"

    @Test("schema and examples document the required release and acknowledgement records")
    func schemaAndExamplesDocumentRequiredRecords() throws {
        let requiredPaths = [
            "schemas/release-ownership-handoff/owner-release.schema.json",
            "schemas/release-ownership-handoff/receiver-ack.schema.json",
            "schemas/release-ownership-handoff/examples/owner-release.json",
            "schemas/release-ownership-handoff/examples/receiver-ack.json"
        ]

        for path in requiredPaths {
            let content = try readReleaseOwnershipRepoFile(path)
            #expect(content.contains("final_web_sha"), "\(path) must name the final web SHA")
            #expect(content.contains("final_native_sha"), "\(path) must name the final native SHA")
            #expect(content.contains("web_cleanup_owner"), "\(path) must name the cleanup owner")
            #expect(content.contains("testflight_owners"), "\(path) must model exclusive TestFlight ownership")
            #expect(!content.localizedCaseInsensitiveContains("secret"), "\(path) must not carry secret placeholders")
        }
    }

    @Test("validator accepts matching release and acknowledgement records")
    func validatorAcceptsMatchingReleaseAndAck() throws {
        let fixture = try makeReleaseOwnershipFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let result = try runReleaseOwnershipVerifier(fixture: fixture)
        #expect(result.status == 0, Comment(rawValue: result.output))
        #expect(result.output.contains("release ownership handoff ok"), Comment(rawValue: result.output))

        let proofData = try Data(contentsOf: fixture.output)
        let proof = try #require(JSONSerialization.jsonObject(with: proofData) as? [String: Any])
        #expect(proof["ok"] as? Bool == true)
        #expect(proof["final_web_sha"] as? String == webSHA)
        #expect(proof["final_native_sha"] as? String == nativeSHA)
        #expect(proof["web_cleanup_owner"] as? String == receiverThreadID)
        #expect(String(decoding: proofData, as: UTF8.self).contains("https://github.com") == false)
    }

    @Test("validator fails closed on mismatch missing stale duplicate and unacknowledged handoffs")
    func validatorRejectsInvalidHandoffs() throws {
        try expectReleaseOwnershipFailure("handoff field final_web_sha mismatch") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                json["final_web_sha"] = String(repeating: "e", count: 40)
            }
        }

        try expectReleaseOwnershipFailure("receiver-ack missing required field merged_prs") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                json.removeValue(forKey: "merged_prs")
            }
        }

        try expectReleaseOwnershipFailure("stale or non-40-character SHA at final_native_sha") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.release) { json in
                json["final_native_sha"] = "c4d13881"
            }
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                json["final_native_sha"] = "c4d13881"
            }
        }

        try expectReleaseOwnershipFailure("duplicate TestFlight owner") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.release) { json in
                var owners = json["testflight_owners"] as! [[String: Any]]
                owners.append([
                    "thread_id": "019f2e25-2fc3-75b2-8ba3-335f3777115c",
                    "scope": "internal_only_testflight_publication",
                    "exclusive": true
                ])
                json["testflight_owners"] = owners
            }
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                var owners = json["testflight_owners"] as! [[String: Any]]
                owners.append([
                    "thread_id": "019f2e25-2fc3-75b2-8ba3-335f3777115c",
                    "scope": "internal_only_testflight_publication",
                    "exclusive": true
                ])
                json["testflight_owners"] = owners
            }
        }

        try expectReleaseOwnershipFailure("receiver cleanup scope is not acknowledged") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                json["cleanup_scope_acknowledged"] = false
            }
        }

        try expectReleaseOwnershipFailure("zero_in_flight_web_deploys must be true") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.release) { json in
                json["zero_in_flight_web_deploys"] = false
            }
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                json["zero_in_flight_web_deploys"] = false
            }
        }
    }

    @Test("validator reports secret-like input without echoing the value")
    func validatorRedactsSecretLikeInput() throws {
        let secretValue = ["token", "super-private-release-value"].joined(separator: "=")
        try expectReleaseOwnershipFailure("secret-like value detected at residual_work[0].description") { fixture in
            try mutateReleaseOwnershipJSON(at: fixture.release) { json in
                var residual = json["residual_work"] as! [[String: Any]]
                residual[0]["description"] = secretValue
                json["residual_work"] = residual
            }
            try mutateReleaseOwnershipJSON(at: fixture.ack) { json in
                var residual = json["residual_work"] as! [[String: Any]]
                residual[0]["description"] = secretValue
                json["residual_work"] = residual
            }
        } outputCheck: { output in
            #expect(!output.contains(secretValue), Comment(rawValue: output))
        }
    }
}

private struct ReleaseOwnershipFixture {
    let root: URL
    let release: URL
    let ack: URL
    let output: URL
}

private struct ReleaseOwnershipProcessResult {
    let status: Int32
    let output: String
}

private let releaseOwnershipRepoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func readReleaseOwnershipRepoFile(_ relativePath: String) throws -> String {
    try String(
        contentsOf: releaseOwnershipRepoURL.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func makeReleaseOwnershipFixture() throws -> ReleaseOwnershipFixture {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("release-ownership-handoff-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let release = root.appendingPathComponent("owner-release.json")
    let ack = root.appendingPathComponent("receiver-ack.json")
    let output = root.appendingPathComponent("ownership-proof.json")

    let shared = makeSharedReleaseOwnershipFields()
    var ownerRelease = shared
    ownerRelease["schema_version"] = 1
    ownerRelease["handoff_id"] = "audit-release-train-unit-0"
    ownerRelease["releasing_thread_id"] = "019f2e25-2fc3-75b2-8ba3-335f3777115b"
    ownerRelease["releasing_pushed_commit_sha"] = String(repeating: "c", count: 40)
    ownerRelease["released_at"] = "2026-07-16T17:45:00Z"

    var receiverAck = shared
    receiverAck["schema_version"] = 1
    receiverAck["handoff_id"] = "audit-release-train-unit-0"
    receiverAck["receiver_thread_id"] = "019f2e25-2fc3-75b2-8ba3-335f3777115a"
    receiverAck["receiver_pushed_commit_sha"] = String(repeating: "d", count: 40)
    receiverAck["acknowledged_at"] = "2026-07-16T17:50:00Z"
    receiverAck["cleanup_scope_acknowledged"] = true

    try writeReleaseOwnershipJSON(ownerRelease, to: release)
    try writeReleaseOwnershipJSON(receiverAck, to: ack)
    return ReleaseOwnershipFixture(root: root, release: release, ack: ack, output: output)
}

private func makeSharedReleaseOwnershipFields() -> [String: Any] {
    let webSHA = String(repeating: "a", count: 40)
    let nativeSHA = String(repeating: "b", count: 40)
    let receiverThreadID = "019f2e25-2fc3-75b2-8ba3-335f3777115a"

    return [
        "final_web_sha": webSHA,
        "final_native_sha": nativeSHA,
        "merged_prs": [
            [
                "repo": "spoonjoy/spoonjoy-v2",
                "number": 272,
                "url": "https://github.com/spoonjoy/spoonjoy-v2/pull/272",
                "merge_sha": webSHA
            ],
            [
                "repo": "spoonjoy/spoonjoy-apple",
                "number": 52,
                "url": "https://github.com/spoonjoy/spoonjoy-apple/pull/52",
                "merge_sha": nativeSHA
            ]
        ],
        "ci_runs": [
            [
                "repo": "spoonjoy/spoonjoy-v2",
                "workflow": "CI",
                "run_id": 1001,
                "url": "https://github.com/spoonjoy/spoonjoy-v2/actions/runs/1001",
                "head_sha": webSHA,
                "status": "completed",
                "conclusion": "success"
            ],
            [
                "repo": "spoonjoy/spoonjoy-v2",
                "workflow": "Storybook",
                "run_id": 1002,
                "url": "https://github.com/spoonjoy/spoonjoy-v2/actions/runs/1002",
                "head_sha": webSHA,
                "status": "completed",
                "conclusion": "success"
            ],
            [
                "repo": "spoonjoy/spoonjoy-apple",
                "workflow": "Native",
                "run_id": 2001,
                "url": "https://github.com/spoonjoy/spoonjoy-apple/actions/runs/2001",
                "head_sha": nativeSHA,
                "status": "completed",
                "conclusion": "success"
            ]
        ],
        "deployments": [
            [
                "repo": "spoonjoy/spoonjoy-v2",
                "environment": "production",
                "run_id": 3001,
                "url": "https://github.com/spoonjoy/spoonjoy-v2/actions/runs/3001",
                "source_sha": webSHA,
                "status": "success"
            ]
        ],
        "residual_work": [
            [
                "owner_thread_id": receiverThreadID,
                "scope": "release_cleanup",
                "status": "pending",
                "description": "Run inventory-only cleanup after the owner-release barrier."
            ]
        ],
        "zero_in_flight_web_merges": true,
        "zero_in_flight_web_deploys": true,
        "web_cleanup_owner": receiverThreadID,
        "testflight_owners": [
            [
                "thread_id": receiverThreadID,
                "scope": "internal_only_testflight_publication",
                "exclusive": true
            ]
        ]
    ]
}

private func runReleaseOwnershipVerifier(fixture: ReleaseOwnershipFixture) throws -> ReleaseOwnershipProcessResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
    process.arguments = [
        releaseOwnershipRepoURL.appendingPathComponent("scripts/verify-release-ownership-handoff.rb").path,
        "--release", fixture.release.path,
        "--ack", fixture.ack.path,
        "--output", fixture.output.path
    ]
    process.currentDirectoryURL = releaseOwnershipRepoURL
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()

    return ReleaseOwnershipProcessResult(
        status: process.terminationStatus,
        output: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func expectReleaseOwnershipFailure(
    _ message: String,
    mutation: (ReleaseOwnershipFixture) throws -> Void,
    outputCheck: ((String) -> Void)? = nil
) throws {
    let fixture = try makeReleaseOwnershipFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try mutation(fixture)
    let result = try runReleaseOwnershipVerifier(fixture: fixture)
    #expect(result.status != 0, "verifier unexpectedly accepted invalid handoff")
    #expect(result.output.contains(message), "expected \(message.debugDescription), got: \(result.output)")
    outputCheck?(result.output)
}

private func writeReleaseOwnershipJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

private func mutateReleaseOwnershipJSON(at url: URL, mutation: (inout [String: Any]) throws -> Void) throws {
    let data = try Data(contentsOf: url)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    try mutation(&object)
    try writeReleaseOwnershipJSON(object, to: url)
}
