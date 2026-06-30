import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Notification Siri intent contracts")
struct NotificationIntentTests {
    private static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("notification Siri intents require preference read update and APNs status actions")
    func notificationSiriIntentsRequirePreferenceReadUpdateAndAPNsStatusActions() throws {
        var failures = notificationIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift",
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift",
                "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceRepository.swift",
                "Sources/SpoonjoyCore/API/NativeAPIRequests.swift",
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "scripts/check-app-intents-contract.rb"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct ReadNotificationPreferencesIntent: AppIntent",
                    "struct UpdateNotificationPreferencesIntent: AppIntent",
                    "struct OpenNotificationAPNsStatusIntent: AppIntent",
                    "@Parameter(title: \"Spoons\")",
                    "@Parameter(title: \"Forks\")",
                    "@Parameter(title: \"Cookbook Saves\")",
                    "@Parameter(title: \"Fellow-Chef Cooks\")",
                    "SettingsNotificationPreferences(",
                    "NativeIntentActionResolver().readNotificationPreferences(",
                    "NativeIntentActionResolver().updateNotificationPreferences(",
                    "NativeIntentActionResolver().openNotificationAPNsStatus(",
                    "SpoonjoyIntentStateWriter",
                    "notificationAPNsSurfaceData()",
                    "notificationAPNsHasCachedPreferences()",
                    "notificationAPNsConnectivity()",
                    "performNotificationAPNsActionStatus",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "OpenURLIntent(action.url)",
                    "ReturnsValue<String>",
                    "APNsDeliveryBlockerState",
                    "AppleDeveloperProgramBlocker.artifactFileName",
                    "String(describing: ReadNotificationPreferencesIntent())",
                    "String(describing: UpdateNotificationPreferencesIntent())",
                    "String(describing: OpenNotificationAPNsStatusIntent())"
                ],
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceRepository.swift": [
                    "NotificationAPNsSurfaceData",
                    "APNsRegistrationSummary",
                    "APNsPermissionState",
                    "APNsDeliveryCapability",
                    "AppleDeveloperProgramBlocker",
                    "apple-developer-program-blocker-apns.json"
                ],
                "Sources/SpoonjoyCore/Features/Notifications/NotificationAPNsSurfaceViewModel.swift": [
                    "NotificationAPNsActionPlanner",
                    "NotificationAPNsActionPlan",
                    "NotificationAPNsSurfaceConnectivity",
                    "case updatePreferences",
                    "case requestPermission",
                    "case registerDevice",
                    "case revokeDevice",
                    "NotificationAPNsOnlineOnlyReason",
                    "NativeOfflineAction.apnsPermissionPrompt",
                    "NativeOfflineAction.apnsDeviceTokenAcquisition",
                    "APNsDeliveryBlockerState"
                ],
                "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceRepository.swift": [
                    "SettingsNotificationPreferences",
                    "notifySpoonOnMyRecipe",
                    "notifyForkOfMyRecipe",
                    "notifyCookbookSaveOfMine",
                    "notifyFellowChefOriginCook"
                ],
                "Sources/SpoonjoyCore/API/NativeAPIRequests.swift": [
                    "public static func notificationPreferences()",
                    "public static func updateNotificationPreferences(",
                    "public static func registerAPNSDevice(",
                    "public static func revokeAPNSDevice("
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    ".notificationPreferenceUpdate",
                    ".apnsDeviceRegister",
                    ".apnsDeviceRevoke",
                    ".apnsPermissionPrompt",
                    ".apnsDeviceTokenAcquisition"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "public struct NativeIntentNotificationPreferencesSummary",
                    "public struct NativeIntentNotificationAction",
                    "public func readNotificationPreferences(",
                    "public func updateNotificationPreferences(",
                    "public func openNotificationAPNsStatus(",
                    "NotificationAPNsActionPlanner",
                    "NotificationAPNsSurfaceConnectivity",
                    "NotificationAPNsActionPlan",
                    ".updatePreferences(preferences, clientMutationID: mutationID)",
                    "SettingsNotificationPreferences",
                    "APNsDeliveryBlockerState",
                    "AppleDeveloperProgramBlocker.artifactFileName",
                    "DeepLinkURLBuilder.url(for: .settings)"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "ReadNotificationPreferencesIntent",
                    "UpdateNotificationPreferencesIntent",
                    "OpenNotificationAPNsStatusIntent"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Notification Siri intents",
                    "ReadNotificationPreferencesIntent",
                    "UpdateNotificationPreferencesIntent",
                    "OpenNotificationAPNsStatusIntent",
                    "AppleDeveloperProgramBlocker"
                ],
                "scripts/check-app-intents-contract.rb": [
                    "\"notification-intents\"",
                    "if domain == \"notification-intents\"",
                    "ReadNotificationPreferencesIntent",
                    "UpdateNotificationPreferencesIntent",
                    "OpenNotificationAPNsStatusIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": notificationIntentForbiddenProductTokens(),
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "NotificationAPNsDeviceBridge",
                    "requestNotificationPermission",
                    "requestDeviceRegistrationAction",
                    "registrationAction(",
                    "planDeviceTokenAcquisition",
                    ".requestPermission",
                    ".registerDevice(",
                    ".revokeDevice(",
                    "requestAuthorization",
                    "registerForRemoteNotifications",
                    "didRegisterForRemoteNotifications",
                    "sendPushNotification",
                    "deliverPushNotification",
                    "productionAPNsAvailable = true"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": notificationIntentForbiddenCapabilityTokens(),
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": notificationIntentForbiddenCapabilityTokens()
            ]
        )

        failures.append(contentsOf: notificationIntentExtraAppIntentSurfaceFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            allowedIntentNames: [
                "ReadNotificationPreferencesIntent",
                "UpdateNotificationPreferencesIntent",
                "OpenNotificationAPNsStatusIntent"
            ]
        ))

        failures.append(contentsOf: notificationIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "ReadNotificationPreferencesIntent",
                    pattern: #"struct\s+ReadNotificationPreferencesIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "ReturnsValue<String>",
                        "let stateWriter = try SpoonjoyIntentStateWriter()",
                        "let connectivity = try await stateWriter.notificationAPNsConnectivity()",
                        "let data = try await stateWriter.notificationAPNsSurfaceData()",
                        "NativeIntentActionResolver().readNotificationPreferences(",
                        "hasCachedPreferences: try await stateWriter.notificationAPNsHasCachedPreferences()",
                        "connectivity: connectivity",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "return .result(value: summary.value"
                    ],
                    forbiddenTokens: [
                        "try await requestConfirmation(",
                        "OpenURLIntent",
                        "NativeQueuedMutation",
                        "NotificationAPNsDeviceBridge",
                        ".requestPermission",
                        ".registerDevice(",
                        ".revokeDevice(",
                        "planDeviceTokenAcquisition",
                        "requestNotificationPermission",
                        "requestDeviceRegistrationAction",
                        "registrationAction("
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "UpdateNotificationPreferencesIntent",
                    pattern: #"struct\s+UpdateNotificationPreferencesIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Spoons\")",
                        "@Parameter(title: \"Forks\")",
                        "@Parameter(title: \"Cookbook Saves\")",
                        "@Parameter(title: \"Fellow-Chef Cooks\")",
                        "var spoons: Bool?",
                        "var forks: Bool?",
                        "var cookbookSaves: Bool?",
                        "var fellowChefCooks: Bool?",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "let stateWriter = try SpoonjoyIntentStateWriter()",
                        "let connectivity = try await stateWriter.notificationAPNsConnectivity()",
                        "let data = try await stateWriter.notificationAPNsSurfaceData()",
                        "let requiresCurrentPreferences = spoons == nil || forks == nil || cookbookSaves == nil || fellowChefCooks == nil",
                        "hasCachedPreferences: try await stateWriter.notificationAPNsHasCachedPreferences()",
                        "SettingsNotificationPreferences(",
                        "spoons ?? data.preferences.notifySpoonOnMyRecipe",
                        "forks ?? data.preferences.notifyForkOfMyRecipe",
                        "cookbookSaves ?? data.preferences.notifyCookbookSaveOfMine",
                        "fellowChefCooks ?? data.preferences.notifyFellowChefOriginCook",
                        "NativeIntentActionResolver().updateNotificationPreferences(",
                        "connectivity: connectivity",
                        "deliveryCapability: data.deliveryCapability",
                        "performNotificationAPNsActionStatus(action, savedAt: createdAt)",
                        "status.dialogMessage(completed: \"Updated notification preferences in Spoonjoy.\"",
                        "queued: \"Queued notification preference update in Spoonjoy.\"",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "try await requestConfirmation(",
                        "NotificationAPNsDeviceBridge",
                        ".requestPermission",
                        ".registerDevice(",
                        ".revokeDevice(",
                        "planDeviceTokenAcquisition",
                        "requestAuthorization",
                        "registerForRemoteNotifications",
                        "requestNotificationPermission",
                        "requestDeviceRegistrationAction",
                        "registrationAction(",
                        "var deviceToken",
                        "@Parameter(title: \"Device Token\")",
                        "spoons = true",
                        "forks = true",
                        "cookbookSaves = true",
                        "fellowChefCooks = true"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenNotificationAPNsStatusIntent",
                    pattern: #"struct\s+OpenNotificationAPNsStatusIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "let data = try await SpoonjoyIntentStateWriter().notificationAPNsSurfaceData()",
                        "NativeIntentActionResolver().openNotificationAPNsStatus(",
                        "APNsDeliveryBlockerState",
                        "AppleDeveloperProgramBlocker.artifactFileName",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [
                        "NotificationAPNsDeviceBridge",
                        ".requestPermission",
                        ".registerDevice(",
                        ".revokeDevice(",
                        "planDeviceTokenAcquisition",
                        "requestAuthorization",
                        "registerForRemoteNotifications",
                        "requestNotificationPermission",
                        "requestDeviceRegistrationAction",
                        "registrationAction(",
                        "revokeAPNSDevice",
                        "sendPushNotification",
                        "deliverPushNotification"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentStateWriter",
                    pattern: #"private\s+struct\s+SpoonjoyIntentStateWriter"#,
                    requiredTokens: [
                        "func notificationAPNsSurfaceData() async throws -> NotificationAPNsSurfaceData",
                        "func notificationAPNsHasCachedPreferences() async throws -> Bool",
                        "func notificationAPNsConnectivity() async throws -> NotificationAPNsSurfaceConnectivity",
                        "func performNotificationAPNsActionStatus(_ action: NativeIntentNotificationAction, savedAt: String) async throws -> SpoonjoyIntentSettingsActionStatus",
                        "executeNotificationAPNsAction(action)",
                        "NotificationAPNsActionPlanner",
                        "recordNotificationAPNsBlocker"
                    ],
                    forbiddenTokens: [
                        "return .online"
                    ]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentShortcutBudget",
                    pattern: #"private\s+enum\s+SpoonjoyIntentShortcutBudget"#,
                    requiredTokens: [
                        "String(describing: ReadNotificationPreferencesIntent())",
                        "String(describing: UpdateNotificationPreferencesIntent())",
                        "String(describing: OpenNotificationAPNsStatusIntent())"
                    ],
                    forbiddenTokens: [
                        "AppShortcut(intent: ReadNotificationPreferencesIntent",
                        "AppShortcut(intent: UpdateNotificationPreferencesIntent",
                        "AppShortcut(intent: OpenNotificationAPNsStatusIntent"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "readNotificationPreferences resolver",
                    pattern: #"public\s+func\s+readNotificationPreferences\("#,
                    requiredTokens: [
                        "SettingsNotificationPreferences",
                        "NativeIntentNotificationPreferencesSummary",
                        "hasCachedPreferences",
                        "settingsActionUnavailable",
                        "notifySpoonOnMyRecipe",
                        "notifyForkOfMyRecipe",
                        "notifyCookbookSaveOfMine",
                        "notifyFellowChefOriginCook"
                    ],
                    forbiddenTokens: [
                        "NativeQueuedMutation",
                        "APIRequestBuilder",
                        "try!"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "partial updateNotificationPreferences resolver",
                    pattern: #"public\s+func\s+updateNotificationPreferences\(\s*currentPreferences:"#,
                    requiredTokens: [
                        "spoons ?? currentPreferences.notifySpoonOnMyRecipe",
                        "forks ?? currentPreferences.notifyForkOfMyRecipe",
                        "cookbookSaves ?? currentPreferences.notifyCookbookSaveOfMine",
                        "fellowChefCooks ?? currentPreferences.notifyFellowChefOriginCook",
                        "return try updateNotificationPreferences("
                    ],
                    forbiddenTokens: [
                        "spoons ?? true",
                        "forks ?? true",
                        "cookbookSaves ?? true",
                        "fellowChefCooks ?? true"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "updateNotificationPreferences resolver",
                    pattern: #"public\s+func\s+updateNotificationPreferences\("#,
                    requiredTokens: [
                        "SettingsNotificationPreferences",
                        "NotificationAPNsActionPlanner(connectivity: connectivity",
                        ".updatePreferences(preferences, clientMutationID: mutationID)",
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: [
                        "requestAuthorization",
                        "registerForRemoteNotifications",
                        ".apnsDeviceRegister",
                        ".apnsDeviceRevoke"
                    ]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openNotificationAPNsStatus resolver",
                    pattern: #"public\s+func\s+openNotificationAPNsStatus\("#,
                    requiredTokens: [
                        "NotificationAPNsSurfaceData",
                        "APNsDeliveryBlockerState",
                        "AppleDeveloperProgramBlocker.artifactFileName",
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: [
                        "requestAuthorization",
                        "registerForRemoteNotifications",
                        "sendPushNotification",
                        "deliverPushNotification"
                    ]
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("notification intent planner preserves queueable preferences and APNs blocker boundaries")
    func notificationIntentPlannerPreservesQueueablePreferencesAndAPNsBlockerBoundaries() throws {
        let now = "2026-06-29T13:30:00.000Z"
        let preferences = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
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

        let onlinePreference = try onlinePlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_siri_notifications"))
        let onlineRequest = try #require(onlinePreference.remoteRequestBuilder).urlRequest(configuration: Self.configuration)
        try notificationIntentAssertJSONRequest(onlineRequest, method: .patch, path: "/api/v1/me/notification-preferences", expected: [
            "notifySpoonOnMyRecipe": true,
            "notifyForkOfMyRecipe": false,
            "notifyCookbookSaveOfMine": true,
            "notifyFellowChefOriginCook": false
        ])
        #expect(onlinePreference.offlineFallbackMutation?.queueableKind == .notificationPreferenceUpdate)
        #expect(onlinePreference.queuedMutation == nil)

        let offlinePreference = try offlinePlanner.plan(.updatePreferences(preferences, clientMutationID: "cm_siri_notifications_offline"))
        #expect(offlinePreference.queuedMutation?.queueableKind == .notificationPreferenceUpdate)
        #expect(offlinePreference.remoteRequestBuilder == nil)
        #expect(offlinePreference.userFacingMessage == "Notification change queued.")

        let offlinePermission = try offlinePlanner.plan(.requestPermission)
        #expect(offlinePermission.onlineOnlyReason == .permissionPrompt)
        #expect(offlinePermission.queuedMutation == nil)
        #expect(offlinePermission.userFacingMessage == "Notification permission prompts are online-only and were not queued.")

        let tokenAcquisition = try onlinePlanner.planDeviceTokenAcquisition()
        #expect(tokenAcquisition.onlineOnlyReason == .deviceTokenAcquisition)
        #expect(tokenAcquisition.remoteRequestBuilder == nil)
        #expect(tokenAcquisition.queuedMutation == nil)

        let blockedProductionRegister = try onlinePlanner.plan(.registerDevice(
            deviceID: "device_production",
            platform: .ios,
            environment: .production,
            token: "production-token",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_apns_production"
        ))
        #expect(blockedProductionRegister.deliveryBlocker == .localValidation)
        #expect(blockedProductionRegister.remoteRequestBuilder == nil)
        #expect(blockedProductionRegister.queuedMutation == nil)
        #expect(blockedProductionRegister.userFacingMessage == AppleDeveloperProgramBlocker.localValidation.ownerAction)

        let developmentRegister = try onlinePlanner.plan(.registerDevice(
            deviceID: "device_development",
            platform: .ios,
            environment: .development,
            token: "development-token",
            deviceName: "Ari's iPhone",
            appVersion: "1.0.0",
            clientMutationID: "cm_apns_development"
        ))
        try notificationIntentAssertJSONRequest(
            try #require(developmentRegister.remoteRequestBuilder).urlRequest(configuration: Self.configuration),
            method: .post,
            path: "/api/v1/me/apns-devices",
            expected: [
                "deviceId": "device_development",
                "platform": "ios",
                "environment": "development",
                "token": "development-token",
                "deviceName": "Ari's iPhone",
                "appVersion": "1.0.0"
            ]
        )
        #expect(developmentRegister.offlineFallbackMutation?.queueableKind == .apnsDeviceRegister)
    }

    @Test("notification resolver rejects unavailable offline preference reads")
    func notificationResolverRejectsUnavailableOfflinePreferenceReads() throws {
        let resolver = NativeIntentActionResolver()
        let data = NotificationAPNsSurfaceData(
            preferences: .disabled,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            source: .cache(serverRevision: nil, lastValidatedAt: Date(timeIntervalSince1970: 1_782_899_000))
        )

        #expect(throws: NativeIntentActionError.settingsActionUnavailable("Notification preferences are unavailable offline until Spoonjoy has cached them.")) {
            try resolver.readNotificationPreferences(data: data, hasCachedPreferences: false, connectivity: .offline)
        }
        #expect(throws: NativeIntentActionError.settingsActionUnavailable("Notification preferences are unavailable until Spoonjoy refreshes or caches them.")) {
            try resolver.readNotificationPreferences(data: data, hasCachedPreferences: false, connectivity: .online)
        }

        let liveData = NotificationAPNsSurfaceData(
            preferences: .disabled,
            apnsRegistration: nil,
            permissionState: .notDetermined,
            deliveryCapability: .developmentOnly(blocker: .localValidation),
            source: .live(requestID: "req_notifications", validatedAt: Date(timeIntervalSince1970: 1_782_899_000))
        )
        let summary = try resolver.readNotificationPreferences(data: liveData, hasCachedPreferences: false, connectivity: .online)
        #expect(summary.preferences == .disabled)

        let statusAction = resolver.openNotificationAPNsStatus(data: liveData)
        #expect(statusAction.deliveryBlocker == .localValidation)
        #expect(statusAction.onlineOnlyReason == nil)
    }

    @Test("notification resolver merges partial Siri updates with current preferences")
    func notificationResolverMergesPartialSiriUpdatesWithCurrentPreferences() throws {
        let resolver = NativeIntentActionResolver()
        let current = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: false,
            notifyFellowChefOriginCook: true
        )

        let action = try resolver.updateNotificationPreferences(
            currentPreferences: current,
            spoons: nil,
            forks: true,
            cookbookSaves: nil,
            fellowChefCooks: nil,
            connectivity: .offline,
            createdAt: "2026-06-29T14:02:00.000Z"
        )
        let mutation = try #require(action.plan.queuedMutation)
        #expect(action.onlineOnlyReason == nil)
        #expect(mutation.notificationPreferenceUpdateValues == SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: true,
            notifyCookbookSaveOfMine: false,
            notifyFellowChefOriginCook: true
        ))

        let forkPreservingAction = try resolver.updateNotificationPreferences(
            currentPreferences: current,
            spoons: false,
            forks: nil,
            cookbookSaves: true,
            fellowChefCooks: false,
            connectivity: .offline,
            createdAt: "2026-06-29T14:03:00.000Z"
        )
        let forkPreservingMutation = try #require(forkPreservingAction.plan.queuedMutation)
        #expect(forkPreservingMutation.notificationPreferenceUpdateValues == SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: false,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        ))
    }

    @Test("notification preference mutation values fail closed when required fields are missing")
    func notificationPreferenceMutationValuesFailClosedWhenRequiredFieldsAreMissing() throws {
        let malformedJSON = """
        {
          "schemaVersion": 1,
          "id": "native:cm_bad_notifications",
          "clientMutationId": "cm_bad_notifications",
          "createdAt": "2026-06-29T14:04:00.000Z",
          "kind": {
            "type": "notification.preference.update",
            "notifySpoonOnMyRecipe": true,
            "notifyForkOfMyRecipe": false,
            "notifyCookbookSaveOfMine": true
          }
        }
        """.data(using: .utf8)!
        let malformed = try JSONDecoder().decode(NativeQueuedMutation.self, from: malformedJSON)

        #expect(malformed.notificationPreferenceUpdateValues == nil)
    }
}

private struct NotificationIntentTestFailure: Error, CustomStringConvertible {
    let description: String
}

private func notificationIntentAssertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) throws {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.headers["Authorization"] == "Bearer sj_private_token")
    #expect(request.headers["Content-Type"] == "application/json")
    #expect(try notificationIntentJSONBody(from: request) == expected as NSDictionary)
}

private func notificationIntentJSONBody(from request: APIRequest) throws -> NSDictionary {
    guard let body = request.body else {
        throw NotificationIntentTestFailure(description: "Missing JSON body.")
    }
    guard let object = try JSONSerialization.jsonObject(with: body) as? NSDictionary else {
        throw NotificationIntentTestFailure(description: "Expected JSON object body.")
    }
    return object
}

private func notificationIntentForbiddenProductTokens() -> [String] {
    [
        "struct EnableNotificationsIntent",
        "struct DisableNotificationsIntent",
        "struct RequestNotificationPermissionIntent",
        "struct RequestPushNotificationPermissionIntent",
        "struct RegisterAPNsDeviceIntent",
        "struct RegisterAPNSDeviceIntent",
        "struct RevokeAPNsDeviceIntent",
        "struct RevokeAPNSDeviceIntent",
        "@Parameter(title: \"Device Token\")",
        "@Parameter(title: \"APNs Token\")",
        "var deviceToken: String",
        "var apnsToken: String",
        "NotificationAPNsDeviceBridge",
        "requestNotificationPermission",
        "requestDeviceRegistrationAction",
        "registrationAction(",
        "planDeviceTokenAcquisition",
        ".requestPermission",
        ".registerDevice(",
        ".revokeDevice(",
        "requestAuthorization",
        "registerForRemoteNotifications",
        "didRegisterForRemoteNotifications",
        "sendPushNotification",
        "deliverPushNotification",
        "productionAPNsAvailable = true",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MessageUI",
        "TODO NotificationIntent",
        "eventually add notification intents"
    ]
}

private func notificationIntentForbiddenCapabilityTokens() -> [String] {
    [
        "EnableNotificationsIntent",
        "DisableNotificationsIntent",
        "RequestNotificationPermissionIntent",
        "RequestPushNotificationPermissionIntent",
        "RegisterAPNsDeviceIntent",
        "RegisterAPNSDeviceIntent",
        "RevokeAPNsDeviceIntent",
        "RevokeAPNSDeviceIntent",
        "SendTestPushNotificationIntent",
        "APNsProductionDeliveryAvailable",
        "productionDeliveryReady",
        "productionAPNsAvailable = true",
        "fakeAPNsDelivery",
        "sendTestPushNotification",
        "sendPushNotification",
        "deliverPushNotification",
        "TestFlightAvailable"
    ]
}

private func notificationIntentExtraAppIntentSurfaceFailures(
    relativePath: String,
    allowedIntentNames: Set<String>
) -> [String] {
    guard let content = try? notificationIntentReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }

    let uncommented = notificationIntentUncommentedSwift(content)
    let pattern = #"\bstruct\s+([A-Za-z0-9_]*(?:Notification|APNs|APNS|Push)[A-Za-z0-9_]*)\s*:\s*AppIntent\b"#
    let expression = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(uncommented.startIndex..<uncommented.endIndex, in: uncommented)
    return expression.matches(in: uncommented, range: range).compactMap { match in
        guard match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: uncommented)
        else {
            return nil
        }
        let name = String(uncommented[nameRange])
        return allowedIntentNames.contains(name) ? nil : "\(relativePath) contains forbidden notification/APNs Siri App Intent \(name)"
    }
}

private func notificationIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? notificationIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = notificationIntentUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func notificationIntentBodyContractFailures(
    contracts: [(
        relativePath: String,
        label: String,
        pattern: String,
        requiredTokens: [String],
        forbiddenTokens: [String]
    )]
) -> [String] {
    var failures: [String] = []
    for contract in contracts {
        guard let content = try? notificationIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = notificationIntentUncommentedSwift(content)
        guard let body = notificationIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
            failures.append("\(contract.relativePath) missing body for \(contract.label)")
            continue
        }
        for token in contract.requiredTokens where !body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) missing \(token)")
        }
        for token in contract.forbiddenTokens where body.contains(token) {
            failures.append("\(contract.relativePath) \(contract.label) contains forbidden \(token)")
        }
    }
    return failures
}

private func notificationIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func notificationIntentDeclarationBody(in content: String, pattern: String) -> String? {
    guard let declarationRange = content.range(of: pattern, options: .regularExpression),
          let openBrace = content[declarationRange.upperBound...].firstIndex(of: "{")
    else {
        return nil
    }

    var depth = 0
    var index = openBrace
    while index < content.endIndex {
        let character = content[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(content[content.index(after: openBrace)..<index])
            }
        }
        index = content.index(after: index)
    }

    return nil
}

private func notificationIntentUncommentedSwift(_ content: String) -> String {
    var output = ""
    var index = content.startIndex
    var inString = false
    var escaping = false

    while index < content.endIndex {
        let character = content[index]
        let nextIndex = content.index(after: index)

        if inString {
            output.append(character)
            if escaping {
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                inString = false
            }
            index = nextIndex
            continue
        }

        if character == "\"" {
            inString = true
            output.append(character)
            index = nextIndex
            continue
        }

        if character == "/", nextIndex < content.endIndex {
            let nextCharacter = content[nextIndex]
            if nextCharacter == "/" {
                index = nextIndex
                while index < content.endIndex, content[index] != "\n" {
                    index = content.index(after: index)
                }
                if index < content.endIndex {
                    output.append(content[index])
                    index = content.index(after: index)
                }
                continue
            }
            if nextCharacter == "*" {
                index = content.index(after: nextIndex)
                while index < content.endIndex {
                    let maybeEnd = content[index]
                    let afterMaybeEnd = content.index(after: index)
                    if maybeEnd == "*", afterMaybeEnd < content.endIndex, content[afterMaybeEnd] == "/" {
                        index = content.index(after: afterMaybeEnd)
                        break
                    }
                    index = afterMaybeEnd
                }
                continue
            }
        }

        output.append(character)
        index = nextIndex
    }

    return output
}
