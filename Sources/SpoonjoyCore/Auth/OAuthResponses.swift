import Foundation

public struct OAuthRegisterResponse: Decodable, Equatable, Sendable {
    public let clientID: String
    public let redirectURIs: [String]
    public let tokenEndpointAuthMethod: String
    public let grantTypes: [String]
    public let responseTypes: [String]

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case redirectURIs = "redirect_uris"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
        case grantTypes = "grant_types"
        case responseTypes = "response_types"
    }
}

public struct OAuthTokenResponse: Decodable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let scope: String
    /// The client_id the server issued these tokens to. Native sign-in responses carry it; the refresh
    /// grant must present exactly this id. Absent on plain OAuth token responses.
    public let clientID: String?

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresIn: Int,
        scope: String,
        clientID: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.clientID = clientID
    }

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}
