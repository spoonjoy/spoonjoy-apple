import CryptoKit
import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native refresh client id")
struct NativeRefreshClientIDTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)
    private static let qaURL = URL(string: "https://qa.spoonjoy.example/")!
    private static let productionURL = URL(string: "https://spoonjoy.app")!

    private static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func response(
        access: String = "sj_access_new",
        refresh: String = "sj_refresh_new",
        clientID: String? = nil
    ) -> OAuthTokenResponse {
        OAuthTokenResponse(
            accessToken: access,
            refreshToken: refresh,
            tokenType: "Bearer",
            expiresIn: 900,
            scope: NativeAuthSession.defaultScope,
            clientID: clientID
        )
    }

    private static func session(
        clientID: String,
        refresh: String = "sj_refresh_old",
        expiresIn: TimeInterval = -60
    ) throws -> AuthSession {
        try AuthSession(
            clientID: clientID,
            accessToken: "sj_access_old",
            refreshToken: refresh,
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(expiresIn),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
    }

    private static func repository(
        vault: InMemoryTokenVault,
        serverBaseURL: URL?,
        signIn: OAuthTokenResponse = response(),
        refresh: @escaping OAuthRefreshOperation = { _, _ in response() }
    ) -> NativeAuthSessionRepository {
        NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "cm_registered" },
            exchangeCode: { _, _, _, _ in signIn },
            exchangeAppleCredential: { _ in signIn },
            exchangePasswordCredential: { _ in signIn },
            refresh: refresh,
            revoke: { _, _ in },
            serverBaseURL: serverBaseURL,
            now: { now }
        )
    }

    private static let appleCredential = NativeAppleSignInCredential(
        identityToken: "apple_identity_token",
        rawNonce: "raw_nonce",
        email: "chef@spoonjoy.app",
        fullName: "Spoonjoy Chef"
    )
    private static let passwordCredential = NativePasswordSignInCredential(
        emailOrUsername: "chef@spoonjoy.app",
        password: "correct horse battery staple"
    )

    // MARK: Client id derivation

    @Test("the native client id is plain on production and carries the origin hash everywhere else")
    func derivesPerOriginClientID() {
        #expect(NativeAuthSession.nativeClientID(forServerBaseURL: Self.productionURL) == "spoonjoy-apple-native")
        #expect(NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "https://SPOONJOY.app:443/some/path?q=1")!) == "spoonjoy-apple-native")
        #expect(
            NativeAuthSession.nativeClientID(forServerBaseURL: Self.qaURL)
                == "spoonjoy-apple-native:" + Self.sha256Hex("https://qa.spoonjoy.example")
        )
        #expect(
            NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "http://127.0.0.1:5179")!)
                == "spoonjoy-apple-native:" + Self.sha256Hex("http://127.0.0.1:5179")
        )
        #expect(
            NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "http://localhost:80/")!)
                == "spoonjoy-apple-native:" + Self.sha256Hex("http://localhost")
        )
        #expect(
            NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "no-scheme-or-host")!)
                == "spoonjoy-apple-native:" + Self.sha256Hex("://")
        )
        #expect(
            NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "mailto:chef@spoonjoy.app")!)
                == "spoonjoy-apple-native:" + Self.sha256Hex("mailto://")
        )
    }

    @Test("token responses decode the client id the server issued")
    func decodesIssuedClientID() throws {
        let json = Data("""
        {"client_id":"spoonjoy-apple-native:abc","access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":900,"scope":"kitchen:read"}
        """.utf8)
        let decoded = try JSONDecoder().decode(OAuthTokenResponse.self, from: json)
        #expect(decoded.clientID == "spoonjoy-apple-native:abc")
        let plain = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data("""
        {"access_token":"a","refresh_token":"r","token_type":"Bearer","expires_in":900,"scope":"kitchen:read"}
        """.utf8))
        #expect(plain.clientID == nil)
    }

    // MARK: Sign-in stores the issued id

    @Test("apple and password sign-in store the client id the server returned")
    func signInStoresIssuedClientID() async throws {
        let issued = "spoonjoy-apple-native:" + Self.sha256Hex("https://qa.spoonjoy.example")
        for useApple in [true, false] {
            let vault = InMemoryTokenVault()
            let repository = Self.repository(
                vault: vault,
                serverBaseURL: Self.productionURL,
                signIn: Self.response(clientID: issued)
            )
            let session = useApple
                ? try await repository.handleAppleSignInCredential(Self.appleCredential)
                : try await repository.handlePasswordSignInCredential(Self.passwordCredential)
            #expect(session.clientID == issued)
            #expect(try await vault.loadClientID() == issued)
            #expect(try await vault.loadSession()?.clientID == issued)
        }
    }

    @Test("sign-in falls back to the derived id, then the plain id, when the response has none")
    func signInFallsBackToDerivedClientID() async throws {
        let derived = NativeAuthSession.nativeClientID(forServerBaseURL: Self.qaURL)
        #expect(derived != NativeAuthSession.nativeAppClientID)

        let qaVault = InMemoryTokenVault()
        let qa = Self.repository(vault: qaVault, serverBaseURL: Self.qaURL, signIn: Self.response(clientID: "  "))
        #expect(try await qa.handlePasswordSignInCredential(Self.passwordCredential).clientID == derived)
        #expect(try await qaVault.loadClientID() == derived)

        let unknownVault = InMemoryTokenVault()
        let unknown = Self.repository(vault: unknownVault, serverBaseURL: nil)
        #expect(try await unknown.handleAppleSignInCredential(Self.appleCredential).clientID == NativeAuthSession.nativeAppClientID)
    }

    // MARK: Migration

    @Test("a stored session with the plain id is migrated to the id this server issues, and refreshes with it")
    func migratesStoredSessions() async throws {
        let derived = NativeAuthSession.nativeClientID(forServerBaseURL: Self.qaURL)
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        let stored = try Self.session(clientID: NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(stored)

        let seen = ClientIDLog()
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL) { clientID, refreshToken in
            await seen.record(clientID: clientID, refreshToken: refreshToken)
            return Self.response(clientID: clientID)
        }

        guard case .refreshRequired(let restored) = try await repository.restoreState() else {
            Issue.record("Expected an expired session to need a refresh")
            return
        }
        #expect(restored.clientID == derived)
        #expect(restored.refreshToken == "sj_refresh_old")
        #expect(restored.accountID == "chef_ari")
        #expect(try await vault.loadClientID() == derived)

        let refreshed = try await repository.validSession()
        #expect(refreshed.clientID == derived)
        #expect(await seen.entries == [.init(clientID: derived, refreshToken: "sj_refresh_old")])
        #expect(try await vault.loadSession()?.clientID == derived)
    }

    @Test("sessions that are already right are left alone, and production keeps the plain id")
    func leavesCorrectSessionsAlone() async throws {
        let production = InMemoryTokenVault()
        try await production.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID, expiresIn: 600))
        let productionRepository = Self.repository(vault: production, serverBaseURL: Self.productionURL)
        guard case .authenticated(let kept) = try await productionRepository.restoreState() else {
            Issue.record("Expected a live session")
            return
        }
        #expect(kept.clientID == NativeAuthSession.nativeAppClientID)
        #expect(try await production.loadClientID() == nil)

        let registered = InMemoryTokenVault()
        try await registered.saveSession(try Self.session(clientID: "cm_registered", expiresIn: 600))
        let registeredRepository = Self.repository(vault: registered, serverBaseURL: Self.qaURL)
        #expect(try await registeredRepository.validSession().clientID == "cm_registered")

        let unknownOrigin = InMemoryTokenVault()
        try await unknownOrigin.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID, expiresIn: 600))
        let unknownRepository = Self.repository(vault: unknownOrigin, serverBaseURL: nil)
        #expect(try await unknownRepository.validSession().clientID == NativeAuthSession.nativeAppClientID)

        let empty = Self.repository(vault: InMemoryTokenVault(), serverBaseURL: Self.qaURL)
        #expect(try await empty.restoreState() == .signedOut)
    }

    @Test("a refresh response that names a client id replaces the stored one")
    func refreshAdoptsIssuedClientID() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            Self.response(clientID: "cm_server_says")
        }
        #expect(try await repository.validSession().clientID == "cm_server_says")
        #expect(try await vault.loadClientID() == "cm_server_says")
    }

    // MARK: Refresh failures

    private static func transportError(status: Int?, kind: APITransportErrorKind = .apiError) -> APITransportError {
        APITransportError(
            kind: kind,
            requestID: "req_1",
            statusCode: status,
            apiError: status.map {
                APIError(requestID: "req_1", code: "oauth_http_status_\($0)", message: "OAuth request failed.", status: $0)
            },
            retryDecision: .doNotRetry
        )
    }

    @Test("invalid_grant ends the session without a second request, and keeps it stored")
    func invalidGrantExpiresSession() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            await counter.bump()
            throw Self.transportError(status: 400)
        }

        for _ in 0..<2 {
            await #expect(throws: TokenRefreshError.sessionExpired) {
                try await repository.validSession()
            }
        }
        #expect(await counter.count == 1)
        #expect(try await vault.loadSession()?.refreshToken == "sj_refresh_old")

        // A new sign-in is a new refresh token, so refreshing is tried again.
        try await vault.saveSession(try Self.session(clientID: "cm_old", refresh: "sj_refresh_signed_in_again"))
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await repository.validSession()
        }
        #expect(await counter.count == 2)
    }

    @Test("concurrent callers all see the expired session")
    func concurrentCallersSeeExpiredSession() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            try await Task.sleep(nanoseconds: 50_000_000)
            throw Self.transportError(status: 401)
        }
        async let first = Self.outcome { try await repository.validSession() }
        async let second = Self.outcome { try await repository.validSession() }
        let outcomes = await [first, second]
        #expect(outcomes == [true, true])
    }

    @Test("network, timeout, rate limit and server errors keep the session and are retried next time")
    func transientFailuresKeepSession() async throws {
        let failures: [Error] = [
            Self.transportError(status: nil, kind: .offline),
            Self.transportError(status: 408),
            Self.transportError(status: 425),
            Self.transportError(status: 429),
            Self.transportError(status: 503),
            URLError(.timedOut)
        ]
        for failure in failures {
            let vault = InMemoryTokenVault()
            try await vault.saveSession(try Self.session(clientID: "cm_old"))
            let counter = CallCounter()
            let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
                await counter.bump()
                if await counter.count == 1 {
                    throw failure
                }
                return Self.response()
            }
            await #expect(throws: (any Error).self) {
                try await repository.validSession()
            }
            #expect(try await vault.loadSession()?.refreshToken == "sj_refresh_old")
            let recovered = try await repository.validSession()
            #expect(recovered.refreshToken == "sj_refresh_new")
            #expect(await counter.count == 2)
        }
    }

    private static func outcome(_ call: () async throws -> AuthSession) async -> Bool {
        do {
            _ = try await call()
            return false
        } catch TokenRefreshError.sessionExpired {
            return true
        } catch {
            return false
        }
    }

    @Test("logging out forgets a rejected refresh token")
    func logoutForgetsRejection() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            await counter.bump()
            throw Self.transportError(status: 400)
        }
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await repository.validSession()
        }
        try await repository.revokeAndLogout()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await repository.validSession()
        }
        #expect(await counter.count == 2)
    }

    // MARK: Routes

    @Test("only safe, existing places come back on relaunch")
    func restorableRoutes() {
        let recipes: Set<String> = ["recipe_1"]
        let cookbooks: Set<String> = ["cookbook_1"]
        func restored(_ route: AppRoute) -> AppRoute? {
            route.restorable(recipeIDs: recipes, cookbookIDs: cookbooks)
        }
        #expect(restored(.recipeDetail(id: "recipe_1", presentation: .cook)) == .recipeDetail(id: "recipe_1", presentation: .cook))
        #expect(restored(.recipeDetail(id: "recipe_gone", presentation: .detail)) == nil)
        #expect(restored(.cookbookDetail(id: "cookbook_1")) == .cookbookDetail(id: "cookbook_1"))
        #expect(restored(.cookbookDetail(id: "cookbook_gone")) == nil)
        #expect(restored(.recipeEditor(id: nil)) == nil)
        #expect(restored(.recipeEditor(id: "recipe_1")) == nil)
        #expect(restored(.recipeCoverControls(id: "recipe_1")) == nil)
        #expect(restored(.unknownLink) == nil)
        for route in [AppRoute.kitchen, .recipes, .savedRecipes, .cookbooks, .chefs, .shoppingList, .capture, .settings,
                      .profile(identifier: "ari"), .search(query: "miso", scope: .all),
                      .profileGraph(identifier: "ari", direction: .fellowChefs, page: 1)] {
            #expect(restored(route) == route)
        }
    }
}

private actor CallCounter {
    private(set) var count = 0
    func bump() { count += 1 }
}

private actor ClientIDLog {
    struct Entry: Equatable {
        let clientID: String
        let refreshToken: String
    }

    private(set) var entries: [Entry] = []
    func record(clientID: String, refreshToken: String) {
        entries.append(Entry(clientID: clientID, refreshToken: refreshToken))
    }
}
