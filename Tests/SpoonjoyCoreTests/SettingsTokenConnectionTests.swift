import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Native settings profile tokens and connections parity")
struct SettingsTokenConnectionTests {
    fileprivate static let createdAt = "2026-06-28T00:00:00.000Z"
    fileprivate static let now = Date(timeIntervalSince1970: 1_782_630_000)
    fileprivate static let configuration = APIClientConfiguration(
        baseURL: URL(string: "https://spoonjoy.app")!,
        bearerToken: "sj_private_token"
    )

    @Test("settings surface exposes signed-in account state, signed-out handoff, tokens, connections, and conflicts")
    func settingsSurfaceExposesAccountTokenConnectionState() throws {
        let queuedProfileUpdate = NativeQueuedMutation.profileDisplayUpdate(
            email: "new-ari@example.com",
            username: "newari",
            clientMutationID: "cm_profile_display",
            createdAt: Self.createdAt
        )
        let conflict = NativeSyncConflict(
            clientMutationID: "cm_profile_display",
            kind: .validation,
            serverRevision: .updatedAt(Self.createdAt),
            message: "Profile changed on another device."
        )
        let surfaceData = SettingsSurfaceData(
            account: SettingsAccountProfile(
                id: "chef_ari",
                email: "ari@example.com",
                username: "ari",
                photoURL: URL(string: "https://spoonjoy.app/cdn/profiles/ari.jpg"),
                hasPassword: true,
                linkedProviders: [
                    SettingsLinkedProvider(provider: .google, providerUsername: "ari@gmail.com"),
                    SettingsLinkedProvider(provider: .github, providerUsername: "arimendelow")
                ],
                passkeys: [
                    SettingsPasskeySummary(
                        id: "passkey_mac",
                        name: "MacBook Touch ID",
                        transports: "internal",
                        createdAt: "2026-06-20T00:00:00.000Z"
                    )
                ]
            ),
            notifications: SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: true,
                notifyForkOfMyRecipe: false,
                notifyCookbookSaveOfMine: true,
                notifyFellowChefOriginCook: false
            ),
            apiTokens: [
                SettingsAPITokenSummary(
                    id: "cred_kitchen_ipad",
                    name: "Kitchen iPad",
                    tokenPrefix: "sj_live_abcd",
                    scopes: ["recipes:read", "shopping_list:write"],
                    createdAt: "2026-06-01T00:00:00.000Z",
                    updatedAt: "2026-06-02T00:00:00.000Z",
                    lastUsedAt: nil,
                    revokedAt: nil,
                    expiresAt: nil
                )
            ],
            oauthConnections: [
                SettingsOAuthConnectionSummary(
                    id: "conn_mobile_importer",
                    clientID: "cm_mobile_importer",
                    clientName: "Mobile Importer",
                    resource: nil,
                    scopes: ["shopping_list:read", "shopping_list:write"],
                    createdAt: "2026-06-02T00:00:00.000Z",
                    refreshTokenCount: 1,
                    accessTokenCount: 2
                )
            ],
            environment: .production,
            offline: .available(snapshotCount: 7, lastRestoredAt: "2026-06-27T23:00:00.000Z"),
            source: .live(requestID: "req_settings", validatedAt: Self.now)
        )

        let viewModel = SettingsSurfaceViewModel(
            data: surfaceData,
            queuedMutations: [queuedProfileUpdate],
            conflicts: [conflict],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )

        #expect(viewModel.sections.map(\.id) == [
            .profile,
            .security,
            .notifications,
            .apiTokens,
            .connections,
            .environment,
            .offline
        ])
        #expect(viewModel.profileDraft == SettingsProfileDraft(
            email: "ari@example.com",
            username: "ari",
            photo: .remote(URL(string: "https://spoonjoy.app/cdn/profiles/ari.jpg")!)
        ))
        #expect(viewModel.notificationDraft == SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        ))
        #expect(viewModel.apiTokenRows.map(\.id) == ["cred_kitchen_ipad"])
        #expect(viewModel.apiTokenRows.map(\.tokenPrefix) == ["sj_live_abcd"])
        #expect(viewModel.apiTokenRows.map(\.updatedAt) == ["2026-06-02T00:00:00.000Z"])
        #expect(viewModel.apiTokenRows.map(\.revealedSecret) == [nil])
        #expect(viewModel.oauthConnectionRows.map(\.id) == ["conn_mobile_importer"])
        #expect(viewModel.securityRows.map(\.id) == [.password, .passkeys, .providerLinks])
        #expect(viewModel.queuedWorkSummary == "1 account change waiting to sync")
        #expect(viewModel.conflictBanner == SettingsSurfaceConflictBanner(
            localClientMutationID: "cm_profile_display",
            message: "Profile changed on another device.",
            actionTitle: "Review account conflict"
        ))
        #expect(viewModel.offlineIndicator.display == .conflict(
            recordID: "cm_profile_display",
            mutationID: "cm_profile_display"
        ))

        let signedOut = SettingsSurfaceViewModel.signedOut(
            environment: .production,
            offline: .unavailable,
            secureHandoffRoutes: .spoonjoyApp
        )
        #expect(signedOut.sections.map(\.id) == [.session, .environment, .offline])
        #expect(signedOut.profileDraft == nil)
        #expect(signedOut.apiTokenRows.isEmpty)
        #expect(signedOut.oauthConnectionRows.isEmpty)
        #expect(signedOut.primaryAuthAction == SettingsSecureHandoff(
            target: .login,
            url: URL(string: "https://spoonjoy.app/login")!
        ))
    }

    @Test("settings view model covers queued offline signed-in empty and fresh cache states")
    func settingsViewModelCoversQueuedOfflineSignedInEmptyAndFreshCacheStates() throws {
        let account = SettingsAccountProfile(
            id: "chef_queue",
            email: "queue@example.com",
            username: "queueari",
            photoURL: nil,
            hasPassword: false,
            linkedProviders: [],
            passkeys: []
        )
        let liveData = SettingsSurfaceData(
            account: account,
            notifications: nil,
            apiTokens: [],
            oauthConnections: [],
            environment: .production,
            offline: .available(snapshotCount: 1, lastRestoredAt: nil),
            source: .live(requestID: "req_queue", validatedAt: Self.now)
        )
        let accountMutation = NativeQueuedMutation.profilePhotoRemove(clientMutationID: "cm_remove_photo", createdAt: Self.createdAt)
        let unrelatedMutation = NativeQueuedMutation.shoppingAddItem(
            name: "lemons",
            quantity: 2,
            unit: "each",
            categoryKey: nil,
            iconKey: nil,
            clientMutationID: "cm_shopping",
            createdAt: Self.createdAt
        )
        let queued = SettingsSurfaceViewModel(
            data: liveData,
            queuedMutations: [accountMutation, unrelatedMutation],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )
        #expect(queued.profileDraft == SettingsProfileDraft(email: "queue@example.com", username: "queueari", photo: nil))
        #expect(queued.queuedWorkSummary == "1 account change waiting to sync")
        #expect(queued.offlineIndicator.display == .queuedWork(count: 1, oldestClientMutationID: "cm_remove_photo"))
        let queuedPlan = try queued.actionPlanner.plan(.updateProfile(
            email: "queued-plan@example.com",
            username: "queuedplan",
            clientMutationID: "cm_queued_plan"
        ))
        #expect(queuedPlan.offlineFallbackMutation?.queueableKind == .profileDisplayUpdate)
        #expect(queuedPlan.queuePreflightDecision(queuedMutations: [accountMutation, unrelatedMutation]) == .queueMutation(
            try requireMutation(queuedPlan.offlineFallbackMutation, "queued profile preflight fallback"),
            drainImmediately: true
        ))
        #expect(queuedPlan.queuePreflightDecision(queuedMutations: [unrelatedMutation]) == nil)

        let twoQueued = SettingsSurfaceViewModel(
            data: liveData,
            queuedMutations: [
                accountMutation,
                NativeQueuedMutation.profilePhotoRemove(clientMutationID: "cm_remove_second_photo", createdAt: Self.createdAt)
            ],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )
        #expect(twoQueued.queuedWorkSummary == "2 account changes waiting to sync")

        let offline = SettingsSurfaceViewModel(
            data: liveData,
            queuedMutations: [],
            conflicts: [],
            connectivity: .offline,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )
        #expect(offline.offlineIndicator.display == .offline)
        let offlinePlan = try offline.actionPlanner.plan(.updateProfile(
            email: "offline-plan@example.com",
            username: "offlineplan",
            clientMutationID: "cm_offline_plan"
        ))
        #expect(offlinePlan.queuePreflightDecision(queuedMutations: [accountMutation]) == .queueMutation(
            try requireMutation(offlinePlan.queuedMutation, "offline queued profile preflight"),
            drainImmediately: false
        ))

        let freshCached = SettingsSurfaceViewModel(
            data: SettingsSurfaceData(
                account: account,
                notifications: nil,
                apiTokens: [],
                oauthConnections: [],
                environment: .production,
                offline: .available(snapshotCount: 1, lastRestoredAt: nil),
                source: .cache(lastValidatedAt: Self.now)
            ),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now }
        )
        #expect(freshCached.offlineIndicator.display == .synced)

        let signedInEmpty = SettingsSurfaceViewModel(
            data: SettingsSurfaceData(
                account: nil,
                notifications: nil,
                apiTokens: [],
                oauthConnections: [],
                environment: .production,
                offline: .unavailable,
                source: .cache(lastValidatedAt: .distantPast)
            ),
            queuedMutations: [],
            conflicts: [],
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.now },
            showsPrimaryAuthActionWhenSignedOut: false
        )
        #expect(signedInEmpty.sections.map(\.id) == [.environment, .offline])
        #expect(signedInEmpty.primaryAuthAction == nil)
    }

    @Test("live and snapshot repositories read the same account settings API surface")
    func repositoriesReadLiveAndSnapshotSettingsSurface() async throws {
        let transport = RecordingSettingsSurfaceTransport(
            account: SettingsAccountProfile(
                id: "chef_ari",
                email: "ari@example.com",
                username: "ari",
                photoURL: URL(string: "https://spoonjoy.app/cdn/profiles/ari.jpg"),
                hasPassword: true,
                linkedProviders: [],
                passkeys: []
            ),
            notifications: SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: true,
                notifyForkOfMyRecipe: true,
                notifyCookbookSaveOfMine: true,
                notifyFellowChefOriginCook: true
            ),
            tokens: [
                SettingsAPITokenSummary(
                    id: "cred_cli",
                    name: "CLI",
                    tokenPrefix: "sj_live_cli",
                    scopes: ["tokens:read"],
                    createdAt: "2026-06-01T00:00:00.000Z",
                    updatedAt: "2026-06-02T00:00:00.000Z",
                    lastUsedAt: nil,
                    revokedAt: nil,
                    expiresAt: nil
                )
            ],
            connections: [
                SettingsOAuthConnectionSummary(
                    id: "conn_cli",
                    clientID: "cm_cli",
                    clientName: "CLI",
                    resource: "https://spoonjoy.app/mcp",
                    scopes: ["kitchen:read"],
                    createdAt: "2026-06-02T00:00:00.000Z",
                    refreshTokenCount: 1,
                    accessTokenCount: 1
                )
            ]
        )
        let liveRepository = LiveSettingsSurfaceRepository(
            transport: transport,
            cache: NativeDurableCache(records: []),
            configuration: Self.configuration
        )

        let live = try await liveRepository.fetchSettingsSurface(
            accountID: "chef_ari",
            environment: .production
        )

        let expectedRequestPaths = [
            "/api/v1/me",
            "/api/v1/me/notification-preferences",
            "/api/v1/tokens",
            "/api/v1/me/connections"
        ]
        #expect(transport.requestPaths.count == expectedRequestPaths.count)
        #expect(Set(transport.requestPaths) == Set(expectedRequestPaths))
        #expect(live.data.account?.username == "ari")
        #expect(live.data.apiTokens.map(\.tokenPrefix) == ["sj_live_cli"])
        #expect(live.data.oauthConnections.map(\.clientID) == ["cm_cli"])
        #expect(live.data.source == .live(requestID: "req_settings_surface", validatedAt: transport.validatedAt))
        #expect(live.persistedRecords.map(\.metadata.domain) == [
            .settings,
            .notificationPreferences,
            .tokenMetadata,
            .connectionStatus
        ])

        let snapshot = SettingsSurfaceCacheSnapshot(
            accountID: "chef_ari",
            environment: .production,
            records: live.persistedRecords
        )
        let cached = try SnapshotSettingsSurfaceRepository(snapshot: snapshot).fetchSettingsSurface()
        #expect(cached.data.account?.email == "ari@example.com")
        #expect(cached.data.notifications?.notifyForkOfMyRecipe == true)
        #expect(cached.data.apiTokens.map(\.id) == ["cred_cli"])
        #expect(cached.data.oauthConnections.map(\.id) == ["conn_cli"])
        #expect(cached.data.source == .cache(lastValidatedAt: transport.validatedAt))

        let emptySnapshot = try SnapshotSettingsSurfaceRepository(snapshot: SettingsSurfaceCacheSnapshot(
            accountID: "chef_empty",
            environment: .production,
            records: []
        )).fetchSettingsSurface()
        #expect(emptySnapshot.data.account == nil)
        #expect(emptySnapshot.data.notifications == nil)
        #expect(emptySnapshot.data.apiTokens.isEmpty)
        #expect(emptySnapshot.data.oauthConnections.isEmpty)
        #expect(emptySnapshot.data.source == .cache(lastValidatedAt: .distantPast))
    }

    @Test("URLSession settings transport builds exact requests and decodes every settings response")
    func urlSessionSettingsTransportBuildsExactRequestsAndDecodesResponses() async throws {
        let apiTransport = RecordingSettingsAPITransport(now: Self.now)
        let transport = URLSessionSettingsSurfaceTransport(transport: apiTransport, now: { Self.now })

        let account = try await transport.fetchAccount(PrivateAccountRequests.currentAccount(), configuration: Self.configuration)
        let notifications = try await transport.fetchNotificationPreferences(PrivateAccountRequests.notificationPreferences(), configuration: Self.configuration)
        let tokens = try await transport.fetchAPITokens(TokenCredentialRequests.listTokens(), configuration: Self.configuration)
        let connections = try await transport.fetchOAuthConnections(PrivateAccountRequests.connections(), configuration: Self.configuration)

        #expect(account.data.username == "transport")
        #expect(notifications.data.notifySpoonOnMyRecipe == true)
        #expect(tokens.data.map(\.id) == ["cred_transport"])
        #expect(connections.data.map(\.clientID) == ["client_transport"])
        #expect(account.validatedAt == Self.now)
        #expect(apiTransport.requests == [
            RecordedSettingsAPIRequest(method: .get, path: "/api/v1/me", bearerToken: "sj_private_token"),
            RecordedSettingsAPIRequest(method: .get, path: "/api/v1/me/notification-preferences", bearerToken: "sj_private_token"),
            RecordedSettingsAPIRequest(method: .get, path: "/api/v1/tokens", bearerToken: "sj_private_token"),
            RecordedSettingsAPIRequest(method: .get, path: "/api/v1/me/connections", bearerToken: "sj_private_token")
        ])

        let defaultClockTransport = URLSessionSettingsSurfaceTransport(transport: RecordingSettingsAPITransport(now: Self.now))
        let defaultClockAccount = try await defaultClockTransport.fetchAccount(PrivateAccountRequests.currentAccount(), configuration: Self.configuration)
        #expect(defaultClockAccount.data.username == "transport")
        #expect(defaultClockAccount.validatedAt.timeIntervalSince1970 > 0)
    }

    @Test("settings response decoders accept current legacy and empty token connection shapes")
    func settingsResponseDecodersAcceptCurrentLegacyAndEmptyShapes() throws {
        let tokensPayload = try JSONDecoder().decode(SettingsAPITokenListResponse.self, from: Data("""
        {
          "tokens": [
            {
              "id": "cred_tokens_key",
              "name": "Tokens key",
              "tokenPrefix": "sj_tokens",
              "scopes": ["recipes:read"],
              "createdAt": "2026-06-28T00:00:00.000Z",
              "lastUsedAt": null,
              "revokedAt": null,
              "expiresAt": null
            }
          ]
        }
        """.utf8))
        #expect(tokensPayload.tokens.map(\.id) == ["cred_tokens_key"])
        #expect(tokensPayload.tokens.map(\.updatedAt) == ["2026-06-28T00:00:00.000Z"])

        let emptyTokens = try JSONDecoder().decode(SettingsAPITokenListResponse.self, from: Data(#"{}"#.utf8))
        #expect(emptyTokens.tokens.isEmpty)
        #expect(SettingsAPITokenListResponse(tokens: tokensPayload.tokens).tokens == tokensPayload.tokens)

        let currentConnections = try JSONDecoder().decode(SettingsOAuthConnectionListResponse.self, from: Data("""
        {
          "connections": [
            {
              "id": "conn_current",
              "clientId": "client_current",
              "clientName": "Current Client",
              "resource": "https://spoonjoy.app/mcp",
              "scopes": ["shopping_list:read"],
              "createdAt": "2026-06-28T00:00:00.000Z",
              "refreshTokenCount": 2,
              "accessTokenCount": 3
            }
          ]
        }
        """.utf8))
        #expect(currentConnections.connections.map(\.id) == ["conn_current"])

        let legacyConnections = try JSONDecoder().decode(SettingsOAuthConnectionListResponse.self, from: Data("""
        {
          "oauthConnections": [
            {
              "id": "conn_legacy",
              "clientId": "client_legacy",
              "clientName": "Legacy Client",
              "resource": null,
              "scopes": [],
              "createdAt": "2026-06-28T00:00:00.000Z",
              "refreshTokenCount": 0,
              "accessTokenCount": 1
            }
          ]
        }
        """.utf8))
        #expect(legacyConnections.connections.map(\.clientID) == ["client_legacy"])
        let emptyConnections = try JSONDecoder().decode(SettingsOAuthConnectionListResponse.self, from: Data(#"{}"#.utf8))
        #expect(emptyConnections.connections.isEmpty)
        #expect(SettingsOAuthConnectionListResponse(connections: currentConnections.connections).connections == currentConnections.connections)

        let created = SettingsCreatedAPIToken(token: "sj_created_once", credential: tokensPayload.tokens[0])
        #expect(created.token == "sj_created_once")
        #expect(created.credential.tokenPrefix == "sj_tokens")
    }

    @Test("snapshot settings restore covers legacy notifications and sparse token connection metadata")
    func snapshotSettingsRestoreCoversLegacyNotificationsAndSparseMetadata() throws {
        let records = [
            try settingsCacheRecord(
                domain: .settings,
                payload: .settings(account: SettingsAccountProfile(
                    id: "chef_cache",
                    email: "cache@example.com",
                    username: "cacheari",
                    photoURL: nil,
                    hasPassword: false,
                    linkedProviders: [],
                    passkeys: []
                ))
            ),
            try settingsCacheRecord(
                domain: .notificationPreferences,
                payload: .notificationPreferences(marketingEnabled: true, cookingRemindersEnabled: false)
            ),
            try settingsCacheRecord(
                domain: .tokenMetadata,
                payload: .tokenMetadata(credentials: [
                    NativeTokenMetadata(
                        id: "cred_sparse",
                        name: "Sparse token",
                        tokenPrefix: "",
                        scopes: ["recipes:read"]
                    )
                ])
            ),
            try settingsCacheRecord(
                domain: .connectionStatus,
                payload: .connectionStatus(connections: [
                    NativeConnectionStatus(
                        id: "conn_sparse",
                        provider: "github",
                        status: .connected
                    )
                ])
            )
        ]
        let cache = NativeDurableCache(records: records)
        #expect(cache.record(for: .tokenMetadata)?.id == "token-metadata")

        let restored = try SnapshotSettingsSurfaceRepository(snapshot: SettingsSurfaceCacheSnapshot(
            accountID: "chef_cache",
            environment: .production,
            records: records
        )).fetchSettingsSurface()

        #expect(restored.data.account?.username == "cacheari")
        #expect(restored.data.notifications == SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
        ))
        #expect(restored.data.apiTokens == [
            SettingsAPITokenSummary(
                id: "cred_sparse",
                name: "Sparse token",
                tokenPrefix: "cred_sparse",
                scopes: ["recipes:read"],
                createdAt: "",
                updatedAt: "",
                lastUsedAt: nil,
                revokedAt: nil,
                expiresAt: nil
            )
        ])
        #expect(restored.data.oauthConnections == [
            SettingsOAuthConnectionSummary(
                id: "conn_sparse",
                clientID: "conn_sparse",
                clientName: "github",
                resource: nil,
                scopes: [],
                createdAt: "",
                refreshTokenCount: 0,
                accessTokenCount: 0
            )
        ])
    }

    @Test("account settings decoder accepts legacy passkeys without created timestamps")
    func accountSettingsDecoderAcceptsLegacyPasskeyTimestamps() throws {
        let envelope = try APIEnvelope<SettingsAccountProfile>.decode(Data("""
        {
          "ok": true,
          "requestId": "req_account",
          "data": {
            "id": "chef_ari",
            "email": "ari@example.com",
            "username": "ari",
            "photoUrl": null,
            "hasPassword": true,
            "oauthAccounts": [],
            "passkeys": [
              {
                "id": "passkey_legacy",
                "name": "Passkey",
                "transports": null,
                "createdAt": null
              },
              {
                "id": "passkey_modern",
                "name": "Kitchen Mac",
                "transports": "internal",
                "createdAt": "2026-06-20T00:00:00.000Z"
              }
            ]
          }
        }
        """.utf8))

        #expect(envelope.data.passkeys.map(\.id) == ["passkey_legacy", "passkey_modern"])
        #expect(envelope.data.passkeys.map(\.createdAt) == [nil, "2026-06-20T00:00:00.000Z"])
    }

    @Test("profile and notification actions plan exact REST requests with offline queue fallbacks")
    func profileAndNotificationActionsPlanRESTAndOfflineFallbacks() throws {
        let planner = SettingsActionPlanner(
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.createdAt }
        )

        let profile = try planner.plan(.updateProfile(
            email: "new-ari@example.com",
            username: "newari",
            clientMutationID: "cm_profile"
        ))
        try assertJSONRequest(try remoteRequest(from: profile), method: .patch, path: "/api/v1/me", expected: [
            "email": "new-ari@example.com",
            "username": "newari"
        ])
        #expect(profile.queuedMutation == nil)
        let profileFallback = try requireMutation(profile.offlineFallbackMutation, "profile fallback")
        #expect(profileFallback.queueableKind == .profileDisplayUpdate)
        try assertJSONRequest(try queuedRequest(from: profileFallback), method: .patch, path: "/api/v1/me", expected: [
            "email": "new-ari@example.com",
            "username": "newari",
            "clientMutationId": "cm_profile"
        ])

        let photo = NativeStagedMediaUpload(
            localStageID: "stage_profile_photo",
            fileName: "avatar.gif",
            contentType: "image/gif",
            data: Data([0x47, 0x49, 0x46])
        )
        let upload = try planner.plan(.uploadProfilePhoto(photo: photo, clientMutationID: "cm_photo"))
        try assertMultipartRequest(
            try remoteRequest(from: upload),
            method: .post,
            path: "/api/v1/me/photo",
            fileField: "photo",
            fileName: "avatar.gif",
            contentType: "image/gif",
            data: Data([0x47, 0x49, 0x46])
        )
        #expect(upload.queuedMutation == nil)
        #expect(try requireMutation(upload.offlineFallbackMutation, "photo fallback").queueableKind == .profilePhotoUpload)

        let removePhoto = try planner.plan(.removeProfilePhoto(clientMutationID: "cm_remove_photo"))
        assertNoBodyRequest(
            try remoteRequest(from: removePhoto),
            method: .delete,
            path: "/api/v1/me/photo",
            queryItems: []
        )
        #expect(try requireMutation(removePhoto.offlineFallbackMutation, "remove photo fallback").queueableKind == .profilePhotoRemove)

        let notifications = try planner.plan(.updateNotificationPreferences(
            SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: false,
                notifyForkOfMyRecipe: true,
                notifyCookbookSaveOfMine: false,
                notifyFellowChefOriginCook: true
            ),
            clientMutationID: "cm_notifications"
        ))
        try assertJSONRequest(
            try remoteRequest(from: notifications),
            method: .patch,
            path: "/api/v1/me/notification-preferences",
            expected: [
                "notifySpoonOnMyRecipe": false,
                "notifyForkOfMyRecipe": true,
                "notifyCookbookSaveOfMine": false,
                "notifyFellowChefOriginCook": true
            ]
        )
        #expect(try requireMutation(notifications.offlineFallbackMutation, "notification fallback").queueableKind == .notificationPreferenceUpdate)

        let offlinePlanner = SettingsActionPlanner(
            connectivity: .offline,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.createdAt }
        )
        let queuedProfile = try offlinePlanner.plan(.updateProfile(
            email: "queued@example.com",
            username: "queuedari",
            clientMutationID: "cm_profile_offline"
        ))
        #expect(queuedProfile.remoteRequestBuilder == nil)
        #expect(queuedProfile.offlineFallbackMutation == nil)
        #expect(queuedProfile.queuedMutation?.queueableKind == .profileDisplayUpdate)
        #expect(queuedProfile.onlineOnlyReason == nil)
        try assertJSONRequest(try queuedRequest(from: requireMutation(queuedProfile.queuedMutation, "queued profile update")), method: .patch, path: "/api/v1/me", expected: [
            "email": "queued@example.com",
            "username": "queuedari",
            "clientMutationId": "cm_profile_offline"
        ])

        let defaultClockPlanner = SettingsActionPlanner(
            connectivity: .offline,
            secureHandoffRoutes: .spoonjoyApp
        )
        let defaultClockProfile = try defaultClockPlanner.plan(.updateProfile(
            email: "clock@example.com",
            username: "clockari",
            clientMutationID: "cm_profile_default_clock"
        ))
        let defaultClockMutation = try requireMutation(defaultClockProfile.queuedMutation, "default clock profile update")
        #expect(defaultClockMutation.queueableKind == .profileDisplayUpdate)
        #expect(defaultClockMutation.createdAt.contains("T"))

        let queuedPhotoUpload = try offlinePlanner.plan(.uploadProfilePhoto(photo: photo, clientMutationID: "cm_photo_offline"))
        #expect(queuedPhotoUpload.remoteRequestBuilder == nil)
        #expect(queuedPhotoUpload.offlineFallbackMutation == nil)
        #expect(queuedPhotoUpload.queuedMutation?.queueableKind == .profilePhotoUpload)
        #expect(queuedPhotoUpload.onlineOnlyReason == nil)
        try assertMultipartRequest(
            try queuedRequest(from: requireMutation(queuedPhotoUpload.queuedMutation, "queued profile photo upload")),
            method: .post,
            path: "/api/v1/me/photo",
            fields: ["clientMutationId": "cm_photo_offline"],
            fileField: "photo",
            fileName: "avatar.gif",
            contentType: "image/gif",
            data: Data([0x47, 0x49, 0x46])
        )

        let queuedPhotoRemove = try offlinePlanner.plan(.removeProfilePhoto(clientMutationID: "cm_remove_photo_offline"))
        #expect(queuedPhotoRemove.remoteRequestBuilder == nil)
        #expect(queuedPhotoRemove.offlineFallbackMutation == nil)
        #expect(queuedPhotoRemove.queuedMutation?.queueableKind == .profilePhotoRemove)
        #expect(queuedPhotoRemove.onlineOnlyReason == nil)
        assertNoBodyRequest(
            try queuedRequest(from: requireMutation(queuedPhotoRemove.queuedMutation, "queued profile photo remove")),
            method: .delete,
            path: "/api/v1/me/photo",
            queryItems: [],
            extraHeaders: ["X-Client-Mutation-Id": "cm_remove_photo_offline"]
        )

        let queuedNotifications = try offlinePlanner.plan(.updateNotificationPreferences(
            SettingsNotificationPreferences(
                notifySpoonOnMyRecipe: true,
                notifyForkOfMyRecipe: false,
                notifyCookbookSaveOfMine: true,
                notifyFellowChefOriginCook: false
            ),
            clientMutationID: "cm_notifications_offline"
        ))
        #expect(queuedNotifications.remoteRequestBuilder == nil)
        #expect(queuedNotifications.offlineFallbackMutation == nil)
        #expect(queuedNotifications.queuedMutation?.queueableKind == .notificationPreferenceUpdate)
        #expect(queuedNotifications.onlineOnlyReason == nil)
        try assertJSONRequest(
            try queuedRequest(from: requireMutation(queuedNotifications.queuedMutation, "queued notification preferences")),
            method: .patch,
            path: "/api/v1/me/notification-preferences",
            expected: [
                "clientMutationId": "cm_notifications_offline",
                "notifySpoonOnMyRecipe": true,
                "notifyForkOfMyRecipe": false,
                "notifyCookbookSaveOfMine": true,
                "notifyFellowChefOriginCook": false
            ]
        )
    }

    @Test("tokens connections logout and credential handoffs are online-only while offline")
    func tokenConnectionLogoutAndCredentialActionsAreOnlineOnlyOffline() throws {
        let onlinePlanner = SettingsActionPlanner(
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.createdAt }
        )

        let createToken = try onlinePlanner.plan(.createAPIToken(
            name: "Kitchen Script",
            scopes: ["recipes:read", "shopping_list:write"]
        ))
        try assertJSONRequest(try remoteRequest(from: createToken), method: .post, path: "/api/v1/tokens", expected: [
            "name": "Kitchen Script",
            "scopes": ["recipes:read", "shopping_list:write"]
        ])
        #expect(createToken.responseHandling == .captureCreatedAPIToken)
        #expect(createToken.offlineFallbackMutation == nil)
        #expect(createToken.queuedMutation == nil)

        let createdToken = try APIEnvelope<SettingsCreatedAPIToken>.decode(Data("""
        {
          "ok": true,
          "requestId": "req_create_token",
          "data": {
            "token": "sj_created_once",
            "credential": {
              "id": "cred_created",
              "name": "Kitchen Script",
              "tokenPrefix": "sj_created",
              "scopes": ["recipes:read", "shopping_list:write"],
              "createdAt": "2026-06-28T00:00:00.000Z",
              "updatedAt": "2026-06-28T00:00:00.000Z",
              "lastUsedAt": null,
              "revokedAt": null,
              "expiresAt": null
            }
          }
        }
        """.utf8))
        #expect(createdToken.data.token == "sj_created_once")
        #expect(createdToken.data.credential.revealedSecret == nil)
        #expect(createdToken.data.credential.tokenPrefix == "sj_created")

        let currentTokenList = try JSONDecoder().decode(SettingsAPITokenListResponse.self, from: Data("""
        {
          "credentials": [
            {
              "id": "cred_current",
              "name": "Current response",
              "tokenPrefix": "sj_current",
              "createdAt": "2026-06-28T00:00:00.000Z",
              "updatedAt": "2026-06-28T00:00:00.000Z",
              "lastUsedAt": null,
              "revokedAt": null,
              "expiresAt": null
            }
          ]
        }
        """.utf8))
        #expect(currentTokenList.tokens.map(\.id) == ["cred_current"])
        #expect(currentTokenList.tokens.map(\.scopes) == [[]])

        let revokeToken = try onlinePlanner.plan(.revokeAPIToken(credentialID: "cred/with spaces"))
        assertNoBodyRequest(
            try remoteRequest(from: revokeToken),
            method: .delete,
            path: "/api/v1/tokens/cred%2Fwith%20spaces",
            queryItems: []
        )
        #expect(revokeToken.offlineFallbackMutation == nil)

        let disconnect = try onlinePlanner.plan(.disconnectOAuthConnection(connectionID: "conn/google"))
        assertNoBodyRequest(
            try remoteRequest(from: disconnect),
            method: .delete,
            path: "/api/v1/me/connections/conn%2Fgoogle",
            queryItems: []
        )
        #expect(disconnect.offlineFallbackMutation == nil)

        #expect(try onlinePlanner.plan(.managePasskeys).secureHandoff == SettingsSecureHandoff(
            target: .passkeys,
            url: URL(string: "https://spoonjoy.app/account/settings#passkeys")!
        ))
        #expect(try onlinePlanner.plan(.managePassword).secureHandoff == SettingsSecureHandoff(
            target: .password,
            url: URL(string: "https://spoonjoy.app/account/settings#password")!
        ))
        #expect(try onlinePlanner.plan(.linkProvider(.google)).secureHandoff == SettingsSecureHandoff(
            target: .providerLink(.google),
            url: URL(string: "https://spoonjoy.app/auth/google?linking=true")!
        ))

        let logout = try onlinePlanner.plan(.logout)
        #expect(logout.sessionOperation == .logout)
        #expect(logout.secureHandoff == SettingsSecureHandoff(
            target: .logout,
            url: URL(string: "https://spoonjoy.app/logout")!
        ))
        #expect(logout.queuedMutation == nil)
        #expect(logout.offlineFallbackMutation == nil)

        let revokeSession = try onlinePlanner.plan(.revokeSession)
        #expect(revokeSession.sessionOperation == .revokeAndLogout)
        #expect(revokeSession.secureHandoff == nil)
        #expect(revokeSession.queuedMutation == nil)
        #expect(revokeSession.offlineFallbackMutation == nil)

        let offlinePlanner = SettingsActionPlanner(
            connectivity: .offline,
            secureHandoffRoutes: .spoonjoyApp,
            now: { Self.createdAt }
        )
        let onlineOnlyCases: [(SettingsAction, SettingsOnlineOnlyReason)] = [
            (.createAPIToken(name: "Offline Script", scopes: ["tokens:read"]), .apiTokenCreate),
            (.revokeAPIToken(credentialID: "cred_cli"), .apiTokenRevoke),
            (.disconnectOAuthConnection(connectionID: "conn_cli"), .oauthConnectionDisconnect),
            (.logout, .logout),
            (.revokeSession, .sessionRevoke),
            (.managePasskeys, .credentialHandoff),
            (.managePassword, .credentialHandoff),
            (.linkProvider(.github), .credentialHandoff)
        ]

        for (action, reason) in onlineOnlyCases {
            let plan = try offlinePlanner.plan(action)
            #expect(plan.remoteRequestBuilder == nil)
            #expect(plan.queuedMutation == nil)
            #expect(plan.offlineFallbackMutation == nil)
            #expect(plan.secureHandoff == nil)
            #expect(plan.onlineOnlyReason == reason)
            #expect(plan.userFacingMessage == reason.message)
        }
    }

    @Test("settings action planner fails closed when offline policy mappings regress")
    func settingsActionPlannerFailsClosedWhenOfflinePolicyMappingsRegress() throws {
        let queueableRegression = SettingsActionPlanner(
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            offlinePolicyDecision: { action in
                switch action {
                case .queuedMutation:
                    NativeOfflineMutationDecision(queueableKind: .shoppingAddItem, onlineOnlyReason: nil)
                default:
                    try NativeOfflineMutationPolicy.decision(for: action)
                }
            },
            now: { Self.createdAt }
        )

        #expect(throws: SettingsActionPlanningError.offlinePolicyRejectedQueueableMutation(.profileDisplayUpdate)) {
            _ = try queueableRegression.plan(.updateProfile(
                email: "regression@example.com",
                username: "regression",
                clientMutationID: "cm_policy_regression"
            ))
        }

        let onlineOnlyRegression = SettingsActionPlanner(
            connectivity: .online,
            secureHandoffRoutes: .spoonjoyApp,
            offlinePolicyDecision: { action in
                switch action {
                case .apiTokenCreate:
                    NativeOfflineMutationDecision(queueableKind: .profileDisplayUpdate, onlineOnlyReason: nil)
                default:
                    try NativeOfflineMutationPolicy.decision(for: action)
                }
            },
            now: { Self.createdAt }
        )

        #expect(throws: SettingsActionPlanningError.offlinePolicyAllowedOnlineOnlyAction(.apiTokenCreate)) {
            _ = try onlineOnlyRegression.plan(.createAPIToken(name: "Bad policy", scopes: ["recipes:read"]))
        }
    }

    @Test("profile photo staging follows web allowlist and preserves existing draft on rejected replacement")
    func profilePhotoStagingPolicyMatchesWebAndPreservesDrafts() throws {
        let policy = SettingsProfilePhotoStagingPolicy.webProfileParity
        #expect(policy.acceptedContentTypes == ["image/jpeg", "image/png", "image/gif", "image/webp"])
        #expect(policy.maxBytes == 5 * 1_024 * 1_024)
        #expect(policy.allowsSilentEvictionOfUnsyncedPhoto == false)

        let existing = NativeStagedMediaUpload(
            localStageID: "existing_profile_photo",
            fileName: "existing.png",
            contentType: "image/png",
            data: Data([0x01, 0x02])
        )
        let badType = NativeStagedMediaUpload(
            localStageID: "bad_profile_photo",
            fileName: "bad.svg",
            contentType: "image/svg+xml",
            data: Data([0x03])
        )
        let oversized = NativeStagedMediaUpload(
            localStageID: "oversized_profile_photo",
            fileName: "huge.png",
            contentType: "image/png",
            byteCount: 6 * 1_024 * 1_024
        )
        let gif = NativeStagedMediaUpload(
            localStageID: "gif_profile_photo",
            fileName: "avatar.gif",
            contentType: "image/gif",
            data: Data([0x47, 0x49, 0x46])
        )

        let rejectedType = policy.stageReplacement(existing: existing, candidate: badType)
        #expect(rejectedType.stagedPhoto == existing)
        #expect(rejectedType.rejection == .unsupportedContentType("image/svg+xml"))

        let rejectedSize = policy.stageReplacement(existing: existing, candidate: oversized)
        #expect(rejectedSize.stagedPhoto == existing)
        #expect(rejectedSize.rejection == .fileTooLarge(maxBytes: 5 * 1_024 * 1_024))

        let accepted = policy.stageReplacement(existing: existing, candidate: gif)
        #expect(accepted.stagedPhoto == gif)
        #expect(accepted.rejection == nil)

        let explicitClear = policy.clear(existing: existing)
        #expect(explicitClear.stagedPhoto == nil)
        #expect(explicitClear.rejection == nil)
    }

    @Test("settings UI and scenario verifier expose native sections instead of web handoff placeholders")
    func settingsSourcesExposeNativeSettingsSections() throws {
        let settingsView = try readRepoFile("Apps/Spoonjoy/Shared/Views/SettingsView.swift")
        let navigation = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift")
        let rootView = try readRepoFile("Apps/Spoonjoy/Shared/AppShell/SpoonjoyRootView.swift")
        let scenarioVerifier = try readRepoFile("Sources/SpoonjoyCore/Native/ScenarioVerifier.swift")

        for token in [
            "SettingsSurfaceViewModel",
            "Profile",
            "Email",
            "Username",
            "Upload Photo",
            "Remove Photo",
            "Notifications",
            "API Tokens",
            "Connections",
            "Passkeys",
            "Password",
            "Sign Out",
            "SettingsOnlineOnlyReason",
            "SettingsSecureHandoff",
            "PendingSettingsDestructiveAction",
            "confirmationDialog(",
            "confirmSettingsAction(",
            "onlineOnlyActionsDisabled(surface)",
            "cm_settings_remove_photo_"
        ] {
            #expect(settingsView.contains(token), "SettingsView.swift missing \(token)")
        }

        for forbidden in ["tokenHash", "rawToken", "tokenSecret", "accessTokenSecret", "refreshTokenSecret", "accessTokenValue", "refreshTokenValue"] {
            #expect(!settingsView.contains(forbidden), "SettingsView.swift must not render raw credential secret field \(forbidden)")
        }

        for token in [
            "contentState.settingsSurfaceViewModel",
            "shellOfflineIndicatorState: offlineIndicatorState",
            "performSettingsAction",
            "shouldShowShellOfflineStatus",
            "routeOwnsOfflineStatus(navigation.route)",
            "detailContentWithShellStatus",
            "shellOfflineStatusBar",
            "VStack(spacing: 0)",
            "queuePreflightDecision(queuedMutations: contentState.queuedMutations)",
            "queueSettingsMutationIfNeeded",
            "executeSettingsActionRequest",
            "performSettingsSessionOperation"
        ] {
            #expect(navigation.contains(token), "PlatformNavigationView.swift missing \(token)")
        }

        for token in [
            "private func signedOutContent(contentState:",
            "if navigation.route == .settings",
            "shellOfflineIndicatorState: contentState.offlineIndicatorState",
            "SignedOutSetupView(",
            "onDismissOfflineIndicator: liveStore.dismissOfflineIndicator"
        ] {
            #expect(rootView.contains(token), "SpoonjoyRootView.swift missing \(token)")
        }

        #expect(!rootView.contains("signedOutRouteUsesNativeShell"), "Signed-out launch must not bypass native Apple sign-in into the shell.")

        #expect(!rootView.contains("""
            SettingsView(
                viewModel: contentState.settingsViewModel,
                settingsSurfaceViewModel: contentState.settingsSurfaceViewModel,
                onDismissOfflineIndicator: liveStore.dismissOfflineIndicator
            )
            .safeAreaInset(edge: .bottom)
            """))

        for token in [
            "settings token connection surface",
            "settings profile update",
            "settings token create online-only",
            "settings connection disconnect online-only",
            "settings secure handoff"
        ] {
            #expect(scenarioVerifier.contains(token), "ScenarioVerifier.swift missing \(token)")
        }
    }
}

private func remoteRequest(from plan: SettingsActionPlan) throws -> APIRequest {
    guard let builder = plan.remoteRequestBuilder else {
        throw SettingsTokenConnectionTestFailure(description: "Missing remote settings request")
    }
    return try builder.urlRequest(configuration: SettingsTokenConnectionTests.configuration)
}

private func queuedRequest(from mutation: NativeQueuedMutation) throws -> APIRequest {
    try mutation.requestBuilder().urlRequest(configuration: SettingsTokenConnectionTests.configuration)
}

private func requireMutation(_ mutation: NativeQueuedMutation?, _ label: String) throws -> NativeQueuedMutation {
    guard let mutation else {
        throw SettingsTokenConnectionTestFailure(description: "Missing \(label)")
    }
    return mutation
}

private func assertJSONRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    expected: [String: Any]
) throws {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems.isEmpty)
    #expect(request.headers["Accept"] == "application/json")
    #expect(request.headers["Authorization"] == "Bearer sj_private_token")
    #expect(request.headers["Content-Type"] == "application/json")
    #expect(request.responseCachePolicy == .privateNoStore)
    #expect(NSDictionary(dictionary: try jsonBody(from: request)).isEqual(to: expected))
}

private func assertNoBodyRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    queryItems: [URLQueryItem],
    extraHeaders: [String: String] = [:]
) {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems == queryItems)
    var expectedHeaders = [
        "Accept": "application/json",
        "Authorization": "Bearer sj_private_token"
    ]
    expectedHeaders.merge(extraHeaders) { _, next in next }
    #expect(request.headers == expectedHeaders)
    #expect(request.body == nil)
    #expect(request.responseCachePolicy == .privateNoStore)
}

private func assertMultipartRequest(
    _ request: APIRequest,
    method: APIRequestMethod,
    path: String,
    fields: [String: String] = [:],
    fileField: String,
    fileName: String,
    contentType: String,
    data: Data
) throws {
    #expect(request.method == method)
    #expect(request.url.baseURL.absoluteString == "https://spoonjoy.app")
    #expect(request.url.path == path)
    #expect(request.queryItems.isEmpty)
    #expect(request.headers["Accept"] == "application/json")
    #expect(request.headers["Authorization"] == "Bearer sj_private_token")
    #expect(request.responseCachePolicy == .privateNoStore)
    let contentTypeHeader = try #require(request.headers["Content-Type"])
    #expect(contentTypeHeader.hasPrefix("multipart/form-data; boundary="))
    let body = try #require(request.body)
    let bodyText = String(decoding: body, as: UTF8.self)
    for (name, value) in fields {
        #expect(bodyText.contains("name=\"\(name)\""))
        #expect(bodyText.contains("\r\n\r\n\(value)\r\n"))
    }
    #expect(bodyText.contains("name=\"\(fileField)\"; filename=\"\(fileName)\""))
    #expect(bodyText.contains("Content-Type: \(contentType)"))
    #expect(body.range(of: data) != nil)
}

private func jsonBody(from request: APIRequest) throws -> [String: Any] {
    let body = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
}

private func readRepoFile(_ relativePath: String) throws -> String {
    let url = repoRootURL().appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func repoRootURL() -> URL {
    var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while candidate.path != "/" {
        if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private struct SettingsTokenConnectionTestFailure: Error, CustomStringConvertible {
    let description: String
}

private func settingsCacheRecord(
    domain: NativeCacheDomain,
    payload: NativeCachePayload,
    accountID: String = "chef_cache",
    environment: NativeCacheEnvironment = .production
) throws -> NativeCacheRecord {
    try NativeCacheRecord(
        id: domain.stableRecordID,
        metadata: NativeCacheRecordMetadata(
            accountID: accountID,
            environment: environment,
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            domain: domain,
            fetchedAt: SettingsTokenConnectionTests.now,
            lastValidatedAt: SettingsTokenConnectionTests.now,
            sourceEndpoint: "local://settings-test/\(domain.stableRecordID)",
            serverRevision: .localRevision("settings-test")
        ),
        payload: payload
    )
}

private struct RecordedSettingsAPIRequest: Equatable {
    let method: APIRequestMethod
    let path: String
    let bearerToken: String?
}

private final class RecordingSettingsAPITransport: SpoonjoyAPITransport, @unchecked Sendable {
    private let now: Date
    private(set) var requests: [RecordedSettingsAPIRequest] = []

    init(now: Date) {
        self.now = now
    }

    func send<Value: Decodable & Equatable>(
        _ request: APIRequestBuilder,
        configuration: APIClientConfiguration,
        decode _: Value.Type
    ) async throws -> APIEnvelope<Value> {
        let apiRequest = try request.urlRequest(configuration: configuration)
        requests.append(RecordedSettingsAPIRequest(
            method: apiRequest.method,
            path: apiRequest.url.path,
            bearerToken: configuration.bearerToken
        ))

        if Value.self == SettingsAccountProfile.self,
           let data = SettingsAccountProfile(
            id: "chef_transport",
            email: "transport@example.com",
            username: "transport",
            photoURL: nil,
            hasPassword: true,
            linkedProviders: [],
            passkeys: []
           ) as? Value {
            return APIEnvelope(requestID: "req_transport_account", data: data)
        }
        if Value.self == SettingsNotificationPreferences.self,
           let data = SettingsNotificationPreferences(
            notifySpoonOnMyRecipe: true,
            notifyForkOfMyRecipe: false,
            notifyCookbookSaveOfMine: true,
            notifyFellowChefOriginCook: false
           ) as? Value {
            return APIEnvelope(requestID: "req_transport_notifications", data: data)
        }
        if Value.self == SettingsAPITokenListResponse.self,
           let data = SettingsAPITokenListResponse(tokens: [
            SettingsAPITokenSummary(
                id: "cred_transport",
                name: "Transport token",
                tokenPrefix: "sj_transport",
                scopes: ["recipes:read"],
                createdAt: SettingsTokenConnectionTests.createdAt,
                updatedAt: SettingsTokenConnectionTests.createdAt,
                lastUsedAt: nil,
                revokedAt: nil,
                expiresAt: nil
            )
           ]) as? Value {
            return APIEnvelope(requestID: "req_transport_tokens", data: data)
        }
        if Value.self == SettingsOAuthConnectionListResponse.self,
           let data = SettingsOAuthConnectionListResponse(connections: [
            SettingsOAuthConnectionSummary(
                id: "conn_transport",
                clientID: "client_transport",
                clientName: "Transport client",
                resource: nil,
                scopes: ["shopping_list:read"],
                createdAt: SettingsTokenConnectionTests.createdAt,
                refreshTokenCount: 1,
                accessTokenCount: 2
            )
           ]) as? Value {
            return APIEnvelope(requestID: "req_transport_connections", data: data)
        }

        throw SettingsTokenConnectionTestFailure(description: "Unexpected settings transport decode type at \(now)")
    }
}

private final class RecordingSettingsSurfaceTransport: SettingsSurfaceTransport, @unchecked Sendable {
    let validatedAt = SettingsTokenConnectionTests.now
    private(set) var requestPaths: [String] = []

    private let account: SettingsAccountProfile
    private let notifications: SettingsNotificationPreferences
    private let tokens: [SettingsAPITokenSummary]
    private let connections: [SettingsOAuthConnectionSummary]

    init(
        account: SettingsAccountProfile,
        notifications: SettingsNotificationPreferences,
        tokens: [SettingsAPITokenSummary],
        connections: [SettingsOAuthConnectionSummary]
    ) {
        self.account = account
        self.notifications = notifications
        self.tokens = tokens
        self.connections = connections
    }

    func fetchAccount(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsAccountProfile> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        return SettingsTransportEnvelope(requestID: "req_account", data: account, validatedAt: validatedAt)
    }

    func fetchNotificationPreferences(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<SettingsNotificationPreferences> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        return SettingsTransportEnvelope(requestID: "req_notifications", data: notifications, validatedAt: validatedAt)
    }

    func fetchAPITokens(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsAPITokenSummary]> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        return SettingsTransportEnvelope(requestID: "req_tokens", data: tokens, validatedAt: validatedAt)
    }

    func fetchOAuthConnections(_ request: APIRequestBuilder, configuration: APIClientConfiguration) async throws -> SettingsTransportEnvelope<[SettingsOAuthConnectionSummary]> {
        requestPaths.append(try request.urlRequest(configuration: configuration).url.path)
        return SettingsTransportEnvelope(requestID: "req_connections", data: connections, validatedAt: validatedAt)
    }
}
