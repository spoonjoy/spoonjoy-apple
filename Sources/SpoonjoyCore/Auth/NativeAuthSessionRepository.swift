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
    private let exchangeAppleCredential: NativeAppleSignInExchangeOperation
    private let exchangePasswordCredential: NativePasswordSignInExchangeOperation
    private let revoke: NativeRevokeOperation
    private let reusesSavedClientID: Bool
    private let serverBaseURL: URL?
    private let now: @Sendable () -> Date
    private let refreshCoordinator: RefreshCoordinator

    public init(
        vault: any TokenVault,
        clientName: String,
        redirectURI: URL = NativeAuthSession.redirectURI,
        scope: String = NativeAuthSession.defaultScope,
        registerClient: @escaping NativeClientRegistrationOperation,
        exchangeCode: @escaping NativeCodeExchangeOperation,
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
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.vault = vault
        self.clientName = clientName
        self.redirectURI = redirectURI
        self.scope = scope
        self.registerClient = registerClient
        self.exchangeCode = exchangeCode
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
            }
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

        let response = try await exchangeCode(clientID, redirectURI, code, codeVerifier)
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
    }

    public func handleAppleSignInCredential(_ credential: NativeAppleSignInCredential) async throws -> AuthSession {
        _ = try NativeAppleSignInRequests.exchangeCredential(credential)
        let response = try await exchangeAppleCredential(credential)
        let clientID = nativeClientID(issuedIn: response)
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
    }

    public func handlePasswordSignInCredential(_ credential: NativePasswordSignInCredential) async throws -> AuthSession {
        _ = try NativePasswordSignInRequests.exchangeCredential(credential)
        let response = try await exchangePasswordCredential(credential)
        let clientID = nativeClientID(issuedIn: response)
        let session = try AuthSession(
            clientID: clientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
        try await vault.saveClientID(clientID)
        try await vault.saveSession(session)
        return session
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

    public func restoreState() async throws -> NativeAuthSessionState {
        guard let session = try await vault.loadSession() else {
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

    public func bindAccountID(_ accountID: String) async throws -> AuthSession {
        let session = try await validSession()
        let boundSession = try session.bindingAccountID(accountID)
        try await vault.saveSession(boundSession)
        return boundSession
    }

    /// Forgets the stored session and client id without telling the server, for a session the server already
    /// reported as revoked.
    public func clearLocalSession() async throws {
        try await refreshCoordinator.disconnect()
    }

    /// Signs this device out. The local session and saved client ID are always
    /// cleared, even when the server revoke fails (offline, outage, or a client ID
    /// the server no longer recognises), so a shared device can always be signed out.
    /// The server revoke is best-effort.
    public func revokeAndLogout() async throws {
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
