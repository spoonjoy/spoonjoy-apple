import AuthenticationServices
import SpoonjoyCore
import SwiftUI

/// The confirmation sheet for Delete account. It says what goes and what stays, asks the person to type their
/// username, and asks them to prove it is them: their password, a fresh Sign in with Apple, or, for an account
/// with neither, a link to delete it on the web. Failures stay in the sheet; none of them signs the person out.
struct AccountDeletionSheet: View {
    static let usernameFieldIdentifier = "settings.deleteAccount.username"
    static let passwordFieldIdentifier = "settings.deleteAccount.password"
    static let confirmButtonIdentifier = "settings.deleteAccount.confirm"
    static let failureIdentifier = "settings.deleteAccount.failure"

    @State private var form: AccountDeletionForm
    @State private var currentNonce: String?
    @State private var isDeleting = false
    @State private var appleStatus: String?

    let isOffline: Bool
    let appleSignInAvailable: Bool
    let webDeletionURL: URL
    let planner: SettingsActionPlanner
    let performSettingsAction: @MainActor @Sendable (SettingsActionPlan) async throws -> SettingsActionOutcome?
    let downloadDataFirst: @MainActor () -> Void
    let onDeleted: @MainActor (AccountDeletionResult) -> Void
    let cancel: @MainActor () -> Void

    @Environment(\.openURL) private var openURL

    init(
        form: AccountDeletionForm,
        isOffline: Bool,
        appleSignInAvailable: Bool,
        webDeletionURL: URL,
        planner: SettingsActionPlanner,
        performSettingsAction: @escaping @MainActor @Sendable (SettingsActionPlan) async throws -> SettingsActionOutcome?,
        downloadDataFirst: @escaping @MainActor () -> Void,
        onDeleted: @escaping @MainActor (AccountDeletionResult) -> Void,
        cancel: @escaping @MainActor () -> Void
    ) {
        _form = State(initialValue: form)
        self.isOffline = isOffline
        self.appleSignInAvailable = appleSignInAvailable
        self.webDeletionURL = webDeletionURL
        self.planner = planner
        self.performSettingsAction = performSettingsAction
        self.downloadDataFirst = downloadDataFirst
        self.onDeleted = onDeleted
        self.cancel = cancel
    }

    var body: some View {
        KitchenTablePage(maxContentWidth: 560, bottomReserve: 32) {
            HStack {
                Spacer()
                Button("Cancel") {
                    cancel()
                }
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.charcoal)
                .disabled(isDeleting)
            }

            KitchenTableHeader(
                eyebrow: "Account",
                title: "Delete your account?",
                subtitle: "This can't be undone."
            )

            consequences

            if case .web(let url) = form.reauthentication {
                webOnly(url: url)
            } else {
                confirmation
            }
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private var consequences: some View {
        SettingsPanel {
            sheetFact(
                title: "Deleted for good",
                body: "Your account, your recipes, cookbooks, shopping list, cooks and photos, and every app and agent you connected."
            )
            sheetFact(
                title: "Stays up",
                body: "Recipes other cooks forked, saved or cooked stay on Spoonjoy, credited to \u{201C}\(ChefDisplayName.deletedChef)\u{201D}. Forks other cooks made of your recipes stay theirs."
            )
            Button {
                downloadDataFirst()
            } label: {
                Label("Download my data first", systemImage: "square.and.arrow.down")
                    .font(KitchenTableTheme.bodyNote.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(KitchenTableTheme.herb)
            .disabled(isOffline || isDeleting)
        }
    }

    private var confirmation: some View {
        SettingsPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text("Type your username, \(form.username), to confirm")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.brass)
                sheetField {
                    TextField("Username", text: $form.typedUsername, prompt: Self.placeholder("Username"))
                        .accountDeletionPlainEntry()
                        .accessibilityIdentifier(Self.usernameFieldIdentifier)
                }
            }

            switch form.reauthentication {
            case .password:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current password")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.brass)
                    sheetField {
                        SecureField("Password", text: $form.password, prompt: Self.placeholder("Password"))
                            .textContentType(.password)
                            .accessibilityIdentifier(Self.passwordFieldIdentifier)
                    }
                }
            case .signInWithApple:
                appleConfirmation
            case .web:
                EmptyView()
            }

            if let failure = form.failure {
                Label(failure.message, systemImage: "exclamationmark.triangle")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.tomato)
                    .accessibilityIdentifier(Self.failureIdentifier)
            } else if isOffline {
                Label(SettingsOnlineOnlyReason.accountDeletion.message, systemImage: "wifi.slash")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
            }

            Button(role: .destructive) {
                deleteAccount()
            } label: {
                if isDeleting {
                    ProgressView()
                        .tint(KitchenTableTheme.paper)
                } else {
                    Text("Delete account")
                }
            }
            .buttonStyle(KitchenTableActionButtonStyle(prominence: .destructive))
            .disabled(form.action == nil || isOffline || isDeleting)
            .opacity(form.action == nil || isOffline ? 0.45 : 1)
            .accessibilityIdentifier(Self.confirmButtonIdentifier)
        }
    }

    @ViewBuilder private var appleConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in with Apple to confirm it's you")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
            if form.appleCredential != nil {
                Label("Apple ID confirmed", systemImage: "checkmark.seal")
                    .font(KitchenTableTheme.bodyNote.weight(.semibold))
                    .foregroundStyle(KitchenTableTheme.herb)
            } else if appleSignInAvailable {
                SignInWithAppleButton(.continue) { request in
                    let nonce = NativeAppleSignInNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = []
                    request.nonce = NativeAppleSignInNonce.sha256(nonce)
                    appleStatus = nil
                } onCompletion: { result in
                    handleAppleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                .clipShape(RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel, style: .continuous))
                .disabled(isOffline || isDeleting)
            } else {
                Text("Sign in with Apple needs a signed Spoonjoy build. Delete your account on the web instead.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
                webLink(url: webDeletionURL)
            }
            if let appleStatus {
                Text(appleStatus)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
        }
    }

    private func webOnly(url: URL) -> some View {
        SettingsPanel {
            Text("Your account signs in with Google or GitHub, so the app can't confirm it's you. Delete it in Account settings on the web.")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)
            webLink(url: url)
        }
    }

    private func webLink(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            Label("Delete on \(url.host() ?? "the web")", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(KitchenTableActionButtonStyle(prominence: .secondary))
    }

    private func sheetFact(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
            Text(body)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The palette is fixed-light, so placeholders get an explicit muted ink instead of the system color that fades in dark mode.
    private static func placeholder(_ text: String) -> Text {
        Text(text).foregroundStyle(KitchenTableTheme.inkMuted)
    }

    private func sheetField<Field: View>(@ViewBuilder _ field: () -> Field) -> some View {
        field()
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(KitchenTableTheme.bone.opacity(0.45), in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                    .strokeBorder(KitchenTableTheme.line.opacity(0.55), lineWidth: 1)
            }
    }

    private func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        defer { currentNonce = nil }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let nonce = currentNonce else {
                appleStatus = "Apple didn't finish confirming it's you. Try again."
                return
            }
            form.clearFailure()
            form.appleCredential = NativeAppleSignInCredential(identityToken: identityToken, rawNonce: nonce)
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
                return
            }
            appleStatus = "Apple didn't finish confirming it's you. Try again."
        }
    }

    private func deleteAccount() {
        guard let action = form.action else {
            return
        }
        isDeleting = true
        form.clearFailure()
        Task { @MainActor in
            defer { isDeleting = false }
            do {
                let plan = try planner.plan(action)
                if plan.onlineOnlyReason != nil {
                    form.record(.offline)
                    return
                }
                if case .deletedAccount(let result)? = try await performSettingsAction(plan) {
                    onDeleted(result)
                }
            } catch {
                form.record(AccountDeletionFailure(error: error))
            }
        }
    }
}

private extension View {
    @ViewBuilder func accountDeletionPlainEntry() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)
#else
        self
            .autocorrectionDisabled()
            .textContentType(.username)
#endif
    }
}
