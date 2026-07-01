import AuthenticationServices
import CryptoKit
import Security
import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    private static let liveAppleSignInIdentifier = "native Apple sign-in"

    let authRepository: NativeAuthSessionRepository
    let pendingRoute: AppRoute
    let openSettings: () -> Void
    let onSignedIn: @MainActor () async -> Void

    @State private var authStatus = "authRequired: sign in to restore your Spoonjoy kitchen."
    @State private var isSigningIn = false
    @State private var canDisconnect = false
    @State private var currentNonce: String?

    init(
        authRepository: NativeAuthSessionRepository,
        pendingRoute: AppRoute = .kitchen,
        openSettings: @escaping () -> Void,
        onSignedIn: @escaping @MainActor () async -> Void = {}
    ) {
        self.authRepository = authRepository
        self.pendingRoute = pendingRoute
        self.openSettings = openSettings
        self.onSignedIn = onSignedIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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

            VStack(alignment: .leading, spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = Self.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                    isSigningIn = true
                    authStatus = "Waiting for Apple sign-in."
                } onCompletion: { result in
                    Task {
                        await handleAppleAuthorization(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: 360, minHeight: 50, maxHeight: 50)
                .disabled(isSigningIn)

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
                .controlSize(.large)
            }
            .accessibilityIdentifier(Self.liveAppleSignInIdentifier)
        }
        .frame(maxWidth: 520, maxHeight: .infinity, alignment: .topLeading)
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
                canDisconnect = false
                authStatus = "authRequired: sign in with Apple to connect Spoonjoy."
            case .authenticated:
                canDisconnect = true
                authStatus = "Signed in. Restoring your Spoonjoy cache."
            case .refreshRequired:
                canDisconnect = true
                authStatus = "Session refresh required. Sign in again if restore does not complete."
            }
        } catch {
            authStatus = "Could not restore auth state: \(error)"
        }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        defer { isSigningIn = false }
        do {
            let authorization = try result.get()
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authStatus = "Could not finish sign-in: Apple returned an unsupported credential."
                return
            }
            guard let nonce = currentNonce else {
                authStatus = "Could not finish sign-in: Apple sign-in nonce was missing."
                return
            }
            guard let identityToken = appleIDCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                authStatus = "Could not finish sign-in: Apple identity token was missing."
                return
            }
            let fullName = appleIDCredential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            let credential = NativeAppleSignInCredential(
                identityToken: identityToken,
                rawNonce: nonce,
                email: appleIDCredential.email,
                fullName: fullName?.isEmpty == true ? nil : fullName
            )
            _ = try await authRepository.handleAppleSignInCredential(credential)
            currentNonce = nil
            canDisconnect = true
            authStatus = "Signed in. Restoring Spoonjoy."
            await onSignedIn()
        } catch {
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                authStatus = "Apple sign-in canceled."
                return
            }
            authStatus = "Could not finish sign-in: \(error)"
        }
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
            canDisconnect = false
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
