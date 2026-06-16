import Foundation

public enum ScenarioReporter {
    public static func report(for stage: ScenarioStage) throws -> ScenarioReport {
        try ScenarioVerifier.report(for: stage, rootURL: ScenarioVerifier.defaultRootURL)
    }

    public static func bootstrapReport() -> ScenarioReport {
        ScenarioVerifier.bootstrapReport()
    }
}

public enum ScenarioVerifier {
    public static var defaultRootURL: URL {
        defaultRootURL(
            environment: ProcessInfo.processInfo.environment,
            currentDirectoryPath: FileManager.default.currentDirectoryPath
        )
    }

    public static func defaultRootURL(environment: [String: String], currentDirectoryPath: String) -> URL {
        let override = environment["SPOONJOY_SCENARIO_ROOT"] ?? ""
        let trimmedOverride = override.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedOverride.isEmpty {
            return URL(fileURLWithPath: trimmedOverride)
        }

        return URL(fileURLWithPath: currentDirectoryPath)
    }

    public static func report(
        for stage: ScenarioStage,
        rootURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> ScenarioReport {
        switch stage {
        case .bootstrap:
            return bootstrapReport()
        case .nativeMetadata:
            return nativeMetadataReport(rootURL: rootURL)
        case .surfaces, .final:
            throw ScenarioCommandError.unsupportedStage(stage)
        }
    }

    public static func bootstrapReport() -> ScenarioReport {
        ScenarioReport(
            stage: .bootstrap,
            checks: [
                ScenarioCheck(name: "fixture bundle", status: .pass, detail: "Fixture resources are packaged."),
                ScenarioCheck(name: "native metadata", status: .pending, detail: "Native metadata lands in Unit 10."),
                ScenarioCheck(name: "app surfaces", status: .pending, detail: "SwiftUI surfaces land in Units 13-16.")
            ],
            nativeCapabilities: ScenarioNativeCapabilities(
                appIntents: [],
                spotlightIndexedTypes: [],
                searchableScopes: [],
                shareActions: [],
                offlineFlows: ["fixture-offline-restore"],
                associatedDomains: [],
                urlSchemes: [],
                deepLinkRoutes: []
            )
        )
    }

    public static func nativeMetadataReport(
        rootURL: URL,
        metadata: NativeCapabilityMetadata = .spoonjoy
    ) -> ScenarioReport {
        return ScenarioReport(
            stage: .nativeMetadata,
            checks: [
                ScenarioCheck(name: "fixture bundle", status: .pass, detail: "Fixture resources are packaged."),
                ScenarioCheck(name: "native metadata", status: metadataCheckStatus(metadata), detail: "Apple-native capability metadata is complete."),
                sourceCheck(
                    name: "app intents source",
                    detail: "AppIntents integration source is present.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    tokens: [
                        "#if canImport(AppIntents)",
                        "import AppIntents",
                        "@available(iOS 27.0, macOS 27.0, *)",
                        "OpenRecipeIntent",
                        "StartCookModeIntent",
                        "AddShoppingListItemIntent"
                    ]
                ),
                sourceCheck(
                    name: "spotlight source",
                    detail: "CoreSpotlight integration source is present.",
                    rootURL: rootURL,
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift",
                    tokens: [
                        "#if canImport(CoreSpotlight)",
                        "import CoreSpotlight",
                        "@available(iOS 27.0, macOS 27.0, *)",
                        "SpoonjoySpotlightIndexer",
                        "CSSearchableItem",
                        "CSSearchableItemAttributeSet",
                        "recipe",
                        "cookbook",
                        "shopping-list-item"
                    ]
                ),
                ScenarioCheck(
                    name: "deep link metadata",
                    status: deepLinkCheckStatus(metadata),
                    detail: "Associated-domain and custom-scheme routes are declared."
                ),
                ScenarioCheck(name: "app surfaces", status: .pending, detail: "SwiftUI surfaces land in Units 14-16.")
            ],
            nativeCapabilities: metadata.scenarioCapabilities
        )
    }

    private static func metadataCheckStatus(_ metadata: NativeCapabilityMetadata) -> ScenarioCheckStatus {
        [
            metadata.appIntents,
            metadata.spotlightIndexedTypes,
            metadata.searchableScopes,
            metadata.shareActions,
            metadata.offlineFlows
        ].allSatisfy { !$0.isEmpty } ? .pass : .fail
    }

    private static func deepLinkCheckStatus(_ metadata: NativeCapabilityMetadata) -> ScenarioCheckStatus {
        let hasAssociatedDomain = metadata.associatedDomains == ["applinks:\(DeepLinkManifest.webDomain)"]
        let hasScheme = metadata.urlSchemes == DeepLinkManifest.urlSchemes
        let hasWebRoutes = metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/recipes/{id}") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/recipes/{id}#cook") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/shopping-list") &&
            metadata.deepLinkRoutes.contains("https://\(DeepLinkManifest.webDomain)/account/settings")
        let hasSchemeRoutes = metadata.deepLinkRoutes.contains("spoonjoy://recipes/{id}") &&
            metadata.deepLinkRoutes.contains("spoonjoy://recipes/{id}/cook") &&
            metadata.deepLinkRoutes.contains("spoonjoy://shopping-list")

        return hasAssociatedDomain && hasScheme && hasWebRoutes && hasSchemeRoutes ? .pass : .fail
    }

    private static func sourceCheck(
        name: String,
        detail: String,
        rootURL: URL,
        relativePath: String,
        tokens: [String]
    ) -> ScenarioCheck {
        let sourceURL = rootURL.appendingPathComponent(relativePath)
        guard
            let source = try? String(contentsOf: sourceURL, encoding: .utf8),
            tokens.allSatisfy(source.contains)
        else {
            return ScenarioCheck(name: name, status: .fail, detail: detail)
        }

        return ScenarioCheck(name: name, status: .pass, detail: detail)
    }
}
