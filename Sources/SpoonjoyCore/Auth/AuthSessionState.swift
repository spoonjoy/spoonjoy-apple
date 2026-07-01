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
        accountID: String? = nil
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
    }

    public func state(at date: Date) -> AuthSessionState {
        if expiresAt > date {
            return .authenticated(accessToken: accessToken, expiresAt: expiresAt)
        }

        return .refreshRequired(refreshToken: refreshToken)
    }

    public func rotated(with response: OAuthTokenResponse, receivedAt: Date) throws -> AuthSession {
        guard response.expiresIn > 0 else {
            throw AuthSessionError.invalidExpiration
        }

        return try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: receivedAt.addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope,
            accountID: accountID
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
            accountID: accountID
        )
    }
}
