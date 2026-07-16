import AuthenticationServices
import CryptoKit
import Security
import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    private static let liveAppleSignInIdentifier = "native Apple sign-in"
    private static let livePasswordSignInIdentifier = "native password sign-in"
    fileprivate static let liveGoogleOAuthSignInIdentifier = "native Google OAuth sign-in"
    fileprivate static let liveGitHubOAuthSignInIdentifier = "native GitHub OAuth sign-in"
    private static let appleSignInEntitlement = "com.apple.developer.applesignin"

    let authRepository: NativeAuthSessionRepository
    let pendingRoute: AppRoute
    let openSettings: () -> Void
    let onSignedIn: @MainActor () async -> Void
    let appleSignInTelemetry: NativeAppleSignInTelemetry.Client

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var emailOrUsername = ""
    @State private var password = ""
    @State private var authStatus = "Use your Spoonjoy email or username to sign in."
    @State private var statusTone = AuthStatusTone.neutral
    @State private var isSigningIn = false
    @State private var canDisconnect = false
    @State private var currentNonce: String?
    @State private var pendingOAuthState: OAuthState?
    @State private var pendingOAuthCodeVerifier: String?
    @State private var pendingOAuthProvider: OAuthProviderHint?
    @State private var webAuthenticationSession: SpoonjoyWebAuthenticationSession?
    @State private var appleSignInCapability = Self.currentAppleSignInCapability()
    @FocusState private var focusedField: SignInField?

    init(
        authRepository: NativeAuthSessionRepository,
        pendingRoute: AppRoute = .kitchen,
        openSettings: @escaping () -> Void,
        appleSignInTelemetry: NativeAppleSignInTelemetry.Client = .disabled,
        onSignedIn: @escaping @MainActor () async -> Void = {}
    ) {
        self.authRepository = authRepository
        self.pendingRoute = pendingRoute
        self.openSettings = openSettings
        self.appleSignInTelemetry = appleSignInTelemetry
        self.onSignedIn = onSignedIn
    }

    var body: some View {
        signedOutLayout
        .background(KitchenTableTheme.bone)
        .task {
            appleSignInCapability = Self.currentAppleSignInCapability()
            await restoreState()
            await writeCapturePendingProofIfNeeded()
        }
    }

    @ViewBuilder private var signedOutLayout: some View {
#if os(macOS)
        HStack(spacing: 0) {
            signedOutBrandColumn
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 36)
                .background(KitchenTableTheme.paper)

            Rectangle()
                .fill(KitchenTableTheme.charcoal.opacity(0.10))
                .frame(width: 1)

            credentialPanel
                .frame(maxWidth: 430, alignment: .leading)
                .padding(.horizontal, 44)
                .padding(.vertical, 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(minWidth: 900, minHeight: 620)
#else
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 26) {
                    identityHeader
                    credentialPanel
                }
                .frame(maxWidth: 430)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 28)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
#endif
    }

    private var identityHeader: some View {
        VStack(spacing: 14) {
            SpoonjoyIdentityMark()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("Spoonjoy")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .multilineTextAlignment(.center)

                Text("Open your kitchen table.")
                    .font(.body)
                    .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signedOutBrandColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            SpoonjoyIdentityMark()
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Spoonjoy")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)

                Text("Open your kitchen table on this Mac.")
                    .font(.title3)
                    .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            Label("spoonjoy.app", systemImage: "link")
                .font(KitchenTableTheme.uiLabel.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.58))
                .labelStyle(.titleAndIcon)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 44)
    }

    private var credentialPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)

                Text("Use the same Spoonjoy account you use on spoonjoy.app.")
                    .font(.body)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if pendingRoute != .kitchen {
                Label(pendingRouteLabel, systemImage: "arrow.triangle.turn.up.right.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KitchenTableTheme.herb.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email or username", text: $emailOrUsername)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .spoonjoyCredentialIdentifierEntry()
                    .focused($focusedField, equals: .identifier)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    .disabled(isSigningIn)
                    .accessibilityIdentifier("native sign-in email or username")

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await handlePasswordSignIn()
                        }
                    }
                    .disabled(isSigningIn)
                    .accessibilityIdentifier("native sign-in password")
            }

            Button {
                Task {
                    await handlePasswordSignIn()
                }
            } label: {
                HStack(spacing: 10) {
                    if isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Image(systemName: "arrow.right.circle.fill")
                        .imageScale(.medium)
                    Text("Sign in")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSubmitPassword && !isSigningIn ? KitchenTableTheme.paper : KitchenTableTheme.charcoal.opacity(0.46))
            .background(passwordButtonBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(KitchenTableTheme.charcoal.opacity(canSubmitPassword ? 0 : 0.10), lineWidth: 1)
            }
            .disabled(isSigningIn || !canSubmitPassword)
            .accessibilityIdentifier(Self.livePasswordSignInIdentifier)

            HStack(alignment: .center, spacing: 12) {
                Rectangle()
                    .fill(KitchenTableTheme.charcoal.opacity(0.14))
                    .frame(height: 1)
                Text("or")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.56))
                Rectangle()
                    .fill(KitchenTableTheme.charcoal.opacity(0.14))
                    .frame(height: 1)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                ForEach(OAuthProviderHint.allCases, id: \.self) { provider in
                    Button {
                        Task {
                            await handleBrowserOAuthSignIn(provider: provider)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if pendingOAuthProvider == provider && isSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: provider.signInSystemImage)
                                .imageScale(.medium)
                            Text(provider.signInButtonTitle)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSigningIn ? KitchenTableTheme.charcoal.opacity(0.46) : KitchenTableTheme.charcoal)
                    .background(KitchenTableTheme.paper, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(KitchenTableTheme.charcoal.opacity(0.14), lineWidth: 1)
                    }
                    .disabled(isSigningIn)
                    .accessibilityIdentifier(provider.signInAccessibilityIdentifier)
                }
            }

            if appleSignInCapability == .available {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = Self.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                    isSigningIn = true
                    statusTone = .progress
                    authStatus = "Waiting for Apple sign-in."
                    NativeAppleSignInTelemetry.logPhase("authorization_request_started")
                    Task {
                        await appleSignInTelemetry.recordPhase("authorization_request_started",
                            rawNoncePresent: true
                        )
                    }
                } onCompletion: { result in
                    Task {
                        await handleAppleAuthorization(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
                .disabled(isSigningIn)
                .accessibilityIdentifier(Self.liveAppleSignInIdentifier)
            } else {
                appleUnavailableRow
            }

            statusRow

            HStack(spacing: 10) {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                if canDisconnect {
                    Button(role: .destructive) {
                        Task {
                            await revokeAndLogout()
                        }
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.regular)
        }
        .frame(maxWidth: 430, alignment: .leading)
    }

    private var appleUnavailableRow: some View {
        Label {
            Text(appleSignInCapability.message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "signature")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(KitchenTableTheme.brass)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.brass.opacity(0.10), in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
        .accessibilityIdentifier("native Apple sign-in availability")
    }

    private var passwordButtonBackground: Color {
        if isSigningIn {
            return KitchenTableTheme.herb.opacity(0.54)
        }
        if canSubmitPassword {
            return KitchenTableTheme.herb
        }
        return KitchenTableTheme.charcoal.opacity(0.08)
    }

    private var statusRow: some View {
        Label {
            Text(authStatus)
                .font(.callout)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
        }
        .accessibilityIdentifier("native sign-in status")
    }

    private var canSubmitPassword: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusColor: Color {
        switch statusTone {
        case .neutral:
            return KitchenTableTheme.charcoal.opacity(0.72)
        case .progress:
            return KitchenTableTheme.herb
        case .success:
            return KitchenTableTheme.herb
        case .warning:
            return KitchenTableTheme.brass
        case .error:
            return KitchenTableTheme.tomato
        }
    }

    private var statusSymbol: String {
        switch statusTone {
        case .neutral:
            return "lock.shield"
        case .progress:
            return "person.badge.clock"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private func restoreState() async {
        do {
            switch try await authRepository.restoreState() {
            case .signedOut:
                canDisconnect = false
                statusTone = .neutral
                authStatus = "Use your Spoonjoy email or username to sign in."
            case .authenticated:
                canDisconnect = true
                statusTone = .success
                authStatus = "Signed in. Restoring your Spoonjoy cache."
            case .refreshRequired:
                canDisconnect = true
                statusTone = .warning
                authStatus = "Session refresh required. Sign in again if restore does not complete."
            }
        } catch {
            statusTone = .warning
            authStatus = "Spoonjoy could not restore this device session. Sign in again to continue."
        }
    }

    private func handleBrowserOAuthSignIn(provider: OAuthProviderHint) async {
        guard !isSigningIn else {
            return
        }

        isSigningIn = true
        pendingOAuthProvider = provider
        statusTone = .progress
        authStatus = "Opening \(provider.displayName) sign-in."

        do {
            let verifier = OAuthPKCE.randomVerifier()
            let challenge = try OAuthPKCE.codeChallenge(for: verifier)
            guard let state = OAuthState(rawValue: OAuthPKCE.randomVerifier()) else {
                throw BrowserOAuthSignInError.invalidState
            }
            let start = try await authRepository.startSignIn(
                state: state,
                codeChallenge: challenge,
                providerHint: provider
            )
            pendingOAuthState = state
            pendingOAuthCodeVerifier = verifier

            let session = SpoonjoyWebAuthenticationSession(callbackURL: start.redirectURI,
                callbackHandler: { callbackURL in
                    Task {
                        await handleBrowserOAuthCallback(callbackURL)
                    }
                },
                cancellationHandler: { error in
                    Task {
                        await handleBrowserOAuthCancellation(error)
                    }
                }
            )
            webAuthenticationSession = session
            guard try session.start(authorizationURL: start.authorizationURL, oauthState: state) else {
                throw BrowserOAuthSignInError.couldNotStart
            }

            authStatus = "Finish \(provider.displayName) sign-in in the browser."
        } catch {
            pendingOAuthState = nil
            pendingOAuthCodeVerifier = nil
            pendingOAuthProvider = nil
            webAuthenticationSession = nil
            isSigningIn = false
            statusTone = .error
            authStatus = "Could not open \(provider.displayName) sign-in. Check your connection and try again."
        }
    }

    @MainActor
    private func handleBrowserOAuthCallback(_ callbackURL: URL) async {
        guard let state = pendingOAuthState,
              let verifier = pendingOAuthCodeVerifier else {
            pendingOAuthProvider = nil
            webAuthenticationSession = nil
            isSigningIn = false
            statusTone = .error
            authStatus = "Browser sign-in expired. Try again."
            return
        }

        isSigningIn = true
        statusTone = .progress
        authStatus = "Finishing Spoonjoy sign-in."
        defer {
            isSigningIn = false
            pendingOAuthState = nil
            pendingOAuthCodeVerifier = nil
            pendingOAuthProvider = nil
            webAuthenticationSession = nil
        }

        do {
            _ = try await authRepository.handleOAuthCallback(
                callbackURL,
                expectedState: state,
                codeVerifier: verifier
            )
            canDisconnect = true
            statusTone = .success
            authStatus = "Signed in. Restoring Spoonjoy."
            await onSignedIn()
        } catch {
            statusTone = .error
            authStatus = "Could not finish browser sign-in. Try again."
        }
    }

    @MainActor
    private func handleBrowserOAuthCancellation(_ error: Error?) async {
        pendingOAuthState = nil
        pendingOAuthCodeVerifier = nil
        pendingOAuthProvider = nil
        webAuthenticationSession = nil
        isSigningIn = false
        statusTone = .neutral
        authStatus = "Browser sign-in canceled."
        _ = error
    }

    private func handlePasswordSignIn() async {
        guard !isSigningIn else {
            return
        }
        let identifier = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusTone = .warning
            authStatus = "Enter your Spoonjoy email or username and password."
            return
        }

        isSigningIn = true
        statusTone = .progress
        authStatus = "Signing in securely."
        defer {
            isSigningIn = false
            password = ""
        }

        do {
            _ = try await authRepository.handlePasswordSignInCredential(
                NativePasswordSignInCredential(emailOrUsername: identifier, password: password)
            )
            focusedField = nil
            canDisconnect = true
            statusTone = .success
            authStatus = "Signed in. Restoring Spoonjoy."
            await onSignedIn()
        } catch {
            statusTone = .error
            authStatus = Self.passwordSignInFailureMessage(for: error)
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        defer { isSigningIn = false }
        do {
            let authorization = try result.get()
            NativeAppleSignInTelemetry.logPhase("authorization_completed")
            await appleSignInTelemetry.recordPhase("authorization_completed",
                outcome: .completed,
                credentialPresent: true
            )
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                NativeAppleSignInTelemetry.logFailure(phase: "credential_validation_failed", code: "missing_apple_id_credential")
                await appleSignInTelemetry.recordFailure(phase: "credential_validation_failed",
                    code: "missing_apple_id_credential",
                    credentialPresent: false,
                    rawNoncePresent: currentNonce != nil
                )
                statusTone = .error
                authStatus = "Apple could not share the sign-in details Spoonjoy needs. Try again."
                return
            }
            guard let nonce = currentNonce else {
                NativeAppleSignInTelemetry.logFailure(phase: "credential_validation_failed", code: "missing_nonce")
                await appleSignInTelemetry.recordFailure(phase: "credential_validation_failed",
                    code: "missing_nonce",
                    credentialPresent: true,
                    identityTokenPresent: appleIDCredential.identityToken != nil,
                    rawNoncePresent: false,
                    emailPresent: appleIDCredential.email?.isEmpty == false,
                    fullNamePresent: appleIDCredential.fullName != nil
                )
                statusTone = .error
                authStatus = "That Apple sign-in expired. Try again."
                return
            }
            guard let identityToken = appleIDCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                NativeAppleSignInTelemetry.logFailure(phase: "credential_validation_failed", code: "missing_identity_token")
                await appleSignInTelemetry.recordFailure(phase: "credential_validation_failed",
                    code: "missing_identity_token",
                    credentialPresent: true,
                    identityTokenPresent: false,
                    rawNoncePresent: true,
                    emailPresent: appleIDCredential.email?.isEmpty == false,
                    fullNamePresent: appleIDCredential.fullName != nil
                )
                statusTone = .error
                authStatus = "Apple did not finish this sign-in. Try again."
                return
            }
            let fullName = appleIDCredential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            let credential = NativeAppleSignInCredential(
                identityToken: identityToken,
                rawNonce: nonce,
                email: appleIDCredential.email,
                fullName: fullName?.isEmpty == true ? nil : fullName
            )
            NativeAppleSignInTelemetry.logPhase("backend_exchange_started")
            await appleSignInTelemetry.recordPhase("backend_exchange_started",
                credentialPresent: true,
                identityTokenPresent: true,
                rawNoncePresent: true,
                emailPresent: credential.email?.isEmpty == false,
                fullNamePresent: credential.fullName?.isEmpty == false
            )
            _ = try await authRepository.handleAppleSignInCredential(credential)
            NativeAppleSignInTelemetry.logPhase("backend_exchange_succeeded")
            await appleSignInTelemetry.recordPhase("backend_exchange_succeeded",
                outcome: .completed,
                credentialPresent: true,
                identityTokenPresent: true,
                rawNoncePresent: true,
                emailPresent: credential.email?.isEmpty == false,
                fullNamePresent: credential.fullName?.isEmpty == false,
                sessionState: "authenticated"
            )
            currentNonce = nil
            canDisconnect = true
            statusTone = .success
            authStatus = "Signed in. Restoring Spoonjoy."
            await onSignedIn()
        } catch {
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                NativeAppleSignInTelemetry.logPhase("authorization_canceled")
                await appleSignInTelemetry.recordPhase("authorization_canceled",
                    outcome: .completed
                )
                statusTone = .neutral
                authStatus = "Apple sign-in canceled."
                return
            }
            NativeAppleSignInTelemetry.logFailure(
                phase: "sign_in_failed",
                code: NativeAppleSignInTelemetry.diagnosticCode(for: error)
            )
            await appleSignInTelemetry.recordFailure(phase: "sign_in_failed",
                code: NativeAppleSignInTelemetry.diagnosticCode(for: error),
                error: error
            )
            statusTone = .error
            authStatus = Self.signInFailureMessage(for: error)
        }
    }

    private static func passwordSignInFailureMessage(for error: Error) -> String {
        switch error {
        case NativeAuthSessionError.passwordSignInUnavailable:
            return "Password sign-in is not available in this build."
        default:
            return "Could not sign in. Check your username, password, and connection."
        }
    }

    private static func signInFailureMessage(for error: Error) -> String {
        guard let authorizationError = error as? ASAuthorizationError else {
            return "Could not finish sign-in. Check your connection and try again."
        }

        switch authorizationError.code {
        case .canceled:
            return "Apple sign-in canceled."
        case .failed:
            return "Sign in with Apple needs a properly signed Spoonjoy build. This local copy is not authorized by Apple yet."
        case .invalidResponse:
            return "Apple returned an invalid sign-in response. Try again in a moment."
        case .notHandled:
            return "Apple could not complete sign-in on this device."
        case .notInteractive:
            return "Apple sign-in needs an interactive window. Bring Spoonjoy forward and try again."
        case .unknown:
            return "Apple could not start sign-in for this build."
        default:
            return "Apple could not finish sign-in for this build."
        }
    }

    private static func currentAppleSignInCapability() -> AppleSignInCapability {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlement = SecTaskCopyValueForEntitlement(
                task,
                Self.appleSignInEntitlement as CFString,
                nil
              ) else {
            return .missingEntitlement
        }

        if let values = entitlement as? [String], values.contains("Default") {
            return .available
        }
        if let value = entitlement as? String, value == "Default" {
            return .available
        }
        return .missingEntitlement
        #elseif SPOONJOY_SIGNED_APPLE_AUTH
        return .available
        #else
        return .missingEntitlement
        #endif
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess, Int(random) < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func revokeAndLogout() async {
        do {
            try await authRepository.revokeAndLogout()
            authStatus = "Signed out."
            statusTone = .neutral
            canDisconnect = false
            isSigningIn = false
        } catch {
            statusTone = .error
            authStatus = "Could not disconnect this device. Check your connection and try again."
        }
    }

    private var pendingRouteLabel: String {
        switch pendingRoute {
        case .kitchen:
            "Opening Kitchen"
        case .recipes:
            "Opening My Recipes after sign-in"
        case .savedRecipes:
            "Opening Saved Recipes after sign-in"
        case .recipeDetail(_, .detail):
            "Opening Recipe after sign-in"
        case .recipeDetail(_, .cook):
            "Opening Cook Mode after sign-in"
        case .recipeEditor(.some):
            "Opening Recipe after sign-in"
        case .recipeEditor(nil):
            "Opening Capture after sign-in"
        case .recipeCoverControls:
            "Opening Recipe after sign-in"
        case .cookbooks:
            "Opening Cookbooks after sign-in"
        case .cookbookDetail:
            "Opening Cookbook after sign-in"
        case .profile:
            "Opening Profile after sign-in"
        case .profileGraph(_, let direction, _):
            switch direction {
            case .fellowChefs:
                "Opening Fellow Chefs after sign-in"
            case .kitchenVisitors:
                "Opening Kitchen Visitors after sign-in"
            }
        case .shoppingList:
            "Opening Shopping List after sign-in"
        case .chefs:
            "Opening Chefs after sign-in"
        case .search:
            "Opening Search after sign-in"
        case .capture:
            "Opening Capture after sign-in"
        case .settings:
            "Opening Settings"
        case .unknownLink:
            "Opening Link"
        }
    }

    private func writeCapturePendingProofIfNeeded() async {
        guard pendingRoute == .capture else {
            return
        }
        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
            route: "capture",
            source: "SignedOutSetupView",
            runtimeContext: ScreenshotAccessibilityRuntimeContext(
                dynamicTypeSize: String(describing: dynamicTypeSize),
                reduceMotionEnabled: accessibilityReduceMotion
            )
        )
    }
}

private enum SignInField: Hashable {
    case identifier
    case password
}

private enum AuthStatusTone {
    case neutral
    case progress
    case success
    case warning
    case error
}

private enum BrowserOAuthSignInError: Error {
    case invalidState
    case couldNotStart
}

@MainActor private extension OAuthProviderHint {
    var displayName: String {
        switch self {
        case .google:
            "Google"
        case .github:
            "GitHub"
        }
    }

    var signInButtonTitle: String {
        switch self {
        case .google:
            "Continue with Google"
        case .github:
            "Continue with GitHub"
        }
    }

    var signInAccessibilityIdentifier: String {
        switch self {
        case .google:
            SignedOutSetupView.liveGoogleOAuthSignInIdentifier
        case .github:
            SignedOutSetupView.liveGitHubOAuthSignInIdentifier
        }
    }

    var signInSystemImage: String {
        switch self {
        case .google:
            "g.circle"
        case .github:
            "chevron.left.forwardslash.chevron.right"
        }
    }
}

private enum AppleSignInCapability: Equatable {
    case available
    case missingEntitlement

    var message: String {
        switch self {
        case .available:
            "Sign in to restore Spoonjoy on this device."
        case .missingEntitlement:
            "Sign in with Apple needs a signed Spoonjoy build. This local dogfood copy is not Apple-authorized yet."
        }
    }
}

private extension View {
    @ViewBuilder func spoonjoyCredentialIdentifierEntry() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
#else
        self
#endif
    }
}

struct SpoonjoyIdentityMark: View {
    var body: some View {
        Image("SpoonjoyMark")
            .resizable()
            .scaledToFit()
    }
}
