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
    /// it is never written to the vault, and it goes with one sign-in attempt, sign-out, expiry, or an Apple
    /// sign-in that succeeds.
    private var pendingAppleLink: PendingAppleLink?

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

        let response: OAuthTokenResponse
        if let exchangeAuthorizationCode {
            let link = await takePendingAppleLink(sendingVia: .browser)
            response = try await exchangeAuthorizationCode(NativeAuthorizationCodeGrant(
                clientID: clientID,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: codeVerifier,
                pendingAppleLinkToken: link?.token
            ))
            await reportOutcome(of: link, in: response)
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
        let link = await takePendingAppleLink(sendingVia: .password)
        let response = try await exchangePasswordCredential(credential.linkingApple(link))
        await reportOutcome(of: link, in: response)
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

    /// The pending link for the sign-in about to go out, forgotten as it is handed over: the server spends it on
    /// the first sign-in that succeeds, so one attempt carries it whatever that attempt's result.
    private func takePendingAppleLink(sendingVia method: PendingAppleLinkEvent.Method) async -> PendingAppleLink? {
        guard let link = await currentPendingAppleLink() else {
            return nil
        }
        pendingAppleLink = nil
        await onPendingAppleLinkEvent(.sent(via: method))
        return link
    }

    private func reportOutcome(of link: PendingAppleLink?, in response: OAuthTokenResponse) async {
        guard link != nil, let outcome = response.appleLinkOutcome else {
            return
        }
        await onPendingAppleLinkEvent(.outcome(outcome))
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
        try await refreshCoordinator.disconnect()
    }

    /// Signs this device out. The local session and saved client ID are always
    /// cleared, even when the server revoke fails (offline, outage, or a client ID
    /// the server no longer recognises), so a shared device can always be signed out.
    /// The server revoke is best-effort.
    public func revokeAndLogout() async throws {
        pendingAppleLink = nil
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
