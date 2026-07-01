import AuthenticationServices
import CryptoKit
import Security
import SpoonjoyCore
import SwiftUI

struct SignedOutSetupView: View {
    private static let liveAppleSignInIdentifier = "native Apple sign-in"
    private static let appleSignInEntitlement = "com.apple.developer.applesignin"

    let authRepository: NativeAuthSessionRepository
    let pendingRoute: AppRoute
    let openSettings: () -> Void
    let onSignedIn: @MainActor () async -> Void

    @State private var authStatus = "Sign in to restore Spoonjoy on this device."
    @State private var isSigningIn = false
    @State private var canDisconnect = false
    @State private var currentNonce: String?
    @State private var appleSignInCapability = Self.currentAppleSignInCapability()

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
        signedOutLayout
        .background(KitchenTableTheme.bone)
        .task {
            appleSignInCapability = Self.currentAppleSignInCapability()
            await restoreState()
        }
    }

    @ViewBuilder private var signedOutLayout: some View {
#if os(macOS)
        VStack(spacing: 30) {
            identityHeader
            signInPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
#else
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: geometry.size.height < 620 ? 12 : 44)
                    identityHeader
                    signInPanel
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
#endif
    }

    private var identityHeader: some View {
        VStack(spacing: 14) {
            SpoonjoyIdentityMark()
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("Spoonjoy")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)
                    .multilineTextAlignment(.center)

                Text("Your recipes, cookbooks, shopping list, and offline kitchen.")
                    .font(.body)
                    .foregroundStyle(KitchenTableTheme.charcoal.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signInPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.charcoal)

                Text("Use your Apple account to connect this native app to Spoonjoy.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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

            SignInWithAppleButton(.signIn) { request in
                guard appleSignInCapability == .available else {
                    authStatus = appleSignInCapability.message
                    return
                }
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
            .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
            .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
            .disabled(isSigningIn || appleSignInCapability != .available)
            .accessibilityIdentifier(Self.liveAppleSignInIdentifier)

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
        .padding(22)
        .frame(maxWidth: 430, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous)
                .stroke(KitchenTableTheme.charcoal.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: KitchenTableTheme.charcoal.opacity(0.08), radius: 24, x: 0, y: 12)
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
        .accessibilityIdentifier("native Apple sign-in status")
    }

    private var statusColor: Color {
        if appleSignInCapability != .available {
            return KitchenTableTheme.brass
        }
        if authStatus.hasPrefix("Could not") {
            return KitchenTableTheme.tomato
        }
        return KitchenTableTheme.charcoal.opacity(0.72)
    }

    private var statusSymbol: String {
        if appleSignInCapability != .available {
            return "signature"
        }
        if authStatus.hasPrefix("Could not") {
            return "exclamationmark.triangle"
        }
        if isSigningIn {
            return "person.badge.clock"
        }
        return "lock.shield"
    }

    private func restoreState() async {
        do {
            switch try await authRepository.restoreState() {
            case .signedOut:
                canDisconnect = false
                authStatus = appleSignInCapability.message
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
            authStatus = Self.signInFailureMessage(for: error)
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
        return .missingEntitlement
#else
        return .available
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

private struct SpoonjoyIdentityMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.93))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                }
                .shadow(color: KitchenTableTheme.charcoal.opacity(0.12), radius: 16, x: 0, y: 8)

            SpoonjoyLogoPath()
                .fill(.black)
                .padding(17)
        }
    }
}

private struct SpoonjoyLogoPath: Shape {
    func path(in rect: CGRect) -> Path {
        let baseWidth: CGFloat = 500
        let baseHeight: CGFloat = 300
        let scale = min(rect.width / baseWidth, rect.height / baseHeight)
        let xOffset = rect.midX - (baseWidth * scale / 2)
        let yOffset = rect.midY - (baseHeight * scale / 2)

        var path = Path()
        path.move(to: CGPoint(x: 300, y: 100))
        path.addLine(to: CGPoint(x: 237.865, y: 100))
        path.addCurve(
            to: CGPoint(x: 215.347, y: 104.007),
            control1: CGPoint(x: 224.941, y: 100.042),
            control2: CGPoint(x: 220.163, y: 101.431)
        )
        path.addCurve(
            to: CGPoint(x: 204.007, y: 115.347),
            control1: CGPoint(x: 210.458, y: 106.622),
            control2: CGPoint(x: 206.622, y: 110.458)
        )
        path.addCurve(
            to: CGPoint(x: 200, y: 138.458),
            control1: CGPoint(x: 201.392, y: 120.237),
            control2: CGPoint(x: 200, y: 125.085)
        )
        path.addLine(to: CGPoint(x: 200, y: 200))
        path.addLine(to: CGPoint(x: 261.542, y: 200))
        path.addCurve(
            to: CGPoint(x: 284.652, y: 195.993),
            control1: CGPoint(x: 274.915, y: 200),
            control2: CGPoint(x: 279.764, y: 198.608)
        )
        path.addCurve(
            to: CGPoint(x: 295.993, y: 184.653),
            control1: CGPoint(x: 289.542, y: 193.378),
            control2: CGPoint(x: 293.378, y: 189.542)
        )
        path.addCurve(
            to: CGPoint(x: 300, y: 161.542),
            control1: CGPoint(x: 298.608, y: 179.763),
            control2: CGPoint(x: 300, y: 174.915)
        )
        path.addLine(to: CGPoint(x: 300, y: 100))
        path.closeSubpath()

        path.move(to: CGPoint(x: 400, y: 184.625))
        path.addCurve(
            to: CGPoint(x: 387.979, y: 253.958),
            control1: CGPoint(x: 400, y: 224.744),
            control2: CGPoint(x: 395.823, y: 239.291)
        )
        path.addCurve(
            to: CGPoint(x: 353.959, y: 287.979),
            control1: CGPoint(x: 380.135, y: 268.625),
            control2: CGPoint(x: 368.625, y: 280.135)
        )
        path.addCurve(
            to: CGPoint(x: 284.624, y: 300),
            control1: CGPoint(x: 339.29, y: 295.823),
            control2: CGPoint(x: 324.743, y: 300)
        )
        path.addLine(to: CGPoint(x: 38.458, y: 300))
        path.addCurve(
            to: CGPoint(x: 15.348, y: 295.993),
            control1: CGPoint(x: 25.085, y: 300),
            control2: CGPoint(x: 20.236, y: 298.608)
        )
        path.addCurve(
            to: CGPoint(x: 4.007, y: 284.653),
            control1: CGPoint(x: 10.458, y: 293.378),
            control2: CGPoint(x: 6.622, y: 289.542)
        )
        path.addCurve(
            to: CGPoint(x: 0.001, y: 262.135),
            control1: CGPoint(x: 1.431, y: 279.837),
            control2: CGPoint(x: 0.042, y: 275.059)
        )
        path.addLine(to: CGPoint(x: 0, y: 200))
        path.addLine(to: CGPoint(x: 100, y: 200))
        path.addLine(to: CGPoint(x: 100, y: 115.375))
        path.addCurve(
            to: CGPoint(x: 112.021, y: 46.042),
            control1: CGPoint(x: 100, y: 75.256),
            control2: CGPoint(x: 104.177, y: 60.709)
        )
        path.addCurve(
            to: CGPoint(x: 146.041, y: 12.021),
            control1: CGPoint(x: 119.865, y: 31.375),
            control2: CGPoint(x: 131.375, y: 19.865)
        )
        path.addCurve(
            to: CGPoint(x: 215.376, y: 0),
            control1: CGPoint(x: 160.71, y: 4.177),
            control2: CGPoint(x: 175.257, y: 0)
        )
        path.addLine(to: CGPoint(x: 461.543, y: 0))
        path.addCurve(
            to: CGPoint(x: 484.653, y: 4.007),
            control1: CGPoint(x: 474.916, y: 0),
            control2: CGPoint(x: 479.765, y: 1.392)
        )
        path.addCurve(
            to: CGPoint(x: 495.994, y: 15.347),
            control1: CGPoint(x: 489.543, y: 6.622),
            control2: CGPoint(x: 493.379, y: 10.458)
        )
        path.addCurve(
            to: CGPoint(x: 500.001, y: 38.458),
            control1: CGPoint(x: 498.609, y: 20.237),
            control2: CGPoint(x: 500.001, y: 25.085)
        )
        path.addLine(to: CGPoint(x: 500.001, y: 100))
        path.addLine(to: CGPoint(x: 400, y: 100))
        path.addLine(to: CGPoint(x: 400, y: 184.625))
        path.closeSubpath()

        return path.applying(CGAffineTransform(translationX: xOffset, y: yOffset).scaledBy(x: scale, y: scale))
    }
}
