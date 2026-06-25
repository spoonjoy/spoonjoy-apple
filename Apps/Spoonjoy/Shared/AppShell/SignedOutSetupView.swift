import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    let openKitchen: () -> Void
    let openCapture: () -> Void
    let openSettings: () -> Void
    @State private var authStatus = "Native sign-in uses https://spoonjoy.app/oauth/callback"
    @State private var webAuthenticationSession: SpoonjoyWebAuthenticationSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoonjoy")
                    .font(.largeTitle)
                Text("Open your kitchen, keep offline fixtures nearby, and connect spoonjoy.app when sign-in is ready.")
                    .foregroundStyle(.secondary)
                Text(authStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Open Kitchen", action: openKitchen)
                    .buttonStyle(.borderedProminent)
                Button("Capture Draft", action: openCapture)
                    .buttonStyle(.bordered)
                Button("Settings", action: openSettings)
                    .buttonStyle(.bordered)
                Button("Connect") {
                    Task { await startSignIn() }
                }
                .buttonStyle(.bordered)
                Link("spoonjoy.app", destination: URL(string: "https://spoonjoy.app") ?? URL(fileURLWithPath: "/"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    @MainActor
    private func startSignIn() async {
        do {
            let vault = KeychainTokenVault()
            let repository = NativeAuthSessionRepository(
                vault: vault,
                clientName: "Spoonjoy Apple",
                redirectURI: NativeAuthSession.redirectURI,
                scope: NativeAuthSession.defaultScope,
                registerClient: { _, _ in "cm_native_spoonjoy" },
                exchangeCode: { _, _, _, _ in throw NativeSignInTransportPendingError.notConnected },
                refresh: { _, _ in throw NativeSignInTransportPendingError.notConnected },
                revoke: { _, _ in }
            )
            let state = try requireOAuthState(UUID().uuidString)
            let codeVerifier = "native-code-verifier-pending-transport-1234567890abcdef"
            let codeChallenge = try OAuthPKCE.codeChallenge(for: codeVerifier)
            let start = try await repository.startSignIn(
                state: state,
                codeChallenge: codeChallenge
            )
            let session = SpoonjoyWebAuthenticationSession { callbackURL in
                Task {
                    _ = try? await repository.handleOAuthCallback(
                        callbackURL,
                        expectedState: state,
                        codeVerifier: codeVerifier
                    )
                    _ = try? await repository.restoreState()
                }
            }
            webAuthenticationSession = session
            _ = try session.start(authorizationURL: start.authorizationURL, oauthState: state)
            authStatus = "Opening spoonjoy.app sign-in"
        } catch {
            authStatus = "Native sign-in is not connected yet"
        }
    }
}

private enum NativeSignInTransportPendingError: Error {
    case notConnected
}

private func requireOAuthState(_ rawValue: String) throws -> OAuthState {
    guard let state = OAuthState(rawValue: rawValue) else {
        throw NativeSignInTransportPendingError.notConnected
    }

    return state
}
