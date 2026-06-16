import Foundation

public enum ScenarioStage: String, CaseIterable, Codable, Sendable {
    case bootstrap
    case nativeMetadata = "native-metadata"
    case surfaces
    case final
}

public enum ScenarioCheckStatus: String, Codable, Sendable {
    case pass
    case fail
    case pending
}

public struct ScenarioCheck: Codable, Equatable, Sendable {
    public let name: String
    public let status: ScenarioCheckStatus
    public let detail: String

    public init(name: String, status: ScenarioCheckStatus, detail: String) {
        self.name = name
        self.status = status
        self.detail = detail
    }
}

public struct ScenarioNativeCapabilities: Codable, Equatable, Sendable {
    public let appIntents: [String]
    public let spotlightIndexedTypes: [String]
    public let searchableScopes: [String]
    public let shareActions: [String]
    public let offlineFlows: [String]
    public let associatedDomains: [String]
    public let urlSchemes: [String]
    public let deepLinkRoutes: [String]

    public init(
        appIntents: [String],
        spotlightIndexedTypes: [String],
        searchableScopes: [String],
        shareActions: [String],
        offlineFlows: [String],
        associatedDomains: [String],
        urlSchemes: [String],
        deepLinkRoutes: [String]
    ) {
        self.appIntents = appIntents
        self.spotlightIndexedTypes = spotlightIndexedTypes
        self.searchableScopes = searchableScopes
        self.shareActions = shareActions
        self.offlineFlows = offlineFlows
        self.associatedDomains = associatedDomains
        self.urlSchemes = urlSchemes
        self.deepLinkRoutes = deepLinkRoutes
    }
}

public struct ScenarioReport: Codable, Equatable, Sendable {
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

public enum ScenarioCommandError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case unknownArgument(String)
    case unknownStage(String)
    case unsupportedStage(ScenarioStage)

    public var description: String {
        switch self {
        case .missingValue(let argument):
            "Missing value for \(argument)."
        case .unknownArgument(let argument):
            "Unknown argument \(argument)."
        case .unknownStage(let stage):
            "Unknown scenario stage \(stage)."
        case .unsupportedStage(let stage):
            "Scenario stage \(stage.rawValue) is not implemented in bootstrap."
        }
    }
}
