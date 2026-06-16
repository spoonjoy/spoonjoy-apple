import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native scenario metadata")
struct NativeScenarioTests {
    private let expectedAppIntents = [
        "OpenRecipeIntent",
        "StartCookModeIntent",
        "AddShoppingListItemIntent"
    ]
    private let expectedSpotlightIndexedTypes = ["recipe", "cookbook", "shopping-list-item"]
    private let expectedSearchableScopes = ["all", "recipes", "cookbooks", "chefs", "shopping-list"]
    private let expectedShareActions = ["capture-recipe-url", "share-recipe"]
    private let expectedOfflineFlows = [
        "fixture-offline-restore",
        "shopping-queue-replay",
        "cook-mode-progress-restore"
    ]
    private let expectedAssociatedDomains = ["applinks:spoonjoy.app"]
    private let expectedURLSchemes = ["spoonjoy"]
    private let expectedDeepLinkRoutes = [
        "https://spoonjoy.app/",
        "https://spoonjoy.app/recipes",
        "https://spoonjoy.app/recipes/{id}",
        "https://spoonjoy.app/recipes/{id}#cook",
        "https://spoonjoy.app/recipes/{id}?mode=cook",
        "https://spoonjoy.app/cookbooks",
        "https://spoonjoy.app/cookbooks/{id}",
        "https://spoonjoy.app/shopping-list",
        "https://spoonjoy.app/search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "https://spoonjoy.app/recipes/new",
        "https://spoonjoy.app/account/settings",
        "spoonjoy://kitchen",
        "spoonjoy://recipes",
        "spoonjoy://recipes/{id}",
        "spoonjoy://recipes/{id}/cook",
        "spoonjoy://cookbooks",
        "spoonjoy://cookbooks/{id}",
        "spoonjoy://shopping-list",
        "spoonjoy://search?q={query}&scope={all|recipes|cookbooks|chefs|shopping-list}",
        "spoonjoy://capture",
        "spoonjoy://settings"
    ]

    @Test("native metadata report exposes Apple-native capabilities")
    func nativeMetadataReportExposesAppleNativeCapabilities() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)
        let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

        #expect(report.ok)
        #expect(report.stage == .nativeMetadata)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["app surfaces"])
        #expect(checksByName["fixture bundle"] == .pass)
        #expect(checksByName["native metadata"] == .pass)
        #expect(checksByName["app intents source"] == .pass)
        #expect(checksByName["spotlight source"] == .pass)
        #expect(checksByName["deep link metadata"] == .pass)
        #expect(report.checks.first { $0.name == "app surfaces" }?.detail.contains("Units 14-16") == true)
        #expect(Set(report.nativeCapabilities.appIntents).isSuperset(of: Set(expectedAppIntents)))
        #expect(!report.nativeCapabilities.appIntents.contains { $0.hasPrefix("Spoonjoy") })
        #expect(Set(report.nativeCapabilities.spotlightIndexedTypes).isSuperset(of: Set(expectedSpotlightIndexedTypes)))
        #expect(Set(report.nativeCapabilities.searchableScopes) == Set(expectedSearchableScopes))
        #expect(Set(report.nativeCapabilities.shareActions) == Set(expectedShareActions))
        #expect(Set(report.nativeCapabilities.offlineFlows) == Set(expectedOfflineFlows))
        #expect(report.nativeCapabilities.associatedDomains == expectedAssociatedDomains)
        #expect(report.nativeCapabilities.urlSchemes == expectedURLSchemes)
        #expect(Set(report.nativeCapabilities.deepLinkRoutes) == Set(expectedDeepLinkRoutes))
        #expect(report.nativeCapabilities.deepLinkRoutes.count == expectedDeepLinkRoutes.count)
    }

    @Test("native metadata report encoding is deterministic")
    func nativeMetadataReportEncodingIsDeterministic() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)
        let first = try #require(String(data: try ScenarioCommand.reportData(report), encoding: .utf8))
        let second = try #require(String(data: try ScenarioCommand.reportData(report), encoding: .utf8))

        #expect(first == second)
        #expect(first.contains(#""stage" : "native-metadata""#))
        #expect(first.contains(#""applinks:spoonjoy.app""#))
        #expect(first.contains(#""https:\/\/spoonjoy.app\/shopping-list""#))
        #expect(first.contains(#""spoonjoy:\/\/shopping-list""#))
        #expect(first.contains(#""all""#))
        #expect(first.contains(#""shopping-list""#))
    }

    @Test("surfaces report proves kitchen and recipe detail slice")
    func surfacesReportProvesKitchenAndRecipeDetailSlice() throws {
        let report = try ScenarioReporter.report(for: .surfaces)
        let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

        #expect(report.ok)
        #expect(report.stage == .surfaces)
        #expect(checksByName["fixture kitchen browsing"] == .pass)
        #expect(checksByName["recipe detail"] == .pass)
        #expect(checksByName["kitchen surface source"] == .pass)
        #expect(checksByName["recipe detail surface source"] == .pass)
        #expect(checksByName["navigation surface source"] == .pass)
        #expect(checksByName["later surfaces"] == .pending)
        #expect(report.checks.filter { $0.status == .fail }.isEmpty)
        #expect(Set(report.nativeCapabilities.deepLinkRoutes) == Set(expectedDeepLinkRoutes))
    }

    @Test("surfaces report fails when surface sources are missing")
    func surfacesReportFailsWhenSurfaceSourcesAreMissing() throws {
        try withTemporaryDirectory { directory in
            let report = ScenarioVerifier.surfacesReport(rootURL: directory)
            let checksByName = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.name, $0.status) })

            #expect(!report.ok)
            #expect(checksByName["kitchen surface source"] == .fail)
            #expect(checksByName["recipe detail surface source"] == .fail)
            #expect(checksByName["navigation surface source"] == .fail)
        }
    }

    @Test("scenario command parses surfaces stage")
    func scenarioCommandParsesSurfacesStage() throws {
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "surfaces",
            "--output", "/tmp/spoonjoy-surfaces.json"
        ])

        #expect(command == ScenarioCommand(stage: .surfaces, outputPath: "/tmp/spoonjoy-surfaces.json"))
    }

    @Test("native metadata command parses stage and output path")
    func nativeMetadataCommandParsesStageAndOutputPath() throws {
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "native-metadata",
            "--output", "/tmp/spoonjoy-native-metadata.json"
        ])

        #expect(command == ScenarioCommand(stage: .nativeMetadata, outputPath: "/tmp/spoonjoy-native-metadata.json"))
    }

    @Test("scenario command writes output and supports stdout mode")
    func scenarioCommandWritesOutputAndSupportsStdoutMode() throws {
        try withTemporaryDirectory { directory in
            let outputURL = directory.appendingPathComponent("native-metadata.json")
            let outputReport = try ScenarioCommand.run(arguments: [
                "--stage", "native-metadata",
                "--output", outputURL.path
            ])
            let outputData = try Data(contentsOf: outputURL)
            let decodedReport = try JSONDecoder().decode(ScenarioReport.self, from: outputData)
            let stdoutReport = try ScenarioCommand.run(arguments: ["--stage", "bootstrap"])

            #expect(outputReport.stage == .nativeMetadata)
            #expect(decodedReport == outputReport)
            #expect(stdoutReport == ScenarioReporter.bootstrapReport())
        }
    }

    @Test("scenario verifier covers root override and failing native metadata checks")
    func scenarioVerifierCoversRootOverrideAndFailingNativeMetadataChecks() throws {
        try withTemporaryDirectory { directory in
            let fallbackRoot = ScenarioVerifier.defaultRootURL(
                environment: [:],
                currentDirectoryPath: repoURL.path
            )
            let overrideRoot = ScenarioVerifier.defaultRootURL(
                environment: ["SPOONJOY_SCENARIO_ROOT": "  \(directory.path)  "],
                currentDirectoryPath: repoURL.path
            )
            let missingSourceReport = ScenarioVerifier.nativeMetadataReport(rootURL: directory)
            let missingSourceChecks = Dictionary(uniqueKeysWithValues: missingSourceReport.checks.map { ($0.name, $0.status) })
            let emptyMetadata = NativeCapabilityMetadata(
                appIntents: [],
                spotlightIndexedTypes: [],
                searchableScopes: [],
                shareActions: [],
                offlineFlows: [],
                associatedDomains: [],
                urlSchemes: [],
                deepLinkRoutes: []
            )
            let emptyMetadataReport = ScenarioVerifier.nativeMetadataReport(rootURL: repoURL, metadata: emptyMetadata)
            let emptyMetadataChecks = Dictionary(uniqueKeysWithValues: emptyMetadataReport.checks.map { ($0.name, $0.status) })

            #expect(fallbackRoot.path == repoURL.path)
            #expect(overrideRoot.path == directory.path)
            #expect(!missingSourceReport.ok)
            #expect(missingSourceChecks["app intents source"] == .fail)
            #expect(missingSourceChecks["spotlight source"] == .fail)
            #expect(!emptyMetadataReport.ok)
            #expect(emptyMetadataChecks["native metadata"] == .fail)
            #expect(emptyMetadataChecks["deep link metadata"] == .fail)
        }
    }

    @Test("app integration sources typecheck and declare expected native types")
    func appIntegrationSourcesTypecheckAndDeclareExpectedNativeTypes() throws {
        let appIntentsPath = "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift"
        let spotlightPath = "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
        let appIntentsSource = try readRepoFile(appIntentsPath)
        let spotlightSource = try readRepoFile(spotlightPath)

        for declaration in [
            "struct OpenRecipeIntent: AppIntent",
            "struct StartCookModeIntent: AppIntent",
            "struct AddShoppingListItemIntent: AppIntent"
        ] {
            #expect(appIntentsSource.contains(declaration))
        }
        #expect(appIntentsSource.contains("#if canImport(AppIntents)"))
        #expect(appIntentsSource.contains("import AppIntents"))
        #expect(appIntentsSource.contains("@available(iOS 27.0, macOS 27.0, *)"))

        for declaration in [
            "struct SpoonjoySpotlightIndexer",
            "CSSearchableItem",
            "CSSearchableItemAttributeSet",
            "shopping-list-item"
        ] {
            #expect(spotlightSource.contains(declaration))
        }
        #expect(spotlightSource.contains("#if canImport(CoreSpotlight)"))
        #expect(spotlightSource.contains("import CoreSpotlight"))
        #expect(spotlightSource.contains("@available(iOS 27.0, macOS 27.0, *)"))

        try assertSwiftSourceTypechecks(appIntentsPath)
        try assertSwiftSourceTypechecks(spotlightPath)
    }

    @Test("verify native scenarios script gates native metadata behavior")
    func verifyNativeScenariosScriptGatesNativeMetadataBehavior() throws {
        let scriptPath = "scripts/verify-native-scenarios.sh"
        let scriptURL = repoURL.appendingPathComponent(scriptPath)
        let attributes = try FileManager.default.attributesOfItem(atPath: scriptURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber).intValue

        #expect(permissions & 0o111 != 0)

        try withTemporaryDirectory { directory in
            let outputURL = directory.appendingPathComponent("native-metadata.json")
            let scratchURL = directory.appendingPathComponent("swiftpm-scratch")
            let success = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata", "--output", outputURL.path],
                environment: ["SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path],
                currentDirectoryURL: repoURL
            )

            #expect(success.exitCode == 0, Comment(rawValue: success.combinedOutput))

            let data = try Data(contentsOf: outputURL)
            let report = try JSONDecoder().decode(ScenarioReport.self, from: data)
            #expect(report.ok)
            #expect(report.stage == .nativeMetadata)
            #expect(report.checks.filter { $0.status == .fail }.isEmpty)
            #expect(report.checks.filter { $0.status == .pending }.map(\.name) == ["app surfaces"])

            let missingSourceRoot = directory.appendingPathComponent("missing-source-root")
            try FileManager.default.createDirectory(at: missingSourceRoot, withIntermediateDirectories: true)
            let missingOutputURL = directory.appendingPathComponent("native-metadata-missing.json")
            let failure = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata", "--output", missingOutputURL.path],
                environment: [
                    "SPOONJOY_SCENARIO_ROOT": missingSourceRoot.path,
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path
                ],
                currentDirectoryURL: repoURL
            )

            #expect(failure.exitCode != 0)
            #expect(failure.combinedOutput.contains("app intents source"))
            #expect(failure.combinedOutput.contains("spotlight source"))

            let surfacesOutputURL = directory.appendingPathComponent("surfaces.json")
            let surfaces = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "surfaces", "--output", surfacesOutputURL.path],
                environment: ["SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path],
                currentDirectoryURL: repoURL
            )
            let surfacesData = try Data(contentsOf: surfacesOutputURL)
            let surfacesReport = try JSONDecoder().decode(ScenarioReport.self, from: surfacesData)

            #expect(surfaces.exitCode == 0, Comment(rawValue: surfaces.combinedOutput))
            #expect(surfacesReport.ok)
            #expect(surfacesReport.stage == .surfaces)
            #expect(surfacesReport.checks.filter { $0.status == .pending }.map(\.name) == ["later surfaces"])

            let defaultOutputDirectory = directory.appendingPathComponent("default-output", isDirectory: true)
            try FileManager.default.createDirectory(at: defaultOutputDirectory, withIntermediateDirectories: true)
            let firstDefaultOutput = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata"],
                environment: [
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path,
                    "TMPDIR": defaultOutputDirectory.path + "/"
                ],
                currentDirectoryURL: repoURL
            )
            let secondDefaultOutput = try runProcess(
                scriptURL.path,
                arguments: ["--stage", "native-metadata"],
                environment: [
                    "SPOONJOY_SCENARIO_SCRATCH_PATH": scratchURL.path,
                    "TMPDIR": defaultOutputDirectory.path + "/"
                ],
                currentDirectoryURL: repoURL
            )
            let defaultArtifacts = try FileManager.default.contentsOfDirectory(
                atPath: defaultOutputDirectory.path
            ).filter {
                $0.hasPrefix("spoonjoy-scenario-native-metadata.") && $0.hasSuffix(".json")
            }

            #expect(firstDefaultOutput.exitCode == 0, Comment(rawValue: firstDefaultOutput.combinedOutput))
            #expect(secondDefaultOutput.exitCode == 0, Comment(rawValue: secondDefaultOutput.combinedOutput))
            #expect(defaultArtifacts.count == 2)
        }
    }

    private var repoURL: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func readRepoFile(_ relativePath: String) throws -> String {
        let url = repoURL.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertSwiftSourceTypechecks(_ relativePath: String) throws {
        let result = try runProcess(
            "/usr/bin/xcrun",
            arguments: ["swiftc", "-typecheck", "-warnings-as-errors", repoURL.appendingPathComponent(relativePath).path],
            currentDirectoryURL: repoURL
        )

        #expect(result.exitCode == 0, Comment(rawValue: result.combinedOutput))
    }

    private func runProcess(
        _ executablePath: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectoryURL: URL
    ) throws -> ProcessResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = output
        process.standardError = error
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, output: outputText, error: errorText)
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("spoonjoy-native-scenario-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try body(directory)
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
    let error: String

    var combinedOutput: String {
        output + error
    }
}
