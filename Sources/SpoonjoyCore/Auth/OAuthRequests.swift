import Foundation

public enum OAuthProviderHint: String, CaseIterable, Hashable, Sendable {
    case google
    case github
}

public enum OAuthRequests {
    public static func registerClient(
        clientName: String,
        redirectURIs: [URL]
    ) throws -> APIRequestBuilder {
        try redirectURIs.forEach { _ = try OAuthRedirectValidator.validate($0) }

        let body = OAuthRegisterRequestBody(
            clientName: clientName,
            redirectURIs: redirectURIs.map(\.absoluteString),
            tokenEndpointAuthMethod: "none"
        )

        return try jsonRequest(
            pathComponents: ["oauth", "register"],
            body: body
        )
    }

    public static func authorize(
        clientID: String,
        redirectURI: URL,
        scope: String,
        state: OAuthState,
        codeChallenge: String,
        providerHint: OAuthProviderHint? = nil
    ) throws -> APIRequestBuilder {
        _ = try OAuthRedirectValidator.validate(redirectURI)
        var queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state.rawValue),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        if let providerHint {
            queryItems.append(URLQueryItem(name: "provider", value: providerHint.rawValue))
        }

        return APIRequestBuilder(
            method: .get,
            pathComponents: ["oauth", "authorize"],
            queryItems: queryItems
        )
    }

    public static func exchangeCode(
        clientID: String,
        redirectURI: URL,
        code: String,
        codeVerifier: String
    ) throws -> APIRequestBuilder {
        try exchangeCode(
            NativeAuthorizationCodeGrant(clientID: clientID, redirectURI: redirectURI, code: code, codeVerifier: codeVerifier)
        )
    }

    /// The authorization_code exchange. A grant carrying a pending Apple link adds `pending_apple_link_token`,
    /// which the server honors only for Spoonjoy's own native client.
    public static func exchangeCode(_ grant: NativeAuthorizationCodeGrant) throws -> APIRequestBuilder {
        _ = try OAuthRedirectValidator.validate(grant.redirectURI)

        var fields = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: grant.clientID),
            URLQueryItem(name: "redirect_uri", value: grant.redirectURI.absoluteString),
            URLQueryItem(name: "code", value: grant.code),
            URLQueryItem(name: "code_verifier", value: grant.codeVerifier)
        ]
        if let pendingAppleLinkToken = grant.pendingAppleLinkToken {
            fields.append(URLQueryItem(name: "pending_apple_link_token", value: pendingAppleLinkToken))
        }
        return formRequest(pathComponents: ["oauth", "token"], fields: fields)
    }

    public static func refreshToken(
        clientID: String,
        refreshToken: String
    ) throws -> APIRequestBuilder {
        formRequest(
            pathComponents: ["oauth", "token"],
            fields: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "refresh_token", value: refreshToken)
            ]
        )
    }

    public static func revoke(
        refreshToken: String,
        clientID: String
    ) throws -> APIRequestBuilder {
        formRequest(
            pathComponents: ["oauth", "revoke"],
            fields: [
                URLQueryItem(name: "token", value: refreshToken),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "token_type_hint", value: "refresh_token")
            ]
        )
    }

    private static func jsonRequest<Body: Encodable>(
        pathComponents: [String],
        body: Body
    ) throws -> APIRequestBuilder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        return APIRequestBuilder(
            method: .post,
            pathComponents: pathComponents,
            queryItems: [],
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(body)
        )
    }

    private static func formRequest(
        pathComponents: [String],
        fields: [URLQueryItem]
    ) -> APIRequestBuilder {
        var components = URLComponents()
        components.queryItems = fields

        return APIRequestBuilder(
            method: .post,
            pathComponents: pathComponents,
            queryItems: [],
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(components.percentEncodedQuery!.utf8)
        )
    }
}

/// An authorization code to exchange for tokens, with the pending Apple link it carries, if any.
public struct NativeAuthorizationCodeGrant: Equatable, Sendable {
    public let clientID: String
    public let redirectURI: URL
    public let code: String
    public let codeVerifier: String
    /// Set only by `NativeAuthSessionRepository`, and never printed.
    let pendingAppleLinkToken: String?

    public init(clientID: String, redirectURI: URL, code: String, codeVerifier: String) {
        self.init(clientID: clientID, redirectURI: redirectURI, code: code, codeVerifier: codeVerifier, pendingAppleLinkToken: nil)
    }

    init(clientID: String, redirectURI: URL, code: String, codeVerifier: String, pendingAppleLinkToken: String?) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.code = code
        self.codeVerifier = codeVerifier
        self.pendingAppleLinkToken = pendingAppleLinkToken
    }

    /// True when this exchange will ask the server to link a pending Apple sign-in to the account.
    public var carriesPendingAppleLink: Bool {
        pendingAppleLinkToken != nil
    }
}

extension NativeAuthorizationCodeGrant: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "NativeAuthorizationCodeGrant(clientID: \(clientID), redirectURI: \(redirectURI), code: <redacted>, codeVerifier: <redacted>, pendingAppleLink: \(carriesPendingAppleLink))"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: ["clientID": clientID, "redirectURI": redirectURI, "carriesPendingAppleLink": carriesPendingAppleLink],
            displayStyle: .struct
        )
    }
}

private struct OAuthRegisterRequestBody: Encodable {
    let clientName: String
    let redirectURIs: [String]
    let tokenEndpointAuthMethod: String

    private enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectURIs = "redirect_uris"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
    }
}
