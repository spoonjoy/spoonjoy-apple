import Foundation

public enum TokenRefreshError: Error, Equatable, Sendable {
    case missingSession
}

public typealias OAuthRefreshOperation = @Sendable (_ clientID: String, _ refreshToken: String) async throws -> OAuthTokenResponse

public actor RefreshCoordinator {
    private let vault: any TokenVault
    private let refresh: OAuthRefreshOperation
    private var inFlightRefresh: Task<AuthSession, Error>?

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

        switch session.state(at: date) {
        case .signedOut:
            throw TokenRefreshError.missingSession
        case .authenticated:
            return session
        case .refreshRequired:
            return try await refreshedSession(from: session, at: date)
        }
    }

    public func disconnect() async throws {
        try await vault.clearSession()
        try await vault.clearClientID()
    }

    private func refreshedSession(from session: AuthSession, at date: Date) async throws -> AuthSession {
        if let inFlightRefresh {
            return try await inFlightRefresh.value
        }

        let vault = self.vault
        let refresh = self.refresh
        let task = Task<AuthSession, Error> {
            let response = try await refresh(session.clientID, session.refreshToken)
            let rotatedSession = try session.rotated(with: response, receivedAt: date)
            try await vault.saveClientID(rotatedSession.clientID)
            try await vault.saveSession(rotatedSession)
            return rotatedSession
        }

        inFlightRefresh = task
        defer {
            inFlightRefresh = nil
        }

        return try await task.value
    }
}
