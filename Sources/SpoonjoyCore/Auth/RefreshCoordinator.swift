import Foundation

public enum TokenRefreshError: Error, Equatable, Sendable {
    case missingSession
    /// The server refused the refresh token for good (invalid_grant and other 4xx answers). The session
    /// cannot recover without a new sign-in.
    case sessionExpired

    /// True when a refresh failure means the stored session can never refresh: the server answered with a
    /// client error other than "try again later". Network failures, timeouts, rate limits and 5xx answers
    /// are transient and keep the session.
    static func isPermanent(_ error: Error) -> Bool {
        guard let transport = error as? APITransportError, let status = transport.statusCode else {
            return false
        }
        guard (400...499).contains(status) else {
            return false
        }
        return ![408, 425, 429].contains(status)
    }
}

public typealias OAuthRefreshOperation = @Sendable (_ clientID: String, _ refreshToken: String) async throws -> OAuthTokenResponse

public actor RefreshCoordinator {
    private let vault: any TokenVault
    private let refresh: OAuthRefreshOperation
    private var inFlightRefresh: Task<AuthSession, Error>?
    private var refreshGeneration = 0
    private var rejectedRefreshToken: String?

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

        if session.refreshToken == rejectedRefreshToken {
            throw TokenRefreshError.sessionExpired
        }

        return try await refreshedSession(from: session, at: date)
    }

    public func disconnect() async throws {
        refreshGeneration += 1
        rejectedRefreshToken = nil
        inFlightRefresh?.cancel()
        inFlightRefresh = nil
        try await vault.clearSession()
        try await vault.clearClientID()
    }

    private func refreshedSession(from session: AuthSession, at date: Date) async throws -> AuthSession {
        if let inFlightRefresh {
            let generation = refreshGeneration
            let refreshedSession = try await value(of: inFlightRefresh, for: session, generation: generation)
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

        let rotatedSession = try await value(of: task, for: session, generation: generation)
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveClientID(rotatedSession.clientID)
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveSession(rotatedSession)
        try ensureCurrentRefreshGeneration(generation)
        return rotatedSession
    }

    private func value(
        of task: Task<AuthSession, Error>,
        for session: AuthSession,
        generation: Int
    ) async throws -> AuthSession {
        do {
            return try await task.value
        } catch {
            if TokenRefreshError.isPermanent(error), generation == refreshGeneration {
                rejectedRefreshToken = session.refreshToken
                throw TokenRefreshError.sessionExpired
            }
            throw error
        }
    }

    private func ensureCurrentRefreshGeneration(_ generation: Int) throws {
        guard generation == refreshGeneration else {
            throw CancellationError()
        }
    }
}
