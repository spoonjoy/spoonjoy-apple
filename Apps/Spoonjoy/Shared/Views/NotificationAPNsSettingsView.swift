import SpoonjoyCore
import SwiftUI

private let notificationAPNsPermissionDeniedTitle = "Notifications are off in System Settings"
private let notificationAPNsPermissionDeniedActionTitle = "Open System Settings"
private let notificationAPNsDeviceFocusID = "settings-section-notification-apns-device"

struct NotificationAPNsDeviceSectionBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

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

    init(
        viewModel: NotificationAPNsSurfaceViewModel,
        performNotificationAPNsAction: @escaping @MainActor @Sendable (NotificationAPNsActionPlan) async throws -> Void,
        requestNotificationPermission: @escaping @MainActor @Sendable () async throws -> APNsPermissionState,
        requestDeviceRegistrationAction: @escaping @MainActor @Sendable (String) async throws -> NotificationAPNsAction,
        openNotificationSettings: @escaping @MainActor @Sendable () -> Void,
        onDismissOfflineIndicator: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.performNotificationAPNsAction = performNotificationAPNsAction
        self.requestNotificationPermission = requestNotificationPermission
        self.requestDeviceRegistrationAction = requestDeviceRegistrationAction
        self.openNotificationSettings = openNotificationSettings
        self.onDismissOfflineIndicator = onDismissOfflineIndicator
        _notifySpoonOnMyRecipe = State(initialValue: viewModel.notificationDraft.notifySpoonOnMyRecipe)
        _notifyForkOfMyRecipe = State(initialValue: viewModel.notificationDraft.notifyForkOfMyRecipe)
        _notifyCookbookSaveOfMine = State(initialValue: viewModel.notificationDraft.notifyCookbookSaveOfMine)
        _notifyFellowChefOriginCook = State(initialValue: viewModel.notificationDraft.notifyFellowChefOriginCook)
        _notificationDraftID = State(initialValue: Self.notificationIdentity(viewModel.notificationDraft))
    }

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
        .task(id: Self.notificationIdentity(viewModel.notificationDraft)) {
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
                if !notificationSaveDisabled(comparedWith: viewModel.notificationDraft) {
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
                }
            }
        }
    }

    private var deviceNotificationsSection: some View {
        KitchenTableSection(
            title: "This Device",
            subtitle: "Permission and delivery on this device",
            accessibilityHeaderIdentifier: "settings.apns.this-device.heading"
        ) {
            SettingsPanel {
                switch deviceSetupPresentation {
                case .permissionDenied:
                    if let banner = viewModel.permissionDeniedBanner {
                        notificationPermissionDeniedBanner(banner)
                    }

                case .permissionRequired:
                    Button {
                        requestNotificationPermissionAction()
                    } label: {
                        notificationRowLabel("Request Permission", systemImage: "bell.badge", prominence: .secondary)
                    }
                    .buttonStyle(.plain)

                case .registered(let registration):
                    if let banner = viewModel.permissionDeniedBanner {
                        notificationPermissionDeniedBanner(banner)
                    } else {
                        Label(deviceSetupReadyMessage, systemImage: "bell.badge")
                            .font(KitchenTableTheme.bodyNote.weight(.semibold))
                            .foregroundStyle(KitchenTableTheme.herb)
                    }
                    NotificationDiagnosticsDisclosure(
                        registration: registration,
                        blocker: nil,
                        artifactFileName: nil
                    )
                    Button(role: .destructive) {
                        pendingNotificationConfirmation = PendingNotificationAPNsConfirmation(
                            title: "Stop notifications here?",
                            message: "Spoonjoy will stop sending notifications to this device. If you are offline, the change will wait to sync.",
                            confirmButtonTitle: "Stop on This Device",
                            action: .revokeDevice(
                                deviceID: registration.deviceID,
                                clientMutationID: "cm_apns_revoke_\(UUID().uuidString)"
                            )
                        )
                    } label: {
                        notificationRowLabel("Stop on This Device", systemImage: "trash", prominence: .destructive)
                    }
                    .buttonStyle(.plain)

                case .registrationRequired:
                    Text("This device isn't set up for Spoonjoy notifications.")
                        .font(KitchenTableTheme.bodyNote)
                        .foregroundStyle(KitchenTableTheme.inkMuted)
                    Button {
                        requestDeviceRegistration()
                    } label: {
                        notificationRowLabel("Turn On for This Device", systemImage: "iphone.radiowaves.left.and.right", prominence: .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .id(notificationAPNsDeviceFocusID)
        .anchorPreference(key: NotificationAPNsDeviceSectionBoundsPreferenceKey.self, value: .bounds) { $0 }
    }

    private var deviceSetupPresentation: NotificationAPNsDeviceSetupPresentation {
        if viewModel.isRegistered, let registration = viewModel.apnsRegistration {
            return .registered(registration)
        }
        switch viewModel.data.permissionState {
        case .denied:
            return .permissionDenied
        case .notDetermined:
            return .permissionRequired
        case .authorized:
            return .registrationRequired
        }
    }

    private func notificationPermissionDeniedBanner(_ banner: NotificationAPNsPermissionBanner) -> some View {
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
    }

    private var apnsDeliverySection: some View {
        KitchenTableSection(
            title: "Push Delivery",
            subtitle: "Delivery to this device",
            accessibilityHeaderIdentifier: "settings.apns.push-delivery.heading"
        ) {
            SettingsPanel {
                switch deliveryBlockerState {
                case .developmentOnly(let blocker):
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
    }

    private var notificationSyncSection: some View {
        KitchenTableSection(
            title: "Notification Sync",
            subtitle: "Queued changes and offline state",
            accessibilityHeaderIdentifier: "settings.apns.notification-sync.heading"
        ) {
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
                notificationActionFailureBanner
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
                notificationActionError = notificationActionErrorMessage(for: error, fallback: "Notification permission could not be checked.")
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
                notificationActionError = notificationActionErrorMessage(for: error, fallback: "Device notifications could not be updated.")
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
            notificationActionError = notificationActionErrorMessage(for: error, fallback: "Notification settings could not be updated.")
        }
    }

    private var deliveryBlockerState: APNsDeliveryBlockerState {
        return viewModel.deliveryBlockerState
    }

    private var deviceSetupReadyMessage: String {
        switch deliveryBlockerState {
        case .developmentOnly, .blocked:
            "Your notification setup is saved."
        }
    }

    @ViewBuilder private var notificationActionFailureBanner: some View {
        if let notificationActionError {
            Label(notificationActionError, systemImage: "exclamationmark.triangle")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.tomato)
        }
    }

    private func notificationActionErrorMessage(for error: Error, fallback: String) -> String {
        "\(fallback) Try again. Code: \(notificationActionDiagnosticCode(for: error))."
    }

    private func notificationActionDiagnosticCode(for error: Error) -> String {
        if let bridgeError = error as? NotificationAPNsNativeBridgeError {
            switch bridgeError {
            case .unavailable:
                return "apns_bridge_unavailable"
            case .deviceTokenUnavailable:
                return "apns_device_token_unavailable"
            case .deviceTokenRequestAlreadyPending:
                return "apns_device_token_pending"
            case .deviceTokenRequestTimedOut:
                return "apns_device_token_timeout"
            }
        }
        if error is NotificationAPNsActionPlanningError {
            return "apns_plan"
        }
        if let transportError = error as? APITransportError {
            if let apiError = transportError.apiError {
                return "apns_api_\(apiError.code)_\(apiError.status)"
            }
            if let statusCode = transportError.statusCode {
                return "apns_http_\(statusCode)"
            }
            return "apns_transport"
        }
        return "apns_unexpected"
    }

    private func hydrateNotificationDraft(_ preferences: SettingsNotificationPreferences) {
        let identity = Self.notificationIdentity(preferences)
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

    private static func notificationIdentity(_ preferences: SettingsNotificationPreferences) -> String {
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

private enum NotificationAPNsDeviceSetupPresentation {
    case permissionDenied
    case permissionRequired
    case registered(APNsRegistrationSummary)
    case registrationRequired
}

private struct AppleDeveloperProgramBlockerView: View {
    let blocker: AppleDeveloperProgramBlocker
    let artifactFileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Push delivery isn't available yet.", systemImage: "lock.shield.fill")
                .font(KitchenTableTheme.objectTitle)
                .foregroundStyle(KitchenTableTheme.charcoal)
            Text("Your preferences are saved.")
                .font(KitchenTableTheme.bodyNote)
                .foregroundStyle(KitchenTableTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            NotificationDiagnosticsDisclosure(
                registration: nil,
                blocker: blocker,
                artifactFileName: artifactFileName
            )
        }
    }

    private var blockerCapabilityContractAnchor: String {
        blocker.capability
    }

    private var blockerOwnerActionContractAnchor: String {
        blocker.ownerAction
    }
}

private struct NotificationDiagnosticsDisclosure: View {
    let registration: APNsRegistrationSummary?
    let blocker: AppleDeveloperProgramBlocker?
    let artifactFileName: String?

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                if let registration {
                    NotificationFactRow(title: "Device ID", value: registration.deviceID)
                    NotificationFactRow(title: "Platform", value: platformLabel(registration.platform))
                    NotificationFactRow(title: "Delivery lane", value: environmentLabel(registration.environment))
                    NotificationFactRow(title: "Setup", value: registrationStateLabel(registration.registrationState))
                }
                if let blocker {
                    NotificationFactRow(title: "Delivery capability", value: blocker.blocked ? "Limited" : "Available")
                    if let artifactFileName {
                        NotificationFactRow(title: "Support note", value: artifactFileName)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Details", systemImage: "info.circle")
                .font(KitchenTableTheme.bodyNote.weight(.semibold))
                .foregroundStyle(KitchenTableTheme.inkMuted)
        }
    }

    private func platformLabel(_ platform: NativeAPNSPlatform) -> String {
        switch platform {
        case .ios:
            "iPhone"
        case .macos:
            "Mac"
        }
    }

    private func environmentLabel(_ environment: APNSEnvironment) -> String {
        switch environment {
        case .development:
            "Local validation"
        case .production:
            "Production"
        }
    }

    private func registrationStateLabel(_ state: NativeAPNSRegistrationState) -> String {
        switch state {
        case .registered:
            "Ready"
        case .unregistered:
            "Not set up"
        }
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
