import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("OAuth PKCE request construction")
struct OAuthRequestTests {
    @Test("PKCE verifier validation and S256 challenge match RFC vector")
    func pkceVerifierValidationAndChallengeMatchRFCVector() throws {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

        #expect(OAuthPKCE.isValidVerifier(verifier))
        #expect(try OAuthPKCE.codeChallenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(OAuthPKCE.isValidVerifier(String(repeating: "a", count: 43)))
        #expect(OAuthPKCE.isValidVerifier(String(repeating: "a", count: 128)))
        #expect(OAuthPKCE.isValidVerifier(String(repeating: "a", count: 42)) == false)
        #expect(OAuthPKCE.isValidVerifier(String(repeating: "a", count: 129)) == false)
        #expect(OAuthPKCE.isValidVerifier("invalid verifier with spaces") == false)
        #expect(throws: OAuthPKCEError.self) {
            try OAuthPKCE.codeChallenge(for: "invalid verifier with spaces")
        }
    }

    @Test("OAuth state trims and validates exact callback state")
    func oauthStateTrimsAndValidatesExactCallbackState() throws {
        let state = try #require(OAuthState(rawValue: " state_123 "))

        #expect(state.rawValue == "state_123")
        #expect(state.matches(returnedState: "state_123"))
        #expect(state.matches(returnedState: " state_123 ") == false)
        #expect(state.matches(returnedState: "state_456") == false)
        #expect(OAuthState(rawValue: " \n ") == nil)
    }

    @Test("redirect validator accepts app links and localhost loopback only")
    func redirectValidatorAcceptsAppLinksAndLocalhostLoopbackOnly() throws {
        #expect(try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/oauth/callback")!))
        #expect(try OAuthRedirectValidator.validate(URL(string: "http://localhost:53123/callback")!))
        #expect(try OAuthRedirectValidator.validate(URL(string: "http://127.0.0.1:53123/callback")!))

        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "spoonjoy://oauth/callback")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "http://example.com/oauth/callback")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https://user:pass@example.com/oauth/callback")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https://example.com/oauth/callback#fragment")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "/oauth/callback")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https:/oauth/callback")!)
        }
    }

    @Test("register request sends dynamic client registration JSON")
    func registerRequestSendsDynamicClientRegistrationJSON() throws {
        let request = try OAuthRequests.registerClient(
            clientName: "Spoonjoy Apple",
            redirectURIs: [
                URL(string: "https://spoonjoy.app/oauth/callback")!,
                URL(string: "http://localhost:53123/callback")!
            ]
        )
        .urlRequest(configuration: .spoonjoyProduction)
        let body = try decodeJSONBody(OAuthRegisterBody.self, from: request)

        #expect(request.method == .post)
        #expect(request.url.path == "/oauth/register")
        #expect(request.queryItems.isEmpty)
        #expect(request.headers["Authorization"] == nil)
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(body == OAuthRegisterBody(
            clientName: "Spoonjoy Apple",
            redirectURIs: [
                "https://spoonjoy.app/oauth/callback",
                "http://localhost:53123/callback"
            ],
            tokenEndpointAuthMethod: "none"
        ))
    }

    @Test("authorize request builds browser URL and omits REST resource")
    func authorizeRequestBuildsBrowserURLAndOmitsRESTResource() throws {
        let request = try OAuthRequests.authorize(
            clientID: "cm_client_id_from_register",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            scope: "shopping_list:read shopping_list:write",
            state: try #require(OAuthState(rawValue: "state_123")),
            codeChallenge: "pkce_s256_challenge"
        )
        .urlRequest(configuration: .spoonjoyProduction)

        #expect(request.method == .get)
        #expect(request.url.path == "/oauth/authorize")
        #expect(request.headers["Authorization"] == nil)
        #expect(request.body == nil)
        #expect(request.queryItems == [
            URLQueryItem(name: "client_id", value: "cm_client_id_from_register"),
            URLQueryItem(name: "redirect_uri", value: "https://spoonjoy.app/oauth/callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "shopping_list:read shopping_list:write"),
            URLQueryItem(name: "state", value: "state_123"),
            URLQueryItem(name: "code_challenge", value: "pkce_s256_challenge"),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ])
        #expect(request.queryItems.contains { $0.name == "resource" } == false)
    }

    @Test("token exchange refresh and revoke requests are form encoded")
    func tokenExchangeRefreshAndRevokeRequestsAreFormEncoded() throws {
        let exchange = try OAuthRequests.exchangeCode(
            clientID: "cm_client_id_from_register",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            code: "oac_code",
            codeVerifier: "pkce_verifier"
        )
        .urlRequest(configuration: .spoonjoyProduction)
        let refresh = try OAuthRequests.refreshToken(
            clientID: "cm_client_id_from_register",
            refreshToken: "ort_refresh"
        )
        .urlRequest(configuration: .spoonjoyProduction)
        let revoke = try OAuthRequests.revoke(
            refreshToken: "ort_refresh",
            clientID: "cm_client_id_from_register"
        )
        .urlRequest(configuration: .spoonjoyProduction)

        #expect(exchange.method == .post)
        #expect(exchange.url.path == "/oauth/token")
        #expect(exchange.headers["Content-Type"] == "application/x-www-form-urlencoded")
        #expect(exchange.headers["Authorization"] == nil)
        #expect(try formBody(from: exchange) == [
            "grant_type": "authorization_code",
            "client_id": "cm_client_id_from_register",
            "redirect_uri": "https://spoonjoy.app/oauth/callback",
            "code": "oac_code",
            "code_verifier": "pkce_verifier"
        ])
        #expect(try formBody(from: exchange)["resource"] == nil)

        #expect(refresh.method == .post)
        #expect(refresh.url.path == "/oauth/token")
        #expect(try formBody(from: refresh) == [
            "grant_type": "refresh_token",
            "client_id": "cm_client_id_from_register",
            "refresh_token": "ort_refresh"
        ])

        #expect(revoke.method == .post)
        #expect(revoke.url.path == "/oauth/revoke")
        #expect(try formBody(from: revoke) == [
            "token": "ort_refresh",
            "client_id": "cm_client_id_from_register",
            "token_type_hint": "refresh_token"
        ])
    }

    @Test("OAuth register and token responses decode snake case payloads")
    func oauthRegisterAndTokenResponsesDecodeSnakeCasePayloads() throws {
        let register = try JSONDecoder().decode(
            OAuthRegisterResponse.self,
            from: Data(
                """
                {
                  "client_id": "cm_client_id_from_register",
                  "redirect_uris": ["https://spoonjoy.app/oauth/callback"],
                  "token_endpoint_auth_method": "none",
                  "grant_types": ["authorization_code", "refresh_token"],
                  "response_types": ["code"]
                }
                """.utf8
            )
        )
        let token = try JSONDecoder().decode(
            OAuthTokenResponse.self,
            from: Data(
                """
                {
                  "access_token": "sj_access",
                  "refresh_token": "ort_refresh",
                  "token_type": "Bearer",
                  "expires_in": 900,
                  "scope": "shopping_list:read shopping_list:write"
                }
                """.utf8
            )
        )

        #expect(register.clientID == "cm_client_id_from_register")
        #expect(register.tokenEndpointAuthMethod == "none")
        #expect(register.grantTypes == ["authorization_code", "refresh_token"])
        #expect(token.accessToken == "sj_access")
        #expect(token.refreshToken == "ort_refresh")
        #expect(token.tokenType == "Bearer")
        #expect(token.expiresIn == 900)
        #expect(token.scope == "shopping_list:read shopping_list:write")
    }
}

private struct OAuthRegisterBody: Decodable, Equatable {
    let clientName: String
    let redirectURIs: [String]
    let tokenEndpointAuthMethod: String

    private enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectURIs = "redirect_uris"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
    }
}

private func decodeJSONBody<Value: Decodable>(_ type: Value.Type, from request: APIRequest) throws -> Value {
    let body = try #require(request.body)
    return try JSONDecoder().decode(type, from: body)
}

private func formBody(from request: APIRequest) throws -> [String: String] {
    let body = try #require(request.body)
    let bodyString = try #require(String(data: body, encoding: .utf8))
    let components = URLComponents(string: "https://spoonjoy.app/form?\(bodyString)")
    let pairs = try #require(components?.queryItems)

    return Dictionary(uniqueKeysWithValues: pairs.map { ($0.name, $0.value ?? "") })
}
