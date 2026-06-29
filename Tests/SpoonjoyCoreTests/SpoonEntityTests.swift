import Foundation
import Testing
@testable import SpoonjoyCore

@Suite("Spoon cook-log App Entity contracts")
struct SpoonEntityTests {
    @Test("spoon entity sources exist with AppIntents contracts")
    func spoonEntitySourcesExistWithAppIntentsContracts() throws {
        var failures = spoonSourceContractFailures(
            requiredFiles: [
                "Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift",
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift",
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift",
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift"
            ],
            requiredTokens: [
                "Sources/SpoonjoyCore/Native/SpoonEntityCatalog.swift": [
                    "SpoonEntityCatalog",
                    "SpoonEntityCatalogError",
                    "SpoonEntityKind",
                    "SpoonEntityTransferValue",
                    "SpoonEntityScope",
                    "SpoonEntityDescriptor",
                    "SpoonEntityIndexPurgePlan",
                    "isPlaceholder",
                    "spoonEntity(id:",
                    "spoonEntities(for identifiers:",
                    "spoonEntities(matching string:",
                    "suggestedSpoonEntities",
                    "public static func loading(",
                    "loadSnapshot()",
                    "NativeSyncSnapshot",
                    "NativeSyncCachedRecord",
                    "NativeSyncEntryKind.recipe",
                    "NativeSyncEntryKind.spoon",
                    "NativeSyncResourceType.spoon",
                    "tombstones",
                    "accountID",
                    "environment",
                    "public static func spoonEntityIdentifier(",
                    "public static func resolvedSpoonID(",
                    "public static func purgeEntityIdentifiers(",
                    "purgeDomainIdentifiers(",
                    "public static func accountScopePurge(",
                    "public static func tombstonePurge(",
                    "public static func cacheDeletePurge(",
                    "domainIdentifiers",
                    "SpotlightIndexPlan.spoonUniqueIdentifier",
                    "SpotlightIndexPlan.spoonDomainIdentifier",
                    "Recipe",
                    "RecipeDetailRecentSpoon",
                    "recentSpoons",
                    "deletedAt",
                    "cookedAt",
                    "note",
                    "nextTime",
                    "photoURL",
                    "AppRoute.recipeDetail",
                    "NativeSharePayload.privateSpoon",
                    "privateTransferValue",
                    "debugFields"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpoonEntities.swift": [
                    "#if canImport(AppIntents)",
                    "import AppIntents",
                    "import CoreTransferable",
                    "import SpoonjoyCore",
                    "@available(iOS 27.0, macOS 27.0, *)",
                    "struct SpoonjoySpoonEntity: AppEntity",
                    "struct SpoonjoySpoonEntityQuery: EntityQuery, EntityStringQuery",
                    "typealias DefaultQuery = SpoonjoySpoonEntityQuery",
                    "static let typeDisplayRepresentation",
                    "var displayRepresentation",
                    "DisplayRepresentation",
                    "TypeDisplayRepresentation",
                    "entities(for identifiers: [String]) async throws",
                    "entities(matching string: String) async throws",
                    "suggestedEntities() async throws",
                    "SpoonEntityCatalog",
                    "SpoonEntityDescriptor",
                    "Transferable",
                    "TransferRepresentation",
                    "SpoonEntityTransferValue",
                    "resolvedSpoonID() throws",
                    "NativeIntentActionError.unresolvedSpoonEntity",
                    "descriptor.isPlaceholder",
                    "DeepLinkURLBuilder.url(for:",
                    "NativeAppStateLocation.defaultFileURL()",
                    "FileBackedNativeSyncStore",
                    "loadSnapshot()",
                    "trustedIntentScope",
                    "KeychainTokenVault()",
                    "scope.accountID",
                    "scope.environment"
                ],
                "Sources/SpoonjoyCore/Native/NativeCapabilityMetadata.swift": [
                    "SpoonjoySpoonEntity",
                    "SpoonjoySpoonEntityQuery"
                ],
                "Sources/SpoonjoyCore/Native/ScenarioVerifier.swift": [
                    "spoon cook-log App Entity",
                    "SpoonEntityCatalog",
                    "SpoonjoySpoonEntity"
                ],
                "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift": [
                    "NativeSpoonEntityIndexPurgeOperation",
                    "NativeSpoonEntityIndexPurgeRequest",
                    "spoonEntityIndexPurge",
                    "spoonEntityPurgeIdentifiers",
                    "spoonEntityPurgeDomainIdentifiers",
                    "performSettingsSessionOperation",
                    "SpoonEntityIndexPurgePlan.accountScopePurge",
                    "SpoonEntityCatalog.purgeEntityIdentifiers(",
                    "SpoonEntityCatalog.purgeDomainIdentifiers(",
                    "purgeSpoonEntityIdentifiers",
                    "logout",
                    "revokeAndLogout",
                    "cacheEnvironment"
                ],
                "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift": [
                    "bootstrapAndDrain",
                    "SpoonEntityIndexPurgePlan.tombstonePurge",
                    "SpoonEntityIndexPurgePlan.accountScopePurge",
                    "spoonEntityAccountScopePurgePlan",
                    "spoonEntityPurgeIdentifiers",
                    "spoonEntityPurgeDomainIdentifiers",
                    "previousSnapshot",
                    "SpoonEntityCatalog.purgeEntityIdentifiers(",
                    "SpoonEntityCatalog.purgeDomainIdentifiers(",
                    "NativeSyncResourceType.spoon",
                    "tombstones",
                    "removedCacheKeys"
                ],
                "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift": [
                    "let report = try? await syncTriggerCoordinator.handle(.foreground)",
                    "NativeSpoonEntityIndexPurgeRequest",
                    "report.spoonEntityPurgeIdentifiers",
                    "report.spoonEntityPurgeDomainIdentifiers",
                    "purgeSpoonEntityIndexesHandler"
                ],
                "Apps/Spoonjoy/Shared/Native/SpoonjoySpotlightIndexer.swift": [
                    "func delete(identifiers: [String], domainIdentifiers: [String])",
                    "deleteSearchableItems(withIdentifiers:",
                    "deleteSearchableItems(withDomainIdentifiers:"
                ]
            ],
            forbiddenTokens: [
                "@Parameter(title: \"Spoon ID\")",
                "var spoonID: String",
                "String-only spoon App Intent",
                "comment App Entity",
                "feed App Entity",
                "reaction App Entity",
                "TODO Spoon AppEntity",
                "eventually add spoon entities"
            ]
        )
        failures.append(contentsOf: spoonSourceBodyContractFailures(
            contracts: [
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "performSettingsSessionOperation",
                    pattern: #"func\s+performSettingsSessionOperation\(_ operation: SettingsSessionOperation\)"#,
                    requiredTokens: [
                        "case .logout, .revokeAndLogout",
                        "SpoonEntityIndexPurgePlan.accountScopePurge",
                        "SpoonEntityCatalog.purgeEntityIdentifiers(",
                        "SpoonEntityCatalog.purgeDomainIdentifiers(",
                        "purgeSpoonEntityIdentifiers",
                        "cacheEnvironment"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/AppState/NativeLiveAppStore.swift",
                    label: "bootstrapFromLiveAPI consumes spoon sync purge report",
                    pattern: #"func\s+bootstrapFromLiveAPI\(\s*session: AuthSession,\s*trigger: NativeSyncTriggerEvent\s*\)"#,
                    requiredTokens: [
                        "let report = try await syncTriggerCoordinator.handle(trigger)",
                        "report.spoonEntityPurgeIdentifiers",
                        "report.spoonEntityPurgeDomainIdentifiers"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Apps/Spoonjoy/Shared/AppShell/PlatformNavigationView.swift",
                    label: "foreground sync consumes spoon sync purge report",
                    pattern: #"\.task\(id: contentState\.environment\.rawValue\)"#,
                    requiredTokens: [
                        "let report = try? await syncTriggerCoordinator.handle(.foreground)",
                        "NativeSpoonEntityIndexPurgeRequest",
                        "report.spoonEntityPurgeIdentifiers",
                        "report.spoonEntityPurgeDomainIdentifiers",
                        "purgeSpoonEntityIndexesHandler"
                    ],
                    forbiddenTokens: []
                ),
                (
                    relativePath: "Sources/SpoonjoyCore/Sync/NativeSyncEngine.swift",
                    label: "bootstrapAndDrain scoped spoon tombstone purge",
                    pattern: #"public\s+func\s+bootstrapAndDrain\(\s*configuration: APIClientConfiguration,\s*trigger: NativeCacheRevalidationTrigger,\s*scope: NativeSyncExecutionScope\s*\)"#,
                    requiredTokens: [
                        "case .success(let cursor, let tombstones)",
                        "SpoonEntityIndexPurgePlan.tombstonePurge",
                        "spoonEntityAccountScopePurgePlan",
                        "spoonEntityPurgeIdentifiers",
                        "spoonEntityPurgeDomainIdentifiers",
                        "previousSnapshot",
                        "SpoonEntityCatalog.purgeEntityIdentifiers(",
                        "SpoonEntityCatalog.purgeDomainIdentifiers(",
                        "NativeSyncResourceType.spoon",
                        "removedCacheKeys"
                    ],
                    forbiddenTokens: []
                )
            ]
        ))

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("spoon entities resolve from scoped native sync cache records")
    func spoonEntitiesResolveFromScopedNativeSyncCacheRecords() async throws {
        let catalog = try Self.spoonCatalog()
        let spoon = try await catalog.spoonEntity(id: "spoon_ari_lemon")

        #expect(spoon.id == SpoonEntityCatalog.spoonEntityIdentifier(spoonID: "spoon_ari_lemon", accountID: "account_ari", environment: .production))
        #expect(spoon.spoonID == "spoon_ari_lemon")
        #expect(spoon.recipeID == "recipe_lemon_pantry_pasta")
        #expect(spoon.recipeTitle == "Lemon Pantry Pasta")
        #expect(spoon.chefUsername == "ari")
        #expect(spoon.title == "Lemon Pantry Pasta cook log")
        #expect(spoon.subtitle == "Loved this with extra lemon.")
        #expect(spoon.disambiguationLabel == "Lemon Pantry Pasta by ari")
        #expect(spoon.route == .recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail))
        #expect(spoon.photoURL == URL(string: "https://spoonjoy.app/photos/spoons/spoon_ari_lemon.jpg"))
        #expect(!spoon.isPlaceholder)

        let transfer = spoon.transferValue
        #expect(transfer.kind == .spoon)
        #expect(transfer.rawResourceID == "spoon_ari_lemon")
        #expect(transfer.recipeID == "recipe_lemon_pantry_pasta")
        #expect(transfer.recipeTitle == "Lemon Pantry Pasta")
        #expect(transfer.title == "Lemon Pantry Pasta cook log")
        #expect(transfer.routeIdentifier == AppRoute.recipeDetail(id: "recipe_lemon_pantry_pasta", presentation: .detail).stateIdentifier)
        #expect(transfer.publicURL == nil)
        #expect(transfer.privateTransferValue.contains("domain=spoon"))
        #expect(transfer.userVisibleSummary == "Lemon Pantry Pasta: Loved this with extra lemon.")
        #expect(transfer.debugFields.isEmpty)
        #expect(try SpoonEntityCatalog.resolvedSpoonID(from: spoon.id, accountID: "account_ari", environment: .production) == "spoon_ari_lemon")

        let matches = try await catalog.spoonEntities(matching: "  lemon  ")
        #expect(matches.map(\.spoonID) == ["spoon_ari_lemon"])

        let suggested = try await catalog.suggestedSpoonEntities(limit: 10)
        #expect(suggested.map(\.spoonID) == ["spoon_ari_lemon", "spoon_bea_toast"])

        let byIdentifier = try await catalog.spoonEntities(for: [suggested[1].id, suggested[0].id])
        #expect(byIdentifier.map(\.spoonID) == ["spoon_bea_toast", "spoon_ari_lemon"])

        let rawIdentifierBatch = try await catalog.spoonEntities(for: ["spoon_ari_lemon"])
        #expect(rawIdentifierBatch.isEmpty)
    }

    @Test("spoon entity lookup uses supplied sync snapshot records instead of fixture fallback")
    func spoonEntityLookupUsesSuppliedSyncSnapshotRecordsInsteadOfFixtureFallback() async throws {
        let recipe = try Self.recipe(id: "recipe_saffron_rice", title: "Saffron Rice", recentSpoons: [
            Self.spoon(id: "spoon_saffron", recipeID: "recipe_saffron_rice", note: "Weeknight saffron test.", cookedAt: nil)
        ])
        let catalog = try Self.spoonCatalog(recipes: [recipe], spoons: recipe.recentSpoons)

        let suggested = try await catalog.suggestedSpoonEntities(limit: 10)
        #expect(suggested.map(\.spoonID) == ["spoon_saffron"])
        #expect(suggested.first?.recipeTitle == "Saffron Rice")
        #expect(suggested.first?.subtitle == "Weeknight saffron test.")

        let matches = try await catalog.spoonEntities(matching: "saff")
        #expect(matches.map(\.spoonID) == ["spoon_saffron"])

        let fixtureMatches = try await catalog.spoonEntities(matching: "lemon")
        #expect(fixtureMatches.isEmpty)
    }

    @Test("spoon entity lookup filters deleted, tombstoned, and wrong-scope data")
    func spoonEntityLookupFiltersDeletedTombstonedAndWrongScopeData() async throws {
        let liveSpoon = Self.spoon(id: "spoon_live", recipeID: "recipe_lemon_pantry_pasta", note: "Visible cook.", cookedAt: "2026-06-01T10:00:00.000Z")
        let deletedSpoon = Self.spoon(id: "spoon_deleted", recipeID: "recipe_lemon_pantry_pasta", note: "Deleted cook.", cookedAt: "2026-06-01T11:00:00.000Z", deletedAt: "2026-06-01T12:00:00.000Z")
        let tombstonedSpoon = Self.spoon(id: "spoon_tombstoned", recipeID: "recipe_lemon_pantry_pasta", note: "Tombstoned cook.", cookedAt: "2026-06-01T12:00:00.000Z")
        let recipe = try Self.recipe(id: "recipe_lemon_pantry_pasta", title: "Lemon Pantry Pasta", recentSpoons: [liveSpoon, deletedSpoon, tombstonedSpoon])
        let catalog = try Self.spoonCatalog(
            recipes: [recipe],
            spoons: recipe.recentSpoons,
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .spoon,
                    resourceID: "spoon_tombstoned",
                    parentResourceID: "recipe_lemon_pantry_pasta",
                    title: "Tombstoned cook.",
                    deletedAt: "2026-06-01T13:00:00.000Z",
                    updatedAt: "2026-06-01T13:00:00.000Z"
                )
            ]
        )

        let suggested = try await catalog.suggestedSpoonEntities(limit: 10)
        #expect(suggested.map(\.spoonID) == ["spoon_live"])
        #expect(try await catalog.spoonEntities(matching: "deleted").isEmpty)
        #expect(try await catalog.spoonEntities(matching: "tombstoned").isEmpty)

        let wrongAccountCatalog = try Self.spoonCatalog(currentAccountID: "account_other")
        let wrongEnvironmentCatalog = try Self.spoonCatalog(environment: .local)

        #expect(try await wrongAccountCatalog.suggestedSpoonEntities(limit: 10).isEmpty)
        #expect(try await wrongEnvironmentCatalog.suggestedSpoonEntities(limit: 10).isEmpty)
        #expect(try await wrongAccountCatalog.spoonEntities(matching: "lemon").isEmpty)
        #expect(try await wrongEnvironmentCatalog.spoonEntities(matching: "lemon").isEmpty)

        await spoonExpectAsyncThrows(SpoonEntityCatalogError.self) {
            _ = try await wrongAccountCatalog.spoonEntity(id: "spoon_ari_lemon")
        }
        await spoonExpectAsyncThrows(SpoonEntityCatalogError.self) {
            _ = try await wrongEnvironmentCatalog.spoonEntity(id: "spoon_ari_lemon")
        }

        let wrongScopedID = SpoonEntityCatalog.spoonEntityIdentifier(
            spoonID: "spoon_ari_lemon",
            accountID: "account_other",
            environment: .production
        )
        let wrongScopedBatch = try await catalog.spoonEntities(for: [wrongScopedID])
        #expect(wrongScopedBatch.isEmpty)
    }

    @Test("spoon entity transfer values filter private and debug-only fields")
    func spoonEntityTransferValuesFilterPrivateAndDebugOnlyFields() async throws {
        let catalog = try Self.spoonCatalog()
        let spoon = try await catalog.spoonEntity(id: "spoon_ari_lemon")
        let serializedValues = [
            spoon.transferValue.privateTransferValue,
            spoon.transferValue.userVisibleSummary
        ].joined(separator: "\n")

        for forbidden in [
            "account_ari",
            NativeCacheEnvironment.production.rawValue,
            "photoUrl",
            "photos/spoons",
            "/tmp/",
            "provider",
            "conflict",
            "debug",
            "comment",
            "feed",
            "reaction"
        ] {
            #expect(!serializedValues.localizedCaseInsensitiveContains(forbidden), "\(forbidden) leaked into spoon transfer value")
        }

        #expect(spoon.transferValue.debugFields.isEmpty)
        #expect(spoon.transferValue.publicURL == nil)
    }

    @Test("spoon entity coverage edges preserve placeholder loading and identifier behavior")
    func spoonEntityCoverageEdgesPreservePlaceholderLoadingAndIdentifierBehavior() async throws {
        let placeholder = SpoonEntityDescriptor.placeholder
        #expect(placeholder.isPlaceholder)
        #expect(placeholder.transferValue.publicURL == nil)

        let cookedAtOnly = Self.spoon(
            id: "spoon_cooked_at_only",
            recipeID: "recipe_edge_spoons",
            note: "  ",
            cookedAt: "2026-06-03T10:00:00.000Z"
        )
        let nextTimeOnly = Self.spoon(
            id: "spoon_next_time_only",
            recipeID: "recipe_edge_spoons",
            note: nil,
            cookedAt: nil,
            nextTime: "Try chili crisp."
        )
        let untimed = Self.spoon(
            id: "spoon_untimed",
            recipeID: "recipe_edge_spoons",
            note: nil,
            cookedAt: nil
        )
        let sameDateB = Self.spoon(id: "spoon_tie_b", recipeID: "recipe_edge_spoons", note: "Tie B.", cookedAt: nil)
        let sameDateA = Self.spoon(id: "spoon_tie_a", recipeID: "recipe_edge_spoons", note: "Tie A.", cookedAt: nil)
        let orphan = Self.spoon(id: "spoon_orphan", recipeID: "recipe_missing", note: "No recipe.", cookedAt: nil)
        let recipe = try Self.recipe(
            id: "recipe_edge_spoons",
            title: "Edge Spoon Pasta",
            recentSpoons: [cookedAtOnly, nextTimeOnly, untimed, sameDateB, sameDateA]
        )
        let snapshot = try Self.syncSnapshot(
            recipes: [recipe],
            spoons: [orphan],
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .recipe,
                    resourceID: "recipe_deleted_elsewhere",
                    parentResourceID: nil,
                    title: "Deleted elsewhere",
                    deletedAt: "2026-06-03T11:00:00.000Z",
                    updatedAt: "2026-06-03T11:00:00.000Z"
                )
            ]
        )
        let directCatalog = SpoonEntityCatalog(
            syncSnapshot: snapshot,
            currentAccountID: "account_ari",
            environment: .production
        )
        #expect(try await directCatalog.spoonEntities(matching: "orphan").isEmpty)
        let syncStore = InMemoryNativeSyncStore(
            accountID: snapshot.accountID,
            environment: snapshot.environment,
            checkpoint: snapshot.checkpoint,
            queue: snapshot.queue,
            cachedRecords: snapshot.cachedRecords
        )
        let catalog = try await SpoonEntityCatalog.loading(
            syncStore: syncStore,
            currentAccountID: "account_ari",
            environment: .production
        )

        let all = try await catalog.spoonEntities(matching: " ")
        #expect(all.map { $0.spoonID } == [
            "spoon_cooked_at_only",
            "spoon_next_time_only",
            "spoon_tie_a",
            "spoon_tie_b",
            "spoon_untimed"
        ])
        #expect(all.first?.subtitle == "Cooked 2026-06-03T10:00:00.000Z")
        #expect(all[1].subtitle == "Next time: Try chili crisp.")
        #expect(all.last?.subtitle == "Cook log")

        let scopedID = SpoonEntityCatalog.spoonEntityIdentifier(
            spoonID: "spoon_cooked_at_only",
            accountID: "account_ari",
            environment: .production
        )
        #expect(try await catalog.spoonEntity(id: scopedID).spoonID == "spoon_cooked_at_only")
        await spoonExpectAsyncThrows(SpoonEntityCatalogError.self) {
            _ = try await catalog.spoonEntity(id: "spoon_missing")
        }
        await spoonExpectAsyncThrows(SpoonEntityCatalogError.self) {
            _ = try await catalog.spoonEntity(id: "spoon/unsafe")
        }
        #expect(try await catalog.spoonEntities(matching: "orphan").isEmpty)
    }

    @Test("spoon entity spotlight and intent error edges stay private and fail closed")
    func spoonEntitySpotlightAndIntentErrorEdgesStayPrivateAndFailClosed() {
        let emptyScope = SpotlightIndexScope(accountID: "", environment: .production)
        #expect(emptyScope.identifierPrefix == "production|unbound")
        #expect(emptyScope.domainPrefix == "app.spoonjoy.production.unbound")

        let safeScope = SpotlightIndexScope(accountID: "account_ari", environment: .production)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: SpotlightIndexPlan.spoonUniqueIdentifier(
            spoonID: "spoon_ari_lemon",
            scope: safeScope
        )) == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account_ari|recipe|../unsafe") == .unknownLink)
        #expect(SpotlightIndexPlan.route(uniqueIdentifier: "production|account_ari|cookbook|../unsafe") == .unknownLink)
        #expect(NativeIntentActionError.unresolvedSpoonEntity.description == "Choose a Spoonjoy cook log before running this Siri action.")
    }

    @Test("spoon entity purge plans cover logout account-switch cache-delete and tombstones")
    func spoonEntityPurgePlansCoverLogoutAccountSwitchCacheDeleteAndTombstones() throws {
        let scope = SpoonEntityScope(accountID: "account_ari", environment: .production)
        #expect(scope.domainIdentifier == "spoon:production:account_ari")

        let logoutPlan = SpoonEntityIndexPurgePlan.accountScopePurge(
            accountID: scope.accountID,
            environment: scope.environment,
            spoonIDs: ["spoon_ari_lemon", "spoon_bea_toast"]
        )
        let spotlightScope = SpotlightIndexScope(accountID: scope.accountID, environment: scope.environment)
        #expect(logoutPlan.identifiers == [
            SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_ari_lemon", scope: spotlightScope),
            SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_bea_toast", scope: spotlightScope)
        ])
        #expect(logoutPlan.domainIdentifiers == [SpotlightIndexPlan.spoonDomainIdentifier(scope: spotlightScope)])
        #expect(logoutPlan.reason == .accountScopeChanged)

        let cacheDeletePlan = SpoonEntityIndexPurgePlan.cacheDeletePurge(
            accountID: scope.accountID,
            environment: scope.environment,
            spoonIDs: ["spoon_ari_lemon"]
        )
        #expect(cacheDeletePlan.identifiers == [
            SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_ari_lemon", scope: spotlightScope)
        ])
        #expect(cacheDeletePlan.domainIdentifiers.isEmpty)
        #expect(cacheDeletePlan.reason == .cacheDeleted)

        let tombstonePlan = SpoonEntityIndexPurgePlan.tombstonePurge(
            tombstones: [
                NativeSyncTombstone(
                    resourceType: .spoon,
                    resourceID: "spoon_ari_lemon",
                    parentResourceID: "recipe_lemon_pantry_pasta",
                    title: "Loved this with extra lemon.",
                    deletedAt: "2026-06-01T00:10:00.000Z",
                    updatedAt: "2026-06-01T00:10:00.000Z"
                ),
                NativeSyncTombstone(
                    resourceType: .recipe,
                    resourceID: "recipe_lemon_pantry_pasta",
                    parentResourceID: nil,
                    title: "Lemon Pantry Pasta",
                    deletedAt: "2026-06-01T00:11:00.000Z",
                    updatedAt: "2026-06-01T00:11:00.000Z"
                )
            ],
            accountID: scope.accountID,
            environment: scope.environment
        )
        #expect(tombstonePlan.identifiers == [
            SpotlightIndexPlan.spoonUniqueIdentifier(spoonID: "spoon_ari_lemon", scope: spotlightScope)
        ])
        #expect(tombstonePlan.domainIdentifiers.isEmpty)
        #expect(tombstonePlan.reason == .tombstoneApplied)

        #expect(SpoonEntityCatalog.purgeEntityIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: SpoonEntityIndexPurgePlan(
                identifiers: [SpoonEntityCatalog.spoonEntityIdentifier(spoonID: "spoon_ari_lemon", accountID: "account_other", environment: .production)],
                domainIdentifiers: ["spoon:production:account_other"],
                reason: .cacheDeleted
            )
        ).isEmpty)
        #expect(SpoonEntityCatalog.purgeDomainIdentifiers(
            accountID: scope.accountID,
            environment: scope.environment,
            plan: SpoonEntityIndexPurgePlan(
                identifiers: [],
                domainIdentifiers: ["spoon:production:account_other"],
                reason: .accountScopeChanged
            )
        ).isEmpty)
    }

    private static func spoonCatalog(
        currentAccountID: String = "account_ari",
        environment: NativeCacheEnvironment = .production,
        recipes: [Recipe]? = nil,
        spoons: [RecipeDetailRecentSpoon]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> SpoonEntityCatalog {
        SpoonEntityCatalog(
            syncSnapshot: try syncSnapshot(recipes: recipes, spoons: spoons, tombstones: tombstones),
            currentAccountID: currentAccountID,
            environment: environment
        )
    }

    private static func syncSnapshot(
        recipes: [Recipe]? = nil,
        spoons: [RecipeDetailRecentSpoon]? = nil,
        tombstones: [NativeSyncTombstone] = []
    ) throws -> NativeSyncSnapshot {
        let resolvedRecipes = try recipes ?? defaultRecipes()
        let resolvedSpoons = spoons ?? resolvedRecipes.flatMap(\.recentSpoons)
        return NativeSyncSnapshot(
            accountID: "account_ari",
            environment: .production,
            checkpoint: try NativeSyncCheckpoint(
                globalCursor: PaginationCursor(rawValue: "spoon-entity-global-cursor"),
                shoppingCursor: nil,
                updatedAt: "2026-06-29T00:00:00.000Z"
            ),
            queue: NativeMutationQueue(),
            cachedRecords: try resolvedRecipes.map { recipe in
                NativeSyncCachedRecord(
                    kind: .recipe,
                    resourceID: recipe.id,
                    payload: try spoonJSONValue(recipe),
                    serverRevision: .updatedAt(recipe.updatedAt)
                )
            } + resolvedSpoons.map { spoon in
                NativeSyncCachedRecord(
                    kind: .spoon,
                    resourceID: spoon.id,
                    payload: try spoonJSONValue(spoon),
                    serverRevision: .updatedAt(spoon.updatedAt)
                )
            },
            tombstones: tombstones
        )
    }

    private static func defaultRecipes() throws -> [Recipe] {
        [
            try recipe(
                id: "recipe_lemon_pantry_pasta",
                title: "Lemon Pantry Pasta",
                recentSpoons: [
                    spoon(
                        id: "spoon_ari_lemon",
                        recipeID: "recipe_lemon_pantry_pasta",
                        note: "Loved this with extra lemon.",
                        cookedAt: "2026-06-01T10:00:00.000Z",
                        photoURL: URL(string: "https://spoonjoy.app/photos/spoons/spoon_ari_lemon.jpg")
                    )
                ]
            ),
            try recipe(
                id: "recipe_tomato_toast",
                title: "Tomato Toast",
                recentSpoons: [
                    spoon(
                        id: "spoon_bea_toast",
                        recipeID: "recipe_tomato_toast",
                        chef: ChefSummary(id: "chef_bea", username: "bea"),
                        note: "Needs more basil next time.",
                        cookedAt: "2026-05-30T10:00:00.000Z"
                    )
                ]
            )
        ]
    }

    private static func recipe(id: String, title: String, recentSpoons: [RecipeDetailRecentSpoon]) throws -> Recipe {
        let fixture = try #require(RecipeFixtureCatalog.decodeFromBundle().recipe(id: "recipe_lemon_pantry_pasta"))
        return Recipe(
            id: id,
            title: title,
            description: fixture.description,
            servings: fixture.servings,
            chef: ChefSummary(id: "chef_ari", username: "ari"),
            coverImageURL: fixture.coverImageURL,
            coverProvenanceLabel: fixture.coverProvenanceLabel,
            coverSourceType: fixture.coverSourceType,
            coverVariant: fixture.coverVariant,
            href: "/recipes/\(id)",
            canonicalURL: URL(string: "https://spoonjoy.app/recipes/\(id)")!,
            attribution: fixture.attribution,
            createdAt: fixture.createdAt,
            updatedAt: "2026-06-01T10:00:00.000Z",
            steps: fixture.steps,
            cookbooks: fixture.cookbooks,
            recentSpoons: recentSpoons
        )
    }

    private static func spoon(
        id: String,
        recipeID: String,
        chef: ChefSummary = ChefSummary(id: "chef_ari", username: "ari"),
        note: String?,
        cookedAt: String?,
        nextTime: String? = nil,
        photoURL: URL? = nil,
        deletedAt: String? = nil
    ) -> RecipeDetailRecentSpoon {
        RecipeDetailRecentSpoon(
            id: id,
            chefID: chef.id,
            recipeID: recipeID,
            cookedAt: cookedAt,
            photoURL: photoURL,
            note: note,
            nextTime: nextTime,
            deletedAt: deletedAt,
            createdAt: "2026-05-29T10:00:00.000Z",
            updatedAt: cookedAt ?? "2026-05-29T10:00:00.000Z",
            chef: chef
        )
    }

    private static func spoonJSONValue<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }
}

private func spoonSourceContractFailures(
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
        let uncommented = spoonUncommentedSwift(content)
        for token in requiredTokens[relativePath, default: []] where !uncommented.contains(token) {
            failures.append("\(relativePath) missing \(token)")
        }
        for token in forbiddenTokens where uncommented.contains(token) {
            failures.append("\(relativePath) contains forbidden \(token)")
        }
    }

    return failures
}

private func spoonSourceBodyContractFailures(
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
        let uncommented = spoonUncommentedSwift(content)
        guard let body = spoonDeclarationBody(in: uncommented, pattern: contract.pattern) else {
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

private func spoonDeclarationBody(in content: String, pattern: String) -> String? {
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

private func spoonUncommentedSwift(_ content: String) -> String {
    content
        .replacingOccurrences(of: #"/\*.*?\*/"#, with: "", options: [.regularExpression])
        .replacingOccurrences(of: #"(?m)//.*$"#, with: "", options: [.regularExpression])
}

private func spoonExpectAsyncThrows<E: Error>(
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
