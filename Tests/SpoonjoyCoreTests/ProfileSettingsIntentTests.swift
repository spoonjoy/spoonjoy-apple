import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Profile and settings Siri intent contracts")
struct ProfileSettingsIntentTests {
    @Test("profile and settings Siri intents require queueable profile actions and online-only credential actions")
    func profileSettingsSiriIntentsRequireQueueableProfileAndOnlineOnlyCredentialActions() throws {
        var failures = profileSettingsIntentSourceContractFailures(
            requiredFiles: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift",
                "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceViewModel.swift",
                "Sources/SpoonjoyCore/API/NativeAPIRequests.swift",
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "scripts/check-app-intents-contract.rb"
            ],
            requiredTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": [
                    "struct OpenProfileIntent: AppIntent",
                    "struct OpenSettingsIntent: AppIntent",
                    "struct UpdateProfileDisplayIntent: AppIntent",
                    "struct UpdateProfilePhotoIntent: AppIntent",
                    "struct RemoveProfilePhotoIntent: AppIntent",
                    "struct OpenAPITokensIntent: AppIntent",
                    "struct CreateAPITokenIntent: AppIntent",
                    "struct RevokeAPITokenIntent: AppIntent",
                    "struct OpenAccountConnectionsIntent: AppIntent",
                    "struct DisconnectAccountConnectionIntent: AppIntent",
                    "struct OpenPasskeysIntent: AppIntent",
                    "struct OpenPasswordIntent: AppIntent",
                    "struct LinkProviderIntent: AppIntent",
                    "struct LogoutIntent: AppIntent",
                    "struct RevokeCurrentSessionIntent: AppIntent",
                    "var profile: SpoonjoyChefProfileEntity",
                    "var token: SpoonjoyAPITokenEntity",
                    "var connection: SpoonjoyAccountConnectionEntity",
                    "SpoonjoySettingsAuthProviderOption",
                    "IntentFile",
                    "SpoonjoyIntentStateWriter",
                    "SpoonjoyIntentClock.timestamp()",
                    "SpoonjoyInteractionDonor",
                    "requestConfirmation(",
                    "OpenURLIntent(action.url)",
                    "OpenURLIntent(plan.secureHandoff.url)",
                    "String(describing: OpenSettingsIntent())",
                    "String(describing: UpdateProfileDisplayIntent())",
                    "String(describing: UpdateProfilePhotoIntent())",
                    "String(describing: RemoveProfilePhotoIntent())",
                    "String(describing: OpenAPITokensIntent())",
                    "String(describing: CreateAPITokenIntent())",
                    "String(describing: RevokeAPITokenIntent())",
                    "String(describing: OpenAccountConnectionsIntent())",
                    "String(describing: DisconnectAccountConnectionIntent())",
                    "String(describing: OpenPasskeysIntent())",
                    "String(describing: OpenPasswordIntent())",
                    "String(describing: LinkProviderIntent())",
                    "String(describing: LogoutIntent())",
                    "String(describing: RevokeCurrentSessionIntent())"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyChefProfileEntities.swift": [
                    "struct SpoonjoyChefProfileEntity: AppEntity",
                    "NativeIntentActionError.unresolvedChefProfileEntity"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import SpoonjoyCore",
                    "struct SpoonjoyAPITokenEntity: AppEntity",
                    "struct SpoonjoyAPITokenEntityQuery: EntityQuery, EntityStringQuery",
                    "struct SpoonjoyAccountConnectionEntity: AppEntity",
                    "struct SpoonjoyAccountConnectionEntityQuery: EntityQuery, EntityStringQuery",
                    "struct SpoonjoySettingsAuthProviderOption: AppEnum",
                    "resolvedCredentialID() throws",
                    "resolvedConnectionID() throws",
                    "tokenPrefix",
                    "NativeIntentActionError.unresolvedAPITokenEntity",
                    "NativeIntentActionError.unresolvedAccountConnectionEntity"
                ],
                "Sources/SpoonjoyCore/Features/Settings/SettingsSurfaceViewModel.swift": [
                    "case updateProfile(email: String, username: String, clientMutationID: String)",
                    "case uploadProfilePhoto(photo: NativeStagedMediaUpload, clientMutationID: String)",
                    "case removeProfilePhoto(clientMutationID: String)",
                    "case createAPIToken(name: String, scopes: [String])",
                    "case revokeAPIToken(credentialID: String)",
                    "case disconnectOAuthConnection(connectionID: String)",
                    "case managePasskeys",
                    "case managePassword",
                    "case linkProvider(SettingsAuthProvider)",
                    "case logout",
                    "case revokeSession",
                    "SettingsOnlineOnlyReason",
                    ".apiTokenCreate",
                    ".apiTokenRevoke",
                    ".oauthConnectionDisconnect",
                    ".logout",
                    ".sessionRevoke",
                    ".credentialHandoff",
                    "TokenCredentialRequests.createToken",
                    "TokenCredentialRequests.revokeToken",
                    "PrivateAccountRequests.disconnectConnection",
                    "credentialHandoff(.passkeys",
                    "credentialHandoff(.password",
                    "credentialHandoff(.providerLink(provider)",
                    "secureHandoffRoutes.handoff(target: target)"
                ],
                "Sources/SpoonjoyCore/API/NativeAPIRequests.swift": [
                    "public static func updateProfile(",
                    "public static func uploadProfilePhoto(",
                    "public static func removeProfilePhoto()",
                    "public static func disconnectConnection(",
                    "public static func listTokens()",
                    "public static func createToken(",
                    "public static func revokeToken("
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    ".profileDisplayUpdate",
                    ".profilePhotoUpload",
                    ".profilePhotoRemove",
                    ".apiTokenCreate",
                    ".apiTokenRevoke",
                    ".providerConnectionDisconnect",
                    ".passkeyOrPasswordChange",
                    ".providerLink",
                    ".logout",
                    ".sessionRevoke"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "case unresolvedAPITokenEntity",
                    "case unresolvedAccountConnectionEntity",
                    "public func openSettings(",
                    "public func updateProfileDisplay(",
                    "public func updateProfilePhoto(",
                    "public func removeProfilePhoto(",
                    "public func openAPITokens(",
                    "public func createAPIToken(",
                    "public func revokeAPIToken(",
                    "public func openAccountConnections(",
                    "public func disconnectAccountConnection(",
                    "public func openPasskeys(",
                    "public func openPassword(",
                    "public func linkProvider(",
                    "public func logout(",
                    "public func revokeCurrentSession(",
                    "SettingsActionPlanner",
                    "SettingsSurfaceConnectivity",
                    "SettingsSecureHandoffRoutes.spoonjoyApp",
                    "DeepLinkURLBuilder.url(for: .settings)"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "OpenSettingsIntent",
                    "UpdateProfileDisplayIntent",
                    "UpdateProfilePhotoIntent",
                    "RemoveProfilePhotoIntent",
                    "OpenAPITokensIntent",
                    "CreateAPITokenIntent",
                    "RevokeAPITokenIntent",
                    "OpenAccountConnectionsIntent",
                    "DisconnectAccountConnectionIntent",
                    "OpenPasskeysIntent",
                    "OpenPasswordIntent",
                    "LinkProviderIntent",
                    "LogoutIntent",
                    "RevokeCurrentSessionIntent",
                    "SpoonjoyAPITokenEntity",
                    "SpoonjoyAccountConnectionEntity"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "Profile and settings Siri intents",
                    "UpdateProfileDisplayIntent",
                    "UpdateProfilePhotoIntent",
                    "CreateAPITokenIntent",
                    "RevokeAPITokenIntent",
                    "DisconnectAccountConnectionIntent",
                    "OpenPasskeysIntent",
                    "OpenPasswordIntent",
                    "LinkProviderIntent",
                    "LogoutIntent",
                    "RevokeCurrentSessionIntent"
                ],
                "scripts/check-app-intents-contract.rb": [
                    "\"profile-settings-intents\"",
                    "if domain == \"profile-settings-intents\"",
                    "CreateAPITokenIntent",
                    "RevokeAPITokenIntent",
                    "DisconnectAccountConnectionIntent"
                ]
            ],
            forbiddenTokens: [
                "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift": profileSettingsIntentForbiddenProductTokens(),
                "Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift": profileSettingsIntentForbiddenSecretTokens(),
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": profileSettingsIntentForbiddenProductTokens()
            ]
        )

        failures.append(contentsOf: profileSettingsIntentShortcutBudgetFailures(
            relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
            maximumShortcuts: 10,
            libraryOnlyIntentNames: [
                "UpdateProfileDisplayIntent",
                "UpdateProfilePhotoIntent",
                "RemoveProfilePhotoIntent",
                "OpenAPITokensIntent",
                "CreateAPITokenIntent",
                "RevokeAPITokenIntent",
                "OpenAccountConnectionsIntent",
                "DisconnectAccountConnectionIntent",
                "OpenPasskeysIntent",
                "OpenPasswordIntent",
                "LinkProviderIntent",
                "LogoutIntent",
                "RevokeCurrentSessionIntent"
            ]
        ))

        failures.append(contentsOf: profileSettingsIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenSettingsIntent",
                    pattern: #"struct\s+OpenSettingsIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "NativeIntentActionResolver().openSettings(",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation", "ReturnsValue<String>"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenAPITokensIntent",
                    pattern: #"struct\s+OpenAPITokensIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "NativeIntentActionResolver().openAPITokens(",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation", "ReturnsValue<String>", "rawToken", "tokenSecret", "revealedSecret"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenAccountConnectionsIntent",
                    pattern: #"struct\s+OpenAccountConnectionsIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "NativeIntentActionResolver().openAccountConnections(",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation", "ReturnsValue<String>"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "UpdateProfileDisplayIntent",
                    pattern: #"struct\s+UpdateProfileDisplayIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Email\")",
                        "@Parameter(title: \"Username\")",
                        "let createdAt = SpoonjoyIntentClock.timestamp()",
                        "NativeIntentActionResolver().updateProfileDisplay(",
                        "performSettingsActionStatus(action, savedAt: createdAt)",
                        "status.dialogMessage(completed: \"Updated profile in Spoonjoy.\"",
                        "queued: \"Queued profile update in Spoonjoy.\"",
                        "await SpoonjoyInteractionDonor().donateBestEffort(self)",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["ReturnsValue<String>", "token", "secret"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "UpdateProfilePhotoIntent",
                    pattern: #"struct\s+UpdateProfilePhotoIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Photo\")",
                        "var photo: IntentFile",
                        "NativeIntentActionResolver().updateProfilePhoto(",
                        "performSettingsActionStatus(action, savedAt: createdAt)",
                        "status.dialogMessage(completed: \"Updated profile photo in Spoonjoy.\"",
                        "queued: \"Queued profile photo update in Spoonjoy.\"",
                        "SettingsProfilePhotoStagingPolicy.webProfileParity",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["var photoPath: String", "@Parameter(title: \"Photo Path\")"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RemoveProfilePhotoIntent",
                    pattern: #"struct\s+RemoveProfilePhotoIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().removeProfilePhoto(",
                        "performSettingsActionStatus(action, savedAt: createdAt)",
                        "status.dialogMessage(completed: \"Removed profile photo in Spoonjoy.\"",
                        "queued: \"Queued profile photo removal in Spoonjoy.\"",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["ReturnsValue<String>", "token", "secret"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "CreateAPITokenIntent",
                    pattern: #"struct\s+CreateAPITokenIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Name\")",
                        "@Parameter(title: \"Scopes\")",
                        "NativeIntentActionResolver().createAPIToken(",
                        "SpoonjoyIntentStateWriter().settingsConnectivity()",
                        "SettingsOnlineOnlyReason.apiTokenCreate.message",
                        "action.plan.userFacingMessage",
                        "not queued",
                        "OpenURLIntent(action.url)"
                    ],
                    forbiddenTokens: ["ReturnsValue<String>", "return .result(value:", "performSettingsAction(action)", "createdAPIToken", "rawToken", "tokenSecret", "revealedSecret", ".apply(action"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RevokeAPITokenIntent",
                    pattern: #"struct\s+RevokeAPITokenIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"API Token\", requestValueDialog:",
                        "var token: SpoonjoyAPITokenEntity",
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().revokeAPIToken(token: token.descriptor",
                        "SpoonjoyIntentStateWriter().settingsConnectivity()",
                        "SettingsOnlineOnlyReason.apiTokenRevoke.message",
                        "not queued"
                    ],
                    forbiddenTokens: ["var credentialID: String", "@Parameter(title: \"Credential ID\")", ".apply(action"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "DisconnectAccountConnectionIntent",
                    pattern: #"struct\s+DisconnectAccountConnectionIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Connection\", requestValueDialog:",
                        "var connection: SpoonjoyAccountConnectionEntity",
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().disconnectAccountConnection(connection: connection.descriptor",
                        "SpoonjoyIntentStateWriter().settingsConnectivity()",
                        "SettingsOnlineOnlyReason.oauthConnectionDisconnect.message",
                        "not queued"
                    ],
                    forbiddenTokens: ["var connectionID: String", "@Parameter(title: \"Connection ID\")", ".apply(action"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenPasskeysIntent",
                    pattern: #"struct\s+OpenPasskeysIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "NativeIntentActionResolver().openPasskeys(",
                        "SettingsOnlineOnlyReason.credentialHandoff.message",
                        "not queued",
                        "OpenURLIntent(plan.secureHandoff.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "OpenPasswordIntent",
                    pattern: #"struct\s+OpenPasswordIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "NativeIntentActionResolver().openPassword(",
                        "SettingsOnlineOnlyReason.credentialHandoff.message",
                        "not queued",
                        "OpenURLIntent(plan.secureHandoff.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "LinkProviderIntent",
                    pattern: #"struct\s+LinkProviderIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "@Parameter(title: \"Provider\")",
                        "var provider: SpoonjoySettingsAuthProviderOption",
                        "NativeIntentActionResolver().linkProvider(",
                        "SettingsOnlineOnlyReason.credentialHandoff.message",
                        "not queued",
                        "OpenURLIntent(plan.secureHandoff.url)"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "LogoutIntent",
                    pattern: #"struct\s+LogoutIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().logout(",
                        "SettingsOnlineOnlyReason.logout.message",
                        "not queued"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "RevokeCurrentSessionIntent",
                    pattern: #"struct\s+RevokeCurrentSessionIntent\s*:\s*AppIntent"#,
                    requiredTokens: [
                        "try await requestConfirmation(",
                        "NativeIntentActionResolver().revokeCurrentSession(",
                        "SettingsOnlineOnlyReason.sessionRevoke.message",
                        "not queued"
                    ],
                    forbiddenTokens: [".apply(action", "NativeQueuedMutation"]
                )
            ]
        ))

        failures.append(contentsOf: profileSettingsIntentBodyContractFailures(
            contracts: [
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "settingsConnectivity",
                    pattern: #"func\s+settingsConnectivity\(\)\s+async\s+throws\s+->\s+SettingsSurfaceConnectivity"#,
                    requiredTokens: [
                        "SpoonjoyIntentConnectivityProbe.settingsSurfaceConnectivity",
                        "return await connectivityProbe()"
                    ],
                    forbiddenTokens: ["return .online"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentConnectivityProbe",
                    pattern: #"private\s+enum\s+SpoonjoyIntentConnectivityProbe"#,
                    requiredTokens: [
                        "spoonjoyIntentIsOffline(error.code)",
                        "return .offline"
                    ],
                    forbiddenTokens: ["isOffline(error.code)"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "spoonjoyIntentIsOffline",
                    pattern: #"func\s+spoonjoyIntentIsOffline\(_ code: URLError\.Code\)\s+->\s+Bool"#,
                    requiredTokens: [
                        ".notConnectedToInternet",
                        ".networkConnectionLost",
                        ".cannotFindHost",
                        ".cannotConnectToHost",
                        ".timedOut",
                        ".internationalRoamingOff",
                        ".callIsActive",
                        ".dataNotAllowed"
                    ],
                    forbiddenTokens: [".dnsLookupFailed"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "performSettingsAction",
                    pattern: #"func\s+performSettingsAction\(_ action: NativeIntentSettingsAction\)\s+async\s+throws\s+->\s+SettingsActionOutcome\?"#,
                    requiredTokens: [
                        "executeSettingsAction(action).outcome"
                    ],
                    forbiddenTokens: ["captureCreatedAPIToken(envelope.data)"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "executeSettingsAction",
                    pattern: #"func\s+executeSettingsAction\(_ action: NativeIntentSettingsAction\)\s+async\s+throws\s+->\s+SpoonjoyIntentSettingsActionExecution"#,
                    requiredTokens: [
                        "action.plan.queuePreflightDecision",
                        "executeSettingsRequest",
                        "catch let error as APITransportError where error.isOffline",
                        "appendNativeMutation(offlineFallbackMutation)",
                        "applyNativeMutation(offlineFallbackMutation",
                        "status: .queued",
                        "status: .completed"
                    ],
                    forbiddenTokens: ["captureCreatedAPIToken(envelope.data)"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "executeSettingsRequest",
                    pattern: #"func\s+executeSettingsRequest\("#,
                    requiredTokens: [
                        "let refresher = SpoonjoyIntentAPIRefresher(vault: authVault)",
                        "let configuration = try await refresher.validConfiguration()",
                        "URLSessionAPITransport(authenticationRefresher: refresher)"
                    ],
                    forbiddenTokens: ["authVault?.loadSession()", "URLSessionAPITransport()"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "SpoonjoyIntentOAuthSupport",
                    pattern: #"private\s+enum\s+SpoonjoyIntentOAuthSupport"#,
                    requiredTokens: [
                        "catch let error as URLError where spoonjoyIntentIsOffline(error.code)",
                        "kind: .offline"
                    ],
                    forbiddenTokens: ["isOffline(error.code)"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoyAppIntents.swift",
                    label: "performSettingsSessionOperation",
                    pattern: #"func\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)\s+async\s+throws"#,
                    requiredTokens: [
                        "OAuthRequests.revoke",
                        "clearClientID()"
                    ],
                    forbiddenTokens: ["case .logout, .revokeAndLogout:\n            try await authVault.clearSession()"]
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/Native/SpoonjoySettingsEntities.swift",
                    label: "API token entity display",
                    pattern: #"var\s+displayRepresentation:\s+DisplayRepresentation"#,
                    requiredTokens: [
                        "subtitle: \"\\(descriptor.subtitle)\""
                    ],
                    forbiddenTokens: ["descriptor.disambiguationLabel"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openSettings resolver",
                    pattern: #"public\s+func\s+openSettings\("#,
                    requiredTokens: [
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation(", "TokenCredentialRequests"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openAPITokens resolver",
                    pattern: #"public\s+func\s+openAPITokens\("#,
                    requiredTokens: [
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation(", "TokenCredentialRequests.createToken", "TokenCredentialRequests.revokeToken"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openAccountConnections resolver",
                    pattern: #"public\s+func\s+openAccountConnections\("#,
                    requiredTokens: [
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation(", "PrivateAccountRequests.disconnectConnection"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "updateProfileDisplay resolver",
                    pattern: #"public\s+func\s+updateProfileDisplay\("#,
                    requiredTokens: [
                        "SettingsActionPlanner(connectivity:",
                        ".updateProfile(email: email, username: username, clientMutationID: mutationID)",
                        "profileDisplayUpdate",
                        ".settingsAction(plan",
                        "route: .settings",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: ["TokenCredentialRequests.createToken", "tokenSecret"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "updateProfilePhoto resolver",
                    pattern: #"public\s+func\s+updateProfilePhoto\("#,
                    requiredTokens: [
                        "SettingsProfilePhotoStagingPolicy.webProfileParity",
                        ".uploadProfilePhoto(photo: stagedPhoto, clientMutationID: mutationID)",
                        "profilePhotoUpload",
                        ".settingsAction(plan",
                        "route: .settings"
                    ],
                    forbiddenTokens: ["photoPath: String"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "removeProfilePhoto resolver",
                    pattern: #"public\s+func\s+removeProfilePhoto\("#,
                    requiredTokens: [
                        ".removeProfilePhoto(clientMutationID: mutationID)",
                        "profilePhotoRemove",
                        ".settingsAction(plan",
                        "route: .settings"
                    ],
                    forbiddenTokens: ["TokenCredentialRequests.revokeToken"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "createAPIToken resolver",
                    pattern: #"public\s+func\s+createAPIToken\("#,
                    requiredTokens: [
                        ".createAPIToken(name: name, scopes: scopes)",
                        "TokenCredentialRequests.createToken",
                        "userFacingMessage",
                        "DeepLinkURLBuilder.url(for: .settings)"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation(", ".captureCreatedAPIToken"]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "revokeAPIToken resolver",
                    pattern: #"public\s+func\s+revokeAPIToken\("#,
                    requiredTokens: [
                        "let credentialID = try tokenIDForMutation(token)",
                        ".revokeAPIToken(credentialID: credentialID)",
                        "SettingsOnlineOnlyReason.apiTokenRevoke",
                        "TokenCredentialRequests.revokeToken"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "disconnectAccountConnection resolver",
                    pattern: #"public\s+func\s+disconnectAccountConnection\("#,
                    requiredTokens: [
                        "let connectionID = try accountConnectionIDForMutation(connection)",
                        ".disconnectOAuthConnection(connectionID: connectionID)",
                        "SettingsOnlineOnlyReason.oauthConnectionDisconnect",
                        "PrivateAccountRequests.disconnectConnection"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openPasskeys resolver",
                    pattern: #"public\s+func\s+openPasskeys\("#,
                    requiredTokens: [
                        ".managePasskeys",
                        "secureHandoffRoutes.handoff(target: .passkeys)",
                        "https://spoonjoy.app/account/settings#passkeys"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "openPassword resolver",
                    pattern: #"public\s+func\s+openPassword\("#,
                    requiredTokens: [
                        ".managePassword",
                        "secureHandoffRoutes.handoff(target: .password)",
                        "https://spoonjoy.app/account/settings#password"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "linkProvider resolver",
                    pattern: #"public\s+func\s+linkProvider\("#,
                    requiredTokens: [
                        ".linkProvider(provider)",
                        "secureHandoffRoutes.handoff(target: .providerLink(provider))",
                        "https://spoonjoy.app/auth/"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                    label: "logout resolver",
                    pattern: #"public\s+func\s+logout\("#,
                    requiredTokens: [
                        ".logout",
                        "SettingsOnlineOnlyReason.logout",
                        "sessionOperation"
                    ],
                    forbiddenTokens: ["NativeQueuedMutation", ".nativeMutation("]
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }
}

private func profileSettingsIntentForbiddenProductTokens() -> [String] {
    [
        "@Parameter(title: \"Token ID\")",
        "@Parameter(title: \"Connection ID\")",
        "var tokenID: String",
        "var credentialID: String",
        "var connectionID: String",
        "String-only profile settings App Intent",
        "CommentIntent",
        "FeedIntent",
        "MessageIntent",
        "MailIntent",
        "social-feed",
        "/comments",
        "/feeds",
        "/messages",
        "mailto:",
        "MFMailComposeViewController",
        "MessageUI",
        "TODO ProfileSettingsIntent",
        "eventually add profile settings intents"
    ]
}

private func profileSettingsIntentForbiddenSecretTokens() -> [String] {
    [
        "StringCredentialSecret",
        "createdToken",
        "createdAPIToken.token",
        "rawToken",
        "tokenSecret",
        "revealedSecret",
        "secretValue"
    ]
}

private func profileSettingsIntentSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String: [String]]
) -> [String] {
    var failures: [String] = []
    for relativePath in requiredFiles {
        guard let content = try? profileSettingsIntentReadRepoFile(relativePath) else {
            failures.append("missing \(relativePath)")
            continue
        }
        let uncommented = profileSettingsIntentUncommentedSource(content, relativePath: relativePath)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens[relativePath, default: []] where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }
    return failures
}

private func profileSettingsIntentShortcutBudgetFailures(
    relativePath: String,
    maximumShortcuts: Int,
    libraryOnlyIntentNames: [String]
) -> [String] {
    guard let content = try? profileSettingsIntentReadRepoFile(relativePath) else {
        return ["missing \(relativePath)"]
    }
    let uncommented = profileSettingsIntentUncommentedSwift(content)
    let shortcutCount = uncommented.components(separatedBy: "AppShortcut(").count - 1
    var failures: [String] = []
    if shortcutCount > maximumShortcuts {
        failures.append("\(relativePath) declares \(shortcutCount) App Shortcuts, above Apple limit \(maximumShortcuts)")
    }

    if let body = profileSettingsIntentDeclarationBody(in: uncommented, pattern: #"struct\s+SpoonjoyAppShortcuts\s*:\s*AppShortcutsProvider"#) {
        for intentName in libraryOnlyIntentNames where body.contains("\(intentName)(") {
            failures.append("\(relativePath) promotes library-only \(intentName) into AppShortcuts")
        }
    } else {
        failures.append("\(relativePath) missing body for SpoonjoyAppShortcuts")
    }
    return failures
}

private func profileSettingsIntentBodyContractFailures(
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
        guard let content = try? profileSettingsIntentReadRepoFile(contract.relativePath) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }
        let uncommented = profileSettingsIntentUncommentedSource(content, relativePath: contract.relativePath)
        guard let body = profileSettingsIntentDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func profileSettingsIntentReadRepoFile(_ relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

private func profileSettingsIntentDeclarationBody(in content: String, pattern: String) -> String? {
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

private func profileSettingsIntentUncommentedSource(_ content: String, relativePath: String) -> String {
    relativePath.hasSuffix(".swift") ? profileSettingsIntentUncommentedSwift(content) : content
}

private func profileSettingsIntentUncommentedSwift(_ content: String) -> String {
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
