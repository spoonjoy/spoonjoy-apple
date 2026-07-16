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
        _ = try OAuthRedirectValidator.validate(redirectURI)

        return formRequest(
            pathComponents: ["oauth", "token"],
            fields: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "code_verifier", value: codeVerifier)
            ]
        )
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
