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
    /// What became of a pending Apple link this sign-in sent (`linked`, `already_linked`, `taken`, ...): the
    /// password sign-in's `appleLink`, or the code exchange's `apple_link`. Nil when none was sent.
    public let appleLinkOutcome: String?

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresIn: Int,
        scope: String,
        clientID: String? = nil,
        appleLinkOutcome: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.clientID = clientID
        self.appleLinkOutcome = appleLinkOutcome
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        scope = try container.decode(String.self, forKey: .scope)
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID)
        appleLinkOutcome = (try? container.decodeIfPresent(String.self, forKey: .appleLink))
            ?? (try? container.decodeIfPresent(String.self, forKey: .appleLinkOAuth))
    }

    private enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case appleLink
        case appleLinkOAuth = "apple_link"
    }
}
