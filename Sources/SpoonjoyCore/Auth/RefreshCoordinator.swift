import Foundation

public enum TokenRefreshError: Error, Equatable, Sendable {
    case missingSession
    /// The server refused the refresh token for good (an `invalid_grant` or `invalid_client` OAuth error). The
    /// session cannot recover without a new sign-in.
    case sessionExpired
    /// The server refused the refresh token and said the chef revoked the session on purpose. The device must
    /// forget the account's private data, not just ask for a new sign-in.
    case sessionRevoked
    /// Several processes kept rotating the refresh token while this one tried to refresh, and the session it
    /// ended with still needs a refresh. Nothing is wrong with the session; trying again later settles it.
    case refreshInconclusive

    /// True when a refresh failure means the stored session can never refresh: the server answered with an
    /// OAuth `invalid_grant` or `invalid_client` error. Everything else is transient and keeps the session:
    /// network failures, timeouts, rate limits, 5xx answers, and 4xx answers that are not an OAuth refusal
    /// (a proxy's HTML 403, a 404, a 413).
    static func isPermanent(_ error: Error) -> Bool {
        OAuthErrorResponse.isPermanentRefusal(error)
    }
}

public typealias OAuthRefreshOperation = @Sendable (_ clientID: String, _ refreshToken: String) async throws -> OAuthTokenResponse

public actor RefreshCoordinator {
    private let vault: any TokenVault
    private let refresh: OAuthRefreshOperation
    private var inFlightRefresh: Task<AuthSession, Error>?
    private var inFlightRefreshToken = ""
    private var inFlightRefreshID = 0
    private var refreshGeneration = 0
    private var rejectedRefreshToken: String?
    private var rejectionWasRevocation = false
    private let alternateClientID: @Sendable (AuthSession) -> String?

    /// `alternateClientID` names a second client id to try once, with the same refresh token, when the server
    /// refuses the stored one. It is for sessions stored before the app kept the server-issued id: those may
    /// carry a guessed id that only works on some servers. Only the id that works is ever saved.
    public init(
        vault: any TokenVault,
        refresh: @escaping OAuthRefreshOperation,
        alternateClientID: @escaping @Sendable (AuthSession) -> String? = { _ in nil }
    ) {
        self.vault = vault
        self.refresh = refresh
        self.alternateClientID = alternateClientID
    }

    public func sessionState(at date: Date) async throws -> AuthSessionState {
        guard let session = try await vault.loadSession() else {
            return .signedOut
        }

        return session.state(at: date)
    }

    public func validSession(at date: Date) async throws -> AuthSession {
        try await validSession(at: date, rotationRetriesLeft: 1)
    }

    /// A refresh that loses a rotation race hands back the newer stored session, which may itself need a
    /// refresh, so look again (a bounded number of times) instead of trusting the first answer.
    private func validSession(at date: Date, rotationRetriesLeft: Int) async throws -> AuthSession {
        guard let session = try await vault.loadSession() else {
            throw TokenRefreshError.missingSession
        }

        if case .authenticated = session.state(at: date) {
            return session
        }

        if session.refreshToken == rejectedRefreshToken {
            throw rejectionWasRevocation ? TokenRefreshError.sessionRevoked : TokenRefreshError.sessionExpired
        }

        let refreshed = try await refreshedSession(from: session, at: date)
        if case .authenticated = refreshed.state(at: date) {
            return refreshed
        }
        guard rotationRetriesLeft > 0 else {
            throw TokenRefreshError.refreshInconclusive
        }
        return try await validSession(at: date, rotationRetriesLeft: rotationRetriesLeft - 1)
    }

    public func disconnect() async throws {
        refreshGeneration += 1
        rejectedRefreshToken = nil
        rejectionWasRevocation = false
        inFlightRefresh?.cancel()
        inFlightRefresh = nil
        inFlightRefreshToken = ""
        inFlightRefreshID += 1
        try await vault.clearSession()
        try await vault.clearClientID()
    }

    private func refreshedSession(from session: AuthSession, at date: Date) async throws -> AuthSession {
        if let inFlightRefresh {
            let generation = refreshGeneration
            // The joined refresh sent its own token, which may differ from the one this caller loaded.
            let sentToken = inFlightRefreshToken
            let outcome = try await value(of: inFlightRefresh, id: inFlightRefreshID, sentToken: sentToken, generation: generation)
            try ensureCurrentRefreshGeneration(generation)
            return outcome.session
        }

        let refresh = self.refresh
        let alternateClientID = self.alternateClientID(session)
        let generation = refreshGeneration
        let task = Task<AuthSession, Error> {
            do {
                let response = try await refresh(session.clientID, session.refreshToken)
                return try session.rotated(with: response, receivedAt: date)
            } catch {
                // The stored client id may have been a guess. Try the other candidate once; only a success is kept.
                guard TokenRefreshError.isPermanent(error), let candidate = alternateClientID else {
                    throw error
                }
                let response = try await refresh(candidate, session.refreshToken)
                return try session.replacingClientID(candidate).rotated(with: response, receivedAt: date)
            }
        }

        inFlightRefreshID += 1
        let id = inFlightRefreshID
        inFlightRefresh = task
        inFlightRefreshToken = session.refreshToken

        let outcome = try await value(of: task, id: id, sentToken: session.refreshToken, generation: generation)
        try ensureCurrentRefreshGeneration(generation)
        if outcome.adoptedFromVault {
            // Another process rotated first and already stored this session; writing it back could overwrite
            // a newer one.
            return outcome.session
        }
        try await vault.saveClientID(outcome.session.clientID)
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveSession(outcome.session)
        try ensureCurrentRefreshGeneration(generation)
        return outcome.session
    }

    private func value(
        of task: Task<AuthSession, Error>,
        id: Int,
        sentToken: String,
        generation: Int
    ) async throws -> (session: AuthSession, adoptedFromVault: Bool) {
        // Whoever sees the refresh finish first retires it, so a caller that resumes next never joins a refresh
        // that already ended and replays its answer.
        defer {
            if inFlightRefreshID == id {
                inFlightRefresh = nil
                inFlightRefreshToken = ""
            }
        }
        do {
            return (try await task.value, false)
        } catch {
            if TokenRefreshError.isPermanent(error), generation == refreshGeneration {
                // The server revokes a refresh token the moment it is used. Another process on this Keychain
                // (App Intents runs its own coordinator) may have rotated it first; if the vault now holds a
                // different token, that session is the live one.
                if let stored = try await vault.loadSession(), stored.refreshToken != sentToken {
                    return (stored, true)
                }
                rejectedRefreshToken = sentToken
                rejectionWasRevocation = OAuthErrorResponse.isUserRevocation(error)
                throw rejectionWasRevocation ? TokenRefreshError.sessionRevoked : TokenRefreshError.sessionExpired
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
