import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Token vault and refresh coordination")
struct TokenRefreshTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("auth sessions validate, classify state, and rotate token responses")
    func authSessionsValidateClassifyStateAndRotateTokenResponses() throws {
        let session = try authSession(
            accessToken: " sj_access_old ",
            refreshToken: " ort_refresh_old ",
            expiresAt: now.addingTimeInterval(900)
        )
        let expired = try authSession(
            accessToken: "sj_access_expired",
            refreshToken: "ort_refresh_expired",
            expiresAt: now.addingTimeInterval(-1)
        )
        let rotated = try expired.rotated(
            with: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 600),
            receivedAt: now
        )

        #expect(session.clientID == "cm_client_id")
        #expect(session.accessToken == "sj_access_old")
        #expect(session.refreshToken == "ort_refresh_old")
        #expect(session.authorizationHeader == "Bearer sj_access_old")
        #expect(session.state(at: now) == .authenticated(accessToken: "sj_access_old", expiresAt: now.addingTimeInterval(900)))
        #expect(expired.state(at: now) == .refreshRequired(refreshToken: "ort_refresh_expired"))
        #expect(rotated.clientID == "cm_client_id")
        #expect(rotated.accessToken == "sj_access_new")
        #expect(rotated.refreshToken == "ort_refresh_new")
        #expect(rotated.expiresAt == now.addingTimeInterval(600))
        #expect(rotated.scope == "shopping_list:read shopping_list:write")

        #expect(throws: AuthSessionError.self) {
            try authSession(clientID: " \n ", accessToken: "sj_access", refreshToken: "ort_refresh", expiresAt: now)
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: " \n ", refreshToken: "ort_refresh", expiresAt: now)
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: "sj_access", refreshToken: " \n ", expiresAt: now)
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: "sj_access", refreshToken: "ort_refresh", tokenType: " \n ", expiresAt: now)
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: "sj_access", refreshToken: "ort_refresh", tokenType: "Basic", expiresAt: now)
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: "sj_access", refreshToken: "ort_refresh", expiresAt: now, scope: " \n ")
        }
        #expect(throws: AuthSessionError.self) {
            try authSession(accessToken: "sj_access", refreshToken: "ort_refresh", expiresAt: now, scope: "shopping_list:read")
        }
        #expect(throws: AuthSessionError.self) {
            try expired.rotated(
                with: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 0),
                receivedAt: now
            )
        }
        #expect(throws: AuthSessionError.self) {
            try expired.rotated(
                with: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", tokenType: "Basic", expiresIn: 600),
                receivedAt: now
            )
        }
        #expect(throws: AuthSessionError.self) {
            try expired.rotated(
                with: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 600, scope: "profile"),
                receivedAt: now
            )
        }
    }

    @Test("token vault persists client id and sessions independently")
    func tokenVaultPersistsClientIDAndSessionsIndependently() async throws {
        let vault: any TokenVault = InMemoryTokenVault()
        let session = try authSession(accessToken: "sj_access", refreshToken: "ort_refresh", expiresAt: now)

        #expect(try await vault.loadClientID() == nil)
        #expect(try await vault.loadSession() == nil)

        try await vault.saveClientID(" cm_client_id ")
        try await vault.saveSession(session)
        #expect(try await vault.loadClientID() == "cm_client_id")
        #expect(try await vault.loadSession() == session)

        var blankClientIDRejected = false
        do {
            try await vault.saveClientID(" \n ")
        } catch AuthSessionError.invalidClientID {
            blankClientIDRejected = true
        }
        #expect(blankClientIDRejected)
        #expect(try await vault.loadClientID() == "cm_client_id")

        try await vault.clearSession()
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == "cm_client_id")

        try await vault.clearClientID()
        #expect(try await vault.loadClientID() == nil)
    }

    @Test("refresh coordinator returns valid sessions without network refresh")
    func refreshCoordinatorReturnsValidSessionsWithoutNetworkRefresh() async throws {
        let vault = InMemoryTokenVault()
        let session = try authSession(accessToken: "sj_access_valid", refreshToken: "ort_refresh", expiresAt: now.addingTimeInterval(900))
        try await vault.saveSession(session)
        let coordinator = RefreshCoordinator(vault: vault) { _, _ in
            throw RefreshSpyError.unexpectedRefresh
        }

        #expect(try await coordinator.sessionState(at: now) == .authenticated(accessToken: "sj_access_valid", expiresAt: now.addingTimeInterval(900)))
        #expect(try await coordinator.validSession(at: now) == session)
    }

    @Test("refresh coordinator shares one concurrent refresh and rotates tokens atomically")
    func refreshCoordinatorSharesOneConcurrentRefreshAndRotatesTokensAtomically() async throws {
        let vault = InMemoryTokenVault()
        let expired = try authSession(accessToken: "sj_access_old", refreshToken: "ort_refresh_old", expiresAt: now.addingTimeInterval(-1))
        try await vault.saveSession(expired)
        let spy = RefreshSpy(response: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 600))
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await spy.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        async let first = coordinator.validSession(at: now)
        async let second = coordinator.validSession(at: now)
        let firstSession = try await first
        let secondSession = try await second
        let spySnapshot = await spy.snapshot()

        #expect(firstSession == secondSession)
        #expect(firstSession.accessToken == "sj_access_new")
        #expect(firstSession.refreshToken == "ort_refresh_new")
        #expect(firstSession.expiresAt == now.addingTimeInterval(600))
        #expect(try await vault.loadSession() == firstSession)
        #expect(spySnapshot.calls == 1)
        #expect(spySnapshot.requests == [RefreshRequest(clientID: "cm_client_id", refreshToken: "ort_refresh_old")])
    }

    @Test("refresh failures preserve prior session and disconnect clears auth state")
    func refreshFailuresPreservePriorSessionAndDisconnectClearsAuthState() async throws {
        let vault = InMemoryTokenVault()
        let expired = try authSession(accessToken: "sj_access_old", refreshToken: "ort_refresh_old", expiresAt: now.addingTimeInterval(-1))
        try await vault.saveClientID("cm_client_id")
        try await vault.saveSession(expired)
        let coordinator = RefreshCoordinator(vault: vault) { _, _ in
            throw RefreshSpyError.offline
        }

        var refreshFailed = false
        do {
            _ = try await coordinator.validSession(at: now)
        } catch RefreshSpyError.offline {
            refreshFailed = true
        }
        #expect(refreshFailed)
        #expect(try await vault.loadSession() == expired)

        try await coordinator.disconnect()
        #expect(try await coordinator.sessionState(at: now) == .signedOut)
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
    }

    @Test("disconnect cancels in-flight refresh and prevents session resurrection")
    func disconnectCancelsInFlightRefreshAndPreventsSessionResurrection() async throws {
        let vault = InMemoryTokenVault()
        let expired = try authSession(accessToken: "sj_access_old", refreshToken: "ort_refresh_old", expiresAt: now.addingTimeInterval(-1))
        try await vault.saveClientID("cm_client_id")
        try await vault.saveSession(expired)
        let gate = RefreshGate(response: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 600))
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await gate.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        async let refreshResult = coordinator.validSession(at: now)
        await gate.waitUntilStarted()
        try await coordinator.disconnect()
        await gate.finish()
        let result = try? await refreshResult

        #expect(result == nil)
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(await gate.calls == 1)
    }

    @Test("disconnect invalidates every waiter on a shared in-flight refresh")
    func disconnectInvalidatesEveryWaiterOnSharedInFlightRefresh() async throws {
        let vault = InMemoryTokenVault()
        let expired = try authSession(accessToken: "sj_access_old", refreshToken: "ort_refresh_old", expiresAt: now.addingTimeInterval(-1))
        try await vault.saveClientID("cm_client_id")
        try await vault.saveSession(expired)
        let gate = RefreshGate(response: tokenResponse(accessToken: "sj_access_new", refreshToken: "ort_refresh_new", expiresIn: 600))
        let coordinator = RefreshCoordinator(vault: vault) { clientID, refreshToken in
            try await gate.refresh(clientID: clientID, refreshToken: refreshToken)
        }

        async let first = coordinator.validSession(at: now)
        await gate.waitUntilStarted()
        async let second = coordinator.validSession(at: now)
        try await Task.sleep(nanoseconds: 5_000_000)
        try await coordinator.disconnect()
        await gate.finish()
        let firstResult = try? await first
        let secondResult = try? await second

        #expect(firstResult == nil)
        #expect(secondResult == nil)
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(await gate.calls == 1)
    }

    @Test("missing sessions are invalid refresh state")
    func missingSessionsAreInvalidRefreshState() async throws {
        let coordinator = RefreshCoordinator(vault: InMemoryTokenVault()) { _, _ in
            throw RefreshSpyError.unexpectedRefresh
        }

        #expect(try await coordinator.sessionState(at: now) == .signedOut)

        var missingSession = false
        do {
            _ = try await coordinator.validSession(at: now)
        } catch TokenRefreshError.missingSession {
            missingSession = true
        }
        #expect(missingSession)
    }

    private func authSession(
        clientID: String = "cm_client_id",
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresAt: Date,
        scope: String = "shopping_list:read shopping_list:write"
    ) throws -> AuthSession {
        try AuthSession(
            clientID: clientID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: expiresAt,
            scope: scope
        )
    }

    private func tokenResponse(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: Int,
        scope: String = "shopping_list:read shopping_list:write"
    ) -> OAuthTokenResponse {
        OAuthTokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope
        )
    }
}

private actor RefreshSpy {
    private var callsCount = 0
    private var capturedRequests: [RefreshRequest] = []
    private let response: OAuthTokenResponse

    init(response: OAuthTokenResponse) {
        self.response = response
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        callsCount += 1
        capturedRequests.append(RefreshRequest(clientID: clientID, refreshToken: refreshToken))
        try await Task.sleep(nanoseconds: 25_000_000)
        return response
    }

    func snapshot() -> (calls: Int, requests: [RefreshRequest]) {
        (callsCount, capturedRequests)
    }
}

private actor RefreshGate {
    private var callsCount = 0
    private var startedContinuations: [CheckedContinuation<Void, Never>] = []
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var shouldFinish = false
    private let response: OAuthTokenResponse

    init(response: OAuthTokenResponse) {
        self.response = response
    }

    var calls: Int {
        callsCount
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        callsCount += 1
        startedContinuations.forEach { $0.resume() }
        startedContinuations.removeAll()
        if !shouldFinish {
            await withCheckedContinuation { continuation in
                finishContinuation = continuation
            }
        }
        return response
    }

    func waitUntilStarted() async {
        if callsCount > 0 {
            return
        }

        await withCheckedContinuation { continuation in
            startedContinuations.append(continuation)
        }
    }

    func finish() {
        shouldFinish = true
        finishContinuation?.resume()
        finishContinuation = nil
    }
}

private struct RefreshRequest: Equatable, Sendable {
    let clientID: String
    let refreshToken: String
}

private enum RefreshSpyError: Error, Equatable {
    case offline
    case unexpectedRefresh
}
