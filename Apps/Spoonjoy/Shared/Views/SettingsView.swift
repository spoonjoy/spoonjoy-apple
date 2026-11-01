import SpoonjoyCore
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum ScreenshotSettingsFocus: String {
        case profile
        case notifications
        case signedOut = "signed-out"
        case yourData = "your-data"
        case deleteAccount = "delete-account"
        case deleteAccountError = "delete-account-error"
        case exportReady = "export-ready"
    }

    private static let screenshotFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"
    private static let notificationsFocusID = "settings-section-notification-apns-device"
    private static let yourDataFocusID = "settings-section-your-data"

    let viewModel: SettingsViewModel
    var settingsSurfaceViewModel: SettingsSurfaceViewModel?
    var notificationAPNsSurfaceViewModel: NotificationAPNsSurfaceViewModel?
    var performSettingsAction: @MainActor @Sendable (SettingsActionPlan) async throws -> SettingsActionOutcome? = { _ in nil }
    var performNotificationAPNsAction: @MainActor @Sendable (NotificationAPNsActionPlan) async throws -> Void = { _ in }
    var requestNotificationPermission: @MainActor @Sendable () async throws -> APNsPermissionState = { throw NotificationAPNsNativeBridgeError.unavailable }
    var requestDeviceRegistrationAction: @MainActor @Sendable (String) async throws -> NotificationAPNsAction = { _ in throw NotificationAPNsNativeBridgeError.unavailable }
    var openNotificationSettings: @MainActor @Sendable () -> Void = {}
    var notificationAPNsSettingsContent: (@MainActor @Sendable (NotificationAPNsSurfaceViewModel) -> AnyView)?
    var shellOfflineIndicatorState: OfflineIndicatorState?
    var syncFailureDiagnosticText: String?
    var onRetrySync: @MainActor @Sendable () async -> Void = {}
    var onDismissOfflineIndicator: @MainActor @Sendable () -> Void = {}

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var selectedProfilePhotoItem: PhotosPickerItem?
    @State private var stagedProfilePhoto: NativeStagedMediaUpload?
    @State private var profileUsername = ""
    @State private var profileDraftID: String?
    @State private var notifySpoonOnMyRecipe = false
    @State private var notifyForkOfMyRecipe = false
    @State private var notifyCookbookSaveOfMine = false
    @State private var notifyFellowChefOriginCook = false
    @State private var notificationDraftID: String?
    @State private var settingsActionMessage: String?
    @State private var settingsActionError: String?
    @State private var createdCredentialValue: String?
    @State private var createdCredentialPrefix: String?
    @State private var tokenName = "Spoonjoy Agent Access"
    @State private var tokenCanReadRecipes = true
    @State private var tokenCanWriteRecipes = false
    @State private var tokenCanReadShoppingList = false
    @State private var tokenCanWriteShoppingList = false
    @State private var pendingDestructiveAction: PendingSettingsDestructiveAction?
    @State private var screenshotSettingsFocus = SettingsView.screenshotSettingsFocus()
    @State private var accountDeletionForm: AccountDeletionForm?
    @State private var isExportingAccountData = false
    @State private var accountExportURL: URL?
    @State private var isBlockedChefsPresented = false
    @State private var isConnectionsExpanded = false
    @State private var allowsThirdPartyAI = ThirdPartyAIConsentStore().consent == .granted

    var body: some View {
        ScrollViewReader { proxy in
            settingsForm
                .task(id: screenshotSettingsFocus) {
                    guard let screenshotSettingsFocus else {
                        return
                    }
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    switch screenshotSettingsFocus {
                    case .profile:
                        Self.writeScreenshotProof(
                            visualFocus: screenshotSettingsFocus,
                            visibleSections: ["Profile", "Security"]
                        )
                        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                            route: "settings",
                            source: "SettingsView",
                            runtimeContext: screenshotAccessibilityRuntimeContext
                        )
                    case .notifications:
                        withAnimation(nil) {
                            proxy.scrollTo(Self.notificationsFocusID, anchor: .top)
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard notificationAPNsSurfaceViewModel != nil else {
                            return
                        }
                        Self.writeScreenshotProof(
                            visualFocus: screenshotSettingsFocus,
                            visibleSections: ["This Device", "Push Delivery", "Notification Sync", "Agent Access"]
                        )
                        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                            route: "settings",
                            source: "SettingsView",
                            runtimeContext: screenshotAccessibilityRuntimeContext
                        )
                    case .signedOut:
                        Self.writeScreenshotProof(
                            visualFocus: screenshotSettingsFocus,
                            visibleSections: ["Session", "Environment", "Offline"]
                        )
                        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                            route: "settings",
                            source: "SettingsView",
                            runtimeContext: screenshotAccessibilityRuntimeContext
                        )
                    case .yourData, .exportReady:
                        if screenshotSettingsFocus == .exportReady, let username = settingsSurfaceViewModel?.data.account?.username {
                            accountExportURL = try? Self.writeAccountExport(Self.screenshotAccountExport(username: username))
                        }
                        withAnimation(nil) {
                            proxy.scrollTo(Self.yourDataFocusID, anchor: .top)
                        }
                        Self.writeScreenshotProof(visualFocus: screenshotSettingsFocus, visibleSections: ["Your data"])
                    case .deleteAccount, .deleteAccountError:
                        guard var form = accountDeletionFormForCurrentAccount() else {
                            return
                        }
                        if screenshotSettingsFocus == .deleteAccountError {
                            form.typedUsername = form.username
                            form.password = "not-the-password"
                            form.record(.passwordIncorrect)
                        }
                        accountDeletionForm = form
                        Self.writeScreenshotProof(visualFocus: screenshotSettingsFocus, visibleSections: ["Delete your account?"])
                    }
                }
        }
        .confirmationDialog(
            pendingDestructiveAction?.title ?? "Confirm account action",
            isPresented: Binding(
                get: { pendingDestructiveAction != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDestructiveAction = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDestructiveAction {
                Button(pendingDestructiveAction.confirmButtonTitle, role: .destructive) {
                    let pending = pendingDestructiveAction
                    self.pendingDestructiveAction = nil
                    guard let planner = settingsSurfaceViewModel?.actionPlanner else {
                        settingsActionError = "Settings are no longer available."
                        return
                    }
                    planSettingsAction(pending.action, using: planner)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDestructiveAction = nil
            }
        } message: {
            if let message = pendingDestructiveAction?.message {
                Text(message)
            }
        }
        .sheet(item: $accountDeletionForm.identified) { identified in
            if let surface = settingsSurfaceViewModel {
                AccountDeletionSheet(
                    form: identified.form,
                    isOffline: onlineOnlyActionsDisabled(surface),
                    appleSignInAvailable: appleSignInAvailableForAccountDeletion,
                    webDeletionURL: surface.accountDeletionWebHandoff.url,
                    planner: surface.actionPlanner,
                    performSettingsAction: performSettingsAction,
                    downloadDataFirst: {
                        accountDeletionForm = nil
                        downloadAccountData(using: surface)
                    },
                    onDeleted: { _ in
                        accountDeletionForm = nil
                        settingsActionError = nil
                        settingsActionMessage = "Your account was deleted."
                    },
                    cancel: {
                        accountDeletionForm = nil
                    }
                )
            }
        }
    }

    private var appleSignInAvailableForAccountDeletion: Bool {
#if DEBUG
        if screenshotSettingsFocus == .deleteAccount {
            return true
        }
#endif
        return SignedOutSetupView.currentAppleSignInCapability() == .available
    }

    private func accountDeletionFormForCurrentAccount() -> AccountDeletionForm? {
        guard let surface = settingsSurfaceViewModel,
              let username = surface.data.account?.username,
              let reauthentication = surface.accountDeletionReauthentication else {
            return nil
        }
        return AccountDeletionForm(username: username, reauthentication: reauthentication)
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var settingsForm: some View {
        KitchenTablePage {
            KitchenTableHeader(title: "Settings", subtitle: nil)
            if let settingsSurfaceViewModel {
                nativeSettings(surface: settingsSurfaceViewModel)
            } else {
                legacySettings
            }
        }
        .tint(KitchenTableTheme.herb)
    }

    @ViewBuilder private func nativeSettings(surface: SettingsSurfaceViewModel) -> some View {
        if let profile = surface.profileDraft {
            KitchenTableSection(title: "Account") {
                SettingsPanel {
                    VStack(alignment: .leading, spacing: 4) {
                        settingsFact("Email", value: profile.email, valueIdentifier: "settings.profile.email")
                        Button {
                            openSecureHandoff(surface.accountSettingsHandoff)
                        } label: {
                            Label(surface.emailChangeNote, systemImage: "arrow.up.right.square")
                                .font(KitchenTableTheme.uiLabel)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(KitchenTableTheme.herb)
                        .accessibilityIdentifier("settings.profile.changeEmail")
                    }

                    // Password and passkeys are managed on the website, where they work today; one row opens it.
                    Button {
                        planSettingsAction(.managePassword, using: surface.actionPlanner)
                    } label: {
                        settingsRowLabel("Password and Passkeys", systemImage: "key", prominence: .secondary, opensElsewhere: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))

                    // Linking Google runs in an in-app secure sign-in sheet, so the row doesn't mark itself as leaving.
                    ForEach(surface.securityRows.filter { $0.id == .providerLinks }, id: \.id) { row in
                        Button {
                            planSettingsAction(row.action, using: surface.actionPlanner)
                        } label: {
                            settingsRowLabel(row.title, systemImage: "link", prominence: .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(onlineOnlyActionsDisabled(surface))
                        .accessibilityIdentifier("settings.providerLinks")
                    }

                    Button(role: .destructive) {
                        confirmSettingsAction(
                            .logout,
                            title: "Sign out?",
                            message: "Spoonjoy will revoke the local session and send you through the secure sign-out flow.",
                            confirmButtonTitle: "Sign Out"
                        )
                    } label: {
                        settingsRowLabel("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", prominence: .destructive)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))
                    .accessibilityIdentifier("settings.signout")
                }
            }

            KitchenTableSection(title: "Profile") {
                SettingsPanel {
                    settingsTextField("Username", text: $profileUsername)

                    Button {
                        planSettingsAction(
                            profile.updateUsernameAction(
                                username: profileUsername,
                                clientMutationID: "cm_settings_profile_\(UUID().uuidString)"
                            ),
                            using: surface.actionPlanner
                        )
                    } label: {
                        settingsRowLabel("Save Profile", systemImage: "checkmark.circle", prominence: .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(profileSaveDisabled(comparedWith: profile))

                    PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                        settingsRowLabel("Upload Photo", systemImage: "photo.badge.plus", prominence: .secondary)
                    }
                    .onChange(of: selectedProfilePhotoItem) { _, item in
                        guard let item else { return }
                        Task { @MainActor in
                            await stageProfilePhoto(item, using: surface.actionPlanner)
                        }
                    }

                    Button(role: .destructive) {
                        confirmSettingsAction(
                            .removeProfilePhoto(clientMutationID: "cm_settings_remove_photo_\(UUID().uuidString)"),
                            title: "Remove profile photo?",
                            message: "Your profile photo will be removed. If you are offline, this change will wait to sync.",
                            confirmButtonTitle: "Remove Photo"
                        )
                    } label: {
                        settingsRowLabel("Remove Photo", systemImage: "trash", prominence: .destructive)
                    }
                    .buttonStyle(.plain)
                }
            }
            .task(id: profileIdentity(profile)) {
                hydrateProfileDraft(profile)
            }

            if let notificationAPNsSurfaceViewModel {
                if let notificationAPNsSettingsContent {
                    notificationAPNsSettingsContent(notificationAPNsSurfaceViewModel)
                } else {
                    NotificationAPNsSettingsView(
                        viewModel: notificationAPNsSurfaceViewModel,
                        performNotificationAPNsAction: performNotificationAPNsAction,
                        requestNotificationPermission: requestNotificationPermission,
                        requestDeviceRegistrationAction: requestDeviceRegistrationAction,
                        openNotificationSettings: openNotificationSettings,
                        onDismissOfflineIndicator: onDismissOfflineIndicator
                    )
                }
            } else if let notifications = surface.notificationDraft {
                KitchenTableSection(title: "Notifications") {
                    SettingsPanel {
                        Toggle("Spoons", isOn: $notifySpoonOnMyRecipe)
                        Toggle("Forks", isOn: $notifyForkOfMyRecipe)
                        Toggle("Cookbook saves", isOn: $notifyCookbookSaveOfMine)
                        Toggle("Fellow-chef cooks", isOn: $notifyFellowChefOriginCook)

                        if !notificationSaveDisabled(comparedWith: notifications) {
                            Button {
                                planSettingsAction(
                                    .updateNotificationPreferences(
                                        SettingsNotificationPreferences(
                                            notifySpoonOnMyRecipe: notifySpoonOnMyRecipe,
                                            notifyForkOfMyRecipe: notifyForkOfMyRecipe,
                                            notifyCookbookSaveOfMine: notifyCookbookSaveOfMine,
                                            notifyFellowChefOriginCook: notifyFellowChefOriginCook
                                        ),
                                        clientMutationID: "cm_settings_notifications_\(UUID().uuidString)"
                                    ),
                                    using: surface.actionPlanner
                                )
                            } label: {
                                settingsRowLabel("Save Notifications", systemImage: "bell.badge", prominence: .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .task(id: notificationIdentity(notifications)) {
                    hydrateNotificationDraft(notifications)
                }
                .id(Self.notificationsFocusID)
            }

            if surface.data.tokenManagementAvailability == .available {
                KitchenTableSection(title: "Connected") {
                    SettingsPanel {
                        DisclosureGroup(isExpanded: $isConnectionsExpanded) {
                            connectedAppsContent(surface: surface)
                        } label: {
                            HStack(spacing: 10) {
                                Text("AI assistants and API tokens")
                                    .font(KitchenTableTheme.bodyNote.weight(.semibold))
                                    .foregroundStyle(KitchenTableTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Text("\(surface.apiTokenRows.count + surface.oauthConnectionRows.count)")
                                    .font(KitchenTableTheme.uiLabel.monospacedDigit())
                                    .foregroundStyle(KitchenTableTheme.ink2)
                            }
                            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                        }
                        .accessibilityIdentifier("settings.connected")
                    }
                }
            }
        } else if let primaryAuthAction = surface.primaryAuthAction {
            KitchenTableSection(title: "Session") {
                SettingsPanel {
                    Button {
                        openSecureHandoff(primaryAuthAction)
                    } label: {
                        settingsRowLabel("Sign In", systemImage: "person.crop.circle.badge.checkmark", prominence: .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            KitchenTableSection(title: "Account") {
                SettingsPanel {
                    Text("Account sync has not finished yet.")
                        .font(KitchenTableTheme.objectTitle)
                        .foregroundStyle(KitchenTableTheme.ink)
                    Text("Spoonjoy is signed in, but the latest sync did not finish loading your profile, security, and notification settings.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.ink2)
                    if let syncFailureDiagnosticText {
                        Text(syncFailureDiagnosticText)
                            .font(.caption.monospaced())
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .textSelection(.enabled)
                    }
                    Button {
                        Task { await onRetrySync() }
                    } label: {
                        Label("Try Sync Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(KitchenTableActionButtonStyle(prominence: .primary))
                }
            }
        }

        if surface.data.account != nil {
            safetySection
            yourDataSection(surface: surface)
        }
        aboutSection

#if DEBUG
        // Diagnostics for builds that point at a non-production environment. Journeys read this row
        // to prove they are on the QA mirror. Release builds keep the account screen to settings only.
        KitchenTableSection(title: "Environment") {
            SettingsPanel {
                settingsFact("Environment", value: surface.data.environment.rawValue, valueIdentifier: "settings.environment.value")
                settingsFact("Source", value: sourceLabel(surface.data.source))
            }
        }
#endif

        KitchenTableSection(title: "Offline") {
            SettingsPanel {
                if let summary = surface.queuedWorkSummary {
                    Label(summary, systemImage: "arrow.triangle.2.circlepath")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                if let conflictBanner = surface.conflictBanner {
                    Label(conflictBanner.message, systemImage: "exclamationmark.triangle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.tomato)
                }
                if let settingsActionMessage {
                    Label(settingsActionMessage, systemImage: "checkmark.circle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.herb)
                }
                settingsActionFailureBanner
                if let partialFailureSummary = surface.partialFailureSummary {
                    Label(partialFailureSummary, systemImage: "exclamationmark.triangle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.tomato)
                }
                let offlineDisplay = effectiveOfflineIndicator(surface.offlineIndicator.display)
                OfflineStatusView(display: offlineDisplay) {
                    if offlineDisplay == surface.offlineIndicator.display {
                        _ = viewModel.dismissOfflineIndicator
                    }
                    onDismissOfflineIndicator()
                }
            }
        }
    }

    @ViewBuilder private var legacySettings: some View {
#if DEBUG
        KitchenTableSection(title: "Status", subtitle: "Live session snapshot") {
            SettingsPanel {
                ForEach(settings.statusRows, id: \.id) { row in
                    settingsFact(row.title, value: row.value)
                }
            }
        }
#endif

        KitchenTableSection(title: "Session") {
            SettingsPanel {
                settingsFact("Auth", value: authSummary)
                settingsFact("Environment", value: viewModel.environmentSwitcher.rawValue, valueIdentifier: "settings.environment.value")
            }
        }

        KitchenTableSection(title: "Shopping") {
            SettingsPanel {
                Label(
                    settings.canReadShoppingList ? "Shopping read enabled" : "Shopping read unavailable",
                    systemImage: settings.canReadShoppingList ? "checkmark.circle" : "xmark.circle"
                )
                .foregroundStyle(settings.canReadShoppingList ? KitchenTableTheme.herb : KitchenTableTheme.tomato)
                Label(
                    settings.canWriteShoppingList ? "Shopping write enabled" : "Shopping write unavailable",
                    systemImage: settings.canWriteShoppingList ? "checkmark.circle" : "xmark.circle"
                )
                .foregroundStyle(settings.canWriteShoppingList ? KitchenTableTheme.herb : KitchenTableTheme.tomato)
            }
        }

        KitchenTableSection(title: "Offline") {
            SettingsPanel {
                OfflineStatusView(display: effectiveOfflineIndicator(viewModel.offlineIndicatorDisplay)) {
                    _ = viewModel.dismissOfflineIndicator
                    onDismissOfflineIndicator()
                }
            }
        }
        aboutSection
    }

    /// Access keys and connected apps, one level down under Connected: managed rarely, kept within reach.
    @ViewBuilder private func connectedAppsContent(surface: SettingsSurfaceViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSubheading("Agent access")
            if let createdCredentialValue {
                settingsCreatedCredentialDisclosure(
                    credentialValue: createdCredentialValue,
                    credentialPrefix: createdCredentialPrefix
                )
            }

            ForEach(surface.apiTokenRows) { token in
                VStack(alignment: .leading, spacing: 4) {
                    settingsFact(token.name, value: token.tokenPrefix)
                    Button(role: .destructive) {
                        confirmSettingsAction(
                            .revokeAPIToken(credentialID: token.id),
                            title: "Revoke access key?",
                            message: "Agents and tools using this key will lose access immediately.",
                            confirmButtonTitle: "Revoke access key"
                        )
                    } label: {
                        settingsRowLabel("Revoke access key", systemImage: "trash", prominence: .destructive)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))
                }
            }

            settingsTextField("Access key name", text: $tokenName)
            Toggle("Recipes read", isOn: $tokenCanReadRecipes)
            Toggle("Recipes write", isOn: $tokenCanWriteRecipes)
            Toggle("Shopping read", isOn: $tokenCanReadShoppingList)
            Toggle("Shopping write", isOn: $tokenCanWriteShoppingList)

            Button {
                planSettingsAction(.createAPIToken(name: tokenName, scopes: selectedTokenScopes), using: surface.actionPlanner)
            } label: {
                settingsRowLabel("Create access key", systemImage: "plus.circle", prominence: .primary)
            }
            .buttonStyle(.plain)
            .disabled(tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedTokenScopes.isEmpty || onlineOnlyActionsDisabled(surface))

            settingsSubheading("Connections")
                .padding(.top, 8)
            if surface.oauthConnectionRows.isEmpty {
                Text("No connected apps.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
            ForEach(surface.oauthConnectionRows) { connection in
                VStack(alignment: .leading, spacing: 4) {
                    settingsFact(connection.clientName, value: connection.scopes.joined(separator: ", "))
                    Button(role: .destructive) {
                        confirmSettingsAction(
                            .disconnectOAuthConnection(connectionID: connection.id),
                            title: "Disconnect OAuth app?",
                            message: "\(connection.clientName) will no longer be able to access your Spoonjoy account.",
                            confirmButtonTitle: "Disconnect"
                        )
                    } label: {
                        settingsRowLabel("Disconnect", systemImage: "xmark.circle", prominence: .destructive)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))
                }
            }
        }
        .padding(.top, 8)
    }

    private func settingsSubheading(_ title: String) -> some View {
        Text(title)
            .font(KitchenTableTheme.uiLabel.weight(.semibold))
            .foregroundStyle(KitchenTableTheme.ink2)
            .accessibilityAddTraits(.isHeader)
    }

    /// Blocked chefs (App Review guideline 1.2) and the AI-features consent (guideline 5.1.2(i)).
    private var safetySection: some View {
        KitchenTableSection(title: "Safety & privacy") {
            SettingsPanel {
                Button {
                    isBlockedChefsPresented = true
                } label: {
                    settingsRowLabel("Blocked chefs", systemImage: "hand.raised", prominence: .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.blockedChefs")

                Toggle(isOn: Binding(
                    get: { allowsThirdPartyAI },
                    set: { allowed in
                        allowsThirdPartyAI = allowed
                        ThirdPartyAIConsentStore().record(allowed ? .granted : .declined)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI features")
                            .font(KitchenTableTheme.objectTitle)
                            .foregroundStyle(KitchenTableTheme.ink)
                        Text(ThirdPartyAIUse.settingsSummary)
                            .font(KitchenTableTheme.uiLabel)
                            .foregroundStyle(KitchenTableTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
                .accessibilityIdentifier("settings.aiConsent")
            }
        }
        .sheet(isPresented: $isBlockedChefsPresented) {
            NavigationStack {
                BlockedChefsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isBlockedChefsPresented = false }
                        }
                    }
            }
        }
    }

    /// Privacy policy, terms, support and contact (App Review guideline 5.1.1(i)).
    private var aboutSection: some View {
        KitchenTableSection(title: "About") {
            SettingsPanel {
                ForEach(SettingsAboutLink.allCases) { link in
                    Link(destination: link.url) {
                        settingsRowLabel(link.title, systemImage: link.systemImage, prominence: .secondary, opensElsewhere: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.about.\(link.rawValue)")
                }
            }
        }
    }

    private func yourDataSection(surface: SettingsSurfaceViewModel) -> some View {
        KitchenTableSection(title: "Your data") {
            SettingsPanel {
                Button {
                    downloadAccountData(using: surface)
                } label: {
                    settingsRowLabel(
                        isExportingAccountData ? "Preparing your data…" : "Download my data",
                        systemImage: "square.and.arrow.down",
                        prominence: .secondary
                    )
                }
                .buttonStyle(.plain)
                .disabled(onlineOnlyActionsDisabled(surface) || isExportingAccountData)
                .accessibilityIdentifier("settings.downloadData")

                if let accountExportURL {
                    ShareLink(item: accountExportURL) {
                        settingsRowLabel(
                            "Save or share \(accountExportURL.lastPathComponent)",
                            systemImage: "square.and.arrow.up",
                            prominence: .primary
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.shareDataExport")
                }

                Button(role: .destructive) {
                    accountDeletionForm = accountDeletionFormForCurrentAccount()
                } label: {
                    settingsRowLabel("Delete account…", systemImage: "person.crop.circle.badge.xmark", prominence: .destructive)
                }
                .buttonStyle(.plain)
                .disabled(onlineOnlyActionsDisabled(surface))
                .accessibilityIdentifier("settings.deleteAccount")

                if onlineOnlyActionsDisabled(surface) {
                    Label("Connect to the internet to download your data or delete your account.", systemImage: "wifi.slash")
                        .font(KitchenTableTheme.uiLabel)
                        .foregroundStyle(KitchenTableTheme.ink2)
                }
            }
        }
        .id(Self.yourDataFocusID)
    }

    private func downloadAccountData(using surface: SettingsSurfaceViewModel) {
        guard let username = surface.data.account?.username else {
            return
        }
        isExportingAccountData = true
        accountExportURL = nil
        Task { @MainActor in
            defer { isExportingAccountData = false }
            do {
                let plan = try surface.actionPlanner.plan(.exportAccountData(username: username))
                if let reason = plan.onlineOnlyReason {
                    settingsActionMessage = reason.message
                    return
                }
                settingsActionError = nil
                if case .exportedAccountData(let file)? = try await performSettingsAction(plan) {
                    accountExportURL = try Self.writeAccountExport(file)
                    settingsActionMessage = "Your data is ready to save or share."
                }
            } catch {
                settingsActionError = settingsActionErrorMessage(for: error)
            }
        }
    }

    /// Writes the export where the share sheet can read it, under its own folder so the file keeps the web's name.
    private static func writeAccountExport(_ file: AccountExportFile) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "SpoonjoyAccountExport-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: file.fileName, directoryHint: .notDirectory)
        try file.contents.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private static func screenshotAccountExport(username: String) throws -> AccountExportFile {
        try AccountExportFile(
            username: username,
            exportedAt: Date(),
            export: .object(["format": .string("spoonjoy.account-export.v1"), "account": .object(["username": .string(username)])])
        )
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, prompt: Text(placeholder).foregroundStyle(KitchenTableTheme.ink2))
            .textFieldStyle(.plain)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.ink)
            .frame(minHeight: KitchenTableTheme.minimumTouchTarget)
            .overlay(alignment: .bottom) {
                Rectangle().fill(KitchenTableTheme.hairline).frame(height: 1)
            }
    }

    private func settingsFact(_ title: String, value: String, valueIdentifier: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.ink2)
            Spacer(minLength: 12)
            settingsFactValue(value, identifier: valueIdentifier)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func settingsFactValue(_ value: String, identifier: String?) -> some View {
        let text = Text(value)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.ink)
            .multilineTextAlignment(.trailing)
        if let identifier {
            text.accessibilityIdentifier(identifier)
        } else {
            text
        }
    }

    private func settingsCreatedCredentialDisclosure(
        credentialValue: String,
        credentialPrefix: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New access key")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
            Text(credentialValue)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(KitchenTableTheme.ink)
                .textSelection(.enabled)
            if let credentialPrefix {
                Text(credentialPrefix)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
            }
        }
    }

    @ViewBuilder private var settingsActionFailureBanner: some View {
        if let settingsActionError {
            Label(settingsActionError, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.tomato)
        }
    }

    nonisolated private func settingsRowLabel(
        _ title: String,
        systemImage: String,
        prominence: SettingsRowProminence,
        opensElsewhere: Bool = false
    ) -> some View {
        SettingsRowLabel(title: title, systemImage: systemImage, prominence: prominence, opensElsewhere: opensElsewhere)
    }

    private func effectiveOfflineIndicator(_ localDisplay: OfflineIndicatorDisplay) -> OfflineIndicatorDisplay {
        guard let shellOfflineIndicatorState,
              !shellOfflineIndicatorState.display.informationalOnly,
              localDisplay.informationalOnly else {
            return localDisplay
        }
        return shellOfflineIndicatorState.display
    }

    private func planSettingsAction(_ action: SettingsAction, using planner: SettingsActionPlanner) {
        Task { @MainActor in
            do {
                if case .createAPIToken = action {
                    createdCredentialValue = nil
                    createdCredentialPrefix = nil
                }
                let plan = try planner.plan(action)
                settingsActionMessage = plan.onlineOnlyReason.map(onlineOnlyMessage) ?? plan.userFacingMessage
                settingsActionError = nil
                let outcome = try await performSettingsAction(plan)
                if case .createdAPIToken(let created)? = outcome {
                    createdCredentialValue = created.token
                    createdCredentialPrefix = created.credential.tokenPrefix
                    settingsActionMessage = "Token created. Save it now."
                    tokenName = ""
                    return
                }
                if plan.userFacingMessage == nil, plan.queuedMutation == nil {
                    settingsActionMessage = nil
                } else if plan.queuedMutation != nil {
                    settingsActionMessage = "Account change queued."
                }
            } catch {
                settingsActionError = settingsActionErrorMessage(for: error)
            }
        }
    }

    private func confirmSettingsAction(
        _ action: SettingsAction,
        title: String,
        message: String,
        confirmButtonTitle: String
    ) {
        pendingDestructiveAction = PendingSettingsDestructiveAction(
            action: action,
            title: title,
            message: message,
            confirmButtonTitle: confirmButtonTitle
        )
    }

    @MainActor private func stageProfilePhoto(_ item: PhotosPickerItem, using planner: SettingsActionPlanner) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                settingsActionMessage = "Photo could not be loaded."
                return
            }
            guard let contentType = acceptedProfilePhotoContentType(for: item) else {
                settingsActionMessage = rejectionMessage(
                    .unsupportedContentType(item.supportedContentTypes.first?.identifier ?? "unknown")
                )
                return
            }
            let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
            let upload = NativeStagedMediaUpload(
                localStageID: "settings-profile-photo-\(UUID().uuidString)",
                fileName: "profile-photo.\(fileExtension)",
                contentType: contentType.preferredMIMEType ?? "image/jpeg",
                data: data
            )
            let result = SettingsProfilePhotoStagingPolicy.webProfileParity.stageReplacement(
                existing: stagedProfilePhoto,
                candidate: upload
            )
            if let rejection = result.rejection {
                settingsActionMessage = rejectionMessage(rejection)
                return
            }
            guard let stagedPhoto = result.stagedPhoto else {
                return
            }
            stagedProfilePhoto = stagedPhoto
            planSettingsAction(
                .uploadProfilePhoto(
                    photo: stagedPhoto,
                    clientMutationID: "cm_settings_photo_\(stagedPhoto.localStageID)"
                ),
                using: planner
            )
        } catch {
            settingsActionError = settingsActionErrorMessage(for: error)
        }
    }

    private func acceptedProfilePhotoContentType(for item: PhotosPickerItem) -> UTType? {
        item.supportedContentTypes.first { type in
            guard let mimeType = type.preferredMIMEType else {
                return false
            }
            return SettingsProfilePhotoStagingPolicy.webProfileParity.acceptedContentTypes.contains(mimeType)
        }
    }

    private func rejectionMessage(_ rejection: SettingsProfilePhotoStagingRejection) -> String {
        switch rejection {
        case .unsupportedContentType(let contentType):
            "Profile photo type \(contentType) is not supported."
        case .fileTooLarge(let maxBytes):
            "Profile photo must be \(maxBytes / 1_024 / 1_024) MB or smaller."
        }
    }

    private func openSecureHandoff(_ handoff: SettingsSecureHandoff) {
        openURL(handoff.url)
    }

    private func onlineOnlyMessage(_ reason: SettingsOnlineOnlyReason) -> String {
        reason.message
    }

    /// A 4xx answer's own message (such as "change your email on the web") when the server sent one, so older
    /// builds still say what to do; otherwise a generic message with a diagnostic code.
    private func settingsActionErrorMessage(for error: Error) -> String {
        SettingsActionFailureMessage.serverMessage(for: error)
            ?? "Settings could not be updated. Try again. Code: \(settingsActionDiagnosticCode(for: error))."
    }

    private func settingsActionDiagnosticCode(for error: Error) -> String {
        SettingsActionFailureMessage.diagnosticCode(for: error)
    }

    private func onlineOnlyActionsDisabled(_ surface: SettingsSurfaceViewModel) -> Bool {
#if DEBUG
        // Screenshot captures restore from the offline cache; these focuses show the online state of Your data.
        if Self.accountLifecycleOnlineScreenshotFocuses.contains(screenshotSettingsFocus) {
            return false
        }
#endif
        return surface.connectivity == .offline
    }

#if DEBUG
    private static let accountLifecycleOnlineScreenshotFocuses: Set<ScreenshotSettingsFocus?> = [
        .yourData, .deleteAccount, .deleteAccountError, .exportReady
    ]
#endif

    private var selectedTokenScopes: [String] {
        var scopes: [String] = []
        if tokenCanReadRecipes {
            scopes.append("recipes:read")
        }
        if tokenCanWriteRecipes {
            scopes.append("recipes:write")
        }
        if tokenCanReadShoppingList {
            scopes.append("shopping_list:read")
        }
        if tokenCanWriteShoppingList {
            scopes.append("shopping_list:write")
        }
        return scopes
    }

    private func hydrateProfileDraft(_ profile: SettingsProfileDraft) {
        let identity = profileIdentity(profile)
        guard profileDraftID != identity else {
            return
        }
        profileUsername = profile.username
        profileDraftID = identity
    }

    private func hydrateNotificationDraft(_ preferences: SettingsNotificationPreferences) {
        let identity = notificationIdentity(preferences)
        guard notificationDraftID != identity else {
            return
        }
        notifySpoonOnMyRecipe = preferences.notifySpoonOnMyRecipe
        notifyForkOfMyRecipe = preferences.notifyForkOfMyRecipe
        notifyCookbookSaveOfMine = preferences.notifyCookbookSaveOfMine
        notifyFellowChefOriginCook = preferences.notifyFellowChefOriginCook
        notificationDraftID = identity
    }

    private func profileSaveDisabled(comparedWith profile: SettingsProfileDraft) -> Bool {
        let username = profileUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty || username == profile.username
    }

    private func notificationSaveDisabled(comparedWith preferences: SettingsNotificationPreferences) -> Bool {
        notifySpoonOnMyRecipe == preferences.notifySpoonOnMyRecipe
            && notifyForkOfMyRecipe == preferences.notifyForkOfMyRecipe
            && notifyCookbookSaveOfMine == preferences.notifyCookbookSaveOfMine
            && notifyFellowChefOriginCook == preferences.notifyFellowChefOriginCook
    }

    private func profileIdentity(_ profile: SettingsProfileDraft) -> String {
        "\(profile.email)|\(profile.username)"
    }

    private func notificationIdentity(_ preferences: SettingsNotificationPreferences) -> String {
        [
            preferences.notifySpoonOnMyRecipe,
            preferences.notifyForkOfMyRecipe,
            preferences.notifyCookbookSaveOfMine,
            preferences.notifyFellowChefOriginCook
        ]
        .map { $0 ? "1" : "0" }
        .joined()
    }

    private static func screenshotSettingsFocus() -> ScreenshotSettingsFocus? {
#if DEBUG
        guard let rawFocus = ProcessInfo.processInfo.environment[screenshotFocusEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawFocus.isEmpty else {
            return nil
        }
        return ScreenshotSettingsFocus(rawValue: rawFocus)
#else
        return nil
#endif
    }

    private static func writeScreenshotProof(
        visualFocus: ScreenshotSettingsFocus,
        visibleSections: [String]
    ) {
#if DEBUG
        guard let rawPath = ProcessInfo.processInfo.environment[screenshotProofPathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return
        }
        let outputURL = URL(fileURLWithPath: rawPath)
        let payload: [String: Any] = [
            "route": "settings",
            "visualFocus": visualFocus.rawValue,
            "visibleSections": visibleSections,
            "source": "SettingsView",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: outputURL, options: [.atomic])
#else
        _ = visualFocus
        _ = visibleSections
#endif
    }

    private func sourceLabel(_ source: SettingsSurfaceDataSource) -> String {
        switch source {
        case .live:
            "Live"
        case .cache:
            "Offline cache"
        }
    }

    private var settings: SettingsState {
        viewModel.settings
    }

    private var authSummary: String {
        switch viewModel.authSessionState {
        case .signedOut:
            "Signed out"
        case .authenticated:
            "Signed in"
        case .refreshRequired:
            "Refresh required"
        }
    }
}

/// A settings row in the iOS Settings grammar: an icon, the title, and an arrow only when it leaves the app.
private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let prominence: SettingsRowProminence
    var opensElsewhere = false

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
                .frame(minWidth: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(KitchenTableTheme.bodyNote.weight(effectiveProminence == .primary ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if opensElsewhere {
                Image(systemName: "arrow.up.right")
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.ink2)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(effectiveProminence.foreground)
        .frame(maxWidth: .infinity, minHeight: KitchenTableTheme.minimumTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var effectiveProminence: SettingsRowProminence {
        isEnabled ? prominence : .disabled
    }
}

private struct PendingSettingsDestructiveAction: Identifiable {
    let id = UUID()
    let action: SettingsAction
    let title: String
    let message: String
    let confirmButtonTitle: String
}

private enum SettingsRowProminence {
    case primary
    case secondary
    case destructive
    case disabled

    var foreground: Color {
        switch self {
        case .primary:
            KitchenTableTheme.herb
        case .secondary:
            KitchenTableTheme.ink
        case .destructive:
            KitchenTableTheme.tomato
        case .disabled:
            KitchenTableTheme.ink2.opacity(0.62)
        }
    }
}

struct SettingsPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .font(KitchenTableTheme.bodyNote)
        .foregroundStyle(KitchenTableTheme.ink)
        .tint(KitchenTableTheme.herb)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.raised, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
    }
}

/// Lets `.sheet(item:)` present the delete sheet from an optional form.
private struct IdentifiedAccountDeletionForm: Identifiable {
    let id: String
    let form: AccountDeletionForm
}

private extension Binding where Value == AccountDeletionForm? {
    var identified: Binding<IdentifiedAccountDeletionForm?> {
        Binding<IdentifiedAccountDeletionForm?>(
            get: { wrappedValue.map { IdentifiedAccountDeletionForm(id: $0.username, form: $0) } },
            set: { if $0 == nil { wrappedValue = nil } }
        )
    }
}

enum SettingsAboutLink: String, CaseIterable, Identifiable {
    case privacy
    case terms
    case support
    case contact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Service"
        case .support: "Support"
        case .contact: "Contact Spoonjoy"
        }
    }

    var systemImage: String {
        switch self {
        case .privacy: "hand.raised.square"
        case .terms: "doc.text"
        case .support: "questionmark.circle"
        case .contact: "envelope"
        }
    }

    var url: URL {
        switch self {
        case .privacy: URL(string: "https://spoonjoy.app/privacy")!
        case .terms: URL(string: "https://spoonjoy.app/terms")!
        case .support: URL(string: "https://spoonjoy.app/support")!
        case .contact: URL(string: "mailto:ari@spoonjoy.app")!
        }
    }
}
