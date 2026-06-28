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

    @State private var notifySpoonOnMyRecipe = false
    @State private var notifyForkOfMyRecipe = false
    @State private var notifyCookbookSaveOfMine = false
    @State private var notifyFellowChefOriginCook = false
    @State private var notificationDraftID: String?
    @State private var notificationActionMessage: String?
    @State private var notificationActionError: String?
    @State private var pendingNotificationConfirmation: PendingNotificationAPNsConfirmation?

    var body: some View {
        Section("Notifications") {
            Toggle("Spoons", isOn: $notifySpoonOnMyRecipe)
            Toggle("Forks", isOn: $notifyForkOfMyRecipe)
            Toggle("Cookbook saves", isOn: $notifyCookbookSaveOfMine)
            Toggle("Fellow-chef cooks", isOn: $notifyFellowChefOriginCook)
            Button("Save Notifications") {
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
            }
            .disabled(notificationSaveDisabled(comparedWith: viewModel.notificationDraft))
        }
        .task(id: notificationIdentity(viewModel.notificationDraft)) {
            hydrateNotificationDraft(viewModel.notificationDraft)
        }

        Section("Device Notifications") {
            if let banner = viewModel.permissionDeniedBanner {
                VStack(alignment: .leading, spacing: 4) {
                    Text(banner.title)
                        .font(KitchenTableTheme.bodyNote.weight(.semibold))
                    Text(banner.message)
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(.secondary)
                    Button(banner.actionTitle) {
                        openNotificationSettings()
                    }
                }
                .accessibilityIdentifier("permissionDenied")
            } else {
                Button("Request Permission") {
                    requestNotificationPermissionAction()
                }
            }

            if let registration = viewModel.apnsRegistration {
                APNsRegistrationSummaryRow(registration: registration)
                Button("Revoke Device", role: .destructive) {
                    pendingNotificationConfirmation = PendingNotificationAPNsConfirmation(
                        title: "Stop device notifications?",
                        message: "Spoonjoy will stop sending notifications to this device. If you are offline, the revocation will wait to sync.",
                        confirmButtonTitle: "Revoke Device",
                        action: .revokeDevice(
                            deviceID: registration.deviceID,
                            clientMutationID: "cm_apns_revoke_\(UUID().uuidString)"
                        )
                    )
                }
            } else {
                Text("This device is not registered for Spoonjoy notifications.")
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
                Button("Register This Device") {
                    requestDeviceRegistration()
                }
            }
        }
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

        Section("APNs Delivery") {
            switch deliveryBlockerState {
            case .developmentOnly(let blocker):
                Text("Development APNs registration can sync for local validation. Production delivery remains blocked.")
                    .font(KitchenTableTheme.bodyNote)
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
            if let blocker = viewModel.productionBlocker {
                Text(blocker.outputPath)
                    .font(KitchenTableTheme.bodyNote)
                    .foregroundStyle(.secondary)
            }
        }
        .id(notificationAPNsDeliveryFocusID)

        Section("Notification Sync") {
            if let summary = viewModel.queuedWorkSummary {
                Text(summary)
            }
            if let notificationActionMessage {
                Text(notificationActionMessage)
            }
            if let notificationActionError {
                Text(notificationActionError)
                    .foregroundStyle(KitchenTableTheme.tomato)
            }
            OfflineStatusView(display: viewModel.offlineIndicator.display)
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
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Device", value: registration.deviceID)
            LabeledContent("Platform", value: registration.platform.rawValue)
            LabeledContent("Environment", value: registration.environment.rawValue)
            LabeledContent("State", value: registration.registrationState.rawValue)
        }
    }
}

private struct AppleDeveloperProgramBlockerView: View {
    let blocker: AppleDeveloperProgramBlocker
    let artifactFileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(blocker.capability, systemImage: "lock.shield.fill")
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
            Text(blocker.reason)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)
            Text(blocker.ownerAction)
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.tomato)
            Text(blocker.blocked ? "blocked" : "available")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(.secondary)
            LabeledContent("Artifact", value: artifactFileName)
                .font(KitchenTableTheme.bodyNote)
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
