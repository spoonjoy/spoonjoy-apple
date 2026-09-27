import Foundation

struct JourneyAccount: Sendable {
    let email: String
    let username: String
    let password: String
}

enum JourneyAccountsError: Error, CustomStringConvertible {
    case missingVariable(String)
    case unreadableFile(String)
    case missingAccount(Int)

    var description: String {
        switch self {
        case .missingVariable(let name):
            "\(name) is not set. The Journeys workflow creates the QA accounts and passes the path of their file as TEST_RUNNER_\(name); journeys never fall back to other accounts."
        case .unreadableFile(let path):
            "The journey accounts file at \(path) is missing or is not the JSON the account script writes."
        case .missingAccount(let number):
            "The journey accounts file has no account \(number)."
        }
    }
}

/// Reads the per-run QA accounts the Journeys workflow created. The test runner receives only the
/// path of the runner-local accounts file, never a credential value, so the result bundle's recorded
/// test environment holds no password. Fails closed when anything is missing.
enum JourneyAccounts {
    static let fileVariable = "SPOONJOY_JOURNEY_ACCOUNTS_FILE"

    private struct AccountsFile: Decodable {
        struct Entry: Decodable {
            let email: String
            let username: String
            let password: String
        }

        let runToken: String
        let accounts: [Entry]
    }

    static func account(_ number: Int) throws -> JourneyAccount {
        let accounts = try load().accounts
        guard accounts.indices.contains(number - 1) else {
            throw JourneyAccountsError.missingAccount(number)
        }
        let entry = accounts[number - 1]
        return JourneyAccount(email: entry.email, username: entry.username, password: entry.password)
    }

    static func runToken() throws -> String {
        try load().runToken
    }

    private static func load() throws -> AccountsFile {
        guard let path = ProcessInfo.processInfo.environment[fileVariable]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            throw JourneyAccountsError.missingVariable(fileVariable)
        }
        guard let data = FileManager.default.contents(atPath: path),
              let file = try? JSONDecoder().decode(AccountsFile.self, from: data) else {
            throw JourneyAccountsError.unreadableFile(path)
        }
        return file
    }
}
