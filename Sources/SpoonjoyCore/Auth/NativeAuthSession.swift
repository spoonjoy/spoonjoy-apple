import Foundation

public enum NativeAuthSessionError: Error, Equatable, Sendable {
    case missingClientID
    case missingAuthorizationCode
    case invalidCallbackURL(String)
    case stateMismatch(expected: String, actual: String?)
    case appleSignInUnavailable
    case passwordSignInUnavailable
}

public enum NativeAuthSessionState: Equatable, Sendable {
    case signedOut
    case authenticated(AuthSession)
    case refreshRequired(AuthSession)
}

public struct NativeAuthSignInStart: Equatable, Sendable {
    public let clientID: String
    public let redirectURI: URL
    public let authorizationURL: URL
}

public enum NativeAuthSession {
    public static let redirectURI = URL(string: "https://spoonjoy.app/oauth/callback")!
    public static let localDogfoodRedirectURI = URL(string: "http://127.0.0.1:53123/callback")!
    public static let nativeAppClientID = "spoonjoy-apple-native"
    public static let nativeAppleClientID = nativeAppClientID
    public static let requiredSessionScopes = [
        "kitchen:read",
        "kitchen:write",
        "shopping_list:read",
        "shopping_list:write",
        "account:read",
        "account:write"
    ]
    public static let tokenManagementScopes = [
        "tokens:read",
        "tokens:write"
    ]
    public static let defaultScopes = requiredSessionScopes
    public static let defaultScope = defaultScopes.joined(separator: " ")
    public static let firstPartyTokenScopes = requiredSessionScopes + tokenManagementScopes
    public static let firstPartyTokenScope = firstPartyTokenScopes.joined(separator: " ")
    public static let lifecycleOperations = ["startSignIn", "handleOAuthCallback", "restoreState", "revokeAndLogout"]
    public static let collaborators = ["OAuthRequests.exchangeCode", "OAuthRequests.revoke", "RefreshCoordinator"]

    public static func authorizationURL(
        clientID: String,
        redirectURI: URL,
        scope: String,
        state: OAuthState,
        codeChallenge: String
    ) throws -> URL {
        let builder = try OAuthRequests.authorize(
            clientID: clientID,
            redirectURI: redirectURI,
            scope: scope,
            state: state,
            codeChallenge: codeChallenge
        )
        var components = URLComponents()
        components.scheme = "https"
        components.host = "spoonjoy.app"
        components.path = "/" + builder.pathComponents.joined(separator: "/")
        components.queryItems = builder.queryItems
        return components.url!
    }

    public static func code(
        from callbackURL: URL,
        expectedState: OAuthState,
        redirectURI: URL = Self.redirectURI
    ) throws -> String {
        _ = try OAuthRedirectValidator.validate(callbackURL)
        guard callbackURL.scheme?.lowercased() == redirectURI.scheme,
              callbackURL.host?.lowercased() == redirectURI.host,
              normalizedPort(for: callbackURL) == normalizedPort(for: redirectURI),
              callbackURL.path(percentEncoded: true) == redirectURI.path(percentEncoded: true) else {
            throw NativeAuthSessionError.invalidCallbackURL(callbackURL.absoluteString)
        }
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let returnedState = components?.queryItems?.first { $0.name == "state" }?.value
        guard expectedState.matches(returnedState: returnedState) else {
            throw NativeAuthSessionError.stateMismatch(expected: expectedState.rawValue, actual: returnedState)
        }
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeAuthSessionError.missingAuthorizationCode
        }

        return code
    }

    private static func normalizedPort(for url: URL) -> Int {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "http":
            return 80
        default:
            return 443
        }
    }
}
