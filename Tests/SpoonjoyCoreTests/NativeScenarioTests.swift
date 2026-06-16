import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native scenario metadata")
struct NativeScenarioTests {
    private let expectedAppIntents = [
        "SpoonjoyOpenRecipeIntent",
        "SpoonjoyStartCookingIntent",
        "SpoonjoyAddShoppingItemIntent",
        "SpoonjoyCaptureRecipeIntent"
    ]
    private let expectedSpotlightIndexedTypes = ["recipe", "cookbook", "shoppingItem"]
    private let expectedSearchableScopes = ["recipes", "cookbooks", "shopping"]
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
        "https://spoonjoy.app/recipes/{id}",
        "https://spoonjoy.app/recipes/{id}?mode=cook",
        "https://spoonjoy.app/recipes/{id}#cook",
        "https://spoonjoy.app/cookbooks/{id}",
        "https://spoonjoy.app/search?q={query}",
        "https://spoonjoy.app/search?q={query}&scope={recipes|cookbooks|shopping}",
        "https://spoonjoy.app/shopping",
        "https://spoonjoy.app/capture",
        "https://spoonjoy.app/settings",
        "spoonjoy://recipes/{id}",
        "spoonjoy://shopping",
        "spoonjoy://capture"
    ]

    @Test("native metadata report exposes Apple-native capabilities")
    func nativeMetadataReportExposesAppleNativeCapabilities() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)

        #expect(report.ok)
        #expect(report.stage == .nativeMetadata)
        #expect(report.checks == [
            ScenarioCheck(name: "fixture bundle", status: .pass, detail: "Fixture resources are packaged."),
            ScenarioCheck(name: "native metadata", status: .pass, detail: "Apple-native capability metadata is complete."),
            ScenarioCheck(name: "app intents source", status: .pass, detail: "AppIntents integration source is present."),
            ScenarioCheck(name: "spotlight source", status: .pass, detail: "CoreSpotlight integration source is present."),
            ScenarioCheck(name: "deep link metadata", status: .pass, detail: "Associated-domain and custom-scheme routes are declared."),
            ScenarioCheck(name: "app surfaces", status: .pending, detail: "SwiftUI surfaces land in Units 13-16.")
        ])
        #expect(report.nativeCapabilities.appIntents == expectedAppIntents)
        #expect(report.nativeCapabilities.spotlightIndexedTypes == expectedSpotlightIndexedTypes)
        #expect(report.nativeCapabilities.searchableScopes == expectedSearchableScopes)
        #expect(report.nativeCapabilities.shareActions == expectedShareActions)
        #expect(report.nativeCapabilities.offlineFlows == expectedOfflineFlows)
        #expect(report.nativeCapabilities.associatedDomains == expectedAssociatedDomains)
        #expect(report.nativeCapabilities.urlSchemes == expectedURLSchemes)
        #expect(report.nativeCapabilities.deepLinkRoutes == expectedDeepLinkRoutes)
    }

    @Test("native metadata report encoding is deterministic")
    func nativeMetadataReportEncodingIsDeterministic() throws {
        let report = try ScenarioReporter.report(for: .nativeMetadata)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let first = try #require(String(data: try encoder.encode(report), encoding: .utf8))
        let second = try #require(String(data: try encoder.encode(report), encoding: .utf8))

        #expect(first == second)
        #expect(first.contains(#""stage" : "native-metadata""#))
        #expect(first.contains(#""associatedDomains" : ["#))
        #expect(first.contains(#""applinks:spoonjoy.app""#))
        #expect(first.contains(#""urlSchemes" : ["#))
        #expect(first.contains(#""spoonjoy""#))
    }

    @Test("native metadata command parses stage and output path")
    func nativeMetadataCommandParsesStageAndOutputPath() throws {
        let command = try ScenarioCommand.parse(arguments: [
            "--stage", "native-metadata",
            "--output", "/tmp/spoonjoy-native-metadata.json"
        ])

        #expect(command == ScenarioCommand(stage: .nativeMetadata, outputPath: "/tmp/spoonjoy-native-metadata.json"))
    }

    @Test("app integration sources declare compile guards and expected symbols")
    func appIntegrationSourcesDeclareCompileGuardsAndExpectedSymbols() throws {
        let appIntentsSource = try readRepoFile("Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift")
        let spotlightSource = try readRepoFile("Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift")

        for token in [
            "#if canImport(AppIntents)",
            "import AppIntents",
            "@available(iOS 27.0, macOS 27.0, *)",
            "SpoonjoyOpenRecipeIntent",
            "SpoonjoyStartCookingIntent",
            "SpoonjoyAddShoppingItemIntent",
            "SpoonjoyCaptureRecipeIntent"
        ] {
            #expect(appIntentsSource.contains(token))
        }

        for token in [
            "#if canImport(CoreSpotlight)",
            "import CoreSpotlight",
            "@available(iOS 27.0, macOS 27.0, *)",
            "SpoonjoySpotlightIndexer",
            "CSSearchableItem",
            "CSSearchableItemAttributeSet",
            "recipe",
            "cookbook",
            "shoppingItem"
        ] {
            #expect(spotlightSource.contains(token))
        }
    }

    @Test("verify native scenarios script gates native metadata")
    func verifyNativeScenariosScriptGatesNativeMetadata() throws {
        let script = try readRepoFile("scripts/verify-native-scenarios.sh")

        for token in [
            "swift run -Xswiftc -warnings-as-errors SpoonjoyScenarioVerifier",
            "--stage",
            "--output",
            "native-metadata",
            "associatedDomains",
            "urlSchemes",
            "deepLinkRoutes"
        ] {
            #expect(script.contains(token))
        }
    }

    private func readRepoFile(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
