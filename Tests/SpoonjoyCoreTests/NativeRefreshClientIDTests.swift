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
        vault: any TokenVault,
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

    @Test("the derived client id matches the server's own output for the QA origin")
    func derivedClientIDMatchesTheServersFixedVector() {
        // nativeAppleOAuthClientId("https://spoonjoy-v2-qa.mendelow-studio.workers.dev") on the server.
        let serverOutput = "spoonjoy-apple-native:bb380180f319522cf838262707b442e3e224fb322ff3570d4d497987650b9d3b"
        let qa = URL(string: "https://spoonjoy-v2-qa.mendelow-studio.workers.dev")!
        #expect(NativeAuthSession.nativeClientID(forServerBaseURL: qa) == serverOutput)
        #expect(NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "https://spoonjoy-v2-qa.mendelow-studio.workers.dev/")!) == serverOutput)
        #expect(NativeAuthSession.nativeClientID(forServerBaseURL: URL(string: "https://SPOONJOY-V2-QA.mendelow-studio.workers.dev:443/x?y=1")!) == serverOutput)
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

    @Test("a stored legacy session is not rewritten before the server has accepted anything")
    func restoreDoesNotRewriteTheStoredClientID() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID))
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL)

        guard case .refreshRequired(let restored) = try await repository.restoreState() else {
            Issue.record("Expected an expired session to need a refresh")
            return
        }
        #expect(restored.clientID == NativeAuthSession.nativeAppClientID)
        #expect(try await vault.loadClientID() == NativeAuthSession.nativeAppClientID)
        #expect(try await vault.loadSession()?.clientID == NativeAuthSession.nativeAppClientID)
    }

    @Test("a legacy session that still refreshes with its stored id keeps that id")
    func legacySessionThatStillWorksKeepsItsID() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID))
        let seen = ClientIDLog()
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL) { clientID, refreshToken in
            await seen.record(clientID: clientID, refreshToken: refreshToken)
            return Self.response()
        }

        let refreshed = try await repository.validSession()
        #expect(refreshed.clientID == NativeAuthSession.nativeAppClientID)
        #expect(await seen.entries == [.init(clientID: NativeAuthSession.nativeAppClientID, refreshToken: "sj_refresh_old")])
        #expect(try await vault.loadSession()?.clientID == NativeAuthSession.nativeAppClientID)
    }

    @Test("a legacy session the server refuses is retried once with the derived id, and only that id is saved")
    func legacySessionRetriesWithTheDerivedID() async throws {
        let derived = NativeAuthSession.nativeClientID(forServerBaseURL: Self.qaURL)
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID))
        let seen = ClientIDLog()
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL) { clientID, refreshToken in
            await seen.record(clientID: clientID, refreshToken: refreshToken)
            if clientID == NativeAuthSession.nativeAppClientID {
                throw Self.transportError(status: 400)
            }
            return Self.response(clientID: clientID)
        }

        let refreshed = try await repository.validSession()
        #expect(refreshed.clientID == derived)
        #expect(refreshed.accountID == "chef_ari")
        #expect(await seen.entries == [
            .init(clientID: NativeAuthSession.nativeAppClientID, refreshToken: "sj_refresh_old"),
            .init(clientID: derived, refreshToken: "sj_refresh_old")
        ])
        #expect(try await vault.loadClientID() == derived)
        #expect(try await vault.loadSession()?.clientID == derived)
    }

    @Test("when both candidate ids are refused the stored session is left exactly as it was")
    func refusedLegacySessionIsNotRewritten() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL) { _, _ in
            await counter.bump()
            throw Self.transportError(status: 400)
        }

        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await repository.validSession()
        }
        #expect(await counter.count == 2)
        #expect(try await vault.loadClientID() == NativeAuthSession.nativeAppClientID)
        #expect(try await vault.loadSession()?.clientID == NativeAuthSession.nativeAppClientID)
        #expect(try await vault.loadSession()?.refreshToken == "sj_refresh_old")
    }

    @Test("a transient failure on a legacy session does not try the second id")
    func transientFailureDoesNotTryTheDerivedID() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: NativeAuthSession.nativeAppClientID))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: Self.qaURL) { _, _ in
            await counter.bump()
            throw Self.transportError(status: 503)
        }
        await #expect(throws: (any Error).self) {
            try await repository.validSession()
        }
        #expect(await counter.count == 1)
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
                // 400 and 401 are the statuses the server's OAuth endpoint answers a refused refresh token with;
                // every other status here is one a proxy or the platform could produce.
                APIError(
                    requestID: "req_1",
                    code: [400, 401].contains($0) ? "invalid_grant" : "oauth_http_status_\($0)",
                    message: "OAuth request failed.",
                    status: $0
                )
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
            Self.transportError(status: 403, kind: .nonJSONResponse),
            Self.transportError(status: 404, kind: .nonJSONResponse),
            Self.transportError(status: 413, kind: .nonJSONResponse),
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

    // MARK: The OAuth error body

    private static func decoded(
        status: Int,
        body: String,
        isJSON: Bool = true
    ) -> APITransportError? {
        OAuthErrorResponse.transportError(
            statusCode: status,
            isJSON: isJSON,
            data: Data(body.utf8),
            requestID: "req_body",
            retryAfterSeconds: nil
        )
    }

    @Test("only an OAuth invalid_grant or invalid_client body makes a refresh failure permanent")
    func onlyOAuthRefusalsArePermanent() throws {
        let invalidGrant = try #require(Self.decoded(
            status: 400,
            body: #"{"error":"invalid_grant","error_description":"Unknown or revoked refresh token"}"#
        ))
        #expect(invalidGrant.apiError?.code == "invalid_grant")
        #expect(invalidGrant.apiError?.message == "Unknown or revoked refresh token")
        #expect(TokenRefreshError.isPermanent(invalidGrant))

        let invalidClient = try #require(Self.decoded(status: 401, body: #"{"error":"invalid_client"}"#))
        #expect(invalidClient.apiError?.message == "invalid_client")
        #expect(TokenRefreshError.isPermanent(invalidClient))

        // Other OAuth errors, and the same codes at statuses the server never uses for them, are not the token's fault.
        for (status, body) in [
            (400, #"{"error":"invalid_request"}"#),
            (400, #"{"error":"unsupported_grant_type"}"#),
            (429, #"{"error":"slow_down"}"#),
            (503, #"{"error":"temporarily_unavailable"}"#),
            (403, #"{"error":"invalid_grant"}"#)
        ] {
            let error = try #require(Self.decoded(status: status, body: body))
            #expect(!TokenRefreshError.isPermanent(error))
        }
    }

    @Test("an HTML 403, a plain 404, a 413 and an empty body are not OAuth errors")
    func nonOAuthBodiesAreNotDecoded() {
        #expect(Self.decoded(status: 403, body: "<html><body>Access denied</body></html>", isJSON: false) == nil)
        #expect(Self.decoded(status: 403, body: "<html>error code: 1020</html>") == nil)
        #expect(Self.decoded(status: 404, body: "Not Found", isJSON: false) == nil)
        #expect(Self.decoded(status: 413, body: "") == nil)
        #expect(Self.decoded(status: 400, body: #"{"error":""}"#) == nil)
        #expect(Self.decoded(status: 400, body: #"{"error":{"code":"x"}}"#) == nil)
        // A body that says invalid_grant but is not served as JSON is not trusted either.
        #expect(Self.decoded(status: 400, body: #"{"error":"invalid_grant"}"#, isJSON: false) == nil)
    }

    @Test("a revoked-on-purpose marker survives decoding and only that marker counts")
    func userRevocationMarker() throws {
        let revoked = try #require(Self.decoded(
            status: 400,
            body: #"{"error":"invalid_grant","error_description":"Session revoked","reason":"revoked_by_user"}"#
        ))
        #expect(OAuthErrorResponse.isUserRevocation(revoked))
        let expired = try #require(Self.decoded(status: 400, body: #"{"error":"invalid_grant","reason":"expired"}"#))
        #expect(!OAuthErrorResponse.isUserRevocation(expired))
        let plain = try #require(Self.decoded(status: 400, body: #"{"error":"invalid_grant"}"#))
        #expect(!OAuthErrorResponse.isUserRevocation(plain))
        #expect(!OAuthErrorResponse.isUserRevocation(URLError(.badURL)))
        #expect(!TokenRefreshError.isPermanent(URLError(.badURL)))
    }

    @Test("a refresh the chef revoked on purpose reports a revocation, not an expiry")
    func revokedRefreshReportsRevocation() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            await counter.bump()
            throw try #require(Self.decoded(
                status: 400,
                body: #"{"error":"invalid_grant","reason":"revoked_by_user"}"#
            ))
        }
        for _ in 0..<2 {
            await #expect(throws: TokenRefreshError.sessionRevoked) {
                try await repository.validSession()
            }
        }
        #expect(await counter.count == 1)
    }

    @Test("URL loading failures that mean no network become offline transport errors")
    func offlineURLErrorsMapToOffline() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
                     .timedOut, .internationalRoamingOff, .callIsActive, .dataNotAllowed] {
            let mapped = OAuthErrorResponse.offlineError(for: URLError(code))
            #expect(mapped?.isOffline == true)
            #expect(mapped?.statusCode == nil)
        }
        #expect(OAuthErrorResponse.offlineError(for: URLError(.badURL)) == nil)
        #expect(OAuthErrorResponse.offlineError(for: URLError(.cancelled)) == nil)
    }

    // MARK: Rotation race

    @Test("a refresh another process already rotated is used instead of expiring the session")
    func rotationRaceUsesTheStoredSession() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let rotatedElsewhere = try AuthSession(
            clientID: "cm_old",
            accessToken: "sj_access_other_process",
            refreshToken: "sj_refresh_other_process",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(900),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, refreshToken in
            await counter.bump()
            // While this request was in flight, App Intents rotated the same token and stored the result.
            try await vault.saveSession(rotatedElsewhere)
            #expect(refreshToken == "sj_refresh_old")
            throw Self.transportError(status: 400)
        }

        let session = try await repository.validSession()
        #expect(session.refreshToken == "sj_refresh_other_process")
        #expect(session.accessToken == "sj_access_other_process")
        #expect(await counter.count == 1)
        #expect(try await vault.loadSession() == rotatedElsewhere)

        // The session was not marked dead: the next call just uses the live one.
        #expect(try await repository.validSession().refreshToken == "sj_refresh_other_process")
    }

    @Test("a rotation race whose stored session is also expired refreshes that one")
    func rotationRaceWithExpiredStoredSessionRefreshesAgain() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let expiredElsewhere = try Self.session(clientID: "cm_old", refresh: "sj_refresh_other_process")
        let seen = ClientIDLog()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { clientID, refreshToken in
            await seen.record(clientID: clientID, refreshToken: refreshToken)
            if refreshToken == "sj_refresh_old" {
                try await vault.saveSession(expiredElsewhere)
                throw Self.transportError(status: 400)
            }
            return Self.response(refresh: "sj_refresh_after_race")
        }

        let session = try await repository.validSession()
        #expect(session.refreshToken == "sj_refresh_after_race")
        #expect(await seen.entries.map(\.refreshToken) == ["sj_refresh_old", "sj_refresh_other_process"])
    }

    @Test("a rotation race that keeps losing to expired sessions reports a temporary failure, not an expired token")
    func endlessRotationRaceIsTemporary() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let counter = CallCounter()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            await counter.bump()
            try await vault.saveSession(try Self.session(clientID: "cm_old", refresh: "sj_refresh_race_\(await counter.count)"))
            throw Self.transportError(status: 400)
        }
        await #expect(throws: TokenRefreshError.refreshInconclusive) {
            try await repository.validSession()
        }
        #expect(await counter.count == 2)
        // Nothing was marked refused: the last token the other process stored is still untried.
        #expect(try await vault.loadSession()?.refreshToken == "sj_refresh_race_2")
    }

    @Test("adopting a session another process stored never writes to the vault")
    func adoptedSessionIsNotWrittenBack() async throws {
        let inner = InMemoryTokenVault()
        let vault = SaveCountingVault(inner)
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let rotatedElsewhere = try AuthSession(
            clientID: "cm_old",
            accessToken: "sj_access_other_process",
            refreshToken: "sj_refresh_other_process",
            tokenType: "Bearer",
            expiresAt: Self.now.addingTimeInterval(900),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            try await inner.saveSession(rotatedElsewhere)
            throw Self.transportError(status: 400)
        }
        let savesBefore = await vault.saves
        let session = try await repository.validSession()
        #expect(session.refreshToken == "sj_refresh_other_process")
        #expect(await vault.saves == savesBefore)
    }

    @Test("a caller that joins a refresh already in flight does not mark its own untried token as refused")
    func joiningCallerKeepsItsOwnToken() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let seen = ClientIDLog()
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { clientID, refreshToken in
            await seen.record(clientID: clientID, refreshToken: refreshToken)
            if refreshToken == "sj_refresh_old" {
                // Slow, then refused; meanwhile another process rotated and stored a newer expired token.
                try await Task.sleep(nanoseconds: 300_000_000)
                throw Self.transportError(status: 400)
            }
            return Self.response(refresh: "sj_refresh_after_join")
        }
        let first = Task { try await repository.validSession() }
        try await Task.sleep(nanoseconds: 60_000_000)
        try await vault.saveSession(try Self.session(clientID: "cm_old", refresh: "sj_refresh_other_process"))
        let second = Task { try await repository.validSession() }

        let sessions = try await [first.value, second.value]
        #expect(sessions.allSatisfy { $0.refreshToken == "sj_refresh_after_join" })
        #expect(await seen.entries.map(\.refreshToken).contains("sj_refresh_other_process"))
    }

    @Test("an expired or revoked session keeps its account scope, and a missing one stays signed out")
    func storedScopeSurvivesExpiry() throws {
        let stored = try Self.session(clientID: "cm_old")
        #expect(NativeAuthSessionState.signedOut.keepingStoredScope == .signedOut)
        #expect(NativeAuthSessionState.authenticated(stored).keepingStoredScope == .refreshRequired(stored))
        #expect(NativeAuthSessionState.refreshRequired(stored).keepingStoredScope == .refreshRequired(stored))
    }

    @Test("an OAuth error with no request id still decodes")
    func decodesWithoutARequestID() throws {
        let error = try #require(OAuthErrorResponse.transportError(
            statusCode: 400,
            isJSON: true,
            data: Data(#"{"error":"invalid_grant"}"#.utf8),
            requestID: nil,
            retryAfterSeconds: nil
        ))
        #expect(error.requestID == "unknown")
    }

    @Test("a refusal with an unchanged vault still expires the session")
    func refusalWithUnchangedVaultExpires() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(clientID: "cm_old"))
        let repository = Self.repository(vault: vault, serverBaseURL: nil) { _, _ in
            throw Self.transportError(status: 400)
        }
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await repository.validSession()
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

private actor SaveCountingVault: TokenVault {
    private let inner: InMemoryTokenVault
    private(set) var saves = 0

    init(_ inner: InMemoryTokenVault) {
        self.inner = inner
    }

    func loadClientID() async throws -> String? { try await inner.loadClientID() }
    func saveClientID(_ clientID: String) async throws {
        saves += 1
        try await inner.saveClientID(clientID)
    }
    func clearClientID() async throws { try await inner.clearClientID() }
    func loadSession() async throws -> AuthSession? { try await inner.loadSession() }
    func saveSession(_ session: AuthSession) async throws {
        saves += 1
        try await inner.saveSession(session)
    }
    func clearSession() async throws { try await inner.clearSession() }
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
