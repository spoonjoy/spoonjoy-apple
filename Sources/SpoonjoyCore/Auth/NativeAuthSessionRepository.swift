import Foundation

public typealias NativeClientRegistrationOperation = @Sendable (
    _ clientName: String,
    _ redirectURI: URL
) async throws -> String

public typealias NativeCodeExchangeOperation = @Sendable (
    _ clientID: String,
    _ redirectURI: URL,
    _ code: String,
    _ codeVerifier: String
) async throws -> OAuthTokenResponse

/// The authorization_code exchange with the whole grant, which may carry a pending Apple link
/// (`OAuthRequests.exchangeCode(_:)` sends it). Prefer it to `NativeCodeExchangeOperation`, which cannot.
public typealias NativeAuthorizationCodeExchangeOperation = @Sendable (
    _ grant: NativeAuthorizationCodeGrant
) async throws -> OAuthTokenResponse

public typealias NativeAppleSignInExchangeOperation = @Sendable (
    _ credential: NativeAppleSignInCredential
) async throws -> OAuthTokenResponse

public typealias NativePasswordSignInExchangeOperation = @Sendable (
    _ credential: NativePasswordSignInCredential
) async throws -> OAuthTokenResponse

public typealias NativeRevokeOperation = @Sendable (
    _ refreshToken: String,
    _ clientID: String
) async throws -> Void

public actor NativeAuthSessionRepository {
    private static let requestCollaborators = ["OAuthRequests.refreshToken"]
    private static let vaultClearOperations = ["clearSession", "clearClientID"]

    private let vault: any TokenVault
    private let clientName: String
    public nonisolated let redirectURI: URL
    private let scope: String
    private let registerClient: NativeClientRegistrationOperation
    private let exchangeCode: NativeCodeExchangeOperation
    private let exchangeAuthorizationCode: NativeAuthorizationCodeExchangeOperation?
    private let exchangeAppleCredential: NativeAppleSignInExchangeOperation
    private let exchangePasswordCredential: NativePasswordSignInExchangeOperation
    private let revoke: NativeRevokeOperation
    private let reusesSavedClientID: Bool
    private let serverBaseURL: URL?
    private let now: @Sendable () -> Date
    private let refreshCoordinator: RefreshCoordinator
    private let onPendingAppleLinkEvent: PendingAppleLinkEventHandler
    /// An Apple sign-in that found no account, waiting to be linked by the next sign-in another way. Memory only:
    /// it is never written to the vault. A sign-in that fails, or that succeeds with the server reporting `error`
    /// for the link, hands it back, because the server spent nothing. It goes once a sign-in succeeds, and on
    /// sign-out, expiry, or an Apple sign-in that succeeds.
    private var pendingAppleLink: PendingAppleLink? {
        didSet { pendingAppleLinkGeneration &+= 1 }
    }
    /// Moves on every change to `pendingAppleLink`, so a password attempt hands its link back only when nothing
    /// (sign-out, an Apple sign-in, a newer link) changed it while the attempt was out.
    private var pendingAppleLinkGeneration = 0
    /// True when the last sign-in's server answer said Apple is now connected to the account.
    private var appleConnectedOnLastSignIn = false

    public init(
        vault: any TokenVault,
        clientName: String,
        redirectURI: URL = NativeAuthSession.redirectURI,
        scope: String = NativeAuthSession.defaultScope,
        registerClient: @escaping NativeClientRegistrationOperation,
        exchangeCode: @escaping NativeCodeExchangeOperation,
        exchangeAuthorizationCode: NativeAuthorizationCodeExchangeOperation? = nil,
        exchangeAppleCredential: @escaping NativeAppleSignInExchangeOperation = { _ in
            throw NativeAuthSessionError.appleSignInUnavailable
        },
        exchangePasswordCredential: @escaping NativePasswordSignInExchangeOperation = { _ in
            throw NativeAuthSessionError.passwordSignInUnavailable
        },
        refresh: @escaping OAuthRefreshOperation,
        revoke: @escaping NativeRevokeOperation,
        reusesSavedClientID: Bool = true,
        serverBaseURL: URL? = nil,
        refreshLock: RefreshLock? = nil,
        now: @escaping @Sendable () -> Date = Date.init,
        onPendingAppleLinkEvent: @escaping PendingAppleLinkEventHandler = { _ in }
    ) {
        self.vault = vault
        self.clientName = clientName
        self.redirectURI = redirectURI
        self.scope = scope
        self.registerClient = registerClient
        self.exchangeCode = exchangeCode
        self.exchangeAuthorizationCode = exchangeAuthorizationCode
        self.onPendingAppleLinkEvent = onPendingAppleLinkEvent
        self.exchangeAppleCredential = exchangeAppleCredential
        self.exchangePasswordCredential = exchangePasswordCredential
        self.revoke = revoke
        self.reusesSavedClientID = reusesSavedClientID
        self.serverBaseURL = serverBaseURL
        self.now = now
        // Sessions stored before the app kept the server-issued client id carry the plain native id, which only
        // production issues. Elsewhere the first refresh uses that stored id (it may still work, because a
        // rotation keeps the id the tokens were issued to); if the server refuses it, the coordinator tries the
        // id this server derives, once, and saves only the id that worked.
        let derivedClientID = serverBaseURL.map(NativeAuthSession.nativeClientID(forServerBaseURL:))
        self.refreshCoordinator = RefreshCoordinator(
            vault: vault,
            refresh: refresh,
            alternateClientID: { session in
                guard session.clientID == NativeAuthSession.nativeAppClientID,
                      let derivedClientID,
                      derivedClientID != session.clientID else {
                    return nil
                }
                return derivedClientID
            },
            refreshLock: refreshLock
        )
    }

    public func startSignIn(
        state: OAuthState,
        codeChallenge: String,
        providerHint: OAuthProviderHint? = nil
    ) async throws -> NativeAuthSignInStart {
        _ = try OAuthRequests.registerClient(clientName: clientName, redirectURIs: [redirectURI])
        let clientID: String
        if reusesSavedClientID, let savedClientID = try await vault.loadClientID() {
            clientID = savedClientID
        } else {
            clientID = try await registerClient(clientName, redirectURI)
            try await vault.saveClientID(clientID)
        }

        return try NativeAuthSignInStart(
            clientID: clientID,
            redirectURI: redirectURI,
            authorizationURL: NativeAuthSession.authorizationURL(
                clientID: clientID,
                redirectURI: redirectURI,
                scope: scope,
                state: state,
                codeChallenge: codeChallenge,
                providerHint: providerHint
            ),
            providerHint: providerHint
        )
    }

    public func handleOAuthCallback(
        _ callbackURL: URL,
        expectedState: OAuthState,
        codeVerifier: String
    ) async throws -> AuthSession {
        let code = try NativeAuthSession.code(
            from: callbackURL,
            expectedState: expectedState,
            redirectURI: redirectURI
        )
        guard let clientID = try await vault.loadClientID() else {
            throw NativeAuthSessionError.missingClientID
        }
        _ = try OAuthRequests.exchangeCode(
            clientID: clientID,
            redirectURI: redirectURI,
            code: code,
            codeVerifier: codeVerifier
        )

        appleConnectedOnLastSignIn = false
        let response: OAuthTokenResponse
        if let exchangeAuthorizationCode {
            let taken = await takePendingAppleLink(sendingVia: .browser)
            do {
                response = try await exchangeAuthorizationCode(NativeAuthorizationCodeGrant(
                    clientID: clientID,
                    redirectURI: redirectURI,
                    code: code,
                    codeVerifier: codeVerifier,
                    pendingAppleLinkToken: taken?.link.token
                ))
            } catch {
                // The server claims the link only after it has spent the code, so a refused or lost exchange used
                // nothing.
                await handBack(taken)
                throw error
            }
            await reportOutcome(of: taken, in: response)
        } else {
            response = try await exchangeCode(clientID, redirectURI, code, codeVerifier)
        }
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope,
            serverOrigin: serverOrigin
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
    }

    public func handleAppleSignInCredential(_ credential: NativeAppleSignInCredential) async throws -> AuthSession {
        _ = try NativeAppleSignInRequests.exchangeCredential(credential)
        let response: OAuthTokenResponse
        do {
            response = try await exchangeAppleCredential(credential)
        } catch {
            if let link = PendingAppleLink.from(error, receivedAt: now()) {
                pendingAppleLink = link
                await onPendingAppleLinkEvent(.received)
            }
            // The token stays here; what leaves the repository can be shown and logged.
            throw PendingAppleLink.redacting(error)
        }
        // Apple signs in on its own now, so nothing is left to link.
        pendingAppleLink = nil
        appleConnectedOnLastSignIn = false
        let clientID = nativeClientID(issuedIn: response)
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope,
            serverOrigin: serverOrigin
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
    }

    public func handlePasswordSignInCredential(_ credential: NativePasswordSignInCredential) async throws -> AuthSession {
        _ = try NativePasswordSignInRequests.exchangeCredential(credential)
        appleConnectedOnLastSignIn = false
        let taken = await takePendingAppleLink(sendingVia: .password)
        let response: OAuthTokenResponse
        do {
            response = try await exchangePasswordCredential(credential.linkingApple(taken?.link))
        } catch {
            // The server spends a link only on a sign-in that succeeds, so a mistyped password must not cost the
            // chef their Apple link.
            await handBack(taken)
            throw error
        }
        await reportOutcome(of: taken, in: response)
        let clientID = nativeClientID(issuedIn: response)
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope,
            serverOrigin: serverOrigin
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
    }

    /// True while an Apple sign-in that found no account is waiting for the next sign-in another way to link it.
    public func hasPendingAppleLink() async -> Bool {
        await currentPendingAppleLink() != nil
    }

    /// The pending link, or nil once it has expired (which forgets it).
    private func currentPendingAppleLink() async -> PendingAppleLink? {
        guard let link = pendingAppleLink else {
            return nil
        }
        guard !link.isExpired(at: now()) else {
            pendingAppleLink = nil
            await onPendingAppleLinkEvent(.expired)
            return nil
        }
        return link
    }

    /// The pending link for the sign-in about to go out, forgotten as it is handed over so no other sign-in sends it
    /// too, with the generation it left behind. The generation is read before the event is reported, because the
    /// actor can run a sign-out or a newer Apple answer during that await, and the caller must see either as a
    /// change.
    private func takePendingAppleLink(
        sendingVia method: PendingAppleLinkEvent.Method
    ) async -> (link: PendingAppleLink, generation: Int)? {
        guard let link = await currentPendingAppleLink() else {
            return nil
        }
        pendingAppleLink = nil
        let generation = pendingAppleLinkGeneration
        await onPendingAppleLinkEvent(.sent(via: method))
        return (link, generation)
    }

    /// Puts a link that went out back, when the server spent nothing, unless something changed the pending link
    /// (sign-out, an Apple sign-in, a newer link) while it was out. A sign-in that did succeed but whose answer was
    /// lost leaves a spent link; the server answers its next use with `consumed`, which is harmless.
    private func handBack(_ taken: (link: PendingAppleLink, generation: Int)?) async {
        guard let taken, pendingAppleLinkGeneration == taken.generation else {
            return
        }
        pendingAppleLink = taken.link
        await onPendingAppleLinkEvent(.kept)
    }

    private func reportOutcome(of taken: (link: PendingAppleLink, generation: Int)?, in response: OAuthTokenResponse) async {
        guard taken != nil, let outcome = response.appleLinkOutcome else {
            return
        }
        appleConnectedOnLastSignIn = PendingAppleLinkEvent.connectedOutcomes.contains(outcome)
        await onPendingAppleLinkEvent(.outcome(outcome))
        // `error` means the server could not write the link and put it back so a retry can still link.
        if outcome == "error" {
            await handBack(taken)
        }
    }

    /// True once after a sign-in whose server answer said Apple is now connected to the account (`linked`, or
    /// `already_linked`), so the screen can say so; false after that, and after any other sign-in.
    public func takeAppleConnectedConfirmation() -> Bool {
        defer { appleConnectedOnLastSignIn = false }
        return appleConnectedOnLastSignIn
    }

    /// The client id the server issued a native sign-in's tokens to: the response's own `client_id`, else the
    /// id the server derives for this server origin.
    private func nativeClientID(issuedIn response: OAuthTokenResponse) -> String {
        if let issued = response.clientID?.trimmingCharacters(in: .whitespacesAndNewlines), !issued.isEmpty {
            return issued
        }
        return derivedNativeClientID ?? NativeAuthSession.nativeAppClientID
    }

    private var derivedNativeClientID: String? {
        serverBaseURL.map(NativeAuthSession.nativeClientID(forServerBaseURL:))
    }

    private var serverOrigin: String? {
        serverBaseURL.map(NativeAuthSession.canonicalOrigin(of:))
    }

    /// The stored session, or signed out. A session another server issued is forgotten, client id included, so its
    /// tokens never reach this server: a build pointed at production must not send a QA token, or the reverse.
    public func restoreState() async throws -> NativeAuthSessionState {
        guard let session = try await vault.loadSession() else {
            return .signedOut
        }
        if let serverBaseURL, session.wasIssued(elsewhereThan: serverBaseURL) {
            try await vault.clearSession()
            try await vault.clearClientID()
            return .signedOut
        }

        if case .authenticated = session.state(at: now()) {
            return .authenticated(session)
        }

        return .refreshRequired(session)
    }

    public func validSession() async throws -> AuthSession {
        try await refreshCoordinator.validSession(at: now())
    }

    /// The session to retry with after the server answered 401 to `rejectedAccessToken`: a forced refresh, or
    /// the session another caller already refreshed. A refused refresh ends the session as `validSession` does.
    public func sessionAfterRejecting(accessToken rejectedAccessToken: String?) async throws -> AuthSession {
        try await refreshCoordinator.sessionAfterRejecting(accessToken: rejectedAccessToken, at: now())
    }

    public func bindAccountID(_ accountID: String) async throws -> AuthSession {
        let session = try await validSession()
        let boundSession = try session.bindingAccountID(accountID)
        try await vault.saveSession(boundSession)
        return boundSession
    }

    /// Forgets the stored session and client id without telling the server, for a session the server already
    /// reported as revoked, or after the account itself was deleted (the server dropped every token with it).
    public func clearLocalSession() async throws {
        pendingAppleLink = nil
        appleConnectedOnLastSignIn = false
        try await refreshCoordinator.disconnect()
    }

    /// Signs this device out. The local session and saved client ID are always
    /// cleared, even when the server revoke fails (offline, outage, or a client ID
    /// the server no longer recognises), so a shared device can always be signed out.
    /// The server revoke is best-effort.
    public func revokeAndLogout() async throws {
        pendingAppleLink = nil
        appleConnectedOnLastSignIn = false
        if let session = try? await vault.loadSession() {
            do {
                _ = try OAuthRequests.revoke(refreshToken: session.refreshToken, clientID: session.clientID)
                try await revoke(session.refreshToken, session.clientID)
            } catch {
                // Best-effort: the local sign-out below must still happen.
            }
        }
        try await refreshCoordinator.disconnect()
    }
}
