import Foundation

public enum NotificationAPNsSurfaceConnectivity: Equatable, Sendable {
    case online
    case offline
}

public struct NotificationAPNsPermissionBanner: Equatable, Sendable {
    public let title: String
    public let message: String
    public let actionTitle: String

    public init(title: String, message: String, actionTitle: String) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
    }
}

public enum NotificationAPNsPermissionStatusToken: Equatable, Sendable {
    case denied
}

public enum NotificationAPNsNativeBridgeError: Error, Equatable, Sendable {
    case unavailable
    case deviceTokenRequestAlreadyPending
    case deviceTokenUnavailable
}

public enum NotificationAPNsAction: Equatable, Sendable {
    case updatePreferences(SettingsNotificationPreferences, clientMutationID: String)
    case requestPermission
    case registerDevice(
        deviceID: String,
        platform: NativeAPNSPlatform,
        environment: APNSEnvironment,
        token: String,
        deviceName: String?,
        appVersion: String?,
        clientMutationID: String
    )
    case revokeDevice(deviceID: String, clientMutationID: String)
}

public enum NotificationAPNsOnlineOnlyReason: Equatable, Sendable {
    case permissionPrompt
    case deviceTokenAcquisition

    public var message: String {
        switch self {
        case .permissionPrompt:
            return "Notification permission prompts are online-only and were not queued."
        case .deviceTokenAcquisition:
            return "Device token acquisition is online-only and was not queued."
        }
    }
}

public struct NotificationAPNsActionPlan: Equatable, Sendable {
    public let remoteRequestBuilder: APIRequestBuilder?
    public let queuedMutation: NativeQueuedMutation?
    public let offlineFallbackMutation: NativeQueuedMutation?
    public let onlineOnlyReason: NotificationAPNsOnlineOnlyReason?
    public let deliveryBlocker: AppleDeveloperProgramBlocker?
    public let userFacingMessage: String?

    public init(
        remoteRequestBuilder: APIRequestBuilder? = nil,
        queuedMutation: NativeQueuedMutation? = nil,
        offlineFallbackMutation: NativeQueuedMutation? = nil,
        onlineOnlyReason: NotificationAPNsOnlineOnlyReason? = nil,
        deliveryBlocker: AppleDeveloperProgramBlocker? = nil,
        userFacingMessage: String? = nil
    ) {
        self.remoteRequestBuilder = remoteRequestBuilder
        self.queuedMutation = queuedMutation
        self.offlineFallbackMutation = offlineFallbackMutation
        self.onlineOnlyReason = onlineOnlyReason
        self.deliveryBlocker = deliveryBlocker
        self.userFacingMessage = userFacingMessage
    }
}

public enum NotificationAPNsActionQueuePreflightDecision: Equatable, Sendable {
    case queueMutation(NativeQueuedMutation, drainImmediately: Bool)
}

public extension NotificationAPNsActionPlan {
    func queuePreflightDecision(queuedMutations: [NativeQueuedMutation]) -> NotificationAPNsActionQueuePreflightDecision? {
        if let queuedMutation {
            return .queueMutation(queuedMutation, drainImmediately: false)
        }

        guard let offlineFallbackMutation,
              queuedMutations.contains(where: { $0.blocksDependencyKey(offlineFallbackMutation.dependencyKey) }) else {
            return nil
        }

        return .queueMutation(offlineFallbackMutation, drainImmediately: true)
    }
}

public enum NotificationAPNsActionPlanningError: Error, Equatable, Sendable {
    case offlinePolicyRejectedQueueableMutation(NativeQueuedMutationKind)
    case offlinePolicyAllowedOnlineOnlyAction(NotificationAPNsOnlineOnlyReason)
}

public typealias NotificationAPNsOfflinePolicyDecision = @Sendable (NativeOfflineAction) throws -> NativeOfflineMutationDecision

public struct NotificationAPNsActionPlanner: Sendable {
    private let connectivity: NotificationAPNsSurfaceConnectivity
    private let deliveryCapability: APNsDeliveryCapability
    private let offlinePolicyDecision: NotificationAPNsOfflinePolicyDecision
    private let now: @Sendable () -> String

    public init(
        connectivity: NotificationAPNsSurfaceConnectivity,
        deliveryCapability: APNsDeliveryCapability = .developmentOnly(blocker: .localValidation),
        offlinePolicyDecision: @escaping NotificationAPNsOfflinePolicyDecision = NativeOfflineMutationPolicy.decision(for:),
        now: @escaping @Sendable () -> String = { ISO8601DateFormatter().string(from: Date()) }
    ) {
        self.connectivity = connectivity
        self.deliveryCapability = deliveryCapability
        self.offlinePolicyDecision = offlinePolicyDecision
        self.now = now
    }

    public func plan(_ action: NotificationAPNsAction) throws -> NotificationAPNsActionPlan {
        switch action {
        case .updatePreferences(let preferences, let clientMutationID):
            let mutation = NativeQueuedMutation.notificationPreferenceUpdate(
                notifySpoonOnMyRecipe: preferences.notifySpoonOnMyRecipe,
                notifyForkOfMyRecipe: preferences.notifyForkOfMyRecipe,
                notifyCookbookSaveOfMine: preferences.notifyCookbookSaveOfMine,
                notifyFellowChefOriginCook: preferences.notifyFellowChefOriginCook,
                clientMutationID: clientMutationID,
                createdAt: now()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.updateNotificationPreferences(
                    notifySpoonOnMyRecipe: preferences.notifySpoonOnMyRecipe,
                    notifyForkOfMyRecipe: preferences.notifyForkOfMyRecipe,
                    notifyCookbookSaveOfMine: preferences.notifyCookbookSaveOfMine,
                    notifyFellowChefOriginCook: preferences.notifyFellowChefOriginCook
                ),
                mutation: mutation
            )
        case .requestPermission:
            return try onlineOnlyPlan(reason: .permissionPrompt, offlineAction: NativeOfflineAction.apnsPermissionPrompt)
        case .registerDevice(
            let deviceID,
            let platform,
            let environment,
            let token,
            let deviceName,
            let appVersion,
            let clientMutationID
        ):
            let normalizedDeviceName = deviceName ?? "Spoonjoy device"
            let normalizedAppVersion = appVersion ?? "0.0.0"
            if let blocker = deliveryCapability.blocker(for: environment) {
                return NotificationAPNsActionPlan(
                    deliveryBlocker: blocker,
                    userFacingMessage: blocker.ownerAction
                )
            }
            let mutation = NativeQueuedMutation.apnsDeviceRegister(
                deviceID: deviceID,
                platform: platform,
                environment: environment,
                token: token,
                deviceName: deviceName,
                appVersion: appVersion,
                clientMutationID: clientMutationID,
                createdAt: now()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.registerAPNSDevice(
                    deviceID: deviceID,
                    platform: platform,
                    environment: environment,
                    token: token,
                    deviceName: normalizedDeviceName,
                    appVersion: normalizedAppVersion
                ),
                mutation: mutation
            )
        case .revokeDevice(let deviceID, let clientMutationID):
            let mutation = NativeQueuedMutation.apnsDeviceRevoke(
                deviceID: deviceID,
                clientMutationID: clientMutationID,
                createdAt: now()
            )
            return try queueablePlan(
                online: PrivateAccountRequests.revokeAPNSDevice(deviceID: deviceID),
                mutation: mutation
            )
        }
    }

    public func planDeviceTokenAcquisition() throws -> NotificationAPNsActionPlan {
        try onlineOnlyPlan(
            reason: .deviceTokenAcquisition,
            offlineAction: NativeOfflineAction.apnsDeviceTokenAcquisition
        )
    }

    private func queueablePlan(online: APIRequestBuilder, mutation: NativeQueuedMutation) throws -> NotificationAPNsActionPlan {
        let policyDecision = try offlinePolicyDecision(.queuedMutation(mutation))
        guard policyDecision.queueableKind == mutation.queueableKind else {
            throw NotificationAPNsActionPlanningError.offlinePolicyRejectedQueueableMutation(mutation.queueableKind)
        }

        switch connectivity {
        case .online:
            return NotificationAPNsActionPlan(remoteRequestBuilder: online, offlineFallbackMutation: mutation)
        case .offline:
            return NotificationAPNsActionPlan(queuedMutation: mutation, userFacingMessage: "Notification change queued.")
        }
    }

    private func onlineOnlyPlan(
        reason: NotificationAPNsOnlineOnlyReason,
        offlineAction: NativeOfflineAction
    ) throws -> NotificationAPNsActionPlan {
        let policyDecision = try offlinePolicyDecision(offlineAction)
        guard policyDecision.queueableKind == nil else {
            throw NotificationAPNsActionPlanningError.offlinePolicyAllowedOnlineOnlyAction(reason)
        }

        switch connectivity {
        case .online:
            return NotificationAPNsActionPlan(onlineOnlyReason: reason)
        case .offline:
            return NotificationAPNsActionPlan(
                onlineOnlyReason: reason,
                userFacingMessage: reason.message
            )
        }
    }
}

public struct NotificationAPNsSurfaceViewModel: Sendable {
    public let data: NotificationAPNsSurfaceData
    public let notificationDraft: SettingsNotificationPreferences
    public let apnsRegistration: APNsRegistrationSummary?
    public let permissionDeniedBanner: NotificationAPNsPermissionBanner?
    public let queuedWorkSummary: String?
    public let offlineIndicator: OfflineIndicatorState
    public let deliveryBlockerState: APNsDeliveryBlockerState
    public let productionBlocker: AppleDeveloperProgramBlocker?
    public let blockerArtifactFileName: String
    public let isRegistered: Bool
    public let lastValidatedAt: Date
    public let actionPlanner: NotificationAPNsActionPlanner
    public let connectivity: NotificationAPNsSurfaceConnectivity

    public init(
        data: NotificationAPNsSurfaceData,
        queuedMutations: [NativeQueuedMutation],
        connectivity: NotificationAPNsSurfaceConnectivity,
        now: @escaping @Sendable () -> Date
    ) {
        self.data = data
        notificationDraft = data.preferences
        apnsRegistration = data.apnsRegistration
        permissionDeniedBanner = Self.permissionDeniedBanner(for: data.permissionState)
        let notificationMutations = Self.notificationMutations(queuedMutations)
        queuedWorkSummary = Self.queuedWorkSummary(count: notificationMutations.count)
        deliveryBlockerState = data.deliveryCapability.blockerState
        productionBlocker = data.deliveryCapability.productionBlocker
        blockerArtifactFileName = "apple-developer-program-blocker-apns.json"
        isRegistered = data.apnsRegistration?.registrationState == .registered
        lastValidatedAt = Self.lastValidatedAt(from: data.source)
        offlineIndicator = Self.offlineIndicator(
            source: data.source,
            queuedMutations: notificationMutations,
            deliveryBlockerState: deliveryBlockerState,
            connectivity: connectivity,
            now: now()
        )
        self.connectivity = connectivity
        actionPlanner = NotificationAPNsActionPlanner(
            connectivity: connectivity,
            deliveryCapability: data.deliveryCapability,
            now: { ISO8601DateFormatter().string(from: now()) }
        )
    }

    private static func permissionDeniedBanner(for state: APNsPermissionState) -> NotificationAPNsPermissionBanner? {
        switch state {
        case .denied:
            return NotificationAPNsPermissionBanner(
                title: "Notifications are off in System Settings",
                message: "Turn on notifications for Spoonjoy in System Settings, then register this device again.",
                actionTitle: "Open System Settings"
            )
        case .authorized, .notDetermined:
            return nil
        }
    }

    private static func notificationMutations(_ mutations: [NativeQueuedMutation]) -> [NativeQueuedMutation] {
        mutations.filter { mutation in
            switch mutation.queueableKind {
            case .notificationPreferenceUpdate, .apnsDeviceRegister, .apnsDeviceRevoke:
                true
            default:
                false
            }
        }
    }

    private static func queuedWorkSummary(count: Int) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(count) notification \(count == 1 ? "change" : "changes") waiting to sync"
    }

    private static func lastValidatedAt(from source: NotificationAPNsSurfaceDataSource) -> Date {
        switch source {
        case .live(_, let validatedAt):
            return validatedAt
        case .cache(_, let lastValidatedAt):
            return lastValidatedAt
        }
    }

    private static func offlineIndicator(
        source: NotificationAPNsSurfaceDataSource,
        queuedMutations: [NativeQueuedMutation],
        deliveryBlockerState: APNsDeliveryBlockerState,
        connectivity: NotificationAPNsSurfaceConnectivity,
        now: Date
    ) -> OfflineIndicatorState {
        if !queuedMutations.isEmpty {
            return OfflineIndicatorState(
                display: .queuedWork(count: queuedMutations.count, oldestClientMutationID: queuedMutations.first?.clientMutationID),
                dismissal: nil
            )
        }

        switch deliveryBlockerState {
        case .developmentOnly:
            break
        case .blocked(let blocker):
            _ = blocker.ownerAction
            return OfflineIndicatorState(
                display: OfflineIndicatorDisplay.blocker(.appleDeveloperProgram(capability: blocker.capability)),
                dismissal: nil
            )
        }

        switch source {
        case .live:
            return OfflineIndicatorState(display: connectivity == .offline ? .offline : .synced, dismissal: nil)
        case .cache(_, let lastValidatedAt):
            if now.timeIntervalSince(lastValidatedAt) > 300 {
                return OfflineIndicatorState(display: .stale(domain: .notificationPreferences), dismissal: nil)
            }
            return OfflineIndicatorState(display: connectivity == .offline ? .offline : .synced, dismissal: nil)
        }
    }
}
