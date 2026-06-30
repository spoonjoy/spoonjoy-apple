import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Capture draft App Entity contracts")
struct CaptureDraftEntityTests {
    @Test("capture draft entity sources exist with AppIntents contracts")
    func captureDraftEntitySourcesExistWithAppIntentsContracts() throws {
        var failures = captureDraftSourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/CaptureDraftEntityCatalog.swift": [
                    "CaptureDraftEntityCatalog",
                    "CaptureDraftEntityCatalogError",
                    "CaptureDraftEntityKind",
                    "CaptureDraftEntityTransferValue",
                    "CaptureDraftEntityScope",
                    "CaptureDraftEntityDescriptor",
                    "CaptureDraftEntityIndexPurgePlan",
                    "isPlaceholder",
                    "captureDraftEntity(id:",
                    "captureDraftEntities(for identifiers:",
                    "captureDraftEntities(matching string:",
                    "suggestedCaptureDraftEntities",
                    "public static func loading(",
                    "NativeAppSnapshot",
                    "NativeAppStateStore",
                    "NativeDurableCacheSnapshot",
                    "NativeDurableCacheStore",
                    "NativeCachePayload.captureDraft",
                    "NativeCacheDomain.captureDraft",
                    "accountID",
                    "environment",
                    "public static func captureDraftEntityIdentifier(",
                    "public static func resolvedCaptureDraftID(",
                    "public static func purgeEntityIdentifiers(",
                    "public static func purgeDomainIdentifiers(",
                    "public static func accountScopePurge(",
                    "public static func cacheDeletePurge(",
                    "public static func draftDiscardPurge(",
                    "domainIdentifiers",
                    "CaptureDraft",
                    "pendingCaptureImport",
                    "captureImportProviderBlocker",
                    "importReadiness",
                    "AppRoute.capture",
                    "NativeSharePayload.privateCaptureDraft",
                    "privateTransferValue",
                    "debugFields"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoyCaptureDraftEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import CoreTransferable",
                    "import SpoonjoyCore",
                    "@available(iOS 27.0, macOS 27.0, *)",
                    "struct SpoonjoyCaptureDraftEntity: AppEntity",
                    "struct SpoonjoyCaptureDraftEntityQuery: EntityQuery, EntityStringQuery",
                    "typealias DefaultQuery = SpoonjoyCaptureDraftEntityQuery",
                    "static let typeDisplayRepresentation",
                    "var displayRepresentation",
                    "DisplayRepresentation",
                    "TypeDisplayRepresentation",
                    "entities(for identifiers: [String]) async throws",
                    "entities(matching string: String) async throws",
                    "suggestedEntities() async throws",
                    "CaptureDraftEntityCatalog",
                    "CaptureDraftEntityDescriptor",
                    "Transferable",
                    "TransferRepresentation",
                    "CaptureDraftEntityTransferValue",
                    "resolvedCaptureDraftID() throws",
                    "NativeIntentActionError.unresolvedCaptureDraftEntity",
                    "descriptor.isPlaceholder",
                    "NativeAppStateLocation.defaultFileURL()",
                    "NativeAppStateStore",
                    "NativeDurableCacheStore",
                    "trustedIntentScope",
                    "KeychainTokenVault()",
                    "scope.accountID",
                    "scope.environment"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "SpoonjoyCaptureDraftEntity",
                    "SpoonjoyCaptureDraftEntityQuery"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "capture draft App Entity",
                    "CaptureDraftEntityCatalog",
                    "SpoonjoyCaptureDraftEntity"
                ],
                "Sources/SpoonjoyCore/Native/NativeIntentAction.swift": [
                    "unresolvedCaptureDraftEntity",
                    "Choose a Spoonjoy capture draft before running this Siri action."
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "NativeCaptureDraftEntityIndexPurgeOperation",
                    "NativeCaptureDraftEntityIndexPurgeRequest",
                    "captureDraftEntityIndexPurge",
                    "restoreFromCache",
                    "performSettingsSessionOperation",
                    "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
                    "CaptureDraftEntityIndexPurgePlan.draftDiscardPurge",
                    "loadOrCreateCacheSnapshot",
                    "loadAppSnapshot",
                    "CaptureDraftEntityCatalog.purgeEntityIdentifiers(",
                    "CaptureDraftEntityCatalog.purgeDomainIdentifiers(",
                    "purgeCaptureDraftEntityIdentifiers",
                    "recordCaptureDraft",
                    "discardCaptureDraft",
                    "logout",
                    "revokeAndLogout",
                    "cacheEnvironment"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "NativeCaptureDraftEntityIndexPurgeRequest",
                    "purgeCaptureDraftEntityIndexesHandler"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    "accountID: String? = nil",
                    "environment: NativeCacheEnvironment? = nil",
                    "deleteSearchableItems(withIdentifiers:",
                    "deleteSearchableItems(withDomainIdentifiers:"
                ]
            ],
            forbiddenTokens: [
                "@Parameter(title: \"Capture Draft ID\")",
                "var captureDraftID: String",
                "String-only capture draft App Intent",
                "comment App Entity",
                "feed App Entity",
                "message App Entity",
                "mail App Entity",
                "TODO CaptureDraft AppEntity",
                "eventually add capture draft entities"
            ]
        )
        failures.append(contentsOf: captureDraftSourceBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "restoreFromCache account or environment switch",
                    pattern: #"func\s+restoreFromCache\(\s*authSessionState: NativeAuthSessionState,\s*optimisticMutations: \[NativeQueuedMutation\] = \[\]\s*\)"#,
                    requiredTokens: [
                        "preFilterCacheRecord",
                        "preFilterAppStateRecord",
                        "dependencies.cacheStore.loadOrRecover(fallback:",
                        "appStateStore.loadOrCreate(fallback:",
                        "previousCacheSnapshot",
                        "previousAppSnapshot",
                        "preFilterCacheRecord.value",
                        "preFilterAppStateRecord.value",
                        "previousCacheSnapshot.accountID",
                        "previousCacheSnapshot.environment",
                        "previousAppSnapshot.accountID",
                        "previousAppSnapshot.environment",
                        "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
                        "CaptureDraftEntityCatalog.purgeEntityIdentifiers(",
                        "CaptureDraftEntityCatalog.purgeDomainIdentifiers(",
                        "purgeCaptureDraftEntityIdentifiers",
                        "accountID: previousCacheSnapshot.accountID",
                        "environment: previousCacheSnapshot.environment",
                        "accountID: previousAppSnapshot.accountID",
                        "environment: previousAppSnapshot.environment",
                        "!= accountID(for: authSessionState)",
                        "!= cacheEnvironment"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "performSettingsSessionOperation",
                    pattern: #"func\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)"#,
                    requiredTokens: [
                        "case .logout, .revokeAndLogout",
                        "CaptureDraftEntityIndexPurgePlan.accountScopePurge",
                        "CaptureDraftEntityCatalog.purgeEntityIdentifiers(",
                        "CaptureDraftEntityCatalog.purgeDomainIdentifiers(",
                        "purgeCaptureDraftEntityIdentifiers",
                        "cacheEnvironment"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "discardCaptureDraft",
                    pattern: #"func\s+discardCaptureDraft\(id draftID: String\)"#,
                    requiredTokens: [
                        "CaptureDraftEntityIndexPurgePlan.draftDiscardPurge",
                        "CaptureDraftEntityCatalog.purgeEntityIdentifiers(",
                        "purgeCaptureDraftEntityIdentifiers",
                        "draftID"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "recordCaptureDraft",
                    pattern: #"func\s+recordCaptureDraft\(_ draft: CaptureDraft\)"#,
                    requiredTokens: [
                        "CaptureDraftEntityIndexPurgePlan.cacheDeletePurge",
                        "CaptureDraftEntityCatalog.purgeEntityIdentifiers(",
                        "purgeCaptureDraftEntityIdentifiers",
                        "draft.id"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("capture draft entities resolve from scoped app state and expose private transfer values")
    func captureDraftEntitiesResolveFromScopedAppStateAndExposePrivateTransferValues() async throws {
        let draft = try CaptureDraft.localText(
            id: "draft_local_text",
            rawText: "  Grandma's soup\nsecret token=should-not-leak  ",
            sourceURL: URL(string: "https://example.com/import?access_token=secret")!,
            createdAt: "2026-06-02T10:00:00.000Z"
        )
        let pendingImport = NativeQueuedMutation.recipeImportSubmit(
            source: try draft.importSource(),
            clientMutationID: "cm_import_draft_local_text",
            createdAt: "2026-06-02T10:01:00.000Z"
        )
        let catalog = try Self.catalog(
            appSnapshot: Self.appSnapshot(
                captureDraft: draft,
                pendingCaptureImport: pendingImport,
                captureImportProviderBlocker: "provider-secret-resource"
            )
        )

        let entity = try await catalog.captureDraftEntity(id: "draft_local_text")
        #expect(entity.id == CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
            draftID: "draft_local_text",
            accountID: "account_ari",
            environment: .production
        ))
        #expect(entity.captureDraftID == "draft_local_text")
        #expect(entity.scope == CaptureDraftEntityScope(accountID: "account_ari", environment: .production))
        #expect(entity.title == "Grandma's soup")
        #expect(entity.subtitle == "Text draft - pending import")
        #expect(entity.disambiguationLabel == "Grandma's soup from capture")
        #expect(entity.route == .capture)
        #expect(entity.source == .text)
        #expect(entity.importReadiness == .ready)
        #expect(entity.hasPendingImport)
        #expect(!entity.isPlaceholder)

        let transfer = entity.transferValue
        #expect(transfer.kind == .captureDraft)
        #expect(transfer.rawResourceID == "draft_local_text")
        #expect(transfer.title == "Grandma's soup")
        #expect(transfer.routeIdentifier == AppRoute.capture.stateIdentifier)
        #expect(transfer.publicURL == nil)
        #expect(transfer.privateTransferValue.contains("domain=capture-draft"))
        #expect(transfer.privateTransferValue.contains("source=text"))
        #expect(transfer.userVisibleSummary == "Grandma's soup")
        #expect(transfer.debugFields.isEmpty)
        #expect(!transfer.privateTransferValue.contains("should-not-leak"))
        #expect(!transfer.privateTransferValue.contains("access_token"))
        #expect(!transfer.privateTransferValue.contains("provider-secret-resource"))
        #expect(!transfer.privateTransferValue.contains("account_ari"))
        #expect(!transfer.privateTransferValue.contains("accountID"))

        let matches = try await catalog.captureDraftEntities(matching: "  soup  ")
        #expect(matches.map(\.captureDraftID) == ["draft_local_text"])

        let byIdentifier = try await catalog.captureDraftEntities(for: [entity.id])
        #expect(byIdentifier.map(\.captureDraftID) == ["draft_local_text"])
        #expect(try CaptureDraftEntityCatalog.resolvedCaptureDraftID(
            from: entity.id,
            accountID: "account_ari",
            environment: .production
        ) == "draft_local_text")
    }

    @Test("capture draft entities restore from durable cache without exposing media identifiers")
    func captureDraftEntitiesRestoreFromDurableCacheWithoutExposingMediaIdentifiers() async throws {
        let cacheSnapshot = try Self.cacheSnapshot(records: [
            Self.cacheRecord(
                id: "draft_cached_url",
                source: .shareSheetURL("https://example.com/recipe?token=secret"),
                fetchedAt: Self.instant("2026-06-02T10:00:00.000Z")
            ),
            Self.cacheRecord(
                id: "draft_cached_asset",
                source: .imageAsset("ph://asset/private-local-media"),
                fetchedAt: Self.instant("2026-06-02T10:02:00.000Z")
            )
        ])
        let catalog = CaptureDraftEntityCatalog(
            appSnapshot: nil,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: "account_ari",
            environment: .production
        )

        let suggested = try await catalog.suggestedCaptureDraftEntities(limit: 10)
        #expect(suggested.map(\.captureDraftID) == ["draft_cached_url"])
        let cached = try await catalog.captureDraftEntity(id: "draft_cached_url")
        #expect(cached.title == "example.com")
        #expect(cached.subtitle == "Share sheet URL draft")
        #expect(cached.transferValue.publicURL == nil)
        #expect(cached.transferValue.privateTransferValue.contains("capturedHost=example.com"))
        #expect(!cached.transferValue.privateTransferValue.contains("token=secret"))
        #expect(!cached.transferValue.privateTransferValue.contains("account_ari"))
        #expect(!cached.transferValue.privateTransferValue.contains("accountID"))
        #expect(cached.transferValue.debugFields.isEmpty)

        #expect(try await catalog.captureDraftEntities(matching: "private-local-media").isEmpty)
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await catalog.captureDraftEntity(id: "draft_cached_asset")
        }
    }

    @Test("capture draft entities filter wrong scope and reject unsafe identifiers")
    func captureDraftEntitiesFilterWrongScopeAndRejectUnsafeIdentifiers() async throws {
        let draft = try CaptureDraft.importURL(
            id: "draft_scoped_url",
            url: URL(string: "https://example.com/scoped")!,
            createdAt: "2026-06-02T11:00:00.000Z"
        )
        let appSnapshot = Self.appSnapshot(captureDraft: draft)
        let wrongAccountCatalog = try Self.catalog(appSnapshot: appSnapshot, currentAccountID: "account_other")
        let wrongEnvironmentCatalog = try Self.catalog(appSnapshot: appSnapshot, environment: .local)

        #expect(try await wrongAccountCatalog.suggestedCaptureDraftEntities(limit: 10).isEmpty)
        #expect(try await wrongEnvironmentCatalog.captureDraftEntities(matching: "example").isEmpty)
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.captureDraftEntity(id: "draft_scoped_url")
        }
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.captureDraftEntity(id: "draft_scoped_url")
        }
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await CaptureDraftEntityCatalog(
                appSnapshot: appSnapshot,
                cacheSnapshot: nil,
                currentAccountID: "account_ari",
                environment: .production
            ).captureDraftEntity(id: "draft/unsafe")
        }
    }

    @Test("capture draft entity purge plans cover logout account-switch discard and cache delete")
    func captureDraftEntityPurgePlansCoverLogoutAccountSwitchDiscardAndCacheDelete() throws {
        let scope = CaptureDraftEntityScope(accountID: "account_ari", environment: .production)
        let otherScope = CaptureDraftEntityScope(accountID: "account_other", environment: .local)
        let draft = try CaptureDraft.localText(
            id: "draft_purge",
            rawText: "Purge me.",
            createdAt: "2026-06-02T12:00:00.000Z"
        )
        let appSnapshot = Self.appSnapshot(captureDraft: draft)
        let spotlightScope = SpotlightIndexScope(accountID: scope.accountID, environment: scope.environment)

        let logoutPlan = CaptureDraftEntityIndexPurgePlan.accountScopePurge(
            appSnapshot: appSnapshot,
            cacheSnapshot: nil,
            accountID: scope.accountID,
            environment: scope.environment
        )
        #expect(logoutPlan.identifiers == [
            SpotlightIndexPlan.captureDraftUniqueIdentifier(draftID: draft.id, scope: spotlightScope)
        ])
        #expect(logoutPlan.domainIdentifiers == [
            SpotlightIndexPlan.captureDraftDomainIdentifier(scope: spotlightScope)
        ])
        #expect(logoutPlan.reason == .accountScopeChanged)

        let discardPlan = CaptureDraftEntityIndexPurgePlan.draftDiscardPurge(
            draftID: draft.id,
            accountID: scope.accountID,
            environment: scope.environment
        )
        #expect(discardPlan.identifiers == logoutPlan.identifiers)
        #expect(discardPlan.domainIdentifiers.isEmpty)
        #expect(discardPlan.reason == .draftDiscarded)

        let cacheDeletePlan = CaptureDraftEntityIndexPurgePlan.cacheDeletePurge(
            deletedRecordDomains: [.captureDraft(id: draft.id), .shoppingList],
            accountID: scope.accountID,
            environment: scope.environment
        )
        #expect(cacheDeletePlan.identifiers == logoutPlan.identifiers)
        #expect(cacheDeletePlan.domainIdentifiers.isEmpty)
        #expect(cacheDeletePlan.reason == .cacheDeleted)

        #expect(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
            accountID: otherScope.accountID,
            environment: otherScope.environment,
            plan: logoutPlan
        ).isEmpty)
        #expect(CaptureDraftEntityCatalog.purgeDomainIdentifiers(
            accountID: otherScope.accountID,
            environment: otherScope.environment,
            plan: logoutPlan
        ).isEmpty)
    }

    @Test("capture draft entity coverage edges preserve labels loading and fail-closed behavior")
    func captureDraftEntityCoverageEdgesPreserveLabelsLoadingAndFailClosedBehavior() async throws {
        let createdAt = "2026-06-02T13:00:00.000Z"
        let scoped = CaptureDraftEntityScope(accountID: "account_ari", environment: .production)
        #expect(scoped.domainIdentifier == "capture-draft:production:schema2:account_ari")
        #expect(CaptureDraftEntityDescriptor.placeholder.isPlaceholder)
        #expect(CaptureDraftEntityDescriptor.placeholder.transferValue.debugFields.isEmpty)
        #expect(NativeIntentActionError.unresolvedCaptureDraftEntity.description == "Choose a Spoonjoy capture draft before running this Siri action.")

        let drafts: [CaptureDraft] = [
            try CaptureDraft.importURL(id: "draft_url", url: URL(string: "https://example.com/url")!, createdAt: createdAt),
            CaptureDraft(id: "draft_image", source: .image, rawText: "scanned card", imageAssetIdentifier: "asset-image", createdAt: createdAt),
            try CaptureDraft.cameraImage(id: "draft_camera", assetIdentifier: "asset-camera", recognizedText: "camera card", createdAt: createdAt),
            try CaptureDraft.photoLibraryImage(id: "draft_photo", assetIdentifier: "asset-photo", recognizedText: "photo card", createdAt: createdAt),
            try CaptureDraft.jsonLD(id: "draft_json", jsonLD: .object(["name": .string("Cake")]), sourceURL: URL(string: "https://example.com/json")!, createdAt: createdAt),
            try CaptureDraft.videoURL(id: "draft_video", url: URL(string: "https://example.com/video")!, createdAt: createdAt)
        ]
        let subtitles = drafts.map { CaptureDraftEntityDescriptor(draft: $0, scope: scoped, hasPendingImport: false).subtitle }
        #expect(subtitles == [
            "URL draft",
            "Image draft",
            "Camera image draft",
            "Photo library image draft",
            "JSON-LD draft",
            "Video URL draft"
        ])

        let pendingDraft = try CaptureDraft.localText(id: "draft_pending_mismatch", rawText: "Draft text", createdAt: createdAt)
        let otherDraft = try CaptureDraft.localText(id: "draft_pending_other", rawText: "Other text", createdAt: createdAt)
        let mismatchedImport = NativeQueuedMutation.recipeImportSubmit(
            source: try otherDraft.importSource(),
            clientMutationID: "cm_other_import",
            createdAt: createdAt
        )
        let mismatchCatalog = try Self.catalog(appSnapshot: Self.appSnapshot(
            captureDraft: pendingDraft,
            pendingCaptureImport: mismatchedImport
        ))
        let mismatchEntity = try await mismatchCatalog.captureDraftEntity(id: "draft_pending_mismatch")
        #expect(!mismatchEntity.hasPendingImport)
        #expect(mismatchEntity.subtitle == "Text draft")

        let noScopeCatalog = CaptureDraftEntityCatalog(
            appSnapshot: Self.appSnapshot(captureDraft: drafts[0]),
            cacheSnapshot: nil,
            currentAccountID: nil,
            environment: .production
        )
        #expect(try await noScopeCatalog.captureDraftEntities(matching: "anything").isEmpty)
        #expect(try await noScopeCatalog.suggestedCaptureDraftEntities(limit: 1).isEmpty)
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await noScopeCatalog.captureDraftEntity(id: drafts[0].id)
        }

        let duplicateCache = try Self.cacheRecord(
            id: "draft_b",
            source: .text("cache duplicate"),
            fetchedAt: Self.instant(createdAt)
        )
        let sortedCatalog = try Self.catalog(
            appSnapshot: nil,
            cacheSnapshot: Self.cacheSnapshot(records: [
                try Self.cacheRecord(id: "draft_b", source: .text("B"), fetchedAt: Self.instant(createdAt)),
                try Self.cacheRecord(id: "draft_a", source: .text("A"), fetchedAt: Self.instant(createdAt)),
                try Self.cacheRecord(id: "draft_bad_url", source: .shareSheetURL("http://[::1"), fetchedAt: Self.instant(createdAt)),
                duplicateCache
            ])
        )
        let scopedDraftAIdentifier = CaptureDraftEntityCatalog.captureDraftEntityIdentifier(
            draftID: "draft_a",
            accountID: "account_ari",
            environment: .production
        )
        #expect(try await sortedCatalog.suggestedCaptureDraftEntities(limit: -1).isEmpty)
        #expect(try await sortedCatalog.suggestedCaptureDraftEntities(limit: 10).map(\.captureDraftID) == ["draft_a", "draft_b"])
        #expect(try await sortedCatalog.captureDraftEntities(matching: "").map(\.captureDraftID) == ["draft_a", "draft_b"])
        #expect(try await sortedCatalog.captureDraftEntities(matching: "zz-no-match").isEmpty)
        #expect(try await sortedCatalog.captureDraftEntities(for: [
            scopedDraftAIdentifier,
            "capture-draft:production:schema2:account_ari:missing"
        ]).map(\.captureDraftID) == ["draft_a"])
        #expect(try await sortedCatalog.captureDraftEntity(id: scopedDraftAIdentifier).captureDraftID == "draft_a")
        #expect(try await sortedCatalog.captureDraftEntity(id: "  draft_a  ").captureDraftID == "draft_a")
        await captureDraftExpectAsyncThrows(CaptureDraftEntityCatalogError.self) {
            _ = try await sortedCatalog.captureDraftEntity(id: ".")
        }

        let mismatchedPlan = CaptureDraftEntityIndexPurgePlan(
            identifiers: [SpotlightIndexPlan.captureDraftUniqueIdentifier(
                draftID: "draft_a",
                scope: SpotlightIndexScope(accountID: "account_other", environment: .production)
            )],
            domainIdentifiers: [],
            reason: .cacheDeleted
        )
        #expect(CaptureDraftEntityCatalog.purgeEntityIdentifiers(
            accountID: "account_ari",
            environment: .production,
            plan: mismatchedPlan
        ).isEmpty)
        #expect(CaptureDraftEntityIndexPurgePlan.draftDiscardPurge(
            draftID: "draft_missing_scope",
            accountID: nil,
            environment: .production
        ).identifiers.isEmpty)
        let scope = SpotlightIndexScope(accountID: "account_ari", environment: .production)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: SpotlightIndexPlan.captureDraftUniqueIdentifier(
            draftID: "draft_a",
            scope: scope
        ), scope: scope) == .capture)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: SpotlightIndexPlan.captureDraftUniqueIdentifier(
            draftID: "draft/unsafe",
            scope: scope
        ), scope: scope) == .unknownLink)
    }

    @Test("capture draft entity catalog loads from file backed stores")
    func captureDraftEntityCatalogLoadsFromFileBackedStores() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("capture-draft-entity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let appStateStore = NativeAppStateStore(fileURL: directory.appendingPathComponent("native-app-state.json"))
        let cacheStore = NativeDurableCacheStore(fileURL: directory.appendingPathComponent("native-durable-cache.json"))
        let appDraft = try CaptureDraft.localText(
            id: "draft_file_app",
            rawText: "Loaded from app store",
            createdAt: "2026-06-02T14:00:00.000Z"
        )
        try appStateStore.save(Self.appSnapshot(captureDraft: appDraft))
        try cacheStore.save(try Self.cacheSnapshot(records: [
            Self.cacheRecord(
                id: "draft_file_cache",
                source: .shareSheetURL("https://example.com/file-cache"),
                fetchedAt: Self.instant("2026-06-02T14:01:00.000Z")
            )
        ]))

        let catalog = try await CaptureDraftEntityCatalog.loading(
            appStateStore: appStateStore,
            cacheStore: cacheStore,
            currentAccountID: "account_ari",
            environment: .production,
            now: Self.instant("2026-06-02T14:02:00.000Z")
        )

        #expect(try await catalog.captureDraftEntity(id: "draft_file_app").title == "Loaded from app store")
        #expect(try await catalog.captureDraftEntity(id: "draft_file_cache").title == "example.com")

        let signedOutCatalog = try await CaptureDraftEntityCatalog.loading(
            appStateStore: NativeAppStateStore(fileURL: directory.appendingPathComponent("signed-out-state.json")),
            cacheStore: NativeDurableCacheStore(fileURL: directory.appendingPathComponent("signed-out-cache.json")),
            currentAccountID: nil,
            environment: .local,
            now: Self.instant("2026-06-02T14:03:00.000Z")
        )
        #expect(try await signedOutCatalog.suggestedCaptureDraftEntities().isEmpty)
    }

    private static func catalog(
        appSnapshot: NativeAppSnapshot?,
        cacheSnapshot: NativeDurableCacheSnapshot? = nil,
        currentAccountID: String = "account_ari",
        environment: NativeCacheEnvironment = .production
    ) throws -> CaptureDraftEntityCatalog {
        CaptureDraftEntityCatalog(
            appSnapshot: appSnapshot,
            cacheSnapshot: cacheSnapshot,
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    private static func appSnapshot(
        captureDraft: CaptureDraft?,
        pendingCaptureImport: NativeQueuedMutation? = nil,
        captureImportProviderBlocker: String? = nil,
        accountID: String? = "account_ari",
        environment: NativeCacheEnvironment? = .production
    ) -> NativeAppSnapshot {
        NativeAppSnapshot(
            accountID: accountID,
            environment: environment,
            captureDraft: captureDraft,
            pendingCaptureImport: pendingCaptureImport,
            captureImportProviderBlocker: captureImportProviderBlocker,
            savedAt: "2026-06-02T12:00:00.000Z"
        )
    }

    private static func cacheSnapshot(records: [NativeCacheRecord]) throws -> NativeDurableCacheSnapshot {
        try NativeDurableCacheSnapshot(
            schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
            accountID: "account_ari",
            environment: .production,
            createdAt: Self.instant("2026-06-02T12:00:00.000Z"),
            records: records,
            dismissedIndicators: []
        )
    }

    private static func cacheRecord(
        id: String,
        source: NativeCaptureDraftCacheSource,
        fetchedAt: Date
    ) throws -> NativeCacheRecord {
        try NativeCacheRecord(
            id: NativeCacheDomain.captureDraft(id: id).stableRecordID,
            metadata: NativeCacheRecordMetadata(
                accountID: "account_ari",
                environment: .production,
                schemaVersion: NativeDurableCacheSnapshot.currentSchemaVersion,
                domain: .captureDraft(id: id),
                fetchedAt: fetchedAt,
                lastValidatedAt: fetchedAt,
                sourceEndpoint: "local://capture-drafts/\(id)",
                serverRevision: .localRevision("draft-\(id)")
            ),
            payload: .captureDraft(id: id, source: source)
        )
    }

    private static func instant(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}

private extension NativeAppSnapshot {
    init(
        accountID: String?,
        environment: NativeCacheEnvironment?,
        captureDraft: CaptureDraft?,
        pendingCaptureImport: NativeQueuedMutation?,
        captureImportProviderBlocker: String?,
        savedAt: String
    ) {
        self.init(
            schemaVersion: 1,
            accountID: accountID,
            environment: environment,
            hasCompletedFirstRun: true,
            cookProgressByRecipeID: [:],
            shoppingList: nil,
            captureDraft: captureDraft,
            pendingCaptureImport: pendingCaptureImport,
            captureImportProviderBlocker: captureImportProviderBlocker,
            pendingMutations: MutationQueue(),
            lastOpenedRoute: AppRoute.capture.stateIdentifier,
            savedAt: savedAt
        )
    }
}

private func captureDraftSourceContractFailures(
    requiredFiles: [String],
    requiredTokens: [String: [String]],
    forbiddenTokens: [String]
) -> [String] {
    var failures: [String] = []
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    for relativePath in requiredFiles {
        let fileURL = rootURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            failures.append("missing \(relativePath)")
            continue
        }

        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let uncommented = captureDraftUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }

    return failures
}

private func captureDraftSourceBodyContractFailures(
    contracts: [(
        relativePath: String,
        label: String,
        pattern: String,
        requiredTokens: [String],
        forbiddenTokens: [String]
    )]
) -> [String] {
    var failures: [String] = []
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    for contract in contracts {
        let fileURL = rootURL.appendingPathComponent(contract.relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            failures.append("missing \(contract.relativePath)")
            continue
        }

        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let uncommented = captureDraftUncommentedSwift(content)
        guard let body = captureDraftDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func captureDraftDeclarationBody(in content: String, pattern: String) -> String? {
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

private func captureDraftUncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}

private func captureDraftExpectAsyncThrows<E: Error>(
    _ expectedError: E.Type,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        Issue.record("Expected \(expectedError) to be thrown.")
    } catch is E {
        return
    } catch {
        Issue.record("Expected \(expectedError), got \(error).")
    }
}
