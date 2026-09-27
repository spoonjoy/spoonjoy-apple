import Foundation

struct JourneyAccount: Sendable {
    let email: String
    let username: String
    let password: String
}

enum JourneyAccountsError: Error, CustomStringConvertible {
    case missingVariable(String)

    var description: String {
        switch self {
        case .missingVariable(let name):
            "\(name) is not set. The Journeys workflow creates the QA accounts and passes them as TEST_RUNNER_\(name); journeys never fall back to other accounts."
        }
    }
}

/// Reads the per-run QA accounts the Journeys workflow created. Fails closed when any value is missing.
enum JourneyAccounts {
    static func account(_ number: Int) throws -> JourneyAccount {
        JourneyAccount(
            email: try value("SPOONJOY_JOURNEY_A\(number)_EMAIL"),
            username: try value("SPOONJOY_JOURNEY_A\(number)_USERNAME"),
            password: try value("SPOONJOY_JOURNEY_A\(number)_PASSWORD")
        )
    }

    static func runToken() throws -> String {
        try value("SPOONJOY_JOURNEY_RUN_TOKEN")
    }

    private static func value(_ name: String) throws -> String {
        guard let raw = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            throw JourneyAccountsError.missingVariable(name)
        }
        return raw
    }
}
