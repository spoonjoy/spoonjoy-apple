import Foundation
import Testing

@Suite("Native repository hygiene guard contract")
struct NativeRepositoryHygieneContractTests {
    @Test("audit rejects tracked generated validation evidence while preserving durable source")
    func auditRejectsTrackedGeneratedEvidenceWhilePreservingDurableSource() throws {
        try withRepositoryHygieneFixture(
            trackedFiles: [
                "apple/unit-10d-native-repository-hygiene-red.log",
                "apple/matrix-route-matrix.json",
                "codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-validation/apple/matrix-macos-launch-env-backup.env",
                "codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-1e-validation/screenshots/ios-mobile.png",
                "codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-3f/before-yield-scale-fix/ios-mobile.png",
                "codex-native/tasks/2026-07-09-1243-doing-native-full-moon/unit-4i/contact-ios.png",
                "tasks/2026-06-16-1754-doing-siri-full-access-parity/apple/unit-21f-shopping-entities-review-diff.patch",
                "apple/unit-22k-cookbook-intents-review-arendt.md",
                "docs/native-design-language.md",
                "Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/Contents.json",
                "Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/sj-1024.png",
                "Sources/SpoonjoyCore/Fixtures/recipes-fixture.json",
                "Tests/SpoonjoyCoreTests/Fixtures/default-camera.heic"
            ],
            changedFiles: [
                HygieneChangedFile(path: "apple/unit-10d-native-repository-hygiene-red.log", additions: 5, deletions: 0)
            ],
            prBody: """
            ## Summary
            Repository hygiene policy is being tested.
            """
        ) { fixture in
            let result = try runRepositoryHygieneAudit(fixture: fixture)

            #expect(result.status != 0, Comment(rawValue: result.output))
            #expect(result.output.contains("tracked generated validation artifact"), Comment(rawValue: result.output))
            #expect(result.output.contains("apple/unit-10d-native-repository-hygiene-red.log"), Comment(rawValue: result.output))
            #expect(result.output.contains("matrix-macos-launch-env-backup.env"), Comment(rawValue: result.output))
            #expect(result.output.contains("before-yield-scale-fix/ios-mobile.png"), Comment(rawValue: result.output))
            #expect(result.output.contains("contact-ios.png"), Comment(rawValue: result.output))
            #expect(result.output.contains("unit-21f-shopping-entities-review-diff.patch"), Comment(rawValue: result.output))

            let manifest = try readRepositoryHygieneManifest(fixture: fixture)
            let preservedMarkdown = try manifest.stringArray(at: ["repoHygiene", "preservedDurableMarkdown"])
            #expect(preservedMarkdown.contains("apple/unit-22k-cookbook-intents-review-arendt.md"))
            #expect(preservedMarkdown.contains("docs/native-design-language.md"))

            let allowedImages = try manifest.stringArray(at: ["repoHygiene", "allowedImageFixtures"])
            #expect(allowedImages.contains("Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/sj-1024.png"))
            #expect(allowedImages.contains("Tests/SpoonjoyCoreTests/Fixtures/default-camera.heic"))

            let allowedJSON = try manifest.stringArray(at: ["repoHygiene", "allowedStructuredFixtures"])
            #expect(allowedJSON.contains("Apps/Spoonjoy/Shared/Assets.xcassets/AppIcon.appiconset/Contents.json"))
            #expect(allowedJSON.contains("Sources/SpoonjoyCore/Fixtures/recipes-fixture.json"))
        }
    }

    @Test("audit passes when validation evidence is external and PR-size manifest is present")
    func auditPassesWithExternalEvidenceAndPRManifest() throws {
        let changedFiles = (1...80).map { index in
            HygieneChangedFile(path: "Sources/SpoonjoyCore/Hygiene/File\(index).swift", additions: 75, deletions: 30)
        }

        try withRepositoryHygieneFixture(
            trackedFiles: [
                "docs/native-repository-hygiene-removal-manifest.md",
                "Apps/Spoonjoy/Shared/Assets.xcassets/LemonPantryPasta.imageset/lemon-pantry-pasta.png",
                "Tests/SpoonjoyCoreTests/Fixtures/default-camera.heic",
                "Sources/SpoonjoyCore/Fixtures/kitchen-fixture.json"
            ],
            changedFiles: changedFiles,
            prBody: """
            ## Summary
            Native repository hygiene cleanup.

            ## Repository Hygiene Manifest
            - Removal manifest: docs/native-repository-hygiene-removal-manifest.md
            - External evidence root: artifacts/apple/native-repository-hygiene
            - Recovery: git restore --source <pre-cleanup-ref> -- <path>
            """
        ) { fixture in
            let result = try runRepositoryHygieneAudit(fixture: fixture)

            #expect(result.status == 0, Comment(rawValue: result.output))
            #expect(result.output.contains("native repository hygiene audit ok"), Comment(rawValue: result.output))

            let manifest = try readRepositoryHygieneManifest(fixture: fixture)
            #expect(try manifest.bool(at: ["repoHygiene", "ok"]))
            #expect(try manifest.bool(at: ["repoHygiene", "externalEvidence", "ignoredByGit"]))
            #expect(try manifest.bool(at: ["repoHygiene", "prSize", "manifestPresent"]))
            #expect(try manifest.bool(at: ["repoHygiene", "prSize", "thresholdExceeded"]))
        }
    }

    @Test("audit fails oversized pull requests without a human-readable manifest")
    func auditFailsOversizedPullRequestsWithoutManifest() throws {
        let changedFiles = (1...121).map { index in
            HygieneChangedFile(path: "Sources/SpoonjoyCore/Hygiene/Oversized\(index).swift", additions: 1, deletions: 0)
        }

        try withRepositoryHygieneFixture(
            trackedFiles: [
                "Sources/SpoonjoyCore/Fixtures/shopping-list-fixture.json"
            ],
            changedFiles: changedFiles,
            prBody: """
            ## Summary
            Large native cleanup without its manifest.
            """
        ) { fixture in
            let result = try runRepositoryHygieneAudit(fixture: fixture)

            #expect(result.status != 0, Comment(rawValue: result.output))
            #expect(result.output.contains("PR size threshold exceeded without Repository Hygiene Manifest"), Comment(rawValue: result.output))
        }
    }
}

private struct HygieneChangedFile {
    let path: String
    let additions: Int
    let deletions: Int
}

private struct RepositoryHygieneFixture {
    let root: URL
    let trackedFiles: URL
    let changedFiles: URL
    let prBody: URL
    let artifactRoot: URL
    let manifest: URL
}

private struct RepositoryHygieneResult {
    let status: Int32
    let output: String
}

private enum RepositoryHygieneContractError: Error {
    case missingManifest
    case malformedManifest
    case missingPath([String])
    case wrongType([String])
}

private typealias RepositoryHygieneManifest = [String: Any]

private func withRepositoryHygieneFixture(
    trackedFiles: [String],
    changedFiles: [HygieneChangedFile],
    prBody: String,
    body: (RepositoryHygieneFixture) throws -> Void
) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("spoonjoy-native-repo-hygiene-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let trackedFilesURL = root.appendingPathComponent("tracked-files.txt")
    let changedFilesURL = root.appendingPathComponent("changed-files.tsv")
    let prBodyURL = root.appendingPathComponent("pr-body.md")
    let artifactRootURL = root
        .appendingPathComponent("artifacts", isDirectory: true)
        .appendingPathComponent("apple", isDirectory: true)
        .appendingPathComponent("native-repository-hygiene", isDirectory: true)
    let manifestURL = root.appendingPathComponent("manifest.json")

    try trackedFiles.sorted().joined(separator: "\n").appending("\n").write(
        to: trackedFilesURL,
        atomically: true,
        encoding: .utf8
    )
    let changedText = changedFiles
        .map { "\($0.additions)\t\($0.deletions)\t\($0.path)" }
        .joined(separator: "\n")
        .appending("\n")
    try changedText.write(to: changedFilesURL, atomically: true, encoding: .utf8)
    try prBody.write(to: prBodyURL, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(at: artifactRootURL, withIntermediateDirectories: true)

    try body(RepositoryHygieneFixture(
        root: root,
        trackedFiles: trackedFilesURL,
        changedFiles: changedFilesURL,
        prBody: prBodyURL,
        artifactRoot: artifactRootURL,
        manifest: manifestURL
    ))
}

private func runRepositoryHygieneAudit(fixture: RepositoryHygieneFixture) throws -> RepositoryHygieneResult {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
    process.arguments = [
        repositoryHygieneRepoRoot().appendingPathComponent("scripts/audit-native-validation-artifacts.rb").path,
        "--repo-hygiene-only",
        "--tracked-files", fixture.trackedFiles.path,
        "--changed-files", fixture.changedFiles.path,
        "--pr-body", fixture.prBody.path,
        "--artifact-root", fixture.artifactRoot.path,
        "--manifest", fixture.manifest.path
    ]
    process.currentDirectoryURL = repositoryHygieneRepoRoot()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()

    return RepositoryHygieneResult(
        status: process.terminationStatus,
        output: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
}

private func readRepositoryHygieneManifest(fixture: RepositoryHygieneFixture) throws -> RepositoryHygieneManifest {
    guard FileManager.default.fileExists(atPath: fixture.manifest.path) else {
        throw RepositoryHygieneContractError.missingManifest
    }
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.manifest))
    guard let manifest = object as? RepositoryHygieneManifest else {
        throw RepositoryHygieneContractError.malformedManifest
    }
    return manifest
}

private func repositoryHygieneRepoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private extension Dictionary where Key == String, Value == Any {
    func bool(at path: [String]) throws -> Bool {
        guard let value = try value(at: path) as? Bool else {
            throw RepositoryHygieneContractError.wrongType(path)
        }
        return value
    }

    func stringArray(at path: [String]) throws -> [String] {
        guard let value = try value(at: path) as? [String] else {
            throw RepositoryHygieneContractError.wrongType(path)
        }
        return value
    }

    private func value(at path: [String]) throws -> Any {
        var current: Any = self
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                throw RepositoryHygieneContractError.missingPath(path)
            }
            current = next
        }
        return current
    }
}
