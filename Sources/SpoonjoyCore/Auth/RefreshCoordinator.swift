import Foundation

public enum TokenRefreshError: Error, Equatable, Sendable {
    case missingSession
}

public typealias OAuthRefreshOperation = @Sendable (_ clientID: String, _ refreshToken: String) async throws -> OAuthTokenResponse

public actor RefreshCoordinator {
    private let vault: any TokenVault
    private let refresh: OAuthRefreshOperation
    private var inFlightRefresh: Task<AuthSession, Error>?
    private var refreshGeneration = 0

    public init(
        vault: any TokenVault,
        refresh: @escaping OAuthRefreshOperation
    ) {
        self.vault = vault
        self.refresh = refresh
    }

    public func sessionState(at date: Date) async throws -> AuthSessionState {
        guard let session = try await vault.loadSession() else {
            return .signedOut
        }

        return session.state(at: date)
    }

    public func validSession(at date: Date) async throws -> AuthSession {
        guard let session = try await vault.loadSession() else {
            throw TokenRefreshError.missingSession
        }

        if case .authenticated = session.state(at: date) {
            return session
        }

        return try await refreshedSession(from: session, at: date)
    }

    public func disconnect() async throws {
        refreshGeneration += 1
        inFlightRefresh?.cancel()
        inFlightRefresh = nil
        try await vault.clearSession()
        try await vault.clearClientID()
    }

    private func refreshedSession(from session: AuthSession, at date: Date) async throws -> AuthSession {
        if let inFlightRefresh {
            let generation = refreshGeneration
            let refreshedSession = try await inFlightRefresh.value
            try ensureCurrentRefreshGeneration(generation)
            return refreshedSession
        }

        let refresh = self.refresh
        let generation = refreshGeneration
        let task = Task<AuthSession, Error> {
            let response = try await refresh(session.clientID, session.refreshToken)
            return try session.rotated(with: response, receivedAt: date)
        }

        inFlightRefresh = task
        defer {
            inFlightRefresh = nil
        }

        let rotatedSession = try await task.value
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveClientID(rotatedSession.clientID)
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveSession(rotatedSession)
        try ensureCurrentRefreshGeneration(generation)
        return rotatedSession
    }

    private func ensureCurrentRefreshGeneration(_ generation: Int) throws {
        guard generation == refreshGeneration else {
            throw CancellationError()
        }
    }
}
