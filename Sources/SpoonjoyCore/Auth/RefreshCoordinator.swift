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

/// Serializes refreshes between coordinators that share one Keychain in one process: the app's sync and each App
/// Intent build their own coordinator, and the server revokes a refresh token the moment it is used, so two of
/// them sending the same token at once sign the loser out. A coordinator holding the lock re-reads the vault first
/// and uses a session another coordinator already stored.
public actor RefreshLock {
    /// The lock for the app's Keychain session.
    public static let keychain = RefreshLock()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func withLock<Value: Sendable>(_ body: @Sendable () async throws -> Value) async throws -> Value {
        await acquire()
        defer { release() }
        return try await body()
    }

    private func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

public actor RefreshCoordinator {
    private let vault: any TokenVault
    private let refresh: OAuthRefreshOperation
    private var inFlightRefresh: Task<RefreshedSession, Error>?
    private var inFlightRefreshToken = ""
    private var inFlightRefreshID = 0
    private var refreshGeneration = 0
    private var rejectedRefreshToken: String?
    private var rejectionWasRevocation = false
    private let alternateClientID: @Sendable (AuthSession) -> String?
    private let serverBaseURL: URL?
    private let refreshLock: RefreshLock?
    private let rotationSettleDelays: [UInt64]
    private let sleep: @Sendable (UInt64) async throws -> Void

    /// `alternateClientID` names a second client id to try once, with the same refresh token, when the server
    /// refuses the stored one. It is for sessions stored before the app kept the server-issued id: those may
    /// carry a guessed id that only works on some servers. Only the id that works is ever saved.
    ///
    /// `serverBaseURL` names the server this coordinator talks to: a stored session another server issued counts as
    /// missing, so its tokens never reach this one. `refreshLock` serializes refreshes with other coordinators on the
    /// same Keychain. After the server refuses a refresh token, the coordinator re-reads the vault once per
    /// `rotationSettleDelays` entry (nanoseconds) before it ends the session, because another process that won the
    /// rotation may still be writing its new session.
    public init(
        vault: any TokenVault,
        refresh: @escaping OAuthRefreshOperation,
        alternateClientID: @escaping @Sendable (AuthSession) -> String? = { _ in nil },
        serverBaseURL: URL? = nil,
        refreshLock: RefreshLock? = nil,
        rotationSettleDelays: [UInt64] = [150_000_000, 350_000_000],
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.vault = vault
        self.refresh = refresh
        self.alternateClientID = alternateClientID
        self.serverBaseURL = serverBaseURL
        self.refreshLock = refreshLock
        self.rotationSettleDelays = rotationSettleDelays
        self.sleep = sleep
    }

    /// The stored session, unless another server issued it.
    private func storedSession() async throws -> AuthSession? {
        guard let session = try await vault.loadSession() else {
            return nil
        }
        if let serverBaseURL, session.wasIssued(elsewhereThan: serverBaseURL) {
            return nil
        }
        return session
    }

    public func sessionState(at date: Date) async throws -> AuthSessionState {
        guard let session = try await storedSession() else {
            return .signedOut
        }

        return session.state(at: date)
    }

    public func validSession(at date: Date) async throws -> AuthSession {
        try await validSession(at: date, rejectedAccessToken: nil, rotationRetriesLeft: 1)
    }

    /// The session to retry with after the server answered 401 to `rejectedAccessToken`. The server may have
    /// revoked that token before its stored expiry, so it is refreshed even when it still looks valid. When the
    /// stored token already differs, another caller has replaced it, and that session is used without a second
    /// refresh; callers that hit 401 together share one refresh.
    public func sessionAfterRejecting(accessToken rejectedAccessToken: String?, at date: Date) async throws -> AuthSession {
        try await validSession(at: date, rejectedAccessToken: rejectedAccessToken, rotationRetriesLeft: 1)
    }

    /// A refresh that loses a rotation race hands back the newer stored session, which may itself need a
    /// refresh, so look again (a bounded number of times) instead of trusting the first answer.
    private func validSession(
        at date: Date,
        rejectedAccessToken: String?,
        rotationRetriesLeft: Int
    ) async throws -> AuthSession {
        guard let session = try await storedSession() else {
            throw TokenRefreshError.missingSession
        }

        if session.accessToken != rejectedAccessToken, case .authenticated = session.state(at: date) {
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
        return try await validSession(
            at: date,
            rejectedAccessToken: rejectedAccessToken,
            rotationRetriesLeft: rotationRetriesLeft - 1
        )
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
        let vault = self.vault
        let refreshLock = self.refreshLock
        let task = Task<RefreshedSession, Error> {
            let send: @Sendable () async throws -> AuthSession = {
                // Another coordinator on this Keychain may have rotated while this one waited for the lock.
                if refreshLock != nil, let stored = try await vault.loadSession(), stored.refreshToken != session.refreshToken {
                    throw RotatedElsewhere(session: stored)
                }
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
            guard let refreshLock else {
                return RefreshedSession(session: try await send(), isStored: false)
            }
            // Store before releasing the lock, so the next coordinator to take it reads the rotated session.
            return try await refreshLock.withLock {
                let refreshed = try await send()
                try await self.store(refreshed, generation: generation)
                return RefreshedSession(session: refreshed, isStored: true)
            }
        }

        inFlightRefreshID += 1
        let id = inFlightRefreshID
        inFlightRefresh = task
        inFlightRefreshToken = session.refreshToken

        let outcome = try await value(of: task, id: id, sentToken: session.refreshToken, generation: generation)
        try ensureCurrentRefreshGeneration(generation)
        if outcome.adoptedFromVault {
            // Already stored: by another process that rotated first (writing it back could overwrite a newer
            // one), or by this refresh while it held the lock.
            return outcome.session
        }
        try await store(outcome.session, generation: generation)
        return outcome.session
    }

    private func store(_ session: AuthSession, generation: Int) async throws {
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveClientID(session.clientID)
        try ensureCurrentRefreshGeneration(generation)
        try await vault.saveSession(session)
        try ensureCurrentRefreshGeneration(generation)
    }

    private func value(
        of task: Task<RefreshedSession, Error>,
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
            let refreshed = try await task.value
            return (refreshed.session, refreshed.isStored)
        } catch let rotated as RotatedElsewhere {
            return (rotated.session, true)
        } catch {
            if TokenRefreshError.isPermanent(error), generation == refreshGeneration {
                // The server revokes a refresh token the moment it is used. Another process on this Keychain
                // (a widget, or App Intents in its own process) may have rotated it first; if the vault holds, or
                // shortly holds, a different token, that session is the live one.
                if let stored = try await sessionRotatedElsewhere(than: sentToken) {
                    return (stored, true)
                }
                rejectedRefreshToken = sentToken
                rejectionWasRevocation = OAuthErrorResponse.isUserRevocation(error)
                throw rejectionWasRevocation ? TokenRefreshError.sessionRevoked : TokenRefreshError.sessionExpired
            }
            throw error
        }
    }

    /// The session another process stored in place of `sentToken`, waiting briefly for a write still in progress.
    private func sessionRotatedElsewhere(than sentToken: String) async throws -> AuthSession? {
        // No temporary array is iterated across the awaits: with Xcode 26's compiler, iterating `[0] + delays` here
        // aborted the test process ("freed pointer was not the last allocation").
        for attempt in 0...rotationSettleDelays.count {
            if attempt > 0 {
                try await sleep(rotationSettleDelays[attempt - 1])
            }
            if let stored = try await vault.loadSession(), stored.refreshToken != sentToken {
                return stored
            }
        }
        return nil
    }

    private func ensureCurrentRefreshGeneration(_ generation: Int) throws {
        guard generation == refreshGeneration else {
            throw CancellationError()
        }
    }
}

private struct RefreshedSession: Sendable {
    let session: AuthSession
    /// True when the refresh already wrote the session to the vault.
    let isStored: Bool
}

/// A coordinator found, after taking the refresh lock, that another coordinator already rotated the session.
private struct RotatedElsewhere: Error {
    let session: AuthSession
}
