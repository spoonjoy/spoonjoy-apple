import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    private static let oauthCallbackRoute = "https://spoonjoy.app/oauth/callback"
    private static let liveOAuthTransportIdentifier = "live OAuth transport"

    let authRepository: NativeAuthSessionRepository
    let pendingRoute: AppRoute
    let openSettings: () -> Void
    let onSignedIn: @MainActor () async -> Void
    let makeWebAuthenticationSession: (@escaping @MainActor (URL) -> Void) -> SpoonjoyWebAuthenticationSession

    @State private var authStatus = "authRequired: sign in to restore your Spoonjoy kitchen."
    @State private var activeWebAuthenticationSession: SpoonjoyWebAuthenticationSession?
    @State private var isSigningIn = false
    @State private var pendingState: OAuthState?
    @State private var pendingCodeVerifier: String?

    init(
        authRepository: NativeAuthSessionRepository,
        pendingRoute: AppRoute = .kitchen,
        openSettings: @escaping () -> Void,
        onSignedIn: @escaping @MainActor () async -> Void = {},
        makeWebAuthenticationSession: @escaping (@escaping @MainActor (URL) -> Void) -> SpoonjoyWebAuthenticationSession = {
            SpoonjoyWebAuthenticationSession(callbackHandler: $0)
        }
    ) {
        self.authRepository = authRepository
        self.pendingRoute = pendingRoute
        self.openSettings = openSettings
        self.onSignedIn = onSignedIn
        self.makeWebAuthenticationSession = makeWebAuthenticationSession
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoonjoy")
                    .font(.largeTitle)
                Text("Sign in to restore your recipes, cookbooks, shopping list, and offline cache.")
                    .foregroundStyle(.secondary)
                Text(authStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if pendingRoute != .kitchen {
                    Label(pendingRouteLabel, systemImage: "arrow.triangle.turn.up.right.circle")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.herb)
                }
            }

            HStack(spacing: 12) {
                if isSigningIn {
                    Button("Opening sign in") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                } else {
                    Button("Sign in") {
                        Task {
                            await startSignIn()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Settings", action: openSettings)
                    .buttonStyle(.bordered)

                Button("Disconnect") {
                    Task {
                        await revokeAndLogout()
                    }
                }
                .buttonStyle(.bordered)

                Link("spoonjoy.app", destination: SecureAuthWebHandoff.login.url)
            }
            .accessibilityIdentifier(Self.liveOAuthTransportIdentifier)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(KitchenTableTheme.bone)
        .task {
            await restoreState()
        }
    }

    private func restoreState() async {
        do {
            switch try await authRepository.restoreState() {
            case .signedOut:
                authStatus = "authRequired: choose Sign in to connect spoonjoy.app."
            case .authenticated:
                authStatus = "Signed in. Restoring your Spoonjoy cache."
            case .refreshRequired:
                authStatus = "Session refresh required. Sign in again if restore does not complete."
            }
        } catch {
            authStatus = "Could not restore auth state: \(error)"
        }
    }

    private func startSignIn() async {
        do {
            guard NativeAuthSession.redirectURI.absoluteString == Self.oauthCallbackRoute else {
                authStatus = "Could not start sign-in: unexpected OAuth callback route."
                return
            }
            guard let state = OAuthState(rawValue: UUID().uuidString) else {
                authStatus = "Could not start sign-in: invalid OAuth state."
                return
            }
            let verifier = OAuthPKCE.randomVerifier()
            let codeChallenge = try OAuthPKCE.codeChallenge(for: verifier)
            pendingState = state
            pendingCodeVerifier = verifier
            isSigningIn = true
            let start = try await authRepository.startSignIn(state: state, codeChallenge: codeChallenge)
            let session = makeWebAuthenticationSession { callbackURL in
                Task {
                    await handleCallback(callbackURL)
                }
            }
            activeWebAuthenticationSession = session
            authStatus = try session.start(authorizationURL: start.authorizationURL, oauthState: state)
                ? "Waiting for spoonjoy.app sign-in."
                : "Could not open spoonjoy.app sign-in."
            if authStatus.hasPrefix("Could not") {
                isSigningIn = false
            }
        } catch {
            isSigningIn = false
            authStatus = "Could not start sign-in: \(error)"
        }
    }

    private func handleCallback(_ callbackURL: URL) async {
        guard let pendingState, let pendingCodeVerifier else {
            authStatus = "Sign-in callback arrived without a pending request."
            return
        }

        do {
            _ = try await authRepository.handleOAuthCallback(
                callbackURL,
                expectedState: pendingState,
                codeVerifier: pendingCodeVerifier
            )
            authStatus = "Signed in. Restoring Spoonjoy."
            activeWebAuthenticationSession = nil
            isSigningIn = false
            await onSignedIn()
        } catch {
            isSigningIn = false
            authStatus = "Could not finish sign-in: \(error)"
        }
    }

    private func revokeAndLogout() async {
        do {
            try await authRepository.revokeAndLogout()
            authStatus = "Signed out."
            isSigningIn = false
        } catch {
            authStatus = "Could not disconnect: \(error)"
        }
    }

    private var pendingRouteLabel: String {
        switch pendingRoute {
        case .kitchen:
            "Opening Kitchen"
        case .recipes:
            "Opening Recipes after sign-in"
        case .recipeDetail(_, .detail):
            "Opening Recipe after sign-in"
        case .recipeDetail(_, .cook):
            "Opening Cook Mode after sign-in"
        case .recipeEditor(.some):
            "Opening Recipe after sign-in"
        case .recipeEditor(nil):
            "Opening Capture after sign-in"
        case .cookbooks:
            "Opening Cookbooks after sign-in"
        case .cookbookDetail:
            "Opening Cookbook after sign-in"
        case .shoppingList:
            "Opening Shopping after sign-in"
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
}
