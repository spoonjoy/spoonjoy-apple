import SpoonjoyCore
import SwiftUI

private let notificationAPNsPermissionDeniedTitle = "Notifications are off in System Settings"
private let notificationAPNsPermissionDeniedActionTitle = "Open System Settings"
private let notificationAPNsDeliveryFocusID = "settings-section-notification-apns-delivery"

struct NotificationAPNsSettingsView: View {
    let viewModel: NotificationAPNsSurfaceViewModel
    var performNotificationAPNsAction: @MainActor @Sendable (NotificationAPNsActionPlan) async throws -> Void
    var requestNotificationPermission: @MainActor @Sendable () async throws -> APNsPermissionState
    var requestDeviceRegistrationAction: @MainActor @Sendable (String) async throws -> NotificationAPNsAction
    var openNotificationSettings: @MainActor @Sendable () -> Void
    var onDismissOfflineIndicator: @MainActor @Sendable () -> Void = {}

    @State private var notifySpoonOnMyRecipe = false
    @State private var notifyForkOfMyRecipe = false
    @State private var notifyCookbookSaveOfMine = false
    @State private var notifyFellowChefOriginCook = false
    @State private var notificationDraftID: String?
    @State private var notificationActionMessage: String?
    @State private var notificationActionError: String?
    @State private var pendingNotificationConfirmation: PendingNotificationAPNsConfirmation?

    var body: some View {
        notificationSections
        .confirmationDialog(
            pendingNotificationConfirmation?.title ?? "Confirm notification action",
            isPresented: Binding(
                get: { pendingNotificationConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingNotificationConfirmation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingNotificationConfirmation {
                Button(pendingNotificationConfirmation.confirmButtonTitle, role: .destructive) {
                    let pending = pendingNotificationConfirmation
                    self.pendingNotificationConfirmation = nil
                    planNotificationAPNsAction(pending.action)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingNotificationConfirmation = nil
            }
        } message: {
            if let message = pendingNotificationConfirmation?.message {
                Text(message)
            }
        }
        .task(id: notificationIdentity(viewModel.notificationDraft)) {
            hydrateNotificationDraft(viewModel.notificationDraft)
        }
    }

    private var notificationSections: some View {
        Group {
            notificationPreferencesSection
            deviceNotificationsSection
            apnsDeliverySection
            notificationSyncSection
        }
    }

    private var notificationPreferencesSection: some View {
        KitchenTableSection(title: "Notifications", subtitle: "Activity worth interrupting dinner prep") {
            SettingsPanel {
                notificationToggle("Spoons", isOn: $notifySpoonOnMyRecipe)
                notificationToggle("Forks", isOn: $notifyForkOfMyRecipe)
                notificationToggle("Cookbook saves", isOn: $notifyCookbookSaveOfMine)
                notificationToggle("Fellow-chef cooks", isOn: $notifyFellowChefOriginCook)
                Button {
                    planNotificationAPNsAction(
                        .updatePreferences(
                            SettingsNotificationPreferences(
                                notifySpoonOnMyRecipe: notifySpoonOnMyRecipe,
                                notifyForkOfMyRecipe: notifyForkOfMyRecipe,
                                notifyCookbookSaveOfMine: notifyCookbookSaveOfMine,
                                notifyFellowChefOriginCook: notifyFellowChefOriginCook
                            ),
                            clientMutationID: "cm_notifications_\(UUID().uuidString)"
                        )
                    )
                } label: {
                    notificationRowLabel("Save Notifications", systemImage: "bell.badge", prominence: .primary)
                }
                .buttonStyle(.plain)
                .disabled(notificationSaveDisabled(comparedWith: viewModel.notificationDraft))
            }
        }
    }

    private var deviceNotificationsSection: some View {
        KitchenTableSection(title: "Device Notifications", subtitle: "Local permission and device token") {
            SettingsPanel {
                if let banner = viewModel.permissionDeniedBanner {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(banner.title, systemImage: "bell.slash")
                            .font(KitchenTableTheme.bodyNote.weight(.semibold))
                            .foregroundStyle(KitchenTableTheme.tomato)
                        Text(banner.message)
                            .font(KitchenTableTheme.bodyNote)
                            .foregroundStyle(KitchenTableTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            openNotificationSettings()
                        } label: {
                            notificationRowLabel(banner.actionTitle, systemImage: "gearshape", prominence: .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .accessibilityIdentifier("permissionDenied")
                } else {
                    Button {
                        requestNotificationPermissionAction()
                    } label: {
                        notificationRowLabel("Request Permission", systemImage: "bell.badge", prominence: .secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let registration = viewModel.apnsRegistration {
                    APNsRegistrationSummaryRow(registration: registration)
                    Button(role: .destructive) {
                        pendingNotificationConfirmation = PendingNotificationAPNsConfirmation(
                            title: "Stop device notifications?",
                            message: "Spoonjoy will stop sending notifications to this device. If you are offline, the revocation will wait to sync.",
                            confirmButtonTitle: "Revoke Device",
                            action: .revokeDevice(
                                deviceID: registration.deviceID,
                                clientMutationID: "cm_apns_revoke_\(UUID().uuidString)"
                            )
                        )
                    } label: {
                        notificationRowLabel("Revoke Device", systemImage: "trash", prominence: .destructive)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("This device is not registered for Spoonjoy notifications.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    Button {
                        requestDeviceRegistration()
                    } label: {
                        notificationRowLabel("Register This Device", systemImage: "iphone.radiowaves.left.and.right", prominence: .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var apnsDeliverySection: some View {
        KitchenTableSection(title: "APNs Delivery", subtitle: "Production delivery status") {
            SettingsPanel {
                switch deliveryBlockerState {
                case .developmentOnly(let blocker):
                    Label("Development APNs registration can sync for local validation.", systemImage: "checkmark.circle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.herb)
                    AppleDeveloperProgramBlockerView(
                        blocker: blocker,
                        artifactFileName: viewModel.blockerArtifactFileName
                    )
                case .blocked(let blocker):
                    AppleDeveloperProgramBlockerView(
                        blocker: blocker,
                        artifactFileName: viewModel.blockerArtifactFileName
                    )
                }
            }
        }
        .id(notificationAPNsDeliveryFocusID)
    }

    private var notificationSyncSection: some View {
        KitchenTableSection(title: "Notification Sync", subtitle: "Queued changes and offline state") {
            SettingsPanel {
                if let summary = viewModel.queuedWorkSummary {
                    Label(summary, systemImage: "arrow.triangle.2.circlepath")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.brass)
                }
                if let notificationActionMessage {
                    Label(notificationActionMessage, systemImage: "checkmark.circle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.herb)
                }
                if let notificationActionError {
                    Label(notificationActionError, systemImage: "exclamationmark.triangle")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.tomato)
                }
                OfflineStatusView(display: viewModel.offlineIndicator.display, onDismiss: onDismissOfflineIndicator)
            }
        }
    }

    private func notificationToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.charcoal)
        }
        .tint(KitchenTableTheme.herb)
    }

    private func notificationRowLabel(
        _ title: String,
        systemImage: String,
        prominence: NotificationRowProminence
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 8)
        }
        .foregroundStyle(prominence.foreground)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(prominence.background, in: RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: KitchenTableTheme.Radius.panel)
                .strokeBorder(prominence.stroke, lineWidth: 1)
        }
    }

    private func planNotificationAPNsAction(_ action: NotificationAPNsAction) {
        Task { @MainActor in
            await performNotificationAPNsAction(action)
        }
    }

    private func requestNotificationPermissionAction() {
        Task { @MainActor in
            do {
                guard viewModel.connectivity == .online else {
                    let plan = try viewModel.actionPlanner.plan(.requestPermission)
                    notificationActionMessage = plan.userFacingMessage ?? plan.onlineOnlyReason?.message
                    notificationActionError = nil
                    try await performNotificationAPNsAction(plan)
                    return
                }

                let permissionState = try await requestNotificationPermission()
                switch permissionState {
                case .authorized:
                    notificationActionMessage = "Notifications are allowed for this device."
                case .denied:
                    notificationActionMessage = notificationAPNsPermissionDeniedTitle
                case .notDetermined:
                    notificationActionMessage = "Notification permission has not been decided yet."
                }
                notificationActionError = nil
            } catch {
                notificationActionError = String(describing: error)
            }
        }
    }

    private func requestDeviceRegistration() {
        Task { @MainActor in
            do {
                guard viewModel.connectivity == .online else {
                    let plan = try viewModel.actionPlanner.planDeviceTokenAcquisition()
                    notificationActionMessage = plan.userFacingMessage ?? plan.onlineOnlyReason?.message
                    notificationActionError = nil
                    try await performNotificationAPNsAction(plan)
                    return
                }

                let action = try await requestDeviceRegistrationAction("cm_apns_register_\(UUID().uuidString)")
                await performNotificationAPNsAction(action)
            } catch {
                notificationActionError = String(describing: error)
            }
        }
    }

    @MainActor
    private func performNotificationAPNsAction(_ action: NotificationAPNsAction) async {
        do {
            let plan = try viewModel.actionPlanner.plan(action)
            notificationActionMessage = plan.userFacingMessage ?? plan.onlineOnlyReason?.message
            notificationActionError = nil
            try await performNotificationAPNsAction(plan)
            if plan.queuedMutation != nil {
                notificationActionMessage = "Notification change queued."
            } else if plan.deliveryBlocker != nil {
                notificationActionMessage = plan.userFacingMessage
            } else if plan.userFacingMessage == nil {
                notificationActionMessage = nil
            }
        } catch {
            notificationActionError = String(describing: error)
        }
    }

    private var deliveryBlockerState: APNsDeliveryBlockerState {
        return viewModel.deliveryBlockerState
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

    private func notificationSaveDisabled(comparedWith preferences: SettingsNotificationPreferences) -> Bool {
        notifySpoonOnMyRecipe == preferences.notifySpoonOnMyRecipe
            && notifyForkOfMyRecipe == preferences.notifyForkOfMyRecipe
            && notifyCookbookSaveOfMine == preferences.notifyCookbookSaveOfMine
            && notifyFellowChefOriginCook == preferences.notifyFellowChefOriginCook
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
}

private struct APNsRegistrationSummaryRow: View {
    let registration: APNsRegistrationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotificationFactRow(title: "Device", value: registration.deviceID)
            NotificationFactRow(title: "Platform", value: registration.platform.rawValue)
            NotificationFactRow(title: "Environment", value: registration.environment.rawValue)
            NotificationFactRow(title: "State", value: registration.registrationState.rawValue)
        }
    }
}

private struct AppleDeveloperProgramBlockerView: View {
    let blocker: AppleDeveloperProgramBlocker
    let artifactFileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Production push delivery not enabled", systemImage: "lock.shield.fill")
                .font(KitchenTableTheme.objectTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text("Notification preferences and local device registration can still sync. TestFlight push delivery waits on Apple push signing for this build.")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Nothing is required to keep using Spoonjoy.")
                .font(KitchenTableTheme.uiLabel)
                .foregroundStyle(KitchenTableTheme.herb)
                .fixedSize(horizontal: false, vertical: true)
            NotificationFactRow(title: "State", value: blocker.blocked ? "blocked" : "available")
        }
    }

    private var blockerCapabilityContractAnchor: String {
        blocker.capability
    }

    private var blockerOwnerActionContractAnchor: String {
        blocker.ownerAction
    }
}

private struct NotificationFactRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleText
                Spacer(minLength: 12)
                valueText
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                titleText
                valueText
            }
        }
        .padding(.vertical, 2)
    }

    private var titleText: some View {
        Text(title)
            .font(KitchenTableTheme.uiLabel)
            .foregroundStyle(KitchenTableTheme.brass)
    }

    private var valueText: some View {
        Text(value)
            .font(KitchenTableTheme.bodyNote)
            .foregroundStyle(KitchenTableTheme.charcoal)
            .lineLimit(3)
            .minimumScaleFactor(0.82)
            .textSelection(.enabled)
    }
}

private enum NotificationRowProminence {
    case primary
    case secondary
    case destructive

    var foreground: Color {
        switch self {
        case .primary:
            KitchenTableTheme.paper
        case .secondary:
            KitchenTableTheme.charcoal
        case .destructive:
            KitchenTableTheme.tomato
        }
    }

    var background: Color {
        switch self {
        case .primary:
            KitchenTableTheme.brass
        case .secondary, .destructive:
            KitchenTableTheme.paper
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
        }
    }
}

private struct PendingNotificationAPNsConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmButtonTitle: String
    let action: NotificationAPNsAction
}
