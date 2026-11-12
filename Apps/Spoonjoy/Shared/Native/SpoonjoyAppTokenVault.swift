import Foundation
import SpoonjoyCore

/// The token vault the app signs in with, for the app and for every App Intent and entity query in its process.
///
/// A Release build keeps the session in the keychain. A debug build keeps it where its launch environment says (a file
/// by default), and Siri has to read it from there too: with a keychain vault of their own, the intents found no
/// session in a debug build and answered as if the cook were signed out (Journeys run 43113155646).
enum SpoonjoyAppTokenVault {
    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> any TokenVault {
#if DEBUG
        screenshotValidationVault(environment: environment) ?? debugVault(
            environment: environment,
            appDirectory: NativeAppStateLocation.defaultFileURL().deletingLastPathComponent()
        )
#else
        KeychainTokenVault()
#endif
    }
#if DEBUG

    private static func screenshotValidationVault(environment: [String: String]) -> (any TokenVault)? {
        guard truthy("SPOONJOY_SCREENSHOT_AUTH", in: environment) else {
            return nil
        }
        let accountID = environment["SPOONJOY_SCREENSHOT_ACCOUNT_ID"] ?? "chef_settings_capture"
        guard let session = try? AuthSession(
            clientID: "cm_screenshot_validation",
            accessToken: "screenshot_access_token",
            refreshToken: "screenshot_refresh_token",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            scope: NativeAuthSession.defaultScope,
            accountID: accountID
        ) else {
            return nil
        }
        return SpoonjoyScreenshotValidationTokenVault(
            clientID: "cm_screenshot_validation",
            session: session
        )
    }

    private static func debugVault(environment: [String: String], appDirectory: URL) -> any TokenVault {
        if truthy("SPOONJOY_DEBUG_KEYCHAIN_AUTH", in: environment) {
            return KeychainTokenVault(allowsUnsignedLocalFallback: true)
        }
        return FileBackedTokenVault(fileURL: appDirectory.appendingPathComponent("debug-auth-session.json"))
    }

    private static func truthy(_ key: String, in environment: [String: String]) -> Bool {
        switch environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            true
        default:
            false
        }
    }
#endif
}

#if DEBUG
private actor SpoonjoyScreenshotValidationTokenVault: TokenVault {
    private var clientID: String?
    private var session: AuthSession?

    init(clientID: String, session: AuthSession) {
        self.clientID = clientID
        self.session = session
    }

    func loadClientID() async throws -> String? {
        clientID
    }

    func saveClientID(_ clientID: String) async throws {
        self.clientID = clientID
    }

    func clearClientID() async throws {
        clientID = nil
    }

    func loadSession() async throws -> AuthSession? {
        session
    }

    func saveSession(_ session: AuthSession) async throws {
        self.session = session
    }

    func clearSession() async throws {
        session = nil
    }
}
#endif

/// The server the app signs in to, for the app and for every App Intent in its process; it sits beside the vault
/// because a session only works on the server that issued it.
///
/// A Release build always talks to spoonjoy.app. A debug build may be pointed elsewhere by `SPOONJOY_API_BASE_URL`
/// (the journeys point it at QA), and Siri has to follow: with spoonjoy.app of their own, the intents sent QA's session
/// to production, and a shopping item Siri added never reached QA's list (Journeys run 43201022926).
enum SpoonjoyAppServer {
    static func configuration(environment: [String: String] = ProcessInfo.processInfo.environment) -> APIClientConfiguration {
#if DEBUG
        if let rawURL = environment["SPOONJOY_API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty,
           let baseURL = URL(string: rawURL) {
            return APIClientConfiguration(baseURL: baseURL)
        }
#endif
        return .spoonjoyProduction
    }
}
