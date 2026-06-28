import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native notification preferences and APNs surface parity")
struct NotificationAPNsSurfaceTests {
    private static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("notification APNs surface exists as a first-class native feature")
    func notificationAPNsSurfaceExistsAsFirstClassNativeFeature() throws {
        let failures = sourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift",
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift",
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift",
                "Apps/Spoonjoy/Shared/Native/NotificationAPNsDeviceBridge.swift",
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift": [
                    "NotificationAPNsSurfaceRepository",
                    "LiveNotificationAPNsSurfaceRepository",
                    "SnapshotNotificationAPNsSurfaceRepository",
                    "FallbackNotificationAPNsSurfaceRepository",
                    "NotificationAPNsSurfaceData",
                    "APNsRegistrationSummary",
                    "APNsPermissionState",
                    "APNsDeliveryCapability",
                    "AppleDeveloperProgramBlocker",
                    "SettingsNotificationPreferences",
                    "PrivateAccountRequests.notificationPreferences",
                    "PrivateAccountRequests.registerAPNSDevice",
                    "PrivateAccountRequests.revokeAPNSDevice",
                    "NativeCacheDomain.notificationPreferences",
                    "NativeCacheDomain.apnsStatus",
                    "NativeCachePayload.notificationPreferenceState",
                    "NativeCachePayload.apnsStatus"
                ],
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift": [
                    "NotificationAPNsSurfaceViewModel",
                    "NotificationAPNsActionPlanner",
                    "NotificationAPNsActionPlan",
                    "case updatePreferences",
                    "case requestPermission",
                    "case registerDevice",
                    "case revokeDevice",
                    "case denied",
                    "NativeQueuedMutation.notificationPreferenceUpdate",
                    "NativeQueuedMutation.apnsDeviceRegister",
                    "NativeQueuedMutation.apnsDeviceRevoke",
                    "NativeOfflineMutationPolicy.decision",
                    "NativeOfflineAction.apnsPermissionPrompt",
                    "NativeOfflineAction.apnsDeviceTokenAcquisition",
                    "OfflineIndicatorState",
                    "OfflineIndicatorDisplay.blocker",
                    "APNsDeliveryBlockerState"
                ],
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift": [
                    "NotificationAPNsSettingsView",
                    "NotificationAPNsSurfaceViewModel",
                    "SettingsNotificationPreferences",
                    "Toggle",
                    "Button",
                    "APNsRegistrationSummary",
                    "AppleDeveloperProgram",
                    "OfflineStatusView",
                    "confirmationDialog(",
                    "requestNotificationPermission",
                    "requestDeviceRegistrationAction",
                    "KitchenTableTheme",
                    "notificationAPNsDeliveryFocusID"
                ],
                "Apps/Spoonjoy/Shared/Native/NotificationAPNsDeviceBridge.swift": [
                    "NotificationAPNsDeviceBridge",
                    "UNUserNotificationCenter.current().requestAuthorization",
                    "registerForRemoteNotifications",
                    "didRegisterForRemoteNotifications",
                    "NotificationAPNsAction",
                    "NativeAPNSRuntimeDefaults.currentPlatform"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "NotificationAPNsSettingsView(",
                    "notificationAPNsSurfaceViewModel",
                    "performNotificationAPNsAction",
                    "requestNotificationPermission",
                    "requestDeviceRegistrationAction",
                    "queueNotificationAPNsMutationIfNeeded",
                    "recordNotificationAPNsBlocker"
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "notificationAPNsSurfaceViewModel",
                    "NotificationAPNsSurfaceViewModel",
                    "notificationAPNsSurfaceData",
                    "restoreNotificationAPNsSnapshot"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "notification APNs surface",
                    "NotificationAPNsActionPlanner",
                    ".apnsDeviceRegister",
                    "AppleDeveloperProgramBlocker.localValidation"
                ]
            ],
            forbiddenTokens: [
                "RecipeComments",
                "SocialFeed",
                "MessageComposer",
                "MailCompose",
                "productionAPNsAvailable = true",
                "fakeAPNsDelivery",
                "sendTestPushNotification",
                "TestFlightAvailable"
            ],
            stringAllowedTokens: [
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift": [
                    "apple-developer-program-blocker-apns.json"
                ],
                "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift": [
                    "permissionDenied",
                    "Notifications are off in System Settings",
                    "Open System Settings",
                    "Register This Device",
                    "settings-section-notification-apns-delivery"
                ]
            ]
        )

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("APNs action boundary queues only after a system device token exists")
    func apnsActionBoundaryQueuesOnlyAfterSystemDeviceTokenExists() throws {
        let preferenceMutation = NativeQueuedMutation.notificationPreferenceUpdate(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false,
            clientMutationID: "cm_notifications",
            createdAt: "2026-06-28T08:00:00.000Z"
        )
        let registerMutation = NativeQueuedMutation.apnsDeviceRegister(
            deviceID: "device_ios_1",
            platform: .ios,
            environment: .development,
            token: "apns-token-value",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_apns_register",
            createdAt: "2026-06-28T08:01:00.000Z"
        )
        let revokeMutation = NativeQueuedMutation.apnsDeviceRevoke(
            deviceID: "device_ios_1",
            clientMutationID: "cm_apns_revoke",
            createdAt: "2026-06-28T08:02:00.000Z"
        )

        #expect(try NativeOfflineMutationPolicy.decision(for: .queuedMutation(preferenceMutation)).queueableKind == .notificationPreferenceUpdate)
        #expect(try NativeOfflineMutationPolicy.decision(for: .queuedMutation(registerMutation)).queueableKind == .apnsDeviceRegister)
        #expect(try NativeOfflineMutationPolicy.decision(for: .queuedMutation(revokeMutation)).queueableKind == .apnsDeviceRevoke)
        #expect(try NativeOfflineMutationPolicy.decision(for: .apnsPermissionPrompt).onlineOnlyReason == "Notification permission prompts are online-only and were not queued.")
        #expect(try NativeOfflineMutationPolicy.decision(for: .apnsDeviceTokenAcquisition).onlineOnlyReason == "Device token acquisition is online-only and was not queued.")

        try assertJSONRequest(registerMutation.requestBuilder().urlRequest(configuration: Self.configuration), method: .post, path: "/api/v1/me/apns-devices", expected: [
            "clientMutationId": "cm_apns_register",
            "deviceId": "device_ios_1",
            "platform": "ios",
            "environment": "development",
            "token": "apns-token-value",
            "deviceName": "Ari's iPhone",
            "appVersion": "1.0.0"
        ])
        assertRequest(
            try revokeMutation.requestBuilder().urlRequest(configuration: Self.configuration),
            method: .delete,
            path: "/api/v1/me/apns-devices/device_ios_1",
            authorization: "Bearer sj_private_token",
            responseCachePolicy: .privateNoStore
        )
    }

    @Test("APNs register and revoke request builders use exact native REST contracts")
    func apnsRegisterAndRevokeRequestBuildersUseExactNativeRESTContracts() throws {
        let register = try SnapshotNotificationAPNsSurfaceRepository.registerRequest(
            deviceID: "device/ios 1",
            platform: .ios,
            environment: .production,
            token: "production-token",
            deviceName: "Kitchen iPad",
            appVersion: "2.0.0"
        )
        .urlRequest(configuration: Self.configuration)
        let revoke = try SnapshotNotificationAPNsSurfaceRepository.revokeRequest(deviceID: "device/ios 1")
            .urlRequest(configuration: Self.configuration)

        try assertJSONRequest(register, method: .post, path: "/api/v1/me/apns-devices", expected: [
            "deviceId": "device/ios 1",
            "platform": "ios",
            "environment": "production",
            "token": "production-token",
            "deviceName": "Kitchen iPad",
            "appVersion": "2.0.0"
        ])
        assertRequest(
            revoke,
            method: .delete,
            path: "/api/v1/me/apns-devices/device%2Fios%201",
            authorization: "Bearer sj_private_token",
            responseCachePolicy: .privateNoStore
        )
        #expect(revoke.body == nil)
    }

    @Test("live and fallback notification APNs repositories restore server preferences")
    func liveAndFallbackNotificationAPNsRepositoriesRestoreServerPreferences() async throws {
        let validatedAt = Date(timeIntervalSince1970: 1_782_901_234)
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: false,
            notifyFellowChefOriginCook: true
        )
        let transport = RecordingNotificationAPNsSettingsTransport(
            preferences: preferences,
            validatedAt: validatedAt
        )
        let liveRepository = LiveNotificationAPNsSurfaceRepository(
            transport: transport,
            configuration: Self.configuration,
            permissionState: .authorized(lastCheckedAt: validatedAt),
            deliveryCapability: .developmentOnly(blocker: .localValidation)
        )

        let liveData = try await liveRepository.restore()

        #expect(transport.requestPaths == ["/api/v1/me/notification-preferences"])
        #expect(liveData.preferences == preferences)
        #expect(liveData.apnsRegistration == nil)
        #expect(liveData.permissionState == .authorized(lastCheckedAt: validatedAt))
        #expect(liveData.deliveryCapability.blockerState == .developmentOnly(.localValidation))
        #expect(liveData.deliveryCapability.productionBlocker == .localValidation)
        #expect(liveData.deliveryCapability.blocker(for: .development) == nil)
        #expect(liveData.deliveryCapability.blocker(for: .production) == .localValidation)
        #expect(APNsDeliveryCapability.blocked(.localValidation).blocker(for: .development) == .localValidation)
        #expect(APNsDeliveryCapability.blocked(.localValidation).blocker(for: .production) == .localValidation)
        #expect(liveData.source == .live(requestID: "req_notification_apns", validatedAt: validatedAt))

        let primarySuccess = FallbackNotificationAPNsSurfaceRepository(
            primary: StubNotificationAPNsSurfaceRepository(data: liveData),
            fallback: StubNotificationAPNsSurfaceRepository(error: NotificationAPNsTestFailure.unexpectedRequest)
        )
        #expect(try await primarySuccess.restore() == liveData)

        let fallbackData = NotificationAPNsSurfaceData(
            preferences: .disabled,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            source: .cache(serverRevision: nil, lastValidatedAt: validatedAt.addingTimeInterval(-60))
        )
        let primaryFailure = FallbackNotificationAPNsSurfaceRepository(
            primary: StubNotificationAPNsSurfaceRepository(error: NotificationAPNsTestFailure.unexpectedRequest),
            fallback: StubNotificationAPNsSurfaceRepository(data: fallbackData)
        )
        #expect(try await primaryFailure.restore() == fallbackData)
    }

    @Test("offline cached notification preferences and APNs status restore into the native surface")
    @MainActor
    func offlineCachedNotificationPreferencesAndAPNsStatusRestoreIntoNativeSurface() async throws {
        let now = Date(timeIntervalSince1970: 1_782_901_800)
        let fetchedAt = Date(timeIntervalSince1970: 1_782_900_000)
        let lastValidatedAt = Date(timeIntervalSince1970: 1_782_899_000)
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: true,
            notifyCookbookSaveOfMine: false,
            notifyFellowChefOriginCook: true
        )
        let notificationRecord = try cacheRecord(
            domain: .notificationPreferences,
            sourceEndpoint: "/api/v1/me/notification-preferences",
            serverRevision: .etag("\"notifications-v2\""),
            payload: .notificationPreferenceState(preferences),
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt
        )
        let apnsRecord = try cacheRecord(
            domain: .apnsStatus,
            sourceEndpoint: "/api/v1/me/apns-devices",
            serverRevision: .etag("\"apns-device-v1\""),
            payload: .apnsStatus(deviceID: "device_ios_1", registrationState: .registered),
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt
        )
        let cache = NativeDurableCache(records: [notificationRecord, apnsRecord])

        #expect(cache.record(for: .notificationPreferences)?.payload == .notificationPreferenceState(preferences))
        #expect(cache.record(for: .apnsStatus)?.payload == .apnsStatus(deviceID: "device_ios_1", registrationState: .registered))

        let repository = SnapshotNotificationAPNsSurfaceRepository(
            cache: cache,
            environment: .production,
            permissionState: .denied(lastCheckedAt: lastValidatedAt),
            fallbackValidatedAt: now
        )
        let data = try await repository.restore()
        #expect(data.preferences == preferences)
        #expect(data.apnsRegistration == APNsRegistrationSummary(
            deviceID: "device_ios_1",
            platform: NativeAPNSRuntimeDefaults.currentPlatform,
            environment: NativeAPNSRuntimeDefaults.currentEnvironment,
            registrationState: .registered,
            lastValidatedAt: lastValidatedAt
        ))
        #expect(data.permissionState == .denied(lastCheckedAt: lastValidatedAt))
        #expect(data.source == .cache(serverRevision: .etag("\"apns-device-v1\""), lastValidatedAt: lastValidatedAt))

        let viewModel = NotificationAPNsSurfaceViewModel(
            data: data,
            queuedMutations: [],
            connectivity: .offline,
            now: { now }
        )

        #expect(viewModel.notificationDraft == preferences)
        #expect(viewModel.apnsRegistration?.deviceID == "device_ios_1")
        #expect(viewModel.apnsRegistration?.registrationState == .registered)
        #expect(viewModel.permissionDeniedBanner == NotificationAPNsPermissionBanner(
            title: "Notifications are off in System Settings",
            message: "Turn on notifications for Spoonjoy in System Settings, then register this device again.",
            actionTitle: "Open System Settings"
        ))
        #expect(viewModel.deliveryBlockerState == .developmentOnly(.localValidation))
        #expect(viewModel.productionBlocker == .localValidation)
        #expect(viewModel.offlineIndicator.display == .stale(domain: .notificationPreferences))
        #expect(viewModel.lastValidatedAt == lastValidatedAt)
    }

    @Test("snapshot notification APNs repository restores legacy defaults and invalid status edges")
    func snapshotNotificationAPNsRepositoryRestoresLegacyDefaultsAndInvalidStatusEdges() async throws {
        let now = Date(timeIntervalSince1970: 1_782_902_000)
        let fetchedAt = Date(timeIntervalSince1970: 1_782_901_000)
        let lastValidatedAt = Date(timeIntervalSince1970: 1_782_901_500)
        let legacyRecord = try cacheRecord(
            domain: .notificationPreferences,
            sourceEndpoint: "/api/v1/me/notification-preferences",
            serverRevision: .etag("\"legacy-notifications\""),
            payload: .notificationPreferences(marketingEnabled: true, cookingRemindersEnabled: false),
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt
        )
        let invalidAPNsRecord = try cacheRecord(
            domain: .apnsStatus,
            sourceEndpoint: "/api/v1/me/apns-devices",
            serverRevision: .etag("\"invalid-apns\""),
            payload: .empty,
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt.addingTimeInterval(10)
        )
        let emptyPreferenceRecord = try cacheRecord(
            domain: .notificationPreferences,
            sourceEndpoint: "/api/v1/me/notification-preferences",
            serverRevision: .etag("\"empty-notifications\""),
            payload: .empty,
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt.addingTimeInterval(20)
        )

        let legacyData = SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(records: [legacyRecord]),
            environment: .production,
            fallbackValidatedAt: now
        )
        .restoreSynchronously()

        #expect(legacyData.preferences == SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        ))
        #expect(legacyData.apnsRegistration == nil)
        #expect(legacyData.source == .cache(serverRevision: .etag("\"legacy-notifications\""), lastValidatedAt: lastValidatedAt))

        let invalidStatusData = SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(records: [invalidAPNsRecord]),
            environment: .production,
            fallbackValidatedAt: now
        )
        .restoreSynchronously()
        #expect(invalidStatusData.preferences == .disabled)
        #expect(invalidStatusData.apnsRegistration == nil)
        #expect(invalidStatusData.source == .cache(serverRevision: .etag("\"invalid-apns\""), lastValidatedAt: lastValidatedAt.addingTimeInterval(10)))

        let emptyPreferenceData = SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(records: [emptyPreferenceRecord]),
            environment: .production,
            fallbackValidatedAt: now
        )
        .restoreSynchronously()
        #expect(emptyPreferenceData.preferences == .disabled)
        #expect(emptyPreferenceData.apnsRegistration == nil)
        #expect(emptyPreferenceData.source == .cache(serverRevision: .etag("\"empty-notifications\""), lastValidatedAt: lastValidatedAt.addingTimeInterval(20)))

        let emptyData = SnapshotNotificationAPNsSurfaceRepository(
            cache: NativeDurableCache(),
            environment: .production,
            fallbackValidatedAt: now
        )
        .restoreSynchronously()
        #expect(emptyData.preferences == .disabled)
        #expect(emptyData.source == .cache(serverRevision: nil, lastValidatedAt: now))
    }

    @Test("notification APNs data restores from settings surface sources")
    func notificationAPNsDataRestoresFromSettingsSurfaceSources() {
        let validatedAt = Date(timeIntervalSince1970: 1_782_905_000)
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: false,
            notifyForkOfMyRecipe: true,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        )
        let liveSettings = SettingsSurfaceData(
            account: nil,
            notifications: preferences,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .live(requestID: "req_settings", validatedAt: validatedAt)
        )
        let cacheSettings = SettingsSurfaceData(
            account: nil,
            notifications: preferences,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .cache(lastValidatedAt: validatedAt.addingTimeInterval(-10))
        )
        let missingNotifications = SettingsSurfaceData(
            account: nil,
            notifications: nil,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .live(requestID: "req_missing_notifications", validatedAt: validatedAt)
        )

        let liveData = NotificationAPNsSurfaceData.restoredFromSettingsSurface(liveSettings, environment: .production)
        let cacheData = NotificationAPNsSurfaceData.restoredFromSettingsSurface(cacheSettings, environment: .production)
        let overriddenSource = NotificationAPNsSurfaceData.restoredFromSettingsSurface(
            liveSettings,
            environment: .production,
            source: .live(requestID: "req_override", validatedAt: validatedAt.addingTimeInterval(5))
        )

        #expect(liveData?.preferences == preferences)
        #expect(liveData?.source == .cache(serverRevision: nil, lastValidatedAt: validatedAt))
        #expect(cacheData?.source == .cache(serverRevision: nil, lastValidatedAt: validatedAt.addingTimeInterval(-10)))
        #expect(overriddenSource?.source == .live(requestID: "req_override", validatedAt: validatedAt.addingTimeInterval(5)))
        #expect(NotificationAPNsSurfaceData.restoredFromSettingsSurface(nil, environment: .production) == nil)
        #expect(NotificationAPNsSurfaceData.restoredFromSettingsSurface(missingNotifications, environment: .production) == nil)
    }

    @Test("production APNs registration is blocked until Apple Developer Program capability exists")
    func productionAPNsRegistrationIsBlockedUntilAppleDeveloperProgramCapabilityExists() throws {
        let planner = NotificationAPNsActionPlanner(
            connectivity: .online,
            deliveryCapability: .developmentOnly(blocker: .localValidation)
        )

        let blockedPlan = try planner.plan(.registerDevice(
            deviceID: "device_ios_1",
            platform: .ios,
            environment: .production,
            token: "production-token",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_apns_production"
        ))

        #expect(blockedPlan.remoteRequestBuilder == nil)
        #expect(blockedPlan.queuedMutation == nil)
        #expect(blockedPlan.deliveryBlocker == .localValidation)
        #expect(blockedPlan.userFacingMessage == AppleDeveloperProgramBlocker.localValidation.ownerAction)

        let developmentPlan = try planner.plan(.registerDevice(
            deviceID: "device_ios_1",
            platform: .ios,
            environment: .development,
            token: "development-token",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_apns_development"
        ))
        #expect(developmentPlan.remoteRequestBuilder != nil)
        #expect(developmentPlan.offlineFallbackMutation?.queueableKind == .apnsDeviceRegister)
    }

    @Test("notification APNs planner covers queued online only and error decisions")
    func notificationAPNsPlannerCoversQueuedOnlineOnlyAndErrorDecisions() throws {
        let now = "2026-06-28T09:00:00.000Z"
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: true,
            notifyCookbookSaveOfMine: false,
            notifyFellowChefOriginCook: false
        )
        let onlinePlanner = NotificationAPNsActionPlanner(
            connectivity: .online,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            now: { now }
        )
        let offlinePlanner = NotificationAPNsActionPlanner(
            connectivity: .offline,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            now: { now }
        )

        let onlinePreference = try onlinePlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_notifications_update"))
        let preferenceFallback = try #require(onlinePreference.offlineFallbackMutation)
        try assertJSONRequest(try #require(onlinePreference.remoteRequestBuilder).urlRequest(configuration: Self.configuration), method: .patch, path: "/api/v1/me/notification-preferences", expected: [
            "notifySpoonOnMyRecipe": true,
            "notifyForkOfMyRecipe": true,
            "notifyCookbookSaveOfMine": false,
            "notifyFellowChefOriginCook": false
        ])
        #expect(preferenceFallback.queueableKind == .notificationPreferenceUpdate)
        #expect(onlinePreference.queuePreflightDecision(queuedMutations: []) == nil)
        #expect(onlinePreference.queuePreflightDecision(queuedMutations: [preferenceFallback]) == .queueMutation(preferenceFallback, drainImmediately: true))

        let offlinePreference = try offlinePlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_notifications_offline"))
        let queuedPreference = try #require(offlinePreference.queuedMutation)
        #expect(queuedPreference.queueableKind == .notificationPreferenceUpdate)
        #expect(offlinePreference.userFacingMessage == "Notification change queued.")
        #expect(offlinePreference.queuePreflightDecision(queuedMutations: []) == .queueMutation(queuedPreference, drainImmediately: false))

        let defaultedRegister = try onlinePlanner.plan(.registerDevice(
            deviceID: "device_defaulted",
            platform: .macos,
            environment: .development,
            token: "defaulted-token",
            deviceName: nil,
            appVersion: nil,
            clientMutationID: "cm_defaulted_register"
        ))
        try assertJSONRequest(try #require(defaultedRegister.remoteRequestBuilder).urlRequest(configuration: Self.configuration), method: .post, path: "/api/v1/me/apns-devices", expected: [
            "deviceId": "device_defaulted",
            "platform": "macos",
            "environment": "development",
            "token": "defaulted-token",
            "deviceName": "Spoonjoy device",
            "appVersion": "0.0.0"
        ])

        let offlineRevoke = try offlinePlanner.plan(.revokeDevice(deviceID: "device_defaulted", clientMutationID: "cm_revoke_offline"))
        #expect(offlineRevoke.queuedMutation?.queueableKind == .apnsDeviceRevoke)
        #expect(offlineRevoke.userFacingMessage == "Notification change queued.")

        let onlineRevoke = try onlinePlanner.plan(.revokeDevice(deviceID: "device_defaulted", clientMutationID: "cm_revoke_online"))
        assertRequest(
            try #require(onlineRevoke.remoteRequestBuilder).urlRequest(configuration: Self.configuration),
            method: .delete,
            path: "/api/v1/me/apns-devices/device_defaulted",
            authorization: "Bearer sj_private_token",
            responseCachePolicy: .privateNoStore
        )

        let permissionPrompt = try onlinePlanner.plan(.requestPermission)
        #expect(permissionPrompt.onlineOnlyReason == .permissionPrompt)
        #expect(permissionPrompt.userFacingMessage == nil)

        let offlinePermissionPrompt = try offlinePlanner.plan(.requestPermission)
        #expect(offlinePermissionPrompt.onlineOnlyReason == .permissionPrompt)
        #expect(offlinePermissionPrompt.userFacingMessage == "Notification permission prompts are online-only and were not queued.")

        let onlineTokenAcquisition = try onlinePlanner.planDeviceTokenAcquisition()
        #expect(onlineTokenAcquisition.onlineOnlyReason == .deviceTokenAcquisition)

        let rejectedQueuePlanner = NotificationAPNsActionPlanner(
            connectivity: .online,
            offlinePolicyDecision: { _ in NativeOfflineMutationDecision(queueableKind: .apnsDeviceRevoke, onlineOnlyReason: nil) },
            now: { now }
        )
        #expect(throws: NotificationAPNsActionPlanningError.offlinePolicyRejectedQueueableMutation(.notificationPreferenceUpdate)) {
            try rejectedQueuePlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_rejected"))
        }

        let invalidOnlineOnlyPlanner = NotificationAPNsActionPlanner(
            connectivity: .online,
            offlinePolicyDecision: { _ in NativeOfflineMutationDecision(queueableKind: .apnsDeviceRegister, onlineOnlyReason: nil) },
            now: { now }
        )
        #expect(throws: NotificationAPNsActionPlanningError.offlinePolicyAllowedOnlineOnlyAction(.permissionPrompt)) {
            try invalidOnlineOnlyPlanner.plan(.requestPermission)
        }
    }

    @Test("notification APNs view model renders queued live cache stale and synced states")
    func notificationAPNsViewModelRendersQueuedLiveCacheStaleAndSyncedStates() throws {
        let now = Date(timeIntervalSince1970: 1_782_910_000)
        let recent = now.addingTimeInterval(-120)
        let stale = now.addingTimeInterval(-301)
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        )
        let liveData = NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: nil,
            permissionState: .authorized(lastCheckedAt: recent),
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            source: .live(requestID: "req_live_notifications", validatedAt: recent)
        )
        let queuedPreference = NativeQueuedMutation.notificationPreferenceUpdate(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false,
            clientMutationID: "cm_queued_notifications",
            createdAt: "2026-06-28T09:10:00.000Z"
        )
        let queuedRevoke = NativeQueuedMutation.apnsDeviceRevoke(
            deviceID: "device_queued",
            clientMutationID: "cm_queued_revoke",
            createdAt: "2026-06-28T09:11:00.000Z"
        )
        let unrelatedShopping = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: 2,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_unrelated_shopping",
            createdAt: "2026-06-28T09:12:00.000Z"
        )

        let queuedViewModel = NotificationAPNsSurfaceViewModel(
            data: liveData,
            queuedMutations: [queuedPreference, unrelatedShopping, queuedRevoke],
            connectivity: .online,
            now: { now }
        )
        #expect(queuedViewModel.queuedWorkSummary == "2 notification changes waiting to sync")
        #expect(queuedViewModel.offlineIndicator.display == .queuedWork(count: 2, oldestClientMutationID: "cm_queued_notifications"))
        #expect(queuedViewModel.permissionDeniedBanner == nil)
        #expect(queuedViewModel.deliveryBlockerState == .developmentOnly(.localValidation))
        #expect(queuedViewModel.productionBlocker == .localValidation)
        #expect(queuedViewModel.isRegistered == false)
        #expect(queuedViewModel.lastValidatedAt == recent)
        #expect(try queuedViewModel.actionPlanner.plan(.requestPermission).onlineOnlyReason == .permissionPrompt)
        let queuedViewModelUpdate = try queuedViewModel.actionPlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_view_model_update"))
        #expect(queuedViewModelUpdate.offlineFallbackMutation?.createdAt == ISO8601DateFormatter().string(from: now))

        let singleQueuedViewModel = NotificationAPNsSurfaceViewModel(
            data: liveData,
            queuedMutations: [queuedPreference],
            connectivity: .online,
            now: { now }
        )
        #expect(singleQueuedViewModel.queuedWorkSummary == "1 notification change waiting to sync")

        let liveOnline = NotificationAPNsSurfaceViewModel(
            data: liveData,
            queuedMutations: [],
            connectivity: .online,
            now: { now }
        )
        #expect(liveOnline.offlineIndicator.display == .synced)

        let liveOffline = NotificationAPNsSurfaceViewModel(
            data: liveData,
            queuedMutations: [],
            connectivity: .offline,
            now: { now }
        )
        #expect(liveOffline.offlineIndicator.display == .offline)

        let freshCacheData = NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            source: .cache(serverRevision: nil, lastValidatedAt: recent)
        )
        let freshOnline = NotificationAPNsSurfaceViewModel(
            data: freshCacheData,
            queuedMutations: [],
            connectivity: .online,
            now: { now }
        )
        #expect(freshOnline.offlineIndicator.display == .synced)

        let freshOffline = NotificationAPNsSurfaceViewModel(
            data: freshCacheData,
            queuedMutations: [],
            connectivity: .offline,
            now: { now }
        )
        #expect(freshOffline.offlineIndicator.display == .offline)

        let staleCacheData = NotificationAPNsSurfaceData(
            preferences: preferences,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            source: .cache(serverRevision: nil, lastValidatedAt: stale)
        )
        let staleViewModel = NotificationAPNsSurfaceViewModel(
            data: staleCacheData,
            queuedMutations: [],
            connectivity: .online,
            now: { now }
        )
        #expect(staleViewModel.offlineIndicator.display == .stale(domain: .notificationPreferences))

        let blockedViewModel = NotificationAPNsSurfaceViewModel(
            data: NotificationAPNsSurfaceData(
                preferences: preferences,
                apnsRegistration: nil,
                permissionState: .notDetermined,
                deliveryCapability: .blocked(.localValidation),
                source: .live(requestID: "req_blocked_notifications", validatedAt: recent)
            ),
            queuedMutations: [],
            connectivity: .online,
            now: { now }
        )
        #expect(blockedViewModel.deliveryBlockerState == .blocked(.localValidation))
        #expect(blockedViewModel.offlineIndicator.display == .blocker(.appleDeveloperProgram(capability: AppleDeveloperProgramBlocker.capabilityName)))
    }

    @Test("source scanners strip comments and preserve strings only for string-allowed checks")
    func sourceScannersStripCommentsAndPreserveStringsOnlyForStringAllowedChecks() {
        let source = """
        // AppleDeveloperProgramBlocker should disappear from comments.
        let blockerPath = "apple-developer-program-blocker-apns.json"
        let url = "https://example.test/sendPushNotification"
        /*
         APNsDeliveryBlockerState should disappear from block comments.
         */
        let state = APNsDeliveryBlockerState.blocked
        let multiline = \"\"\"
        AppleDeveloperProgramBlocker inside a multiline string should not satisfy typed scans.
        \"\"\"
        let raw = #"APNsDeliveryBlockerState inside a raw string should not satisfy typed scans."#
        """

        let uncommented = uncommentedSwift(source)
        #expect(!uncommented.contains("should disappear from comments"))
        #expect(!uncommented.contains("should disappear from block comments"))
        #expect(uncommented.contains(#""apple-developer-program-blocker-apns.json""#))
        #expect(uncommented.contains(#""https://example.test/sendPushNotification""#))
        #expect(uncommented.contains("APNsDeliveryBlockerState.blocked"))

        let contractSource = swiftContractSource(source)
        #expect(!contractSource.contains("AppleDeveloperProgramBlocker"))
        #expect(!contractSource.contains("apple-developer-program-blocker-apns.json"))
        #expect(!contractSource.contains("sendPushNotification"))
        #expect(contractSource.contains("APNsDeliveryBlockerState.blocked"))
    }

    @Test("production APNs delivery is represented only by the Apple Developer Program blocker")
    func productionAPNsDeliveryIsRepresentedOnlyByAppleDeveloperProgramBlocker() throws {
        let root = repoRoot()
        let blockerConsumers = [
            "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift",
            "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift",
            "Apps/Spoonjoy/Shared/Views/NotificationAPNsSettingsView.swift"
        ]

        let consumerFailures = blockerConsumers.flatMap { relativePath -> [String] in
            let fileURL = root.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return ["missing APNs blocker consumer: \(relativePath)"]
            }

            let rawContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let typedContent = swiftContractSource(rawContent)
            let stringAllowedContent = uncommentedSwift(rawContent)
            return [
                "AppleDeveloperProgramBlocker",
                "APNsDeliveryBlockerState",
                "ownerAction",
                "blocked",
                "capability",
                relativePath.hasSuffix("NotificationAPNsSettingsView.swift") ? "blockerArtifactFileName" : nil
            ].compactMap { token in
                guard let token else {
                    return nil
                }
                return typedContent.contains(token) ? nil : "\(relativePath) missing typed blocker token \(token)"
            } + (relativePath.hasSuffix("NotificationAPNsSettingsView.swift") ? [] : [
                "apple-developer-program-blocker-apns.json"
            ].compactMap { token in
                stringAllowedContent.contains(token) ? nil : "\(relativePath) missing blocker path token \(token)"
            })
        }

        let fakeDeliveryTokens = [
            "APNsProductionDeliveryAvailable",
            "productionDeliveryReady",
            "deliverPushNotification",
            "sendPushNotification",
            "TestFlight upload available"
        ]
        let fakeDeliveryHits = allSwiftSources(under: root).flatMap { relativePath, content in
            fakeDeliveryTokens
                .filter { content.contains($0) }
                .map { "\(relativePath) contains forbidden APNs delivery token \($0)" }
        }

        #expect((consumerFailures + fakeDeliveryHits).isEmpty, Comment(rawValue: (consumerFailures + fakeDeliveryHits).joined(separator: "\n")))
    }
}

private func sourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String],
    stringAllowedTokens: [String: [String]]
) -> [String] {
    let root = repoRoot()
    var failures: [String] = []

    for relativePath in requiredFiles {
        if !FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path) {
            failures.append("missing notification/APNs surface file: \(relativePath)")
        }
    }

    for (relativePath, tokens) in requiredTokens {
        let fileURL = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
        let rawContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let content = scenarioLike(relativePath) ? uncommentedSwift(rawContent) : swiftContractSource(rawContent)
        let missingTokens = tokens.filter { !content.contains($0) }
        if !missingTokens.isEmpty {
            failures.append("\(relativePath) missing notification/APNs tokens: \(missingTokens.joined(separator: ", "))")
        }
    }

    for (relativePath, tokens) in stringAllowedTokens {
        let fileURL = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
        let content = uncommentedSwift((try? String(contentsOf: fileURL, encoding: .utf8)) ?? "")
        let missingTokens = tokens.filter { !content.contains($0) }
        if !missingTokens.isEmpty {
            failures.append("\(relativePath) missing string-allowed notification/APNs tokens: \(missingTokens.joined(separator: ", "))")
        }
    }

    for relativePath in requiredFiles {
        let fileURL = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
        let content = uncommentedSwift((try? String(contentsOf: fileURL, encoding: .utf8)) ?? "")
        let forbiddenHits = forbiddenTokens.filter { content.contains($0) }
        if !forbiddenHits.isEmpty {
            failures.append("\(relativePath) contains forbidden notification/APNs tokens: \(forbiddenHits.joined(separator: ", "))")
        }
    }

    return failures
}

private func cacheRecord(
    domain: NativeCacheDomain,
    sourceEndpoint: String,
    serverRevision: NativeCacheServerRevision,
    payload: NativeCachePayload,
    fetchedAt: Date,
    lastValidatedAt: Date
) throws -> NativeCacheRecord {
    try NativeCacheRecord(
        id: domain.stableRecordID,
        metadata: NativeCacheRecordMetadata(
            accountID: "chef_ari",
            environment: .production,
            schemaVersion: 2,
            domain: domain,
            fetchedAt: fetchedAt,
            lastValidatedAt: lastValidatedAt,
            sourceEndpoint: sourceEndpoint,
            serverRevision: serverRevision
        ),
        payload: payload
    )
}

private enum NotificationAPNsTestFailure: Error, CustomStringConvertible {
    case unexpectedRequest

    var description: String {
        switch self {
        case .unexpectedRequest:
            "Unexpected notification APNs test request."
        }
    }
}

private final class RecordingNotificationAPNsSettingsTransport: SettingsSurfaceTransport, @unchecked Sendable {
    private let preferences: SettingsNotificationPreferences
    private let validatedAt: Date
    private(set) var requestPaths: [String] = []

    init(preferences: SettingsNotificationPreferences, validatedAt: Date) {
        self.preferences = preferences
        self.validatedAt = validatedAt
    }

    func fetchAccount(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsAccountProfile> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        throw NotificationAPNsTestFailure.unexpectedRequest
    }

    func fetchNotificationPreferences(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsNotificationPreferences> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        return SettingsTransportEnvelope(
            requestID: "req_notification_apns",
            data: preferences,
            validatedAt: validatedAt
        )
    }

    func fetchAPITokens(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsAPITokenSummary]> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        throw NotificationAPNsTestFailure.unexpectedRequest
    }

    func fetchOAuthConnections(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsOAuthConnectionSummary]> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        throw NotificationAPNsTestFailure.unexpectedRequest
    }
}

private final class StubNotificationAPNsSurfaceRepository: NotificationAPNsSurfaceRepository, @unchecked Sendable {
    private let data: NotificationAPNsSurfaceData?
    private let error: Error?

    init(data: NotificationAPNsSurfaceData) {
        self.data = data
        error = nil
    }

    init(error: Error) {
        data = nil
        self.error = error
    }

    func restore() async throws -> NotificationAPNsSurfaceData {
        if let error {
            throw error
        }

        return data!
    }
}

private func scenarioLike(_ relativePath: String) -> Bool {
    relativePath == "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift"
}

private func uncommentedSwift(_ content: String) -> String {
    scanSwiftSource(content, stripStrings: false)
}

private func swiftContractSource(_ content: String) -> String {
    scanSwiftSource(content, stripStrings: true)
}

private func scanSwiftSource(_ content: String, stripStrings: Bool) -> String {
    var output = ""
    var index = content.startIndex

    while index < content.endIndex {
        if content[index...].hasPrefix("//") {
            index = copyNewlinesWhileSkippingLineComment(in: content, from: index, into: &output)
            continue
        }

        if content[index...].hasPrefix("/*") {
            index = copyNewlinesWhileSkippingBlockComment(in: content, from: index, into: &output)
            continue
        }

        if let literalEnd = swiftStringLiteralEnd(in: content, at: index) {
            let segment = content[index..<literalEnd]
            if stripStrings {
                output += #""""#
                output += segment.filter { $0 == "\n" || $0 == "\r" }
            } else {
                output += segment
            }
            index = literalEnd
            continue
        }

        output.append(content[index])
        index = content.index(after: index)
    }

    return output
}

private func copyNewlinesWhileSkippingLineComment(in content: String, from start: String.Index, into output: inout String) -> String.Index {
    var index = start
    while index < content.endIndex {
        let character = content[index]
        if character == "\n" || character == "\r" {
            output.append(character)
            index = content.index(after: index)
            break
        }
        index = content.index(after: index)
    }
    return index
}

private func copyNewlinesWhileSkippingBlockComment(in content: String, from start: String.Index, into output: inout String) -> String.Index {
    var index = content.index(start, offsetBy: 2)
    var depth = 1

    while index < content.endIndex, depth > 0 {
        if content[index...].hasPrefix("/*") {
            depth += 1
            index = content.index(index, offsetBy: 2)
        } else if content[index...].hasPrefix("*/") {
            depth -= 1
            index = content.index(index, offsetBy: 2)
        } else {
            let character = content[index]
            if character == "\n" || character == "\r" {
                output.append(character)
            }
            index = content.index(after: index)
        }
    }

    return index
}

private func swiftStringLiteralEnd(in content: String, at start: String.Index) -> String.Index? {
    var cursor = start
    var hashCount = 0
    while cursor < content.endIndex, content[cursor] == "#" {
        hashCount += 1
        cursor = content.index(after: cursor)
    }

    guard cursor < content.endIndex, content[cursor] == "\"" else {
        return nil
    }

    let quoteCount = content[cursor...].hasPrefix(#"""""#) ? 3 : 1
    cursor = content.index(cursor, offsetBy: quoteCount)

    if quoteCount == 1 {
        while cursor < content.endIndex {
            if hashCount == 0, content[cursor] == "\\" {
                cursor = content.index(after: cursor)
                if cursor < content.endIndex {
                    cursor = content.index(after: cursor)
                }
                continue
            }

            if content[cursor] == "\"" {
                let afterQuote = content.index(after: cursor)
                if let end = indexAfterHashes(in: content, from: afterQuote, count: hashCount) {
                    return end
                }
            }

            cursor = content.index(after: cursor)
        }
    } else {
        while cursor < content.endIndex {
            if content[cursor...].hasPrefix(#"""""#) {
                let afterQuotes = content.index(cursor, offsetBy: 3)
                if let end = indexAfterHashes(in: content, from: afterQuotes, count: hashCount) {
                    return end
                }
            }
            cursor = content.index(after: cursor)
        }
    }

    return content.endIndex
}

private func indexAfterHashes(in content: String, from start: String.Index, count: Int) -> String.Index? {
    var cursor = start
    for _ in 0..<count {
        guard cursor < content.endIndex, content[cursor] == "#" else {
            return nil
        }
        cursor = content.index(after: cursor)
    }
    return cursor
}

private func allSwiftSources(under root: URL) -> [(String, String)] {
    let directories = ["Sources", "Apps"]
    return directories.flatMap { directory -> [(String, String)] in
        let directoryURL = root.appendingPathComponent(directory)
        guard let enumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return (relativePath, uncommentedSwift(content))
        }
    }
}

private func repoRoot() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func assertRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    authorization: String,
    responseCachePolicy: APIResponseCachePolicy
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.headers["Authorization"] == authorization)
    #expect(request.headers["Accept"] == "application/json")
    #expect(request.responseCachePolicy == responseCachePolicy)
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: AnyHashable]
) throws {
    assertRequest(
        request,
        method: method,
        path: path,
        authorization: "Bearer sj_private_token",
        responseCachePolicy: .privateNoStore
    )
    #expect(request.headers["Content-Type"] == "application/json")

    let body = try #require(request.body)
    let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: AnyHashable])
    #expect(object == expected)
}
