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
        self.now = now
        self.refreshCoordinator = RefreshCoordinator(vault: vault, refresh: refresh)
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
        let session = try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(session)
        return session
    }

    public func handlePasswordSignInCredential(_ credential: NativePasswordSignInCredential) async throws -> AuthSession {
        _ = try NativePasswordSignInRequests.exchangeCredential(credential)
        let response = try await exchangePasswordCredential(credential)
        let session = try AuthSession(
            clientID: NativeAuthSession.nativeAppClientID,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            scope: response.scope
        )
        try await vault.saveClientID(NativeAuthSession.nativeAppClientID)
        try await vault.saveSession(session)
        return session
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

    public func revokeAndLogout() async throws {
        if let session = try await vault.loadSession() {
            _ = try OAuthRequests.revoke(refreshToken: session.refreshToken, clientID: session.clientID)
            try await revoke(session.refreshToken, session.clientID)
        }
        try await refreshCoordinator.disconnect()
    }
}
