import Foundation

public struct OAuthRegisterResponse: Decodable, Equatable {
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

public struct OAuthTokenResponse: Decodable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let scope: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}
