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
    }

    private static let screenshotFocusEnvironmentKey = "SPOONJOY_SCREENSHOT_SETTINGS_FOCUS"
    private static let screenshotProofPathEnvironmentKey = "SPOONJOY_SCREENSHOT_PROOF_PATH"
    private static let notificationsFocusID = "settings-section-notification-apns-device"
    private static let notificationFocusCorrectionAnchor = UnitPoint(x: 0.5, y: 0.14)

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
    @State private var tokenName = "Spoonjoy Agent Access"
    @State private var tokenCanReadRecipes = true
    @State private var tokenCanWriteRecipes = false
    @State private var tokenCanReadShoppingList = false
    @State private var tokenCanWriteShoppingList = false
    @State private var pendingDestructiveAction: PendingSettingsDestructiveAction?
    @State private var screenshotSettingsFocus = SettingsView.screenshotSettingsFocus()
    @State private var notificationFocusWasCorrected = false
    @State private var notificationScreenshotProofWasWritten = false

    var body: some View {
        ScrollViewReader { proxy in
            settingsForm
                .overlayPreferenceValue(NotificationAPNsDeviceSectionBoundsPreferenceKey.self) { anchor in
                    GeometryReader { geometry in
                        let observation = SettingsNotificationVisibilityObservation(
                            deviceSectionFrame: anchor.map { geometry[$0] } ?? .null,
                            viewportSize: geometry.size,
                            safeAreaTop: geometry.safeAreaInsets.top
                        )
                        Color.clear
                            .task(id: observation) {
                                await acknowledgeNotificationFocusIfVisible(observation, proxy: proxy)
                            }
                    }
                }
                .task(id: screenshotSettingsFocus) {
                    guard let screenshotSettingsFocus else {
                        return
                    }
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
                        guard notificationAPNsSurfaceViewModel != nil else {
                            return
                        }
                        withAnimation(nil) {
                            proxy.scrollTo(Self.notificationsFocusID, anchor: .top)
                        }
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

    @MainActor
    private func acknowledgeNotificationFocusIfVisible(
        _ observation: SettingsNotificationVisibilityObservation,
        proxy: ScrollViewProxy
    ) async {
        guard screenshotSettingsFocus == .notifications,
              notificationAPNsSurfaceViewModel != nil,
              !notificationScreenshotProofWasWritten else {
            return
        }

        guard observation.hasVisibleDeviceHeader else {
            guard observation.hasMeasuredDeviceSection, !notificationFocusWasCorrected else {
                return
            }
            notificationFocusWasCorrected = true
            withAnimation(nil) {
                proxy.scrollTo(Self.notificationsFocusID, anchor: Self.notificationFocusCorrectionAnchor)
            }
            return
        }

        notificationScreenshotProofWasWritten = true
        Self.writeScreenshotProof(
            visualFocus: .notifications,
            visibleSections: ["This Device", "Push Delivery", "Notification Sync", "Agent Access"],
            visibilityObservation: observation
        )
        await ScreenshotAccessibilityProofWriter.writeIfNeeded(
            route: "settings",
            source: "SettingsView",
            runtimeContext: screenshotAccessibilityRuntimeContext
        )
    }

    private var screenshotAccessibilityRuntimeContext: ScreenshotAccessibilityRuntimeContext {
        ScreenshotAccessibilityRuntimeContext(
            dynamicTypeSize: String(describing: dynamicTypeSize),
            reduceMotionEnabled: accessibilityReduceMotion
        )
    }

    private var settingsForm: some View {
        KitchenTablePage {
            KitchenTableHeader(
                eyebrow: "Account",
                title: "Settings",
                subtitle: settingsHeaderSubtitle
            )
            if let settingsSurfaceViewModel {
                nativeSettings(surface: settingsSurfaceViewModel)
            } else {
                legacySettings
            }
        }
        .tint(KitchenTableTheme.herb)
    }

    private var settingsHeaderSubtitle: String {
        if let surface = settingsSurfaceViewModel {
            "\(surface.data.environment.rawValue.capitalized) - \(sourceLabel(surface.data.source))"
        } else {
            "\(authSummary) - \(viewModel.environmentSwitcher.rawValue.capitalized)"
        }
    }

    @ViewBuilder private func nativeSettings(surface: SettingsSurfaceViewModel) -> some View {
        if let profile = surface.profileDraft {
            KitchenTableSection(title: "Profile", subtitle: "Public identity and chef card") {
                SettingsPanel {
                    settingsTextField("Email", text: $profileEmail)
                    settingsTextField("Username", text: $profileUsername)

                    Button {
                        planSettingsAction(
                            .updateProfile(
                                email: profileEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                                username: profileUsername.trimmingCharacters(in: .whitespacesAndNewlines),
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

            KitchenTableSection(title: "Security", subtitle: "Online-only account controls") {
                SettingsPanel {
                    Button {
                        planSettingsAction(.managePassword, using: surface.actionPlanner)
                    } label: {
                        settingsRowLabel("Password", systemImage: "key", prominence: .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))

                    Button {
                        planSettingsAction(.managePasskeys, using: surface.actionPlanner)
                    } label: {
                        settingsRowLabel("Passkeys", systemImage: "person.badge.key", prominence: .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(onlineOnlyActionsDisabled(surface))

                    ForEach(surface.securityRows.filter { $0.id == .providerLinks }, id: \.id) { row in
                        Button {
                            planSettingsAction(row.action, using: surface.actionPlanner)
                        } label: {
                            settingsRowLabel(row.title, systemImage: "link", prominence: .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(onlineOnlyActionsDisabled(surface))
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
                }
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
                KitchenTableSection(title: "Notifications", subtitle: "Activity worth interrupting dinner prep") {
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
                KitchenTableSection(title: "Agent access", subtitle: "Keys for agents and connected tools") {
                    SettingsPanel {
                        if let createdCredentialValue {
                            settingsCreatedCredentialDisclosure(
                                credentialValue: createdCredentialValue,
                                credentialPrefix: createdCredentialPrefix
                            )
                        }

                        ForEach(surface.apiTokenRows) { token in
                            VStack(alignment: .leading, spacing: 8) {
                                settingsFact(token.name, value: token.displayIdentifier)
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
                    }
                }

                KitchenTableSection(title: "Connections", subtitle: "Apps connected to Spoonjoy") {
                    SettingsPanel {
                        if surface.oauthConnectionRows.isEmpty {
                            Text("No connected apps.")
                                .font(KitchenTableTheme.bodyNote)
                                .foregroundStyle(KitchenTableTheme.inkMuted)
                        }
                        ForEach(surface.oauthConnectionRows) { connection in
                            VStack(alignment: .leading, spacing: 8) {
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
                }
            }
        } else if let primaryAuthAction = surface.primaryAuthAction {
            KitchenTableSection(title: "Session", subtitle: "Secure Spoonjoy handoff") {
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
            KitchenTableSection(title: "Account", subtitle: "Sync needs another attempt") {
                SettingsPanel {
                    Text("Account sync has not finished yet.")
                        .font(KitchenTableTheme.objectTitle)
                        .foregroundStyle(KitchenTableTheme.charcoal)
                    Text("Spoonjoy is signed in, but the latest sync did not finish loading your profile, security, and notification settings.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    if let syncFailureDiagnosticText {
                        Text(syncFailureDiagnosticText)
                            .font(.caption.monospaced())
                            .foregroundStyle(KitchenTableTheme.inkMuted)
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

        KitchenTableSection(title: "Environment", subtitle: "Current data source") {
            SettingsPanel {
                settingsFact("Environment", value: surface.data.environment.rawValue)
                settingsFact("Source", value: sourceLabel(surface.data.source))
            }
        }

        KitchenTableSection(title: "Offline", subtitle: "What the app is using right now") {
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.terminal")
            .accessibilityLabel("Offline")
        }
    }

    @ViewBuilder private var legacySettings: some View {
        KitchenTableSection(title: "Status", subtitle: "Live session snapshot") {
            SettingsPanel {
                ForEach(settings.statusRows, id: \.id) { row in
                    settingsFact(row.title, value: row.value)
                }
            }
        }

        KitchenTableSection(title: "Session") {
            SettingsPanel {
                settingsFact("Auth", value: authSummary)
                settingsFact("Environment", value: viewModel.environmentSwitcher.rawValue)
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.terminal")
            .accessibilityLabel("Offline")
        }
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
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

    private func settingsFact(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.brass)
            Spacer(minLength: 12)
            Text(value)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
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
                .foregroundStyle(KitchenTableTheme.charcoal)
                .textSelection(.enabled)
            if let credentialPrefix {
                Text(credentialPrefix)
                    .font(KitchenTableTheme.uiLabel)
                    .foregroundStyle(KitchenTableTheme.inkMuted)
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
        prominence: SettingsRowProminence
    ) -> some View {
        SettingsRowLabel(title: title, systemImage: systemImage, prominence: prominence)
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

    private func settingsActionErrorMessage(for error: Error) -> String {
        "Settings could not be updated. Try again. Code: \(settingsActionDiagnosticCode(for: error))."
    }

    private func settingsActionDiagnosticCode(for error: Error) -> String {
        if let transportError = error as? APITransportError {
            if let apiError = transportError.apiError {
                return "settings_api_\(apiError.code)_\(apiError.status)"
            }
            if let statusCode = transportError.statusCode {
                return "settings_http_\(statusCode)"
            }
            return "settings_transport"
        }
        if error is SettingsActionPlanningError {
            return "settings_plan"
        }
        return "settings_unexpected"
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
        visibleSections: [String],
        visibilityObservation: SettingsNotificationVisibilityObservation? = nil
    ) {
#if DEBUG
        guard let rawPath = ProcessInfo.processInfo.environment[screenshotProofPathEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return
        }
        let outputURL = URL(fileURLWithPath: rawPath)
        var payload: [String: Any] = [
            "route": "settings",
            "visualFocus": visualFocus.rawValue,
            "visibleSections": visibleSections,
            "source": "SettingsView",
            "writtenAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let visibilityObservation {
            payload["visibilityAcknowledged"] = visibilityObservation.hasVisibleDeviceHeader
            payload["safeAreaTop"] = Double(visibilityObservation.safeAreaTop)
            payload["deviceSectionFrame"] = [
                "minY": Double(visibilityObservation.deviceSectionFrame.minY),
                "maxY": Double(visibilityObservation.deviceSectionFrame.maxY),
                "height": Double(visibilityObservation.deviceSectionFrame.height)
            ]
            payload["viewportHeight"] = Double(visibilityObservation.viewportSize.height)
        }
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
        _ = visibilityObservation
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

private struct SettingsNotificationVisibilityObservation: Equatable {
    let deviceSectionFrame: CGRect
    let viewportSize: CGSize
    let safeAreaTop: CGFloat

    var hasMeasuredDeviceSection: Bool {
        !deviceSectionFrame.isNull
            && !deviceSectionFrame.isInfinite
            && deviceSectionFrame.height > 0
            && viewportSize.height > 0
    }

    var hasVisibleDeviceHeader: Bool {
        guard hasMeasuredDeviceSection else {
            return false
        }
        let visibleTop = max(0, safeAreaTop) + 12
        let visibleBottom = viewportSize.height - 12
        let headerHeight = min(72, deviceSectionFrame.height)
        let preferredHeaderBandBottom = min(viewportSize.height * 0.38, visibleBottom - headerHeight)
        return deviceSectionFrame.minY >= visibleTop
            && deviceSectionFrame.minY <= preferredHeaderBandBottom
            && deviceSectionFrame.minY + headerHeight <= visibleBottom
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let prominence: SettingsRowProminence

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 8)
        }
        .foregroundStyle(effectiveProminence.foreground)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(effectiveProminence.background, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .strokeBorder(effectiveProminence.stroke, lineWidth: 1)
        }
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
            KitchenTableTheme.paper
        case .secondary:
            KitchenTableTheme.charcoal
        case .destructive:
            KitchenTableTheme.tomato
        case .disabled:
            KitchenTableTheme.inkMuted.opacity(0.62)
        }
    }

    var background: Color {
        switch self {
        case .primary:
            KitchenTableTheme.brass
        case .secondary:
            KitchenTableTheme.paper
        case .destructive:
            KitchenTableTheme.paper
        case .disabled:
            KitchenTableTheme.paper.opacity(0.72)
        }
    }

    var stroke: Color {
        switch self {
        case .primary:
            KitchenTableTheme.brass
        case .secondary:
            KitchenTableTheme.line.opacity(0.55)
        case .destructive:
            KitchenTableTheme.tomato.opacity(0.42)
        case .disabled:
            KitchenTableTheme.line.opacity(0.38)
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
        .foregroundStyle(KitchenTableTheme.charcoal)
        .tint(KitchenTableTheme.herb)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KitchenTableTheme.paper, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .strokeBorder(KitchenTableTheme.line.opacity(0.42), lineWidth: 1)
        }
    }
}
