import Foundation
import Security
import Testing
@testable import SpoonjoyCore

@Suite("Native auth session contract")
struct NativeAuthSessionTests {
    @Test("OAuth callback contract uses universal links and rejects custom schemes")
    func oauthCallbackContractUsesUniversalLinksAndRejectsCustomSchemes() throws {
        #expect(try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/oauth/callback")!))
        #expect(DeepLinkRouter.spoonjoy.route(for: URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!) == .unknownLink)
        #expect(DeepLinkRouter.spoonjoy.route(for: URL(string: "spoonjoy://oauth/callback?code=oac_code&state=state_123")!) == .unknownLink)

        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/not-oauth")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "https://spoonjoy.app/oauth/callback/extra")!)
        }
        #expect(throws: OAuthRedirectValidationError.self) {
            try OAuthRedirectValidator.validate(URL(string: "spoonjoy://oauth/callback")!)
        }
    }

    @Test("native auth repository behavior persists client id rotates refresh tokens revokes and restores state")
    func nativeAuthRepositoryBehaviorPersistsClientIDRotatesRefreshTokensRevokesAndRestoresState() throws {
        let result = try runSwiftContractPackage(
            name: "NativeAuthBehaviorProbe",
            testSource: nativeAuthBehaviorContractSource
        )

        #expect(result.status == 0, Comment(rawValue: result.truncatedOutput))
    }

    @Test("native auth implementation is covered in process")
    func nativeAuthImplementationIsCoveredInProcess() async throws {
        let now = Date(timeIntervalSince1970: 1_781_612_800)
        let vault = InMemoryTokenVault()
        let network = CoverageAuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: coverageTokenResponse(accessToken: "sj_access_initial", refreshToken: "ort_refresh_initial", expiresIn: 300),
            refreshResponse: coverageTokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600),
            appleResponse: coverageTokenResponse(accessToken: "sj_access_apple", refreshToken: "ort_refresh_apple", expiresIn: 900),
            passwordResponse: coverageTokenResponse(accessToken: "sj_access_password", refreshToken: "ort_refresh_password", expiresIn: 900)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: NativeAuthSession.redirectURI,
            scope: NativeAuthSession.defaultScope,
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            exchangeAppleCredential: network.exchangeAppleCredential,
            exchangePasswordCredential: network.exchangePasswordCredential,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )

        #expect(try await repository.restoreState() == .signedOut)
        let state = try #require(OAuthState(rawValue: "state_123"))
        let start = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(start.clientID == "cm_native_spoonjoy")
        #expect(start.authorizationURL.path == "/oauth/authorize")
        #expect(Set(NativeAuthSession.defaultScope.split(separator: " ").map(String.init)) == Set([
            "kitchen:read",
            "kitchen:write",
            "shopping_list:read",
            "shopping_list:write",
            "account:read",
            "account:write"
        ]))
        #expect(Set(NativeAuthSession.firstPartyTokenScope.split(separator: " ").map(String.init)).isSuperset(of: [
            "kitchen:read",
            "kitchen:write",
            "shopping_list:read",
            "shopping_list:write",
            "account:read",
            "account:write",
            "tokens:read",
            "tokens:write"
        ]))
        let secondStart = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(secondStart.clientID == start.clientID)
        #expect(await network.registerRequests.count == 1)
        let localDogfoodNetwork = CoverageAuthNetworkSpy(
            clientID: "cm_native_spoonjoy_loopback",
            exchangeResponse: coverageTokenResponse(accessToken: "sj_access_loopback", refreshToken: "ort_refresh_loopback", expiresIn: 300),
            refreshResponse: coverageTokenResponse(accessToken: "sj_access_loopback_rotated", refreshToken: "ort_refresh_loopback_rotated", expiresIn: 600)
        )
        let localDogfoodRepository = NativeAuthSessionRepository(
            vault: InMemoryTokenVault(),
            clientName: "Spoonjoy Apple",
            redirectURI: NativeAuthSession.localDogfoodRedirectURI,
            registerClient: localDogfoodNetwork.registerClient,
            exchangeCode: localDogfoodNetwork.exchangeCode,
            refresh: localDogfoodNetwork.refresh,
            revoke: localDogfoodNetwork.revoke,
            reusesSavedClientID: false,
            now: { now }
        )
        let loopbackStart = try await localDogfoodRepository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        let secondLoopbackStart = try await localDogfoodRepository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(loopbackStart.clientID == "cm_native_spoonjoy_loopback")
        #expect(secondLoopbackStart.clientID == "cm_native_spoonjoy_loopback")
        #expect(await localDogfoodNetwork.registerRequests.count == 2)
        let randomVerifierA = OAuthPKCE.randomVerifier()
        let randomVerifierB = OAuthPKCE.randomVerifier()
        #expect(OAuthPKCE.isValidVerifier(randomVerifierA))
        #expect(OAuthPKCE.isValidVerifier(randomVerifierB))
        #expect(randomVerifierA != randomVerifierB)
        #expect(try !OAuthPKCE.codeChallenge(for: randomVerifierA).isEmpty)
        #expect(!OAuthPKCE.isValidVerifier(String(repeating: "a", count: 42)))
        #expect(throws: OAuthPKCEError.invalidVerifier) {
            _ = try OAuthPKCE.codeChallenge(for: "short")
        }
        #expect(OAuthState(rawValue: "   ") == nil)
        #expect(NativeAuthSession.lifecycleOperations.contains("handleOAuthCallback"))
        #expect(NativeAuthSession.collaborators.contains("RefreshCoordinator"))

        let session = try await repository.handleOAuthCallback(
            URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
            expectedState: state,
            codeVerifier: "pkce_verifier"
        )
        #expect(session.accessToken == "sj_access_initial")
        #expect(try await repository.restoreState() == .authenticated(session))
        #expect(await network.exchangeRequests == [
            CoverageCodeExchangeRequest(clientID: "cm_native_spoonjoy", redirectURI: "https://spoonjoy.app/oauth/callback", code: "oac_code", codeVerifier: "pkce_verifier")
        ])

        let expired = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_expired",
            refreshToken: "ort_refresh_initial",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(-1),
            scope: NativeAuthSession.defaultScope
        )
        try await vault.saveSession(expired)
        #expect(try await repository.restoreState() == .refreshRequired(expired))
        let refreshed = try await repository.validSession()
        #expect(refreshed.accessToken == "sj_access_rotated")
        let bound = try await repository.bindAccountID("chef_ari")
        #expect(bound.accountID == "chef_ari")
        #expect(try await vault.loadSession()?.accountID == "chef_ari")
        try await repository.revokeAndLogout()
        #expect(try await repository.restoreState() == .signedOut)
        #expect(await network.revokeRequests == [
            CoverageRevokeRequest(refreshToken: "ort_refresh_rotated", clientID: "cm_native_spoonjoy")
        ])
        try await repository.revokeAndLogout()

        let appleCredential = NativeAppleSignInCredential(
            identityToken: "apple_identity_token",
            rawNonce: "raw_nonce",
            email: "chef@spoonjoy.app",
            fullName: "Spoonjoy Chef"
        )
        let appleRequest = try NativeAppleSignInRequests.exchangeCredential(appleCredential)
            .urlRequest(configuration: .spoonjoyProduction)
        #expect(appleRequest.method == .post)
        #expect(appleRequest.url.path == "/api/v1/auth/apple/native")
        #expect(appleRequest.headers["Content-Type"] == "application/json")
        #expect(appleRequest.responseCachePolicy == .privateNoStore)
        let appleBody = try #require(appleRequest.body)
        let appleJSON = try #require(JSONSerialization.jsonObject(with: appleBody) as? [String: String])
        #expect(appleJSON["identityToken"] == "apple_identity_token")
        #expect(appleJSON["rawNonce"] == "raw_nonce")
        #expect(appleJSON["email"] == "chef@spoonjoy.app")
        #expect(appleJSON["fullName"] == "Spoonjoy Chef")

        let appleSession = try await repository.handleAppleSignInCredential(appleCredential)
        #expect(appleSession.clientID == NativeAuthSession.nativeAppleClientID)
        #expect(appleSession.accessToken == "sj_access_apple")
        #expect(try await vault.loadClientID() == NativeAuthSession.nativeAppClientID)
        #expect(try await repository.restoreState() == .authenticated(appleSession))
        #expect(await network.appleCredentials == [appleCredential])

        let passwordCredential = NativePasswordSignInCredential(
            emailOrUsername: "chef@spoonjoy.app",
            password: "correct horse battery staple"
        )
        let passwordRequest = try NativePasswordSignInRequests.exchangeCredential(passwordCredential)
            .urlRequest(configuration: .spoonjoyProduction)
        #expect(passwordRequest.method == .post)
        #expect(passwordRequest.url.path == "/api/v1/auth/password/native")
        #expect(passwordRequest.headers["Content-Type"] == "application/json")
        #expect(passwordRequest.responseCachePolicy == .privateNoStore)
        let passwordBody = try #require(passwordRequest.body)
        let passwordJSON = try #require(JSONSerialization.jsonObject(with: passwordBody) as? [String: String])
        #expect(passwordJSON["emailOrUsername"] == "chef@spoonjoy.app")
        #expect(passwordJSON["password"] == "correct horse battery staple")

        let passwordSession = try await repository.handlePasswordSignInCredential(passwordCredential)
        #expect(passwordSession.clientID == NativeAuthSession.nativeAppClientID)
        #expect(passwordSession.accessToken == "sj_access_password")
        #expect(try await vault.loadClientID() == NativeAuthSession.nativeAppClientID)
        #expect(try await repository.restoreState() == .authenticated(passwordSession))
        #expect(await network.passwordCredentials == [passwordCredential])

        let unavailableAppleRepository = NativeAuthSessionRepository(
            vault: InMemoryTokenVault(),
            clientName: "Spoonjoy Apple",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke
        )
        do {
            _ = try await unavailableAppleRepository.handleAppleSignInCredential(appleCredential)
            Issue.record("Expected unavailable native Apple sign-in exchange to throw")
        } catch NativeAuthSessionError.appleSignInUnavailable {
        } catch {
            Issue.record("Expected NativeAuthSessionError.appleSignInUnavailable; got \(error)")
        }
        do {
            _ = try await unavailableAppleRepository.handlePasswordSignInCredential(passwordCredential)
            Issue.record("Expected unavailable native password sign-in exchange to throw")
        } catch NativeAuthSessionError.passwordSignInUnavailable {
        } catch {
            Issue.record("Expected NativeAuthSessionError.passwordSignInUnavailable; got \(error)")
        }

        let vaultDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoonjoy-file-backed-vault-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: vaultDirectory)
        }
        let fileVaultURL = vaultDirectory.appendingPathComponent("debug-auth-session.json")
        let fileVault = FileBackedTokenVault(fileURL: fileVaultURL)
        #expect(try await fileVault.loadClientID() == nil)
        #expect(try await fileVault.loadSession() == nil)
        try FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        try Data().write(to: fileVaultURL)
        #expect(try await fileVault.loadClientID() == nil)
        try await fileVault.saveClientID("spoonjoy-apple-native")
        try await fileVault.saveSession(appleSession)
        #expect(try await fileVault.loadClientID() == "spoonjoy-apple-native")
        #expect(try await fileVault.loadSession() == appleSession)
        let reloadedFileVault = FileBackedTokenVault(fileURL: fileVaultURL)
        #expect(try await reloadedFileVault.loadClientID() == "spoonjoy-apple-native")
        #expect(try await reloadedFileVault.loadSession() == appleSession)
        try await reloadedFileVault.clearSession()
        #expect(try await reloadedFileVault.loadSession() == nil)
        try await reloadedFileVault.clearClientID()
        #expect(try await reloadedFileVault.loadClientID() == nil)

        let missingClientRepository = NativeAuthSessionRepository(
            vault: InMemoryTokenVault(),
            clientName: "Spoonjoy Apple",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke
        )
        let defaultClockVault = InMemoryTokenVault()
        let defaultClockSession = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_default_clock",
            refreshToken: "ort_refresh_default_clock",
            tokenType: "Bearer",
            expiresAt: Date().addingTimeInterval(300),
            scope: NativeAuthSession.defaultScope
        )
        try await defaultClockVault.saveSession(defaultClockSession)
        let defaultClockRepository = NativeAuthSessionRepository(
            vault: defaultClockVault,
            clientName: "Spoonjoy Apple",
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke
        )
        #expect(try await defaultClockRepository.restoreState() == .authenticated(defaultClockSession))
        #expect(try await coverageThrowsNativeAuthSessionError {
            _ = try await missingClientRepository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: state,
                codeVerifier: "pkce_verifier"
            )
        })
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=wrong")!,
                expectedState: state
            )
        })
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "https://spoonjoy.app/oauth/callback?state=state_123")!,
                expectedState: state
            )
        })
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "http://localhost/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: state
            )
        })
        #expect(try NativeAuthSession.code(
            from: URL(string: "https://spoonjoy.app:443/oauth/callback?code=oac_code&state=state_123")!,
            expectedState: state
        ) == "oac_code")
        #expect(try NativeAuthSession.code(
            from: URL(string: "http://127.0.0.1/callback?code=oac_loopback_default_port&state=state_123")!,
            expectedState: state,
            redirectURI: URL(string: "http://127.0.0.1/callback")!
        ) == "oac_loopback_default_port")
        #expect(try NativeAuthSession.code(
            from: URL(string: "http://127.0.0.1:53123/callback?code=oac_loopback&state=state_123")!,
            expectedState: state,
            redirectURI: NativeAuthSession.localDogfoodRedirectURI
        ) == "oac_loopback")
        #expect(try coverageThrowsNativeAuthSessionError {
            _ = try NativeAuthSession.code(
                from: URL(string: "https://spoonjoy.app:444/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: state
            )
        })

        #expect(try OAuthRedirectValidator.validate(URL(string: "http://localhost/oauth/callback")!))
        #expect(try OAuthRedirectValidator.validate(URL(string: "http://127.0.0.1/oauth/callback")!))
        for invalid in [
            "/oauth/callback",
            "ftp://spoonjoy.app/oauth/callback",
            "http://spoonjoy.app/oauth/callback",
            "https://evil.example/oauth/callback",
            "https://user:pass@spoonjoy.app/oauth/callback",
            "https://spoonjoy.app/oauth/callback#fragment",
            "https://spoonjoy.app/oauth/callback/extra",
            "https:///oauth/callback"
        ] {
            #expect(throws: OAuthRedirectValidationError.self) {
                try OAuthRedirectValidator.validate(URL(string: invalid)!)
            }
        }
        #expect(SecureAuthWebHandoff.allCases.map(\.url).contains(URL(string: "https://spoonjoy.app/login")!))
    }

    @Test("app bundle declares associated domains without treating custom scheme as OAuth redirect")
    func appBundleDeclaresAssociatedDomainsWithoutTreatingCustomSchemeAsOAuthRedirect() throws {
        let infoPlist = try propertyListDictionary("Apps/Spoonjoy/Shared/Info.plist")
        let entitlements = try propertyListDictionary("Apps/Spoonjoy/Shared/Spoonjoy.entitlements")
        let urlTypes = try #require(infoPlist["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        let associatedDomains = try #require(entitlements["com.apple.developer.associated-domains"] as? [String])
        let launchScreen = try #require(infoPlist["UILaunchScreen"] as? [String: Any])
        let supportedOrientations = try #require(infoPlist["UISupportedInterfaceOrientations"] as? [String])
        let launchBackground = repoRoot()
            .appendingPathComponent("Apps/Spoonjoy/Shared/Assets.xcassets/LaunchBackground.colorset/Contents.json")

        #expect(schemes == ["spoonjoy"])
        #expect(associatedDomains.contains("applinks:spoonjoy.app"))
        #expect(launchScreen["UIColorName"] as? String == "LaunchBackground")
        #expect(supportedOrientations == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"
        ])
        #expect(FileManager.default.fileExists(atPath: launchBackground.path))
        #expect(!schemes.contains("spoonjoy://oauth/callback"))
        #expect(!associatedDomains.contains("applinks:oauth/callback"))
    }

    @Test("auth files are wired into generated app targets and signed out flow")
    func authFilesAreWiredIntoGeneratedAppTargetsAndSignedOutFlow() throws {
        try withTemporaryDirectory { directory in
            let generator = repoRoot().appendingPathComponent("scripts/bundle-exec.sh")
            let result = try runProcess(
                executable: generator.path,
                arguments: [
                    "ruby",
                    "scripts/generate-xcode-project.rb",
                    "--output-dir",
                    directory.path
                ]
            )
            #expect(result.status == 0, Comment(rawValue: result.output))

            let project = try String(
                contentsOf: directory
                    .appendingPathComponent("Spoonjoy.xcodeproj", isDirectory: true)
                    .appendingPathComponent("project.pbxproj"),
                encoding: .utf8
            )
            for appAuthSource in ["SpoonjoyWebAuthenticationSession.swift"] {
                let sourceEntries = project.components(separatedBy: "\(appAuthSource) in Sources").count - 1
                #expect(sourceEntries >= 2, "\(appAuthSource) must be in both iOS and macOS Sources phases")
            }
            #expect(project.contains("SpoonjoyCore"))
            #expect(!project.contains("KeychainTokenVault.swift in Sources"))
        }

        let signedOutSetup = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift")
        expectContent(
            signedOutSetup,
            in: "Apps/Spoonjoy/Shared/AppShell/SignedOutSetupView.swift",
            contains: [
                "SignInWithAppleButton",
                "NativeAppleSignInCredential",
                "NativePasswordSignInCredential",
                "handleAppleSignInCredential",
                "handlePasswordSignInCredential",
                "SpoonjoyWebAuthenticationSession(callbackURL:",
                "handleBrowserOAuthSignIn",
                "handleBrowserOAuthSignIn(provider:",
                "handleBrowserOAuthCallback",
                "handleBrowserOAuthCancellation",
                "authRepository.startSignIn",
                "authRepository.handleOAuthCallback",
                "providerHint:",
                "pendingOAuthProvider",
                "Continue with Google",
                "Continue with GitHub",
                "emailOrUsername",
                "passwordSignInFailureMessage(for error: Error)",
                "request.nonce = Self.sha256(nonce)",
                "native password sign-in",
                "native Apple sign-in",
                "native Google OAuth sign-in",
                "native GitHub OAuth sign-in",
                "Browser sign-in canceled.",
                "signInFailureMessage(for error: Error)",
                "com.apple.developer.applesignin",
                "Sign in with Apple isn't available right now. Choose another sign-in option.",
                "authorization_request_started",
                "backend_exchange_started"
            ],
            forbids: [
                "authRequired:",
                "offlineIndicatorDisplay",
                "OfflineStatusView(display:",
                "safeAreaInset(edge: .bottom)",
                "Could not finish sign-in: \\(error)",
                "cm_native_spoonjoy",
                "native-code-verifier-pending",
                "registerClient:",
                "exchangeCode:",
                "KeychainTokenVault()",
                "SpoonjoyWebAuthenticationSession {",
                "SecureAuthWebHandoff.login.url",
                "OAuthRedirectValidator.validate(callbackURL)",
                "Continue with Google or GitHub",
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )

        let appleTelemetry = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift")
        expectContent(
            appleTelemetry,
            in: "Apps/Spoonjoy/Shared/AppShell/NativeAppleSignInTelemetry.swift",
            contains: [
                "Logger(subsystem: \"app.spoonjoy\", category: \"auth.apple\")",
                "diagnosticCode(for error: Error)",
                "providerCode"
            ],
            forbids: []
        )

    }

    @Test("native auth session source defines launch callback and restoration contract")
    func nativeAuthSessionSourceDefinesLaunchCallbackAndRestorationContract() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/NativeAuthSession.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/NativeAuthSession.swift",
            contains: [
                "NativeAuthSession",
                "NativeAuthSessionState",
                "NativeAuthSessionError",
                "startSignIn",
                "handleOAuthCallback",
                "restoreState",
                "revokeAndLogout",
                "https://spoonjoy.app/oauth/callback",
                "OAuthProviderHint",
                "providerHint: OAuthProviderHint? = nil",
                "OAuthRedirectValidator",
                "OAuthRequests.authorize",
                "OAuthRequests.exchangeCode",
                "OAuthRequests.revoke",
                "RefreshCoordinator"
            ],
            forbids: [
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("ASWebAuthenticationSession adapter launches exact HTTPS callback route")
    func authenticationSessionAdapterLaunchesExactHTTPSCallbackRoute() throws {
        let content = try readRepoFile("Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift")

        expectContent(
            content,
            in: "Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift",
            contains: [
                "AuthenticationServices",
                "ASWebAuthenticationSession",
                "SpoonjoyWebAuthenticationSession",
                "SpoonjoyLoopbackWebAuthenticationSession",
                "NSWorkspace.shared.open",
                "127.0.0.1",
                "53123",
                "presentationContextProvider",
                "prefersEphemeralWebBrowserSession",
                "session.prefersEphemeralWebBrowserSession = false",
                "callbackURL: URL",
                "cancellationHandler:",
                "parsedCallbackURL",
                "ASWebAuthenticationSession.Callback.https",
                "host: \"spoonjoy.app\"",
                "path: \"/oauth/callback\"",
                "loopback(host: String, port: UInt16, path: String)",
                "handleOAuthCallback",
                "cancel()",
                "OAuthState",
                "SpoonjoyAuthenticationPresentationContextProvider.make()",
                "SpoonjoyUnavailableWebAuthenticationSession",
                "activeSession = didStart ? session : nil",
                "preferredPresentationAnchor",
                "NSApplication.shared.keyWindow",
                "ASPresentationAnchor(windowScene: windowScene)"
            ],
            forbids: [
                "preconditionFailure",
                "session.prefersEphemeralWebBrowserSession = true",
                "spoonjoy://oauth/callback",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("web authentication adapter is executable with injected session factory")
    func webAuthenticationAdapterIsExecutableWithInjectedSessionFactory() throws {
        let result = try runAppAuthAdapterContractPackage(
            name: "SpoonjoyWebAuthenticationSessionProbe",
            testSource: webAuthenticationSessionAdapterContractSource
        )

        #expect(result.status == 0, Comment(rawValue: result.truncatedOutput))
    }

    @Test("Keychain token vault stores auth material outside general cache")
    func keychainTokenVaultStoresAuthMaterialOutsideGeneralCache() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/KeychainTokenVault.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/KeychainTokenVault.swift",
            contains: [
                "Security",
                "KeychainTokenVault",
                "TokenVault",
                "loadClientID",
                "saveClientID",
                "loadSession",
                "saveSession",
                "clearSession",
                "clearClientID",
                "kSecClassGenericPassword",
                "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
                "kSecAttrService",
                "spoonjoy.auth.client-id",
                "spoonjoy.auth.session"
            ],
            forbids: [
                "UserDefaults",
                "JSONFileStore",
                "FileManager.default"
            ]
        )
    }

    @Test("Keychain token vault persists values and surfaces security statuses")
    func keychainTokenVaultPersistsValuesAndSurfacesSecurityStatuses() async throws {
        let keychain = FakeKeychainTokenVaultClient()
        let vault = KeychainTokenVault(accessGroup: "group.spoonjoy.tests", keychain: keychain)
        let session = try AuthSession(
            clientID: "client_keychain",
            accessToken: "sj_access_keychain",
            refreshToken: "sj_refresh_keychain",
            tokenType: "Bearer",
            expiresAt: Date(timeIntervalSince1970: 1_781_612_800),
            scope: NativeAuthSession.defaultScope,
            accountID: "chef_keychain"
        )

        #expect(try await vault.loadClientID() == nil)
        try await vault.saveClientID("client_keychain")
        #expect(try await vault.loadClientID() == "client_keychain")
        try await vault.saveClientID("client_keychain_rotated")
        #expect(try await vault.loadClientID() == "client_keychain_rotated")
        try await vault.saveSession(session)
        #expect(try await vault.loadSession() == session)
        try await vault.clearClientID()
        try await vault.clearSession()
        try await vault.clearSession()
        #expect(try await vault.loadClientID() == nil)
        #expect(try await vault.loadSession() == nil)
        #expect(keychain.capturedAccessGroups == ["group.spoonjoy.tests"])

        keychain.nextCopyStatus = errSecInteractionNotAllowed
        await expectKeychainStatus(errSecInteractionNotAllowed) {
            _ = try await vault.loadClientID()
        }
        keychain.nextCopyStatus = errSecMissingEntitlement
        await expectKeychainStatus(errSecMissingEntitlement) {
            _ = try await vault.loadClientID()
        }

        keychain.nextUpdateStatus = errSecAuthFailed
        await expectKeychainStatus(errSecAuthFailed) {
            try await vault.saveClientID("blocked-update")
        }

        keychain.nextAddStatus = errSecDuplicateItem
        await expectKeychainStatus(errSecDuplicateItem) {
            try await vault.saveClientID("blocked-add")
        }

        keychain.nextDeleteStatus = errSecAuthFailed
        await expectKeychainStatus(errSecAuthFailed) {
            try await vault.clearClientID()
        }
        keychain.nextDeleteStatus = errSecMissingEntitlement
        await expectKeychainStatus(errSecMissingEntitlement) {
            try await vault.clearClientID()
        }

        let unsignedLocalVault = KeychainTokenVault(
            accessGroup: "group.spoonjoy.tests",
            keychain: keychain,
            allowsUnsignedLocalFallback: true
        )
        keychain.nextCopyStatus = errSecMissingEntitlement
        #expect(try await unsignedLocalVault.loadClientID() == nil)
        keychain.nextDeleteStatus = errSecMissingEntitlement
        try await unsignedLocalVault.clearClientID()
        keychain.nextUpdateStatus = errSecMissingEntitlement
        await expectKeychainStatus(errSecMissingEntitlement) {
            try await unsignedLocalVault.saveClientID("blocked-unsigned-update")
        }

        let systemClient = SystemKeychainTokenVaultClient()
        var result: CFTypeRef?
        #expect(systemClient.copyMatching([:], &result) != errSecSuccess)
        #expect(systemClient.update([:], [:]) != errSecSuccess)
        #expect(systemClient.add([:]) != errSecSuccess)
        #expect(systemClient.delete([:]) != errSecSuccess)
        _ = KeychainTokenVault()
        _ = KeychainTokenVault(allowsUnsignedLocalFallback: true)
    }

    @Test("refresh rotation revoke logout and restoration persist through native repository")
    func refreshRotationRevokeLogoutAndRestorationPersistThroughNativeRepository() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/NativeAuthSessionRepository.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/NativeAuthSessionRepository.swift",
            contains: [
                "NativeAuthSessionRepository",
                "TokenVault",
                "RefreshCoordinator",
                "providerHint: OAuthProviderHint? = nil",
                "restoreState",
                "validSession",
                "handlePasswordSignInCredential",
                "NativePasswordSignInRequests.exchangeCredential",
                "NativePasswordSignInExchangeOperation",
                "saveClientID",
                "saveSession",
                "OAuthRequests.refreshToken",
                "OAuthRequests.revoke",
                "clearSession",
                "clearClientID",
                "revokeAndLogout"
            ],
            forbids: [
                "UserDefaults",
                "MutationQueue"
            ]
        )
    }

    @Test("secure web handoff URLs are exact and separate from native OAuth redirects")
    func secureWebHandoffURLsAreExactAndSeparateFromNativeOAuthRedirects() throws {
        let content = try readRepoFile("Sources/SpoonjoyCore/Auth/SecureAuthWebHandoff.swift")

        expectContent(
            content,
            in: "Sources/SpoonjoyCore/Auth/SecureAuthWebHandoff.swift",
            contains: [
                "SecureAuthWebHandoff",
                "https://spoonjoy.app/login",
                "https://spoonjoy.app/signup",
                "https://spoonjoy.app/logout",
                "https://spoonjoy.app/auth/google",
                "https://spoonjoy.app/auth/github",
                "https://spoonjoy.app/auth/apple",
                "https://spoonjoy.app/agent/connect",
                "https://spoonjoy.app/oauth/authorize"
            ],
            forbids: [
                "spoonjoy://login",
                "spoonjoy://signup",
                "spoonjoy://logout",
                "spoonjoy://oauth"
            ]
        )
    }

    @Test("xcodebuild blocker wrapper classifies only local pre-parse platform faults")
    func xcodebuildBlockerWrapperClassifiesOnlyLocalPreParsePlatformFaults() throws {
        let content = try readRepoFile("scripts/run-xcodebuild-with-blocker.sh")

        expectContent(
            content,
            in: "scripts/run-xcodebuild-with-blocker.sh",
            contains: [
                "set -euo pipefail",
                "xcodebuild -version",
                "xcode-select -p",
                "xcodebuild -checkFirstLaunchStatus",
                "XcodePlatform",
                "timeoutSeconds",
                "outputPath",
                "iOS 26.5 is not installed",
                "Unable to find a destination",
                "CoreSimulator",
                "DVTPlugIn",
                "IDEDistribution",
                "preflight_command",
                "command_status",
                "exit \"$command_status\""
            ],
            forbids: [
                "|| true",
                "2>/dev/null",
                "grep -q warning"
            ]
        )
    }

    @Test("xcodebuild blocker wrapper behavior is executable with fake xcodebuild")
    func xcodebuildBlockerWrapperBehaviorIsExecutableWithFakeXcodebuild() throws {
        let script = repoRoot().appendingPathComponent("scripts/run-xcodebuild-with-blocker.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw NativeAuthContractError.missingFile("scripts/run-xcodebuild-with-blocker.sh")
        }

        try withTemporaryDirectory { directory in
            let fakeBin = directory.appendingPathComponent("bin", isDirectory: true)
            try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
            let fakeXcodebuild = fakeBin.appendingPathComponent("xcodebuild")
            try fakeXcodebuildSource.write(to: fakeXcodebuild, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeXcodebuild.path)

            let allowed = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("allowed", isDirectory: true),
                fakeBin: fakeBin,
                mode: "missing-ios-platform"
            )
            #expect(allowed.status == 0, Comment(rawValue: allowed.output))
            let allowedBlocker = try #require(allowed.blocker)
            #expect(allowedBlocker["capability"] as? String == "XcodePlatform")
            #expect(allowedBlocker["blocked"] as? Bool == true)
            #expect(allowedBlocker["timeoutSeconds"] as? Int == 30)
            #expect((allowedBlocker["command"] as? String)?.contains("xcodebuild -project Spoonjoy.xcodeproj") == true)
            #expect((allowedBlocker["outputPath"] as? String)?.hasSuffix("xcodebuild.log") == true)

            let hardFailure = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("hard-failure", isDirectory: true),
                fakeBin: fakeBin,
                mode: "compile-failure"
            )
            #expect(hardFailure.status == 65, Comment(rawValue: hardFailure.output))
            #expect(hardFailure.blocker == nil)

            let hardFailureWithCoreSimulatorMention = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("hard-failure-coresimulator", isDirectory: true),
                fakeBin: fakeBin,
                mode: "compile-failure-coresimulator-mention"
            )
            #expect(hardFailureWithCoreSimulatorMention.status == 65, Comment(rawValue: hardFailureWithCoreSimulatorMention.output))
            #expect(hardFailureWithCoreSimulatorMention.blocker == nil)

            let preflightBlocker = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("preflight-blocker", isDirectory: true),
                fakeBin: fakeBin,
                mode: "preflight-dvtplugin"
            )
            #expect(preflightBlocker.status == 0, Comment(rawValue: preflightBlocker.output))
            let preflightBlockerJSON = try #require(preflightBlocker.blocker)
            #expect(preflightBlockerJSON["capability"] as? String == "XcodePlatform")
            #expect(preflightBlockerJSON["command"] as? String == "xcodebuild -checkFirstLaunchStatus (exit 69)")
            #expect((preflightBlockerJSON["ownerAction"] as? String)?.contains("Complete Xcode first-launch setup") == true)

            let silentFirstLaunchBlocker = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("preflight-silent-first-launch", isDirectory: true),
                fakeBin: fakeBin,
                mode: "preflight-silent-first-launch"
            )
            #expect(silentFirstLaunchBlocker.status == 0, Comment(rawValue: silentFirstLaunchBlocker.output))
            let silentFirstLaunchBlockerJSON = try #require(silentFirstLaunchBlocker.blocker)
            #expect(silentFirstLaunchBlockerJSON["capability"] as? String == "XcodePlatform")
            #expect(silentFirstLaunchBlockerJSON["command"] as? String == "xcodebuild -checkFirstLaunchStatus (exit 69)")
            #expect((silentFirstLaunchBlockerJSON["reason"] as? String)?.contains("preflight command failed") == true)

            let success = try runWrapperProbe(
                script: script,
                artifactDirectory: directory.appendingPathComponent("success", isDirectory: true),
                fakeBin: fakeBin,
                mode: "success"
            )
            #expect(success.status == 0, Comment(rawValue: success.output))
            #expect(success.blocker == nil)
        }
    }

    @Test("local validation matrix executes xcodebuild wrapper for app bundle rows")
    func localValidationMatrixExecutesXcodebuildWrapperForAppBundleRows() throws {
        let success = try runValidationMatrixHarness(wrapperMode: "success")
        #expect(success.result.status == 0, Comment(rawValue: success.result.output))
        #expect(success.wrapperCalls.filter { $0.contains("matrix-xcodebuild-ios.log") }.count == 1)
        #expect(success.wrapperCalls.filter { $0.contains("matrix-xcodebuild-macos.log") }.count == 1)
        #expect(success.matrix.contains("\"name\": \"native password dogfood\""))
        #expect(success.matrix.contains("matrix-native-password-dogfood-report.json"))
        #expect(success.directXcodebuildCalls.isEmpty, Comment(rawValue: success.directXcodebuildCalls.joined(separator: "\n")))

        let blocker = try runValidationMatrixHarness(wrapperMode: "xcode-platform-blocker") { artifacts in
            let staleBlocker = artifacts
                .appendingPathComponent("apple", isDirectory: true)
                .appendingPathComponent("matrix-smoke-ios-simulator-blocker.json")
            try FileManager.default.createDirectory(
                at: staleBlocker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try """
            {
              "blocked": true,
              "capability": "BogusStale",
              "command": "stale",
              "timeoutSeconds": 30,
              "outputPath": "stale.log",
              "reason": "stale",
              "ownerAction": "stale"
            }
            """.write(to: staleBlocker, atomically: true, encoding: .utf8)
        }
        #expect(blocker.result.status != 0, Comment(rawValue: blocker.result.output))
        #expect(blocker.result.output.contains("external validation log expected:"))
        #expect(blocker.matrix.contains("\"capability\": \"XcodePlatform\""))
        #expect(blocker.matrix.contains("\"status\": \"blocked\""))
        #expect(!blocker.matrix.contains("BogusStale"))

        let compileFailure = try runValidationMatrixHarness(wrapperMode: "compile-failure")
        #expect(compileFailure.result.status != 0, Comment(rawValue: compileFailure.result.output))
        #expect(compileFailure.matrix.contains("\"status\": \"fail\""))
        #expect(!compileFailure.matrix.contains("\"capability\": \"XcodePlatform\""))

        let staleTopLevelBlocker = try runValidationMatrixHarness(wrapperMode: "success") { artifacts in
            try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
            let staleBlocker = artifacts.appendingPathComponent("unit-stale-xcode-blocker.json")
            try """
            {
              "blocked": true,
              "capability": "XcodePlatform",
              "command": "stale top-level xcodebuild",
              "timeoutSeconds": 30,
              "outputPath": "stale-top-level.log",
              "reason": "stale top-level blocker",
              "ownerAction": "stale top-level action"
            }
            """.write(to: staleBlocker, atomically: true, encoding: .utf8)
        }
        #expect(staleTopLevelBlocker.result.status != 0, Comment(rawValue: staleTopLevelBlocker.result.output))
        #expect(staleTopLevelBlocker.matrix.contains("\"name\": \"stale noncanonical blocker scan\""))
        #expect(staleTopLevelBlocker.matrix.contains("\"status\": \"fail\""))
        #expect(staleTopLevelBlocker.matrix.contains("unit-stale-xcode-blocker.json"))
    }

    @Test("local validation matrix delegates xcodebuild classification to wrapper")
    func localValidationMatrixDelegatesXcodebuildClassificationToWrapper() throws {
        let content = try readRepoFile("scripts/validate-native-local.sh")

        expectContent(
            content,
            in: "scripts/validate-native-local.sh",
            contains: [
                "scripts/run-xcodebuild-with-blocker.sh",
                "matrix-xcodebuild-ios.log",
                "matrix-xcodebuild-macos.log",
                "matrix-xcode-platform-blocker.json",
                "matrix-smoke-ios-simulator-blocker.json",
                "matrix-smoke-macos-blocker.json",
                "scripts/verify-native-password-dogfood.sh",
                "scripts/capture-native-screenshot-matrix.sh",
                "matrix-native-password-dogfood-report.json",
                "artifacts/apple/native-local",
                "XcodePlatform"
            ],
            forbids: [
                "run_blockable",
                "allowed_blocker_pattern",
                "tasks/2026-06-16-1754-doing-siri-full-access-parity",
                "tasks/2026-06-15-2314-doing-native-app-skeleton"
            ]
        )
    }

    @Test("native password dogfood verifier drives real Spoonjoy API instead of fixture tokens")
    func nativePasswordDogfoodVerifierDrivesRealSpoonjoyAPI() throws {
        let content = try readRepoFile("scripts/verify-native-password-dogfood.sh")
        let wrapper = try readRepoFile("scripts/dogfood-native-password-auth.sh")
        let executable = try readRepoFile("Sources/SpoonjoyNativeDogfood/main.swift")

        expectContent(
            content,
            in: "scripts/verify-native-password-dogfood.sh",
            contains: [
                "scripts/native-dogfood-api-server.ts",
                "SPOONJOY_WEB_REPO",
                "SPOONJOY_NATIVE_DOGFOOD_IDENTIFIER",
                "SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE",
                "SecureRandom.hex",
                "artifacts/apple/native-password-dogfood",
                "/api/v1/auth/password/native",
                "wrongPassword",
                "native password dogfood ok against real Spoonjoy API"
            ],
            forbids: [
                "WEBrick",
                "sj_native_dogfood_fixture",
                "ort_native_dogfood_fixture",
                "chef_native_dogfood",
                "correctHorseBatteryStaple",
                "tasks/2026-06-16-1754-doing-siri-full-access-parity",
                "tasks/2026-06-15-2314-doing-native-app-skeleton"
            ]
        )
        expectContent(
            wrapper,
            in: "scripts/dogfood-native-password-auth.sh",
            contains: [
                "SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE",
                "unset SPOONJOY_NATIVE_DOGFOOD_PASSWORD",
                "swift run"
            ],
            forbids: [
                "case \"--password\"",
                "case \"--password-file\""
            ]
        )
        expectContent(
            executable,
            in: "Sources/SpoonjoyNativeDogfood/main.swift",
            contains: [
                "SPOONJOY_NATIVE_DOGFOOD_PASSWORD_FILE",
                "String(contentsOfFile:"
            ],
            forbids: [
                "CommandLine.arguments.dropFirst().contains(\"--password\")"
            ]
        )
    }
}

private enum NativeAuthContractError: Error, CustomStringConvertible {
    case missingFile(String)
    case unreadablePropertyList(String)

    var description: String {
        switch self {
        case .missingFile(let path):
            return "Missing required native auth contract file: \(path)"
        case .unreadablePropertyList(let path):
            return "Could not read property list contract file: \(path)"
        }
    }
}

private struct ProcessResult: Equatable {
    let status: Int32
    let output: String

    var truncatedOutput: String {
        let limit = 6_000
        guard output.count > limit else {
            return output
        }

        return String(output.suffix(limit))
    }
}

private struct WrapperProbeResult: Equatable {
    let status: Int32
    let output: String
    let blocker: [String: AnyHashable]?
}

private struct ValidationMatrixHarnessResult: Equatable {
    let result: ProcessResult
    let wrapperCalls: [String]
    let directXcodebuildCalls: [String]
    let matrix: String
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeAuthContractError.missingFile(relativePath)
    }

    return try String(contentsOf: url, encoding: .utf8)
}

private func propertyListDictionary(_ relativePath: String) throws -> [String: Any] {
    let url = repoRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw NativeAuthContractError.missingFile(relativePath)
    }

    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    guard let dictionary = plist as? [String: Any] else {
        throw NativeAuthContractError.unreadablePropertyList(relativePath)
    }

    return dictionary
}

private func runSwiftContractPackage(name: String, testSource: String) throws -> ProcessResult {
    try withTemporaryDirectory { directory in
        let testsDirectory = directory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("\(name)Tests", isDirectory: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try packageManifest(name: name).write(
            to: directory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try testSource.write(
            to: testsDirectory.appendingPathComponent("\(name)Tests.swift"),
            atomically: true,
            encoding: .utf8
        )

    return try runProcess(
        executable: "/usr/bin/env",
        arguments: [
            "swift",
            "test",
                "--package-path",
                directory.path,
                "--disable-xctest",
                "--parallel",
                "-Xswiftc",
                "-warnings-as-errors"
            ]
        )
    }
}

private func runAppAuthAdapterContractPackage(name: String, testSource: String) throws -> ProcessResult {
    try withTemporaryDirectory { directory in
        let sourceDirectory = directory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("SpoonjoyAppAuth", isDirectory: true)
        let testsDirectory = directory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("\(name)Tests", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testsDirectory, withIntermediateDirectories: true)
        try appAuthAdapterPackageManifest(name: name).write(
            to: directory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try readRepoFile("Apps/Spoonjoy/Shared/Auth/SpoonjoyWebAuthenticationSession.swift").write(
            to: sourceDirectory.appendingPathComponent("SpoonjoyWebAuthenticationSession.swift"),
            atomically: true,
            encoding: .utf8
        )
        try testSource.write(
            to: testsDirectory.appendingPathComponent("\(name)Tests.swift"),
            atomically: true,
            encoding: .utf8
        )

        return try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "swift",
                "test",
                "--package-path",
                directory.path,
                "--disable-xctest",
                "--parallel",
                "-Xswiftc",
                "-warnings-as-errors"
            ]
        )
    }
}

private func packageManifest(name: String) -> String {
    let packageIdentity = repoPackageIdentity()
    return """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(name)",
        platforms: [
            .iOS(.v26),
            .macOS(.v26)
        ],
        dependencies: [
            .package(path: "\(repoRoot().path)")
        ],
        targets: [
            .testTarget(
                name: "\(name)Tests",
                dependencies: [
                    .product(name: "SpoonjoyCore", package: "\(packageIdentity)")
                ]
            )
        ]
    )
    """
}

private func appAuthAdapterPackageManifest(name: String) -> String {
    let packageIdentity = repoPackageIdentity()
    return """
    // swift-tools-version: 6.2
    import PackageDescription

    let package = Package(
        name: "\(name)",
        platforms: [
            .iOS(.v26),
            .macOS(.v26)
        ],
        dependencies: [
            .package(path: "\(repoRoot().path)")
        ],
        targets: [
            .target(
                name: "SpoonjoyAppAuth",
                dependencies: [
                    .product(name: "SpoonjoyCore", package: "\(packageIdentity)")
                ]
            ),
            .testTarget(
                name: "\(name)Tests",
                dependencies: [
                    "SpoonjoyAppAuth",
                    .product(name: "SpoonjoyCore", package: "\(packageIdentity)")
                ]
            )
        ]
    )
    """
}

private func repoPackageIdentity() -> String {
    repoRoot().lastPathComponent.lowercased()
}

private func runWrapperProbe(
    script: URL,
    artifactDirectory: URL,
    fakeBin: URL,
    mode: String
) throws -> WrapperProbeResult {
    try FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
    let outputURL = artifactDirectory.appendingPathComponent("xcodebuild.log")
    let blockerURL = artifactDirectory.appendingPathComponent("xcode-platform-blocker.json")
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = "\(fakeBin.path):\(environment["PATH"] ?? "")"
    environment["FAKE_XCODEBUILD_MODE"] = mode
    let result = try runProcess(
        executable: script.path,
        arguments: [
            "--output",
            outputURL.path,
            "--blocker",
            blockerURL.path,
            "--timeout-seconds",
            "30",
            "--",
            "xcodebuild",
            "-project",
            "Spoonjoy.xcodeproj",
            "-scheme",
            "Spoonjoy iOS",
            "build"
        ],
        environment: environment
    )

    let blocker: [String: AnyHashable]?
    if FileManager.default.fileExists(atPath: blockerURL.path) {
        let data = try Data(contentsOf: blockerURL)
        blocker = try #require(JSONSerialization.jsonObject(with: data) as? [String: AnyHashable])
    } else {
        blocker = nil
    }

    return WrapperProbeResult(status: result.status, output: result.output, blocker: blocker)
}

private func runValidationMatrixHarness(
    wrapperMode: String,
    prepareArtifacts: ((URL) throws -> Void)? = nil
) throws -> ValidationMatrixHarnessResult {
    try withTemporaryDirectory { directory in
        try writeValidationMatrixHarness(at: directory)
        let artifacts = directory.appendingPathComponent("artifacts", isDirectory: true)
        try prepareArtifacts?(artifacts)
        let wrapperCallsURL = directory.appendingPathComponent("wrapper-calls.log")
        let directXcodebuildCallsURL = directory.appendingPathComponent("direct-xcodebuild-calls.log")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(directory.appendingPathComponent("bin", isDirectory: true).path):\(environment["PATH"] ?? "")"
        environment["FAKE_WRAPPER_MODE"] = wrapperMode
        environment["WRAPPER_CALLS"] = wrapperCallsURL.path
        environment["DIRECT_XCODEBUILD_CALLS"] = directXcodebuildCallsURL.path

        let result = try runProcess(
            executable: directory.appendingPathComponent("scripts/validate-native-local.sh").path,
            arguments: ["--artifact-root", artifacts.path],
            environment: environment,
            currentDirectory: directory
        )
        let wrapperCalls = readLinesIfPresent(wrapperCallsURL)
        let directXcodebuildCalls = readLinesIfPresent(directXcodebuildCallsURL)
        let matrixURL = artifacts
            .appendingPathComponent("apple", isDirectory: true)
            .appendingPathComponent("validation-matrix.json")
        let matrix = (try? String(contentsOf: matrixURL, encoding: .utf8)) ?? ""

        return ValidationMatrixHarnessResult(
            result: result,
            wrapperCalls: wrapperCalls,
            directXcodebuildCalls: directXcodebuildCalls,
            matrix: matrix
        )
    }
}

private func writeValidationMatrixHarness(at directory: URL) throws {
    let scripts = directory.appendingPathComponent("scripts", isDirectory: true)
    let scriptTests = scripts.appendingPathComponent("tests", isDirectory: true)
    let bin = directory.appendingPathComponent("bin", isDirectory: true)
    let docs = directory
        .appendingPathComponent("docs", isDirectory: true)
        .appendingPathComponent("source", isDirectory: true)
    try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: scriptTests, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    try "source design language\n".write(to: docs.appendingPathComponent("spoonjoy-v2-design-language.md"), atomically: true, encoding: .utf8)
    try "source \"https://rubygems.org\"\n".write(to: directory.appendingPathComponent("Gemfile"), atomically: true, encoding: .utf8)
    try "BUNDLED WITH\n   2.4.22\n".write(to: directory.appendingPathComponent("Gemfile.lock"), atomically: true, encoding: .utf8)

    let validate = scripts.appendingPathComponent("validate-native-local.sh")
    try readRepoFile("scripts/validate-native-local.sh").write(to: validate, atomically: true, encoding: .utf8)
    try makeExecutable(validate)

        let shellStubs = [
            "bundle-check.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
            "bundle-exec.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexec \"$@\"\n",
            "verify-native-scenarios.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
            "verify-native-password-dogfood.sh": "#!/usr/bin/env bash\nset -euo pipefail\nreport=''\nwhile [[ $# -gt 0 ]]; do case \"$1\" in --report) report=\"$2\"; shift 2 ;; *) shift ;; esac; done\nif [[ -n \"$report\" ]]; then mkdir -p \"$(dirname \"$report\")\"; printf '{\"ok\":true,\"tokenType\":\"Bearer\",\"scopeCount\":6,\"syncEnvironment\":\"local\",\"syncEntryCount\":1,\"wroteVault\":true}\\n' > \"$report\"; fi\nexit 0\n",
            "smoke-macos.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
            "smoke-ios-simulator.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
            "capture-native-screenshots.sh": "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
            "capture-native-screenshot-matrix.sh": "#!/usr/bin/env bash\nset -euo pipefail\nartifact_root=''\nunit_slug='matrix'\nwhile [[ $# -gt 0 ]]; do case \"$1\" in --artifact-root) artifact_root=\"$2\"; shift 2 ;; --unit-slug) unit_slug=\"$2\"; shift 2 ;; *) shift ;; esac; done\nmkdir -p \"$artifact_root/apple\"\nprintf '{\"ok\":true,\"fullyValidated\":true,\"routes\":[]}\\n' > \"$artifact_root/apple/${unit_slug}-route-matrix.json\"\nprintf '{\"mobileScreenshot\":true,\"desktopScreenshot\":true,\"screenshotRoute\":\"kitchen\",\"observedAccessibilityEvidenceArtifacts\":[],\"accessibilityProofArtifacts\":[],\"blockers\":[]}\\n' > \"$artifact_root/design-review.json\"\nexit 0\n"
        ]
    for (name, source) in shellStubs {
        let url = scripts.appendingPathComponent(name)
        try source.write(to: url, atomically: true, encoding: .utf8)
        try makeExecutable(url)
    }

    let rubyStubs = [
        "fail-on-warning.rb",
        "enforce-swift-coverage.rb",
        "check-xcode-project-contract.rb",
        "check-xcode-generator-contract.rb",
        "check-native-design-language.rb",
        "check-design-accessibility-contract.rb",
        "check-kitchen-recipe-surfaces.rb",
        "check-cook-shopping-surfaces.rb",
        "check-search-capture-settings-surfaces.rb",
        "check-launch-screenshot-contract.rb",
        "check-app-intents-contract.rb",
        "check-native-advisory-pipeline.rb",
        "native-screenshot-provenance.rb",
        "scan-ruby-advisories.rb",
        "validate-design-review.rb",
        "validate-design-review-blocker.rb",
        "validate-aasa.rb"
    ]
    for name in rubyStubs {
        let url = scripts.appendingPathComponent(name)
        try "#!/usr/bin/env ruby\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
        try makeExecutable(url)
    }

    let provenanceTest = scriptTests.appendingPathComponent("native_screenshot_provenance_test.rb")
    try "#!/usr/bin/env ruby\nexit 0\n".write(to: provenanceTest, atomically: true, encoding: .utf8)
    try makeExecutable(provenanceTest)

    let wrapper = scripts.appendingPathComponent("run-xcodebuild-with-blocker.sh")
    try validationHarnessWrapperSource.write(to: wrapper, atomically: true, encoding: .utf8)
    try makeExecutable(wrapper)

    let fakeSwift = bin.appendingPathComponent("swift")
    try validationHarnessSwiftSource.write(to: fakeSwift, atomically: true, encoding: .utf8)
    try makeExecutable(fakeSwift)

    let fakeXcodebuild = bin.appendingPathComponent("xcodebuild")
    try validationHarnessXcodebuildSource.write(to: fakeXcodebuild, atomically: true, encoding: .utf8)
    try makeExecutable(fakeXcodebuild)
}

private func readLinesIfPresent(_ url: URL) -> [String] {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        return []
    }

    return content.split(separator: "\n").map(String.init)
}

private func makeExecutable(_ url: URL) throws {
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

private func runProcess(
    executable: String,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentDirectory: URL? = nil
) throws -> ProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment
    process.currentDirectoryURL = currentDirectory

    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }
    process.standardOutput = outputHandle
    process.standardError = outputHandle
    try process.run()
    process.waitUntilExit()

    let output = String(data: try Data(contentsOf: outputURL), encoding: .utf8) ?? ""
    return ProcessResult(status: process.terminationStatus, output: output)
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
}

private func repoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func expectContent(
    _ content: String,
    in relativePath: String,
    contains requiredTokens: [String],
    forbids forbiddenTokens: [String]
) {
    for token in requiredTokens {
        let hasToken = content.contains(token)
        #expect(hasToken, "\(relativePath) missing required token \(token)")
    }

    for token in forbiddenTokens {
        let doesNotHaveForbiddenToken = !content.contains(token)
        #expect(doesNotHaveForbiddenToken, "\(relativePath) must not contain forbidden token \(token)")
    }
}

private actor CoverageAuthNetworkSpy {
    let clientID: String
    let exchangeResponse: OAuthTokenResponse
    let refreshResponse: OAuthTokenResponse
    let appleResponse: OAuthTokenResponse
    let passwordResponse: OAuthTokenResponse
    private(set) var registerRequests: [CoverageRegisterRequest] = []
    private(set) var exchangeRequests: [CoverageCodeExchangeRequest] = []
    private(set) var appleCredentials: [NativeAppleSignInCredential] = []
    private(set) var passwordCredentials: [NativePasswordSignInCredential] = []
    private(set) var refreshRequests: [CoverageRefreshRequest] = []
    private(set) var revokeRequests: [CoverageRevokeRequest] = []

    init(
        clientID: String,
        exchangeResponse: OAuthTokenResponse,
        refreshResponse: OAuthTokenResponse,
        appleResponse: OAuthTokenResponse? = nil,
        passwordResponse: OAuthTokenResponse? = nil
    ) {
        self.clientID = clientID
        self.exchangeResponse = exchangeResponse
        self.refreshResponse = refreshResponse
        self.appleResponse = appleResponse ?? exchangeResponse
        self.passwordResponse = passwordResponse ?? exchangeResponse
    }

    func registerClient(clientName: String, redirectURI: URL) async throws -> String {
        registerRequests.append(CoverageRegisterRequest(clientName: clientName, redirectURI: redirectURI.absoluteString))
        return clientID
    }

    func exchangeCode(clientID: String, redirectURI: URL, code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        exchangeRequests.append(
            CoverageCodeExchangeRequest(
                clientID: clientID,
                redirectURI: redirectURI.absoluteString,
                code: code,
                codeVerifier: codeVerifier
            )
        )
        return exchangeResponse
    }

    func exchangeAppleCredential(_ credential: NativeAppleSignInCredential) async throws -> OAuthTokenResponse {
        appleCredentials.append(credential)
        return appleResponse
    }

    func exchangePasswordCredential(_ credential: NativePasswordSignInCredential) async throws -> OAuthTokenResponse {
        passwordCredentials.append(credential)
        return passwordResponse
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        refreshRequests.append(CoverageRefreshRequest(clientID: clientID, refreshToken: refreshToken))
        return refreshResponse
    }

    func revoke(refreshToken: String, clientID: String) async throws {
        revokeRequests.append(CoverageRevokeRequest(refreshToken: refreshToken, clientID: clientID))
    }
}

private struct CoverageRegisterRequest: Equatable {
    let clientName: String
    let redirectURI: String
}

private struct CoverageCodeExchangeRequest: Equatable {
    let clientID: String
    let redirectURI: String
    let code: String
    let codeVerifier: String
}

private struct CoverageRefreshRequest: Equatable {
    let clientID: String
    let refreshToken: String
}

private struct CoverageRevokeRequest: Equatable {
    let refreshToken: String
    let clientID: String
}

private func coverageTokenResponse(accessToken: String, refreshToken: String, expiresIn: Int) -> OAuthTokenResponse {
    let data = Data(
        #"""
        {
          "access_token": "\#(accessToken)",
          "refresh_token": "\#(refreshToken)",
          "token_type": "Bearer",
          "expires_in": \#(expiresIn),
          "scope": "\#(NativeAuthSession.defaultScope)"
        }
        """#.utf8
    )
    return try! JSONDecoder().decode(OAuthTokenResponse.self, from: data)
}

private func coverageThrowsNativeAuthSessionError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private func coverageThrowsNativeAuthSessionError(_ operation: () throws -> Void) throws -> Bool {
    do {
        try operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private let validationHarnessWrapperSource = #"""
#!/usr/bin/env bash
set -euo pipefail

output_path=""
blocker_path=""
timeout_seconds=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      output_path="$2"
      shift 2
      ;;
    --blocker)
      blocker_path="$2"
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf 'unknown wrapper argument %s\n' "$1" >&2
      exit 64
      ;;
  esac
done

mkdir -p "$(dirname "$output_path")" "$(dirname "$blocker_path")"
printf '%s|output=%s|blocker=%s|timeout=%s|command=%s\n' \
  "${FAKE_WRAPPER_MODE:-success}" "$output_path" "$blocker_path" "$timeout_seconds" "$*" >> "${WRAPPER_CALLS:?}"
rm -f "$blocker_path"

case "${FAKE_WRAPPER_MODE:-success}" in
  success)
    printf 'Build Succeeded\n' > "$output_path"
    exit 0
    ;;
  xcode-platform-blocker)
    printf 'xcodebuild: error: iOS 26.5 is not installed\n' > "$output_path"
    cat > "$blocker_path" <<JSON
{
  "capability": "XcodePlatform",
  "blocked": true,
  "command": "$*",
  "timeoutSeconds": $timeout_seconds,
  "outputPath": "$output_path",
  "reason": "fake local platform blocker",
  "ownerAction": "Install the fake local platform."
}
JSON
    exit 0
    ;;
  compile-failure)
    printf 'SwiftCompile failed while compiling SpoonjoyRootView.swift\n' > "$output_path"
    exit 65
    ;;
  *)
    printf 'unknown fake wrapper mode %s\n' "${FAKE_WRAPPER_MODE:-}" >&2
    exit 64
    ;;
esac
"""#

private let validationHarnessSwiftSource = #"""
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"--show-codecov-path"* ]]; then
  printf '%s\n' "$PWD/fake-coverage.json"
  exit 0
fi

if [[ "${1:-}" == "test" ]]; then
  exit 0
fi

printf 'unexpected swift invocation: %s\n' "$*" >&2
exit 64
"""#

private let validationHarnessXcodebuildSource = #"""
#!/usr/bin/env bash
set -euo pipefail

case "${*:-}" in
  "-version")
    printf 'Xcode 26.5\nBuild version 17F76\n'
    exit 0
    ;;
  "-checkFirstLaunchStatus")
    if [[ "${FAKE_XCODEBUILD_MODE:-success}" == "preflight-dvtplugin" ]]; then
      printf 'DVTPlugInManager failed to load plug-in com.apple.dt.IDEDistribution\n' >&2
      exit 69
    fi
    if [[ "${FAKE_XCODEBUILD_MODE:-success}" == "preflight-silent-first-launch" ]]; then
      exit 69
    fi
    exit 0
    ;;
esac

printf '%s\n' "$*" >> "${DIRECT_XCODEBUILD_CALLS:?}"
printf 'direct xcodebuild invocation should be delegated through wrapper: %s\n' "$*" >&2
exit 64
"""#

private let fakeXcodebuildSource = #"""
#!/usr/bin/env bash
set -euo pipefail

case "${*:-}" in
  "-version")
    printf 'Xcode 26.5\nBuild version 17F76\n'
    exit 0
    ;;
  "-checkFirstLaunchStatus")
    if [[ "${FAKE_XCODEBUILD_MODE:-success}" == "preflight-dvtplugin" ]]; then
      printf 'DVTPlugInManager failed to load plug-in com.apple.dt.IDEDistribution\n' >&2
      exit 69
    fi
    if [[ "${FAKE_XCODEBUILD_MODE:-success}" == "preflight-silent-first-launch" ]]; then
      exit 69
    fi
    exit 0
    ;;
esac

case "${FAKE_XCODEBUILD_MODE:-success}" in
  missing-ios-platform)
    printf 'xcodebuild: error: iOS 26.5 is not installed. To use with Xcode, first download and install the platform.\n' >&2
    exit 70
    ;;
  compile-failure)
    printf 'SwiftCompile failed while compiling SpoonjoyRootView.swift\n' >&2
    exit 65
    ;;
  compile-failure-coresimulator-mention)
    printf 'SwiftCompile failed while compiling CoreSimulatorAdapter.swift\n' >&2
    exit 65
    ;;
  success)
    printf 'Build Succeeded\n'
    exit 0
    ;;
  *)
    printf 'unknown fake mode %s\n' "${FAKE_XCODEBUILD_MODE:-}" >&2
    exit 64
    ;;
esac
"""#

private final class FakeKeychainTokenVaultClient: KeychainTokenVaultClient, @unchecked Sendable {
    var nextCopyStatus: OSStatus?
    var nextUpdateStatus: OSStatus?
    var nextAddStatus: OSStatus?
    var nextDeleteStatus: OSStatus?

    private var storage: [String: Data] = [:]
    private var accessGroups = Set<String>()

    var capturedAccessGroups: [String] {
        accessGroups.sorted()
    }

    func copyMatching(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        recordAccessGroup(from: query)
        if let status = nextCopyStatus {
            nextCopyStatus = nil
            return status
        }
        guard let service = service(from: query), let data = storage[service] else {
            return errSecItemNotFound
        }
        result?.pointee = data as CFTypeRef
        return errSecSuccess
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        recordAccessGroup(from: query)
        if let status = nextUpdateStatus {
            nextUpdateStatus = nil
            return status
        }
        guard let service = service(from: query), storage[service] != nil else {
            return errSecItemNotFound
        }
        storage[service] = attributes[kSecValueData as String] as? Data
        return errSecSuccess
    }

    func add(_ query: [String: Any]) -> OSStatus {
        recordAccessGroup(from: query)
        if let status = nextAddStatus {
            nextAddStatus = nil
            return status
        }
        guard let service = service(from: query), let data = query[kSecValueData as String] as? Data else {
            return errSecParam
        }
        storage[service] = data
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        recordAccessGroup(from: query)
        if let status = nextDeleteStatus {
            nextDeleteStatus = nil
            return status
        }
        guard let service = service(from: query), storage.removeValue(forKey: service) != nil else {
            return errSecItemNotFound
        }
        return errSecSuccess
    }

    private func service(from query: [String: Any]) -> String? {
        query[kSecAttrService as String] as? String
    }

    private func recordAccessGroup(from query: [String: Any]) {
        if let accessGroup = query[kSecAttrAccessGroup as String] as? String {
            accessGroups.insert(accessGroup)
        }
    }
}

private func expectKeychainStatus(
    _ status: OSStatus,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected KeychainTokenVaultError.unhandledStatus(\(status))")
    } catch KeychainTokenVaultError.unhandledStatus(let actualStatus) {
        #expect(actualStatus == status)
    } catch {
        Issue.record("Expected KeychainTokenVaultError.unhandledStatus(\(status)); got \(error)")
    }
}

private let webAuthenticationSessionAdapterContractSource = #"""
import Foundation
import Testing
@testable import SpoonjoyCore
@testable import SpoonjoyAppAuth

@MainActor
@Suite("Web authentication session adapter contract")
struct WebAuthenticationSessionAdapterContract {
    @Test("adapter configures exact HTTPS callback forwards callback and cancels")
    func adapterConfiguresExactHTTPSCallbackForwardsCallbackAndCancels() throws {
        let factory = FakeSessionFactory()
        var forwardedCallbacks: [URL] = []
        let adapter = SpoonjoyWebAuthenticationSession(
            callbackURL: URL(string: "https://spoonjoy.app/oauth/callback")!,
            sessionFactory: factory.makeSession,
            callbackHandler: { callbackURL in
                forwardedCallbacks.append(callbackURL)
            },
            cancellationHandler: { _ in
                Issue.record("Successful callback must not invoke cancellation handler")
            }
        )
        let authorizationURL = URL(string: "https://spoonjoy.app/oauth/authorize?client_id=cm_native_spoonjoy&state=state_123")!
        let state = try #require(OAuthState(rawValue: "state_123"))

        #expect(try adapter.start(authorizationURL: authorizationURL, oauthState: state))
        #expect(factory.requests == [
            FakeSessionRequest(
                authorizationURL: authorizationURL,
                callback: .https(host: "spoonjoy.app", path: "/oauth/callback")
            )
        ])
        let session = try #require(factory.sessions.first)
        #expect(session.prefersEphemeralWebBrowserSession == false)
        #expect(session.startCount == 1)

        let callbackURL = URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!
        factory.complete(with: callbackURL)
        #expect(forwardedCallbacks == [callbackURL])

        adapter.cancel()
        #expect(session.cancelCount == 1)
    }

    @Test("adapter clears active session when system start fails")
    func adapterClearsActiveSessionWhenSystemStartFails() throws {
        let factory = FakeSessionFactory(startResult: false)
        let adapter = SpoonjoyWebAuthenticationSession(
            callbackURL: URL(string: "https://spoonjoy.app/oauth/callback")!,
            sessionFactory: factory.makeSession,
            callbackHandler: { _ in },
            cancellationHandler: { _ in
                Issue.record("A start failure must not be reported as user cancellation")
            }
        )
        let authorizationURL = URL(string: "https://spoonjoy.app/oauth/authorize?client_id=cm_native_spoonjoy&state=state_123")!
        let state = try #require(OAuthState(rawValue: "state_123"))

        #expect(try !adapter.start(authorizationURL: authorizationURL, oauthState: state))
        let session = try #require(factory.sessions.first)
        #expect(session.startCount == 1)

        adapter.cancel()
        #expect(session.cancelCount == 0)
    }

    @Test("adapter reports system cancellation without forwarding a callback")
    func adapterReportsSystemCancellationWithoutForwardingCallback() throws {
        let factory = FakeSessionFactory()
        var forwardedCallbacks: [URL] = []
        var cancellations = 0
        let adapter = SpoonjoyWebAuthenticationSession(
            callbackURL: URL(string: "https://spoonjoy.app/oauth/callback")!,
            sessionFactory: factory.makeSession,
            callbackHandler: { callbackURL in
                forwardedCallbacks.append(callbackURL)
            },
            cancellationHandler: { error in
                cancellations += 1
                #expect(error != nil)
            }
        )
        let authorizationURL = URL(string: "https://spoonjoy.app/oauth/authorize?client_id=cm_native_spoonjoy&state=state_123")!
        let state = try #require(OAuthState(rawValue: "state_123"))

        #expect(try adapter.start(authorizationURL: authorizationURL, oauthState: state))
        factory.complete(with: nil, error: TestAuthenticationError.canceled)

        #expect(forwardedCallbacks.isEmpty)
        #expect(cancellations == 1)
    }
}

private enum TestAuthenticationError: Error {
    case canceled
}

private struct FakeSessionRequest: Equatable {
    let authorizationURL: URL
    let callback: SpoonjoyWebAuthenticationCallback
}

@MainActor
private final class FakeSessionFactory {
    private(set) var requests: [FakeSessionRequest] = []
    private(set) var sessions: [FakeWebAuthenticationSession] = []
    private var completionHandler: (@MainActor (URL?, Error?) -> Void)?
    private let startResult: Bool

    init(startResult: Bool = true) {
        self.startResult = startResult
    }

    func makeSession(
        authorizationURL: URL,
        callback: SpoonjoyWebAuthenticationCallback,
        completionHandler: @escaping @MainActor (URL?, Error?) -> Void
    ) -> any SpoonjoyWebAuthenticationSessionProtocol {
        requests.append(FakeSessionRequest(authorizationURL: authorizationURL, callback: callback))
        self.completionHandler = completionHandler
        let session = FakeWebAuthenticationSession(startResult: startResult)
        sessions.append(session)
        return session
    }

    func complete(with url: URL?, error: Error? = nil) {
        completionHandler?(url, error)
    }
}

@MainActor
private final class FakeWebAuthenticationSession: SpoonjoyWebAuthenticationSessionProtocol {
    var prefersEphemeralWebBrowserSession = false
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    private let startResult: Bool

    init(startResult: Bool = true) {
        self.startResult = startResult
    }

    func start() -> Bool {
        startCount += 1
        return startResult
    }

    func cancel() {
        cancelCount += 1
    }
}

"""#

private let nativeAuthBehaviorContractSource = ##"""
import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native auth behavior contract")
struct NativeAuthBehaviorContract {
    private let now = Date(timeIntervalSince1970: 1_781_612_800)

    @Test("repository starts sign in restores sessions refreshes rotates revokes and logs out")
    func repositoryStartsSignInRestoresRefreshesRotatesRevokesAndLogsOut() async throws {
        let vault = InMemoryTokenVault()
        let network = AuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: tokenResponse(accessToken: "sj_access_initial", refreshToken: "ort_refresh_initial", expiresIn: 300),
            refreshResponse: tokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            scope: NativeAuthSession.defaultScope,
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )

        #expect(try await repository.restoreState() == .signedOut)

        let state = try #require(OAuthState(rawValue: "state_123"))
        let randomVerifierA = OAuthPKCE.randomVerifier()
        let randomVerifierB = OAuthPKCE.randomVerifier()
        #expect(OAuthPKCE.isValidVerifier(randomVerifierA))
        #expect(OAuthPKCE.isValidVerifier(randomVerifierB))
        #expect(randomVerifierA != randomVerifierB)
        let start = try await repository.startSignIn(state: state, codeChallenge: "code_challenge_123")
        #expect(start.clientID == "cm_native_spoonjoy")
        #expect(start.redirectURI == URL(string: "https://spoonjoy.app/oauth/callback")!)
        #expect(start.authorizationURL.path == "/oauth/authorize")
        #expect(start.authorizationURL.query?.contains("client_id=cm_native_spoonjoy") == true)
        #expect(try await vault.loadClientID() == "cm_native_spoonjoy")

        let session = try await repository.handleOAuthCallback(
            URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_123")!,
            expectedState: state,
            codeVerifier: "pkce_verifier"
        )
        #expect(session.accessToken == "sj_access_initial")
        #expect(session.refreshToken == "ort_refresh_initial")
        #expect(try await vault.loadSession() == session)
        #expect(try await repository.restoreState() == .authenticated(session))
        #expect(await network.exchangeRequests == [
            CodeExchangeRequest(clientID: "cm_native_spoonjoy", redirectURI: "https://spoonjoy.app/oauth/callback", code: "oac_code", codeVerifier: "pkce_verifier")
        ])

        let expired = try AuthSession(
            clientID: "cm_native_spoonjoy",
            accessToken: "sj_access_expired",
            refreshToken: "ort_refresh_initial",
            tokenType: "Bearer",
            expiresAt: now.addingTimeInterval(-1),
            scope: NativeAuthSession.defaultScope
        )
        try await vault.saveSession(expired)
        #expect(try await repository.restoreState() == .refreshRequired(expired))

        let valid = try await repository.validSession()
        #expect(valid.accessToken == "sj_access_rotated")
        #expect(valid.refreshToken == "ort_refresh_rotated")
        #expect(try await vault.loadSession() == valid)
        #expect(await network.refreshRequests == [
            RefreshRequest(clientID: "cm_native_spoonjoy", refreshToken: "ort_refresh_initial")
        ])

        try await repository.revokeAndLogout()
        #expect(try await repository.restoreState() == .signedOut)
        #expect(try await vault.loadSession() == nil)
        #expect(try await vault.loadClientID() == nil)
        #expect(await network.revokeRequests == [
            RevokeRequest(refreshToken: "ort_refresh_rotated", clientID: "cm_native_spoonjoy")
        ])
    }

    @Test("repository rejects callback state mismatch missing code and wrong callback route")
    func repositoryRejectsCallbackStateMismatchMissingCodeAndWrongCallbackRoute() async throws {
        let vault = InMemoryTokenVault()
        try await vault.saveClientID("cm_native_spoonjoy")
        let network = AuthNetworkSpy(
            clientID: "cm_native_spoonjoy",
            exchangeResponse: tokenResponse(accessToken: "sj_access", refreshToken: "ort_refresh", expiresIn: 300),
            refreshResponse: tokenResponse(accessToken: "sj_access_rotated", refreshToken: "ort_refresh_rotated", expiresIn: 600)
        )
        let repository = NativeAuthSessionRepository(
            vault: vault,
            clientName: "Spoonjoy Apple",
            redirectURI: URL(string: "https://spoonjoy.app/oauth/callback")!,
            scope: NativeAuthSession.defaultScope,
            registerClient: network.registerClient,
            exchangeCode: network.exchangeCode,
            refresh: network.refresh,
            revoke: network.revoke,
            now: { now }
        )
        let expected = try #require(OAuthState(rawValue: "state_123"))

        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?code=oac_code&state=state_other")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/oauth/callback?state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsOAuthRedirectValidationError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "spoonjoy://oauth/callback?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsOAuthRedirectValidationError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app/not-oauth?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "http://localhost/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(
            try await throwsNativeAuthSessionError {
                _ = try await repository.handleOAuthCallback(
                URL(string: "https://spoonjoy.app:444/oauth/callback?code=oac_code&state=state_123")!,
                expectedState: expected,
                codeVerifier: "pkce_verifier"
                )
            }
        )
        #expect(await network.exchangeRequests.isEmpty)
    }
}

private actor AuthNetworkSpy {
    let clientID: String
    let exchangeResponse: OAuthTokenResponse
    let refreshResponse: OAuthTokenResponse
    private(set) var exchangeRequests: [CodeExchangeRequest] = []
    private(set) var refreshRequests: [RefreshRequest] = []
    private(set) var revokeRequests: [RevokeRequest] = []

    init(clientID: String, exchangeResponse: OAuthTokenResponse, refreshResponse: OAuthTokenResponse) {
        self.clientID = clientID
        self.exchangeResponse = exchangeResponse
        self.refreshResponse = refreshResponse
    }

    func registerClient(clientName: String, redirectURI: URL) async throws -> String {
        #expect(clientName == "Spoonjoy Apple")
        #expect(redirectURI.absoluteString == "https://spoonjoy.app/oauth/callback")
        return clientID
    }

    func exchangeCode(clientID: String, redirectURI: URL, code: String, codeVerifier: String) async throws -> OAuthTokenResponse {
        exchangeRequests.append(
            CodeExchangeRequest(
                clientID: clientID,
                redirectURI: redirectURI.absoluteString,
                code: code,
                codeVerifier: codeVerifier
            )
        )
        return exchangeResponse
    }

    func refresh(clientID: String, refreshToken: String) async throws -> OAuthTokenResponse {
        refreshRequests.append(RefreshRequest(clientID: clientID, refreshToken: refreshToken))
        return refreshResponse
    }

    func revoke(refreshToken: String, clientID: String) async throws {
        revokeRequests.append(RevokeRequest(refreshToken: refreshToken, clientID: clientID))
    }
}

private struct CodeExchangeRequest: Equatable {
    let clientID: String
    let redirectURI: String
    let code: String
    let codeVerifier: String
}

private struct RefreshRequest: Equatable {
    let clientID: String
    let refreshToken: String
}

private struct RevokeRequest: Equatable {
    let refreshToken: String
    let clientID: String
}

private func tokenResponse(accessToken: String, refreshToken: String, expiresIn: Int) -> OAuthTokenResponse {
    let data = Data(
        #"""
        {
          "access_token": "\#(accessToken)",
          "refresh_token": "\#(refreshToken)",
          "token_type": "Bearer",
          "expires_in": \#(expiresIn),
          "scope": "\#(NativeAuthSession.defaultScope)"
        }
        """#.utf8
    )
    return try! JSONDecoder().decode(OAuthTokenResponse.self, from: data)
}

private func throwsNativeAuthSessionError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is NativeAuthSessionError {
        return true
    }
}

private func throwsOAuthRedirectValidationError(_ operation: () async throws -> Void) async throws -> Bool {
    do {
        try await operation()
        return false
    } catch is OAuthRedirectValidationError {
        return true
    }
}
"""##
