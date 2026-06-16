import Foundation

public enum SpoonjoyCore {
    public static let productName = "Spoonjoy"
}

public enum SpoonjoyFixture {
    public static let names = [
        "kitchen-fixture",
        "recipes-fixture",
        "cookbooks-fixture",
        "shopping-list-fixture",
        "offline-snapshot-fixture"
    ]

    public static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try Data(contentsOf: url)
    }
}

public enum ScenarioStage: String, CaseIterable, Codable {
    case bootstrap
    case nativeMetadata = "native-metadata"
    case surfaces
    case final
}

public enum ScenarioCheckStatus: String, Codable {
    case pass
    case fail
    case pending
}

public struct ScenarioCheck: Codable, Equatable {
    public let name: String
    public let status: ScenarioCheckStatus
    public let detail: String

    public init(name: String, status: ScenarioCheckStatus, detail: String) {
        self.name = name
        self.status = status
        self.detail = detail
    }
}

public struct ScenarioNativeCapabilities: Codable, Equatable {
    public let appIntents: [String]
    public let spotlightIndexedTypes: [String]
    public let searchableScopes: [String]
    public let shareActions: [String]
    public let offlineFlows: [String]

    public init(
        appIntents: [String],
        spotlightIndexedTypes: [String],
        searchableScopes: [String],
        shareActions: [String],
        offlineFlows: [String]
    ) {
        self.appIntents = appIntents
        self.spotlightIndexedTypes = spotlightIndexedTypes
        self.searchableScopes = searchableScopes
        self.shareActions = shareActions
        self.offlineFlows = offlineFlows
    }
}

public struct ScenarioReport: Codable, Equatable {
    public let ok: Bool
    public let stage: ScenarioStage
    public let checks: [ScenarioCheck]
    public let nativeCapabilities: ScenarioNativeCapabilities

    public init(stage: ScenarioStage, checks: [ScenarioCheck], nativeCapabilities: ScenarioNativeCapabilities) {
        self.stage = stage
        self.checks = checks
        self.nativeCapabilities = nativeCapabilities
        self.ok = !checks.contains { $0.status == .fail }
    }
}

public enum ScenarioReporter {
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
                offlineFlows: ["fixture-offline-restore"]
            )
        )
    }
}
