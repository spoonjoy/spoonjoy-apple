import Foundation

public enum NativeFixtureFallbackPolicy: Equatable, Sendable {
    case disabledInProduction
    case testsAndDemoOnly

    public func allowsProductionFallback(
        isTestOrDemoBuild: Bool,
        environment: [String: String]
    ) -> Bool {
        switch self {
        case .disabledInProduction:
            false
        case .testsAndDemoOnly:
            isTestOrDemoBuild || Self.fixtureFallbackOptIn(environment: environment)
        }
    }

    public func allowsProductionFallback(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        allowsProductionFallback(
            isTestOrDemoBuild: Self.isTestOrDemoBuild(environment: environment),
            environment: environment
        )
    }

    public static func isTestOrDemoBuild(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        hasTruthyValue("SPOONJOY_DEMO_MODE", in: environment) ||
            hasTruthyValue("XCODE_RUNNING_FOR_PREVIEWS", in: environment) ||
            environment["XCTestConfigurationFilePath"] != nil
    }

    private static func fixtureFallbackOptIn(environment: [String: String]) -> Bool {
        hasTruthyValue("SPOONJOY_ALLOW_FIXTURE_FALLBACK", in: environment)
    }

    private static func hasTruthyValue(_ key: String, in environment: [String: String]) -> Bool {
        switch environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }
}
