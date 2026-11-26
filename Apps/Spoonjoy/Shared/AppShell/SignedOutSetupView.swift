import AuthenticationServices
import OSLog
import Security
import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    private static let liveAppleSignInIdentifier = "native Apple sign-in"
    private static let livePasswordSignInIdentifier = "native password sign-in"
    fileprivate static let liveGoogleOAuthSignInIdentifier = "native Google OAuth sign-in"
    fileprivate static let liveGitHubOAuthSignInIdentifier = "native GitHub OAuth sign-in"
    private static let liveServerBrowserSignInIdentifier = "native server browser sign-in"
    private static let serverRowIdentifier = "signin.server"
    private static let browserSignInLogger = Logger(subsystem: "app.spoonjoy", category: "auth.browser")
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
    @State private var pendingOAuthProvider: OAuthProviderHint?
    /// True while a browser sign-in is under way; with `pendingOAuthProvider` nil, it is the server's own page.
    @State private var browserSignInPending = false
    @State private var browserSignIn: NativeBrowserOAuthSignIn?
    /// True while browser sign-in waits to retry after the system's early cancel (spoonjoy-apple#344): no sheet is up,
    /// so the status row offers Cancel.
    @State private var browserSignInRetryPending = false
    @State private var appleSignInCapability = Self.currentAppleSignInCapability()
    /// The server this screen signs in to, and the one the cook chose, if any (nil while they use the app's own).
    @State private var server = SpoonjoyAppServer.current()
    @State private var chosenServer = SpoonjoyAppServer.chosen()
    @State private var showsServerPicker = false
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
        .background(KitchenTableTheme.page)
        .task {
            appleSignInCapability = Self.currentAppleSignInCapability()
            await restoreState()
            await writeCapturePendingProofIfNeeded()
        }
        .onDisappear {
            // A start still waiting on its request must not open a sheet for a window that has gone.
            browserSignIn?.cancelStart()
        }
        .sheet(isPresented: $showsServerPicker) {
            ServerPickerSheet(
                builtIn: SpoonjoyAppServer.builtIn(),
                current: server,
                onChoose: { address in
                    await chooseServer(address)
                },
                cancel: { showsServerPicker = false }
            )
        }
    }

    @ViewBuilder private var signedOutLayout: some View {
#if os(macOS)
        // As web's desktop sign-in: the lead on the left, the credentials on the right, a hairline between.
        HStack(spacing: 0) {
            // A fixed lead column, so the credentials keep their full width at the window's narrowest.
            signedOutBrandColumn
                .frame(width: 340)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 40)

            Rectangle()
                .fill(KitchenTableTheme.hairline)
                .frame(width: 1)

            GeometryReader { geometry in
                ScrollView {
                    credentialPanel
                        .frame(maxWidth: 430, alignment: .leading)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 44)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
#else
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    identityHeader
                    credentialPanel
                }
                .frame(maxWidth: 430, alignment: .leading)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
#endif
    }

    /// The Spoonjoy wordmark, as web's header sets it: the mark and the name in tracked serif capitals.
    private var spoonjoyWordmark: some View {
        HStack(spacing: 10) {
            SpoonjoyIdentityMark()
                .frame(width: min(wordmarkSize, 44), height: min(wordmarkSize, 44))
            // The name is one word and never breaks: at the largest sizes it scales down on its one line rather
            // than splitting into "SPOONJ / OY".
            Text("Spoonjoy")
                .font(KitchenTableTheme.sectionTitle)
                .textCase(.uppercase)
                .kitchenEyebrowTracking()
                .foregroundStyle(KitchenTableTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spoonjoy")
    }

    @ScaledMetric(relativeTo: .title3) private var wordmarkSize: CGFloat = 30

    /// Web's editorial lead: the eyebrow, the promise in display Fraunces and one serif sentence.
    private var signInLead: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Kitchen sign-in")
                .kitchenEyebrow(KitchenTableTheme.ink2)
            Text("Keep the good recipes close.")
                .font(KitchenTableTheme.displayTitle)
                .foregroundStyle(KitchenTableTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(signInLeadSentence)
                .font(KitchenTableTheme.story)
                .foregroundStyle(KitchenTableTheme.ink2)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The lead's last sentence names the server whose account works here.
    private var signInLeadSentence: String {
        let accountLine = chosenServer.map { "Your account on \($0.displayName) works here." }
            ?? "Your spoonjoy.app account works here too."
        return "Sign in to cook, fork, save, and remember the recipes that actually make it to your table. \(accountLine)"
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: 34) {
            spoonjoyWordmark
            signInLead
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signedOutBrandColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            spoonjoyWordmark
            signInLead
                .padding(.top, 88)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 44)
    }

    private var credentialPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if pendingRoute != .kitchen {
                Label(pendingRouteLabel, systemImage: "arrow.triangle.turn.up.right.circle")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.herb)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KitchenTableTheme.herb.opacity(0.12), in: Capsule(style: .continuous))
            }

            // Guideline 4.8: Sign in with Apple comes first and at full width whenever Google or GitHub is offered,
            // so it is never less prominent than a third-party login. App Review rejected Mac 1.0 (build 2) when it sat last.
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
                // A capsule, as every other control on the screen.
                .clipShape(Capsule(style: .continuous))
                .disabled(isSigningIn)
                .accessibilityIdentifier(Self.liveAppleSignInIdentifier)
            } else {
                appleUnavailableRow
            }

            if let chosenServer {
                // Google and GitHub are spoonjoy.app's. Another server's own sign-in page offers what it has: a
                // password, its own identity provider, or passkeys where its address allows them.
                browserSignInButton(
                    provider: nil,
                    systemImage: "safari",
                    title: "Sign In on \(chosenServer.displayName)",
                    identifier: Self.liveServerBrowserSignInIdentifier
                )
            } else {
                providerButtons
            }

            HStack(alignment: .center, spacing: 12) {
                Rectangle()
                    .fill(KitchenTableTheme.ink.opacity(0.14))
                    .frame(height: 1)
                Text("or")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink.opacity(0.56))
                Rectangle()
                    .fill(KitchenTableTheme.ink.opacity(0.14))
                    .frame(height: 1)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email or username", text: $emailOrUsername)
                    .modifier(SignInFieldStyle { focusField(.identifier) })
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
                    .modifier(SignInFieldStyle { focusField(.password) })
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
                        .font(KitchenTableTheme.control)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSubmitPassword && !isSigningIn ? KitchenTableTheme.onInk : KitchenTableTheme.ink.opacity(0.46))
            .background(passwordButtonBackground, in: Capsule(style: .continuous))
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
            .disabled(isSigningIn || !canSubmitPassword)
            .accessibilityIdentifier(Self.livePasswordSignInIdentifier)

            statusRow

            if browserSignInRetryPending {
                Button("Cancel", action: cancelBrowserSignInRetry)
                    .font(KitchenTableTheme.control)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .accessibilityHint("Stops opening sign-in")
                    .accessibilityIdentifier("native browser sign-in cancel retry")
            }

            HStack(spacing: 20) {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundStyle(KitchenTableTheme.ink2)
                }
                .accessibilityIdentifier("signin.settings")

                // One place to choose the server: it opens the server sheet, and names the server signed in to.
                Button {
                    showsServerPicker = true
                } label: {
                    Label(server.displayName, systemImage: "server.rack")
                        .foregroundStyle(KitchenTableTheme.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .disabled(isSigningIn)
                .accessibilityLabel("Server, \(server.displayName)")
                .accessibilityHint("Chooses the Spoonjoy server to sign in to")
                .accessibilityIdentifier(Self.serverRowIdentifier)

                if canDisconnect {
                    Button(role: .destructive) {
                        Task {
                            await revokeAndLogout()
                        }
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                            .foregroundStyle(KitchenTableTheme.tomato)
                    }
                }
            }
            .buttonStyle(.plain)
            .font(KitchenTableTheme.uiLabel)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
        }
        .frame(maxWidth: 430, alignment: .leading)
    }

    private var providerButtons: some View {
        VStack(spacing: 10) {
            ForEach(OAuthProviderHint.allCases, id: \.self) { provider in
                browserSignInButton(
                    provider: provider,
                    systemImage: provider.signInSystemImage,
                    title: provider.signInButtonTitle,
                    identifier: provider.signInAccessibilityIdentifier
                )
            }
        }
    }

    private func browserSignInButton(
        provider: OAuthProviderHint?,
        systemImage: String,
        title: String,
        identifier: String
    ) -> some View {
        Button {
            Task {
                await handleBrowserOAuthSignIn(provider: provider)
            }
        } label: {
            HStack(spacing: 10) {
                if browserSignInPending && pendingOAuthProvider == provider && isSigningIn {
                    ProgressView()
                        .controlSize(.small)
                }
                Image(systemName: systemImage)
                    .imageScale(.medium)
                Text(title)
                    .font(KitchenTableTheme.control)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSigningIn ? KitchenTableTheme.ink.opacity(0.46) : KitchenTableTheme.ink)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .disabled(isSigningIn)
        .accessibilityIdentifier(identifier)
    }

    private var appleUnavailableRow: some View {
        Label {
            Text(appleSignInCapability.message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "signature")
        }
        .font(KitchenTableTheme.meta)
        .foregroundStyle(KitchenTableTheme.ink2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("native Apple sign-in availability")
    }

    /// Sign in is the screen's primary capsule: the action fill every primary button has (charcoal by day, amber at
    /// night), and a quiet wash until both fields are filled.
    private var passwordButtonBackground: Color {
        if isSigningIn {
            return KitchenTableTheme.action.opacity(0.54)
        }
        if canSubmitPassword {
            return KitchenTableTheme.action
        }
        return KitchenTableTheme.ink.opacity(0.08)
    }

    private var statusRow: some View {
        Label {
            Text(authStatus)
                .font(KitchenTypeRole.meta.font(relativeTo: .callout))
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
            return KitchenTableTheme.ink.opacity(0.72)
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

    /// Moves sign-in to another server. A session still stored for the old one is signed out there first, so its
    /// tokens never reach the new server; then the app's windows start over on the new server.
    /// Nothing else on the screen can start a sign-in meanwhile, and if the old session cannot be signed out the
    /// server stays as it was.
    private func chooseServer(_ address: SpoonjoyServerAddress?) async {
        guard (address ?? SpoonjoyAppServer.builtIn()) != server else {
            showsServerPicker = false
            return
        }
        isSigningIn = true
        defer {
            isSigningIn = false
            showsServerPicker = false
        }
        if canDisconnect {
            guard await revokeAndLogout() else {
                return
            }
        }
        SpoonjoyAppServer.choose(address)
        server = SpoonjoyAppServer.current()
        chosenServer = SpoonjoyAppServer.chosen()
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

    /// Google or GitHub in the system browser sheet. `NativeBrowserOAuthSignIn` gives each attempt its own state and
    /// verifier and keeps one sheet open app-wide, because the web app holds one provider sign-in per browser cookie
    /// jar: a second start would turn the first one's return into `invalid_state`.
    /// What a browser sign-in is named in its status lines: Google or GitHub, or the server whose page it opens.
    private func signInName(_ provider: OAuthProviderHint?) -> String {
        provider?.displayName ?? server.displayName
    }

    private func handleBrowserOAuthSignIn(provider: OAuthProviderHint?) async {
        guard !isSigningIn else {
            return
        }

        isSigningIn = true
        pendingOAuthProvider = provider
        browserSignInPending = true
        statusTone = .progress
        authStatus = "Opening \(signInName(provider)) sign-in."

        let signIn = browserSignIn ?? NativeBrowserOAuthSignIn(
            repository: authRepository,
            log: { Self.browserSignInLogger.notice("\($0, privacy: .public)") },
            makeSession: SpoonjoyBrowserOAuthWebSession.make
        )
        browserSignIn = signIn
        let start = await signIn.begin(provider: provider, sendsProviderHint: Self.sendsProviderHint(), onReturn: {
            statusTone = .progress
            authStatus = "Finishing Spoonjoy sign-in."
        }, onRetry: { phase in
            // The system ended the sheet before showing it and a retry is coming (spoonjoy-apple#344).
            browserSignInRetryPending = phase != .started
            statusTone = .progress
            authStatus = NativeBrowserOAuthEarlyCancel.status(for: phase, providerName: signInName(provider))
        }) { finish in
            // The sign-in has ended: no Cancel for a pending retry from here on.
            browserSignInRetryPending = false
            Task {
                await handleBrowserOAuthFinish(finish, provider: provider)
            }
        }
        switch start {
        case .opened, .alreadyInProgress:
            authStatus = "Finish \(signInName(provider)) sign-in in the browser."
        case .canceled:
            // Stopped before the sheet opened (the view went away): free the buttons quietly.
            pendingOAuthProvider = nil
            browserSignInPending = false
            isSigningIn = false
            statusTone = .neutral
            authStatus = "Browser sign-in canceled."
        case .superseded:
            // Another window's sign-in claimed the gate while this one waited to retry its request.
            pendingOAuthProvider = nil
            browserSignInPending = false
            isSigningIn = false
            statusTone = .neutral
            authStatus = "Browser sign-in continued in another window."
        case .couldNotOpen:
            let reason = signIn.startFailure.map(NativeBrowserOAuthSignIn.diagnosticReason) ?? "unknown"
            Self.browserSignInLogger.error("Browser sign-in did not start: \(reason, privacy: .public)")
            pendingOAuthProvider = nil
            browserSignInPending = false
            isSigningIn = false
            statusTone = .error
            authStatus = "Could not open \(signInName(provider)) sign-in. Check your connection and try again."
        }
    }

    /// Whether /oauth/authorize gets the provider hint. Release builds always send it, so the sheet goes straight to
    /// Google or GitHub. Debug builds launched with `SPOONJOY_UI_TEST_BROWSER_SIGN_IN_LOGIN_PAGE=1` leave it out, so the
    /// server shows spoonjoy.app/login in the same ASWebAuthenticationSession: BrowserSignInCallbackUITests signs a
    /// throwaway account in there with a password and proves the https callback comes back to the app.
    static func sendsProviderHint(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
#if DEBUG
        return !NativeBrowserOAuthSignIn.loginPageRequested(environment: environment)
#else
        return true
#endif
    }

    @MainActor
    private func handleBrowserOAuthFinish(_ finish: NativeBrowserOAuthFinish, provider: OAuthProviderHint?) async {
        pendingOAuthProvider = nil
        browserSignInPending = false
        switch finish {
        case .signedIn:
            canDisconnect = true
            statusTone = .success
            authStatus = await Self.signedInStatus(appleConnected: authRepository.takeAppleConnectedConfirmation())
            await onSignedIn()
        case .failed:
            statusTone = .error
            authStatus = "Could not finish browser sign-in. Try again."
        case .canceled(let error):
            // NativeBrowserOAuthSignIn logs the cancel's domain, code and timing.
            let ended = NativeBrowserOAuthEarlyCancel.endedStatus(error: error, providerName: signInName(provider))
            statusTone = ended.isProblem ? .error : .neutral
            authStatus = ended.text
            if ended.isProblem {
                // The sheet never opened (spoonjoy-apple#344), so nothing on screen changed for VoiceOver to notice.
                AccessibilityNotification.Announcement(ended.text).post()
            }
        case .superseded:
            statusTone = .neutral
            authStatus = "Browser sign-in continued in another window."
        }
        isSigningIn = false
    }

    /// Cancel while browser sign-in waits to retry: the pending retry never starts, and the sign-in ends as canceled.
    @MainActor
    private func cancelBrowserSignInRetry() {
        guard browserSignInRetryPending else { return }
        browserSignInRetryPending = false
        browserSignIn?.cancel()
    }

    private func focusField(_ field: SignInField) {
        guard !isSigningIn else { return }
        focusedField = field
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
            authStatus = await Self.signedInStatus(appleConnected: authRepository.takeAppleConnectedConfirmation())
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
            // Apple vouched for this Apple ID but sent no email, and no account has it yet. That is a next step,
            // not a failure: the next sign-in with Google, GitHub or a password connects Apple to that account.
            if let message = PendingAppleLink.userMessage(for: error) {
                await appleSignInTelemetry.recordPhase("sign_in_needs_account",
                    outcome: .completed
                )
                statusTone = .warning
                authStatus = message
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

    /// The status after a sign-in by another method. When that sign-in also connected an Apple ID that had found no
    /// account, it says so, so the chef knows Sign in with Apple works from now on.
    private static func signedInStatus(appleConnected: Bool) -> String {
        appleConnected ? "Signed in, and Apple is connected. Restoring Spoonjoy." : "Signed in. Restoring Spoonjoy."
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

    static func currentAppleSignInCapability() -> AppleSignInCapability {
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
        NativeAppleSignInNonce.random(length: length)
    }

    private static func sha256(_ input: String) -> String {
        NativeAppleSignInNonce.sha256(input)
    }

    @discardableResult
    private func revokeAndLogout() async -> Bool {
        do {
            try await authRepository.revokeAndLogout()
            authStatus = "Signed out."
            statusTone = .neutral
            canDisconnect = false
            isSigningIn = false
            return true
        } catch {
            statusTone = .error
            authStatus = "Could not disconnect this device. Check your connection and try again."
            return false
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
        case .everyoneRecipes:
            "Opening Everyone's Recipes after sign-in"
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

enum AppleSignInCapability: Equatable {
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

/// Sign-in fields sit on glass capsules, like every other field in 1.1. The text field is narrower than its
/// capsule, so a tap anywhere on the capsule focuses it.
private struct SignInFieldStyle: ViewModifier {
    let focus: () -> Void

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .contentShape(Capsule(style: .continuous))
            .onTapGesture(perform: focus)
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
    }
}

struct SpoonjoyIdentityMark: View {
    var body: some View {
        // The mark is drawn in ink so it reads on the night page as well as on bone.
        Image("SpoonjoyMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(KitchenTableTheme.ink)
    }
}
