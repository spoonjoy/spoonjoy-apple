import Foundation

public enum AuthSessionError: Error, Equatable, Sendable {
    case invalidClientID
    case invalidAccessToken
    case invalidRefreshToken
    case invalidTokenType
    case invalidScope
    case invalidExpiration
}

public enum AuthSessionState: Equatable, Sendable {
    case signedOut
    case authenticated(accessToken: String, expiresAt: Date)
    case refreshRequired(refreshToken: String)
}

public struct AuthSession: Equatable, Codable, Sendable {
    private static let bearerTokenType = "Bearer"
    private static let requiredScopes: Set<String> = Set(NativeAuthSession.requiredSessionScopes)

    public let clientID: String
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresAt: Date
    public let scope: String
    public let accountID: String?
    /// The origin of the server that issued these tokens (`https://spoonjoy.app`). Nil for a session stored before
    /// the app kept it.
    public let serverOrigin: String?

    public var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }

    public init(
        clientID: String,
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresAt: Date,
        scope: String,
        accountID: String? = nil,
        serverOrigin: String? = nil
    ) throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenType = tokenType.trimmingCharacters(in: .whitespacesAndNewlines)
        let scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountID = accountID?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clientID.isEmpty else {
            throw AuthSessionError.invalidClientID
        }
        guard !accessToken.isEmpty else {
            throw AuthSessionError.invalidAccessToken
        }
        guard !refreshToken.isEmpty else {
            throw AuthSessionError.invalidRefreshToken
        }
        guard !tokenType.isEmpty else {
            throw AuthSessionError.invalidTokenType
        }
        guard tokenType.caseInsensitiveCompare(Self.bearerTokenType) == .orderedSame else {
            throw AuthSessionError.invalidTokenType
        }
        guard !scope.isEmpty else {
            throw AuthSessionError.invalidScope
        }
        guard Self.requiredScopes.isSubset(of: Set(scope.split(separator: " ").map(String.init))) else {
            throw AuthSessionError.invalidScope
        }

        self.clientID = clientID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = Self.bearerTokenType
        self.expiresAt = expiresAt
        self.scope = scope
        self.accountID = accountID?.isEmpty == true ? nil : accountID
        self.serverOrigin = serverOrigin
    }

    /// True when another server issued this session than the one at `serverBaseURL`. A session without a stored
    /// origin names its server only through a derived client id (`spoonjoy-apple-native:<digest>`); the plain id is
    /// ambiguous and counts as a match.
    public func wasIssued(elsewhereThan serverBaseURL: URL) -> Bool {
        if let serverOrigin {
            return serverOrigin != NativeAuthSession.canonicalOrigin(of: serverBaseURL)
        }
        guard clientID.hasPrefix(NativeAuthSession.nativeAppClientID + ":") else {
            return false
        }
        return clientID != NativeAuthSession.nativeClientID(forServerBaseURL: serverBaseURL)
    }

    /// How long before `expiresAt` the access token is treated as expired, so a request never leaves with a
    /// token that runs out in flight or on a server whose clock is slightly ahead.
    public static let expiryMargin: TimeInterval = 60

    public func state(at date: Date) -> AuthSessionState {
        if expiresAt > date.addingTimeInterval(Self.expiryMargin) {
            return .authenticated(accessToken: accessToken, expiresAt: expiresAt)
        }

        return .refreshRequired(refreshToken: refreshToken)
    }

    public func rotated(with response: OAuthTokenResponse, receivedAt: Date) throws -> AuthSession {
        guard response.expiresIn > 0 else {
            throw AuthSessionError.invalidExpiration
        }

        return try AuthSession(
            clientID: response.clientID ?? clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: receivedAt.addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope,
            accountID: accountID,
            serverOrigin: serverOrigin
        )
    }

    public func replacingClientID(_ clientID: String) throws -> AuthSession {
        try AuthSession(
            clientID: clientID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: expiresAt,
            scope: scope,
            accountID: accountID,
            serverOrigin: serverOrigin
        )
    }

    public func bindingAccountID(_ accountID: String) throws -> AuthSession {
        try AuthSession(
            clientID: clientID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: expiresAt,
            scope: scope,
            accountID: accountID,
            serverOrigin: serverOrigin
        )
    }
}
