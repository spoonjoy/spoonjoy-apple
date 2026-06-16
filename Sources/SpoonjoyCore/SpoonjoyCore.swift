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
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try Data(contentsOf: url)
    }
}

public enum ScenarioStage: String, CaseIterable, Codable, Sendable {
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
    public static func report(for stage: ScenarioStage) throws -> ScenarioReport {
        switch stage {
        case .bootstrap:
            return bootstrapReport()
        case .nativeMetadata, .surfaces, .final:
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

public struct ScenarioCommand: Equatable {
    public let stage: ScenarioStage
    public let outputPath: String?

    public init(stage: ScenarioStage, outputPath: String?) {
        self.stage = stage
        self.outputPath = outputPath
    }

    public static func parse(arguments: [String]) throws -> ScenarioCommand {
        var stage = ScenarioStage.bootstrap
        var outputPath: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--stage":
                let rawStage = try value(after: argument, in: arguments, at: index)
                guard let parsedStage = ScenarioStage(rawValue: rawStage) else {
                    throw ScenarioCommandError.unknownStage(rawStage)
                }
                stage = parsedStage
                index += 2
            case "--output":
                outputPath = try value(after: argument, in: arguments, at: index)
                index += 2
            default:
                throw ScenarioCommandError.unknownArgument(argument)
            }
        }

        return ScenarioCommand(stage: stage, outputPath: outputPath)
    }

    private static func value(after argument: String, in arguments: [String], at index: Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw ScenarioCommandError.missingValue(argument)
        }

        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            throw ScenarioCommandError.missingValue(argument)
        }

        return value
    }
}
