import Foundation
import Testing
@testable import SpoonjoyCore

/// A session belongs to the server that issued it: a build pointed at another server must never send its tokens.
@Suite("Session issuing server")
struct NativeSessionOriginTests {
    private static let now = Date(timeIntervalSince1970: 1_780_010_000)
    private static let production = URL(string: "https://spoonjoy.app")!
    private static let qa = URL(string: "https://spoonjoy-v2-qa.example.workers.dev/")!

    private static func session(clientID: String, serverOrigin: String?) throws -> AuthSession {
        try AuthSession(
            clientID: clientID,
            accessToken: "sj_access_stored",
            refreshToken: "sj_refresh_stored",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(3_600),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari",
            serverOrigin: serverOrigin
        )
    }

    private static func repository(vault: InMemoryTokenVault, serverBaseURL: URL?) -> NativeAuthSessionRepository {
        let fixedNow = Self.now
        return NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "client_live" },
            exchangeCode: { _, _, _, _ in throw NativeAuthSessionError.missingAuthorizationCode },
            exchangePasswordCredential: { _ in
                OAuthTokenResponse(
                    accessToken: "sj_access_signed_in",
                    refreshToken: "sj_refresh_signed_in",
                    tokenType: "Bearer",
                    expiresIn: 3_600,
                    scope: NativeAuthSession.defaultScope
                )
            },
            refresh: { _, _ in throw TokenRefreshError.missingSession },
            revoke: { _, _ in },
            serverBaseURL: serverBaseURL,
            now: { fixedNow }
        )
    }

    /// Restores `stored` on a build pointed at `serverBaseURL`, and returns what it restored and what the vault kept.
    private static func restore(
        _ stored: AuthSession,
        on serverBaseURL: URL?
    ) async throws -> (state: NativeAuthSessionState, session: AuthSession?, clientID: String?) {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID(stored.clientID)
        try await vault.saveSession(stored)
        let state = try await repository(vault: vault, serverBaseURL: serverBaseURL).restoreState()
        return (state, try await vault.loadSession(), try await vault.loadClientID())
    }

    @Test("a sign-in records the origin of the server that issued the session")
    func signInRecordsTheIssuingOrigin() async throws {
        let vault = InMemoryTokenVault()
        let session = try await Self.repository(vault: vault, serverBaseURL: Self.qa).handlePasswordSignInCredential(
            NativePasswordSignInCredential(emailOrUsername: "chef@spoonjoy.app", password: "correct horse battery staple")
        )

        #expect(session.serverOrigin == "https://spoonjoy-v2-qa.example.workers.dev")
        #expect(try await vault.loadSession()?.serverOrigin == "https://spoonjoy-v2-qa.example.workers.dev")
    }

    @Test("a refreshed or rebound session keeps its issuing origin")
    func derivedSessionsKeepTheOrigin() throws {
        let stored = try Self.session(clientID: "client_live", serverOrigin: "https://spoonjoy.app")
        let rotated = try stored.rotated(
            with: OAuthTokenResponse(
                accessToken: "sj_access_rotated",
                refreshToken: "sj_refresh_rotated",
                tokenType: "Bearer",
                expiresIn: 3_600,
                scope: NativeAuthSession.defaultScope
            ),
            receivedAt: Self.now
        )

        #expect(rotated.serverOrigin == "https://spoonjoy.app")
        #expect(try stored.replacingClientID("client_other").serverOrigin == "https://spoonjoy.app")
        #expect(try stored.bindingAccountID("chef_other").serverOrigin == "https://spoonjoy.app")
    }

    @Test("a production build forgets a session QA issued, client id included")
    func productionForgetsAQASession() async throws {
        let restored = try await Self.restore(
            try Self.session(clientID: "client_live", serverOrigin: "https://spoonjoy-v2-qa.example.workers.dev"),
            on: Self.production
        )

        #expect(restored.state == .signedOut)
        #expect(restored.session == nil)
        #expect(restored.clientID == nil)
    }

    @Test("a session stored before origins were kept is forgotten when its derived client id names another server")
    func legacyDerivedClientIDNamesItsServer() async throws {
        let qaClientID = NativeAuthSession.nativeClientID(forServerBaseURL: Self.qa)
        let onProduction = try await Self.restore(try Self.session(clientID: qaClientID, serverOrigin: nil), on: Self.production)
        let onQA = try await Self.restore(try Self.session(clientID: qaClientID, serverOrigin: nil), on: Self.qa)

        #expect(onProduction.state == .signedOut)
        #expect(onProduction.session == nil)
        #expect(onQA.state == .authenticated(try Self.session(clientID: qaClientID, serverOrigin: nil)))
    }

    @Test("a session from the configured server, or one that cannot name its server, is kept")
    func matchingOrUnknownSessionsAreKept() async throws {
        let matching = try Self.session(clientID: "client_live", serverOrigin: "https://spoonjoy.app")
        let legacyPlain = try Self.session(clientID: NativeAuthSession.nativeAppClientID, serverOrigin: nil)
        let foreign = try Self.session(clientID: "client_live", serverOrigin: "https://spoonjoy-v2-qa.example.workers.dev")

        #expect(try await Self.restore(matching, on: Self.production).state == .authenticated(matching))
        #expect(try await Self.restore(legacyPlain, on: Self.production).state == .authenticated(legacyPlain))
        #expect(try await Self.restore(legacyPlain, on: Self.qa).state == .authenticated(legacyPlain))
        // A repository that does not know its server cannot judge, so it keeps the session.
        #expect(try await Self.restore(foreign, on: nil).state == .authenticated(foreign))
    }

    @Test("origins compare without case or a default port, and keep any other port")
    func originNormalisation() throws {
        let origin = { (string: String) in NativeAuthSession.canonicalOrigin(of: URL(string: string)!) }
        #expect(origin("HTTPS://Spoonjoy.APP/api") == "https://spoonjoy.app")
        #expect(origin("https://spoonjoy.app:443/") == "https://spoonjoy.app")
        #expect(origin("http://localhost:80") == "http://localhost")
        #expect(origin("https://spoonjoy.app:8443") == "https://spoonjoy.app:8443")
        #expect(origin("http://localhost:8787/") == "http://localhost:8787")

        let stamped = try Self.session(clientID: "client_live", serverOrigin: "https://spoonjoy.app")
        #expect(!stamped.wasIssued(elsewhereThan: URL(string: "HTTPS://SPOONJOY.APP:443")!))
        #expect(stamped.wasIssued(elsewhereThan: URL(string: "https://spoonjoy.app:8443")!))
    }
}
