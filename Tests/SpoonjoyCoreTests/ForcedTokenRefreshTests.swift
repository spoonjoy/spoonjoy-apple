import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Forced token refresh after a 401")
struct ForcedTokenRefreshTests {
    private static let now = Date(timeIntervalSince1970: 1_780_020_000)

    private static func session(
        access: String = "sj_access_current",
        refresh: String = "sj_refresh_current",
        expiresIn: TimeInterval = 900
    ) throws -> AuthSession {
        try AuthSession(
            clientID: "cm_client_id",
            accessToken: access,
            refreshToken: refresh,
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(expiresIn),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_ari"
        )
    }

    private static func response(access: String = "sj_access_new", refresh: String = "sj_refresh_new") -> OAuthTokenResponse {
        OAuthTokenResponse(
            accessToken: access,
            refreshToken: refresh,
            tokenType: "Bearer",
            expiresIn: 900,
            scope: NativeAuthSession.defaultScope
        )
    }

    private static func refusal(reason: String?) -> APITransportError {
        OAuthErrorResponse.transportError(
            statusCode: 400,
            isJSON: true,
            data: Data(
                ("{\"error\":\"invalid_grant\",\"error_description\":\"refused\""
                    + (reason.map { ",\"reason\":\"\($0)\"" } ?? "") + "}").utf8
            ),
            requestID: "req_refusal",
            retryAfterSeconds: nil
        )!
    }

    // MARK: Forcing a refresh

    @Test("a 401 refreshes a token that still looks valid, and stores the new session")
    func rejectedTokenIsRefreshedEvenBeforeItsExpiry() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session())
        let log = RefreshLog(response: Self.response())
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await log.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        // Without a 401 the cached token is used as before.
        #expect(try await coordinator.validSession(at: Self.now).accessToken == "sj_access_current")
        #expect(await log.refreshTokens.isEmpty)

        let refreshed = try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        #expect(refreshed.accessToken == "sj_access_new")
        #expect(refreshed.refreshToken == "sj_refresh_new")
        #expect(refreshed.accountID == "chef_ari")
        #expect(try await vault.loadSession() == refreshed)
        #expect(await log.refreshTokens == ["sj_refresh_current"])
    }

    @Test("a 401 for a token that was already replaced uses the stored session without refreshing")
    func rejectedTokenAlreadyReplacedIsNotRefreshedAgain() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(access: "sj_access_replaced", refresh: "sj_refresh_replaced"))
        let log = RefreshLog(response: Self.response())
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await log.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        let session = try await coordinator.sessionAfterRejecting(accessToken: "sj_access_stale", at: Self.now)
        #expect(session.accessToken == "sj_access_replaced")
        // A request sent with no token at all also just gets the stored one.
        #expect(try await coordinator.sessionAfterRejecting(accessToken: nil, at: Self.now).accessToken == "sj_access_replaced")
        #expect(await log.refreshTokens.isEmpty)
    }

    @Test("concurrent 401s for the same token share one refresh, and a late one reuses its result")
    func concurrentRejectionsShareOneRefresh() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session())
        let gate = HeldRefresh(response: Self.response())
        let coordinator = RefreshCoordinator(vault: vault) { _, refreshToken in
            try await gate.refresh(refreshToken: refreshToken)
        }

        async let first = coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        await gate.waitUntilStarted()
        async let second = coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        try await Task.sleep(nanoseconds: 20_000_000)
        await gate.release()
        let sessions = try await [first, second]

        #expect(sessions.allSatisfy { $0.accessToken == "sj_access_new" })
        let late = try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        #expect(late.accessToken == "sj_access_new")
        #expect(await gate.refreshTokens == ["sj_refresh_current"])
    }

    // MARK: A refused forced refresh

    @Test("a forced refresh the server refuses ends the session the way an expiry refresh does")
    func refusedForcedRefreshExpiresTheSession() async throws {
        let vault = InMemoryTokenVault()
        let stored = try Self.session()
        try await vault.saveSession(stored)
        let counter = RefreshLog(response: Self.response())
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            _ = try await counter.refresh(clientID: clientID, refreshToken: refreshToken)
            throw Self.refusal(reason: nil)
        }

        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        }
        // The session stays stored, so the cached kitchen keeps its account scope.
        #expect(try await vault.loadSession() == stored)
        // The dead refresh token is not sent again, by either path.
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        }
        await #expect(throws: TokenRefreshError.sessionExpired) {
            try await coordinator.validSession(at: Self.now.addingTimeInterval(3_600))
        }
        #expect(await counter.refreshTokens == ["sj_refresh_current"])
    }

    @Test("a forced refresh refused as a revocation reports a revocation")
    func revokedForcedRefreshReportsRevocation() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session())
        let coordinator = RefreshCoordinator(vault: vault) { _, _ in
            throw Self.refusal(reason: OAuthErrorResponse.userRevokedReason)
        }

        await #expect(throws: TokenRefreshError.sessionRevoked) {
            try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        }
    }

    @Test("a forced refresh with no stored session reports a missing session")
    func forcedRefreshWithoutSessionIsMissing() async throws {
        let coordinator = RefreshCoordinator(vault: InMemoryTokenVault()) { _, _ in Self.response() }
        await #expect(throws: TokenRefreshError.missingSession) {
            try await coordinator.sessionAfterRejecting(accessToken: "sj_access_current", at: Self.now)
        }
    }

    @Test("the native repository forces the refresh with its own clock")
    func repositoryForcesTheRefresh() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session())
        let log = RefreshLog(response: Self.response())
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple Tests",
            registerClient: { _, _ in "cm_registered" },
            exchangeCode: { _, _, _, _ in Self.response() },
            exchangeAppleCredential: { _ in Self.response() },
            exchangePasswordCredential: { _ in Self.response() },
            refresh: { clientID, refreshToken in try await log.refresh(clientID: clientID, refreshToken: refreshToken) },
            revoke: { _, _ in },
            serverBaseURL: nil,
            now: { Self.now }
        )

        #expect(try await repository.validSession().accessToken == "sj_access_current")
        let refreshed = try await repository.sessionAfterRejecting(accessToken: "sj_access_current")
        #expect(refreshed.accessToken == "sj_access_new")
        #expect(refreshed.expiresAt == Self.now.addingTimeInterval(900))
        #expect(await log.refreshTokens == ["sj_refresh_current"])
    }

    // MARK: Early expiry

    @Test("a token is treated as expired 60 seconds before its expiry")
    func tokenExpiresSixtySecondsEarly() throws {
        #expect(AuthSession.expiryMargin == 60)
        let session = try Self.session(expiresIn: 120)
        let expiresAt = Self.now.addingTimeInterval(120)

        #expect(session.state(at: Self.now) == .authenticated(accessToken: "sj_access_current", expiresAt: expiresAt))
        #expect(session.state(at: Self.now.addingTimeInterval(59)) == .authenticated(accessToken: "sj_access_current", expiresAt: expiresAt))
        #expect(session.state(at: Self.now.addingTimeInterval(60)) == .refreshRequired(refreshToken: "sj_refresh_current"))
        #expect(session.state(at: Self.now.addingTimeInterval(61)) == .refreshRequired(refreshToken: "sj_refresh_current"))
    }

    @Test("the coordinator refreshes a token inside its last minute and keeps one just outside it")
    func coordinatorRefreshesInsideTheLastMinute() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveSession(try Self.session(expiresIn: 120))
        let log = RefreshLog(response: Self.response())
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await log.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        // 61 seconds left: still used as is.
        #expect(try await coordinator.validSession(at: Self.now.addingTimeInterval(59)).accessToken == "sj_access_current")
        #expect(await log.refreshTokens.isEmpty)

        // 60 seconds left: refreshed before it is sent.
        let refreshed = try await coordinator.validSession(at: Self.now.addingTimeInterval(60))
        #expect(refreshed.accessToken == "sj_access_new")
        #expect(await log.refreshTokens == ["sj_refresh_current"])
    }
}

private actor RefreshLog {
    private let response: OAuthTokenResponse
    private(set) var refreshTokens: [String] = []

    init(response: OAuthTokenResponse) {
        self.response = response
    }

    func refresh(clientID _: String, refreshToken: String) throws -> OAuthTokenResponse {
        refreshTokens.append(refreshToken)
        return response
    }
}

/// Holds a refresh open until the test releases it, so a second caller can arrive while it is in flight.
private actor HeldRefresh {
    private let response: OAuthTokenResponse
    private(set) var refreshTokens: [String] = []
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(response: OAuthTokenResponse) {
        self.response = response
    }

    func refresh(refreshToken: String) async throws -> OAuthTokenResponse {
        refreshTokens.append(refreshToken)
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters = []
        if !released {
            await withCheckedContinuation { releaseWaiters.append($0) }
        }
        return response
    }

    func waitUntilStarted() async {
        if started {
            return
        }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}
