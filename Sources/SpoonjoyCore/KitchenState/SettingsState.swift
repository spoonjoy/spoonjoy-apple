import Foundation

public enum AuthState: Equatable, Sendable {
    case signedIn(username: String, scopes: [String], tokenExpiresAt: String?)
    case signedOut

    public var scopes: [String] {
        switch self {
        case .signedIn(_, let scopes, _):
            scopes
        case .signedOut:
            []
        }
    }
}

public enum SpoonjoyEnvironment: Equatable, Sendable {
    case production(baseURL: URL)
    case preview(baseURL: URL)
    case local(baseURL: URL)

    public var baseURL: URL {
        switch self {
        case .production(let baseURL), .preview(let baseURL), .local(let baseURL):
            baseURL
        }
    }

    public var apiBaseURL: URL? {
        baseURL.appending(path: "api").appending(path: "v1")
    }
}

public enum OfflineState: Equatable, Sendable {
    case available(snapshotCount: Int, lastRestoredAt: String?)
    case unavailable

    public var statusLabel: String {
        switch self {
        case .available(let snapshotCount, _):
            "Offline cache ready: \(snapshotCount) \(snapshotCount == 1 ? "snapshot" : "snapshots")"
        case .unavailable:
            "Offline cache unavailable"
        }
    }
}

public enum CookModeTextSize: String, Equatable, Sendable {
    case standard
    case large
}

public struct SettingsStatusRow: Equatable, Sendable {
    public let id: String
    public let title: String
    public let value: String
}

public struct SettingsState: Equatable, Sendable {
    public let auth: AuthState
    public let environment: SpoonjoyEnvironment
    public let offline: OfflineState
    public let preferredCookModeTextSize: CookModeTextSize

    public init(
        auth: AuthState,
        environment: SpoonjoyEnvironment,
        offline: OfflineState,
        preferredCookModeTextSize: CookModeTextSize
    ) {
        self.auth = auth
        self.environment = environment
        self.offline = offline
        self.preferredCookModeTextSize = preferredCookModeTextSize
    }

    public var canReadShoppingList: Bool {
        auth.scopes.contains("shopping_list:read") || auth.scopes.contains("kitchen:read")
    }

    public var canWriteShoppingList: Bool {
        auth.scopes.contains("shopping_list:write") || auth.scopes.contains("kitchen:write")
    }

    public var statusRows: [SettingsStatusRow] {
        [
            SettingsStatusRow(id: "auth", title: "Auth", value: authValue),
            SettingsStatusRow(id: "environment", title: "Environment", value: environment.baseURL.absoluteString),
            SettingsStatusRow(id: "offline", title: "Offline", value: offline.statusLabel),
            SettingsStatusRow(id: "cook-mode-text", title: "Cook Mode Text", value: preferredCookModeTextSize.rawValue)
        ]
    }

    private var authValue: String {
        switch auth {
        case .signedIn(let username, _, _):
            username
        case .signedOut:
            "Signed out"
        }
    }
}
