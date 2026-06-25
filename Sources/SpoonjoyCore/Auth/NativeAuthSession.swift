import Foundation

public enum NativeAuthSessionError: Error, Equatable, Sendable {
    case missingClientID
    case missingAuthorizationCode
    case invalidCallbackURL(String)
    case stateMismatch(expected: String, actual: String?)
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
    public static let defaultScope = "shopping_list:read shopping_list:write"
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

    public static func code(from callbackURL: URL, expectedState: OAuthState) throws -> String {
        _ = try OAuthRedirectValidator.validate(callbackURL)
        guard callbackURL.scheme?.lowercased() == redirectURI.scheme,
              callbackURL.host?.lowercased() == redirectURI.host,
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
}
