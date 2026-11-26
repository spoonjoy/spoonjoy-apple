import Foundation

enum JourneySelfHostedServerError: Error, CustomStringConvertible {
    case missingVariable(String)

    var description: String {
        "\(name) is not set. The Self-hosted server job runs a Spoonjoy server beside the simulator and passes its address as TEST_RUNNER_\(name)."
    }

    private var name: String {
        switch self {
        case .missingVariable(let name): name
        }
    }
}

/// The servers the Self-hosted server job runs beside the simulator, which shares the runner's network: a Spoonjoy
/// server built from spoonjoy-v2's self-host/ folder, and a plain web server that is not Spoonjoy. Fails closed.
enum JourneySelfHostedServer {
    static let serverVariable = "SPOONJOY_SELF_HOSTED_SERVER"
    static let notSpoonjoyVariable = "SPOONJOY_NOT_SPOONJOY_SERVER"

    /// The Spoonjoy server's address as a cook types it, such as `localhost:8080`.
    static func address() throws -> String {
        try value(serverVariable)
    }

    /// An address that answers, but not as a Spoonjoy server.
    static func notSpoonjoyAddress() throws -> String {
        try value(notSpoonjoyVariable)
    }

    private static func value(_ name: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            throw JourneySelfHostedServerError.missingVariable(name)
        }
        return value
    }
}
