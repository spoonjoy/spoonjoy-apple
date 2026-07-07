import SpoonjoyCore
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum ScreenshotSettingsFocus: String {
        case profile
        case notifications
    }

    private static let screenshotFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"
    private static let notificationsFocusID = "settings-section-notification-apns-delivery"

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
    var onRetrySync: @MainActor @Sendable () async -> Void = {}
    var onDismissOfflineIndicator: @MainActor @Sendable () -> Void = {}

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var selectedProfilePhotoItem: PhotosPickerItem?
    @State private var stagedProfilePhoto: NativeStagedMediaUpload?
    @State private var profileEmail = ""
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
    @State private var tokenName = "Native App Token"
    @State private var tokenCanReadRecipes = true
    @State private var tokenCanWriteRecipes = false
    @State private var tokenCanReadShoppingList = false
    @State private var tokenCanWriteShoppingList = false
    @State private var pendingDestructiveAction: PendingSettingsDestructiveAction?
    @State private var screenshotSettingsFocus = SettingsView.screenshotSettingsFocus()

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
                            proxy.scrollTo(Self.notificationsFocusID, anchor: .center)
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        guard notificationAPNsSurfaceViewModel != nil else {
                            return
                        }
                        Self.writeScreenshotProof(
                            visualFocus: screenshotSettingsFocus,
                            visibleSections: ["Notifications", "Device Notifications", "APNs Delivery", "Notification Sync"]
                        )
                        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
                            route: "settings",
                            source: "SettingsView",
                            runtimeContext: screenshotAccessibilityRuntimeContext
                        )
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
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var settingsForm: some View {
        Form {
            if let settingsSurfaceViewModel {
                nativeSettings(surface: settingsSurfaceViewModel)
            } else {
                legacySettings
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(KitchenTableTheme.bone)
        .tint(KitchenTableTheme.herb)
    }

    @ViewBuilder private func nativeSettings(surface: SettingsSurfaceViewModel) -> some View {
        if let profile = surface.profileDraft {
            Section("Profile") {
                TextField("Email", text: $profileEmail)
                TextField("Username", text: $profileUsername)
                Button("Save Profile") {
                    planSettingsAction(
                        .updateProfile(
                            email: profileEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            username: profileUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                            clientMutationID: "cm_settings_profile_\(UUID().uuidString)"
                        ),
                        using: surface.actionPlanner
                    )
                }
                .disabled(profileSaveDisabled(comparedWith: profile))
                PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                    Text("Upload Photo")
                }
                .onChange(of: selectedProfilePhotoItem) { _, item in
                    guard let item else { return }
                    Task { @MainActor in
                        await stageProfilePhoto(item, using: surface.actionPlanner)
                    }
                }
                Button("Remove Photo", role: .destructive) {
                    confirmSettingsAction(
                        .removeProfilePhoto(clientMutationID: "cm_settings_remove_photo_\(UUID().uuidString)"),
                        title: "Remove profile photo?",
                        message: "Your profile photo will be removed. If you are offline, this change will wait to sync.",
                        confirmButtonTitle: "Remove Photo"
                    )
                }
            }
            .task(id: profileIdentity(profile)) {
                hydrateProfileDraft(profile)
            }

            Section("Security") {
                Button("Password") {
                    planSettingsAction(.managePassword, using: surface.actionPlanner)
                }
                .disabled(onlineOnlyActionsDisabled(surface))
                Button("Passkeys") {
                    planSettingsAction(.managePasskeys, using: surface.actionPlanner)
                }
                .disabled(onlineOnlyActionsDisabled(surface))
                ForEach(surface.securityRows.filter { $0.id == .providerLinks }, id: \.id) { row in
                    Button(row.title) {
                        planSettingsAction(row.action, using: surface.actionPlanner)
                    }
                    .disabled(onlineOnlyActionsDisabled(surface))
                }
                Button("Sign Out", role: .destructive) {
                    confirmSettingsAction(
                        .logout,
                        title: "Sign out?",
                        message: "Spoonjoy will revoke the local session and send you through the secure sign-out flow.",
                        confirmButtonTitle: "Sign Out"
                    )
                }
                .disabled(onlineOnlyActionsDisabled(surface))
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
                Section("Notifications") {
                    Toggle("Spoons", isOn: $notifySpoonOnMyRecipe)
                    Toggle("Forks", isOn: $notifyForkOfMyRecipe)
                    Toggle("Cookbook saves", isOn: $notifyCookbookSaveOfMine)
                    Toggle("Fellow-chef cooks", isOn: $notifyFellowChefOriginCook)
                    Button("Save Notifications") {
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
                    }
                    .disabled(notificationSaveDisabled(comparedWith: notifications))
                }
                .task(id: notificationIdentity(notifications)) {
                    hydrateNotificationDraft(notifications)
                }
                .id(Self.notificationsFocusID)
            }

            if surface.data.tokenManagementAvailability == .available {
                Section("API Tokens") {
                    if let createdCredentialValue {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("New token")
                            Text(createdCredentialValue)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            if let createdCredentialPrefix {
                                Text(createdCredentialPrefix)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(surface.apiTokenRows) { token in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(token.name)
                            Text(token.tokenPrefix)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Revoke Token", role: .destructive) {
                            confirmSettingsAction(
                                .revokeAPIToken(credentialID: token.id),
                                title: "Revoke API token?",
                                message: "Apps using this token will lose access immediately.",
                                confirmButtonTitle: "Revoke Token"
                            )
                        }
                        .disabled(onlineOnlyActionsDisabled(surface))
                    }
                    TextField("Token name", text: $tokenName)
                    Toggle("Recipes read", isOn: $tokenCanReadRecipes)
                    Toggle("Recipes write", isOn: $tokenCanWriteRecipes)
                    Toggle("Shopping read", isOn: $tokenCanReadShoppingList)
                    Toggle("Shopping write", isOn: $tokenCanWriteShoppingList)
                    Button("Create Token") {
                        planSettingsAction(.createAPIToken(name: tokenName, scopes: selectedTokenScopes), using: surface.actionPlanner)
                    }
                    .disabled(tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedTokenScopes.isEmpty || onlineOnlyActionsDisabled(surface))
                }

                Section("Connections") {
                    ForEach(surface.oauthConnectionRows) { connection in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(connection.clientName)
                            Text(connection.scopes.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Disconnect", role: .destructive) {
                            confirmSettingsAction(
                                .disconnectOAuthConnection(connectionID: connection.id),
                                title: "Disconnect OAuth app?",
                                message: "\(connection.clientName) will no longer be able to access your Spoonjoy account.",
                                confirmButtonTitle: "Disconnect"
                            )
                        }
                        .disabled(onlineOnlyActionsDisabled(surface))
                    }
                }
            }
        } else if let primaryAuthAction = surface.primaryAuthAction {
            Section("Session") {
                Button("Sign In") {
                    openSecureHandoff(primaryAuthAction)
                }
            }
        } else {
            Section("Account") {
                Text("Account data has not loaded yet.")
                Text("Try sync again to load your profile, security, and notification settings from Spoonjoy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await onRetrySync() }
                } label: {
                    Label("Try Sync Again", systemImage: "arrow.clockwise")
                }
            }
        }

        Section("Environment") {
            LabeledContent("Environment", value: surface.data.environment.rawValue)
            LabeledContent("Source", value: sourceLabel(surface.data.source))
        }

        Section("Offline") {
            if let summary = surface.queuedWorkSummary {
                Text(summary)
            }
            if let conflictBanner = surface.conflictBanner {
                Text(conflictBanner.message)
            }
            if let settingsActionMessage {
                Text(settingsActionMessage)
            }
            if let settingsActionError {
                Text(settingsActionError)
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

    @ViewBuilder private var legacySettings: some View {
        Section("Status") {
            ForEach(settings.statusRows, id: \.id) { row in
                LabeledContent(row.title, value: row.value)
            }
        }

        Section("Session") {
            LabeledContent("Auth", value: authSummary)
            LabeledContent("Environment", value: viewModel.environmentSwitcher.rawValue)
        }

        Section("Shopping") {
            Label(
                settings.canReadShoppingList ? "Shopping read enabled" : "Shopping read unavailable",
                systemImage: settings.canReadShoppingList ? "checkmark.circle" : "xmark.circle"
            )
            Label(
                settings.canWriteShoppingList ? "Shopping write enabled" : "Shopping write unavailable",
                systemImage: settings.canWriteShoppingList ? "checkmark.circle" : "xmark.circle"
            )
        }

        Section("Offline") {
            OfflineStatusView(display: effectiveOfflineIndicator(viewModel.offlineIndicatorDisplay)) {
                _ = viewModel.dismissOfflineIndicator
                onDismissOfflineIndicator()
            }
        }
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
                settingsActionError = String(describing: error)
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
            settingsActionError = String(describing: error)
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

    private func onlineOnlyActionsDisabled(_ surface: SettingsSurfaceViewModel) -> Bool {
        surface.connectivity == .offline
    }

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
        profileEmail = profile.email
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
        let email = profileEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = profileUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty || username.isEmpty || (email == profile.email && username == profile.username)
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

private struct PendingSettingsDestructiveAction: Identifiable {
    let id = UUID()
    let action: SettingsAction
    let title: String
    let message: String
    let confirmButtonTitle: String
}
